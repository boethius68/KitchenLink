# Codex Handoff

**Updated:** 19 July 2026
**Branch:** `codex/local-hub-discovery`
**Status:** Native Hub-Erkennung in Draft-PR #29; reale iPhone-Abnahme vor
Integration offen

## Latest Continuation (19. Juli 2026, KL-OFFLINE-008)

- Ein gemeinsamer Bonjour-Vertrag fuer `_kitchenlink-hub._tcp` uebertraegt
  Schema-Version, stabile Hub-ID, Anzeigename und die konkrete lokale
  HTTP-Basisadresse. Ungueltige, unvollstaendige oder unerwartet versionierte
  Datensaetze werden nicht als waehlbarer Hub angeboten.
- iPhone- und macOS-Hub kuendigen denselben Vertrag an. Das iPhone behaelt eine
  stabile Geraete-ID, aktualisiert bei WLAN-/IP-Wechsel nur den TXT-Datensatz
  und entfernt die waehlbare URL, solange keine LAN-Adresse vorhanden ist.
- Die native Business-App sucht im Vordergrund mit `NWBrowser`, filtert den
  eigenen iPhone-Hub und zeigt andere Hubs unter `Anderen Hub verwenden` als
  bewusste Auswahl. Es gibt keine automatische Verbindung; die manuelle
  Adresse bleibt vollstaendig erhalten.
- HTTP-Listener und Bonjour-Ankuendigung sind getrennt. Das verhindert die im
  Wiederholungstest reproduzierte kurze Listener-Unterbrechung, die beim
  nachtraeglichen Austausch von `NWListener.service` auftrat.
- Normale Gastbrowser erhalten absichtlich keine automatische Discovery. Sie
  verwenden weiterhin den sichtbaren QR-Code beziehungsweise die konkrete
  lokale IP-Adresse.

## Verification (KL-OFFLINE-008)

- `KitchenLinkLocalGuestPOC`: **12/12 Tests bestanden**, darunter drei Tests
  fuer Bonjour-Roundtrip, fehlende LAN-Adresse und unsichere/ungueltige URLs.
- Venue-Hub-Testblock nach der Listener-/Bonjour-Trennung **zehnmal
  hintereinander bestanden**; kein erneuter Loopback-Aussetzer.
- Komplettes `kitchenlinkTests`-Target auf dem iPhone-17-Pro-Simulator:
  **176 bestanden, 1 bewusst uebersprungen, 0 fehlgeschlagen**.
- Echter macOS-Bonjour-Smoke mit `dns-sd`: `KitchenLink Mac Hub` unter
  `_kitchenlink-hub._tcp.local.` gefunden, auf Port `18080` aufgeloest und
  TXT-Daten `id`, `name`, `url=http://192.168.178.110:18080`, `v=1`
  verifiziert.
- Signierter arm64-Build fuer `Philipps iPhone XR`: **bestanden** und der
  aktuelle Branch-Stand erfolgreich auf dem gekoppelten Geraet installiert.
- `git diff --check`: bestanden.

## Remaining Risk (KL-OFFLINE-008)

- Die automatische Anzeige und bewusste Auswahl des Mac-Hubs muss noch mit
  dem signierten Build auf dem echten iPhone bestaetigt werden. Bis dahin
  bleibt der PR im Draft.
- Discovery ist auf aktive native Operator-Clients und dasselbe erreichbare
  WLAN begrenzt. Hintergrundbetrieb, automatisches Failover, LAN-
  Authentisierung, AP-Isolation, Android und TLS/Trust bleiben ausserhalb
  dieser Scheibe.

## Latest Continuation (19. Juli 2026, PR #27 Integration)

- Der Nutzer bestaetigte den vorbereiteten realen WLAN-aus/an-Test auf dem
  iPhone als vollstaendig funktionsfaehig. Damit ist die offene interaktive
  Recovery-Abnahme bestanden.
- PR #27 war unveraendert, konfliktfrei und mergebar; es gab keine Reviews,
  Kommentare oder konfigurierten GitHub-Actions-Checks. Die lokale Suite, der
  signierte Geraetebuild und die reale Abnahme bildeten den Freigabenachweis.
- PR #27 nach der Nutzerabnahme aus dem Draft genommen und als Merge-Commit
  `dc67ecc` nach `main` integriert. `origin/main` enthaelt den vollstaendigen
  Feature-Stand `4554607`.
