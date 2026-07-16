# Claude Audit: Integrierter Stand ab `03c146a`

**Datum:** 16. Juli 2026
**Auditor:** Claude Code (Claude Fable 5), Branch `claude/design-audit`
**Umfang:** `03c146a` (V2-Scan-Erlebnis) bis `4a8506e` (HEAD), mit Schwerpunkt
`MenuImportDraft`, `MenuImportDraftAdapter`, duale Scanner-Pipeline,
SwiftUI-V2 gegen Round 04 / `DESIGN_SYSTEM.md`, Startpfade und Testbarkeit.
**Ticket:** KL-CLAUDE-001

## Ergebnis in einem Satz

Keine P0- oder P1-Findings; der integrierte Stand ist konsistent, ehrlich in
seiner Evidenz und reproduzierbar getestet. Fünf P2/P3-Punkte sind unten
dokumentiert; keiner blockiert den Start von Phase B (KL-OPS-001).

## Findings

### P2-1 · Unlokalisierte Evidenz zeigt auf fremde Zeilen oder Seite 0

- **Datei:** `kitchenlink/Features/MenuImport/MenuImportDraftAdapter.swift:550-593`
  (`fallbackEvidence`), genutzt von `makeOffer` (`:343-360`) und `makeText`.
- **Risiko:** Wenn kein OCR-Match existiert, zeigt die Offer-Evidenz auf die
  Namenszeile, ersatzweise auf die *erste OCR-Zeile des Dokuments* oder auf eine
  degenerierte `1e-6`-Box bei Seite 0; `rawPrice`/`rawText` sind dann teilweise
  aus Legacy-Cents synthetisiert (`formattedPrice`). Die geplante
  Evidenz-Review-UI (KL-MENU-004) wuerde damit falsche Seitenausschnitte als
  Beleg rendern.
- **Beleg:** Codepfad-Analyse; der Zustand ist per `method == .layoutRule`,
  `reviewState == .needsReview`, niedriger Confidence und
  `methodDetail == "legacy-price-without-matched-ocr-line"` markiert, aber nur
  ueber Magic Strings erkennbar.
- **Kleinste Korrektur:** Vor KL-MENU-004 einen expliziten
  "nicht lokalisiert"-Zustand einfuehren (z. B. dokumentierter
  `methodDetail`-Kontrakt oder optionale Bounding Box) und die Review-UI darauf
  testen. Blockiert KL-OPS-001 nicht.

### P3-1 · Kandidaten-Dedup vergleicht gegen moeglicherweise falsche Evidenzseite

- **Datei:** `kitchenlink/Features/MenuImport/MenuImportDraftAdapter.swift:130-135`
  (`alreadyRepresented`).
- **Risiko:** Der Duplikatabgleich nutzt die Seite der *Namens-Evidenz* des
  Legacy-Eintrags. Faellt diese Evidenz auf `fallbackLines.first` (Seite 0)
  zurueck, kann ein echter unbepreister Kandidat faelschlich unterdrueckt oder
  ein Duplikat aufgenommen werden.
- **Beleg:** Codepfad-Analyse; in den drei Fixtures nicht beobachtet
  (Benchmark-Draft-Zahlen stimmen mit `CURRENT_RESULTS.md` ueberein).
- **Kleinste Korrektur:** Dedup nur gegen tatsaechlich gematchte Namenszeilen
  ausfuehren oder zusaetzlich die Titel-Bounding-Box vergleichen.

### P3-2 · Legacy-Parserverhalten wurde im Integrationscommit mitgeaendert

- **Datei:** `kitchenlink/ContentView.swift` (c1d3970): Preiszeilen-Abschluss
  ohne Rechtsbuendigkeits-Pflicht (`if let pending = pendingItem`, vorher
  `isRightAlignedPrice`-Guard), Abschnitts-X-Grenze `0.44 -> 0.52`, ganze
  Euro-Preise mit Waehrungskontext, generische Menue-Ueberschriftenregel.
- **Risiko:** Die Aussage "der Legacy-Pfad bleibt unveraendert" gilt nur auf
  Anker-/Schwellen-Ebene: `gold-baseline.json` entstand im selben Commit
  (`git log` zeigt nur c1d3970), ein Vorher-Nachher-Vergleich ist nicht mehr
  moeglich.
