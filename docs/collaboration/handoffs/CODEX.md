# Codex Handoff

**Updated:** 15 July 2026
**Branch:** `main`
**Status:** First V2 implementation slice ready for review

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

## Risks And Open Work

- Guest branding still needs a venue-owned logo, image and accent slot with grape
  as a safe fallback.
- A local end-to-end regression test from guest order through kitchen status with
  cloud unavailable is still missing.
- The scan screen reuses the production import behavior, but camera and
  PhotosPicker error branches are not yet dependency-injected for unit tests.
- Do not treat the working logo geometry, current typefaces, exact hex values or
  status palette as final approval.
- Do not spend the Claude reserve prompt. Codex continues the design system and
  implementation from Round 04.

## Recommended Next Step

Collect focused user feedback on the V2 home and scan entry. Then implement the
offline end-to-end smoke test while Today/kitchen reference views are built in a
separate write scope. Decide the guest-web stack before starting KL-WEB-001.
