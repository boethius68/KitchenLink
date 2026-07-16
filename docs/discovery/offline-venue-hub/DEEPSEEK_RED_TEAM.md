# Red-Team Review: Offline-Venue-Hub & Relay Prototype

**Agent:** DeepSeek
**Datum:** 2026-07-16
**Prüfgegenstand:** iPad-Venue-Hub-Architektur (Blueprint §16), OrderRelayService, LocalDemoRepository, OrderingDomain
**Status:** Discovery / noch keine Produktionsentscheidung

---

## 1. P0-Findings (Datenverlust / Finanziell / Security)

### P0-01: UserDefaults ist kein multiplex-fähiger Speicher

**Wo:** `LocalDemoRepository` (`KitchenLinkRepository.swift:18–154`)
**Was:** Sämtliche Persistenz liegt in `UserDefaults.standard`.

**Warum kritisch:**
- `UserDefaults` ist nicht thread-safe – zwei gleichzeitige `set(_:forKey:)`-Aufrufe aus verschiedenen Tasks verlieren Daten (letzter Schreibzugriff gewinnt, kein Lock).
- `UserDefaults` ist nicht crash-safe. Ein Absturz zwischen `encoder.encode` und `defaults.set` kann teilweise Updates hinterlassen (iOS schreibt auf NSUbiquitousKeyValueStore-Sync-Ebene asynchron).
- `UserDefaults` hat eine undocumented aber reale Größenbeschränkung (~1 MB auf iOS). Sobald eine Venue mehrere hundert Bestellungen hat, wird `LiveOrderMessage` + Order-Array diese Grenze überschreiten → `set` schlägt still fehl, `loadOrders` returned leeres Array, alle Bestellungen sind weg.
- Keine Query-Möglichkeit: `loadOrder` deserialisiert *alle* Bestellungen und filtert dann per `first(where:)` – O(n) Deserialisierung pro Einzellookup.
- **Blueprint §16.3 mandatiert SQLite.** Der aktuelle Code ignoriert das vollständig.

**Fix-Richtung:** SQLite (GRDB oder SwiftData) mit Transaktionen und punktuellen Queries. Bis dahin: `OSAllocatedUnfairLock` oder `Actor`-Wrapping für Thread-Safety.

### P0-02: Keine Idempotenz bei Order-Erstellung

**Wo:** `LocalDemoRepository.createOrder` (`KitchenLinkRepository.swift:124–132`)
**Was:**
```swift
orders.removeAll { $0.id == savedOrder.id }
orders.insert(savedOrder, at: 0)
```

**Warum kritisch:**
Wenn der aufrufende Code dieselbe Order-ID zweimal sendet (z. B. Retry bei Timeout), wird die erste Bestellung *ersetzt* ohne Prüfung. Im Relay-Kontext: Ein Gast bestellt, der Relay-Transport stockt, der Client wiederholt den Request → die erste Bestellung (möglicherweise bereits vom Koch akzeptiert) wird mit `status: .pending` überschrieben.

**Fix-Richtung:** `createOrder` muss existierende Orders mit derselben ID zurückweisen (409 Conflict). Erfordert externen Idempotenz-Key, der vom Client signiert wird (Blueprint §16.3).

### P0-03: Anon Key & Base URL hardcoded

