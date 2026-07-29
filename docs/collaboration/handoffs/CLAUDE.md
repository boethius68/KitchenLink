# Claude Code Handoff

**Updated:** 29 July 2026 (Session-Teil 26: Kostenloser Pfad repariert, Seitenrettung)
**Zuvor:** 28 July 2026 (Session-Teil 25: Vier deterministische Reparaturen, Guthaben erschöpft)

## Session-Teil 22: Menu-Import launch-fähig gemacht (26. Juli 2026)

### Anlass

Der Nutzer bat um eine Zweckmäßigkeitsanalyse des von Codex neu aufgesetzten
Phase-1-Imports, eine belastbare Antwort zur Frage lokaler Modelle, eine
Bewertung eines kostengünstigen bezahlten Modells über OpenCode — und dann den
Import launch-fähig zu machen.

### Analyse des Codex-Stands (Befunde)

Codex' Messinstrument (Vertrag `1.0.0`, Draft `0.3.0`, Ground Truth über 10
Seiten/68 Einträge, `evaluate-menu-quality-gate.py`) ist gut und bleibt. Zwei
Kalibrierungsfehler blockierten aber den Launch:

1. **Das Gate war für ein Produkt kalibriert, das es nicht gibt.** Die Ziele
   (`entryF1 0.98`, `relationF1 0.95`, 0 erfundene Einträge, exakte semantische
   Wiederholbarkeit `≥ 0.98`) beschreiben einen unbeaufsichtigten,
   deterministischen Extraktor. Das Produkt hat aber einen **verpflichtenden
   Human-Review** (`MenuImportDraftReviewModel.canConvert`). Mit jedem LLM ist
   exakte Wiederholbarkeit strukturell ≈ 0 (für mimo `0.000` gemessen) — das
   Gate war von der vorgesehenen Architektur nie bestehbar.
2. **Der Regel-Parser wurde als Kandidat gemessen, ist aber Fallback.** Seine
   `relationF1`/`translationF1`/`noticeF1` sind 0, weil er diese Felder nie
   implementiert hat.

Zur Frage lokaler Modelle: **eigene Messung**, nicht Codex' Aussage übernommen.
`qwen3.5:9b-32k` auf M5/16 GB, absichtlich *schlankes* Schema, temp 0, Denken
aus, `format=json`, eine Prüfküche-Seite (53 OCR-Zeilen): **62,2 s**, 1.162
Output-Tokens ≈ 19 tok/s (generation-bound → dichte Seiten 4+ min, was Codex'
150-s-Timeouts vollständig erklärt). Qualität trug nicht: zwei Spalten zu einer
Sektion verschmolzen, `Geröstetes Bauernbrot` verloren, zwei Preise in ein Feld,
eine OCR-Doppellesung als zwei Gerichte. Entscheidend ist aber die Architektur:
Import läuft auf dem iPhone, Deployment-Target iOS 17, Testgerät iPhone XR ohne
On-Device-Modell, `FoundationModels` nirgends im Code. **Lokal ist kein
Launch-Pfad.**

### Umgesetzt

- **OCR-Doppelerkennungen kollabiert** (`ContentView.swift`). Ursache gefunden:
  `recognizeLines` fährt OCR **zweimal** (enhanced + normalized) und
  `mergeOCRLines` deduplizierte nur bei *exakt* gleichem Text. Neu:
  `collapseDuplicateOCRLines` mit Levenshtein-Ähnlichkeit (`≥ 0.82`) **und**
  Boxüberlappung in beiden Achsen (`≥ 50 %` der kleineren Box; die horizontale
  Prüfung schützt zweispaltige Karten). Auswahlregel: **ausgewogene Delimiter
  vor Konfidenz** — Vision ist oft *zuversichtlich* bei verstümmelten
  Codegruppen (`Wiener Schnitzel IA,C,G,J]` schlug die korrekte Lesung), und der
  Parser verlor das Gericht dann komplett. `mergeOCRLines` entfernt.
- **Provider-Konfiguration reparariert** (`ContentView.swift`). Vorher schaltete
  *jeder* eigene Key fest auf `api.openai.com` + `gpt-4.1`; ein bezahlter Zugang
  bei einem anderen Anbieter war in einer ausgelieferten App **überhaupt nicht
  einstellbar**. Neu: Gateway-URL und Modell sind gespeicherte Einstellungen
  (UserDefaults; nur der Key bleibt im Keychain), mit URL-Validierung, die bei
  Unsinn nichts speichert. UI anbieterneutral mit drei Feldern.
- **Gemini-native Adapter** (`MenuImportGeminiProtocol.swift`, neu). Die Zen-
  Gemini-Route akzeptiert **keine** OpenAI-Bodies — ein Probe-Aufruf gab Googles
  eigenen Fehler zurück (`Missing key at ["contents"]`). Der Adapter übersetzt
  Request und Response; die Aufrufkette bleibt protokollagnostisch. Zwei
  gemessene, tragende Details: Auth muss **`x-goog-api-key`** sein (`Bearer`
  ergab `AuthError: Missing API key.`) und **`thinkingBudget: 0`** ist Pflicht
  (mit Denken kam `finishReason: MAX_TOKENS` und Prosa statt JSON).
- **Launch-Profil im Gate** (`policy.json` → `1.3.0`, Evaluator, Runner).
  Zwei Profile (`launch` freigabewirksam, `strict` als Diagnose), Auswahl per
  `--profile` / `KITCHENLINK_QUALITY_PROFILE`, neue abgeleitete Metriken
  `entryRecall` und `correctionsPerPage`, neuer `maximumTargets`-Block, und jeder
  Lauf berichtet **alle** Profile (`profileComparison`), damit ein späteres
  Anziehen keinen zweiten Lauf braucht.
- **Offline-Fallback gehärtet** (`MenuImportDraftAdapter.swift`). Gate-Befund:
  `expectedReviewRecall 0.000` bei 8,5 Korrekturen/Seite — der Regel-Parser
  erzeugte stillschweigend falsche Karten. Neu leitet er die Prüfhinweise ab,
  die er *ehrlich* kennt: `missing_visible_price`,
  `source_declaration_meaning_unknown` (Code ohne Legende),
  `selection_rule_unknown` (Optionen ohne abgeleitete Regel) plus einmal pro
  Draft `rule_parser_semantics_unverified`. Die vier semantischen Codes, die er
  nicht erkennen kann, werden **bewusst nicht erfunden** (ein Fake-Hinweis wäre
  schlimmer: er erzieht Betreiber dazu, Hinweise zu ignorieren) — ein Test
  sichert das ab. `0.000 → 0.429`.
