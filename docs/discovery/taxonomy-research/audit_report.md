# Audit Report v2 — Red-Team Review GLM v0.2.0 (KL-MENU-001)

**Prüfer:** DeepSeek-V4-Pro (Red-Team-Instanz)
**Geprüfte Artefakte:** Voller Satz unter `docs/discovery/taxonomy-research/` (v0.2.0)
**Datum:** 2026-07-16
**Stichprobe:** 59 source_registry-Einträge, 55 pattern_evidence, Ontologie 10 Achsen, Schema 1472 Zeilen, 35 Golden Cases, saturation_test.md, PROGRESS.md

> **Methode:** Delta-Review zu v0.1 – welche meiner 16 Ursprungs-Findings sind geschlossen, welche offen? Welche neuen Inkonsistenzen kamen durch die Stichprobenerweiterung (F03b–F03f) hinzu?

---

## Status der ursprünglichen 16 Findings (v0.1 → v0.2)

### 🔴 KRITISCH (v0.1)

| # | Finding | Status v0.2 | Begründung |
|---|---|---|---|
| F-01 | Stichprobe 6/150 | **OFFEN** (entschärft) | 9 tiefe Karten (F03b–f). Besser, aber weit unter Soll. Ontologie bleibt Hypothese. |
| F-02 | 0/33 reusable | **OFFEN** | Auch nach Erweiterung: alle 59 Quellen `research_only`. Benchmark nicht baubar. |
| F-03 | keine if/then für priceKind | **GESCHLOSSEN** | if/then-Constraints in Offer eingebaut (P-03). 7 Negativtests bestanden. |

### 🟠 HOCH (v0.1)

| # | Finding | Status v0.2 | Begründung |
|---|---|---|---|
| F-04 | preModifier US-only | **GESCHLOSSEN** | Axis auf `closed: false` + DACH-Caveat. |
| F-05 | choiceKind-Überlapp | **GESCHLOSSEN** | Abgrenzungstabelle in Guideline §2.6. |
| F-06 | courseRole=kids redundant | **GESCHLOSSEN** | Guideline: kids MUSS audience=kids setzen. |
| F-07 | BundleComponent.optionGroup nicht required | **GESCHLOSSEN** | Schema required ergänzt. |
| F-08 | 23% synth Golden Cases | **OFFEN** | 8/35 immer noch theoretical. Kein realer Ersatz beschafft. |

### 🟡 MITTEL (v0.1)

| # | Finding | Status v0.2 | Begründung |
|---|---|---|---|
| F-09 | per_unit als priceKind | **GESCHLOSSEN** | Nach grundpreis migriert. Ontologie YAML hatte per_unit aber noch drin → **soeben gefixt**. |
| F-10 | keine Facet-Inheritance | **GESCHLOSSEN** | Guideline §2.7 ergänzt. |
| F-11 | choiceKind=remove ohne Preismodell | **GESCHLOSSEN** | Guideline: immer included/free. |
| F-12 | kein Sättigungstest | **GESCHLOSSEN** | saturation_test.md mit 8 Karten. Nicht gesättigt – ehrlich ausgewiesen. |
| F-13 | keine nested OptionGroups | **OFFEN** | Für v0.3 vorgemerkt. Evidenz liegt vor (PE-031/032/034/051). |

### 🔵 NIEDRIG (v0.1)

| # | Finding | Status v0.2 | Begründung |
|---|---|---|---|
| F-14 | qr_menu ungetestet | **OFFEN** | OBS_qr_multilang als Quelle, aber keine Tiefenanalyse. |
| F-15 | repeatedPlacement ohne ID-Regel | **GESCHLOSSEN** | Guideline §2.8 ergänzt. |
| F-16 | pageOrLocation freier Text | **OFFEN** | Kein strukturiertes BoundingBox-Format. |

### Zusammenfassung v0.1→v0.2

| Status | Anzahl |
|---|---|
| GESCHLOSSEN | 9 |
| OFFEN (weiterhin) | 5 |
| OFFEN (neu entschärft) | 1 (F-01) |
| OFFEN (Blocking) | 1 (F-02) |

---

## Neue Findings v0.2

### 🟠 F-17: Ontologie YAML inkompatibel mit Schema (per_unit)

- **Beobachtung:** Ontologie `priceKind` hatte noch `per_unit` (Zeile 188), Schema v0.2.0 hat es entfernt und in `Offer.grundpreis` migriert. YAML und Schema widersprechen sich.
- **Schweregrad:** 🟠 HOCH (soeben durch Patch korrigiert)
- **Empfehlung:** Beide Artefakte müssen bei jedem Release synchron versioniert werden. Ein `schema-ontology-sync`-Check in QC aufnehmen.

### 🟠 F-18: Research Report §2 zeigt veraltete Zahlen

- **Beobachtung:** Report §2 (Tabelle) zeigte 38 Quellen / 16 Kandidaten / 6 tief, obwohl PROGRESS.md 59/27/9 meldet.
- **Schweregrad:** 🟠 HOCH (soeben durch Patch korrigiert)
- **Empfehlung:** Report muss bei jeder Stichprobenerweiterung aktualisiert werden, nicht nur PROGRESS.md.

### 🟠 F-19: Ontologie Header deepSampleSize=6 veraltet

- **Beobachtung:** Header sagte `deepSampleSize: 6`, tatsächlich 9.
- **Schweregrad:** 🟠 HOCH (soeben durch Patch korrigiert)
- **Empfehlung:** QC muss Header-Zahlen mit PROGRESS.md abgleichen.

### 🟡 F-20: Versionitis – Dateinamen vs. Inhalt

