# Annotation Guideline — Speisekarten-Ontologie v0.1

**Status:** Discovery-Artefakt, keine freigegebene Entscheidung.
**Gültigkeit:** Zusammen mit `menu_ontology_v0.1.yaml` und `menu_schema_v0.1.json`.

## 1. Grundprinzipien (bindend)

1. **Original vor Normalisierung.** Titel, Schreibweise, Reihenfolge, Hierarchie,
   Rohpreise und Beschreibungen bleiben unverändert erhalten (`rawText`).
2. **Facetten, nicht eine Kategorie.** Jeder Entry/Section bekommt mehrere Achsen
   gleichzeitig; jede Achse erlaubt `unknown`.
3. **Keine Halluzination.** Allergene, Zusatzstoffe, Zutaten, Claims und
   Auswahlregeln werden **nur** übernommen, wenn sie auf der Karte belegt sind.
4. **`unknown` ist gültig.** Ungeklärte Werte werden markiert, nicht geraten.
5. **Evidenz pro Wert.** Jeder normalisierte Wert erhält `rawText`, `sourceId`,
   `directUrl`, `pageOrLocation`, `method`, `confidence`, `reviewStatus`.
6. **Preissemantik trennen.** Absolut (`fixed`/`amountCents`) vs. Delta
   (`delta`/`deltaCents`) vs. `included` vs. `unknown` sind strikt getrennt.

## 2. Annotierungsregeln

### 2.1 Sektionen und Lesereihenfolge
- Erhalte die sichtbare Reihenfolge über `Section.order` (0-basiert).
- Unterabschnitte über `subSections`; mehrseitige Fortsetzungen über
  `continuedFromSectionId`.
- Bei Mehrspaltigkeit: `pageOrLocation` muss Spalte + Zeile oder Bounding-Box
  kodieren, nicht nur eine Zeilennummer.

### 2.2 Achsen-Vergabe
- `consumptionFamily`: anhand dominanter Sachverhaltsklasse der Sektion (Bier =
  drink, Schnitzel = food, Formel = bundle, Pfandposten = fee_deposit, Legende =
  information). Im Zweifel `unknown`.
- `courseRole`: nur, wenn der Titel oder Kontext es klar macht (Vorspeisen →
  appetizer, Hauptgänge → main, Kinderspeisekarte → kids). Sonst `unknown`.
