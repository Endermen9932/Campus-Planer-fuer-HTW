import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Lokale Benachrichtigungen (z.B. „Stundenplan hat sich geändert").
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Öffnen'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showScheduleChanged(String body) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'schedule_changes',
        'Stundenplan-Änderungen',
        channelDescription: 'Benachrichtigungen bei Änderungen am Stundenplan',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );
    await _plugin.show(0, 'Stundenplan aktualisiert', body, details);
  }
}
