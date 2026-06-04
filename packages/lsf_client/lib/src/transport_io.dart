import 'dart:convert';
import 'dart:io';

import 'exceptions.dart';
import 'transport.dart';

LsfTransport createTransport({String proxyBase = ''}) => IoLsfTransport();

/// `dart:io`-basierte Implementierung mit eigenem Cookie-Jar und manuellem
/// Redirect-Following (damit `Set-Cookie` über Redirects hinweg zuverlässig
/// übernommen wird).
class IoLsfTransport implements LsfTransport {
  IoLsfTransport({HttpClient? client, this.maxRedirects = 10})
      : _client = client ?? HttpClient() {
    _client.userAgent =
        'Mozilla/5.0 (compatible; HTW Center/0.1; +https://github.com/endermen9932/htw_center)';
  }

  final HttpClient _client;
  final int maxRedirects;
  final Map<String, Cookie> _jar = {};

  @override
  Future<LsfResponse> get(Uri url) => _send('GET', url);

  @override
  Future<LsfResponse> postForm(Uri url, Map<String, String> fields) =>
      _send('POST', url, formFields: fields);

  Future<LsfResponse> _send(
    String method,
    Uri url, {
    Map<String, String>? formFields,
    int redirectCount = 0,
  }) async {
    try {
      final request = await _client.openUrl(method, url);
      request.followRedirects = false;
      request.cookies.addAll(_jar.values);
      request.headers.set(HttpHeaders.acceptHeader, 'text/html,*/*');

      if (formFields != null) {
        final encoded = formFields.entries
            .map((e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
            .join('&');
        request.headers.contentType = ContentType(
            'application', 'x-www-form-urlencoded',
            charset: 'utf-8');
        request.write(encoded);
      }

      final response = await request.close();
      _storeCookies(response.cookies);

      if (_isRedirect(response.statusCode) && redirectCount < maxRedirects) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location != null) {
          final next = url.resolve(location);
          final keepMethod =
              response.statusCode == 307 || response.statusCode == 308;
          return _send(
            keepMethod ? method : 'GET',
            next,
            formFields: keepMethod ? formFields : null,
            redirectCount: redirectCount + 1,
          );
        }
      }

      final body = await _readBody(response);
      return LsfResponse(
        statusCode: response.statusCode,
        body: body,
        finalUri: url,
      );
    } on SocketException catch (e) {
      throw LsfTransportException('Netzwerkfehler bei $url', cause: e);
    } on HttpException catch (e) {
      throw LsfTransportException('HTTP-Fehler bei $url', cause: e);
    }
  }

  bool _isRedirect(int code) =>
      code == 301 || code == 302 || code == 303 || code == 307 || code == 308;

  void _storeCookies(List<Cookie> cookies) {
    for (final c in cookies) {
      _jar[c.name] = c;
    }
  }

  Future<String> _readBody(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    final charset = response.headers.contentType?.charset?.toLowerCase();
    if (charset == 'iso-8859-1' ||
        charset == 'latin1' ||
        charset == 'iso8859-1') {
      return latin1.decode(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  void close() => _client.close(force: true);
}
