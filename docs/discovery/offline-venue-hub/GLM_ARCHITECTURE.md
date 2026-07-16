# Zielarchitektur — Lokaler KitchenLink Venue-Hub

**Erstellt:** 2026-07-16
**Agent:** GLM-5.2 via ZCode
**Ticket:** Discovery-Auftrag lokaler Venue-Hub (Blueprint §16)
**Status:** Discovery/Entwurf — keine Produkt- oder Designfreigabe

Dieses Dokument ist eine quellenbasierte Architektur-Exploration, kein
freigegebenes Produktdesign. Es erfindet keine Produktentscheidungen und ändert
keinen Produktcode. Quellenverweise `[Sxx]` verweisen auf
[`GLM_SOURCES.md`](./GLM_SOURCES.md).

---

## 1. Fakten, Annahmen und offene Risiken

### 1.1 Verifizierte Fakten (aus Primärquellen)

| Fakt | Quelle | Bedeutung |
|------|--------|-----------|
| `MCSession` unterstützt maximal **8 Peers inklusive lokalem Peer** | [S14] | MPC ist für ein Restaurant mit vielen Tisch-Geräten ungeeignet |
| Bei App-Hintergrundgrund stoppt MPC Advertising/Browsing und **trennt alle Sessions** | [S15] | MPC fällt aus, sobald die Hub-App in den Hintergrund geht |
| MPC gilt als unzuverlässig in Produktion; Apple-Mitarbeiter empfehlen auf Network.framework zu wechseln | [S16][S20] | Network.framework ist der zuverlässigere Transport |
| `NWListener` kann auf iOS **TCP-Verbindungen an einem lokalen Port annehmen** und über Bonjour advertisen | [S01][S02][S03] | lokaler HTTP-/WebSocket-Server auf dem Hub-Gerät ist technisch möglich |
| `NWBrowser` findet Bonjour-Services über `Descriptor.bonjour(type:domain:)` | [S04][S06] | Geräte können den Hub entdecken ohne feste IP/Port-Konfiguration |
| `NSLocalNetworkUsageDescription` ist **seit iOS 14 Pflicht** für lokalen Netzwerkzugriff; einmalige Nutzerabfrage | [S24] | Info.plist-Eintrag und Nutzeraufklärung zwingend |
| `NSBonjourServices` muss alle beworbenen/gebrowse-ten Service-Typen deklarieren | [S05][S25] | sonst funktioniert Discovery nicht |
| Privacy Manifest (`PrivacyInfo.xcprivacy`) ist **seit 1. Mai 2024 Pflicht** für App-Updates | [S26][S27] | App-Store-Rejection bei Fehlen |
| Background-Modi sind streng limitiert; App pausiert ohne deklarierten Modus | [S21][S22] | Hub muss im Vordergrund bleiben ODER geeigneten Background-Modus nutzen |
| SQLite WAL-Modus erlaubt **mehrere gleichzeitige Reader und einen Writer** | [S28][S32] | lokale Datenbank ohne Lese-Sperren während Schreibens |
| Raft ist **nicht byzantinisch-fehlertolerant** und setzt vertrauenswürdige Knoten voraus | [S38] | passt zu einem kontrollierten Venue-LAN mit authentifizierten Mitarbeiter-Geräten |
| SWIM garantiert **eventuelle Fehlerekennung** jedes fehlerhaften Prozesses | [S39] | zuverlässige Membership-Erkennung für Hub-Ausfall |
| Supabase implementiert Offline-Sync **nicht nativ**; eine lokale Schicht ist erforderlich | [S43] | Venue-Hub muss die Sync-Verantwortung selbst tragen |

### 1.2 Annahmen (plausibel, aber nicht freigegeben)

| Annahme | Begründung | Risiko falls falsch |
|---------|------------|---------------------|
| Das Restaurant verfügt über ein **eigenes WLAN**, das Gäste und Mitarbeitergeräte ins selbe Subnetz bringt | Blueprint §16.2 spricht vom „Restaurant-WLAN" | Guest Isolation / Client-Isolation im WLAN blockiert Gerätekommunikation; Hub nicht erreichbar |
| Pro Venue läuft **genau ein** autoritativer Hub während einer Betriebsschicht | Blueprint §16.1: „Das Hub-Gerät bleibt … im Venue-Hub-Modus" | zwei Hubs erfordern Split-Brain-Auflösung (siehe §5) |
| Mitarbeitergeräte sind **authentifiziert und vertrauenswürdig** | Blueprint §9.1: Rollen/Rechte/PIN | fremde Geräte im WLAN könnten sonst Bestellungen einspeisen |
| Gäste bestellen im **Browser** (keine App-Installation) | Blueprint §3.1, DECISIONS.md | Safari/Chrome müssen lokalen HTTP-Endpunkt ohne HTTPS-Warnung erreichen |
| Der Hub ist ein **iPad oder iPhone**, das am Strom bleibt und im Vordergrund gehalten wird | Blueprint §16.1 |_battery_ oder _user closes app_ bricht den Hub-Betrieb |
| Die Betriebsschicht definiert den **Zeitraum**, in dem ein Hub aktiv sein darf | Blueprint §8.3 | außerhalb der Schicht dürfen keine Bestellungen angenommen werden |
| Bestellungen sind das **erste kritische Fachobjekt** für lokalen Mehrgerätebetrieb | Blueprint §16.3, Meilenstein 1 Schritt 12 | Zahlung, Lager, Zeit kommen später und benötigen dieselbe Infrastruktur |

