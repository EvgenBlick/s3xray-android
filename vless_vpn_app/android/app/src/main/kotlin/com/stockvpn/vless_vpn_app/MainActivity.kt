package com.stockvpn.vless_vpn_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "SamuraiServiceOAuth"
    }

    private var authEventSink: EventChannel.EventSink? = null
    private var pendingAuthCallbackUrl: String? = null
    private var s3xEventSink: EventChannel.EventSink? = null
    private var pendingS3xLink: String? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.i(TAG, "onNewIntent action=${intent.action} data=${intent.dataString}")

        val s3xLink = extractS3xLink(intent)
        if (s3xLink != null) {
            Log.i(TAG, "onNewIntent accepted s3x link")
            pendingS3xLink = s3xLink
            s3xEventSink?.success(s3xLink)
            return
        }

        val callbackUrl = extractAuthCallbackUrl(intent) ?: return
        Log.i(TAG, "onNewIntent accepted callback=$callbackUrl")
        pendingAuthCallbackUrl = callbackUrl
        authEventSink?.success(callbackUrl)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppUpdateBackgroundWorker.schedule(applicationContext)
        pendingAuthCallbackUrl = extractAuthCallbackUrl(intent)
        pendingS3xLink = extractS3xLink(intent)
        Log.i(
            TAG,
            "configureFlutterEngine action=${intent?.action} data=${intent?.dataString} pending=$pendingAuthCallbackUrl s3xPending=${pendingS3xLink != null}"
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/auth_platform/events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                authEventSink = events
                Log.i(TAG, "auth event stream attached pending=$pendingAuthCallbackUrl")
                pendingAuthCallbackUrl?.let { callbackUrl ->
                    Log.i(TAG, "emitting pending callback to Dart stream callback=$callbackUrl")
                    events?.success(callbackUrl)
                }
            }

            override fun onCancel(arguments: Any?) {
                Log.i(TAG, "auth event stream detached")
                authEventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/auth_platform"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openExternalUrl" -> {
                    val rawUrl = call.argument<String>("url")
                    if (rawUrl.isNullOrBlank()) {
                        result.error("missing_url", "External URL is required", null)
                        return@setMethodCallHandler
                    }

                    startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(rawUrl)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    )
                    result.success(null)
                }
                "consumePendingCallbackLink" -> {
                    val callbackUrl = pendingAuthCallbackUrl
                    Log.i(TAG, "consumePendingCallbackLink callback=$callbackUrl")
                    pendingAuthCallbackUrl = null
                    result.success(callbackUrl)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "s3x/deeplink/events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                s3xEventSink = events
                pendingS3xLink?.let { link -> events?.success(link) }
            }

            override fun onCancel(arguments: Any?) {
                s3xEventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "s3x/deeplink"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingLink" -> {
                    val link = pendingS3xLink
                    pendingS3xLink = null
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/auth_pending_request"
        ).setMethodCallHandler { call, result ->
            val sharedPreferences = getSecurePreferences("auth_pending_request")

            when (call.method) {
                "getPendingRequest" -> {
                    val provider = sharedPreferences.getString("provider", null)
                    val state = sharedPreferences.getString("state", null)
                    if (provider.isNullOrBlank() || state.isNullOrBlank()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    result.success(
                        mapOf(
                            "provider" to provider,
                            "state" to state,
                        )
                    )
                }
                "setPendingRequest" -> {
                    val provider = call.argument<String>("provider")
                    val state = call.argument<String>("state")
                    sharedPreferences.edit()
                        .putString("provider", provider?.trim())
                        .putString("state", state?.trim())
                        .apply()
                    result.success(null)
                }
                "clearPendingRequest" -> {
                    sharedPreferences.edit().clear().apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/purchase_pending_request"
        ).setMethodCallHandler { call, result ->
            val sharedPreferences = getSecurePreferences("purchase_pending_request")

            when (call.method) {
                "getPendingPurchase" -> {
                    val tariffId = sharedPreferences.getInt("tariff_id", 0)
                    val periodDays = sharedPreferences.getInt("period_days", 0)
                    val createdAtMillis = sharedPreferences.getLong("created_at_millis", 0L)
                    val hasDeviceLimit = sharedPreferences.contains("device_limit")
                    if (tariffId <= 0 || periodDays <= 0 || createdAtMillis <= 0L) {
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    result.success(
                        mapOf(
                            "tariffId" to tariffId,
                            "periodDays" to periodDays,
                            "deviceLimit" to if (hasDeviceLimit) {
                                sharedPreferences.getInt("device_limit", 0)
                            } else {
                                null
                            },
                            "createdAtMillis" to createdAtMillis,
                        )
                    )
                }
                "setPendingPurchase" -> {
                    val tariffId = call.argument<Int>("tariffId") ?: 0
                    val periodDays = call.argument<Int>("periodDays") ?: 0
                    val deviceLimit = call.argument<Int>("deviceLimit")
                    val createdAtMillis = call.argument<Number>("createdAtMillis")?.toLong() ?: 0L

                    sharedPreferences.edit()
                        .putInt("tariff_id", tariffId)
                        .putInt("period_days", periodDays)
                        .putLong("created_at_millis", createdAtMillis)
                        .apply {
                            if (deviceLimit != null) {
                                putInt("device_limit", deviceLimit)
                            } else {
                                remove("device_limit")
                            }
                        }
                        .apply()
                    result.success(null)
                }
                "clearPendingPurchase" -> {
                    sharedPreferences.edit().clear().apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/subscription_device"
        ).setMethodCallHandler { call, result ->
            if (call.method != "getHeaders") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val androidId = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ANDROID_ID
            ).orEmpty()

            val manufacturer = Build.MANUFACTURER.orEmpty().trim()
            val model = Build.MODEL.orEmpty().trim()
            val deviceModel = listOf(manufacturer, model)
                .filter { it.isNotEmpty() }
                .joinToString(" ")
                .ifEmpty { "Android device" }

            result.success(
                mapOf(
                    "hwid" to androidId,
                    "deviceOs" to "Android",
                    "osVersion" to (Build.VERSION.RELEASE ?: Build.VERSION.SDK_INT.toString()),
                    "deviceModel" to deviceModel,
                )
            )
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/split_tunnel"
        ).setMethodCallHandler { call, result ->
            val sharedPreferences = getSecurePreferences("split_tunnel_prefs")

            when (call.method) {
                "listApps" -> {
                    val packageManager = packageManager
                    val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_LAUNCHER)
                    }
                    val resolveInfos = packageManager.queryIntentActivities(
                        launcherIntent,
                        PackageManager.MATCH_ALL
                    )

                    val apps = resolveInfos
                        .asSequence()
                        .mapNotNull { resolveInfo ->
                            val appInfo = resolveInfo.activityInfo?.applicationInfo ?: return@mapNotNull null
                            if (appInfo.packageName == packageName) {
                                return@mapNotNull null
                            }
                            val isSystemApp =
                                (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                            mapOf(
                                "packageName" to appInfo.packageName,
                                "label" to resolveInfo.loadLabel(packageManager).toString(),
                                "isSystemApp" to isSystemApp
                            )
                        }
                        .distinctBy { it["packageName"].toString() }
                        .sortedBy { it["label"].toString().lowercase() }
                        .toList()

                    result.success(apps)
                }
                "getBlockedApps" -> {
                    val blockedApps = sharedPreferences
                        .getStringSet("blocked_apps", emptySet())
                        ?.toList()
                        ?: emptyList()
                    result.success(blockedApps)
                }
                "setBlockedApps" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    sharedPreferences.edit()
                        .putStringSet("blocked_apps", packages.toSet())
                        .apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/app_preferences"
        ).setMethodCallHandler { call, result ->
            val sharedPreferences = getSecurePreferences("app_preferences")

            when (call.method) {
                "getLastImportLink" -> {
                    result.success(sharedPreferences.getString("last_import_link", null))
                }
                "setLastImportLink" -> {
                    val link = call.argument<String>("link")
                    sharedPreferences.edit()
                        .putString("last_import_link", link?.trim())
                        .apply()
                    result.success(null)
                }
                "getGuestModeEnabled" -> {
                    result.success(sharedPreferences.getBoolean("guest_mode_enabled", false))
                }
                "setGuestModeEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    sharedPreferences.edit()
                        .putBoolean("guest_mode_enabled", enabled)
                        .apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/cabinet_session"
        ).setMethodCallHandler { call, result ->
            val sharedPreferences = getSecurePreferences("cabinet_session")

            when (call.method) {
                "getSession" -> {
                    val accessToken = sharedPreferences.getString("access_token", null)
                    val refreshToken = sharedPreferences.getString("refresh_token", null)
                    val tokenType = sharedPreferences.getString("token_type", "bearer")
                    val expiresAt = sharedPreferences.getString("expires_at", null)

                    if (accessToken.isNullOrBlank() ||
                        refreshToken.isNullOrBlank() ||
                        expiresAt.isNullOrBlank()
                    ) {
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    result.success(
                        mapOf(
                            "accessToken" to accessToken,
                            "refreshToken" to refreshToken,
                            "tokenType" to tokenType,
                            "expiresAt" to expiresAt,
                        )
                    )
                }
                "setSession" -> {
                    val accessToken = call.argument<String>("accessToken")
                    val refreshToken = call.argument<String>("refreshToken")
                    val tokenType = call.argument<String>("tokenType")
                    val expiresAt = call.argument<String>("expiresAt")

                    sharedPreferences.edit()
                        .putString("access_token", accessToken?.trim())
                        .putString("refresh_token", refreshToken?.trim())
                        .putString("token_type", tokenType?.trim())
                        .putString("expires_at", expiresAt?.trim())
                        .apply()
                    result.success(null)
                }
                "clearSession" -> {
                    sharedPreferences.edit().clear().apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/notifications"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 1000
                    val title = call.argument<String>("title") ?: "Samurai Service"
                    val body = call.argument<String>("body") ?: ""
                    result.success(showLocalNotification(id, title, body))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stockvpn/app_update"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppInfo" -> {
                    val packageInfo = packageManager.getPackageInfo(packageName, 0)
                    val versionCode =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageInfo.longVersionCode.toInt()
                        } else {
                            @Suppress("DEPRECATION")
                            packageInfo.versionCode
                        }

                    result.success(
                        mapOf(
                            "packageName" to packageName,
                            "versionName" to (packageInfo.versionName ?: ""),
                            "versionCode" to versionCode
                        )
                    )
                }
                "getUpdateDirectory" -> {
                    val updateDirectory = File(cacheDir, "updates")
                    if (!updateDirectory.exists()) {
                        updateDirectory.mkdirs()
                    }
                    result.success(updateDirectory.absolutePath)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("missing_path", "APK path is required", null)
                        return@setMethodCallHandler
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        val settingsIntent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(settingsIntent)
                        result.success("permission_required")
                        return@setMethodCallHandler
                    }

                    val apkFile = File(path)
                    if (!apkFile.exists() || !apkFile.isFile) {
                        result.error("missing_apk", "APK file was not found", null)
                        return@setMethodCallHandler
                    }
                    val apkUri = FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        apkFile
                    )
                    val installIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(
                            apkUri,
                            "application/vnd.android.package-archive"
                        )
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }

                    startActivity(installIntent)
                    result.success("install_started")
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun showLocalNotification(id: Int, title: String, body: String): Boolean {
        val channelId = "samurai_service_status"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Samurai Service",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Subscription and update notifications"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7001)
            return false
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        getSystemService(NotificationManager::class.java).notify(id, notification)
        return true
    }

    private fun getSecurePreferences(name: String) =
        try {
            val masterKey = MasterKey.Builder(this)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            EncryptedSharedPreferences.create(
                this,
                name,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (_: Exception) {
            getSharedPreferences(name, Context.MODE_PRIVATE)
        }

    private fun extractAuthCallbackUrl(intent: Intent?): String? {
        val data = intent?.data ?: return null
        if (intent.action != Intent.ACTION_VIEW) {
            Log.i(TAG, "reject intent because action=${intent.action} data=${intent.dataString}")
            return null
        }
        if (data.scheme == "ultimteamvpn" || data.scheme == "samuraiservice") {
            if (data.host != "auth" || data.path != "/oauth/callback") {
                Log.i(TAG, "reject custom scheme callback host=${data.host} path=${data.path}")
                return null
            }
            Log.i(TAG, "accept custom scheme callback data=$data")
            return data.toString()
        }
        val supportedHosts = setOf(
            "samuraiservice.live",
            "app.samuraiservice.live",
            "web.ultimteam.ru",
            "pedzeo.ru",
        )
        if (data.scheme != "https" || data.host !in supportedHosts) {
            Log.i(TAG, "reject https callback scheme=${data.scheme} host=${data.host} path=${data.path}")
            return null
        }
        if (data.path != "/auth/oauth/callback") {
            Log.i(TAG, "reject https callback path=${data.path}")
            return null
        }
        Log.i(TAG, "accept https callback data=$data")
        return data.toString()
    }

    private fun extractS3xLink(intent: Intent?): String? {
        val data = intent?.data ?: return null
        if (intent.action != Intent.ACTION_VIEW) {
            return null
        }
        return if (data.scheme == "s3x") data.toString() else null
    }
}
