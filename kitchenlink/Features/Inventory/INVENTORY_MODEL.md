# Inventory Domain Model

**Stand:** 17. Juli 2026
**Status:** Verbindliche Spezifikation des Sandbox-Bestandskerns.
**Geltungsbereich:** KL-INVENTORY-001, exklusiver Schreibbereich `kitchenlink/Features/Inventory/`.

Dieses Dokument beschreibt die Invarianten, Rundungsregeln,
Ledger-Semantik und Idempotenz des Warenwirtschafts-Kerns. Es ist die
fachliche Spezifikation; Implementierungsdetails stehen in den
Swift-Dateien neben diesem Dokument. UI, Persistenz, Cloud-Sync,
Buchhaltung, Bewertung, FIFO und Lieferanten-APIs sind bewusst nicht
Teil dieses Kerns (siehe §6).

## 1. Ziele

Der Bestandskern liefert eine exakt testbare, dimensionssichere
Mengeverwaltung mit append-only Historie. Er ist die Grundlage fuer
Rezeptaufloesung, Bestellvorschlaege, Reservierungen und Transfers, aber
bewusst noch nicht fuer Bewertung, FIFO oder steuerliche Aspekte.

## 2. Fachobjekte

| Objekt | Beschreibung | Datei |
| --- | --- | --- |
| `Ingredient` | Zutat mit Basiseinheit, Mindest- und Zielbestand | `InventoryModels.swift` |
| `SalesItem` | Verkaufsartikel mit optionaler Rezept-Referenz | `InventoryModels.swift` |
| `Recipe` / `RecipeComponent` | Rezept und seine Komponenten | `InventoryModels.swift` |
| `StockLocation` | Lagerort (Kueche, Bar, Keller, Lager, Wareneingang) | `InventoryModels.swift` |
| `Supplier` | Lieferant | `InventoryModels.swift` |
| `PurchasePrice` | Einkaufspreis pro Zutat/Lieferant (optional) | `InventoryModels.swift` |
| `InventoryCatalog` | Konsistenter Stammdaten-Container | `InventoryModels.swift` |
| `StockMovement` | Eintrag im append-only Bestandsledger | `InventoryMovement.swift` |
| `InventoryLedger` | Append-only Historie mit Idempotenz- und Reversal-Schutz | `InventoryLedger.swift` |
| `InventoryProjection` | Aktueller physischer, reservierter und verfuegbarer Bestand | `InventoryProjection.swift` |
| `InventoryReplenishmentAdvisor` | Fehlbestandswarnung und Bestellvorschlag | `InventoryReplenishment.swift` |
| `InventoryRecipeResolver` | Aufloesung von Bestellpositionen in Verbrauchsbewegungen | `InventoryRecipeResolution.swift` |
| `InventorySandboxFixture` | Deterministische Beispiel-Domaene | `InventorySandboxFixture.swift` |

## 3. Einheiten und Rundung

Die Sandbox akzeptiert ausschliesslich drei Dimensionen:

- **Masse** in Gramm (`g`) oder Kilogramm (`kg`)
- **Volumen** in Milliliter (`ml`) oder Liter (`l`)
- **Stueck** (`count`)

Jede `InventoryQuantity` wird intern in der jeweiligen Basiseinheit
(Gramm, Milliliter, Stueck) als `Decimal` gehalten. Konversionen
zwischen Anzeigeeinheiten derselben Dimension sind verlustfrei
(Faktor 1000). Additionen und Vergleiche zwischen inkompatiblen
Dimensionen werfen `InventoryQuantityError.incompatibleUnits`.

Rundung erfolgt deterministisch beim Initialisieren oder Konvertieren
ueber `NSDecimalRound` mit Modus `.plain` (Half-up, away from zero):

- Masse und Volumen: 0,001 Basiseinheit (Milligramm bzw. Mikroliter)
- Stueck: 1

Negative Mengen werden im Initialisierer abgelehnt. Subtraktionen
koennen negative Ergebnisse erzeugen, damit Operator:innen Fehlbuchungen
sehen, statt still abgeschnittene Werte zu erhalten (siehe §5).

## 4. Ledger-Semantik

Das Ledger ist strikt append-only. Es gibt keine Operation, die einen
bestehenden Eintrag loescht oder aendert. Der aktuelle Bestand wird
ausschliesslich aus der Historie projiziert.

### 4.1 Bewegungskategorien

| Kategorie | Bucket | Vorzeichen | Erklaerung |
| --- | --- | --- | --- |
| `receipt` | physical | + | Wareneingang |
| `consumption` | physical | - | Verbrauch (Rezept, Verkauf) |
| `waste` | physical | - | Verderb, Bruch, Eigenverbrauch |
| `correctionIncrease` | physical | + | Positive Korrektur (Nachzaehlung) |
| `correctionDecrease` | physical | - | Negative Korrektur (Schwund) |
| `transferOut` | physical | - | Transfer raus aus einem Lagerort |
| `transferIn` | physical | + | Transfer rein in einen Lagerort |
| `reservation` | reserved | - | Reservierung fuer eine Vorbestellung |
| `release` | reserved | + | Freigabe einer Reservierung |
| `reversal` | gleich Original | invers | Storno/Gegenbuchung |

Reservationen und Freigaben wirken ausschliesslich auf den
`reserved`-Bucket; der physische Bestand bleibt unveraendert. Sie
spiegeln damit das in `PRODUCT_BLUEPRINT` §11 genannte Prinzip
"Vorbestellungen reservieren, abgeschlossene Bestellungen verbrauchen".

### 4.2 Transfers

Ein Transfer zwischen zwei Lagerorten wird als Paar von Bewegungen
modelliert (`transferOut` und `transferIn`) mit gemeinsamer
`transferGroupID`. Der Ledger erzwingt beim Einlesen der zweiten
Bewegung:

