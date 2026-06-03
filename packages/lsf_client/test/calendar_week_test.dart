import 'package:lsf_client/lsf_client.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarWeek', () {
    test('param-Format', () {
      expect(const CalendarWeek(23, 2026).param, '23_2026');
    });

    test('parse', () {
      expect(CalendarWeek.parse('23_2026'), const CalendarWeek(23, 2026));
    });

    test('fromDate: 2026-06-03 ist KW 23 (vgl. Screenshot week=23_2026)', () {
      expect(CalendarWeek.fromDate(DateTime(2026, 6, 3)),
          const CalendarWeek(23, 2026));
    });

    test('fromDate: Jahresgrenze 2025-12-29 gehört zu KW 1/2026', () {
      expect(CalendarWeek.fromDate(DateTime(2025, 12, 29)),
          const CalendarWeek(1, 2026));
    });

    test('next / previous innerhalb des Jahres', () {
      expect(const CalendarWeek(23, 2026).next, const CalendarWeek(24, 2026));
      expect(
          const CalendarWeek(23, 2026).previous, const CalendarWeek(22, 2026));
    });

    test('previous über Jahresgrenze (KW 1/2026 -> letzte Woche 2025)', () {
      final prev = const CalendarWeek(1, 2026).previous;
      expect(prev.year, 2025);
      expect(prev.week, anyOf(52, 53));
    });

    test('round-trip next.previous', () {
      const w = CalendarWeek(10, 2026);
      expect(w.next.previous, w);
    });

    test('current liefert eine plausible Woche', () {
      expect(CalendarWeek.current().week, inInclusiveRange(1, 53));
    });
  });
}
