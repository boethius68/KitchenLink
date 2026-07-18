# KitchenLink Current State

**Updated:** 18 July 2026
**Integration branch:** `main`
**Phase:** Integrated sandbox; guest web live, iOS domain expansion
**Release status:** Publicly reachable sandbox, not production
**Latest material integration:** PR #17
(`codex/project-cleanup-20260718` -> `main`) aligned the repository with the
live sandbox, preserved Supabase menu ordering and cleared the dependency
audit. PR #15 previously added the reviewed read-only V2 inventory operator
surface. The guest web remains deployed from `main` to Hostinger PaaS at
**`https://kitchenlink.luneq.eu`** and anonymous sandbox ordering has been
verified end-to-end against the EU-Frankfurt Supabase instance.

## Product

- KitchenLink is a smartphone-first restaurant operating system for guests,
  employees and operators.
- Initial target: straightforward restaurants, bars and cafes in Germany.
- Guest ordering starts in the browser; operators require the iPhone app.
- The sandbox retains demo and simulated flows for testing.
- Supabase is active again, but cloud availability must not remove demo paths.
- Full scope and milestones live in `docs/PRODUCT_BLUEPRINT.md`.

## Design

- The first internal logo and app direction was not approved.
- Claude Design Round 01 contains `Tageslicht`, `Takt` and `Blende`.
- Claude Design Round 02 archives Turn 3 with six additional logo principles and
  four color worlds plus Turn 4 with two Zitrus role distributions. None of the
  Claude logos was selected.
- The rounded Codex wordmark from refinements 14 and 15 is the strongest basis so
  far. After additional comparisons, the complete gastronomy refinement 15 is
  now the preferred working baseline. It is not a final logo approval.
- Logo history and user feedback are preserved under
  `docs/design/codex-logo/round-01/`.
- A reconstructed vector working version, including color, monochrome, reverse,
  app icon and small-size tests, is under `docs/design/codex-logo/working-v1/`.
- Color remains separate from logo development. Dark green is not compelling as
  a lead color, and the Claude-like terracotta/cream/warm-brown combination is
  excluded.
- The emotional color brief is the reward after a hard day through taste and
  connection: fresh and sparkling like a warm breeze.
- From Claude Design Turn 3b, `Zitrus` (lemon and grape) is the preferred color
  territory. In Turn 4, 4a `Ruhe` was selected as the sole basis for refinement:
  grape carries the brand foundation and lemon marks the logo handoff and primary
  action. Exact values and supporting colors are not yet approved.
- Round 01 and its review are under `docs/design/claude-design/round-01/`.
- Round 02, the selected 4a direction and the constrained Turn 5 prompt are under
  `docs/design/claude-design/round-02/`.
- Round 03 archives and reviews Turn 5. The refined light/dark tokens and primary
  action states are promising, but the palette is not final: payment versus error
  semantics, light-surface status-symbol contrast and control-border contrast
  require one constrained correction.
- Round 04 archives and verifies Turn 6, the last regular Claude Design pass. It
  resolves the blocking status, contrast, density and typography issues. No
  reserve prompt is required; Claude Code and Codex continue implementation as
  equal peers.
- Claude Code completed KL-CLAUDE-001 and KL-OPS-001: an independent audit of
  the integrated state (no P0/P1 findings, one P2 and four P3 notes in
  `docs/collaboration/reviews/CLAUDE_AUDIT_2026-07-16.md`), then the Round-04
  direction implemented as two real reference areas, `Heute` and `Kueche`. The
  user reviewed both visually and merged PR #1. No new palette, typography or
  logo approval follows from this; `DECISIONS.md` remains the approval
  boundary.
- Following the user's own feedback on the kitchen bump action (wet hands,
  time pressure at the pass), the ticket-advance control became a full-width,
  light-filled high-contrast button with success haptics instead of a swipe
  gesture. A swipe remains a possible later accelerator once the order domain
  supports reversing a status change.
- The platform-neutral working specification is
  `docs/design/DESIGN_SYSTEM.md`. It preserves the selected 4a direction while
  keeping exact palette, typography and logo approval explicitly open.

## Code

- A functioning SwiftUI sandbox prototype exists.
- The 4a `Ruhe` tokens, type roles, status semantics, surfaces and controls now
  exist alongside the legacy theme in `KitchenLinkDesignSystemV2.swift`.
- The internal build starts in a switchable V2 business home and scan/import
  flow. `--kitchenlink-design-legacy` opens the previous presentation directly;
  both variants retain a visible route to the other one.
