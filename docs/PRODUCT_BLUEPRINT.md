# KitchenLink Product Blueprint

**Stand:** 14. Juli 2026
**Status:** Verbindliche Arbeitsgrundlage für den kontrollierten Neuaufbau

Dieses Dokument enthält die gemeinsam getroffenen Produktentscheidungen. Es ersetzt die Produktannahmen aus `PRODUCT_PLAN.md`, `MVP_SPEC.md` und `SCREEN_TICKETS.md`. Die älteren Dokumente bleiben vorerst als historische Referenz erhalten.

> **Abgrenzung:** Dieser Blueprint beschreibt, was KitchenLink leisten soll. Er ist kein finales App- oder Markendesign. Die visuelle und interaktive Produktrichtung wird separat in [`design/DESIGN_DIRECTION.md`](design/DESIGN_DIRECTION.md) entwickelt und erst nach ihrer Freigabe in alle Oberflächen übertragen.

## 1. Vision

KitchenLink ist ein vollständiges, smartphone-first Restaurantbetriebssystem für Gäste, Mitarbeiter und Betreiber.

Das langfristige Kernversprechen lautet:

> Ein Mensch kann grundsätzlich mit einem iPhone ein Restaurant eröffnen und betreiben. Zusätzliche Geräte verbessern den Betrieb, sind aber keine Voraussetzung.

KitchenLink verbindet in einer Plattform:

- Restaurantgründung und Einrichtung
- digitale Speisekarte
- Bestellungen aller Kanäle
- Tischservice und Küche/Bar
- Bezahlung und Kasse
- Reservierungen
- Personal- und Schichtplanung
- Zeiterfassung
- Warenwirtschaft und Einkauf
- Lieferung
- Kundenkonto und Loyalty
- Multi-Location-Management
- operative Abrechnung
- später echte Fiskalisierung, Buchhaltung und Steueranbindung

KitchenLink ist damit kein QR-Menü-Zusatz und keine Ergänzung zu einer fremden Kasse. Es soll langfristig das zentrale Betriebssystem des Restaurants sein.

## 2. Erstmarkt und Referenzbetrieb

### 2.1 Zielmarkt

Der erste Rechts-, Steuer- und Zahlungsmarkt ist Deutschland.

- Währung: Euro
- Sprache zum Start: Deutsch
- Architektur: von Anfang an mehrsprachig und für weitere Länder erweiterbar
- Rechtliche Zielarchitektur: KassenSichV, TSE, GoBD, Belegpflicht und deutsche Steuerlogik
- In der Sandbox noch keine steuerlich gültige Aufzeichnung

### 2.2 Referenzbetrieb

Die primäre Produktreferenz ist ein klassisches, nicht gehobenes Full-Service-Restaurant mit:

- Tischservice
- Küche und optionaler Bar
- mehreren Mitarbeitern und Stationen
- Bargeld- und Kartenzahlung
- Reservierungen
- Abholung und Lieferung

Die gleichen Grundabläufe müssen auch für Bar und Café funktionieren.

## 3. Produktoberflächen

KitchenLink ist eine Plattform, aber nicht nur eine einzige App-Datei.

### 3.1 Gast-Web

- Einstieg über Tisch-QR, Link, Restaurantwebsite oder Suche
- kein App-Download notwendig
- anonyme Bestellung am Tisch möglich
- Bestellung, Reservierung, Abholung, Vorbestellung, Lieferung und Zahlung
- responsive für iPhone, Android und Desktop
- später universeller Fallback zur Kunden-App

### 3.2 KitchenLink Business

Native App für iPhone und iPad.

- Betreiber und Management
- Service und Kasse
- Küche und Bar
- Fahrer
- Lager und Wareneingang
- Venue-Hub-Modus
- rollenabhängige Oberfläche
- später Tap to Pay on iPhone und weitere native Gerätefunktionen

### 3.3 Browser-Verwaltung

Responsive Weboberfläche für umfangreiche Aufgaben:

- Schicht- und Personalplanung
- Warenwirtschaft und Einkauf
- Auswertungen
- Multi-Location
- umfangreiche Menüpflege
- Abrechnung und Exporte

Alle Kernfunktionen bleiben grundsätzlich auch auf dem iPhone erreichbar.

### 3.4 KitchenLink Kunden-App

