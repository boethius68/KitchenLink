# Handoff — GLM (Offline Venue Hub Architektur)

**Datum:** 2026-07-16
**Agent:** GLM-5.2 via ZCode
**Ticket:** Discovery-Auftrag lokaler Venue-Hub (Blueprint §16)
**Branch:** `glm/offline-venue-hub`
**Status:** Quellenbasierte Zielarchitektur geliefert; kein Produktcode geändert

## Was in dieser Session erledigt wurde

1. Verbindliche Kontextdokumente gelesen: `AGENTS.md`,
   `docs/collaboration/DECISIONS.md`, `docs/PRODUCT_BLUEPRINT.md` (besonders
   §16), `docs/collaboration/PEER_WORKFLOW.md`, `CURRENT.md`, `WORK_QUEUE.md`
   und alle vier Handoffs.
2. Bestehende Quellcode-Basis analysiert:
   `OrderRelayService.swift`, `OrderingDomain.swift`, `KitchenLinkRepository.swift`.
   Befund: aktuell UserDefaults-basiert, kein SQLite, kein Event-Log, kein echter
   Mehrgeräte-Transport — nur lokales Speichern + Supabase-Polling.
3. Primärquellen-Recherche zu zehn Themenbereichen mit **55 Quellen**
   (Apple-Doku, WWDC, Original-Papers, sqlite.org, Supabase, objc.io, etc.).
4. Drei Deliverables erstellt:
   - `docs/discovery/offline-venue-hub/GLM_SOURCES.md` — Quellenregister
   - `docs/discovery/offline-venue-hub/GLM_ARCHITECTURE.md` — Zielarchitektur
   - dieses Handoff
5. Eigener Branch `glm/offline-venue-hub`, Commit und Push, Draft PR.

## Wichtigste architektonische Empfehlungen

- **Transport:** Network.framework (`NWListener`/`NWBrowser`) statt Multipeer
  Connectivity. MPC ist verworfen: 8-Peer-Limit [S14], Background-Abbruch [S15],
  Produktionstunzuverlässigkeit [S16][S20].
- **Persistenz:** SQLite mit WAL + append-only Event-Log + GRDB.swift
  `DatabasePool` [S28][S33]. Migration hinter bestehendem
  `KitchenLinkRepository`-Protokoll, Demo-Pfad bleibt erhalten.
- **Konfliktmodell:** Event Sourcing statt CRDT für kritische Fachobjekte
  (fachspezifische deterministische Regeln, Historie, keine stillen Merges gemäß
  Blueprint §16.3) [S48][S50][S53].
- **Leader-Wechsel:** vereinfachtes Lease-Modell (Raft-inspiriert [S36]) +
  SWIM-Gossip-Fehlerekennung [S39][S40]. Voll-Raft bewusst verworfen (Overkill
  für 2–5 vertrauenswürdige Geräte).
- **Sync:** eigene Outbox/Inbox-Logik mit Idempotenzkeys [S31]; Supabase
  implementiert Offline-Sync nicht nativ [S43]. Externe Sync-Engines
  (PowerSync/RxDB) für nach der Sandbox zurückgestellt.
- **Acknowledgement:** Bestellung gilt erst als angekommen, nachdem der Event
  dauerhaft in SQLite committet ist (Blueprint §16.2 erfüllt).

## Verifizierte Fakten vs. Annahmen klar getrennt

- **Verifizierte Fakten** (14, aus Primärquellen) in Architektur §1.1.
- **Annahmen** (7, plausibel aber nicht freigegeben) in Architektur §1.2.
- **Offene Risiken** (8, mit P0–P2-Priorität) in Architektur §1.3.

## Offene Produktentscheidungen (dem Nutzer vorzulegen)

Diese **fünf** Entscheidungen kann diese Architektur nicht selbst treffen und
werden im Draft PR sichtbar gemacht:

1. **🔴 P0 HTTPS-Lösung für lokale Gastoberfläche** — Self-signed? HTTP? Apple-CA?
   Blockiert Stufe 3 des Prototypplans.
2. **🔴 P0 WLAN-Anforderung** — wie wird Client-Isolation (`AP Isolation`)
   vermieden? Blockiert Stufe 3.
3. **🟠 P1 Hub-Gerät-Hardware** — iPad fest oder iPhone des Betreibers?
4. **🟠 P1 Background-Keepalive** — ist Audio-Background-Modus akzeptabel
   (Apple-Review-Risiko)?
5. **🟡 P2 Sync-Engine nach Sandbox** — eigene Logik vs. PowerSync/RxDB.

## Schreibbereich & Kollisionsfreiheit

- Ausschließlich neue Dateien unter `docs/discovery/offline-venue-hub/` und
  dieses Handoff erstellt.
- **Kein Produktcode** verändert.
- Keine Einträge in `DECISIONS.md` oder `CURRENT.md` (nur Discovery).
- Bestehende uncommittierte Arbeit anderer Agenten nicht berührt.

## Verbleibendes Risiko

- Die Architektur ist eine quellenbasierte Empfehlung, keine Freigabe.
- P0-Risiken (WLAN-Isolation, HTTPS) sind **technische Blocker** für jeden
  lokalen Bestellpfad und müssen vor Implementierung von Stufe 3 geklärt werden.
- Mehrgeräte- und Wiederanlauftests erfordern zwingend echte Hardware
  (Simulatoren können Bonjour/WLAN nicht realistisch abbilden).
- Die Annahme „ein Hub pro Venue" muss produktsprachlich bestätigt werden.
- Prototypplan ist nicht bindend; Stufen können nach Nutzerfeedback umgeordnet
  werden.

## Verification / Überprüfung

- Alle 55 Quellen am 2026-07-16 abgerufen und kategorisiert.
- Architekturdokument gegen Blueprint §16 (Offline- und Venue-Hub-Architektur)
  abgeglichen: alle geforderten Prinzipien (SQLite, append-only, globale IDs,
  Idempotenz, Outbox/Inbox, deterministische Konfliktregeln, keine stillen LWW,
  Sichtbarkeit) sind abgedeckt.
- Worktree clean vor Commit; `git status` zeigt nur die neuen Discovery-Dateien
  und das Handoff.
- Keine Build-/Testauswirkungen, da nur Markdown-Dokumente.

## Empfohlener nächster Schritt

Nach Nutzerfreigabe der P0-Entscheidungen (HTTPS-Lösung + WLAN-Anforderung) kann
die Implementierung bei Stufe 1 (lokales Event-Log) beginnen, ohne die
Demo-Pfade zu entfernen. Stufe 0 (manuelles PoC für Bonjour + HTTP auf echten
Geräten) kann parallel laufen, um die P0-Risiken früh zu verifizieren.