- The selected Working-v1 symbol and outlined wordmark are bundled as local
  light/dark vector assets recolored to grape and lemon. No runtime font or
  network dependency was added.
- Document camera, photo selection, OCR, review, local menu replacement and the
  complete legacy product sandbox continue to use the existing implementation.
- Three real multi-page menu fixtures can now be selected directly from the scan
  entry and use the same local OCR, review and import path as uploaded photos.
- A reproducible 14-page scanner benchmark now protects 23 section and 46 item
  anchors in both the legacy result and the import draft. The draft retains all
  46 item-name anchors, including two Lichtburg names whose prices Vision does
  not currently associate, while the legacy result remains unchanged.
- GLM completed the KL-MENU-001 taxonomy research and DeepSeek performed a
  red-team review. The material is useful discovery, not an approved ontology:
  source counts, saturation counts and artifact versions remain inconsistent.
- The integration review under `docs/discovery/taxonomy-research/` accepts only
  the lossless draft principles. A thin, provider-neutral Swift import contract
  now exists as pre-stable version `0.1.0`, with structured evidence, typed
  optional prices and recursive validation. Broad additional research does not
  block implementation.
- The local Apple Vision/rule scanner now creates `[MenuSectionData]` and a
  `MenuImportDraft` from the same OCR pass. Source type, document fingerprint,
  raw OCR text, page, normalized bounding box, confidence, raw price and review
  state are carried into the draft; the old sandbox preview remains active.
- Pending title blocks that the price-required legacy model used to discard are
  retained as unpriced `needsReview` entries. The current fixtures produce seven
  such candidates for Lichtburg and two for Alexxanders; they include both real
  missing-price items and structural/translation candidates and must not be
  auto-published.
- The draft-native review now displays original evidence, raw text, price state
  and review reasons. Unlocated fallback evidence is explicitly marked and does
  not render a misleading crop.
- Operators can edit, move, accept or reject entries before conversion. An
  explicit batch action accepts only unresolved entries with a usable fixed
  price; unpriced candidates remain open for individual correction or rejection.
- Conversion stays locked until every candidate is resolved and writes only to
  the existing local sandbox menu. The complete unit/UI suites and the 14-page
  scanner benchmark passed before integration.
- `kitchenlinkTests/KitchenLinkOfflineOrderFlowTests.swift` (KL-QA-002) covers
  the local offline order flow: guest-to-owner delivery, the full lifecycle
  chain, guest tracking, all 36 status-transition combinations, persistence
  across relay recreation and observable teardown. What this smoke does not
  prove (SQLite durability, idempotency, real venue-hub transport) is recorded
  in `docs/test-plans/OFFLINE_ORDER_FLOW.md`.
- `kitchenlink/Features/Today/` and `kitchenlink/Features/Kitchen/` now provide
  the V2 `Heute` and `Kueche` reference areas, reachable from the V2 business
  home. Both derive their state from the existing sandbox order domain
  (repository and relay) rather than a second order model, and a demo seeder
  drives a representative service scenario for review and testing.
- The kitchen ticket-advance action is a full-width, high-contrast button
  with success haptics; lemon is not used there, matching the status-token
  rule.
- `prototypes/KitchenLinkEventLog/` (KL-OFFLINE-003) is an isolated Swift
  package prototype for the authoritative local event log and its outbox:
  append-only events with optimistic concurrency, idempotency via
  `(venue_id, idempotency_key, request_fingerprint)`, and a lease-based
  outbox claim/nack/ack cycle with an honest, source-linked durability
  policy (WAL + `synchronous=FULL` + `fullfsync`, no unproven crash-safety
  claims). It has no app dependency and activates nothing productive; the
  later iOS integration seam is documented but deliberately out of scope
  (`docs/architecture/offline/EVENT_LOG_V2.md` §12).
- `kitchenlink/Features/Workforce/` (KL-WORKFORCE-001) is an isolated Swift
  domain foundation for shift planning, time tracking and staffing
  (Blueprint §9): `VenueShift`, `WorkforcePlannedShift` and time-entry
  objects stay separate as required, every availability/leave/shift carries
  an explicit time zone, and shift-template resolution is DST-correct
  (verified against both 2025 Europe/Berlin transitions). No UI,
  persistence, cloud or legal-policy encoding, as scoped.
