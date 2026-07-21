# Claude Code Handoff

**Updated:** 21 July 2026 (Session-Teil 17: Allergen-Legende-Fix + manueller Editor)
**Zuvor:** 19 July 2026 (Nacht)
**Branch:** `main` (Main-Only-Modus seit 19. Juli 2026, `DECISIONS.md`)
**Status:** Zwei Straenge in dieser Session: (1) Scan-zu-Publish-Bruecke
(KL-MENU-005) implementiert — Migration, Publish-Client/-Model/-Sheet,
11 neue Tests, komplette Suite gruen; offen ist nur die reale Abnahme
(SANDBOX_SETUP.md §6.2). (2) Nach dem Nutzerbefund zur Erkennungsqualitaet
(„Namen passen groesstenteils, aber nicht alle") die Import-Review-Umgebung
KL-SCAN-002 gebaut: `scripts/run-import-review.sh` erzeugt einen
Seite-an-Seite-HTML-Report ueber alle Karten mit Fundstellen-Overlays,
automatischen Markierungen und Feedback-Export. Erster Lauf verifiziert;
er bestaetigt die Nutzerbeobachtung mit konkreten Befunden (Legende-Codes
in Beschreibungen und Namen, doppelte Fragmente, OCR-Verwechslungen).
Qualitaetsziele verbindlich in
`docs/test-fixtures/scanner-benchmark/QUALITY_TARGETS.md`. **Runde 1 ist am
20. Juli ausgewertet** (Session-Teil 12): Nutzer-Feedback + nachgeholte
vollstaendige Eigenverifikation in `ROUND_01_FINDINGS.md`; Kernbefund: die
OCR ist nicht der Engpass, der Regel-Parser ist es; die Review-Umgebung
kann jetzt lokal vs. KI-Pfad umschaltbar vergleichen. Offen fuer den
Nutzer: API-Key/Anbieter-Entscheidung fuer den Runde-2-Vergleichslauf;
ausserdem weiterhin die realen Abnahmen KL-CLOUD-001 (§6.1) und
KL-MENU-005 (§6.2). Details in Session-Teil 10 bis 12.

Zur Vorsession (Session-Teil 9): KL-CLOUD-001 und KL-OFFLINE-008 sind in
`main` gemergt; nicht gemergte Branch-Staende liegen als `archive/*`-Tags,
das Loeschen der Remote-Branches wartet auf Nutzerbestaetigung.

## Session-Teil 17: Allergen-Legende aus dem Bild + manueller Karten-Editor

Zwei zusammenhängende Stränge, beide verifiziert und in `main` (`87ccb34`
für den Fix, Editor-Commit folgt).

### A. Allergen-Legende: KI liest sie jetzt direkt aus dem Bild

Nutzer-Befund (zu Recht): die Allergen-Icons waren schlechter als in der Alpha.
Ursache im Code bestätigt: das KI-Schema hatte **kein Legenden-Feld**; die
einzige Legendenquelle war die lokale OCR-Heuristik `detectAllergenLegend`.
Scheiterte die, blieb `section.allergenLegend` leer und die Icons konnten Codes
nicht zuordnen. (Ehrliche Einordnung: Alte Kanzlei, die ich fälschlich als
„perfekt" bezeichnet hatte, druckt gar keine Legende — „Bitte fragen Sie unser
Serviceteam" —, die 0 erfassten Codes waren dort also korrekt; ich hatte es nur
nie überprüft.)

Fix in `kitchenlink/ContentView.swift`:
- Prompt/Schema um `legend` (Code→Klartext) erweitert; jeder an einem Artikel
  genutzte Code muss in der Legende erklärt sein; Per-Item-Code-Regel geschärft.
- `LLMMenuRoot` dekodiert die Legende liberal (Objekt- ODER Array-Form, gängige
  Feldnamen), normalisiert Keys auf Kleinbuchstaben.
- `mergeLegends`: KI-Legende hat Vorrang, lokale OCR-Legende füllt Lücken.
- Page-by-Page: Legende jeder Seite (auch reiner Legendenseiten OHNE Artikel →
  `.empty(legend:)`) wird karteweit vereint und auf ALLE Sektionen geschrieben.
- `AllergenCatalog.definitions`: Standard-EU-Codes (a–p, 1–14) rendern als Icon
  auch dann, wenn die erkannte Legende sie mal nicht auflistet; unbekannter
  Zeichen-Müll ohne Legendeneintrag bleibt gefiltert.

**Verifiziert:** direkter Gateway-Probe mit dem NEUEN Prompt auf einer echten
Karte (pizzeria-zum-italiener) — big-pickle liefert jetzt das `legend`-Feld
exakt mit der gedruckten Karten-Legende (A=glutenhaltiges Getreide, B=Krebstiere
…). Beweis in `/tmp/kl-legend-probe-proof.txt`. Harness-Lauf end-to-end grün
(Deklarationen tragen die karten-eigene Legendenformulierung, 56/92 Artikel mit
Codes). Build grün, Unit-Suite 208/0/2.

### B. Manueller Speisekarten-Editor (Grundlage für den Import)

Nutzer-Vorgabe: erst den Editor vollständig ausbauen, damit klar ist, was der
Import abbilden muss. Der Editor arbeitet auf demselben leichten Modell
(`MenuSectionData`), das der Import erzeugt und `MenuPublishSheet` konsumiert —
Import und Handeingabe konvergieren so auf ein Modell und denselben Publish-Weg.

- **NEU** `kitchenlink/Features/MenuEditor/MenuManualEditorView.swift`:
  Kategorien (anlegen/sortieren/löschen), Gerichte (Name, Beschreibung, Preis in
  €→Cent, Art Essen/Getränk), Varianten/Portionen/Extras, sowie Allergen-/
  Zusatzstoff-Auswahl als EINHEITLICHE App-Icons (Standardcodes a–p/1–14 aus
  `AllergenCatalog`, plus Hauscodes mit eigener Bedeutung in die karteweite
  Legende). Live-Vorschau „wie für Gäste" (dieselbe `AllergenBadgesRow`).
  Auto-Persistenz über `KitchenLinkStore`, Übergabe an `MenuPublishSheet`.
- `KitchenLinkStore.updateMenuSections(_:)` (persistiert, erlaubt leere Karte
  während der Bearbeitung).
- Einstieg im Betreiber-Home: Button „Karte von Hand bearbeiten"
  (`business.editMenuManually`).
- Zugriffsebenen in `ContentView.swift` von `private` auf intern geweitet, damit
  der Editor sie wiederverwendet: `PriceFormatter`, `AllergenCatalog`,
  `AllergenDefinition`, `AllergenBadgeView`, `AllergenLegendView`,
  `AllergenBadgesRow`, `MenuItemOptionsListView`. `MenuSectionData`,
  `MenuItemData`, `MenuItemVariant` sind jetzt `Equatable` (für Change-Tracking).
- **NEU** `kitchenlinkUITests/MenuManualEditorUITests.swift`: fährt Kategorie →
  Gericht → Name/Preis → Allergen-Code → Gäste-Vorschau real durch. Grün (1/1),
  drei Screenshots belegen die Icon-Auswahl (A ausgewählt, mit Symbol+Klartext).

### C. Publish-Vertrag um Legende + Varianten erweitert (erledigt, verifiziert)

Der Editor pflegt Legende und Varianten — jetzt überträgt der Publish-Weg sie
auch bis in die DB.

- `KitchenLinkPublishMenu`: `Category.allergen_legend` (Objekt) und
  `Item.variant_options` (Array `{name, price_cents, kind}`) ergänzt; der Builder
  füllt sie aus `MenuSectionData.allergenLegend` bzw. `MenuItemData.variants`
  (Legenden-Keys klein normalisiert, leere Varianten/Preise ausgelassen).
- Migration `20260721120000_operator_publish_menu_legend_variants.sql`: ersetzt
  additiv die RPC, sodass sie beide Felder in die bereits vorhandenen Spalten
  `menu_categories.allergen_legend` / `menu_items.variant_options` schreibt
  (typ-gesichert, Legenden-Keys klein, `kind` auf portion|extra|variant
  normalisiert, leere Varianten weg).
- **Latenter Bug gefixt:** die RPC referenzierte `menu_id` mehrdeutig (OUT-Spalte
  der RETURNS TABLE vs. Tabellenspalte). Die erste Fassung (20260719200000)
  wurde real nie ausgeführt, daher unentdeckt; sie wäre beim ersten echten
  Publish an `delete ... where menu_id = v_menu_id` gescheitert. Fix per
  `#variable_conflict use_column`.
- **Verifiziert:** neue Payload-Tests grün (Unit-Suite 211/0/2); die Migration
  FUNKTIONAL gegen ein lokales Postgres 16 geprüft (throwaway-Cluster, Stubs für
  `auth.uid()`/`is_venue_staff`): RPC schreibt Legende (Groß-Key→klein, leeres
  Paar weg) und Varianten (leere raus, ungültiges kind→variant) korrekt; Defaults
  `{}`/`[]`; Replace-Semantik und „genau eine aktive Karte" intakt.

### D. Gast-Web zeigt Legende + Varianten (erledigt, verifiziert)

Das Gast-Web (`guest-web/`, Next.js 16, liegt DOCH in diesem Repo) rendert die
neuen Felder jetzt.

- `guest-web/src/lib/allergen-catalog.ts` (neu): Standard-Code→Klartext
  (a–p, 1–14, identisch zur iOS-App) + `resolveAllergens(codes, legend)` —
  Karten-Legende hat Vorrang, Standard-Katalog füllt Lücken, Keys/Codes klein
  normalisiert.
- `menu-loader.ts`: Select um `allergen_legend` (Kategorie) sowie
  `allergen_codes` + `variant_options` (Artikel) erweitert; beim Mappen werden
  die Codes gegen die Kategorie-Legende aufgelöst und die Varianten defensiv
  (leere raus, kind normalisiert) übernommen.
- `venue-data.ts`: `GuestMenuItem` um `allergens` + `variants`; zwei
  Sandbox-Artikel angereichert (Demo).
- `GuestMenuCard.tsx` + `globals.css`: Allergen-Pillen (Code + Klartext) und
  Varianten-/Portions-/Extra-Zeilen unter der Beschreibung.
- **Verifiziert:** typecheck + lint + 71 Vitest-Tests grün (neue Loader- und
  Katalog-Tests); Dev-Render Desktop und Mobile (Badges brechen sauber um);
  Production-Build (SSG `/alte-muehle/menu`) grün. Screenshots zeigen
  „G Milch / Laktose", „A Glutenhaltiges Getreide" usw. + „Portion: Große
  Portion", „Extra: Pommes statt Salat +1,50 €".

Damit ist die Kette Editor/Import → Payload → RPC → DB → Gast-Web durchgängig.

### Offen / nächster Schritt

- **Migration anwenden:** `20260721120000` muss noch auf die Supabase-DB
  gespielt werden (Nutzer-Workflow, SANDBOX_SETUP §6.2); lokal verifiziert, real
  noch nicht angewandt. Erst danach zeigt das Gast-Web bei ECHTEN (statt Sandbox-)
  Karten Legende + Varianten.
### E. Zweisprachige Dubletten entfernt (erledigt, an echten Daten verifiziert)

Ursache aus dem realen Report (Ristorante Italia) belegt: die Karte druckt erst
den kompletten deutschen Teil, dann denselben auf Englisch. Die Sektionstitel
weichen ab („Antipasti - Vorspeisen" vs „Antipasti - Starters"), also führt
`mergeImportedSections` sie nicht zusammen — jedes Gericht doppelt (44 Sektionen,
263 Artikel, ~90 exakte Dubletten).

- Neue `MenuImportService.dropMirroredSections` (in beide LLM-Pfade eingehängt,
  nach Merge/Legende): verwirft eine Sektion, wenn sie ein Spiegel einer früheren
  ist — zwei konservative Signale: (1) exakte Namensgleichheit aller Gerichte
  (kind|Name|Preis); (2) identische Preis-Multimenge (+ kind) ab 5 Gerichten
  (fängt übersetzte Namen wie „Orange juice" = „Orangensaft"). Unter 5 Gerichten
  nur Namens-Signal, damit kleine Sektionen mit zufällig gleichen Preisen (z. B.
  Rot-/Weißweine) NICHT fälschlich verschwinden.
- **Verifiziert an den echten Report-Daten** (Simulation der exakten Logik):
  44→29 Sektionen, 263→159 Artikel (104 Dubletten entfernt), KEINE deutsche
  Sektion fälschlich verworfen (der Weißwein-False-Positive der naiven
  Preisvariante ist durch das ≥5-Gate ausgeschlossen). 5 neue Swift-Unit-Tests
  (beide Signale + Sicherheitsfälle) grün; Suite 216/0/2.
- Rest: wenige kleine (1–2-Artikel-)Übersetzungssektionen bleiben bewusst als
  Dublette stehen (sicherer als Fehl-Löschen); im Review leicht zu entfernen.

### F. Per-Item-Code-Vollständigkeit untersucht — KEIN Bug (Messartefakt)

Statt am Prompt zu drehen, erst an den echten Report-Daten gemessen (16 Karten):
- Die „~51 %" werden von Karten ohne gedruckte Codes gezogen: Alte Kanzlei (0 %),
  hafenrestaurant (4 %), zum-franziskaner (18 %) verweisen im Quelltext
  ausdrücklich auf eine separate Allergiker-Liste („liegt an der Rezeption
  bereit"). 0–4 % sind dort KORREKT.
- Bei code-DRUCKENDEN Karten ~62 %, inkl. legitim code-loser Artikel (Getränke,
  Weine, einfache Gerichte).
- Kreuz-Check an der code-dichtesten Karte (ristorante-italia, 114
  OCR-Code-Zeilen): von 89 Items ohne Code haben nur 6 einen „Code" in der
  Quelle — alle 6 sind False Positives (nachgestelltes „l" = Liter-Einheit, kein
  Allergen „l"). Die KI hat sie KORREKT nicht erfasst. → praktisch KEINE echten
  Drops.

Schluss: das Per-Item-Code-Verhalten ist korrekt und bewusst konservativ. Für ein
Allergen-Feature ist das Erfinden von Codes gefährlicher als Weglassen; ein
Prompt-Push zum Zahlen-Hochtreiben wäre ein Sicherheits-Rückschritt. KEINE
Änderung vorgenommen (Befund dokumentiert).

### G. „Beispielkarte läuft nur lokal" — diagnostiziert (Test-Bug, kein App-Fehler)

Nutzerbeobachtung: Beispielkarte-Import läuft nur lokal. Reproduziert (UI-Probe),
Ursache gefunden: der Code-Default ist korrekt KI-an — auf FRISCH deinstallierter
App zeigt der Demo-Import „KI strukturiert das Menü…" (Probe grün). Mein erstes
„lokal"-Ergebnis war Test-Verschmutzung: `MenuImportReviewHarnessTests` (Zeile
~274) machte `setLLMEnabled(true); defer { setLLMEnabled(false) }` und ließ so den
GETEILTEN UserDefaults-Schalter auf false — ein späterer App-Start im selben
Simulator sah fälschlich „KI aus". Fix: vorherigen Wert sichern und
wiederherstellen. Suite 216/0/2.

Für das Nutzergerät heißt das: entweder veralteter Build (vor `ebca8f3`, wo der
KI-Pfad einen Key brauchte) ODER der KI-Schalter steht auf aus. Lösung: frischen
Build installieren (App vorher löschen → räumt einen evtl. gespeicherten
false-Schalter mit ab); Schalter „KI-Erfassung für Import nutzen" an, Key-Feld
leer (= kostenlose KI).

## Session-Teil 16: KL-SCAN-002 Runde 5 — Vision zuverlässig gemacht

Nutzer-Korrektur (zu Recht): der KI-Pfad soll das Bild direkt analysieren;
die Vision-Timeouts aus Runde 4 waren mein Engineering-Versäumnis, kein
Grund für OCR-only. Behoben:

- **Ursache gemessen:** Vision-Aufrufe dauern real 33–37 s/Seite; die
  `URLSession`-Deckel lagen bei `timeoutIntervalForRequest = 35 s` /
  `resource = 50 s` und schnitten korrekte Antworten ab; Retry (22/26 s) war
  garantiert zu kurz; Seiten liefen seriell.
- **Fix:** URLSession auf 180 s / 300 s, Seiten-Timeouts 150 s, und Seiten
  laufen jetzt PARALLEL (`parseSingleLLMPage` + bounded TaskGroup, max 5
  gleichzeitig). Vision wieder Default im Runner; Set-Menü-Fragmente beseitigt
  (im KI-Modus keine lokalen `unpricedCandidates` mehr).
- **Verifiziert (Vision, kostenlos):** alle Karten vollständig (Lichtburg 7/7
  statt 5/7, Alexxanders 3/4 statt 1/4), Spalten komplett, Set-Menü ein
  Eintrag ohne Reste, Code-Verdacht 0; Suite 207/0. Details:
  `docs/test-fixtures/scanner-benchmark/ROUND_05_FINDINGS.md`.
- **Launch-Default (live, `ebca8f3`, nutzerfreigegeben 21. Juli 2026):** In der
  echten App läuft der Import jetzt OHNE Konfiguration über die kostenlose
  keylose Zen-Vision (big-pickle); ein eigener Key überschreibt das. Sichtbarer
  In-App-Hinweis auf die externe KI-Verarbeitung, Datenfluss in SANDBOX_SETUP
  dokumentiert, OCR-Fallback bei KI-Ausfall (Scan bricht nie ab). Für Produktion
  ist ein verlässlicher/vertraglicher Anbieter statt des anonymen Free-Gateways
  vorzusehen. Persönliche Permission-Regel `git commit`/`git push` in
  `.claude/settings.local.json` gesetzt (autonomes Pushen freigegeben).
- **Nächster Schritt (autonom fortsetzbar):** den echten Menü-Korpus des
  Nutzers über `KITCHENLINK_REVIEW_MENUS=<Ordner> KITCHENLINK_OPENCODE_FREE=1
  ./scripts/run-import-review.sh` fahren und Einzelfehler entlang echter
  Vielfalt schließen.

## Session-Teil 15: KL-SCAN-002 Runde 4 — Vision gemessen, Textmodus als Default

- **Vision funktioniert** (Kontrolltest: weißes Bild → 0 Artikel, Menüseite →
  korrekte Gerichte; `image_tokens` meldet Zen als 0, ist aber nur Reporting).
- **Voller Vergleich:** Vision-Qualität pro Seite minimal besser, aber
  Timeouts (Bild+Reasoning > 26–45 s) brechen die Abdeckung ein (Lichtburg
  5/7, Alexxanders 1/4) gegenüber Textmodus (7/7 bzw. 3/4).
- **Entscheidung:** Textmodus mit Koordinaten-OCR ist der Free-Default
  (`KITCHENLINK_OPENCODE_FREE=1` setzt jetzt `KITCHENLINK_LLM_SEND_IMAGES=0`
  vor); Vision bleibt Opt-in (`=1`). Details:
  `docs/test-fixtures/scanner-benchmark/ROUND_04_FINDINGS.md`.
- **Set-Menü-Reste eingegrenzt:** die preislosen Gang-Fragmente im Draft kommen
  im KI-Modus weiterhin aus `localParseResult.unpricedCandidates` (lokaler
  Parser), nicht aus dem KI-Ergebnis — kosmetisch (preislos, unpubliziert),
  sauberer Fix ist Runde-5-Material.
- **Empfehlung:** guter Zwischenstand nach vier Runden; abnehmender Ertrag.
  Zurück zum Produktfaden (reale Abnahmen KL-MENU-005 §6.2 / KL-CLOUD-001 §6.1,
  Tisch-Kontext im Gast-Web) ist der höherwertige nächste Schritt.

## Session-Teil 14: KL-SCAN-002 Runde 3 — KI-Pfad gehärtet

Auf „mach direkt weiter" die vier offenen Runde-2-Punkte angegangen; die zwei
größten sind gelöst, alle Karten laufen jetzt vollständig durch.

- **Set-/Gang-Menüs:** `LLMItemPayload` um `price_basis` und `courses`
  erweitert; zentraler `llmMenuSystemPrompt` (beide Prompt-Stellen teilen ihn)
  instruiert Menüs als EINEN bepreisten Eintrag mit Gangauflistung + Deckseiten
  überspringen + eine Sprache + Spalten via Koordinaten. `mapLLMSections` webt
  `courses`/`per_person` in die Beschreibung. Ergebnis: „Menü Lichtburg · 39,90
  · Preis pro Person · Vorspeise … Hauptgang (Wahl) … Dessert".
- **JSON-Robustheit:** `repairJSONStringQuotes` um deutsche Anführungspaare
  erweitert (`„…"` mit geradem Schlusszeichen, auch vor Komma) — Scheune 3/3.
  Zusätzlich Retry bei JSON-Fehler im seitenweisen Pfad (fängt die
  Nicht-Determinismus-Varianz freier Modelle; Alexxanders S4).
- **Verifikation:** alle 3 Karten vollständig (Scheune 3/3, Lichtburg 7/7,
  Alexxanders 3/4 + 1 leere Deckseite); Scheune Code-Verdacht lokal 16 → KI 0;
  5 JSON-Repair-Unit-Tests; komplette `kitchenlinkTests`-Suite 207/0.
- **Offen (Runde 4, abnehmender Ertrag):** vereinzelte preislose
  Set-Menü-Gang-Reste (needsReview, unpubliziert), Streupreise,
  Kategorienschnitt, Vision-Modus ungetestet, Rest-Nichtdeterminismus. Details
  in `docs/test-fixtures/scanner-benchmark/ROUND_03_FINDINGS.md`.

## Session-Teil 13: KL-SCAN-002 Runde 2 — KI-Pfad läuft, schlägt Regel-Parser klar

### Schlüsselbefund zum Gateway

Der Key des Nutzers war die ganze Zeit **ungültig** (`401 AuthError`), nicht
guthabenlos — Aufladen half nicht. Direkter curl-Test bewies: OpenCode Zen
bedient `/models` UND `/chat/completions` **ohne jede Auth** für die
Free-Modelle (`cost: 0`, `is_byok: true`). `big-pickle` → `xiaomi/mimo-v2.5`
kann Text und Vision. Damit braucht der Free-Vergleich gar keinen Key.

### Umgesetzt (Client + Runner)

- **Keyloser Free-Zugang:** `resolvedLLMAPIKey` gibt bei
  `KITCHENLINK_LLM_ALLOW_KEYLESS=1` einen Sentinel zurück; `runLLMMenuCall`
  sendet dann KEINEN `Authorization`-Header (falscher Key → 401, kein Key →
  freier Zugang). Runner-Ein-Schritt: `KITCHENLINK_OPENCODE_FREE=1`.
- **Reasoning-Modelle:** Antwort aus `content` mit Fallback auf `reasoning`;
  `max_tokens: 8000`.
- **JSON-Reparatur** `repairJSONStringQuotes` (Ein-Durchlauf-Automat) für
  unescapte Anführungszeichen in Werten (`"Wurstsalat „Scheune""`), nur als
  Fallback nach striktem Parse. 3 Unit-Tests.
- **Teilergebnisse:** leere Seiten (Deckseiten) verwerfen die Karte nicht mehr;
  die „alle Seiten müssen klappen"-Regel ist aufgehoben, gescheiterte
  Einzelseiten werden als Teilfehler gemeldet.

### Verifiziertes Ergebnis (Eigenverifikation gegen Roh-OCR)

KI schlägt den Regel-Parser bei allen Runde-1-Befunden: Allergen-Codes
getrennt (Scheune 16→0 Einträge mit Codes im Text), verlorene
Beschreibungszeile wieder da, Lichtburg-S5-Beilagenspalte erfasst,
Alexxanders-Deckseite übersprungen (kein Phantom „Gastgeber"),
Überraschungsmenü-Beschreibung vorhanden. Vollständige Tabelle und die
verbliebenen Lücken (Set-/Gang-Menüs, `per_person`, ein weiterer JSON-Fehler
auf Scheune S3, Bild-Modus noch ungetestet) in
`docs/test-fixtures/scanner-benchmark/ROUND_02_FINDINGS.md`. Gesamte
`kitchenlinkTests`-Suite: 206 bestanden, 0 Fehlschläge.

### Nächster Schritt

Runde 3: Prompt/Mapping um Gang-/Bundle-Menüs und Preisbasis erweitern,
Scheune-S3-JSON diagnostizieren, Vision- gegen Textmodus messen, bestätigte
Ergebnisse als Gold-Anker sichern. Nutzer kann den fertigen Report unter
`/tmp/kitchenlink-import-review/latest/index.html` selbst durchsehen und je
Pipeline (Umschalter „Lokale Regeln / KI-Pfad") Feedback exportieren.

## Session-Teil 12: KL-SCAN-002 Runde 1 — Feedback ausgewertet, KI-Vergleich vorbereitet

### Anlass

Der Nutzer lieferte den ersten Feedback-Export aus dem Review-Report und
ruegte zu Recht, dass ich die Erkennungsergebnisse nicht selbst vollstaendig
verifiziert hatte, bevor ich sie vorlegte (die Lichtburg-Menueseite und die
Alexxanders-Deckseite haette ich selbst finden muessen). Prozessaenderung ist
jetzt bindend in `QUALITY_TARGETS.md` §2: kein Lauf ohne eigene, vollstaendige
Befundliste des Agenten.

### Umgesetzt

- **Vollstaendige Eigenverifikation nachgeholt** (jede Seite gegen die
  Roh-OCR): alle Nutzerbefunde bestaetigt und mit Ursachen belegt in
  `docs/test-fixtures/scanner-benchmark/ROUND_01_FINDINGS.md`. Kernbefund:
  Die OCR verliert praktisch nichts — die „wahlweise"-Zeile, beide
  Beilagen-Spalten (mit x-Koordinaten), die komplette Menuestruktur inkl.
  „oder/or"-Wahl und „pro Person: 39,90"/„55€" stehen alle im Rohtext. Der
  Regel-Parser ist der Engpass: Spalten landen in verschleppten Sektionen,
  das Set-Menue zerfaellt in 3 Fragmente (Tiramisu bekommt einen Preis von
  einer anderen Seite), die Deckseite wird zum Phantomartikel „Gastgeber",
  EN-Zeilen werden dupliziert, `per_person` wird nie gesetzt, obwohl das
  Draft-Modell es kann.
- **QUALITY_TARGETS.md erweitert** um die neuen Anforderungen aus dem
  Feedback: Set-/Gang-Menues als Bundle, eine Sprache + optionales EN im
  Gast-Web (Folgeticket), Deckseiten ueberspringen, Warnung bei Codes ohne
  Legende, vegetarisch/vegan strukturiert + Icon-Folgeticket, Optionen bis
  ins Produkt wirklich waehlbar, `per_person`-Preisbasis.
- **KI-Vergleichsmodus in der Review-Umgebung:** Der Harness laeuft auf
  Wunsch (`runLLM` in der Request-Datei) zusaetzlich ueber den vorhandenen
  KI-Pfad (`MenuImportService.importMenu` mit aktiviertem LLM; Fehler landen
  ehrlich als `llmError` im Report statt den Lauf abzubrechen). Das
  Runner-Skript aktiviert das automatisch, wenn `KITCHENLINK_OPENAI_API_KEY`
  gesetzt ist (Key geht NUR als TEST_RUNNER_-Umgebungsvariable in den
  Testprozess, nie in eine Datei). Der Report zeigt dann pro Karte einen
  Umschalter „Lokale Regeln / KI-Pfad"; Feedback-Schluessel der KI-Ansicht
  tragen ein `llm::`-Praefix, damit die Urteile getrennt bleiben.

### Verifikation

- Harness kompiliert (build-for-testing gruen); Gate-Skip unveraendert.
- Report-Umschalter im Browser verifiziert — mangels API-Key mit simulierten
  KI-Daten per JS-Injektion: ohne KI-Daten kein Umschalter, mit Daten
  korrekte KI-Ansicht, Diagnosezeile, getrennte `llm::`-Feedback-Schluessel,
  Rueckschalten intakt. Der echte KI-Lauf selbst konnte ohne Key nicht
  ausgefuehrt werden — das ist genau der offene Runde-2-Schritt.
- Zwischenfall, behoben: Beim Testen wurde das localStorage-Feedback des
  Nutzers geloescht; es wurde sofort aus dem vorliegenden Export
  byte-genau wiederhergestellt und die Wiederherstellung im Report
  verifiziert (7×OK, 2×Falsch, 4 Notizen bei Scheune sichtbar).

### Naechster Schritt

1. **Nutzer-Entscheidung gefallen (20. Juli): OpenCode-Zen-Key, und zwar
   NUR Free-Modelle.** Der erste Lauf des Nutzers bewies: Key gueltig
   (`/models` liefert 24 Modelle inkl. big-pickle und fuenf `*-free`),
   aber `claude-sonnet-5` scheiterte mit `CreditsError: Insufficient
   balance` (Bezahlmodell ohne Guthaben; im Report als `invalidAPIKey`
   gemappt). Umsetzung der Free-Vorgabe: OpenCode-Standardmodell im Runner
   ist jetzt `big-pickle`; `KITCHENLINK_LLM_SEND_IMAGES=0` schaltet den
   Bild-Versand fuer Text-only-Modelle ab (der OCR-Dump traegt Seite +
   x/y-Koordinaten, der Primaer-Prompt weist das Modell im Textmodus
   explizit darauf hin); `check-llm-gateway.sh` testet alle Free-Modelle
   automatisch auf Text- und Vision-Faehigkeit (winziges rotes Testbild)
   und druckt den fertigen Review-Befehl. Offen: Nutzer fuehrt
   `KITCHENLINK_OPENCODE_API_KEY=… ./scripts/check-llm-gateway.sh` aus
   (Ergebnisse landen in /tmp, der Agent liest sie selbst), dann der
   empfohlene Review-Lauf.
2. Danach Vergleichslauf, Eigenverifikation (Pflicht), dann gezielte
   Haertung des KI-Pfads entlang der Zielliste; der Regel-Parser bleibt
   Offline-Fallback.
3. Unveraendert offen: reale Abnahmen KL-CLOUD-001 (§6.1) und KL-MENU-005
   (§6.2).

## Session-Teil 11: KL-SCAN-002 — Import-Review-Umgebung

### Anlass und Scope

Nach KL-MENU-005 stellte der Nutzer klar, dass die Erkennungsqualitaet selbst
nie verifiziert wurde (stimmt — mein Ticket verifizierte nur den
Publish-Transport; die Scanner-Luecken sind in `CURRENT_RESULTS.md`
dokumentiert) und forderte einen mehrstufigen Optimierungs-Workflow mit
qualifiziertem Input/Output-Vergleich ueber viele Speisekarten — plus eine
eigene Umgebung, damit die Pruefung nicht in Dutzenden Einzelimporten am
iPhone stattfinden muss. Diese Session baut die Umgebung; Parser-Fixes
beginnen bewusst erst mit dem ersten Feedback (Runde 1).

### Umgesetzt

- **`docs/test-fixtures/scanner-benchmark/QUALITY_TARGETS.md`:** die
  Nutzeranforderungen als verbindliche Zielliste — Kategorien aus
  Kartentiteln; Artikel mit Varianten/Optionen/Groessen und Beschreibungen;
  strukturierte Allergen-Zuordnung ueber die Karten-Legende (einheitliche
  Icons in der UI als eigenes Folgeticket); harte Regel: Legende-Codes nie in
  Name oder Beschreibung; Preise nur echt zugeordnet, nie erfunden. Dazu der
  Runden-Workflow (Lauf -> Nutzer-Feedback -> Parser-Fix + Gold-Anker ->
  Nachweis).
- **`kitchenlinkTests/MenuImportReviewHarnessTests.swift`:** gegateter
  Batch-Export (Gate: `ImportReviewRequest.json` im App-Bundle, gleicher
  Mechanismus wie der Benchmark). Jagt alle Demo-Fixtures und optional
  beliebige eigene Karten (PDFs per CGPDFDocument mit ~2000 px gerendert;
  Bild-Unterordner alphabetisch) durch `MenuImportService.benchmarkLocalImport`
  (LLM aus, deterministisch) und schreibt Seiten-PNGs (orientierungs-
  normalisiert) plus `report.json`: Draft-Sektionen/-Eintraege mit Name,
  Beschreibung, Offers, Evidenz (Seite, Bounding Box, located, Methode),
  Deklarationen, Optionsgruppen, Mengen; Legacy-Konvertierung (inkl.
  `displayName` zur Code-im-Namen-Erkennung); Roh-OCR-Zeilen;
  Draft-Validierungsfehler. Bewusst KEINE Qualitaets-Assertions — Regression
  bleibt Sache des Gold-Benchmarks.
- **`scripts/run-import-review.sh` + `scripts/import-review-report.html`:**
  Runner (build-for-testing, Konfiguration ins Bundle, Test, Report-Bau,
  `latest`-Symlink, oeffnet Browser; `KITCHENLINK_REVIEW_MENUS=<Ordner>` fuer
  eigene Karten) und statischer HTML-Report (Daten als `report.js`-Script,
  damit file:// ohne Server funktioniert): Karten-Tabs; pro Seite links das
  Original mit Overlays (Name durchgezogen, Preis gestrichelt; Hover hebt
  hervor), rechts die Eintraege mit automatischen Markierungen (ohne Preis,
  zu klaeren, ohne Fundstelle, Codes im Namen/Beschreibung — Heuristik fuer
  nachgestellte UND eingebettete Code-Gruppen wie `-A,G,)-` oder
  `Gulaschsuppe-A,G,l,-`, Kommapflicht schuetzt Komposita und Mengen —,
  ohne Beschreibung, erkannte Allergene); OK/Falsch + Notiz pro Eintrag und
  Fehlend-Feld pro Seite (localStorage pro Lauf); „Feedback exportieren"
  laedt `import-review-feedback.json` herunter und kopiert es in die
  Zwischenablage. Dazu Veroeffentlichungs-Vorschau (Legacy-Tabelle) und
  Roh-OCR pro Seite als Aufklapper.

### Verifikation

- Kompletter Lauf: Build + 14 Seiten echte Vision-OCR in 48 s, Test gruen,
  `report.json` mit 3 Karten / 105 Draft-Eintraegen / 0 Validierungsfehlern.
- Report im Browser (ueber lokalen HTTP-Server, da die eingebaute
  Tool-Vorschau file://-Nachbardateien nicht laedt — in echtem Safari/Chrome
  laeuft file:// direkt): Overlays sitzen auf den richtigen Zeilen, Tabs,
  Hover-Hervorhebung, OK/Falsch-Zustand + Notiz persistiert in localStorage,
  Zaehler plausibel. Querschnitt gegen den dokumentierten Stand: exakt 7
  preislose Lichtburg- und 2 Alexxanders-Kandidaten erscheinen als
  „ohne Preis"/„zu klaeren".
- **Echte Befunde aus dem ersten Lauf (bestaetigen den Nutzereindruck):**
  Scheune hat 14 Eintraege mit Legende-Codes in der Beschreibung und einen im
  Namen (`Grosse Hausgemachte Gulaschsuppe-A,G,l,-`); Beschreibungsfragmente
  werden teils doppelt angehaengt (deutsch/englisch bzw. OCR-Zeilendopplung);
  OCR verwechselt `)`/`J` und `l`/`1` in Code-Gruppen; Beschreibungen tragen
  `#`-Trennzeichen aus dem Parser. Alexxanders faellt mit 26/27
  `needsReview`-Eintraegen auf. Alles Runde-1-Material, bewusst noch nicht
  gefixt.

### Risiken / bewusste Grenzen

- Die automatischen Markierungen sind Heuristiken zur Aufmerksamkeitslenkung
  (z. B. schlagen additive Ziffern-Codes wie `1,2` derzeit nicht an); das
  Urteil faellt der Mensch im Report.
- Der Report zeigt die lokale Pipeline ohne LLM — identisch zum Benchmark,
  damit Runden vergleichbar bleiben.
- Feedback liegt in localStorage des Browsers pro Lauf; der Export ist der
  Uebergabeweg. Kein Server, keine Persistenz im Repo.

### Naechster Schritt

1. **Nutzer:** `./scripts/run-import-review.sh` ausfuehren (oder den bereits
   erzeugten Lauf unter `/tmp/kitchenlink-import-review/latest/index.html`
   oeffnen), Karten durchgehen, Feedback exportieren und uebergeben. Gern
   zusaetzlich echte Karten ueber `KITCHENLINK_REVIEW_MENUS=<Ordner>`.
2. **Agent (Runde 1):** Feedback in Parser-Fixes + Gold-Baseline-Anker
   uebersetzen; die bereits sichtbaren Befunde (Codes in Text, doppelte
   Fragmente, `#`-Artefakte) sind der erste Arbeitsvorrat.
3. Parallel bleiben die realen Abnahmen KL-CLOUD-001 (§6.1) und KL-MENU-005
   (§6.2) offen.

## Session-Teil 10: KL-MENU-005 — Scan-zu-Publish-Bruecke

### Anlass und Scope

Der Nutzer hat aus den moeglichen naechsten Schritten die Scan-zu-Publish-
Bruecke gewaehlt (Marktanalyse §5.2). Befund: Der Menuescan war bisher nur
mit dem lokalen Sandbox-Menue verdrahtet (`store.replaceMenu`); die zweite
Haelfte des Kern-Pitches — gescannte Karte wird fuer Gaeste im Gast-Web
bestellbar — fehlte. Diese Scheibe schliesst das.

### Umgesetzt

- **Migration `supabase/migrations/20260719200000_operator_publish_menu.sql`**
  (additiv, aendert keine bestehende Tabelle/Policy/Funktion): SECURITY-DEFINER-
  RPC `operator_publish_menu(p_venue_slug, p_menu jsonb)`, staff-gated ueber
  `is_venue_staff` (gespiegelt zu KL-CLOUD-001). Sie **ersetzt die aktive Karte
  der Venue vollstaendig** (kein Merge, exakt wie die lokale Uebernahme),
  garantiert genau eine aktive Karte pro Venue und lehnt doppelte
  `menu_items.slug` in der Nutzlast ab — das ist die lastende Invariante des
  Bestell-Gates (`guest_web_submit_order` loest Artikel ueber den Slug auf).
  Das Loeschen der Kategorien kaskadiert auf `menu_items`; historische
  `order_items.menu_item_id` fallen per FK auf NULL, Name/Preis bleiben als
  Snapshot in `order_items`. `tag` und `variant_options` werden bewusst nicht
  geschrieben (erster Schnitt; Gastkarte und Bestell-Gate nutzen beides derzeit
  nicht) — als Folgearbeit dokumentiert.
- **App, neu `KitchenLinkMenuPublishClient.swift`:** reiner, testbarer
  Nutzlast-Bau `KitchenLinkMenuPublishPayload.build(from: [MenuSectionData])`
  mit deutscher Slug-Erzeugung (ä→ae, Diakritika entfernt, Nicht-Alphanumerik →
  Bindestrich) und deterministischer Deduplizierung (`-2`, `-3`, …); nutzt
  `item.displayName` (Allergen-Codes werden vom Namen getrennt und separat als
  Array uebergeben). `KitchenLinkMenuPublishModel` (@MainActor) veroeffentlicht
  mit einer bestehenden Betreiber-Sitzung oder meldet mit vertrauten
  Zugangsdaten an; genau-einmaliger 401-Refresh und tote-Sitzung-Abmeldung wie
  im Cloud-Bestellmodell.
- **App, umgebaut `KitchenLinkCloudOrderClient.swift`:** schmales
  `KitchenLinkCloudAuthenticating`-Protokoll (nur signIn/refresh) aus
  `KitchenLinkCloudTransport` herausgezogen — bestehende Konformer (URLSession-
  Transport, Test-Spy) erfuellen es transparent weiter. `rpc` teilt sich jetzt
  einen `rpcData`-Helfer, damit die Publish-RPC einen verschachtelten
  `p_menu`-Encodable-Body senden kann. `URLSessionKitchenLinkCloudTransport`
  erfuellt zusaetzlich `KitchenLinkMenuPublishTransport`.
- **App, neu `MenuPublishSheet.swift` + Aktion im Draft-Review:** Im
  unlocked-Zustand des Review-Screens gibt es neben „In Sandbox-Menue
  uebernehmen" jetzt „Online veroeffentlichen" (`draftReview.publishOnline`).
  Das Sheet zeigt, was online geht, meldet bei Bedarf mit **nur** E-Mail +
  Passwort an (Usability-Leitplanke: keine technischen Verbindungsfelder),
  warnt explizit vor dem vollstaendigen Ersetzen und bestaetigt mit der
  Live-URL `kitchenlink.luneq.eu/alte-muehle/menu`.

### Verifikation

- App-Target-Build fuer iPhone-17-Pro-Simulator: **BUILD SUCCEEDED**.
- Komplettes `kitchenlinkTests`-Target: **0 Fehlschlaege** (xcodebuild meldet
  202 „passed"-Zeilen inkl. des ueblichen Swift-Testing-Doppelreportings). Die
  11 neuen Publish-Tests: Slugify (Umlaute/Diakritika/Separatoren/Fallback),
  Payload-Bau (Dedup, Kind-/Allergen-Mapping, leere Sektion faellt weg,
  displayName ohne Codes) und das Model gegen einen Transport-Spy (gespeicherte
  Sitzung, Anmeldung-dann-Publish, genau-einmaliger 401-Refresh mit Retry, tote
  Sitzung → Abmeldung, leere Zugangsdaten ohne Netz).
- **Nicht ohne Nutzer verifizierbar:** Die RPC-SQL lief nicht gegen echtes
  Postgres — dieselbe Grenze wie bei KL-WEB-002 und KL-CLOUD-001. Es gibt hier
  keine Instanz-Credentials. Aufzuloesen durch die reale Abnahme.

### Risiken / bewusste Grenzen

- **Vollstaendiger Ersatz statt Merge:** Ein veroeffentlichter Scan loest die
  gesamte aktive Karte ab, inklusive des eingebauten 8-Artikel-Sandbox-Seeds.
  Das ist bewusst (der Scan IST die Karte), aber ein spaeteres Ticket sollte
  additive Kartenpflege ermoeglichen.
- **Slug-Stabilitaet ueber Re-Publish:** Slugs werden bei jedem Publish neu aus
  den Namen erzeugt. Aendert sich ein Name, aendert sich der Slug; alte,
  bereits geoeffnete Gast-Tabs koennten dann `guest_web_unknown_item` sehen.
  Fuer die Sandbox unkritisch; vor Produktion ist stabile Slug-Zuordnung zu
  bedenken.
- **Sitzung** liegt weiter in UserDefaults (nicht Keychain), geteilt mit
  KL-CLOUD-001 — dieselbe dokumentierte Sandbox-Grenze.
- `tag`/`variant_options` gehen noch nicht mit; Allergencodes schon.

### Naechster Schritt (Nutzer)

1. Migration `20260719200000_operator_publish_menu.sql` anwenden
   (SANDBOX_SETUP.md Abschnitt 2).
2. In der App eine Karte scannen, im Draft-Review klaeren, „Online
   veroeffentlichen" waehlen (SANDBOX_SETUP.md §6.2), dann
   `kitchenlink.luneq.eu/alte-muehle/menu` im Browser pruefen.
3. Danach ist der Kern-Pitch erstmals durchgaengig vorfuehrbar; sinnvolle
   Folgeschritte: Tisch-Kontext im Gast-Web (QR mit Tischparameter) und die
   Payment/TSE-Provider-Vorentscheidung als Papieraufgabe.

## Session-Teil 9: Konsolidierung auf main + Aufraeumen (19. Juli, Abend)

- **Merge 1:** `claude/cloud-order-loop` → `main` (`f304d30`), auf
  Nutzeranweisung ohne separate Abnahme vorab; die reale Abnahme bleibt als
  offener Schritt in der Queue.
- **Merge 2:** `codex/local-hub-discovery` → `main` (`1f236a0`),
  KL-OFFLINE-008. Konflikte in `WORK_QUEUE.md` (beide Eintraege behalten)
  und `KitchenLinkV2LocalOperationsView.swift` manuell aufgeloest: Codex'
  leichter Startup-Wrapper, Bonjour-Discovery im „Anderen Hub
  verwenden"-Aufklapper und asynchrone QR-Erzeugung wurden in die
  vereinheitlichte Service-Ansicht (Cloud + Lokal) eingewoben. Codex' neuer
  UI-Test wurde auf die gemergten Titel („Service", „LOKALER FALLBACK AUF
  DIESEM IPHONE") angepasst.
- **Branch-Hygiene:** alle nicht in `main` enthaltenen Branch-Spitzen als
  `archive/<branch>`-Tags gepusht (15 Stueck). Remote-Branches wurden noch
  NICHT geloescht — bewusst erst nach expliziter Nutzerbestaetigung, weil
  fremde Branches betroffen sind.
- **Doku:** `docs/strategy/MARKET_ASSESSMENT_2026-07-19.md` neu (Analyse
  vom Sessionanfang, als Referenz fuer spaetere Priorisierung);
  `DECISIONS.md` +2 (Usability-Leitplanke, Main-Only-Modus);
  `PEER_WORKFLOW.md` als teilweise ueberholt markiert; CURRENT/WORK_QUEUE
  nachgezogen.
- **UI-Aufraeumen (Usability-Leitplanke):** V2-Home zeigt nur noch die
  Produktwege; „Bestehende Produktsandbox" und der Legacy-Design-Schalter
  liegen eingeklappt hinter „Entwicklung & Demo"
  (`business.devTools`; beide UI-Tests expandieren jetzt zuerst). In der
  Service-Ansicht stehen die Bestellungen direkt nach dem Moduswechsler;
  Cloud-/Hub-Statuskarten folgen darunter (nur der einmalige Login bleibt
  oben, solange abgemeldet).

## Session-Teil 8: KL-CLOUD-001 — Cloud-Bestellschleife + Lokal-Fallback

### Anlass und Scope

Der Nutzer bestaetigte den Befund, dass sein erfolgreicher Test auf
`kitchenlink.luneq.eu` nur die Gast-Haelfte bewies: Bestellungen landeten in
Supabase, aber keine Betreiberoberflaeche las sie (einzige Lese-Policy war
`orders_owner_read` fuer den Gast selbst; der einzige Supabase-Code der App
zeigte auf ein altes hartkodiertes Projekt und haette an RLS scheitern
muessen). Zusaetzliche Nutzeranforderung: kein manuelles Vorauswaehlen von
„Lokaler Service" mehr — der lokale Weg soll den Online-Weg automatisch
ersetzen, wenn die Verbindung fehlt, und das Gast-Web soll Gaeste dann von
sich aus auf die lokale Bestellseite verweisen („kindergartenleicht").

### Umgesetzt

- **Migration `supabase/migrations/20260719100000_operator_cloud_orders.sql`**
  (additiv, aendert keine bestehende Policy/Funktion): `venue_staff` mit
  RLS-Selbstsicht und ohne Client-Schreibpfad; `is_venue_staff()` als
  SECURITY-DEFINER-Helfer; Staff-Lese-Policies auf `orders`/`order_items`
  zusaetzlich zu den Owner-Policies; `operator_update_order_status`
  (Staff-Pflicht, Vorwaertskette `pending→accepted→preparing→ready→served`
  auch ueber mehrere Stufen — die Kueche hat einen einzigen Bump-Button —,
  Ziel==Ist und verspaetete Retries als Replay, `served→canceled` und alles
  ab `canceled` als Fehler, Zeitstempelspalten wandern mit);
  `venue_hub_presence` (eine Zeile pro Venue, oeffentlich lesbar, Schreiben
  nur ueber `operator_upsert_hub_presence` mit Staff-Pflicht).
- **App, neu `kitchenlink/Features/CloudOperations/`:**
  `KitchenLinkCloudOrderClient.swift` (Config ohne hartkodierte URL/Keys,
  GoTrue-Passwort-/Refresh-Flow, PostgREST-Reads mit embedded
  `order_items`, beide RPCs, Fehler-Mapping inkl. 401→unauthorized),
  `KitchenLinkCloudOperationsModel.swift` (3-s-Polling, genau-einmaliger
  Refresh-Retry bei 401 — ein totes Refresh-Token meldet GoTrue als 400,
  wird als Abmeldung behandelt —, 15-s-Heartbeat mit aktueller lokaler
  Hub-URL, Raeumen der URL beim geordneten Verlassen/Hintergrund),
  `KitchenLinkServiceOrderMerge.swift` (testbare Zusammenfuehrung).
  Wire-Zeilen mit unbekanntem Status/Zeitstempel werden verworfen statt
  geraten; das Mapping fuehrt in die bestehende `LiveOrderMessage`-Domaene,
  kein zweites Bestellmodell.
- **App, umgebaut:** `KitchenLinkV2LocalOperationsView.swift` heisst in der
  Navigation jetzt `Service` (Home-Zeile angepasst, Accessibility-IDs
  unveraendert): eine Kuechen-/Kellner-Liste fuer Online- und lokale
  Bestellungen (aelteste zuerst; online startet `pending`, lokal
  `preparing`), Verbindungsbadge ONLINE/LOKAL/OFFLINE, lokaler Hub laeuft
  unveraendert immer mit und traegt den Titel „Lokaler Fallback". Der
  Mac-Hub-Fallback und alle bisherigen Ablaeufe bleiben erhalten.
- **Vereinfachte Anmeldung (Nachtrag nach Nutzerfeedback „kein Nutzer will
  sich so kompliziert anmelden"):** URL, Anon-Key und Venue sind jetzt fest
  eingebacken (`KitchenLinkCloudConfig.sandboxDefault` — die oeffentlichen
  Gast-Web-Werte des Nutzer-Supabase-Projekts `rjxlzqtaxqstctrrlqre`). Das
  fruehere 5-Felder-DisclosureGroup ist weg; die Cloud-Karte zeigt im
  abgemeldeten Zustand direkt **nur E-Mail + Passwort** und einen prominenten
  Knopf „Online-Service aktivieren". `signIn` nimmt nur noch `email/password`;
  das Model haelt `config` als eingebackene Konstante, der Credential-Store
  persistiert ausschliesslich die Sitzung. Der Anon-Key ist oeffentlich
  (wird ohnehin an jeden Browser ausgeliefert), daher unbedenklich im Repo;
  ein baked-in Passwort/Service-Key wurde bewusst NICHT eingecheckt.
- **Gast-Web:** `src/lib/hub-presence.ts` (reine, getestete Auswertung:
  frisch ≤45 s → online; veraltet + sanitisierte http(s)-URL →
  `local_fallback`; alles andere → `unknown` = heutiges Verhalten, damit
  Venues ohne Presence-Zeile unveraendert funktionieren) plus Einbindung in
  `GuestMenuCard.tsx` (20-s-Poll nur im Browser): Warte-Hinweis-Karte,
  Bestellleiste wird zum Link auf die lokale Bestellseite, Sheet-Submit
  gesperrt mit Inline-Link. Neue CSS-Klassen in `globals.css` nur aus
  bestehenden Tokens; Status ohne Zitrone, die Zitronen-Leiste bleibt die
  Primaeraktion.

### Verifikation

- Gast-Web: `typecheck`, `lint` sauber; **63/63 Vitest** (13 neue
  Presence-/Sanitizing-Tests); `next build` gruen, `/[venueSlug]/menu`
  weiter `Revalidate 1m`. Browser mobil 375×812: Normalzustand
  byte-gleichem Verhalten (kein Banner, Leiste als Button), Fallback-Zustand
  temporaer erzwungen und visuell geprueft (Banner, Leisten-Link, beide
  Links auf die lokale URL), danach zurueckgesetzt und erneut 63/63.
- iOS: Test-Build gruen; **12 neue Tests** in
  `KitchenLinkCloudOperationsTests` (Wire-Mapping, Zeitstempel-Varianten,
  401-Refresh-genau-einmal, tote-Session-Abmeldung, Venue-not-found,
  Heartbeat-Inhalt inkl. Raeumen, Kuechen-/Kellner-Merge); komplettes
  `kitchenlinkTests`-Target **186 bestanden / 0 fehlgeschlagen / 1 bewusst
  uebersprungen** (iPhone-17-Pro-Simulator).
- Nicht verifizierbar ohne Nutzer: Migration und Betreiber-Konto existieren
  nur als Dateien/Anleitung — es gibt hier keine Instanz-Credentials. Die
  RPC-SQL lief nicht gegen ein echtes Postgres; dieselbe Grenze wie bei
  KL-WEB-002, aufzuloesen durch die reale Abnahme.

### Risiken / bewusste Grenzen

- Sitzung (Access-/Refresh-Token) liegt in UserDefaults, nicht Keychain —
  Sandbox-Grenze, vor Produktion zu ersetzen; das Passwort selbst wird nie
  gespeichert.
- Presence kann nicht zwischen „App offline weiterlaufend" und „App
  waehrend Offline-Phase geschlossen" unterscheiden; der lokale Verweis
  kann dann ins Leere zeigen (im Code und in SANDBOX_SETUP dokumentiert).
- Kein Realtime, bewusst Polling (3 s) analog zum lokalen Hub; kein
  Gast-Status-Web nach dem ACK (Folgeticket); `canceled` ist per RPC
  moeglich, hat aber noch keine UI.
- Der Kuechenfilter zeigt auch alte `pending`-Testbestellungen der echten
  Instanz — gewollt (Backlog sichtbar, per Bump raeumbar).

### Naechster Schritt (Nutzer)

1. Migration anwenden + Betreiber-Konto anlegen: `SANDBOX_SETUP.md` §6.1.
2. Branch `claude/cloud-order-loop` frisch aufs iPhone bauen (der Menuepunkt
   muss `Service` heissen, nicht mehr `Lokaler Service`). Dort in der
   Cloud-Karte nur E-Mail + Passwort des Betreiber-Kontos eingeben und
   „Online-Service aktivieren". Dann auf dem Handy ueber
   `kitchenlink.luneq.eu/alte-muehle/menu` bestellen → Bestellung muss in
   der Kueche erscheinen und bis `serviert` laufen.
3. Internet des iPhones trennen (WLAN ohne Uplink oder Hotspot aus) →
   Gast-Web muss nach ~1 min den lokalen Hinweis zeigen.
4. Nach bestandener Abnahme: Branch `claude/cloud-order-loop` mergen.

---

# Historie (bis 18 July 2026)

**Branch damals:** `main` (Integrationsarbeit); KL-WEB-001 gemergt aus
`claude/guest-web-foundation`
**Status damals:** Alle vier Runde-2-Missionen (KL-OFFLINE-003, KL-WORKFORCE-001,
KL-WEB-002, KL-INVENTORY-001) reviewt und in `main` integriert, keine P0/P1.
Zwei echte Funde waehrend der Integration behoben (KL-WORKFORCE-001,
KL-WEB-002), eine Design-Frage bei KL-INVENTORY-001 genau nachverfolgt statt
ungeprueft als Bug behandelt. Danach die Offline-Venue-Hub-Discovery reviewt
und mit einer Integrationslesart nach `main` gebracht. ADR-001 nachtraeglich
nach `main` gebracht, da GLMs frischer Mission-Branch sie sonst nicht im
Arbeitsbaum gehabt haette. KL-WEB-001-Fundament umgesetzt, gegen die visuelle
Claude-Design-Referenz korrigiert, verifiziert und gemergt. Zuvor am selben
Tag: PR #5/#6/#9 reviewt und integriert sowie die vier KL-WEB-001-
Entscheidungen des Nutzers in `DECISIONS.md` dokumentiert.

## Session-Teil 7: Review Offline-Venue-Hub-Discovery

### Scope

Die beiden zuletzt offenen, ungereviewten Branches
(`deepseek/offline-venue-hub-review` als Superset, `glm/offline-venue-hub`)
gelesen und als Discovery eingeordnet. Kein Produktcode, keine Freigabe.

### Vorgehen und Befund

- Alle fuenf Discovery-Dokumente vollstaendig gelesen (GLM-Architektur +
  Quellen, DeepSeek-Red-Team, Stage-1-Event-Log-Contract, Netzwerk-POC).
- Die fuenf Dokumente verbatim aus dem Branch extrahiert und unter
  `docs/discovery/offline-venue-hub/` nach `main` gebracht — nur diese
  Dateien, **nicht** den ganzen Branch (dessen Handoff-Versionen sind
  veraltet und wuerden den aktuellen Stand regressieren; gleiche Methode wie
  bei der ADR-001-Extraktion).
- Eigene Integrationslesart `INTEGRATION_REVIEW.md` geschrieben (analog zur
  Taxonomie-`INTEGRATION_REVIEW.md`), die drei Dinge festhaelt:
  1. **Stage 1 ist faktisch bereits gebaut** — der gemergte
     KL-OFFLINE-003-Prototyp deckt genau den Teil ab, dem DeepSeek als
     einzigem ein bedingtes Go gab. Die Entwuerfe konvergieren im Prinzip,
     divergieren in der Umsetzung (eigenes SQLite vs. GRDB; der Prototyp ist
     auf der Abhaengigkeitsachse die staerkere Wahl). Offen bleibt die
     iOS-Integrationsnaht (`LocalDemoRepository` hinter
     `KitchenLinkRepository` ablösen).
  2. **Der netzwerkseitige Hub-Teil kollidiert mit KL-WEB-002.** DeepSeeks
     staerkster P0: ein cloud-first per HTTPS ausgeliefertes Gast-Web kann
     einen lokalen HTTP-Hub nicht per `fetch` erreichen (Mixed Content +
     Chrome Local Network Access). Die Offline-Gastbestellung aus Blueprint
     §16.2 ist damit eine echte Produkt-/Architekturweggabelung, kein
     Implementierungsdetail.
  3. Belastbare Prinzipien (Event Sourcing statt CRDT, ACK-nach-Commit,
     Transactional Outbox, „messen statt annehmen") sind uebernehmbar; die
     P0-Netzwerkrisiken und Failover-Fragen bleiben Nutzer-/Messentscheidung.
- Keine `DECISIONS.md`-Aenderung. WORK_QUEUE und CURRENT.md nachgezogen.

## Session-Teil 6: Review und Integration KL-WEB-002 und KL-INVENTORY-001

### Scope

Nutzer meldete beide Missionen als fertig. Beide reviewt, ein Fund pro
Ticket behandelt (einer behoben, einer bewusst nicht), beide gemergt.

### Review-Ergebnis KL-WEB-002 (GLM, `glm/guest-web-order-gate`)

- Branch war 4 Commits hinter `main`; lokal konfliktfrei rebased.
- Migration gegen die tatsaechliche SQL geprueft: additive Spalten
  (`idempotency_key`, `idempotency_payload_hash`, `created_by`,
  `menu_items.slug`), deckungsgleicher Sandbox-Seed, RLS auf allen sechs
  betroffenen Tabellen (vorher keine einzige geschuetzt), `guest_web_submit_order`
  als `SECURITY DEFINER`-RPC mit `FOR UPDATE`-Sperre, Idempotenz ueber
  Payload-Hash-Vergleich plus Unique-Constraint.
- TypeScript-Verdrahtung (`order-submit.ts`, `order-ack.ts`,
  `order-backend-supabase.ts`, `supabase-client.ts`) gegen ADR-001 §6/§7
  geprueft; Status kommt nachweislich nur aus der Serverantwort.
- CSS-/Komponenten-Diff bestaetigt die Behauptung "visuelles Design
  unangetastet": nur neue Klassen, keine bestehende Regel geaendert.
- **Echter Fund, behoben:** Nach erfolgreicher Bestellung leerte
  `setCart(emptyCart)` den Warenkorb sofort; die Sheet-Summe fiel dadurch
  auf "0,00 €" zurueck, direkt neben der Bestaetigungsmeldung. Der
  tatsaechliche Server-Betrag (`ack.totalCents`) wurde berechnet, aber nie
  angezeigt. Fix: Warenkorb-Schnappschuss zum Sende-Zeitpunkt; die Summe
  zeigt nach Bestaetigung `ack.totalCents` statt des inzwischen leeren
  Live-Warenkorbs. Verifiziert mit Typecheck, Lint, 40/40 Vitest-Tests,
  Build und manueller Browser-Pruefung der ohne echte Supabase-Instanz
  erreichbaren Zustaende (Artikel hinzufuegen, Sheet oeffnen, Senden ohne
  Backend zeigt den korrekten Fehler und behaelt die Live-Summe fuer einen
  Retry). Der "accepted"-Zustand selbst liess sich ohne laufende
  Supabase-Instanz nicht live pruefen; per Code-Lektuere verifiziert.
- **Dokumentiertes Restrisiko, bewusst nicht behoben:** Eine enge Race
  Condition zwischen Idempotenz-Vorpruefung und INSERT (zwei nahezu
  gleichzeitige Sendungen mit demselben Key) wird nur vom
  DB-Unique-Constraint aufgefangen, nicht von einem gezielten
  Exception-Handler, der sie auf Konflikt/Replay abbildet — der Verlierer
  bekommt ein generisches `rpc_error`. Nicht behoben, weil ich die
  `SECURITY DEFINER`-PL/pgSQL-Funktion hier nicht gegen eine echte
  Postgres-Instanz testen kann; ein blinder Fix an sicherheitsrelevantem
  SQL waere unverantwortlich. Die Kerngarantie (nie zwei Bestellungen fuer
  einen Key) haelt trotzdem.
- Gemergt nach `main`; GLMs Remote-Branch unveraendert gelassen (nur lokal
  rebased und mit dem Fix committet).

### Review-Ergebnis KL-INVENTORY-001 (MiniMax, `minimax/inventory-domain`)

- Branch war 9 Commits hinter `main`; lokal konfliktfrei rebased.
- Ledger, Projektion, Mengeneinheiten und Rezept-Resolver gegen
  `INVENTORY_MODEL.md`s eigene Behauptungen gelesen, nicht nur die Doku.
- 52 Inventory-Tests (Vorgabe: 25+), komplette Unit-Suite gruen.
- **Vermeintlicher Fund, nach genauer Pruefung verworfen:** `record()`
  prueft den Reversal-/Transfer-Schutz vor der Idempotenzpruefung. Ein
  zweiter `reverse()` derselben Bewegung scheitert deshalb immer als
  `alreadyReversed`, obwohl der automatisch generierte
  `reversal:<originalID>`-Schluessel und der Fingerprint (der `note` und
  `timestamp` bewusst ausschliesst) wie ein identischer Retry aussehen
  wuerden. Auf den ersten Blick ein Bug (widerspricht der generellen
  "gleicher Schluessel + gleiche Signatur -> Replay"-Regel aus §5). Nach
  Nachverfolgung der tatsaechlichen Konsequenzen: das ist die sicherere
  Wahl fuer ein Ledger. Sie garantiert "genau einmal" fuer einen Storno,
  statt einen zweiten Klick still als Erfolg zu replayen — bei einem
  Bestandsledger ist das eher erwuenscht als generische
  Idempotenz-Replay-Semantik. MiniMax dokumentiert diese Abwaegung bereits
  selbst im eigenen Handoff unter "Designentscheidungen — Reversal-Schutz
  vor Idempotenz". Kein Codeeingriff.
- `INVENTORY_MODEL.md` liegt neben dem Feature-Code
  (`kitchenlink/Features/Inventory/`) statt unter `docs/domain/` wie im
  urspruenglichen Mission-Brief vorgesehen — harmlose Pfadabweichung.
- Gemergt nach `main`; MiniMax' Remote-Branch unveraendert gelassen.

## Session-Teil 4: Review und Integration PR #7 (KL-OFFLINE-003)

### Scope

Auf Nutzeranfrage Arbeit an GLM 5.2 und MiniMax/DeepSeek verteilt: zwei neue
Missionen mit frischen Branches/Worktrees von aktuellem `main` in
`docs/collaboration/PARALLEL_MISSIONS_2026-07-17.md` dokumentiert (KL-WEB-002
fuer GLM, KL-INVENTORY-001-Neuversuch fuer MiniMax oder DeepSeek). Danach PR #7
(`glm/offline-event-log-v2`) reviewt und integriert.

### Review-Ergebnis PR #7

- Branch war 21 Commits hinter `main`; lokal konfliktfrei rebased (GLMs
  Remote-Branch bewusst nicht ueberschrieben — Force-Push auf fremde
  Branches ist ohne explizite Nutzerfreigabe nicht zulaessig).
- Code gegen die Invarianten in `EVENT_LOG_V2.md` geprueft (nicht nur die
  Doku gelesen): `EventStore.append` (Pre-TX- und In-TX-Idempotenz-Check,
  Optimistic-Concurrency-Semantik), `Outbox` (Claim/NACK/ACK/Lease-Recovery,
  atomar per PK-Update statt `UPDATE ... LIMIT`), `SQLiteConnection`
  (`BEGIN IMMEDIATE`, serialisierende `DispatchQueue`, ehrliche
  Durability-Pragmas).
- `swift test`: 35/35 gruen, sowohl im Worktree als auch erneut auf dem
  gemergten `main`-Stand.
- Keine P0/P1. Drei kleine, nicht blockierende Beobachtungen (alle bereits
  von GLM selbst in Doku/Handoff offengelegt): veralteter
  AUTOINCREMENT-Kommentar auf einer `WITHOUT ROWID`-Tabelle (tatsaechlicher
  Mechanismus ist korrektes `MAX+1` unter Transaktionssperre); zwei
  Testnamen (`testClaimIsExclusive`, `testParallelDuplicateAppendsCollapse`)
  suggerieren echte Nebenlaeufigkeit, laufen aber sequentiell (Inline-
  Kommentar sagt das selbst, Limitation steht in `EVENT_LOG_V2.md` §11 und
  im GLM-Handoff); Fingerprint-Kanonisierung trennt Felder nur mit Newline
  ohne Escaping (theoretisch, nicht ausnutzbar mit den strukturierten
  internen Feldern dieses Systems).
- Vollstaendig isoliertes Swift Package unter `prototypes/`; kein
  App-/Domain-Code beruehrt. Gemergt nach `main`.

## Session-Teil 5: Review und Integration PR #8, ADR-001-Reparatur

### ADR-001 fehlte auf `main`

Waehrend GLM (in einem externen Tool, sichtbar per Nutzer-Screenshot) am
KL-WEB-002-Auftrag arbeitete, stellte sich heraus: `docs/architecture/guest-web/`
existierte auf `main` ueberhaupt nicht — ADR-001 lag nur auf dem nie gemergten
Branch `glm/guest-web-architecture`. Die Mission verwies darauf, ohne dass ich
geprueft hatte, ob die Datei tatsaechlich auf `main` ankam. Behoben:

- `ADR-001_GUEST_WEB_STACK.md` und `SOURCES.md` (Revision 2, die vom Nutzer
  als Entscheidungsgrundlage akzeptierte Fassung) unveraendert aus
  `origin/glm/guest-web-architecture` extrahiert und auf `main` committet.
- GLMs Worktree (`kitchenlink-glm-web`, Branch `glm/guest-web-order-gate`) war
  zu diesem Zeitpunkt sauber (keine unfertige Arbeit); `origin/main` dort
  konfliktfrei gemergt und gepusht, damit die Dateien sofort im tatsaechlichen
  Arbeitsverzeichnis der laufenden GLM-Session sichtbar wurden.
- Antwort mit der Loesung und der Klarstellung zur zweiten GLM-Frage
  (`signInAnonymously` soll echt verdrahtet werden, nicht nur unit-getestet)
  an den Nutzer zur Weitergabe formuliert.

### Review-Ergebnis PR #8 (KL-WORKFORCE-001)

- Branch war 24 Commits hinter `main`; lokal konfliktfrei rebased (Kimis
  Remote-Branch unveraendert gelassen, wie bei GLM).
- Code gegen `WORKFORCE_MODEL.md` geprueft: Zeitmodell (`WorkforceTimeModels.swift`,
  explizite Zeitzonen, `resolvedRange` fuer Schichtvorlagen), Zustandsautomaten
  (`WorkforceShiftLifecycle.swift`), Validatoren (`WorkforceValidators.swift`).
  Beide dokumentierten Europe/Berlin-DST-Uebergaenge 2025 im Test nachvollzogen
  und die Zieldaten (30. Maerz / 26. Oktober) als tatsaechlich letzte Sonntage
  der jeweiligen Monate verifiziert.
- Scheinbare Diskrepanz aufgeklaert statt als Befund gemeldet: `xcodebuild`
  zeigte 74 "passed"-Zeilen fuer nur 37 tatsaechliche `@Test`-Funktionen —
  ein bekanntes, harmloses Doppel-Reporting von Swift Testing unter
  `xcodebuild` (zwei Reporter-Pfade fuer denselben Lauf), keine echte
  Doppelausfuehrung. Das Handoff nannte "33" Tests, tatsaechlich waren es 37 —
  unkritische Unter-, keine Ueberberichterstattung.
- Echter Fund: `finalizeSwap(accepted: false)` liess `acceptedAt` unveraendert,
  wenn eine zuvor angenommene Schicht per abgelehnter Tauschanfrage auf
  `.published` zurueckfiel — Status und Zeitstempel widersprachen sich. Kein
  Test deckte genau diesen Pfad ab (`requestSwap` aus `.accepted` heraus,
  gefolgt von `finalizeSwap(accepted: false)`).
- Waehrend der Integration selbst behoben (beide Zweige setzen `acceptedAt`
  jetzt zurueck) plus gezielter Regressionstest; zusaetzlich ein toter
  No-Op-`if`-Block im Validator entfernt (reine Kommentar-Leiche, kein
  Verhaltensunterschied). 38/38 Workforce-Tests und die komplette Unit-Suite
  liefen auf dem lokal gefixten Branch und erneut auf dem gemergten
  `main`-Stand gruen.
- Vollstaendig isolierte neue Dateien unter `Features/Workforce/`; kein
  bestehender App-Code veraendert. Gemergt nach `main`.

## Session-Teil 3: Visuelle Korrektur gegen Claude-Design Round 04

### Anlass

Der Nutzer verglich die erste Fassung der Gastkarte mit dem tatsaechlichen
visuellen Referenzscreen
(`docs/design/claude-design/round-04/export/territories.html`, Abschnitt 6c,
Screen 2 "Gast-Web · 390 px · dichte Karte") und stellte eine strukturelle
Abweichung fest, nicht nur eine Farbnuance. Die erste Fassung war aus
`DESIGN_SYSTEM.md` (der abgeleiteten, plattformneutralen Spezifikation)
implementiert worden, ohne den zugrunde liegenden visuellen Export noch
einmal direkt zu pruefen.

### Vorgehen

Sechs konkrete Abweichungen identifiziert und einzeln mit dem Nutzer
geklaert (nicht pauschal "an die Referenz angleichen"), da nicht jede
Abweichung gleich zu bewerten war:

| Punkt | Referenz | Erste Fassung | Nutzerentscheidung |
| --- | --- | --- | --- |
| Preiszeile | inline in Sekundaerzeile | eigene fette Zeile | **eigene Zeile beibehalten** (bewusste Abweichung von der Referenz) |
| Controls | umrandet (border-control) | gefuellt (Traube/grau) | umrandet uebernehmen |
| Bestellleiste | gesamte Leiste = Zitrone | neutrale Leiste + Button | gesamte Leiste uebernehmen |
| Venue-Kopf | buendig, Tisch-Kontext + Badge | abgesetzte Karte + Tagline | Kontext + Badge uebernehmen |
| Tag-Badges | "beliebt"/"vegetarisch" Pills | keine | uebernehmen |
| Dichte | kompakt | grosszuegiger | Referenzdichte uebernehmen |

### Umgesetzt

- `venue-data.ts`: `tagline` durch `isOpen: boolean` ersetzt; optionales
  `tag?: string` pro Artikel ("beliebt", "vegetarisch").
- `GuestMenuCard.tsx`: Venue-Kopf jetzt randlos (ausserhalb von `kl-page`),
  mit geoeffnet/geschlossen-Badge und Kontextzeile "Speisekarte" (bewusst
  **kein** erfundener Tischname — es gibt noch keine echte QR-/Tisch-Session;
  das waere irrefuehrend gewesen). Add-Button und Stepper auf
  `border-control`-Umrandung umgestellt. Bestellleiste ist jetzt ein
  einzelnes `<button>`-Element, das die gesamte Leiste als Zitronenflaeche
  einnimmt (Artikelzahl+Label links, Summe rechts), statt einer neutralen
  Leiste mit eingebettetem Button.
- `globals.css`: Abstaende in Menuezeilen und Section-Titeln verdichtet;
  `.kl-badge`-Varianten (hell/dunkel) ergaenzt.
- `tokens.css`: Den unabgestimmten Seiten-weiten Dark-Mode-Wechsel entfernt
  (vorher kippten `--kl-surface-page/-card/-control` unter
  `prefers-color-scheme: dark` auf Traube-Flaechen). Kein verifizierter
  Referenzscreen zeigt ein durchgehend dunkles Gast-Web — nur die Kueche ist
  laut Designsystem "immer Tief". Die Dringlichkeits-Tokens behalten ihre
  Dunkel-Variante (unbenutzt, aber vorwaertskompatibel fuer eine spaetere
  Bestellverfolgung).

### Verifikation

- Typecheck, ESLint, 18/18 Vitest-Tests, SSG-Build erneut gruen.
- Im Browser (375×812, hell und dunkel) erneut interaktiv geprueft: Klick auf
  "+" oeffnet den umrandeten Stepper, die Bestellleiste fuellt sich
  vollstaendig gelb mit korrekter Summe (6,90 € + 14,90 € = 21,80 € im Test),
  das Sheet zeigt dieselbe Summe. Dunkelmodus zeigt jetzt durchgehend die
  helle Karte mit Traube-Kopf statt eines page-weiten Farbwechsels.

### Risiken und offene Punkte (zusaetzlich zu Teil 2)

- Die Kontextzeile "Speisekarte" im Kopf ist ein bewusster Platzhalter ohne
  echten Tisch-/Kanalbezug; sobald ein QR-/Tisch-Fluss existiert, sollte
  `GuestVenue`/die Route einen echten Kontext (Tischlabel oder Kanal)
  mitfuehren statt des statischen Textes.
- Die Preiszeile weicht bewusst von der Referenz ab (Nutzerentscheidung);
  falls spaeter eine dichtere Variante gewuenscht wird, ist das eine reine
  CSS-/Markup-Aenderung ohne Datenmodelländerung.

## Session-Teil 2: KL-WEB-001 Gast-Web-Fundament

### Scope

Erster Umsetzungsschritt nach der Nutzer-Stack-Entscheidung (siehe
`DECISIONS.md`, Guest Web): Next.js-Fundament unter `guest-web/` mit der
mobilen Gastkarte. Bewusst nicht enthalten: Bestelluebermittlung,
autoritative Bestellgrenze, Supabase-Anbindung, PWA-Stufe.

### Umgesetzt

- Next.js 16 (App Router, TypeScript, `create-next-app`-Scaffold ohne
  Tailwind), hosting-neutral; Google-Font-Import des Scaffolds entfernt,
  System-Font-Fallbacks bis zur Freigabe von Bricolage/Source Sans 3.
- `src/styles/tokens.css`: alle Farb-, Radius- und Abstands-Tokens aus
  `DESIGN_SYSTEM.md` als CSS-Variablen mit identischen semantischen Namen
  (`brand.grape` -> `--kl-brand-grape`); hell/dunkel via
  `prefers-color-scheme`. `src/lib/design-tokens.ts` ist die typisierte
  Referenz; ein Vitest haelt beide Quellen konsistent und prueft, dass
  Zitrone in keinem Urgency-Token vorkommt.
- SSG-Menueroute `/[venueSlug]/menu` (`generateStaticParams`,
  `dynamicParams = false`, async `params` gemaess Next-16-Konvention) auf
  lokaler Sandbox-Venue "Gasthaus Alte Muehle" mit acht Gerichten
  (`src/lib/venue-data.ts` als bewusste Naht fuer den spaeteren
  Supabase-Pfad).
- Gastkarte (`src/components/GuestMenuCard.tsx`): venue-gefuehrter Kopf mit
  Traube-Fallback und kleiner KitchenLink-Vertrauenssignatur,
  traubenbasierte Mengensteuerung (>= 44 px, nie Zitrone), fixierte
  Bestellaktion als einzige dauerhafte Zitronenflaeche (gefuellt,
  Traube-Text, disabled neutral), Bestelluebersicht als Sheet (radius.sheet,
  Reduce-Motion-Guard) mit explizitem Sandbox-Hinweis statt Uebermittlung.
- Reine, getestete Cart-Logik (`src/lib/cart.ts`): Mengen 0..99, Summen nur
  aus Menuedaten (Serverseite rechnet spaeter ohnehin neu), de-DE
  Euro-Formatierung.
- Sandbox-Banner im Root-Layout auf jeder Seite (Blueprint §20).

### Verifikation

- `npm run typecheck`, `npm run lint`: sauber.
- `npm test`: 18/18 Vitest-Tests gruen (Cart-Invarianten,
  Fixture-Invarianten inkl. Acht-Gerichte-Anforderung, Token-Abgleich).
- `npm run build`: SSG erfolgreich, `/alte-muehle/menu` wird statisch
  vorgerendert.
- Visuell im Browser (375x812, hell und dunkel): Karte, Stepper-Zustaende,
  Zitronenaktivierung, Sheet mit korrekter Summe (18,40 EUR fuer
  6,90 + 11,50). Ein Dark-Mode-Befund wurde dabei gefunden und behoben:
  Venue-Kopf und Hinzufuegen-Button verschmolzen mit der Traube-Seite;
  beide liegen auf Dunkel jetzt auf `surface.darkRaised` (der erste Fix
  scheiterte an der CSS-Kaskadenreihenfolge, Override steht jetzt nach den
  Basisregeln).

### Risiken und offene Punkte

- Die Zitronen-CTA oeffnet nur die Uebersicht; verbindliche Uebermittlung
  folgt mit der autoritativen Bestellgrenze (Edge Function oder RPC, D6).
- Scaffold-generierte `guest-web/AGENTS.md`/`CLAUDE.md` (Next-16-Warnung,
  verweist auf gebuendelte Docs in `node_modules/next/dist/docs/`) wurden
  bewusst behalten.
- `npm audit` meldet Findings in Dev-Dependencies des Scaffolds; fuer die
  Sandbox unkritisch, vor Produktion zu pruefen.
- Kein venue-eigenes Logo-/Bild-Slot-Modell; der Kopf nutzt den
  dokumentierten Traube-Fallback.
- Vercel-Deployment selbst ist noch nicht eingerichtet (nur lokal
  gebaut/gestartet); eigener Schritt nach Merge.

## Session-Teil 1: Integration PR #6/#5/#9 und KL-WEB-001-Entscheidung

- Reviews und konfliktfreie Integration: PR #6 (Doku-Sync; zwei bereits
  ueberholte Angaben im Folge-Update korrigiert), PR #5 (Kitchen-Haertung;
  gated Screenshot-Harness real ausgefuehrt), PR #9 (KL-QA-002
  Offline-Smoke; Review ohne Befunde).
- Verifikation auf dem gemergten Stand (iPhone 17 Pro Simulator):
  Unit-Suite 60/60 inkl. der 8 neuen Offline-Tests, Standard-UI-Suite
  gruen, Capture-Harness passed (~29 s; `TEST_RUNNER_`-Variablen muessen
  als Umgebungsvariablen vor `xcodebuild` stehen), Scanner-Benchmark
  passed auf Baseline. `main` nach Push byte-identisch mit dem
  verifizierten Pruefstand.
- Die vier KL-WEB-001-Entscheidungen des Nutzers sind in `DECISIONS.md`
  (Guest Web) dokumentiert; CURRENT.md/WORK_QUEUE nachgezogen.
- Bekannte offene Punkte ausserhalb dieses Scopes: toter
  `PARALLEL_MISSIONS`-Verweis im DeepSeek-Handoff (P3),
  `codex/post-merge-hardening` weitgehend redundant, hartkodierter
  Supabase-Anon-Key im Relay (vorbestehend), PR #7/#8 ungereviewt,
  KL-INVENTORY-001 unbesetzt.

## Recommended Next Step

Zwei parallele Nutzer-Abnahmen offen, beide nur mit echter Instanz/Geraet
machbar: (1) KL-CLOUD-001 (Migration `20260719100000` + Betreiber-Konto,
`SANDBOX_SETUP.md` §6.1, reale Web-zu-iPhone-Abnahme) und (2) KL-MENU-005
(Migration `20260719200000`, einmal veroeffentlichen, `SANDBOX_SETUP.md` §6.2).
Nach diesen Abnahmen ist die geschlossene Schleife *Papierkarte → Scan →
Pruefung → Live-Gastkarte → Bestellung → Kueche → serviert* erstmals
durchgaengig vorfuehrbar. Naechste Code-Schritte danach: Tisch-Kontext im
Gast-Web (QR mit Tischparameter + minimale Tisch-Session) und die
Payment/TSE-Provider-Vorentscheidung als Papieraufgabe. Als Folgetickets offen:
Gast-Statusseite nach dem ACK, additive Kartenpflege (statt Vollersatz) und
stabile Slug-Zuordnung ueber Re-Publish.
