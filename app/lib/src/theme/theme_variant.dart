import 'package:flutter/material.dart';

/// Die vier Material-You-Varianten aus der AOSP-PDF (Seite 8).
/// TONAL_SPOT = Standard, VIBRANT, EXPRESSIVE, SPRITZ (≈ grauton/neutral).
enum AppThemeVariant {
  tonalSpot('Tonal Spot',   DynamicSchemeVariant.tonalSpot),
  vibrant('Vibrant',        DynamicSchemeVariant.vibrant),
  expressive('Expressive',  DynamicSchemeVariant.expressive),
  spritz('Spritz',          DynamicSchemeVariant.neutral);

  const AppThemeVariant(this.label, this.scheme);

  /// Anzeigename in der UI.
  final String label;

  /// Zugehöriger Flutter-`DynamicSchemeVariant`.
  final DynamicSchemeVariant scheme;
}
