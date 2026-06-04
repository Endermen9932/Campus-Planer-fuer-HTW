import 'endpoints.dart';
import 'exceptions.dart';
import 'harvest.dart';
import 'ical.dart';
import 'login.dart';
import 'models.dart';
import 'timetable_html.dart';
import 'transport.dart';

/// High-Level-Client für das HTW-LSF.
///
/// Kapselt Login (mit verschleiertem Formular), Stundenplan-Abruf und den
/// iCal-Export. Die Zugangsdaten werden nur für den Login verwendet und nicht
/// gespeichert – die Session lebt im [LsfTransport] (Cookie-Jar).
class LsfClient {
  LsfClient({
    LsfTransport? transport,
    String baseUrl = LsfEndpoints.defaultBaseUrl,
    String proxyBase = '',
  })  : _transport = transport ?? createDefaultTransport(proxyBase: proxyBase),
        _endpoints = LsfEndpoints(baseUrl: baseUrl);

  final LsfTransport _transport;
  final LsfEndpoints _endpoints;

  bool _loggedIn = false;
  String? _asi;

  /// Aktuelles Anti-CSRF-Session-Token (für schreibende Operationen).
  String? get asi => _asi;

  bool get isAuthenticated => _loggedIn;

  /// Loggt sich ein. Wirft [LoginFailedException] bei falschen Zugangsdaten.
  Future<void> login(String username, String password) async {
    final page = await _transport.get(_endpoints.loginPage());
    final form = LoginForm.parse(page.body);
    final body = form.buildBody(username, password);

    final response =
        await _transport.postForm(_resolveAction(form.actionPath), body);
    if (!looksLoggedIn(response.body)) {
      throw LoginFailedException(
        'Login abgelehnt – Benutzername/Passwort prüfen.',
      );
    }
    _loggedIn = true;
    _asi = extractAsi(response.body);
  }

  /// Wechselt das aktive Semester (z.B. `Semester('20261')`).
  Future<void> switchSemester(Semester semester) async {
    _requireAuth();
    await _transport.get(_endpoints.switchSemester(semester));
  }

  /// Holt den Stundenplan über die HTML-Listenansicht und parst ihn.
  ///
  /// Hinweis: HTML-Parsing ist fragiler als iCal – für stabile Daten
  /// [fetchICalEvents] bevorzugen.
  Future<List<Lesson>> fetchTimetable({CalendarWeek? week}) async {
    _requireAuth();
    final response = await _transport.get(_endpoints.timetableList(week: week));
    _asi = extractAsi(response.body) ?? _asi;
    return TimetableHtmlParser.parseTimetable(response.body);
  }

  /// Goldener Pfad: holt die Termine als geparste iCal-Events.
  ///
  /// Ohne [termineIds] wird zuerst die Planseite geladen, um die IDs zu ernten.
  Future<List<ICalEvent>> fetchICalEvents({
    CalendarWeek? week,
    List<String>? termineIds,
  }) async {
    final raw = await fetchICalRaw(week: week, termineIds: termineIds);
    return ICalParser.parse(raw);
  }

  /// Wie [fetchICalEvents], gibt aber den rohen `.ics`-Text zurück (z.B. zum
  /// Speichern / Teilen / Importieren in eine Kalender-App).
  Future<String> fetchICalRaw({
    CalendarWeek? week,
    List<String>? termineIds,
  }) async {
    _requireAuth();
    var ids = termineIds;
    if (ids == null || ids.isEmpty) {
      final page = await _transport.get(_endpoints.timetablePlan(week: week));
      _asi = extractAsi(page.body) ?? _asi;
      ids = extractTermineIds(page.body);
      if (ids.isEmpty) {
        throw LsfParseException(
          'Keine Termin-IDs auf der Planseite gefunden.',
        );
      }
    }
    final response = await _transport.get(_endpoints.ical(ids));
    return response.body;
  }

  /// Loggt aus und verwirft die Session.
  Future<void> logout() async {
    try {
      await _transport.get(_endpoints.logout());
    } finally {
      _loggedIn = false;
      _asi = null;
    }
  }

  /// Schließt den Transport (HTTP-Client).
  void close() => _transport.close();

  void _requireAuth() {
    if (!_loggedIn) throw NotAuthenticatedException();
  }

  Uri _resolveAction(String action) {
    if (action.isEmpty) return _endpoints.base;
    final parsed = Uri.parse(action);
    if (parsed.hasScheme) return parsed;
    return _endpoints.base.resolveUri(parsed);
  }
}
