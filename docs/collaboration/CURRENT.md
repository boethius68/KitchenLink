# KitchenLink Current State

**Updated:** 19 July 2026
**Integration branch:** `main`
**Phase:** Integrated sandbox; guest web live, iOS domain expansion
**Release status:** Publicly reachable sandbox, not production
**Latest material integration:** PR #27
(`codex/iphone-hub-network-recovery` -> `main`) stabilizes the foreground
iPhone Hub across WLAN loss and local IPv4 changes. Listener, port, loopback
operator path and SQLite event log stay active while the guest URL and QR code
disappear into an explicit waiting state and return automatically with the
current WLAN address. The real WLAN-off/on acceptance passed on 19 July 2026.
PR #25 remains the underlying iPhone-hosted vertical slice, PR #23 the operator
workflow, PR #22 fixed the first iPhone-LAN blocker and PR #20 introduced
commit-before-ACK. Local guest ordering during cloud failure remains a required
Sandbox-Beta capability. The guest web remains deployed from
`main` to Hostinger PaaS at
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
  claims). PR #25 now exercises the documented iOS integration seam through
  the shared guest-order core; it still activates nothing productive
  (`docs/architecture/offline/EVENT_LOG_V2.md` §12).
- `prototypes/KitchenLinkLocalGuestPOC/` began as the isolated macOS host
  surrogate from KL-OFFLINE-004. Its shared core now supports iOS and macOS,
  bundles the same-origin mobile guest page and bootstrap document, validates
  menu lines and prices server-side, and returns an accepted receipt only after
  the existing event log has atomically committed the event plus cloud outbox.
  Retries return the original receipt; same-key/different-payload requests
  conflict. This proves the software seam locally; Android, AP isolation,
  background Hub lifecycle, automatic discovery and TLS/trust remain open and
  no production path is activated.
  PR #20 integrated the prototype after an additional review pass required
  `application/json` for order writes and replaced menu HTML interpolation with
  DOM-safe text rendering. The merge commit is `be54d60`.
- The same host surrogate now projects
  committed orders through `GET /operator/orders` and accepts the narrow,
  append-only lifecycle `preparing -> ready -> served`. The iPhone V2 business
  home exposes `Lokaler Service`: Kitchen mode receives placed local orders,
  `Bestellung zubereitet` hands them to Waiter mode, and `Bestellung serviert`
  completes them. It reuses `LiveOrderMessage` and `OrderLifecycleStatus`
  rather than creating another app order domain. This remains a sandbox
  polling client for either its internal foreground iPhone Hub or the retained
  macOS fallback, not a production hub architecture.
  PR #23 integrated this slice after the intended real two-device acceptance:
  the iPhone stayed open in Kitchen mode while a second device submitted
  through the local guest page; the order appeared live, moved to Waiter mode
  after preparation, and was completed there as served.
- PR #25 integrates KL-OFFLINE-006: `Lokaler Service` starts an iOS
  `NWListener` on a dynamic port, advertises `_kitchenlink-hub._tcp`, shows a
  scannable QR code plus the concrete WLAN guest URL and connects the operator
  projection internally through loopback. The Hub stops when the view closes
  or the app backgrounds; the macOS address remains available as a deliberate
  fallback. The signed build was installed on the test iPhone and the user
  passed the real Mac-to-iPhone flow: guest page from the iPhone URL, durable
  order receipt, live Kitchen arrival and handoff into Waiter mode.
  PR #27 adds KL-OFFLINE-007: a foreground monitor tracks only the iOS WLAN
  interface, keeps listener/port/event log stable without an address and
  publishes guest URL plus QR code again after WLAN recovery or an IPv4
  change. Start without WLAN, loss/recovery and stable-port behavior are
  automated; the user also passed the real WLAN-off/on device flow. Automatic
  client discovery, background operation, LAN authentication, Android, AP
  isolation and TLS/trust remain open; no production path is enabled.
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
- KL-CLOUD-001 (merged into `main` on 19 July 2026) closes the
  operator half of the cloud order loop: an additive migration adds
  `venue_staff`, staff read policies, the status RPC
  `operator_update_order_status` and the public-readable
  `venue_hub_presence` heartbeat. The app gains
  `kitchenlink/Features/CloudOperations/` (configurable Supabase access,
  e-mail operator sign-in with refresh-token renewal, 3-second polling,
  status via RPC, 15-second presence heartbeat carrying the local hub URL).
  `Lokaler Service` became a unified `Service` area: online and local orders
  appear in one kitchen/waiter list, the local hub always runs as fallback,
  no mode pre-selection. The guest web evaluates the heartbeat and, when the
  service device loses connectivity (>45 s), blocks the futile cloud submit
  and points guests to the local hub URL instead. Operator sign-in is a
  plain one-time e-mail/password login; the public sandbox connection data
  (URL, anon key, venue) is baked in. Pending: applying the migration plus
  operator account on the real instance (`SANDBOX_SETUP.md` §6.1) and the
  real web-to-iPhone acceptance.
