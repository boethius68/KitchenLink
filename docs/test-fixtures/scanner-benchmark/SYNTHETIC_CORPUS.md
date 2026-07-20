# Synthetischer Speisekarten-Testkorpus mit Ground Truth (KL-SCAN-002)

**Stand:** 21. Juli 2026
**Zweck:** Import-Qualität objektiv und im großen Maßstab messen — nicht
begucken. Ersetzt/ergänzt eine (verloren gegangene) reale Kartensammlung durch
generierte Karten, deren **korrektes Ergebnis bekannt ist**.

## Idee

Ein Free-LLM (DeepSeek über OpenCode Zen, keylos/kostenlos) erzeugt diverse
deutsche Speisekarten als JSON. Aus **diesem JSON** wird deterministisch ein
realistisches PDF gerendert (Chrome headless) — Bild und Wahrheit stimmen exakt
überein. Allergen-Codes werden im Bild an die Artikelnamen gehängt (wie auf
echten Karten), in der Wahrheit stehen sie getrennt: so misst sich das
Code-Trennen automatisch. Abgedeckte harte Fälle: zweispaltig, dichte Karten,
Set-/Gang-Menüs (pro Person), Varianten/Portionen, zweisprachig, Deckseiten.

## Ablauf

```bash
# 1. Korpus erzeugen (PDFs + Ground-Truth-JSON)
python3 scripts/generate_menu_corpus.py --count 30 --out /tmp/kl-corpus

# 2. Durch den echten Vision-Import jagen (kostenlos, keylos)
KITCHENLINK_OPENCODE_FREE=1 KITCHENLINK_REVIEW_MENUS=/tmp/kl-corpus/pdf \
  KITCHENLINK_REVIEW_NO_OPEN=1 ./scripts/run-import-review.sh

# 3. Automatisch gegen die Ground Truth scoren
python3 scripts/score_menu_corpus.py \
  --report /tmp/kitchenlink-import-review/latest/report.json \
  --truth  /tmp/kl-corpus/truth
```

Der Scorer meldet pro Karte und im Durchschnitt:

- **Recall** — Anteil der Wahrheits-Artikel, die die KI (Name) fand
- **Preis** — Anteil der gefundenen Artikel mit korrektem Preis
- **Codes** — Anteil der KI-Namen OHNE hineingerutschte Allergencodes
- **Erfund.** — von der KI erfundene Artikel (nicht in der Wahrheit)

## Erster Nachweis (21. Juli 2026)

Pipeline end-to-end bewiesen. Zwei generierte Karten (Steakhouse, Burger-Laden,
je mit Varianten) durch den Vision-Import: **Recall 100 %, Preis 100 %,
Code-Trennung 100 %, 0 erfundene Artikel.** Ein sauberer synthetischer Render
ist leichter als ein echtes Foto — der Wert liegt in Skalierung und den harten
Fällen (Set-Menü/zweisprachig/Deckseite), die der Korpus breit streut.

## Grenzen / echte Karten

Synthetische Renders testen **Struktur** (Kategorien, Spalten, Set-Menüs,
Code-Trennung, Preise) sehr gut, aber nicht die volle **Foto-Robustheit**
(Schräglage, Beleuchtung, Handschrift, laminierte Reflexe). Für diese Achse
ergänzt man später echte Fotos: dieselben Skripte nehmen jeden Ordner mit PDFs
oder Bild-Unterordnern über `KITCHENLINK_REVIEW_MENUS=<Ordner>`.
