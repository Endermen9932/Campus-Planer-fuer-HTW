/**
 * Cloudflare Worker: transparenter CORS-Proxy für lsf.htw-berlin.de + www.stw.berlin.
 *
 * WICHTIG: Der Worker folgt alle Redirects intern (redirect: 'manual' im loop),
 * sammelt dabei Set-Cookie-Header, und gibt NUR die finale Antwort zurück.
 * Hintergrund: XHR im Browser folgt 30x-Antworten automatisch – direkt zu LSF,
 * das keine CORS-Header hat. Das würde sofort geblockt.
 *
 * Protokoll (Dart ↔ Worker):
 *   Request:  ?url=<URL-encoded target>
 *             X-Proxy-Cookie: name=val; name2=val2   (Dart-eigene Jar)
 *             X-Proxy-UA:     <user-agent>
 *   Response: X-Proxy-Set-Cookie: <zeile>\n<zeile>   (alle Cookies über alle Hops)
 *             X-Proxy-Location: <finale URL>
 *
 * Deploy:  cd worker && npx wrangler deploy
 */

const ALLOW_HOSTS = new Set(['lsf.htw-berlin.de', 'www.stw.berlin']);
const MAX_REDIRECTS = 10;

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
        status: 400, headers: corsHeaders(origin),
      });
    }

    let targetUrl;
    try { targetUrl = new URL(targetParam); } catch {
      return new Response('invalid url parameter', {
        status: 400, headers: corsHeaders(origin),
      });
    }
    if (!ALLOW_HOSTS.has(targetUrl.hostname)) {
      return new Response(`host not allowed: ${targetUrl.hostname}`, {
        status: 403, headers: corsHeaders(origin),
      });
    }

    // Dart-Jar in lokales cookie-Objekt überführen
    const cookieJar = {};
    const initCookie = request.headers.get('X-Proxy-Cookie');
    if (initCookie) {
      for (const part of initCookie.split(';')) {
        const trimmed = part.trim();
        const eq = trimmed.indexOf('=');
        if (eq > 0) {
          cookieJar[trimmed.substring(0, eq).trim()] = trimmed.substring(eq + 1).trim();
        }
      }
    }

    const proxyUA = request.headers.get('X-Proxy-UA') || 'HTW Center/0.1';
    const acceptHdr = request.headers.get('Accept') || 'text/html,*/*';
    let method = request.method;
    let bodyText = method === 'POST' ? await request.text() : null;
    const origContentType = request.headers.get('Content-Type') ||
      'application/x-www-form-urlencoded; charset=utf-8';

    const allSetCookies = [];
    let currentUrl = targetUrl;
    let finalResponse = null;

    // Redirects intern abhandeln – Browser sieht niemals eine 30x-Antwort
    for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
      const fwdHeaders = new Headers();
      fwdHeaders.set('User-Agent', proxyUA);
      fwdHeaders.set('Accept', acceptHdr);

      const cookieStr = Object.entries(cookieJar)
        .map(([k, v]) => `${k}=${v}`).join('; ');
      if (cookieStr) fwdHeaders.set('Cookie', cookieStr);

      if (method === 'POST' && bodyText != null) {
        fwdHeaders.set('Content-Type', origContentType);
      }

      const upstream = await fetch(currentUrl.toString(), {
        method,
        headers: fwdHeaders,
        body: method === 'POST' ? bodyText : null,
        redirect: 'manual',
      });

      // Set-Cookie von diesem Hop sammeln und in lokale Jar eintragen
      const sc = upstream.headers.getSetCookie
        ? upstream.headers.getSetCookie()
        : [upstream.headers.get('set-cookie')].filter(Boolean);
      for (const line of sc) {
        allSetCookies.push(line);
        const first = line.split(';')[0].trim();
        const eq = first.indexOf('=');
        if (eq > 0) {
          cookieJar[first.substring(0, eq)] = first.substring(eq + 1);
        }
      }

      const status = upstream.status;
      if (![301, 302, 303, 307, 308].includes(status)) {
        finalResponse = upstream;
        break;
      }

      const location = upstream.headers.get('Location');
      if (!location) { finalResponse = upstream; break; }

      const nextUrl = new URL(location, currentUrl);
      // Redirect nur zu erlaubten Hosts folgen
      if (!ALLOW_HOSTS.has(nextUrl.hostname)) {
        finalResponse = upstream;
        break;
      }

      currentUrl = nextUrl;
      // 301/302/303 nach POST → GET (Standard-Browser-Verhalten)
      if (status !== 307 && status !== 308) {
        method = 'GET';
        bodyText = null;
      }
    }

    if (!finalResponse) {
      return new Response('too many redirects', {
        status: 508, headers: corsHeaders(origin),
      });
    }

    const outHeaders = new Headers(corsHeaders(origin));
    if (allSetCookies.length > 0) {
      outHeaders.set('X-Proxy-Set-Cookie', allSetCookies.join('\n'));
    }
    // Finale URL zurückgeben (nach allen Redirects)
    outHeaders.set('X-Proxy-Location', currentUrl.toString());

    const ct = finalResponse.headers.get('Content-Type');
    if (ct) outHeaders.set('Content-Type', ct);

    return new Response(finalResponse.body, {
      status: finalResponse.status,
      headers: outHeaders,
    });
  },
};
