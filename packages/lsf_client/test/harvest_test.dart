import 'package:lsf_client/lsf_client.dart';
import 'package:test/test.dart';

void main() {
  group('extractAsi', () {
    test('liest Token bis zum Anführungszeichen', () {
      const html = '<a href="rds?state=wscheck&asi=qeCs1io\$3tyfeCsZH.yv">L</a>';
      expect(extractAsi(html), r'qeCs1io$3tyfeCsZH.yv');
    });
    test('null wenn keins vorhanden', () {
      expect(extractAsi('<html>kein token</html>'), isNull);
    });
  });

  group('extractTermineIds', () {
    test('aus iCal-Link (Reihenfolge: termine vor moduleCall)', () {
      const html =
          '<a href="rds?state=verpublish&termine=649105,636662&moduleCall=iCalendarPlan&x=1">iCal</a>';
      expect(extractTermineIds(html), ['649105', '636662']);
    });

    test('aus iCal-Link (Reihenfolge: moduleCall vor termine)', () {
      const html =
          "<a href='rds?moduleCall=iCalendarPlan&foo=bar&termine=111,222'>iCal</a>";
      expect(extractTermineIds(html), ['111', '222']);
    });

    test('ignoriert lose termine= wenn echte iCal-Links existieren', () {
      const html =
          '<a href="rds?termine=649105&moduleCall=iCalendarPlan">a</a>'
          '<a href="rds?termine=999">b</a>';
      expect(extractTermineIds(html), ['649105']);
    });

    test('Fallback: nutzt lose termine= wenn keine iCal-Links da sind', () {
      expect(extractTermineIds('<a href="rds?termine=999">b</a>'), ['999']);
    });
  });

  group('extractPublishIds', () {
    test('sammelt IDs, ignoriert 0', () {
      const html =
          '<a href="rds?publishid=230957">a</a><a href="rds?publishid=0">b</a>'
          '<a href="rds?publishid=231293">c</a>';
      expect(extractPublishIds(html), ['230957', '231293']);
    });
  });
}
