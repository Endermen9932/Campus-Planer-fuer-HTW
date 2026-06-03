import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'exceptions.dart';

/// Geparstes LSF-Login-Formular.
///
/// Der QIS-Server verschleiert die Feldnamen (z.B. heißt das Benutzerfeld oft
/// `asdf` und das Passwortfeld `fdsa`) und enthält versteckte Felder, die
/// unverändert mitgeschickt werden müssen. Wir identifizieren die relevanten
/// Felder daher NICHT über ihren Namen, sondern über ihren `type`:
///
/// * Passwortfeld = `input[type=password]`
/// * Benutzerfeld = erstes sichtbares Textfeld (`type=text` oder ohne `type`)
///
/// Alle übrigen (versteckten) Felder werden 1:1 übernommen.
class LoginForm {
  LoginForm({
    required this.actionPath,
    required this.fields,
    required this.usernameField,
    required this.passwordField,
  });

  /// `action`-Attribut des Formulars (kann relativ/leer sein → dann an die
  /// Login-URL posten).
  final String actionPath;

  /// Alle Formularfelder als Name → Vorbelegung (inkl. versteckte Felder).
  final Map<String, String> fields;

  /// Name des Benutzerfelds (z.B. `asdf` oder `username`).
  final String usernameField;

  /// Name des Passwortfelds (z.B. `fdsa` oder `password`).
  final String passwordField;

  /// Parst die Login-Seite und findet das richtige Formular (das mit einem
  /// Passwortfeld).
  static LoginForm parse(String htmlSource) {
    final doc = html_parser.parse(htmlSource);

    Element? loginForm;
    for (final form in doc.querySelectorAll('form')) {
      if (form.querySelector('input[type=password]') != null) {
        loginForm = form;
        break;
      }
    }
    if (loginForm == null) {
      throw LoginFailedException(
        'Login-Formular nicht gefunden (kein input[type=password]).',
      );
    }

    final fields = <String, String>{};
    String? usernameField;
    String? passwordField;

    for (final input in loginForm.querySelectorAll('input')) {
      final name = input.attributes['name'];
      if (name == null || name.isEmpty) continue;

      final type = (input.attributes['type'] ?? 'text').toLowerCase();
      final value = input.attributes['value'] ?? '';

      switch (type) {
        case 'password':
          passwordField = name;
          fields[name] = value;
        case 'text':
        case 'email':
          usernameField ??= name; // erstes sichtbares Textfeld
          fields[name] = value;
        case 'submit':
        case 'button':
        case 'image':
          // Submit-Buttons mit Namen werden als Feld übernommen (z.B.
          // submit=Anmelden), sind aber kein User-/Passwortfeld.
          fields[name] = value;
        case 'checkbox':
        case 'radio':
          // Nur übernehmen, wenn vorausgewählt.
          if (input.attributes.containsKey('checked')) {
            fields[name] = value;
          }
        default: // hidden u.a.
          fields[name] = value;
      }
    }

    if (passwordField == null) {
      throw LoginFailedException('Kein Passwortfeld im Login-Formular.');
    }
    if (usernameField == null) {
      throw LoginFailedException('Kein Benutzerfeld im Login-Formular.');
    }

    return LoginForm(
      actionPath: loginForm.attributes['action'] ?? '',
      fields: fields,
      usernameField: usernameField,
      passwordField: passwordField,
    );
  }

  /// Baut den abzusendenden Formular-Body mit eingesetzten Zugangsdaten.
  /// Versteckte/verschleierte Felder bleiben erhalten.
  Map<String, String> buildBody(String username, String password) {
    final body = Map<String, String>.from(fields);
    body[usernameField] = username;
    body[passwordField] = password;
    return body;
  }
}

/// Heuristik zur Erkennung, ob eine Antwort-Seite einen erfolgreichen Login
/// zeigt. LSF hat keine eindeutige JSON-Antwort, daher prüfen wir Indizien.
bool looksLoggedIn(String htmlSource) {
  final lower = htmlSource.toLowerCase();
  // Nach dem Login erscheinen Logout-Link und der personalisierte Navigations-
  // baum; ein `asi=`-Token in den Links ist ein starkes Indiz.
  final hasLogout = lower.contains('category=auth.logout') ||
      lower.contains('logout') && lower.contains('abmelden');
  final hasAsi = RegExp(r'asi=[^"&\s]+').hasMatch(htmlSource);
  // Typische Fehlermeldung bei falschen Daten.
  final hasError = lower.contains('anmeldung fehlgeschlagen') ||
      lower.contains('benutzerkennung oder passwort') ||
      lower.contains('login failed');
  if (hasError) return false;
  return hasLogout || hasAsi;
}