- Diesen reinen CURRENT-/Queue-/Handoff-Nachtrag direkt vom gemergten
  `origin/main` abgezweigt; lokales `main` blieb unangetastet, weil es im
  separaten Claude-Worktree ausgecheckt ist.

## Latest Continuation (19. Juli 2026, KL-OFFLINE-007)

- Der Implementierungsstand wurde auf `codex/iphone-hub-network-recovery`
  veroeffentlicht und mit PR #27 nach `main` integriert.
- Der `NWListener` bleibt bei fehlender oder geaenderter WLAN-Adresse aktiv.
  Ein leichter Zwei-Sekunden-Monitor prueft ausschliesslich die iOS-WLAN-
  Schnittstelle `en0`; Tunnel-, Mobilfunk- und Peer-to-Peer-Adressen werden
  nicht als Gastadresse ausgegeben.
- Listener-Port, Loopback-Operatoradresse und SQLite-Event-Log bleiben ueber
  den Wechsel stabil. Nur die optionale Gastadresse wird als Ereignis an das
  View-Model weitergegeben; ein Listenerfehler wird ebenfalls sichtbar
  propagiert.
- Ohne WLAN-Adresse startet der Hub jetzt in `waitingForWiFi`, statt komplett
  zu scheitern. Kuechen-/Kellneransicht und gespeicherte Bestellungen bleiben
  ueber Loopback verfuegbar. Bei Rueckkehr oder IP-Wechsel aktualisieren sich
  Gast-URL, QR-Code und Teilen-Aktion automatisch.
- Die Oberflaeche zeigt den Wartezustand mit `wifi.slash` und erklaert, welche
  lokalen Funktionen weiterlaufen. Foreground-, Sandbox- und WLAN-Hinweise
  bleiben bestehen.

## Verification (KL-OFFLINE-007)

- Gezielte iOS-Hub-Suite: **6/6 bestanden**, darunter Start ohne WLAN,
  Adresse kommt/geht, unveraenderter Port/Loopback und echter HTTP-Bestelllauf.
- Komplettes `kitchenlinkTests`-Target auf iPhone-17-Pro-Simulator:
  **174 bestanden, 1 bewusst uebersprungen, 0 fehlgeschlagen**.
- Signierter arm64-Build fuer `Philipps iPhone XR`: **bestanden**; der aktuelle
  Draft-PR-Stand wurde erfolgreich auf dem gekoppelten Geraet installiert.
- `git diff --check`: bestanden.

## Remaining Risk (KL-OFFLINE-007)

- Bereits auf einem Gastgeraet geoeffnete Seiten unter der alten IP koennen
  nach einem Netzwechsel naturgemaess nicht umgeleitet werden; der sichtbare
  Link und QR-Code auf dem Hub zeigen danach die neue Adresse.
- Der Hub bleibt ein Foreground-Sandbox-PoC. Hintergrundbetrieb, automatische
  Client-Discovery, LAN-Authentisierung, AP-Isolation, Android und TLS/Trust
  bleiben offen; Zahlung und aktive Cloud-Synchronisation sind unveraendert
  nicht freigegeben.

## Latest Continuation (19. Juli 2026, PR #25 Integration)

- PR #25 nach der positiven Mac-zu-iPhone-Abnahme aus dem Draft genommen und
  als Merge-Commit `cbf7196` nach `main` integriert.
- `origin/main` auf den exakten Merge-Stand verifiziert und diesen reinen
  Statusnachtrag direkt davon abgezweigt; lokales `main` blieb unangetastet,
  weil es im separaten Claude-Worktree ausgecheckt ist.
- Keine GitHub-Actions-Checks waren fuer PR #25 konfiguriert. Die neun
  Core-Tests, 172 App-Tests, Simulator-/Geraetebuilds und die reale Abnahme
  waren vor Integration gruen.
- Der GitHub-Ablauf hielt PR #25 bis zur realen Geraeteabnahme bewusst im
  Draft; erst der bestandene Lauf loeste Ready-Status und Merge aus.

## Latest Continuation (19. Juli 2026, echte iPhone-Hub-Abnahme)

- KitchenLink auf dem iPhone in `Lokaler Service` geoeffnet; der Foreground-Hub
  zeigte seine dynamische Gastadresse im gemeinsamen WLAN.