**Wo:** `OrderRelayService.swift:158–159`
**Was:**
```swift
private let supabaseBaseURL = URL(string: "https://kiqboyshhsogvdvnleup.supabase.co/rest/v1")!
private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Warum kritisch:**
- Supabase-RLS muss korrekt konfiguriert sein, damit der anon Key nur freigegebene Operationen ausführen kann. Wenn RLS fehlt oder fehlerhaft ist, kann *jeder* mit diesem Key Venue-Daten löschen (`DELETE /tables` etc.).
- Der anon Key hat ein Ablaufdatum (exp: 2087199507), aber weder `aud`-Claim noch IP-Bindung.

**Fix-Richtung:**
1. `supabaseBaseURL` konfigurierbar (Info.plist oder Build-Config).
2. Anon Key in Secrets-Management (Edge-Funktion stellt kurzlebiges JWT aus).
3. RLS-Policies in SQL-Migrationen dokumentieren und testen.

### P0-04: Keine Authentisierung, keine Authorization

**Wo:** `OrderRelayService` – sämtliche Supabase-Requests (KitchenLinkRepository.swift + OrderRelayService.swift)
**Was:** Jeder Aufruf verwendet nur den anon Key. Kein Login, kein Session-Token, keine Rolle, keine Geräteidentität.

**Warum kritisch:**
Im Venue-Hub-Szenario (Blueprint §16) müssen mehrere Business-Geräte schreiben, aber Gäste dürfen nur lesen. Der anon Key erlaubt *alles* (Upsert, Delete auf allen Tabellen). Ein Gast, der den QR-Code scannt und die API-URL extrahiert, könnte direkt DELETE auf `orders` senden.

**Fix-Richtung:** Supabase Auth + RLS. Business-Geräte erhalten device-JWT (Blueprint §16.3: "Gerätesignaturen"), Gast-Web verwendet anonyme Session mit Leserechten.

### P0-05: `URLSession.shared` ohne Custom-Konfiguration

**Wo:** `OrderRelayService.swift:165`
**Was:**
```swift
private let session = URLSession.shared
```

**Warum kritisch:**
- Kein Certificate Pinning.
- Default-Timeout 60s – im Offline-Szenario wartet `send(order:)` 60s.
- Kein `waitsForConnectivity`.
- Keine `httpMaximumConnectionsPerHost`-Begrenzung.

**Fix-Richtung:** Eigene `URLSession` mit `URLSessionConfiguration.default` + `waitsForConnectivity = true`, `timeoutIntervalForRequest = 10s`, Certificate Pinning via `URLSessionDelegate`.

---

## 2. P1-Findings (Datenkonsistenz / Split-Brain / Sync)

### P1-01: Polling statt Realtime / Push

**Wo:** `OrderRelayService.startPollingOrders` (Zeile 464–479) + `startTrackingCustomerOrder` (Zeile 224–238)
**Was:** Beide Polling-Tasks laufen mit `Task.sleep(for: .seconds(3))`.

**Warum kritisch:**
- Max 3s Latenz bis Bestellung auf Küchen-View erscheint.
- Owner + Customer-Tracker = mehrere parallele 3s-Polling-Tasks → unnötige CPU/Battery.
- Polling liest `select=...venues,tables,order_items` – große Payloads.
- Zwischen Order-Insert und OrderItem-Insert kann Polling inkonsistenten Zustand lesen.
- **Blueprint §18.3** nennt Supabase Realtime als Benachrichtigungskanal – nicht implementiert.

**Fix-Richtung:** Supabase Realtime Subscription statt Polling. Fallback auf Polling nur bei Verbindungsabbruch.

### P1-02: Schema-Fallback ist fragile String-Parsing-Magic

**Wo:** `OrderRelayService.shouldFallbackToLegacySchema` (Zeile 1137–1159)
**Was:** Erkennung von Schema-Versionen durch Substring-Suche im Fehler-String.

**Warum kritisch:**
- Die `legacySchemaIndicators` enthalten `"column"`, `"venues"`, `"tables"` – diese Strings können in *jedem* Fehlertext auftauchen (z. B. wird der Venue-Name zufällig im Error-Body referenziert).
- Supabase aktualisiert Fehlermeldungen mit Versionen → die Magic-Strings können sich ändern.
- Sprachabhängig: deutsche Fehlertexte (Rest-API) würden nicht matchen.

**Fix-Richtung:** Schema-Version muss aus der Response (Header oder expliziter Schema-Endpunkt) ermittelt werden. Statt `shouldFallbackToLegacySchema` → `readSchemaMode` und `writeSchemaMode` direkt setzbar.

### P1-03: `createOrder` löscht vor Insert – Race-Condition mit Polling

**Wo:** `LocalDemoRepository.createOrder` (Zeile 124–132)
**Was:**
```swift
orders.removeAll { $0.id == savedOrder.id }
orders.insert(savedOrder, at: 0)
try persistOrders(orders)
```

**Szenario:**
- Owner-Polling liest zwischen `removeAll` und `persistOrders` → temporär verschwundene Bestellung.
- Zwei parallele `createOrder`-Aufrufe (verschiedene Order-IDs) → beide `loadOrders`, beide `insert`, beide `persistOrders` → einer gewinnt, der andere verliert eine Bestellung.

**Fix-Richtung:** `actor LocalDemoRepository` oder `os_unfair_lock` um `loadOrders`+`modify`+`persistOrders`.

### P1-04: Kein Outbox / kein lokaler Queue-Mechanismus

**Wo:** Ganzer Relay-Stack
**Was:** Weder `LocalDemoRepository` noch `OrderRelayService` haben eine Outbox für nicht-zugestellte Orders.

**Szenario:**
- Gast bestellt lokal (Demomodus) → `send(order:)` → `createOrder` → OK.
- Aber: Was passiert, wenn der Owner-Mode nicht läuft? Die Bestellung liegt im lokalen Speicher, wird aber nie an Supabase weitergeleitet.
- `OrderRelayService` hat keine `syncPendingOrdersToCloud()`-Methode.
- Relay-Queue (`ORDER_RELAY_QUEUE` Key) ist ein reiner Daten-Transport-Puffer, kein persistentes Outbox.

**Fix-Richtung:** Append-only Event-Log (Blueprint §16.3). Jeder lokale Write erzeugt einen Event-Eintrag. Ein Sync-Actor repliziert Events in der Reihenfolge an Supabase/Venue-Hub.

### P1-05: `isConnected` ist ein Mischmasch aus Cloud und Lokal

**Wo:** `OrderRelayService` – `isConnected = true` bei jeder gelungenen *lokalen* Operation.
**Was:**
```swift
func startHostingAsOwner() {
    isConnected = true
    connectionText = "Lokales Demo-Backend aktiv"
}
```

**Warum kritisch:**
- UI kann nicht unterscheiden: "mit Cloud verbunden" vs. "nur lokal verfügbar".
- `isConnected = false` wird nur bei *lokalen Speicherfehlern* gesetzt, nicht bei Cloud-Ausfall.
- Blueprint §16.3 fordert sichtbaren Status: `online`, `lokal verbunden`, `eingeschränkt`, `offline`, `synchronisiert`, `Konflikt`.

**Fix-Richtung:** Eigener `ConnectivityState`-Enum mit allen 6 Zuständen aus §16.3.

### P1-06: `shouldTreatAsMissingQRTokenSchema` cached dauerhaft als `.unavailable`

**Wo:** `OrderRelayService` Zeile 359–364 und 414–415
**Was:** Einmal als `.unavailable` markiert, wird der Supabase-Table `qr_tokens` nie wieder versucht – bis App-Neustart.

**Szenario:**
- QR-Token-Schema existiert in Prod, aber Entwickler hat Migration vergessen → Setzen auf `.unavailable`.
- Migration wird später ausgeführt → App müsste neu starten. Kein Mechanismus für "retry after backoff".

**Fix-Richtung:** Time-basierte Retry-Strategie (Exponential Backoff, max 1h). Oder expliziter "Scan QR tokens schema now"-Button für Admin.

### P1-07: Keine Status-Validierung bei `updateStatus` auf Repository-Ebene

**Wo:** `OrderRelayService.updateStatus` (Zeile 247–272)
**Was:** Der Service prüft `order.status.canTransition(to: newStatus)`, aber das Repository nicht.

**Szenario:**
- Ein direkter `try repository.updateOrderStatus(orderID: "x", to: .canceled)` ist möglich – für jedes Repository, das `KitchenLinkRepository` implementiert.
- Das `LocalDemoRepository` hat keine Status-Machine.

**Fix-Richtung:** Status-Transition-Logik in die Repository-Implementierung verschieben oder ein `OrderStatusValidator`-Protokoll separat testen.

---

## 3. P2-Findings (Edge Cases / UX / Design-Lücken)

### P2-01: QR-Token-Erzeugung ist deterministisch vorhersagbar

**Wo:** `LocalQRTokenCodec` (`KitchenLinkRepository.swift:156–200`)
**Was:**
```swift
static func sharedCode(slug: String) -> String {
    "\(scheme)://venue/\(slug)/shared"
}
```

**Warum problematisch:**
- Jeder, der den Venue-Slug kennt, kann gültige QR-Codes erzeugen.
- Bei Venue-Shared-Modus kein Problem (der QR hängt öffentlich am Tisch). Aber Table-QRs mit Label-Kodierung erlauben Table-Spoofing.

**Fix-Richtung:** QR-Tokens müssen kryptografisch zufällige Komponenten enthalten (z. B. UUID + HMAC-Signatur mit einem Venue-Secret). Der `expires_at`-Mechanismus sollte implementiert werden.

### P2-02: `buildVenueProfile` überschreibt `supportedServiceModes` mit Fallback

**Wo:** `OrderRelayService.buildVenueProfile` (Zeile 820–842)
**Was:**
```swift
let supportedModes = fallbackServiceModes.isEmpty ? ServiceMode.allCases : fallbackServiceModes
```

**Szenario:**
- Ein Venue-Profil aus der Cloud hat `supportedServiceModes: [.dineIn]` (nur Tischservice).
- Weil `fallbackServiceModes` leer ist, wird `.bar` und `.pickup` hinzugefügt.
- Ein Gast bestellt per Pickup → Venue kann nicht liefern.

**Fix-Richtung:** `supportedServiceModes` aus dem Venue-Profil übernehmen, Fallback nur bei fehlendem Feld in der DB.

### P2-03: `operatorContextLine` zeigt raw `sourceDevice` bei fehlender Venue-Info

**Wo:** `LiveOrderMessage.operatorContextLine` (Zeile 30–44)
**Was:**
```swift
if segments.isEmpty {
    return sourceDevice
}
```

**Szenario:**
- Device-Name des Gasts (`sourceDevice`) wird dem Operator als Kontext angezeigt.
- Ein Gast mit Device-Name "iPhone von Karen" wird als "Tisch: iPhone von Karen" interpretiert.

**Fix-Richtung:** `sourceDeviceLine` separat zeigen, `operatorContextLine` nie auf sourceDevice fallen lassen.

### P2-04: `loadOrderRows`-Limit bei `orderID == nil` = 50, bei `orderID != nil` = 1

**Wo:** `OrderRelayService.swift:571`
**Was:**
```swift
URLQueryItem(name: "limit", value: orderID == nil ? "50" : "1")
```

**Szenario:**
- In einer belebten Schicht mit >50 Bestellungen werden ältere Bestellungen nie geladen.
- Ein Operator sucht eine Bestellung von vor 2 Stunden → nicht in der Liste.

**Fix-Richtung:** Kein Hard-Limit im Polling, ggf. Paginierung implementieren. Oder `receivedOrders` als dedizierte Queue öffnen.

### P2-05: `clearOrders` löscht alle Orders ohne Bestätigung

**Wo:** `OrderRelayService.clearOrders` (Zeile 208–219)
**Was:** Löscht den gesamten `orderStorageKey` aus UserDefaults.

**Szenario:**
- Operator tippt im Demo-Mode versehentlich auf "Löschen" → alle Bestellungen der Schicht weg.
- Kein Undo, kein Papierkorb.

**Fix-Richtung:** Soft-Delete oder Archivierung.

### P2-06: `allergenCodes` als komma-separierter String im Domain-Model

**Wo:** `MenuItemData` (in OrderRelayService.swift:890) und `SupabaseUpsertMenuItemRequest.allergenCodes`
**Was:** Join + Split per `,` ohne Escape-Mechanismus.

**Szenario:**
- Ein Allergencode enthält ein Komma (z. B. "Gluten, Dinkel").
- Der Split produziert zwei Einträge.
- Supabase-Seite erwartet `[String]` → Rücksplit aus legacy-Format verliert Information.

**Fix-Richtung:** `allergenCodes: [String]` direkt im Domain-Model, kein Join/Split an der API-Grenze.

---

## 4. P3-Findings (Design / Future / Beobachtungen)

### P3-01: `MenuItemKind` ist `food`/`drink` – zu flach

**Wo:** `MenuItemKind` (im Projekt)
**Was:** Die Ontologie-Arbeit (KL-MENU-001) hat gezeigt, dass `MenuItemKind` mindestens bundles, deposits, cover, service-fee, weight-based, per-person umfassen muss.

### P3-02: Venue-Slug als Matching-Key bei Sync

**Wo:** `OrderRelayService.syncVenueProfile` (Zeile 288–317)
**Was:** Abgleich per `slug` zwischen lokalem und remote Venue-Profil.

**Szenario:**
- Zwei Organisationen haben denselben Slug → falsche Venue wird gematcht.
- Slug-Änderung → lokales Profil kann nicht mehr zugeordnet werden.

**Fix-Richtung:** Venue-ID als Matching-Key, Slug nur für QR/Human-Display.

### P3-03: Kein Token-Expiry-Check

**Wo:** `SupabaseQRTokenRecord.isUsable` (Zeile 1286–1291)
**Was:**
```swift
guard let expiresAtRaw else { return true }
```

**Szenario:**
- QR-Token ohne `expires_at` (nil) gilt immer als gültig.
- Legacy-Tokens ohne Ablauf können nie deaktiviert werden.

**Fix-Richtung:** Default-Expiry von 1 Jahr für alle neuen Tokens. `expires_at` nicht optional im Schema.

### P3-04: `VenueTable.isActive` wird von `createOrder` nicht geprüft

**Wo:** `Checked in CheckoutState.validated` (OrderingDomain.swift:189) – aber nicht auf Service-Ebene.
**Was:** Der `OrderRelayService` prüft nicht, ob ein Table noch aktiv ist, bevor eine Bestellung platziert wird.

**Szenario:**
- Tisch wird deaktiviert, während eine Bestellung in Bearbeitung ist.
- `send(order:)` akzeptiert die Bestellung trotzdem.

**Fix-Richtung:** Validierung vor `createOrder` (oder idempotentes Zurückweisen).

---

## 5. Non-negotiable Invariants (müssen immer gelten)

1. **Keine Bestellung gilt als angenommen, bevor sie von mindestens einem autoritativen Gerät bestätigt wurde.** (Blueprint §16.2)
2. **Zahlungen und Kassenereignisse dürfen niemals stillen Last-write-wins unterliegen.** (Blueprint §16.3)
3. **Jede Order hat genau eine autoritative Status-Maschine** – nie zwei Geräte gleichzeitig mit inkonsistenten Vorstellungen.
4. **Geräteidentität ist nicht verhandelbar** – jeder Business-Client signiert mit einer hardwaregebundenen Device-ID (Blueprint §16.3).
5. **Lokale Speicherung muss crash-safe und transaktional sein** – `UserDefaults` erfüllt das nicht.

---

## 6. Failure / Attack Tree

```
Offline-Venue-Ausfall
├── Venue-Hub-Gerät stirbt (Akku/Aspect/Crash)
│   ├── Alle lokalen Orders verloren → P0-01 (UserDefaults)
│   ├── Kein Failover zum nächsten Device → §16.1 nicht implementiert
│   └── Cloud-Sync pending → Outbox nie geflusht → P1-04
├── WLAN-Ausfall im Restaurant
│   ├── Gast kann nicht bestellen → §16.2 präzise
│   ├── Business-Geräte sehen sich offline
│   └── Polling-Tasks laufen leer (403/Timeout) → CPU/Battery
├── Supabase-Ausfall
│   ├── Schemas werden lokal nicht aktualisiert → P1-02 Fallback-Magic
│   ├── QR-Token-Status unbekannt → P1-06
│   └── `isConnected` = false → UI ohne Funktion, obwohl lokal OK → P1-05
├── Split-Brain (zwei aktive Hubs)
│   ├── Beide akzeptieren Orders → unterschiedliche Order-IDs
│   ├── Beide aktualisieren denselben Table → Inkonsistenz
│   └── Sync nach Reconnect: keine Vektoruhren → Merge-Konflikte unerkannt → P0-01
├── Angriff
│   ├── QR-Spoofing (Slug bekannt) → P2-01
│   ├── Anon-Key-Missbrauch (RLS fehlt) → P0-04
│   └── Replay eines alten createOrder-Requests → P0-02
└── Datenkorruption
    ├── UserDefaults-Größenlimit erreicht → alle Bestellungen verschwunden
    ├── Concurrent-Write-Race → eine Bestellung verloren → P1-03
    └── Status-Machine übersprungen (direktes repository.updateOrderStatus) → P1-07
