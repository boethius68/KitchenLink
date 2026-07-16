# Research Report — Evidenzbasierte Speisekarten-Ontologie (KL-MENU-001)

**Status:** Discovery-Ergebnis (GLM-Lauf inkl. DeepSeek-Gegencheck + Patches +
Stichprobenerweiterung F03b–F03e). Ontologie/Schema **v0.2.0**. Keine
freigegebene Produktentscheidung.
**Autor:** GLM-5.2 Forschungslauf (ZCode), 2026-07-16
**Auftrag:** `docs/discovery/MENU_TAXONOMY_RESEARCH_TICKET.md`

> **Ehrlichkeitsvorbehalt (wie vom Ticket verlangt):** Die in diesem Bericht
> genannten Zahlen sind **tatsächlich erreichte**, nicht die vom Ticket
> angestrebten. Das Ticket fordert ≥200 Kandidaten und 100–150 tief analysierte
> Karten. Dieser Lauf erreichte **59 Quellen** (Standards, Gesetz, Forschung,
> reale Karten, Sekundärquellen, Beobachtungen), davon **20 direkt geöffnet**,
> **12 reale Speisekarten tief analysiert** mit abgeleiteten Strukturbeobachtungen.
> Die Vollerhebung auf 100–150 Karten wurde bewusst *nicht* vorgetäuscht; die
> Sättigung wurde mit 12 tiefen Karten geprüft und ist **nicht erreicht**.
> Details in `saturation_test.md`.

## 0. Durchlaufene Phasen

- **F01–F02** Standards/POS/Recht (Schema.org, Google FoodMenus, Toast, EU 1169/2011,
  PAngV, VerpackG, UrhG, RFC9309, BMEL/LMIV).
- **F03a–F03e** Stichprobenausbau: DACH-Biergarten/Fine-Dining/Café/Bäckerei →
  Poké/Bubble-Tea (Option-Dependencies) → IT- & ES-Primärkarten → Kantine/Catering/QR →
  Steakhouses (Gewichtspreise) + Griechisch (Bilingualität).
- **Red-Team** DeepSeek-V4-Pro `audit_report.md` (16 Findings, 6 Patches).
- **Patch-Umsetzung** → Ontologie/Schema **v0.2.0**.
- **QC** Schema als Draft 2020-12 validiert; if/then-Constraints gegen 3 Beispiele
  + 7 Negativtests bestätigt.

## 1. Methode

1. **Quellenpriorität** wie vom Ticket vorgegeben: Gesetz/Behörden → offene
   Standards/POS-APIs → offizielle Restaurant-PDFs → Forschung/Datasets →
   Sekundärquellen nur zur Entdeckung.
2. **Direkt geöffnet** wurden offizielle Dokumente über WebFetch (nicht über
   Such-Snippets). Suchergebnisse dienten ausschließlich der Quellenentdeckung.
3. **Evidenzbindung:** Jede Modellierungsempfehlung ist mit mindestens einer
   `pattern_evidence.csv`-Zeile und einer `source_registry.csv`-Quelle verknüpft.
4. **Beobachtung vs. Interpretation vs. Empfehlung** werden im Bericht und in der
   Ontologie getrennt ausgewiesen.
5. **Keine Nutzer-Uploads oder privaten Karten** wurden verwendet; nur öffentlich
   rechtmäßig zugängliche Quellen.

## 2. Quellenklassen und erreichte Stichprobe

| Klasse | Erreichte Anzahl | Geöffnet (deep) |
|---|---|---|---|
| Offene Standards / APIs | 6 | 4 |
| Gesetz / Behörden (EU, DE, IETF, BMEL) | 7 | 3 |
| Forschung / Datasets | 3 | 0 (nur Metadaten) |
| Reale Speisekarten (Kandidaten) | 27 | 9 (3 mit Strukturbeobachtungen) |
| Sekundärquellen (Entdeckung) | 13 | 2 |
| Format-/Standard-Beobachtungen | 1 | 0 |
| **Summe Quellen** | **59** | **18** |

