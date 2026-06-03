import 'package:meta/meta.dart' show immutable;

/// Ein Semester im LSF-Schema `YYYYS` (`1` = Sommer, `2` = Winter).
///
/// Beispiele: `20261` = SS 2026, `20252` = WS 2025/26.
@immutable
class Semester {
  const Semester(this.id);

  /// Roh-ID, z.B. `"20261"`.
  final String id;

  int get year => int.parse(id.substring(0, 4));

  /// `true` = Sommersemester, `false` = Wintersemester.
  bool get isSummer => id.endsWith('1');

  /// Menschlich lesbares Label, z.B. `"SS 2026"` oder `"WS 2025/26"`.
  String get label {
    if (isSummer) return 'SS $year';
    final next = (year + 1) % 100;
    return 'WS $year/${next.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) => other is Semester && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Semester($id, $label)';
}

/// Eine Kalenderwoche im LSF-Format `KW_YYYY` (z.B. `23_2026`).
@immutable
class CalendarWeek {
  const CalendarWeek(this.week, this.year);

  factory CalendarWeek.parse(String value) {
    final parts = value.split('_');
    if (parts.length != 2) {
      throw FormatException('Ungültiges Wochenformat: $value');
    }
    return CalendarWeek(int.parse(parts[0]), int.parse(parts[1]));
  }

  final int week;
  final int year;

  /// LSF-Parameterwert, z.B. `"23_2026"`.
  String get param => '${week}_$year';

  @override
  bool operator ==(Object other) =>
      other is CalendarWeek && other.week == week && other.year == year;

  @override
  int get hashCode => Object.hash(week, year);

  @override
  String toString() => 'CalendarWeek($param)';
}

/// Eine einzelne Veranstaltung aus der HTML-Listenansicht (`show=liste`).
///
/// Nicht alle Felder sind immer vorhanden – LSF liefert je nach Veranstaltung
/// unterschiedlich viel. Felder, die nicht erkannt wurden, sind `null`.
@immutable
class Lesson {
  const Lesson({
    required this.title,
    this.courseNumber,
    this.type,
    this.sws,
    this.day,
    this.startTime,
    this.endTime,
    this.rhythm,
    this.room,
    this.lecturer,
    this.language,
    this.publishId,
  });

  /// Voller Titel, z.B. `"K12 Mathematik 2 (SL)"`.
  final String title;

  /// Veranstaltungsnummer / Modulkürzel, z.B. `"K12"`.
  final String? courseNumber;

  /// Veranstaltungstyp, z.B. `"SL"`, `"PCÜ"`, `"PS"`, `"LPr"`.
  final String? type;

  /// Semesterwochenstunden.
  final int? sws;

  /// Wochentag (`"Montag"` … `"Freitag"`).
  final String? day;

  /// Startzeit, z.B. `"09:45"`.
  final String? startTime;

  /// Endzeit, z.B. `"11:15"`.
  final String? endTime;

  /// Rhythmus, z.B. `"wöch"`, `"14tägl"`.
  final String? rhythm;

  /// Raum, z.B. `"WH C 351"`.
  final String? room;

  /// Dozent:in.
  final String? lecturer;

  /// Unterrichtssprache, z.B. `"deutsch"`.
  final String? language;

  /// Veranstaltungs-ID für Detailaufrufe (`publishid`).
  final String? publishId;

  @override
  String toString() =>
      'Lesson($title, $day $startTime-$endTime, $room, $rhythm)';
}

/// Datum/Zeit aus einem iCal-Feld, inkl. Metainformationen zur Interpretation.
@immutable
class ICalDateTime {
  const ICalDateTime(
    this.value, {
    this.isUtc = false,
    this.dateOnly = false,
    this.tzid,
  });

  /// Geparster Zeitwert. Bei [isUtc] ein UTC-`DateTime`, sonst „floating"
  /// (lokale Wandzeit ohne Zeitzonenumrechnung).
  final DateTime value;

  /// `true`, wenn der Wert ein `Z`-Suffix hatte (UTC).
  final bool isUtc;

  /// `true` für reine Datumswerte (`VALUE=DATE`, `YYYYMMDD`).
  final bool dateOnly;

  /// Optionaler TZID-Parameter, z.B. `"Europe/Berlin"`. Es findet KEINE
  /// automatische Zeitzonenumrechnung statt – das übernimmt die App-Schicht
  /// (z.B. via `package:timezone`).
  final String? tzid;

  @override
  String toString() =>
      'ICalDateTime($value${isUtc ? 'Z' : ''}${tzid != null ? ' [$tzid]' : ''})';
}

/// Ein VEVENT aus einem iCal-Export – der „goldene Pfad" für Stundenplandaten.
@immutable
class ICalEvent {
  const ICalEvent({
    this.uid,
    this.summary,
    this.location,
    this.description,
    this.start,
    this.end,
    this.rrule,
  });

  final String? uid;
  final String? summary;
  final String? location;
  final String? description;
  final ICalDateTime? start;
  final ICalDateTime? end;

  /// Roher RRULE-Wert (Wiederholungsregel), falls vorhanden.
  final String? rrule;

  @override
  String toString() => 'ICalEvent($summary, $start → $end, $location)';
}
