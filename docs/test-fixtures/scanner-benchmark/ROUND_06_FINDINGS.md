# Import-Qualität Runde 6: Vollabdeckung und Produktkonsolidierung

**Stand:** 22. Juli 2026
**Auslöser:** Der aktuelle Import soll den nützlichen Stand der früheren
Produktsandbox vollständig übernehmen; drei auswählbare Karten sollen die
strukturierte Breite des Imports nachvollziehbar testen.

## 1. Neuer reproduzierbarer Testumfang

Die dreiseitige `KitchenLink Prüfküche` enthält absichtlich neun Kategorien,
23 Artikel (16 Speisen, 7 Getränke), 23 Beschreibungen, 22 Artikel mit
Allergen-/Zusatzstoffcodes, 14 Artikel mit Varianten/Größen/Extras sowie ein
3-Gang-Menü mit Preis pro Person. Inhalt und Anker stehen in
`kitchenlink-pruefkueche-truth.json`; die Bilder erzeugt
`scripts/generate_demo_test_menu.py` deterministisch neu.

Der App-Picker kombiniert diese kontrollierte Vollabdeckung mit Lichtburg und
Alexxanders als reale schwierige Layouts. Die historische
Scheune/Lichtburg/Alexxanders-Gold-Baseline bleibt unverändert.

## 2. Selbstprüfung des ersten 17-Seiten-Laufs

Der keylose KI-Textpfad lief über Prüfküche plus die drei historischen Karten
vollständig durch (`run-20260722-003922`, 17 Seiten, 147 OCR-Zeilen allein auf
der Prüfküche). Für die Prüfküche erkannte er:

| Feld | Ergebnis |
| --- | ---: |
| Kategorien | 9 / 9 |
| Artikel | 23 / 23 |
| Speisen / Getränke | 16 / 7 |
| Beschreibungen | 23 / 23 |
| Artikel mit Deklarationen | 22 / 22 |
| Artikel mit Optionsgruppen | 13 / 14 |
| Preisbasis `per_person` im Draft | 0 / 1 |

Alle drei Seiten wurden gegen Bild und Roh-OCR geprüft. Namen, Preise,
Kategoriegrenzen und Beschreibungen waren vollständig. Die Prüfung deckte drei
konkrete Schwächen auf:

1. `price_basis` wurde vom KI-Payload zwar gelesen, im
   `MenuItemData`-Zwischenschritt aber verworfen.
2. Optionen mit `0,00 €` wurden ausgefiltert; dadurch fehlte die Variante
   „ohne Parmesan“ vollständig und zwei enthaltene Beilagen wurden reduziert.
3. Kleine Allergenbuchstaben wurden im OCR-Text wiederholt verwechselt
   (`g`/`9`, `i`/`l`).

## 3. Umgesetzt

- `MenuItemData.priceBasis` erhält die strukturierte Basis durch Mapping,
  Draft, Review-Korrektur, Konvertierung und lokale Codable-Persistenz.
- Kostenlose/enthaltene Optionen bleiben als `.included` im Draft und kommen
  mit Preis 0 wieder in der lokalen Menüstruktur an.
- Die deterministische Karte druckt Buchstabencodes größer, in eckigen Klammern
  und in Versalien. Inhalt und Bedeutung bleiben unverändert, die Glyphen sind
  aber eindeutig von Ziffern unterscheidbar.
- Gezielte Regressionstests schützen `per_person`, menschliche
  Preiskorrekturen, Persistenz und enthaltene Nullpreis-Optionen.

## 4. Verifikationsgrenze

Der finale lokale Apple-Vision-/Regel-Review lief über alle 17 Seiten
erfolgreich durch (`run-20260722-005204`). Auf der Prüfküche entstanden 157
OCR-Zeilen; darin sind `39,90 € pro Person`, die beiden `0,00 €`-Auswahlen und
die vorgesehenen groß gesetzten Deklarationscodes sichtbar. Der lokale
Diagnoseparser übersegmentiert das absichtlich dichte Layout weiterhin und ist
nicht als Ersatz für den strukturierten KI-Pfad zu bewerten.

Die vollständige Unit-Suite, die gezielten Import-UI-Smokes und der unveränderte
14-Seiten-Gold-Benchmark sind ebenfalls grün. Die neuen Tests schützen
insbesondere `per_person`, menschliche Preiskorrektur, Codable-Persistenz,
enthaltene Nullpreis-Optionen und die exakt drei auswählbaren Fixtures.

Der abschließende direkte Vision-Lauf würde die Kartenbilder an den externen
Free-LLM-Dienst übertragen. Diese zusätzliche Bildübertragung war für dieses
Ticket nicht ausdrücklich freigegeben und wurde daher nicht durchgeführt.
Lokaler Gold-Benchmark, komplette Unit-Suite und UI-Smokes bilden den
Abschlussnachweis; ein erneuter externer Vision-Bericht bleibt optional nach
expliziter Freigabe.

Das Gangmenü bleibt korrekt ein bepreister Artikel mit `per_person` und
vollständiger Gangbeschreibung. Eine weitergehende Zerlegung der Gänge in
`bundleComponents` ist noch nicht Teil des aktuellen KI-Adapters und bleibt
eine ehrliche Folgestufe.
