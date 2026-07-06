# S3XRAY Android Worklog

## 2026-07-07

### App integration

- Added `s3x://` Android intent handling in `vless_vpn_app/android/app/src/main/AndroidManifest.xml`.
- Extended `MainActivity.kt` with:
  - pending S3X link storage
  - `s3x/deeplink` MethodChannel
  - `s3x/deeplink/events` EventChannel.
- Added Dart bridge:
  - `vless_vpn_app/lib/features/s3x/application/s3x_deep_link_bridge.dart`
  - `vless_vpn_app/lib/features/s3x/application/s3x_link_parser.dart`
- Updated `ImportLinkResolver` so `s3x://` imports become a runtime-config group.
- Updated `HomeScreen` so pending/incoming S3X deeplinks are imported automatically.

### Xray runtime

- Rebuilt `libxray.so` from the patched S3XRAY/WINGSV Xray-core and copied it into:
  - `vendor_flutter_vless_android/android/src/main/jniLibs/arm64-v8a/libxray.so`
  - `vendor_flutter_vless_android/android/src/main/jniLibs/armeabi-v7a/libxray.so`
- The patched Xray-core includes the VK Cloud S3 DNS fallback for `hb.ru-msk.vkcloud-storage.ru`.
- Updated `XrayCoreManager.kt` to merge stderr into stdout for logcat visibility.

### Build environment

- Installed Flutter SDK into `C:\tools\flutter`.
- Ran `flutter pub get`.
- Ran `dart format` on changed Dart files.
- Ran `flutter analyze`.

### Build blocker

Fixed. Gradle now uses Android Studio JBR via `org.gradle.java.home`.

### APK build

Built debug APK:

```text
C:\Users\admin\Desktop\S3XRAY-Flutter-debug.apk
```

Installed the APK on the connected Android device with adb.

Verified Android `s3x://` activity registration. The device currently has two handlers:

- `com.stockvpn.vless_vpn_app`
- `wings.v`

Android may show an app chooser until the old WINGSV build is removed or the package/scheme strategy is changed.

### Pending verification

- Real S3X deeplink import from Telegram bot.
- VPN runtime start.
- logcat inspection for fedarisha/S3 errors.
- Throughput test.
