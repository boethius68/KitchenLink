# Codex Handoff

**Updated:** 16 July 2026
**Branch:** `main`
**Status:** Scanner-to-draft adapter complete; peer workflow corrected

## Completed

- Consolidated product planning into `docs/PRODUCT_BLUEPRINT.md`.
- Documented the rejected initial design direction and Claude Design workflow.
- Imported and reviewed Claude Design Round 01.
- Recommended `Blende` as the brand base, with only `Takt` status semantics carried
  over as a functional subsystem.
- Added the shared agent protocol and normalized design export workflow.
- Registered the official Claude Design MCP endpoint for Claude Code; interactive
  `/design-login` authentication remains for the user.
- Recovered and archived the pre-Claude logo exploration, including the rounded
  wordmark that the user currently prefers.
- Reconstructed the preferred gastronomy refinement as a portable SVG working
  set with color, monochrome, reverse, app-icon and 16-24 px checks under
  `docs/design/codex-logo/working-v1/`.
- Imported the current Claude Design export as Round 02, visually compared both
  Zitrus role distributions and recorded the user's selection of 4a `Ruhe`.
- Defined a constrained Turn 5 prompt that keeps the logo and 4a direction fixed,
  removes semantic overuse of lemon and hardens contrast plus interaction states.
- Imported Turn 5 as Claude Design Round 03 and visually reviewed its token,
  interaction, status and four-application boards.
- Verified that the exported lockup and app icon are canonically identical to the
  repository SVGs and independently recalculated the displayed contrast pairs.
- Prepared one quota-conscious final Turn 6 prompt combining status semantics,
  non-text contrast, control borders, typography proof and four realistic screens.
- Imported Turn 6 as Claude Design Round 04 and verified the status, contour,
  typography and four-screen boards.
- Decided not to spend the reserve Claude prompt; remaining corrections are small
  and are now owned by Codex.
- Added `docs/design/DESIGN_SYSTEM.md` as the platform-neutral source for tokens,
  status semantics, typography, geometry, motion and implementation boundaries.
- Added an isolated V2 SwiftUI layer with adaptive `Ruhe` tokens, separate
  operation/urgency semantics, accessible status glyphs, typography fallbacks,
  surfaces and 44-point controls.
- Added a switchable V2 business home and scan/import presentation while keeping
  the previous root and complete local product sandbox reachable.
- Reused the existing document camera, PhotosPicker, OCR, review and local menu
  replacement logic rather than cloning functional paths.
- Bundled the preferred outlined Working-v1 lockup and symbol as local adaptive
  assets recolored to grape/lemon.
- Added a model-neutral work queue with exclusive write scopes for later Codex,
  GLM, DeepSeek or Claude Code workers.
- Added three bundled real-menu fixtures and a reproducible 14-page local Vision
  benchmark while keeping camera, photo and sandbox demo paths available.
- Integrated the useful lossless principles from the GLM research and DeepSeek
  red-team review without adopting their inconsistent taxonomy as product truth.
- Added provider-neutral `MenuImportDraft` contract version `0.1.0` with typed
  optional prices, evidence, hierarchy, declarations and recursive validation.
- Added `MenuImportDraftAdapter` and changed the local scanner service to produce
  legacy sections and a draft from one OCR pass. The primary scanner view keeps
  the draft in memory while the old review/application path remains unchanged.
- Preserved price-less pending OCR blocks as `needsReview` entries with source
  page and bounding box rather than deleting them or copying neighboring prices.
- Extended the benchmark with page-aware draft name/price recall and explicit
  assertions for the two Lichtburg OCR-price losses plus `Gemischter Eisbecher`.
- Replaced the accidental Codex-gatekeeper workflow with a user-approved peer
  model: Claude Code and Codex have identical technical authority, `main` is
  neutral and the user remains the product and design authority.

## Files To Read

- `docs/design/claude-design/round-01/REVIEW.md`
- `docs/design/claude-design/round-02/REVIEW.md`
- `docs/design/claude-design/round-03/REVIEW.md`
- `docs/design/claude-design/round-04/REVIEW.md`
- `docs/design/DESIGN_SYSTEM.md`
- `docs/design/codex-logo/round-01/REVIEW.md`
- `docs/design/codex-logo/working-v1/README.md`
- `docs/design/CLAUDE_DESIGN_WORKFLOW.md`
- `docs/PRODUCT_BLUEPRINT.md`
- `docs/collaboration/CURRENT.md`

## Verification

- Rendered and visually inspected all three Round 01 territories, including Scan,
  Today, guest menu and stress states.
- Rendered and visually inspected Turn 4a and 4b from Round 02 at the same scale.
- Independently checked the central 4a WCAG contrast pairs from their hex values.
- Rendered Turn 5 and checked all displayed text-status pairs plus the underlying
  status-symbol and border contrasts.
- Canonicalized and compared the exported `kitchenlink-lockup.svg` and
  `kitchenlink-app-icon.svg` against the repository assets.
- Rendered Turn 6 at full board width, recalculated its semantic symbol, control
  border and focus contrasts, and reverified canonical logo assets.
- Checked collaboration documents with `git diff --check`.
- Validated the Claude Design import script against the current Round 01 ZIP.
- Ran the complete Xcode test suite on iPhone 17 Pro simulator. Domain,
  repository, launch, UI-flow and launch-performance tests passed. Xcode emitted
  local LLDB version warnings, but `xcodebuild` completed with exit code 0.
- Rebuilt the V2 app and ran 17 unit tests plus focused V2/Legacy UI tests on the
  iPhone 17 Pro simulator.
- Visually inspected the V2 home in light mode, dark mode and the maximum
  accessibility Dynamic Type category. Corrected the wordmark asset rendering,
  dark surface hierarchy and accessibility-size header layout found during QA.
- Ran the focused draft-adapter tests on iPhone 17 Pro Simulator; raw price,
  bounding box, optional price and delta semantics passed.
- Ran the complete 14-page scanner benchmark after the adapter integration. All
  legacy thresholds still pass; draft item-name recall is 100% for all three
  fixtures and both Lichtburg price losses remain explicitly unpriced.
- Validated every generated fixture draft with `MenuImportDraftValidator` and
  checked the working tree with `git diff --check`.

## Risks And Open Work

- Guest branding still needs a venue-owned logo, image and accent slot with grape
  as a safe fallback.
- A local end-to-end regression test from guest order through kitchen status with
  cloud unavailable is still missing.
- The scan screen reuses the production import behavior, but camera and
  PhotosPicker error branches are not yet dependency-injected for unit tests.
- The draft intentionally over-captures uncertain title blocks: seven unpriced
  Lichtburg candidates and two Alexxanders candidates need human structural
  classification. They must not be auto-published.
- The existing sandbox review still renders `[MenuSectionData]`; draft evidence,
  missing-price entries and original page crops are not visible there yet.
- Do not treat the working logo geometry, current typefaces, exact hex values or
  status palette as final approval.
- Claude Code may independently audit and continue the Round-04 implementation
  under the shared peer workflow; Codex approval is not required.

## Recommended Next Step

Implement KL-MENU-004 as a draft-native review slice with original evidence,
optional price and explicit accept/edit/reject actions, followed by an explicit
conversion into the existing sandbox menu. Keep the offline smoke test and
Today/kitchen reference views in separate write scopes.
