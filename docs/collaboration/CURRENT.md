# KitchenLink Current State

**Updated:** 30 July 2026
**Integration branch:** `main`
**Phase:** Integrated sandbox; guest web live, iOS domain expansion
**Release status:** Publicly reachable sandbox, not production
**Latest material integration:** The current iOS preview and guest web now use
a genuinely dish-first menu: the 20-point bold dish name leads, the 16-point
price remains clear but secondary. **Every** declaration of an item is shown —
the pictograms wrap onto additional lines instead of truncating to a `+N`
indicator, which was identified as incompatible with food-labeling
requirements and is now a recorded decision. The declarations are
deliberately quiet: small monochrome outline pictograms in the muted text
colour (no coloured badges or boxes) that sit **in the flow of the
description** — trailing the description text as a quiet continuation and
wrapping with it, not as a separate strip below the item (an own icon row was
rejected as obtrusive and against the item's form). The whole pictogram run
is a single tap target that opens a grouped clear-text list of all
declarations; group colour and detail appear only there. This balances legal
completeness against the fact that allergen info is secondary for most
guests. Every unselected item has only a small circular plus beside the
price; the stepper, once an item is in the cart, sits on its own right-aligned
line. Configurable dishes open their focused
choice sheet from that plus instead of displaying a wide `Auswählen` action;
generic `Variante`/`Option` headings remain suppressed. Declaration badges and
guest details no longer expose source-menu letter/number codes, while a
dedicated wine-glass pictogram replaces the generic alcohol speech bubble.
Every quantity minus/plus now uses a shared full-surface 44-point hit target,
including configured rows and the selection sheet. The deterministic sandbox
demo card now covers the full guest-menu scope (all declaration groups incl.
alcohol, a fully declared 11-icon reference dish, required and optional
choice groups, repeatable extras, `per_person` pricing).
The cart keeps each configuration separately and shows only the guest-facing
choice names. New V2 publish/order RPCs preserve
option groups, free-choice allowances and repeatable quantities, then calculate
one fixed price plus the remaining deltas authoritatively, with selected
options snapshotted on the order item. The preceding semantic
food-declaration collection covers all 14 EU allergens, the relevant German
loose-food additive statements, consumer notices and dynamic E numbers; every
icon remains tappable for clear text. PR #27 remains the
latest merged network slice and stabilizes
the foreground iPhone Hub across WLAN loss and local IPv4 changes.
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
- The internal build starts directly in the current V2 business home and
  scan/import flow. The legacy design switch and product-sandbox entry are
  retired; their useful import behavior now lives in the V2 path.
- The selected Working-v1 symbol and outlined wordmark are bundled as local
  light/dark vector assets recolored to grape and lemon. No runtime font or
  network dependency was added.
- Document camera, photo selection, OCR, draft review and local menu replacement
  stay on the existing sandbox-safe implementation. Import now opens the
  draft-native review directly instead of detouring through the duplicate old
  review.
- The review and guest preview show food/drink/total counts and dense menu rows.
  The dish name uses a dedicated 20-point bold role; price uses a distinct
  16-point role. Declaration visuals are 18-point monochrome outline glyphs in
  the muted text colour, embedded in the flow of the description (words and
  glyphs share one wrapping secondary line via `KitchenLinkV2WrappingRow` in
  iOS / inline glyphs in the guest web), never truncated. The whole pictogram
  run is one tap target opening a grouped clear-text list
  (`FoodDeclarationListView` in iOS, `FoodDeclarationListDialog` in the guest
  web); coloured badges with per-icon tap remain only in the operator
  review/editor. Every unselected
  row uses a small circular plus at the price; configurable dishes open a
  focused selection sheet from it and then use configured cart lines. All
  quantity buttons use their complete 44-point rectangle. Generic
  variant/option labels are omitted.
- The food-declaration catalog now distinguishes the complete 14-item EU
  allergen set from German additive statements, consumer notices and dynamic
  E numbers. Source legends take precedence over non-standard house codes;
  former numeric 1–14 codes remain read-compatible but are not presented as a
  universal legal code system. Every compact icon opens a clear-text detail in
  the iOS guest preview and guest web without exposing the internal source code.
- Badge geometry keeps each pictogram centered with no letter/number overlay;
  alcohol uses a dedicated wine-glass glyph instead of the generic notice
  speech bubble. Meaning, group and explanation remain available after a tap.
- Research scope, mapping rules, sources and the legal display boundary are
  documented in `docs/discovery/food-declarations/ICON_CATALOG_RESEARCH.md`.
- Structured price basis now survives payload mapping, draft review, human
  correction, conversion and local persistence; included `0,00 EUR` choices
  likewise remain available instead of being discarded.
- Exactly three complementary multi-page fixtures can be selected directly:
  the deterministic three-page KitchenLink Prüfküche plus the real Lichtburg
  and Alexxanders cards. The historical Scheune/Lichtburg/Alexxanders set stays
  unchanged for the 14-page gold benchmark.
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
  state are carried into the draft; the current draft review is the only
  product-facing review path.
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
  the existing local sandbox menu. The complete unit suite, targeted import UI
  smokes, the 14-page scanner benchmark and a local 17-page OCR/review run all
  pass on the consolidated implementation.
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
  `KitchenLinkCloudAuthenticating` protocol. KL-MENU-008 now publishes rich
  `variant_options` through `operator_publish_menu_v2` and submits opaque
  option IDs through `guest_web_submit_order_v2`. The database validates group
  limits, free allowances and repeatable quantities, recomputes one fixed price
  plus remaining deltas, and snapshots the selection into
  `order_items.selected_options`. Checkout attempts now remain idempotent only
  across their own retries, so identical later orders stay independent. `tag`
  remains a follow-up. Verified: app build green, full
  `kitchenlinkTests` target 0 failures incl. 11 new publish tests. Pending:
  apply the migration and run one real publish against the instance
  (`SANDBOX_SETUP.md` §6.2) — all eight migrations and V2 behavior passed in a
  temporary local PostgreSQL instance, but not yet against the public project
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

- **Inventory:** integrated; future assortment contract is a known model
  boundary, not an active ticket.
- **Offline venue hub:** real Mac-to-iPhone flow passed; foreground WLAN
  loss/recovery accepted. Remaining: background Hub, Android, TLS/trust.
- **Guest web:** Hostinger sandbox with live Supabase menu loading and
  authoritative ordering. Migration `20260722120000` (V2 configured orders)
  applied against the real instance; 8/8 integration tests green.
- **Cloud order loop (KL-CLOUD-001):** applied migration `20260719100000`;
  operator account active; real web-to-iPhone acceptance passed.
- **Scan-to-publish (KL-MENU-005):** all migrations through `20260722120000`
  applied; real publish verified with the original 8-item card restored.
- **Production hardening (23 July):** Keychain (`Security.framework`) replaces
  UserDefaults for cloud credentials and LLM API key; deterministic hash-based
  slug de-duplication; additive menu edit RPCs (`operator_upsert_menu_item`,
  `operator_delete_menu_item`) with Swift transport and tests.
- **Item availability (KL-MENU-010, 23 July):** new migration adds
  `available_from`/`available_until` columns, `operator_set_item_availability`
  RPC (staff-gated), and updates `guest_web_submit_order_v2` to reject items
  outside their time window. Swift transport + tests added.
- **Cloud-sync UI (23 July):** `MenuEditorItemEditor` now shows a
  "Cloud & Verfügbarkeit" section with per-item Upsert/Löschen buttons
  (session-gated), availability toggle, optional scheduling via DatePickers,
  and feedback messages. `MenuItemData` extended with `available`,
  `availableFrom`, `availableUntil` (backward-compatible decoder).
- **Import quality rounds (KL-SCAN-002):** rounds 1–4 documented; AI text-mode
  path (OpenCode Zen) beats rule parser. Remaining polish has diminishing
  returns.
- **Menu import launch readiness (26 July):** the Phase-1 gate now carries two
  threshold profiles (`policy.json` 1.3.0). `launch` is the release bar —
  recall-first, zero unrecoverable loss, `correctionsPerPage` as the headline
  effort metric — because every draft passes a mandatory human review. `strict`
  is retained as a diagnostic long-term target that a sampled model cannot pass
  (it requires near-exact cross-run repeatability). Both decisions are recorded
  in `DECISIONS.md`.
  A deterministic OCR fix collapses the near-duplicate readings produced by the
  intentional double Vision pass (they were becoming phantom dishes): local
  entry F1 0.592 → 0.679, invented entries 51 → 37, invented prices 50 → 34,
  P95 page latency 7145 → 3715 ms. The offline rule fallback now emits the
  review findings it can honestly derive (`expectedReviewRecall` 0.000 → 0.429)
  and declares its own semantic gap once per draft; the findings it cannot
  detect are deliberately not fabricated.
  Operators can now configure key, gateway URL and model in the app — the code
  previously forced every stored key onto OpenAI, so no other paid provider was
  configurable in a shipped build. `MenuImportGeminiProtocol` adds the
  Google-native `generateContent` translation the Zen Gemini route requires
  (`x-goog-api-key`, `thinkingBudget: 0`).
  One approved paid run with `gemini-3.5-flash` over the ten gate pages:
  corrections per page 8.50 → **1.00**, section F1 **1.000**, entry F1 0.971,
  relation F1 0.411, translations 0.902, missing/invented entries 2/2, invented
  prices 6; 81,366 input and 71,655 output tokens for 17 pages. The two
  "missing" entries are unnormalized names (`Bunter Marktsalat WI`), not losses.
  Prompt 1.0.4 addresses them plus the unstated review-code vocabulary and the
  unset currency code, but is not yet re-measured. Release still needs the three
  repeat runs. Local on-device models are ruled out as a launch path (measured:
  62 s per page on the development Mac; the operator runtime is an iPhone).
  The name normalization no longer depends on the prompt alone: the assembler
  collects the document's legend codes across *all* pages first (a legend
  usually sits on its own page) and then splits a trailing code run off an entry
  name only when the legend defines every one of its letters. That covers both
  observed shapes — the unseparated bracket run `[FI]` and the bare run
  `Bunter Marktsalat WI` — while `Pizza Familie [XL]` keeps its size even on a
  card with a legend, because `X` is not one of its codes. Without a legend
  neither new shape fires: leaving a run in the name is recoverable in review,
  inventing declarations from a size is not.
