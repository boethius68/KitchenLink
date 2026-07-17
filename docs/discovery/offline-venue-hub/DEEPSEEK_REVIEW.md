# Adversarial Red-Team Review: GLM Venue-Hub-Architektur

**Reviewer:** DeepSeek (Red-Team-Instanz)  
**Geprüfte Version:** GLM_ARCHITECTURE.md v1 (Commit c07115b)  
**Datum:** 2026-07-16  
**Prüfgegenstand:** Lokaler Venue-Hub gemäß GLM-Architekturentwurf  
**Auftrag:** KL-OFFLINE-002 – unabhängiger, nicht bestätigender Red-Team-Review  

---

## Zusammenfassung

GLM hat eine umfangreiche, quellenbasierte Zielarchitektur vorgelegt. Die Recherche ist gründlich (55 Quellen), die Komponentenstruktur ist logisch und die Abgrenzung zu verworfenen Alternativen ist nachvollziehbar. Die Architektur hat jedoch **fundamentale Lücken in drei der vier Kernbereiche**, die ein Go zum jetzigen Stand nicht rechtfertigen.

| Komponente | Rating | Begründung |
|---|---|---|
| **Lokales Event-Log** (SQLite/WAL/GRDB) | ⚠️ BEDINGT GO | Fundament solide, aber Details fehlen |
| **Lokaler HTTP-Server** (NWListener) | ❌ NO-GO | Mixed Content, Secure Context, CORS, keine TLS |
| **Gastzugriff** (QR→Browser→Hub) | ❌ NO-GO | AP-Isolation, mDNS heterogen, HTTPS-Zwang |
| **Mehrgeräte-Failover** (Lease/SWIM) | ❌ NO-GO | SWIM unreif auf iOS, 60s-Lücke, kein Epoch, kein Fencing |

---

## P0 – Blocking (muss vor Implementierung gelöst sein)

### P0-01: Mixed Content & Secure Context blockieren Gast-Browser

**Wo:** GLM_ARCHITECTURE.md §2.2, §3, §6 Stufe 2–3, GLM_SOURCES.md [S07][S08]  
**Risiko:** Der Gast öffnet die Web-App über HTTPS (von Supabase/Cloudflare ausgeliefert). Die Web-App muss `fetch()` an den lokalen Hub senden. Der lokale Hub läuft auf `http://<ip>:<port>` – das ist **Mixed Content**. Browser blockieren aktive Mixed-Content-Anfragen (seit Chrome 86/Safari 15) vollständig.  

**Primärquelle:**  
- `https://developer.mozilla.org/en-US/docs/Web/Security/Mixed_content` – "Active mixed content is blocked by all major browsers"
- `https://www.w3.org/TR/mixed-content/` – "block-all-mixed-content" ist Default in modernen Browsern

**Reproduktion:**  
1. Gast öffnet QR → `https://kitchenlink.app/venue/{slug}` (HTTPS)  
2. Seite lädt JavaScript, das `fetch('http://192.168.1.5:8080/orders', ...)` aufruft  
3. Browser blockiert: "Mixed Content: The page at 'https://...' was loaded over HTTPS, but requested an insecure resource..."  

**Zusätzlich:** Safari verlangt für Service Worker, Geolocation, LocalStorage (in einigen Kontexten) einen **Secure Context** (`https://`, `http://localhost`, `http://127.0.0.1`). `http://192.168.1.x` ist **kein** Secure Context. PWA-Features (Offline-Caching, Background-Sync) sind auf dem Gastgerät nicht nutzbar.  

**Minimale Korrektur:** Entscheidung des Users erforderlich:  
- **Option A:** Hub stellt HTTPS mit einer lokal vertrauenswürdigen CA aus (Apple-CA via `SecCertificateCreateWithData` + lokaler DNS-Name) – machbar aber komplex  
- **Option B:** Lokale Gastoberfläche wird direkt vom Hub als HTTP-Seite ausgeliefert (QR zeigt `http://hub-name.local:8080/menu`) – keine Mixed-Content-Probleme, aber kein Secure Context  
- **Option C:** iPhone/iPad als Wi-Fi Hotspot – Hub erzeugt eigenes Netz, keine AP-Isolation, aber Gast muss WLAN wechseln  

**GLM-Referenz:** GLM listet HTTPS als offene Produktentscheidung (§1.3, Anhang B) aber **unterschätzt die Dringlichkeit**: Es blockiert nicht nur Stufe 3, sondern bereits jede noch so einfache Gast-Hub-Kommunikation über HTTPS-geladene Webseiten.

### P0-02: AP Isolation / Client Isolation macht lokale Kommunikation unmöglich

**Wo:** GLM_ARCHITECTURE.md §1.2 Annahme 1, §1.3 Risiko 1  
**Risiko:** Die gesamte Architektur setzt voraus, dass Geräte im Restaurant-WLAN einander direkt erreichen können. In unzähligen kommerziellen WLANs (FritzBox, UniFi, Cisco Meraki) ist **AP Isolation / Client Isolation** standardmäßig aktiviert. Dadurch können Geräte im selben WLAN **keine** direkten TCP-Verbindungen aufnehmen, kein mDNS/Bonjour, keine UDP-Kommunikation.  

