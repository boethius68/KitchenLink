# KitchenLink Work Queue

**Stand:** 15. Juli 2026
**Phase:** Designsystem-Implementierung im internen Sandbox-Build

Diese Queue zerlegt die naechste Ausbaustufe in konfliktfreie Arbeitspakete. Ein
Agent uebernimmt immer genau ein Ticket in einem eigenen Branch oder Worktree.
Bestehende Demo-, Offline- und Simulationspfade duerfen nicht entfernt werden.

## Arbeitsregeln

- Vor Beginn `AGENTS.md`, `docs/collaboration/CURRENT.md`,
  `docs/collaboration/DECISIONS.md`, `docs/PRODUCT_BLUEPRINT.md` und
  `docs/design/DESIGN_SYSTEM.md` lesen.
- Der im Ticket genannte Schreibbereich ist exklusiv. Aenderungen ausserhalb
  dieses Bereichs werden vorher mit dem Integrator abgestimmt.
- Keine neuen Produktentscheidungen aus Designs ableiten.
- Keine Runtime-Abhaengigkeit von extern geladenen Schriften oder Farbdiensten.
- Jedes Ticket endet mit Build-/Testnachweis und einer kurzen Risikonotiz.

## Aktiver Schnitt

### KL-DS-001 - Semantische SwiftUI-Bausteine

**Status:** Erledigt
**Abhaengigkeit:** keine
**Schreibbereich:** `kitchenlink/DesignSystem/KitchenLinkDesignSystemV2.swift`
und optional eine gleichnamige Unit-Testdatei

**Auftrag**

- 4a-`Ruhe` als semantische Hell-/Dunkel-Tokens abbilden.
- Vorgangsart und Dringlichkeit als getrennte Typen modellieren.
- Flaeche, Karte, Primaer- und Sekundaeraktion fuer SwiftUI bereitstellen.
- Touch-Ziele ab 44 Punkt und die Zitronenregel technisch absichern.
- Bis zur Font-Freigabe sichere System-Fallbacks verwenden.

**Abnahme**

- App-Target kompiliert fuer iOS 17.
- Kein bestehendes Theme und kein Produktscreen wurde veraendert.
- Zitrone taucht in keinem Status-Token auf.

### KL-IOS-001 - Schaltbarer Scan-Einstieg V2

**Status:** In Review
**Abhaengigkeit:** KL-DS-001
**Schreibbereich:** `kitchenlink/App/`,
`kitchenlink/Features/MenuImport/` und gezielte UI-Tests

**Auftrag**

- Die neue Richtung als standardmaessig aktive Designvorschau integrieren.
- Einen gut sichtbaren Rueckweg zur bisherigen Oberflaeche erhalten.
- Den bestehenden Dokumentkamera-, Foto-, OCR-, Review- und Sandbox-Ablauf
  unveraendert weiterverwenden.
- Scan-Rahmen im Ruhezustand neutral halten; Zitrone nur fuer Primaeraktion und
  kurzen Erkennungserfolg nutzen.

**Abnahme**

- Scan und Fotoauswahl sind mit stabilen Accessibility-IDs erreichbar.
- Die Legacy-Sandbox bleibt aus der V2-Oberflaeche erreichbar.
- Ein Launch-Argument kann V2 fuer UI-Tests explizit ein- oder ausschalten.
- Dynamic Type schneidet bei den Accessibility-Groessen keine Pflichttexte ab.

### KL-QA-001 - Design- und Regressionspruefung

**Status:** Teilweise erledigt
**Abhaengigkeit:** KL-DS-001, KL-IOS-001
**Schreibbereich:** `kitchenlinkTests/` und `kitchenlinkUITests/`

**Auftrag**

- V2- und Legacy-Startpfad automatisiert pruefen.
- Mindestzielgroessen, wichtige Accessibility-Bezeichnungen und Reduce Motion
  fuer den Scan-Einstieg absichern.
- Bestehende Repository-, Relay-, Offline- und Bestelltests vollstaendig laufen
  lassen.

**Abnahme**

- Unit- und UI-Test-Suite laufen auf einem fest benannten iPhone-Simulator.
- Fehlende visuelle Assertions werden als konkrete Restluecke dokumentiert.

Unit-Tests, V2-/Legacy-UI-Smoke-Tests sowie manuelle Hell-, Dunkel- und maximale
Dynamic-Type-Pruefung sind erledigt. Offen bleibt ein lokaler End-to-End-Test vom
Gastauftrag bis zum Kuechenstatus ohne Cloudverbindung.

## Naechste parallele Scheiben

### KL-OPS-001 - Heute und Kueche

**Status:** Wartet
**Abhaengigkeit:** KL-DS-001, KL-IOS-001
**Voraussichtlicher Schreibbereich:** neue Views unter `kitchenlink/Features/Today/`
und `kitchenlink/Features/Kitchen/`

Ereignisorientiertes `Heute` und eine iPad-Kuechenansicht mit sechs gleichzeitig
lesbaren Tickets bauen. Beide verwenden echte Sandbox-Daten und das zweiachsige
Statusmodell. Kein Umbau der Bestell-Domain in diesem Ticket.

### KL-WEB-001 - Gast-Web-Grundlage

**Status:** Wartet auf Stack-Entscheidung
**Abhaengigkeit:** semantische Token-Namen aus KL-DS-001

Zuerst den Web-Stack und den Deployment-Pfad als kleine Architecture Decision
festlegen. Danach eine mobile Gastkarte mit acht Gerichten, Venue-fuehrendem
Branding, traubenbasierter Mengensteuerung und genau einer fixierten
Zitronenaktion umsetzen. Noch keine Live-Zahlung und keine Entfernung der
Sandbox-Daten.

## Integrationsreihenfolge

1. KL-DS-001 integrieren und kompilieren.
2. KL-IOS-001 funktional und visuell abnehmen.
3. KL-QA-001 ausfuehren und Luecken schliessen.
4. KL-OPS-001 und die Web-Stack-Entscheidung parallel starten.
5. Erst nach stabilen Referenzscreens weitere Produktmodule migrieren.
