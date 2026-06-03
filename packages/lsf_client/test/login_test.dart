import 'dart:io';

import 'package:lsf_client/lsf_client.dart';
import 'package:test/test.dart';

void main() {
  final html = File('test/fixtures/login_page.html').readAsStringSync();

  group('LoginForm.parse', () {
    final form = LoginForm.parse(html);

    test('wählt das Formular mit Passwortfeld (nicht die Suche)', () {
      expect(form.actionPath, 'rds');
      expect(form.fields.containsKey('q'), isFalse);
    });

    test('erkennt verschleierte Benutzer-/Passwortfelder per type', () {
      expect(form.usernameField, 'asdf');
      expect(form.passwordField, 'fdsa');
    });

    test('behält versteckte Felder mit ihren Werten', () {
      expect(form.fields['asdf2x9'], 'qswer');
      expect(form.fields['fdsa7k1'], 'rewqs');
      expect(form.fields['submit'], 'Anmelden');
    });

    test('nimmt nicht-angehakte Checkboxen NICHT auf', () {
      expect(form.fields.containsKey('remember'), isFalse);
    });

    test('buildBody setzt Zugangsdaten und erhält Hidden-Felder', () {
      final body = form.buildBody('s0500001', 'geheim!');
      expect(body['asdf'], 's0500001');
      expect(body['fdsa'], 'geheim!');
      expect(body['asdf2x9'], 'qswer'); // unverändert
      expect(body['submit'], 'Anmelden');
    });

    test('wirft, wenn kein Login-Formular vorhanden', () {
      expect(() => LoginForm.parse('<html><form><input name="x"></form></html>'),
          throwsA(isA<LoginFailedException>()));
    });
  });

  group('looksLoggedIn', () {
    test('true bei asi-Token / Logout-Link', () {
      expect(
          looksLoggedIn('<a href="rds?asi=abc123.def">x</a>'), isTrue);
      expect(
          looksLoggedIn('<a href="rds?state=user&category=auth.logout">Abmelden</a>'),
          isTrue);
    });
    test('false bei Fehlermeldung', () {
      expect(
          looksLoggedIn('<p>Anmeldung fehlgeschlagen</p> asi=x'), isFalse);
    });
    test('false bei nackter Login-Seite', () {
      expect(looksLoggedIn('<form><input type="password"></form>'), isFalse);
    });
  });
}