**Reproduktion:**  
1. Venue hat FritzBox 7590 mit "WLAN-Isolierung" aktiviert (Standard bei Gast-WLANs)  
2. Hub-Gerät (iPad) und Gast-iPhone sind im selben WLAN  
3. Gast scannt QR → Browser öffnet `http://kitchenlink-hub.local:8080`  
4. mDNS-Query kommt nicht am Hub an → `.local` aufgelöst  
5. Selbst bei IP: TCP SYN vom Gast an Hub-Port wird vom Access Point verworfen  

**Primärquelle:**  
- `https://www.fritzbox-ratgeber.de/fritzbox-wlan-isolierung-einrichten/` – Standardeinstellung  
- `https://help.ubnt.com/hc/en-us/articles/360007897694-UniFi-Layer-2-Isolation` – UniFi Client Isolation  

**GLM-Referenz:** GLM erkennt dies als P0-Risiko (§1.3) und listet es als offene Frage (Anhang B). Aber die Architektur ist ohne Lösung dieser Frage nicht implementierbar. Die Architektur sollte zwei Pfade vorsehen (mit/ohne AP Isolation) oder eine Alternative zur WLAN-basierten Kommunikation definieren.

### P0-03: Keine Transport-Sicherheit im lokalen WLAN

**Wo:** GLM_ARCHITECTURE.md §2.2, §4.2, kein Kapitel zu Security/Transport-Encryption  
**Risiko:** Die gesamte lokale Kommunikation (Gast→Hub, Replica→Hub) läuft über unverschlüsseltes TCP. In einem Restaurant-WLAN können beliebige Gäste:  
- Bestellungen mitsniffen (Name, Tischnummer, Bestelldetails, Preis)  
- Gefälschte Bestellungen einschleusen  
- Bestellungen manipulieren (Mengen ändern, löschen)  
- Bonjour-Spoofing betreiben (eigenen NWListener als Hub advertisen)  

**Reproduktion:**  
1. Gast startet Wireshark im Restaurant-WLAN  
2. Filtert nach `tcp.port == 8080`  
3. Sieht alle Bestellungen in Klartext (JSON over TCP)  
4. Sendet gefälschte `POST /orders` mit beliebigen Daten  

**Minimale Korrektur:** TLS für lokale Kommunikation. Aber TLS setzt Zertifikate voraus, die Browser akzeptieren (s. P0-01). Für Staff-Geräte: mTLS mit Client-Zertifikat + Geräte-HMAC.

### P0-04: 60-Sekunden-Failover-Lücke

**Wo:** GLM_ARCHITECTURE.md §4.2 Lease-Mechanismus ("2× Lease-Zeit" = 60s)  
**Risiko:** Wenn der Hub ausfällt (App-Crash, Akku leer, Bildschirmsperre), dauert es **bis zu 60 Sekunden**, bis ein neuer Hub aktiv ist. In dieser Zeit:  
- Nimmt kein Gerät Bestellungen an  
- Alle Mitarbeiter sehen "Verbindung zum Hub verloren"  
- Gäste sehen Fehler oder Timeout  

**Reproduktion:**  
1. Betreiber öffnet Hub-App auf iPhone  
2. Telefon klingelt → App geht in Hintergrund → NWListener stoppt (S22)  
3. SWIM-Heartbeats bleiben aus  
4. Nach 30s (1× Lease) + 2s Toleranz = max 60s: Failover ausgelöst  
5. 60s ohne Bestellannahme  

**Minimale Korrektur:** Lease-Zeit auf 5s reduzieren, Heartbeat-Intervall auf 1s. Oder: "Hot Standby" mit warmem Replica-Device (hat Event-Log bereits geladen). **Aber:** SWIM-Garantien sind nur "eventuell" – kurze Intervalle erhöhen False-Positives.

### P0-05: SWIM auf iOS nicht produktionsreif

**Wo:** GLM_ARCHITECTURE.md §4.2, GLM_SOURCES.md [S40]  
**Risiko:** Der einzige Swift-SWIM-Prototyp [S40] ist ein nicht gewartetes Hobby-Projekt (2 GitHub-Stars, letzter Commit 2017). Es gibt:  
- Keine iOS-Produktionsdeployment-Erfahrung mit SWIM  
- Keine Validierung im Restaurant-WLAN mit hoher Störung (Mikrowellen, Bluetooth, viele Clients)  
- Keine Integration in iOS Background-Modi (App wird suspendiert → SWIM-Heartbeats stoppen)  

**Primärquelle:**  
- `https://github.com/1amageek/swift-SWIM` – 2 Stars, 1 Fork, nicht gewartet  
- `https://www.cs.cornell.edu/projects/Quicksilver/public_pdfs/SWIM.pdf` – SWIM-Papier selbst: "eventuell", nicht "garantiert in bounded time"  

