# Import-Qualität Runde 1: Befunde und Ursachen (KL-SCAN-002)

**Stand:** 20. Juli 2026
**Quellen:** Nutzer-Feedback-Export vom 20. Juli 2026 (Lauf `2026-07-19T21:17`)
plus die vollständige Eigenverifikation des Agenten (jede Seite gegen die
Roh-OCR-Zeilen geprüft). Prozessfehler eingeräumt und abgestellt: Der erste
Report wurde ohne vollständige eigene Befundliste vorgelegt; ab dieser Runde
verifiziert der Agent jeden Lauf zuerst selbst (siehe `QUALITY_TARGETS.md` §2).

## 1. Systemische Ursachen (alle am Report belegt)

- **U1 — Die OCR ist NICHT der Engpass.** Jeder geprüfte „fehlende" Inhalt
  steht vollständig in den Roh-OCR-Zeilen, inklusive x-Koordinaten beider
  Spalten, der „wahlweise…"-Beschreibungszeile, der kompletten Menüstruktur
  und „Menüpreis pro Person / 55€". Die Bedingung des Nutzers („wenn der
  OCR-Prozess Wesentliches herausfiltert → Bild direkt an die KI") greift
  also nicht bei der OCR — sondern beim nachgelagerten Regel-Parser.
- **U2 — Der Regel-Parser versteht keine 2D-Layouts:** Spalten werden der
  falschen (teils von der Vorseite verschleppten) Sektion zugeordnet,
  vertikal abgesetzte Preisblöcke falsch oder gar nicht zugeordnet.
- **U3 — Der Regel-Parser hat keine Semantik:** Set-Menüs („oder/or",
  Gänge, „pro Person"), Zweisprachigkeit, Deckseiten, Variantenspalten und
  Legenden-lose Allergen-Codes werden nicht als das erkannt, was sie sind.
  Das Draft-Modell KÖNNTE das meiste abbilden (`bundleComponents`,
  `basis: per_person`, `optionGroups`, `declarations`) — der Parser erzeugt
  diese Strukturen nur nie.

**Konsequenz:** Punkt-Fixes am Regel-Parser wären Symptombekämpfung pro
Kartentyp. Der im Code bereits vorhandene KI-Pfad (`parseSectionsWithLLM`:
Seitenbilder + OCR-Zeilen an ein Vision-LLM, derzeit OpenAI `gpt-4.1`,
Key des Nutzers erforderlich) ist die vom Nutzer geforderte „intelligente
Erfassung" und wird in Runde 2 im direkten Vergleich gemessen (die
Review-Umgebung kann beide Pipelines nebeneinander zeigen).

## 2. Einzelbefunde

### Scheune Berlin

| # | Befund | Ursache | Beleg |
|---|---|---|---|
| S1 | „Kleiner Salat": Beschreibungszeile „#wahlweise #gemischter Salat #Tomatensalat #Gurkensalat #Krautsalat" fehlt komplett (nur „#Cole Slaw" übernommen) | Parser verwirft Zeile | Zeile steht wörtlich in der Roh-OCR von Seite 1 |
| S2 | Legende-Codes in Beschreibungen (14 Einträge) und im Namen („Gulaschsuppe-A,G,l,-") | Parser trennt Codes nicht ab | U3 |
| S3 | Die Karte hat KEINE Legende für die Codes → es muss eine Import-Warnung geben („Codes erkannt, Legende fehlt") statt stillschweigender Übernahme | fehlende Funktion | Nutzeranforderung |
| S4 | Beschreibungsfragmente doppelt angehängt („…-A,G,)- …-A,G,J-") | Zeilen-Doppelverarbeitung | Report |
| S5 | Option „ohne Hähnchenbrust 11,90" wird erkannt, muss aber bis ins Produkt (Gast-Web) als echt wählbare Option durchgereicht werden | Folgeanforderung an Publish/Gast-Web | Nutzeranforderung |

### Lichtburg Berlin

| # | Befund | Ursache | Beleg |
|---|---|---|---|
| L1 | Zweisprachige Karte: EN-Zeilen werden dupliziert übernommen, teils als eigene Artikel („Salat" UND „Salad") | U3 | Report S5 |
| L2 | Produktanforderung dazu: EINE Sprache strukturiert erfassen; Gäste sollen EN optional als Sprache wählen können (Gast-Web-Folgeticket, nicht Parser) | — | Nutzeranforderung |
| L3 | Seite 5, Spalten: linke Beilagen-Spalte landet unter „Hauptgerichte & main dishes" (von Vorseite verschleppt), „Grüne Bohnen mit Speck"/„Bratkartoffeln" fehlen als Einträge, Preisblock „3× 4,90€" falsch zugeordnet, „Kräuterbutter" mit falschem Preis 1,90 | U2 | OCR hat beide Spalten sauber mit x-Koordinaten |
| L4 | Seite 6, Set-Menü: komplette Struktur in OCR (Vorspeise fix, Hauptgang als 3er-Wahl mit „oder/or", Dessert fix, „pro Person: 39,90") → Ergebnis sind 3 Fragmente; „Tiramisu" erhält den 7,90-Preis von einer anderen Seite | U2+U3 | OCR-Auszug in diesem Dokument geprüft |
| L5 | Vegetarisch/vegan sollen ein eigenes einheitliches Icon bekommen (zusammen mit den Allergen-Icons ein UI-Folgeticket; Voraussetzung ist strukturierte Erfassung) | — | Nutzeranforderung |

### Alexxanders Chemnitz

| # | Befund | Ursache | Beleg |
|---|---|---|---|
| A1 | Seite 1 ist eine Deck-/Markenseite („anders / Gastgeber / …wir lassen sie andersessen") → Parser erfindet Artikel „Gastgeber" | U3 | Report |
| A2 | Gerichte mit zwei Preisspalten (Zwischengericht/Hauptgericht) müssten zwei Varianten pro Gericht ergeben; stattdessen ein Preis plus Phantomeintrag „Zwischengericht" ohne Preis | U2 | Report |
| A3 | „Überraschungsmenü 3-gang": Beschreibung („…lassen Sie sich überraschen…") fehlt komplett; Preisbasis ist laut Karte „pro Person", erfasst als `per_item` (das Draft-Modell kennt `per_person`) | U3 | OCR Seite 4 |
| A4 | Dessertseite: Preisblock (13/12/15/7,40 €) steht vertikal getrennt von den Gerichten — Zuordnung fragil | U2 | OCR Seite 4 |
| A5 | 26 von 27 Einträgen stehen auf `needsReview` | Parser-Unsicherheit | Report |

## 3. Nächste Schritte (Runde 2)

1. **KI-Vergleich messen:** Review-Umgebung im Vergleichsmodus laufen lassen
   (lokal vs. KI nebeneinander). Benötigt den OpenAI-Key des Nutzers
   (`KITCHENLINK_OPENAI_API_KEY` beim Skriptaufruf); alternativ Entscheidung,
   den KI-Pfad auf einen anderen Anbieter umzustellen.
2. Nach dem Vergleich: KI-Pfad gezielt auf die Zielliste härten (Bundles,
   `per_person`, Sprachen-Trennung, Deckseiten, Legende-Warnung) statt den
   Regel-Parser fallweise zu flicken. Der Regel-Parser bleibt Offline-Fallback
   und Benchmark-Basis.
3. Bestätigte Korrekturen wandern als Anker in die Gold-Baseline.