### 1.3 Offene Risiken (Produktentscheidung oder Verifizierung nötig)

| Risiko | Prio | Bedeutung | Wem |
|--------|------|-----------|-----|
| **WLAN-Client-Isolation** (`AP Isolation`) blockiert Device-to-Device-Traffic — in vielen Guest-WLANs Standard | 🔴 P0 | Gast erreicht Hub nicht; komplette Offline-Bestellung unmöglich | Nutzer / Venue-Administrator |
| **HTTPS vs. HTTP**: Browser warnen bei gemischtem Inhalt oder self-signed certs; Gäste geben keine Cert-Warnungen ein | 🔴 P0 | lokale Gastoberfläche muss ohne HTTPS-Fehler erreichbar sein | Nutzer (Architekturentscheidung) |
| **Background-Ausfall**: iOS suspendiert die App; der Hub stirbt, wenn der Bildschirm sperrt oder der Nutzer wegwischt | 🟠 P1 | Blueprint sagt „sichtbar im Vordergrund", aber unbeabsichtigtes Backgrounding muss überlebt werden | Implementierung + Nutzer |
| **Bonjour-Regressionen** seit iOS 14 (Advertising bricht ab) | 🟠 P1 | Hub wird von Geräten nicht gefunden | Verifizierung auf Ziel-iOS-Version |
| **Split-Brain** bei Netzwerk-Partition (WLAN-Access-Point teilt das Netz) | 🟠 P1 | zwei Hubs in unterschiedlichen Subnetzen akzeptieren getrennt Bestellungen | Architekturentscheidung |
| **Uhren-Drift** zwischen Geräten beeinträchtigt zeitbasierte Lease/Leader-Election | 🟡 P2 | falsche Leader-Wechsel bei Lease-Ablauf | Implementierung (NTP-/Monoclock-Strategie) |
| **Apple-App-Review**: dauerhaft lauschender lokaler Server und Background-Audio könnten Review-Komplikationen auslösen | 🟡 P2 | Verzögerung oder Ablehnung bei produktiver Einreichung | Nutzer (vor Produktivfreigabe) |
| **Leistung**: viele simultane Gäste übertragen Bilder/Preise über einen lokalen HTTP-Server auf einem iPad | 🟡 P2 | Hub-Gerät könnte überlastet werden | Lasttests erforderlich |

---

## 2. Empfohlene Komponenten- und Datenflussarchitektur

### 2.1 Architekturüberblick

```
┌─────────────────────────────────────────────────────────────┐
│                    Restaurant-WLAN (ein Subnetz)            │
│                                                             │
│  ┌──────────┐   ┌──────────────────┐    ┌───────────────┐  │
│  │  Gast A  │   │   VENUE HUB      │    │ Mitarbeiter B │  │
│  │ (Browser)│──▶│  iPhone/iPad     │◀──▶│  (Business-   │  │
│  │  Safari  │   │  autoritativ     │    │   App)        │  │
│  └──────────┘   │                  │    └───────────────┘  │
│                  │  ┌────────────┐ │          ▲            │
│  ┌──────────┐   │  │ HTTP-/WS-  │ │          │ Bonjour     │
│  │  Gast B  │──▶│  │ Server     │ │    ┌─────┴───────┐    │
│  │ (Browser)│   │  │ (NWListener)│ │    │ Replika-    │    │
│  └──────────┘   │  └─────┬──────┘ │    │ tion-Client │    │
│                  │        │        │    └─────────────┘    │
│                  │  ┌─────▼──────┐ │                      │
│                  │  │ Event Log  │ │    ┌───────────────┐  │
│                  │  │ (SQLite +  │ │    │ Mitarbeiter C │  │
│                  │  │  WAL)      │◀┼──▶│  (Business-   │  │
│                  │  └─────┬──────┘ │    │   App)        │  │
│                  │        │        │    └───────────────┘  │
│                  │  ┌─────▼──────┐ │                      │
│                  │  │ Outbox/    │ │                      │
│                  │  │ Inbox +    │ │                      │
│                  │  │ Leader-    │ │                      │
│                  │  │ Election   │ │                      │
│                  │  └────────────┘ │                      │
│                  └────────┬────────┘                      │
└───────────────────────────┼─────────────────────────────┘
                            │ Internet (optional)
                   ┌────────▼────────┐
                   │   Supabase      │
                   │  (PostgreSQL)   │
                   │  Cloud-Abgleich │
                   └─────────────────┘
```

### 2.2 Komponenten

**A. Venue Hub (autoritativer Knoten)** — läuft auf einem iPhone/iPad

1. **HTTP-/WebSocket-Server** (`VenueHTTPServer`)
   - Implementiert auf `NWListener` [S01][S03][S07]
   - Akzeptiert Gast-Verbindungen vom Browser (Safari/Chrome) im WLAN
   - Endpunkte: `POST /orders`, `GET /menu`, `GET /orders/:id/status`, `WS /events`
   - Parst HTTP manuell oder via `NWProtocolFramer` [S08]
   - Bonjour-advertised als `_kitchenlink-hub._tcp` [S03][S05]

