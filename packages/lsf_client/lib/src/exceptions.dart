/// Basisklasse für alle Fehler dieser Bibliothek.
class LsfException implements Exception {
  LsfException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'LsfException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Login fehlgeschlagen (falsche Zugangsdaten, Formular nicht gefunden o.ä.).
class LoginFailedException extends LsfException {
  LoginFailedException(super.message, {super.cause});
}

/// Es wird eine aktive Session benötigt, aber es ist keine vorhanden.
class NotAuthenticatedException extends LsfException {
  NotAuthenticatedException([super.message = 'Nicht eingeloggt.']);
}

/// Eine Antwort des Servers konnte nicht wie erwartet geparst werden.
class LsfParseException extends LsfException {
  LsfParseException(super.message, {super.cause});
}

/// Netzwerk-/Transportfehler beim Kontakt mit dem LSF-Server.
class LsfTransportException extends LsfException {
  LsfTransportException(super.message, {super.cause});
}
