import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lsf_client/lsf_client.dart';

/// Wochenkalender-Ansicht: Montag–Freitag als Spalten mit Stunden-Zeitraster.
///
/// Jeder Tag zeigt die zugehörigen [ICalEvent]-Blöcke positioniert nach
/// Startzeit. Der heutige Tag wird in der Kopfzeile hervorgehoben.
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
  static const _startHour = 7;
  static const _endHour = 21;

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
              startHour: _startHour,
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
          // Gutter placeholder
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
              // Hour grid lines + gutter labels
              _HourGrid(
                startHour: startHour,
                endHour: endHour,
                hourHeight: hourHeight,
                gutterWidth: gutterWidth,
              ),
              // Event blocks per day
              Row(
                children: [
                  SizedBox(width: gutterWidth),
                  ...days.map((day) {
                    final dayEvents = _eventsForDay(day);
                    return SizedBox(
                      width: colWidth,
                      height: _totalHeight,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: dayEvents
                            .map((e) => _EventBlock(
                                  event: e,
                                  startHour: startHour,
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

  List<ICalEvent> _eventsForDay(DateTime day) {
    return events.where((e) {
      final d = e.start?.localValue;
      if (d == null) return false;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }
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
    required this.event,
    required this.startHour,
    required this.hourHeight,
    required this.colWidth,
  });

  final ICalEvent event;
  final int startHour;
  final double hourHeight;
  final double colWidth;

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

  @override
  Widget build(BuildContext context) {
    final start = event.start?.localValue;
    final end = event.end?.localValue;
    if (start == null) return const SizedBox.shrink();

    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end != null
        ? end.hour * 60 + end.minute
        : startMinutes + 60;

    final top = (startMinutes - startHour * 60) * hourHeight / 60;
    final height =
        ((endMinutes - startMinutes) * hourHeight / 60).clamp(20.0, double.infinity);

    // Don't render blocks outside the visible grid
    if (top + height < 0 || top > (22 - startHour) * hourHeight) {
      return const SizedBox.shrink();
    }

    final bg = _colorForSummary(event.summary);
    final fg = Colors.white;
    final timeFormat = DateFormat('HH:mm');

    return Positioned(
      top: top,
      left: 1,
      right: 1,
      height: height,
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
                style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 9, height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (height > 40 && end != null)
              Text(
                '${timeFormat.format(start)}–${timeFormat.format(end)}',
                style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 9, height: 1.2),
              ),
          ],
        ),
      ),
    );
  }
}
