import 'transport_io.dart' if (dart.library.html) 'transport_web.dart' as impl;

/// Eine vereinfachte HTTP-Antwort.
class LsfResponse {
  LsfResponse({
    required this.statusCode,
    required this.body,
    required this.finalUri,
  });

  final int statusCode;
  final String body;

  /// URL nach evtl. Redirects (nützlich, um die aktuelle Session-URL zu sehen).
  final Uri finalUri;

  bool get isOk => statusCode >= 200 && statusCode < 400;
}

/// Abstraktion der HTTP-Schicht, damit Logik gegen einen Fake testbar ist.
abstract class LsfTransport {
  Future<LsfResponse> get(Uri url);
  Future<LsfResponse> postForm(Uri url, Map<String, String> fields);
  void close();
}

/// Erzeugt den plattformgerechten Standard-Transport.
///
/// [proxyBase] wird auf nativem Code ignoriert (Direktverbindung).
/// Auf Web wird jede Anfrage über `$proxyBase/?url=<encoded>` geleitet.
LsfTransport createDefaultTransport({String proxyBase = ''}) =>
    impl.createTransport(proxyBase: proxyBase);
