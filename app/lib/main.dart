import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/services/background_refresh.dart';
import 'src/services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Deutsche Datums-/Wochentagsnamen für intl.
  await initializeDateFormatting('de');

  // Optionale Plattform-Dienste dürfen den Start nie blockieren (Desktop-
  // Plugins können Lücken haben). Hintergrund-Refresh ist intern auf
  // Android/iOS beschränkt.
  try {
    await Notifications.instance.init();
  } catch (_) {
    // Benachrichtigungen sind optional – ohne sie läuft die App normal weiter.
  }
  await BackgroundRefresh.init();

  runApp(const HtwCenterApp());
}
