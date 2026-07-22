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
- **Hosting path (superseded for the sandbox on 18 July 2026):** The original
  plan targeted Vercel while keeping the code hosting-neutral and requiring the
  ADR-001 §8 PoC before production.
- **Current sandbox hosting (approved by deployment on 18 July 2026):** The
  public sandbox deploys from `main` to Hostinger PaaS at
  `https://kitchenlink.luneq.eu`. This settles sandbox hosting only; the code
  remains hosting-neutral and production-grade hosting stays open.
- **Anonymous identity:** Guest ordering uses Supabase Anonymous Sign-in
  (`authenticated` role with `is_anonymous` claim) combined with the
  authoritative order gate; a cleanup policy for orphaned anonymous users is
  required. The bare `anon` role is not used for order writes.
- **URL structure:** The sandbox uses path-based venue routes (`…/<venue>`).
  Per-venue subdomains and custom domains remain open product decisions to
  revisit before production.
- Still open by design: custom domains per restaurant (D3) and the PWA/offline
  shell stage (D5). The sandbox order gate currently uses the PostgreSQL RPC
  variant; a production architecture may revisit that implementation detail.

## Local Guest Ordering (approved 18 July 2026)

- **Required sandbox capability:** Guests must be able to order locally when
  the cloud connection is unavailable. Dropping local guest access in favor of
  cloud-only guest ordering is not an acceptable fallback for the Sandbox Beta.
- **Local eligibility:** The guest device must be connected to the restaurant's
  local network and must reach a locally served guest surface. KitchenLink does
  not promise local ordering to a device that can reach neither the restaurant
  network nor the cloud.
- **Authoritative acknowledgement:** The guest UI may confirm arrival only
  after at least one authoritative venue node has durably stored the order.
- **Architecture boundary:** This approves the product requirement, not a
  transport shortcut. A cloud HTTPS page must not be designed to fetch an
  untrusted local HTTP endpoint in conflict with browser security. Local page
  delivery/bootstrap, AP isolation, TLS/trust, device identity, failover and
  recovery require measured architecture proof before network implementation.
- **Sandbox boundary:** This decision activates no live payment, production
  infrastructure or certified fiscal behavior.

## Usability Guardrail (approved 19 July 2026)

- The app must stay user-friendly **throughout the entire development
  process**, not only at release. Concretely: no technical configuration
  forms inside product paths (connection data is baked in or provisioned,
  users enter at most familiar credentials), no manual mode pre-selection
  where the app can decide automatically (e.g. local vs. online service),
  and development/demo entry points stay visually separated from the
  product path (collapsed "Entwicklung & Demo" section instead of
  equal-ranking cards).
- Every UI-facing ticket is expected to check its result against this
  guardrail before integration.

## Main-Only Working Mode (approved 19 July 2026)

- All existing branch work was consolidated into `main` on 19 July 2026
  (KL-CLOUD-001 and KL-OFFLINE-008 merged; remaining branch tips preserved
  as `archive/*` tags). From now on, agents commit directly to `main` —
  no long-lived feature branches, no cross-branch handoffs.
- This supersedes the branch/worktree isolation rules in
  `PEER_WORKFLOW.md` until the user decides otherwise. Verification duties
  (tests green before push, honest handoff notes) remain unchanged.
