# Sättigungstest — KL-MENU-001 (F05)

**Ticket-Vorgabe (Zeile 121–124):** Für die letzten 20 tief analysierten eindeutigen
Karten prüfen, welche neuen Struktur-/Preis-/Options-/Deklarationsmuster jeweils
hinzukamen. Markiere Achsen, die noch nicht gesättigt sind.

> **Ehrlichkeitsvorbehalt:** Dieser Lauf erreichte **8 tief analysierte Karten**
> (Ticket fordert 20 als Sättigungsmenge). Der Test wird mit den 8 vorhandenen
> durchgeführt und ist damit **nicht voll aussagekräftig** – jedes „kein neues
> Muster" ist eine Beobachtung auf dünner Basis, kein Beweis für Sättigung.
> Achsen mit „ungesättigt" unten sind verlässlich; „potenziell gesättigt" ist
> eine Hypothese auf 8 Karten.

## Getestete Karten (8, tief analysiert)

| # | source_id | Land | Typ | Format | Neu hinzugekommene Muster |
|---|---|---|---|---|---|
| 1 | MENU_augustinerkeller_biergarten | DE | Biergarten | text_pdf | Mehrfachpreis pro Menge (PE-001); Einheitsmenge (PE-002) |
| 2 | MENU_hofbraeu_wirtshaus | DE | Restaurant | text_pdf | Allergenhinweis als Block; mehrseitige Sektionen |
| 3 | MENU_intercontinental_berlin | DE | Fine Dining | text_pdf | Nummerierte Allergenlegende 1–14 global (PE-003); Bilingual DE/EN seitwärts (PE-004) |
| 4 | MENU_cafe_carree | DE | Café | text_pdf | Fraktionale Stückmenge 2½ (PE-009) |
| 5 | MENU_baecker_frank | DE | Bäckerei | text_pdf | Bedingter Aufschlag Café-Verzehr (PE-012) |
| 6 | MENU_pokebowlstation | US | Restaurant | html | Quantity-tiered Bundle-Preis (PE-031); mehrstufige Pflicht-OptionGroups (PE-032) |
| 7 | MENU_osteriapratellino_firenze | IT | Restaurant | text_pdf | 5-Gang-Folge IT (PE-037); coperto per-Person-Gebühr (PE-038); franchigia Mindestverzehr (PE-039) |
| 8 | MENU_laventana_es | ES | Restaurant | text_pdf | Allergen-Icons pro Artikel (PE-042); spanische Produkt-Familien-Split carnes/pescados (PE-043) |

## Muster-Zuwachs pro Karte

Jede der 8 Karten brachte **mindestens ein neues Muster**. Das ist das klare
Signal: **keine Sättigung erreicht**. Bei echter Sättigung würden die letzten
Karten keine neuen Muster mehr liefern.

## Achsen-Sättigungsbewertung

| Achse | Status | Begründung |
|---|---|---|
| consumptionFamily | **potenziell gesättigt** | food/drink/bundle/fee_deposit/information alle belegt; kein neues aufgetaucht |
| courseRole | **potenziell gesättigt** | DE/IT/FR/ES-Folgen abgedeckt; kids belegt; tasting belegt |
| productFamily | **ungesättigt** | offener Baum, aber Spezialitäten (Jahrgangswein, Regionalküche) kaum erfasst |
| context | **ungesättigt** | timeOfDay/dayOfWeek/season/channel/audience teils belegt; saisonale Karten kaum tief |
| entryKind | **potenziell gesättigt** | simple/configurable/bundle/notice/fee_deposit alle belegt |
| priceKind | **ungesättigt** | gewichtsbasiert (per 100 g) nur schwach; Marktpreis/Tagespreis nur indirekt |
| choiceKind / preModifier | **ungesättigt** | DACH-Modifier-Ausdrücke nicht validiert; temperatur/sauce nur theoriebelegt |
| selectionRule | **ungesättigt** | nested/dependent OptionGroups (Bubble Tea/Poké) erst theorieweise erfasst |
| declarations | **ungesättigt** | Option-Level-Allergene nie beobachtet; may_contain/traces/free_from kaum belegt |

