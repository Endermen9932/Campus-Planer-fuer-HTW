import 'models.dart';

/// Baut alle LSF-URLs aus den (reverse-engineerten) Query-Parametern.
///
/// Alle Requests gehen an denselben Endpunkt; nur die Query-Parameter steuern
/// das Verhalten. Die Basis-URL ist konfigurierbar, damit Tests gegen einen
/// Mock-Server laufen können.
class LsfEndpoints {
  LsfEndpoints({String baseUrl = defaultBaseUrl}) : base = Uri.parse(baseUrl);

  static const String defaultBaseUrl =
      'https://lsf.htw-berlin.de/qisserver/rds';

  final Uri base;

  Uri _build(Map<String, String> params) =>
      base.replace(queryParameters: params);

  /// Login-Seite (rendert das Formular, das wir parsen).
  Uri loginPage() => _build({'state': 'user', 'type': '1'});

  /// Logout.
  Uri logout() =>
      _build({'state': 'user', 'type': '4', 're': 'last', 'category': 'auth.logout'});

  /// Semesterwechsel.
  Uri switchSemester(Semester semester) => _build({
        'state': 'user',
        'type': '0',
        'k_semester.semid': semester.id,
        'idcol': 'k_semester.semid',
        'idval': semester.id,
        'purge': 'n',
        'getglobal': 'semester',
      });

  /// Stundenplan als Listenansicht (`show=liste&P.vx=lang`) – am besten zu
  /// parsen. Ohne [week] liefert der Server die aktuelle Woche.
  Uri timetableList({CalendarWeek? week}) => _build({
        'state': 'wplan',
        'act': 'show',
        'show': 'liste',
        'P.vx': 'lang',
        'P.subc': 'plan',
        if (week != null) 'week': week.param,
      });

  /// Stundenplan als Kalenderansicht (`show=plan`).
  Uri timetablePlan({CalendarWeek? week}) => _build({
        'state': 'wplan',
        'act': 'show',
        'show': 'plan',
        'P.subc': 'plan',
        'P.vx': 'mittel',
        if (week != null) 'week': week.param,
      });

  /// iCal-Export für eine Menge von Termin-IDs (NICHT Veranstaltungs-IDs!).
  Uri ical(Iterable<String> termineIds) => _build({
        'state': 'verpublish',
        'status': 'transform',
        'vmfile': 'no',
        'termine': termineIds.join(','),
        'moduleCall': 'iCalendarPlan',
        'publishConfFile': 'reports',
        'publishSubDir': 'veranstaltung',
      });

  /// Detailseite einer Veranstaltung.
  Uri eventDetail(String publishId) => _build({
        'state': 'verpublish',
        'status': 'init',
        'vmfile': 'no',
        'publishid': publishId,
        'moduleCall': 'webInfo',
        'publishConfFile': 'webInfo',
        'publishSubDir': 'veranstaltung',
      });
}