**Minimale Korrektur:** SWIM durch einen einfacheren, iOS-native Mechanismus ersetzen: Bonjour-Heartbeat (jeder Hub advertiset seinen Service, Replica-Geräte überwachen den Service via NWBrowser. Wenn der Service verschwindet, gilt Hub als tot). Oder: Keepalive via regelmäßiger SQLite-Write (letzte Heartbeat-Zeit in Shared SQLite? Geht nicht bei mehreren Geräten.) – am einfachsten: Mitgliederverwaltung über Supabase Realtime + lokalen Bonjour-Health-Check.

---

## P1 – Hoch (sollte vor Integration gelöst sein)

### P1-01: Kein Epoch/Term im Event-Modell

**Wo:** GLM_ARCHITECTURE.md §3.1 VenueEvent (`prev_event_seq`)  
**Risiko:** Das Event-Modell verwendet `prev_event_seq` für die zeitliche Ordnung, aber **ohne Epoch/Term** (wie Raft ihn verwendet). Wenn Hub A seq 1–50 produziert, dann stirbt, und Hub B seq 1–50 produziert: Bei der Rückkehr von A überschreibt B's seq 40 A's seq 40 nicht – es gibt zwei seq 40. Der `prev_event_seq` kann nicht unterscheiden, zu welchem Hub-Generation ein Event gehört.  

