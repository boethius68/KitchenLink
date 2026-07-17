# Handoff — MiniMax (KL-INVENTORY-001)

**Datum:** 2026-07-17
**Agent:** MiniMax (minimax-m3) ueber opencode
**Ticket:** KL-INVENTORY-001 — Warenwirtschafts-Domaene
**Branch:** `minimax/inventory-domain`
**Status:** Vollstaendig. 54 neue Tests gruen, vollstaendige Unit-Suite
gruen (insgesamt 113 Test-Cases, 0 Failures).

## Erledigt

Isolierte Swift-Domaenengrundlage fuer die in `PRODUCT_BLUEPRINT` §11
verpflichtende Warenwirtschaft. Exakt testbarer Bestandskern, keine UI,
keine Persistenz, keine Cloud, keine Buchhaltung, keine Lieferanten-API.

### Neue Dateien (exklusiver Schreibbereich)

| Datei | Inhalt |
|-------|--------|
| `kitchenlink/Features/Inventory/InventoryQuantity.swift` | `MeasurementUnit` (Masse g/kg, Volumen ml/l, Stueck), `InventoryQuantity` (Decimal + deterministische Halb-Auf-Rundung), Operatoren `+`/`-`/`*`/Vergleiche, Anzeige in `de_DE` |
| `kitchenlink/Features/Inventory/InventoryModels.swift` | `Ingredient`, `SalesItem`, `Recipe`, `RecipeComponent`, `StockLocation`, `Supplier`, `PurchasePrice`, `InventoryCatalog` mit Konsistenzpruefungen |
| `kitchenlink/Features/Inventory/InventoryMovement.swift` | `StockMovement` (append-only, idempotent), `StockMovementKind` mit Bucket-/Sign-Semantik, Fabrik-Methoden `receipt/consumption/waste/correction/reservation/release/reversal`, `fingerprint()` fuer Idempotenzvergleich |
| `kitchenlink/Features/Inventory/InventoryLedger.swift` | Append-only Ledger mit Idempotenzschluessel-Verwaltung, Reversal-Schutz (kein Doppel-Storno, kein Storno einer Gegenbuchung) und ausgeglichenem Transfer-Schutz (Zutat, Menge, Lagerort, hoechstens eine Stornierung pro Gruppe) |
| `kitchenlink/Features/Inventory/InventoryProjection.swift` | Berechnet physischen, reservierten und verfuegbaren Bestand je (Zutat, Lagerort) frisch aus dem Ledger; negative Werte werden sichtbar zurueckgegeben, kein stilles Abschneiden |
| `kitchenlink/Features/Inventory/InventoryReplenishment.swift` | `ReplenishmentEvaluation` mit `Severity` (`ok`/`warning`/`critical`) und `explanation`, `ReplenishmentSuggestion` mit Zielbestand und Fehlmenge |
| `kitchenlink/Features/Inventory/InventoryRecipeResolution.swift` | `InventoryRecipeResolver` loest Bestellpositionen (mehrere Zeilen, Mengen) in Verbrauchsbewegungen auf; deterministische Idempotenzschluessel `consumption:<reference>:<lineID>:<ingredientID>` |
| `kitchenlink/Features/Inventory/InventorySandboxFixture.swift` | Deterministische Fixture: 12 Zutaten, 4 Rezepte (Pizza Margherita, Spaghetti Bolognese, Tiramisu, Knoblauchbrot), 5 Verkaufsartikel, 2 Lieferanten, 2 Lagerorte (Kueche, Bar), 4 Einkaufspreise, vorab befuellter Ledger mit Wareneingaengen, Verkauf (3 Pizzen, 2 Spaghetti), 200 g Basilikum-Verderb und 1 kg Mehl-Transfer |
| `kitchenlink/Features/Inventory/INVENTORY_MODEL.md` | Verbindliche Spezifikation: Invarianten, Rundung, Ledger-Semantik, Idempotenzkonventionen, Reservierungs-/Transfer-/Reversal-Regeln, Persistenznaht, bewusst vertagter Umfang (Bewertung, FIFO, Steuerfragen, Lieferanten-API, UI, Cloud) |
| `kitchenlinkTests/InventoryQuantityTests.swift` | 12 Tests fuer Einheiten-Konversion, Kompatibilitaet, Rundung, Skalierung, Negativwerte |
| `kitchenlinkTests/InventoryLedgerTests.swift` | 8 Tests fuer Validierung (unbekannte Zutat, Lagerort, Einheit, fehlende Transfer-Gruppe) und Idempotenz (gleicher Schluessel + Inhalt = no-op, gleicher Schluessel + abweichender Inhalt = Konflikt, unterschiedliche Schluessel = beide erfasst, Schluesselformat stabil) |
| `kitchenlinkTests/InventoryProjectionTests.swift` | 7 Tests fuer physisch/reserviert/verfuegbar, pro Lagerort isoliert, Reversal-Effekt, Negativbestand nicht geclampt, Snapshot fuer alle Paare |
| `kitchenlinkTests/InventoryRecipeTests.swift` | 6 Tests fuer lineare Rezeptskalierung, Multi-Line-Aufloesung, artikel-ohne-Rezept, negative Menge, idempotente Wiederholung |
| `kitchenlinkTests/InventoryTransferTests.swift` | 5 Tests fuer ausgeglichenen Transfer, Zutat-Mismatch, identische Lagerorte, Gruppen-Storno und doppelter Storno-Schutz |
| `kitchenlinkTests/InventoryReversalTests.swift` | 5 Tests fuer Storno-Effekt, Doppelstorno-Schutz, Storno einer Gegenbuchung, unbekanntes Original, fehlender Verweis |
| `kitchenlinkTests/InventoryReplenishmentTests.swift` | 4 Tests fuer kritischen Fehlbestand mit Erklaerung, Bestellvorschlag bis Zielbestand, `nil`-Vorschlag bei Ueberfuelle, lagerort-spezifische Bewertung |
| `kitchenlinkTests/InventorySandboxFixtureTests.swift` | 6 Tests fuer Fixture-Form (12/4/2/5), alle Bewegungskategorien vertreten, erwartete Projektion, Katalog-Konsistenz (Doppelkomponente, Mindest>Ziel, ungueltiger Waehrungscode) |
| `docs/collaboration/handoffs/MINIMAX.md` | Dieses Update |

