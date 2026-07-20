# Import-Qualität Runde 3: KI-Pfad gehärtet (Set-Menüs, pro Person, JSON-Robustheit)

**Stand:** 20. Juli 2026
**Setup:** wie Runde 2 (`big-pickle` → `xiaomi/mimo-v2.5` über OpenCode Zen,
keylos/kostenlos, Textmodus mit Koordinaten-OCR). Alle Änderungen gegen die
Zielliste (`QUALITY_TARGETS.md`) und mit Eigenverifikation gegen die Roh-OCR.

## 1. Umgesetzt und verifiziert

| Runde-2-Lücke | Runde-3-Ergebnis |
|---|---|
| Set-/Gang-Menüs zerfielen in Fragmente | **Ein bepreister Eintrag** „Menü Lichtburg · 39,90" mit „Preis pro Person" und Gangauflistung in der Beschreibung (Vorspeise/Hauptgang mit Wahl/Dessert) |
| „pro Person" nicht erfasst | **`price_basis: per_person`** im Schema; Mapping stellt „Preis pro Person" der Beschreibung voran (Alexxanders-Überraschungsmenü, Lichtburg-Menü) |
| Scheune S3 scheiterte an JSON | **3/3 Seiten** — German-quote-aware JSON-Reparatur (`„Süßes" Wiener Schnitzel`, `nach „Hausfrauenart", …`) |
| Alexxanders S4 flackerte (JSON) | **Retry bei JSON-Fehler**: dieselbe Seite eines nicht-deterministischen Free-Modells wird einmal neu angefragt und kommt zurück |

Alle drei Karten laufen jetzt vollständig durch (Scheune 3/3, Lichtburg 7/7,
Alexxanders 3/4 + 1 legitim leere Deckseite). Code-in-Text-Verdacht: Scheune
lokal 16 → **KI 0**. Kompletter Prompt zentralisiert (`llmMenuSystemPrompt`)
und um Spalten-, Zweisprachigkeits- und Deckseiten-Regeln erweitert.

### Technische Bausteine

- **`repairJSONStringQuotes`** um deutsche Anführungspaare erweitert: ein
  gerades `"` mit offenem `„` im selben String-Wert ist Inhalt (wird escapt),
  auch wenn ein Komma folgt. 5 Unit-Tests (inkl. der zwei realen Muster).
- **`LLMItemPayload`** trägt `price_basis` und `courses`; `mapLLMSections`
  webt beides treu in die Beschreibung.
- **Retry-auf-JSON-Fehler** im seitenweisen Pfad (auch im Textmodus ohne Bilder).

## 2. Verbliebene Punkte (Runde 4, abnehmender Ertrag)

1. **Set-Menü-Reste:** Neben dem korrekten Menü-Eintrag bleibt vereinzelt ein
   preisloses Gang-Fragment (z. B. „Vorspeise" ohne Preis) als
   `needsReview`-Kandidat im Draft. Wird nicht veröffentlicht (preislos), ist
   aber unschöner Restmüll; ein strengerer Prompt oder ein Post-Filter könnte
   Gang-Titel unterdrücken, die schon im Menü-`courses` stehen.
2. **Vereinzelte Streupreise** (z. B. Tiramisu 7,90 neben dem 39,90-Menü).
3. **Kategorienschnitt** gelegentlich eigenwillig (getrennte „Saucen"/
   „Beilagen").
4. **Vision-Modus weiterhin ungetestet** im Volllauf — big-pickle kann Bilder;
   ein Bild-vs-Text-Vergleich steht aus.
5. **Nicht-Determinismus bleibt** die Natur eines freien Reasoning-Modells; der
   Retry entschärft es, garantiert aber keine 100 %. Für Produktionsrobustheit
   wäre ein verlässlicheres (ggf. bezahltes) Modell zu erwägen — Nutzer-/
   Kostenentscheidung.

## 3. Gesamtbild nach drei Runden

Der KI-Pfad erfasst die Testkarten **deutlich vollständiger und sauberer** als
der Regel-Parser: Allergen-Codes getrennt, Beschreibungen und Spalten erhalten,
Set-Menüs und Preisbasis strukturiert, Deckseiten übersprungen, robuste
JSON-Behandlung — und das kostenlos über die Zen-Free-Modelle. Der Regel-Parser
bleibt der Offline-Fallback und die Benchmark-Basis. Nächster sinnvoller Schritt
ist, bestätigte Ergebnisse als Gold-Anker zu sichern und den Vision-Modus zu
messen.