Länder abgedeckt: **DE, FR, DK, FI, US, ES, IT, INT**.
Sprachen: **de, en, fr, sv, it, es**.
Formate: **text_pdf, html, (image_pdf, photo, qr_menu noch nicht tief abgedeckt)**.
Venue-Typen: **restaurant, biergarten, fine_dining, cafe, bakery, bar, canteen,
catering, study/standard**. *Lieferservice, Catering und saisonale temporäre Karten
weiterhin untervertreten; Bild-PDF/Foto/OCR-Tiefenanalyse = 0.*

### Bekannte Lücken (ungesättigte Achsen, für Fortsetzung F03/F04)

- Foto/Scan und bildbasiertes PDF als Tiefenanalyse nahezu nicht abgedeckt.
- Italienische Originalkarten (IT-Quellen) nur über US-Spiegel; italienische
  Primärquellen fehlen noch.
- Gewichtsbasierte Preisgebung (Steak per 100 g) nur schwach belegt.
- Ketten-/Template-Duplikate wurden nicht quantitativ geclustert (kein
  perceptual-hash/minhash-Lauf durchgeführt).
- Option-Abhängigkeiten über das Toast-Modell hinaus (Bubble-Tea, Poké-Bowl) nicht
  beobachtet.

## 3. Befunde pro Achse

### 3.1 consumptionFamily (Speise/Getränk/Bundle/Retail/Gebühr/Hinweis)
- **Beobachtung:** Toast katalogisiert Lebensmittel/Getränke/Retail getrennt;
  DACH-Karten führen Getränke- und Speisensektion sowie Pfand-/Gebührenposten
  separat. Google FoodMenus hat `FoodMenuItem`/`FoodMenuSection`.
- **Interpretation:** Eine binäre `food|drink`-Achse (wie im bisherigen
  `MenuItemKind`) verliert Bundles, Pfand, Gebühren und reine Hinweise.
- **Empfehlung:** Geschlossene Enum mit `food|drink|bundle|retail|fee_deposit|
  information|unknown` (Ontologie-Achse 1). Siehe `PE-005`, `PE-014`.

### 3.2 courseRole (Gang-/Funktionsrolle)
- **Beobachtung:** Itali. antipasto/primo/secondo/contorno, frz.
  entrée/plat/dessert, dt. Vorspeise/Hauptgang/Beilage. Verbraucherzentrale-Studie
  quantifiziert Kindermenüs (63/100 Schnitzel, 46/100 Pasta).
- **Interpretation:** Vokabular ist kulissenspezifisch; eine geschlossene Enum
  wäre kulturell verzerrt.
- **Empfehlung:** Offene, registrierte Werteliste mit `unknown`; `kids` als
  eigene Rolle plus `context.audience=kids`. Siehe `PE-020`.

### 3.3 productFamily (offener Baum)
- **Beobachtung:** FoodOn vermeidet bewusst `is-a`-Subklassen zwischen
  Lebensmittelprodukten und Kategorisierungshierarchien (foodon.org Relations).
- **Interpretation:** Eine geschlossene Produkt-Enum würde Pflege und Bias erzwingen.
- **Empfehlung:** Slash-Pfad-Baum (z. B. `drink/wine/white/riesling`), nie
  geschlossen, mit `unknown`. Siehe `PE-027`.

### 3.4 context (Zeit/Tag/Saison/Kanal/Audience)
- **Beobachtung:** Tages-/Wochenkarten, Mittagskarten, saisonale Angebote,
  Sharing-Platten (min. 2 Personen), Lieferservice-Preise.
- **Empfehlung:** Eigene Achse mit `timeOfDay/dayOfWeek/season/channel/audience/
  location/minPersons`. `channel` als geschlossene Sub-Enum. Siehe `PE-019`, `PE-028`.

### 3.5 entryKind
- **Beobachtung:** Einfache Artikel, konfigurierbare Artikel (Größe/Toppings),
  Bundles/Set Menüs, reine Hinweise, Pfandposten.
