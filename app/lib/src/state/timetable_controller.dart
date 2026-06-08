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
  static List<ICalEvent> _filterToWeek(
    List<ICalEvent> events,
    CalendarWeek week,
  ) {
    final monday = week.monday;
    final sunday = monday.add(const Duration(days: 6));
    return events.where((e) {
      final d = e.start?.localValue;
      if (d == null) return false;
      final date = DateTime(d.year, d.month, d.day);
      return !date.isBefore(monday) && !date.isAfter(sunday);
    }).toList();
  }
}