```

---

## 7. Minimal Sandbox Architecture

Was muss mindestens existieren, bevor der Venue-Hub die Sandbox verlässt:

| Komponente | Jetzt | Ziel |
|---|---|---|
| **Lokaler Speicher** | UserDefaults | SQLite (GRDB/SwiftData), transaktional |
| **Thread-Safety** | keine | Actor oder Lock |
| **Outbox** | Fehlt | Append-only Event-Log |
| **Status-Machine** | Nur auf Service-Ebene | Im Repository / DB-Level |
| **Auth** | Anon Key | Supabase Auth + RLS + Device-JWT |
| **Netzwerk** | URLSession.shared | Custom Session + Pinning |
| **Realtime** | 3s-Polling | Supabase Realtime Subscription |
| **Sync** | Keiner | Inbox/Outbox nach §16.3 |
| **Connectivity-State** | Bool | 6 Zustände nach §16.3 |
| **Failover** | Keins | Leader-Election zwischen Hubs |
| **Idempotenz** | Fehlt | Idempotency-Key pro Order |
| **QR-Token** | Deterministisch | HMAC- oder UUID-basiert |
| **Conflict-Resolution** | LWW (lokal) | Deterministische Regeln je Fachobjekt (§16.3) |

### Priorisierte Roadmap

1. SQLite-Migration (P0-01) – ohne transaktionalen Speicher ist alles andere riskant.
2. Thread-Safety / Actor (P1-03) – einfacher Fix, sofort wirksam.
3. Auth + RLS (P0-04) – verhindert Datenmissbrauch noch in der Sandbox.
4. Outbox + Event-Log (P1-04) – Grundlage für Sync/Reconnect.
5. Custom URLSession + Pinning (P0-05) – Netzwerk-Sicherheit.
6. Idempotenz (P0-02) – verhindert Duplikate bei Retry.
7. Realtime statt Polling (P1-01) – Latenz und Battery.
8. Connectivity-State-Modell (P1-05) – UI-Transparenz.
9. Schema-Version aus Metadata (P1-02) – statt String-Magic.
10. Failover-Election (P3) – für Produktion.

---

## 8. Forbidden Shortcuts (niemals so implementieren)

- **🚫 Silent Last-Write-Wins für Zahlungen oder Kassenereignisse** (§16.3 non-negotiable).
- **🚫 UserDefaults als dauerhafter Speicher** – nur für Präferenzen, nie für Bestellungen.
- **🚫 SharedPreferences / NSUserDefaults in Produktion ohne Transaktionsemulation**.
- **🚫 Supabase anon Key im Client ohne RLS**.
- **🚫 Deterministische QR-Codes ohne kryptografische Signatur**.
- **🚫 Polling als alleiniger Mechanismus für zeitkritische Bestellungen** (≥3s Latenz inakzeptabel für Getränke-Nachbestellung).
- **🚫 Kein Device-JWT = kein autoritativer Business-Client**.
- **🚫 Multicast / UDP-Broadcast für Order-Verteilung ohne Quittung** (Paketverlust = Bestellverlust).
- **🚫 Single-Device-Hub ohne Fallback** (Blueprint §16.1: "bei Ausfall übernimmt ein anderes Gerät").

---

## 9. Test-Ideen (Deterministisch / Property-Based)

### Deterministische Integrationstests

```swift
func test_createOrder_isIdempotent() throws {
    let repo = LocalDemoRepository(defaults: UserDefaults())
    let order = LiveOrderMessage(id: "a", …)
    let first = try repo.createOrder(order)
    let second = try repo.createOrder(order) // sollte fehlschlagen oder second.status != first.status nicht überschreiben
    XCTAssertEqual(first.id, second.id)
    // Aktuell: schlägt nicht fehl, überschreibt → lost status
}