- `productFamily`: nur bei klarem Produktbezug; als Slash-Pfad. Sonst `unknown`.
- `context`: aus expliziten Hinweisen (Tageskarte, Mittagskarte, saisonal,
  „ab 2 Personen"). Nicht aus Datum oder Wetter ableiten.

### 2.3 Preise
- Lese den **Rohpreis** wörtlich ein (`rawPrice`).
- `priceKind`:
  - „24,90 €" → `fixed`, `amountCents=2490`.
  - „ab 9,00 €" → `from`, `minAmountCents=900`.
  - „9,00–12,00 €" → `range`.
  - „Marktpreis"/„Tagespreis" → `market`, `amountCents=null`.
  - „auf Anfrage" → `on_request`.
  - „inklusive"/„im Preis enthalten" → `included`.
  - „+2,50 €"/„Aufschlag" → `delta`, `deltaCents=250`, **niemals** `amountCents`.
  - „0,00 €"/„gratis" → `free`.
  - Artikel ohne Basispreis, Preis nur an Größe → `unknown` am Entry-Offer.
- `basis`: `per_item|per_person|per_piece|per_weight|per_volume|per_unit|unknown`.
- Pfand/Verpackung/Zuschlag in eigene Strukturen (`Offer.deposit`,
  `Offer.packagingFee`, `Offer.surcharge`), nicht in `amountCents` mischen.

### 2.4 Optionen
- Definiere `OptionGroup` nur, wenn die Karte echte Auswahlregeln zeigt.
- `selectionRule`:
  - „1 inklusive" → `freeSelectionCount=1`.
  - „Pflichtauswahl" → `required=required`, `min=1`.
  - „bis zu 3" → `max=3`.
  - Einzelauswahl (Größe) → `cardinality=single`.
- `Choice.offer.priceKind` analog zu Preise: inklusive Option → `included`,
  Aufpreis → `delta`.

### 2.5 Deklarationen
- Allergene: `localCode` wörtlich (z. B. „1,7"). `canonicalId` **nur**, wenn eine
  Legende die Zuordnung explizit macht. Sonst `null`. `claim` aus Text oder Legende
  (`contains`, `may_contain`, `traces`, `free_from`); unsicher → `unknown`.
- `scope` ausdrücklich setzen (global/page/section/entry/option). Widersprüche
  werden nicht aufgelöst, sondern beide Scope-Pfade annotiert.
- Dietary-Claims (vegan, vegetarisch, glutenfrei, „fait maison") nur, wenn
  ausdrücklich auf der Karte.

### 2.6 choiceKind-Abgrenzung (bei Überlapp)

| choiceKind | wann verwenden | Beispiel | nicht verwenden wenn |
|---|---|---|---|
| addon | Separater, zusätzlicher Bestandteil gegen Aufpreis | "Trüffel +5€" | Es ist ein Austausch (→ substitute) |
| upgrade | Höherwertige Version eines Standards | "Rind statt Hähnchen +3€" | Es ist ein separater Extra (→ addon) |
| extra | Zusätzliche Menge eines enthaltenen Bestandteils | "Extra Käse +1,50€" | Es ersetzt etwas (→ substitute) |
| substitute | Austausch eines Standardbestandteils | "Statt Pommes: Salat" | Es kommt dazu (→ addon) |
| remove | Weglassen ohne Ersatz | "Ohne Zwiebeln" | Immer priceKind=included oder free, nie delta>0 |

### 2.7 Facet Inheritance

- Entry-Facet-Werte überschreiben Section-Facet-Werte nur bei **explizitem Beleg** im Entry.
- Fehlt der Beleg für einen Entry-Facet → `null` (ererbt von Section).
- Abweichung von der Section muss in `evidence` begründet sein.
- **Kindermenü-Kopplung (F-06):** Wenn `courseRole=kids` gesetzt wird, MUSS
  gleichzeitig `context.audience=kids` gesetzt werden. Umgekehrt ist
  `context.audience=kids` ohne `courseRole=kids` gültig (z. B. ein
  mitbestellbarer Kinderteller in der Hauptgang-Sektion). Beide Werte zusammen
  kennzeichnen eine echte Kinder-Sektion/einen Kinder-Artikel.

### 2.8 Repeated Placements

- Ein wiederholt platzierter Artikel bekommt in allen Vorkommen die **gleiche** `entryId`.
- `repeatedPlacement=true` setzen; Einträge nicht deduplizieren.

## 3. Grenzfälle / Konfliktlösung

- **Widersprüchliche Legenden:** zwei `Legend`-Einträge mit unterschiedlichen
  Scope; nicht verschmelzen.
- **Doppelt platzierte Artikel:** `repeatedPlacement=true`, nicht dedupen.
- **Preis fehlt komplett:** `offers=[]` ist gültig; `entryKind` trotzdem setzen.
- **Unklare Sprache:** `lang` bestmöglich aus Text; `unknown` als BCP-47 nicht
  erlaubt → dann `lang="und"` (undetermined).
- **Ketten-/Template-Duplikate:** `duplicateCluster`-ID vergeben, in
  Häufigkeitsaussagen nur einen Vertreter zählen.

## 4. Inter-Annotator-Vorgehen

1. Zwei Annotatoren bearbeiten dieselben Golden Cases unabhängig.
2. Vergleich auf Achsen-Ebene; Diskrepanz = Fehlerklasse (siehe
   `benchmark_plan.md`).
3. Reliabilität: Cohen's Kappa pro Achse; Akzeptanzschwelle ≥ 0,7.
4. Konfliktlösung durch dritte Person; Ergebnis fließt in Guideline v0.2.

## 5. Golden Cases (≥30)

Jeder Fall listet die erwartete Achsenausprägung und die Fehlerklasse, die er
prüft. `src` verweist auf `source_registry.csv`.

> **⚠️ 8 von 35 Fällen sind "synth" (synthetisch, ohne reale Quellen).**
> Synth-Fälle decken theoretische Fehlerklassen ab, aber keine realen OCR-/Layout-Fehler.
> **Vor Ontologie v0.2 müssen synth-Fälle durch echte Karten ersetzt werden.**
> `src=theoretical` = nur für Schema-Test, nicht als Evidenzquelle zulässig.

| # | Beschreibung (Kurz) | Quelle | Erwartete Ausprägung | Geprüfte Fehlerklasse |
|---|---|---|---|---|
| GC01 | Bier 0,25L=3,10€ / 0,5L=5,90€ | MENU_augustinerkeller_biergarten | zwei Offer priceKind=fixed appliesToQuantity | mehrfach-preis-pro-menge |
| GC02 | Maß Edelstoff 1,0L=9,00€ | MENU_augustinerkeller_biergarten | Quantity 1L, fixed 900 | einheitsmenge |
| GC03 | Allergencode „1,2,3,7,8" mit Legende 1–14 | MENU_intercontinental_berlin | localCode raw, canonicalId via Legende, scope=entry | code-mapping |
| GC04 | DE/EN bilingualer Artikel | MENU_intercontinental_berlin | zwei LocalizableText, isTranslation | mehrsprachigkeit |
| GC05 | Formule entrée+plat | MENU_bistrot_generations | entryKind=bundle, courseRole=tasting/main | bundle-struktur |
| GC06 | 6-Gang Prix fixe $175 + Wein $75 | MENU_chezfrancois_prixfixe | bundle+tasting, Wein als separates Offer | tasting+pairing |
| GC07 | Fleisch inkl. / Garnelen +5€ | theoretical (Toast-Daten) | single group, freeSelectionCount=1, ein included/ein delta | delta-vs-included |
| GC08 | 1 Beilage inkl., jede weitere +2,50€ | theoretical | multiple, freeSelectionCount=1, delta | freeSelectionCount+delta |
| GC09 | 2½ belegte Brötchen 4,70€ | MENU_cafe_carree | Quantity count=2.5, fixed | fractional-count |
| GC10 | „taxes et service compris" | MENU_cafedelapaix | fixed + surcharge reason context | inkludierte-zuschlaege |
| GC11 | Glutenfreie Pasta-Substitution | MENU_milano_restaurant | dietaryClaim gf + substitute unknown | dietary+substitute |
| GC12 | Preisaufschlag Café-Verzehr | MENU_baecker_frank | surcharge reason=dine_in | bedingter-aufschlag |
| GC13 | Marktpreis/Tagespreis | MENU_chezfrancois_prixfixe (saisonal) | priceKind=market | fehlender-absolutpreis |
| GC14 | „auf Anfrage" | theoretical | priceKind=on_request | on-request |
| GC15 | Einweg-Pfand 0,25€ | LAW_verpackg_31 | deposit single_use 25 | pfand |
| GC16 | Mehrweg-Pfand 0,15€ / Bier 0,08€ | LAW_verpackg_31 | deposit reusable | pfand-mehrweg |
| GC17 | Pre-Modifier EXTRA | STD_toast_premodifiers | preModifier=extra | premodifier |
| GC18 | ModifierGroup SINGLE, min=1 | STD_toast_modifiergroup | selectionRule required/single/min=1 | required-single |
| GC19 | US Big-8 vs EU-14 „Lupin" | STD_google_foodmenus vs LAW_eu_1169_2011 | canonicalId null wenn kein Mapping | allergen-konflikt |
| GC20 | Schema.org menuAddOn ohne Min/Max | STD_schema_menuitem | motiviert OptionGroup | standard-luecke |
| GC21 | Tageskarte/Mittagskarte | MENU_db_bordgastronomie | context.timeOfDay=lunch | context-zeit |
| GC22 | Kindermenü (Schnitzel) | SEC_vz_kinderspeisekarten | courseRole=kids, audience=kids | kids-achse |
| GC23 | Grundpreis je Liter (PAngV) | LAW_de_pangv_2022 | Offer.grundpreis.amountCents, .basis=per_volume | grundpreis |
| GC24 | Sektion über zwei Seiten | MENU_intercontinental_berlin | continuedFromSectionId | seitenfortsetzung |
| GC25 | Pizza nur mit Preis an Größe | MENU_milano_restaurant | Entry offer unknown, Choice offer fixed | preis-nur-an-variante |
| GC26 | „fait maison" Claim | MENU_cafedelapaix | dietaryClaim/warning explicit | claim-nicht-ableiten |
| GC27 | SIZE_PRICE vs SEQUENCE_PRICE | STD_toast_modifiergroup | priceKind fixed vs delta | pricing-strategy |
| GC28 | Wein 16cl/37cl/75cl | MENU_vikingline_wine | drei Quantity+Offer | volumen-abstufung |
| GC29 | Riesling Pfad | MENU_geranium_wine | productFamily drink/wine/white/riesling | produktbaum |
| GC30 | Sharing-Platte ab 2 Pers. | theoretical | context.minPersons=2, audience=sharing | minpersons |
| GC31 | Mehrspaltiges Layout | MENU_intercontinental_berlin | pageOrLocation mit Spalte | spalten-ordnung |
| GC32 | Unbekannter Allergencode | theoretical | canonicalId null, scope conflict | unknown-pflicht |
| GC33 | Artikel ohne Preis gesamt | theoretical | offers=[] | fehlender-preis-gueltig |
| GC34 | Espresso „0,00 € / gratis Kasse" | theoretical | priceKind=free | free |
| GC35 | Widersprüchliche Legenden | theoretical | zwei Legend-Einträge | konflikt-erhalten |