Separate App in einer späteren Entwicklungsstufe.

- Restaurantentdeckung
- Bestellhistorie und Belege
- Favoriten und Wiederbestellung
- Reservierungen
- Loyalty und Gutscheine
- gespeicherte Adressen und Zahlungsarten
- Universal Links öffnen installierte App, sonst Gast-Web

Die Kunden-App und Business-App bleiben getrennt, verwenden aber dasselbe Backend und Kontosystem.

### 3.5 Plattformreihenfolge

1. Native Business-App für iPhone und iPad
2. Gast-Web
3. Browser-Verwaltung
4. Android-Business-App nach der iOS-/iPadOS-Beta
5. separate Kunden-App nach ausreichender Restaurantabdeckung

## 4. Zentrales Einstiegserlebnis: Speisekarte scannen

Der Menüscan ist der erste Einstieg und wichtigste Produkt-Pitch für bestehende Restaurants.

### 4.1 Ablauf ohne Registrierung

1. App oder Landingpage öffnet direkt „Speisekarte scannen“.
2. Interessent fotografiert oder scannt eine oder mehrere Seiten.
3. Alternativ werden Bilder oder PDF hochgeladen.
4. KitchenLink erkennt die Menüstruktur.
5. Das digitalisierte Ergebnis wird vor einer Registrierung angezeigt.
6. Unsichere Erkennungen sind deutlich markiert und direkt korrigierbar.
7. Erst zum Speichern wird ein Konto und ein Restaurant angelegt.
8. Das anonyme Ergebnis wird ohne erneuten Scan übernommen.

Anonyme Scans werden zeitlich begrenzt gespeichert, mengenmäßig limitiert und nicht öffentlich veröffentlicht.

### 4.2 Erkennungsumfang

- Kategorien und Unterkategorien
- Artikelname
- Beschreibung
- Preise
- Größen und Varianten
- Extras und Beilagen
- ausdrücklich genannte Allergene und Zusatzstoffe
- mehrsprachige Inhalte
- Vertrauenswerte und Warnungen

Nicht automatisch geraten werden:

- Steuersatz
- Produktionsstation
- Verfügbarkeit
- Rezept und Wareneinsatz
- rechtliche oder ernährungsbezogene Angaben, die nicht auf der Vorlage stehen

### 4.3 Technische Leitplanken

- bestehende Apple-Vision-/OCR-Arbeit wird übernommen und modularisiert
- KI-Auswertung läuft über einen serverseitigen Provider, nicht über einen vom Betreiber eingegebenen API-Schlüssel
- jedes KI-Ergebnis ist ein Entwurf
- Originalseiten bleiben während der Prüfung sichtbar
- Artikel, Varianten und Kategorien sind in der Importprüfung editierbar
- PDF, Kamera und Fotomediathek verwenden dieselbe Import-Pipeline

## 5. Restaurant-Onboarding

Nach dem Scan bleibt die Einrichtung knapp und aufgabenbezogen.

1. Restaurantname und minimale Grunddaten
2. Betreiberkonto erstellen oder anmelden
3. Scan-Ergebnis speichern und veröffentlichen
4. Öffnungszeiten und Bestellkanäle wählen
5. Bereiche, Tische und Plätze anlegen
6. Küche, Bar und weitere Stationen konfigurieren
7. Mitarbeiter per Link oder QR einladen
8. Zahlungs-, Kassen- und Steuerprofil im Sandbox-Modus einrichten
9. vollständige Demo-Bestellung durchführen
10. Sandbox-Restaurant aktivieren

Zusätzlich steht jederzeit ein sofort nutzbares und zurücksetzbares Demo-Restaurant bereit.

## 6. Tisch-, Bestell- und Rechnungskern

### 6.1 Gemeinsame Tisch-Session

Ein belegter Tisch besitzt eine gemeinsame offene Session.

- Kellner und mehrere Gäste können gleichzeitig hinzufügen.
- Jede Bestellung und Position bleibt ihrer Quelle zuordenbar.
- Gäste können anonym oder angemeldet bestellen.
- Positionen können verschoben, geteilt oder zusammengeführt werden.
- Rechnung kann gemeinsam, einzeln oder teilweise bezahlt werden.
- mehrere Zahlarten innerhalb einer Rechnung sind möglich.
- Trinkgeld kann pro Zahlung erfasst werden.

