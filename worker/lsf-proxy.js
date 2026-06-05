/**
 * Cloudflare Worker: transparenter CORS-Proxy für lsf.htw-berlin.de + www.stw.berlin.
 *
 * Redirects werden intern verfolgt (gleiche Worker-Instanz = gleiche Cloudflare-Node-IP),
 * damit LSF POST (Login) und nachfolgenden GET als zusammengehörig erkennt und die
 * JSESSIONID-Session nicht verliert.
 * Alle Set-Cookie-Header aller Hops werden gesammelt und über X-Proxy-Set-Cookie
 * an Dart zurückgegeben.
 *
 * Deploy:  cd worker && npx wrangler deploy
 */

const ALLOW_HOSTS = new Set(['lsf.htw-berlin.de', 'www.stw.berlin']);
const MAX_REDIRECTS = 10;

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
    try {
      return await handleRequest(request, origin);
    } catch (err) {
      console.error('Unhandled worker error:', err);
      return new Response('worker error: ' + String(err), {
        status: 500,
        headers: CORS(origin),
      });
    }
  },
};

async function handleRequest(request, origin) {
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
    const clientCookie = request.headers.get('X-Proxy-Cookie');
    if (clientCookie) fwd.set('Cookie', clientCookie);

    let method = request.method;
    let body = null;
    if (method === 'POST' || method === 'PUT' || method === 'PATCH') {
      body = await request.text();
      fwd.set('Content-Type',
        request.headers.get('Content-Type') ||
        'application/x-www-form-urlencoded; charset=utf-8');
    }

    // Redirects intern verfolgen: POST-Login und nachfolgender GET laufen innerhalb
    // derselben Worker-Invokation auf derselben Cloudflare-Node → LSF sieht dieselbe
    // Quell-IP für beide Requests → JSESSIONID bleibt gültig.
    const allSetCookies = [];
    let currentUrl = t;
    let currentMethod = method;
    let currentBody = body;
    let upstream;

    for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
      const fetchOpts = { method: currentMethod, headers: new Headers(fwd), redirect: 'manual' };
      if (currentBody !== null && currentMethod !== 'GET' && currentMethod !== 'HEAD') {
        fetchOpts.body = currentBody;
      }

      try {
        upstream = await fetch(currentUrl.toString(), fetchOpts);
      } catch (err) {
        return new Response('upstream fetch failed: ' + String(err), {
          status: 502, headers: CORS(origin),
        });
      }

      // Set-Cookie dieses Hops sammeln und für nächsten Hop in Cookie-Header einbauen
      try {
        const sc = upstream.headers.getSetCookie
          ? upstream.headers.getSetCookie()
          : [upstream.headers.get('set-cookie')].filter(Boolean);
        for (const raw of sc) {
          allSetCookies.push(raw);
          const nameVal = raw.split(';')[0].trim();
          const eq = nameVal.indexOf('=');
          if (eq > 0) {
            const name = nameVal.substring(0, eq);
            const existing = fwd.get('Cookie') || '';
            const kept = existing
              ? existing.split('; ').filter(p => !p.startsWith(name + '='))
              : [];
            kept.push(nameVal);
            fwd.set('Cookie', kept.join('; '));
          }
        }
      } catch (_) { /* getSetCookie nicht verfügbar */ }

      const isRedirect = [301, 302, 303, 307, 308].includes(upstream.status);
      if (!isRedirect || hop === MAX_REDIRECTS) break;

      const loc = upstream.headers.get('Location');
      if (!loc) break;

      let nextUrl;
      try { nextUrl = new URL(loc, currentUrl); } catch (_) { break; }

      // Nicht-erlaubter Host: virtuellen Redirect zurückgeben, Dart entscheidet
      if (!ALLOW_HOSTS.has(nextUrl.hostname)) {
        const out = new Headers(CORS(origin));
        out.set('X-Proxy-Status', String(upstream.status));
        if (allSetCookies.length > 0) out.set('X-Proxy-Set-Cookie', allSetCookies.join('\n'));
        out.set('X-Proxy-Location', loc);
        return new Response(null, { status: 200, headers: out });
      }

      // 301/302/303: POST → GET (HTTP-Standard)
      if ([301, 302, 303].includes(upstream.status) && currentMethod === 'POST') {
        currentMethod = 'GET';
        currentBody = null;
        fwd.delete('Content-Type');
      }

      currentUrl = nextUrl;
    }

    // Endantwort zusammenstellen: Body komplett puffern statt streamen,
    // damit Verbindungsfehler beim Lesen des Upstream-Streams als JS-Exception
    // sichtbar werden (statt als platform-level 500 ohne CORS-Header).
    let responseBody;
    try {
      responseBody = await upstream.arrayBuffer();
    } catch (err) {
      return new Response('body read error: ' + String(err), {
        status: 502, headers: CORS(origin),
      });
    }

    const out = new Headers(CORS(origin));
    out.set('X-Proxy-Status', String(upstream.status));
    if (allSetCookies.length > 0) out.set('X-Proxy-Set-Cookie', allSetCookies.join('\n'));
    const ct = upstream.headers.get('Content-Type');
    if (ct) out.set('Content-Type', ct);

    return new Response(responseBody, { status: 200, headers: out });
}