- Die Gastseite auf dem Mac ueber genau diese iPhone-Adresse geoeffnet und dort
  eine echte Bestellung abgegeben. Der fruehere macOS-Server war dafuer nicht
  erforderlich.
- Bestellung erschien live auf demselben iPhone im Kuechenmodus, wechselte nach
  `Bestellung zubereitet` in den Kellnermodus und liess sich dort erfolgreich
  weiterbearbeiten.
- Nutzer bestaetigte den gesamten Mac-zu-iPhone-Ablauf als erfolgreich. Damit
  ist die offene reale Abnahme fuer PR #25 bestanden.

## Latest Continuation (19. Juli 2026, KL-OFFLINE-006)

- Der iPhone-Hub verwendet den bestehenden `KitchenLinkLocalGuestCore` und das
  bestehende `KitchenLinkEventLog` direkt als lokales Swift Package. Die
  Gastseite wurde deshalb in den Core-Ressourcen gebuendelt; der macOS-Server
  verwendet weiterhin exakt dieselbe Seite.
- Neuer Foreground-HTTP-Server auf Apples `NWListener`: lokale WLAN-Adresse,
  dynamischer Port, Bonjour-Ankuendigung, begrenzter HTTP-Parser und
  one-request-per-connection. Bestell-ACKs kommen unveraendert erst nach dem
  atomaren Event-/Outbox-Commit.
- `Lokaler Service` startet standardmaessig dieses iPhone als Hub, zeigt
  QR-Code, URL und Teilen-Aktion und verbindet die Operatorprojektion intern
  ueber `127.0.0.1`. Der gespeicherte macOS-Hub bleibt als bewusster Fallback
  erhalten und wird durch Loopback nicht ueberschrieben.
- Der Hub stoppt im Hintergrund und beim Verlassen der Ansicht. Die Oberflaeche
  kennzeichnet den PoC daher sichtbar als Foreground-Sandbox mit gemeinsamem
  WLAN und empfohlenem Stromanschluss.

## Verification (KL-OFFLINE-006)

- `KitchenLinkLocalGuestPOC`: **9/9 Swift-Tests bestanden**.
- Neue iOS-Hub-Suite: **4/4 bestanden** (HTTP-Parser, Groessenlimit,
  Model-Lifecycle und echter `NWListener`-Loopback mit Health, Order-POST,
  `local-event-log-committed` und anschliessender Kuechenprojektion).
- Local-Operations-Suite: **4/4 bestanden**, einschliesslich Schutz der
  gespeicherten Mac-Fallback-Adresse.
- Komplettes `kitchenlinkTests`-Target: **172 bestanden, 1 bewusst
  uebersprungen, 0 fehlgeschlagen**.
- iPhone-17-Simulator-Build und signierter arm64-Build fuer
  `Philipps iPhone XR`: **bestanden**.
- Finaler signierter Build erfolgreich auf dem iPhone XR installiert.
  Automatischer Start wurde nur vom gesperrten Geraetezustand abgewiesen; das
  ist kein Build- oder Installationsfehler.
- `git diff --check`: bestanden.

## Remaining Risk (KL-OFFLINE-006)

- Der iPhone-gehostete Pfad ist real mit Safari auf dem Mac als Gastgeraet
  bestanden. Android Chrome, AP-Isolation und ein zweites mobiles Gastgeraet
  bleiben separate Kompatibilitaets-Gates.
- Der Hub ist absichtlich nur im Vordergrund aktiv. Kein Background-Mode,
  Failover oder produktiver Dauerbetrieb ist behauptet.
- Bonjour wird angekuendigt, aber automatische Discovery/Adresswechsel sind
  noch nicht implementiert. LAN-Authentisierung, feindliches WLAN,
  Mehrgeraetekonkurrenz, AP-Isolation, Android und TLS/Trust bleiben offen.
- Keine Zahlung und keine aktive Cloud-Synchronisation; Sandbox- und
  Demoablaeufe bleiben erhalten.

## Latest Continuation (19. Juli 2026, PR #23 Integration)

- PR #23 nach der positiven Nutzerabnahme aus dem Draft genommen und als
  Merge-Commit `7376f5a` nach `main` integriert.
- `origin/main` auf den exakten Merge-Stand aktualisiert und diesen reinen
  Statusnachtrag davon abgezweigt.