**Reproduktion:**  
1. Hub A erzeugt Events seq 1–50  
2. Hub A stürzt ab  
3. Hub B übernimmt, schreibt `HubLeaseAcquired` (seq 1 in B's Log)  
4. Hub B erzeugt Events seq 2–30 für neue Bestellungen  
5. Hub A kommt zurück, synct seine seq 1–50 an B  
6. B's Konfliktlöser sieht Event A:seq_40 (OrderStatusChanged → preparing) und B:seq_20 (OrderStatusChanged → ready) für dieselbe Order – **beide haben `prev_event_seq` aus unterschiedlichen Generationen**  
7. System kann nicht entscheiden, welches "jünger" ist  

**Minimale Korrektur:** Event `hub_epoch` (monoton steigende Zahl, die mit jedem Hub-Wechsel inkrementiert wird) oder `term` (Raft-Term) ins VenueEvent aufnehmen. `(epoch, event_seq)` statt nur `event_seq` für globale Ordnung.

### P1-02: Event-Log Recovery nach Hub-Verlust

**Wo:** GLM_ARCHITECTURE.md §4.3 Wiederanlauf  
**Risiko:** Wenn das Hub-Gerät physisch zerstört wird, gestohlen wird oder der Speicher korrumpiert ist, sind **alle Events auf diesem Gerät verloren** – auch solche, die noch nicht in die Cloud repliziert wurden (z.B. Bestellungen aus den letzten Minuten vor dem Ausfall, bei denen der Outbox-Sync noch nicht abgeschlossen war).  

**Reproduktion:**  
1. Akku des Hub-iPhone ist bei 3%  
2. Letzte drei Bestellungen (Events seq 48–50) wurden lokal committet, aber Outbox hat noch nicht an Supabase gesendet  
3. iPhone stirbt, Akku leer  
4. Failover zu Hub B – aber B's Event-Log endet bei seq 47 (letzte Replikation)  
5. Die Bestellungen seq 48–50 sind unwiederbringlich verloren  

**Minimale Korrektur:** Replikation an mindestens ein weiteres Gerät muss **synchron** (innerhalb der Transaktion) erfolgen, bevor ACK an den Gast geht. Oder: jedes Replica-Gerät hat eine "letzte bekannte Event-Sequenz" und der Hub schreibt mit Write-Ahead-Log, das asynchron auf ein zweites Gerät gespiegelt wird.

### P1-03: Bonjour-Zuverlässigkeit auf iOS (seit iOS 14)

**Wo:** GLM_ARCHITECTURE.md §4.1 (Hub-Discovery über Bonjour), GLM_SOURCES.md [S12]  
**Risiko:** GLM zitiert selbst die Quelle [S12] – "Bonjour broken in iOS 14". Das Advertising kann ohne erkennbaren Grund aufhören. Der `NWListener` mit Bonjour-Advertising ist insbesondere betroffen, wenn:  
- Das Gerät in den Hintergrund geht (auch kurz durch System-Notification)  
- Das WLAN wechselt (Roaming zwischen Access Points)  
- Das Gerät in den Low-Power-Mode wechselt  

**Reproduktion:**  
1. Hub läuft, advertiset `_kitchenlink-hub._tcp`  
2. Hub erhält Push-Notification → App bleibt im Vordergrund, aber Bonjour-Advertising stoppt (iOS-Bug)  
3. Replica-Geräte sehen `NWBrowser`-Ergebnis = leer  
4. Replica denkt "Hub ist tot" → initiiert Failover → **falscher Failover**  

**Minimale Korrektur:** Bonjour als primäre Discovery, aber mit:  
- Redundanter IP-basierter Discovery (QR-Code enthält IP + Port des Hubs, aktualisiert per Heartbeat)  
- Heartbeat-Überwachung zusätzlich zur Bonjour-Anwesenheit  
- Failover erst nach fehlgeschlagenem Heartbeat + Bonjour-Abfrage

### P1-04: HTTP-Server-Komplexität unterschätzt

**Wo:** GLM_ARCHITECTURE.md §2.2 Komponente A1 (`VenueHTTPServer`), GLM_SOURCES.md [S07][S08]  
**Risiko:** GLM verweist auf [S07] (ein Blog-Post mit 30 Zeilen HTTP-Server) und [S08] (ein 3rd-Party NWProtocolFramer). Ein produktionsreifer HTTP/1.1-Server muss:  
- HTTP-Methoden und Pfade korrekt parsen  
- Chunked Transfer-Encoding unterstützen  
- Keep-Alive-Connections handhaben  
- CORS-Header setzen (Allow-Origin, Allow-Methods, Allow-Headers)  
- Request-Body-Größen limitieren  
- Timeouts für untätige Connections setzen  
- 100-continue-Handling  
- Content-Type-Parsing  
- URL-Encoding und Query-String-Parsing  

Die Referenzen decken **maximal 10%** dieser Anforderungen ab.  

**Reproduktion:**  
1. Gast-Browser sendet `POST /orders` mit `Content-Type: application/json`  
2. Browser erwartet `Access-Control-Allow-Origin: *` im Response (CORS-Preflight mit OPTIONS)  
3. NWListener-Server hat keinen CORS-Handler → Browser blockiert Response  
4. Gast sieht "Netzwerkfehler"  

**Minimale Korrektur:** Entweder auf existierende Embedded-HTTP-Server zurückgreifen (SwiftNIO, Vapor, Kitura – aber die sind schwergewichtig) oder HTTP-Parsing von Grund auf mit vollständiger Testabdeckung implementieren. Oder: **statt HTTP einen WebSocket- oder Binary-Protokoll-Server auf NWListener**, mit einem proxierenden Service in der Business-App.

### P1-05: Supabase-Outbox/Inbox nur skizziert

**Wo:** GLM_ARCHITECTURE.md §2.2 Komponente A4, §3.4, GLM_SOURCES.md [S31]  
**Risiko:** Die Outbox/Inbox-Synchronisation wird in einem Satz beschrieben ("Outbox leer sequentiell; Dedup via client_idempotency_key"). Details fehlen:  
- **Konfliktprävention:** Was passiert, wenn Supabase während des Offline-Zeitraums per Management-UI eine Order storniert hat, die lokal noch aktiv ist?  
- **Schema-Änderungen:** Was, wenn Supabase-Migrationen das Schema ändern, während lokale Events im Outbox-Format der alten Schema-Version vorliegen?  
- **Reihenfolge:** Outbox-Events müssen **in der gleichen Reihenfolge** an Supabase gesendet werden, in der sie lokal committet wurden. Wie wird das sichergestellt?  
- **Transactional Outbox:** Outbox-Insert und Event-Insert müssen in derselben SQLite-Transaktion erfolgen. Ist im Modell vorgesehen, aber nicht explizit.  

**Minimale Korrektur:** Detail-Design für SyncCoordinator mit:  
1. Event-Sending in exakter Event-Seq-Reihenfolge  
2. Supabase-seitiger Idempotenz-Prüfung (via DB-Constraint auf `client_idempotency_key`)  
3. Fehlerbehandlung: Was bei Supabase-Validation-Error (kein Netzwerkfehler)?  
4. Schema-Version in Outbox-Events für Migration-Kompatibilität

---

## P2 – Mittel (sollte adressiert werden)

### P2-01: WAL-Checkpointing und Snapshotting fehlt

**Wo:** GLM_ARCHITECTURE.md §2.2 Komponente A2, §6 Stufe 1  
**Risiko:** Der Event-Store in SQLite mit WAL-Modus wird ohne Checkpointing- und Snapshotting-Strategie beschrieben. Ohne regelmäßige Checkpoints wächst die WAL-Datei unbegrenzt. Bei häufigen Write-Operationen (alle 30s eine Bestellung + 5 Statuswechsel in 8h Schicht = ~1000 Events) kann die WAL mehrere MB erreichen. Ohne Snapshots muss beim App-Start die gesamte Event-Historie seit Schichtbeginn replayt werden.  

**Minimale Korrektur:**  
- WAL-Checkpoint nach jedem COMMIT oder nach N Events (via `PRAGMA wal_checkpoint(TRUNCATE)`)  
- Snapshot-Intervall definieren (z.B. alle 50 Events oder alle 5 Minuten)  
- Snapshot-Tabelle mit `last_event_seq` + serialisierter Aggregate-State

### P2-02: mDNS-Auflösung auf Android/Windows nicht sichergestellt

**Wo:** GLM_ARCHITECTURE.md §2.3, §6 Stufe 3  
**Risiko:** Die Architektur setzt darauf, dass Gäste den Hub über `.local`-Adressen (mDNS) erreichen. mDNS wird auf iOS/macOS nativ unterstützt, auf Android ist die Unterstützung uneinheitlich (Chrome unzuverlässig, Samsung Browser unbekannt), auf Windows praktisch nicht vorhanden (kein mDNS-Resolver außerhalb von Apps).  

**Reproduktion:**  
1. Gast mit Samsung Galaxy S24 scannt QR → öffnet Browser  
2. QR enthält `http://kitchenlink-hub.local:8080`  
3. Chrome auf Android kann `.local` nicht auflösen → DNS-Fehler  
4. Gast sieht "Seite nicht gefunden"  

**Minimale Korrektur:** QR-Code muss alternative Zugangswege enthalten (IP + Port, oder NFC-Tag mit IP). Oder: Hub-IP wird per DHCP-Reservation fest vergeben und im QR statisch codiert. Aber das setzt Admin-Zugriff auf den Router voraus – unrealistisch für viele Restaurants.

### P2-03: HMAC-Schlüsselverteilung nicht spezifiziert

**Wo:** GLM_ARCHITECTURE.md §3.1 `signature: HMAC`  
**Risiko:** Das Event-Modell enthält eine HMAC-Signatur für Authentizität. Der HMAC-Schlüssel muss auf jedem Gerät verfügbar sein. Die Architektur spezifiziert **nicht**:  
- Wie wird der Schlüssel generiert? (Venue-Secret? Geräte-spezifisch?)  
- Wie wird er auf neue Geräte verteilt? (QR-Code? Supabase-API?)  
- Wie wird er rotiert?  
- Was passiert bei Schlüsselverlust? (Gerät resetet → alle Signaturen ungültig)  

**Minimale Korrektur:** Schlüsselmanagement-Design. Vorschlag: Venue-spezifischer HMAC-Key, generiert bei Venue-Erstellung in Supabase, abrufbar via authentifiziertem API-Call. Business-Geräte laden den Key beim ersten Start nach Authentifizierung.

### P2-04: MPC als Fallback nicht in Betracht gezogen

**Wo:** GLM_ARCHITECTURE.md §8.1  
**Risiko:** GLM verwirft MPC vollständig wegen des 8-Peer-Limits. Aber:  
- Für Staff-Geräte (1–5 Stück) ist MPC durchaus geeignet  
- MPC überlebt AP Isolation (es nutzt Bluetooth + Infrastructure Wi-Fi)  
- MPC könnte als **Fallback** dienen, wenn WLAN-Kommunikation (NWListener) ausfällt  
- Die Architektur hat keinen Fallback-Pfad für den Fall, dass Network.framework nicht funktioniert  

**Minimale Korrektur:** MPC als zweiten Transport-Layer für Staff-Kommunikation in Betracht ziehen, mit automatischem Fallback. Oder zumindest dokumentieren, warum MPC auch als Fallback nicht in Frage kommt (z.B. Background-Verhalten).

### P2-05: Kein Request-Rate-Limiting auf lokalen Endpunkten

**Wo:** `VenueHTTPServer` – keine Erwähnung von Rate-Limiting  
**Risiko:** Der lokale HTTP-Server hat keine Schutzmechanismen gegen:  
- `POST /orders`-Flooding (ein Gast sendet 1000 Bestellungen pro Sekunde)  
- Brute-Force von QR-Token-IDs oder Order-IDs  
- Große Payloads (JSON mit mehreren MB)  

**Reproduktion:**  
1. Gast (oder Skript im WLAN) sendet 10.000 `POST /orders` in 5 Sekunden  
2. NWListener akzeptiert alle, fork-t für jeden einen neuen Task  
3. SQLite kann nicht mithalten → WAL wächst → App wird langsam  
4. App wird von iOS wegen Speicherdruck beendet  

**Minimale Korrektur:** `NWParameters` + App-Layer Rate-Limiting. Max N Requests pro Minute pro IP. Max Body-Size 1 MB.

---

## P3 – Niedrig (Beobachtungen)

### P3-01: ULID-Kollision bei schneller Event-Erzeugung

**Wo:** GLM_ARCHITECTURE.md §3.2 (`event_id: ULID`)  
ULIDs bestehen aus Timestamp (ms-Genauigkeit) + Randomness. Bei sehr schneller Event-Erzeugung (durch Automation oder mehrere gleichzeitige Requests) können ULIDs auf demselben Gerät kollidieren. Die Wahrscheinlichkeit ist gering, aber bei 10.000+ Events pro Schicht nicht vernachlässigbar. UUIDv7 (in iOS 17+ verfügbar) hat 74 Bit Randomness statt 80 Bit bei ULID, ähnliches Risiko.  

**Minimale Korrektur:** `event_seq` + device_id als Primärschlüssel, ULID nur als sortierbare ID.

### P3-02: GRDB-Version-Pinning fehlt

**Wo:** GLM_ARCHITECTURE.md §2.2 Komponente A2, GLM_SOURCES.md [S33]  
GRDB.swift ist aktiv entwickelt. Ohne Version-Pinning in `Package.swift` oder `Podfile` kann ein zukünftiges GRDB-Release die API ändern und die Architektur brechen.

### P3-03: `shift_id` ohne Lebenszyklus

**Wo:** GLM_ARCHITECTURE.md §3.1 VenueEvent  
`shift_id` wird im Event-Modell geführt, aber der Lebenszyklus einer Schicht wird nicht beschrieben:  
- Wer erstellt eine Schicht?  
- Wann beginnt/endet sie?  
- Werden Events mit abgelaufener `shift_id` akzeptiert oder zurückgewiesen?  
- Dürfen Events ohne gültige `shift_id` existieren?

### P3-04: UUIDv7 nicht auf iOS < 17 verfügbar

**Wo:** GLM_ARCHITECTURE.md §3.2 (`aggregate_id: UUIDv7`)  
`UUIDv7` ist erst ab iOS 17 verfügbar (`UUID.init(v7:)`). Der Sandbox-Beta-Zeitraum könnte noch iOS 15/16 unterstützen müssen. Ein Fallback-Mechanismus (UUIDv4 + ULID für Sortierung) ist nicht spezifiziert.

---

## Faktencheck: GLM-Quellenbehauptungen

| GLM-Behauptung | Quelle | Bewertung |
|---|---|---|
| MCSession max 8 Peers | [S14] | ✅ **Korrekt** – Apple-Dokumentation |
| NWListener kann TCP+Bonjour | [S01][S03] | ✅ **Korrekt** |
| NWBrowser findet Bonjour | [S04][S06] | ✅ **Korrekt** |
| NSLocalNetworkUsageDescription Pflicht seit iOS 14 | [S24] | ✅ **Korrekt** |
| Privacy Manifest Pflicht seit Mai 2024 | [S26][S27] | ✅ **Korrekt** |
| SQLite WAL: mehrere Reader + ein Writer | [S28][S32] | ✅ **Korrekt** |
| Raft nicht byzantinisch-fehlertolerant | [S38] | ✅ **Korrekt** |
| SWIM garantiert eventuelle Fehlerekennung | [S39] | ✅ **Korrekt** – aber "eventuell" ist die Einschränkung |
| Supabase kein native Offline-Sync | [S43] | ✅ **Korrekt** – GitHub Discussion bestätigt |
| MPC unzuverlässig in Produktion | [S16] | ⚠️ **Veraltet** – Quelle von 2015 (objc.io). MPC hat sich bis iOS 17 verbessert. Für Staff-only (1–5 Geräte) immer noch akzeptabel. |
| Apple-Mitarbeiter empfehlen Network.framework | [S20] | ⚠️ **Kontextabhängig** – Apple Developer Forum Link ist generisch. Empfehlung variiert nach Use Case. Für einfache lokale Staff-Kommunikation ist MPC weiterhin von Apple supported. |
| swift-SWIM ist Swift-Referenzimplementierung | [S40] | ❌ **Irreführend** – 2 GitHub Stars, 8 Commits, letzter Commit 2017. Keine Produktionserfahrung. Keine Tests. Keine iOS-Doku. |
| NWHTTPProtocol ist verwendbarer HTTP-Framer | [S08] | ❌ **Unvollständig** – 3rd-Party-Bibliothek, unklar ob CORS, Chunked-Encoding, Keep-Alive unterstützt |

---

## Failure-Matrix (adversarial erweitert)

Legende: ✅ funktionsfähig / ⚠️ eingeschränkt / ❌ nicht funktionsfähig / — nicht betroffen

| Szenario | Gast-bestellung | Mitarbeiter-gerät | Hub | Cloud-Sync | GLM-Einschätzung | Adversarial-Bewertung |
|---|---|---|---|---|---|---|
| **Internetverlust** (WLAN intakt) | ✅ lokal | ✅ repliziert | ✅ autoritativ | ❌ pausiert | wie GLM | ✅ **Bestätigt** – Outbox-Pattern korrekt |
| **Hub stürzt ab** | ⚠️ 60s Lücke | ⚠️ offline | ✅ Failover | entkoppelt | ⚠️ wie GLM | ⚠️ **Aber:** 60s sind zu lang; Replica-Log evtl. hinter Hub; SWIM-False-Positive |
| **WLAN-Ausfall** (komplett) | ❌ | ❌ | ❌ | ❌ | wie GLM | ❌ **Bestätigt** – §16.2 akzeptiert dies |
| **App-Hintergrund** (Hub) | ❌ Server stoppt | ❌ Sessions enden | ❌ | — | ❌ wie GLM | ❌ **Bestätigt** – GLM sagt korrekt "muss im Vordergrund bleiben" |
| **AP Isolation aktiv** | ❌ | ⚠️ Staff ggf. | ✅ isoliert | ✅ | ❌ (P0 Risiko) | ❌ **Noch schärfer** – auch Staff-Kommunikation blockiert bei strikter Isolation; keine Alternative spezifiziert |
| **Two Hubs gleichzeitig** | ⚠️ beide nehmen an | ⚠️ konkurrierend | ⚠️ | ⚠️ | ⚠️ wie GLM | ⚠️ **Aber:** epoch/term fehlt → Logs nicht unterscheidbar nach Reunion |
| **Hub-Gerät gestohlen** | ❌ alle Events weg | ❌ | ❌ | ✅ nur gesyncte | ❌ **fehlt** | ❌ **Nicht betrachtet** – Event Recovery fehlt |
| **Android-Gast** (mDNS-fail) | ❌ | — | — | — | ❌ **fehlt** | ❌ **Nicht betrachtet** – mDNS-Auflösung auf Android/Windows |
| **Mixed Content** (HTTPS-Seite → HTTP-Hub) | ❌ Browser blockiert | — | — | — | ❌ **fehlt** | ❌ **Nicht betrachtet** – GLM erkennt nur "HTTPS-Lösung nötig" als offene Frage, nicht den Mixed-Content-Blocker |
| **HMAC-Key kompromittiert** | — | ⚠️ Spoofing | ⚠️ | — | ❌ **fehlt** | ❌ **Nicht betrachtet** – Kein Schlüsselmanagement |
| **Staff-Gerät nicht authentifiziert** | — | ✅ Spoofing möglich | — | — | ⚠️ Annahme "vertrauenswürdig" | ❌ **Risiko unterschätzt** – Annahme "Mitarbeitergeräte sind authentifiziert und vertrauenswürdig" (§1.2) ohne Spezifikation, wie das erreicht wird |

---

## Go / No-Go Bewertung

### 1. Lokales Event-Log (SQLite + WAL + GRDB)

**Urteil: ⚠️ BEDINGTES GO**

**Begründung:** Der Ansatz ist solide. SQLite mit WAL, append-only Events, Idempotenz-Tabelle und GRDB `DatabasePool` sind bewährte Technologien. GLMs Designprinzipien (§16.3-konform) sind korrekt.

**Bedingungen für Go:**
1. ✅ GRDB-Version in Package.swift pinning
2. ✅ WAL-Checkpointing-Strategie definieren (nach N Events oder periodisch)
3. ✅ Snapshot-Intervall definieren (alle 50 Events)
4. ✅ Transactional Outbox: Outbox-Insert in derselben SQLite-Transaktion wie Event-Insert
5. ✅ Migration der LocalDemoRepository-Tests auf SQLite (alte Tests weiterhin grün, §18.1)
6. ✅ iOS-Crash-Simulation testen (os_crash während COMMIT → WAL-Recovery)

### 2. Lokaler HTTP-Server (NWListener)

**Urteil: ❌ NO-GO**

**Begründung:** Das Risiko ist zu hoch für den aktuellen Stand:
- Kein TLS → unverschlüsselte Kommunikation (Geld-strafbar bei Zahlungsdaten)
- Komplexität des HTTP/1.1-Servers massiv unterschätzt
- CORS, Mixed Content, Secure Context nicht adressiert
- Request-Rate-Limiting, Body-Size-Limits, Timeouts fehlen
- NWHTTPProtocol [S08] ist ein unzureichendes 3rd-Party-Projekt

**Empfehlung:** Statt eines HTTP-Servers auf dem Hub:
- **Option A:** Native Business-App auf dem Gast-iPhone (widerspricht Blueprint §3.1: "kein App-Download")
- **Option B:** Der Hub stellt nur WebSocket-Endpunkte bereit, die Business-App fungiert als Proxy zwischen Gast-Browser und Hub (Browser→Supabase→Hub via WebSocket) – aber das setzt Internet voraus
- **Option C:** Gast-Web läuft komplett lokal auf dem Hub (QR zeigt `http://hub-ip:8080` – gesamte Web-App vom Hub ausgeliefert) – kein Mixed Content, da alles HTTP ist – aber: kein Secure Context für PWA-Features

### 3. Gastzugriff (QR → Browser → Hub)

**Urteil: ❌ NO-GO**

**Begründung:** Drei ungelöste P0-Probleme:
1. Mixed Content (P0-01) – HTTPS-Seite kann HTTP-Hub nicht erreichen
2. AP Isolation (P0-02) – oft blockiert
3. mDNS/Android (P2-02) – große Nutzergruppe ausgeschlossen

Der Gastzugriff im lokalen Modus kann erst implementiert werden, wenn **alle drei** Probleme gelöst sind.

### 4. Mehrgeräte-Failover (Leader-Election + SWIM + Replication)

**Urteil: ❌ NO-GO**

**Begründung:**
- SWIM (P0-05) ist auf iOS nicht produktionsreif
- 60s-Failover (P0-04) ist für Restaurantbetrieb zu lang
- Kein Epoch/Term (P1-01) macht Event-Logs nach Failover nicht eindeutig zuordenbar
- Kein Fencing (P0-04 Zusatz) – alter Hub kann weiter schreiben
- Event Recovery nach Hub-Verlust (P1-02) nicht spezifiziert

**Empfehlung:** Failover auf Stufe 7 verschieben (GLM sieht es in Stufe 6 – das ist zu früh). Zuerst:
1. Warm-Standby mit synchro-ner Replikation auf mindestens ein zweites Gerät
2. Bonjour-basierte Heartbeat-Erkennung statt SWIM (P0-05)
3. Epoch in Event-Modell aufnehmen (P1-01)
4. Failover-Latenz auf ≤5s reduzieren
5. Event-Recovery spezifizieren (auch bei totalem Hub-Verlust)

---

## Offene Fragen (muss der User entscheiden)

1. **HTTP vs. HTTPS auf dem Hub (P0-01):** Darf der Hub HTTP ausliefern (QR zeigt `http://...`) oder muss HTTPS verwendet werden? Falls HTTPS: Self-Signed-CA mit manueller Vertrauenseinrichtung oder Apple-CA über lokalen DNS?

2. **WLAN-Isolation (P0-02):** Ist bekannt, ob Referenz-Venues AP-Isolation aktiv haben? Dürfen wir eine separate Staff-SSID voraussetzen oder muss das System mit einer einzigen geteilten SSID funktionieren?

3. **Priorität des Gastzugriffs (P0-01/P0-02):** Soll der lokale Gastzugriff (Browser→Hub) überhaupt entwickelt werden, oder reicht Cloud-Betrieb + lokaler Staff-Betrieb für die Sandbox? Der lokale Gastzugriff könnte auf "nach Sandbox" verschoben werden.

4. **SWIM vs. Bonjour-Heartbeat (P0-05):** Darf SWIM durch einen einfacheren Mechanismus ersetzt werden, oder ist SWIM als Architekturentscheidung gewünscht?

5. **Failover-Latenz (P0-04):** Ist eine 60-Sekunden-Unterbrechung akzeptabel, oder muss der Failover in ≤5s erfolgen? (Letzteres erfordert Hot Standby)

6. **Event Recovery (P1-02):** Ist Datenverlust bei Hub-Verlust akzeptabel, solange die Cloud-USV gewahrt bleibt? Oder muss synchrone Replikation auf ein zweites Gerät erfolgen?

7. **HTTP-Server-Komplexität (P1-04):** Dürfen externe Abhängigkeiten wie SwiftNIO oder Vapor für den HTTP-Server verwendet werden, oder muss der Hub bei "Zero zusätzlichen Abhängigkeiten" bleiben?

---

## Anhang: Quellenverifikation

### Geprüfte GLM-Quellen
Die 55 Quellen in GLM_SOURCES.md wurden stichprobenartig auf Aktualität und Relevanz geprüft:

| # | Quelle | Abruf | Status |
|---|---|---|---|
| S01 | Network Apple Docs | 2026-07-16 | ✅ Aktiv |
| S02 | WWDC 2018 Network.framework | 2018 | ✅ Grundsolide |
| S07 | Simple Web Server (ko9.org) | – | ⚠️ 23 Zeilen, kein Produktionscode |
| S08 | NWHTTPProtocol GitHub | – | ❌ Ungewartet, 12 Forks |
| S14 | MCSession Apple Docs | aktuell | ✅ Aktiv |
| S33 | GRDB.swift GitHub | aktuell | ✅ Aktiv, ~4700 Stars |
| S40 | swift-SWIM GitHub | 2017 | ❌ Dead Project (2 Stars) |
| S43 | Supabase Offline Discussion | 2026-07-16 | ✅ Aktiv |

### Zusätzliche, von GLM nicht betrachtete Quellen
Diese Quellen sind relevant für die Architektur, aber in GLM_SOURCES.md nicht enthalten:

- **`https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts`** – Secure-Context-Anforderungen für PWA und Browser-APIs  
- **`https://www.w3.org/TR/mixed-content/`** – Mixed-Content-Spezifikation  
- **`https://developer.apple.com/documentation/network/network_framework`** – NWListener Advanced Usage (Connection Grouping, etc.)  
- **`https://developer.apple.com/documentation/foundation/urlsession/websocket_task`** – URLSessionWebSocketTask als Alternative zu NWListener (iOS 13+)  
- **`https://datatracker.ietf.org/doc/html/rfc6762`** – mDNS-Spezifikation (Multicast DNS)  
- **`https://developer.apple.com/documentation/uikit/app_and_environment/scene_preventing_suspension`** – iOS Suspension-Prävention (BGTaskScheduler, KeepAlive)
