import 'package:flutter/material.dart';

import 'theme_variant.dart';

/// Baut ein [ThemeData] aus einem bereits generierten [ColorScheme].
ThemeData buildTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
  );
}

/// Erzeugt einen [ColorScheme] aus Seed-Color, Brightness und AOSP-Variante.
/// Nutzt [ColorScheme.fromSeed] mit [DynamicSchemeVariant] (Flutter ≥ 3.22).
ColorScheme schemeFor({
  required Color seed,
  required Brightness brightness,
  required AppThemeVariant variant,
}) {
  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: variant.scheme,
  );
}