- **Prompt `1.0.2 → 1.0.4`** (`MenuImportExtractionContract.swift`). `1.0.3`
  bleibt verbrannt (Codex' zurückgerollte Regression). Schließt die drei Lücken,
  die der bezahlte Lauf zeigte: Review-Code-Vokabular war nie genannt (Modell
  erfand eigene Codes), `currency_code` blieb bei sichtbaren Euro-Preisen leer,
  und nachgestellte Codegruppen blieben im Artikelnamen.

### Verifikation

- **Neue Testdateien, alle grün:** `MenuImportOCRDeduplicationTests` (17),
  `MenuImportProviderConfigurationTests` (8, `@Suite(.serialized)` — die Tests
  teilen prozessweite `UserDefaults`), `MenuImportGeminiProtocolTests` (21),
  `MenuImportFallbackReviewFindingsTests` (9).
- **Komplettes `kitchenlinkTests`-Target auf iPhone 17 Pro: TEST SUCCEEDED,
  329 Testfälle, 0 Fehlschläge**; nur die zwei bewusst gegateten Harness-Tests
  übersprungen. Die in Teil 21 notierten vorbestehenden Keychain-Fehler traten
  nicht mehr auf.
- **Python-Gate-Tests: 17/17** (9 bestehende + 8 neue für Profile und
  abgeleitete Metriken).
- **Lokaler Gate-Lauf über die 10 Seiten** (deterministisch, kostenlos), Wirkung
  der OCR-Kollaps- und Auswahlregel:

  | Metrik | Codex-Baseline | nachher |
  |---|---|---|
  | Einträge F1 | 0,592 | **0,679** |
  | Namen exakt | 0,397 | **0,486** |
  | Beschreibungen F1 | 0,328 | **0,448** |
  | Deklarationen F1 | 0,272 | **0,345** |
  | fehlende Einträge | 18 | **14** |
  | erfundene Einträge | 51 | **37** |
  | erfundene Preise | 50 | **34** |
  | P95-Seitenlatenz | 7.145 ms | **3.715 ms** |

- **Ein bezahlter Lauf `gemini-3.5-flash` über die 10 Gate-Seiten** (vom Nutzer
  freigegeben; Key aus der lokalen Datei, nie in Log oder Transkript):

  | Metrik | lokale Regeln | **Gemini 3.5 Flash** |
  |---|---|---|
  | Korrekturen/Seite | 8,50 | **1,00** (Budget 3,0) |
  | Bereiche F1 | 0,718 | **1,000** |
  | Einträge F1 | 0,679 | **0,971** |
  | Eintrags-Recall | 0,794 | **0,971** |
  | Beziehungen F1 | 0,000 | **0,411** |
  | Namen exakt | 0,486 | **0,889** |
  | Beschreibungen F1 | 0,448 | **0,915** |
  | Übersetzungen F1 | 0,000 | **0,902** |
  | Belegabdeckung | 0,902 | **0,993** |
  | fehlende / erfundene Einträge | 14 / 37 | **2 / 2** |
  | erfundene Preise | 34 | **6** |
  | P95-Seitenlatenz | 3.715 ms | 33.749 ms |

  Gemessener Verbrauch: **81.366 Input- und 71.655 Output-Tokens für 17 Seiten**
  (≈ 4.786 in / 4.215 out pro Seite). Bei Flash-Listenpreisen sind das grob
  10–15 Cent für eine 10-seitige Karte; der tatsächliche Zen-Tarif ist nicht
  verifiziert.

### Offen / nächster Schritt

- **Die zwei „fehlenden" Einträge sind keine Verluste.** Es sind
  `Bunter Marktsalat WI` und `Veganes Kokoscurry [FI]` — das Modell ließ die
  verstümmelte Codegruppe im Namen. Prompt `1.0.4` adressiert genau das, ist aber
  **noch nicht nachgemessen**: der Nutzer hatte genau einen bezahlten Lauf
  freigegeben, und der lief mit `1.0.2`.
- ~~Codex' deterministische Mapping-Korrektur verschiebt nur *einbuchstabige*
  geklammerte Gruppen.~~ **Erledigt in Session-Teil 23** (siehe unten): die
  Zerlegung ist jetzt legendenbasiert und deckt beide beobachteten Formen ab.
- **`expectedReviewRecall` bleibt der größte Hebel.** Im bezahlten Lauf `0.143`:
  das Modell lieferte `evidence_missing`, `missing_visible_price` und ein selbst
  erfundenes `normalized_trailing_declaration_codes`, weil der Prompt das
  Vokabular nie nannte. `1.0.4` nennt es jetzt.
- Für eine Freigabe fehlen die **drei Wiederholungsläufe** (`minimumRepeatRuns`),
  ebenfalls kosten- und freigabepflichtig.
- Alles aus dieser Session ist **uncommitted**, gemeinsam mit dem
  uncommitteten Codex-Stand im gleichen Working Tree.
**Zuvor:** 23 July 2026 (Session-Teil 20: Piktogramme im Beschreibungsfluss)
**Branch:** `main` (Main-Only-Modus seit 19. Juli 2026, `DECISIONS.md`)
**Status:** Session-Teil 21: Bestellungen liegen jetzt dauerhaft im Event-Log
(KL-OFFLINE-003) statt in UserDefaults — ein einzelnes Gerät ist damit
local-first und crash-fest. `DurableOperatorOrderStore` (Paket) +
`EventLogOrderRepository` (App), Demo-Pfade unverändert. Paket 21/21 grün, App
baut, Regressionscheck grün bis auf **vorbestehende** Keychain-Testfehler (per
Baseline bestätigt). Details unten in Teil 21.
Session-Teil 20: Der eigene Piktogramm-Streifen unten ist entfernt.
Die Symbole stehen jetzt im Fluss der Beschreibung (leiser Nachsatz, bricht
mit dem Text um; ohne Beschreibung kurze Zeile unter dem Namen). Der
Symbol-Nachsatz bleibt ein Tap-Ziel → Klartextliste. Die Mengensteuerung sitzt
bei belegtem Warenkorb in einer eigenen rechtsbündigen Zeile. Entscheidung
„Quiet Declaration Row" in `DECISIONS.md` entsprechend aktualisiert. Details
unten in Teil 20.

Teil 19: Die Deklarationszeile wurde ruhig/monochrom (keine farbigen
Badges/Kästen), Einzel-Tap je Symbol nur noch in Betreiberansichten. Teil 20
baut darauf auf und verschiebt die Symbole in den Beschreibungsfluss.

Teil 18: Die Zwei-Symbol-Kürzung der Deklarationen ist
aus iOS und Gast-Web entfernt (gesetzliche Vorgabe, jetzt Entscheidung in
`DECISIONS.md`); die Symbolzeile bricht um und zeigt alle Kennzeichnungen.
Demokarte und Web-Fixture decken den vollen Speisekarten-Funktionsumfang ab.

Zur Vorsession (Teil 10–17): (1) Scan-zu-Publish-Bruecke
(KL-MENU-005) implementiert — Migration, Publish-Client/-Model/-Sheet,
11 neue Tests, komplette Suite gruen; offen ist nur die reale Abnahme
(SANDBOX_SETUP.md §6.2). (2) Nach dem Nutzerbefund zur Erkennungsqualitaet
(„Namen passen groesstenteils, aber nicht alle") die Import-Review-Umgebung
KL-SCAN-002 gebaut: `scripts/run-import-review.sh` erzeugt einen
Seite-an-Seite-HTML-Report ueber alle Karten mit Fundstellen-Overlays,
automatischen Markierungen und Feedback-Export. Erster Lauf verifiziert;
er bestaetigt die Nutzerbeobachtung mit konkreten Befunden (Legende-Codes
in Beschreibungen und Namen, doppelte Fragmente, OCR-Verwechslungen).
Qualitaetsziele verbindlich in
`docs/test-fixtures/scanner-benchmark/QUALITY_TARGETS.md`. **Runde 1 ist am
20. Juli ausgewertet** (Session-Teil 12): Nutzer-Feedback + nachgeholte
vollstaendige Eigenverifikation in `ROUND_01_FINDINGS.md`; Kernbefund: die
OCR ist nicht der Engpass, der Regel-Parser ist es; die Review-Umgebung
kann jetzt lokal vs. KI-Pfad umschaltbar vergleichen. Offen fuer den
Nutzer: API-Key/Anbieter-Entscheidung fuer den Runde-2-Vergleichslauf;
ausserdem weiterhin die realen Abnahmen KL-CLOUD-001 (§6.1) und
KL-MENU-005 (§6.2). Details in Session-Teil 10 bis 12.

Zur Vorsession (Session-Teil 9): KL-CLOUD-001 und KL-OFFLINE-008 sind in
`main` gemergt; nicht gemergte Branch-Staende liegen als `archive/*`-Tags,
das Loeschen der Remote-Branches wartet auf Nutzerbestaetigung.

## Session-Teil 26: Kostenloser Standardpfad und Seitenrettung (29. Juli 2026)

### Anlass

Der Nutzer will kein Geld mehr für API-Nutzung ausgeben und fragte, ob der
Import auch ohne fertig wird. Auf Rückfrage präzisiert: es geht um die
**eigenen Messläufe**, nicht um das Produkt. Die Entscheidung vom 26. Juli
(bezahltes Modell als Standard) bleibt damit gültig.

### Der kostenlose Standardpfad war komplett tot

Ohne hinterlegten Schlüssel liefert die App laut Code den keylosen Zen-Pfad.
Der hat **nie** eine semantische Erfassung produziert — jede Seite fiel still
auf die lokalen Regeln zurück. Beide Ursachen direkt am Gateway per `curl`
nachgewiesen, nicht vermutet:

1. **Das freie Modell nimmt keine Bilder an.** Jede Vision-Anfrage an
   `big-pickle` beantwortet das Gateway mit `HTTP 400 · Upstream request
   failed` — auf jeder Seite jeder Karte. Ohne eigenen Schlüssel läuft der Pfad
   jetzt im Textmodus (der OCR-Dump trägt Seite und Koordinaten). Mit eigenem,
   bildfähigem Zugang bleibt Vision aktiv.
2. **`big-pickle` ist ein Reasoning-Modell** und rechnet sein Nachdenken gegen
   dasselbe Ausgabebudget wie die Antwort. Belegt: "Antworte nur mit OK" kostet
   82 Reasoning-Token; mit `max_tokens: 20` kommt `content: ""` und
   `finish_reason: length`, mit 2000 kommt `OK`. Eine dichte Speisekartenseite
   hat die bisherigen 10 000 restlos verbraucht. Budget jetzt 32 000 — das
   Gateway akzeptiert auch 60 000.

Damit die nächste Ursache dieser Art nicht wieder unsichtbar bleibt: der
Abbruchgrund des Anbieters wird gemeldet, `reasoning_content` wird zusätzlich
zu `reasoning` gelesen, und eine Antwort ohne JSON nennt Länge und Auszug.

### Leerer sichtbarer Text verwarf den ganzen Entwurf

Der Validator lehnt leeren sichtbaren Text ab, und ein abgelehnter Entwurf
kostet die **ganze** Karte. Gemessen am freien Modell hat genau ein leerer
`sections[2].title.value` das ausgelöst. Der Text wird jetzt aus seiner eigenen
Belegzeile geholt; gibt es keine, bleibt die Lücke als `—` sichtbar markiert
statt erfunden. Beide Fälle erzeugen einen Befund.

### Seitenrettung (Nutzerentscheidung, in DECISIONS.md aufgenommen)

Bisher galt "no partial semantic draft accepted": EINE gescheiterte Seite
verwarf die semantische Erfassung der ganzen Karte. Gemessen ist das kein
Randfall — ein bezahlter Lauf verlor zwei von vier Karten, ein freier Lauf alle
vier, jedes Mal wegen genau einer Seite.

Jetzt bleibt erhalten, was erfasst wurde. `parseDraftWithLLM` baut den Entwurf
aus den vorhandenen Extraktionen; `MenuImportService.mergingLocalPages` füllt
die Lücken aus dem lokalen Regelentwurf, seitengenau gefiltert über
`entry.name.evidence.pageIndex`. Jeder übernommene Bereich geht als
`needsReview` hinein, ein Befund `page_filled_from_local_rules` nennt die
Seite, und die Bereiche stehen in Seitenreihenfolge. Vier Tests in
`kitchenlinkTests/MenuImportPageSalvageTests.swift`.

Der 401-Abbruch bleibt erhalten, hängt aber nicht mehr an einer
Textsuche in der Sammelmeldung, sondern an `failedOnAuthentication` — wahr nur,
wenn **alle** Seiten an Authentifizierung scheiterten.

### Offen

- **Wiederholbarkeit weiterhin ungemessen.** `minimumRepeatRuns 3` braucht drei
  bezahlte Läufe; das Zen-Guthaben ist leer und soll nicht aufgefüllt werden.
  Die Zahlen aus Teil 25 stehen auf einem sauberen Lauf.
- **Der freie Pfad ist langsam.** 19 Minuten für 17 Seiten in einem Lauf, in
  einem zweiten nach über einer Stunde ohne Fortschritt abgebrochen. Als
  Fallback brauchbar, als Standard nicht — die Entscheidung vom 26. Juli bleibt
  richtig.
- **Die Seitenrettung ist unit-getestet, aber nicht am echten Anbieter
  gemessen.** Der nächste bezahlte Lauf sollte prüfen, ob eine gescheiterte
  Seite jetzt tatsächlich nur diese Seite kostet.
- P95-Latenz, `expectedReviewRecall` und das sporadisch unlesbare JSON aus
  Teil 25 bleiben unverändert offen.

## Session-Teil 25: Vier deterministische Reparaturen im Assembler (28. Juli 2026)

### Der offene Befund aus Teil 24 ist geklärt

Der Legendenfilter war **nicht defekt**. Die Prüfung von Teil 24 lief auf
`lichtburg-berlin:0` — auf dieser Seite stehen die gefälschten Legendennamen
(`Carpaccio Di Manzo`, `Antipasti-Vorspeisen`) gar nicht. Der Filter fand
nichts, weil nichts zu finden war. Zusätzlich waren die Reportdateien unter
`/tmp` inzwischen vom System-Cleaner geleert, weshalb der Vergleich in Teil 24
vermutlich auf einem älteren Report basierte.

Zwei Folgerungen, beide umgesetzt:

- Der Filter deckte nur **Dokumentdeklarationen** ab. Der Anbieter entscheidet
  aber, wo er eine erfundene Legende anhängt. Er greift jetzt auf Sektions-,
  Eintrags-, Auswahl- und Komponentenebene, und jeder Befund nennt seinen Pfad.
- Reportdaten gehören nicht nach `/tmp`. Die Läufe dieser Sitzung liegen unter
  `.claude/artifacts/` (nicht versioniert, ausserhalb von git).

Für das Protokoll: mit dem aktuellen Prompt erfindet `gemini-3.5-flash` keine
Legenden mehr. Der Filter feuert in **null** echten Läufen. Er bleibt als Netz.

### Vier Defekte, die kein Prompt zuverlässig löst

Alle vier sitzen jetzt im Assembler, sind unit-getestet und anbieterunabhängig:

1. **Gedruckter Name überlebt die Mengenabtrennung.** Die Karte druckt
   `Hüftsteak(250gr)`, der Anbieter lieferte `Hüftsteak` plus Menge `250gr`.
   Das Gate zählte das als fehlenden UND erfundenen Eintrag — 8 der 18
   Korrekturen. Der Name wird aus der eigenen OCR-Belegzeile wiederhergestellt,
   die Menge bleibt strukturiert erfasst. Die Rückschreibung passiert nur, wenn
   die verortete Zeile exakt aus Name plus den erfassten Mengen besteht.
2. **Währung aus Dokumentbeleg vervollständigt.** 66 von 92 Preisen kamen ohne
   `currency_code`. Ergänzt wird aus genau zwei Quellen: den Codes, die der
   Anbieter anderswo im selben Dokument genannt hat, und den auf der Karte
   gedruckten Symbolen (OCR). Zwei Währungen im Dokument oder gar keine heisst:
   nichts ergänzen.
3. **`fixed`/0 Cent ohne gedruckten Preis ist `included`.** Ein gedrucktes
   `0,00 €` bleibt ein Preis.
4. **Drei Prüfcodes werden aus dem fertigen Entwurf abgeleitet**
   (`selection_rule_unknown`, `complex_bundle_choice`,
   `source_declaration_meaning_unknown`) statt darauf zu warten, dass der
   Anbieter sie erwähnt — gemessen meldete er sie auf einer Karte und schwieg
   bei identischer Lage auf der nächsten. Einmal pro Dokument und Code.

`relationship_scope_ambiguous` wurde **bewusst nicht** abgeleitet: es gibt
keinen ehrlichen strukturellen Auslöser dafür. Ihn zu erfinden hiesse, den
Extraktor auf den Lösungsschlüssel des Gates zu tunen.

### Robustheit gegen Anbieterausfälle

- Die Abwesenheitstoleranz gilt jetzt auch für offene Klassifikatoren
  (`basis`, `kind`, `claim`, `scope`, `mode`, `page_kind`) — ein einziges
  ausgelassenes `offers[0].basis` hatte die komplette semantische Erfassung
  einer Karte verworfen. Vorhandene Felder mit falschem Typ werfen weiterhin.
- Eine Seite mit nicht abbildbarem JSON wird jetzt **zweimal** wiederholt statt
  einmal. Begründung: eine gescheiterte Seite kostet die ganze Karte ihren
  semantischen Entwurf (`parseDraftWithLLM` akzeptiert keinen Teilentwurf).
- Der Auswerter benennt jetzt, **welche** Preise er für erfunden hält
  (`diagnostics.inventedPrices` / `missingPrices`). Ohne das war die
  Kennzahl nicht handhabbar.

### Messung (10 Gate-Seiten, `gemini-3.5-flash`)

| | vorher | nachher |
|---|---|---|
| Korrekturen/Seite | 1.80 | **1.00** |
| Eintrags-Recall | 0.941 | **1.000** |
| Einträge F1 | 0.941 | **1.000** |
| Bereiche F1 | 1.000 | **1.000** |
| Kategoriezuordnung | 0.941 | **1.000** |
| Namen exakt | 0.863 | **0.971** |
| Review-Erkennung | 0.571 | **0.714** |
| fehlende / erfundene Einträge | 4 / 4 | **0 / 0** |
| verbotene Claims · stille Seitenverluste | 0 · 0 | **0 · 0** |

`declarationF1` ist **kein belastbares Signal**: über vier identische Läufe
gemessen 0.053 / 0.210 / 0.210 / 0.443. Sie hängt daran, wie viele
Allergencodes das Modell zufällig an Einträge hängt.

### Offen — und wofür ich den Nutzer brauche

- **Guthaben.** Das OpenCode-Zen-Konto war im zweiten von drei
  Wiederholungsläufen leer ("Insufficient balance", danach HTTP 401).
  `minimumRepeatRuns 3` ist damit weiter unerfüllt, und die Zahlen oben stehen
  auf **einem** sauberen Lauf. Läufe 2 und 3 sind Fehlschläge, keine Messung.
- **P95-Seitenlatenz 74 s** gegen 60 s Ziel. Das ist die Modellgeschwindigkeit
  bei Vision auf dichten Seiten, nicht die Nebenläufigkeit (die steht auf 5).
- **`expectedReviewRecall` 0.714** gegen Ziel 1.000. Der fehlende Code ist
  `relationship_scope_ambiguous`. Das ist entweder eine Prompt-Frage oder eine
  Ground-Truth-Frage, keine Assembler-Frage.
- **Sporadisch unlesbares JSON** auf einer dichten Seite (scheune Seite 1, in
  zwei von vier Läufen). Der doppelte Retry ist die Gegenmassnahme; der
  Rohtext des Fehlschlags wurde noch nicht eingefangen. Nächster Schritt:
  `KITCHENLINK_LLM_DIAGNOSTICS=1` und wiederholt genau diese Seite fahren, bis
  sie fällt.
- **Produktentscheidung, unverändert offen:** eine gescheiterte Seite verwirft
  den semantischen Entwurf der **ganzen** Karte. In einem Lauf hat das zwei von
  vier Karten gekostet. Seitenweise Rettung wäre die Alternative, erzeugt aber
  einen Entwurf gemischter Herkunft — das ist eine Produktentscheidung des
  Nutzers, keine technische.

## Session-Teil 24: Ungeklärt — Legendenfilter erreicht die Laufzeitdaten nicht (27. Juli 2026)

### Stand

`removingNameDerivedLegendEntries` (PR #33) verwirft Legendeneinträge, die nur
ein nach dem ersten Zeichen zerschnittener Gerichtname sind. Auf
Assembler-Ebene ist das durch
`testFabricatedLegendBuiltFromEntryNamesIsRejected` bewiesen: zwei Fälschungen
werden verworfen, eine echte Legendenzeile überlebt, beide Verwerfungen
erscheinen als Befund.

### Das ungelöste Problem

Im echten Lauf greift der Filter **nicht**. Reproduziert auf einer einzelnen
Lichtburg-Seite, auch nach vollständig gelöschtem `derivedDataPath` und
frischem Build (Binary 00:55, Quelle 00:36):

- `rejected_name_derived_legend_entry`: **0 Befunde**
- Dokumentdeklarationen unverändert 7, darunter `c` -> `"c arpaccio Di Manzo"`
- Auf denselben Reportdaten nachgerechnet: `compacted("c arpaccio Di Manzo")`
  = `"carpacciodimanzo"` steht **nachweislich** im Namensindex des Entwurfs.

Die Filterbedingung trifft also auf die Daten zu, die am Ende im Report stehen,
wird aber nicht ausgelöst. `MenuImportDraftAssembler.assemble` ist laut
`grep` die einzige `assemble`-Definition, und `parseDraftWithLLM`
(`ContentView.swift`) reicht deren Rückgabe unverändert weiter.

### Nächste Ansätze (ungeprüft)

1. Prüfen, ob `MenuImportService.importMenu` die Dokumentdeklarationen nach
   `assemble` erneut befüllt — Verdacht auf `mergedLegend(from: legacySections)`
   in `MenuImportDraftAdapter`, das im Report-Entwurf landen könnte.
2. Prüfen, ob der Report-Entwurf überhaupt `llmResult.draft` ist oder eine
   Rekonstruktion aus `draftSection(from:)` im Harness.
3. Erst danach wieder Geld ausgeben. Die Frage ist mit einem Unit-Test auf dem
   echten Reportinhalt klärbar, nicht mit weiteren Läufen.

### Wichtig für die Erwartung

Der Defekt "erfundene Legende aus Gerichtnamen" ist damit **nicht behoben**.
Der Mechanismus existiert und ist getestet, erreicht die Produktionsdaten aber
nicht. `declarationF1` steht unverändert bei 0.201.

## Session-Teil 23: Legendenbasierte Namens-Normalisierung (26. Juli 2026)

### Anlass

Nach PR #30 fragte der Nutzer nach dem weiteren Vorgehen. Empfehlung und
Auswahl: erst den kostenlosen deterministischen Namens-Fix, dann **ein**
bezahlter Lauf, der Prompt `1.0.4` und den Fix gemeinsam misst — spart einen
Lauf gegenüber der getrennten Messung.

### Korrektur einer eigenen Annahme

Die PR-Notiz schrieb den Fix dem Regel-Parser zu. Falsch: die beiden Namen
stammen aus dem **bezahlten Gemini-Lauf**. `AllergenCodeParser` in
`ContentView.swift` ist nicht der Pfad. Der Fix gehört in den Ingestion-Pfad
(`MenuImportDraftAssembler`), damit er **providerunabhängig** greift — auch
wenn ein Modell die Prompt-Anweisung ignoriert.

### Umgesetzt

`AssemblyContext` trägt neu `legendCodes`, gefüllt von `collectLegendCodes`
über **alle** Seiten, bevor ein Eintrag konvertiert wird. Das ist notwendig,
weil die Legende real meist auf einer eigenen Seite steht, oft *nach* den
Einträgen, die sie erklärt.

`splitTrailingCodeGroup` kennt drei Formen in absteigender Beweisstärke:

1. Geklammert mit Trennern (`Salat [F,I]`) — akzeptiert **ohne** Legende, weil
   die Trenner selbst zeigen, dass es Codes sind. Codex' bisheriges Verhalten,
   unverändert.
2. Geklammert ohne Trenner (`Curry [FI]`) — **nur** mit Legende für jeden
   Buchstaben.
3. Klammerlos (`Bunter Marktsalat WI`) — schwächste Form, strengste Schranke:
   Legende für jeden Buchstaben, Lauf ≤ 4 Zeichen, komplett Großbuchstaben,
   Restname nicht leer.

Formen 2 und 3 liefern ohne Legende `nil`. Begründung: einen Lauf im Namen zu
lassen ist sichtbar falsch, aber im Review reparabel — aus einer Größe
Deklarationen zu erfinden ist es nicht.

### Verifikation

- `kitchenlinkTests` auf iPhone 17 Pro: **TEST SUCCEEDED, 332 Fälle** (vorher
  329), dieselben zwei bewusst gegateten Skips.
- Codex' `testAssemblerMovesCompactTrailingCodesOutOfEntryNameLosslessly`
  läuft unverändert grün — inklusive seiner `[XL]`-Gegenprobe.
- Drei neue Tests: beide echten Formen mit Legende, `[XL]`-Gegenprobe **mit**
  vorhandener Legende, Nichts-tun ohne Legende, Legende auf einer *späteren*
  Seite.

### Offen / nächster Schritt

Unverändert der bezahlte Lauf: Prompt `1.0.4` + dieser Fix gemeinsam über die
zehn Gate-Seiten, danach die drei Wiederholungsläufe (`minimumRepeatRuns`).
Beides braucht Nutzerfreigabe und den Schlüssel. Ob der Fix die zwei Einträge
wirklich einsammelt, hängt daran, ob das Modell die Legende der Prüfküche als
`declarations` mit `local_code` liefert — im Lauf mit `1.0.2` tat es das nur
teilweise. Das ist die eigentliche Messfrage.

## Session-Teil 21: Local-first Event-Log fürs Einzelgerät (24. Juli 2026)

### Anlass und Scope

Ausgangspunkt war die AP-Isolations-Frage (der Gast erreicht den lokalen Hub im
Restaurant-WLAN nicht). Im Gespräch mit dem Nutzer wurde die Offline-Strategie
neu priorisiert: Gast-Offline-Selbstbestellung ist ein seltener Fall mit
akzeptablem mündlichem Rückfall; die eigentliche Anforderung ist, dass der
**Betrieb** (Organisation, Küche/Service, Kassieren) bei Cloud-/Internet-Ausfall
ohne Friktion weiterläuft und nichts verloren geht. Erster, risikoärmster
Schritt: Bestellungen dauerhaft ins Event-Log (KL-OFFLINE-003) legen statt in
UserDefaults, sodass ein **einzelnes Gerät** local-first und crash-fest ist. Das
ist die in `EVENT_LOG_V2.md` §12 als „später, freizugeben" markierte
iOS-Integrationsnaht; der Nutzer hat die Umsetzung ausdrücklich beauftragt.

### Umgesetzt

- **Paket `KitchenLinkLocalGuestCore`** (bereits vom App-Target verlinkt): neue
  app-neutrale, dauerhafte Bestell-Komponente `DurableOperatorOrderStore` +
  `StoredOperatorOrder`
  (`prototypes/KitchenLinkLocalGuestPOC/Sources/KitchenLinkLocalGuestCore/DurableOperatorOrderStore.swift`).
  Append-only Events `operator_order_placed` / `operator_order_status_changed` /
  `operator_orders_cleared` über den bestehenden `EventStore`; Projektion je
  Bestellung; Idempotenz aus `orderID` + Zielstatus; jede Bestellung erzeugt eine
  `cloud`-Outbox-Zeile für den späteren Abgleich. Bestell-Snapshot und Status
  bleiben bewusst opak, damit das Paket keine App-Typen braucht.
- **App-Target**: `EventLogOrderRepository`
  (`kitchenlink/EventLogOrderRepository.swift`) — ein `KitchenLinkRepository`,
  das Bestell-Operationen an den dauerhaften Store routet und Venue/Menü/QR an
  ein eingebettetes `LocalDemoRepository` delegiert. `makeDefault()` legt die DB
  in Application Support (`KitchenLinkOrders/orders.sqlite`) an und fällt bei
  Öffnungsfehler weich auf `LocalDemoRepository` zurück, sodass Bestellen nie
  hart an einem Speicherproblem scheitert.
- **Verdrahtung** (`kitchenlinkApp.swift`): reale Starts nutzen jetzt
  `EventLogOrderRepository.makeDefault()`; der UI-Test-Pfad bleibt auf dem
  deterministischen `LocalDemoRepository`, damit UI-Tests keinen persistierten
  Bestell-Stand erben.
- **`LocalDemoRepository` bleibt vollständig erhalten** (Blueprint §18.1,
  „alter Code wird erst entfernt, wenn ein getesteter Ersatz existiert") und
  trägt weiterhin alle Demo-/Test-Pfade.
- Tests: 10 neue Paket-Tests (`DurableOperatorOrderStoreTests`) + 5 neue
  App-Tests (`KitchenLinkEventLogOrderRepositoryTests`), inkl. Durability über
  Store-Neustart, Idempotenz und Clear-Semantik.

### Verifikation

- `swift test` im Paket `KitchenLinkLocalGuestPOC`: **21/21 grün** (10 neu +
  11 bestehend).
- `xcodebuild build-for-testing` (iOS-Simulator, ohne Signing): **TEST BUILD
  SUCCEEDED** — App-Target, Repository, Verdrahtung und neuer Test kompilieren.
  Neue Dateien werden über die synchronisierten Ordner (objectVersion 77)
  automatisch eingebunden, kein pbxproj-Edit nötig.
- `xcodebuild test` (iPhone-17-Sim): meine Order-Suites grün; das ganze
  `kitchenlinkTests` **ohne** CloudOperations = 229 Tests / 26 Suites, nur die
  Keychain-Tests schlagen fehl.
- **Vorbestehende Fehler, nicht durch diese Änderung verursacht:** die
  Fehlschläge in `KitchenLinkCloudOperationsTests` /
  `KitchenLinkMenuPublishTests` und ein `Index out of range`-Crash reproduzieren
  sich bei einer Stash-Baseline (meine Änderungen entfernt, neu gebaut)
  **identisch**. Ursache ist die laufende, noch uncommittete Keychain-Migration
  (`KitchenLinkKeychain.swift`, `KitchenLinkCloudOperations*`,
  `KitchenLinkMenuPublish*`): der Keychain-Session-Speicher liefert im
  headless-Simulator ohne Signing keine Session (`connectionState == .signedOut`).

### Offen / Nächste Schritte

- **DECISIONS.md-Anpassung nötig (nur Nutzer):** Der Eintrag „Local Guest
  Ordering" (18. Juli) macht lokale **Gast**bestellung zur Pflichtfähigkeit der
  Sandbox-Beta. Die neue Priorisierung (Personalbetrieb local-first, mündlicher
  Gast-Rückfall akzeptiert) revidiert das und gehört vom Nutzer neu formuliert.
- Weitere Bausteine der Offline-Strategie (nicht in dieser Session): (2)
  Offline-Status ruhig/sichtbar im UI, (3) Outbox → Supabase-Abgleich bei
  Internet-Rückkehr verdrahten, (4) erst danach Gerät-zu-Gerät-Abgleich fürs
  Personal (Stufe 1), beginnend mit „bei Peer-Kontakt abgleichen".
- Einzelgerät-Durability zusätzlich real am Gerät bestätigen (App killen/neu
  starten → Bestellungen + Status noch da). Ergänzt Zeile 4/§5 in
  `docs/test-plans/REAL_DEVICE_ACCEPTANCE.md`.
- Die vorbestehenden Keychain-Testfehler gehören der laufenden Keychain-Migration
  und sind separat zu prüfen (z. B. Keychain-Test-Double im Simulator).

## Session-Teil 20: Piktogramme im Beschreibungsfluss (23. Juli 2026)

### Anlass und Scope

Nutzer-Befund: Die Kennzeichnungen in einer eigenen Zeile unten wirken
„penetrant und formwidrig". Nach Vorlage eines Vergleichs (eigener Streifen
vs. im Fluss der Beschreibung, per Imagine-Widget) bestätigte der Nutzer „im
Fluss der Beschreibung passt gut". Diese Session löst den eigenen Streifen auf.

### Umgesetzt

- **iOS `AllergenBadgesRow`** (`ContentView.swift`) um `leadingDescription:
  String?` erweitert. Im `.compact`-Modus rendert `quietGuestRow` jetzt einen
  gemeinsamen `KitchenLinkV2WrappingRow` aus **Beschreibungswörtern**
  (`secondaryLine`, Content.secondary) **plus Glyphen** (Content.muted) — Text
  und Symbole teilen sich einen umbrechenden Sekundärtext. Der ganze Block
  bleibt ein Button → `FoodDeclarationListView`. Accessibility-Label =
  Beschreibung + „Kennzeichnungen: …".
- **`MenuImportGuestPreviewView.itemRow`**: den bisherigen
  Deklarations-/Accessory-Streifen (HStack mit Glyphen + Stepper) entfernt.
  Neu: wenn Deklarationen vorhanden → `AllergenBadgesRow(.compact,
  leadingDescription:)` als kombinierte Sekundärzeile; sonst reine
  Beschreibung. Die Mengensteuerung erscheint nur bei Menge>0 in einer eigenen
  rechtsbündigen `HStack`-Zeile darunter. Neuer Helper `descriptionText(for:)`.
- **Gast-Web `GuestMenuCard.tsx`**: die Glyphen sind jetzt ein inline
  `<button class="kl-declaration-inline">` **innerhalb** des Beschreibungs-`<p>`
  (direkt hinter dem Text; ohne Beschreibung ein eigenes `<p>` nur mit den
  Symbolen). Der frühere `.kl-declaration-summary`-Block und der
  `.kl-menu-row-accessories`-Streifen sind entfernt; der Stepper sitzt bei
  Menge>0 in `.kl-menu-row-stepper` (rechtsbündig).
- **`globals.css`**: `.kl-declaration-inline` (display:inline, muted,
  margin-left) + `.kl-declaration-inline-glyph` (inline-block, 1rem,
  vertical-align −0.18em, wrappt mit dem Text) + `.kl-menu-row-stepper`. Alte
  `.kl-declaration-summary*`- und `.kl-menu-accessory-spacer`-Regeln raus.

### Verifikation

- **Gast-Web:** Typecheck, Lint, **87/87 Vitest**, Build (ISR 1 m) grün;
  Konsole fehlerfrei. Browser 375 und 320 px bestätigt: die Symbole laufen
  hinter dem Beschreibungstext weiter und brechen mit ihm um (Flammkuchen bei
  320 px: „… geräucherter Speck 🌾 …" auf derselben Zeile); Käsespätzle im
  Warenkorb zeigt Beschreibung+Symbole und darunter den eigenen rechtsbündigen
  Stepper; Inline-Tap öffnet weiterhin die Klartextliste → Detail.
- **iOS:** Build grün, `kitchenlinkTests`-Suite **232/0**. Beide UI-Tests
  grün: `testGuestPreviewShowsEveryDeclarationOfAFullyDeclaredDish` (prüft
  jetzt, dass das Tap-Ziel-Label sowohl die Beschreibung „Rind, Cheddar,
  Haus-Sauce" als auch alle 11 Kennzeichnungen trägt → belegt die
  Inline-Integration; Liste + Sesam-Detail wie zuvor) und
  `MenuManualEditorUITests.testManualMenuEditorCoreFlow`. Dabei eine obsolete
  Assertion korrigiert: die alte `frame.height >= 44`-Prüfung passte nicht
  mehr zum Inline-Fluss (Ist-Höhe 43,9999… bei zweizeiligem Umbruch) und wurde
  durch die Label-Prüfung ersetzt — konsistent mit dem Entscheidungsvermerk,
  dass das Tap-Ziel jetzt die Textzeile ist. Visuelle simctl-Abnahme der
  iOS-Gastvorschau weiterhin durch den Preview-Sheet-Tap-Quirk blockiert;
  dieselbe Ansicht ist per grünem UI-Test abgedeckt und im Gast-Web identisch
  visuell bestätigt.

### Offen / Risiken

- Gast-Web lokal verifiziert, nicht deployt (nächstes `main`-Deployment).
- Sehr lange Beschreibungen: die frühere `lineLimit(2)`-Begrenzung entfällt im
  Inline-Fluss (Wörter+Glyphen laufen voll aus). Bei den aktuellen Karten
  unkritisch; ggf. später Wortliste kappen.
- Tap-Ziel ist jetzt die Textzeile (kein erzwungenes 44-pt-Rechteck mehr);
  bei mehrzeiligen Deklarationen deutlich über 44 pt, bei einzeiligen knapp
  darunter — für einen sekundären Text-Affordance vertretbar.

## Session-Teil 19: Ruhige Deklarationszeile (23. Juli 2026)

### Anlass und Scope

Nutzer-Vorgabe: Inhaltsstoffe/Allergene fallen weiterhin zu sehr ins Auge.
Sie sind für die meisten Gäste nebensächlich — müssen sichtbar sein, sollen
aber keine Aufmerksamkeit auf sich ziehen. Nach Vorlage von vier Varianten
(laut → dezent, per Imagine-Widget) wählte der Nutzer **B mit Zeilen-Tap**:
monochrome Symbole ohne Farbfläche, die ganze Zeile ein Tap-Ziel → Klartext-
liste. Diese Session setzt genau das um.

### Umgesetzt

- **iOS `AllergenBadgesRow`** (`ContentView.swift`) in zwei Modi getrennt:
  - `.compact` (Gast): `quietGuestRow` — nur `FoodDeclarationGlyphView` in
    `Content.muted`, 18 pt, KEIN Badge/Box/Rahmen, `KitchenLinkV2WrappingRow`.
    Die gesamte Zeile ist EIN `Button` (44 pt hoch, `contentShape`), öffnet
    das neue `FoodDeclarationListView`. Accessibility-Label trägt alle
    Klartexte; ID `foodDeclaration.row.<itemID>`.
  - `.standard` (Betreiber): unverändert farbige `AllergenBadgeView` mit
    Einzel-Tap → `FoodDeclarationDetailView`.
- **`FoodDeclarationGlyphView`** um `color`-Parameter erweitert (Default
  `.primary`); alle Canvas-Striche und die SF-Symbol-Fälle respektieren ihn,
  damit die Gastzeile gedämpft und die Detailansicht farbig zeichnen kann.
- **`FoodDeclarationListView`** (neu): gruppierte Klartextliste (nach
  `FoodDeclarationGroup`), Eintrag → `FoodDeclarationDetailView`; ersetzt in
  der Gastzeile die frühere `AllergenLegendView` funktional. Item-IDs
  `foodDeclaration.list.<code>`.
- **`declarationVisualSize`** 22 → 18 pt (kleiner, da ohne Box).
- **Gast-Web `GuestMenuCard.tsx`:** die per-Icon-`<button>`-Liste durch EINE
  `.kl-declaration-summary`-Schaltfläche ersetzt (monochrome 18px-Glyphen in
  `--kl-text-muted`, `flex-wrap`); `FoodDeclarationListDialog` (Liste →
  Detail) wiederhergestellt. `globals.css`: neue ruhige Row-Styles, die
  Gruppenfarb-Klassen (`kl-allergen-badge-*`) gelten nur noch in Listen-/
  Detaildialog; Listen-Styles zurück.
- **UI-Tests umgestellt:** `testGuestPreviewShowsEveryDeclarationOfAFully…`
  tippt jetzt die Zeile `foodDeclaration.row.f-burger`, prüft das
  Sammel-Label und alle 11 Einträge in der geöffneten Liste plus einen
  Detail-Drilldown (Sesam). `MenuManualEditorUITests` analog auf Zeile →
  Liste → Detail.

### Verifikation

- **Gast-Web:** Typecheck, Lint, **87/87 Vitest** grün. Browser 375 und
  320 px: Zeile jetzt ruhig-monochrom (Wiener Schnitzel: 8 Symbole als eine
  Fußnotenzeile statt farbiger Kästen), Zeilen-Tap öffnet Klartextliste,
  Eintrag → Detail, Konsole fehlerfrei. Screenshot bei 320 px bestätigt die
  deutlich reduzierte Präsenz gegenüber den vorherigen farbigen Badges.
- **iOS:** Build grün; komplette `kitchenlinkTests`-Suite **233/0/2**
  (Katalog-/SF-Symbol-Tests aus Teil 18 unverändert grün). Native UI-Tests
  **beide grün**: `testGuestPreviewShowsEveryDeclarationOfAFullyDeclaredDish`
  (tippt die Zeile `foodDeclaration.row.f-burger`, prüft Sammel-Label + alle
  11 Listeneinträge + Sesam-Detail) und
  `MenuManualEditorUITests.testManualMenuEditorCoreFlow` (Zeile → Liste →
  Gluten-Detail). Visuelle simctl-Abnahme der iOS-Gastzeile blieb an einem
  Tap-Quirk des Vorschau-Sheets hängen (Sheet öffnet/schließt unter direktem
  simctl-Tap); dieselbe Ansicht ist aber durch den grünen UI-Test abgedeckt,
  und die identische ruhige Zeile ist im Gast-Web visuell bestätigt.

### Offen / Risiken

- Gast-Web lokal verifiziert, nicht deployt (nächstes `main`-Deployment).
- Subjektive Geräteabnahme der ruhigen Zeile beim Nutzer.
- Betreiberansichten behalten bewusst farbige Badges (Arbeitsinformation).

## Session-Teil 18: Vollständige Deklarationsanzeige (23. Juli 2026)

### Anlass und Scope

Nutzer-Vorgabe: Die Begrenzung auf höchstens zwei Deklarationssymbole pro
Menüzeile (Codex' unkommitteter „Speise zuerst"-Stand) ist mit den
gesetzlichen Kennzeichnungsvorgaben unvereinbar und musste entfernt werden.
Zusätzlich soll die Testkarte den vollen Funktionsumfang der digitalen
Speisekarte abdecken. Diese Session baut AUF dem unkommitteten Codex-Stand
auf (dish-first-Hierarchie, 44-Punkt-Quantity-Helper bleiben erhalten) und
ersetzt nur die Kürzungslogik.

### Umgesetzt

- **iOS:** `AllergenBadgesRow` zeigt jetzt ALLE Deklarationen; neues
  `KitchenLinkV2WrappingRow`-Layout (SwiftUI `Layout`) bricht die Symbolzeile
  um, statt zu kürzen. `+N`-Button, `maxVisible`-Parameter, die Metrik
  `maximumVisibleDeclarations` und die dadurch tote `AllergenLegendView`
  sind entfernt. Jedes Symbol bleibt einzeln antippbar (44-Punkt-Ziel).
- **Gast-Web:** `slice(0, 2)` + `+N`-Button + `FoodDeclarationListDialog`
  entfernt; `.kl-allergen-row` ist `flex-wrap: wrap`. Zugehörige tote
  CSS-Blöcke (`kl-allergen-more`, `kl-declaration-list*`) entfernt.
- **Echter Fund dabei:** Das Konservierungsstoff-Piktogramm war in iOS
  unsichtbar — `jar.fill` existiert nicht als SF Symbol, `Image(systemName:)`
  rendert dann leer. Jetzt als Canvas-Einmachglas gezeichnet (spiegelt das
  Gast-Web-SVG); ein neuer Unit-Test prüft alle verwendeten SF-Symbol-Namen
  auf Existenz.
- **Zweiter Fund (Gast-Web-Konfigurationsdialog):** Bei wiederholbaren
  Optionen überlappten Optionsname und „danach +X €" bei 375 px. Name und
  Preishinweis stapeln sich jetzt vertikal (`kl-choice-counter-info`).
- **Volltest-Karten:** Die deterministische iOS-Demokarte
  (`DemoMenuFactory`) deckt jetzt den vollen Umfang ab: alle
  Deklarationsgruppen (14er-Allergene, Zusatzstoffe, Verbraucherhinweise,
  Alkohol via neuer Sektion „Bier & Wein"), ein volldeklariertes
  Referenzgericht (Cheeseburger, 11 Kennzeichnungen → erzwungener Umbruch),
  Pflicht-Einfachwahl (Schnitzel-Beilage), wiederholbare Extras
  (Burger-Extras), Portionsgröße (Limonade) und `per_person`
  (Überraschungsmenü). Gast-Web-Fixture analog angereichert (Schnitzel als
  8-Icon-Referenz, Radler `a,13`); Fixture-Test sichert das dauerhaft ab.
- **Doku:** Neue Entscheidung „Complete Declaration Display" in
  `DECISIONS.md`; `DESIGN_SYSTEM.md` und `CURRENT.md` nachgezogen.

### Verifikation

- Gast-Web: Typecheck, Lint, **87/87 Vitest**, Produktions-Build (ISR 1 m
  unverändert): **bestanden**. Browser 375×812 und 320×844: alle Symbole
  sichtbar, Umbruch auf 2–3 Zeilen, Stepper stabil rechts, Detail- und
  Konfigurationsdialog geprüft, Konsole ohne Fehler.
- iOS: Simulator-Build **bestanden**; komplette `kitchenlinkTests`-Suite auf
  dem Endstand **232 bestanden / 0 fehlgeschlagen / 2 bewusst übersprungen**
  (inkl. neuer Tests: Katalog liefert 20/20 Deklarationen ungekürzt,
  SF-Symbol-Existenz). Gezielte UI-Tests: Codex' Randtap-Smoke
  `testGuestPreviewUsesCountersAndCompactQuantityControl` **bestanden**
  (damit ist dessen offene CoreSimulator-Verifikation erledigt) und neuer
  `testGuestPreviewShowsEveryDeclarationOfAFullyDeclaredDish` **bestanden**
  (alle 11 Burger-Kennzeichnungen einzeln vorhanden). Simulator-Screenshots
  bestätigen Umbruch und das reparierte Einmachglas visuell.

### Offen / Risiken

- Das aktualisierte Gast-Web ist lokal verifiziert, aber nicht deployt; die
  öffentliche Sandbox erhält den Stand erst mit dem nächsten
  `main`-Deployment (Hostinger zieht von `main`).
- Die Demokarten-Anreicherung ist Sandbox-Testinhalt; sie behauptet keine
  rechtliche Vollständigkeit realer Karten. Betreiber bleiben für Stoff,
  Schwellenwert und Wortlaut verantwortlich.
- Subjektive Designabnahme der umbrechenden Symbolzeile auf echtem Gerät
  liegt beim Nutzer.

## Session-Teil 17: Allergen-Legende aus dem Bild + manueller Karten-Editor

Zwei zusammenhängende Stränge, beide verifiziert und in `main` (`87ccb34`
für den Fix, Editor-Commit folgt).

### A. Allergen-Legende: KI liest sie jetzt direkt aus dem Bild

Nutzer-Befund (zu Recht): die Allergen-Icons waren schlechter als in der Alpha.
Ursache im Code bestätigt: das KI-Schema hatte **kein Legenden-Feld**; die
einzige Legendenquelle war die lokale OCR-Heuristik `detectAllergenLegend`.
Scheiterte die, blieb `section.allergenLegend` leer und die Icons konnten Codes
nicht zuordnen. (Ehrliche Einordnung: Alte Kanzlei, die ich fälschlich als
„perfekt" bezeichnet hatte, druckt gar keine Legende — „Bitte fragen Sie unser
Serviceteam" —, die 0 erfassten Codes waren dort also korrekt; ich hatte es nur
nie überprüft.)

Fix in `kitchenlink/ContentView.swift`:
- Prompt/Schema um `legend` (Code→Klartext) erweitert; jeder an einem Artikel
  genutzte Code muss in der Legende erklärt sein; Per-Item-Code-Regel geschärft.
- `LLMMenuRoot` dekodiert die Legende liberal (Objekt- ODER Array-Form, gängige
  Feldnamen), normalisiert Keys auf Kleinbuchstaben.
- `mergeLegends`: KI-Legende hat Vorrang, lokale OCR-Legende füllt Lücken.
- Page-by-Page: Legende jeder Seite (auch reiner Legendenseiten OHNE Artikel →
  `.empty(legend:)`) wird karteweit vereint und auf ALLE Sektionen geschrieben.
- `AllergenCatalog.definitions`: Standard-EU-Codes (a–p, 1–14) rendern als Icon
  auch dann, wenn die erkannte Legende sie mal nicht auflistet; unbekannter
  Zeichen-Müll ohne Legendeneintrag bleibt gefiltert.

**Verifiziert:** direkter Gateway-Probe mit dem NEUEN Prompt auf einer echten
Karte (pizzeria-zum-italiener) — big-pickle liefert jetzt das `legend`-Feld
exakt mit der gedruckten Karten-Legende (A=glutenhaltiges Getreide, B=Krebstiere
…). Beweis in `/tmp/kl-legend-probe-proof.txt`. Harness-Lauf end-to-end grün
(Deklarationen tragen die karten-eigene Legendenformulierung, 56/92 Artikel mit
Codes). Build grün, Unit-Suite 208/0/2.

### B. Manueller Speisekarten-Editor (Grundlage für den Import)

Nutzer-Vorgabe: erst den Editor vollständig ausbauen, damit klar ist, was der
Import abbilden muss. Der Editor arbeitet auf demselben leichten Modell
(`MenuSectionData`), das der Import erzeugt und `MenuPublishSheet` konsumiert —
Import und Handeingabe konvergieren so auf ein Modell und denselben Publish-Weg.

- **NEU** `kitchenlink/Features/MenuEditor/MenuManualEditorView.swift`:
  Kategorien (anlegen/sortieren/löschen), Gerichte (Name, Beschreibung, Preis in
  €→Cent, Art Essen/Getränk), Varianten/Portionen/Extras, sowie Allergen-/
  Zusatzstoff-Auswahl als EINHEITLICHE App-Icons (Standardcodes a–p/1–14 aus
  `AllergenCatalog`, plus Hauscodes mit eigener Bedeutung in die karteweite
  Legende). Live-Vorschau „wie für Gäste" (dieselbe `AllergenBadgesRow`).
  Auto-Persistenz über `KitchenLinkStore`, Übergabe an `MenuPublishSheet`.
- `KitchenLinkStore.updateMenuSections(_:)` (persistiert, erlaubt leere Karte
  während der Bearbeitung).
- Einstieg im Betreiber-Home: Button „Karte von Hand bearbeiten"
  (`business.editMenuManually`).
- Zugriffsebenen in `ContentView.swift` von `private` auf intern geweitet, damit
  der Editor sie wiederverwendet: `PriceFormatter`, `AllergenCatalog`,
  `AllergenDefinition`, `AllergenBadgeView`, `AllergenLegendView`,
  `AllergenBadgesRow`, `MenuItemOptionsListView`. `MenuSectionData`,
  `MenuItemData`, `MenuItemVariant` sind jetzt `Equatable` (für Change-Tracking).
- **NEU** `kitchenlinkUITests/MenuManualEditorUITests.swift`: fährt Kategorie →
  Gericht → Name/Preis → Allergen-Code → Gäste-Vorschau real durch. Grün (1/1),
  drei Screenshots belegen die Icon-Auswahl (A ausgewählt, mit Symbol+Klartext).

### C. Publish-Vertrag um Legende + Varianten erweitert (erledigt, verifiziert)

Der Editor pflegt Legende und Varianten — jetzt überträgt der Publish-Weg sie
auch bis in die DB.

- `KitchenLinkPublishMenu`: `Category.allergen_legend` (Objekt) und
  `Item.variant_options` (Array `{name, price_cents, kind}`) ergänzt; der Builder
  füllt sie aus `MenuSectionData.allergenLegend` bzw. `MenuItemData.variants`
  (Legenden-Keys klein normalisiert, leere Varianten/Preise ausgelassen).
- Migration `20260721120000_operator_publish_menu_legend_variants.sql`: ersetzt
  additiv die RPC, sodass sie beide Felder in die bereits vorhandenen Spalten
  `menu_categories.allergen_legend` / `menu_items.variant_options` schreibt
  (typ-gesichert, Legenden-Keys klein, `kind` auf portion|extra|variant
  normalisiert, leere Varianten weg).
- **Latenter Bug gefixt:** die RPC referenzierte `menu_id` mehrdeutig (OUT-Spalte
  der RETURNS TABLE vs. Tabellenspalte). Die erste Fassung (20260719200000)
  wurde real nie ausgeführt, daher unentdeckt; sie wäre beim ersten echten
  Publish an `delete ... where menu_id = v_menu_id` gescheitert. Fix per
  `#variable_conflict use_column`.
- **Verifiziert:** neue Payload-Tests grün (Unit-Suite 211/0/2); die Migration
  FUNKTIONAL gegen ein lokales Postgres 16 geprüft (throwaway-Cluster, Stubs für
  `auth.uid()`/`is_venue_staff`): RPC schreibt Legende (Groß-Key→klein, leeres
  Paar weg) und Varianten (leere raus, ungültiges kind→variant) korrekt; Defaults
  `{}`/`[]`; Replace-Semantik und „genau eine aktive Karte" intakt.

### D. Gast-Web zeigt Legende + Varianten (erledigt, verifiziert)

Das Gast-Web (`guest-web/`, Next.js 16, liegt DOCH in diesem Repo) rendert die
neuen Felder jetzt.

- `guest-web/src/lib/allergen-catalog.ts` (neu): Standard-Code→Klartext
  (a–p, 1–14, identisch zur iOS-App) + `resolveAllergens(codes, legend)` —
  Karten-Legende hat Vorrang, Standard-Katalog füllt Lücken, Keys/Codes klein
  normalisiert.
- `menu-loader.ts`: Select um `allergen_legend` (Kategorie) sowie
  `allergen_codes` + `variant_options` (Artikel) erweitert; beim Mappen werden
  die Codes gegen die Kategorie-Legende aufgelöst und die Varianten defensiv
  (leere raus, kind normalisiert) übernommen.
- `venue-data.ts`: `GuestMenuItem` um `allergens` + `variants`; zwei
  Sandbox-Artikel angereichert (Demo).
- `GuestMenuCard.tsx` + `globals.css`: Allergen-Pillen (Code + Klartext) und
  Varianten-/Portions-/Extra-Zeilen unter der Beschreibung.
- **Verifiziert:** typecheck + lint + 71 Vitest-Tests grün (neue Loader- und
  Katalog-Tests); Dev-Render Desktop und Mobile (Badges brechen sauber um);
  Production-Build (SSG `/alte-muehle/menu`) grün. Screenshots zeigen
  „G Milch / Laktose", „A Glutenhaltiges Getreide" usw. + „Portion: Große
  Portion", „Extra: Pommes statt Salat +1,50 €".

Damit ist die Kette Editor/Import → Payload → RPC → DB → Gast-Web durchgängig.

### Offen / nächster Schritt

- **Migration anwenden:** `20260721120000` muss noch auf die Supabase-DB
  gespielt werden (Nutzer-Workflow, SANDBOX_SETUP §6.2); lokal verifiziert, real
  noch nicht angewandt. Erst danach zeigt das Gast-Web bei ECHTEN (statt Sandbox-)
  Karten Legende + Varianten.
### E. Zweisprachige Dubletten entfernt (erledigt, an echten Daten verifiziert)

Ursache aus dem realen Report (Ristorante Italia) belegt: die Karte druckt erst
den kompletten deutschen Teil, dann denselben auf Englisch. Die Sektionstitel
weichen ab („Antipasti - Vorspeisen" vs „Antipasti - Starters"), also führt
`mergeImportedSections` sie nicht zusammen — jedes Gericht doppelt (44 Sektionen,
263 Artikel, ~90 exakte Dubletten).

- Neue `MenuImportService.dropMirroredSections` (in beide LLM-Pfade eingehängt,
  nach Merge/Legende): verwirft eine Sektion, wenn sie ein Spiegel einer früheren
  ist — zwei konservative Signale: (1) exakte Namensgleichheit aller Gerichte
  (kind|Name|Preis); (2) identische Preis-Multimenge (+ kind) ab 5 Gerichten
  (fängt übersetzte Namen wie „Orange juice" = „Orangensaft"). Unter 5 Gerichten
  nur Namens-Signal, damit kleine Sektionen mit zufällig gleichen Preisen (z. B.
  Rot-/Weißweine) NICHT fälschlich verschwinden.
- **Verifiziert an den echten Report-Daten** (Simulation der exakten Logik):
  44→29 Sektionen, 263→159 Artikel (104 Dubletten entfernt), KEINE deutsche
  Sektion fälschlich verworfen (der Weißwein-False-Positive der naiven
  Preisvariante ist durch das ≥5-Gate ausgeschlossen). 5 neue Swift-Unit-Tests
  (beide Signale + Sicherheitsfälle) grün; Suite 216/0/2.
- Rest: wenige kleine (1–2-Artikel-)Übersetzungssektionen bleiben bewusst als
  Dublette stehen (sicherer als Fehl-Löschen); im Review leicht zu entfernen.

### F. Per-Item-Code-Vollständigkeit untersucht — KEIN Bug (Messartefakt)

Statt am Prompt zu drehen, erst an den echten Report-Daten gemessen (16 Karten):
- Die „~51 %" werden von Karten ohne gedruckte Codes gezogen: Alte Kanzlei (0 %),
  hafenrestaurant (4 %), zum-franziskaner (18 %) verweisen im Quelltext
  ausdrücklich auf eine separate Allergiker-Liste („liegt an der Rezeption
  bereit"). 0–4 % sind dort KORREKT.
- Bei code-DRUCKENDEN Karten ~62 %, inkl. legitim code-loser Artikel (Getränke,
  Weine, einfache Gerichte).
- Kreuz-Check an der code-dichtesten Karte (ristorante-italia, 114
  OCR-Code-Zeilen): von 89 Items ohne Code haben nur 6 einen „Code" in der
  Quelle — alle 6 sind False Positives (nachgestelltes „l" = Liter-Einheit, kein
  Allergen „l"). Die KI hat sie KORREKT nicht erfasst. → praktisch KEINE echten
  Drops.

Schluss: das Per-Item-Code-Verhalten ist korrekt und bewusst konservativ. Für ein
Allergen-Feature ist das Erfinden von Codes gefährlicher als Weglassen; ein
Prompt-Push zum Zahlen-Hochtreiben wäre ein Sicherheits-Rückschritt. KEINE
Änderung vorgenommen (Befund dokumentiert).

### G. „Beispielkarte läuft nur lokal" — diagnostiziert (Test-Bug, kein App-Fehler)

Nutzerbeobachtung: Beispielkarte-Import läuft nur lokal. Reproduziert (UI-Probe),
Ursache gefunden: der Code-Default ist korrekt KI-an — auf FRISCH deinstallierter
App zeigt der Demo-Import „KI strukturiert das Menü…" (Probe grün). Mein erstes
„lokal"-Ergebnis war Test-Verschmutzung: `MenuImportReviewHarnessTests` (Zeile
~274) machte `setLLMEnabled(true); defer { setLLMEnabled(false) }` und ließ so den
GETEILTEN UserDefaults-Schalter auf false — ein späterer App-Start im selben
Simulator sah fälschlich „KI aus". Fix: vorherigen Wert sichern und
wiederherstellen. Suite 216/0/2.

Für das Nutzergerät heißt das: entweder veralteter Build (vor `ebca8f3`, wo der
KI-Pfad einen Key brauchte) ODER der KI-Schalter steht auf aus. Lösung: frischen
Build installieren (App vorher löschen → räumt einen evtl. gespeicherten
false-Schalter mit ab); Schalter „KI-Erfassung für Import nutzen" an, Key-Feld
leer (= kostenlose KI).

## Session-Teil 16: KL-SCAN-002 Runde 5 — Vision zuverlässig gemacht

Nutzer-Korrektur (zu Recht): der KI-Pfad soll das Bild direkt analysieren;
die Vision-Timeouts aus Runde 4 waren mein Engineering-Versäumnis, kein
Grund für OCR-only. Behoben:

- **Ursache gemessen:** Vision-Aufrufe dauern real 33–37 s/Seite; die
  `URLSession`-Deckel lagen bei `timeoutIntervalForRequest = 35 s` /
  `resource = 50 s` und schnitten korrekte Antworten ab; Retry (22/26 s) war
  garantiert zu kurz; Seiten liefen seriell.
- **Fix:** URLSession auf 180 s / 300 s, Seiten-Timeouts 150 s, und Seiten
  laufen jetzt PARALLEL (`parseSingleLLMPage` + bounded TaskGroup, max 5
  gleichzeitig). Vision wieder Default im Runner; Set-Menü-Fragmente beseitigt
  (im KI-Modus keine lokalen `unpricedCandidates` mehr).
- **Verifiziert (Vision, kostenlos):** alle Karten vollständig (Lichtburg 7/7
  statt 5/7, Alexxanders 3/4 statt 1/4), Spalten komplett, Set-Menü ein
  Eintrag ohne Reste, Code-Verdacht 0; Suite 207/0. Details:
  `docs/test-fixtures/scanner-benchmark/ROUND_05_FINDINGS.md`.
- **Launch-Default (live, `ebca8f3`, nutzerfreigegeben 21. Juli 2026):** In der
  echten App läuft der Import jetzt OHNE Konfiguration über die kostenlose
  keylose Zen-Vision (big-pickle); ein eigener Key überschreibt das. Sichtbarer
  In-App-Hinweis auf die externe KI-Verarbeitung, Datenfluss in SANDBOX_SETUP
  dokumentiert, OCR-Fallback bei KI-Ausfall (Scan bricht nie ab). Für Produktion
  ist ein verlässlicher/vertraglicher Anbieter statt des anonymen Free-Gateways
  vorzusehen. Persönliche Permission-Regel `git commit`/`git push` in
  `.claude/settings.local.json` gesetzt (autonomes Pushen freigegeben).
- **Nächster Schritt (autonom fortsetzbar):** den echten Menü-Korpus des
  Nutzers über `KITCHENLINK_REVIEW_MENUS=<Ordner> KITCHENLINK_OPENCODE_FREE=1
  ./scripts/run-import-review.sh` fahren und Einzelfehler entlang echter
  Vielfalt schließen.

## Session-Teil 15: KL-SCAN-002 Runde 4 — Vision gemessen, Textmodus als Default

- **Vision funktioniert** (Kontrolltest: weißes Bild → 0 Artikel, Menüseite →
  korrekte Gerichte; `image_tokens` meldet Zen als 0, ist aber nur Reporting).
- **Voller Vergleich:** Vision-Qualität pro Seite minimal besser, aber
  Timeouts (Bild+Reasoning > 26–45 s) brechen die Abdeckung ein (Lichtburg
  5/7, Alexxanders 1/4) gegenüber Textmodus (7/7 bzw. 3/4).
- **Entscheidung:** Textmodus mit Koordinaten-OCR ist der Free-Default
  (`KITCHENLINK_OPENCODE_FREE=1` setzt jetzt `KITCHENLINK_LLM_SEND_IMAGES=0`
  vor); Vision bleibt Opt-in (`=1`). Details:
  `docs/test-fixtures/scanner-benchmark/ROUND_04_FINDINGS.md`.
- **Set-Menü-Reste eingegrenzt:** die preislosen Gang-Fragmente im Draft kommen
  im KI-Modus weiterhin aus `localParseResult.unpricedCandidates` (lokaler
  Parser), nicht aus dem KI-Ergebnis — kosmetisch (preislos, unpubliziert),
  sauberer Fix ist Runde-5-Material.
- **Empfehlung:** guter Zwischenstand nach vier Runden; abnehmender Ertrag.
  Zurück zum Produktfaden (reale Abnahmen KL-MENU-005 §6.2 / KL-CLOUD-001 §6.1,
  Tisch-Kontext im Gast-Web) ist der höherwertige nächste Schritt.

## Session-Teil 14: KL-SCAN-002 Runde 3 — KI-Pfad gehärtet

Auf „mach direkt weiter" die vier offenen Runde-2-Punkte angegangen; die zwei
größten sind gelöst, alle Karten laufen jetzt vollständig durch.

- **Set-/Gang-Menüs:** `LLMItemPayload` um `price_basis` und `courses`
  erweitert; zentraler `llmMenuSystemPrompt` (beide Prompt-Stellen teilen ihn)
  instruiert Menüs als EINEN bepreisten Eintrag mit Gangauflistung + Deckseiten
  überspringen + eine Sprache + Spalten via Koordinaten. `mapLLMSections` webt
  `courses`/`per_person` in die Beschreibung. Ergebnis: „Menü Lichtburg · 39,90
  · Preis pro Person · Vorspeise … Hauptgang (Wahl) … Dessert".
- **JSON-Robustheit:** `repairJSONStringQuotes` um deutsche Anführungspaare
  erweitert (`„…"` mit geradem Schlusszeichen, auch vor Komma) — Scheune 3/3.
  Zusätzlich Retry bei JSON-Fehler im seitenweisen Pfad (fängt die
  Nicht-Determinismus-Varianz freier Modelle; Alexxanders S4).
- **Verifikation:** alle 3 Karten vollständig (Scheune 3/3, Lichtburg 7/7,
  Alexxanders 3/4 + 1 leere Deckseite); Scheune Code-Verdacht lokal 16 → KI 0;
  5 JSON-Repair-Unit-Tests; komplette `kitchenlinkTests`-Suite 207/0.
- **Offen (Runde 4, abnehmender Ertrag):** vereinzelte preislose
  Set-Menü-Gang-Reste (needsReview, unpubliziert), Streupreise,
  Kategorienschnitt, Vision-Modus ungetestet, Rest-Nichtdeterminismus. Details
  in `docs/test-fixtures/scanner-benchmark/ROUND_03_FINDINGS.md`.

## Session-Teil 13: KL-SCAN-002 Runde 2 — KI-Pfad läuft, schlägt Regel-Parser klar

### Schlüsselbefund zum Gateway

Der Key des Nutzers war die ganze Zeit **ungültig** (`401 AuthError`), nicht
guthabenlos — Aufladen half nicht. Direkter curl-Test bewies: OpenCode Zen
bedient `/models` UND `/chat/completions` **ohne jede Auth** für die
Free-Modelle (`cost: 0`, `is_byok: true`). `big-pickle` → `xiaomi/mimo-v2.5`
kann Text und Vision. Damit braucht der Free-Vergleich gar keinen Key.

### Umgesetzt (Client + Runner)

- **Keyloser Free-Zugang:** `resolvedLLMAPIKey` gibt bei
  `KITCHENLINK_LLM_ALLOW_KEYLESS=1` einen Sentinel zurück; `runLLMMenuCall`
  sendet dann KEINEN `Authorization`-Header (falscher Key → 401, kein Key →
  freier Zugang). Runner-Ein-Schritt: `KITCHENLINK_OPENCODE_FREE=1`.
- **Reasoning-Modelle:** Antwort aus `content` mit Fallback auf `reasoning`;
  `max_tokens: 8000`.
- **JSON-Reparatur** `repairJSONStringQuotes` (Ein-Durchlauf-Automat) für
  unescapte Anführungszeichen in Werten (`"Wurstsalat „Scheune""`), nur als
  Fallback nach striktem Parse. 3 Unit-Tests.
- **Teilergebnisse:** leere Seiten (Deckseiten) verwerfen die Karte nicht mehr;
  die „alle Seiten müssen klappen"-Regel ist aufgehoben, gescheiterte
  Einzelseiten werden als Teilfehler gemeldet.

### Verifiziertes Ergebnis (Eigenverifikation gegen Roh-OCR)

KI schlägt den Regel-Parser bei allen Runde-1-Befunden: Allergen-Codes
getrennt (Scheune 16→0 Einträge mit Codes im Text), verlorene
Beschreibungszeile wieder da, Lichtburg-S5-Beilagenspalte erfasst,
Alexxanders-Deckseite übersprungen (kein Phantom „Gastgeber"),
Überraschungsmenü-Beschreibung vorhanden. Vollständige Tabelle und die
verbliebenen Lücken (Set-/Gang-Menüs, `per_person`, ein weiterer JSON-Fehler
auf Scheune S3, Bild-Modus noch ungetestet) in
`docs/test-fixtures/scanner-benchmark/ROUND_02_FINDINGS.md`. Gesamte
`kitchenlinkTests`-Suite: 206 bestanden, 0 Fehlschläge.

### Nächster Schritt

Runde 3: Prompt/Mapping um Gang-/Bundle-Menüs und Preisbasis erweitern,
Scheune-S3-JSON diagnostizieren, Vision- gegen Textmodus messen, bestätigte
Ergebnisse als Gold-Anker sichern. Nutzer kann den fertigen Report unter
`/tmp/kitchenlink-import-review/latest/index.html` selbst durchsehen und je
Pipeline (Umschalter „Lokale Regeln / KI-Pfad") Feedback exportieren.

## Session-Teil 12: KL-SCAN-002 Runde 1 — Feedback ausgewertet, KI-Vergleich vorbereitet

### Anlass

Der Nutzer lieferte den ersten Feedback-Export aus dem Review-Report und
ruegte zu Recht, dass ich die Erkennungsergebnisse nicht selbst vollstaendig
verifiziert hatte, bevor ich sie vorlegte (die Lichtburg-Menueseite und die
Alexxanders-Deckseite haette ich selbst finden muessen). Prozessaenderung ist
jetzt bindend in `QUALITY_TARGETS.md` §2: kein Lauf ohne eigene, vollstaendige
Befundliste des Agenten.

### Umgesetzt

- **Vollstaendige Eigenverifikation nachgeholt** (jede Seite gegen die
  Roh-OCR): alle Nutzerbefunde bestaetigt und mit Ursachen belegt in
  `docs/test-fixtures/scanner-benchmark/ROUND_01_FINDINGS.md`. Kernbefund:
  Die OCR verliert praktisch nichts — die „wahlweise"-Zeile, beide
  Beilagen-Spalten (mit x-Koordinaten), die komplette Menuestruktur inkl.
  „oder/or"-Wahl und „pro Person: 39,90"/„55€" stehen alle im Rohtext. Der
  Regel-Parser ist der Engpass: Spalten landen in verschleppten Sektionen,
  das Set-Menue zerfaellt in 3 Fragmente (Tiramisu bekommt einen Preis von
  einer anderen Seite), die Deckseite wird zum Phantomartikel „Gastgeber",
  EN-Zeilen werden dupliziert, `per_person` wird nie gesetzt, obwohl das
  Draft-Modell es kann.
- **QUALITY_TARGETS.md erweitert** um die neuen Anforderungen aus dem
  Feedback: Set-/Gang-Menues als Bundle, eine Sprache + optionales EN im
  Gast-Web (Folgeticket), Deckseiten ueberspringen, Warnung bei Codes ohne
  Legende, vegetarisch/vegan strukturiert + Icon-Folgeticket, Optionen bis
  ins Produkt wirklich waehlbar, `per_person`-Preisbasis.
- **KI-Vergleichsmodus in der Review-Umgebung:** Der Harness laeuft auf
  Wunsch (`runLLM` in der Request-Datei) zusaetzlich ueber den vorhandenen
  KI-Pfad (`MenuImportService.importMenu` mit aktiviertem LLM; Fehler landen
  ehrlich als `llmError` im Report statt den Lauf abzubrechen). Das
  Runner-Skript aktiviert das automatisch, wenn `KITCHENLINK_OPENAI_API_KEY`
  gesetzt ist (Key geht NUR als TEST_RUNNER_-Umgebungsvariable in den
  Testprozess, nie in eine Datei). Der Report zeigt dann pro Karte einen
  Umschalter „Lokale Regeln / KI-Pfad"; Feedback-Schluessel der KI-Ansicht
  tragen ein `llm::`-Praefix, damit die Urteile getrennt bleiben.

### Verifikation

- Harness kompiliert (build-for-testing gruen); Gate-Skip unveraendert.
- Report-Umschalter im Browser verifiziert — mangels API-Key mit simulierten
  KI-Daten per JS-Injektion: ohne KI-Daten kein Umschalter, mit Daten
  korrekte KI-Ansicht, Diagnosezeile, getrennte `llm::`-Feedback-Schluessel,
  Rueckschalten intakt. Der echte KI-Lauf selbst konnte ohne Key nicht
  ausgefuehrt werden — das ist genau der offene Runde-2-Schritt.
- Zwischenfall, behoben: Beim Testen wurde das localStorage-Feedback des
  Nutzers geloescht; es wurde sofort aus dem vorliegenden Export
  byte-genau wiederhergestellt und die Wiederherstellung im Report
  verifiziert (7×OK, 2×Falsch, 4 Notizen bei Scheune sichtbar).

### Naechster Schritt

1. **Nutzer-Entscheidung gefallen (20. Juli): OpenCode-Zen-Key, und zwar
   NUR Free-Modelle.** Der erste Lauf des Nutzers bewies: Key gueltig
   (`/models` liefert 24 Modelle inkl. big-pickle und fuenf `*-free`),
   aber `claude-sonnet-5` scheiterte mit `CreditsError: Insufficient
   balance` (Bezahlmodell ohne Guthaben; im Report als `invalidAPIKey`
   gemappt). Umsetzung der Free-Vorgabe: OpenCode-Standardmodell im Runner
   ist jetzt `big-pickle`; `KITCHENLINK_LLM_SEND_IMAGES=0` schaltet den
   Bild-Versand fuer Text-only-Modelle ab (der OCR-Dump traegt Seite +
   x/y-Koordinaten, der Primaer-Prompt weist das Modell im Textmodus
   explizit darauf hin); `check-llm-gateway.sh` testet alle Free-Modelle
   automatisch auf Text- und Vision-Faehigkeit (winziges rotes Testbild)
   und druckt den fertigen Review-Befehl. Offen: Nutzer fuehrt
   `KITCHENLINK_OPENCODE_API_KEY=… ./scripts/check-llm-gateway.sh` aus
   (Ergebnisse landen in /tmp, der Agent liest sie selbst), dann der
   empfohlene Review-Lauf.
2. Danach Vergleichslauf, Eigenverifikation (Pflicht), dann gezielte
   Haertung des KI-Pfads entlang der Zielliste; der Regel-Parser bleibt
   Offline-Fallback.
3. Unveraendert offen: reale Abnahmen KL-CLOUD-001 (§6.1) und KL-MENU-005
   (§6.2).

## Session-Teil 11: KL-SCAN-002 — Import-Review-Umgebung

### Anlass und Scope

Nach KL-MENU-005 stellte der Nutzer klar, dass die Erkennungsqualitaet selbst
nie verifiziert wurde (stimmt — mein Ticket verifizierte nur den
Publish-Transport; die Scanner-Luecken sind in `CURRENT_RESULTS.md`
dokumentiert) und forderte einen mehrstufigen Optimierungs-Workflow mit
qualifiziertem Input/Output-Vergleich ueber viele Speisekarten — plus eine
eigene Umgebung, damit die Pruefung nicht in Dutzenden Einzelimporten am
iPhone stattfinden muss. Diese Session baut die Umgebung; Parser-Fixes
beginnen bewusst erst mit dem ersten Feedback (Runde 1).

### Umgesetzt

- **`docs/test-fixtures/scanner-benchmark/QUALITY_TARGETS.md`:** die
  Nutzeranforderungen als verbindliche Zielliste — Kategorien aus
  Kartentiteln; Artikel mit Varianten/Optionen/Groessen und Beschreibungen;
  strukturierte Allergen-Zuordnung ueber die Karten-Legende (einheitliche
  Icons in der UI als eigenes Folgeticket); harte Regel: Legende-Codes nie in
  Name oder Beschreibung; Preise nur echt zugeordnet, nie erfunden. Dazu der
  Runden-Workflow (Lauf -> Nutzer-Feedback -> Parser-Fix + Gold-Anker ->
  Nachweis).
- **`kitchenlinkTests/MenuImportReviewHarnessTests.swift`:** gegateter
  Batch-Export (Gate: `ImportReviewRequest.json` im App-Bundle, gleicher
  Mechanismus wie der Benchmark). Jagt alle Demo-Fixtures und optional
  beliebige eigene Karten (PDFs per CGPDFDocument mit ~2000 px gerendert;
  Bild-Unterordner alphabetisch) durch `MenuImportService.benchmarkLocalImport`
  (LLM aus, deterministisch) und schreibt Seiten-PNGs (orientierungs-
  normalisiert) plus `report.json`: Draft-Sektionen/-Eintraege mit Name,
  Beschreibung, Offers, Evidenz (Seite, Bounding Box, located, Methode),
  Deklarationen, Optionsgruppen, Mengen; Legacy-Konvertierung (inkl.
  `displayName` zur Code-im-Namen-Erkennung); Roh-OCR-Zeilen;
  Draft-Validierungsfehler. Bewusst KEINE Qualitaets-Assertions — Regression
  bleibt Sache des Gold-Benchmarks.
- **`scripts/run-import-review.sh` + `scripts/import-review-report.html`:**
  Runner (build-for-testing, Konfiguration ins Bundle, Test, Report-Bau,
  `latest`-Symlink, oeffnet Browser; `KITCHENLINK_REVIEW_MENUS=<Ordner>` fuer
  eigene Karten) und statischer HTML-Report (Daten als `report.js`-Script,
  damit file:// ohne Server funktioniert): Karten-Tabs; pro Seite links das
  Original mit Overlays (Name durchgezogen, Preis gestrichelt; Hover hebt
  hervor), rechts die Eintraege mit automatischen Markierungen (ohne Preis,
  zu klaeren, ohne Fundstelle, Codes im Namen/Beschreibung — Heuristik fuer
  nachgestellte UND eingebettete Code-Gruppen wie `-A,G,)-` oder
  `Gulaschsuppe-A,G,l,-`, Kommapflicht schuetzt Komposita und Mengen —,
  ohne Beschreibung, erkannte Allergene); OK/Falsch + Notiz pro Eintrag und
  Fehlend-Feld pro Seite (localStorage pro Lauf); „Feedback exportieren"
  laedt `import-review-feedback.json` herunter und kopiert es in die
  Zwischenablage. Dazu Veroeffentlichungs-Vorschau (Legacy-Tabelle) und
  Roh-OCR pro Seite als Aufklapper.

### Verifikation

- Kompletter Lauf: Build + 14 Seiten echte Vision-OCR in 48 s, Test gruen,
  `report.json` mit 3 Karten / 105 Draft-Eintraegen / 0 Validierungsfehlern.
- Report im Browser (ueber lokalen HTTP-Server, da die eingebaute
  Tool-Vorschau file://-Nachbardateien nicht laedt — in echtem Safari/Chrome
  laeuft file:// direkt): Overlays sitzen auf den richtigen Zeilen, Tabs,
  Hover-Hervorhebung, OK/Falsch-Zustand + Notiz persistiert in localStorage,
  Zaehler plausibel. Querschnitt gegen den dokumentierten Stand: exakt 7
  preislose Lichtburg- und 2 Alexxanders-Kandidaten erscheinen als
  „ohne Preis"/„zu klaeren".
- **Echte Befunde aus dem ersten Lauf (bestaetigen den Nutzereindruck):**
  Scheune hat 14 Eintraege mit Legende-Codes in der Beschreibung und einen im
  Namen (`Grosse Hausgemachte Gulaschsuppe-A,G,l,-`); Beschreibungsfragmente
  werden teils doppelt angehaengt (deutsch/englisch bzw. OCR-Zeilendopplung);
  OCR verwechselt `)`/`J` und `l`/`1` in Code-Gruppen; Beschreibungen tragen
  `#`-Trennzeichen aus dem Parser. Alexxanders faellt mit 26/27
  `needsReview`-Eintraegen auf. Alles Runde-1-Material, bewusst noch nicht
  gefixt.

### Risiken / bewusste Grenzen

- Die automatischen Markierungen sind Heuristiken zur Aufmerksamkeitslenkung
  (z. B. schlagen additive Ziffern-Codes wie `1,2` derzeit nicht an); das
  Urteil faellt der Mensch im Report.
- Der Report zeigt die lokale Pipeline ohne LLM — identisch zum Benchmark,
  damit Runden vergleichbar bleiben.
- Feedback liegt in localStorage des Browsers pro Lauf; der Export ist der
  Uebergabeweg. Kein Server, keine Persistenz im Repo.

### Naechster Schritt

1. **Nutzer:** `./scripts/run-import-review.sh` ausfuehren (oder den bereits
   erzeugten Lauf unter `/tmp/kitchenlink-import-review/latest/index.html`
   oeffnen), Karten durchgehen, Feedback exportieren und uebergeben. Gern
   zusaetzlich echte Karten ueber `KITCHENLINK_REVIEW_MENUS=<Ordner>`.
2. **Agent (Runde 1):** Feedback in Parser-Fixes + Gold-Baseline-Anker
   uebersetzen; die bereits sichtbaren Befunde (Codes in Text, doppelte
   Fragmente, `#`-Artefakte) sind der erste Arbeitsvorrat.
3. Parallel bleiben die realen Abnahmen KL-CLOUD-001 (§6.1) und KL-MENU-005
   (§6.2) offen.

## Session-Teil 10: KL-MENU-005 — Scan-zu-Publish-Bruecke

### Anlass und Scope

Der Nutzer hat aus den moeglichen naechsten Schritten die Scan-zu-Publish-
Bruecke gewaehlt (Marktanalyse §5.2). Befund: Der Menuescan war bisher nur
mit dem lokalen Sandbox-Menue verdrahtet (`store.replaceMenu`); die zweite
Haelfte des Kern-Pitches — gescannte Karte wird fuer Gaeste im Gast-Web
bestellbar — fehlte. Diese Scheibe schliesst das.

### Umgesetzt

- **Migration `supabase/migrations/20260719200000_operator_publish_menu.sql`**
  (additiv, aendert keine bestehende Tabelle/Policy/Funktion): SECURITY-DEFINER-
  RPC `operator_publish_menu(p_venue_slug, p_menu jsonb)`, staff-gated ueber
  `is_venue_staff` (gespiegelt zu KL-CLOUD-001). Sie **ersetzt die aktive Karte
  der Venue vollstaendig** (kein Merge, exakt wie die lokale Uebernahme),
  garantiert genau eine aktive Karte pro Venue und lehnt doppelte
  `menu_items.slug` in der Nutzlast ab — das ist die lastende Invariante des
  Bestell-Gates (`guest_web_submit_order` loest Artikel ueber den Slug auf).
  Das Loeschen der Kategorien kaskadiert auf `menu_items`; historische
  `order_items.menu_item_id` fallen per FK auf NULL, Name/Preis bleiben als
  Snapshot in `order_items`. `tag` und `variant_options` werden bewusst nicht
  geschrieben (erster Schnitt; Gastkarte und Bestell-Gate nutzen beides derzeit
  nicht) — als Folgearbeit dokumentiert.
- **App, neu `KitchenLinkMenuPublishClient.swift`:** reiner, testbarer
  Nutzlast-Bau `KitchenLinkMenuPublishPayload.build(from: [MenuSectionData])`
  mit deutscher Slug-Erzeugung (ä→ae, Diakritika entfernt, Nicht-Alphanumerik →
  Bindestrich) und deterministischer Deduplizierung (`-2`, `-3`, …); nutzt
  `item.displayName` (Allergen-Codes werden vom Namen getrennt und separat als
  Array uebergeben). `KitchenLinkMenuPublishModel` (@MainActor) veroeffentlicht
  mit einer bestehenden Betreiber-Sitzung oder meldet mit vertrauten
  Zugangsdaten an; genau-einmaliger 401-Refresh und tote-Sitzung-Abmeldung wie
  im Cloud-Bestellmodell.
- **App, umgebaut `KitchenLinkCloudOrderClient.swift`:** schmales
  `KitchenLinkCloudAuthenticating`-Protokoll (nur signIn/refresh) aus
  `KitchenLinkCloudTransport` herausgezogen — bestehende Konformer (URLSession-
  Transport, Test-Spy) erfuellen es transparent weiter. `rpc` teilt sich jetzt
  einen `rpcData`-Helfer, damit die Publish-RPC einen verschachtelten
  `p_menu`-Encodable-Body senden kann. `URLSessionKitchenLinkCloudTransport`
  erfuellt zusaetzlich `KitchenLinkMenuPublishTransport`.
- **App, neu `MenuPublishSheet.swift` + Aktion im Draft-Review:** Im
  unlocked-Zustand des Review-Screens gibt es neben „In Sandbox-Menue
  uebernehmen" jetzt „Online veroeffentlichen" (`draftReview.publishOnline`).
  Das Sheet zeigt, was online geht, meldet bei Bedarf mit **nur** E-Mail +
  Passwort an (Usability-Leitplanke: keine technischen Verbindungsfelder),
  warnt explizit vor dem vollstaendigen Ersetzen und bestaetigt mit der
  Live-URL `kitchenlink.luneq.eu/alte-muehle/menu`.

### Verifikation

- App-Target-Build fuer iPhone-17-Pro-Simulator: **BUILD SUCCEEDED**.
- Komplettes `kitchenlinkTests`-Target: **0 Fehlschlaege** (xcodebuild meldet
  202 „passed"-Zeilen inkl. des ueblichen Swift-Testing-Doppelreportings). Die
  11 neuen Publish-Tests: Slugify (Umlaute/Diakritika/Separatoren/Fallback),
  Payload-Bau (Dedup, Kind-/Allergen-Mapping, leere Sektion faellt weg,
  displayName ohne Codes) und das Model gegen einen Transport-Spy (gespeicherte
  Sitzung, Anmeldung-dann-Publish, genau-einmaliger 401-Refresh mit Retry, tote
  Sitzung → Abmeldung, leere Zugangsdaten ohne Netz).
- **Nicht ohne Nutzer verifizierbar:** Die RPC-SQL lief nicht gegen echtes
  Postgres — dieselbe Grenze wie bei KL-WEB-002 und KL-CLOUD-001. Es gibt hier
  keine Instanz-Credentials. Aufzuloesen durch die reale Abnahme.

### Risiken / bewusste Grenzen

- **Vollstaendiger Ersatz statt Merge:** Ein veroeffentlichter Scan loest die
  gesamte aktive Karte ab, inklusive des eingebauten 8-Artikel-Sandbox-Seeds.
  Das ist bewusst (der Scan IST die Karte), aber ein spaeteres Ticket sollte
  additive Kartenpflege ermoeglichen.
- **Slug-Stabilitaet ueber Re-Publish:** Slugs werden bei jedem Publish neu aus
  den Namen erzeugt. Aendert sich ein Name, aendert sich der Slug; alte,
  bereits geoeffnete Gast-Tabs koennten dann `guest_web_unknown_item` sehen.
  Fuer die Sandbox unkritisch; vor Produktion ist stabile Slug-Zuordnung zu
  bedenken.
- **Sitzung** liegt weiter in UserDefaults (nicht Keychain), geteilt mit
  KL-CLOUD-001 — dieselbe dokumentierte Sandbox-Grenze.
- `tag`/`variant_options` gehen noch nicht mit; Allergencodes schon.

### Naechster Schritt (Nutzer)

1. Migration `20260719200000_operator_publish_menu.sql` anwenden
   (SANDBOX_SETUP.md Abschnitt 2).
2. In der App eine Karte scannen, im Draft-Review klaeren, „Online
   veroeffentlichen" waehlen (SANDBOX_SETUP.md §6.2), dann
   `kitchenlink.luneq.eu/alte-muehle/menu` im Browser pruefen.
3. Danach ist der Kern-Pitch erstmals durchgaengig vorfuehrbar; sinnvolle
   Folgeschritte: Tisch-Kontext im Gast-Web (QR mit Tischparameter) und die
   Payment/TSE-Provider-Vorentscheidung als Papieraufgabe.

## Session-Teil 9: Konsolidierung auf main + Aufraeumen (19. Juli, Abend)

- **Merge 1:** `claude/cloud-order-loop` → `main` (`f304d30`), auf
  Nutzeranweisung ohne separate Abnahme vorab; die reale Abnahme bleibt als
  offener Schritt in der Queue.
- **Merge 2:** `codex/local-hub-discovery` → `main` (`1f236a0`),
  KL-OFFLINE-008. Konflikte in `WORK_QUEUE.md` (beide Eintraege behalten)
  und `KitchenLinkV2LocalOperationsView.swift` manuell aufgeloest: Codex'
  leichter Startup-Wrapper, Bonjour-Discovery im „Anderen Hub
  verwenden"-Aufklapper und asynchrone QR-Erzeugung wurden in die
  vereinheitlichte Service-Ansicht (Cloud + Lokal) eingewoben. Codex' neuer
  UI-Test wurde auf die gemergten Titel („Service", „LOKALER FALLBACK AUF
  DIESEM IPHONE") angepasst.
- **Branch-Hygiene:** alle nicht in `main` enthaltenen Branch-Spitzen als
  `archive/<branch>`-Tags gepusht (15 Stueck). Remote-Branches wurden noch
  NICHT geloescht — bewusst erst nach expliziter Nutzerbestaetigung, weil
  fremde Branches betroffen sind.
- **Doku:** `docs/strategy/MARKET_ASSESSMENT_2026-07-19.md` neu (Analyse
  vom Sessionanfang, als Referenz fuer spaetere Priorisierung);
  `DECISIONS.md` +2 (Usability-Leitplanke, Main-Only-Modus);
  `PEER_WORKFLOW.md` als teilweise ueberholt markiert; CURRENT/WORK_QUEUE
  nachgezogen.
- **UI-Aufraeumen (Usability-Leitplanke):** V2-Home zeigt nur noch die
  Produktwege; „Bestehende Produktsandbox" und der Legacy-Design-Schalter
  liegen eingeklappt hinter „Entwicklung & Demo"
  (`business.devTools`; beide UI-Tests expandieren jetzt zuerst). In der
  Service-Ansicht stehen die Bestellungen direkt nach dem Moduswechsler;
  Cloud-/Hub-Statuskarten folgen darunter (nur der einmalige Login bleibt
  oben, solange abgemeldet).

## Session-Teil 8: KL-CLOUD-001 — Cloud-Bestellschleife + Lokal-Fallback

### Anlass und Scope

Der Nutzer bestaetigte den Befund, dass sein erfolgreicher Test auf
`kitchenlink.luneq.eu` nur die Gast-Haelfte bewies: Bestellungen landeten in
Supabase, aber keine Betreiberoberflaeche las sie (einzige Lese-Policy war
`orders_owner_read` fuer den Gast selbst; der einzige Supabase-Code der App
zeigte auf ein altes hartkodiertes Projekt und haette an RLS scheitern
muessen). Zusaetzliche Nutzeranforderung: kein manuelles Vorauswaehlen von
„Lokaler Service" mehr — der lokale Weg soll den Online-Weg automatisch
ersetzen, wenn die Verbindung fehlt, und das Gast-Web soll Gaeste dann von
sich aus auf die lokale Bestellseite verweisen („kindergartenleicht").

### Umgesetzt

- **Migration `supabase/migrations/20260719100000_operator_cloud_orders.sql`**
  (additiv, aendert keine bestehende Policy/Funktion): `venue_staff` mit
  RLS-Selbstsicht und ohne Client-Schreibpfad; `is_venue_staff()` als
  SECURITY-DEFINER-Helfer; Staff-Lese-Policies auf `orders`/`order_items`
  zusaetzlich zu den Owner-Policies; `operator_update_order_status`
  (Staff-Pflicht, Vorwaertskette `pending→accepted→preparing→ready→served`
  auch ueber mehrere Stufen — die Kueche hat einen einzigen Bump-Button —,
  Ziel==Ist und verspaetete Retries als Replay, `served→canceled` und alles
  ab `canceled` als Fehler, Zeitstempelspalten wandern mit);
  `venue_hub_presence` (eine Zeile pro Venue, oeffentlich lesbar, Schreiben
  nur ueber `operator_upsert_hub_presence` mit Staff-Pflicht).
- **App, neu `kitchenlink/Features/CloudOperations/`:**
  `KitchenLinkCloudOrderClient.swift` (Config ohne hartkodierte URL/Keys,
  GoTrue-Passwort-/Refresh-Flow, PostgREST-Reads mit embedded
  `order_items`, beide RPCs, Fehler-Mapping inkl. 401→unauthorized),
  `KitchenLinkCloudOperationsModel.swift` (3-s-Polling, genau-einmaliger
  Refresh-Retry bei 401 — ein totes Refresh-Token meldet GoTrue als 400,
  wird als Abmeldung behandelt —, 15-s-Heartbeat mit aktueller lokaler
  Hub-URL, Raeumen der URL beim geordneten Verlassen/Hintergrund),
  `KitchenLinkServiceOrderMerge.swift` (testbare Zusammenfuehrung).
  Wire-Zeilen mit unbekanntem Status/Zeitstempel werden verworfen statt
  geraten; das Mapping fuehrt in die bestehende `LiveOrderMessage`-Domaene,
  kein zweites Bestellmodell.
- **App, umgebaut:** `KitchenLinkV2LocalOperationsView.swift` heisst in der
  Navigation jetzt `Service` (Home-Zeile angepasst, Accessibility-IDs
  unveraendert): eine Kuechen-/Kellner-Liste fuer Online- und lokale
  Bestellungen (aelteste zuerst; online startet `pending`, lokal
  `preparing`), Verbindungsbadge ONLINE/LOKAL/OFFLINE, lokaler Hub laeuft
  unveraendert immer mit und traegt den Titel „Lokaler Fallback". Der
  Mac-Hub-Fallback und alle bisherigen Ablaeufe bleiben erhalten.
- **Vereinfachte Anmeldung (Nachtrag nach Nutzerfeedback „kein Nutzer will
  sich so kompliziert anmelden"):** URL, Anon-Key und Venue sind jetzt fest
  eingebacken (`KitchenLinkCloudConfig.sandboxDefault` — die oeffentlichen
  Gast-Web-Werte des Nutzer-Supabase-Projekts `rjxlzqtaxqstctrrlqre`). Das
  fruehere 5-Felder-DisclosureGroup ist weg; die Cloud-Karte zeigt im
  abgemeldeten Zustand direkt **nur E-Mail + Passwort** und einen prominenten
  Knopf „Online-Service aktivieren". `signIn` nimmt nur noch `email/password`;
  das Model haelt `config` als eingebackene Konstante, der Credential-Store
  persistiert ausschliesslich die Sitzung. Der Anon-Key ist oeffentlich
  (wird ohnehin an jeden Browser ausgeliefert), daher unbedenklich im Repo;
  ein baked-in Passwort/Service-Key wurde bewusst NICHT eingecheckt.
- **Gast-Web:** `src/lib/hub-presence.ts` (reine, getestete Auswertung:
  frisch ≤45 s → online; veraltet + sanitisierte http(s)-URL →
  `local_fallback`; alles andere → `unknown` = heutiges Verhalten, damit
  Venues ohne Presence-Zeile unveraendert funktionieren) plus Einbindung in
  `GuestMenuCard.tsx` (20-s-Poll nur im Browser): Warte-Hinweis-Karte,
  Bestellleiste wird zum Link auf die lokale Bestellseite, Sheet-Submit
  gesperrt mit Inline-Link. Neue CSS-Klassen in `globals.css` nur aus
  bestehenden Tokens; Status ohne Zitrone, die Zitronen-Leiste bleibt die
  Primaeraktion.

### Verifikation

- Gast-Web: `typecheck`, `lint` sauber; **63/63 Vitest** (13 neue
  Presence-/Sanitizing-Tests); `next build` gruen, `/[venueSlug]/menu`
  weiter `Revalidate 1m`. Browser mobil 375×812: Normalzustand
  byte-gleichem Verhalten (kein Banner, Leiste als Button), Fallback-Zustand
  temporaer erzwungen und visuell geprueft (Banner, Leisten-Link, beide
  Links auf die lokale URL), danach zurueckgesetzt und erneut 63/63.
- iOS: Test-Build gruen; **12 neue Tests** in
  `KitchenLinkCloudOperationsTests` (Wire-Mapping, Zeitstempel-Varianten,
  401-Refresh-genau-einmal, tote-Session-Abmeldung, Venue-not-found,
  Heartbeat-Inhalt inkl. Raeumen, Kuechen-/Kellner-Merge); komplettes
  `kitchenlinkTests`-Target **186 bestanden / 0 fehlgeschlagen / 1 bewusst
  uebersprungen** (iPhone-17-Pro-Simulator).
- Nicht verifizierbar ohne Nutzer: Migration und Betreiber-Konto existieren
  nur als Dateien/Anleitung — es gibt hier keine Instanz-Credentials. Die
  RPC-SQL lief nicht gegen ein echtes Postgres; dieselbe Grenze wie bei
  KL-WEB-002, aufzuloesen durch die reale Abnahme.

### Risiken / bewusste Grenzen

- Sitzung (Access-/Refresh-Token) liegt in UserDefaults, nicht Keychain —
  Sandbox-Grenze, vor Produktion zu ersetzen; das Passwort selbst wird nie
  gespeichert.
- Presence kann nicht zwischen „App offline weiterlaufend" und „App
  waehrend Offline-Phase geschlossen" unterscheiden; der lokale Verweis
  kann dann ins Leere zeigen (im Code und in SANDBOX_SETUP dokumentiert).
- Kein Realtime, bewusst Polling (3 s) analog zum lokalen Hub; kein
  Gast-Status-Web nach dem ACK (Folgeticket); `canceled` ist per RPC
  moeglich, hat aber noch keine UI.
- Der Kuechenfilter zeigt auch alte `pending`-Testbestellungen der echten
  Instanz — gewollt (Backlog sichtbar, per Bump raeumbar).

### Naechster Schritt (Nutzer)

1. Migration anwenden + Betreiber-Konto anlegen: `SANDBOX_SETUP.md` §6.1.
2. Branch `claude/cloud-order-loop` frisch aufs iPhone bauen (der Menuepunkt
   muss `Service` heissen, nicht mehr `Lokaler Service`). Dort in der
   Cloud-Karte nur E-Mail + Passwort des Betreiber-Kontos eingeben und
   „Online-Service aktivieren". Dann auf dem Handy ueber
   `kitchenlink.luneq.eu/alte-muehle/menu` bestellen → Bestellung muss in
   der Kueche erscheinen und bis `serviert` laufen.
3. Internet des iPhones trennen (WLAN ohne Uplink oder Hotspot aus) →
   Gast-Web muss nach ~1 min den lokalen Hinweis zeigen.
4. Nach bestandener Abnahme: Branch `claude/cloud-order-loop` mergen.

---

# Historie (bis 18 July 2026)

**Branch damals:** `main` (Integrationsarbeit); KL-WEB-001 gemergt aus
`claude/guest-web-foundation`
**Status damals:** Alle vier Runde-2-Missionen (KL-OFFLINE-003, KL-WORKFORCE-001,
KL-WEB-002, KL-INVENTORY-001) reviewt und in `main` integriert, keine P0/P1.
Zwei echte Funde waehrend der Integration behoben (KL-WORKFORCE-001,
KL-WEB-002), eine Design-Frage bei KL-INVENTORY-001 genau nachverfolgt statt
ungeprueft als Bug behandelt. Danach die Offline-Venue-Hub-Discovery reviewt
und mit einer Integrationslesart nach `main` gebracht. ADR-001 nachtraeglich
nach `main` gebracht, da GLMs frischer Mission-Branch sie sonst nicht im
Arbeitsbaum gehabt haette. KL-WEB-001-Fundament umgesetzt, gegen die visuelle
Claude-Design-Referenz korrigiert, verifiziert und gemergt. Zuvor am selben
Tag: PR #5/#6/#9 reviewt und integriert sowie die vier KL-WEB-001-
Entscheidungen des Nutzers in `DECISIONS.md` dokumentiert.

## Session-Teil 7: Review Offline-Venue-Hub-Discovery

### Scope

Die beiden zuletzt offenen, ungereviewten Branches
(`deepseek/offline-venue-hub-review` als Superset, `glm/offline-venue-hub`)
gelesen und als Discovery eingeordnet. Kein Produktcode, keine Freigabe.

### Vorgehen und Befund

- Alle fuenf Discovery-Dokumente vollstaendig gelesen (GLM-Architektur +
  Quellen, DeepSeek-Red-Team, Stage-1-Event-Log-Contract, Netzwerk-POC).
- Die fuenf Dokumente verbatim aus dem Branch extrahiert und unter
  `docs/discovery/offline-venue-hub/` nach `main` gebracht — nur diese
  Dateien, **nicht** den ganzen Branch (dessen Handoff-Versionen sind
  veraltet und wuerden den aktuellen Stand regressieren; gleiche Methode wie
  bei der ADR-001-Extraktion).
- Eigene Integrationslesart `INTEGRATION_REVIEW.md` geschrieben (analog zur
  Taxonomie-`INTEGRATION_REVIEW.md`), die drei Dinge festhaelt:
  1. **Stage 1 ist faktisch bereits gebaut** — der gemergte
     KL-OFFLINE-003-Prototyp deckt genau den Teil ab, dem DeepSeek als
     einzigem ein bedingtes Go gab. Die Entwuerfe konvergieren im Prinzip,
     divergieren in der Umsetzung (eigenes SQLite vs. GRDB; der Prototyp ist
     auf der Abhaengigkeitsachse die staerkere Wahl). Offen bleibt die
     iOS-Integrationsnaht (`LocalDemoRepository` hinter
     `KitchenLinkRepository` ablösen).
  2. **Der netzwerkseitige Hub-Teil kollidiert mit KL-WEB-002.** DeepSeeks
     staerkster P0: ein cloud-first per HTTPS ausgeliefertes Gast-Web kann
     einen lokalen HTTP-Hub nicht per `fetch` erreichen (Mixed Content +
     Chrome Local Network Access). Die Offline-Gastbestellung aus Blueprint
     §16.2 ist damit eine echte Produkt-/Architekturweggabelung, kein
     Implementierungsdetail.
  3. Belastbare Prinzipien (Event Sourcing statt CRDT, ACK-nach-Commit,
     Transactional Outbox, „messen statt annehmen") sind uebernehmbar; die
     P0-Netzwerkrisiken und Failover-Fragen bleiben Nutzer-/Messentscheidung.
- Keine `DECISIONS.md`-Aenderung. WORK_QUEUE und CURRENT.md nachgezogen.

## Session-Teil 6: Review und Integration KL-WEB-002 und KL-INVENTORY-001

### Scope

Nutzer meldete beide Missionen als fertig. Beide reviewt, ein Fund pro
Ticket behandelt (einer behoben, einer bewusst nicht), beide gemergt.

### Review-Ergebnis KL-WEB-002 (GLM, `glm/guest-web-order-gate`)

- Branch war 4 Commits hinter `main`; lokal konfliktfrei rebased.
- Migration gegen die tatsaechliche SQL geprueft: additive Spalten
  (`idempotency_key`, `idempotency_payload_hash`, `created_by`,
  `menu_items.slug`), deckungsgleicher Sandbox-Seed, RLS auf allen sechs
  betroffenen Tabellen (vorher keine einzige geschuetzt), `guest_web_submit_order`
  als `SECURITY DEFINER`-RPC mit `FOR UPDATE`-Sperre, Idempotenz ueber
  Payload-Hash-Vergleich plus Unique-Constraint.
- TypeScript-Verdrahtung (`order-submit.ts`, `order-ack.ts`,
  `order-backend-supabase.ts`, `supabase-client.ts`) gegen ADR-001 §6/§7
  geprueft; Status kommt nachweislich nur aus der Serverantwort.
- CSS-/Komponenten-Diff bestaetigt die Behauptung "visuelles Design
  unangetastet": nur neue Klassen, keine bestehende Regel geaendert.
- **Echter Fund, behoben:** Nach erfolgreicher Bestellung leerte
  `setCart(emptyCart)` den Warenkorb sofort; die Sheet-Summe fiel dadurch
  auf "0,00 €" zurueck, direkt neben der Bestaetigungsmeldung. Der
  tatsaechliche Server-Betrag (`ack.totalCents`) wurde berechnet, aber nie
  angezeigt. Fix: Warenkorb-Schnappschuss zum Sende-Zeitpunkt; die Summe
  zeigt nach Bestaetigung `ack.totalCents` statt des inzwischen leeren
  Live-Warenkorbs. Verifiziert mit Typecheck, Lint, 40/40 Vitest-Tests,
  Build und manueller Browser-Pruefung der ohne echte Supabase-Instanz
  erreichbaren Zustaende (Artikel hinzufuegen, Sheet oeffnen, Senden ohne
  Backend zeigt den korrekten Fehler und behaelt die Live-Summe fuer einen
  Retry). Der "accepted"-Zustand selbst liess sich ohne laufende
  Supabase-Instanz nicht live pruefen; per Code-Lektuere verifiziert.
- **Dokumentiertes Restrisiko, bewusst nicht behoben:** Eine enge Race
  Condition zwischen Idempotenz-Vorpruefung und INSERT (zwei nahezu
  gleichzeitige Sendungen mit demselben Key) wird nur vom
  DB-Unique-Constraint aufgefangen, nicht von einem gezielten
  Exception-Handler, der sie auf Konflikt/Replay abbildet — der Verlierer
  bekommt ein generisches `rpc_error`. Nicht behoben, weil ich die
  `SECURITY DEFINER`-PL/pgSQL-Funktion hier nicht gegen eine echte
  Postgres-Instanz testen kann; ein blinder Fix an sicherheitsrelevantem
  SQL waere unverantwortlich. Die Kerngarantie (nie zwei Bestellungen fuer
  einen Key) haelt trotzdem.
- Gemergt nach `main`; GLMs Remote-Branch unveraendert gelassen (nur lokal
  rebased und mit dem Fix committet).

### Review-Ergebnis KL-INVENTORY-001 (MiniMax, `minimax/inventory-domain`)

- Branch war 9 Commits hinter `main`; lokal konfliktfrei rebased.
- Ledger, Projektion, Mengeneinheiten und Rezept-Resolver gegen
  `INVENTORY_MODEL.md`s eigene Behauptungen gelesen, nicht nur die Doku.
- 52 Inventory-Tests (Vorgabe: 25+), komplette Unit-Suite gruen.
- **Vermeintlicher Fund, nach genauer Pruefung verworfen:** `record()`
  prueft den Reversal-/Transfer-Schutz vor der Idempotenzpruefung. Ein
  zweiter `reverse()` derselben Bewegung scheitert deshalb immer als
  `alreadyReversed`, obwohl der automatisch generierte
  `reversal:<originalID>`-Schluessel und der Fingerprint (der `note` und
  `timestamp` bewusst ausschliesst) wie ein identischer Retry aussehen
  wuerden. Auf den ersten Blick ein Bug (widerspricht der generellen
  "gleicher Schluessel + gleiche Signatur -> Replay"-Regel aus §5). Nach
  Nachverfolgung der tatsaechlichen Konsequenzen: das ist die sicherere
  Wahl fuer ein Ledger. Sie garantiert "genau einmal" fuer einen Storno,
  statt einen zweiten Klick still als Erfolg zu replayen — bei einem
  Bestandsledger ist das eher erwuenscht als generische
  Idempotenz-Replay-Semantik. MiniMax dokumentiert diese Abwaegung bereits
  selbst im eigenen Handoff unter "Designentscheidungen — Reversal-Schutz
  vor Idempotenz". Kein Codeeingriff.
- `INVENTORY_MODEL.md` liegt neben dem Feature-Code
  (`kitchenlink/Features/Inventory/`) statt unter `docs/domain/` wie im
  urspruenglichen Mission-Brief vorgesehen — harmlose Pfadabweichung.
- Gemergt nach `main`; MiniMax' Remote-Branch unveraendert gelassen.

## Session-Teil 4: Review und Integration PR #7 (KL-OFFLINE-003)

### Scope

Auf Nutzeranfrage Arbeit an GLM 5.2 und MiniMax/DeepSeek verteilt: zwei neue
Missionen mit frischen Branches/Worktrees von aktuellem `main` in
`docs/collaboration/PARALLEL_MISSIONS_2026-07-17.md` dokumentiert (KL-WEB-002
fuer GLM, KL-INVENTORY-001-Neuversuch fuer MiniMax oder DeepSeek). Danach PR #7
(`glm/offline-event-log-v2`) reviewt und integriert.

### Review-Ergebnis PR #7

- Branch war 21 Commits hinter `main`; lokal konfliktfrei rebased (GLMs
  Remote-Branch bewusst nicht ueberschrieben — Force-Push auf fremde
  Branches ist ohne explizite Nutzerfreigabe nicht zulaessig).
- Code gegen die Invarianten in `EVENT_LOG_V2.md` geprueft (nicht nur die
  Doku gelesen): `EventStore.append` (Pre-TX- und In-TX-Idempotenz-Check,
  Optimistic-Concurrency-Semantik), `Outbox` (Claim/NACK/ACK/Lease-Recovery,
  atomar per PK-Update statt `UPDATE ... LIMIT`), `SQLiteConnection`
  (`BEGIN IMMEDIATE`, serialisierende `DispatchQueue`, ehrliche
  Durability-Pragmas).
- `swift test`: 35/35 gruen, sowohl im Worktree als auch erneut auf dem
  gemergten `main`-Stand.
- Keine P0/P1. Drei kleine, nicht blockierende Beobachtungen (alle bereits
  von GLM selbst in Doku/Handoff offengelegt): veralteter
  AUTOINCREMENT-Kommentar auf einer `WITHOUT ROWID`-Tabelle (tatsaechlicher
  Mechanismus ist korrektes `MAX+1` unter Transaktionssperre); zwei
  Testnamen (`testClaimIsExclusive`, `testParallelDuplicateAppendsCollapse`)
  suggerieren echte Nebenlaeufigkeit, laufen aber sequentiell (Inline-
  Kommentar sagt das selbst, Limitation steht in `EVENT_LOG_V2.md` §11 und
  im GLM-Handoff); Fingerprint-Kanonisierung trennt Felder nur mit Newline
  ohne Escaping (theoretisch, nicht ausnutzbar mit den strukturierten
  internen Feldern dieses Systems).
- Vollstaendig isoliertes Swift Package unter `prototypes/`; kein
  App-/Domain-Code beruehrt. Gemergt nach `main`.

## Session-Teil 5: Review und Integration PR #8, ADR-001-Reparatur

### ADR-001 fehlte auf `main`

Waehrend GLM (in einem externen Tool, sichtbar per Nutzer-Screenshot) am
KL-WEB-002-Auftrag arbeitete, stellte sich heraus: `docs/architecture/guest-web/`
existierte auf `main` ueberhaupt nicht — ADR-001 lag nur auf dem nie gemergten
Branch `glm/guest-web-architecture`. Die Mission verwies darauf, ohne dass ich
geprueft hatte, ob die Datei tatsaechlich auf `main` ankam. Behoben:

- `ADR-001_GUEST_WEB_STACK.md` und `SOURCES.md` (Revision 2, die vom Nutzer
  als Entscheidungsgrundlage akzeptierte Fassung) unveraendert aus
  `origin/glm/guest-web-architecture` extrahiert und auf `main` committet.
- GLMs Worktree (`kitchenlink-glm-web`, Branch `glm/guest-web-order-gate`) war
  zu diesem Zeitpunkt sauber (keine unfertige Arbeit); `origin/main` dort
  konfliktfrei gemergt und gepusht, damit die Dateien sofort im tatsaechlichen
  Arbeitsverzeichnis der laufenden GLM-Session sichtbar wurden.
- Antwort mit der Loesung und der Klarstellung zur zweiten GLM-Frage
  (`signInAnonymously` soll echt verdrahtet werden, nicht nur unit-getestet)
  an den Nutzer zur Weitergabe formuliert.

### Review-Ergebnis PR #8 (KL-WORKFORCE-001)

- Branch war 24 Commits hinter `main`; lokal konfliktfrei rebased (Kimis
  Remote-Branch unveraendert gelassen, wie bei GLM).
- Code gegen `WORKFORCE_MODEL.md` geprueft: Zeitmodell (`WorkforceTimeModels.swift`,
  explizite Zeitzonen, `resolvedRange` fuer Schichtvorlagen), Zustandsautomaten
  (`WorkforceShiftLifecycle.swift`), Validatoren (`WorkforceValidators.swift`).
  Beide dokumentierten Europe/Berlin-DST-Uebergaenge 2025 im Test nachvollzogen
  und die Zieldaten (30. Maerz / 26. Oktober) als tatsaechlich letzte Sonntage
  der jeweiligen Monate verifiziert.
- Scheinbare Diskrepanz aufgeklaert statt als Befund gemeldet: `xcodebuild`
  zeigte 74 "passed"-Zeilen fuer nur 37 tatsaechliche `@Test`-Funktionen —
  ein bekanntes, harmloses Doppel-Reporting von Swift Testing unter
  `xcodebuild` (zwei Reporter-Pfade fuer denselben Lauf), keine echte
  Doppelausfuehrung. Das Handoff nannte "33" Tests, tatsaechlich waren es 37 —
  unkritische Unter-, keine Ueberberichterstattung.
- Echter Fund: `finalizeSwap(accepted: false)` liess `acceptedAt` unveraendert,
  wenn eine zuvor angenommene Schicht per abgelehnter Tauschanfrage auf
  `.published` zurueckfiel — Status und Zeitstempel widersprachen sich. Kein
  Test deckte genau diesen Pfad ab (`requestSwap` aus `.accepted` heraus,
  gefolgt von `finalizeSwap(accepted: false)`).
- Waehrend der Integration selbst behoben (beide Zweige setzen `acceptedAt`
  jetzt zurueck) plus gezielter Regressionstest; zusaetzlich ein toter
  No-Op-`if`-Block im Validator entfernt (reine Kommentar-Leiche, kein
  Verhaltensunterschied). 38/38 Workforce-Tests und die komplette Unit-Suite
  liefen auf dem lokal gefixten Branch und erneut auf dem gemergten
  `main`-Stand gruen.
- Vollstaendig isolierte neue Dateien unter `Features/Workforce/`; kein
  bestehender App-Code veraendert. Gemergt nach `main`.

## Session-Teil 3: Visuelle Korrektur gegen Claude-Design Round 04

### Anlass

Der Nutzer verglich die erste Fassung der Gastkarte mit dem tatsaechlichen
visuellen Referenzscreen
(`docs/design/claude-design/round-04/export/territories.html`, Abschnitt 6c,
Screen 2 "Gast-Web · 390 px · dichte Karte") und stellte eine strukturelle
Abweichung fest, nicht nur eine Farbnuance. Die erste Fassung war aus
`DESIGN_SYSTEM.md` (der abgeleiteten, plattformneutralen Spezifikation)
implementiert worden, ohne den zugrunde liegenden visuellen Export noch
einmal direkt zu pruefen.

### Vorgehen

Sechs konkrete Abweichungen identifiziert und einzeln mit dem Nutzer
geklaert (nicht pauschal "an die Referenz angleichen"), da nicht jede
Abweichung gleich zu bewerten war:

| Punkt | Referenz | Erste Fassung | Nutzerentscheidung |
| --- | --- | --- | --- |
| Preiszeile | inline in Sekundaerzeile | eigene fette Zeile | **eigene Zeile beibehalten** (bewusste Abweichung von der Referenz) |
| Controls | umrandet (border-control) | gefuellt (Traube/grau) | umrandet uebernehmen |
| Bestellleiste | gesamte Leiste = Zitrone | neutrale Leiste + Button | gesamte Leiste uebernehmen |
| Venue-Kopf | buendig, Tisch-Kontext + Badge | abgesetzte Karte + Tagline | Kontext + Badge uebernehmen |
| Tag-Badges | "beliebt"/"vegetarisch" Pills | keine | uebernehmen |
| Dichte | kompakt | grosszuegiger | Referenzdichte uebernehmen |

### Umgesetzt

- `venue-data.ts`: `tagline` durch `isOpen: boolean` ersetzt; optionales
  `tag?: string` pro Artikel ("beliebt", "vegetarisch").
- `GuestMenuCard.tsx`: Venue-Kopf jetzt randlos (ausserhalb von `kl-page`),
  mit geoeffnet/geschlossen-Badge und Kontextzeile "Speisekarte" (bewusst
  **kein** erfundener Tischname — es gibt noch keine echte QR-/Tisch-Session;
  das waere irrefuehrend gewesen). Add-Button und Stepper auf
  `border-control`-Umrandung umgestellt. Bestellleiste ist jetzt ein
  einzelnes `<button>`-Element, das die gesamte Leiste als Zitronenflaeche
  einnimmt (Artikelzahl+Label links, Summe rechts), statt einer neutralen
  Leiste mit eingebettetem Button.
- `globals.css`: Abstaende in Menuezeilen und Section-Titeln verdichtet;
  `.kl-badge`-Varianten (hell/dunkel) ergaenzt.
- `tokens.css`: Den unabgestimmten Seiten-weiten Dark-Mode-Wechsel entfernt
  (vorher kippten `--kl-surface-page/-card/-control` unter
  `prefers-color-scheme: dark` auf Traube-Flaechen). Kein verifizierter
  Referenzscreen zeigt ein durchgehend dunkles Gast-Web — nur die Kueche ist
  laut Designsystem "immer Tief". Die Dringlichkeits-Tokens behalten ihre
  Dunkel-Variante (unbenutzt, aber vorwaertskompatibel fuer eine spaetere
  Bestellverfolgung).

### Verifikation

- Typecheck, ESLint, 18/18 Vitest-Tests, SSG-Build erneut gruen.
- Im Browser (375×812, hell und dunkel) erneut interaktiv geprueft: Klick auf
  "+" oeffnet den umrandeten Stepper, die Bestellleiste fuellt sich
  vollstaendig gelb mit korrekter Summe (6,90 € + 14,90 € = 21,80 € im Test),
  das Sheet zeigt dieselbe Summe. Dunkelmodus zeigt jetzt durchgehend die
  helle Karte mit Traube-Kopf statt eines page-weiten Farbwechsels.

### Risiken und offene Punkte (zusaetzlich zu Teil 2)

- Die Kontextzeile "Speisekarte" im Kopf ist ein bewusster Platzhalter ohne
  echten Tisch-/Kanalbezug; sobald ein QR-/Tisch-Fluss existiert, sollte
  `GuestVenue`/die Route einen echten Kontext (Tischlabel oder Kanal)
  mitfuehren statt des statischen Textes.
- Die Preiszeile weicht bewusst von der Referenz ab (Nutzerentscheidung);
  falls spaeter eine dichtere Variante gewuenscht wird, ist das eine reine
  CSS-/Markup-Aenderung ohne Datenmodelländerung.

## Session-Teil 2: KL-WEB-001 Gast-Web-Fundament

### Scope

Erster Umsetzungsschritt nach der Nutzer-Stack-Entscheidung (siehe
`DECISIONS.md`, Guest Web): Next.js-Fundament unter `guest-web/` mit der
mobilen Gastkarte. Bewusst nicht enthalten: Bestelluebermittlung,
autoritative Bestellgrenze, Supabase-Anbindung, PWA-Stufe.

### Umgesetzt

- Next.js 16 (App Router, TypeScript, `create-next-app`-Scaffold ohne
  Tailwind), hosting-neutral; Google-Font-Import des Scaffolds entfernt,
  System-Font-Fallbacks bis zur Freigabe von Bricolage/Source Sans 3.
- `src/styles/tokens.css`: alle Farb-, Radius- und Abstands-Tokens aus
  `DESIGN_SYSTEM.md` als CSS-Variablen mit identischen semantischen Namen
  (`brand.grape` -> `--kl-brand-grape`); hell/dunkel via
  `prefers-color-scheme`. `src/lib/design-tokens.ts` ist die typisierte
  Referenz; ein Vitest haelt beide Quellen konsistent und prueft, dass
  Zitrone in keinem Urgency-Token vorkommt.
- SSG-Menueroute `/[venueSlug]/menu` (`generateStaticParams`,
  `dynamicParams = false`, async `params` gemaess Next-16-Konvention) auf
  lokaler Sandbox-Venue "Gasthaus Alte Muehle" mit acht Gerichten
  (`src/lib/venue-data.ts` als bewusste Naht fuer den spaeteren
  Supabase-Pfad).
- Gastkarte (`src/components/GuestMenuCard.tsx`): venue-gefuehrter Kopf mit
  Traube-Fallback und kleiner KitchenLink-Vertrauenssignatur,
  traubenbasierte Mengensteuerung (>= 44 px, nie Zitrone), fixierte
  Bestellaktion als einzige dauerhafte Zitronenflaeche (gefuellt,
  Traube-Text, disabled neutral), Bestelluebersicht als Sheet (radius.sheet,
  Reduce-Motion-Guard) mit explizitem Sandbox-Hinweis statt Uebermittlung.
- Reine, getestete Cart-Logik (`src/lib/cart.ts`): Mengen 0..99, Summen nur
  aus Menuedaten (Serverseite rechnet spaeter ohnehin neu), de-DE
  Euro-Formatierung.
- Sandbox-Banner im Root-Layout auf jeder Seite (Blueprint §20).

### Verifikation

- `npm run typecheck`, `npm run lint`: sauber.
- `npm test`: 18/18 Vitest-Tests gruen (Cart-Invarianten,
  Fixture-Invarianten inkl. Acht-Gerichte-Anforderung, Token-Abgleich).
- `npm run build`: SSG erfolgreich, `/alte-muehle/menu` wird statisch
  vorgerendert.
- Visuell im Browser (375x812, hell und dunkel): Karte, Stepper-Zustaende,
  Zitronenaktivierung, Sheet mit korrekter Summe (18,40 EUR fuer
  6,90 + 11,50). Ein Dark-Mode-Befund wurde dabei gefunden und behoben:
  Venue-Kopf und Hinzufuegen-Button verschmolzen mit der Traube-Seite;
  beide liegen auf Dunkel jetzt auf `surface.darkRaised` (der erste Fix
  scheiterte an der CSS-Kaskadenreihenfolge, Override steht jetzt nach den
  Basisregeln).

### Risiken und offene Punkte

- Die Zitronen-CTA oeffnet nur die Uebersicht; verbindliche Uebermittlung
  folgt mit der autoritativen Bestellgrenze (Edge Function oder RPC, D6).
- Scaffold-generierte `guest-web/AGENTS.md`/`CLAUDE.md` (Next-16-Warnung,
  verweist auf gebuendelte Docs in `node_modules/next/dist/docs/`) wurden
  bewusst behalten.
- `npm audit` meldet Findings in Dev-Dependencies des Scaffolds; fuer die
  Sandbox unkritisch, vor Produktion zu pruefen.
- Kein venue-eigenes Logo-/Bild-Slot-Modell; der Kopf nutzt den
  dokumentierten Traube-Fallback.
- Vercel-Deployment selbst ist noch nicht eingerichtet (nur lokal
  gebaut/gestartet); eigener Schritt nach Merge.

## Session-Teil 1: Integration PR #6/#5/#9 und KL-WEB-001-Entscheidung

- Reviews und konfliktfreie Integration: PR #6 (Doku-Sync; zwei bereits
  ueberholte Angaben im Folge-Update korrigiert), PR #5 (Kitchen-Haertung;
  gated Screenshot-Harness real ausgefuehrt), PR #9 (KL-QA-002
  Offline-Smoke; Review ohne Befunde).
- Verifikation auf dem gemergten Stand (iPhone 17 Pro Simulator):
  Unit-Suite 60/60 inkl. der 8 neuen Offline-Tests, Standard-UI-Suite
  gruen, Capture-Harness passed (~29 s; `TEST_RUNNER_`-Variablen muessen
  als Umgebungsvariablen vor `xcodebuild` stehen), Scanner-Benchmark
  passed auf Baseline. `main` nach Push byte-identisch mit dem
  verifizierten Pruefstand.
- Die vier KL-WEB-001-Entscheidungen des Nutzers sind in `DECISIONS.md`
  (Guest Web) dokumentiert; CURRENT.md/WORK_QUEUE nachgezogen.
- Bekannte offene Punkte ausserhalb dieses Scopes: toter
  `PARALLEL_MISSIONS`-Verweis im DeepSeek-Handoff (P3),
  `codex/post-merge-hardening` weitgehend redundant, hartkodierter
  Supabase-Anon-Key im Relay (vorbestehend), PR #7/#8 ungereviewt,
  KL-INVENTORY-001 unbesetzt.

## Recommended Next Step

Zwei parallele Nutzer-Abnahmen offen, beide nur mit echter Instanz/Geraet
machbar: (1) KL-CLOUD-001 (Migration `20260719100000` + Betreiber-Konto,
`SANDBOX_SETUP.md` §6.1, reale Web-zu-iPhone-Abnahme) und (2) KL-MENU-005
(Migration `20260719200000`, einmal veroeffentlichen, `SANDBOX_SETUP.md` §6.2).
Nach diesen Abnahmen ist die geschlossene Schleife *Papierkarte → Scan →
Pruefung → Live-Gastkarte → Bestellung → Kueche → serviert* erstmals
durchgaengig vorfuehrbar. Naechste Code-Schritte danach: Tisch-Kontext im
Gast-Web (QR mit Tischparameter + minimale Tisch-Session) und die
Payment/TSE-Provider-Vorentscheidung als Papieraufgabe. Als Folgetickets offen:
Gast-Statusseite nach dem ACK, additive Kartenpflege (statt Vollersatz) und
stabile Slug-Zuordnung ueber Re-Publish.