2. **Event Store** (`VenueEventStore`)
   - SQLite mit WAL-Modus über GRDB.swift `DatabasePool` [S28][S33][S34]
   - **Append-only Event-Tabelle** für kritische Vorgänge [S29][S30]
   - Snapshot-Tabellen für abgeleiteten Zustand (Bestellungen, Sessions)
   - Idempotenz-Tabelle für Deduplizierung [S31]

3. **Leader-Election-Engine** (`HubLeadership`)
   - Lease-basiertes Leader-Modell, von Raft-Prinzipien inspiriert [S36][S37]
   - Vereinfacht: ein aktiver Hub pro Venue-Schicht, deterministischer Fallback
   - SWIM-Gossip für Mitgliedschaft und Fehlerekennung [S39][S40][S41]
   - Siehe §4 für detaillierte Regeln

4. **Outbox/Inbox-Synchronisation** (`SyncCoordinator`)
   - Outbox: lokal persistierte Events, die an Supabase gesendet werden müssen [S31]
   - Inbox: empfangene Cloud-Änderungen, die lokal eingespielt werden
   - Idempotenzschlüssel verhindern Doppelverarbeitung [S31]
   - Wiederverbindungs-Backoff bei Internet-Ausfall

5. **Replikations-Server** (für Mitarbeitergeräte)
   - Stellt Mitarbeitergeräten lokale Events zur Verfügung
   - Empfängt Events von Mitarbeitergeräten (z.B. Kellner-Bestellung, Statuswechsel)
   - Über denselben HTTP-/WS-Kanal oder separaten Binär-Protokoll

**B. Mitarbeitergeräte** (Business-App, nicht-autoritativ)

6. **Replikations-Client** (`ReplicaClient`)
   - Findet Hub via `NWBrowser` + Bonjour [S04][S06]
   - Lokale SQLite-Replik (read-mostly + eigene Outbox)
   - Schreiboperationen gehen an den Hub; bei Hub-Ausfall lokal gepuffert

7. **Lokaler Cache** (`ReplicaStore`)
   - SQLite mit den vom Hub replizierten Events
   - Eigene Outbox für Offline-Operationen (später synchronisiert)

**C. Gast-Browser** (keine App)

8. **Gast-Web-Client** (PWA / responsive Webseite)
   - Verbindung zum Hub über `http://<hub-bonjour-name>.local:<port>` oder gefundene IP
   - POST von Bestellungen, Polling/WebSocket für Status
   - Siehe §3 für Acknowledgement-Fluss

### 2.3 Datenfluss — Gastbestellung

```
Gast-Browser          Venue Hub                 Supabase
     │                    │                         │
     │ 1. GET /menu       │                         │
     │───────────────────▶│                         │
     │  ◀── Menü-JSON     │                         │
     │                    │                         │
     │ 2. POST /orders    │                         │
     │  (mit Client-      │                         │
     │   Idempotenzkey)   │                         │
     │───────────────────▶│                         │
     │                    │ 3. Event anhängen       │
     │                    │    (append-only,        │
     │                    │     SQLite TX)          │
     │                    │ 4. Idempotenz prüfen    │
     │                    │ 5. ACK mit Event-Seq    │
     │  ◀── 200 OK +      │                         │
     │      Order-ID      │                         │
     │                    │ 6. Outbox-Eintrag       │
     │                    │    (async)              │
     │                    │────────────────────────▶│
     │                    │                    7. Persistierung
     │                    │  ◀── 200 OK            │
     │                    │ 8. Outbox markiert     │
     │                    │    als gesendet         │
     │                    │                         │
     │ 9. WS /events      │                         │
     │  (Status-Update)   │                         │
     │◀───────────────────│                         │
```

**Schlüsselprinzip (Blueprint §16.2):** Schritt 5 (ACK) darf erst gesendet
werden, **nachdem** Schritt 3 (dauerhaftes Speichern im Event Log) erfolgreich
abgeschlossen ist. Erst dann gilt die Bestellung als „angekommen".

---

## 3. Ereignismodell, IDs, Acknowledgement- und Konfliktregeln

### 3.1 Ereignismodell

Alle kritischen Vorgänge werden als unveränderliche Events gespeichert
(append-only) [S29][S30]. Der aktuelle Zustand wird durch Replay der Events
abgeleitet (Event Sourcing).

```text
VenueEvent {
  event_id:          ULID (global sortierbar, zeitgeordnet)
  event_type:        Enum (OrderSubmitted, OrderAccepted, OrderStatusChanged,
                            OrderCanceled, PaymentRequested, …)
  aggregate_id:      UUID des Fachobjekts (z.B. Order-ID)
  aggregate_type:    Enum (Order, TableSession, Payment, …)
  venue_id:          UUID der Venue
  source_device_id:  UUID des erzeugenden Geräts
  shift_id:          UUID der Betriebsschicht
  occurred_at:       ISO8601 mit Monotonischer Sequenznummer
  payload:           JSON (typisiert pro event_type)
  client_idempotency_key: UUID (vom Erzeuger, für Dedup)
  prev_event_seq:    Sequenznummer des Vorgänger-Events (Hub-Lamport-Zeit)
  signature:         HMAC des Geräts (Authentizität)
}
```

