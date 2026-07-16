# Handoff — DeepSeek (KL-OFFLINE-002: Red-Team GLM Venue-Hub-Architektur)

**Datum:** 2026-07-16
**Agent:** DeepSeek-V4-Free (Red-Team-Instanz)
**Ticket:** KL-OFFLINE-002 – unabhängiger Red-Team-Review der GLM-Venue-Hub-Architektur
**Branch:** `deepseek/offline-venue-hub-review`
**Basis:** `glm/offline-venue-hub` (Commit c07115b)
**Status:** Red-Team-Review abgeschlossen; 4 Kernbereiche bewertet (1× bedingt Go, 3× No-Go)

## Was in dieser Session erledigt wurde

Adversarialer Red-Team-Review der GLM-Venue-Hub-Architektur (`GLM_ARCHITECTURE.md`, `GLM_SOURCES.md`).

### Geprüft
- `GLM_ARCHITECTURE.md` (629 Zeilen) – vollständige Zielarchitektur
- `GLM_SOURCES.md` (158 Zeilen) – Quellenregister mit 55 Quellen
- `docs/PRODUCT_BLUEPRINT.md` §16 (Offline-Architektur), §3 (Gast-Web)
- `docs/collaboration/DECISIONS.md`
- `docs/collaboration/CURRENT.md`
- `docs/collaboration/handoffs/GLM.md`, `DEEPSEEK.md`, `CODEX.md`, `CLAUDE.md`
- `kitchenlink/OrderRelayService.swift`, `OrderingDomain.swift`, `KitchenLinkRepository.swift`

### Findings (28 gesamt)

**P0 (6 Findings):**
| ID | Titel | Bereich |
|---|---|---|
| P0-01 | Mixed Content & Secure Context blockieren Gast-Browser | Gastzugriff |
| P0-02 | AP Isolation macht lokale Kommunikation unmöglich | Gastzugriff |
| P0-03 | Keine Transport-Sicherheit im lokalen WLAN | Security |
| P0-04 | 60-Sekunden-Failover-Lücke | Failover |
| P0-05 | SWIM auf iOS nicht produktionsreif | Failover |
| P0-06 | Kein Epoch/Term im Event-Modell | Event-Log (upgraded from P1) |

**P1 (5 Findings):**
| ID | Titel | Bereich |
|---|---|---|
| P1-01 | Event-Log Recovery nach Hub-Verlust | Event-Log |
| P1-02 | Bonjour-Zuverlässigkeit auf iOS | Discovery |
| P1-03 | HTTP-Server-Komplexität unterschätzt | HTTP-Server |
| P1-04 | Supabase-Outbox/Inbox nur skizziert | Cloud-Sync |
| P1-05 | Request-Rate-Limiting fehlt | HTTP-Server |

**P2 (5 Findings):**
- WAL-Checkpointing und Snapshotting fehlt, mDNS-Auflösung auf Android/Windows, HMAC-Schlüsselverteilung, MPC-Fallback nicht betrachtet, kein Rate-Limiting auf Endpunkten

**P3 (4 Findings):**
- ULID-Kollision, GRDB-Version-Pinning, shift_id-Lebenszyklus, UUIDv7 auf iOS <17

**Faktencheck (3 Abweichungen):**
- S16 (MPC unreliability) – Quelle von 2015, für Staff-only akzeptabel
- S40 (swift-SWIM) – irreführend als "Swift-Referenzimplementierung" (Dead Project)
- S08 (NWHTTPProtocol) – unvollständig für Produktion

### Go / No-Go Bewertung

| Komponente | Rating | Bedingungen |
|---|---|---|
| Lokales Event-Log (SQLite/WAL/GRDB) | ⚠️ BEDINGT GO | 6 Auflagen (GRDB-Pinning, WAL-Checkpointing, Snapshots, Transactional Outbox, Migrationstests, Crash-Simulation) |
| Lokaler HTTP-Server (NWListener) | ❌ NO-GO | Mixed Content, CORS, kein TLS, Komplexität unterschätzt |
| Gastzugriff (QR→Browser→Hub) | ❌ NO-GO | 3 ungelöste P0-Probleme (Mixed Content, AP Isolation, mDNS-Heterogenität) |
| Mehrgeräte-Failover (Lease/SWIM) | ❌ NO-GO | SWIM nicht produktionstauglich, 60s-Lücke, kein Epoch, kein Fencing, Event Recovery fehlt |

## Veränderte Dateien (diese Session)

- `docs/discovery/offline-venue-hub/DEEPSEEK_REVIEW.md` **(neu)** – Vollständiger Red-Team-Report (30 kB)
- `docs/collaboration/handoffs/DEEPSEEK.md` **(dieses Update)**

## Verbleibendes Risiko / Offenpunkte

- **Größtes architektonisches Risiko:** Der lokale Gastzugriff (QR→Browser→Hub) ist der zentrale Product-Market-Fit für KitchenLink. Wenn er wegen Mixed Content / AP Isolation / mDNS nicht funktioniert, entfällt der Hauptgrund für den Venue-Hub.
- **SWIM-Evaluierung:** GLM hat SWIM empfohlen ohne iOS-Produktionsnachweis. Dies muss vor Implementierung durch ein adäquates Heartbeat-Verfahren ersetzt werden.
- **Event Recovery:** Das Risiko des Datenverlusts bei physischem Hub-Verlust ist nicht adressiert und könnte zu unumkehrbaren Bestellverlusten führen.
- **GLM hat solide Arbeit geleistet.** Die Quellen-Recherche und die Komponentenstruktur sind wertvoll. Die identifizierten Lücken sind typisch für eine Architektur in der Discovery-Phase und kein Zeichen von schlechter Arbeit.

## Empfohlener nächster Schritt

1. **User-Entscheidungen einholen** (siehe 7 Fragen in DEEPSEEK_REVIEW.md §"Offene Fragen")
2. **HTTP-Server durch WebSocket-Protokoll ersetzen** (Staff-App als Proxy) oder **Gastzugriff auf Cloud-Betrieb beschränken** (lokaler Gastzugriff auf post-Sandbox verschieben)
3. **SWIM durch Bonjour-Heartbeat mit IP-Fallback ersetzen**
4. **Epoch ins Event-Modell aufnehmen** (als Voraussetzung für Failover)
5. **Event Recovery spezifizieren** (synchrone Replikation auf zweites Gerät?)

## Schreibbereich & Kollisionsfreiheit

- Nur Dateien unter `docs/discovery/offline-venue-hub/` + Handoff geändert.
- Kein Produkt-Code; `GLM_ARCHITECTURE.md` und `GLM_SOURCES.md` nicht verändert.
- Keine Einträge in `DECISIONS.md`, `CURRENT.md` oder `WORK_QUEUE.md`.