- **Menu import, deterministic repairs (28 July):** four defects that a prompt
  cannot reliably fix were moved into the assembler, where they are unit-tested
  and provider-independent. Measured over the ten gate pages with
  `gemini-3.5-flash`: corrections per page 1.80 → **1.00**, entry recall
  0.941 → **1.000**, entry F1 0.941 → **1.000**, section F1 **1.000**, category
  assignment **1.000**, names exact 0.863 → **0.971**, expected review recall
  0.571 → **0.714**, missing entries 4 → **0**, invented entries 4 → **0**,
  forbidden claims **0**, silent page losses **0**, validation errors **0**.
  1. The printed name survives when the provider splits a quantity out of it:
     the card prints `Hüftsteak(250gr)`, the provider returned `Hüftsteak` plus
     the quantity, and the gate counted that as a missing *and* an invented
     entry. The name is restored from its own OCR evidence line, the quantity
     stays recorded, and the rewrite only happens when the located line equals
     name plus exactly the recorded quantities.
  2. A price without a currency is completed from the document's own evidence —
     the codes the provider did state elsewhere, or the symbols printed on the
     card. 66 of 92 prices arrived without one. Two currencies in one document,
     or none, mean nothing is filled in.
  3. A choice the card prints no price for is `included`, not `fixed`/0 cents.
     A printed `0,00 €` stays a price.
  4. Three review codes are now derived from the finished draft instead of
     depending on the provider mentioning them: an option group without a stated
     selection rule, a bundle course offering a choice, and an unresolved legend
     code. Raised once per document and code.
  The absent-key tolerance was extended from arrays to the open classifiers
  (`basis`, `kind`, `claim`, `scope`, `mode`, `page_kind`): a single omitted
  `offers[0].basis` had discarded a whole card's semantic extraction. A page
  whose JSON does not map is now retried twice rather than once, because one
  failed page costs the entire card its semantic draft.
  The fabricated-legend filter from 27 July applied only to document-level
  declarations; it now covers section, entry, choice and component level, and
  each finding names its path. Note for the record: it fires on zero real runs —
  with the current prompt the provider no longer fabricates legends.
  `declarationF1` is **not** a stable signal: across four identical runs it
  measured 0.053, 0.210, 0.210 and 0.443. It reflects how many allergen codes
  the model happens to attach to entries, and it is the least repeatable part of
  the extraction.
  **Open, needs credit:** the OpenCode Zen balance ran out during the second of
  three repeat runs ("Insufficient balance"), so `minimumRepeatRuns 3` is still
  unmet and the numbers above rest on one clean run. Also open: `p95` page
  latency 74 s against a 60 s target, `expectedReviewRecall` 0.714 against 1.000
  (the missing code is `relationship_scope_ambiguous`, which has no honest
  structural trigger and was deliberately not faked), and an intermittent
  unparseable provider response on one dense page.
