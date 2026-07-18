# Integration Review: Offline Venue Hub Discovery

**Reviewer:** Claude Code
**Datum:** 17. Juli 2026
**Geprüftes Material:** `GLM_ARCHITECTURE.md`, `GLM_SOURCES.md`,
`DEEPSEEK_REVIEW.md`, `STAGE1_EVENT_LOG_CONTRACT.md`, `LOCAL_NETWORK_POC.md`
(alle in diesem Verzeichnis, aus `deepseek/offline-venue-hub-review` extrahiert)
**Status:** Discovery mit genehmigter Produktrichtung. Der Nutzer hat am
18. Juli 2026 lokale Gastbestellung bei Cloud-Ausfall als Pflicht der
Sandbox-Beta bestaetigt. Eine konkrete Netzwerkimplementierung ist damit noch
nicht freigegeben. Diese Datei ist die verbindliche Lesart, wie das Material zu
verwenden ist — analog zu
`docs/discovery/taxonomy-research/INTEGRATION_REVIEW.md`.

---

## 1. Was dieses Material ist

Zwei Agenten haben den lokalen Venue-Hub (Blueprint §16) als Discovery
bearbeitet, ohne Produktcode zu ändern:

- **GLM** lieferte eine umfangreiche, quellenbasierte Zielarchitektur
  (`GLM_ARCHITECTURE.md`, 55 Quellen): HTTP-/WebSocket-Server auf `NWListener`,
  SQLite/WAL-Event-Log, Lease-basierte Leader-Election mit SWIM-Gossip,
  Outbox/Inbox-Cloud-Sync, sowie eine begründete Verwerfung von MPC, reinem
  CRDT, reinem Supabase und vollem Raft.
- **DeepSeek** führte ein adversariales Red-Team durch (`DEEPSEEK_REVIEW.md`)
  und leitete daraus zwei konkrete Folgeartefakte ab: einen minimalen
  **Stage-1-Event-Log-Contract** (`STAGE1_EVENT_LOG_CONTRACT.md`) und eine
  **Netzwerk-POC-Testmatrix** (`LOCAL_NETWORK_POC.md`).

Das Material ist gründlich, primärquellengestützt und in sich konsistent. Es
ist **Erkenntnisgrundlage, keine Umsetzungsfreigabe.**

## 2. Der wichtigste Befund: Stage 1 ist bereits gebaut

Beide Dokumente wurden am 16. Juli geschrieben. Am 17. Juli wurde
**KL-OFFLINE-003** (`prototypes/KitchenLinkEventLog/`) reviewt und in `main`
integriert. Dieser Prototyp ist faktisch eine Umsetzung genau des Teils, dem
DeepSeek als einzigem ein „bedingtes Go" gab: das lokale, autoritative,
append-only Event-Log mit Outbox und Idempotenz.

Die beiden Entwürfe **konvergieren im Prinzip, divergieren in der Umsetzung**:

| Aspekt | Stage-1-Contract (Discovery) | KL-OFFLINE-003 (gemergt) |
| --- | --- | --- |
| SQLite-Zugriff | GRDB.swift (externe Abhängigkeit) | direktes `SQLite3`-Modul, kein Fremd-Package |
| Idempotenz | `client_idempotency_key` allein | `(venue_id, idempotency_key, request_fingerprint)` |
| Sequenz | `AUTOINCREMENT` | `MAX(local_seq)+1` unter RESERVED-Sperre, `WITHOUT ROWID` |
| Tabellen | events, idempotency, outbox, schema_version | events, aggregate_revisions, outbox, schema_meta |
| Reifegrad | Contract (Spezifikation) | ausführbar, 35 Tests grün |
| Einbettung | „Migration von `LocalDemoRepository`" | isoliertes Package, noch keine App-Integration |

