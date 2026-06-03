import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/services/background_refresh.dart';
import 'src/services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Deutsche Datums-/Wochentagsnamen für intl.
  await initializeDateFormatting('de');

  // Lokale Benachrichtigungen + Hintergrund-Refresh initialisieren.
  await Notifications.instance.init();
  await BackgroundRefresh.init();

  runApp(const HtwCenterApp());
}