### 6.2 Bestellquellen der Sandbox-Beta

- Gastbestellung per Tisch-QR
- Bestellung durch Kellner
- Bestellung an Theke oder Bar
- Take-away zur Abholung
- Vorbestellung für einen späteren Zeitpunkt
- Lieferung
- telefonische Bestellung durch einen Mitarbeiter

Alle Kanäle verwenden denselben Artikel-, Preis-, Steuer-, Stations-, Zahlungs- und Statuskern.

### 6.3 Annahmeregel

- Gastbestellungen werden standardmäßig nach erfolgreicher Validierung automatisch angenommen.
- Betreiber kann Bestätigungspflicht global, pro Standort, Bereich, Kanal oder Zeitraum aktivieren.
- Mitarbeiterbestellungen werden standardmäßig direkt angenommen.
- Preis, Verfügbarkeit, Öffnungszeit und Bestellkapazität werden vor Annahme serverseitig beziehungsweise lokal-authoritativ geprüft.

### 6.4 Statusmodell

```text
draft -> submitted -> accepted -> in_progress -> ready -> served/completed
                   -> rejected
accepted/in_progress -> cancelled
completed -> partially_refunded/refunded
```

Positionen besitzen zusätzlich eigene Stations- und Produktionsstatus.

## 7. Service, Küche und Bar

KitchenLink Business besitzt rollen- und geräteabhängige Stationsmodi.

- Ein iPhone kann in einem kleinen Betrieb alle Aufgaben anzeigen.
- Mehrere Geräte können Service, Küche, Bar, Kasse oder Fahrer zugeordnet sein.
- Positionen werden automatisch nach Produktionsstation getrennt.
- Geräte synchronisieren Status lokal und über die Cloud.
- Service sieht, welche Station noch arbeitet.
- Küche und Bar sehen Varianten, Notizen, Allergene und Priorität.
- Rückfragen und Probleme werden als strukturierte Ereignisse an den Service gesendet.
- akustische und visuelle Hinweise sind pro Station konfigurierbar.

## 8. Zahlung und Kasse

### 8.1 Sandbox-Beta

Alle Zahlungswege werden vollständig simuliert:

- Bargeld
- Kartenzahlung beim Mitarbeiter
- Tap to Pay
- Onlinezahlung im Gast-Web
- Zahlung bei Lieferung
- Gutschein und Guthaben
- Split- und Teilzahlung
- Trinkgeld
- Storno und Erstattung

Keine Sandbox-Zahlung bewegt echtes Geld.

### 8.2 Provider-Architektur

- `PaymentProvider`: zunächst Sandbox-Provider, später echte PSPs
- `FiscalizationProvider`: zunächst simulierte TSE, später zertifizierte Lösung
- `ReceiptProvider`: digitale und simulierte Druckausgabe
- Zahlungs- und Bestellstatus sind getrennt
- Kartendaten werden nie von KitchenLink selbst gespeichert
- jeder Zahlungsvorgang ist idempotent und auditiert

### 8.3 Betriebsschicht und Tagesabschluss

- Betreiber oder Manager öffnet eine gemeinsame Betriebsschicht.
- optionaler Bargeld-Anfangsbestand
- alle Geräte arbeiten auf derselben Venue-Schicht
- Einnahmen, Trinkgeld, Ausgaben, Entnahmen, Stornos und Erstattungen werden gesammelt
- Bargeldzählung und dokumentierte Abweichung beim Abschluss
- Tagesbericht und Sandbox-Z-Bericht

## 9. Personal und Schichtplanung

Die vollständige Personalplanung ist Pflichtbestandteil der Sandbox-Beta.

### 9.1 Mitarbeiter und Rechte

- Mitarbeiterprofile
- Standortzuordnung
- Rollen und Qualifikationen
- Standardrollen: Inhaber, Manager, Schichtleitung, Service, Küche, Bar, Fahrer, Lager und Buchhaltung
- eigene Rollen mit granularen Rechten
- sensible Aktionen per besonderem Recht oder Manager-PIN
- Rechte pro Organisation und Standort

### 9.2 Planung

- Verfügbarkeiten und Abwesenheiten
- Wochen- und Monatsplanung
- Schichtvorlagen und Wiederholungen
- Zuordnung zu Bereichen und Stationen
- Sollbesetzung und Unterbesetzungswarnung
- Veröffentlichung und Benachrichtigung
- Annahme, Ablehnung und Tauschanfrage
- Urlaubs- und Krankmeldungen

