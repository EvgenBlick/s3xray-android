# Update Feed

Статический update feed для Android release APK.

Формат:

```json
{
  "versionCode": 6,
  "versionName": "1.1.4",
  "apkUrl": "https://samuraiservice.live/updates/app-release.apk",
  "checksumSha256": "64-char-lowercase-sha256-of-apk",
  "changelog": "Security hardening: release signing, encrypted preferences and verified in-app updates.",
  "publishedAt": "2026-04-08T20:35:00Z"
}
```

Размещение на сервере:

- host path: `/var/www/samurai-updates`
- public URL: `https://samuraiservice.live/updates/latest.json`
- APK URL: `https://samuraiservice.live/updates/app-release.apk`

Минимальный publish flow:

1. Собрать `app-release.apk`.
2. Посчитать SHA-256 для APK.
3. Загрузить APK в `.../miniapp/updates/app-release.apk`.
4. Обновить `latest.json`, включая `checksumSha256`.
4. Проверить:
   - `curl -I https://samuraiservice.live/updates/latest.json`
   - `curl -I https://samuraiservice.live/updates/app-release.apk`