- **Free default path repaired, page salvage added (29 July):** the shipped
  keyless default had never produced a semantic extraction at all. Every page
  fell back to the local rules silently, and the only trace was "Antwort ohne
  parsebares JSON". Two causes, both verified directly against the gateway:
  the free model accepts no images (every vision request answered
  `HTTP 400 · Upstream request failed`), and it is a reasoning model that
  charges its thinking against the same output budget as the answer — a dense
  page consumed the whole 10,000-token budget and returned `content: ""` with
  `finish_reason: length`. The keyless path now runs without images, the budget
  is 32,000 tokens, and the provider's finish reason is reported instead of
  being swallowed.
  A blank visible text used to invalidate the entire draft, which cost the
  operator the whole card; it is now restored from its own OCR evidence line, or
  left visibly marked when there is no evidence to restore it from.
  **A failed page no longer discards the card** (user decision, recorded in
  `DECISIONS.md`): the pages that were extracted keep their semantic result and
  the gaps are filled from the local rules as `needsReview`, with a
  `page_filled_from_local_rules` finding per page.
  **Verified in the app, not only in the harness (29 July):** the import runs
  end to end on the simulator — pick a card, OCR, semantic pass, review screen
  with per-entry evidence. Driving it there produced the last missing root
  cause: the gateway answered after **154.6 s** while the per-page timeout was
  **150 s**, so five of six requests were cancelled by the app itself
  (`-999 cancelled`) and the whole card fell back to the local rules although
  the provider had answered correctly. The free path now gets 300 s per page,
  the paid one keeps 150 s. Measured again on the same path afterwards: zero
  self-cancellations, three responses received. The pages that answered carry
  real semantic entries with allergen declarations; the one page the provider
  answered with HTTP 500 comes from the local rules — which is exactly what the
  new page salvage is for, and before it that single error would have cost all
  three pages.
  The free path remains slow — roughly 8 minutes for a three-page card, 19
  minutes for 17 pages, and a stall in one run — which is why the paid default
  of 26 July stands unchanged.
