import 'exceptions.dart';
import 'models.dart';

/// Minimaler, aber RFC-5545-konformer iCal-Parser für die VEVENT-Blöcke eines
/// LSF-iCal-Exports.
///
/// Bewusst dependency-frei und auf das beschränkt, was LSF liefert:
/// Zeilen-Unfolding, VEVENT-Erkennung, Properties mit Parametern, Text-
/// Unescaping und Datums-/Zeit-Parsing (UTC `Z`, floating, `VALUE=DATE`).
class ICalParser {
  /// Parst den kompletten iCal-Text in eine Liste von Events.
  static List<ICalEvent> parse(String source) {
    if (!source.contains('BEGIN:VCALENDAR') &&
        !source.contains('BEGIN:VEVENT')) {
      throw LsfParseException('Kein gültiger iCal-Inhalt (kein BEGIN:VEVENT).');
    }

    final lines = _unfold(source);
    final events = <ICalEvent>[];

    var inEvent = false;
    Map<String, _Property> current = {};

    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        current = {};
        continue;
      }
      if (line == 'END:VEVENT') {
        inEvent = false;
        events.add(_buildEvent(current));
        continue;
      }
      if (!inEvent) continue;

      final prop = _Property.parse(line);
      if (prop != null) {
        // Bei mehrfachen gleichen Properties zählt die erste.
        current.putIfAbsent(prop.name, () => prop);
      }
    }

    return events;
  }

  /// RFC 5545 Zeilen-Unfolding: Eine Folgezeile beginnt mit einem einzelnen
  /// Whitespace (Space oder Tab); dieses wird entfernt und der Rest an die
  /// vorherige Zeile angehängt.
  static List<String> _unfold(String source) {
    final raw = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <String>[];
    for (final line in raw) {
      if (line.isEmpty) continue;
      if ((line.startsWith(' ') || line.startsWith('\t')) && out.isNotEmpty) {
        out[out.length - 1] = out.last + line.substring(1);
      } else {
        out.add(line);
      }
    }
    return out;
  }

  static ICalEvent _buildEvent(Map<String, _Property> props) {
    return ICalEvent(
      uid: props['UID']?.value,
      summary: _text(props['SUMMARY']),
      location: _text(props['LOCATION']),
      description: _text(props['DESCRIPTION']),
      start: _date(props['DTSTART']),
      end: _date(props['DTEND']),
      rrule: props['RRULE']?.value,
    );
  }

  static String? _text(_Property? p) =>
      p == null ? null : unescapeText(p.value);

  static ICalDateTime? _date(_Property? p) =>
      p == null ? null : parseICalDate(p.value, params: p.params);
}

/// Eine geparste iCal-Property: Name, Parameter und (roher) Wert.
class _Property {
  _Property(this.name, this.params, this.value);

  final String name;
  final Map<String, String> params;
  final String value;

  static _Property? parse(String line) {
    final colon = line.indexOf(':');
    if (colon < 0) return null;

    final left = line.substring(0, colon);
    final value = line.substring(colon + 1);

    final segments = left.split(';');
    final name = segments.first.toUpperCase();
    final params = <String, String>{};
    for (var i = 1; i < segments.length; i++) {
      final eq = segments[i].indexOf('=');
      if (eq > 0) {
        params[segments[i].substring(0, eq).toUpperCase()] =
            segments[i].substring(eq + 1);
      }
    }
    return _Property(name, params, value);
  }
}

/// Hebt iCal-TEXT-Escapes auf: `\\`, `\,`, `\;`, `\n`/`\N`.
String unescapeText(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    if (ch == r'\' && i + 1 < input.length) {
      final next = input[i + 1];
      switch (next) {
        case 'n':
        case 'N':
          buffer.write('\n');
        case ',':
          buffer.write(',');
        case ';':
          buffer.write(';');
        case r'\':
          buffer.write(r'\');
        default:
          buffer.write(next);
      }
      i++;
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

/// Parst einen iCal-Datums-/Zeitwert.
///
/// Unterstützt:
/// * `YYYYMMDDTHHMMSSZ`  → UTC
/// * `YYYYMMDDTHHMMSS`   → floating (lokal, ggf. mit `TZID`-Parameter)
/// * `YYYYMMDD`          → reines Datum (`VALUE=DATE`)
ICalDateTime parseICalDate(String value, {Map<String, String> params = const {}}) {
  final tzid = params['TZID'];
  final isDateValue = params['VALUE']?.toUpperCase() == 'DATE';

  final dateOnly = RegExp(r'^\d{8}$');
  final utc = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$');
  final local = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$');

  if (isDateValue || dateOnly.hasMatch(value)) {
    final y = int.parse(value.substring(0, 4));
    final m = int.parse(value.substring(4, 6));
    final d = int.parse(value.substring(6, 8));
    return ICalDateTime(DateTime(y, m, d), dateOnly: true, tzid: tzid);
  }

  final mu = utc.firstMatch(value);
  if (mu != null) {
    final p = mu.groups([1, 2, 3, 4, 5, 6]).map((g) => int.parse(g!)).toList();
    return ICalDateTime(
      DateTime.utc(p[0], p[1], p[2], p[3], p[4], p[5]),
      isUtc: true,
      tzid: tzid,
    );
  }

  final ml = local.firstMatch(value);
  if (ml != null) {
    final p = ml.groups([1, 2, 3, 4, 5, 6]).map((g) => int.parse(g!)).toList();
    return ICalDateTime(
      DateTime(p[0], p[1], p[2], p[3], p[4], p[5]),
      tzid: tzid,
    );
  }

  throw LsfParseException('Unbekanntes iCal-Datumsformat: "$value"');
}
