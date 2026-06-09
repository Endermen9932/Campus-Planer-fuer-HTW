import 'package:flutter/foundation.dart';
import 'package:lsf_client/lsf_client.dart';

import '../services/lsf_repository.dart';
import '../services/mensa_service.dart';
import '../services/offline_cache.dart';

enum LoadState { idle, loading, ready, error }

/// Hält den Zustand der Stundenplan-Ansicht und lädt die Daten via Repository.
class TimetableController extends ChangeNotifier {
  TimetableController({
    LsfRepository? repository,
    CalendarWeek? initialWeek,
    OfflineCache? cache,
    MensaService? mensaService,
  })  : _repository = repository ?? LsfRepository(),
        _cache = cache ?? OfflineCache(),
        _mensaService = mensaService ?? MensaService(),
        week = initialWeek ?? CalendarWeek.current();

  final LsfRepository _repository;
  final OfflineCache _cache;
  final MensaService _mensaService;

  /// Aktuell angezeigte Woche.
  CalendarWeek week;
  LoadState state = LoadState.idle;
  List<ICalEvent> events = const [];
  String? errorMessage;

  /// `true` wenn Daten aus dem Offline-Cache stammen.
  bool isOffline = false;

  Future<void> nextWeek() {
    week = week.next;
    return load();
  }

  Future<void> previousWeek() {
    week = week.previous;
    return load();
  }

  Future<void> goToCurrentWeek() {
    week = CalendarWeek.current();
    return load();
  }

  Future<void> load() async {
    state = LoadState.loading;
    isOffline = false;
    errorMessage = null;
    notifyListeners();
    try {
      final fetched = await _repository.fetchEvents(week: week);
      final filtered = _filterToWeek(fetched, week);
      filtered.sort((a, b) {
        final ad = a.start?.localValue;
        final bd = b.start?.localValue;
        if (ad == null || bd == null) return 0;
        return ad.compareTo(bd);
      });
      events = filtered;
      state = LoadState.ready;
      await _cache.saveTimetable(week, filtered);
      _prefetchMensa(week);
    } on LoginFailedException catch (e) {
      state = LoadState.error;
      errorMessage = 'Login fehlgeschlagen: ${e.message}';
    } on LsfException catch (e) {
      await _tryLoadFromCache();
      if (state != LoadState.ready) {
        state = LoadState.error;
        errorMessage = e.message;
      }
    } catch (e) {
      await _tryLoadFromCache();
      if (state != LoadState.ready) {
        state = LoadState.error;
        errorMessage = 'Unerwarteter Fehler: $e';
      }
    }
    notifyListeners();
  }

  Future<void> _tryLoadFromCache() async {
    final cached = await _cache.loadTimetable(week);
    if (cached != null) {
      events = cached;
      state = LoadState.ready;
      isOffline = true;
    }
  }

  void _prefetchMensa(CalendarWeek w) {
    for (final day in w.weekdaysMonToFri) {
      _mensaService.fetchDay(day).then(
        (mensaDay) => _cache.saveMensaDay(mensaDay),
        onError: (_) {},
      );
    }
  }

  /// Filtert Events auf Mo–So der gegebenen Woche.
  ///
  /// Wöchentlich wiederkehrende Events (RRULE:FREQ=WEEKLY) werden auf das
  /// konkrete Auftreten in der Zielwoche expandiert, damit Events nicht
  /// herausgefiltert werden, wenn DTSTART in einer anderen Woche liegt.
  static List<ICalEvent> _filterToWeek(
    List<ICalEvent> events,
    CalendarWeek week,
  ) {
    final monday = week.monday;
    final sunday = monday.add(const Duration(days: 6));
    final result = <ICalEvent>[];
    for (final e in events) {
      final expanded = _expandToWeek(e, monday, sunday);
      if (expanded != null) result.add(expanded);
    }
    return result;
  }

  /// Gibt das Event zurück, wenn es in [monday]..[sunday] fällt.
  ///
  /// Für FREQ=WEEKLY wird das Auftreten in der Zielwoche berechnet und ein
  /// neues [ICalEvent] mit angepasstem Start/End zurückgegeben.
  static ICalEvent? _expandToWeek(
    ICalEvent event,
    DateTime monday,
    DateTime sunday,
  ) {
    final start = event.start?.localValue;
    if (start == null) return null;
    final startDate = DateTime(start.year, start.month, start.day);

    // Kein RRULE: direkter Datumsvergleich.
    if (event.rrule == null) {
      return (!startDate.isBefore(monday) && !startDate.isAfter(sunday))
          ? event
          : null;
    }

    final rrule = event.rrule!.toUpperCase();

    // Nur FREQ=WEEKLY wird expandiert; andere Frequenzen → direkter Vergleich.
    if (!rrule.contains('FREQ=WEEKLY')) {
      return (!startDate.isBefore(monday) && !startDate.isAfter(sunday))
          ? event
          : null;
    }

    // Event darf noch nicht nach der Zielwoche begonnen haben.
    if (startDate.isAfter(sunday)) return null;

    // INTERVAL (Standard = 1 für wöchentlich, 2 für 14-täglich usw.)
    final intervalMatch = RegExp(r'INTERVAL=(\d+)').firstMatch(rrule);
    final interval =
        intervalMatch != null ? int.parse(intervalMatch.group(1)!) : 1;

    // Kandidatentag in der Zielwoche: gleicher Wochentag wie DTSTART.
    // weekday: 1=Mo … 7=So → Offset ab Montag: 0 … 6
    final dayOffset = start.weekday - 1;
    final occurrenceDate = monday.add(Duration(days: dayOffset));

    // Auftreten muss auf oder nach DTSTART liegen.
    if (occurrenceDate.isBefore(startDate)) return null;

    // Wochenabstand muss durch INTERVAL teilbar sein.
    final weeksBetween =
        occurrenceDate.difference(startDate).inDays ~/ 7;
    if (weeksBetween % interval != 0) return null;

    // COUNT-Grenze prüfen.
    final countMatch = RegExp(r'COUNT=(\d+)').firstMatch(rrule);
    if (countMatch != null) {
      final count = int.parse(countMatch.group(1)!);
      if (weeksBetween >= count) return null;
    }

    // UNTIL-Grenze prüfen (YYYYMMDD oder YYYYMMDDTHHMMSSz).
    final untilMatch =
        RegExp(r'UNTIL=(\d{8})').firstMatch(rrule);
    if (untilMatch != null) {
      final u = untilMatch.group(1)!;
      final untilDate = DateTime(
        int.parse(u.substring(0, 4)),
        int.parse(u.substring(4, 6)),
        int.parse(u.substring(6, 8)),
      );
      if (occurrenceDate.isAfter(untilDate)) return null;
    }

    // Neues Event mit angepasstem Datum, aber gleicher Uhrzeit.
    final end = event.end?.localValue;
    final duration =
        end != null ? end.difference(start) : const Duration(hours: 1);
    final newStart = DateTime(
      occurrenceDate.year,
      occurrenceDate.month,
      occurrenceDate.day,
      start.hour,
      start.minute,
      start.second,
    );
    return ICalEvent(
      uid: event.uid,
      summary: event.summary,
      location: event.location,
      description: event.description,
      start: ICalDateTime(newStart, tzid: event.start?.tzid),
      end: ICalDateTime(newStart.add(duration), tzid: event.end?.tzid),
      rrule: event.rrule,
    );
  }
}