- **Table context (KL-TABLE-001, 30 July):** a guest order now belongs to a
  **table**, not just to the venue. The dormant `tables`/`qr_tokens`/
  `table_sessions` layer from the core schema is activated by migration
  `20260730120000` — and secured: these three were the only guest-schema tables
  without Row Level Security, and `anon` could write QR tokens directly
  (reproduced locally before the fix). Now RLS is on, staff read through
  policies, every write goes through `operator_upsert_table`,
  `operator_delete_table` or `operator_rotate_table_token`.
  The table QR carries an opaque token (`qr_tokens`), not the table number:
  renaming keeps printed codes valid, rotating invalidates exactly them. The
  guest card reads `?tisch=<token>`, resolves it through
  `guest_web_resolve_table` and shows "Tisch 3 · Gastraum" in the header and
  the order sheet; the token enters the idempotency key and
  `guest_web_submit_order_v2` (one additional, defaulted parameter) attaches
  the order to the table **and** to the table's open session. First order opens
  the shared session, every further order of that table joins it (Blueprint
  §6.1). The page stays ISR-rendered — reading `searchParams` server-side would
  have cost every card its CDN cache. An unknown, expired or deactivated code
  is deliberately **rejected** rather than silently becoming a table-less
  order; that is a reversible product decision, not an approved one.
  iOS gains a `Tische` area (areas, tables, per-table QR with share/print,
  rename, deactivate, rotate) and cloud orders now carry their table into
  `Service` and `Heute`.
  New: `scripts/verify-supabase-migrations.sh` runs all twelve migrations plus
  SQL assertions against a throwaway local PostgreSQL — the first time this
  project's RPC SQL was executed before the user applied it to the real
  instance. It immediately found two real defects.
  **Applied** on the real instance (31 July). Open: one order through a table
  QR on a real device (`SANDBOX_SETUP.md` §6.3).