- `guest-web/` now holds the KL-WEB-001 guest-web foundation: a Next.js App
  Router (TypeScript) project with a statically generated eight-dish guest
  menu card over a local sandbox venue, the same seam the later Supabase
  path will replace. Design tokens from `DESIGN_SYSTEM.md` exist as CSS
  variables sharing the SwiftUI semantic names, kept consistent with a
  Vitest check. The first pass was rebuilt after the user compared it
  against the actual Round-04 visual export (not just the derived
  `DESIGN_SYSTEM.md` spec) and requested a closer match: a flush venue
  header with an open/closed badge, outlined `border-control` quantity
  controls, a single full-width lemon order-bar button, small tag pills,
  and no unrequested page-wide dark-mode surface flip (only the venue
  header is grape-led; the content area stays light, matching every
  verified reference screen). The PWA/offline stage remains deliberately out
  of scope.
- `docs/architecture/guest-web/ADR-001_GUEST_WEB_STACK.md` and `SOURCES.md`
  (Revision 2, the version the user approved as the guest-web stack decision
  basis) are now on `main` under the same path GLM's own mission references.
  They previously existed only on the unmerged `glm/guest-web-architecture`
  branch; brought over verbatim, no content changes.
- KL-WEB-002 (GLM) implements ADR-001 §6/§6.3 for real: an additive migration
  (`idempotency_key` + payload-hash comparison, `menu_items.slug`, a sandbox
  seed matching `venue-data.ts`), Row Level Security enabled on all six
  guest-facing tables (previously none had any), and `guest_web_submit_order`
  — a `SECURITY DEFINER` RPC with a `FOR UPDATE`-locked re-pricing step — as
  the sole write path for guest orders. The guest card's visual design is
  unchanged; only the submit/ACK wiring is new. A narrow race (two
  near-simultaneous submits with the same idempotency key) is caught by the
  database's unique constraint but not remapped to a clean conflict/replay
  result client-side — documented as a follow-up, not a merge blocker, since
  the core "never two orders for one key" guarantee still holds.
