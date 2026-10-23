# Wettbewerbsanalyse & Strategische Positionierung im DACH-Raum (Oktober 2026)

**Status:** Strategische Marktanalyse und Entscheidungsgrundlage (Ergänzung zu `MARKET_ASSESSMENT_2026-07-19.md`).
Verbindliche Produktentscheidungen verbleiben in `docs/collaboration/DECISIONS.md`; der kanonische Produktumfang steht in `docs/PRODUCT_BLUEPRINT.md`.

---

## 1. Marktumfeld DACH (2025/2026)

Das Gastgewerbe in Deutschland (~240.000 Betriebe), Österreich und der Schweiz steht unter massivem Konsolidierungs- und Kostendruck (19 % MwSt. in Deutschland, Lebensmittelinflation, steigende Personalkosten, akuter Fachkräftemangel). Gleichzeitig leiden Betreiber unter einer fragmentierten Software- und Hardware-Landschaft („App-Spaghetti“ aus separater Kasse, QR-Bestelltool, Schichtplanung, Reservierung und Warenwirtschaft mit 200–600 € monatlichen Fixkosten).

### Regulatorische Eintrittsschwelle
- **Deutschland:** KassenSichV, zertifizierte TSE (heute primär Cloud-TSE wie *fiskaly*), Belegausgabepflicht (digitaler E-Bon zulässig) und DSFinV-K-/GoBD-Exporte.
- **Österreich:** Registrierkassensicherheitsverordnung (RKSV) mit kryptografischer Signatur.
- **Schweiz:** MwSt.-Konformität und zwingende TWINT-Akzeptanz im Gast-Checkout.

---

## 2. Die gefährlichsten Wettbewerber im DACH-Raum

| Anbieter | Marktrolle | Stärken | Schwachstellen (Angriffsfläche für KitchenLink) |
| :--- | :--- | :--- | :--- |
| **gastronovi** | All-in-One Cloud-Gastro-ERP | Deckt fast 100 % des Blueprint-Umfangs ab (Kasse, KDS, Reservierung, WWS, Personal, QR, Tap to Pay). Sehr etabliert. | Überladenes, altbackenes ERP-UI; wochenlanges manuelles Onboarding; teures Baukastensystem (schnell 200–400 €/Monat). |
| **SIDES** | Omnichannel- & Delivery-System | Stark bei Systemgastronomie, Lieferdiensten, Webshops und Ghost Kitchens. Moderne API-Architektur. | Fokus auf Delivery/QSR; vernachlässigt die Bedürfnisse klassischer, inhabergeführter Speiserestaurants und Biergärten. |
| **orderbird (Nexi)** | Marktführer für kleine Gastro/Cafés | Hohe Markenbekanntheit, weiter Vertrieb über METRO, Tap to Pay on iPhone integriert. | Technologische Spaltung (PRO vs. MINI); Hardware-Zwang (iPads/Terminals); teure Zusatzlizenzen pro Mobilgerät; keine tiefe WWS oder Schichtplanung; QR-Order wirkt angeflanscht. |
| **Lightspeed (K-Series)** | Enterprise & Gehobene Gastro | Hohe Skalierbarkeit, tiefe Berichte, Hotel-PMS-Integrationen. | Hohe Anschaffungs- und Monatskosten, lange Vertragslaufzeiten, schwerfälliges Setup durch Systemhäuser. |
| **DiKAS** | BYOD-Cloud-Herausforderer | Bietet KI-Speisekartenimport, Browser-BYOD und günstige Einstiegstarife (ab 29–59 €/Monat). | Reine Web-Oberfläche ohne native iOS-Qualität und ohne lokale Event-Sourcing-Ausfallsicherheit. |
| **Sunday** | Spezialist für QR-Order & Pay | Extrem schneller Gast-Checkout am Tisch („in 10 Sekunden zahlen“), Rechnungs-Splitting, hohe Trinkgeldquote. | Kein eigenes Kassensystem; funktioniert nur als Aufsatz auf fremde POS-Systeme. |

---

## 3. Die 5 strategischen Überlegenheiten von KitchenLink

1. **5-Minuten Scan-to-Live statt wochenlanger Systemeinrichtung:**
   Durch die mehrstufige KI-Import-Pipeline (Vision OCR + Layout-Auflösung + LLM-Extraktion inkl. 14 EU-Allergenen und Varianten) wird aus einer abfotografierten Papierkarte in wenigen Minuten ein live bestellbares Restaurant.
2. **Echtes Zero-CAPEX-Restaurant (100 % Smartphone / BYOD):**
   Kein Zwang zu proprietären Kassen-Terminals, iPads oder externen Kartenlesegeräten. Betrieb über vorhandene iPhones, Kontaktloszahlung via *Tap to Pay on iPhone* und digitaler Beleg (E-Bon).
3. **Wahres Local-First statt Schönwetter-Cloud:**
   Mit lokalem SQLite-WAL-Event-Log, ACK-nach-Commit und iPhone-Venue-Hub läuft der Betrieb im Biergarten oder Gewölbekeller auch bei Internetausfall ohne Datenverlust weiter.
4. **Autoritative gemeinsame Tisch-Session (Gast & Kellner auf einem Bon):**
   QR-Bestellungen der Gäste und mündlich beim Kellner aufgegebene Bestellungen landen in derselben offenen `table_session`. Gäste können die gesamte Tischrechnung im Browser einsehen, nach einzelnen Positionen oder Personen aufteilen und direkt bezahlen („Sunday-Killer“).
5. **Ruhe & Gastfreundschaft im Design (4a `Ruhe`):**
   Gericht-führende Typografie, vollständige aber dezente monochrome Allergen-Piktogramme im Textfluss und stoßfeste Großflächen-Bedienung für die Küche.

---

## 4. Ableitung für die Produktentwicklung

1. **Gast-Self-Checkout & Rechnungs-Splitting am Tisch (`KL-WEB-007`):**
   Verbindung der gemeinsamen Tisch-Session (`KL-PAY-001`) mit dem Gast-Web, sodass Gäste alle offenen Tischpositionen (auch Kellner-Bonierungen) einsehen, eigene Positionen antippen oder den Betrag durch $N$ Personen teilen und inkl. Trinkgeld direkt per Wallet begleichen können.
2. **Digitaler Kassenbon (E-Bon nach KassenSichV):**
   Direkte Anzeige des KassenSichV-Prüfbelegs inkl. TSE-Signatur nach Zahlungsabschluss im Browser.
3. **Schlanke Betriebsprofile:**
   Modulare Ein-/Ausblendung fortgeschrittener Bereiche (Lieferdienst, tiefes Lager, Schichtplanung), um den Einstieg für kleine Cafés und Bars frei von Komplexität zu halten.