- **Waiter-entered orders (KL-TABLE-002, 31 July):** the Local-First decision
  of 23 July made "guests order verbally, the waiter enters it on the service
  iPhone" the offline path of the sandbox beta — and the product had no such
  path: `Service` only advanced statuses, order entry lived in the retired
  legacy checkout, and `operator_create_order` was unused. `Service` now has
  **„Bestellung aufnehmen"**: channel, table, the venue's own card, a kitchen
  note. The order is committed to the local event log **first**, confirmed
  only then, and pushed to the cloud afterwards — the waiter sees explicitly
  whether the cloud already has it. Migration `20260730160000` gives
  `operator_create_order` a table, attaches it to the table's open session
  (shared with the guests' orders) and **fixes a real idempotency defect**: the
  previous version kept the order unique on replay but inserted its *items*
  again, so any outbox retry produced doubled lines and a wrong total.
  Driving it in the simulator surfaced two more defects, both fixed: the local
  order list filtered on `preparing` while a waiter order starts `pending` (it
  was invisible), and the merge did not deduplicate by id (after cloud sync the
  same order would have sat on the pass twice). Order cards now lead with the
  table.
  **Applied** on the real instance (31 July). Open: one real waiter order
  (`SANDBOX_SETUP.md` §6.3/§6.4).
- **Bill, tip and simulated payment (KL-PAY-001, 31 July):** Milestone 1 is
  closed — the shared table session now has a bill. Multiple payments, multiple
  methods (cash, card, Tap to Pay, voucher), splitting **by items** (which is
  what "getrennt zahlen" means at a German table), tip per payment, refund.
  **No sandbox payment moves real money.**
  The amount never comes from the device: with items selected the database
  computes it from their line totals and rejects a differing claim. The
  load-bearing invariant is an index, not app logic —
  `payment_items_one_open_payment_per_item` means two devices cashing the same
  table cannot bill the same course twice; the loser gets a clean refusal.
  Every payment carries an idempotency key that survives a session refresh, so
  a retry never books twice. A refund keeps the payment as `refunded` (audited,
  §8.2), frees its items and reopens the bill — unless new guests are already
  seated at that table. `KitchenLinkPaymentProviding` is the §8.2 seam: card
  and Tap to Pay run through the simulated provider, a declined authorization
  produces no booking, and card data never reaches the app.
  Deliberately not included: operating shift and day close (§8.3), guest-web
  online payment, voucher/balance accounts, payment on delivery, fiscalization
  and receipt printing.
  **Applied** on the real instance (31 July). Open: one real split payment
  (`SANDBOX_SETUP.md` §6.5).
- **Stations and acceptance rule (KL-STATION-001 / KL-ORDER-001, 31 July):**
  the last two open points of Milestone 1. `Service` now has `Küche | Bar |
  Kellner`: each station sees only its own lines and releases only its own, and
  an order becomes `ready` only when no station is still open — decided by
  `operator_mark_station_ready` in the database, not by the app. The card names
  the station that is still working (Blueprint §7). The station follows
  `kind` (food → kitchen, drink → bar) but is stored as its own column, so a
  later per-item assignment changes nothing structural.
  `venues.order_confirmation_channels` carries the channels that need
  confirmation; empty stays the documented default "automatically accepted".
  Affected orders reach the station only after `accepted` and wait in their own
  list with accept/reject. `rejected` was missing from the database status model
  although Blueprint §6.4 lists it — it exists now, with reason and timestamp,
  and only before acceptance (afterwards cancelling is the right move).
  Deliberate boundary: station state lives in the cloud; purely local orders
  (offline, one device) keep the whole-order bump, because station separation
  solves a multi-device problem. The order read path falls back to the old
  column list when `order_items.ready_at` is missing, so a venue that updated
  the app but not yet the database still sees its orders.
  **Applied** on the real instance (31 July). Open: one real run across two
  stations (`SANDBOX_SETUP.md` §6.6).
- **Own restaurant, and with it Milestone 1 (KL-ONBOARD-001, 31 July):** the
  core pitch used to end where it should start — every scan went into the one
  bundled demo venue, and a second restaurant needed hand-written SQL. An
  operator can now create an account and their own restaurant in the app
  (`operator_create_venue` makes the creator staff of it and seeds an empty
  active menu; an anonymous guest explicitly cannot). The name comes from the
  operator, the guest address follows from it — nobody invents a URL, and a
  taken slug moves to a free variant instead of failing.
  The load-bearing change is small and reaches everywhere:
  `KitchenLinkCloudConfig.sandboxDefault` is no longer a constant but follows
  the **active venue**. Instance and anon key stay baked in (the sandbox has one
  instance), the venue does not. Scan-publish, tables, orders, stations and the
  bill therefore work on the operator's own restaurant without further change —
  every one of those RPCs already gates on `is_venue_staff`.
  Verified against real PostgreSQL as a whole path in a fresh venue: create,
  publish a menu, add a table, guest orders through the table QR, operator reads
  the bill. Sandbox limit of five restaurants per account, against accidental
  mass creation.
  **Applied** on the real instance (31 July). Open: creating one real
  restaurant (`SANDBOX_SETUP.md` §6.7).
  **With this, Milestone 1 (`Scan bis Bezahlung`) is complete**: scan → review →
  live guest menu → table QR → guest and waiter orders → acceptance rule →
  kitchen and bar stations → served → split bill, tip and simulated payment.
- **Operating shift and cash close (KL-SHIFT-001, 31 July):** the first slice of
  Milestone 2 (Blueprint §8.3). Milestone 1 opened the money loop but never
  closed it — money was taken, refunded and tipped, and at the end of the day
  there was nothing to count against. A venue now opens one shared shift that
  every device works on, with an optional opening float, collected movements
  (payouts, expenses, deposits) and a close that records a counted amount, the
  expected amount and the difference between them.
  The load-bearing invariant is again an index, not a rule in the app: **at most
  one open shift per venue.** Two open tills cannot be counted.
  Two deliberate choices. A **payment** without an open shift is not blocked —
  taking money must never fail on a forgotten button — it just carries no
  shift and shows up in the report as "outside the shift" instead of vanishing
  silently. A **cash movement** does require an open till, because it is the
  booking *onto* the shift. And the variance is recorded, never prevented: a
  close that hides a difference is worthless.
  `payments.shift_id` is set by a `before insert` trigger rather than by
  changing `operator_record_payment`, so the assignment also covers every later
  payment path (guest-web online payment, counter, delivery) without anyone
  having to remember it.
  Verified against real PostgreSQL (second open shift rejected, card does not
  count into the drawer, cash tips do, a refund lowers it again, a closed shift
  stays frozen, Z numbers gapless, RLS proven with `set role`), 462 iOS unit
  tests green, and a simulator run through open, book an expense, close both
  with and without a variance. Migration applied to the instance and verified.
  **Open:** one real trading day on a device (`SANDBOX_SETUP.md` §6.8).
- **Roles and permissions (KL-ROLE-001, 31 July):** Blueprint §9.1. Until now
  **whoever was signed in could do everything** — `is_venue_staff` checks
  membership, not authority, so any service hand could close the till, refund a
  payment and take cash out of the drawer.
  The scoping was the real decision. There are 25 `operator_` RPCs; replacing
  them all would have been a maintenance nightmare, and most of them *should*
  stay open to every staff member (the kitchen needs `mark_station_ready`, the
  service needs `record_payment`). So this slice introduces exactly **five**
  permissions and enforces **all five**: `shift.open`, `shift.close`,
  `cash.movement`, `payments.refund`, `staff.manage`. No permission is listed
  that isn't checked somewhere — a role with an empty permission set means "may
  do everything ordinary, nothing sensitive". Configuration rights (publish a
  menu, change tables) are their own slice and will arrive together with their
  enforcement, not before it.
  Roles live **per venue** in `venue_roles` with the nine standard roles from
  §9.1, so "custom roles with granular rights" later is one more row, not a
  rebuild. `venue_staff.role` had a CHECK pinned to the single value
  `'operator'`; it is now a foreign key.
  Existing staff lose nothing — `operator` becomes `owner`. Anything else would
  be a silent disenfranchisement by migration. The column default for *new* rows
  is `service`: least privilege.
  Three locks keep a venue from becoming leaderless: nobody changes or removes
  their own access, only an owner may touch an owner, and the last owner stays
  owner.
  In the app: a new **Team** area, and the till now locks close and cash
  movement and **explains** why instead of running into a server error.
  Verified against real PostgreSQL in its own test venue, 483 iOS unit tests,
  13 UI tests, a simulator run with a role change. Migration applied and
  verified on the instance.
  **Open:** one real run with a second account (`SANDBOX_SETUP.md` §6.9).