## Bewusst vertagt (in INVENTORY_MODEL.md §6 dokumentiert)

- Bewertung, Wareneinsatz, Rezeptkosten, Deckungsbeitrag
- FIFO, Chargen, Haltbarkeitsdaten
- Steuerlogik, USt-Aufteilung, GoBD/TSE
- Lieferanten-API, Einkaufsbestellungen, Wareneingangs-Bestaetigung
- Persistenz (SQLite/Supabase) — als eigene Schicht mit Codable-Schnittstelle
- UI (Tabelle, Editor, Scanner) — nur `InventorySnapshotEntry` als Sicht vorhanden
- Cloud-Sync, Outbox/Inbox, Konfliktauflauf

## Verifikation

```bash
# Fokussiert: nur die neuen Inventory-Tests
xcodebuild test -project kitchenlink.xcodeproj -scheme kitchenlink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:kitchenlinkTests/InventoryQuantityTests \
  -only-testing:kitchenlinkTests/InventoryLedgerTests \
  -only-testing:kitchenlinkTests/InventoryProjectionTests \
  -only-testing:kitchenlinkTests/InventoryRecipeTests \
  -only-testing:kitchenlinkTests/InventoryTransferTests \
  -only-testing:kitchenlinkTests/InventoryReversalTests \
  -only-testing:kitchenlinkTests/InventoryReplenishmentTests \
  -only-testing:kitchenlinkTests/InventorySandboxFixtureTests

# Ergebnis: alle Tests gruen, kein Build-Fehler
```

```bash
# Gesamte Unit-Suite
xcodebuild test -project kitchenlink.xcodeproj -scheme kitchenlink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:kitchenlinkTests

# Ergebnis: TEST SUCCEEDED, 113 Test-Cases, 0 Failures
```

## Designentscheidungen

- **Reservierungs-Semantik**: `.reservation` wirkt positiv auf den
  `reserved`-Bucket, `.release` negativ. `available = physical - reserved`.
  Dadurch ist `reserved` immer eine positive "wie viel ist reserviert"-Aussage.
