/**
 * Cloudflare Worker: transparenter CORS-Proxy für lsf.htw-berlin.de + www.stw.berlin.
 *
 * Redirect-Strategie: "Virtuelle Redirects"
 * Der Worker gibt bei 3xx-Antworten IMMER HTTP 200 zurück, aber mit dem
 * echten Status-Code in X-Proxy-Status und der Ziel-URL in X-Proxy-Location.
 * So folgt der Browser der Weiterleitung NICHT automatisch (XHR/fetch folgen
 * 30x sonst direkt zum Zielserver, der keine CORS-Header hat → geblockt).
 * Der Dart-WebLsfTransport liest X-Proxy-Status und folgt manuell.
 *
 * Protokoll (Dart ↔ Worker):
 *   Request:  ?url=<URL-encoded target>
 *             X-Proxy-Cookie: name=val; name2=val2   (Dart-Cookie-Jar)
 *             X-Proxy-UA:     <user-agent>
 *   Response: X-Proxy-Status:     <echter HTTP-Status>  (immer gesetzt)
 *             X-Proxy-Set-Cookie: <zeile>\n<zeile>       (bei Set-Cookie)
 *             X-Proxy-Location:   <Location-URL>         (bei Redirects)
 *             Body + Content-Type: nur bei Nicht-Redirect-Antworten
 *
 * Deploy:  cd worker && npx wrangler deploy
 */

const ALLOW_HOSTS = new Set(['lsf.htw-berlin.de', 'www.stw.berlin']);

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin || '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Proxy-Cookie, X-Proxy-UA, Accept',
    'Access-Control-Expose-Headers':
      'X-Proxy-Status, X-Proxy-Set-Cookie, X-Proxy-Location',
    'Access-Control-Max-Age': '86400',
  };
}

function isRedirectStatus(status) {
  return status === 301 || status === 302 || status === 303 ||
         status === 307 || status === 308;
}

export default {
  async fetch(request) {
    const origin = request.headers.get('Origin') || '*';

    // Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    const targetParam = new URL(request.url).searchParams.get('url');
    if (!targetParam) {
      return new Response('missing url parameter', {
        status: 400, headers: corsHeaders(origin),
      });
    }

    let targetUrl;
    try {
      targetUrl = new URL(targetParam);
    } catch (_) {
      return new Response('invalid url parameter', {
        status: 400, headers: corsHeaders(origin),
      });
    }

    if (!ALLOW_HOSTS.has(targetUrl.hostname)) {
      return new Response('host not allowed', {
        status: 403, headers: corsHeaders(origin),
      });
    }

    // Upstream-Request aufbauen
    const fwdHeaders = new Headers();
    fwdHeaders.set('User-Agent',
      request.headers.get('X-Proxy-UA') || 'HTW Center/0.1');
    fwdHeaders.set('Accept',
      request.headers.get('Accept') || 'text/html,*/*');

    const cookie = request.headers.get('X-Proxy-Cookie');
    if (cookie) fwdHeaders.set('Cookie', cookie);

    let body = null;
    if (request.method === 'POST') {
      body = await request.text();
      fwdHeaders.set('Content-Type',
        request.headers.get('Content-Type') ||
        'application/x-www-form-urlencoded; charset=utf-8');
    }

    let upstream;
    try {
      upstream = await fetch(targetUrl.toString(), {
        method: request.method,
        headers: fwdHeaders,
        body: body,
        redirect: 'manual',
      });
    } catch (err) {
      return new Response(`fetch error: ${err}`, {
        status: 502, headers: corsHeaders(origin),
      });
    }

    // Antwort-Header zusammenstellen (immer HTTP 200 zurück an Browser)
    const outHeaders = new Headers(corsHeaders(origin));
    outHeaders.set('X-Proxy-Status', String(upstream.status));

    // Set-Cookie weiterleiten
    const setCookies = upstream.headers.getSetCookie
      ? upstream.headers.getSetCookie()
      : [upstream.headers.get('set-cookie')].filter(Boolean);
    if (setCookies.length > 0) {
      outHeaders.set('X-Proxy-Set-Cookie', setCookies.join('\n'));
    }

    if (isRedirectStatus(upstream.status)) {
      // Virtueller Redirect: 200 + X-Proxy-Status + X-Proxy-Location
      // Browser folgt nicht → Dart liest X-Proxy-Status und folgt manuell
      const location = upstream.headers.get('Location');
      if (location) outHeaders.set('X-Proxy-Location', location);
      return new Response(null, { status: 200, headers: outHeaders });
    }

    // Normale Antwort: Body + Content-Type durchleiten
    const ct = upstream.headers.get('Content-Type');
    if (ct) outHeaders.set('Content-Type', ct);
    return new Response(upstream.body, {
      status: 200,  // immer 200, echter Status in X-Proxy-Status
      headers: outHeaders,
    });
  },
};
