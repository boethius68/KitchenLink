# Import-Qualität Runde 5: Vision zuverlässig gemacht (Timeouts + Parallelität)

**Stand:** 20. Juli 2026
**Auslöser:** Nutzer-Korrektur — der KI-Pfad soll das **Bild direkt** analysieren
(Vision), reine OCR reicht nicht. Die Vision-Timeouts aus Runde 4 waren ein
Engineering-Problem, kein Grund für den Rückfall auf Textmodus.

## 1. Ursachenanalyse (gemessen, nicht geraten)

Direkte Latenzmessung realer Menüseiten gegen `big-pickle`:
`33–37 s pro Bildseite`, HTTP 200, korrekte Artikel. Dagegen die App-Deckel:

- **`URLSessionConfiguration.timeoutIntervalForRequest = 35 s`** (harter
  Netzwerk-Deckel) → korrekte 35-s-Antworten wurden abgeschnitten.
- **`timeoutIntervalForResource = 50 s`**, Wrapper-Timeouts 36 s / 22 s, im
  Seitenpfad 45 s / 26 s → der Retry war garantiert zu kurz.
- **Seiten liefen seriell** → eine 7-Seiten-Karte = ~4 min, für einen großen
  Testdurchlauf untragbar.

## 2. Umgesetzt

- **Timeouts großzügig:** URLSession `request 180 s / resource 300 s`;
  Seiten-Primär- und Retry-Timeout je `150 s`.
- **Seiten PARALLEL:** `parseSectionsWithLLMPageByPage` verarbeitet Seiten
  jetzt nebenläufig (max. `llmMaxConcurrentPages = 5` gleichzeitig, schont das
  Free-Gateway) über eine ausgelagerte, nebenläufigkeitssichere
  `parseSingleLLMPage`. Ergebnis wird in Seitenreihenfolge aggregiert;
  401/Auth-Fehler brechen sauber ab.
- **Vision ist wieder Default** (`KITCHENLINK_OPENCODE_FREE=1`); Textmodus nur
  noch Opt-in (`KITCHENLINK_LLM_SEND_IMAGES=0`).
- **Set-Menü-Reste beseitigt:** im KI-Modus werden die preislosen Kandidaten
  des LOKALEN Parsers nicht mehr in den Draft gemischt
  (`unpricedCandidates: usedLLM ? [] : …`). Das „Vorspeise"-Fragment ist weg.

## 3. Verifiziertes Ergebnis (Vision, keylos/kostenlos)

Alle Karten laufen **vollständig** durch (vorher mit Timeouts: Lichtburg 5/7,
Alexxanders 1/4):

| Karte | Vision jetzt | Qualität |
|---|---|---|
| Scheune (3 S.) | 3/3, 28 Artikel | Codes getrennt (Verdacht 0) |
| Lichtburg (7 S.) | 7/7, 46 Artikel | Spalten S5 komplett (Steaks + alle Beilagen/Saucen); Set-Menü S6 = ein Eintrag „Menü Lichtburg · 39,90", kein Fragment mehr |
| Alexxanders (4 S.) | 3/4 + 1 leere Deckseite, 25 Artikel | Codes 0, Deckseite übersprungen |

Code-in-Text-Verdacht über alle Karten: **0**. Gesamtlaufzeit für 3 Karten /
14 Seiten inkl. Build ~4 min (Seiten parallel). Komplette
`kitchenlinkTests`-Suite: **207 bestanden, 0 Fehlschläge**.

## 4. Rest (echte Kleinigkeiten)

- Vereinzelter Streupreis (z. B. Tiramisu 7,90 neben dem 39,90-Menü) — ein
  Modell-Einzelfehler, kein strukturelles Problem.
- Gelegentlicher Kategorienschnitt-Feinschliff.
- Nicht-Determinismus bleibt (durch Retry entschärft).

## 5. Stand: launchnah für den großen Testdurchlauf

Die Vision-Erfassung ist jetzt zuverlässig, sauber und schnell genug für einen
großen Testdurchlauf. Nächster sinnvoller Schritt: den echten Menü-Korpus des
Nutzers über `KITCHENLINK_REVIEW_MENUS=<Ordner> KITCHENLINK_OPENCODE_FREE=1
./scripts/run-import-review.sh` durchlaufen lassen (PDFs oder Bild-Unterordner),
Ergebnisse im Report prüfen und die verbliebenen Einzelfehler entlang echter
Vielfalt gezielt schließen.
