import 'package:flutter/material.dart';

import 'services/credential_store.dart';
import 'ui/login_screen.dart';
import 'ui/timetable_screen.dart';

class HtwCenterApp extends StatelessWidget {
  const HtwCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTW Center',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005a9b),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF005a9b),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _StartGate(),
    );
  }
}

/// Entscheidet beim Start: gespeicherte Zugangsdaten → Stundenplan, sonst Login.
class _StartGate extends StatelessWidget {
  const _StartGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: CredentialStore().hasCredentials(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const TimetableScreen() : const LoginScreen();
      },
    );
  }
}