## Schlussfolgerung

**Sättigung nicht erreicht** (8/20 Karten, jede lieferte neue Muster). Die drei
ungesättigten Bereiche mit dem größten erwarteten Erkenntnisgewinn für die nächste
Fortsetzung (F03c):

1. **Option-Level-Deklarationen** (Allergene direkt am Choice, nicht nur am Entry).
2. **Gewichtsbasierte Preisgebung** (Steak per 100 g) mit echtem Beispiel.
3. **Bild-PDF/Foto-Tiefenanalyse** (bisher nur text_pdf/html) – hier könnten
   OCR-spezifische Muster (Spalten, Trennzeichen, Legendenposition) auftreten,
   die auf den bisher sauberen Textquellen nicht sichtbar werden.

Diese Priorisierung ersetzt raten.

---

## F03d-Nachtrag (2026-07-16)

Die drei priorisierten Lücken wurden mit **Brechts Steakhaus Berlin** (eine einzige
reiche Primärquelle) plus BMEL-Rechtsquelle weitgehend geschlossen:

| Priorisierte Lücke | Status nach F03d | Evidenz |
|---|---|---|
| Gewichtsbasierte Preise | **geschlossen** | PE-046 (per-100g mit Mindestgewicht), PE-047 (Zweigrößen), PE-048 (Gewicht im Namen) |
| Option-Level-Deklarationen | **teilweise geschlossen** | PE-049 (per-Entry-Allergencodes bestätigt); Option-Level (am Choice) juristisch durch LMIV legitimiert (PE-052), aber noch keine Karte beobachtet, die Allergene direkt am *Topping* ausweist |
| Bild-PDF/Foto/OCR | **noch offen** | keine echte Bild-PDF-Tiefenquelle gefunden; Tool- und Anbieterquellen nur (topfood/Adobe/Speiso) |

Brechts lieferte über die Prioritäten hinaus noch: Person-scoped Bundles mit
min/max und pro-Person-Gewicht (PE-050), gemischte 32er-Legende aus Zusatzstoffen
+ Allergenen + Hilfsstoffen (PE-049, wichtig für kanonische Trennung), und
Modifier mit Sub-Choice (PE-051).

**Bild-PDF/OCR bleibt die größte verbleibende strukturale Lücke** – alle bisher
tiefen Karten hatten saubere Textebenen.

---

## F03e-Nachtrag (2026-07-16)

Systematische Suche nach öffentlichen Bild-PDFs (curl + `pdftotext`-Textmengen-Check
auf 9 Kandidaten). Ergebnis: **alle erreichbaren öffentlichen PDFs haben
Textebenen** (4419–22340 Zeichen). Echte Scan-/Foto-PDFs lassen sich über öffentliche
Websuche verlässlich nicht beschaffen – Restaurants veröffentlichen fast immer
textbasierte PDFs (InDesign/Illustrator-Export) oder HTML-Karten.

Das Ticket erlaubt ausdrücklich (Zeile 138) **intern bereitgestellte Testkarten**.
Die OCR-Lücke ist damit nicht mit öffentlichen Quellen closbar; sie erfordert
Team-Fotos. Das ist ehrlich als Ergebnis dokumentiert, nicht als Fehler vertuscht.

Stichprobe trotzdem signifikant erweitert (DE/AT/CH/Griechisch/Argentinisch),
darunter neue Beobachtungen:
- **Inline-Bilingualität** (griechisch+deutsch in *einer* Namenszeile, PE-053) –
  Randfall, den das LocalizableText-Modell beachten muss (beide Sprachen in einem value).
- **Gewichtspreise bestätigt** an zweiter unabhängiger Quelle (PE-054).
- **Gewichts-+Personen-Bundle gleichzeitig** (PE-055): Roastbeef 3€/100g UND
  57€ für 2 Pers. ca. 200g – zwei Offers mit unterschiedlicher basis auf einem Entry.
