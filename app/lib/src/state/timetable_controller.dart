import 'package:flutter/foundation.dart';
import 'package:lsf_client/lsf_client.dart';

import '../services/lsf_repository.dart';

enum LoadState { idle, loading, ready, error }

/// Hält den Zustand der Stundenplan-Ansicht und lädt die Daten via Repository.
class TimetableController extends ChangeNotifier {
  TimetableController({LsfRepository? repository, CalendarWeek? initialWeek})
    : _repository = repository ?? LsfRepository(),
      week = initialWeek ?? CalendarWeek.current();

  final LsfRepository _repository;

  /// Aktuell angezeigte Woche.
  CalendarWeek week;
  LoadState state = LoadState.idle;
  List<ICalEvent> events = const [];
  String? errorMessage;

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
    errorMessage = null;
    notifyListeners();
    try {
      final fetched = await _repository.fetchEvents(week: week);
      fetched.sort((a, b) {
        final ad = a.start?.value;
        final bd = b.start?.value;
        if (ad == null || bd == null) return 0;
        return ad.compareTo(bd);
      });
      events = fetched;
      state = LoadState.ready;
    } on LoginFailedException catch (e) {
      state = LoadState.error;
      errorMessage = 'Login fehlgeschlagen: ${e.message}';
    } on LsfException catch (e) {
      state = LoadState.error;
      errorMessage = e.message;
    } catch (e) {
      state = LoadState.error;
      errorMessage = 'Unerwarteter Fehler: $e';
    }
    notifyListeners();
  }
}
