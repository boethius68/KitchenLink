# Import-Qualität Runde 2: KI-Pfad (OpenCode Zen, Free) vs. Regel-Parser

**Stand:** 20. Juli 2026
**Setup:** Modell `big-pickle` (→ `xiaomi/mimo-v2.5`) über das OpenCode-Zen-
Gateway, **keylos/kostenlos** (Free-Modelle brauchen keine Auth; `cost: 0`).
Textmodus (`KITCHENLINK_LLM_SEND_IMAGES=0`): die KI arbeitet mit den
koordinaten-annotierten OCR-Zeilen, nicht mit den Bildern. Lauf über alle drei
Fixtures durch die echte App-Import-Pipeline; vollständige Eigenverifikation
des Agenten gegen die Roh-OCR (Pflicht seit Runde 1).

## 1. Kernergebnis

**Der KI-Pfad löst die Mehrzahl der Runde-1-Befunde — der Regel-Parser bleibt
klar unterlegen.** Gemessen und einzeln geprüft:

| Runde-1-Problem | Regel-Parser | KI (big-pickle, Text+Koordinaten) |
|---|---|---|
| Allergen-Codes in Name/Beschreibung (Scheune) | 16 Einträge betroffen | **0** — Codes sauber getrennt |
| „Kleiner Salat": ganze Beschreibungszeile verloren | nur „Cole Slaw" | **vollständig** („wahlweise gemischter Salat, Tomaten-, Gurken-, Krautsalat, Cole Slaw") |
| Lichtburg S5: linke Beilagen-Spalte verschluckt | fehlten | **erfasst** (Salat, Grüne Bohnen mit Speck, Bratkartoffeln, Kräuterbutter als [Beilagen]) |
| Alexxanders S1 Deckseite → Phantomartikel „Gastgeber" | erzeugt | **übersprungen** (leere Seite, kein Phantom) |
| „Überraschungsmenü": Beschreibung fehlt | fehlte | **vollständig erfasst** |

Doppelte EN/DE-Zeilen (Lichtburg) tauchen im KI-Ergebnis nicht mehr als
Doppelartikel auf. Die KI liefert kostenlos und deterministisch genug für
einen Review-Workflow.

## 2. Was noch nicht stimmt (Runde-3-Material)

1. **Set-/Gang-Menüs weiterhin falsch (Lichtburg S6).** Die KI zerlegt das
   Menü in Fragmente („Vorspeise Antipasti", „Haupgerichte", „Dessert
   Tiramisu") mit dem 39,90-Preis auf jedem, plus doppelte preislose
   Einträge. Ursache: das Prompt-Schema kennt nur `sections/items/options`,
   aber **keine Bundle-/Gang-Struktur mit Wahlgängen** („oder/or"). Das
   Draft-Modell hätte `bundleComponents` — Prompt und Mapping müssen das
   nutzen.
2. **Preisbasis `pro Person` fehlt.** „Überraschungsmenü … Menüpreis pro
   Person 55€" wird als `per_item` erfasst. Das Schema braucht ein
   Preisbasis-Feld (`per_person`/`per_item`).
3. **Vereinzelt weiterhin ungültiges JSON (Scheune S3).** Der neue
   Quote-Reparaturschritt fängt unescapte Anführungszeichen; S3 scheitert an
   einem anderen Muster (noch nicht diagnostiziert). Dank der aufgehobenen
   „alle-Seiten"-Regel bleibt das Teilergebnis (2/3 Seiten) erhalten statt
   alles zu verwerfen.
4. **Kategorienschnitt teils eigenwillig** (Lichtburg S5: „Saucen" und
   „Mediterranean vegetables" getrennt; „Mediterranes Gemüse" unter Saucen;
   „Pepper sauce" ohne Preis). Kleinere Zuordnungsfehler.
5. **Vision noch ungetestet im vollen Lauf.** big-pickle KANN Bilder
   (im Direkttest verifiziert), aber der Volllauf lief bewusst im Textmodus
   (schneller/robuster). Bild-Modus könnte den Spalten-/Layout-Fällen weiter
   helfen — eigener Vergleich in Runde 3.

## 3. Umgesetzte Infrastruktur-Fixes (diese Runde)

- **Keyloser Free-Zugang:** OpenCode Zen bedient die Free-Modelle ohne Auth.
  Der iOS-Client sendet dann bewusst KEINEN `Authorization`-Header (ein
  falscher Key löste `401` aus, kein Key fällt auf den freien Zugang durch).
  `KITCHENLINK_OPENCODE_FREE=1 ./scripts/run-import-review.sh` aktiviert alles
  in einem Schritt. **Wichtig:** der zuvor probierte echte Key war ungültig
  (`401 AuthError`); Aufladen half nicht, weil es ein Key- und kein
  Guthaben-Problem war. Für die Free-Modelle ist gar kein Key nötig.
- **Reasoning-Modelle:** Antwort wird aus `content` gelesen, mit Fallback auf
  `reasoning`; `max_tokens` auf 8000 angehoben, damit vor der JSON-Antwort
  genug Denk-Budget bleibt.
- **JSON-Reparatur:** Ein-Durchlauf-Automat escapt unescapte Anführungszeichen
  in String-Werten (`"Wurstsalat „Scheune""`), nur als Fallback nach striktem
  Parse. Unit-getestet (sauberes JSON bleibt unverändert).
- **Teilergebnisse statt Alles-oder-Nichts:** Eine leere Seite (Deck-/
  Infoseite) verwirft die Karte nicht mehr; gescheiterte Einzelseiten werden
  als Teilfehler gemeldet, die guten Seiten bleiben erhalten.

## 4. Empfehlung Runde 3

1. Prompt + Mapping um **Gang-/Bundle-Menüs** und **Preisbasis** erweitern
   (die zwei größten inhaltlichen Lücken).
2. Scheune-S3-JSON-Fehler diagnostizieren und die Reparatur erweitern.
3. **Bild-Modus** (Vision) im selben Free-Modell gegen den Textmodus messen.
4. Bestätigte Ergebnisse als Gold-Baseline-Anker sichern.
