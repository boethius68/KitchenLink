# KitchenLink Current State

**Updated:** 17 July 2026
**Integration branch:** `main`
**Phase:** Design-system implementation
**Release status:** Internal sandbox, not production
**Last merge:** `claude/guest-web-foundation` -> `main`, the KL-WEB-001
guest-web foundation (Next.js App Router, statically generated eight-dish
guest menu card, shared design tokens). Before that, the same day: PR #9
(KL-QA-002 offline order smoke), PR #6 (collaboration-state sync) and PR #5
(kitchen hardening). Earlier: PR #1 delivered the Claude audit and the
`Heute`/`Kueche` reference areas, PR #2/#3 completed `KL-MENU-004`, PR #4
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
  verified reference screen). The authoritative order gate, Supabase
  wiring and PWA/offline stage are deliberately not part of this
  foundation.
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
base, all three merges applied conflict-free, and `minimax/inventory-domain`
does not exist on `origin` at all.

The KL-WEB-001 guest-web foundation merged the same day, reviewed visually by
the user against the Round-04 Claude Design export rather than only the
derived `DESIGN_SYSTEM.md` spec (see `guest-web/README.md` and the Claude
handoff for the six divergences found and corrected).

Remaining, in recommended order:

- Review `glm/offline-event-log-v2` (PR #7, KL-OFFLINE-003) in its own scope —
  isolated Swift package prototype (schema, outbox, transport, 20+ tests).
- Review `kimi/workforce-domain` (PR #8, KL-WORKFORCE-001) in its own scope —
  new `Features/Workforce/` domain plus 632 lines of tests.
- KL-WEB-001 next increments, each its own scope: the authoritative order
  gate (Edge Function or PostgreSQL RPC, ADR-001 §6), Supabase Anonymous
  Sign-in wiring, and the Vercel sandbox deployment (with the
  Cloudflare-Workers PoC still required before any production activation).
- `minimax/inventory-domain` does not exist on `origin`; KL-INVENTORY-001
  needs to be reassigned or dropped.
- KL-INVENTORY-001 was never started and needs to be reassigned or dropped.
- `deepseek/offline-venue-hub-review` and `glm/offline-venue-hub` remain
  discovery material and need their own review before anything is adopted.
