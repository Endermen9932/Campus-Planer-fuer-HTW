import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:lsf_client/lsf_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'lsf_repository.dart';
import 'notifications.dart';

const _taskName = 'lsf-periodic-refresh';
const _prefsKey = 'lsf_last_schedule_hash';

/// Einstiegspunkt für den Hintergrund-Isolate (muss top-level + `vm:entry-point`
/// sein, damit der Tree-Shaker ihn behält).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final events = await LsfRepository().fetchEvents();
      final changed = await ScheduleDiff.updateAndDetectChange(events);
      if (changed) {
        await Notifications.instance.showScheduleChanged(
          'Dein Stundenplan hat sich geändert.',
        );
      }
      return true;
    } on NotAuthenticatedException {
      return true; // nicht eingeloggt → nichts zu tun, kein Fehler
    } catch (_) {
      return false; // Fehler → WorkManager versucht es später erneut
    }
  });
}

/// Erkennt Änderungen am Stundenplan über einen stabilen Hash.
class ScheduleDiff {
  /// Vergleicht die neuen Events mit dem zuletzt gespeicherten Hash, speichert
  /// den neuen Hash und gibt zurück, ob sich etwas geändert hat.
  static Future<bool> updateAndDetectChange(List<ICalEvent> events) async {
    final hash = computeHash(events);
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_prefsKey);
    await prefs.setString(_prefsKey, hash);
    // Beim allerersten Lauf (previous == null) nicht benachrichtigen.
    return previous != null && previous != hash;
  }

  /// Reihenfolge-unabhängiger Hash über die relevanten Felder.
  static String computeHash(List<ICalEvent> events) {
    final parts =
        events
            .map(
              (e) =>
                  '${e.uid}|${e.summary}|${e.start?.value.toIso8601String()}'
                  '|${e.end?.value.toIso8601String()}|${e.location}',
            )
            .toList()
          ..sort();
    return base64Url.encode(utf8.encode(parts.join('\n')));
  }
}

class BackgroundRefresh {
  /// WorkManager unterstützt nur Android & iOS. Auf Desktop (Linux/Windows/
  /// macOS) gibt es keine Implementierung – dort sind die Aufrufe No-Ops und
  /// die App aktualisiert nur im Vordergrund (Pull-to-Refresh / beim Öffnen).
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// Im `main()` aufrufen.
  static Future<void> init() async {
    if (!isSupported) return;
    await Workmanager().initialize(callbackDispatcher);
  }

  /// Periodischen Refresh registrieren (Minimum auf Android ~15 min; iOS
  /// entscheidet das OS und garantiert KEINE festen Intervalle).
  static Future<void> schedule({
    Duration frequency = const Duration(hours: 1),
  }) async {
    if (!isSupported) return;
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: frequency,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancel() async {
    if (!isSupported) return;
    await Workmanager().cancelByUniqueName(_taskName);
  }
}
