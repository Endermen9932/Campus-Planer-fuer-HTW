# lsf_client

Plattformunabhängige Dart-Client-Bibliothek für das **HTW-Berlin-LSF**
(HIS/QIS-Server). Reines Dart, ohne Flutter – nutzbar in App, CLI und Tests.

## Funktionen

- **Login** mit dem verschleierten LSF-Formular (Felder werden über ihren
  `type` erkannt, nicht über den Namen → robust gegen `asdf`/`fdsa`-Tricks).
- **Session-Handling** mit Cookie-Jar und manuellem Redirect-Following
  (JSESSIONID bleibt über den Login-POST-Redirect erhalten).
- **iCal-Export** abrufen und parsen (RFC 5545) – der stabile „goldene Pfad"
  für Stundenplandaten.
- **HTML-Parser** für die Listenansicht (Best-Effort; iCal bevorzugen).
- **Harvesting** von `termine`-/`asi`-/`publishid`-Werten aus LSF-HTML.
- **Kalenderwochen** im LSF-Format (`23_2026`) inkl. ISO-8601-Berechnung.

## Schnellstart

```dart
import 'package:lsf_client/lsf_client.dart';

final client = LsfClient();
await client.login('s0500001', 'geheim');

// Goldener Pfad: geparste iCal-Events der aktuellen Woche
final events = await client.fetchICalEvents();
for (final e in events) {
  print('${e.start?.value}  ${e.summary}  (${e.location})');
}

// Bestimmte Woche
final next = await client.fetchICalEvents(week: CalendarWeek.current().next);

client.close();
```

## Live-Test gegen das echte LSF

```bash
LSF_USER=dein-login LSF_PASS=dein-passwort \
  dart run example/fetch_timetable.dart 23_2026
```

## Entwicklung

```bash
dart pub get
dart test       # 41 Unit-Tests gegen Fixtures
dart analyze
```

## Architektur

| Datei | Zweck |
|---|---|
| `endpoints.dart` | Alle LSF-URLs (reverse-engineerte Query-Parameter) |
| `transport.dart` | HTTP + Cookie-Jar + Redirect-Following (`dart:io`) |
| `login.dart` | Verschleiertes Login-Formular parsen/absenden |
| `harvest.dart` | `termine`/`asi`/`publishid` aus HTML extrahieren |
| `ical.dart` | RFC-5545-iCal-Parser |
| `timetable_html.dart` | HTML-Listen-Parser (Best-Effort) |
| `lsf_client_base.dart` | High-Level-`LsfClient` |

> Hinweis: Der HTML-Parser ist gegen reale Textblöcke getestet, die
> DOM-Extraktion aber noch gegen echtes `show=liste`-HTML zu validieren. Der
> iCal-Pfad ist die zuverlässige Hauptquelle.