### 9.3 Zeit und Auswertung

- Ein- und Ausstempeln
- Pausen
- Soll-/Ist-Vergleich
- Überstunden
- Korrektur mit Freigabe und Audit
- spätere Lohnbuchhaltungs- und Steuerberaterexporte

Betriebsschicht, geplante Arbeitsschicht und tatsächlicher Zeiteintrag bleiben getrennte Fachobjekte.

## 10. Reservierung und Tischbelegung

Pflichtumfang der Sandbox-Beta:

- Online-Reservierung durch Gäste
- telefonische Reservierung durch Mitarbeiter
- grafischer Tischplan
- Tischzuweisung, Zusammenlegen und Umsetzen
- Walk-ins und Warteliste
- Aufenthaltsdauer und Folgebelegung
- Gruppenreservierungen
- Gastnotizen und besondere Anforderungen
- simulierte Anzahlung und No-Show-Gebühr
- Verknüpfung von Reservierung, Gastprofil und späterer Tisch-Session

## 11. Warenwirtschaft und Einkauf

Die vollständige Warenwirtschaft ist Pflichtbestandteil der Sandbox-Beta.

- Zutaten, Verkaufsartikel und Einheiten
- Rezepte und Zutatenmengen
- Lagerorte und Bestände
- automatische Bestandsbewegung durch abgeschlossene Bestellungen
- Reservierung von Bestand für Vorbestellungen
- Lieferanten und Einkaufspreise
- Bestellvorschläge
- Lieferantenbestellungen
- Wareneingang
- Inventur
- Bruch, Verderb, Eigenverbrauch und Korrektur
- Mindestbestände und Warnungen
- Wareneinsatz, Rezeptkosten und Deckungsbeitrag
- Preisentwicklung
- Umlagerungen zwischen Standorten

Jede Bestandsänderung wird als unveränderliche Lagerbewegung gespeichert. Der aktuelle Bestand wird daraus abgeleitet.

## 12. Lieferung

KitchenLink steuert in der Sandbox-Beta einen eigenen Lieferbetrieb.

- Liefergebiete
- Mindestbestellwert und Liefergebühr
- Zeitfenster und Kapazitätsgrenzen
- manuelle oder automatische Fahrerzuweisung
- Fahrermodus in KitchenLink Business
- Abholung in der Küche
- Zustellstatus und Kundenansicht
- Navigation über Karten-App
- Bar- oder simulierte Kartenzahlung bei Lieferung
- Trinkgeld
- mehrere Lieferungen pro Tour
- Rückgabe und fehlgeschlagene Zustellung

Externe Lieferplattformen folgen später über Integrationen.

## 13. Kundenkonto und Loyalty

### 13.1 Gast ohne Konto

- Tischbestellung und Gastzahlung ohne Registrierung
- temporäre Sitzung
- keine unnötigen personenbezogenen Daten

### 13.2 Optionales Kundenkonto

- Bestell- und Belegverlauf
- gespeicherte Lieferadressen
- Favoriten und Wiederbestellung
- Reservierungsverlauf
- Treuepunkte und Kundenstufen
- Gutscheine, Rabattcodes und Aktionen
- Feedback und Reklamationen
- Einwilligungen für Marketing und Datenschutz
- simulierte gespeicherte Zahlarten als Provider-Tokens

## 14. Multi-Location

Die Sandbox-Beta unterstützt mehrere Standorte innerhalb einer Organisation.

- zentrale Organisation und Eigentümerstruktur
- standortbezogene Berechtigungen
- gemeinsame oder lokale Menüs, Preise und Aktionen
- standortübergreifende Personalplanung
- zentrale Kunden- und Loyalty-Daten
- Lager und Lieferanten je Standort
- Warenumlagerungen
- einzelne und konsolidierte Auswertungen
- eigenes Zahlungs-, Kassen- und Steuerprofil je Standort

## 15. Abrechnung, Berichte und Steuergrenze

### 15.1 In der Sandbox-Beta

