# Local Network POC: Testmatrix für Gast-Browser → Hub

**Zweck:** Systematische Erhebung, unter welchen realen Bedingungen ein
Gast-Browser (iOS Safari, Android Chrome) einen lokalen HTTP-Endpunkt auf
dem Venue-Hub-Gerät erreichen kann.

**Status:** Keine Implementierung, kein Architektur-Go. Nur Messung und
Dokumentation von beobachtbarem Verhalten.

---

## 1. Korrigierte Annahmen (basierend auf DEEPSEEK_REVIEW.md P0-01–P0-03)

| Alte Annahme (GLM) | Korrektur | Primärquelle |
|---|---|---|
| Gast-Browser erreicht Hub via `http://<name>.local:<port>` | Safari akzeptiert `.local` (mDNS); Android Chrome tut das nicht. Chrome auf Windows hat keinen mDNS-Resolver. | `https://datatracker.ietf.org/doc/html/rfc6762` §15.1: mDNS ist link-local; Android DNS-Resolver unterstützt `.local` nicht systemweit. |
| HTTP zum Hub ist akzeptabel | **Top-Level-HTTP** (Seite direkt von `http://hub:8080` geladen) ≠ **Mixed Content** (HTTPS-Seite lädt `http://hub:8080` per fetch). Letzteres wird von allen Browsern blockiert. | `https://www.w3.org/TR/mixed-content/` §5.1 (blockable content) |
| WebSocket ersetzt TLS und Auth | WebSocket (ws://) hat denselben Mixed-Content-Status wie HTTP. `wss://` benötigt TLS-Zertifikat auf dem Hub. | `https://www.w3.org/TR/websockets/` – WebSocket-Protokoll ist transportunabhängig; Mixed-Content-Regeln gelten analog zu `fetch()`. |
| Apple könnte eine lokale CA bereitstellen | Es gibt keine Apple-API oder -Dienst für eine "lokale Apple-CA" auf dem Gerät. `SecCertificateCreateWithData` importiert nur vorhandene Zertifikate. Self-signed-Zertifikate lösen in Safari immer eine nicht-ignorierbare Warnung aus (seit iOS 13). | `https://developer.apple.com/documentation/security/2876140-seccertificatecreatewithdata` – importiert nur; erzeugt keine CAs. |
| Failover-Zeit = 5s wäre akzeptabel | Failover-Zeit muss gemessen werden, nicht willkürlich gesetzt. 5s sind eine Behauptung; die tatsächliche Zeit hängt von SWIM/Liveness-Erkennung + Leader-Election + SQLite-Replay ab. | Keine Quelle für "5s" – siehe DEEPSEEK_REVIEW.md P0-04. |
| Privacy Manifest = generelle Pflicht | `PrivacyInfo.xcprivacy` ist seit 1. Mai 2024 Pflicht für **neue App-Updates** im App Store. Die darin aufgeführten Required-Reason-APIs betreffen spezifische Frameworks (UserDefaults, Date Timestamp, Disk Space, Active Keyboard, File Timestamp, System Boot Time). Network.framework ist **keine** Required-Reason-API. `NSLocalNetworkUsageDescription` ist eine Runtime-Berechtigung, kein Privacy-Manifest-Eintrag. | `https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api` |

---

## 2. Zu testende Szenarien

### 2.1 Netzwerktopologie

```
[Supabase Cloud]
      │ HTTPS (Produktion)
      ▼
[Restaurant-WLAN] ←─── [Gateway/Router]
      │
      ├── [Hub-Gerät: iPad/iPhone] ←── Port 8080 (NWListener oder URLSession)
      │       Bonjour: _kitchenlink-hub._tcp
      │       IP: DHCP oder statisch
      │
      └── [Gast-Geräte: iPhone, Android]
              QR → Browser → Hub
```

### 2.2 Endpunkte

| Endpunkt | Protokoll | Beschreibung |
|---|---|---|
| Cloud-HTTPS | `https://kitchenlink.app/venue/{slug}` | Normale Gast-Web-App, ausgeliefert von Supabase/Cloudflare |
| Lokales HTTP | `http://<hub-ip>:8080/menu` | Direkt vom Hub ausgelieferte HTML-Seite (kein Mixed Content) |
| Lokales WS | `ws://<hub-ip>:8080/events` | WebSocket für Status-Updates (gleiche Mixed-Content-Probleme wie HTTP) |
| .local mDNS | `http://kitchenlink-hub.local:8080` | Bonjour/mDNS-Name (nur Apple-Geräte, siehe §3) |

---

## 3. Testmatrix

Jede Zelle: ✅ erwartet funktionsfähig / ❌ erwartet blockiert / ? unklar (muss gemessen werden)

### 3.1 iOS Safari (aktuelles iOS 17/18)

| Szenario | AP Isolation AUS | AP Isolation AN | Kein WLAN (Mobilfunk) |
|---|---|---|---|
| **Cloud-HTTPS-Seite → fetch(`http://hub:8080/orders`)** | ❌ Mixed Content blockiert | ❌ Kein Routing + Mixed Content | ❌ Kein lokales Netz |
| **Cloud-HTTPS-Seite → WebSocket(`ws://hub:8080/events`)** | ❌ Mixed Content blockiert | ❌ Kein Routing | ❌ Kein lokales Netz |
| **Top-Level-HTTP-Seite von `http://hub:8080/menu`** | ✅ HTTP, kein Mixed Content | ❌ Kein Routing | ❌ Kein lokales Netz |
| **QR mit `http://hub-ip:8080/menu` → Browser öffnet direkt** | ✅ HTTP, kein Mixed Content | ❌ Kein Routing | ❌ |
| **QR mit `http://kitchenlink-hub.local:8080`** | ✅ mDNS wird aufgelöst | ❌ mDNS + Routing blockiert | ❌ |
| **QR → HTTP → fetch → CORS-Preflight (OPTIONS)** | ? CORS-Header erforderlich | ❌ | ❌ |
| **PWA von Cloud-HTTPS installiert → offline → fetch(http://hub)** | ❌ Service Worker in HTTPS-Seite: Mixed Content | ❌ | ❌ |
| **PWA von `http://hub:8080`** | ? Service Worker benötigt Secure Context → `http://hub:8080` ist KEIN Secure Context | ❌ | ❌ |

**Safari-spezifische Anmerkungen:**
- Safari blockt aktiven Mixed Content seit iOS 15. Quelle: `https://webkit.org/blog/12858/release-notes-for-safari-technology-preview-131/`
- Safari erlaubt `ws://` von HTTPS-Seiten nicht (Mixed Content). Quelle: `https://developer.apple.com/documentation/safari-release-notes/safari-15-release-notes`
- Safari auf iOS unterstützt `.local`-mDNS-Auflösung nativ (via mDNSResponder). Quelle: `https://developer.apple.com/bonjour/`
- Safari zeigt keine "nicht-vertrauenswürdige Zertifikat"-Warnung bei HTTP (da HTTP kein Zertifikat hat) – aber bei self-signed HTTPS zeigt Safari eine **full-page interstitial warning**, die der Benutzer nicht wegklicken kann (kein "Weiter trotzdem" wie in Chrome).

### 3.2 Android Chrome (aktuelles Chrome 125+)

| Szenario | AP Isolation AUS | AP Isolation AN | Kein WLAN (Mobilfunk) |
|---|---|---|---|
| **Cloud-HTTPS-Seite → fetch(`http://hub:8080/orders`)** | ❌ Mixed Content blockiert + **Chrome LNA** (siehe §4) | ❌ | ❌ |
| **Cloud-HTTPS-Seite → WebSocket(`ws://hub:8080/events`)** | ❌ Mixed Content + LNA | ❌ | ❌ |
| **Top-Level-HTTP-Seite von `http://hub:8080/menu`** | ? Chrome erlaubt HTTP-Seiten, aber LNA gilt nicht für Top-Level | ❌ | ❌ |
| **QR mit `http://hub-ip:8080/menu` → Chrome öffnet direkt** | ✅ (wenn LNA deaktiviert, siehe §4) | ❌ | ❌ |
| **QR mit `http://kitchenlink-hub.local:8080`** | ❌ Android-Resolver kennt `.local` nicht | ❌ | ❌ |
| **mDNS via google-cast-dns-sd-helper** | ? Android hat mDNS nur über Cast SDK, nicht systemweit | ❌ | ❌ |

**Android-spezifische Anmerkungen:**
- Android DNS-Resolver unterstützt `.local` mDNS **nicht** systemweit. Nur Chrome-Cast und proprietäre Apps mit eigenem mDNS-Resolver. Quelle: `https://developer.android.com/reference/android/net/dns/DnsResolver` – kein mDNS.
- QR muss zwingend eine IPv4-Adresse enthalten (z.B. `http://192.168.1.100:8080`).
- Statische IP oder DHCP-Reservation vorausgesetzt. Sonst QR ungültig nach IP-Wechsel.

### 3.3 Chrome Local Network Access (LNA)

**Chrome 94+** blockiert Requests von öffentlichen HTTPS-Seiten an private
Netzwerk-Endpunkte (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`,
`127.0.0.0/8`, `[::1]`). Dies ist unabhängig von Mixed Content.

**Quelle:** `https://developer.chrome.com/blog/private-network-access-update/`

| Szenario | LNA-Wirkung |
|---|---|
| `https://kitchenlink.app` → `fetch('http://192.168.1.5:8080/orders')` | ❌ Blockiert (öffentlich → privat) |
| `https://kitchenlink.app` → `fetch('https://192.168.1.5:8443/orders')` | ❌ Blockiert, auch mit HTTPS (LNA prüft Adresse, nicht Protokoll) |
| `http://192.168.1.5:8080` (Top-Level-Seite) → `fetch('/orders')` | ✅ Gleiche Quelle = kein LNA |
| `http://192.168.1.5:8080` → `ws://192.168.1.5:8080/events` | ✅ Gleiche Quelle |
| LNA-Warning vs. Block | Chrome 94–130: **Warnung** in DevTools, aber Request erlaubt. Chrome 130+: **Block** (hart). Status ab Chrome 131 unbekannt. |

**Konsequenz:** Wenn das Gast-Web als HTTPS-Seite ausgeliefert wird (Cloud),
kann es **weder über HTTP noch über HTTPS** einen lokalen Hub erreichen –
LNA blockiert den Request, bevor Mixed Content greift.

**Ausnahme:** Chrome 94–130 sendet einen `Access-Control-Request-Private-Network:
true`-Preflight und erlaubt den Request, wenn der Server mit
`Access-Control-Allow-Private-Network: true` antwortet. Der Hub müsste also
diesen spezifischen CORS-Header setzen. Quelle: `https://developer.chrome.com/blog/private-network-access-preflight/`

### 3.4 AP Isolation (Client Isolation)

**Getestete Router und ihr Standardverhalten** (vor dem POC zu erheben – hier
als Hypothesen für die Testmatrix):

| Router | AP Isolation Standard | Test erforderlich |
|---|---|---|
| FritzBox 7590 | Standard: AUS (nur Gast-WLAN: AN) | ✅ |
| UniFi U6-Pro | Standard: AUS (kann aktiviert werden) | ✅ |
| Cisco Meraki MR-Serie | Oft AN für Guest SSID | ✅ |
| Apple Airport | Standard: AUS | ✅ |
| TP-Link Archer | Oft AUS (Einstellung variiert) | ✅ |

**Messung:** Minimaler Test: Zwei iPhones im selben WLAN, eine hostet
NWListener auf Port 8080, die andere versucht `curl http://<ip>:8080`.
Misslingt dies, ist AP Isolation aktiv.

### 3.5 App-Lifecycle und Verbindungsstabilität

| Szenario | Hub-App-Zustand | Gast-Seite | Erwartetes Verhalten |
|---|---|---|---|
| Hub im Vordergrund, Bildschirm an | ✅ Aktiv | ✅ Verbunden | Normale Requests |
| Hub im Vordergrund, Bildschirm AUS (idle) | ⚠️ iOS hält App aktiv | ? NWListener läuft weiter | Laut Apple: App bleibt aktiv bei Bildschirm-aus (kein Sleep). Quelle: `https://developer.apple.com/documentation/uikit/app_and_environment/managing_your_app_s_life_cycle` |
| Hub-App im Hintergrund (Home-Button) | ❌ NWListener gestoppt | ❌ Keine Verbindung | `UIApplication.didEnterBackgroundNotification` – App hat ~5s für Cleanup, dann suspendiert. Quelle: `https://developer.apple.com/documentation/uikit/about-the-background-execution-sequence` |
| Hub-App suspendiert (nach 10s Hintergrund) | ❌ Keine Ausführung | ❌ Keine Verbindung | Kein Code wird ausgeführt. NWListener ist tot. |
| Hub-App beendet (Swipe-up) | ❌ Prozess beendet | ❌ Keine Verbindung | Kein KeepAlive möglich. |
| Hub erhält Anruf (Phone.app) | ⚠️ App geht in Hintergrund | ❌ Keine Verbindung | iOS priorisiert Telefonie. App wird suspendiert. |
| Hub-Gerät im Low Power Mode | ⚠️ Hintergrundaktivität reduziert | ? NWListener könnte überleben | Quelle: `https://developer.apple.com/documentation/foundation/processinfo/1617048-lowpowermodeenabled` |
| Hub-Gerät im Standby-Modus (iOS 17+, horizontal ladend) | ⚠️ App bleibt aktiv | ✅ NWListener läuft | Quelle: `https://developer.apple.com/documentation/uikit/app_and_environment/standby` |
| WLAN-Verbindungsabbruch (Roaming) | ⚠️ Kurze Unterbrechung | ❌ Verbindung getrennt | NWListener überlebt Roaming (bindet an IP, die sich ändert) – NWConnection muss neu aufgebaut werden. Quelle: Network.framework path monitoring |
| WLAN-Wiederverbindung (gleiche IP nach DHCP) | ✅ NWListener aktiv | ✅ Automatische Wiederherstellung? | Gast-Browser braucht Retry-Logik (WebSocket-Rekonnekt, Polling) |

### 3.6 Hub-Ausfall während aktiver Verbindung

| Szenario | Gast-Seite | Mitarbeiter-Seite | Maßnahme |
|---|---|---|---|
| Hub-App stürzt ab | ❌ fetch/WS hängt | ❌ NWBrowser leer | Gast-Seite: Timeout (60s+), dann Fehler. WS: `onclose`-Event. |
| Hub-Gerät-Akku leer | ❌ Totale Unterbrechung | ❌ | Daten im SQLite-Event-Log auf dem Hub – wenn Gerät nicht mehr startet: verloren. |
| Hub-App beendet, Gast hat offene Bestellung | ❌ Bestellung nicht abgeschlossen | ❌ | Bestellung ist nur dann gesichert, wenn ein Event vor dem ACK committet wurde (§16.2). |
| Hub-App abstürzt und SQLite beschädigt | ❌ Totale Unterbrechung | ❌ | SQLite `PRAGMA integrity_check` beim Start erforderlich. Quelle: `https://sqlite.org/pragma.html#pragma_integrity_check` |

---

## 4. Messprotokoll

Jeder Test wird nach folgendem Schema dokumentiert:

```
## Test N: [Titel]

**Datum:** 2026-07-16
**Tester:** [Name]
**Geräte:** Hub: iPad Pro M4 (iOS 18.2), Gast: iPhone 15 Pro (iOS 18.2)

### Setup
- WLAN: FritzBox 7590, 5 GHz, keine AP Isolation
- Hub: NWListener auf Port 8080, Bonjour-Typ _kitchenlink-hub._tcp
- Gast: Safari, QR-Code zu http://192.168.1.100:8080/menu

### Durchführung
1. [Schritt 1]
2. [Schritt 2]

### Beobachtung
✅ / ❌ / ⚠️: [Beschreibung]

### Gemessene Werte
- Verbindungsaufbau: [ms]
- Request-Antwort (GET /menu): [ms]
- Request-Antwort (POST /orders): [ms]
- Timeout bei Hub-Ausfall: [ms]

### Offene Fragen
- [Frage 1]
```

---

## 5. Entscheidungsmatrix (nach Abschluss aller Tests)

Nach Abschluss der Testreihe wird für jede Kombination dokumentiert, ob der
Gastzugriff funktioniert:

| Zugriffspfad | iOS Safari | Android Chrome | Windows Edge | macOS Safari |
|---|---|---|---|---|
| QR mit IP → HTTP (Top-Level) | TBD | TBD | TBD | TBD |
| QR mit mDNS → HTTP (Top-Level) | TBD | ❌ (kein mDNS) | ❌ | TBD |
| Cloud-HTTPS → fetch HTTP (Mixed) | ❌ (blocked) | ❌ (blocked + LNA) | ❌ | ❌ |
| Cloud-HTTPS → fetch HTTPS (LNA) | ? (kein LNA) | ❌ (LNA block) | ❌ | ? |
| Cloud-HTTPS → WS HTTP (Mixed) | ❌ | ❌ | ❌ | ❌ |
| Cloud-HTTPS → WSS HTTPS (LNA) | ? | ❌ (LNA) | ❌ | ? |
| QR mit IP + Cloud-Seite (weiterleit) | ? | ❌ (LNA) | ❌ | ? |

**Akzeptanzkriterium für Stage 3 (Gastzugriff):** Mindestens ein Pfad muss
für iOS Safari UND Android Chrome funktionieren, ohne dass der Gast:
- eine Sicherheitswarnung wegklicken muss
- Einstellungen ändern muss
- eine App installieren muss
- ein Captive Portal umgehen muss

---

## 6. Primärquellen

| Thema | Quelle | Abruf |
|---|---|---|
| Mixed Content W3C Spec | `https://www.w3.org/TR/mixed-content/` | 2026-07-16 |
| Secure Contexts W3C Spec | `https://w3c.github.io/webappsec-secure-contexts/` | 2026-07-16 |
| Chrome Private Network Access | `https://developer.chrome.com/blog/private-network-access-update/` | 2026-07-16 |
| Chrome LNA Preflight | `https://developer.chrome.com/blog/private-network-access-preflight/` | 2026-07-16 |
| WebSocket API Spec | `https://www.w3.org/TR/websockets/` | 2026-07-16 |
| mDNS RFC 6762 | `https://datatracker.ietf.org/doc/html/rfc6762` | 2026-07-16 |
| Apple Bonjour Overview | `https://developer.apple.com/bonjour/` | 2026-07-16 |
| iOS Background Execution | `https://developer.apple.com/documentation/uikit/about-the-background-execution-sequence` | 2026-07-16 |
| iOS App Lifecycle | `https://developer.apple.com/documentation/uikit/app_and_environment/managing_your_app_s_life_cycle` | 2026-07-16 |
| iOS Low Power Mode | `https://developer.apple.com/documentation/foundation/processinfo/1617048-lowpowermodeenabled` | 2026-07-16 |
| NSLocalNetworkUsageDescription | `https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription` | 2026-07-16 |
| Apple Privacy Manifest (Required Reason APIs) | `https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api` | 2026-07-16 |
| Android DNS Resolution (kein mDNS) | `https://developer.android.com/reference/android/net/dns/DnsResolver` | 2026-07-16 |
| Safari 15 Release Notes (Mixed Content) | `https://developer.apple.com/documentation/safari-release-notes/safari-15-release-notes` | 2026-07-16 |
| WebKit Mixed Content Blocking | `https://webkit.org/blog/12858/release-notes-for-safari-technology-preview-131/` | 2026-07-16 |
| SQLite WAL Mode | `https://sqlite.org/wal.html` | 2026-07-16 |
| SQLite PRAGMA integrity_check | `https://sqlite.org/pragma.html#pragma_integrity_check` | 2026-07-16 |
| SecCertificateCreateWithData | `https://developer.apple.com/documentation/security/2876140-seccertificatecreatewithdata` | 2026-07-16 |

---

## 7. Offene Hypothesen (müssen im POC widerlegt oder bestätigt werden)

1. **Hypothese:** Safari akzeptiert `http://192.168.1.x` als Top-Level-HTTP
   und erlaubt `fetch()` zu derselben Quelle (gleicher Host:Port) ohne
   Mixed-Content-Warnung.
   - **Falsifikation:** Safari blockiert HTTP generisch, auch Top-Level.
     Quelle: Safari 15+ Verhalten – muss getestet werden.

2. **Hypothese:** Chrome auf Android akzeptiert `http://192.168.1.x` als
   Top-Level-HTTP ohne LNA-Block (LNA gilt nur für Sub-Requests von
   HTTPS-Seiten).
   - **Falsifikation:** Chrome blockiert auch Top-Level-HTTP zu
     Privat-IPs (LNA-Warnung). Quelle: Chrome LNA Spec – muss getestet.

3. **Hypothese:** Safari zeigt bei self-signed HTTPS auf lokaler IP einen
   übergehbaren Warning-Dialog (wie Chrome "Proceed anyway").
   - **Falsifikation:** Safari zeigt einen **nicht übergehbaren**
     Full-Screen-Fehler (seit iOS 13). Quelle: Apple Security –
     muss getestet.

4. **Hypothese:** Chrome LNA-Warnung (nicht Block) ist umgehbar durch
   Setzen des `Access-Control-Allow-Private-Network: true`-Headers auf dem
   Hub-Server.
   - **Falsifikation:** Header wird von Chrome ignoriert oder Block ist
     hart ab Chrome 131. Quelle: Chromium LNA Discourse.

5. **Hypothese:** AP Isolation in aktuellen Restaurant-WLANs (FritzBox
   Gastzugang, UniFi Guest Network) ist Standard AN.
   - **Falsifikation:** Messung vor Ort zeigt, ob Geräte kommunizieren können.

6. **Hypothese:** WebSocket (`ws://`) von einer Top-Level-HTTP-Seite
   (`http://hub:8080`) wird von Safari unterstützt.
   - **Falsifikation:** Safari erlaubt `ws://` nur von `https://`. Quelle:
     Safari 15+ WS-Verhalten – muss getestet.
