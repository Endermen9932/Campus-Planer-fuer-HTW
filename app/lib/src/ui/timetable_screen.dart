import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lsf_client/lsf_client.dart';

import '../services/background_refresh.dart';
import '../services/credential_store.dart';
import '../state/timetable_controller.dart';
import 'login_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _controller = TimetableController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.load();
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await CredentialStore().clear();
    await BackgroundRefresh.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stundenplan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _controller.state == LoadState.loading
                ? null
                : () => _controller.load(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _WeekBar(
            week: _controller.week,
            onPrevious: _controller.previousWeek,
            onNext: _controller.nextWeek,
            onToday: _controller.goToCurrentWeek,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _controller.load(),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.state) {
      case LoadState.loading:
      case LoadState.idle:
        return const Center(child: CircularProgressIndicator());
      case LoadState.error:
        return _ErrorView(
          message: _controller.errorMessage ?? 'Unbekannter Fehler',
          onRetry: () => _controller.load(),
        );
      case LoadState.ready:
        if (_controller.events.isEmpty) {
          return const _CenteredScroll(
            child: Text('Keine Termine in dieser Woche.'),
          );
        }
        return _EventList(events: _controller.events);
    }
  }
}

/// Leiste zum Blättern zwischen Kalenderwochen.
class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.week,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final CalendarWeek week;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Vorige Woche',
              onPressed: onPrevious,
            ),
            Expanded(
              child: Center(
                child: Text(
                  'KW ${week.week} · ${week.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Nächste Woche',
              onPressed: onNext,
            ),
            TextButton(onPressed: onToday, child: const Text('Heute')),
          ],
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});
  final List<ICalEvent> events;

  @override
  Widget build(BuildContext context) {
    // Nach Wochentag gruppieren.
    final byDay = <String, List<ICalEvent>>{};
    final dayFormat = DateFormat('EEEE, d. MMMM', 'de');
    for (final e in events) {
      final start = e.start?.localValue;
      final key = start != null ? dayFormat.format(start) : 'Ohne Datum';
      byDay.putIfAbsent(key, () => []).add(e);
    }

    final dayKeys = byDay.keys.toList();
    return ListView.builder(
      itemCount: dayKeys.length,
      itemBuilder: (context, i) {
        final day = dayKeys[i];
        final dayEvents = byDay[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                day,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...dayEvents.map((e) => _EventTile(event: e)),
          ],
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final ICalEvent event;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final start = event.start?.localValue;
    final end = event.end?.localValue;
    final time = (start != null && end != null)
        ? '${timeFormat.format(start)} – ${timeFormat.format(end)}'
        : '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(event.summary ?? 'Veranstaltung'),
        subtitle: Text(
          [
            time,
            if (event.location != null) event.location!,
          ].where((s) => s.isNotEmpty).join('  ·  '),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
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

/// Scrollbarer, zentrierter Inhalt – damit RefreshIndicator auch bei „leer"
/// und „Fehler" funktioniert.
class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({required this.child});
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