- **Empfehlung:** `simple_item|configurable_item|bundle|notice|fee_deposit|unknown`.

### 3.6 priceKind (STRIKTE Trennung absolut vs. Delta)
- **Beobachtung:** Toast kennt `pricingStrategy` (`SIZE_PRICE`/`SEQUENCE_PRICE`),
  `defaultOptionsChargePrice`, Substitutionspreise. PAngV 2022 verlangt Grundpreis
  je Mengeneinheit. Feinschiffe zeigen Marktpreis/„auf Anfrage".
- **Interpretation:** Ein einziges Preisfeld vermischt absoluten Variantenpreis und
  Aufschlag – die zentrale Schwäche des bisherigen `priceCents`.
- **Empfehlung:** `priceKind`-Enum `fixed|from|range|market|on_request|included|
  free|delta|per_unit|unknown`. Ein `delta`-Offer **darf kein** `amountCents`
  tragen, sondern `deltaCents`. Artikel ohne sichtbaren Basispreis bekommen
  `priceKind=unknown` (Preis nur an Größe/Choice). Siehe `PE-001`, `PE-007`,
  `PE-008`, `PE-021`, `PE-023`, `PE-025`.

### 3.7 choiceKind / preModifier / selectionRule
- **Beobachtung:** Toast dokumentiert `choiceKind`, Pre-Modifiers
  (`NO/SUB/ADD/EXTRA/ON SIDE`) und Modifiergruppen mit `selectionType`,
  `min/max`, `requiredMode`, `instanceCount`. Schema.org kennt demgegenüber nur
  `menuAddOn` ohne Auswahlregeln.
- **Empfehlung:** Drei separate Achsen: `choiceKind` (size/side/sauce/...),
  `preModifier` (add/no/sub/extra/on_side), `selectionRule` (required/cardinality/
  min/max/freeSelectionCount/defaultOptionIds/repeatable). Siehe `PE-015`, `PE-016`,
  `PE-018`.

### 3.8 declarations (Allergene/Additive/Zutaten/Claims/Warnungen)
- **Beobachtung:** EU 1169/2011 Annex II listet **14** Allergene (inkl. Sellerie,
  Senf, Sesam, Lupin, Weichtiere, Schwefeldioxid/Sulfite >10 mg/kg). Google
  FoodMenus nutzt US **Big-8** (DAIRY/EGG/FISH/PEANUT/SHELLFISH/SOY/TREE_NUT/WHEAT).
  Karten verwenden oft nummerierte **lokale Legenden** (z. B. InterContinental:
  1–14) mit **globaler** Geltung.
- **Interpretation:** Allergen-Sets sind **konfliktär**; eine automatische
  Zuordnung lokaler Codes zu kanonischen IDs wäre fehlerhaft.
- **Empfehlung:** Fünf getrennte Deklarations-Achsen; `localCode` bleibt roh,
  `canonicalId` **nur** bei expliziter Legendenzuordnung, sonst `null`; Konflikte
  werden erhalten; `claim` (`contains|may_contain|traces|free_from|unknown`) und
  `scope` werden getrennt. **Nie Ableitung aus Weltwissen.** Siehe `PE-003`,
  `PE-011`, `PE-017`, `PE-024`, `PE-030`.

## 4. Gegenbeispiele und Konflikte

- **Schema.org reicht nicht:** `menuAddOn` hat keine Pflicht/Min/Max-Semantik
  (`PE-018`). Gegenbeispiel: Beilagenauswahl „1 inklusive, jede weitere +2,50 €"
  lässt sich in Schema.org nicht ausdrücken.
- **Allergen-Konflikt:** EU-14 vs. US Big-8 (`PE-017`). „Lupin" existiert in US
  Big-8 nicht; would-be-falsch als „unknown" oder „soy" geraten.
