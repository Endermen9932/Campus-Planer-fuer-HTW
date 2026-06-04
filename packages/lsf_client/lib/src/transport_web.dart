import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'transport.dart';

LsfTransport createTransport({String proxyBase = ''}) =>
    WebLsfTransport(proxyBase: proxyBase);

/// Web-Transport: nutzt `package:http` und leitet Anfragen über einen
/// Cloudflare-Worker-Proxy, der CORS-Header setzt und Cookies über
/// Custom-Header transportiert (iOS Safari blockt Third-Party-Cookies).
///
/// Protokoll:
///   Request:  `X-Proxy-Cookie: name=val; name2=val2`  (eigene Jar)
///             `X-Proxy-UA: <user-agent>`
///   Response: `X-Proxy-Set-Cookie: <raw>\n<raw>` (Worker joiniert mehrere)
///             `X-Proxy-Location: <url>` (bei Redirects, zuverlässiger als Location)
///   Worker folgt Redirects NICHT (`redirect: 'manual'`) – Dart-Seite folgt manuell,
///   damit die Jar über jeden Redirect-Hop erhalten bleibt (JSESSIONID nach Login-POST).
class WebLsfTransport implements LsfTransport {
  WebLsfTransport({required this.proxyBase, this.maxRedirects = 10})
      : _client = http.Client();

  final String proxyBase;
  final int maxRedirects;
  final http.Client _client;
  final Map<String, String> _jar = {};

  static const _ua =
      'Mozilla/5.0 (compatible; HTW Center/0.1; +https://github.com/endermen9932/htw_center)';

  @override
  Future<LsfResponse> get(Uri url) => _send('GET', url);

  @override
  Future<LsfResponse> postForm(Uri url, Map<String, String> fields) =>
      _send('POST', url, fields: fields);

  Uri _proxy(Uri target) => Uri.parse(
      '$proxyBase/?url=${Uri.encodeQueryComponent(target.toString())}');

  String _cookieHeader() =>
      _jar.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<LsfResponse> _send(
    String method,
    Uri url, {
    Map<String, String>? fields,
    int redirectCount = 0,
  }) async {
    final headers = <String, String>{
      'Accept': 'text/html,*/*',
      'X-Proxy-UA': _ua,
      if (_jar.isNotEmpty) 'X-Proxy-Cookie': _cookieHeader(),
    };
    try {
      late http.Response res;
      final proxied = _proxy(url);
      if (method == 'POST') {
        headers['Content-Type'] =
            'application/x-www-form-urlencoded; charset=utf-8';
        final encoded = fields == null
            ? null
            : fields.entries
                .map((e) =>
                    '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
                .join('&');
        res = await _client.post(proxied, headers: headers, body: encoded);
      } else {
        res = await _client.get(proxied, headers: headers);
      }

      final setCookie = res.headers['x-proxy-set-cookie'];
      if (setCookie != null) _storeCookies(setCookie);

      if (_isRedirect(res.statusCode) && redirectCount < maxRedirects) {
        final loc =
            res.headers['x-proxy-location'] ?? res.headers['location'];
        if (loc != null) {
          final next = url.resolve(loc);
          final keepMethod =
              res.statusCode == 307 || res.statusCode == 308;
          return _send(
            keepMethod ? method : 'GET',
            next,
            fields: keepMethod ? fields : null,
            redirectCount: redirectCount + 1,
          );
        }
      }

      final ct = (res.headers['content-type'] ?? '').toLowerCase();
      final body =
          (ct.contains('iso-8859-1') || ct.contains('latin1') || ct.contains('iso8859-1'))
              ? latin1.decode(res.bodyBytes)
              : utf8.decode(res.bodyBytes, allowMalformed: true);

      return LsfResponse(statusCode: res.statusCode, body: body, finalUri: url);
    } on http.ClientException catch (e) {
      throw LsfTransportException('Netzwerkfehler bei $url', cause: e);
    }
  }

  bool _isRedirect(int code) =>
      code == 301 || code == 302 || code == 303 || code == 307 || code == 308;

  // Worker joiniert mehrere Set-Cookie-Header per Newline.
  void _storeCookies(String raw) {
    for (final line in raw.split('\n')) {
      final first = line.split(';').first.trim();
      final eq = first.indexOf('=');
      if (eq > 0) _jar[first.substring(0, eq)] = first.substring(eq + 1);
    }
  }

  @override
  void close() => _client.close();
}