- Keine GitHub-Actions-Checks waren fuer den PR konfiguriert; Mergebarkeit,
  kompletter lokaler Testnachweis und die reale Zwei-Geraete-Abnahme waren vor
  der Integration gruen.
- Naechste Netzwerk-Gates bleiben Android Chrome, AP-Isolation,
  Bonjour/Discovery, IP-Wechsel und Hub-Lifecycle. Daraus folgt weiterhin
  keine Produktionsfreigabe.

## Latest Continuation (19. Juli 2026, echte Zwei-Geraete-Abnahme)

- KitchenLink auf dem iPhone im Kuechen-Modus geoeffnet und mit dem lokalen
  macOS-Hub im gemeinsamen WLAN verbunden.
- Eine neue Bestellung live von einem zweiten Geraet ueber die lokale Gastseite
  abgegeben.
- Auftrag erschien live im Kuechen-Modus, wechselte nach
  `Bestellung zubereitet` in den Kellner-Modus und liess sich dort mit
  `Bestellung serviert` abschliessen.
- Nutzer bestaetigte den gesamten Lauf als erfolgreich. Damit ist die bisher
  offene interaktive Geraeteabnahme fuer PR #23 bestanden.

## Latest Continuation (18. Juli 2026, KL-OFFLINE-005)

- PR #22 (`codex/fix-lan-order-uuid`) vor Beginn als Merge-Commit `e93393f`
  nach `main` integriert und den neuen Branch exakt davon erstellt.
- Der lokale Hostsurrogat bietet jetzt `GET /operator/orders` und
  `POST /operator/orders/{id}/status`. Neue Gastbestellungen starten in der
  Operatorprojektion als `preparing`; nur `ready` und danach `served` sind
  erlaubt. Jeder Schritt ist ein eigenes Event mit optimistischer Revision und
  Cloud-Outbox. Auch ein erst nach `served` eintreffender `ready`-Retry liefert
  die urspruengliche Receipt statt einen falschen Konflikt.
- Neue V2-Ansicht `Lokaler Service` auf dem iPhone: editierbare, gespeicherte
  Hub-Adresse, 1-Sekunden-Polling, Kueche/Kellner-Umschaltung,
  `Bestellung zubereitet` und `Bestellung serviert`. Die Ansicht mappt auf die
  bestehende `LiveOrderMessage`-/`OrderLifecycleStatus`-Domaene.
- Statische App-Info-Plist ergaenzt, damit die iOS-Berechtigungsbeschreibung
  und `NSAllowsLocalNetworking` tatsaechlich im Produkt landen. Der zuvor
  versuchte flache generierte Build-Key erzeugte den verschachtelten ATS-Wert
  nicht und wurde vor Abschluss ersetzt.

## Verification (KL-OFFLINE-005)

- Hostsurrogat: **9/9 Swift-Tests bestanden**.
- iOS: fokussierte Local-Operations-Tests **3/3 bestanden**; komplettes
  `kitchenlinkTests`-Target **167 bestanden, 1 bewusst uebersprungen, 0
  fehlgeschlagen**.
- Echter HTTP-Ablauf: Bestellung 201/`preparing`, Status 201/`ready`, danach
  201/`served`; Projektion nach jedem Schritt geprueft. Verzoegerter Ready-
  Retry nach Served: 200 mit der urspruenglichen Event-ID und `replayed=true`.
- App fuer Simulator, generisches iOS und das gekoppelte echte iPhone gebaut.
  Signierter Build erfolgreich auf `Philipps iPhone XR` installiert. Der
  automatische Start wurde nur durch den gesperrten Geraetezustand abgewiesen.
- Gebautes Info.plist kontrolliert: lokale Netzwerkbeschreibung und
  `NSAppTransportSecurity.NSAllowsLocalNetworking = true` vorhanden.
- Echter Zwei-Geraete-Lauf im Referenz-WLAN: zweites Geraet bestellt lokal,
  iPhone empfaengt in Kueche, reicht an Kellner weiter und schliesst als
  serviert ab: **vom Nutzer bestanden bestaetigt**.

## Remaining Risk (KL-OFFLINE-005)

- Polling und feste/editierbare IP sind eine Sandbox-Naht. Bonjour/Discovery,
  IP-Wechsel, Hintergrundbetrieb, Push, Mehrgeraetekonkurrenz, AP-Isolation,
  Android und TLS/Trust sind nicht geloest.
