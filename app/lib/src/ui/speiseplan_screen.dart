import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/mensa_service.dart';

class SpeiseplanScreen extends StatefulWidget {
  const SpeiseplanScreen({super.key});

  @override
  State<SpeiseplanScreen> createState() => _SpeiseplanScreenState();
}

enum _LoadState { idle, loading, ready, error }

class _SpeiseplanScreenState extends State<SpeiseplanScreen> {
  final _service = MensaService();
  var _state = _LoadState.idle;
  DateTime _date = DateTime.now();
  MensaDay? _day;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _error = null;
    });
    try {
      final day = await _service.fetchDay(_date);
      if (!mounted) return;
      setState(() {
        _day = day;
        _state = _LoadState.ready;
      });
    } on MensaFetchException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _state = _LoadState.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _state = _LoadState.error;
      });
    }
  }

  void _changeDate(DateTime date) {
    _date = date;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _state == _LoadState.loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _DateBar(
            date: _date,
            onPrevious: () =>
                _changeDate(_date.subtract(const Duration(days: 1))),
            onNext: () => _changeDate(_date.add(const Duration(days: 1))),
            onToday: () => _changeDate(DateTime.now()),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.idle:
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return _ErrorView(message: _error ?? 'Unbekannter Fehler', onRetry: _load);
      case _LoadState.ready:
        final day = _day;
        if (day == null || day.isEmpty) {
          return const _CenteredScroll(
            child: Text('Kein Angebot für diesen Tag.'),
          );
        }
        return _MenuList(day: day);
    }
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, d. MMMM', 'de');
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Vorheriger Tag',
              onPressed: onPrevious,
            ),
            Expanded(
              child: Center(
                child: Text(
                  fmt.format(date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Nächster Tag',
              onPressed: onNext,
            ),
            TextButton(onPressed: onToday, child: const Text('Heute')),
          ],
        ),
      ),
    );
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
                          color: Theme.of(context).colorScheme.primary,
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

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.labels});

  final MensaLabels labels;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (labels.vegan) {
      chips.add(_Chip('Vegan', Colors.green));
    } else if (labels.vegetarian) {
      chips.add(_Chip('Vegetarisch', Colors.lightGreen));
    }

    if (labels.sustainability case final s?) {
      final (color, text) = switch (s) {
        'green' => (Colors.green, 'Nachhaltig'),
        'yellow' => (Colors.amber, 'Mittel'),
        'red' => (Colors.red, 'Wenig nachhaltig'),
        _ => (Colors.grey, 'Nachhaltig'),
      };
      chips.add(_Chip(text, color));
    }

    if (labels.co2Rating case final r?) {
      chips.add(_Chip('CO₂ $r', Colors.blue.shade300));
    }

    if (labels.h2oRating case final r?) {
      chips.add(_Chip('H₂O $r', Colors.cyan.shade300));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
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
          FilledButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
        ],
      ),
    );
  }
}

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
