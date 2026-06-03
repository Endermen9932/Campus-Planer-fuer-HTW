import 'package:lsf_client/lsf_client.dart';
import 'package:test/test.dart';

void main() {
  group('parseLessonBlock (reale Textblöcke aus dem LSF)', () {
    test('Standard-Veranstaltung mit Modulkürzel', () {
      const block = 'K12 Mathematik 2 (SL)\n'
          '6 SWS   deutsch\n'
          'Montag, 11:30 - 15:30 , wöch\n'
          'Seminaristischer Lehrvortrag, Raum: WH C 351';
      final l = TimetableHtmlParser.parseLessonBlock(block);
      expect(l.title, 'K12 Mathematik 2 (SL)');
      expect(l.courseNumber, 'K12');
      expect(l.type, 'SL');
      expect(l.sws, 6);
      expect(l.language, 'deutsch');
      expect(l.day, 'Montag');
      expect(l.startTime, '11:30');
      expect(l.endTime, '15:30');
      expect(l.rhythm, 'wöch');
      expect(l.room, 'WH C 351');
    });

    test('14-täglich, Umlaute im Typ', () {
      const block =
          'K22 Fortgeschrittene Algorithmen und Programmierung (PCÜ)\n'
          '2 SWS   deutsch\n'
          'Mittwoch,  09:45 - 13:00 , 14tägl\n'
          'PC-Übung, Raum: WH F 225';
      final l = TimetableHtmlParser.parseLessonBlock(block);
      expect(l.courseNumber, 'K22');
      expect(l.type, 'PCÜ');
      expect(l.sws, 2);
      expect(l.day, 'Mittwoch');
      expect(l.startTime, '09:45');
      expect(l.endTime, '13:00');
      expect(l.rhythm, '14tägl');
      expect(l.room, 'WH F 225');
    });

    test('umgebrochener Titel ohne Modulkürzel', () {
      const block = 'English for Information and Communication Engineering,\n'
          'M3Ts (GER B2.2)\n'
          '4 SWS   engl./deutsch\n'
          'Mittwoch, 17:30 - 20:45 , wöch\n'
          'Übung, Raum: WH C 401';
      final l = TimetableHtmlParser.parseLessonBlock(block);
      expect(l.title,
          'English for Information and Communication Engineering, M3Ts (GER B2.2)');
      expect(l.courseNumber, isNull);
      expect(l.language, 'engl./deutsch');
      expect(l.day, 'Mittwoch');
      expect(l.startTime, '17:30');
      expect(l.room, 'WH C 401');
    });
  });

  group('parseTimetable (Best-Effort-DOM, illustratives HTML)', () {
    test('extrahiert Veranstaltung inkl. publishId aus Tabellenzelle', () {
      const html = '<table><tr>'
          '<td>K12 Mathematik 2 (SL)<br>6 SWS&nbsp;&nbsp;deutsch<br>'
          'Montag, 11:30 - 15:30 , wöch<br>'
          'Seminaristischer Lehrvortrag, Raum: WH C 351<br>'
          '<a href="rds?state=verpublish&publishid=231293">Information</a></td>'
          '<td>&nbsp;</td>'
          '</tr></table>';
      final lessons = TimetableHtmlParser.parseTimetable(html);
      expect(lessons, hasLength(1));
      expect(lessons.first.title, 'K12 Mathematik 2 (SL)');
      expect(lessons.first.room, 'WH C 351');
      expect(lessons.first.publishId, '231293');
    });
  });
}