- **Preissemantik-Konflikt:** Ein „+ 5,00 €" bei Garnelenwahl ist ein **Delta**,
  kein absoluter Preis. Das bisherige `priceCents` kann das nicht trennen
  (`PE-007`).
- **Artikel ohne Basispreis:** Bei größenbasierter Pizza steht der Preis oft nur
  an der Größe, nicht am Artikel. Bisherige Pipeline verwirft solche Artikel
  (`PE-023`).
- **Legenden-Geltung:** Globale Allergenlegende vs. eintragsbezogene Codes können
  widersprüchlich sein; muss erhalten bleiben (`PE-030`).

## 5. Rechte-/Zugriffsgrenzen

- Alle `rights_status`-Werte in `source_registry.csv` sind `research_only`
  (Karten) bzw. `research_only`/offiziell (Standards/Gesetz). Keine Quelle als
  `reusable` ohne Lizenznachweis klassifiziert.
- Keine Paywall/Anmeldung/Captcha/robots-Sperre umgangen. `robots_status=allowed`
  nur, wo eindeutig feststellbar; sonst `unknown`.
- Für einen späteren Benchmark sind nur Quellen mit dokumentierter Lizenz oder
  intern bereitgestellte Testkarten zulässig (siehe `benchmark_plan.md`).
- UrhG §44b und RFC 9309 (robots) wurden als Rechtsrahmen aufgenommen, keine
  Rechtsberatung.

## 6. Zehn wichtigste Modellierungsentscheidungen (mit Evidenz)

1. **Mehrere Achsen statt flacher Kategorie** — Ticket-Vorgabe, bestätigt durch
   Schema.org-Lücke (`PE-018`) und Toast-Multi-Facet-Modell.
2. **`priceKind` trennt absolut/delta/included/unknown** — Toast `pricingStrategy`
   (`PE-025`) und PAngV (`PE-021`); im Schema v0.2.0 als if/then-Constraints
   *erzwungen* (F-03 Patch).
3. **`selectionRule` mit freeSelectionCount** — „1 inklusive"-Muster (`PE-008`)
   und Toast `ModifierGroup` (`PE-016`).
4. **`bundle`/`configurable_item` als eigene entryKinds** — Formules/Prix fixe
   (`PE-005`, `PE-006`), Person-scoped-Bundles (`PE-050`, `PE-055`).
5. **Allergene: `localCode` vs `canonicalId` nur bei Explizitheit** — EU-14 vs
   US Big-8 Konflikt (`PE-017`), InterContinental-Legende (`PE-003`), gemischte
   32er-Legende (`PE-049`) bestätigt die Trennung erzwingend.
6. **Deklarationen werden nie aus Weltwissen abgeleitet** — EU 1169/2011
   erfordert explizite Angabe; Google trennt Felder (`PE-024`); LMIV verlangt
   Option-Level-Deklaration bei Imitationen (`PE-052`).
7. **`productFamily` als offener Baum** — FoodOn-Designphilosophie (`PE-027`).
8. **Mengen mehrfach pro Artikel, Preise attachen auf Quantity** — Biergrößen
   (`PE-001`), Wein-Cl (`PE-026`), Steakgewichte (`PE-046/047`).
9. **EvidenzRef für jeden normalisierten Wert** — Ticket-Vorgabe; konsequent im
   JSON-Schema verankert.
10. **`unknown` als gültiges Ergebnis auf jeder Achse** — Ticket-Vorgabe; in
    Ontologie `unknownStrategy` verankert; `rights_status` bewusst ohne
    `unknown` (ungewiss → `unclear`) als Sicherheitsmaßnahme.

## 7. Zehn größte verbleibende Risiken / ungesättigte Bereiche

(Stand nach F03e; einige ehemalige Risiken sind inzwischen geschlossen und
durch neue, tieferliegende ersetzt.)

1. **Tiefen-Stichprobe 12/100–150** → Ontologie bleibt eine Hypothese, obwohl
   als `evidenceLevel: low` sauber deklariert (F-01 standing).
