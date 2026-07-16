# Handoff — GLM (KL-MENU-001 Rechercheauftrag)

**Datum:** 2026-07-16
**Agent:** GLM-5.2 via ZCode
**Ticket:** `docs/discovery/MENU_TAXONOMY_RESEARCH_TICKET.md` (KL-MENU-001)
**Status:** Erstlauf + Red-Team-Patches + F03b-Teil erledigt; Ontologie/Schema v0.2.0.

## Was in dieser Session erledigt wurde

1. **GLM-Erstlauf** mit 8 Artefakten unter `docs/discovery/taxonomy-research/`.
2. **DeepSeek-Red-Team** (`audit_report.md`, 16 Findings) eingespielt/geprüft.
3. **Patches P-01…P-06** umgesetzt → Ontologie/Schema auf **v0.2.0** gehoben
   (evidenceLevel-Header, preModifier offen, if/then-Constraints für priceKind,
   BundleComponent.optionGroup required, grundpreis-Feld).
4. **Validierung** v0.2.0: Schema + if/then gegen 3 Beispiele + 7 Negativtests.
5. **F03b** Teilerweiterung: Poké/Bubble-Tea (F-13 Option-Dependencies),
   Lieferservice-Pricing, Delivery-Additiv-Deklaration.
6. **F03c** weitere Erweiterung: IT-Primär (Osteria Pratellino: coperto/franchigia/
   5-Gang-Folge), ES-Primár (La Ventana: Allergen-Icons pro Artikel),
   Kantine/Catering, QR-Formatbeobachtung.
7. **F05 Sättigungstest** auf 8 tiefen Karten (Ticket fordert 20): **nicht
   gesättigt**, jede Karte brachte neue Muster. 3 Prioritäten für F03d benannt.
8. **F03d priorisierte Lücken geschlossen**: Brechts Steakhaus Berlin liefert
   gewichtsbasierte Preise (per-100g, Zweigrößen, Gewicht-im-Namen), gemischte
   32er-Legende (Zusatzstoffe+Allergene+Hilfsstoffe), Person-scoped Bundles,
   Modifier-Sub-Choice. BMEL/LMIV legitimiert Option-Level-Deklarationen juristisch.
9. **F03e Bild-PDF/Foto-Systematik**: 9 Kandidaten via curl+`pdftotext` auf
   Textebene geprüft. Ergebnis: **alle öffentlichen PDFs haben Textebenen**;
   echte Scan-/Foto-PDFs über öffentliche Suche nicht verlässlich beschaffbar.
   Lücke ist dokumentiert, nur über interne Testfotos schließbar (Ticket Zeile 138).
10. **F03f Stichprobe erweitert** auf 59 Quellen / 55 Pattern. Finale QC bestanden.

## Tatsächlich erreichte Stichprobe (nach F03f)

- 59 Quellen gesamt; **7 reale Karten tief** analysiert (DE/IT/ES/US); 12 mit
  Strukturbeobachtungen. Länder: DE/FR/DK/FI/US/ES/IT/CH/ID/INT.
- 55 Pattern-Evidenzen, 35 Golden Cases, Ontologie/Schema **v0.2.0**.

## Finale QC (bestanden)

- Schema valid als Draft 2020-12 (inkl. allOf/if-then).
- 3 Beispiele validieren; 7 Negativtests korrekt (delta+amountCents etc.).
- CSV-Konsistenz: keine orphan-Referenzen, keine Duplikate.
- YAML v0.2.0, evidenceLevel=low, 10 Achsen.

## Verbleibendes Risiko / Offenpunkte

- **Bild-PDF/Foto/QR-Tiefenanalyse = 0** – einzige echte strukturale Restlücke;
  alle tiefen Karten hatten Textebenen. OCR-spezifische Muster (Spalten,
  Legendenposition, Trennzeichen) daher unbeobachtet.
- Tiefen-Stichprobe 9/100–150 → Ontologie bleibt Hypothese (F-01 standing).
- Sättigungstest (8/20) nicht voll aussagekräftig → nicht gesättigt.
- Inter-Annotator-Reliabilität noch nicht gemessen.
- Option-Level-Allergene am Choice juristisch legitimiert, aber ohne Kartenbeobachtung.
- Schema v0.2 kann nested OptionGroups / OptionGroup.dependencies / quantity-tiered
  bundle-pricing noch nicht formalisieren → künftiges v0.3-Thema (Evidenz liegt vor
  via PE-031/032/034/051).
- Benchmark nur über interne Testkarten (Ticket Zeile 138); 0 reusable-Quellen
  ist kein Produktblocker, sondern nur für einen *veröffentlichten* Benchmark relevant.

## Schreibbereich & Kollisionsfreiheit

- Nur Dateien unter `docs/discovery/taxonomy-research/` + diese Handoff-Datei.
- Kein Produkt-Code; bestehende uncommittierte Änderungen unangetastet.
- Keine `DECISIONS.md`/`CURRENT.md`-Einträge (nur Discovery).

## Empfohlener nächster Schritt

**F03e**: einzige echte strukturale Restlücke ist **Bild-PDF/Foto/OCR**. Dazu
müssen echte gescannte/fotografierte Karten ohne Textebene beschafft werden – das
geht am ehesten über intern bereitgestellte Testfotos (Ticket Zeile 138) oder
über gezielte Suche nach Bild-PDFs. Parallel weiter Stichprobe in Richtung ≥100.
