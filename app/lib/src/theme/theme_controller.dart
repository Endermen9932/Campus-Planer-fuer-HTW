import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'colorways.dart';
import 'theme_variant.dart';

/// Verwaltet Theme-Einstellungen (Modus, Colorway, Variante) und persistiert
/// sie via [SharedPreferences] – analog zum Muster in `background_refresh.dart`.
class ThemeController extends ChangeNotifier {
  static const _kMode    = 'theme_mode';
  static const _kColorway = 'theme_colorway';
  static const _kVariant  = 'theme_variant';

  ThemeMode       _mode      = ThemeMode.system;
  String          _colorwayId = dynamicColorwayId;
  AppThemeVariant _variant   = AppThemeVariant.tonalSpot;

  ThemeMode       get mode       => _mode;
  String          get colorwayId => _colorwayId;
  AppThemeVariant get variant    => _variant;

  /// Lädt gespeicherte Einstellungen aus [SharedPreferences].
  /// Muss vor [runApp] mit `await` aufgerufen werden.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _mode = switch (prefs.getString(_kMode)) {
      'light'  => ThemeMode.light,
      'dark'   => ThemeMode.dark,
      _        => ThemeMode.system,
    };

    _colorwayId = prefs.getString(_kColorway) ?? dynamicColorwayId;

    final variantStr = prefs.getString(_kVariant);
    _variant = AppThemeVariant.values.firstWhere(
      (v) => v.name == variantStr,
      orElse: () => AppThemeVariant.tonalSpot,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> setColorway(String id) async {
    _colorwayId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kColorway, id);
  }

  Future<void> setVariant(AppThemeVariant variant) async {
    _variant = variant;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVariant, variant.name);
  }
}
