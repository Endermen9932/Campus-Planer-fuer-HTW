import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../theme/colorways.dart';
import '../theme/theme_controller.dart';
import '../theme/theme_variant.dart';

/// Einstellungs-Screen für Erscheinungsbild, Colorway und Theme-Variante.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    // DynamicColorBuilder wird hier direkt genutzt, um die Verfügbarkeit von
    // Wallpaper-Farben zu prüfen – ohne globale State-Weitergabe.
    return DynamicColorBuilder(
      builder: (lightDynamic, _) {
        final hasDynamic = lightDynamic != null;
        return Scaffold(
          appBar: AppBar(title: const Text('Einstellungen')),
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => _SettingsBody(
              controller: controller,
              hasDynamicColor: hasDynamic,
            ),
          ),
        );
      },
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.controller,
    required this.hasDynamicColor,
  });

  final ThemeController controller;
  final bool hasDynamicColor;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _SectionHeader('Erscheinungsbild'),
        _AppearanceSection(controller: controller),
        const SizedBox(height: 8),
        _SectionHeader('Farbe'),
        _ColorSection(controller: controller, hasDynamicColor: hasDynamicColor),
        const SizedBox(height: 8),
        _SectionHeader('Stil'),
        _VariantSection(controller: controller),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hilfs-Widget: Abschnitts-Überschrift
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Abschnitt: Hell / Dunkel / System
// ---------------------------------------------------------------------------

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.controller});
  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto_outlined),
            label: Text('System'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Hell'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined),
            label: Text('Dunkel'),
          ),
        ],
        selected: {controller.mode},
        onSelectionChanged: (v) => controller.setMode(v.first),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Abschnitt: Colorway-Picker
// ---------------------------------------------------------------------------

class _ColorSection extends StatelessWidget {
  const _ColorSection({
    required this.controller,
    required this.hasDynamicColor,
  });

  final ThemeController controller;
  final bool hasDynamicColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          // „Dynamisch (Wallpaper)" – nur aktiv wenn Gerät es unterstützt.
          _DynamicSwatch(
            isSelected: controller.colorwayId == dynamicColorwayId,
            isAvailable: hasDynamicColor,
            onTap: hasDynamicColor
                ? () => controller.setColorway(dynamicColorwayId)
                : null,
          ),
          // Feste Colorways
          for (final cw in kColorways)
            _ColorSwatch(
              colorway: cw,
              isSelected: controller.colorwayId == cw.id,
              onTap: () => controller.setColorway(cw.id),
            ),
        ],
      ),
    );
  }
}

/// Kreisförmige Farbkachel für einen festen Colorway.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.colorway,
    required this.isSelected,
    required this.onTap,
  });

  final AppColorway  colorway;
  final bool         isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: colorway.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorway.seed,
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  )
                : null,
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 28)
              : null,
        ),
      ),
    );
  }
}

/// Kachel für die dynamische Wallpaper-Farbe.
class _DynamicSwatch extends StatelessWidget {
  const _DynamicSwatch({
    required this.isSelected,
    required this.isAvailable,
    this.onTap,
  });

  final bool          isSelected;
  final bool          isAvailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: isAvailable
          ? 'Dynamisch (Wallpaper)'
          : 'Nicht verfügbar (Android 12+ erforderlich)',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isAvailable
                ? SweepGradient(colors: [
                    cs.primary,
                    cs.tertiary,
                    cs.secondary,
                    cs.primary,
                  ])
                : null,
            color: isAvailable ? null : cs.surfaceContainerHighest,
            border: isSelected
                ? Border.all(color: cs.onSurface, width: 3)
                : null,
          ),
          child: isSelected
              ? Icon(Icons.check, color: cs.onPrimary, size: 28)
              : Icon(
                  Icons.auto_awesome,
                  color: isAvailable ? cs.onPrimary : cs.outline,
                  size: 24,
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Abschnitt: Theme-Variante (TONAL_SPOT / VIBRANT / EXPRESSIVE / SPRITZ)
// ---------------------------------------------------------------------------

class _VariantSection extends StatelessWidget {
  const _VariantSection({required this.controller});
  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    // Variante ist nur relevant, wenn ein fester Colorway gewählt ist.
    // Bei „Dynamisch" gibt das OS den Stil vor.
    final isDynamic  = controller.colorwayId == dynamicColorwayId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDynamic)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Beim dynamischen Colorway bestimmt das OS den Stil.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppThemeVariant.values.map((v) {
              final isSelected = controller.variant == v;
              return ChoiceChip(
                label: Text(v.label),
                selected: isSelected,
                onSelected: isDynamic ? null : (_) => controller.setVariant(v),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