- gleiche Zutat
- unterschiedliche Lagerorte
- identische Menge
- genau ein `transferOut` und ein `transferIn` pro Gruppe
- hoechstens eine Gegenbuchung pro Gruppe (siehe §4.3)

### 4.3 Gegenbuchungen (Reversal)

Eine Gegenbuchung ist eine Bewegung der Kategorie `reversal`, die via
`reversalOfID` auf das Original verweist. Beim Aufzeichnen prueft der
Ledger:

- Original existiert
- Original ist nicht selbst eine Gegenbuchung
- Original wurde noch nicht storniert

Ein zweiter Storno auf dasselbe Original wird mit
`InventoryLedgerError.alreadyReversed` abgelehnt. Ein Storno einer
Gegenbuchung wird mit `InventoryLedgerError.reversalOfReversal`
abgelehnt.

### 4.4 Reihenfolge

Bewegungen werden in der Reihenfolge ihres Eintreffens verarbeitet.
`timestamp` ist informativ, nicht ordnend. Fuer reproduzierbare
Projektionen nutzt die Sandbox-Fixture monotone Timestamps
(`Date(timeIntervalSince1970: 1_700_000_000)` als Startwert).

## 5. Idempotenz

Jede Bewegung kann optional einen `idempotencyKey` tragen. Beim
Aufzeichnen gilt:

- **Gleicher Schluessel + gleiche Signatur** (Ingredient, Lagerort,
  Kategorie, Menge, Verweis, Reversal/Transfer-Referenz) -> es wird
  der existierende Eintrag zurueckgegeben; der Ledger bleibt
  unveraendert.
- **Gleicher Schluessel + abweichende Signatur** -> Konflikt mit
  `InventoryLedgerError.idempotencyConflict`.

Konventionen fuer aus Bestellungen erzeugte Bewegungen:

- Verbrauch: `consumption:<reference>:<lineID>:<ingredientID>`
- Reservierung: `reservation:<reference>:<lineID>:<ingredientID>`
- Freigabe: `release:<reference>:<lineID>:<ingredientID>`
- Gegenbuchung: `reversal:<originalID>`

Eine Wiederholung derselben Bestellung fuehrt damit zu
`IdenticalEntry`-Pfaden; eine Aenderung (z. B. Menge erhoeht) unter
gleichem Schluessel schlaegt als Konflikt fehl und zwingt zu einem neuen
Schluessel.

## 6. Bewusst vertagt

Folgende Aspekte gehoeren zur spaeteren Vervollstaendigung und sind
nicht Bestandteil dieses Kerns:

- **Bewertung**: kein Wareneinsatz, keine Rezeptkosten, kein
  Deckungsbeitrag. Einkaufspreise sind optionale Stammdaten ohne
  Berechnung.
- **FIFO / Verbrauchsreihenfolge**: Der Kern summiert saemtliche
  Bewegungen; einzelne Chargen oder Haltbarkeitsdaten werden nicht
  modelliert.
- **Steuerfragen**: keine USt-Aufteilung, keine GoBD-, KassenSichV- oder
  TSE-Logik.
- **Lieferanten-APIs**: keine echte Bestelluebermittlung; nur die
  Stammdaten `Supplier` und `PurchasePrice` existieren.
- **Cloud-Sync**: keine Persistenz, kein Outbox/Inbox, kein
  Konfliktauflauf. Persistenz folgt als eigene Schicht (siehe §7).
- **UI**: keine Views, keine Bindings. Die Sandbox bedient
  ausschliesslich Tests.

## 7. Persistenznaht

Die Persistenz ist bewusst noch nicht implementiert. Sie wird in einer
folgenden Schicht eingefuehrt, ohne die Ledger-Semantik zu aendern.
Erwartete Schnittstelle:

- `InventoryCatalog` und `InventoryLedger` sind `Codable`/`Sendable`
  und koennen vollstaendig serialisiert werden.
- `InventoryLedger.record(_:)` liefert die geschriebene Bewegung
  zurueck; idempotente Aufrufe liefern die bereits gespeicherte
  Bewegung.
- Die Reihenfolge der `movements` bleibt beim Serialisieren erhalten,
  damit die Projektion reproduzierbar bleibt.

Vorgeschlagene Persistenztechnologien: SQLite (Append-only
`stock_movements`-Tabelle mit Indizes auf
`(ingredient_id, location_id)` und `idempotency_key`) oder Supabase
PostgreSQL mit derselben Tabelle und `Row Level Security` analog zu
`PRODUCT_BLUEPRINT` §18.3.

## 8. Konventionen und Lesarten

- Alle `Codable`-Modelle verwenden `String`-IDs (UUIDs oder
  sprechende Schluessel), damit sie ohne DTO-Wechsel sowohl in der
  Sandbox als auch spaeter in Supabase genutzt werden koennen.
- `Ingredient.baseUnit` ist die *kanonische* Basiseinheit; alle
  Rezeptkomponenten, Bewegungen und Mindest-/Zielbestaende werden in
  dieser Einheit angegeben und vom Konstruktor validiert.
- Projektionen werden frisch berechnet, nicht gecacht. Caching folgt
  mit der Persistenzschicht.
- Bei negativen Bestaenden wird die Warnung `critical` ausgeloest und
  der Wert unveraendert zurueckgegeben. Operator:innen sollen dadurch
  fehlende Wareneingaenge oder zu hohe Verbraeufe erkennen, statt still
  auf Null geclampt zu werden.
- `InventorySnapshotEntry` bildet die Sicht fuer die spaetere UI-Schicht
  (Tabelle "Bestaende pro Lagerort"). Die UI ist nicht Teil dieses
  Tickets.