### 3.2 ID-Strategie

| ID-Typ | Format | Erzeuger | Eigenschaft |
|--------|--------|----------|-------------|
| `event_id` | **ULID** | erzeugendes Gerät | global sortierbar, zeitgeordnet, kollisionsresistent |
| `aggregate_id` (Order, Session) | **UUIDv7** (zeitgeordnet) | erzeugendes Gerät | eindeutig über Geräte hinweg |
| `source_device_id` | UUIDv4 (registriert) | Supabase bei GerätRegistration | stabil pro Gerät |
| `client_idempotency_key` | UUIDv4 | Client pro logischer Operation | gleicher Key = gleiche Operation (Dedup) |

**Begründung UUIDv7/ULID:** Zeitgeordnete IDs ermöglichen deterministische
Sortierung für Konfliktlösung ohne zentralen Sequenz-Server [S50].

### 3.3 Acknowledgement-Regel

```text
Gast sendet POST /orders
  ↓
Hub empfängt Anfrage
  ↓
Hub prüft Idempotenzkey gegen idempotency-Tabelle
  ├─ schon verarbeitet → return vorhandene Order-ID (idempotent)
  └─ neu → weiter
  ↓
Hub validiert: Menü, Preise, Öffnungszeit, Kapazität (Blueprint §6.3)
  ↓
Hub schreibt VenueEvent in SQLite-Transaktion:
  BEGIN;
    INSERT INTO events (...);          -- append-only
    INSERT INTO idempotency (...);     -- Dedup-Key
    UPDATE snapshots SET ...;          -- abgeleiteter Zustand
  COMMIT;                              -- ← dauerhaft gespeichert!
  ↓
Hub sendet ACK: { order_id, event_seq, status: "received" }
  ↓
Erst jetzt gilt die Bestellung als "angekommen" (Blueprint §16.2)
  ↓
Hub trägt Event in Outbox ein (async, nach ACK)
  ↓
SyncCoordinator sendet an Supabase bei Internetverfügbarkeit
```

### 3.4 Konfliktregeln (deterministisch je Fachobjekt)

Das Blueprint verbietet stilles Last-Write-Wins für Zahlungen, Bestand und
Kassenereignisse (§16.3). Daher: **deterministische, fachspezifische
Konfliktlösung** [S48][S50][S53].

| Fachobjekt | Konfliktfall | Regel |
|------------|--------------|-------|
| **Order** | zwei Geräte ändern Status gleichzeitig | Höchster `event_seq` gewinnt; Übergang muss gültig bleiben (`canTransition`) |
| **OrderItem** | gleiche Position von zwei Geräten modifiziert | Append: beide Events bleiben; UI zeigt Konflikt zur manuellen Klärung |
| **Order** | gleiche Bestellung doppelt eingereicht (Idempotenz) | `client_idempotency_key` dedupliziert; nur ein Event [S31] |
| **Payment** | zwei Zahlungsversuche für gleiche Rechnung | **niemals automatisch**; zweiter wird blockiert und als Konflikt markiert (sichtbar) |
| **StockMovement** | Bestandsänderung divergiert | Append-only; Bestand = Summe aller Movements; Konflikt = sichtbare Warnung |
| **TableSession** | zwei Geräte fügen gleichzeitig hinzu | Beide Events gültig (kommutativ); Zusammenführung deterministisch nach `event_seq` |

**Konflikt-Sichtbarkeit** (Blueprint §16.3): Unauflösbare Konflikte werden mit
Status `Konflikt` markiert und dem Personal angezeigt — niemals still
aufgelöst für kritische Vorgänge.

### 3.5 Warum Event Sourcing statt CRDT

| Kriterium | Event Sourcing (gewählt) | CRDT (verworfen für Kern) |
|-----------|--------------------------|---------------------------|
| Fachregeln abbildbar | ✅ beliebige deterministische Logik pro Event | ❌ erfordert merge-freundliche Typen, schwer für komplexe Fachregeln |
| Vollständige Historie | ✅ alle Vorgänge nachvollziehbar | ❌ nur Endzustand, Historie geht verloren |
| Konflikt-Sichtbarkeit | ✅ explizit markierbar | ❌ mergt automatisch (still) |
| Audit & GoBD-Vorbereitung | ✅ append-only erfüllt Nachvollziehbarkeit | ❌ weniger natürlich |
| Komplexität | ⚠️ eigene Replay-Logik nötig | ✅ mathematisch garantiert |

Quellen: [S48][S50][S51][S53]. **Teil-CRDTs** können ergänzend für
unkritische, rein additive Daten (z.B. Lesezeichen) eingesetzt werden.

---

## 4. Hub-Erkennung, Leader-Wechsel und Wiederanlauf

### 4.1 Hub-Discovery über Bonjour

```
Mitarbeitergerät startet
  ↓
NWBrowser sucht _kitchenlink-hub._tcp im lokalen Netz [S04][S06]
  ↓
Gefundener Hub?
  ├─ JA → verbinde via NWConnection zum Hub
  └─ NEIN → Gerät kann selbst Hub werden (siehe Leader-Election)
```

