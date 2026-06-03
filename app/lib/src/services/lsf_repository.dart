import 'package:lsf_client/lsf_client.dart';

import 'credential_store.dart';

/// Dünne Hülle um `lsf_client`: loggt ein, holt die Termine via iCal (stabiler
/// als HTML-Parsing) und schließt die Session wieder.
class LsfRepository {
  LsfRepository({CredentialStore? credentials})
    : _credentials = credentials ?? CredentialStore();

  final CredentialStore _credentials;

  /// Holt die Termine der angegebenen (oder aktuellen) Woche.
  ///
  /// Wirft [NotAuthenticatedException], wenn keine Zugangsdaten gespeichert
  /// sind, bzw. [LoginFailedException] bei falschen Daten.
  Future<List<ICalEvent>> fetchEvents({CalendarWeek? week}) async {
    final creds = await _credentials.read();
    if (creds == null) {
      throw NotAuthenticatedException('Keine Zugangsdaten gespeichert.');
    }
    return _withClient((client) async {
      await client.login(creds.username, creds.password);
      return client.fetchICalEvents(week: week);
    });
  }

  /// Prüft Zugangsdaten durch einen Login-Versuch (für den Login-Screen).
  Future<void> verifyLogin(String username, String password) async {
    await _withClient((client) => client.login(username, password));
  }

  Future<T> _withClient<T>(Future<T> Function(LsfClient) action) async {
    final client = LsfClient();
    try {
      return await action(client);
    } finally {
      client.close();
    }
  }
}