- KL-WEB-003 (GLM, PR #10) closes that follow-up and proves the whole guest-web
  stack against a real Supabase instance for the first time. Additive migration
  `20260718010000` redefines `guest_web_submit_order` with an
  `EXCEPTION WHEN unique_violation` block so the concurrent-race loser gets a
  clean replay/conflict result instead of a generic `rpc_error`. The first real-
  instance integration run (4/4 tests green against the user's EU-Frankfurt
  sandbox project) also surfaced **two genuine bugs in the as-merged KL-WEB-002
  RPC that the unit tests could not find**: `digest()` lives in Supabase's
  `extensions` schema (not in the function's `search_path`) and the
  `status`/`total_cents`/`currency` column references were ambiguous against the
  function's own `RETURNS TABLE` columns. Both are fixed in `20260718010000`.
  **Important: the three guest-web migrations (`20260318011000`,
  `20260717120000`, `20260718010000`) are only runnable together** — the
  original KL-WEB-002 RPC does not execute on a fresh Supabase instance without
  the KL-WEB-003 fix migration. Also added: an integration-test harness under
  `guest-web/__tests__/integration/` (skips cleanly without a configured
  instance, `KL_INTEGRATION=1` to run), a Supabase CLI `config.toml` (no
  secrets), and `docs/architecture/guest-web/SANDBOX_SETUP.md` (step-by-step:
  Supabase EU-Frankfurt, enable Anonymous Sign-in, apply migrations, `.env.local`,
  deploy).
- KL-WEB-003 went live the same day: the user deployed the guest web via
  **Hostinger PaaS** (Git-based auto-deploy from `main`, not a Vercel or
  Cloudflare setup as ADR-001 §8 anticipated) to
  **`https://kitchenlink.luneq.eu`**, with `NEXT_PUBLIC_SUPABASE_*` set as
  Hostinger environment variables. End-to-end verified: menu renders, an
  anonymous order goes through and returns the ACK, against the real EU-
  Frankfurt Supabase instance. A manual smoke test also surfaced and fixed two
  follow-ups: the order-summary sheet offered a second submit on an already-
  emptied cart (now disabled after `accepted`) and the success confirmation was
  a small grey note (now a prominent grape confirmation card, no new tokens).
  **D4 (Vercel vs Cloudflare Workers) is effectively resolved for the sandbox:
  Hostinger PaaS was chosen by the user.** ADR-001's Vercel-vs-Cloudflare PoC
  is therefore superseded for sandbox use; a later production-grade hosting
  decision remains open but is no longer blocking. Lesson recorded: the
  `NEXT_PUBLIC_SUPABASE_URL` was initially set to `supabase.com` instead of
  `supabase.co`, producing a misleading "Load failed"; the correct TLD is
  `.co` and `SANDBOX_SETUP.md` should call this out explicitly.
- KL-WEB-004 (GLM, merged with PR #14) closes the
  menu-source inconsistency left by KL-WEB-002/003: the guest card's menu was
  still served from the local fixture `guest-web/src/lib/venue-data.ts` while
  the order was validated against Supabase, so DB-side menu edits would never
  reach the live product. This ticket switches the menu display to a Supabase
  fetch via a new read layer `guest-web/src/lib/menu-loader.ts`, rendered as
  **ISR (`revalidate = 60s`)** — the page stays CDN-cacheable but DB changes
  show up within a minute. Additive migration `20260719000000_menu_items_tag`
  adds a nullable `menu_items.tag` column (seeded for the 8 sandbox items to
  match the fixture) so the "beliebt"/"vegetarisch" pills survive the switch.
  **Load-bearing invariant documented in `menu-loader.ts`:
  `GuestMenuItem.id = menu_items.slug` (not the UUID)** — `order-submit.ts`
  sends `item.id` as the order slug to the RPC, which resolves via
  `menu_items.slug`. The local fixture stays as a **build fallback** (so a
  Hostinger rebuild during a Supabase outage does not fail). Verified: 50/50
  unit + 8/8 integration tests green against the real instance; `next build`
  reports `Revalidate 1m` on `/[venueSlug]/menu`. No visual change, no token
  change, no order-path change.
- `kitchenlink/Features/Inventory/` contains the Swift stock foundation from
  KL-INVENTORY-001 and the read-only operator surface from KL-INVENTORY-002:
  dimension-safe quantities (mass/volume/count), an append-only ledger with
  idempotency keys, reversal and balanced-transfer protection, a
  fresh-computed physical/reserved/available projection, a recipe resolver
  and a replenishment advisor. The UI shows only location pairs with actual
  ledger activity, avoiding false zero-stock alarms where no assortment model
  exists. Persistence, cloud sync and valuation logic remain out of scope.
- The completed ticket history is recorded in
  `docs/collaboration/WORK_QUEUE.md`.
- The shared collaboration and design state must be present on `origin/main`
  before Claude Code and Codex start parallel worktrees from it.
- No production deployment, live payment activation or final fiscal integration
  is approved.

## Agent Setup

- Shared instructions are available through `AGENTS.md` and `CLAUDE.md`.
- Claude Code and Codex are equal technical collaborators. `main` is neutral;
  the user remains the product and design authority. The binding integration
  process is `docs/collaboration/PEER_WORKFLOW.md`.
- New work is assigned only to Claude Code or Codex until the user changes that
  decision. Earlier GLM, DeepSeek, Kimi and MiniMax handoffs remain historical
  context. The last already-started GLM strand, PR #15, has been reviewed and
  integrated.
- Claude Code `2.1.150` is installed locally.
- The two-phase Claude audit and design implementation mission is recorded in
  `docs/collaboration/CLAUDE_MISSION.md`; Claude works in an isolated worktree.
- The user starts Claude Fable 5 independently through the Claude app. The local
  folder and copy-ready prompts are documented in
  `docs/collaboration/CLAUDE_START_HERE.md`.
- The official Claude Design MCP endpoint is registered in the Claude user
  configuration. Interactive authentication with `/design-login` is still
  required.
- New Claude Design ZIP files can be imported with
  `scripts/import-claude-design.sh`.

## Current Focus and Open Decisions

- **Inventory:** PR #15 / KL-INVENTORY-002 is integrated after technical and
  visual review. A future location-specific assortment contract would be
  needed to display a planned article at `0` before its first ledger movement;
  this is a known model boundary, not an active implementation ticket.
- **Offline venue hub:** the local-network side remains blocked on the P0
  product and architecture decisions in
  `docs/discovery/offline-venue-hub/INTEGRATION_REVIEW.md` §4. In particular,
  an HTTPS guest web cannot directly rely on an untrusted local HTTP hub.
- **Guest web:** production-grade hosting, PWA/offline behavior and retention
  for orphaned anonymous users remain open. Hostinger is selected only for the
  current sandbox; Supabase menu loading and authoritative sandbox ordering are
  already live.
- **Production boundary:** no live payment, fiscal activation or removal of
  sandbox labeling is approved.