- **Beleg:** `git diff 03c146a..c1d3970 -- kitchenlink/ContentView.swift`;
  `git log --oneline --all -- docs/test-fixtures/scanner-benchmark/gold-baseline.json`.
- **Kleinste Korrektur:** Formulierung in `CURRENT.md` praezisieren
  ("Anker-Niveau, Baseline aus c1d3970"). Kein Codefix noetig; die neuen Regeln
  sind durch `MenuImportParserTests` und den Benchmark abgedeckt.

### P3-3 · Fotoauswahl verliert nicht ladbare Seiten stumm

- **Datei:** `kitchenlink/Features/MenuImport/MenuImportEntryView.swift:434-439`
  (`loadSelectedPhotos`).
- **Risiko:** Fotos, die nicht als `Data`/`UIImage` ladbar sind, werden per
  `continue` uebersprungen. Die Statusmeldung zaehlt nur geladene Seiten; ein
  Betreiber kann unbemerkt mit fehlenden Karten-Seiten importieren.
- **Beleg:** Codepfad-Analyse.
- **Kleinste Korrektur:** Anzahl uebersprungener Elemente in
  `importStatusMessage` ausweisen.

### P3-4 · 6a-Kontrastgarantie ist nicht automatisiert abgesichert

- **Datei:** `kitchenlinkTests/KitchenLinkDesignSystemV2Tests.swift` (2 Paare).
- **Risiko:** Die Round-04-Zusage "jede Statusform >= 3:1 auf allen Flaechen"
  haengt allein an Hexwerten im Code; eine spaetere Tokenaenderung wuerde nicht
  auffallen.
- **Beleg:** `KitchenLinkV2Palette.RGB.contrastRatio` existiert bereits, wird
  aber nur fuer Traube/Zitrone und Text/Flaeche getestet.
- **Kleinste Korrektur:** Parametrischen Test Urgency-Symbolfarben x
  Flaechen (Sprudel, Traube, Tief) mit `>= 3.0` ergaenzen.

### P3-5 · Statisches Diagnosefeld ist nicht nebenlaeufigkeitssicher

- **Datei:** `kitchenlink/ContentView.swift:4011`
  (`MenuImportService.lastImportDiagnosticsStorage`).
- **Risiko:** Unsynchronisierte statische Variable, beschrieben aus async
  Kontexten. Unter Swift 5 praktisch Single-Writer; unter
  Swift-6-Strict-Concurrency ein Compile-Fehler.
- **Beleg:** Codepfad-Analyse; `SWIFT_VERSION = 5.0` im Projekt.
- **Kleinste Korrektur:** Bei der naechsten Service-Extraktion in einen Actor
  oder `@MainActor`-Kontext kapseln; kein Sofortfix noetig.

## Verifizierte Staerken

- **Draft-Kontrakt:** Strikte Trennung absoluter Preise und Deltas je
  `priceKind`, globale ID-Eindeutigkeit, Seiten-/Bounding-Box-/
  Confidence-Grenzen, preislose Eintraege als gueltige Warnung —
  alles rekursiv validiert und durch `MenuImportDraftTests` abgedeckt,
  inklusive JSON-Roundtrip.
- **Ehrliche Evidenz im Regelfall:** Preis-Evidenz referenziert die echte
  OCR-Zeile samt Rohtext (`adapterPreservesRawPriceAndBoundingBox`); Extras
  bleiben Deltas statt zweiter Basispreise; preislose Pending-Bloecke werden als
  `needsReview` ohne erfundenen Nachbarpreis aufgenommen (Benchmark: beide
  Lichtburg-Preisverluste explizit unbepreist, 7+2 Review-Kandidaten).
- **V2-Designsystem:** Alle Farb-Token stimmen wertgenau mit Round 04 Turn 6
  und `DESIGN_SYSTEM.md` ueberein (hell und dunkel nachgeprueft). Zitrone
  existiert nur als `Action.persistentPrimary/Pressed` und `logoHandoff`;
  kein Status-Token nutzt Zitrone. Vorgangsart und Dringlichkeit sind getrennte
  Typen mit Accessibility-Labels; Formen entsprechen 6a (Kreis, Raute,
  durchgestrichener Ring, Quadrat).
