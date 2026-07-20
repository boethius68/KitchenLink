# Import-Qualität Runde 4: Vision- vs. Textmodus gemessen (Free-Modell)

**Stand:** 20. Juli 2026
**Frage:** Bringt der Bild-Modus (Vision) von `big-pickle` gegenüber dem
Textmodus mit koordinaten-annotierten OCR-Zeilen genug, um den Timeout-Nachteil
zu rechtfertigen?

## 1. Vorab geklärt: Vision funktioniert überhaupt

Kontrolltest: dasselbe Prompt mit (a) einer echten Menüseite und (b) einem
leeren weißen Bild.
- Weißes Bild → **0 Artikel** (keine Halluzination).
- Menüseite → **korrekte, seitenspezifische Gerichte**.

Das Ergebnis ist also bildgesteuert; `big-pickle` (→ mimo-v2.5) verarbeitet
Bilder tatsächlich. (`usage.image_tokens` meldet das Gateway zwar als 0 — eine
Reporting-Eigenheit —, der Weiß-vs-Menü-Unterschied beweist die Bildwirkung.)

## 2. Voller Vergleichslauf

Identische Fixtures, einmal Textmodus, einmal Vision:

| Karte | Textmodus (Koordinaten) | Vision (Bilder) |
|---|---|---|
| Scheune (3 S.) | 3/3 Seiten, 28 Artikel | 3/3, 28 |
| Lichtburg (7 S.) | **7/7**, 45 Artikel | **5/7** (2 Timeouts), 36 |
| Alexxanders (4 S.) | **3/4** + 1 leere Deckseite | **1/4** (2 Timeouts), 12 |

**Qualität, wo Vision durchkam, ist minimal besser** (Lichtburg S5: Steaks +
alle Beilagen/Saucen sauber unter „Beilagen" vereinheitlicht). **Aber die
Timeouts dominieren:** Bild + Reasoning sprengen 26–45 s/Seite, die Abdeckung
bricht ein — besonders bei dichten Seiten (Alexxanders nur 1/4).

## 3. Entscheidung

**Textmodus mit Koordinaten-OCR ist der Default für die Free-Modelle.**
Begründung: zuverlässige Vollabdeckung, schnell, kostenlos, Qualität nach
Runde 3 gut genug (Codes getrennt, Beschreibungen/Spalten erhalten, Set-Menüs
und Preisbasis strukturiert). Der marginale Qualitätsvorsprung von Vision wiegt
den Coverage-Verlust und die Laufzeit nicht auf.

Umgesetzt: `KITCHENLINK_OPENCODE_FREE=1` läuft jetzt standardmäßig im Textmodus
(`KITCHENLINK_LLM_SEND_IMAGES=0` als Vorbelegung). Vision bleibt explizit
anforderbar (`KITCHENLINK_LLM_SEND_IMAGES=1`) — sinnvoll erst mit einem
schnelleren/verlässlicheren (ggf. bezahlten) Vision-Modell oder deutlich
höheren Seiten-Timeouts.

## 4. Verbliebene Politur (weiterhin abnehmender Ertrag)

- **Set-Menü-Gang-Reste:** In der Draft-Ansicht erscheinen neben dem korrekten
  Menü-Eintrag noch preislose Gang-Fragmente. Ursache genauer eingegrenzt: im
  KI-Modus kommen die `unpricedCandidates` weiterhin aus dem LOKALEN Parser
  (`localParseResult.unpricedCandidates`), nicht aus dem KI-Ergebnis — sie
  mischen sich in den Draft. Sauberer wäre, im KI-Modus die KI-eigene
  Unpriced-Ableitung zu nutzen oder die lokalen Kandidaten zu unterdrücken.
  Sie sind preislos → werden nicht veröffentlicht, also kosmetisch.
- Vereinzelte Streupreise, Kategorienschnitt.
- Rest-Nichtdeterminismus (durch Retry entschärft).

## 5. Stand der Import-Qualitäts-Arbeit

Nach vier Runden ist der KI-Textpfad deutlich besser als der Regel-Parser und
kostenlos betreibbar. Die verbleibenden Punkte sind Politur mit abnehmendem
Ertrag. Empfehlung: bestätigten Stand als guten Zwischenpunkt festhalten, den
Regel-Parser als Offline-Fallback/Benchmark-Basis behalten und — sofern der
Nutzer keine weitere Runde will — zurück zum Produktfaden (reale
Scan-zu-Publish- und Cloud-Abnahmen, Tisch-Kontext im Gast-Web).
