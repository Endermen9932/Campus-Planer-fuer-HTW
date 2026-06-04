import 'package:flutter/material.dart';

/// Sentinel-ID für „Dynamisch (Wallpaper)".
const dynamicColorwayId = 'dynamic';

/// Festes Colorway-Preset mit einem Seed-Color für Material-You-Tonerzeugung.
class AppColorway {
  const AppColorway({
    required this.id,
    required this.label,
    required this.seed,
  });

  final String id;
  final String label;
  final Color seed;
}

/// Alle verfügbaren festen Colorways.
/// Index 0 = HTW-Blau, wird als Fallback verwendet wenn Wallpaper-Dynamic
/// gewählt ist aber nicht verfügbar (API < 31 / Nicht-Android-Plattformen).
const List<AppColorway> kColorways = [
  AppColorway(id: 'htw_blue', label: 'HTW-Blau',  seed: Color(0xFF005a9b)),
  AppColorway(id: 'green',    label: 'Grün',       seed: Color(0xFF2E7D32)),
  AppColorway(id: 'violet',   label: 'Violett',    seed: Color(0xFF6A1B9A)),
  AppColorway(id: 'red',      label: 'Rot',        seed: Color(0xFFC62828)),
  AppColorway(id: 'orange',   label: 'Orange',     seed: Color(0xFFE65100)),
  AppColorway(id: 'teal',     label: 'Türkis',     seed: Color(0xFF00695C)),
  AppColorway(id: 'pink',     label: 'Pink',       seed: Color(0xFFAD1457)),
];

/// Gibt den Colorway für eine gegebene ID zurück oder HTW-Blau als Fallback.
AppColorway colorwayById(String id) =>
    kColorways.firstWhere((c) => c.id == id, orElse: () => kColorways.first);
