# Handoff — DeepSeek (KL-OFFLINE-002: Red-Team + Stage 1 + POC)

**Datum:** 2026-07-16
**Agent:** DeepSeek-V4-Free (Red-Team-Instanz)
**Ticket:** KL-OFFLINE-002 – adversariale Review + Folge-Dokumente
**Branch:** `deepseek/offline-venue-hub-review`
**Basis:** `glm/offline-venue-hub` (Commit c07115b)
**Status:** Red-Team-Review + 2 Folge-Dokumente abgeschlossen

## Was in dieser Session erledigt wurde

### Phase 1: Red-Team Review (abgeschlossen)
28 Findings (6 P0, 5 P1, 5 P2, 4 P3), Faktencheck mit 3 Abweichungen.
Go/No-Go: 1× bedingt (Event-Log), 3× No-Go (HTTP-Server, Gastzugriff, Failover).

### Phase 2: Folge-Dokumente (diese Session)

**1. `STAGE1_EVENT_LOG_CONTRACT.md`** – Minimaler SQLite/GRDB-Event-Log:
- Tabellendefinitionen (events, idempotency, outbox, schema_version)
- Atomic Append Contract (Event + Idempotenz + Outbox in einer Transaktion)
- Schema-Versionierung via GRDB-Migrations (kein String-Parsing wie OrderRelayService)
- Replay/Recovery (Kaltstart, Absturz)
- ACK erst nach dauerhaftem COMMIT (§16.2)
- Keine willkürlichen Snapshot-/Checkpointintervalle
- Gemessene Grenzen (müssen vor Stage 2 auf echter Hardware erhoben werden)
- Transactional Outbox mit 4 Status (pending/sending/sent/permanent_failure)
- Primärquellen: sqlite.org, GRDB-Dokumentation, Transactional Outbox Pattern

**2. `LOCAL_NETWORK_POC.md`** – Testmatrix für Gast-Browser → Hub:
- Korrigierte Annahmen: WebSocket ≠ TLS/Auth, keine Apple-CA, Top-Level-HTTP ≠ Mixed Content, Chrome LNA, Failover-Zeiten gemessen, Privacy Manifest korrekt zitiert
- Testmatrix: iOS Safari, Android Chrome, Windows Edge, macOS Safari
- 3 Szenarien × AP Isolation AN/AUS/Kein WLAN
- Chrome Local Network Access (LNA) ab Chrome 94, hart ab ~Chrome 130
- App-Lifecycle (Vordergrund, Hintergrund, suspendiert, beendet, Anruf, Low Power, Standby)
- Hub-Ausfall (Crash, Akku leer, SQLite-Korruption)
- Messprotokoll-Vorlage
- 6 offene Hypothesen mit Falsifikationskriterien

## Veränderte Dateien (diese Session)

- `docs/discovery/offline-venue-hub/STAGE1_EVENT_LOG_CONTRACT.md` **(neu)** – 15,7 kB
- `docs/discovery/offline-venue-hub/LOCAL_NETWORK_POC.md` **(neu)** – 17,6 kB
- `docs/discovery/offline-venue-hub/DEEPSEEK_REVIEW.md` **(bestehend, unverändert)** – 30 kB
- `docs/collaboration/handoffs/DEEPSEEK.md` **(dieses Update)**

## Verbleibendes Risiko / Offenpunkte

1. **LNA-Härtung ab Chrome 130:** Der Zeitpunkt des harten LNA-Blocks ist nicht genau bekannt. Wenn Chrome im Ziel-Release der Sandbox LNA hart blockt, ist der gesamte Cloud-HTTPS→lokaler-Hub-Pfad tot, unabhängig von Mixed Content.
2. **Safari iOS 18 Verhalten:** Safari 18 (iOS 18) wurde noch nicht getestet. Die Annahmen basieren auf Safari 15–17. Ein Update könnte Top-Level-HTTP zu Privat-IPs blockieren.
3. **AP Isolation Messung:** Kein Referenz-Venue getestet. Die 5 Router-Hypothesen in LOCAL_NETWORK_POC.md §3.4 müssen vor Ort verifiziert werden.
4. **GRDB-Version-Pinning:** Im Contract nicht festgelegt – muss vor Implementierung in Package.swift auf eine konkrete Version pinnen.
5. **Kein Code, kein Deployment.** Beide Dokumente sind Specifications/Pläne, keine Implementierung.

## Empfohlener nächster Schritt

1. **LOCAL_NETWORK_POC durchführen** – echte Geräte, echte Router, alle 6 Hypothesen testen
2. **STAGE1 Implementierung** – GRDB-Integration, Tabellen, Atomic Append Contract
3. **Abhängig von POC-Ergebnissen:** Entscheidung über Gastzugriff-Pfad (nur Cloud vs. lokal vs. Hybrid)

## Schreibbereich & Kollisionsfreiheit

- Nur Dateien unter `docs/discovery/offline-venue-hub/` + Handoff geändert.
- Kein Produkt-Code; `GLM_ARCHITECTURE.md`, `GLM_SOURCES.md` nicht verändert.
- Keine Einträge in `DECISIONS.md`, `CURRENT.md` oder `WORK_QUEUE.md`.