### 4.2 Leader-Election (Lease-basiert, vereinfacht)

Vollständiges Raft [S36] ist für eine kleine Anzahl vertrauenswürdiger
Mitarbeitergeräte in einem Venue-LAN überdimensioniert. Empfohlen wird ein
**vereinfachtes Lease-Modell** mit Raft-inspirierter Sicherheit:

**Wahlberechtigung:**
- Nur Geräte mit aktiver Betriebsschicht und Mitarbeiter-Authentifizierung
- Bevorzugt: das Gerät, das vom Betreiber als „Hub-Gerät" markiert wurde
- Fallback: das Gerät mit der höchsten `(shift_started_at, device_id)`-Rangfolge

**Lease-Mechanismus:**
```text
1. Bei Schichtstart ernennt der Betreiber ein Hub-Gerät (manuell, Blueprint §16.1)
2. Das Hub-Gerät erhält eine LEASE (z.B. 30 Sekunden)
3. Das Hub erneuert die Lease alle 10 Sekunden (Heartbeat)
4. Andere Geräte beobachten Heartbeats via SWIM-Gossip [S39][S40]
5. Bleibt ein Heartbeat 2× Lease-Zeit aus → Hub gilt als ausgefallen
6. Fallback-Wahl: ranghöchstes verfügbares Gerät übernimmt
7. Neues Hub schreibt einen HubLeaseAcquired-Event ins eigene Event Log
```

**Split-Brain-Schutz:**
- Ein Gerät wird nur Hub, wenn es die Mehrheit der bekannten aktiven Geräte erreicht
- Da typischerweise wenige Geräte (1–5) aktiv sind, ist Quorum pragmatisch
- Bei echter Netzwerkpartition (zwei Subnetze): jedes Subnetz hat eigene Venue-View;
  bei Wiederverbindung vergleicht Supabase-Abgleich die Event-Logs [S43][S44]

### 4.3 Wiederanlauf nach Hub-Ausfall

```text
Hub-Gerät A stürzt ab / App wird beendet
  ↓
SWIM erkennt nach ≤ 2× Lease-Zeit: A ist nicht mehr erreichbar [S39]
  ↓
Mitarbeitergerät B (zweit-höchste Rangfolge) startet Wahl
  ↓
B prüft: habe ich mein lokales Event Log? → JA (SQLite ist persistent)
  ↓
B wird neues Hub, schreibt HubLeaseAcquired-Event
  ↓
B beginnt, Bonjour zu advertisen und HTTP-Server zu starten
  ↓
Gäste und Mitarbeiter entdecken B via NWBrowser [S04]
  ↓
B empfängt neue Events und repliziert an andere Geräte
  ↓
Bei Wiederkehr von A: A ist nicht mehr Hub (B hält Lease)
  A synchronisiert seine Offline-Events an B (Outbox)
```

---

## 5. Failure-Matrix

Legende: ✅ funktionsfähig / ⚠️ eingeschränkt / ❌ nicht funktionsfähig

| Szenario | Gastbestellung | Mitarbeitergerät | Hub | Cloud-Sync | Maßnahmen |
|----------|----------------|------------------|-----|------------|-----------|
| **Internetverlust** (WLAN intakt) | ✅ lokal über Hub | ✅ lokal repliziert | ✅ autoritativ | ❌ pausiert | Outbox puffert; Sync bei Rückkehr idempotent [S31] |
| **Hub-Gerät-Ausfall** (App stirbt) | ⚠️ bis neuer Hub da | ⚠️ gepuffert | ❌ → ✅ Failover | entkoppelt | Leader-Wechsel nach §4.2; Geräte finden neuen Hub via Bonjour |
| **WLAN-Ausfall** (komplett) | ❌ Gast erreicht nichts | ❌ Geräte isoliert | ❌ keine Verbindungen | ❌ | Mobile DatenFallback nur für Cloud, nicht für lokal; Bestellung erst möglich bei WLAN-Wiederkehr (Blueprint §16.2) |
| **App-Hintergrund** (Hub) | ❌ Server stoppt | ❌ Sessions enden | ❌ | — | Hub muss im Vordergrund bleiben [S22]; ggf. Audio-Background-Modus als Keepalive prüfen (Risiko §1.3) |
| **Geräteneustart** (Hub) | ⚠️ Unterbrechung | ⚠️ Reconnect nötig | ✅ nach Neustart | ✅ | SQLite persistent; Event Log überlebt Neustart; Lease-Timeout löst Failover aus |
| **Zwei gleichzeitige Hubs** (Split-Brain) | ⚠️ beide nehmen an | ⚠️ konkurrierend | ⚠️ | ⚠️ | Lease-Quorum verhindert; bei echter Partition: sichtbarer Konfliktstatus bei Cloud-Reunion (§3.4) |
| **Cloud-Wiederkehr** | — | — | ✅ | ✅ idempotent | Outbox leer sequentiell; Dedup via `client_idempotency_key`; Konflikte sichtbar [S31][S43] |

### 5.1 Detaillierung kritischer Szenarien

