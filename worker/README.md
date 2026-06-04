# LSF-Proxy (Cloudflare Worker)

Transparenter CORS-Proxy für `lsf.htw-berlin.de` und `www.stw.berlin`.
Wird benötigt, damit die Flutter-Web-PWA (GitHub Pages) auf die HTW-APIs
zugreifen kann – der Browser blockiert diese Cross-Origin-Requests sonst.

## Einmaliges Deployment

**Voraussetzungen:**
- [Cloudflare-Account](https://dash.cloudflare.com/sign-up) (kostenlos)
- Node.js ≥ 18

```bash
cd worker
npx wrangler login        # öffnet Browser, einmalig authentifizieren
npx wrangler deploy       # deployt den Worker
```

Nach dem Deploy zeigt Wrangler die Worker-URL an, z. B.:
```
https://lsf-proxy.<dein-subdomain>.workers.dev
```

## PROXY_BASE in GitHub eintragen

1. Repository → **Settings** → **Secrets and variables** → **Actions** → Tab **Variables**
2. **New repository variable** anlegen:
   - Name: `PROXY_BASE`
   - Value: `https://lsf-proxy.<dein-subdomain>.workers.dev`
3. Speichern. Der nächste Web-Deploy-Workflow liest die URL automatisch ein.

## Worker aktualisieren

```bash
cd worker
npx wrangler deploy       # Änderungen in lsf-proxy.js deployen
```

## Smoke-Test

```bash
# Mensa-Endpunkt testen (kein Cookie nötig)
curl -s "https://lsf-proxy.<sub>.workers.dev/?url=https%3A%2F%2Fwww.stw.berlin%2Fxhr%2Fspeiseplan-wochentag.html" \
     -X POST -d "resources_id=319&date=2026-06-04&week=" | head -c 500

# LSF-Login-Seite abrufen (prüft ob Proxy die JSESSIONID-Cookies weiterleitet)
curl -v "https://lsf-proxy.<sub>.workers.dev/?url=https%3A%2F%2Flsf.htw-berlin.de%2Fqisserver%2Frds%3Fstate%3Duser%26type%3D1" \
     2>&1 | grep -i "x-proxy"
```

## Erlaubte Hosts

Der Worker akzeptiert nur Anfragen an:
- `lsf.htw-berlin.de`
- `www.stw.berlin`

Alle anderen Hosts werden mit HTTP 403 abgewiesen.
