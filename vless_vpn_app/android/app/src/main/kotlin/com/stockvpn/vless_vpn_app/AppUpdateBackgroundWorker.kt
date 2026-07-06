package com.stockvpn.vless_vpn_app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

private const val UPDATE_MANIFEST_URL = "https://samuraiservice.live/updates/latest.json"
private const val UPDATE_CHANNEL_ID = "samurai_service_status"
private const val UPDATE_PREFS_NAME = "update_background"
private const val UPDATE_PREF_LAST_NOTIFIED_VERSION = "last_notified_version_code"
private const val UPDATE_CHECK_INTERVAL_MILLIS = 3 * 60 * 60 * 1000L

class AppUpdateBackgroundWorker : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val pendingResult = goAsync()
        thread(name = "samurai-service-update-check") {
            try {
                performUpdateCheck(context.applicationContext)
            } finally {
                pendingResult.finish()
            }
        }
    }

    companion object {
        private const val ACTION_CHECK = "com.stockvpn.vless_vpn_app.ACTION_CHECK_UPDATES"

        fun schedule(context: Context) {
            val alarmManager = context.getSystemService(AlarmManager::class.java)
            val pendingIntent = pendingIntent(context)
            val triggerAtMillis = SystemClock.elapsedRealtime() + UPDATE_CHECK_INTERVAL_MILLIS
            alarmManager.setInexactRepeating(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAtMillis,
                UPDATE_CHECK_INTERVAL_MILLIS,
                pendingIntent,
            )
        }

        fun rescheduleAfterBoot(context: Context) {
            schedule(context)
        }

        private fun pendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, AppUpdateBackgroundWorker::class.java).apply {
                action = ACTION_CHECK
            }
            return PendingIntent.getBroadcast(
                context,
                5001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun performUpdateCheck(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS,
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }

            try {
                val localVersionCode = context.packageManager
                    .getPackageInfo(context.packageName, 0)
                    .let { packageInfo ->
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageInfo.longVersionCode.toInt()
                        } else {
                            @Suppress("DEPRECATION")
                            packageInfo.versionCode
                        }
                    }
                val manifest = fetchManifest()
                if (manifest.versionCode <= localVersionCode) {
                    return
                }

                val prefs = context.getSharedPreferences(UPDATE_PREFS_NAME, Context.MODE_PRIVATE)
                val lastNotifiedVersion = prefs.getInt(UPDATE_PREF_LAST_NOTIFIED_VERSION, 0)
                if (lastNotifiedVersion >= manifest.versionCode) {
                    return
                }

                if (showUpdateNotification(context, manifest)) {
                    prefs.edit()
                        .putInt(UPDATE_PREF_LAST_NOTIFIED_VERSION, manifest.versionCode)
                        .apply()
                }
            } catch (_: Exception) {
                // Background checks are best-effort only.
            }
        }

        private fun fetchManifest(): UpdateManifest {
            val connection = (URL(UPDATE_MANIFEST_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 15_000
                readTimeout = 15_000
                setRequestProperty("Accept", "application/json")
            }
            try {
                val code = connection.responseCode
                if (code !in 200..299) {
                    throw IllegalStateException("Unexpected response code: $code")
                }
                val payload = BufferedReader(InputStreamReader(connection.inputStream)).use { reader ->
                    reader.readText()
                }
                val json = JSONObject(payload)
                return UpdateManifest(
                    versionCode = json.optInt("versionCode", 0),
                    versionName = json.optString("versionName", "").trim(),
                )
            } finally {
                connection.disconnect()
            }
        }

        private fun showUpdateNotification(context: Context, manifest: UpdateManifest): Boolean {
            val notificationManager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    UPDATE_CHANNEL_ID,
                    "Samurai Service",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "Subscription and update notifications"
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
            val pendingIntent = PendingIntent.getActivity(
                context,
                manifest.versionCode,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val versionLabel = manifest.versionName.ifBlank { manifest.versionCode.toString() }
            val body = "Откройте приложение, чтобы установить новую версию Samurai Service."
            val notification = NotificationCompat.Builder(context, UPDATE_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentTitle("Доступно обновление $versionLabel")
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .build()
            notificationManager.notify(2000 + manifest.versionCode, notification)
            return true
        }
    }

    data class UpdateManifest(
        val versionCode: Int,
        val versionName: String,
    )
}

class AppUpdateBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            AppUpdateBackgroundWorker.rescheduleAfterBoot(context.applicationContext)
        }
    }
}