- **Zitronenregel in der Flaeche:** Pro sichtbarem Kontext genau eine
  Zitronen-Primaeraktion (Home: Scannen; Import nach Ergebnis: genau ein
  Primaerbutton, Scanner faellt auf sekundaer zurueck). Scanrahmen im
  Ruhezustand neutral (`border.control`), wie in der Round-04-Review gefordert.
- **Startpfade:** V2 ist Default, `--kitchenlink-design-legacy` erzwingt die
  alte Ansicht, beide Richtungen sind sichtbar verlinkt und per UI-Test
  abgesichert; Accessibility-IDs stabil.
- **Reproduzierbarkeit:** Der 14-Seiten-Benchmark wurde komplett neu ausgefuehrt
  und reproduziert exakt die dokumentierten Werte aus `CURRENT_RESULTS.md`.

## Ausgefuehrte Befehle und Ergebnisse

- `xcodebuild test … -only-testing:kitchenlinkTests` (iPhone 17 Pro Simulator):
  **TEST SUCCEEDED**, alle Faelle gruen (Draft, Adapter, Parser, Repository,
  Ordering, Designsystem, Preview-Konfiguration); Benchmark-Test korrekt
  uebersprungen ohne Flag.
- `xcodebuild test … -only-testing:kitchenlinkUITests/kitchenlinkUITests`:
  **TEST SUCCEEDED**, 3/3 (Scan-First-Launch V2, Legacy->V2-Rueckweg,
  Launch-Performance). Xcode meldete transiente
  LLDB-/Launch-Retry-Warnungen, Exit-Code 0.
- `scripts/run-scanner-benchmark.sh`: **passed: true**.
  Scheune 4/4 · 15/15 · 15/15; Lichtburg 11/12 · 14/16 · 14/16, Draft-Namen
  16/16, Draft-Preise 14/16, 2 explizit unbepreist, 7 Review-Kandidaten;
  Alexxanders 6/7 · 15/15 · 15/15, 2 Review-Kandidaten. Identisch mit
  `CURRENT_RESULTS.md`.

## Visuell geprueft

iPhone 17 Pro Simulator (iOS 26.5):

- V2-Home hell und dunkel (Standardgroesse): Token, Zitronen-Disziplin,
  neutraler Rahmen, Logo-Uebergabe korrekt.
- V2-Home hell und dunkel bei `accessibility-extra-extra-extra-large`:
  Texte wachsen ohne Abschneiden, Wortmarke bleibt, SANDBOX-Chip wird zum
  Icon, "FUER BETREIBER" wird planmaessig ausgeblendet.
- Legacy-Home hell via `--kitchenlink-design-legacy`: unveraendert erreichbar,
  sichtbarer Weg zurueck zur Designvorschau.

Nicht visuell geprueft: iPad (es existiert noch keine V2-iPad-Flaeche),
Reduce Motion (keine dauerhafte Animation im V2-Home gefunden).

## Restunsicherheiten

- Der LLM-Reflexionspfad (`OpenAIChatRequest`-Format) wurde nur gelesen, nicht
  ausgefuehrt (kein Schluessel konfiguriert, Standard deaktiviert).
- Ein lokaler End-to-End-Test Gastbestellung -> Kuechenstatus ohne Cloud fehlt
  weiterhin (bekannter KL-QA-001-Rest).
- `importedDraft` lebt nur im Speicher; Absturz/Neustart verwirft ihn. Bewusste
  Entscheidung bis KL-MENU-004, aber im Review-Slice zu beruecksichtigen.
- Die Benchmark-Anker messen Wiedererkennung, keine Vollstaendigkeit; neue
  Menues ausserhalb der drei Fixtures bleiben unbewertet.

## Empfehlung

**Phase B (KL-OPS-001) kann ohne Vorfix starten.** Keine P0/P1-Findings.
P2-1 ist eine Eingangsbedingung fuer KL-MENU-004 (Evidenz-Review-UI), nicht
fuer die Heute-/Kuechen-Referenzflaechen. P3-Punkte koennen als kleine
Folgeaufgaben in bestehende Scopes einfliessen.
