# Claude Code Handoff

**Updated:** 16 July 2026
**Branch:** `claude/design-audit`
**Status:** Phase A (KL-CLAUDE-001) und Phase B (KL-OPS-001) abgeschlossen;
Merge wartet auf visuelle Nutzerfreigabe

## Scope

Zweiphasige Mission nach `docs/collaboration/CLAUDE_MISSION.md`. Primaere
visuelle Quelle war das lebende Claude-Design-Projekt (`d564bf09-…`,
"KitchenLink Brand Territories.dc.html"); es ist byte-identisch (SHA-256
`3077…e0bc`) mit `docs/design/claude-design/round-04/export/territories.html`.
Grenze der Nutzerfreigaben war `docs/collaboration/DECISIONS.md`; kein Design
wurde dadurch zusaetzlich freigegeben.

## Completed

### Phase A — unabhaengiges Audit

- `docs/collaboration/reviews/CLAUDE_AUDIT_2026-07-16.md`: keine P0/P1;
  1x P2 (unlokalisierte Draft-Evidenz, Eingangsbedingung fuer KL-MENU-004),
  4x P3. Unit-, UI- und Benchmark-Laeufe reproduzierten alle dokumentierten
  Ergebnisse.

### Phase B — Heute und Kueche als Round-04-Referenzflaechen

- `kitchenlink/Features/Today/KitchenLinkV2TodayEvents.swift`: pure, getestete
  Ableitung Sandbox-Bestellung -> Ereignis (Vorgangsart = Form, Dringlichkeit =
  Farbe, Verb sichtbar). Offene Zahlung (serviert) ist neutral; Kueche ueber
  Richtzeit wird Amber; storniert traegt keine naechste Handlung.
- `kitchenlink/Features/Today/KitchenLinkV2TodayView.swift`: ereignisorientierte
  Arbeitsliste mit Verbindungszeile (durchgestrichener Ring nur bei fehlendem
  Empfang), genau einer Zitronen-Primaeraktion (naechste Handlung des
  dringendsten Ereignisses bzw. "Service starten") und traubenbasierter
  Demo-Aktion.
- `kitchenlink/Features/Today/KitchenLinkV2DemoOperations.swift`: Demo-Szenario
  ueber die bestehende Repository-/Relay-Domaene (send + regulaere
  Statusuebergaenge, rueckdatierte `createdAt`); ersetzt lokale
  Sandbox-Bestellungen, keine zweite Bestell-Domaene.
- `kitchenlink/Features/Kitchen/KitchenLinkV2KitchenView.swift`: Kuechenboard
  auf Tief (per Designsystem immer dunkel), adaptives Grid, sechs gleichzeitige
  Tickets auf iPad ohne horizontales Scrollen, Urgency-Oberkante, Hinweis als
  Quadrat-Form, 44-Punkt-Aktionen, keine Zitrone.
- `kitchenlink/App/KitchenLinkV2BusinessHomeView.swift`: Betriebszugang
  (`business.openToday`, `business.openKitchen`).
- `kitchenlink/App/KitchenLinkDesignPreviewConfiguration.swift` und
  `KitchenLinkRootView.swift`: Sandbox-Launch-Argumente
  `--kitchenlink-demo-service` (Szenario beim Oeffnen von Heute/Kueche) und
  `--kitchenlink-appearance-light/-dark` (reproduzierbare visuelle Checks).

## Files Changed

- Neu: `kitchenlink/Features/Today/` (3 Dateien),
  `kitchenlink/Features/Kitchen/KitchenLinkV2KitchenView.swift`,
  `kitchenlinkTests/KitchenLinkV2TodayEventsTests.swift`,
  `kitchenlinkUITests/kitchenlinkV2ScreenshotTests.swift` (Capture-Harness,
  ohne Umgebungsflag uebersprungen).