- **Time tracking (KL-TIME-001, 1 August):** Blueprint §9.3, and the first time
  the workforce domain from 17 July does anything. It had 1850 lines of code and
  tests with **zero references** from the app; what it lacked was persistence
  and a screen. This slice supplies both for the clock.
  Blueprint §9 keeps three objects apart and this keeps them apart: the
  operating shift (`business_shifts`, "the till is open"), the planned shift
  (not persisted yet) and the time entry ("this person worked"). A time entry
  therefore explicitly does **not** hang off an operating shift — someone
  prepping the kitchen at 3pm is working even though the till is still closed.
  Load-bearing invariants are indexes again: **nobody is on the clock twice at
  once**, and at most one break runs per entry. Breaks subtract from working
  time, and a running break is counted up to now so the display doesn't keep
  ticking. A night shift belongs to the day it **started**.
  Clocking yourself needs **no** permission — the kitchen has to get on the
  clock without asking anyone. Seeing and correcting other people's time
  requires `staff.manage`; deliberately **no sixth permission**, since one that
  acts in a single place is a line in every role list without a gain.
  Corrections carry a reason and **keep the original**: `original_started_at`
  and `original_ended_at` survive, and a second correction does not overwrite
  them. Without that path a forgotten clock-out would stay open forever — and
  the person could never get back on the clock, because the index forbids it.
  The screen therefore flags entries open for over twelve hours.
  Verified against real PostgreSQL in its own test venue, 526 iOS unit tests on
  the merged tree, a simulator run through clock-in, break and correcting a
  forgotten clock-out. Migration applied and verified on the instance.
  Integrating this with the parallel manager-PIN line surfaced a real defect:
  both SQL tests claimed the same account UUIDs for different emails, and since
  every test runs against **one** database in sequence, `on conflict do nothing`
  silently dropped the later test's accounts. The taken UUID ranges are now
  documented in the harness header.
  **Open:** one real trading day on a device (`SANDBOX_SETUP.md` §6.11).
- **Manager PIN (KL-ROLE-002, 31 July):** the other half of Blueprint §9.1,
  which asks for sensitive actions "by special permission **or** manager PIN".
  KL-ROLE-001 built only the permission — so a service hand who had to refund a
  payment at the table had to go and fetch the manager. Now a lead authorises
  **one** action on the spot, and nobody signs out and back in.
  **The PIN belongs to a person, not to the venue.** That is the load-bearing
  decision and it follows from §8.2: a shared house PIN cannot answer "who
  authorised this?" — it only proves someone in the building knew it. So every
  lead sets their own, and the grant carries their name. What a PIN may
  authorise follows from the same rule: exactly what its holder could do
  themselves. Demote a lead and their PIN stops working the same second,
  without anyone deleting it.
  **Four of the five permissions are overridable, `staff.manage` is not.**
  Someone who could manage staff on a borrowed PIN would make themselves an
  owner in the same minute — that is not an authorisation for one action but a
  permanent escalation.
  A grant is single-use, five minutes, one venue, one permission, one requester,
  and it is claimed in the same statement that checks it, so two devices cannot
  both win. The PIN is stored as a bcrypt hash (`extensions.crypt`), five wrong
  attempts lock the **requesting device** (not the venue — a wrong PIN belongs
  to nobody), and two people sharing a PIN authorise nothing rather than
  producing an unattributable grant. `manager_pins`,
  `manager_pin_attempts` and `manager_overrides` carry RLS with **no policy**
  and no grants: no client ever reads a row; the audit is read through
  `operator_recent_overrides`, which never hands out the token hash.
  In the app: a shared authorisation sheet used by both the till and the check,
  own-PIN management and the grant log under `Team`. The four money RPCs each
  gained one defaulted `p_override_token` parameter (drop + create in the same
  transaction, as with `guest_web_submit_order_v2`); callers without a grant are
  unchanged.
  New launch argument `--kitchenlink-demo-service-role`: the demo account owns
  its venue and may do everything, so the *locked* state from KL-ROLE-001 — and
  with it the PIN — could not be shown at all. It can now, in the simulator and
  in a UI test.
  Verified against real PostgreSQL in its own test venue (17 checked sections incl.
  single use, wrong action, wrong requester, expiry, demoted grantor, lockout,
  ambiguity, `staff.manage` refused, RLS), 512 iOS unit tests, 10 UI tests, and
  a simulator run through both flows. Migration applied and verified on the
  instance.
  **Open:** one real run with a second account (`SANDBOX_SETUP.md` §6.10).
- **Shift schedule (KL-PLAN-001, 1 August):** Blueprint §9.2, the counterpart to
  the clock. KL-TIME-001 recorded who **actually** worked; this records who is
  **supposed to**. Without it the target/actual comparison of §9.3 has nothing
  to compare against.
  The lifecycle is not reinvented — it follows the domain tested since
  KL-WORKFORCE-001 (`WorkforceShiftLifecycle.swift`): draft → published →
  accepted or declined. `swap_requested` is deliberately absent: swaps are their
  own slice, and a status nothing can reach is ballast.
  The load-bearing promise is an **exclusion constraint** (`btree_gist`): nobody
  is scheduled twice at once. A declined shift stops blocking — it is no longer
  an assignment, only its history. A **draft is invisible to the person
  assigned**, which is the whole point of the split: planning must be able to
  reshuffle the week without someone thinking they are rostered at every
  intermediate state. Moving an already **accepted** shift drops it back to
  published, because otherwise "accepted" would sit on a time nobody ever saw.
  A sixth permission, `schedule.manage`, checked on every planning RPC and held
  by owner, manager and shift lead — planning is a different responsibility from
  staff administration. Deliberately **not** PIN-overridable: the PIN is for the
  handover at the table. Answering your own shift needs no permission at all.
  Verified against real PostgreSQL in its own test venue, 550 iOS unit tests, 14
  UI tests, a simulator run through publishing and a rejected double booking.
  Migration applied and verified on the instance.
  Three findings on the way: a **count** of permissions broke in both the SQL and
  the Swift test as soon as a sixth arrived — both now assert what a role
  **excludes** instead of how many rights it carries. The demo team transport
  did not know the new permission and silently hid the week view although it is
  supposed to mirror the database. And the overlap rejection was **invisible**:
  the notice sat on the screen behind the editor sheet.
  **Open:** one real run with a second account (`SANDBOX_SETUP.md` §6.12).
