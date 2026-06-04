/**
 * Cloudflare Worker: transparenter CORS-Proxy für lsf.htw-berlin.de + www.stw.berlin.
 *
 * Virtuelle Redirects: bei 3xx-Antworten gibt der Worker HTTP 200 zurück,
 * echter Status in X-Proxy-Status, Ziel in X-Proxy-Location.
 * Dart-WebLsfTransport liest X-Proxy-Status und folgt Redirects manuell.
 *
 * Deploy:  cd worker && npx wrangler deploy
 */

const ALLOW_HOSTS = new Set(['lsf.htw-berlin.de', 'www.stw.berlin']);

const CORS = (origin) => ({
  'Access-Control-Allow-Origin': origin || '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Proxy-Cookie, X-Proxy-UA, Accept',
  'Access-Control-Expose-Headers': 'X-Proxy-Status, X-Proxy-Set-Cookie, X-Proxy-Location',
  'Access-Control-Max-Age': '86400',
});

export default {
  async fetch(request) {
    const origin = request.headers.get('Origin') || '*';

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS(origin) });
    }

    const target = new URL(request.url).searchParams.get('url');
    if (!target) {
      return new Response('missing url', { status: 400, headers: CORS(origin) });
    }

    let t;
    try { t = new URL(target); } catch (_) {
      return new Response('bad url', { status: 400, headers: CORS(origin) });
    }
    if (!ALLOW_HOSTS.has(t.hostname)) {
      return new Response('host not allowed', { status: 403, headers: CORS(origin) });
    }

    // Upstream-Headers aufbauen
    const fwd = new Headers();
    fwd.set('User-Agent', request.headers.get('X-Proxy-UA') || 'HTW Center/0.1');
    fwd.set('Accept', request.headers.get('Accept') || 'text/html,*/*');
    const cookie = request.headers.get('X-Proxy-Cookie');
    if (cookie) fwd.set('Cookie', cookie);

    // fetchOptions ohne body für GET/HEAD (Cloudflare wirft bei body:null + GET)
    const fetchOptions = { method: request.method, headers: fwd, redirect: 'manual' };
    if (request.method === 'POST' || request.method === 'PUT' || request.method === 'PATCH') {
      fetchOptions.body = await request.text();
      fwd.set('Content-Type',
        request.headers.get('Content-Type') ||
        'application/x-www-form-urlencoded; charset=utf-8');
    }

    let upstream;
    try {
      upstream = await fetch(t.toString(), fetchOptions);
    } catch (err) {
      return new Response('upstream fetch failed: ' + String(err), {
        status: 502, headers: CORS(origin),
      });
    }

    // Antwort zusammenstellen
    const out = new Headers(CORS(origin));
    out.set('X-Proxy-Status', String(upstream.status));

    // Set-Cookie weiterleiten (getSetCookie unterstützt mehrere Header)
    try {
      const sc = upstream.headers.getSetCookie
        ? upstream.headers.getSetCookie()
        : [upstream.headers.get('set-cookie')].filter(Boolean);
      if (sc.length > 0) out.set('X-Proxy-Set-Cookie', sc.join('\n'));
    } catch (_) { /* ignorieren falls getSetCookie nicht verfügbar */ }

    const isRedirect = upstream.status === 301 || upstream.status === 302 ||
                       upstream.status === 303 || upstream.status === 307 ||
                       upstream.status === 308;

    if (isRedirect) {
      // Virtueller Redirect: 200 zurück, Dart folgt X-Proxy-Location manuell
      const loc = upstream.headers.get('Location');
      if (loc) out.set('X-Proxy-Location', loc);
      return new Response(null, { status: 200, headers: out });
    }

    const ct = upstream.headers.get('Content-Type');
    if (ct) out.set('Content-Type', ct);
    return new Response(upstream.body, { status: 200, headers: out });
  },
};
