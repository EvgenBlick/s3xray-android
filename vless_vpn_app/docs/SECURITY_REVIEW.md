# Security Review

Дата: 2026-04-09

## Закрыто

- `release` сборка больше не использует debug signing config.
- Release APK подписывается отдельным keystore через `android/key.properties`.
- In-app update manifest теперь принимает только `https://` URL.
- APK update теперь требует `checksumSha256` и проверяет SHA-256 после скачивания.
- Последняя импортированная ссылка и split-tunnel настройки переведены на `EncryptedSharedPreferences` с fallback только на случай platform failure.
- Android backup выключен через `allowBackup="false"`, `fullBackupContent="false"` и `dataExtractionRules`.
- Из manifest удален `QUERY_ALL_PACKAGES`; список приложений для split tunneling теперь собирается по launcher apps через package queries.

## Осталось

- Нет certificate pinning для update endpoint `https://pedzeo.ru/updates/latest.json`.
- Fallback с `EncryptedSharedPreferences` на обычный `SharedPreferences` сохраняет совместимость, но оставляет residual risk на устройствах, где encrypted storage недоступен.
- Split tunneling теперь видит только launcher-приложения. Это осознанный tradeoff ради отказа от `QUERY_ALL_PACKAGES`.

## Операционные требования

- Не коммитить `android/key.properties` и `android/app/keystore/`.
- Для каждой публикации обновлять `versionName/versionCode`.
- Для каждой публикации считать SHA-256 собранного APK и записывать его в `ops/update_feed/latest.json`.
- Не публиковать update manifest или APK по `http://`.
