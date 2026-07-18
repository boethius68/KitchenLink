# KitchenLink Current State

**Updated:** 18 July 2026
**Integration branch:** `main`
**Phase:** Design-system implementation
**Release status:** Internal sandbox, not production
**Last merge:** PR #10 `glm/web-next` -> `main` (KL-WEB-003), bringing the
guest-web sandbox into real operation for the first time: an additive
`20260718010000` migration that fixes two genuine bugs found by the first
real-instance integration run (the merged KL-WEB-002 RPC was not runnable as
shipped), plus an integration-test harness, Supabase CLI init and a setup
guide. Before that, the same day: `minimax/inventory-domain` (KL-INVENTORY-001),
`glm/guest-web-order-gate` (KL-WEB-002, the authoritative guest order gate and
Supabase Anonymous Sign-in), PR #8 (KL-WORKFORCE-001 workforce domain), PR #7
(KL-OFFLINE-003 event-log/outbox prototype), `claude/guest-web-foundation`
(KL-WEB-001 guest-web foundation), PR #9 (KL-QA-002 offline order smoke), PR #6
(collaboration-state sync) and PR #5 (kitchen hardening). Earlier: PR #1
delivered the Claude audit and the `Heute`/`Kueche` reference areas, PR #2/#3
completed `KL-MENU-004`, PR #4
recorded that merge.

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
  Vercel deploy). The user's sandbox instance is configured and live; the gate
  runs. Hosting decision D4 (Vercel vs Cloudflare Workers) remains open.
- `kitchenlink/Features/Inventory/` (KL-INVENTORY-001) is an isolated Swift
  domain foundation for the stock core required by Blueprint §11:
  dimension-safe quantities (mass/volume/count), an append-only ledger with
  idempotency keys, reversal and balanced-transfer protection, a
  fresh-computed physical/reserved/available projection, a recipe resolver
  and a replenishment advisor. No UI, persistence, cloud sync or valuation
  logic, as scoped.
- The active parallel queue and disjoint agent scopes are recorded in
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

## Next Decision

PR #6 (collaboration-state sync), PR #5 (kitchen hardening) and PR #9
(KL-QA-002 offline order smoke) were reviewed by Claude Code and integrated on
17 July 2026. The Round-2 rebase warning from PR #6 became obsolete before
integration: the remaining mission branches were rebased onto the PR #4 merge
base and all merges applied conflict-free. The KL-INVENTORY-001 mission that
never got a `minimax/inventory-domain` branch the first time around was
reassigned and delivered the same day (see below).

The KL-WEB-001 guest-web foundation merged the same day, reviewed visually by
the user against the Round-04 Claude Design export rather than only the
derived `DESIGN_SYSTEM.md` spec (see `guest-web/README.md` and the Claude
handoff for the six divergences found and corrected).

PR #7 (`glm/offline-event-log-v2`, KL-OFFLINE-003) was reviewed by Claude Code
and integrated the same day: 35/35 tests pass, no P0/P1 findings. Three minor
observations (a stale AUTOINCREMENT comment, two sequentially-run tests whose
names imply real multi-threading, an unescaped fingerprint delimiter) are
non-blocking and already self-disclosed in `EVENT_LOG_V2.md` and the GLM
handoff.

PR #8 (`kimi/workforce-domain`, KL-WORKFORCE-001) was reviewed by Claude Code
and integrated the same day. One real bug was found and fixed during
integration: `finalizeSwap(accepted: false)` left a stale `acceptedAt` after
a rejected swap on a previously-accepted shift, contradicting the
`.published` status; fixed with a regression test covering the previously
untested path. 38/38 workforce tests and the complete unit suite are green
on the merged state.

Two missions were assigned the same day (documented as copy-ready prompts in
`docs/collaboration/PARALLEL_MISSIONS_2026-07-17.md`) and both were delivered
and integrated the same day too:

- **KL-WEB-002** (GLM 5.2, `glm/guest-web-order-gate`): reviewed by Claude
  Code and merged. One real bug was found and fixed during integration — the
  order summary sheet showed a stale "Summe: 0,00 €" right next to the
  confirmed-order message, because the cart was cleared before the sheet's
  live total recomputed. Fixed by snapshotting the cart and showing the
  server-confirmed total once accepted. A narrow, documented (not fixed)
  risk remains: a concurrent double-submit race with the same idempotency
  key surfaces as a generic error instead of a clean conflict/replay result
  for the losing request; the core "never two orders for one key" guarantee
  is unaffected.
- **KL-INVENTORY-001** (MiniMax, `minimax/inventory-domain`): reviewed by
  Claude Code and merged, no code changes needed. One design choice was
  investigated in depth rather than assumed to be a bug — reversal
  protection intentionally runs before the idempotency check, guaranteeing
  "exactly once" for a Storno rather than silently replaying a second click.
  MiniMax's own handoff already documents this exact tradeoff.

The offline-venue-hub discovery (both branches) was reviewed on 18 July 2026.
The five discovery documents plus an integration reading now live under
`docs/discovery/offline-venue-hub/`. Key reading: the Stage-1 event-log
contract — the only part the red-team gave a conditional go — is effectively
already covered by the merged KL-OFFLINE-003 prototype, so the next low-risk
step there would be the iOS integration seam (event store behind
`KitchenLinkRepository`). The network side of the hub stays blocked on
unresolved P0 decisions, most notably a collision with the just-merged
cloud-first guest web: an HTTPS-served guest page cannot reach a local HTTP
hub (Mixed Content + Chrome Local Network Access), so Blueprint §16.2's
offline guest ordering is a genuine product/architecture fork for the user.
No `DECISIONS.md` change follows — discovery stays discovery.

Remaining:

- The network-side venue hub (local HTTP server, guest-to-hub reach,
  leader election/failover) is blocked on the user P0 decisions recorded in
  `docs/discovery/offline-venue-hub/INTEGRATION_REVIEW.md` §4.
- The KL-WEB-002 idempotency-race follow-up is now closed (KL-WEB-003). The
  user's real Supabase sandbox instance is configured and live; the guest-web
  gate runs against it end-to-end.
- Still open in the guest-web scope: the Vercel sandbox deployment (first
  deploy, not a D4 hosting decision — the Vercel-vs-Cloudflare-Workers PoC from
  ADR-001 §8 stays open), the PWA/offline stage (D5), the menü-fetch switch
  from the local fixture to Supabase, and the cleanup policy for orphaned
  anonymous users.
