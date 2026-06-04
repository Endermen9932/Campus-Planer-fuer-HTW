import 'package:flutter/material.dart';

/// Generische Navigationsleiste für Wochen- / Tages-Navigation.
/// Ersetzt die früheren privaten `_WeekBar` und `_DateBar`-Widgets.
class NavigationStrip extends StatelessWidget {
  const NavigationStrip({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    this.previousTooltip = 'Zurück',
    this.nextTooltip     = 'Vorwärts',
  });

  final String        label;
  final VoidCallback  onPrevious;
  final VoidCallback  onNext;
  final VoidCallback  onToday;
  final String        previousTooltip;
  final String        nextTooltip;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: previousTooltip,
              onPressed: onPrevious,
            ),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: nextTooltip,
              onPressed: onNext,
            ),
            TextButton(onPressed: onToday, child: const Text('Heute')),
          ],
        ),
      ),
    );
  }
}

/// Zentrierter, scrollbarer Inhalt – damit [RefreshIndicator] auch bei
/// „leer" und „Fehler"-Zustand korrekt funktioniert.
class AppCenteredScroll extends StatelessWidget {
  const AppCenteredScroll({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );
  }
}

/// Einheitliche Fehler-Anzeige mit Retry-Button.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCenteredScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Erneut versuchen'),
          ),
        ],
      ),
    );
  }
}