**Internetverlust:**
- Alle Events bleiben lokal im SQLite-Event-Log erhalten
- Outbox sammelt zu sendende Events
- Bei Rückkehr: SyncCoordinator sendet Outbox idempotent an Supabase
- Cloud-Events (z.B. Menüänderung durch Betreiber im Web) werden in Inbox gepuffert
- dedup via `event_id` und `client_idempotency_key`

**App-Hintergrund (Hub-Gerät):**
- iOS suspendiert die App; `NWListener` stoppt [S22]
- Vorübergehend keine neuen Bestellungen möglich
- **Prävention:** Bildschirm an lassen, Guided Access, „Display nie sperren"
- **Notfall:** Background-Audio-Modus könnte als Keepalive missbraucht werden,
  aber Apple-Review-Risiko [S21] — **nur nach Nutzerfreigabe** prüfen
- Blueprint §16.1 sagt ausdrücklich: Hub „bleibt im Vordergrund" — dies ist
  die Produktvorgabe, keine technische Lücke

**Zwei gleichzeitige Hubs:**
- Szenario A (versehentlich): Zwei Geräte denken, sie seien Hub → Lease-Quorum
  verhindert, da nur ein Gerät die Mehrheit erreichen kann
- Szenario B (Netzwerkpartition): WLAN teilt sich in zwei Subnetze → jeder Hub
  sammelt unabhängig Events → bei Wiederverbindung vergleicht Cloud-Abgleich
  beide Logs → Konfliktstatus für überlappende Vorgänge (§3.4)

---

## 6. Sandbox-Prototypplan in kleinen Stufen

Dieser Plan respektiert die Sandbox-Grundsätze (Blueprint §20): sichtbares
Banner, kein echtes Geld, Demo-Daten, simulierbare Fehler. Jede Stufe ist
eigenständig testbar. **Keine Produktivfreigabe ohne Nutzerentscheidung.**

### Stufe 0 — Evaluation & Beweis der Machbarkeit (Discovery, kein Code)

- [x] Quellenbasierte Machbarkeitsanalyse (dieses Dokument)
- [ ] Manuelles Proof-of-Concept: NWListener auf einem Simulator/Device,
      HTTP-Request vom zweiten Device/Simulator
- [ ] WLAN-Client-Isolation beim Referenz-Venue prüfen (P0-Risiko §1.3)
- [ ] HTTPS-Lösung evaluieren (lokales Self-Signed? HTTP-Ausnahme?)
- **Abnahme:** bestätigte Machbarkeit der Bonjour-Discovery und HTTP-Erreichbarkeit

### Stufe 1 — Lokales Event-Log und Repository-Migration

- [ ] `VenueEventStore` mit GRDB.swift + WAL [S33]
- [ ] Append-only `events`-Tabelle, `idempotency`-Tabelle, `snapshots`
- [ ] Migration des bestehenden `LocalDemoRepository` (UserDefaults → SQLite)
  hinter dem `KitchenLinkRepository`-Protokoll — **alte Demo-Pfade erhalten!**
- [ ] Unit-Tests: Append, Replay, Idempotenz-Dedup
- **Abnahme:** Bestellungen persistent über App-Neustart; Legacy-Tests noch grün

### Stufe 2 — HTTP-Server auf dem Hub-Gerät

- [ ] `VenueHTTPServer` auf `NWListener` [S03][S07]
- [ ] Endpunkte: `GET /menu`, `POST /orders`, `GET /orders/:id`
- [ ] HTTP-Parsing (minimal) oder `NWHTTPProtocol` [S08]
- [ ] Integration mit `VenueEventStore` (Bestellung → Event → ACK)
- [ ] Info.plist: `NSLocalNetworkUsageDescription`, `NSBonjourServices` [S24][S25]
- [ ] PrivacyInfo.xcprivacy [S26]
- **Abnahme:** Bestellung von Simulator-Browser an Simulator-App

### Stufe 3 — Bonjour-Discovery und Gast-Erreichung

- [ ] Hub advertiset `_kitchenlink-hub._tcp` [S03]
- [ ] Gast-Web erreicht Hub via `.local`-Adresse oder aufgelöste IP [S11]
- [ ] End-to-End: QR-Code → Browser → Hub → Event-Log → ACK
- [ ] Echtes Gerätetest im WLAN (P0-Risiken §1.3 verifizieren)
- **Abnahme:** Bestellung von echtem Gast-Gerät an echtes Hub-Gerät im WLAN

### Stufe 4 — Replikation an Mitarbeitergeräte

- [ ] `ReplicaClient` mit `NWBrowser` [S04][S06]
- [ ] Mitarbeitergerät verbindet sich, repliziert Event-Log (read)
- [ ] Mitarbeitergerät sendet eigene Events (Statuswechsel) an Hub
- [ ] Lokaler SQLite-Cache auf dem Mitarbeitergerät
- **Abnahme:** zwei Geräte zeigen dieselben Bestellungen; Statuswechsel synchron

### Stufe 5 — Outbox und Cloud-Sync

