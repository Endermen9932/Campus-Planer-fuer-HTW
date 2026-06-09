import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lsf_client/lsf_client.dart';

/// Wochenkalender-Ansicht: Montag–Freitag als Spalten mit Stunden-Zeitraster.
///
/// Jeder Tag zeigt die zugehörigen [ICalEvent]-Blöcke positioniert nach
/// Startzeit. Gleichzeitige Events werden nebeneinander dargestellt.
/// Der heutige Tag wird in der Kopfzeile hervorgehoben.
class WeekCalendarView extends StatelessWidget {
  const WeekCalendarView({
    super.key,
    required this.week,
    required this.events,
  });

  final CalendarWeek week;
  final List<ICalEvent> events;

  static const _hourHeight = 64.0;
  static const _gutterWidth = 40.0;
  static const _endHour = 21;

  /// Früheste Startzeit aller Events, mindestens 8 Uhr.
  int _startHour() {
    int min = 8;
    for (final e in events) {
      final h = e.start?.localValue?.hour;
      if (h != null && h < min) min = h;
    }
    return min;
  }

  @override
  Widget build(BuildContext context) {
    final days = week.weekdaysMonToFri;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Column(
      children: [
        _DayHeader(days: days, today: todayDate),
        Expanded(
          child: SingleChildScrollView(
            child: _TimeGrid(
              days: days,
              events: events,
              today: todayDate,
              hourHeight: _hourHeight,
              gutterWidth: _gutterWidth,
              startHour: _startHour(),
              endHour: _endHour,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Day header row ────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.days, required this.today});

  final List<DateTime> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shortDay = DateFormat('EEE', 'de');

    return Container(
      color: cs.surfaceContainerLow,
      child: Row(
        children: [
          const SizedBox(width: WeekCalendarView._gutterWidth),
          ...days.map((d) {
            final isToday =
                d.year == today.year && d.month == today.month && d.day == today.day;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shortDay.format(d).toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isToday ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: isToday
                          ? BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      alignment: Alignment.center,
                      child: Text(
                        '${d.day}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isToday ? cs.onPrimary : cs.onSurface,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Layout record für überlappende Events ─────────────────────────────────────

class _EventLayout {
  const _EventLayout(this.event, this.column, this.totalColumns);

  final ICalEvent event;

  /// 0-basierter Spalten-Index innerhalb der Überlappungsgruppe.
  final int column;

  /// Gesamtanzahl nebeneinander angezeigter Spalten für diesen Tag.
  final int totalColumns;
}

// ── Time grid ─────────────────────────────────────────────────────────────────

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.days,
    required this.events,
    required this.today,
    required this.hourHeight,
    required this.gutterWidth,
    required this.startHour,
    required this.endHour,
  });

  final List<DateTime> days;
  final List<ICalEvent> events;
  final DateTime today;
  final double hourHeight;
  final double gutterWidth;
  final int startHour;
  final int endHour;

  double get _totalHeight => (endHour - startHour) * hourHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = (constraints.maxWidth - gutterWidth) / days.length;
        return SizedBox(
          height: _totalHeight,
          child: Stack(
            children: [
              _HourGrid(
                startHour: startHour,
                endHour: endHour,
                hourHeight: hourHeight,
                gutterWidth: gutterWidth,
              ),
              Row(
                children: [
                  SizedBox(width: gutterWidth),
                  ...days.map((day) {
                    final layouts = _layoutEventsForDay(day);
                    return SizedBox(
                      width: colWidth,
                      height: _totalHeight,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: layouts
                            .map((l) => _EventBlock(
                                  layout: l,
                                  startHour: startHour,
                                  endHour: endHour,
                                  hourHeight: hourHeight,
                                  colWidth: colWidth,
                                ))
                            .toList(),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Gibt Events für einen Tag mit Spalten-Zuweisung zurück.
  ///
  /// Greedy-Algorithmus: Jedes Event bekommt die erste freie Spalte, in der
  /// kein anderes Event zur selben Zeit läuft. So werden Überlappungen
  /// nebeneinander statt übereinander dargestellt.
  List<_EventLayout> _layoutEventsForDay(DateTime day) {
    final dayEvents = events.where((e) {
      final d = e.start?.localValue;
      if (d == null) return false;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();

    if (dayEvents.isEmpty) return [];

    dayEvents.sort((a, b) =>
        _minutes(a.start?.localValue).compareTo(_minutes(b.start?.localValue)));

    // colEnds[i] = Ende-Minute des zuletzt zugewiesenen Events in Spalte i.
    final colEnds = <int>[];
    final assignments = <int>[];

    for (final e in dayEvents) {
      final startMin = _minutes(e.start?.localValue);
      int col = colEnds.indexWhere((end) => end <= startMin);
      if (col == -1) {
        col = colEnds.length;
        colEnds.add(0);
      }
      final endMin = e.end?.localValue != null
          ? _minutes(e.end!.localValue)
          : startMin + 60;
      colEnds[col] = endMin;
      assignments.add(col);
    }

    final total = colEnds.length;
    return List.generate(
      dayEvents.length,
      (i) => _EventLayout(dayEvents[i], assignments[i], total),
    );
  }

  static int _minutes(DateTime? dt) =>
      dt == null ? 0 : dt.hour * 60 + dt.minute;
}

// ── Hour grid lines ───────────────────────────────────────────────────────────

class _HourGrid extends StatelessWidget {
  const _HourGrid({
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.gutterWidth,
  });

  final int startHour;
  final int endHour;
  final double hourHeight;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    final dividerColor =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Stack(
      children: [
        for (int h = startHour; h < endHour; h++) ...[
          Positioned(
            top: (h - startHour) * hourHeight,
            left: 0,
            right: 0,
            child: Divider(height: 1, color: dividerColor),
          ),
          Positioned(
            top: (h - startHour) * hourHeight + 2,
            left: 0,
            width: gutterWidth,
            child: Text(
              '${h.toString().padLeft(2, '0')}:00',
              textAlign: TextAlign.center,
              style: labelStyle,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Single event block ────────────────────────────────────────────────────────

class _EventBlock extends StatelessWidget {
  const _EventBlock({
    required this.layout,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.colWidth,
  });

  final _EventLayout layout;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double colWidth;

  ICalEvent get event => layout.event;

  static const _palette = [
    Color(0xFF1A6B4A), // teal-green
    Color(0xFF4A3F8C), // indigo
    Color(0xFF8C3A1A), // burnt orange
    Color(0xFF1A4A6B), // steel blue
    Color(0xFF6B1A4A), // plum
    Color(0xFF4A6B1A), // olive
    Color(0xFF6B4A1A), // brown
    Color(0xFF1A6B6B), // cyan-teal
  ];

  Color _colorForSummary(String? summary) {
    if (summary == null) return _palette[0];
    return _palette[summary.hashCode.abs() % _palette.length];
  }

  void _showDetail(BuildContext context) {
    final start = event.start?.localValue;
    final end = event.end?.localValue;
    final timeFmt = DateFormat('HH:mm');
    final cs = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          event.summary ?? 'Termin',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (start != null)
              _DetailRow(
                icon: Icons.access_time_rounded,
                text: end != null
                    ? '${timeFmt.format(start)} – ${timeFmt.format(end)}'
                    : timeFmt.format(start),
                color: cs.primary,
              ),
            if (event.location != null) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.room_rounded,
                text: event.location!,
                color: cs.secondary,
              ),
            ],
            if (event.description != null &&
                event.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.info_outline_rounded,
                text: event.description!.trim(),
                color: cs.tertiary,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = event.start?.localValue;
    final end = event.end?.localValue;
    if (start == null) return const SizedBox.shrink();

    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes =
        end != null ? end.hour * 60 + end.minute : startMinutes + 60;

    final top = (startMinutes - startHour * 60) * hourHeight / 60;
    final height =
        ((endMinutes - startMinutes) * hourHeight / 60).clamp(20.0, double.infinity);

    if (top + height < 0 || top > (endHour - startHour) * hourHeight) {
      return const SizedBox.shrink();
    }

    final eventWidth = colWidth / layout.totalColumns;
    final left = layout.column * eventWidth + 1;

    final bg = _colorForSummary(event.summary);
    final fg = Colors.white;
    final timeFormat = DateFormat('HH:mm');

    return Positioned(
      top: top,
      left: left,
      width: eventWidth - 2,
      height: height,
      child: GestureDetector(
        onTap: () => _showDetail(context),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.summary ?? '',
                style: TextStyle(
                  color: fg,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (height > 28 && event.location != null)
                Text(
                  event.location!,
                  style: TextStyle(
                      color: fg.withValues(alpha: 0.85),
                      fontSize: 9,
                      height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (height > 40 && end != null)
                Text(
                  '${timeFormat.format(start)}–${timeFormat.format(end)}',
                  style: TextStyle(
                      color: fg.withValues(alpha: 0.75),
                      fontSize: 9,
                      height: 1.2),
                ),
            ],
          ),
        ),
      ),
    );
  }

}

// ── Detail-Dialog Hilfswidget ─────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