- Rechnungen und Belege
- Trinkgeld, Rabatte, Storno und Erstattung
- Kassenbuch
- Tagesabschluss
- deutsche Steuersätze und Steueraufteilung als Simulation
- simulierte TSE- und Belegdaten
- DSFinV-K-, DATEV- und Steuerberaterexport als Testdateien
- Eingangsrechnungen und Betriebsausgaben
- Umsatz-, Kosten-, Personal- und Gewinnauswertungen

### 15.2 Nach der Sandbox-Beta

- zertifizierte TSE/Fiskalisierung
- echte Payment-Provider
- rechtlich geprüfte Exporte
- echte Umsatzsteuervoranmeldung
- Lohnabrechnung
- Einkommen- und Gewerbesteuerunterstützung
- direkte Kommunikation mit Steuerberater- und Finanzamtsdiensten

## 16. Offline- und Venue-Hub-Architektur

Echter lokaler Mehrgerätebetrieb ist Pflichtbestandteil der Sandbox-Beta.

### 16.1 Betriebsmodell

- Während einer geöffneten Betriebsschicht läuft ein iPhone oder iPad sichtbar im Venue-Hub-Modus.
- Das Hub-Gerät bleibt im Vordergrund, am Strom und im lokalen WLAN.
- weitere Business-Geräte replizieren relevante Ereignisse lokal
- bei Ausfall übernimmt ein anderes geeignetes aktives Gerät
- Cloud-Synchronisation läuft zusätzlich, wenn Internet verfügbar ist
- nach Wiederverbindung werden Ereignisse idempotent abgeglichen

### 16.2 Gastbestellung bei Ausfall

- Bei Cloud-Ausfall kann ein Gast nur dann lokal bestellen, wenn er mit dem Restaurant-WLAN verbunden ist und die lokale Gastoberfläche erreicht.
- Ohne Restaurant-WLAN oder Mobilfunk kann ein Gastgerät das Restaurant nicht erreichen.
- Die App darf nie eine Bestellung als angekommen bestätigen, bevor mindestens ein autoritativer Venue-Knoten sie dauerhaft gespeichert hat.

### 16.3 Synchronisationsprinzipien

- lokale SQLite-Datenbank auf Business-Geräten
- append-only Ereignisprotokoll für kritische Vorgänge
- globale IDs, Idempotenzschlüssel und Gerätesignaturen
- Outbox/Inbox-Synchronisation
- deterministische Konfliktregeln je Fachobjekt
- niemals stille Last-write-wins-Regel für Zahlungen, Bestand oder Kassenereignisse
- sichtbarer Status: online, lokal verbunden, eingeschränkt, offline, synchronisiert, Konflikt

## 17. Hardwaregrenze der Sandbox

KitchenLink muss ohne zusätzliche Restaurant-Hardware funktionieren.

In der Sandbox werden simuliert:

- Belegdrucker
- Küchenbondrucker
- Kassenschublade
- Barcode-Scanner
- Waage
- externes Kartenterminal

Küchendisplays laufen bereits auf iPhone, iPad oder Browser. Echte Hardwareadapter folgen nach der Sandbox, ohne das Domainmodell zu verändern.

## 18. Technische Zielarchitektur

### 18.1 Grundsatz

Kontrollierter Neuaufbau im bestehenden Repository:

- vorhandene App bleibt zunächst als Referenzprototyp erhalten
- funktionierende Fachlogik wird gezielt extrahiert
- monolithische UI wird nicht weiter vergrößert
- neue Module werden parallel aufgebaut
- alter Code wird erst entfernt, wenn ein getesteter Ersatz existiert

### 18.2 Clients

- Business: SwiftUI für iOS/iPadOS
- Gast-Web und Browser-Verwaltung: TypeScript-basierte responsive Webanwendung/PWA
- gemeinsame API-Verträge und generierte Typen, keine duplizierten freien Datenmodelle

### 18.3 Cloud

Supabase bleibt gesetzt:

- PostgreSQL
- Auth
- Storage
- Realtime als Benachrichtigungskanal
- serverseitige Funktionen für privilegierte Vorgänge
- SQL-Migrationen und Row Level Security
- getrennte Projekte für Entwicklung, Sandbox und Produktion

Supabase Realtime ist nicht die Quelle der Wahrheit. Jeder Client kann den autoritativen Zustand aus Datenbank beziehungsweise Venue Hub neu laden.

### 18.4 Kernmodule

