# Campus-Planer (Inoffiziell)

> ⚠️ **Unabhängiges Projekt:** Dieses ist ein privates, inoffizielles Projekt ohne offizielle Verbindung zur Hochschule für Technik und Wirtschaft Berlin (HTW Berlin) oder stw.berlin. Es wird weder von der HTW Berlin noch von stw.berlin autorisiert, unterstützt oder verwaltet.

Plattformübergreifende Stundenplan-App für die **HTW Berlin** (LSF / QIS).
Nach dem Login wird der persönliche Stundenplan angezeigt und im Hintergrund
regelmäßig aktualisiert – mit Benachrichtigung bei Änderungen.

> **Status:** Datenschicht (`packages/lsf_client`) ist implementiert und
> **getestet** (48 Unit-Tests, Analyzer sauber). Die Flutter-App (`app/`) ist
> ein lauffähiges Gerüst, dem noch die generierten Plattform-Ordner fehlen
> (siehe [Setup](#setup--build)).

---

## Warum eine eigene Implementierung statt Reverse-Engineering der vorhandenen App?

Das LSF ist ein **server-gerendertes, session-basiertes Web-System (HIS/QIS)** –
es gibt **keine versteckte/geheime API** zu entdecken. Jede App, die mit dem LSF
spricht, kann nur eines von zwei Dingen tun:

1. **HTML scrapen** mit Session-Cookie, oder
2. den **iCal-Export** nutzen.

Die vorhandene (schlechte) App macht zwangsläufig genau dasselbe. Ihren APK zu
dekompilieren würde dieselben Endpunkte bestätigen, aber keine bessere
Schnittstelle liefern – die existiert serverseitig nicht. Deshalb: **selbst
sauber implementieren** statt reverse-engineeren. Der eigentliche Aufwand liegt
nicht im „API finden", sondern im robusten Login (verschleiertes Formular) und
im stabilen Parsen – beides ist hier gelöst und getestet.

---

## Architektur

Monorepo mit klarer Trennung zwischen plattformunabhängiger Logik und UI:

```
htw_center/
├── packages/
│   └── lsf_client/        # Reines Dart: Login, Scraping, iCal-Parsing (getestet)
│       ├── lib/src/
│       │   ├── endpoints.dart        # Alle LSF-URLs (reverse-engineert)
│       │   ├── transport.dart        # HTTP + Cookie-Jar + Redirects
│       │   ├── login.dart            # Verschleiertes Login-Formular
│       │   ├── harvest.dart          # termine-/asi-/publishid-Extraktion
│       │   ├── ical.dart             # RFC-5545 iCal-Parser  ← goldener Pfad
│       │   ├── timetable_html.dart   # HTML-Listen-Parser (Best-Effort)
│       │   └── lsf_client_base.dart  # High-Level-Client
│       ├── example/                  # fetch_timetable.dart – CLI zum Live-Test
│       └── test/                     # 48 Unit-Tests gegen Fixtures
└── app/                   # Flutter-App (Android, iOS, Windows, macOS, Linux)
    └── lib/src/
        ├── services/      # CredentialStore, LsfRepository, Background, Notifications
        ├── state/         # TimetableController
        └── ui/            # Login- & Stundenplan-Screen
```

**Datenfluss:** `app` → `LsfRepository` → `LsfClient` (login → iCal-Export →
`ICalParser`) → typisierte `ICalEvent`-Liste → UI.

### Warum „Client-only" (kein Backend)?

Die Zugangsdaten bleiben **verschlüsselt auf dem Gerät** und werden nur für den
Login verwendet. Es gibt **keinen Server**, der Daten speichert. Ein Backend-
Proxy würde HTW-Zugangsdaten anderer Studierender speichern müssen – ein
ernstes Sicherheits- und Haftungsrisiko. Die sauberste Infrastruktur ist hier
keine.

---

## Plattform-Matrix

| Plattform | Artefakt | Build | Background-Refresh |
|---|---|---|---|
| Android | `.apk` / `.aab` | `flutter build apk` | WorkManager (~15 min) ✅ |
| Linux (Ubuntu) | Bundle → `.deb` | `flutter build linux` | systemd-Timer / In-App |
| Windows | `.exe` | `flutter build windows` | Scheduled Task / In-App |
| macOS | `.app` / `.dmg` | `flutter build macos` | In-App / launchd |
| iOS (iPhone) | TestFlight / App Store | `flutter build ios` | BGTaskScheduler (Best-Effort) ⚠️ |

**iOS-Realität:** Es gibt kein „lose verteilbares" Pendant zu APK/.deb/.exe.
Verteilung läuft über **TestFlight oder App Store** (Apple Developer Account,
99 $/Jahr). Hintergrund-Refresh entscheidet das OS – keine festen Intervalle.

---

## Setup & Build

### Voraussetzungen
- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.24 (bringt Dart mit)

### 1. Datenschicht testen (reines Dart, schnell)
```bash
cd packages/lsf_client
dart pub get
dart test          # 48 Tests
dart analyze
```

### 2. App vorbereiten
Die nativen Plattform-Ordner (`android/`, `ios/`, `linux/`, `macos/`,
`windows/`) werden **einmalig generiert** und dann eingecheckt:
```bash
cd app
flutter create .          # erzeugt die Plattform-Ordner um die lib/ herum
flutter pub get
```

### 3. App bauen / starten
```bash
flutter run                        # Debug auf angeschlossenem Gerät/Desktop
flutter build apk --release        # Android
flutter build linux --release      # Linux (danach .deb-Verpackung, s.u.)
flutter build windows --release    # Windows
flutter build macos --release      # macOS
flutter build ios --release        # iOS (Signierung nötig)
```
**CI-Workflows:**
- `ci.yml` – testet die Datenschicht (Dart) bei jedem Push/PR.
- `pr-build.yml` – baut bei **jedem Pull Request** APK, `.deb` und Windows-Build
  als herunterladbare Artefakte (siehe unten).
- `build.yml` – Release-Build aller fünf Plattformen (Tag `v*` oder manuell).

### Test-Builds bei jedem Pull Request herunterladen
`pr-build.yml` erzeugt bei jedem PR drei Artefakte. So testest du sie:
1. PR öffnen → Reiter **Checks** (bzw. **Actions** → der „PR-Builds"-Lauf).
2. Unten unter **Artifacts**: `htw-center-apk`, `htw-center-deb` oder
   `htw-center-windows` herunterladen (GitHub liefert sie als ZIP).
3. APK auf Android sideloaden · `.deb` via `sudo dpkg -i …` installieren ·
   Windows-ZIP entpacken und `htw_center.exe` starten.

> Die nativen Plattform-Ordner werden in CI per `flutter create` erzeugt; für
> Android macht `tools/ci/enable_android_desugaring.sh` den
> `flutter_local_notifications`-Build lauffähig. Sobald du die Plattform-Ordner
> einmal lokal erzeugst und committest, kannst du diese Schritte entfernen.

### .deb aus dem Linux-Bundle
`flutter build linux` erzeugt ein Bundle; das mitgelieferte Skript verpackt es
als `.deb`:
```bash
cd app && flutter build linux --release && cd ..
bash packaging/linux/build_deb.sh 0.1.0 amd64   # -> build/deb/htw-center_0.1.0_amd64.deb
```
Das Skript (`packaging/linux/`) installiert nach `/opt/htw-center`, legt einen
`/usr/bin`-Launcher und einen Desktop-Eintrag an. In CI (`build.yml`) läuft es
automatisch.

---

## Hintergrund-Aktualisierung

Implementiert via `workmanager` (`app/lib/src/services/background_refresh.dart`):
periodischer Task → Login → iCal holen → **Hash-Vergleich** mit dem letzten
Stand → bei Änderung **lokale Benachrichtigung**.

- **Android:** zuverlässig, Minimum ~15 min.
- **iOS:** `BGAppRefreshTask`, vom OS gedrosselt (oft 1–2×/Tag). Daher zusätzlich
  beim App-Start aktualisieren.
- **Desktop:** während die App läuft; optional systemd-Timer/Scheduled Task.

---

## Sicherheit & Datenschutz

- Zugangsdaten via `flutter_secure_storage` (Keychain/Keystore/libsecret/DPAPI).
- Kein Server, keine Telemetrie, keine Weitergabe an Dritte.
- TLS direkt zur HTW; Session-Cookie nur im Speicher.

---

## Reverse-engineerte LSF-API (Kurzreferenz)

Basis: `https://lsf.htw-berlin.de/qisserver/rds` – alles über Query-Parameter.
Vollständig abgebildet in [`endpoints.dart`](packages/lsf_client/lib/src/endpoints.dart).

| Zweck | Parameter |
|---|---|
| Login-Seite | `?state=user&type=1` |
| Login | `POST` mit Formularfeldern (User-/Passwortfeld verschleiert) |
| Stundenplan (Liste) | `?state=wplan&show=liste&P.vx=lang&P.subc=plan&act=show[&week=KW_YYYY]` |
| Stundenplan (Plan) | `?state=wplan&show=plan&P.subc=plan&P.vx=mittel` |
| **iCal-Export** | `?state=verpublish&status=transform&termine=ID,ID&moduleCall=iCalendarPlan&publishConfFile=reports&publishSubDir=veranstaltung` |
| Semesterwechsel | `?state=user&type=0&k_semester.semid=20261&…` |
| Logout | `?state=user&type=4&re=last&category=auth.logout` |

Details siehe `docs/` bzw. die Dokumentation im Quellcode.

---

## Offene Punkte / TODO

- [ ] **HTML-Listen-Parser gegen echtes LSF-HTML validieren.** `parseLessonBlock`
      ist gegen reale Textblöcke getestet; die DOM-Extraktion (`parseTimetable`)
      braucht eine Probe der echten `show=liste`-Seite. Der iCal-Pfad ist die
      zuverlässige Hauptquelle. Live testen mit dem CLI:
      `LSF_USER=… LSF_PASS=… dart run example/fetch_timetable.dart [KW_JAHR]`.
- [ ] **Stabile iCal-Abo-URL prüfen:** Falls das HTW-LSF eine tokenisierte
      Kalender-Abo-URL anbietet, könnte man darauf umstellen (kein Login je
      Abruf nötig).
- [x] Wochen-Navigation (`CalendarWeek`) in der UI. ✅
- [ ] Volle TZID-Umrechnung via `package:timezone` (UTC→lokal ist bereits erledigt).
- [ ] iOS-Signierung + TestFlight-Pipeline.
- [ ] App-Icons & Splash.

> **Hinweis für Claude Code on the web:** Outbound-Zugriff auf
> `lsf.htw-berlin.de` ist in der Standard-Netzwerk-Policy geblockt. Für Live-
> Tests gegen den echten Server den Host in der
> [Netzwerk-Policy](https://code.claude.com/docs/en/claude-code-on-the-web)
> der Umgebung freischalten oder lokal testen.

---

## Nutzungshinweise

Bitte nutze die App nur mit deinen **eigenen** Zugangsdaten für deinen **eigenen** Stundenplan. Respektiere die Nutzungsbedingungen der HTW Berlin und vermeide unnötige Last (keine parallelen Massen-Requests).