- The user's Xcode working copy is `/Users/test/Developments/
  kitchenlink-claude` on `main`.

## Import Consolidation (approved 22 July 2026)

- The current V2 import and review flow is the only visible product path. The
  former legacy product sandbox, design switch and duplicate import review are
  retired from navigation once their useful behavior is represented in V2.
- The current review and guest preview must retain the useful legacy coverage:
  food/drink/total counters, structured allergen and additive symbols,
  descriptions, variants/options and a space-efficient quantity control.
- In guest-facing menu rows, the dish and price lead visually. Every unselected
  item uses only a compact circular plus beside the price; if choices are
  required, that plus opens the configuration. Text actions such as
  `Auswählen` do not occupy a separate row. The visual circle may be smaller
  than its accessible 44-point touch target.
- Within that row, the dish name is the strongest element, the price is clearly
  readable but secondary, and declaration icons are tertiary orientation aids.
  Plus and minus controls use their complete accessible target, not only the
  visible glyph, even when the drawn control is smaller.
- The in-app fixture picker exposes exactly three complementary cards: one
  deterministic KitchenLink full-coverage menu plus two difficult real-world
  menus. Historical benchmark fixtures remain stable and separate from this
  product-facing selection.
- This consolidates sandbox UX; it does not authorize production activation,
  live payments or removal of the remaining demo/simulation capabilities.

## Food Declaration Icons (approved 22 July 2026)

- The shared collection covers all 14 EU allergens, the relevant German
  loose-food additive statements, separate consumer notices and dynamic
  E-number declarations. Garlic and onion are not presented as standard EU
  allergens.
- Icons are compact orientation aids, not a replacement for mandatory wording.
  The compact surface contains only the semantic pictogram; source-menu letters
  and numbers are not overlaid. Guests can tap each icon to see its clear text,
  group and a short explanation, but no internal source code is shown or read
  aloud anywhere in the guest experience.
- Alcohol-containing items use a dedicated, immediately recognizable drinking-
  glass pictogram rather than the generic notice speech bubble. Polyol notices
  remain a separate additive meaning.
- A source menu's legend is authoritative for non-standard house codes.
  Historical numeric 1–14 declarations remain readable as a compatibility
  fallback, but KitchenLink does not present them as a universal legal code
  system.
- The implementation remains a sandbox aid. Operators remain responsible for
  the correct substance, threshold, exception and legally required wording.

## Complete Declaration Display (approved 22 July 2026)

- Guest-facing menu rows must show **every** food declaration of an item.
  Truncating the icon row to a fixed maximum with a `+N` overflow indicator is
  not compatible with German/EU food-labeling requirements and is not
  permitted in any guest surface (iOS guest preview, guest web).
- When space runs out, the declaration icon row wraps onto additional lines.
  Icons stay compact orientation aids per the Food Declaration Icons decision.
- The sandbox test menus (iOS demo card and guest-web fixture) must
  permanently contain at least one fully declared reference dish whose icon
  row actually wraps, so this behavior stays visible and testable.

## Quiet Declaration Row (approved 23 July 2026)

- Allergens and additives are secondary information for most guests. In the
  guest menu they must be legible but visually recessed — they should not
  compete with the dish name, price or order controls. The chosen balance:
  **must be visible, must not draw attention.**
- In guest-facing surfaces (iOS guest preview, guest web) the declarations are
  quiet, **monochrome** outline pictograms in the muted text colour — no
  coloured badges, no filled boxes, no border chips. Group colour (allergen
  vs. additive etc.) is not shown here; it appears only after the guest opens
  the detail views.
- **The pictograms sit in the flow of the description, not in their own row.**
  They trail the description text as a quiet continuation of the same
  secondary line and wrap together with it; when there is no description they
  form a short muted line under the name. A separate icon strip below the item
  is explicitly rejected as obtrusive and against the item's form (user
  feedback, 23 July 2026).
- **The whole pictogram run is one tap target** that opens a clear-text list
  of all the item's declarations, grouped, each entry leading to the full
  explanation. Individual icons are not separately tappable in guest surfaces.
  Operator-facing surfaces (draft review, manual editor) keep the coloured
  badges with per-icon tap, where group is working information.
- All declarations remain shown in full (they wrap rather than truncating);
  this decision governs their visual weight, placement and tap affordance, not
  their completeness.
- The order stepper, when an item is in the cart, occupies its own
  right-aligned line; it no longer shares a row with the declarations.

## Collaboration Governance

- **Agent parity:** Claude Code and Codex work as equal technical collaborators.
  Neither is the boss, permanent integrator or mandatory gatekeeper for the
  other's work.
- **Active agents (approved 18 July 2026):** Until the user changes this
  decision, new project work is assigned only to Claude Code and Codex. Work
  and handoffs from GLM, DeepSeek, Kimi and MiniMax remain historical context.
  The temporary exception for the already-started GLM PR #15 is fulfilled; it
  was reviewed and integrated and does not authorize further GLM work.
- **Shared integration:** `main` is a neutral shared integration branch. Every
  agent works in its own branch and worktree and may propose, implement, review
  or integrate work under the same rules.
- **User authority:** The user retains final authority over product scope,
  design approval, production activation and other product decisions. Agent
  disagreement is surfaced to the user rather than resolved by hierarchy.
