/// Basis-URL des CORS-Proxys (Cloudflare Worker).
///
/// Auf Web via `--dart-define=PROXY_BASE=https://xxx.workers.dev` gesetzt.
/// Leer auf nativem Code → Direktverbindungen ohne Proxy.
const String kProxyBase = String.fromEnvironment('PROXY_BASE', defaultValue: '');
