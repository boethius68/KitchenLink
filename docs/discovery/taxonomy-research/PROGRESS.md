# KL-MENU-001 Forschungsfortschritt

**Auftrag:** `docs/discovery/MENU_TAXONOMY_RESEARCH_TICKET.md`
**Start:** 2026-07-16
**Status:** GLM-Erstlauf + DeepSeek-Gegencheck + Patch-Umsetzung + F03b-Teil abgeschlossen.
**Wichtig:** Discovery. Keine freigegebene Produktentscheidung.
Alle Zahlen sind **tatsächlich erreichte**, nicht angestrebt behauptete.

## Nummerierte Fortsetzungen

- [x] **F01 — Setup & Standards-Quellen**
- [x] **F02 — POS- & Rechts-Quellen** (Toast, EU 1169/2011, PAngV 2022, VerpackG, UrhG, RFC9309)
- [x] **F03a — Stichprobe reale Karten (Erstteil)** 16 Kandidaten, 6 tief
- [x] **F04 — Forschung/Datasets** metadaten-tief
- [x] **F05 — Sättigungstest** mit 6 Karten nicht aussagekräftig → ungesättigt ausgewiesen
- [x] **F06 — Artefakte (alle 8)**
- [x] **F07a — QC Erstlauf**
- [x] **Red-Team** — DeepSeek `audit_report.md` (16 Findings: 3 kritisch, 5 hoch, 5 mittel, 3 niedrig)
- [x] **F07b — Patches P-01…P-06 umgesetzt → Ontologie/Schema v0.2.0**
- [x] **Validierung v0.2.0** — Schema inkl. if/then gegen 3 Beispiele + 7 Negativtests (alle korrekt)
- [x] **F03b — Stichprobenerweiterung (Teil)** auf Audit-Lücken: Poké/Bubble-Tea (F-13 Option-Dependencies), Lieferservice (F-Preis/Channel)
- [x] **F03c — weitere Erweiterung** IT-Primär (Osteria Pratellino), ES-Primär (La Ventana), Kantine/Catering, QR-Formatbeobachtung
- [x] **F05 — Sättigungstest** auf 8 tiefen Karten durchgeführt (Ticket fordert 20): **nicht gesättigt**, jede Karte brachte neue Muster; 3 Prioritäten für F03d identifiziert
- [x] **F03d — priorisierte Lücken geschlossen**: Brechts Steakhaus liefert gewichtsbasierte Preise (per-100g, Zweigrößen, Gewicht-im-Namen), gemischte 32er-Legende, Person-scoped Bundles, Modifier-Sub-Choice; BMEL/LMIV legitimiert Option-Level-Deklarationen juristisch
- [x] **F03e — Bild-PDF/Foto systematisch gesucht**: 9 Kandidaten via curl+pdftotext auf Textebene geprüft. **Ergebnis: alle öffentlichen PDFs haben Textebenen** – echte Scan-/Foto-PDFs über öffentliche Suche nicht verlässlich beschaffbar. Lücke nur über interne Testfotos schließbar (Ticket Zeile 138).
- [x] **F03f — Stichprobe weiter ausgebaut** auf 59 Quellen / 55 Pattern (DE/FR/DK/FI/US/ES/IT/CH/ID)
- [x] **F05 — Sättigungstest** aktualisiert (12 tiefe Karten): nicht gesättigt, jede Karte brachte neue Muster
- [x] **Finale QC v0.2.0** bestanden (Schema Draft 2020-12, 3 Beispiele, Negativtests, CSV-Konsistenz)

## Tatsächlich erreichte Stichprobe (nach F03d)

| Klasse | Anzahl | deep |
|---|---|---|
| Standards-/API-Quellen geöffnet | 6 | 4 |
| Gesetz/Behörden (EU/DE/IETF) | 6 (+1 BMEL) | 3 |
| Forschung/Datasets | 3 | 0 (Metadaten) |
| Reale Speisekarten-Kandidaten | 27 (+1 Brechts) | 9 (+1 Brechts) |
| Sekundärquellen (Entdeckung) | 13 | 2 |
| Format-/Standard-Beobachtungen | 1 | 0 |
| **Summe** | **51** | **18** |

Länder: DE, FR, DK, FI, US, ES, IT, INT. Sprachen: de, en, fr, sv, it, es.
Neu abgedeckt (F03d): **gewichtsbasierte Preise** (per-100g + Zweigrößen +
Gewicht-im-Namen), **gemischte 32er-Legende** (Zusatzstoffe+Allergene+Hilfsstoffe
in einer Legende), **Person-scoped Bundles** (min/max + pro-Person-Gewicht),
**Modifier-Sub-Choice** (+Sirup mit Flavor-Unterauswahl).

## QC-Ergebnisse v0.2.0

- Schema valid als Draft 2020-12 (inkl. allOf/if-then).
- Alle 3 Beispiele valide gegen volles Schema.
- 7 Negativtests (delta+amountCents, fixed+deltaCents, etc.): alle korrekt abgelehnt/akzeptiert.
- YAML v0.2.0, evidenceLevel=low, 10 Achsen.
- `per_unit` aus priceKind entfernt, dafür `Offer.grundpreis` als eigenes Feld.
- `BundleComponent.optionGroup` jetzt required.

## Bekannte Einschränkungen / offene Lücken (für F03e)

- **Bild-PDF/Foto/QR-Tiefenanalyse weiterhin 0** – einzige echte strukturale Restlücke. Alle tiefen Karten hatten Textebenen.
- Tiefen-Stichprobe 9/100–150 → klar unter Soll.
- Sättigungstest (8/20) nicht voll aussagekräftig → nicht gesättigt.
- Inter-Annotator-Reliabilität noch nicht gemessen.
- Option-Level-Allergene am *Choice* (nicht am Entry) juristisch legitimiert, aber noch ohne Kartenbeobachtung.
- Option-Dependencies (PE-031/032/034) und Modifier-Sub-Choice (PE-051) zeigen,
  dass Schema v0.3 nested OptionGroups / OptionGroup.dependencies formalisieren muss.