- [ ] `SyncCoordinator` mit Outbox/Inbox [S31]
- [ ] Idempotenter Abgleich mit bestehender Supabase-Anbindung
- [ ] Wiederverbindungslogik mit Backoff
- [ ] Dedup bei Cloud-Wiederkehr
- **Abnahme:** Offline-Bestellungen erscheinen nach Internetrückkehr in Supabase

### Stufe 6 — Leader-Election und Failover

- [ ] Lease-basierte Hub-Erkennung (§4.2)
- [ ] SWIM-Gossip-Heartbeats [S39][S40]
- [ ] Failover: Hub schließen → zweites Gerät übernimmt
- [ ] Split-Brain-Erkennung und Konfliktmarkierung
- **Abnahme:** Bestellbetrieb läuft weiter nach Hub-Schließung

### Stufe 7 — Konfliktlösung und Härtung

- [ ] Deterministische Konfliktregeln pro Fachobjekt (§3.4)
- [ ] Konflikt-Sichtbarkeit in UI
- [ ] Failure-Simulationen (Blueprint §20: „Netzwerkfehler … simulierbar")
- [ ] Lasttests mit vielen simultanen Gästen
- **Abnahme:** Blueprint §22-Kriterien für Mehrgerätebetrieb erfüllt

---

## 7. Teststrategie

### 7.1 Unit-Tests (automatisiert, CI-tauglich)

| Testbereich | Was geprüft wird | Werkzeug |
|-------------|------------------|----------|
| `VenueEventStore` | Append, Replay, Idempotenz, WAL-Concurrency | XCTest |
| Konfliktregeln | deterministischer Merge pro Fachobjekt | XCTest mit synthetischen Events |
| Acknowledgement | Event persistent → ACK; Idempotenz-Dedup | XCTest |
| Status-Übergänge | `OrderLifecycleStatus.canTransition` (bereits vorhanden) | bestehende Tests erweitern |
| `LocalQRTokenCodec` | QR-Auflösung (bereits vorhanden) | bestehende Tests erhalten |

### 7.2 Integrationstests (Simulator-zu-Simulator)

| Test | Aufbau | Erwartung |
|------|--------|-----------|
| Bestellung lokal | Hub-Simulator + Browser-Request (URLSession) | Event im Log; ACK korrekt |
| Idempotenz | gleicher Request 2× | gleiche Order-ID; nur ein Event |
| Replikation | zwei Simulator-Apps über Bonjour | beide sehen dieselben Events |
| App-Neustart | Hub beenden, neu starten | Event-Log intakt; Bestellungen erhalten |

### 7.3 Mehrgeräte-Tests (echte Hardware, manuell)

Diese sind **nicht voll automatisierbar** und erfordern physische Geräte:

| Test | Geräte | Szenario | Akzeptanz |
|------|--------|----------|-----------|
| **Gast→Hub** | 1 iPad (Hub) + 1 iPhone (Gast-Browser) | QR scannen, bestellen | Bestellung im Hub-Event-Log |
| **Mehrere Gäste** | 1 Hub + 3 Gast-Geräte | simultan bestellen | alle Bestellungen erhalten, keine Duplikate |
| **Mitarbeiter-Replika** | 1 Hub + 2 Mitarbeiter-iPhones | Bestellung + Statuswechsel | alle Geräte synchron |
| **WLAN-Isolation** | wie oben | Client-Isolation am AP prüfen | Identifikation des P0-Risikos |
| **Bonjour-Discovery** | wie oben | Hub finden nach App-Start | NWBrowser findet `_kitchenlink-hub._tcp` |

### 7.4 Wiederanlauf- und Ausfalltests

| Szenario | Durchführung | Erwartung |
|----------|--------------|-----------|
| **Hub-Absturz** | Hub-App beenden während Betrieb | Failover ≤ Lease-Zeit; Betrieb läuft |
| **Internetverlust** | WLAN-Router vom Internet trennen | lokale Bestellungen weiter möglich; Outbox puffert |
| **Internet-Wiederkehr** | Internet wiederherstellen | Outbox synced idempotent; keine Duplikate |
| **Gerät-Neustart** | Hub-iPhone neustarten | Event-Log intakt; Bestellungen nach Boot wieder da |
| **Split-Brain** | zwei Hubs in getrennten Subnetzen | Konfliktstatus bei Reunion sichtbar |
| **App-Hintergrund** | Hub in Hintergrund schicken | Server stoppt (erwartet); Warnhinweis im UI |

### 7.5 Test-Fixtures und Demo-Daten

- Vorbereitetes Demo-Restaurant mit Menü, Tischen, Mitarbeitern (Blueprint §20)
- Simulierbare Fehler: Netzwerk aus, Hub-Absturz, Gerät-Offline (Toggle in UI)
- Rücksetzbarkeit pro Venue (bereits im Blueprint gefordert)

---

## 8. Verworfene Alternativen mit Begründung

### 8.1 Multipeer Connectivity (MPC) als primärer Transport — VERWORFEN

**Begründung:**
- Hartes Limit von **8 Peers pro Session** [S14] — unzureichend für ein Restaurant
  mit mehreren Mitarbeitern und vielen Gästen
- Sessions werden bei **App-Hintergrund abgebaut** [S15] — unvereinbar mit
  zuverlässigem Hub-Betrieb
- Gilt als **unzuverlässig in Produktion** [S16]; Apple selbst empfiehlt
  Network.framework [S20]
- Bekannter **„Lost Peer stays in Session"-Bug** [S17] erfordert Workarounds
- Skalierung über 8 Peers nur durch komplexe Multi-Session-Architektur [S18]

**Restnutzung:** MPC könnte für **unkritische, optionale** Discovery-Ergänzung
bleiben (z.B.„Tippen, um Geräte zu paaren"), aber nicht als Transport für
Bestellungen oder kritische Events.

### 8.2 CRDT als alleiniges Konfliktmodell — VERWORFEN für Kern

**Begründung:**
- CRDTs mergen **automatisch und still** [S51] — verstößt gegen Blueprint §16.3
  („niemals stille Last-write-wins-Regel für Zahlungen, Bestand")
- Schwierig auf **komplexe Fachregeln** abzubilden (Zahlungslogik,
  Bestandsbeschränkungen) [S48][S53]
- Verlust der **vollständigen Historie**, die für GoBD-Vorbereitung und Audit
  benötigt wird

**Restnutzung:** Teil-CRDTs können für rein additive, unkritische Daten
(Lesezeichen, „Gefällt mir") ergänzend eingesetzt werden.

### 8.3 Supabase als alleinige Wahrheit ohne lokalen Hub — VERWORFEN

**Begründung:**
- Blueprint §16 fordert ausdrücklich lokalen Mehrgerätebetrieb bei Internet-Ausfall
- Supabase implementiert Offline-Sync **nicht nativ** [S43]
- Bei Internetverlust wäre keine Bestellannahme möglich — verstößt gegen Kernversprechen

### 8.4 Vollständiges Raft-Konsensus — VERWORFEN (zu komplex)

**Begründung:**
- Raft [S36] ist für 2–5 vertrauenswürdige Geräte in einem LAN überdimensioniert
- Erfordert Quorum-Abstimmung für jeden Write → Latenz und Komplexität
- Das Blueprint-Modell (ein autoritativer Hub, andere replizieren) ist einfacher
  und ausreichend, solange der Hub-Dienst klar definiert ist

**Restnutzung:** Raft-Prinzipien (Lease, Term-Begriff, Safety) fließen in das
vereinfachte Lease-Modell ein (§4.2).

### 8.5 PowerSync/ElectricSQL/RxDB als externe Sync-Engine — VERWORFEN für Sandbox

**Begründung:**
- Diese Engines [S44][S45][S47] sind mächtig, aber fügen **externe Abhängigkeit**
  und Lizenz/Kosten hinzu
- Für die Sandbox-Beta ist eine **eigene, kontrollierte Outbox/Inbox**-Logik
  vorzuziehen (Blueprint §18.1: „kontrollierter Neuaufbau")
- Können nach der Sandbox evaluiert werden, wenn die eigene Logik Grenzen erreicht

### 8.6 Background-Audio-Modus als Hub-Keepalive — VERWORFEN für jetzt

**Begründung:**
- Missbrauch des Audio-Background-Modus zur App-Lebendhaltung riskiert
  **Apple-App-Review-Ablehnung** [S21]
- Blueprint §16.1 sagt ausdrücklich: Hub „bleibt im Vordergrund" — dies ist die
  Produktvorgabe
- Nur bei **expliziter Nutzerfreigabe** als Notfall-Strategie zu prüfen

---

## Anhang A — Abhängigkeit zu bestehendem Code

| Bestehend | Bezug zur Architektur |
|-----------|----------------------|
| `OrderRelayService.swift` | derzeit UserDefaults-basiert, polling; würde durch Event-Store + HTTP-Server ergänzt, nicht ersetzt (Legacy bleibt in Sandbox) |
| `KitchenLinkRepository` (Protokoll) | stabile Schnittstelle; neue SQLite-Implementierung dahinter, Demo-Pfad erhalten |
| `OrderingDomain.swift` | Statusmodell `OrderLifecycleStatus` bleibt gültig; Events referenzieren diese Status |
| `LocalDemoRepository` | bleibt als Fallback/Demo erhalten (Blueprint §20) |

**Prinzip (Blueprint §18.1):** „alter Code wird erst entfernt, wenn ein
getesteter Ersatz existiert."

---

## Anhang B — Offene Produktentscheidungen (dem Nutzer vorzulegen)

Diese Architektur kann folgende Entscheidungen nicht selbst treffen:

1. **HTTPS-Lösung für lokale Gastoberfläche** — Self-signed? HTTP? Apple-CA?
   (P0, blockiert Stufe 3)
2. **WLAN-Anforderung an Venue** — wie wird Client-Isolation vermieden?
   (P0, blockiert Stufe 3)
3. **Hub-Gerät-Hardware** — iPad fest im Laden oder iPhone des Betreuers?
   (Produkt/Design)
4. **Background-Keepalive-Strategie** — ist ein Audio-Keepalive akzeptabel?
   (P1, Apple-Review-Risiko)
5. **Sync-Engine-Strategie nach Sandbox** — eigene Logik vs. PowerSync/RxDB
   (post-Sandbox)

Diese Punkte werden im Pull Request und im Handoff sichtbar gemacht.