- **Beobachtung:** `menu_ontology_v0.1.yaml` enthält `ontologyVersion: "0.2.0"`. `menu_schema_v0.1.json` enthält `schemaVersion: "0.2.0"`. `annotation_guideline.md` sagt "v0.1" im Titel. `benchmark_plan.md` sagt "v0.1".
- **Schweregrad:** 🟡 MITTEL
- **Empfehlung:** Dateien bei nächstem Major Bump umbenennen oder in QC-Regel aufnehmen, dass Dateiname und Inhalt konsistent sein müssen.

### 🟡 F-21: saturation_test.md wurde nicht auf 12 Karten aktualisiert

- **Beobachtung:** PROGRESS.md sagt "Sättigungstest aktualisiert (12 tiefe Karten)", aber `saturation_test.md` zeigt nur 8 Karten und wurde nach F03f nicht erweitert. F03d-Nachtrag ist eingepflegt, aber die Tabelle selbst nicht.
- **Schweregrad:** 🟡 MITTEL
- **Empfehlung:** saturation_test.md um die 4 weiteren Karten (Brechts, griechisch, argentinisch, CH) ergänzen oder zumindest im Header klarstellen, dass die Tabelle 8 von 12 zeigt.

### 🟡 F-22: GC23 annotiert grundpreis, aber kein Golden Case für gewichtsbasierten Preis

- **Beobachtung:** GC23 (Grundpreis PAngV) ist auf `Offer.grundpreis` korrigiert. Aber es gibt keinen Golden Case für `priceKind=from` („ab 200g"), `per_person`-basis, oder ein Bundle mit zwei Offers (fixed + per_person). Brechts (PE-046/047/050) und Cocina Argentina (PE-055) bieten reale Fälle.
- **Schweregrad:** 🟡 MITTEL
- **Empfehlung:** Neue Golden Cases GC36–GC40 aus Brechts/Cocina Argentina ableiten.

### 🔵 F-23: PE-028 und PE-030 immer noch "theoretical_composite"

- **Beobachtung:** PE-028 (minPersons) und PE-030 (conflicting legends) haben als Quelle `theoretical_composite`. PE-050 (person-scoped bundle) und PE-049 (mixed legend) liefern jetzt reale Evidenz für beide Muster.
- **Schweregrad:** 🔵 NIEDRIG
- **Empfehlung:** PE-028 und PE-030 auf die realen Quellen updaten (PE-049 für legend, PE-050 für minPersons).

---

## Tabelle aller offenen Findings (v0.2)

| # | Artefakt | Finding | Schweregrad |
|---|---|---|---|
| F-01 | Alle | Stichprobe 9/150 | 🔴 KRITISCH |
| F-02 | source_registry.csv | 0/59 reusable | 🔴 KRITISCH |
| F-08 | annotation_guideline.md | 8/35 theoretical GCs | 🟠 HOCH |
| F-13 | menu_schema_v0.1.json | keine nested OptionGroups | 🟡 MITTEL |
| F-14 | menu_schema_v0.1.json | qr_menu ungetestet | 🔵 NIEDRIG |
| F-16 | menu_schema_v0.1.json | pageOrLocation freier Text | 🔵 NIEDRIG |
| F-20 | Alle | Versionitis Dateiname vs. Inhalt | 🟡 MITTEL |
| F-21 | saturation_test.md | Nicht auf 12 Karten aktualisiert | 🟡 MITTEL |
| F-22 | annotation_guideline.md | Kein GC für weight/from/per_person | 🟡 MITTEL |
| F-23 | pattern_evidence.csv | PE-028/030 noch theoretical | 🔵 NIEDRIG |

---

## Konkrete Gegenbeispiele (v0.2 neu)

| # | Behauptung | Gegenbeispiel | Quelle |
|---|---|---|---|
| CE-07 | priceKind=per_unit in Ontologie | Schema v0.2 hat per_unit entfernt → Widerspruch | menu_ontology_v0.1.yaml vs menu_schema_v0.1.json |
| CE-08 | Report-Zahlen aktuell | §2 zeigt 38, PROGRESS 59 | research_report.md §2 |
| CE-09 | Sättigungstest auf 12 Karten | saturation_test.md zeigt nur 8 | saturation_test.md vs PROGRESS.md |

---

## Bewertung des Gesamtfortschritts

| Aspekt | v0.1 (Erstlauf) | v0.2 (nach F03b–f) | Trend |
|---|---|---|---|
| Quellen gesamt | 38 | 59 | ↗️ |
| Tiefe Karten | 6 | 9 | ↗️ |
| Pattern-Evidenzen | 30 | 55 | ↗️ |
| Länder | 6 | 8 | ↗️ |
| Formate tief | text_pdf, html | text_pdf, html | ➡️ |
| Sättigungstest | nicht durchgeführt | 8/20, ungesättigt | ↗️ |
| Geschlossene Findings | – | 9/16 | ✅ |
| Offene Findings | 16 | 10 (davon 2 🔴, 1 🟠, 4 🟡, 3 🔵) | ↘️ |
| Schema-Validität | keine if/then | if/then + Negativtests | ✅ |
| Bild-PDF/OCR-Lücke | nicht adressiert | systematisch geprüft, interner Bedarf erkannt | ↗️ |

Die Stichprobenerweiterung war substanziell und gut fokussiert (IT/ES/Kantine/Steakhaus). Die Qualität ist ehrlich ausgewiesen. Kritisch bleiben die absolute Stichprobengröße (9/150) und der fehlende rechtebereinigte Benchmark-Datensatz.