- KL-OFFLINE-008 (merged into `main` on 19 July 2026): Bonjour discovery of
  other venue hubs in the external-hub disclosure, a lightweight service
  startup screen (navigation responds instantly, models mount on the next
  runloop turn) and async QR rendering — resolved against the unified
  Service view.
- KL-MENU-005 (implemented on `main`, 19 July 2026): the scan-to-publish
  bridge. Until now the menu scan published **only** into the local sandbox
  menu, never to the guest web. An operator can now publish a reviewed import
  draft straight into the Supabase venue from the draft-review screen; the
  guest card at `kitchenlink.luneq.eu/<slug>/menu` shows it within the ISR
  window (max 1 min). New additive migration
  `20260719200000_operator_publish_menu.sql` adds the staff-gated
  `operator_publish_menu` RPC that **fully replaces** the venue's active menu
  (no merge, mirroring `store.replaceMenu`), guarantees exactly one active
  menu and rejects duplicate `menu_items.slug` in the payload (the load-bearing
  order-gate invariant). App side: a pure, tested payload builder
  (`KitchenLinkMenuPublishPayload`, German slug generation ä→ae plus
  deterministic slug de-duplication), `KitchenLinkMenuPublishModel` (reuses a
  stored operator session or signs in with familiar credentials, exactly-once
  401 refresh) and `MenuPublishSheet` from the review flow (email/password
  only, explicit replace warning, success card with the live URL). Auth is
  shared with the order transport through the narrow
  `KitchenLinkCloudAuthenticating` protocol. `tag`/`variant_options` are not
  published yet (documented follow-up). Verified: app build green, full
  `kitchenlinkTests` target 0 failures incl. 11 new publish tests. Pending:
  apply the migration and run one real publish against the instance
  (`SANDBOX_SETUP.md` §6.2) — the RPC SQL has not run against real Postgres
  (same boundary as KL-WEB-002/KL-CLOUD-001).
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
- **Main-only mode since 19 July 2026** (`DECISIONS.md`): all agents commit
  directly to `main`; the previous branch/worktree isolation from
  `PEER_WORKFLOW.md` is superseded. All prior branch work is merged;
  remaining unique branch tips are preserved as `archive/*` tags. The user's
  Xcode working copy is `/Users/test/Developments/kitchenlink-claude`.
- Claude Code and Codex are equal technical collaborators; the user remains
  the product and design authority.
- A market/focus assessment underpinning the current priorities is recorded
  in `docs/strategy/MARKET_ASSESSMENT_2026-07-19.md`; the usability
  guardrail ("the app stays user-friendly throughout development") is a
  binding decision in `DECISIONS.md`.
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
- **Offline venue hub:** iPhone Safari can now reach the local top-level guest
  page and commit an order over the reference WLAN. The iPhone itself can host
  the page and the app-side Kitchen-to-Waiter slice; foreground WLAN loss and
  recovery sind nun auch real abgenommen. Android Chrome, AP isolation,
  automatic client discovery, background Hub lifecycle, TLS/trust and failover
  remain unproven; no production hub architecture follows from this sandbox
  result.
- **Guest web:** production-grade hosting, PWA/offline behavior and retention
  for orphaned anonymous users remain open. Hostinger is selected only for the
  current sandbox; Supabase menu loading and authoritative sandbox ordering are
  already live.
- **Cloud order loop (KL-CLOUD-001):** merged into `main`, waiting for the user
  to apply migration `20260719100000` plus the operator account
  (SANDBOX_SETUP.md §6.1) and to run the real web-to-iPhone acceptance. A guest
  status page in the web remains a follow-up.
- **Scan-to-publish (KL-MENU-005):** implemented on `main`. Waiting for the user
  to apply migration `20260719200000` and run one real publish against the
  instance (SANDBOX_SETUP.md §6.2). This is the second half of the core pitch:
  paper menu → scan → review → live guest card. Open follow-ups: publishing
  `tag`/`variant_options`, additive menu editing (currently full replace), and a
  table context in the guest web.
- **Import quality rounds (KL-SCAN-002):** after the first real scan comparison
  the user required an iterative quality workflow (categories from card titles,
  variants/sizes/descriptions, structured allergen mapping via the card legend
  with uniform icons later in the UI, and the hard rule that legend codes never
  end up in names or descriptions — targets recorded in
  `docs/test-fixtures/scanner-benchmark/QUALITY_TARGETS.md`). A batch review
  environment now exists: `scripts/run-import-review.sh` runs all fixtures
  (plus any user-supplied menus) through the real local OCR pipeline and opens
  an HTML report — original page with evidence overlays next to the parsed
  result, automatic issue flags, per-entry OK/Falsch feedback with export for
  the agent. The first run already surfaces real findings (legend codes inside
  descriptions and names, duplicated description fragments, OCR confusions).
  Parser fixes start with round 1 once the user returns the first feedback
  export.
- **Production boundary:** no live payment, fiscal activation or removal of
  sandbox labeling is approved.
