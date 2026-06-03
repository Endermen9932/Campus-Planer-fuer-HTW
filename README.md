# HTW Center

Plattformübergreifende Stundenplan-App für die **HTW Berlin** (LSF / QIS).
Nach dem Login wird der persönliche Stundenplan angezeigt und im Hintergrund
regelmäßig aktualisiert – mit Benachrichtigung bei Änderungen.

> **Status:** Datenschicht (`packages/lsf_client`) ist implementiert und
> **getestet** (33 Unit-Tests, Analyzer sauber). Die Flutter-App (`app/`) ist
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
│       └── test/                     # 33 Unit-Tests gegen Fixtures
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
dart test          # 33 Tests
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
CI (`.github/workflows/build.yml`) baut alle fünf Plattformen automatisch.

### .deb aus dem Linux-Bundle
`flutter build linux` erzeugt ein Bundle unter
`build/linux/x64/release/bundle/`. Daraus ein `.deb` z.B. mit
[`flutter_to_debian`](https://pub.dev/packages/flutter_to_debian) oder einem
eigenen `DEBIAN/control` + `dpkg-deb --build`.

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
      zuverlässige Hauptquelle.
- [ ] **Stabile iCal-Abo-URL prüfen:** Falls das HTW-LSF eine tokenisierte
      Kalender-Abo-URL anbietet, könnte man darauf umstellen (kein Login je
      Abruf nötig).
- [ ] Wochen-Navigation (`CalendarWeek`) in der UI.
- [ ] Zeitzonen-Handling für iCal (`package:timezone`) statt floating local.
- [ ] iOS-Signierung + TestFlight-Pipeline.
- [ ] App-Icons & Splash.

> **Hinweis für Claude Code on the web:** Outbound-Zugriff auf
> `lsf.htw-berlin.de` ist in der Standard-Netzwerk-Policy geblockt. Für Live-
> Tests gegen den echten Server den Host in der
> [Netzwerk-Policy](https://code.claude.com/docs/en/claude-code-on-the-web)
> der Umgebung freischalten oder lokal testen.

---

## Rechtliches

Inoffizielles, privates Projekt – keine Verbindung zur HTW Berlin. Nutzung mit
den **eigenen** Zugangsdaten für den **eigenen** Stundenplan. Bitte respektiere
die Nutzungsbedingungen der HTW und vermeide unnötige Last (keine parallelen
Massen-Requests).
