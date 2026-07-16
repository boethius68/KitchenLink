# Quellenregister — Gast-Web-Stack ADR-001

**Erstellt:** 2026-07-16
**Agent:** GLM-5.2 via ZCode
**Ticket:** KL-WEB-001A (Gast-Web-Stack und Hosting-ADR)
**Abrufdatum aller Quellen:** 2026-07-16

Dieses Register listet die Primär- und Sekundärquellen, die in
`ADR-001_GUEST_WEB_STACK.md` herangezogen wurden. Quellenverweise `[Sxx]`
verweisen auf die Einträge hier. Bei Widersprüchen haben offizielle
Framework-/Plattform-Dokumente Vorrang vor Community-Artikeln.

> **Hinweis zur Verlässlichkeit:** Offizielle Dokumentation (nextjs.org,
> supabase.com, developer.mozilla.org, web.dev) ist maßgeblich für
> API-Verhalten. Anbieter-Vergleiche (Bejamas, MakerKit, DigitalApplied) sind
> kommerziell motiviert und wurden gegen mehrere Quellen kreuzgeprüft.

---

## 1. Next.js, React und PWA

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S01 | [Guides: Progressive Web Apps — Next.js Official Docs](https://nextjs.org/docs/app/guides/progressive-web-apps) | Offiziell | 2026-07-16 | PWA-Erstellung mit Next.js App Router; Manifest, Service Worker |
| S02 | [Building a PWA in Next.js with Serwist (next-pwa successor)](https://javascript.plainenglish.io/building-a-progressive-web-app-pwa-in-next-js-with-serwist-next-pwa-successor-94e05cb418d7) | Community | 2026-07-16 | Serwist als Nachfolger des veralteten next-pwa; Service-Worker-Caching |
| S03 | [Building an Offline-First Next.js 15 App with App Router — GitHub Discussion](https://github.com/vercel/next.js/discussions/82498) | Community | 2026-07-16 | Service Worker als Fallback-Shell; IndexedDB-Daten-Caching |
| S04 | [Service Workers — web.dev](https://web.dev/learn/pwa/service-workers) | Offiziell (Google) | 2026-07-16 | Konzepte: Service Worker für schnelles Laden unabhängig vom Netzwerk |

---

## 2. Astro und statische/site-fokussierte Frameworks

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S05 | [Astro vs. Next.js: Features, performance, and use cases compared — Contentful](https://www.contentful.com/blog/astro-next-js-compared/) | Community | 2026-07-16 | Astro für statische/fast SEO-Seiten; Next.js für app-artige Daten-Erlebnisse |
| S06 | [Astro vs NextJS for Marketing Websites — Makers Den](https://makersden.io/blog/astro-vs-nextjs-marketing-website) | Community | 2026-07-16 | Astro: partielle Hydration (Islands), minimales JS; Next.js: dynamische Interaktivität |
| S07 | [Astro vs Next.js: Battle of the Static Site Generators — Medium](https://medium.com/@shujaamarwat/astro-vs-next-js-battle-of-the-static-site-generators-4a2ad77b19c9) | Community | 2026-07-16 | Astro schnellere SSG-Ladezeiten durch weniger JS |
| S08 | [Astro vs Next.js — Choose the Right Framework — Themefisher](https://themefisher.com/astrojs-vs-nextjs) | Community | 2026-07-16 | Astro stärker für statischen SEO-Inhalt; Next.js für dynamischen Inhalt |

---

## 3. SvelteKit

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S09 | [Use Supabase with SvelteKit (Official Quickstart)](https://supabase.com/docs/guides/getting-started/quickstarts/sveltekit) | Offiziell (Supabase) | 2026-07-16 | Offizielle SvelteKit-Integration; schneller Einstieg |
| S10 | [Align SvelteKit auth tutorial with Next.js #37803 — GitHub](https://github.com/supabase/supabase/issues/37803) | Issue-Tracker | 2026-07-16 | SvelteKit-Auth-Setup ist komplexer als Next.js; DX-Vergleich |
| S11 | [SvelteKit vs. Next.js — CloudCannon](https://cloudcannon.com/blog/sveltekit-vs-next-js/) | Community | 2026-07-16 | Open-Source-Vergleich: Rendering, Routing, Deployment |
| S12 | [Sveltekit vs. Next.js: A side-by-side comparison — Hygraph](https://hygraph.com/blog/sveltekit-vs-nextjs) | Community | 2026-07-16 | SvelteKit SSR; Next.js hybride Rendering (SSR + SSG) |
| S13 | [SvelteKit without SSR / SSG? — GitHub Discussion #3365](https://github.com/sveltejs/kit/discussions/3365) | Community | 2026-07-16 | adapter-static für reine SPA/PWA-Nutzung |

---

## 4. Hosting und Deployment (Vercel vs. Cloudflare Pages)

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S14 | [Cloudflare Pages vs Vercel — Bejamas](https://bejamas.com/compare/cloudflare-pages-vs-vercel) | Anbieter-Vergleich | 2026-07-16 | Free-Tier, Bandbreite, GDPR-Hinweise im Seitenvergleich |
| S15 | [Vercel vs Netlify vs Cloudflare Pages: 2025 Comparison — DigitalApplied](https://www.digitalapplied.com/blog/vercel-vs-netlify-vs-cloudflare-pages-comparison) | Community | 2026-07-16 | Free-Tier-Tabelle: Build-Minuten, Serverless-Requests, Bandbreite |
| S16 | [Cloudflare Pages vs Vercel - Which is Better for Hosting? — SpeedVitals](https://speedvitals.com/blog/cloudflare-pages-vs-vercel/) | Community | 2026-07-16 | Cloudflare gewinnt bei globalem TTFB, unbegrenzter Bandbreite, Preis |
| S17 | [Vercel vs Cloudflare Pricing Comparison (2026) — MakerKit](https://makerkit.dev/pricing-calculator/vercel-vs-cloudflare) | Anbieter-Vergleich | 2026-07-16 | Cloudflare ~92 % günstiger für typische SaaS-Lasten; kein Egress |
| S18 | [Cloudflare Pages vs Netlify vs Vercel: Static Site Hosting Compared — DanubeData](https://danubedata.ro/blog/cloudflare-pages-vs-netlify-vs-vercel-static-hosting-2026) | Community | 2026-07-16 | EU/GDPR-Compliance pro Anbieter; Vercel EU-Optionen weniger ideal für GDPR |
| S19 | [Cloudflare Pages vs Vercel — MG Software](https://www.mgsoftware.nl/en/vergelijking/cloudflare-pages-vs-vercel) | Community | 2026-07-16 | Cloudflare: unbegrenzte Bandbreite gratis; Vercel: 100 GB/Monat gratis |

---

## 5. Supabase — RLS, anonyme Bestellung, TypeScript, Region

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S20 | [Row Level Security — Supabase Docs](https://supabase.com/docs/guides/database/postgres/row-level-security) | Offiziell (Supabase) | 2026-07-16 | RLS muss auf allen Tabellen eines exponierten Schemas aktiv sein |
| S21 | [Supabase RLS Best Practices: Production Patterns — MakerKit](https://makerkit.dev/blog/tutorials/supabase-rls-best-practices) | Community | 2026-07-16 | Produktionsmuster für Multi-Tenant; auth-Kontext-basierte Policies |
| S22 | [Generating TypeScript Types — Supabase Docs](https://supabase.com/docs/guides/api/rest/generating-types) | Offiziell (Supabase) | 2026-07-16 | `supabase gen types` erzeugt TypeScript-Typen aus DB-Schema |
| S23 | [JavaScript: TypeScript Support — Supabase Docs](https://supabase.com/docs/reference/javascript/typescript-support) | Offiziell (Supabase) | 2026-07-16 | Typen direkt aus Schema; End-to-End-Typsicherheit |
| S24 | [Generate types using GitHub Actions — Supabase Docs](https://supabase.com/docs/guides/deployment/ci/generating-types) | Offiziell (Supabase) | 2026-07-16 | CI/CD-Automatisierung der Typ-Generierung; immer synchron |
| S25 | [Available Regions — Supabase Docs](https://supabase.com/docs/guides/platform/regions) | Offiziell (Supabase) | 2026-07-16 | EU-Region Frankfurt (eu-central-1) verfügbar |
| S26 | [DPA (Data Processing Addendum) — Supabase](https://supabase.com/legal/dpa) | Offiziell (Supabase) | 2026-07-16 | Datenschutz-Zusatzvereinbarung für GDPR |
| S27 | [Is Supabase GDPR compliant? — GitHub Discussion #2341](https://github.com/orgs/supabase/discussions/2341) | Community | 2026-07-16 | EU-Region (eu-west-1/Frankfurt) unterstützt GDPR-Compliance |
| S28 | [Is Supabase DSGVO/GDPR compliant? — AnswerOverflow](https://www.answeroverflow.com/m/1448312332403871754) | Community | 2026-07-16 | Supabase nutzt AWS; Frankfurt = eu-central-1 |

---

## 6. PWA Offline — App Shell vs. Datenübermittlung

| # | Quelle | Typ | Abruf | Verwendung |
|---|--------|-----|-------|------------|
| S29 | [Offline and Background Operation — MDN](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Offline_and_background_operation) | Offiziell (MDN) | 2026-07-16 | App-Shell-Modell + Background-Sync/Periodic-Sync-API |
| S30 | [Offline Support in Web Apps: Foreground Queue vs. Background Sync — Tomasz Gil](https://blog.tomaszgil.me/offline-support-in-web-apps-foreground-queue-vs-background-sync) | Community | 2026-07-16 | **Kernquelle** für Trennung: Foreground-Queue vs. Background-Sync bei Daten-Submission |
| S31 | [Synchronize and Update a PWA in the Background — Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-edge/progressive-web-apps/how-to/background-syncs) | Offiziell (MS) | 2026-07-16 | Background-Sync-API: automatischer Retry bei Konnektivität |
| S32 | [PWA Offline Experience: App Shell Pattern — Medium](https://medium.com/codetodeploy/pwa-offline-experience-offline-pages-and-app-shell-pattern-95714355c551) | Community | 2026-07-16 | App-Shell: minimales HTML/CSS/JS für Instant-Load cachen |
| S33 | [Difference in Offline-First Approach and PWAs — Stack Overflow](https://stackoverflow.com/questions/59031717/difference-in-offline-first-approach-and-pwas) | Community | 2026-07-16 | Verhältnis Offline-First-Architektur vs. PWA-Fähigkeiten |

---

## Quellen-Hierarchie

Bei Widersprüchen gilt:

1. **Offizielle Framework-/Plattform-Dokumentation** (nextjs.org, supabase.com,
   developer.mozilla.org, web.dev, learn.microsoft.com)
2. **Offizielle Supabase-Docs** für Backend/RLS/Region
3. **Anbieter-Vergleichsseiten** (Bejamas, MakerKit) — kommerziell motiviert,
   gegen mehrere Quellen kreuzgeprüft
4. **Community-Artikel/Blogs** — Erfahrungswerte und DX-Vergleiche
5. **Foren/Stack Overflow/Reddit** — Workarounds und bekannte Probleme
