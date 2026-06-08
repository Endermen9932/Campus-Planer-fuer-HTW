# Campus-Planer HTW – Projekthinweise für Claude

## Android-Version vor jedem Release erhöhen

Vor jedem APK-Build (manuell oder per Workflow-Dispatch) muss der `versionCode` in `app/pubspec.yaml` erhöht werden:

```
version: X.Y.Z+<versionCode>
```

- `versionCode` (die Zahl nach `+`) muss **immer größer** sein als die zuletzt installierte Version auf Android-Geräten.
- `versionName` (der Teil vor `+`) nach Bedarf anpassen.
- Beispiel: `0.1.0+4` → `0.1.0+5`

Android blockiert sonst die Installation mit `INSTALL_FAILED_VERSION_DOWNGRADE`.

## Android-Signierung

APKs werden mit dem **Android Debug Key** signiert (kein Keystore nötig).
`build_apk_release.yml` setzt bewusst keinen Keystore ein – `build.gradle.kts`
greift automatisch auf `signingConfigs.getByName("debug")` zurück.

## APK-Verteilung: immer GitHub Releases, nie Artifacts

APKs werden **ausschließlich** über **GitHub Releases** veröffentlicht (`softprops/action-gh-release`).
`actions/upload-artifact` darf für APKs **niemals** verwendet werden – das Artifact-Storage-Kontingent
ist begrenzt und läuft schnell voll. Der `build_apk_release.yml`-Workflow veröffentlicht die fertige
APK direkt als GitHub Release ohne Zwischenspeicherung als Artifact.