- Der macOS-Hostsurrogat bleibt sequentiell und nicht fuer Produktion oder ein
  feindliches LAN gehaertet. Keine Zahlung oder Cloud-Synchronisation wurde
  aktiviert; Sandboxkennzeichnung und bestehende Demos bleiben erhalten.

## Latest Continuation (18. Juli 2026, iPhone-LAN-Fund)

- Der erste echte iPhone-Safari-Lauf erreichte die Gastseite im WLAN, blieb
  nach dem Absenden aber bei „Bestellung wird lokal gespeichert …“ stehen.
- LAN-Endpunkt separat mit HTTP 201 und lokalem Commit verifiziert. Im Browser
  gegen die LAN-IP reproduziert: Plain-HTTP ist kein sicherer Kontext und
  `window.crypto`/`crypto.randomUUID()` war nicht verfügbar. Die Exception lag
  vor dem `try/catch`, daher blieb der Zwischenzustand sichtbar.
- Fix auf `codex/fix-lan-order-uuid`: LAN-taugliche UUID-Fallback-Erzeugung,
  gesamter Sendeaufbau innerhalb der Fehlerbehandlung und ein stabiler
  `pendingOrder`-Snapshot. Ein Retry derselben Bestellung behält dadurch den
  Idempotenzschlüssel statt eine mögliche Doppelbestellung zu erzeugen.
- Verifikation: 6/6 Swift-Tests; mobile Bestellung über
  `http://192.168.178.110:8080` trotz nicht verfügbarem Web Crypto erfolgreich
  als `lokal #1`, keine Browser-Warnungen oder -Fehler.

## Latest Continuation (18. Juli 2026, PR #20 Integration)

- PR #20 nach dem Integrationsreview aus dem Draft genommen und als Merge-
  Commit `be54d60` nach `main` integriert.
- `origin/main` auf den Merge-Commit aktualisiert und diesen CURRENT-/Queue-
  Nachtrag von der exakten Integrationsbasis angelegt.
- Vor dem Merge wurden zwei Review-Härtungen ergänzt: JSON-Inhaltstyp-Pflicht
  für Order-Writes und DOM-sicheres Menü-Rendering. Danach erneut 6/6 Tests und
  eine mobile Browserbestellung ohne Warnungen oder Fehler.
- Der nächste Gate bleibt unverändert: iOS Safari und Android Chrome müssen den
  lokalen Top-Level-Pfad im Referenz-WLAN tatsächlich erreichen und bestellen.

## Latest Continuation (18. Juli 2026, KL-OFFLINE-004)

- PR #19 mit der bestaetigten Anforderung zur lokalen Gastbestellung nach
  `main` gemergt (`f6c8821`) und den Implementierungsbranch davon erstellt.
- Neues isoliertes Swift Package `prototypes/KitchenLinkLocalGuestPOC/`:
  macOS-LAN-Server, same-origin Gastseite, `/bootstrap`, `/health` und
  `POST /orders`.
- Das bestehende `KitchenLinkEventLog` ist die einzige Annahmenaht. Ein
  `accepted`-Receipt wird erst gebaut, nachdem Event und Cloud-Outbox atomar
  committed sind. Replay liefert Event-ID/Sequenz des Originals; ein gleicher
  Key mit anderem kanonischen Payload ergibt HTTP 409.
- Artikel und Mengen werden gegen die lokale Sandbox-Karte geprueft; Preise und
  Gesamtbetrag entstehen serverseitig. Ein vom Browser gesendeter Gesamtbetrag
  ist nicht vertrauenswuerdig und beeinflusst weder Payload noch ACK.
- Der Browser oeffnet die Gastseite direkt lokal. Es gibt absichtlich keinen
  Cross-Origin-Fetch von der HTTPS-Cloudseite zum HTTP-Hub.
- Commit `ee8c62e` ist auf `codex/local-guest-ordering-poc` gepusht; Draft PR
  #20 zielt auf `main`.

## Verification (KL-OFFLINE-004)

- `swift test`: **6/6 bestanden**.
- HTTP-Smoke mit echtem Server: `/health` 200, Gastseite 200, erste Bestellung
  201 nach Commit, identischer Retry 200 mit gleicher Event-ID/Sequenz,
  Same-Key/Different-Payload 409. Serverpreis 900 Cent statt manipuliertem
  Clientwert 1 Cent.