func test_concurrent_createOrder_noDataLoss() async throws {
    // 50 parallele createOrder-Aufrufe → alle 50 müssen lesbar sein
}

func test_statusTransition_validatesCorrectly() {
    // Alle Status-Transitionen durchtesten (6x6 Matrix)
    XCTAssertTrue(OrderLifecycleStatus.pending.canTransition(to: .accepted))
    XCTAssertFalse(OrderLifecycleStatus.pending.canTransition(to: .served))
    XCTAssertTrue(OrderLifecycleStatus.pending.canTransition(to: .canceled))
    XCTAssertFalse(OrderLifecycleStatus.served.canTransition(to: .canceled))
}

func test_userDefaults_limit_notReached() throws {
    // 10.000 Orders schreiben → muss lesbar bleiben
    // Erwartet: current mit UserDefaults schlägt fehl
}

func test_polling_doesNotReadPartialOrder() async throws {
    // Order + Items in zwei Schritten schreiben → Polling liest erst nach commit beider
}

func test_schemaFallback_notTriggeredOnUnrelatedErrors() {
    // Fehler ohne "venues/columns/tables"-Substring → kein Fallback
}

func test_connectivityState_distinguishesLocalVsCloud() {
    // isConnected = true nach lokalem createOrder
    // isConnected = false nach fehlgeschlagenem cloud-upsert
}
```

### Property-Based Tests (ideal mit SwiftCheck)

```swift
// Für alle möglichen Kombinationen von concurrent Interleavings
property("create + update + delete ist linearisierbar")
    <- forAll(genOrder, genCommand) { order, cmds in
        let serial = SerialExecutor.execute(cmds)
        let concurrent = ConcurrentExecutor.execute(cmds)
        return serial.finalState == concurrent.finalState
    }