```text
Identity & Access
Organizations & Venues
Menu Import & Catalog
Floor, Tables & Reservations
Orders & Fulfillment
Checks, Payments & Fiscalization
Workforce & Scheduling
Inventory & Procurement
Delivery & Dispatch
Customers & Loyalty
Reporting & Accounting
Device, Offline & Sync
Demo & Sandbox Providers
```

### 18.5 Provider-Schnittstellen

Externe oder noch simulierte Fähigkeiten werden hinter stabilen Protokollen gekapselt:

- MenuIntelligenceProvider
- PaymentProvider
- FiscalizationProvider
- PrintProvider
- NotificationProvider
- RoutingProvider
- AccountingExportProvider

## 19. Zentrale Datenobjekte

- Organization, Venue, Zone, Table, Station, Device
- User, Membership, Role, Permission
- Menu, MenuVersion, Category, Item, Modifier, Allergen
- TableSession, Order, OrderItem, OrderEvent
- Check, Payment, PaymentAllocation, Tip, Refund
- VenueShift, PlannedShift, TimeEntry, Availability, LeaveRequest
- Reservation, WaitlistEntry, Seating
- Ingredient, Recipe, StockLocation, StockMovement
- Supplier, PurchaseOrder, GoodsReceipt, InventoryCount
- Delivery, DriverAssignment, DeliveryTour
- Customer, Address, LoyaltyAccount, Voucher, Consent
- Expense, Invoice, Receipt, CashMovement, FiscalEvent, ExportJob
- SyncEvent, OutboxEntry, Conflict, DeviceCheckpoint

## 20. Sandbox-Grundsätze

- sichtbares Sandbox-Banner auf jeder Oberfläche
- kein echtes Geld
- keine steuerlich gültigen Belege
- keine echten Hardwareaktionen
- Demo-Uhr und Szenarien steuerbar
- vorbereitete Restaurant-, Mitarbeiter-, Kunden- und Lieferdaten
- Netzwerkfehler, Zahlungsverzögerung und Geräteausfall simulierbar
- vollständige Rücksetzung pro Organisation oder Standort
- keine Mischung mit späteren Produktionsdaten

## 21. Interne Entwicklungsmeilensteine

Alle folgenden Module gehören zur Sandbox-Beta. Die Reihenfolge ist nur die Build-Reihenfolge, keine Reduktion des Beta-Umfangs.

### Meilenstein 1: Scan bis Bezahlung

1. scan-first App-Einstieg ohne Konto
2. Menüerkennung und editierbare Prüfung
3. Konto und Restaurant aus Scan-Ergebnis anlegen
4. Bereiche, Tische und Stationen
5. Gast-Web per QR
6. gemeinsame Tisch-Session
7. Gast- und Kellnerbestellung
8. automatische oder bestätigungspflichtige Annahme
9. Küche-/Bar-Routing
10. Fertigstellung und Auslieferung
11. Split-Rechnung, Trinkgeld und Sandbox-Zahlung
12. lokale Venue-Hub-Verteilung und Cloud-Abgleich

### Meilenstein 2: Tagesbetrieb und Personal

- Betriebsschicht und Kassenabschluss
- Rollen und Berechtigungen
- vollständige Schichtplanung
- Zeit-, Pausen-, Urlaubs- und Krankheitsverwaltung
- Soll-/Ist-Auswertung

### Meilenstein 3: Reservierung und Omnichannel

- Tischplan, Reservierung und Warteliste
- Theke, Telefon, Abholung und Vorbestellung
- eigener Lieferbetrieb und Fahrer

### Meilenstein 4: Warenwirtschaft

- Zutaten, Rezepte und Lager
- automatische Bewegungen
- Einkauf, Wareneingang, Inventur und Kalkulation

### Meilenstein 5: Kunden und Wachstum

- Kundenkonto
- Loyalty, Gutscheine und Aktionen
- Feedback
- Multi-Location

### Meilenstein 6: Abrechnungssandbox

- Kassenbuch und Ausgaben
- Rechnungen und Belege
- simulierte TSE
- DSFinV-K-/DATEV-Testexport
- konsolidierte Berichte

### Meilenstein 7: Beta-Härtung

- vollständige Offline-, Konflikt- und Wiederanlauftests
- Security- und RLS-Tests
- Accessibility
- Performance und Lasttests
- Datenexport und Backup/Restore
- geführte Demo-Szenarien

