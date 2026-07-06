# S3XRAY Android

Custom Android client workbench for S3XRAY.

The app is currently based on a local Flutter VPN client and a local Android VLESS/Xray plugin. The first milestone is stable `s3x://` import and Xray `fedarisha` runtime over VK Cloud S3. VK TURN mode is planned after the S3 path is verified on a real device.

## Workspace

- `vless_vpn_app/` - Flutter Android app.
- `vendor_flutter_vless/` - Flutter plugin facade.
- `vendor_flutter_vless_android/` - Android runtime bridge for Xray and tun2socks.
- `vendor_flutter_vless_platform_interface/` - plugin platform interface.
- `PLAN.md` - current state and next steps.
- `WORKLOG.md` - chronological implementation notes.

## Build

```powershell
cd C:\Users\admin\Desktop\hlam\ultimteam-mobile-app-main\vless_vpn_app
C:\tools\flutter\bin\flutter.bat pub get
C:\tools\flutter\bin\flutter.bat analyze
C:\tools\flutter\bin\flutter.bat build apk --debug
```

The current build still needs Java 17 selected for Gradle. See `PLAN.md`.

## Secrets

Do not commit real tokens, VPS passwords, Telegram bot tokens, S3 access keys, or generated user configs.
