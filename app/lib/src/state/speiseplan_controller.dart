import 'package:flutter/material.dart';

import '../services/mensa_service.dart';

enum SpeiseplanLoadState { idle, loading, ready, error }

/// State-Controller für den Mensa-Speiseplan – analog zu [TimetableController].
class SpeiseplanController extends ChangeNotifier {
  final _service = MensaService();

  SpeiseplanLoadState _state = SpeiseplanLoadState.idle;
  DateTime            _date  = DateTime.now();
  MensaDay?           _day;
  String?             _errorMessage;

  SpeiseplanLoadState get state        => _state;
  DateTime            get date         => _date;
  MensaDay?           get day          => _day;
  String?             get errorMessage => _errorMessage;

  void nextDay()     { _date = _date.add(const Duration(days: 1));      load(); }
  void previousDay() { _date = _date.subtract(const Duration(days: 1)); load(); }
  void goToToday()   { _date = DateTime.now();                           load(); }

  Future<void> load() async {
    _state        = SpeiseplanLoadState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _day   = await _service.fetchDay(_date);
      _state = SpeiseplanLoadState.ready;
    } on MensaFetchException catch (e) {
      _errorMessage = e.message;
      _state        = SpeiseplanLoadState.error;
    } catch (e) {
      _errorMessage = e.toString();
      _state        = SpeiseplanLoadState.error;
    }
    notifyListeners();
  }
}