## 22. Definition der Sandbox-Beta

Die Sandbox-Beta ist vollständig, wenn:

- alle bestätigten Produktmodule testbar sind
- ein Restaurant ohne Zusatzhardware vollständig simuliert betrieben werden kann
- alle Rollen auf ihren vorgesehenen Oberflächen arbeiten können
- der Scan-to-Payment-Ablauf Ende-zu-Ende funktioniert
- Mehrgerätebetrieb online und lokal funktioniert
- keine Bestellung, Zahlung, Zeit- oder Lagerbewegung verloren oder doppelt erzeugt wird
- Demo-Provider externe Systeme realistisch ersetzen
- alle Daten vollständig zurücksetzbar sind
- kritische Fachregeln automatisiert getestet sind

## 23. Bewusst nachgelagert

Nicht Teil der Sandbox-Beta sind nur echte externe Wirkungen:

- Live-Payment
- zertifizierte TSE und rechtsgültiger Kassenbetrieb
- echte Steuererklärung oder Finanzamtübermittlung
- echte Lohnabrechnung
- breite physische Hardwareunterstützung
- externe Lieferplattformintegrationen
- Android-Business-App
- separate Kunden-App

Die fachlichen Schnittstellen und Sandbox-Abläufe dafür müssen jedoch bereits existieren.

## 24. Marktbeobachtung

Marktanalyse wird durch KitchenLink selbst durchgeführt und laufend aktualisiert. Betreiberinterviews sind keine Voraussetzung für den aktuellen Aufbau; sie können später vor einer Live-Beta zur Validierung und Härtung eingesetzt werden.

Wichtige Ausgangspunkte:

- Das deutsche Gastgewerbe umfasst laut Destatis rund 245.000 rechtliche Einheiten und steht unter realem Umsatzdruck.
- Gäste nutzen digitale Restaurantinformationen selbstverständlich, erwarten aber weiterhin Wahlfreiheit.
- QR-Bestellung allein ist durch etablierte Kassen- und Paymentanbieter austauschbar geworden.
- Wettbewerber bündeln häufig Kasse, QR, Payment und Küche, verlangen aber oft eine bestimmte Systemlandschaft.
- KitchenLinks Differenzierung ist die Kombination aus scan-first Einrichtung, vollständigem smartphone-first Betrieb, optionaler Hardware und echter lokaler Ausfallsicherheit.

Quellen:

- [Destatis: Gastgewerbeumsatz 2025](https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/02/PD26_054_45213.html)
- [Destatis: Unternehmensregister Gastgewerbe](https://www.destatis.de/DE/Themen/Branchen-Unternehmen/Unternehmen/Unternehmensregister/Tabellen/unternehmen-beschaeftigte-umsatz-wz08.html)
- [Bundesbank: Zahlungsverhalten 2025](https://www.bundesbank.de/de/presse/pressenotizen/zahlungsverhalten-in-deutschland-2025-964736)
- [METRO/YouGov: Digitale Gastronomie](https://newsroom.metroag.de/de/news/repraesentative-umfrage-digitale-gastronomie?dt=20250221)
- [Bitkom: Digitale Restaurantangebote](https://www.bitkom.org/Presse/Presseinformation/Restaurants-und-Cafes-Online-Bewertungen-entscheidend)
- [orderbird Bestellmanagement](https://www.orderbird.com/de/bestellmanagement)
- [Lightspeed Order Anywhere](https://www.lightspeedhq.de/kassensystem/restaurant/order-anywhere/)
- [Gastronovi Preise](https://www.gastronovi.com/preise/preisuebersicht/)
- [DISH Professional Order](https://www.dish.co/DE/de/bestellsystem-gastronomie/)
- [Apple Tap to Pay on iPhone](https://developer.apple.com/tap-to-pay/)
- [Apple Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity)

## 25. Nächster konkreter Schritt

Der kontrollierte Neuaufbau beginnt mit Meilenstein 1 und darin zuerst mit:

1. modularer App-Root
2. scan-first Einstieg
3. Extraktion der bestehenden Menüimportlogik
4. editierbarer Importentwurf
5. Sandbox-Sitzung vor Registrierung

Erst danach wird der Scan mit Restaurantanlage, Tischmodell und Bestellkern verbunden.
