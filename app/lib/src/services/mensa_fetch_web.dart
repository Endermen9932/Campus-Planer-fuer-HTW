import 'package:http/http.dart' as http;

import 'mensa_service.dart' show MensaFetchException;

/// Sendet einen POST via `package:http` über den CORS-Proxy (Web).
Future<String> postMensaHtml(
  String endpoint,
  String body, {
  required String userAgent,
  String proxyBase = '',
}) async {
  final url = Uri.parse(
      '$proxyBase/?url=${Uri.encodeQueryComponent(endpoint)}');
  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'X-Proxy-UA': userAgent,
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw MensaFetchException('Server antwortete mit ${response.statusCode}');
    }
    return response.body;
  } on http.ClientException catch (e) {
    throw MensaFetchException('Netzwerkfehler', cause: e);
  }
}
