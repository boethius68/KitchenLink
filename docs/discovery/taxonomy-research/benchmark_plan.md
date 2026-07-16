# Benchmark Plan — Speisekarten-Import v0.1

**Status:** Vorschlag, Discovery. Keine freigegebene Entscheidung.
**Geltungsbereich:** Messverfahren für Wert- und Beziehungs-Extraktion aus
Speisekarten. Noch kein Produktionsparser.

## 1. Zulässige Datenquellen

- **Primär:** intern bereitgestellte, rechtmäßig nutzbare Testkarten (vom Team
  mit Erlaubnis fotografiert oder vom Betreiber freigegeben).
- **Sekundär:** Quellen mit dokumentierter Lizenz (Creative Commons, offene
  Regierungsdaten) oder explizitem `rights_status=reusable` im `source_registry`.
- **Verboten:** private Nutzer-Uploads; ohne Erlaubnis gecrawlte Karten; jede
  Quelle mit `rights_status in {research_only, metadata_only, unclear, excluded}`
  darf **nicht** in den Benchmark aufgenommen werden, sondern nur in die
  Strukturforschung (Metadaten + abgeleitete Beobachtungen).
- **Datenschutz:** EXIF, Gesichter und personenbezogene Daten aus Testbildern
  entfernen, bevor sie in den Benchmark gelangen.

## 2. Splits und Dedup-Logik

- **Dedup vor Split:** perceptual hash (Bilder) + OCR-MinHash (Text) +
  kanonische URL + Datei-Hash. Duplicate-Cluster werden ausgewiesen; pro Cluster
  geht nur ein Vertreter in Häufigkeitsaussagen ein.
- **Stratifizierung** nach venue_type, Land, Sprache, Format, venue-Kategorie
  (Kette ≤3 Vertreter, unabhängig ≥60%).
- **Splits:**
  - dev (10%): Annotator-Kalibrierung, Guideline-Iteration.
  - train (60%): späteres Modelltraining.
  - val (15%): Modell-/Prompt-Auswahl.
  - test (15%): einziges, gesperrtes Endmaß; darf nicht für Prompt-Tuning
    verwendet werden.
- **Holdout für Halluzinations-Items:** Items ohne Beleg werden als Negative
  mitannotiert (Deklarationen/Optionen, die ein Modell erfinden könnte).

## 3. Metriken (Werte)

- **Pro Feld (Value-level):** Exact-Match auf normalisiertem Wert und auf
  `rawText` (zwei getrennte Zahlen). Felder: name, description, quantity, price
  (amountCents, deltaCents, priceKind), currency.
- **Preis-Spezifisch:** separate Metriken für `priceKind`-Korrekt
  (Klassifikation) und für Cents-Genauigkeit (Regression nur auf `fixed`).
- **Beziehungs-Level (Relation-level):**
  - Entry ↔ Section (Zuordnung),
  - Choice ↔ OptionGroup (Gruppenzugehörigkeit),
  - Offer ↔ Quantity (`appliesToQuantity`),
  - Declaration ↔ Entry/Option (Scope),
  - Bundle ↔ Component.
  Metrik: F1 auf Relationen.
- **Layout-Level:** Lesereihenfolge (Kendall-Tau gegen annotierte Sequenz);
  Spaltenzuordnung.

## 4. Halluzinations-/Verlustmetriken

- **Hallucination Rate (Deklarationen):** Anteil der Modell-Allergene/Claims/
  Zusatzstoffe, die **keinen** Beleg im Gold haben (False Positives). Ziel: ≤2%.
- **Evidenz-Treue:** Anteil der normalisierten Werte mit korrektem `rawText` +
  `pageOrLocation`, das den Gold-Wert tatsächlich trägt. Ziel: ≥95%.
- **Verlust-Rate:** Anteil der Gold-Entries/Options/Preise, die das Modell
  verwirft (False Negatives). Speziell: Artikel ohne Basispreis und inkludierte
  Optionen dürfen nicht verworfen werden (bisheriger App-Fehler).
- **Unknown-Missbrauch:** Anteil der Fälle, in denen `unknown` gesetzt wird,
  obwohl die Karte den Wert klar enthält (zu träges Unknown).

## 5. Betriebsmetriken (lokal)

- Laufzeit pro Seite (Sekunden), Spitzen-RAM (MB), Energie/Entropie nach
  Möglichkeit, auf einem fest benannten iPhone-Simulator/Referenzgerät.
- Offline-Fähigkeit: kein Netzwerkzugriff während Inferenz.

## 6. Menschliche Korrekturzeit

- Pro Gold-Seite: Zeit für vollständige Review (Sekunde) als Akzeptanzgröße.
- Zielvorgabe (Vorschlag): ≤90 Sekunden pro typischer Speisekartenseite nach
  Schema v0.1.

## 7. Akzeptanzschwellen (Vorschlag, erst nach Inter-Annotator-Baseline)

| Metrik | Schwellwert |
|---|---|
| Value Exact-Match (priceKind) | ≥ 0,90 |
| Value Exact-Match (amountCents, fixed) | ≥ 0,92 |
| Relation F1 (Entry↔Section) | ≥ 0,93 |
| Relation F1 (Choice↔OptionGroup) | ≥ 0,80 |
| Hallucination Rate (Deklarationen) | ≤ 0,02 |
| Verlust-Rate (Entries) | ≤ 0,03 |
| Lesereihenfolge Kendall-Tau | ≥ 0,80 |
| Review-Zeit/Site | ≤ 90 s |

## 8. Offene Punkte für die nächste Stufe

- Inter-Annotator-Kappa messen, bevor Modelle evaluiert werden.
- Build eines ersten internen Testsets (≥50 Seiten) mit `rights_status=reusable`.
- Erweiterung auf bildbasierte PDFs und Fotos.
- Definition der Negative-Set-Größe (Halluzinations-Tests).