- **Absences (KL-LEAVE-001, 1 August):** Blueprint §9.2, "holiday and sick
  leave". KL-PLAN-001 had left a gap that shows up on day one: **someone on
  holiday could still be rostered.**
  The load-bearing decision is an asymmetry, and it follows from the trade, not
  from the technology. Planning **into** an approved absence is **refused** —
  the planner is doing something demonstrably wrong. Approving an absence that
  falls on **already planned** shifts is **allowed** and merely reports them: a
  sick note arrives after the roster, not before it. Whoever is ill is ill; the
  approval must not fail on that. The shifts are not cancelled automatically —
  who re-staffs them is the planner's call.
  A **request** blocks nothing; only approval holds the period. Two approved
  absences for one person cannot overlap (exclusion constraint), requests may —
  otherwise a period could never be re-planned. Requesting needs no permission,
  deciding needs `schedule.manage`: no seventh permission, because it is the
  same job as planning.
  One finding that could have been expensive: the model gained the leave
  transport as a dependency — with the usual **network default**. The schedule
  tests did not pass it through, so 48 unit tests suddenly called the real
  instance and went red with nothing wrong in them, and the failure output said
  nothing (`failed (0.000 seconds)`, no message).
  **Open:** one real run with a second account (`SANDBOX_SETUP.md` §6.13).