**Lesart:** Der gemergte Prototyp ist auf der Abhängigkeitsachse die stärkere
Wahl — er hält Blueprint §18.1 („kontrollierter Neuaufbau") ein und fügt
keine GRDB-Laufzeitabhängigkeit hinzu, während die iOS-Seite ansonsten
abhängigkeitsarm bleibt. Der Stage-1-Contract hat aber einen Punkt, den der
Prototyp bewusst offenließ: **die eigentliche Integrationsnaht** — das
Einziehen des Event-Logs hinter dem bestehenden `KitchenLinkRepository`-
Protokoll, sodass `LocalDemoRepository` (UserDefaults) schrittweise ersetzt
wird, ohne Demo-Pfade zu entfernen. Diese Naht ist der nächste sinnvolle
Schritt und ist in `EVENT_LOG_V2.md` §12 als „später, freizugeben" markiert.

Wer den Venue-Hub weiterverfolgt, sollte **den gemergten Prototyp als Stage-1-
Basis nehmen** und den Stage-1-Contract nur noch als Vergleichsmaßstab für die
zwei offenen Punkte lesen (GRDB-vs-eigenes-SQLite ist entschieden zugunsten
eigenem SQLite; die `LocalDemoRepository`-Migrationsnaht bleibt zu bauen).

## 3. Belastbare Prinzipien (übernehmbar)

Diese Aussagen sind quellengestützt und stehen im Einklang mit Blueprint und
den bereits gemergten Arbeiten. Sie dürfen als Arbeitsgrundlage dienen:

- **Event Sourcing statt CRDT für den kritischen Kern.** Deterministische,
  fachspezifische Konfliktregeln mit sichtbarem `Konflikt`-Status erfüllen
  Blueprint §16.3 („niemals stille Last-write-wins-Regel"). CRDT bleibt
  allenfalls für rein additive, unkritische Daten. Deckt sich mit dem
  gemergten Prototyp.
- **ACK erst nach dauerhaftem Commit.** Der ACK-Vertrag (Event persistiert →
  dann ACK) ist in beiden Discovery-Dokumenten und im gemergten Prototyp
  identisch und setzt Blueprint §16.2 wörtlich um. Er ist außerdem in
  KL-WEB-002 auf der Cloud-Seite bereits verdrahtet (Status nur aus der
  Serverantwort).
- **Transactional Outbox.** Event-Insert, Idempotenz-Eintrag und Outbox-Eintrag
  in einer Transaktion; Reihenfolgegarantie beim Sync. Bewährtes Muster, im
  Prototyp umgesetzt.
- **„Messen statt annehmen".** DeepSeeks Disziplin (kein willkürliches
  WAL-Checkpoint-/Snapshot-Intervall, sondern gemessene Grenzen auf echten
  Geräten) ist die richtige Haltung für jede spätere Hub-Implementierung.
- **Verworfene Alternativen mit Begründung.** MPC (8-Peer-Limit,
  Hintergrundabbau), volles Raft (überdimensioniert) und externe Sync-Engines
  (Fremdabhängigkeit) sind nachvollziehbar ausgeschlossen. DeepSeeks Einwand,
  MPC als *Fallback* für 1–5 Staff-Geräte offenzuhalten, ist eine sinnvolle
  Ergänzung, keine Widerlegung.

## 4. Offene Entscheidungen und ungelöste Risiken (Nutzer/Verifikation)

Diese Punkte **blockieren** weiterhin eine Umsetzung des netzwerkseitigen
Hub-Teils. Die Produktrichtung ist entschieden; Transport, Netzwerkbetrieb und
Failover gehoeren weiterhin einer echten Geraetemessung und technischen
Abnahme, nicht einer unbelegten Agentenannahme:

- **P0 — Lokaler Gastzugriff ist gefordert, der Browser erreicht den Hub aber
  noch nicht belastbar (kollidiert mit KL-WEB-002).**
  Das ist der schwerwiegendste Befund und für dieses Projekt besonders
  relevant, weil KL-WEB-002 das Gast-Web gerade **cloud-first über HTTPS**
  verdrahtet hat. DeepSeek zeigt quellengestützt: eine per HTTPS ausgelieferte
  Gast-Seite kann einen lokalen HTTP-Hub **nicht** per `fetch` erreichen —
  Mixed Content blockiert es, und Chromes Local Network Access blockiert selbst
  HTTPS-zu-Privat-IP. Der einzige plausible Pfad wäre, die **gesamte
  Gast-Seite vom Hub über Top-Level-HTTP** auszuliefern (oder ein
  Hub-Hotspot) — ein grundlegend anderer Ansatz als das aktuelle Cloud-Gast-Web.
  Das heißt: Die Offline-Gastbestellung aus Blueprint §16.2 ist mit der
  jetzigen Cloud-Gast-Web-Architektur **nicht** ohne Weiteres erreichbar. Das
  ist nach der Nutzerentscheidung keine optionale Produktfrage mehr, sondern
  die zentrale zu loesende Architektur- und Verifikationsluecke.
- **P0 — AP-/Client-Isolation.** Viele Restaurant-WLANs (besonders Gast-SSIDs)
  verbieten Gerät-zu-Gerät-Traffic standardmäßig. Ohne Lösung (eigene
  Venue-Gast-SSID ohne Client-Isolation, Hub-Hotspot oder eine technisch
  gleichwertige Topologie) ist der lokale Betrieb nicht erreichbar. Ein
  Verzicht auf lokalen Gastzugriff ist nach der Nutzerentscheidung keine
  Loesung; die gewaehlte Topologie muss am Referenz-Venue gemessen werden.
- **P0 — Transportsicherheit im LAN.** Unverschlüsseltes TCP erlaubt Sniffing,
  Fälschung und Bonjour-Spoofing. TLS/mTLS setzt Zertifikate voraus, die
  Browser akzeptieren — was wieder am HTTPS-Problem hängt.
- **P0/P1 — Failover.** SWIM ist auf iOS nicht produktionsreif (die zitierte
  Swift-Implementierung ist ein totes Hobby-Projekt); die 60-Sekunden-
  Failover-Lücke ist für den Restaurantbetrieb zu lang; Epoch/Term fehlt im
  Event-Modell (Logs nach Hub-Wechsel nicht eindeutig ordenbar); Event-Recovery
  bei totalem Hub-Verlust ist ungelöst. DeepSeek empfiehlt, Failover deutlich
  später anzugehen und zuerst synchrone Zweitgerät-Replikation plus
  Bonjour-Heartbeat statt SWIM.
- **P2 — Reichweite.** mDNS (`.local`) funktioniert auf Android/Windows nicht
  zuverlässig; QR muss dann eine IP tragen, was DHCP-Reservierung voraussetzt.

## 5. Empfehlung

1. **Stage 1 gilt als abgedeckt** durch den gemergten KL-OFFLINE-003-Prototyp.
   Der nächste konkrete, risikoarme Schritt wäre — auf ausdrücklichen
   Nutzerwunsch — die iOS-Integrationsnaht: den Event-Store hinter
   `KitchenLinkRepository` einziehen und `LocalDemoRepository` schrittweise
   ablösen, Demo-Pfade erhalten (Blueprint §18.1, §20). Das ist Domain-/
   Persistenzarbeit ohne die ungelösten Netzwerk-P0s.
2. **KL-OFFLINE-004 belegt die Software-Naht, nicht den Stage-2-Netzwerkgate.**
   Der isolierte macOS-Hostsurrogat liefert eine lokale Top-Level-Seite samt
   Bootstrap aus und bestaetigt erst nach Event-/Outbox-Commit. Damit koennen
   Browserfluss, serverseitige Preispruefung und Idempotenz reproduzierbar
   getestet werden. Auf echten Gast- und Business-Geraeten bleiben QR-Wechsel,
   AP-Isolation, iOS-/Android-Erreichbarkeit, Hub-Lifecycle sowie TLS/Trust zu
   messen. Erst ein bestandener Geraeteproof waehlt die App-Implementierung.
3. **Freigegeben ist die Produktrichtung, nicht eine konkrete Technik.** Die
   Entscheidung steht in `DECISIONS.md`; die Discovery-Artefakte bleiben
   Erkenntnisgrundlage und duerfen nicht als Produktionsfreigabe gelesen
   werden.
