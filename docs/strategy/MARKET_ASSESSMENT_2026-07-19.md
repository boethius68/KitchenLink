# Markt- und Fokus-Einschätzung (Claude Code, 19. Juli 2026)

**Status:** Analyse und Empfehlung, keine genehmigte Produktentscheidung.
Entscheidungen bleiben in `docs/collaboration/DECISIONS.md`; der verbindliche
Produktumfang steht in `docs/PRODUCT_BLUEPRINT.md`. Dieses Dokument hält die
Bewertung fest, die am 19. Juli 2026 zur Priorisierung der Cloud-Bestellschleife
(KL-CLOUD-001) geführt hat, damit sie für spätere Arbeit nachlesbar bleibt.

## 1. Ausgangslage zum Bewertungszeitpunkt

- Gast-Web live auf `https://kitchenlink.luneq.eu` (Next.js auf Hostinger,
  Supabase EU-Frankfurt, Projekt `rjxlzqtaxqstctrrlqre`), anonyme Bestellung
  Ende-zu-Ende verifiziert.
- iOS-Sandbox-App mit Scan-/OCR-Import inkl. 14-Seiten-Benchmark, V2-Flächen
  `Heute`/`Küche`, read-only Warenwirtschaft, isolierten Workforce-/
  Inventory-Domänen.
- Offline-Venue-Hub: iPhone hostet die lokale Gastseite selbst, Event-Log mit
  ACK-nach-Commit, WLAN-Verlust/-Recovery real abgenommen (PR #25/#27).
- Design: 4a-`Ruhe`-Richtung (Traube/Zitrone) als Arbeitsbasis; Logo und exakte
  Palette bewusst offen.

## 2. Was für Markterfolg spricht

1. **Echte Differenzierung.** Scan-first-Onboarding + reiner
   Smartphone-Betrieb + lokale Ausfallsicherheit bietet keiner der etablierten
   Anbieter (orderbird, gastronovi, Lightspeed, DISH) in dieser Kombination.
   Der Menüscan ist ein Null-Reibungs-Einstieg, während die Konkurrenz mit
   Vertriebsgespräch und Hardware-Bundle beginnt.
2. **Engineering-Qualität als Asset.** Idempotenz, Event-Sourcing,
   ACK-nach-Commit, RLS, reale Geräteabnahmen — genau das Fundament, das ein
   System braucht, das später Geld und Kassendaten verantwortet.

## 3. Risiken und Lücken

1. **Beta-Umfang ist das größte Risiko.** Blueprint §21/§22 definiert die
   Sandbox-Beta als vollständiges Gastro-ERP (inkl. Lieferung, Loyalty,
   Multi-Location, Abrechnung). Gefahr: der verkaufbare Kern wird durch die
   Breite verdünnt. Empfehlung: intern einen deutlich kleineren
   „Pilot-Schnitt" definieren — **Scan → QR-Bestellung → Küche → einfache
   Zahlung**.
2. **Zahlung und Fiskalisierung sind das eigentliche Markttor** — mit der
   längsten Vorlaufzeit (KassenSichV/TSE, PSP-Verträge). Alles ist simuliert;
   es gibt noch keine Provider-Vorentscheidung (Kandidaten: fiskaly als
   Cloud-TSE; Stripe/Adyen/SumUp als PSP; Tap to Pay on iPhone). Das ist keine
   Coding-Aufgabe für jetzt, aber eine Recherche-/Entscheidungsaufgabe, die
   nicht bis nach der Beta warten sollte — Payment ist zugleich das dominante
   Monetarisierungsmodell der Konkurrenz.
3. **Nicht-Feature-Bausteine fehlen:** kein Preis-/Monetarisierungsmodell,
   kein Go-to-Market-Ansatz dokumentiert. Blueprint §24 erklärt
   Betreiberinterviews für nicht erforderlich — die riskanteste Einzelannahme.
   Sobald die Demo-Schleife steht: 3–5 echte Gastronomen den
   Scan-zu-Bestellung-Ablauf live sehen lassen, bevor Meilenstein 2–6 gebaut
   werden.
4. **Kleinere fachliche Lücken** für den Erstmarkt: Allergen-/LMIV-
   Pflichtangaben beim Veröffentlichen einer Karte (rechtlich relevant; der
   Scan erkennt explizite Angaben immerhin), Mehrsprachigkeit der Gastkarte
   (Touristen), Menü-Sync zum Google Business Profile als günstiger
   Vertriebshebel.

## 4. Fokus-Befund vom 19. Juli 2026

Die Offline-Hub-Arbeit (KL-OFFLINE-003…007) war Blueprint-Pflicht und
technisch stark, aber die zwei Produkthälften waren nicht verbunden:

- Bestellungen von `kitchenlink.luneq.eu` landeten in Supabase, aber **keine
  Betreiberoberfläche las sie** (einzige Lese-Policy war der Gast selbst).
- Der Menüscan publizierte **nicht** ins Gast-Web (nur ins lokale
  Sandbox-Menü).

Die erste Lücke schließt KL-CLOUD-001 (Betreiber-Lesepfad, Status-RPC,
Presence-Heartbeat, automatischer Lokal-Fallback im Gast-Web — seit 19. Juli
in `main`; reale Abnahme offen). Die zweite Lücke ist der nächste große
Produktschritt.

## 5. Empfohlene Reihenfolge (Stand 19. Juli 2026)

1. ~~**Cloud-Bestellschleife schließen** (KL-CLOUD-001).~~ Umgesetzt; reale
   Web-zu-iPhone-Abnahme offen.
2. **Scan-zu-Publish-Brücke:** geprüften Import-Draft in die Supabase-Venue
   veröffentlichen — macht den Kern-Pitch (Papierkarte → Minuten später
   bestellen Gäste per QR) erstmals vorführbar.
3. **Tisch-Kontext im Gast-Web:** QR mit Tischparameter + minimale
   Tisch-Session; Voraussetzung für echten In-Restaurant-Betrieb.
4. **Parallel als Papier-Aufgabe:** Provider-Vorentscheidung Payment/TSE und
   ein grobes Preismodell — entschärft die längsten Vorlaufzeiten ohne Code.
5. **Zurückstellen:** weitere Offline-Gates (Android, TLS,
   Hintergrundbetrieb), Lieferung, Loyalty, Multi-Location.

Mit Schritt 1–3 entsteht die geschlossene Schleife *Papierkarte → digitale
Karte → QR am Tisch → Bestellung → Küche → serviert* über das Internet — der
Moment, in dem sich der Plan erstmals an echten Gastronomen testen lässt.

## 6. Dauerhafte Leitplanke (vom Nutzer am 19. Juli 2026 vorgegeben)

Die App muss **über den gesamten Entwicklungsprozess benutzerfreundlich
bleiben**: keine technischen Formulare in Produktwegen, keine
Modus-Vorauswahl, Entwicklungs-/Demo-Zugänge sichtbar getrennt vom
Produktweg. Details als Entscheidung in `DECISIONS.md`.
