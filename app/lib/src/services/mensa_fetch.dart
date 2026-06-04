import 'dart:convert';
import 'dart:io';

import 'mensa_service.dart' show MensaFetchException;

/// Sendet einen POST via `dart:io` (nativ). [proxyBase] wird ignoriert.
Future<String> postMensaHtml(
  String endpoint,
  String body, {
  required String userAgent,
  String proxyBase = '',
}) async {
  final client = HttpClient()..userAgent = userAgent;
  try {
    final request = await client.postUrl(Uri.parse(endpoint));
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write(body);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw MensaFetchException('Server antwortete mit ${response.statusCode}');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  } on SocketException catch (e) {
    throw MensaFetchException('Netzwerkfehler', cause: e);
  } on HttpException catch (e) {
    throw MensaFetchException('HTTP-Fehler', cause: e);
  } finally {
    client.close();
  }
}
