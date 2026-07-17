# KitchenLink Approved Decisions

Only decisions explicitly approved by the user belong here. New entries are
append-only; superseded decisions are marked rather than deleted.

## Product Foundation

- **Target venue:** Start with straightforward restaurants; bars and cafes must
  fit the same product.
- **Users:** Guests, employees and operators use KitchenLink.
- **Guest access:** Guests can order immediately in the browser without installing
  an app. A customer app may be added later.
- **Business access:** Operators require an iPhone app. The product must remain
  capable of expanding to iPad, web and other phones.
- **Core promise:** A restaurant can theoretically be opened and operated with
  smartphones instead of a costly bundle of proprietary hardware.
- **Ordering:** Orders normally pass through immediately. A venue can optionally
  require employee confirmation.
- **Menu onboarding:** Scanning an existing restaurant menu is the first onboarding
  tool and primary pitch. The first explanation of it should remain concise.
- **Staff scheduling:** Complete shift planning is part of the sandbox beta.
- **Sandbox:** Demo and simulation functions remain available during development.
- **Payments and providers:** Initially simulated in sandbox mode.
- **Offline direction:** An iPad venue hub is the intended local continuity layer;
  the detailed production implementation remains pending.

## Design

- KitchenLink should feel simple, fresh without trying too hard, friendly without
  becoming cute, and self-explanatory in use.
- The original internal logo and visual direction are not approved.
- No Claude Design territory has been approved yet.
- **Logo exploration:** None of the six Claude Design Turn 3a logos is approved.
  The rounded Codex wordmark shown in logo refinements 14 and 15 is the strongest
  basis so far, but it is not final.
- **Wordmark option:** A distinctive wordmark may become the primary logo if it
  also yields a memorable compact signature for customer-facing touchpoints.
- **Brand emotion:** KitchenLink should evoke the reward after a hard day through
  delicious taste and connection with loved ones. The desired mood is fresh and
  sparkling like a warm breeze.
- **Color exclusions:** Dark green is not preferred as a lead brand color. The
  Claude-like combination of terracotta, cream and warm brown is excluded. The
  final palette remains open.
- **Logo working baseline:** After comparing additional logo and color variants,
  the user still prefers the original Codex gastronomy refinement 15. Further
  work should refine this design rather than replace it with a new concept.
- **Logo color scope:** The original relationship of a dark foundation and one
  vivid handoff accent is part of the preferred effect. Its exact color values
  and the surrounding product palette are not approved yet.
- **Preferred color territory:** Of the four Claude Design Turn 3b color worlds,
  `Zitrus` (lemon and grape) is the user's preferred direction. It must be tested
  with the selected logo before exact colors or usage rules are approved.
- **Zitrus role distribution:** Of the two Turn 4 applications, the user selected
  4a `Ruhe` as the sole basis for further palette refinement. Grape carries the
  brand foundation; lemon is reserved for the logo handoff and primary actions.
  This selects the role model, not the final hex values, typefaces or status
  palette.

## Guest Web (KL-WEB-001, approved 17 July 2026)

- **Framework:** Next.js (App Router, TypeScript) per ADR-001 on
  `glm/guest-web-architecture` is the working basis for the guest web.
- **Hosting path:** The sandbox beta deploys to Vercel. The code stays
  hosting-neutral; the Vercel-versus-Cloudflare-Workers PoC from ADR-001 §8
  becomes a mandatory gate before any production activation.
- **Anonymous identity:** Guest ordering uses Supabase Anonymous Sign-in
  (`authenticated` role with `is_anonymous` claim) combined with the
  authoritative order gate; a cleanup policy for orphaned anonymous users is
  required. The bare `anon` role is not used for order writes.
- **URL structure:** The sandbox uses path-based venue routes (`…/<venue>`).
  Per-venue subdomains and custom domains remain open product decisions to
  revisit before production.
- Still open by design: custom domains per restaurant (D3), the PWA/offline
  shell stage (D5) and the order-gate implementation variant Edge Function
  versus PostgreSQL RPC (D6, implementation detail).

## Collaboration Governance

- **Agent parity:** Claude Code, Codex and future coding agents work as equal
  technical collaborators. No agent is the boss, permanent integrator or
  mandatory gatekeeper for another agent's work.
- **Shared integration:** `main` is a neutral shared integration branch. Every
  agent works in its own branch and worktree and may propose, implement, review
  or integrate work under the same rules.
- **User authority:** The user retains final authority over product scope,
  design approval, production activation and other product decisions. Agent
  disagreement is surfaced to the user rather than resolved by hierarchy.
