# Quellenregister — Offline Venue Hub Architektur

**Erstellt:** 2026-07-16
**Agent:** GLM-5.2 via ZCode
**Ticket:** Discovery-Auftrag lokaler Venue-Hub (Blueprint §16)
**Abrufdatum aller Quellen:** 2026-07-16, sofern nicht abweichend vermerkt

Dieses Register listet die Primär- und Sekundärquellen, die in
`GLM_ARCHITECTURE.md` herangezogen wurden. Jede Quelle ist kategorisiert und mit
einer Kurznotiz versehen, wofür sie verwendet wurde. Apple-Dokumentation hat
Vorrang vor Community-Quellen.

> **Hinweis zur Verlässlichkeit:** Apple-Primärdokumentation
> (`developer.apple.com`) ist verbindlich für API-Verhalten. WWDC-Sessions
> ergänzen das mit Design-Ratschlägen. Community-Quellen (Stack Overflow,
> Medium, Foren) dokumentieren Erfahrungsberichte und Workarounds und sind als
> solche gekennzeichnet; sie ersetzen keine Verifizierung auf Zielgeräten.

---

## 1. Network.framework — Transport, Listener, Browser

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S01 | [Network \| Apple Developer Documentation](https://developer.apple.com/documentation/network) | Apple offiziell | 2026-07-16 | Rahmen-Referenz für NWListener, NWConnection, NWBrowser, NWParameters |
| S02 | [Introducing Network.framework: A Modern Alternative to Sockets — WWDC 2018 Session 715](https://developer.apple.com/videos/play/wwdc2018/715/) | Apple WWDC | 2026-07-16 | Design-Rationale: User-Space-Stack, NWListener mit Bonjour-Advertising, Abkehr von BSD-Sockets |
| S03 | [NWListener \| Apple Developer Documentation](https://developer.apple.com/documentation/network/nwlistener) | Apple offiziell | 2026-07-16 | API für lokales TCP-Listening und Bonjour-Service-Advertising |
| S04 | [NWBrowser — NWBrowser.Descriptor.bonjour(type:domain:)](https://stackoverflow.com/questions/76576518/swift-nwbrowser-bonjour-service-error-nwbrowser-has-no-member-service) | Community (SO) | 2026-07-16 | Korrekte moderne NWBrowser-API (`Descriptor.bonjour`), ältere `service:`-API ist entfernt |
| S05 | [How to create and advertise a Bonjour service with Network.framework — Swift Forums](https://forums.swift.org/t/how-to-create-and-advertise-a-bonjour-service-with-network-framework/68240) | Community | 2026-07-16 | Info.plist `NSBonjourServices`-Pflicht für NWListener+NWBrowser |
| S06 | [iOS/OSX Connections with Network Framework and Bonjour Service — Medium](https://boramaapps.medium.com/ios-osx-connections-with-network-framework-and-bonjour-service-7fa6130f5789) | Community | 2026-07-16 | Praxisbeispiel Mehrgeräte-Verbindung über NWBrowser + NWListener |
| S07 | [Simple Web Server in Swift — ko9.org](https://ko9.org/posts/simple-swift-web-server/) | Community | 2026-07-16 | NWListener-basierter HTTP-Server in Swift (Prototyp-Referenz) |
| S08 | [helje5/NWHTTPProtocol — GitHub](https://github.com/helje5/NWHTTPProtocol) | OSS-Referenz | 2026-07-16 | HTTP-Protocol-Framer (NWProtocolFramer) auf Network.framework |

---

## 2. Bonjour / mDNS / Service Discovery

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S09 | [Bonjour Concepts — Apple Developer (archived)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Articles/about.html) | Apple offiziell (archiviert) | 2026-07-16 | Funktionsweise von DNS-SD/mDNS-Service-Discovery |
| S10 | [Bonjour Network Discovery and Connectivity — WWDC 2011 Session 211](https://nonstrict.eu/wwdcindex/wwdc2011/211/) | Apple WWDC | 2026-07-16 | Grundlagen Publishing/Browsing/Resolving auf lokalem IP-Netz |
| S11 | [Swift: Bonjour, NSNetService & IP Addresses — Eric Dolecki](https://blog.ericd.net/2016/06/16/swift-bonjour-nsnetservice-ip-addresses/) | Community | 2026-07-16 | IP-Auflösung aus gefundenem Service |
| S12 | [Bonjour broken in iOS 14 — cocoa@apple-dev.groups.io](https://apple-dev.groups.io/g/cocoa/topic/bonjour_broken_in_ios_14/76927407) | Community | 2026-07-16 | Bekannte iOS-14+-Regressionen bei Bonjour-Advertising (includePeerToPeer) |
| S13 | [herald-ios-bonjour-browser — GitHub](https://github.com/jessedc/herald-ios-bonjour-browser) | OSS-Referenz | 2026-07-16 | Debug- und Referenz-App für Service-Browsing |

---

## 3. Multipeer Connectivity (MPC) — abgewogen und verworfen

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S14 | [MCSession \| Apple Developer Documentation](https://developer.apple.com/documentation/multipeerconnectivity/mcsession) | Apple offiziell | 2026-07-16 | **Hartes Limit: max. 8 Peers pro Session** (inkl. lokalem Peer) |
| S15 | [Multipeer Connectivity \| Apple Developer Documentation](https://developer.apple.com/documentation/multipeerconnectivity) | Apple offiziell | 2026-07-16 | Background-Verhalten: Session wird bei App-Hintergrund abgebaut |
| S16 | [Multipeer Connectivity for Games — objc.io Issue 18](https://www.objc.io/issues/18-games/multipeer-connectivity-for-games) | Community (anerkannt) | 2026-07-16 | Zuverlässigkeits-Bewertung: "reliability remains a sore point"; Retry/Reconnect nötig |
| S17 | [The dark corners of the Multipeer Connectivity Framework — Medium (baydet)](https://baydet.medium.com/dark-corners-of-multipeer-connectivity-framework-abd566422920) | Community | 2026-07-16 | "Lost Peer stays in Session"-Bug; 1:1-Session-Pattern als Workaround |
| S18 | [Multipeer Connectivity Framework for up to 45 devices — Stack Overflow](https://stackoverflow.com/questions/19479295/multipeer-connectivity-framework-for-up-to-45-devices) | Community (SO) | 2026-07-16 | Skalierung über 8 Peers nur durch parallele MCSession-Objekte, hohe Komplexität |
| S19 | [Multipeer Connectivity stability and recommendations — Stack Overflow](https://stackoverflow.com/questions/34597170/multipeer-connectivity-framework-stability-and-recommendations) | Community (SO) | 2026-07-16 | Heartbeat/Keepalive-Muster zur Zombie-Peer-Erkennung |
| S20 | [Apple Developer Forums — Networking/Multipeer tag](https://developer.apple.com/forums/tags/multipeerconnectivity) | Apple Foren | 2026-07-16 | Apple-Mitarbeiter-Empfehlung: "consider moving to Network framework" für Produktionszuverlässigkeit |

---

## 4. iOS/iPadOS App-Lifecycle und Background-Grenzen

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S21 | [Configuring background execution modes — Apple Developer](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes) | Apple offiziell | 2026-07-16 | Begrenzte Anzahl Background-Modi; App muss diese explizit deklarieren |
| S22 | [About the background execution sequence — Apple Developer](https://developer.apple.com/documentation/uikit/about-the-background-execution-sequence) | Apple offiziell | 2026-07-16 | App kann auf Background-Events reagieren, läuft aber nicht ununterbrochen |
| S23 | [iOS Background Execution Limits — AppsOnAir](https://www.appsonair.com/blogs/background-execution-limits-in-ios-what-every-developer-must-know) | Community | 2026-07-16 | Übersicht der strikten Battery-/Performance-Beschränkungen |

---

## 5. Local-Network-Berechtigungen und Gerätezertifizierung

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S24 | [NSLocalNetworkUsageDescription — Apple Developer](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription) | Apple offiziell | 2026-07-16 | Pflicht-Info.plist-Key seit iOS 14 für lokalen Netzwerkzugriff; einmalige Nutzerabfrage |
| S25 | [iOS Local Network Privacy Permission Explained — PTKD](https://ptkd.com/journal/ios-local-network-privacy-permission) | Community | 2026-07-16 | Praxis: NSBonjourServices muss spezifische Service-Typen deklarieren |
| S26 | [Enforcement of Apple Privacy Manifest starting May 1, 2024 — Bitrise](https://bitrise.io/blog/post/enforcement-of-apple-privacy-manifest-starting-from-may-1-2024) | Community | 2026-07-16 | PrivacyInfo.xcprivacy ist seit 01.05.2024 für alle neuen App-Updates Pflicht |
| S27 | [Apple Privacy Manifest requirements — Xojo Blog](https://blog.xojo.com/2024/03/20/apples-new-privacy-manifest-requirements/) | Community | 2026-07-16 | Inhalt von PrivacyInfo.xcprivacy (NSPrivacyTracking, Required-Reason-APIs) |

---

## 6. SQLite, WAL, Append-Only Event Log, Outbox/Inbox, Idempotenz

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S28 | [Write-Ahead Logging — sqlite.org](https://sqlite.org/wal.html) | SQLite offiziell | 2026-07-16 | WAL-Modus: mehrere Reader + ein Writer; Eigenschaft der Datei, nicht der Connection |
| S29 | [Event Sourcing with SQLite: Append-Only Design — sqliteforum.com](https://www.sqliteforum.com/p/event-sourcing-with-sqlite) | Community | 2026-07-16 | Append-only-Tabellen, Snapshots, Replay-Queries |
| S30 | [Persistence Model for a Dual-Contract Event Store in SQLite — Medium](https://medium.com/@impactarchitecture/persistence-model-for-a-dual-contract-event-store-in-sqlite-53f3505f7d21) | Community | 2026-07-16 | Events als append-only-Zeilen + Snapshots als veränderlicher Zustand |
| S31 | [Reduce Duplicates in Outbox Pattern — Software Engineering Stack Exchange](https://softwareengineering.stackexchange.com/questions/393691/reduce-duplicates-in-outbox-pattern-in-event-driven-systems) | Community (SE) | 2026-07-16 | Idempotenz / Exactly-Once beim Outbox-Pattern |
| S32 | [Enabling WAL Mode for SQLite — Simon Willison's TIL](https://til.simonwillison.net/sqlite/enabling-wal-mode) | Community | 2026-07-16 | WAL ist Datei-Eigenschaft (Gotcha bei mehreren Connections) |
| S33 | [GRDB.swift — GitHub (groue/GRDB.swift)](https://github.com/groue/GRDB.swift) | OSS-Projekt | 2026-07-16 | DatabasePool (WAL, Multi-Reader/Single-Writer), DatabaseQueue, Migrations |
| S34 | [GRDB Reference Documentation](http://groue.github.io/GRDB.swift/docs/2.1/) | OSS-Doku | 2026-07-16 | Raw-SQL-Zugang, Concurrency-Primitive |
| S35 | [Raw SQL in iOS/Swift: SQLite.swift or GRDB? — Reddit](https://www.reddit.com/r/iOSProgramming/comments/1d7a0zr/raw_sql_in_iosswift_sqliteswift_or_grdb/) | Community | 2026-07-16 | Bibliotheksvergleich; GRDB bevorzugt für concurrency-lastige Apps |

---

## 7. Hub-Erkennung, Leader-Wechsel und Wiederanlauf

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S36 | [In Search of an Understandable Consensus Algorithm (Raft) — Stanford PDF](https://web.stanford.edu/~ouster/cgi-bin/papers/raft-atc14) | Original-Paper | 2026-07-16 | Raft: Leader Election, Log Replication, Safety, randomisierte Timeouts |
| S37 | [Raft Consensus Algorithm — offizielle Seite](https://raft.github.io/) | Referenz | 2026-07-16 | Visualisierung Leader Election; Paxos-Äquivalenz |
| S38 | [Raft (algorithm) — Wikipedia](https://en.wikipedia.org/wiki/Raft_(algorithm)) | Enzyklopädie | 2026-07-16 | Nicht byzantinisch-fehlertolerant; vertrauenswürdige Knoten vorausgesetzt (passt zu Venue-LAN) |
| S39 | [SWIM: Scalable Weakly-consistent Infection-style Process Group Membership Protocol — Cornell PDF](https://www.cs.cornell.edu/projects/Quicksilver/public_pdfs/SWIM.pdf) | Original-Paper | 2026-07-16 | SWIM-Gossip: garantierte eventuelle Fehlerekennung, Mitgliedschafts-Dissemination |
| S40 | [swift-SWIM — pure Swift SWIM-Implementierung, GitHub](https://github.com/1amageek/swift-SWIM) | OSS-Projekt | 2026-07-16 | Swift-Referenzimplementierung; Hinweis: unauthentifiziert (Incarnation-Fälschung) |
| S41 | [SWIM Protocol — Wikipedia](https://en.wikipedia.org/wiki/SWIM_Protocol) | Enzyklopädie | 2026-07-16 | Hybrid aus Failure-Detection + Mitgliedschafts-Gossip |

---

## 8. Supabase-Abgleich nach Wiederverbindung

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S42 | [Database Replication — Supabase Docs](https://supabase.com/docs/guides/database/replication) | Supabase offiziell | 2026-07-16 | Postgres Logical Replication / CDC als Grundlage |
| S43 | [Using Supabase offline #357 — GitHub Discussion](https://github.com/orgs/supabase/discussions/357) | Community | 2026-07-16 | "Unmöglich für Supabase, Offline korrekt selbst zu implementieren" → lokale Schicht nötig |
| S44 | [PowerSync + Supabase Integration Guide](https://docs.powersync.com/integrations/supabase/guide) | Sync-Engine-Doku | 2026-07-16 | Sync zu lokaler SQLite, inkrementell, konfliktauflösend (Referenzarchitektur) |
| S45 | [Supabase Replication Plugin for RxDB](https://rxdb.info/replication-supabase.html) | OSS-Plugin | 2026-07-16 | Zwei-Wege-Sync, Offline, automatische Wiederverbindung |
| S46 | [Offline-first React Native Apps with WatermelonDB and Supabase — Supabase Blog](https://supabase.com/blog/react-native-offline-first-watermelon-db) | Supabase offiziell | 2026-07-16 | Push/Pull-Sync zu Supabase (Referenzmuster, auch wenn RN) |
| S47 | [ElectricSQL \| Works With Supabase](https://supabase.com/partners/integrations/electricsql) | Sync-Engine | 2026-07-16 | Active-Active-Replikation, partielle Replikation |

---

## 9. Konfliktlösung — Event Sourcing vs. CRDT

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S48 | [CRDTs vs Event Sourcing: The Architecture War — Medium](https://medium.com/@optimzationking2/crdts-vs-event-sourcing-the-architecture-war-that-will-define-the-next-10-years-ae8245cd2ac9) | Community | 2026-07-16 | Vergleich: CRDT (zustandsorientiert) vs. Event Sourcing (log-orientiert) |
| S49 | [An Event Source is also a CRDT! — Yves Goeleven (LinkedIn)](https://www.linkedin.com/posts/goeleven_an-event-source-is-also-a-crdt-over-the-activity-7154442448868368385-c1Qc) | Community | 2026-07-16 | Event Sourcing durch CRDT-Linse betrachtet |
| S50 | [Event sourcing, local-first, and distributed state — Sandro Maglione](https://www.sandromagliones.com/newsletter/event-sourcing-local-first-and-distributed-state) | Community | 2026-07-16 | Event Sourcing als Lösungsansatz für lokalen Mehrgerätebetrieb |
| S51 | [Conflict-free replicated data type — Wikipedia](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type) | Enzyklopädie | 2026-07-16 | Definition mathematisch garantierter deterministischer Merges |
| S52 | [How to Build Robust Offline-First Apps — Ditto Blog](https://www.ditto.com/blog/how-to-build-robust-offline-first-apps-a-technical-guide-to-conflict-resolution-with-crdts-and-ditto) | Community | 2026-07-16 | CRDT-Sync, Merge, Audit auf Applikationsebene |
| S53 | [Downsides of Local First / Offline First — RxDB](https://rxdb.info/downsides-of-offline-first.html) | Community | 2026-07-16 | Deterministische vs. custom Konfliktstrategien; Schmerzpunkte |

---

## 10. Captive Portal / Gast-WebView auf Restaurant-WLAN

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S54 | [Use Captive Wi-Fi Networks on iPhone or iPad — Apple Support](https://support.apple.com/en-us/102554) | Apple offiziell | 2026-07-16 | Verhalten von Captive-Portal-Netzwerken auf iOS |
| S55 | [iOS Mini Browser / Captive Network Assistant rendering — WatchGuard](https://techsearch.watchguard.com/KB?type=Article&SFDCID=kA10H000000g3ATSAY&lang=en_US) | Community | 2026-07-16 | CNA ist eingeschränkt; komplexe JS/SPAs rendern evtl. nicht zuverlässig |

---

## Quellen-Hierarchie für Architekturentscheidungen

Bei Widersprüchen zwischen Quellen gilt folgende Priorität:

1. **Apple-Primärdokumentation** (`developer.apple.com`) — verbindlich für API-Verhalten
2. **WWDC-Sessions** — offizielles Design-Rationale
3. **Original-Papers** (Raft, SWIM) — Algorithmus-Grundlage
4. **Offizielle Projektdokus** (sqlite.org, Supabase) — Plattformverhalten
5. **Anerkannte Community-Artikel** (objc.io) — Erfahrungswerte
6. **Foren/Stack Overflow** — Workarounds und bekannte Bugs

Alle Architekturaussagen in `GLM_ARCHITECTURE.md` referenzieren die hier
aufgeführten Quellen mittels `[Sxx]`-Notation.
