# S3XRAY Android Plan

## Goal

Build a simplified Android VPN client based on the local Flutter app, with first-class support for S3XRAY `s3x://` imports and Xray `fedarisha` transport over VK Cloud S3.

## Done

- Chosen the local Flutter workspace as the new app base:
  - `vless_vpn_app/`
  - `vendor_flutter_vless/`
  - `vendor_flutter_vless_android/`
  - `vendor_flutter_vless_platform_interface/`
- Installed Flutter SDK at `C:\tools\flutter` for this machine.
- Added Android `s3x://` intent filter.
- Added native Android MethodChannel/EventChannel bridge for incoming `s3x://` deeplinks.
- Added Dart S3X parser:
  - reads `s3x://<base64url-json>`
  - supports `s3x://...?data=` and `s3x://...?config=`
  - converts decoded JSON into runtime Xray config.
- Connected S3X links to the existing import flow:
  - manual paste into import field works
  - Telegram/browser deeplink opens the app and imports the profile
  - existing `connectFromConfig` path starts the runtime JSON config.
- Rebuilt Android `libxray.so` from the patched S3XRAY Xray-core for:
  - `arm64-v8a`
  - `armeabi-v7a`
- Updated Android NDK version to the installed local version: `28.2.13676358`.
- Enabled stderr logging for Xray process output, so fedarisha/S3 startup errors appear in logcat.
- Temporarily bypassed cabinet authorization with `kBypassAuthForS3xTesting = true` in `HomeScreen`.
- Ran `flutter pub get`.
- Ran `flutter analyze`: no compile errors; one existing Flutter deprecation warning remains.

## Current Build Status

Debug APK build is working.

Built APK:

```powershell
C:\Users\admin\Desktop\S3XRAY-Flutter-debug.apk
```

Gradle is pinned to Android Studio JBR in `vless_vpn_app/android/gradle.properties` because the system `java` command points to Java 8.

## Next

- Test:
  - manual `s3x://` import
  - Telegram bot deeplink import
  - VPN start/stop
  - Xray logcat output
  - S3 HeadBucket/DNS behavior
  - download/upload speed through VPS target.
- Rename app/package/labels from the original brand to S3XRAY.
- Change package or uninstall old WINGSV during tests if Android shows an app chooser for `s3x://`.
- Re-enable or fully remove cabinet authorization flow after S3X testing decision.
- Remove unused cabinet/payment/auth UI after the S3X runtime is proven stable.
- Port VK TURN mode from the WINGSV layout as a native helper binary plus Flutter control wrapper.
- Add a non-secret config template for bot-generated `s3x://` payloads.

## Notes

- Do not commit real GitHub tokens, bot tokens, VPS passwords, S3 access keys, or generated user configs.
- S3 credentials should stay in local secret files, CI secrets, or the bot/VPS runtime environment.