- **Target headcount (KL-STAFFING-001, 1 August):** Blueprint §9.2. The roster
  shows **who** is scheduled; the question a planner actually has looking at the
  week is **is that enough?**
  The requirement is a **weekly pattern** — weekday, time window, headcount,
  optional station — because that is how staffing needs are ("Friday evening,
  three"). Nobody re-enters the same thing every week.
  Coverage is computed **in the database**: only it knows the plan every device
  shares, and only it resolves the window correctly in the venue's timezone.
  People are counted, only overlapping shifts, a **declined** shift does not
  count and a **draft** does.
  **Understaffing warns, it does not block.** A week can be published
  understaffed — sometimes there simply is nobody, and a roster you cannot hand
  out helps no one. Same stance as closing the till with open bills.
  Overstaffing is not a message at all.
  The DST test earned its keep on the first run: `generate_series` with `date`
  arguments returns **timestamptz**, and on that `at time zone` reverses
  direction — it converts *out of* the zone instead of into it. The window
  slipped by an hour at both transitions, which in a real business shows up
  exactly twice a year and is expensive when it does. Second finding: the demo
  path built **two separate** transports for plan and coverage, so the week view
  would have counted a different roster than it displays.
  **Open:** one real week on a device (`SANDBOX_SETUP.md` §6.14).
- **Target vs. actual evaluation and overtime (KL-WORKFORCE-EVAL-001, October 2026):**
  Blueprint §9.3. Links planned shift hours (`KitchenLinkPlannedShift`) with
  tracked time entries (`KitchenLinkTimeTotals`). Calculates employee and team
  target hours, actual net hours, overtime/undertime balances, and checks statutory
  German break compliance under § 4 ArbZG (30 min for >6h, 45 min for >9h).
  Accessible for managers via `KitchenLinkV2WorkforceEvaluationSheet` in the schedule view.
- **Guest Web Dark Mode (KL-WEB-005, October 2026 / Issue #38):**
  Theme store with localStorage persistence, anti-FOUC script, semantic dark CSS tokens,
  and accessible theme toggle in header.
- **Simulated Wallet Checkout (KL-WEB-006, October 2026 / Issue #40):**
  `WalletPayButton` and animated `WalletPaymentSheet` with haptic feedback simulation
  and direct submission into the authoritative order RPC.
- **RFC 4180 CSV Export (KL-OPS-002, October 2026 / Issue #39):**
  `KitchenLinkCSVExporter` for closed orders and shift close totals with UTF-8 BOM
  for Excel compatibility and standard iOS `ShareLink` toolbar integration.
- **Table reservations and operator seating (KL-RES-001, October 2026):**
  Blueprint §10 (Milestone 3: Reservierung und Omnichannel).
  1. Additive database migration `20261023120000_table_reservations.sql` creating `table_reservations`
     with RLS, `guest_web_create_reservation` RPC generating 6-digit confirmation codes (`KL-XXXXXX`),
     and staff RPCs `operator_list_reservations` and `operator_update_reservation_status`.
  2. Guest-Web reservation domain (`guest-web/src/lib/reservation.ts`), validation rules,
     simulated & Supabase backends, and full interactive UI (`ReservationForm.tsx` & `/[venueSlug]/reserve/page.tsx`).
     Connected with header link on menu page. 12 new unit tests.
  3. iOS reservation domain (`KitchenLinkReservationModel.swift`) with live status transitions
     (`confirmed` -> `seated` -> `completed` / `no_show` / `cancelled`), table assignment, and phone
     reservation creation (`KitchenLinkNewReservationSheet`). Integrated into `KitchenLinkV2BusinessHomeView.swift`.
     7 new Swift unit tests.
- **Walk-ins, waitlist and seating turnover (KL-RES-002, October 2026):**
  Blueprint §10 (Warteliste, Walk-ins, Aufenthaltsdauer und Folgebelegung).
  1. Additive database migration `20261023140000_waitlist_walkins.sql` creating `table_waitlist_entries`
     with RLS, staff RPCs `operator_add_waitlist_entry`, `operator_list_waitlist`, and `operator_update_waitlist_status`.
  2. Swift waitlist domain (`KitchenLinkWaitlistModel.swift`): `KitchenLinkWaitlistStatus` (`waiting`, `notified`,
     `seated`, `cancelled`), elapsed wait time tracking, overdue flagging, and `KitchenLinkSeatingTurnoverHelper`
     (90-minute standard seating duration projection).
  3. Integrated into `KitchenLinkV2ReservationsView.swift` with tab navigation between reservations and live waitlist,
     `KitchenLinkNewWaitlistSheet` for staff entry of walk-ins, and direct seating/notification actions.
  4. 7 new Swift unit tests in `KitchenLinkWaitlistTests.swift`.
- **Interactive floor plan, occupancy status and table transfer (KL-TABLE-003, October 2026):**
  Blueprint §10 (grafischer Tischplan, Raumstatus, Tisch umsetzen und zusammenlegen).
  1. Additive database migration `20261023160000_table_floorplan.sql` adding `seats`, `shape`, `pos_x`, `pos_y`
     to `tables`, plus staff RPCs `operator_get_floorplan_status`, `operator_transfer_table_session` (transferring
     open session and orders from table A to B) and `operator_merge_tables` (merging sessions).
  2. Swift floor plan domain (`KitchenLinkFloorPlanModel.swift`): `KitchenLinkFloorPlanOccupancy` (`free`, `occupied`,
     `reserved`, `inactive`), `KitchenLinkFloorPlanTable`, `KitchenLinkFloorPlanProviding` protocol, and demo actor provider.
  3. Interactive SwiftUI view [`KitchenLinkV2FloorPlanView.swift`](file:///Users/test/Developments/kitchenlink-claude/kitchenlink/Features/Tables/KitchenLinkV2FloorPlanView.swift)
     with area filters, status color-coded cards, detail sheet, table transfer sheet, and table merge sheet.
     Integrated via toolbar action in `KitchenLinkV2TablesView.swift`.
  4. 4 new Swift unit tests in `KitchenLinkFloorPlanTests.swift`.
- **Take-away and scheduled pickup orders in guest-web (KL-OMNI-001, October 2026):**
  Blueprint §10 & §6.2 (Abholung, Zeitfenster, Omnichannel).
  1. Extended `guest-web/src/components/GuestMenuCard.tsx` with service mode selection
     (`🍽️ Im Restaurant` vs `🛍️ Zur Abholung`) and pickup scheduling slots ("sofort (~20 Min.)",
     "+30 Min.", "+45 Min.", "+60 Min."), guest contact name and phone intake.
  2. Enforced backend table constraint (`tableToken: null` for pickup orders) while preserving
     customer pickup note and timestamp in `submitOrder`.
  3. Added responsive UI feedback in order summary sheet, wallet payment sheet, and post-order
     confirmation banner specifically tailored for take-away pickup.
  4. Added comprehensive unit tests in `guest-web/__tests__/order-submit.test.ts`.
- **In-house delivery, driver dispatch & tour management (KL-DELIVERY-001, October 2026):**
  Blueprint §12 & §6.2 (Meilenstein 3: Eigener Lieferbetrieb, Fahrerzuweisung, Tourenstatus).
  1. Additive database migration `20261023180000_delivery_orders.sql` adding `delivery_areas` table
     with postal codes, minimum order requirements, and delivery fees. Added delivery attributes to
     `orders` (recipient name, phone, address, status, driver reference, dispatch/delivery timestamps,
     payment method on delivery). Added staff RPCs `operator_list_deliveries`, `operator_assign_delivery_driver`,
     `operator_update_delivery_status`, and `operator_upsert_delivery_area`.
  2. Swift delivery domain (`KitchenLinkDeliveryModel.swift`): `KitchenLinkDeliveryStatus` (`pending`, `assigned`,
     `out_for_delivery`, `delivered`, `failed`), `KitchenLinkDeliveryAddress` with single-line formatting
     and Apple Maps deep-linking, `KitchenLinkDeliveryOrder`, and `KitchenLinkDeliveryDemoProvider` actor.
  3. Interactive SwiftUI operator view [`KitchenLinkV2DeliveryView.swift`](file:///Users/test/Developments/kitchenlink-claude/kitchenlink/Features/Delivery/KitchenLinkV2DeliveryView.swift)
     with tabs for ready/assigned, in-transit, and completed deliveries, active driver summary, driver dispatch
     sheet, failure reporting sheet, delivery area conditions sheet, and direct map navigation.
     Integrated into `KitchenLinkV2BusinessHomeView.swift`.
  4. 7 new Swift unit tests in `KitchenLinkDeliveryTests.swift`.
- **Milestone 2 remainder:** availability, shift templates and recurrence,
  notification, swap requests (§9.2) — the domain models them, persistence does
  not. Also open from §9.1: custom roles, qualifications, staff profiles and
  permissions across several locations.
- **Production boundary:** no live payment, fiscal activation or removal of
  sandbox labeling is approved.
