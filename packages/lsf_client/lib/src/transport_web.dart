import 'dart:convert';

// ignore: avoid_print
import 'dart:developer' as dev;

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
///   Response (Worker gibt IMMER HTTP 200 zurück):
///             `X-Proxy-Status:     <echter HTTP-Status>`
///             `X-Proxy-Set-Cookie: <raw>\n<raw>` (Worker joiniert mehrere)
///             `X-Proxy-Location:   <url>` (bei Redirects)
///   Redirects: Worker gibt 200 + X-Proxy-Status: 302 → Browser folgt NICHT
///   automatisch → Dart liest X-Proxy-Status und folgt manuell.
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
    final sentJarKeys = _jar.keys.join(', ');
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

      // Debug: show what cookies were sent and what the Worker+LSF saw/set.
      final dbgRecv = res.headers['x-debug-recv-cookie'];
      final dbgKeys = res.headers['x-debug-set-cookie-keys'];
      dev.log(
        '[LsfTransport] $method ${url.path}'
        '\n  → jar keys before request: $sentJarKeys'
        '\n  ← worker echoed X-Proxy-Cookie: $dbgRecv'
        '\n  ← LSF set-cookie keys: $dbgKeys'
        '\n  ← jar keys after: ${_jar.keys.join(', ')}',
        name: 'lsf',
      );

      // Worker gibt immer HTTP 200; echter Status steckt in X-Proxy-Status.
      final proxyStatus =
          int.tryParse(res.headers['x-proxy-status'] ?? '') ?? res.statusCode;

      if (_isRedirect(proxyStatus) && redirectCount < maxRedirects) {
        final loc = res.headers['x-proxy-location'];
        if (loc != null) {
          final next = url.resolve(loc);
          final keepMethod = proxyStatus == 307 || proxyStatus == 308;
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

      return LsfResponse(statusCode: proxyStatus, body: body, finalUri: url);
    } on http.ClientException catch (e) {
      throw LsfTransportException('Netzwerkfehler bei $url', cause: e);
    }
  }

  bool _isRedirect(int code) =>
      code == 301 || code == 302 || code == 303 || code == 307 || code == 308;

  // Worker sendet "name=value; name2=value2" ('; '-getrennte name=value-Paare).
  void _storeCookies(String raw) {
    for (final pair in raw.split('; ')) {
      final eq = pair.indexOf('=');
      if (eq > 0) _jar[pair.substring(0, eq)] = pair.substring(eq + 1);
    }
  }

  @override
  void close() => _client.close();
}
