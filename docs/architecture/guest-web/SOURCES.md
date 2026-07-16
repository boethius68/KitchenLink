# Quellenregister — Gast-Web-Stack ADR-001 (Revision 2)

**Erstellt:** 2026-07-16 (Revision 2 nach Review)
**Agent:** GLM-5.2 via ZCode
**Ticket:** KL-WEB-001A (Gast-Web-Stack und Hosting-ADR)
**Abrufdatum aller Quellen:** 2026-07-16

Dieses Register listet die Primär- und Sekundärquellen, die in
`ADR-001_GUEST_WEB_STACK.md` herangezogen wurden. Quellenverweise `[Sxx]`
verweisen auf die Einträge hier.

> **Änderung zur Revision 1:** Kommerzielle Anbieter-Vergleichsseiten (Bejamas,
> MakerKit, SpeedVitals, DanubeData, MG Software, DigitalApplied), die zu
> unbelegten Pauschalaussagen führten, sind entfernt. Die Hosting-Aussagen
> stützen sich jetzt auf offizielle Anbieter-Dokumentation und werden im PoC
> (ADR §8) direkt gegen die Preis-/Rechtsseiten von Vercel und Cloudflare
> verifiziert. Neu aufgenommen: OpenNext/Cloudflare-Workers-Primärquellen
> (S34–S36), Supabase Edge Functions (S37–S38) und Supabase Anonymous Sign-in
> (S40).

Bei Widersprüchen haben offizielle Framework-/Plattform-Dokumente Vorrang vor
Community-Artikeln.

---

