# Handoff — GLM (KL-WEB-001A Gast-Web-Stack-ADR, Revision 2)

**Datum:** 2026-07-16
**Agent:** GLM-5.2 via ZCode
**Ticket:** KL-WEB-001A — Gast-Web-Stack und Hosting-ADR
**Branch:** `glm/guest-web-architecture`
**Worktree:** `/Users/test/Developments/kitchenlink-glm-web`
**Status:** ADR-001 Revision 2 nach Review („CHANGES REQUIRED") überarbeitet;
ADR-Status bleibt „Proposed"; kein Produktcode geändert.

## Was in dieser Session erledigt wurde

Überarbeitung von ADR-001 und SOURCES.md entsprechend den 8 Review-Punkten zu
Commit `b72327b`. Alle Punkte umgesetzt:

1. **`@cloudflare/next-on-pages` vollständig entfernt.** Kein Vorkommen mehr in
   ADR oder SOURCES.
2. **Cloudflare aktuell als Workers + `@opennextjs/cloudflare` beschrieben.**
   Neue Primärquellen S34–S36 (OpenNext-Doku, GitHub-README,
   Cloudflare-Workers-Next.js-Guide). Verifiziert: OpenNext löst next-on-pages
   ab, zielt auf Workers (workerd), nutzt Node.js-Kompatibilitätsschicht.
3. **Hostingentscheidung offen gehalten.** §2.2 und neue §8 (PoC-Matrix)
   vergleichen Vercel und Cloudflare Workers datengetrieben; keine Vorab-
   Empfehlung zugunsten eines Anbieters.
4. **Unbelegte Aussagen entfernt.** „~92 % günstiger", pauschale
   „EU/GDPR-freundlicher"-Behauptungen und alle kommerziellen Vergleichsquellen
   (Bejamas, MakerKit, SpeedVitals, DanubeData, MG Software, DigitalApplied;
   ehemals S14–S19) gestrichen. Tragende Kosten-/GDPR-Aussagen werden im PoC
   direkt gegen offizielle Preis-/Rechtsseiten beider Anbieter gemessen.
5. **Direkte Tabellen-INSERTs ersetzt.** Neue §6 „Autoritative Bestellgrenze":
   Bestellungen verlaufen durch eine Supabase Edge Function oder transaktionale
   PostgreSQL-RPC mit Preis-, Verfügbarkeits-, Öffnungszeit-, Kapazitäts- und
   Idempotenzprüfung. Browser hat keinen direkten Schreibpfad mehr.
6. **`anon` vs. Anonymous Sign-in unterschieden.** §6.3 mit Primärquelle S40:
   `anon`-Rolle (unauthenticated, kein User) vs. Anonymous Sign-in
   (`authenticated`-Rolle, `auth.users`-Zeile, `is_anonymous=true`,
   JWT-Claim). Empfohlen wird Anonymous Sign-in für die Bestellung; Endwahl ist
   Entscheidung D2.
7. **Responsive Beta und PWA/Offline-Shell getrennt.** Neue §5 mit Stage 1
   (responsive Website, kein Service Worker) und Stage 2 (spätere PWA-Shell,
   eigene Entscheidung D5).
8. **PoC-Matrix Vercel vs. Cloudflare Workers.** Neue §8 mit 7 Meßkriterien
   (Next.js-Kompatibilität, Edge Function/Route, Preview, QR-LCP, EU-Region,
   Kosten, DSGVO), ausdrücklich ohne vorab Pauschalurteil.

## Primärquellen-Verifikation (Subagent, 2026-07-16)

Da WebSearch/WebReader das Wochenlimit erreichten, wurden die vier zentralen
Primärquellen über einen Subagent live abgerufen und verifiziert (alle HTTP 200,
mit direkten Zitaten belegt):

- **OpenNext** [S34]: `@opennextjs/cloudflare` deployt Next.js auf Workers;
  löst `@cloudflare/next-on-pages` ab (Edge-only) durch volle Node.js-Runtime.
- **Edge Functions** [S37][S38]: Supabase Edge Runtime (Deno); `ctx.supabaseAdmin`
  umgeht RLS serverseitig; „design for short-lived, idempotent operations".
- **Anonymous Sign-in** [S40]: „Anonymous user vs the anon key" — echten User
  mit `is_anonymous=true` und `authenticated`-Rolle, unterschieden vom
  `anon`-API-Key ohne User.
- **Cloudflare Workers** [S36]: Next.js via OpenNext (`--platform=workers`).

## Geänderte Dateien (diese Session)

- `docs/architecture/guest-web/ADR-001_GUEST_WEB_STACK.md` (vollständig
  überarbeitet: Revision 2)
- `docs/architecture/guest-web/SOURCES.md` (kommerzielle Quellen entfernt;
   OpenNext/Edge-Function/Anonymous-Quellen S34–S40 ergänzt)
- `docs/collaboration/handoffs/GLM.md` (dieses Update)

## Verification / Überprüfung

- Alle 8 Review-Punkte punktgenau umgesetzt und im ADR-Änderungshinweis oben
  dokumentiert.
- Tragende Aussagen nur mit Primärquellen belegt: OpenNext [S34][S35][S36],
  Edge Functions [S37][S38], Anonymous Sign-in [S40], Supabase-Region [S25],
  RLS [S20], TypeScript-Typen [S22][S23][S24].
- Keine kommerziellen Vergleichsquellen mehr für Kosten-/GDPR-Aussagen;
  diese werden ausschließlich im PoC (§8) gegen offizielle Anbieterseiten
  gemessen.
- ADR gegen Blueprint §6.3 (Annahmeprüfung), §16.2 (Bestell-ACK nur nach
  autoritativem Commit) und DESIGN_SYSTEM §11 (Token-Namen) abgeglichen.
- Worktree clean vor Commit; nur die drei oben genannten Dateien geändert.
- ADR-Status bleibt ausdrücklich „Proposed".

## Verbleibendes Risiko

- **Hosting-Offenheit bindet Kapazität:** bis zur PoC-Entscheidung (§8) müssen
  Vercel und Cloudflare Workers nachverfolgt werden. Das PoC ist nicht Teil
  dieser ADR und muß separat nach Freigabe durchgeführt werden.
- **`@opennextjs/cloudflare`-Adapter-Risiko:** Node.js-Kompatibilität in workerd
  kann Lücken aufweisen [S35]. Das PoC muß die Kernrouten früh verifizieren;
  Vercel bleibt Zero-Adapter-Fallback mit identischem Next.js-Code.
- **Autoritative Bestellgrenze ist aufwändiger** als direkte RLS-INSERTs, aber
  produktsprachlich erforderlich (Blueprint §6.3). Wahl zwischen Edge Function
  und RPC bleibt Entscheidung D6.
- **Background Sync ist keine Bestellgarantie** (ADR §5.3) — dies ist klar
  getrennt, muß aber in der Implementierung strikt durchgehalten werden.
- **Stage-2-PWA ist produktsprachlich offen** (D5); die Beta bleibt bewußt
  eine responsive Website ohne Service Worker.
- **WebSearch-/WebReader-Limit** war erschöpft; die Primärquellen wurden per
  Subagent verifiziert. Sollten bei der finalen PoC-Durchführung aktuelle
  Preis-/Versionsstände nötig sein, sind diese direkt gegen die Anbieterseiten
  zu prüfen.

## Offene Produktentscheidungen (dem Nutzer vorgelegt, ADR §11)

| # | Entscheidung |
|---|--------------|
| D1 | Domain-Strategie (Subdomain vs. Pfad) |
| D2 | Anonyme Identität: `anon` vs. Anonymous Sign-in (empfohlen: letzteres) |
| D3 | Custom-Domain pro Restaurant |
| D4 | Hosting-Wahl nach PoC (Vercel vs. Cloudflare Workers) |
| D5 | PWA-/Offline-Shell Stage 2 (ob und wie tief) |
| D6 | Bestellgrenze: Edge Function vs. PostgreSQL-RPC |

## Schreibbereich & Kollisionsfreiheit

- Ausschließlich die drei oben genannten Dateien in eigenem Scope geändert.
- Kein Produktcode; keine `CURRENT.md`-, `DECISIONS.md`- oder
  `WORK_QUEUE.md`-Änderungen.
- Keine fremde uncommittierte Arbeit berührt; Worktree war zu Beginn clean.

## Empfohlener nächster Schritt

Nach Nutzerfreigabe kann das Hosting-PoC (§8) als eigener kleiner Schritt
laufen: identische Next.js-App auf Vercel und Cloudflare Workers deployen und
messen. Das Ergebnis führt zu Entscheidung D4. Parallel kann
Bestellgrenze-Prototyp (§6) für D6 beginnen. Die responsive Beta (Stage 1)
bleibt von der PWA-/Offline-Komplexität entkoppelt.
