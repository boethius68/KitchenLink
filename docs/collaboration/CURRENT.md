# KitchenLink Current State

**Updated:** 28 July 2026
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
- **Production boundary:** no live payment, fiscal activation or removal of
  sandbox labeling is approved.
