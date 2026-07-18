# Codex Handoff

**Updated:** 18 July 2026
**Branch:** `codex/review-pr15` (Review-Fixes fuer PR #15)
**Status:** PR #15 technisch und visuell abgenommen; Merge-Blocker im
Bestandsbild behoben

## Latest Continuation (18. Juli 2026, PR #15 Review)

- PR #15 (`KL-INVENTORY-002`) gegen die Inventory-Domain, den aktuellen
  Designvertrag und die echte Simulatoransicht geprueft.
- Der erste Screenshot zeigte einen fachlichen Merge-Blocker: Die vollstaendige
  Zutaten-mal-Lagerorte-Projektion meldete nicht gefuehrte Artikel als Bestand
  `0` und erzeugte dadurch falsche Warnungen, etwa Wein in der Kueche. Die
  Operator-Ansicht zeigt jetzt nur Paare mit Ledger-Aktivitaet. Ein einmal auf
  `0` gefallener, zuvor gefuehrter Artikel bleibt sichtbar.
- Pflichtinformationen werden nicht mehr abgeschnitten. Physisch, reserviert
  und verfuegbar sind explizit sichtbar; Minimum/Ziel bzw. der kritische
  Buchungshinweis bleiben in Klartext erhalten. Header und Zahlenblock stapeln
  sich bei Accessibility-Dynamic-Type-Groessen.
- Den im Dunkelmodus unsichtbaren Text des primaeren Demo-Buttons durch eine
  robuste explizite Symbol-Text-Komposition korrigiert.
- Die Sandbox-Bezeichnung `Kueche` auf `Küche` korrigiert und die
  Projektionsabdeckung auf 13 Tests erweitert, einschliesslich eines Guards
  gegen lagerortuebergreifende Fehlalarme.

## Verification (PR #15 Review)

- Alle 13 `KitchenLinkV2InventoryStockProjectionTests`: **bestanden**.
- Vollstaendiges `kitchenlinkTests`-Target: **bestanden**; der absichtlich
  gegatete OCR-Benchmark wurde uebersprungen.
- Screenshot-UI-Test im Hell- und Dunkelmodus: **bestanden**; beide
  Bestandsansichten visuell geprueft.
- Der erste komplette UI-Lauf hatte nach einem vom Simulator abgewiesenen
  XCTest-Runner-Start drei Navigationsfehler. Genau diese drei Tests wurden auf
  einem frischen Lauf wiederholt und sind **alle bestanden**.
- `git diff --check`: keine Whitespace-Fehler.

## Remaining Risk (PR #15 Review)

- Bis ein eigener lagerortspezifischer Sortimentsvertrag existiert, dient
  Ledger-Aktivitaet als konservativer Sichtbarkeitsnachweis. Das verhindert
  Fehlalarme, kann aber einen neu geplanten Artikel ohne erste Buchung noch
  nicht als `0` anzeigen. Die Domain-Projektion selbst bleibt unveraendert.
- Die Ansicht bleibt bewusst read-only und sandbox-lokal; keine produktive
  Persistenz oder Bestellautomatik wurde aktiviert.

## Latest Continuation (17. Juli 2026)

- Vollstaendiger Status-Check des Projekts gegen die echten Branches, Worktrees
  und gemergten PRs. Die Doku (`CURRENT.md`, `WORK_QUEUE.md`) wies signifikante
  Luecken auf: PR #4 war nicht erwähnt, vier Round-2-Missionsbranches waren als
  „in Arbeit" statt als „implementiert, nicht integriert" markiert, und
  `KL-IOS-001` stand noch auf „In Review" trotz Merge mit PR #1.
- MiniMax-Branch `minimax/inventory-domain` als nicht begonnen identifiziert: kein
  eigener Commit, keine `Features/Inventory/`-Dateien. KL-INVENTORY-001 muss neu
  vergeben werden.
- Eigener Kitchen-Hardening-Fix (dd1c77e) aus dem veralteten
  `codex/post-merge-hardening` isoliert und als sauberer Branch
  `codex/kitchen-hardening-fix` von aktuellem `main` aufgebaut:
  `.preferredColorScheme(.dark)` am Kitchen-View und stabile SwiftUI-Identitäten
  fuer wiederholte Item-Namen. PR #5 ist offen.
- `CURRENT.md`, `WORK_QUEUE.md` und dieser Handoff auf den echten Stand gebracht:
  PR #4 erfasst, Round-2-Sektion mit echtem Status ergaenzt, KL-IOS-001 als
  erledigt markiert, KL-WEB-001 mit beiden konkurrierenden Vorschlaegen
  dokumentiert.

## Verification

- `xcodebuild build` auf iPhone 17 Pro fuer den Kitchen-Hardening-Fix:
  **BUILD SUCCEEDED**.
- `kitchenlinkV2ScreenshotTests` kompiliert und geladen (ohne Capture-Env-Flag
  uebersprungen, wie erwartet).
- `git diff --check` auf allen Doku-Aenderungen: keine Whitespace-Fehler.
- Reale Branch-Zustaende mit `git rev-list --count`, `git log` und
  `git diff --stat` gegen `origin/main` verifiziert.

## Risks And Open Work

- Die vier Round-2-Branches sind 6 Commits hinter `main`; ein Rebase wird bei
  `deepseek/offline-e2e-smoke` und `kimi/workforce-domain` Konflikte in
  `MenuImportDraftReviewTests.swift` und aehnlichen geteilten Testdateien
  erzeugen. Konfliktloesung muss den main-Stand (PR #2/#3) bewahren, nicht die
  alten Branch-Staende.
- KL-WEB-001 hat zwei konkurrierende Stack-Vorschlaege (Claude Fable 5
  urspruenglich zugewiesen, GLM hat eigenen ADR gepusht). Nur der Nutzer
  entscheidet.
- KL-INVENTORY-001 ist unbesetzt, seit MiniMax nie geliefert hat.
- Unautorisierte Nebenzweige existieren: `deepseek/offline-venue-hub-review`
  (KL-OFFLINE-002 Red-Team) und `glm/offline-venue-hub` liegen ebenfalls
  brach und sind nicht Teil der offiziellen Round-2-Missionen.

## Recommended Next Step

PR #5 reviewen und mergen. Danach die Round-2-Branches in der Reihenfolge
KL-OFFLINE-003 -> KL-WORKFORCE-001 -> KL-QA-002 rebase + review + integrieren,
jedes separat. KL-INVENTORY-001 neu vergeben. KL-WEB-001 erst nach
Nutzerentscheid zum Stack.

## Fruehere Continuation

- Continued Claude Code's pushed WIP commit `d9c9719` after its quota stopped the
  active KL-MENU-004 verification pass. No concurrent agent was editing the
  worktree.
- Traced the failing guided UI test to its scroll loop: it repeatedly reopened
  the last visible row instead of advancing through the remaining draft. The
  scanner, draft and conversion model were not losing candidates.
- Added an explicit batch action for unresolved entries that already have a
  usable fixed price. Unpriced candidates remain open and must still be priced
  or rejected individually.
- Prevented unpriced entries from being accepted at both model and UI level,
  and added a fixed next-open action so review no longer depends on list
  scrolling.
- Replaced the brittle 40-row UI loop with the actual Alexxanders workflow:
  accept the priced candidates, price one remaining candidate, reject the other
  and explicitly apply the resolved draft to the local sandbox.
- Removed the temporary diagnostic test after it confirmed that resolving every
  convertible entry leaves exactly the two known unpriced fixture candidates.
- Opened and integrated follow-up PR #3 after PR #2 had already merged Claude's
  WIP commit. `main` now contains the corrected workflow and its verification.

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
- Passed all focused draft-review tests, including model guards and batch
  acceptance semantics.
- Passed the gated fixture-to-review-to-sandbox UI test in 54 seconds and
  visually inspected its open, detail, resolved and applied screenshots.
- Passed the complete unit-test and standard UI-test targets on iPhone 17 Pro.
- Re-ran the 14-page scanner benchmark. All thresholds passed; the two known
  Lichtburg prices remain explicitly unresolved rather than inferred.

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
- The batch action is intentionally explicit and accepts only price-bound
  candidates. It does not publish anything and does not bypass the final local
  sandbox conversion.
- Do not treat the working logo geometry, current typefaces, exact hex values or
  status palette as final approval.
- Claude Code may independently audit and continue the Round-04 implementation
  under the shared peer workflow; Codex approval is not required.

## Recommended Next Step

Review the completed offline smoke-test branch next, then decide the guest-web
stack separately. Keep workforce, inventory and event-log proposals isolated
until each has its own review.