- **Reversal-Schutz vor Idempotenz**: Die Reversal- und Transfer-Schutzregeln
  laufen vor der Idempotenzpruefung. Dadurch scheitert ein zweiter
  `reverse(out)` immer als `alreadyReversed`, auch wenn der automatisch
  generierte `reversal:<id>`-Schluessel mit dem ersten Storno kollidieren
  wuerde. Idempotenz gilt nur fuer identische Inhalte unter explizit
  unterschiedlichen Schluesseln.
- **Negative Bestaende**: Die Projektion gibt negative Werte unveraendert
  zurueck; die Replenishment-Bewertung stuft sie als `critical` ein. So
  sehen Operator:innen fehlende Wareneingaenge oder zu hohe Verbraeufe,
  statt still auf Null geclampt zu werden.
- **Decimal-Rundung**: Masse/Volumen auf 0,001 Basiseinheit (Milligramm
  bzw. Mikroliter) per `NSDecimalRound` mit Modus `.plain`
  (Half-up, away from zero). Stueck auf 1. So sind Tests exakt
  reproduzierbar und nicht von Schwebe-Arithmetik abhaengig.
- **Sandbox-Fixture**: 12 Zutaten, 4 Rezepte, 5 Verkaufsartikel
  (einer ohne Rezept, fuer Negativtest), 2 Lagerorte, 2 Lieferanten, 4
  Einkaufspreise. Der vorab befuellte Ledger deckt alle 5 Pflicht-Bewegungsarten
  (Wareneingang, Verkauf, Verderb, Transfer raus, Transfer rein) ab.

## Schreibbereich & Kollisionsfreiheit

- Nur Dateien unter `kitchenlink/Features/Inventory/` und `kitchenlinkTests/Inventory*Tests.swift`
  sowie `docs/collaboration/handoffs/MINIMAX.md` angefasst.
- Kein Produktcode ausserhalb des Schreibbereichs veraendert
  (keine Aenderung an `Features/Today/`, `Features/Kitchen/`, `Features/MenuImport/`,
  `App/`, `DesignSystem/`, `OrderRelayService.swift`, `KitchenLinkRepository.swift`,
  `KitchenLinkStore.swift`, `OrderingDomain.swift`, `ContentView.swift`).
- Kein Eingriff in `DECISIONS.md`, `CURRENT.md`, `WORK_QUEUE.md`.
- Keine Aenderung am Xcode-Projekt noetig: `PBXFileSystemSynchronizedRootGroup`
  nimmt neue Dateien in `kitchenlink/` und `kitchenlinkTests/` automatisch auf.
- Keine Geheimnisse, keine Supabase-Keys, keine externen Endpunkte.

## Verbleibende Risiken / offene Punkte

- Persistenz folgt als eigene Schicht (SQLite oder Supabase). Die Schicht
  nutzt die `Codable`-Faahigkeit von `InventoryCatalog` und `InventoryLedger`
  und respektiert die `movements`-Reihenfolge fuer reproduzierbare Projektionen.
- UI folgt in einem spaeteren Scope. `InventorySnapshotEntry` ist die
  bewusst gewaehlte Datenform fuer die spaetere Tabellenansicht.
- Rezeptkosten/Deckungsbeitrag benoetigen die optionalen `PurchasePrice`-Daten
  und eine Aggregation pro Rezept — bewusst nicht Teil dieses Kerns.
- Lieferanten-Bestellungen (KL-Bestellwesen) sind ein eigenes Modul und
  produzieren ueber `InventoryRecipeResolver`-aehnliche Helfer spaeter
  `consumption`/`reservation`-Bewegungen, sobald das Modul anfaellt.
- Es gibt aktuell keine Tests, die `InventoryLedger.updateCatalog(_:)` mit
  geloeschten Stammdaten aufrufen — die Pflicht ist im Code dokumentiert,
  aber die Test-Suite deckt nur den Happy-Path ab.

## Recommended Next Step

Review durch Claude oder Codex (Peer-Workflow). Wenn die Tests dort
reproduzierbar gruen laufen und die Invarianten akzeptiert werden, kann der
Branch nach `main` gemergt werden. Persistenz, UI und Lieferanten-Bestellung
folgen danach in eigenen Scopes.
