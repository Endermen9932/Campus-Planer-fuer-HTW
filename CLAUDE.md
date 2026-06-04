# Campus-Planer HTW – Projekthinweise für Claude

## Android-Version vor jedem Release erhöhen

Vor jedem APK- oder AAB-Build (manuell, per Tag oder Workflow-Dispatch) muss der `versionCode` in `app/pubspec.yaml` erhöht werden:

```
version: X.Y.Z+<versionCode>
```

- `versionCode` (die Zahl nach `+`) muss **immer größer** sein als die zuletzt installierte Version auf Android-Geräten.
- `versionName` (der Teil vor `+`) nach Bedarf anpassen.
- Beispiel: `0.1.0+4` → `0.1.0+5`

Android blockiert sonst die Installation mit `INSTALL_FAILED_VERSION_DOWNGRADE`.

## Android-Signierung

Alle drei Workflows (`build.yml`, `build_aab.yml`, `build_apk_release.yml`) signieren mit einem persistenten Keystore aus den GitHub Secrets:
- `KEYSTORE_BASE64` – Keystore-Datei als Base64
- `KEY_ALIAS` – Key-Alias
- `KEY_PASSWORD` – Key-Passwort
- `STORE_PASSWORD` – Store-Passwort

Niemals `keytool -genkey` in den Workflows verwenden – das erzeugt bei jedem Build einen neuen Key und bricht Updates.
