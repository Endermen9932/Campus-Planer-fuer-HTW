import 'dart:io';

import 'package:lsf_client/lsf_client.dart';
import 'package:test/test.dart';

void main() {
  final ics = File('test/fixtures/plan.ics').readAsStringSync();

  group('ICalParser.parse', () {
    final events = ICalParser.parse(ics);

    test('findet alle VEVENTs', () {
      expect(events, hasLength(3));
    });

    test('parst Summary und Location', () {
      expect(events[0].summary, 'K12 Mathematik 2 (SL)');
      expect(events[0].location, 'WH C 351');
      expect(events[0].uid, '649105@lsf.htw-berlin.de');
    });

    test('parst TZID-Zeit als floating local mit tzid', () {
      final start = events[0].start!;
      expect(start.isUtc, isFalse);
      expect(start.tzid, 'Europe/Berlin');
      expect(start.value, DateTime(2026, 6, 1, 11, 30));
      expect(events[0].end!.value, DateTime(2026, 6, 1, 15, 30));
    });

    test('entfaltet gefaltete Zeilen und entschärft Escapes', () {
      final desc = events[0].description!;
      expect(desc, contains('Prof. Dr. Mustermann')); // Unfolding (2 Zeilen)
      expect(desc, contains('Raum: WH C 351'));
      expect(desc, contains(',')); // \, wurde zu ,
      expect(desc, isNot(contains(r'\,')));
    });

    test('übernimmt RRULE roh', () {
      expect(events[0].rrule, 'FREQ=WEEKLY;COUNT=15');
    });

    test('parst UTC-Zeit (Z-Suffix)', () {
      final start = events[1].start!;
      expect(start.isUtc, isTrue);
      expect(start.value, DateTime.utc(2026, 6, 3, 7, 45));
      expect(events[1].summary, contains('PCÜ')); // Unicode
    });

    test('parst reines Datum (VALUE=DATE)', () {
      final start = events[2].start!;
      expect(start.dateOnly, isTrue);
      expect(start.value, DateTime(2026, 5, 25));
    });

    test('wirft bei Nicht-iCal', () {
      expect(() => ICalParser.parse('<html>nope</html>'),
          throwsA(isA<LsfParseException>()));
    });
  });

  group('unescapeText', () {
    test('alle Escape-Sequenzen', () {
      expect(unescapeText(r'a\,b\;c\nd\\e'), 'a,b;c\nd\\e');
    });
  });

  group('parseICalDate', () {
    test('UTC', () {
      final d = parseICalDate('20260603T074500Z');
      expect(d.isUtc, isTrue);
      expect(d.value, DateTime.utc(2026, 6, 3, 7, 45));
    });
    test('floating mit tzid', () {
      final d =
          parseICalDate('20260601T113000', params: {'TZID': 'Europe/Berlin'});
      expect(d.isUtc, isFalse);
      expect(d.tzid, 'Europe/Berlin');
      expect(d.value, DateTime(2026, 6, 1, 11, 30));
    });
    test('date only', () {
      final d = parseICalDate('20260525');
      expect(d.dateOnly, isTrue);
      expect(d.value, DateTime(2026, 5, 25));
    });
    test('wirft bei Müll', () {
      expect(
          () => parseICalDate('not-a-date'), throwsA(isA<LsfParseException>()));
    });
  });
}
