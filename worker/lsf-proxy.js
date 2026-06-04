/**
 * Cloudflare Worker: transparenter CORS-Proxy für lsf.htw-berlin.de + www.stw.berlin.
 *
 * Protokoll (Dart-Seite ↔ Worker):
 *   Request:  ?url=<URL-encoded target>
 *             X-Proxy-Cookie: name=val; name2=val2   (eigene Dart-Jar)
 *             X-Proxy-UA: <user-agent>
 *   Response: X-Proxy-Set-Cookie: <cookie-zeile>\n<cookie-zeile>  (newline-joined)
 *             X-Proxy-Location: <url>                              (bei Redirects)
 *
 * Redirects: Worker folgt NICHT selbst (redirect: 'manual'), damit Dart die
 * Cookies auf jedem Redirect-Hop einfangen kann (JSESSIONID nach Login-POST).
 *
 * Deploy:  cd worker && npx wrangler deploy
 */

const ALLOW_HOSTS = new Set(['lsf.htw-berlin.de', 'www.stw.berlin']);

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin || '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers':
      'Content-Type, X-Proxy-Cookie, X-Proxy-UA, Accept',
    'Access-Control-Expose-Headers': 'X-Proxy-Set-Cookie, X-Proxy-Location',
    'Access-Control-Max-Age': '86400',
  };
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
        status: 400,
        headers: corsHeaders(origin),
      });
    }

    let targetUrl;
    try {
      targetUrl = new URL(targetParam);
    } catch {
      return new Response('invalid url parameter', {
        status: 400,
        headers: corsHeaders(origin),
      });
    }

    if (!ALLOW_HOSTS.has(targetUrl.hostname)) {
      return new Response(`host not allowed: ${targetUrl.hostname}`, {
        status: 403,
        headers: corsHeaders(origin),
      });
    }

    // Upstream-Request aufbauen
    const fwdHeaders = new Headers();
    fwdHeaders.set(
      'User-Agent',
      request.headers.get('X-Proxy-UA') || 'HTW Center/0.1'
    );
    fwdHeaders.set('Accept', request.headers.get('Accept') || 'text/html,*/*');

    const cookie = request.headers.get('X-Proxy-Cookie');
    if (cookie) fwdHeaders.set('Cookie', cookie);

    let bodyText = null;
    if (request.method === 'POST') {
      bodyText = await request.text();
      fwdHeaders.set(
        'Content-Type',
        request.headers.get('Content-Type') ||
          'application/x-www-form-urlencoded; charset=utf-8'
      );
    }

    const upstream = await fetch(targetUrl.toString(), {
      method: request.method,
      headers: fwdHeaders,
      body: bodyText,
      redirect: 'manual', // Dart folgt manuell, um Cookies pro Hop zu lesen
    });

    const outHeaders = new Headers(corsHeaders(origin));

    // Set-Cookie als lesbaren Custom-Header weiterleiten
    const setCookies = upstream.headers.getSetCookie
      ? upstream.headers.getSetCookie()
      : [upstream.headers.get('set-cookie')].filter(Boolean);
    if (setCookies.length > 0) {
      outHeaders.set('X-Proxy-Set-Cookie', setCookies.join('\n'));
    }

    // Location als Custom-Header (Browser liest Location bei 30x ggf. nicht)
    const location = upstream.headers.get('Location');
    if (location) outHeaders.set('X-Proxy-Location', location);

    const contentType = upstream.headers.get('Content-Type');
    if (contentType) outHeaders.set('Content-Type', contentType);

    // Body-Bytes unverändert durchleiten (latin1 für LSF-Antworten bleibt erhalten)
    return new Response(upstream.body, {
      status: upstream.status,
      headers: outHeaders,
    });
  },
};
