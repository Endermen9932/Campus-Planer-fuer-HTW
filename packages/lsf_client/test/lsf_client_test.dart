import 'dart:io';

import 'package:lsf_client/lsf_client.dart';
import 'package:test/test.dart';

/// Fake-Transport: liefert kanonierte Antworten je nach angefragter URL,
/// ganz ohne Netzwerk.
class FakeLsfTransport implements LsfTransport {
  FakeLsfTransport(this.handler);

  final LsfResponse Function(String method, Uri url, Map<String, String>? body)
      handler;
  final List<Uri> requests = [];

  @override
  Future<LsfResponse> get(Uri url) async {
    requests.add(url);
    return handler('GET', url, null);
  }

  @override
  Future<LsfResponse> postForm(Uri url, Map<String, String> fields) async {
    requests.add(url);
    return handler('POST', url, fields);
  }

  @override
  void close() {}
}

LsfResponse _ok(String body, Uri url) =>
    LsfResponse(statusCode: 200, body: body, finalUri: url);

void main() {
  final loginHtml = File('test/fixtures/login_page.html').readAsStringSync();
  final ics = File('test/fixtures/plan.ics').readAsStringSync();

  const timetableHtml =
      '<a href="rds?state=verpublish&termine=649105,636662&moduleCall=iCalendarPlan">iCal</a>'
      ' <a href="rds?asi=TOKEN123">x</a>';
  const loggedInHtml =
      '<a href="rds?state=user&type=4&category=auth.logout">Abmelden</a>'
      ' <a href="rds?asi=TOKEN123">x</a>';

  LsfClient buildClient({bool loginSucceeds = true}) {
    LsfResponse handler(String method, Uri url, Map<String, String>? body) {
      final qp = url.queryParameters;
      if (qp['moduleCall'] == 'iCalendarPlan') return _ok(ics, url);
      if (qp['state'] == 'wplan') return _ok(timetableHtml, url);
      if (method == 'POST') {
        return _ok(
          loginSucceeds ? loggedInHtml : '<p>Anmeldung fehlgeschlagen</p>',
          url,
        );
      }
      if (qp['state'] == 'user' && qp['type'] == '1') {
        return _ok(loginHtml, url);
      }
      return _ok('<html></html>', url);
    }

    return LsfClient(transport: FakeLsfTransport(handler));
  }

  group('LsfClient', () {
    test('verlangt Login vor Datenabruf', () async {
      final client = buildClient();
      await expectLater(
        client.fetchTimetable(),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test('Login erfolgreich: setzt Status und asi-Token', () async {
      final client = buildClient();
      await client.login('s0500001', 'geheim');
      expect(client.isAuthenticated, isTrue);
      expect(client.asi, 'TOKEN123');
    });

    test('Login fehlgeschlagen: wirft LoginFailedException', () async {
      final client = buildClient(loginSucceeds: false);
      await expectLater(
        client.login('s0500001', 'falsch'),
        throwsA(isA<LoginFailedException>()),
      );
    });

    test('fetchICalEvents: Planseite -> termine -> iCal -> Events', () async {
      final client = buildClient();
      await client.login('s0500001', 'geheim');
      final events = await client.fetchICalEvents();
      expect(events, hasLength(3));
      expect(events.first.summary, 'K12 Mathematik 2 (SL)');
    });

    test('Logout verwirft die Session', () async {
      final client = buildClient();
      await client.login('s0500001', 'geheim');
      await client.logout();
      expect(client.isAuthenticated, isFalse);
      expect(client.asi, isNull);
    });
  });
}
