# Handoff — DeepSeek (Red-Team: Offline-Venue-Hub & Relay)

**Datum:** 2026-07-16
**Agent:** DeepSeek-V4-Free (Red-Team-Instanz)
**Prüfgegenstand:** iPad-Venue-Hub-Architektur (Blueprint §16), OrderRelayService, KitchenLinkRepository, OrderingDomain
**Status:** Red-Team-Review abgeschlossen, 22 Findings (5 P0, 7 P1, 6 P2, 4 P3)

## Was in dieser Session erledigt wurde

Adversarial Red-Team Review des aktuellen Relay-Prototypen und der geplanten Venue-Hub-Architektur.

### Geprüfte Quellen
- `docs/PRODUCT_BLUEPRINT.md` §16 (Offline-Architektur) und §18 (Technische Architektur)
- `docs/collaboration/DECISIONS.md`
- `docs/collaboration/CURRENT.md`
- `docs/collaboration/PEER_WORKFLOW.md`
- `kitchenlink/OrderRelayService.swift` (1561 Zeilen, vollständiger Relay-Prototyp)
- `kitchenlink/KitchenLinkRepository.swift` (206 Zeilen, LocalDemoRepository + QR-Codec)
- `kitchenlink/OrderingDomain.swift` (354 Zeilen, Domain-Modelle)

### Wesentliche Findings

**P0 (5 Findings):**
- **P0-01:** UserDefaults als einzige Persistenz (kein SQLite, §16.3 ignoriert)
- **P0-02:** Keine Idempotenz bei Order-Erstellung (createOrder überschreibt still)
- **P0-03:** Supabase Anon Key + Base URL hardcoded
- **P0-04:** Keine Authentisierung/Authorization (nur anon Key)
- **P0-05:** URLSession.shared ohne Pinning/Timeout-Konfig

**P1 (7 Findings):**
- Polling statt Realtime, Schema-Fallback als fragile String-Magic, Race-Condition createOrder vs Polling, keine Outbox, isConnected-Mischmasch, QR-Token-Schema dauerhaft cached, Status-Validierung fehlt auf Repository-Ebene

**P2 (6 Findings):**
- QR-Token deterministisch, supportedServiceModes überschrieben, operatorContextLine fallback auf sourceDevice, 50er-Limit bei Polling, clearOrders ohne Bestätigung, allergenCodes als CSV-String

**P3 (4 Findings):**
- MenuItemKind zu flach, Venue-Slug als Matching-Key, kein Token-Expiry-Check, isActive nicht auf Service-Ebene geprüft

### Weitere Deliverables
- 5 non-negotiable Invariants definiert
- Failure/Attack Tree (8 branching paths)
- Minimal Sandbox Architecture (13 Komponenten-Soll/Ist, 10-stufige Roadmap)
- 9 Forbidden Shortcuts
- 12 deterministische + 3 property-based Test-Ideen
- 7 User-decidable Questions

## Veränderte Dateien (diese Session)

- `docs/discovery/offline-venue-hub/DEEPSEEK_RED_TEAM.md` **(neu)** – Vollständiger Red-Team-Report
- `docs/collaboration/handoffs/DEEPSEEK.md` **(dieses Update)**

## Verbleibendes Risiko / Offenpunkte

- Die Analyse basiert auf Quellcode-Review, nicht auf Laufzeit-Beobachtung (kein Profiling, kein Chaos-Engineering).
- WatchConnectivity-Integration im Relay wurde nicht auf Transportebene geprüft (keine Bonjour/MDNS-Konfiguration im Code).
- Blueprint-§16.1-Failover ("bei Ausfall übernimmt ein anderes Gerät") ist weder spezifiziert noch implementiert – das ist das größte architektonische Risiko nach den P0-Fixes.
- Kein E2E-Test existiert für den Relay-Flow Gast → QR → Venue → Supabase.

## Empfohlener nächster Schritt

1. **P0-Fixes priorisieren:** SQLite-Migration, Auth/RLS, Idempotenz
2. **User-decidable Questions klären** (§10 im Report) – insbesondere SQLite-Timing, QR-Token-Mechanismus und Connectivity-State-Modell
3. **Letzten verbleibenden Codex-Handoff konsolidieren**, bevor Claude Code weiterarbeitet

## Schreibbereich & Kollisionsfreiheit

- Nur Dateien unter `docs/discovery/offline-venue-hub/` + Handoff geändert.
- Kein Produkt-Code; bestehende uncommittierte Änderungen unangetastet.
- Keine Entscheidung in `DECISIONS.md` oder `CURRENT.md`.
