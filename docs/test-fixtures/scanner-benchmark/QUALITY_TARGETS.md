# Menü-Import: Qualitätsziele und Iterations-Workflow (KL-SCAN-002)

**Stand:** 19. Juli 2026
**Quelle:** Nutzerfeedback nach dem ersten realen Scan-Vergleich („Namen passen
größtenteils, aber nicht alle") und die daraus formulierten Anforderungen.

Dieses Dokument ist die Messlatte für die Import-Qualitätsrunden. Der bestehende
Gold-Baseline-Benchmark (`gold-baseline.json`, 23 Sektions-/46 Artikelanker)
schützt nur gegen Regression einzelner Anker; er misst NICHT die vollständige
Feldqualität. Die Runden unten schließen diese Lücke schrittweise.

## 1. Was der Import erfassen und abbilden muss

1. **Kategorien aus den Kartentiteln** — Vorspeisen, Salate, Hauptgerichte,
   Desserts, Getränke usw., in der Reihenfolge der Karte. Keine erfundenen und
   keine verschmolzenen Kategorien.
2. **Artikel vollständig und korrekt benannt** — der Name exakt wie auf der
   Karte (ohne OCR-Verstümmelung), inklusive Sonderzeichen/Anführungen.
3. **Varianten / Optionen / Größen** — z. B. klein/groß, 0,3 l / 0,5 l,
   Wahlbeilagen — als strukturierte Optionen am Artikel, nicht als eigener
   Artikel und nicht im Namen.
4. **Beschreibungen** — die Beschreibungszeile(n) unter dem Namen gehören in
   das Beschreibungsfeld, nicht in den Namen und nicht verworfen.
5. **Inhaltsstoffe/Allergene über die Karten-Legende** — Karten ordnen Codes
   (Buchstaben oder Ziffern, z. B. „a, c, g" oder „1,2") über eine Legende zu.
   Der Import muss: die Legende erkennen, die Codes dem Artikel strukturiert
   zuordnen und **die Codes aus Name und Beschreibung entfernen**. In der
   Produkt-UI werden sie später einheitlich als kleine Icons dargestellt
   (eigenes UI-Ticket; Voraussetzung ist die saubere strukturierte Zuordnung
   hier).
6. **Preise** — dem richtigen Artikel zugeordnet, auch bei mehrspaltigen
   Layouts und vertikal abgesetzten Preisblöcken; preislose Einträge bleiben
   als `needsReview` erhalten (nie erfundene Preise). Preisbasis erfassen:
   „pro Person" ist `per_person`, nicht `per_item`.

Ergänzt nach Runde 1 (Nutzer-Feedback vom 20. Juli 2026, Details in
`ROUND_01_FINDINGS.md`):

7. **Set-/Gang-Menüs** — feste Gänge, Wahlgänge („oder/or") und
   Menüpreis pro Person als Bundle-Struktur, nicht als lose Fragmente.
8. **Zweisprachige Karten** — EINE Sprache strukturiert erfassen, keine
   Duplikate; eine optionale englische Gastkarten-Sprache ist ein
   Gast-Web-Folgeticket.
9. **Deck-/Zierseiten** — Seiten ohne Speiseinhalt (Logo, Claim) erkennen
   und überspringen statt Phantomartikel zu erzeugen.
10. **Legende fehlt = Warnung** — werden Codes erkannt, aber keine Legende
    auf der Karte gefunden, muss der Import ausdrücklich warnen und die
    Zuordnung zur Klärung stellen.
11. **Vegetarisch/vegan** — strukturiert erfassen; einheitliche Icons
    (gemeinsam mit den Allergen-Icons) sind ein UI-Folgeticket.
12. **Optionen müssen wählbar ankommen** — erkannte Optionen (z. B. „ohne
    Hähnchenbrust") müssen bis ins Produkt (Gast-Web) als echt wählbare
    Auswahl durchgereicht werden, nicht nur als Text.

**Harte Regel (Punkt 5, nochmals):** Nachgestellte Legende-Codes dürfen
**niemals** im veröffentlichten Namen oder in der Beschreibung landen.

## 2. Der Iterations-Workflow

Werkzeug: `scripts/run-import-review.sh` (Review-Umgebung, KL-SCAN-002).

```
./scripts/run-import-review.sh
# oder mit eigenen Karten (PDFs oder Bild-Unterordner in einem Ordner):
KITCHENLINK_REVIEW_MENUS=~/Speisekarten ./scripts/run-import-review.sh
```

Der Lauf erzeugt einen HTML-Report (öffnet automatisch im Browser): pro Seite
links das Original mit eingezeichneten Fundstellen, rechts das
Erkennungsergebnis mit automatischen Markierungen (ohne Preis, Codes im Namen,
ohne Fundstelle, ohne Beschreibung, …), dazu die Veröffentlichungs-Vorschau und
die Roh-OCR-Zeilen pro Seite.

**Eine Runde:**

1. **Lauf:** Agent oder Nutzer führt das Skript aus (mit möglichst vielen
   Karten). Mit gesetztem `KITCHENLINK_OPENAI_API_KEY` läuft zusätzlich der
   KI-Pfad; der Report zeigt dann beide Pipelines umschaltbar nebeneinander.
2. **Selbstverifikation (Pflicht, seit Runde 1):** Der Agent prüft den Lauf
   zuerst vollständig selbst — jede Seite gegen die Roh-OCR-Zeilen — und legt
   dem Nutzer seine eigene Befundliste zusammen mit dem Report vor. Ein Lauf
   ohne eigene Befundliste wird nicht zur Prüfung vorgelegt.
3. **Prüfung:** Der Nutzer geht die Karten im Report durch, markiert pro
   Eintrag OK/Falsch mit kurzer Notiz und trägt Fehlendes pro Seite ein.
   „Feedback exportieren" erzeugt `import-review-feedback.json`.
4. **Auswertung:** Der Agent übersetzt das Feedback in (a) konkrete
   Pipeline-Fixes und (b) neue/erweiterte Gold-Baseline-Anker, damit jede
   bestätigte Korrektur dauerhaft gegen Regression geschützt ist.
5. **Nachweis:** Benchmark (`run-scanner-benchmark.sh`) und komplette Unit-Suite
   müssen grün bleiben; der nächste Review-Lauf zeigt den Fortschritt am
   selben Kartensatz (Läufe sind zeitgestempelt und vergleichbar).

Die Befunde und der Architektur-Entscheid aus Runde 1 stehen in
`ROUND_01_FINDINGS.md`: Die OCR verliert nichts Wesentliches; der Regel-Parser
ist der Engpass (2D-Layout, Semantik). Runde 2 misst deshalb den vorhandenen
KI-Pfad (Bilder + OCR an ein Vision-LLM) im direkten Vergleich.

Runden werden wiederholt, bis die Ziele aus §1 auf dem Kartensatz erfüllt sind.
Erst dann lohnt sich Feinschliff an der Veröffentlichung (KL-MENU-005 ist der
Transportweg; er ist bewusst getrennt von der Erkennungsqualität).

## 3. Ehrliche Abgrenzung

- Der Report zeigt, was die **lokale** Pipeline (Apple Vision + Regeln, ohne
  LLM) erkennt — dieselbe Konfiguration wie der Benchmark, deterministisch.
- Automatische Markierungen sind Heuristiken zur Aufmerksamkeitslenkung, kein
  Urteil. Das Urteil fällt der Mensch im Report.
- Bekannte offene Punkte vor Runde 1 stehen in `CURRENT_RESULTS.md`
  (u. a. zwei Lichtburg-Preiszuordnungen, strukturell unsichere Kandidaten).