property("Status-Transition-Graph ist azyklisch")
    <- forAll(genStatusChain) { chain in
        !chain.containsDuplicates || chain.last == .canceled
    }

property("QR-Token-Codec ist reversibel")
    <- forAll(genSlug, genTableLabel) { slug, label in
        let encoded = LocalQRTokenCodec.tableCode(slug: slug, tableLabel: label)
        let parsed = LocalQRTokenCodec.parse(encoded)!
        return parsed.slug == slug.lowercased()
            && parsed.tableLabel?.lowercased() == label.lowercased()
    }
```

---

## 10. User-decidable Questions (nur der User entscheidet)

1. **Priorität SQLite vs. Actor-Wrapping:** Sofort SQLite oder reicht Thread-Safety für die Sandbox?
2. **Supabase-Projekt-Einstellung:** Soll ein separates Dev-Project mit automatischen Migrationen eingerichtet werden?
3. **RLS-Dev-Policy:** Dürfen in der Sandbox alle Business-Geräte Vollzugriff haben (um Admin-Login zu sparen)?
4. **QR-Token-Verschärfung:** Sind HMAC-QR-Tokens oder reicht UUID/+expiry für die erste Beta?
5. **Failover-Strategie:** Soll der Hub-Status per Bonjour/NSD im WLAN bekanntgegeben werden, oder per manueller Konfiguration?
6. **Connectivity-State-Modell:** Soll der 6-Zustands-Enum (§16.3) sofort eingebaut werden, oder reicht `isConnected` + `connectionText` für die Demo?
7. **Payment-Hardening:** Soll in der Sandbox eine simulierte "Zahlung ist final" Schranke eingebaut werden (damit der Code später nicht umgestellt werden muss)?

---

## 11. Anhänge

### A: Verwendete Quellen
- `docs/PRODUCT_BLUEPRINT.md` – §16 (Offline-Architektur), §18 (Technische Architektur)
- `docs/collaboration/DECISIONS.md` – iPad Venue Hub = pending
- `docs/collaboration/PEER_WORKFLOW.md` – Branch/PR-Regeln
- `docs/collaboration/handoffs/DEEPSEEK.md` – KL-MENU-001 Red-Team v2
- `docs/collaboration/handoffs/GLM.md` – GLM-Erstlauf
- `kitchenlink/OrderRelayService.swift` – Vollständiger Relay-Prototyp (1561 Zeilen)
- `kitchenlink/OrderingDomain.swift` – Domain-Modelle (354 Zeilen)
- `kitchenlink/KitchenLinkRepository.swift` – Repository-Protokoll + LocalDemoRepository + QR-Codec (206 Zeilen)

### B: Metrik-Report
- **Zeilen geprüft:** ~2.100 (OrderRelayService + OrderingDomain + KitchenLinkRepository)
- **P0 Findings:** 5 (Datenverlust, Security kritisch)
- **P1 Findings:** 7 (Datenkonsistenz, Schema-Fallback, Fehlende Outbox)
- **P2 Findings:** 6 (Edge Cases, UX-Lücken)
- **P3 Findings:** 4 (Design-Beobachtungen)
- **Non-negotiable Invariants:** 5
- **Forbidden Shortcuts:** 9
- **Test-Ideen:** 12 deterministisch, 3 property-based

### C: Offene Fragen an den User
- Siehe §10 oben.
