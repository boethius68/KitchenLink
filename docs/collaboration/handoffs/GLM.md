# Handoff — GLM (KL-INVENTORY-002 Inventory-Operator-UI)

**Datum:** 18. Juli 2026
**Agent:** GLM-5.2 via ZCode
**Branch:** `glm/inventory-operator-ui` (von `origin/main`, `298b74a`)
**Ticket:** KL-INVENTORY-002 — Read-only Bestandsansicht (V2-Oberfläche)
**Status:** Vollständig umgesetzt und verifiziert (build + komplette
Unit-Suite + UI-Suite + Screenshot-Capture Light/Dark alles `TEST
SUCCEEDED`); committet auf Branch, bereit für Review.

> KL-WEB-004 (Menü aus Supabase) ist zuvor gemergt worden (`298b74a`).
> Dieser iOS-Strang berührt keinen Gast-Web-/Supabase-Code; die
> Verzeichnisbäume sind disjunkt.

## Anlass und Entscheidung

Nachdem KL-WEB-001 bis -004 abgeschlossen waren, hat der Nutzer als
nächsten Strang explizit die Vertiefung einer iOS-Domäne gewählt und aus
drei Kandidaten (Inventory-UI, Workforce-UI, Event-Log-Integrationsnaht)
die **Inventory-Operator-UI** ausgewählt — der sauberste Scope: MiniMax'
Domain (KL-INVENTORY-001) ist vollständig gemergt und explizit mit
vertagter UI versehen (`INVENTORY_MODEL.md` §6 listet UI, §8 definiert
`InventorySnapshotEntry` als „die View für die spätere UI-Schicht").

Es ist **keine neue Produkt- oder Designentscheidung**. Die Domain ist
genehmigt, und `DESIGN_SYSTEM.md` §6 erlaubt explizit den Interim, dass
eine noch nicht mit eigenem Form-Muster versehene Operation über Farbe
und Klartext sichtbar bleibt. Ein späterer `.stock`-Glyph ist eine
separate Designfreigabe; heute wird er bewusst nicht erfunden.

## Was dieser Strang tut

Eine read-only Bestandsansicht für Betreiber:innen, die ihren Zustand
ausschließlich aus der echten `InventoryProjection` und dem
`InventoryReplenishmentAdvisor` der KL-INVENTORY-001-Domain ableitet —
kein zweites Bestandsmodell, keine Mockwerte. Die Ansicht gruppiert
je Lagerort (Küche vor Bar vor Keller/Lager/Eingang), zeigt physisch,
reserviert, verfügbar und eine Schwere-Bewertung (`ok`/`warning`/`critical`)
als Klartext-Verb plus Urgency-Farbe. Buchen, Persistenz und Cloud-Sync
bleiben vertagt.

Muster analog KL-OPS-001 (Heute/Küche): pure Foundation-Projektion
(testbar ohne App) + dünner SwiftUI-View + `@MainActor ObservableObject`-
Zustandsträger + `@MainActor enum`-Demo-Seeder + Swift-Testing-Unit-Tests.

## Umgesetzte Dateien (exklusiver Schreibbereich, alle additive oder MiniMax-Core unangetastet)

**Neue Dateien unter `kitchenlink/Features/Inventory/Views/`**
(Xcode nimmt via `PBXFileSystemSynchronizedRootGroup` automatisch auf,
kein Projektfile-Edit nötig — wie von MiniMax im Handoff dokumentiert):

- `KitchenLinkV2InventoryStockProjection.swift` (neu, Foundation-only):
  `KitchenLinkV2InventoryStockRow` (Werttyp: Zutatname, BestandTriple,
  Urgency, Verb, Explanation) und `KitchenLinkV2InventoryLocationGroup`.
  Pure `static func groups(catalog:ledger:)` bzw. `rows(...)` — die
  einzige UI-seitige Projektionslogik. Severity→Urgency-Abbildung
  (`ok`→neutral, `warning`→waiting, `critical`→critical) und
  Klartext-Verben („verfügbar"/„knapp"/„kritisch"). Sortierung:
  Dringlichkeit dann Zutatname; Lagerorte operational (Küche zuerst).
- `InventoryOperatorModel.swift` (neu): `@MainActor final class … :
  ObservableObject`. Kapselt Katalog + Ledger (die bewusst nicht
  `Sendable`/`ObservableObject` sind — KL-INVENTORY-001) und
  republished die frisch projizierten `groups`. `refresh()` rechnet
  die Projektion jedes Mal frisch (Caching ist per `INVENTORY_MODEL.md`
  §8 vertagt). Helfer `totalRowCount`/`criticalCount` für Header.
- `InventoryOperatorView.swift` (neu): SwiftUI-View. `@StateObject`-
  owned Model, gruppiert nach `StockLocation`, Karte pro Lagerort,
  Zeile mit Name + Explanation + verfügbar-Wert und Verb in
  Urgency-Farbe. Header-Summary wechselt auf Critical-Textfarbe, sobald
  kritische Zeilen existieren. Einzelne `persistentPrimary`-Aktion
  („Demo-Szenario laden") ist die einzige Zitrone — wie bei Heute.
- `InventoryOperatorDemoSeeder.swift` (neu): `@MainActor enum`, ruft
  `InventorySandboxFixture.makePopulatedLedger()` auf. Kein Relay-/
  Repository-Kontakt (der Inventory-Pfad hat keine Order-Domain).

**Editierte Dateien (rein additive Zeilen, keine bestehenden verändert):**

- `kitchenlink/App/KitchenLinkDesignPreviewConfiguration.swift` (+11
  Zeilen): neue `demoInventoryLaunchArgument`-Konstante
  (`--kitchenlink-demo-inventory`) plus parallele
  `shouldSeedDemoInventory(...)`-Methode. Keine der bestehenden
  Methoden geändert.
- `kitchenlink/App/KitchenLinkV2BusinessHomeView.swift` (+14 Zeilen):
  dritter `NavigationLink`-Block im `operationsAccess`-Plug-in (Datei
  ~Zeile 163), exakt parallel zu Heute/Küche. Titel „Bestand",
  SF-Symbol `archivebox`, `accessibilityIdentifier("business.openInventory")`.
- `kitchenlinkUITests/kitchenlinkV2ScreenshotTests.swift` (+26 Zeilen):
  neuer Branch im Screenshot-Test, der mit `--kitchenlink-demo-inventory`
  startet, auf `business.openInventory` tappt und `inventory.title`
  sowie „Positionen" als Text-Assertion prüft. Skipt sauber ohne
  `KITCHENLINK_CAPTURE_V2_SCREENSHOTS=1`.

**Neue Testdatei:**

- `kitchenlinkTests/KitchenLinkV2InventoryStockProjectionTests.swift`
  (neu, Swift Testing, 12 `@Test`): Severity→Urgency-Mapping (3 Fälle),
  leerer Katalog, Fixture-Form (2 Lagerorte, 24 Zeilen cross-product,
  mindestens eine kritische Zeile), SortierungMonotonie,
  Lagerort-Reihenfolge (Küche vor Bar), aufgelöste Zutatnamen,
  `available == physical - reserved`, nicht-leere Explanation.
  Keine Relay-/Repository-Abhängigkeit; die darunterliegende Domain
  ist durch MiniMax' 53 Tests bereits abgedeckt.

Dateinamen mit `KitchenLinkV2`-Präfix (statt `Inventory...`) bewusst
gewählt, um nicht mit MiniMax' 8 `Inventory*Tests.swift`-Dateien zu
kollidieren und konsistent mit `KitchenLinkV2TodayEvents` etc. zu sein.

## Was bewusst NICHT getan wurde

- **Keine Edits an MiniMax' 8 Core-Dateien** oder `INVENTORY_MODEL.md`.
  `Features/Inventory/` ist zwar nach Merge Shared Territory (PEER_WORKFLOW),
  aber die sauberste Scope-Ehre ist additive-only.
- **Kein neuer `KitchenLinkV2Operation`-Case** (kein `.stock`), keine
  Edit an `KitchenLinkDesignSystemV2.swift`, keine neuen Tokens, keine
  neue Urgency. Die Zeile trägt Dringlichkeit als Farbe und Klartext,
  kein Form-Glyph — §6 Interim.
- **Kein Buchen/Wareneingang/Verbrauch/Verderb** — Folgeticket. Die
  Ansicht ist heute strikt read-only.
- **Keine Persistenz** (§7-Seam bleibt vertagt).
- **Keine `@EnvironmentObject`-Injection am App-Root** — die Ansicht
  owned ihr Model via `@StateObject`. Bei einem späteren Buchen-Ticket
  kann das zu einem app-weiten Service befördert werden.
- **Keine Änderung an `InventoryLedger`-Sichtbarkeit** — wrappt, nicht
  verändert.
- **Keine `DECISIONS.md`-Änderung** — keine neue Produkt- oder
  Designentscheidung; alles im Rahmen bereits genehmigter Specs.

## Verifikation

```bash
# iPhone 17 Pro, iOS 26.5
xcodebuild build  -project kitchenlink.xcodeproj -scheme kitchenlink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
# → ** BUILD SUCCEEDED **

xcodebuild test   -project kitchenlink.xcodeproj -scheme kitchenlink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:kitchenlinkTests/KitchenLinkV2InventoryStockProjectionTests
# → 12/12 grün

xcodebuild test   ... -only-testing:kitchenlinkTests
# → ** TEST SUCCEEDED ** (komplette Unit-Suite inkl. MiniMax' 53 Inventory-Tests)

xcodebuild test   ... -only-testing:kitchenlinkUITests
# → ** TEST SUCCEEDED **

KITCHENLINK_CAPTURE_V2_SCREENSHOTS=1 KITCHENLINK_APPEARANCE=light xcodebuild test ...
KITCHENLINK_CAPTURE_V2_SCREENSHOTS=1 KITCHENLINK_APPEARANCE=dark  xcodebuild test ...
# → jeweils ** TEST SUCCEEDED ** (inkl. neuer Inventory-Branch mit Assertions)
```

## Verbleibende Risiken / offene Punkte

- **Visuelle Live-Inspektion blockiert.** idb (der UI-Automation-Backend
  für `ios_ui_describe`/`ios_ui_tap`) ist in dieser Umgebung nicht
  verfügbar; die Live-Simulator-Screenshots lassen sich daher von mir
  nicht visuell gegen `DESIGN_SYSTEM.md` prüfen. Der Screenshot-Test
  (Light + Dark) ist mit Text-Assertionen (`inventory.title`, „Positionen")
  jedoch autoritativ durchgelaufen — ein leerer oder kaputter View würde
  dort failen. Eine menschliche visuelle Prüfung durch den Reviewer
  bleibt offen, ist aber kein Blocker.
- **Projection ist ungecached.** Für Sandbox (24 Paare, 17 Bewegungen)
  trivial; bei realen Venues mit hunderten Zutaten × vielen Lagerorten
  × tausenden Bewegungen wird eine Projektions-Cache nötig (§8
  dokumentiert das als mit der Persistenzschicht kommend).
- **Heute wird die Ansicht nur vom Demo-Seeder befüllt.** Ein späteres
  Buchen-Ticket muss den `InventoryOperatorModel.load(...)`-Pfad von
  einer echten Quelle (Persistenz, Cloud) aus triggern; der seams
  dafür ist vorbereitet (`load(catalog:ledger:)`, `refresh()`).
- **Keine Such-/Filterfunktion.** Bei vielen Zutaten wird die Liste
  lang; ein Suchfeld ist ein mögliches Folgeticket.

## Recommended Next Step

Review durch Claude Code oder Codex (Peer-Workflow). Wenn die Suite
dort reproduzierbar grün läuft und die Statusmodell-Entscheidung
(Severity→Urgency, kein `.stock`-Glyph als bewusster Interim) akzeptiert
wird, kann der Branch nach `main` gemergt werden. Der Merge-Agent
aktualisiert `CURRENT.md`; `WORK_QUEUE.md` ist in diesem Branch schon
angepasst.