- Mobile Browserpruefung bei 390 x 844: Karte vollstaendig gerendert,
  Warenkorb bedienbar, lokale Bestellung mit `lokal #1` bestaetigt und danach
  zurueckgesetzt; keine Browser-Warnungen oder -Fehler.
- `git diff --check`: bestanden.

## Integration Review (PR #20)

- PR gegen den exakten `main`-Stand geprueft: mergebar, keine offenen Reviews,
  Kommentare oder CI-Fehler.
- Vor Integration zwei Härtungen eingearbeitet: `POST /orders` akzeptiert nur
  noch `application/json`, sodass einfache Cross-Origin-Form-/Text-Requests
  keine lokale Bestellung ausloesen koennen; Menüdaten werden mit DOM-
  `textContent` statt HTML-Interpolation gerendert.
- Danach erneut 6/6 Swift-Tests und eine echte mobile Browserbestellung bei
  390 x 844: `lokal #1`, keine Browser-Warnungen oder -Fehler.

## Remaining Risk (KL-OFFLINE-004)

- Der Server ist bewusst ein sequentieller macOS-Entwickler-Surrogat. Er ist
  kein iOS-Hub und nicht fuer Produktion, Last oder ein feindliches LAN
  gehaertet.
- QR-Erzeugung, Bonjour, DHCP/IP-Wechsel, AP-Isolation, iOS Safari, Android
  Chrome, Hub-App-Lifecycle, TLS/Trust und Failover sind nicht bewiesen.
- Keine Zahlung und keine Cloud-Synchronisation; der `.cloud`-Outboxeintrag
  bleibt lokal `pending`. Das Sandbox- und Produktionslabeling bleibt erhalten.

## Latest Continuation (18. Juli 2026, lokale Gastbestellung)

- Der Nutzer hat explizit entschieden, dass Gaeste bei Cloud-Ausfall lokal
  bestellen koennen muessen.
- Entscheidung in `DECISIONS.md` und Blueprint §16.2 als verbindliche
  Sandbox-Beta-Anforderung festgehalten: Restaurant-WLAN/lokale Oberflaeche,
  ACK erst nach dauerhafter Speicherung auf einem autoritativen Venue-Knoten.
- `CURRENT.md`, `WORK_QUEUE.md` und die Offline-Hub-Integrationslesart
  nachgezogen. Der Verzicht auf lokalen Gastzugriff ist keine Option mehr.
- Keine konkrete Transporttechnik freigegeben. Lokale Top-Level-Zustellung,
  QR-/Bootstrap-Wechsel, AP-Isolation, TLS/Trust und Failover muessen vor
  Netzwerkcode auf echten Geraeten nachgewiesen werden.

## Latest Continuation (18. Juli 2026, PR #17 Integration)

- Cleanup-PR #17 aus dem Draft genommen und als Merge-Commit `a743723` nach
  `main` integriert.
- `origin/main` und den gemergten `CURRENT.md`-Stand verifiziert.
- Oeffentlicher Read-only-Smoke auf
  `https://kitchenlink.luneq.eu/alte-muehle/menu`: HTTP 200.
- Diesen reinen Doku-Follow-up angelegt, weil die bisherige Ueberschrift
  unmittelbar nach dem Merge noch PR #15 als letzten Merge bezeichnete.

## Latest Continuation (18. Juli 2026, PR #15 Review)

- PR #15 (`KL-INVENTORY-002`) gegen die Inventory-Domain, den aktuellen
  Designvertrag und die echte Simulatoransicht geprueft.
- Der erste Screenshot zeigte einen fachlichen Merge-Blocker: Die vollstaendige
  Zutaten-mal-Lagerorte-Projektion meldete nicht gefuehrte Artikel als Bestand
  `0` und erzeugte dadurch falsche Warnungen, etwa Wein in der Kueche. Die
  Operator-Ansicht zeigt jetzt nur Paare mit Ledger-Aktivitaet. Ein einmal auf
  `0` gefallener, zuvor gefuehrter Artikel bleibt sichtbar.
- Pflichtinformationen werden nicht mehr abgeschnitten. Physisch, reserviert
  und verfuegbar sind explizit sichtbar; Minimum/Ziel bzw. der kritische
  Buchungshinweis bleiben in Klartext erhalten. Header und Zahlenblock stapeln
  sich bei Accessibility-Dynamic-Type-Groessen.
