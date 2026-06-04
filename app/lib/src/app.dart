import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'services/credential_store.dart';
import 'theme/app_theme.dart';
import 'theme/colorways.dart';
import 'theme/theme_controller.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';

class HtwCenterApp extends StatelessWidget {
  const HtwCenterApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    // DynamicColorBuilder liefert Wallpaper-Farben auf Android 12+ (API 31+).
    // Auf älteren Versionen / anderen Plattformen sind beide Werte null →
    // Fallback auf den gewählten Preset-Colorway.
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            final ColorScheme lightScheme;
            final ColorScheme darkScheme;

            final useDynamic = themeController.colorwayId == dynamicColorwayId &&
                lightDynamic != null;

            if (useDynamic) {
              // Wallpaper-Farben direkt nutzen.
              lightScheme = lightDynamic!;
              darkScheme  = darkDynamic!;
            } else {
              // Festen Colorway (oder HTW-Blau-Fallback) mit gewählter Variante.
              final cw = themeController.colorwayId == dynamicColorwayId
                  ? kColorways.first          // HTW-Blau als Fallback
                  : colorwayById(themeController.colorwayId);

              lightScheme = schemeFor(
                seed:       cw.seed,
                brightness: Brightness.light,
                variant:    themeController.variant,
              );
              darkScheme = schemeFor(
                seed:       cw.seed,
                brightness: Brightness.dark,
                variant:    themeController.variant,
              );
            }

            return MaterialApp(
              title: 'Campus-Planer',
              theme:      buildTheme(lightScheme),
              darkTheme:  buildTheme(darkScheme),
              themeMode:  themeController.mode,
              home: _StartGate(themeController: themeController),
            );
          },
        );
      },
    );
  }
}

/// Entscheidet beim Start: gespeicherte Zugangsdaten → [HomeShell], sonst
/// [LoginScreen].
class _StartGate extends StatelessWidget {
  const _StartGate({required this.themeController});

  final ThemeController themeController;

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
        return snapshot.data!
            ? HomeShell(themeController: themeController)
            : LoginScreen(themeController: themeController);
      },
    );
  }
}