2. **Bild-PDF/Foto/OCR-Tiefenanalyse = 0** → systematische Suche (9 Kandidaten
   via curl+`pdftotext`) zeigte: öffentliche PDFs haben stets Textebenen.
   OCR-spezifische Muster (Spalten, Legendenposition, Trennzeichen) unbeobachtet.
   Nur über interne Testfotos schließbar (Ticket Zeile 138).
3. **Sättigungstest mit 12/20 Karten** → nicht voll aussagekräftig; jede Karte
   brachte noch neue Muster (siehe `saturation_test.md`).
4. **Duplikat-/Template-Cluster nicht quantitativ gemessen** (kein perceptual-
   hash/MinHash-Lauf). Ketten-Bias zwar erkannt (PE-CE-05), aber nicht gemessen.
5. **Nested/dependent OptionGroups im Schema nicht formalisierbar** — Evidenz
   liegt vor (Poké PE-031/032, Bubble-Tea PE-033/034, Modifier-Sub-Choice
   PE-051), aber v0.2 kennt nur flache OptionGroups → künftiges v0.3-Thema.
6. **Option-Level-Allergene am Choice** — juristisch legitimiert (LMIV, PE-052),
   aber noch ohne direkte Kartenbeobachtung.
7. **Mehrsprachigkeit mit Preisunterschied pro Sprache** — Inline-Bilingualität
   belegt (PE-053), aber DE-Preis ≠ EN-Preis (Touristenaufschlag) unbeobachtet.
8. **Inline-Bilingualität (zwei Sprachen in *einer* Name-Zeile, PE-053)** —
   das LocalizableText-Modell geht von einer Sprache pro value aus; Randfall
   braucht explizite Behandlungsregel in v0.3.
9. **Forschungs-Datasets nur metadaten-tief geprüft** (M6Doc, FoodKG, FoodOn);
   keine inhaltliche Validierung gegen die Ontologie.
10. **Inter-Annotator-Reliabilität nicht gemessen** — Guideline + 35 Golden
    Cases vorhanden, aber kein Zwei-Annotator-Kappa-Lauf.

## 8. Nächste manuelle Datensammlung (Vorschlag)

1. **Interne Testfotos** (Ticket Zeile 138) beschaffen, um die OCR-Lücke (Risiko 2)
   zu schließen – der produktionsrelevante Eingangskanal laut Blueprint §4.1.
2. Fortsetzung **F03**: 60–90 weitere eindeutige DACH/EU-Karten, Schwerpunkt
   Lieferservice-Preisdifferenzen und seltene Produktfamilien (Jahrgangsweine,
   regionale Spezialitäten).
2. Duplikat-Cluster-Lauf mit perceptual hash (Bilder) + MinHash (OCR-Text).
3. Lizenzklärung: mindestens 20 `reusable`-Quellen oder Bereitstellung intern
   nutzbarer Testkarten für den Benchmark.
4. Annotierung von ≥30 Golden Cases durch **zwei** Annotatoren + Kappa-Messung.
5. Anschließend DeepSeek-Red-Team (Ticket-Abschnitt „Prompt für den
   DeepSeek-Gegencheck").

## Quellen (Auswahl, voll in `source_registry.csv`)

- Schema.org: https://schema.org/MenuItem , https://schema.org/Menu
- Google FoodMenus: https://developers.google.com/my-business/reference/rest/v4/FoodMenus
- Toast ModifierGroup: https://doc.toasttab.com/openapi/menus/tag/Data-definitions/schema/ModifierGroup/
- EU 1169/2011: https://eur-lex.europa.eu/LexUriServ/LexUriServ.do?uri=OJ:L:2011:304:0018:0063:en:PDF
- PAngV 2022: https://www.gesetze-im-internet.de/pangv_2022/BJNR492110021.html
- Augustiner-Keller Biergarten (PDF), InterContinental Berlin (PDF), Café de la Paix (PDF), Viking Line Wine (PDF), Verbraucherzentrale Kinderspeisekarten-Studie (PDF).