- Den im Dunkelmodus unsichtbaren Text des primaeren Demo-Buttons durch eine
  robuste explizite Symbol-Text-Komposition korrigiert.
- Die Sandbox-Bezeichnung `Kueche` auf `Küche` korrigiert und die
  Projektionsabdeckung auf 13 Tests erweitert, einschliesslich eines Guards
  gegen lagerortuebergreifende Fehlalarme.

## Verification (PR #15 Review)

- Alle 13 `KitchenLinkV2InventoryStockProjectionTests`: **bestanden**.
- Vollstaendiges `kitchenlinkTests`-Target: **bestanden**; der absichtlich
  gegatete OCR-Benchmark wurde uebersprungen.
- Screenshot-UI-Test im Hell- und Dunkelmodus: **bestanden**; beide
  Bestandsansichten visuell geprueft.
- Der erste komplette UI-Lauf hatte nach einem vom Simulator abgewiesenen
  XCTest-Runner-Start drei Navigationsfehler. Genau diese drei Tests wurden auf
  einem frischen Lauf wiederholt und sind **alle bestanden**.
- `git diff --check`: keine Whitespace-Fehler.

## Remaining Risk (PR #15 Review)

- Bis ein eigener lagerortspezifischer Sortimentsvertrag existiert, dient
  Ledger-Aktivitaet als konservativer Sichtbarkeitsnachweis. Das verhindert
  Fehlalarme, kann aber einen neu geplanten Artikel ohne erste Buchung noch
  nicht als `0` anzeigen. Die Domain-Projektion selbst bleibt unveraendert.
- Die Ansicht bleibt bewusst read-only und sandbox-lokal; keine produktive
  Persistenz oder Bestellautomatik wurde aktiviert.

## Scope

The user reported the live guest-web deployment and ended the broader
multi-model working setup. This branch aligns the repository with the actual
integrated state and records Claude Code plus Codex as the only active agents
until further notice. Earlier GLM, DeepSeek, Kimi and MiniMax contributions and
handoffs remain historical context.

The previously open GLM PR #15 (`KL-INVENTORY-002`) was reviewed, corrected and
merged before this cleanup was rebased. Its implementation and review record
remain intact; the cleanup itself stays focused on repository, collaboration
and guest-web maintenance.

## Changes

- Replaced the unusable root `README.md` (two insulting lines) with a proper
  project entry point, live sandbox link, repository map, local guest-web setup
  and source-of-truth links.
- Updated `CURRENT.md`, `DECISIONS.md`, `AGENTS.md`, `PEER_WORKFLOW.md` and the
  queue header for the live Hostinger/Supabase sandbox and the Claude/Codex-only
  working setup.
- Corrected stale Vercel, three-migration, local-menu-only and no-order claims
  in the guest-web README and sandbox setup guide. ADR-001 now clearly marks
  its hosting comparison as historical for sandbox use.
- Corrected `menu-loader.ts`: it previously claimed to respect database
  `sort_order` but actually sorted items by slug. The mapper now preserves
  category/item sort order with a slug tie-breaker; the load-bearing
  `GuestMenuItem.id == menu_items.slug` invariant is unchanged. Added a
  regression assertion whose slug order deliberately differs from DB order.
- Added a narrow npm override from Next.js's pinned vulnerable PostCSS 8.4.31
  to compatible PostCSS 8.5.19. The lockfile was regenerated; audit findings
  fell from two moderate entries to zero.

## Verification

From `guest-web/` after a clean dependency install:

- `npm run typecheck` — passed
- `npm run lint` — passed
- `npm test` — 50/50 passed
- `npm run build` — passed; `/[venueSlug]/menu` remains 1-minute ISR
- `npm run test:integration` — 8 tests skipped as designed without local
  sandbox credentials/`KL_INTEGRATION=1`; earlier real-instance results remain
  documented, but were not rerun in this worktree
- `npm audit --json` — 0 vulnerabilities
- `git diff --check` — passed
- Public read-only smoke: `https://kitchenlink.luneq.eu/alte-muehle/menu`
  returned HTTP 200 via Hostinger/Next.js cache and contained the expected
  Alte Muehle menu. No live order was submitted during this cleanup.

## Remaining / Recommended Next Step

1. Product decisions for the network-side venue hub, PWA/offline behavior,
   anonymous-user retention and production hosting remain open.