## 1. Next.js, React und PWA

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S01 | [Guides: Progressive Web Apps — Next.js Official Docs](https://nextjs.org/docs/app/guides/progressive-web-apps) | Offiziell | 2026-07-16 | PWA-Erstellung mit Next.js App Router; Manifest, Service Worker |
| S02 | [Building a PWA in Next.js with Serwist (next-pwa successor)](https://javascript.plainenglish.io/building-a-progressive-web-app-pwa-in-next-js-with-serwist-next-pwa-successor-94e05cb418d7) | Community | 2026-07-16 | Serwist als Nachfolger des veralteten next-pwa |
| S03 | [Building an Offline-First Next.js 15 App with App Router — GitHub Discussion](https://github.com/vercel/next.js/discussions/82498) | Community | 2026-07-16 | Service Worker als Fallback-Shell; IndexedDB-Daten-Caching |
| S04 | [Service Workers — web.dev](https://web.dev/learn/pwa/service-workers) | Offiziell (Google) | 2026-07-16 | Konzepte: Service Worker für schnelles Laden unabhängig vom Netzwerk |

---

## 2. Astro und statische/site-fokussierte Frameworks

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S05 | [Astro vs. Next.js: Features, performance, and use cases compared — Contentful](https://www.contentful.com/blog/astro-next-js-compared/) | Community | 2026-07-16 | Astro für statische SEO-Seiten; Next.js für app-artige Daten-Erlebnisse |
| S06 | [Astro vs NextJS for Marketing Websites — Makers Den](https://makersden.io/blog/astro-vs-nextjs-marketing-website) | Community | 2026-07-16 | Astro: partielle Hydration (Islands), minimales JS |
| S07 | [Astro vs Next.js: Battle of the Static Site Generators — Medium](https://medium.com/@shujaamarwat/astro-vs-next-js-battle-of-the-static-site-generators-4a2ad77b19c9) | Community | 2026-07-16 | Astro schnellere SSG-Ladezeiten durch weniger JS |

---

## 3. SvelteKit

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S09 | [Use Supabase with SvelteKit (Official Quickstart)](https://supabase.com/docs/guides/getting-started/quickstarts/sveltekit) | Offiziell (Supabase) | 2026-07-16 | Offizielle SvelteKit-Integration |
| S10 | [Align SvelteKit auth tutorial with Next.js #37803 — GitHub](https://github.com/supabase/supabase/issues/37803) | Issue-Tracker | 2026-07-16 | SvelteKit-Auth-Setup ist komplexer als Next.js; DX-Vergleich |
| S11 | [SvelteKit vs. Next.js — CloudCannon](https://cloudcannon.com/blog/sveltekit-vs-next-js/) | Community | 2026-07-16 | Open-Source-Vergleich: Rendering, Routing, Deployment |
| S12 | [Sveltekit vs. Next.js: A side-by-side comparison — Hygraph](https://hygraph.com/blog/sveltekit-vs-nextjs) | Community | 2026-07-16 | SvelteKit SSR; Next.js hybride Rendering (SSR + SSG) |
| S13 | [SvelteKit without SSR / SSG? — GitHub Discussion #3365](https://github.com/sveltejs/kit/discussions/3365) | Community | 2026-07-16 | adapter-static für reine SPA/PWA-Nutzung |

---

## 4. Cloudflare Workers + OpenNext (NEU in Revision 2)

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S34 | [OpenNext for Cloudflare — opennext.js.org/cloudflare](https://opennext.js.org/cloudflare) | Offiziell (OpenNext) | 2026-07-16 | `@opennextjs/cloudflare` als aktueller Adapter für Next.js auf Cloudflare Workers; löst `@cloudflare/next-on-pages` ab (nur Edge-Runtime) |
| S35 | [opennextjs/opennextjs-cloudflare — GitHub README](https://github.com/opennextjs/opennextjs-cloudflare) | Offiziell (Repo) | 2026-07-16 | workerd-Laufzeit + Workers-Node.js-Kompatibilitätsschicht; Deployment-Details |
| S36 | [Deploy a Next.js app — Cloudflare Workers docs](https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/) | Offiziell (Cloudflare) | 2026-07-16 | Cloudflare empfiehlt OpenNext (`--platform=workers`) für Next.js auf Workers |

> **Entfernt:** die kommerziellen Hosting-Vergleichsquellen S14–S19 aus
> Revision 1 (Bejamas, MakerKit, SpeedVitals, DanubeData, MG Software,
> DigitalApplied). Ihre pauschalen Kosten-/GDPR-Aussagen wurden durch das PoC
> in ADR §8 ersetzt, das direkt gegen die offiziellen Preis-/Rechtsseiten
> beider Anbieter mißt.

---

## 5. Supabase — RLS, Edge Functions, Anonymous Sign-in, TypeScript, Region

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S20 | [Row Level Security — Supabase Docs](https://supabase.com/docs/guides/database/postgres/row-level-security) | Offiziell (Supabase) | 2026-07-16 | RLS muß auf allen Tabellen eines exponierten Schemas aktiv sein; Grundlage für PostgreSQL-RPC-Bestellgrenze |
| S22 | [Generating TypeScript Types — Supabase Docs](https://supabase.com/docs/guides/api/rest/generating-types) | Offiziell (Supabase) | 2026-07-16 | `supabase gen types` erzeugt TypeScript-Typen aus DB-Schema |
| S23 | [JavaScript: TypeScript Support — Supabase Docs](https://supabase.com/docs/reference/javascript/typescript-support) | Offiziell (Supabase) | 2026-07-16 | Typen direkt aus Schema; End-to-End-Typsicherheit |
| S24 | [Generate types using GitHub Actions — Supabase Docs](https://supabase.com/docs/guides/deployment/ci/generating-types) | Offiziell (Supabase) | 2026-07-16 | CI/CD-Automatisierung der Typ-Generierung |
| S25 | [Available Regions — Supabase Docs](https://supabase.com/docs/guides/platform/regions) | Offiziell (Supabase) | 2026-07-16 | EU-Region Frankfurt (eu-central-1) verfügbar |
| S26 | [DPA (Data Processing Addendum) — Supabase](https://supabase.com/legal/dpa) | Offiziell (Supabase) | 2026-07-16 | Datenschutz-Zusatzvereinbarung für GDPR |
| S37 | [Edge Functions — Supabase Docs](https://supabase.com/docs/guides/functions) | Offiziell (Supabase) | 2026-07-16 | Edge Functions laufen auf Supabase Edge Runtime (Deno-kompatibel); „design for short-lived, idempotent operations" — geeignet für autoritative Bestellvalidierung |
| S38 | [Connect to Postgres from an Edge Function — Supabase Docs](https://supabase.com/docs/guides/functions/connect-to-postgres) | Offiziell (Supabase) | 2026-07-16 | `ctx.supabaseAdmin` umgeht RLS für privilegierte serverseitige Operationen |
| S40 | [Anonymous Sign-ins — Supabase Docs](https://supabase.com/docs/guides/auth/auth-anonymous) | Offiziell (Supabase) | 2026-07-16 | **„Anonymous user vs the anon key"**: Anonymous Sign-in erzeugt echten User (`is_anonymous=true`) mit `authenticated`-Rolle + JWT-Claim; unterschieden vom `anon`-API-Key ohne User (`anon`-Rolle) |

> **Nummerierung:** Lücken (S08, S14–S19, S21, S27–S33, S39) entstehen durch
> Entfernen der kommerziellen Sekundärquellen aus Revision 1. Die verbleibenden
> Quellen sind Primärquellen oder direkt belastbare Community-Belege.

---

## 6. PWA Offline — App Shell vs. Datenübermittlung

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S29 | [Offline and Background Operation — MDN](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Offline_and_background_operation) | Offiziell (MDN) | 2026-07-16 | App-Shell-Modell + Background-Sync/Periodic-Sync-API |
| S30 | [Offline Support in Web Apps: Foreground Queue vs. Background Sync — Tomasz Gil](https://blog.tomaszgil.me/offline-support-in-web-apps-foreground-queue-vs-background-sync) | Community | 2026-07-16 | Trennung: Foreground-Queue vs. Background-Sync bei Daten-Submission |
| S31 | [Synchronize and Update a PWA in the Background — Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-edge/progressive-web-apps/how-to/background-syncs) | Offiziell (MS) | 2026-07-16 | Background-Sync-API: automatischer Retry bei Konnektivität |

> **Verwendung in Revision 2:** diese Quellen stützen ausschließlich Stage 2
> (PWA-/Offline-Shell) der ADR; sie werden nicht herangezogen, um Offline-
> Bestellgarantien zu behaupten (ADR §5.3 trennt das explizit).

---

## Quellen-Hierarchie

Bei Widersprüchen gilt:

1. **Offizielle Framework-/Plattform-Dokumentation** (nextjs.org, supabase.com,
   developer.mozilla.org, web.dev, learn.microsoft.com, developers.cloudflare.com,
   opennext.js.org)
2. **Offizielle Supabase-Docs** für Backend/RLS/Edge Functions/Anonymous Auth
3. **Offizielle Cloudflare-/OpenNext-Docs** für Workers/Hosting
4. **Community-Artikel/Blogs** — nur für DX-Vergleiche und qualitative
   Framework-Einschätzungen, niemals für tragende Kosten-/GDPR-Aussagen
5. **Foren/Stack Overflow/Reddit** — Workarounds und bekannte Probleme

> Tragende Kosten-, GDPR- und Leistungs-Aussagen werden im PoC (ADR §8) direkt
> gegen die offiziellen Preis- und Rechtsseiten der Anbieter gemessen, nicht
> aus kommerziellen Vergleichsportalen Dritter übernommen.
