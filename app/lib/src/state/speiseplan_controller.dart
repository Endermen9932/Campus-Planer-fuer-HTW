import 'package:flutter/material.dart';

import '../services/mensa_service.dart';
import '../services/offline_cache.dart';

enum SpeiseplanLoadState { idle, loading, ready, error }

/// State-Controller für den Mensa-Speiseplan – analog zu [TimetableController].
class SpeiseplanController extends ChangeNotifier {
  SpeiseplanController({MensaService? service, OfflineCache? cache})
      : _service = service ?? MensaService(),
        _cache = cache ?? OfflineCache();

  final MensaService _service;
  final OfflineCache _cache;

  SpeiseplanLoadState _state = SpeiseplanLoadState.idle;
  DateTime            _date  = DateTime.now();
  MensaDay?           _day;
  String?             _errorMessage;
  bool                _isOffline = false;

  SpeiseplanLoadState get state        => _state;
  DateTime            get date         => _date;
  MensaDay?           get day          => _day;
  String?             get errorMessage => _errorMessage;
  bool                get isOffline    => _isOffline;

  void nextDay()     { _date = _date.add(const Duration(days: 1));      load(); }
  void previousDay() { _date = _date.subtract(const Duration(days: 1)); load(); }
  void goToToday()   { _date = DateTime.now();                           load(); }

  Future<void> load() async {
    _state        = SpeiseplanLoadState.loading;
    _errorMessage = null;
    _isOffline    = false;
    notifyListeners();
    try {
      _day   = await _service.fetchDay(_date);
      await _cache.saveMensaDay(_day!);
      _state = SpeiseplanLoadState.ready;
    } on MensaFetchException catch (e) {
      final cached = await _cache.loadMensaDay(_date);
      if (cached != null) {
        _day       = cached;
        _state     = SpeiseplanLoadState.ready;
        _isOffline = true;
      } else {
        _errorMessage = e.message;
        _state        = SpeiseplanLoadState.error;
      }
    } catch (e) {
      final cached = await _cache.loadMensaDay(_date);
      if (cached != null) {
        _day       = cached;
        _state     = SpeiseplanLoadState.ready;
        _isOffline = true;
      } else {
        _errorMessage = e.toString();
        _state        = SpeiseplanLoadState.error;
      }
    }
    notifyListeners();
  }
}
