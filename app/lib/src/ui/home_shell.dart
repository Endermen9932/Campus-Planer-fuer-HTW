import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lsf_client/lsf_client.dart';

import '../services/background_refresh.dart';
import '../services/credential_store.dart';
import '../services/mensa_service.dart';
import '../state/timetable_controller.dart';
import '../state/speiseplan_controller.dart';
import '../theme/theme_controller.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'widgets/shared_widgets.dart';
import 'widgets/week_calendar.dart';

/// Root-Shell für eingeloggte Nutzer.
///
/// Verwaltet [TimetableController] und [SpeiseplanController], zeigt eine
/// gemeinsame [AppBar] mit Refresh/Settings/Logout-Aktionen und navigiert
/// per [NavigationBar] + [IndexedStack] zwischen den Tabs ohne Route-Push.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  late final TimetableController  _timetable;
  late final SpeiseplanController _speiseplan;

  @override
  void initState() {
    super.initState();

    _timetable = TimetableController();
    _timetable.addListener(_rebuild);
    _timetable.load();

    // Mensa wird lazy geladen, sobald der Tab erstmals ausgewählt wird.
    _speiseplan = SpeiseplanController();
    _speiseplan.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _timetable
      ..removeListener(_rebuild)
      ..dispose();
    _speiseplan
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  // --- Navigation -------------------------------------------------------

  void _onDestinationSelected(int index) {
    if (index == 1 && _speiseplan.state == SpeiseplanLoadState.idle) {
      _speiseplan.load(); // Lazy-Load beim ersten Tab-Öffnen
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    await CredentialStore().clear();
    await BackgroundRefresh.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(themeController: widget.themeController),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(controller: widget.themeController),
      ),
    );
  }

  // --- Refresh-Hilfen ---------------------------------------------------

  void _refresh() {
    if (_selectedIndex == 0) {
      _timetable.load();
    } else {
      _speiseplan.load();
    }
  }

  bool get _isLoading => _selectedIndex == 0
      ? _timetable.state == LoadState.loading
      : _speiseplan.state == SpeiseplanLoadState.loading;

  // --- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Stundenplan' : 'Mensa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: _isLoading ? null : _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _TimetableTab(controller: _timetable),
          _SpeiseplanTab(controller: _speiseplan),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Stundenplan',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Mensa',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stundenplan-Tab-Inhalt
// ---------------------------------------------------------------------------

class _TimetableTab extends StatelessWidget {
  const _TimetableTab({required this.controller});
  final TimetableController controller;

  String _weekLabel() {
    final days = controller.week.weekdaysMonToFri;
    final fmt = DateFormat('d. MMM', 'de');
    return 'KW ${controller.week.week}  ·  '
        '${fmt.format(days.first)} – ${fmt.format(days.last)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (controller.isOffline) const _OfflineBanner(),
        NavigationStrip(
          label: _weekLabel(),
          previousTooltip: 'Vorige Woche',
          nextTooltip: 'Nächste Woche',
          onPrevious: controller.previousWeek,
          onNext: controller.nextWeek,
          onToday: controller.goToCurrentWeek,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: _buildBody(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (controller.state) {
      case LoadState.idle:
      case LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadState.error:
        return AppErrorView(
          message: controller.errorMessage ?? 'Unbekannter Fehler',
          onRetry: controller.load,
        );
      case LoadState.ready:
        if (controller.events.isEmpty) {
          return const AppCenteredScroll(
            child: Text('Keine Termine in dieser Woche.'),
          );
        }
        return WeekCalendarView(
          week: controller.week,
          events: controller.events,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Mensa-Tab-Inhalt
// ---------------------------------------------------------------------------

class _SpeiseplanTab extends StatelessWidget {
  const _SpeiseplanTab({required this.controller});
  final SpeiseplanController controller;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, d. MMMM', 'de');
    return Column(
      children: [
        if (controller.isOffline) const _OfflineBanner(),
        NavigationStrip(
          label: fmt.format(controller.date),
          previousTooltip: 'Vorheriger Tag',
          nextTooltip: 'Nächster Tag',
          onPrevious: controller.previousDay,
          onNext: controller.nextDay,
          onToday: controller.goToToday,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: _buildBody(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (controller.state) {
      case SpeiseplanLoadState.idle:
      case SpeiseplanLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case SpeiseplanLoadState.error:
        return AppErrorView(
          message: controller.errorMessage ?? 'Unbekannter Fehler',
          onRetry: controller.load,
        );
      case SpeiseplanLoadState.ready:
        final day = controller.day;
        if (day == null || day.isEmpty) {
          return const AppCenteredScroll(
            child: Text('Kein Angebot für diesen Tag.'),
          );
        }
        return _MenuList(day: day);
    }
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList({required this.day});
  final MensaDay day;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: day.categories.length,
      itemBuilder: (context, i) {
        final cat = day.categories[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                cat.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...cat.meals.map((m) => _MealCard(meal: m)),
          ],
        );
      },
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});
  final MensaMeal meal;

  @override
  Widget build(BuildContext context) {
    final prices = meal.prices;
    final cs     = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    meal.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                if (prices != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${_fmtPrice(prices.student)} €',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ],
            ),
            if (prices != null) ...[
              const SizedBox(height: 2),
              Text(
                'Stud. ${_fmtPrice(prices.student)} · '
                'MA ${_fmtPrice(prices.staff)} · '
                'Gast ${_fmtPrice(prices.guest)} €',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            _LabelRow(labels: meal.labels),
          ],
        ),
      ),
    );
  }

  String _fmtPrice(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
}

// Semantische Chip-Typen – gemappt auf Material-You-ColorScheme-Rollen,
// damit Dark-Mode & Colorways korrekt greifen.
enum _ChipType { primary, secondary, tertiary, error, neutral }

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.labels});
  final MensaLabels labels;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (labels.vegan) {
      chips.add(const _Chip('Vegan', _ChipType.primary));
    } else if (labels.vegetarian) {
      chips.add(const _Chip('Vegetarisch', _ChipType.secondary));
    }

    if (labels.sustainability case final s?) {
      final (type, text) = switch (s) {
        'green'  => (_ChipType.primary,  'Nachhaltig'),
        'yellow' => (_ChipType.tertiary, 'Mittel'),
        'red'    => (_ChipType.error,    'Wenig nachhaltig'),
        _        => (_ChipType.neutral,  'Nachhaltig'),
      };
      chips.add(_Chip(text, type));
    }

    if (labels.co2Rating case final r?) chips.add(_Chip('CO₂ $r', _ChipType.secondary));
    if (labels.h2oRating  case final r?) chips.add(_Chip('H₂O $r', _ChipType.tertiary));

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.type);

  final String    label;
  final _ChipType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (type) {
      _ChipType.primary   => (cs.primaryContainer,        cs.onPrimaryContainer),
      _ChipType.secondary => (cs.secondaryContainer,      cs.onSecondaryContainer),
      _ChipType.tertiary  => (cs.tertiaryContainer,       cs.onTertiaryContainer),
      _ChipType.error     => (cs.errorContainer,          cs.onErrorContainer),
      _ChipType.neutral   => (cs.surfaceContainerHighest, cs.onSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline-Banner
// ---------------------------------------------------------------------------

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.tertiaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 14, color: cs.onTertiaryContainer),
          const SizedBox(width: 6),
          Text(
            'Offline – gespeicherte Daten',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onTertiaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}