- Geaendert: `kitchenlink/App/…` (3 Dateien, Navigation + Launch-Argumente),
  `kitchenlinkTests/KitchenLinkDesignSystemV2Tests.swift` (6a-Kontrasttest),
  `kitchenlinkUITests/kitchenlinkUITests.swift` (Navigations-Smoke),
  `docs/collaboration/handoffs/CLAUDE.md`,
  `docs/collaboration/reviews/CLAUDE_AUDIT_2026-07-16.md` (Phase A).

## Verification

- Unit-Suite iPhone 17 Pro: TEST SUCCEEDED, inklusive 7 neuer
  Ereignis-/Ticket-Tests und des parametrischen Urgency-Kontrasttests
  (alle Symbole >= 3:1 auf Sprudel, Traube, Tief und `#383048`).
- UI-Suite: 4/4, inklusive neuem Smoke V2-Home -> Heute -> Kueche mit stabilen
  Accessibility-IDs.
- Scanner-Benchmark nach den Phase-B-Aenderungen erneut ausgefuehrt:
  passed, Werte unveraendert.
- Visuell geprueft (Screenshots via Capture-Harness): Heute iPhone hell und
  dunkel, Kueche iPhone dunkel, Heute und Kueche iPad Pro 13" dunkel mit sechs
  gleichzeitigen Tickets (3x2-Raster, kein horizontales Scrollen). Abnahmefaelle
  sichtbar: neue Bestellung (frisch), Kueche wartet (+3:00, Amber), Zahlung
  offen (neutral, Betrag), Hinweis "Bitte ohne Ei" (Quadrat), Empfangszeile.
- Legacy-Startpfad und Scan-Flow unveraendert (bestehende UI-Tests gruen).

### Nachschärfung Bump-Aktion (Nutzerfeedback 16. Juli)

- Abwaegung Wischgeste vs. Button: Der Button gewinnt als primaerer Weg
  (nasse Haende, Gestenkonflikt mit Scrollen, Entdeckbarkeit, VoiceOver).
  Eine Wischgeste bleibt als spaeterer Beschleuniger denkbar, aber erst mit
  einem Rueckgaengig-Mechanismus; die Bestell-Domaene kennt bisher keine
  Rueckwaertsuebergaenge.
- Neuer `KitchenLinkV2KitchenBumpButtonStyle`: volle Ticketbreite, 52 pt,
  Licht-Fuellung mit Traube-Text (~12:1 gegen das Ticket). Bewusst keine
  Zitrone (wiederholte Aktion, Kuechenstatus). Haptisches Erfolgs-Feedback
  ueber `sensoryFeedback(.success:)`.
- Kontraste des Buttons (ruhend, gedrueckt, deaktiviert) sind als Unit-Test
  abgesichert; iPad-Board erneut visuell geprueft, sechs Tickets bleiben
  gleichzeitig sichtbar.

## Risks And Open Work

- `Heute` kennt keine echte Zahlungs-Domaene: "Zahlung offen" ist die
  Interpretation von `served` und traegt bewusst keine Aktion.
- Offline-Zustand ist der Empfangszustand des lokalen Demo-Relays; ein echter
  Venue-Hub-/Sync-Status existiert noch nicht (bekannte Blueprint-Luecke).
- Das Demo-Szenario ersetzt beim Laden alle lokalen Sandbox-Bestellungen
  (bewusst, im Button-Hinweis dokumentiert).
- P2-1 aus dem Audit bleibt Eingangsbedingung fuer KL-MENU-004.
- `gh` CLI fehlt lokal; Draft-PR ueber
  https://github.com/boethius68/KitchenLink/pull/new/claude/design-audit anlegen.

## Recommended Next Step

Visuelle Nutzerfreigabe der beiden Referenzflaechen einholen; danach Merge nach
`main` durch einen beliebigen Peer und Fortsetzung mit KL-MENU-004
(Evidenz-Review, inkl. Entscheidung zu P2-1) sowie dem Offline-E2E-Smoke in
getrennten Scopes.
