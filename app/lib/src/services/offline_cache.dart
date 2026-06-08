import 'dart:convert';

import 'package:lsf_client/lsf_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mensa_service.dart';

/// Lightweight offline cache backed by shared_preferences.
///
/// Timetable events are stored per CalendarWeek; Mensa days per date string.
class OfflineCache {
  static const _timetablePrefix = 'cache_timetable_';
  static const _mensaPrefix = 'cache_mensa_';

  Future<void> saveTimetable(
    CalendarWeek week,
    List<ICalEvent> events,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString('$_timetablePrefix${week.param}', data);
  }

  Future<List<ICalEvent>?> loadTimetable(CalendarWeek week) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_timetablePrefix${week.param}');
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ICalEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMensaDay(MensaDay day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_mensaPrefix${day.date}',
      jsonEncode(day.toJson()),
    );
  }

  Future<MensaDay?> loadMensaDay(DateTime date) async {
    final key = _dateKey(date);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_mensaPrefix$key');
    if (raw == null) return null;
    try {
      return MensaDay.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
