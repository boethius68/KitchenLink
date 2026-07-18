# KitchenLink Parallel Missions — 18 July 2026

These missions follow the established peer workflow (`docs/collaboration/PEER_WORKFLOW.md`).
Two disjoint assignments are open this round. Each agent works in its own
worktree and branch, both freshly created from the current `origin/main`
(`298b74a`). Do not edit another mission's write scope.

All agents must first read, in this order:

1. `AGENTS.md`
2. `docs/collaboration/CURRENT.md`
3. `docs/collaboration/DECISIONS.md`
4. `docs/PRODUCT_BLUEPRINT.md`
5. This mission file
6. The other agent's latest handoff if it touches an adjacent scope

## Common constraints (apply to both missions)

- KitchenLink remains an internal sandbox. Keep every demo and simulation path.
- Do not deploy, enable live payments, or add secrets to the repository.
- Do not edit `docs/collaboration/DECISIONS.md`.
- Do not edit `docs/collaboration/CURRENT.md`; the integrator owns it.
- Use primary sources for technical claims and link them directly.
- Commit and push the assigned branch. Update only the assigned handoff file.
- Report exact verification commands, results, and unresolved risks.
- The user is the product and design authority. Surface product or design
  decisions instead of making them.

## Worktree and branch setup (do this first, exactly once per agent)

```bash
# Claude
git worktree add -b claude/<your-branch-name> /Users/test/Developments/kitchenlink-claude origin/main

# Codex
git worktree add -b codex/<your-branch-name> /Users/test/Developments/kitchenlink-codex origin/main
```

The existing `kitchenlink-claude` and `kitchenlink-codex` worktrees currently
sit on stale branches (`main` is 12 commits behind on the Claude side; Codex
is on `codex/menu-import-review`). Either create a fresh branch from
`origin/main` as above, or `git checkout main && git reset --hard origin/main`
inside the existing worktree, then branch. **Do not rebase the old
`claude/design-audit` or `codex/menu-import-review` branches onto `main`** —
their work is already merged via PR #1 / older PRs; a fresh branch is cleaner.

---

## Mission A — Review and merge PR #15 (KL-INVENTORY-002)

**Branch:** `claude/pr-15-review` **or** `codex/pr-15-review` (whoever takes it)
**Worktree:** the corresponding `kitchenlink-claude` or `kitchenlink-codex`
**Exclusive write scope:**

- `docs/collaboration/reviews/REVIEW_PR_015_<DATE>.md` (new file)
- `docs/collaboration/handoffs/<YOUR_AGENT>.md` (your own handoff only)
- If you merge: `docs/collaboration/CURRENT.md` (the merge agent owns this)
- No code edits unless a real bug requires an in-PR fix; in that case push to
  the `glm/inventory-operator-ui` branch and coordinate with GLM via the PR

### What PR #15 delivers

KL-INVENTORY-002 (by GLM, branch `glm/inventory-operator-ui`): a read-only
`Bestand` (inventory) operator surface in the V2 business home, deriving its
state exclusively from the real `InventoryProjection` and
`InventoryReplenishmentAdvisor` of the merged KL-INVENTORY-001 domain. No
second stock model, no mock values. Grouped by stock location, severity
(`ok`/`warning`/`critical`) shown as German plaintext verb plus urgency color.
Booking, persistence, and cloud sync remain deferred.

Key things to verify carefully:

- **Design-rule adherence.** Severity → urgency mapping
  (`ok`→neutral, `warning`→waiting, `critical`→critical) is within the
  already-approved `DESIGN_SYSTEM.md` §6. **Critically check** that no new
  `KitchenLinkV2Operation` case (`.stock`) was invented, that
  `KitchenLinkDesignSystemV2.swift` is untouched, that lemon appears only in
  the single demo action, and that no fake glyph fakes a status. The author
  explicitly chose the §6 interim (color + plaintext, no form glyph); confirm
  that choice is honestly applied.
- **MiniMax scope honour.** None of the 8 Inventory core files
  (`InventoryQuantity/Models/Movement/Ledger/Projection/Replenishment/
  RecipeResolution/SandboxFixture.swift`) or `INVENTORY_MODEL.md` may be
  touched. UI lives under a new `Features/Inventory/Views/` subdirectory.
  File names use the `KitchenLinkV2` prefix (consistent with
  `KitchenLinkV2TodayEvents`), avoiding collision with MiniMax's
  `Inventory*Tests.swift`. Confirm with `git diff origin/main...glm/inventory-operator-ui -- kitchenlink/Features/Inventory/ docs/`.
- **Tests are real.** GLM reports 12 new unit tests + complete unit suite
  + UI suite + light/dark screenshot capture all `** TEST SUCCEEDED **`.
  Reproduce at least the new projection tests
  (`KitchenLinkV2InventoryStockProjectionTests`) and the complete unit suite
  on `iPhone 17 Pro` (or equivalent iOS 26.5 simulator). Report exact
  xcodebuild commands and outputs.
- **Visual inspection (the one thing GLM could not do).** idb was unavailable
  in GLM's environment, so GLM could not visually inspect the live view
  against `DESIGN_SYSTEM.md`. The screenshot test passed text assertions, but
  a human/agent visual pass on iPhone 17 Pro light + dark is the explicit
  open item. If you have idb or can open the simulator, capture the Inventory
  screen and confirm: urgency colors are correct, lemon only in the demo
  button, no fake glyph, layout doesn't clip on accessibility type sizes.

### Merge rule

If review finds no P0/P1: merge PR #15 to `main`, then as the merge agent
update `CURRENT.md` to record KL-INVENTORY-002 (what it delivered, the
design-rule interim that was applied, the open visual-inspection item if you
did not close it yourself). Skip the merge if you find P0/P1; instead leave
the review file and request fixes on the PR.

### Copy-ready prompt (for whichever agent takes Mission A)

```text
Lies in dieser Reihenfolge: AGENTS.md, docs/collaboration/CURRENT.md,
docs/collaboration/DECISIONS.md, docs/PRODUCT_BLUEPRINT.md und
docs/collaboration/PARALLEL_MISSIONS_2026-07-18.md (Mission A). Wechsle in
deinen Worktree (/Users/test/Developments/kitchenlink-claude oder
/Users/test/Developments/kitchenlink-codex), lege einen frischen Branch von
origin/main an (claude/pr-15-review oder codex/pr-15-review), und pruefe
PR #15 (Branch glm/inventory-operator-ui, KL-INVENTORY-002).

PR #15 fuegt eine read-only Bestand-Ansicht (V2) hinzu, die ihren Zustand
ausschliesslich aus der echten InventoryProjection und dem
InventoryReplenishmentAdvisor der gemergten KL-INVENTORY-001-Domain ableitet.
GLM hat es nicht visuell gegen DESIGN_SYSTEM.md pruefen koennen (idb fehlte);
diese Inspektion ist ausdruecklich an dich delegiert.

Pruefe sorgfaeltig:
- Design-Regeltreue: keine neue KitchenLinkV2Operation (kein .stock),
  KitchenLinkDesignSystemV2.swift unangetastet, Zitrone nur in der einzelnen
  Demo-Aktion, kein erfundener Glyph. Der §6-Interim (Farbe + Klartext) muss
  ehrlich angewendet sein.
- MiniMax-Scope-Ehre: keine der 8 Inventory-Core-Dateien oder
  INVENTORY_MODEL.md darf angeruehrt sein (git diff pruefen).
- Tests: reproduziere mindestens die neuen
  KitchenLinkV2InventoryStockProjectionTests und die komplette Unit-Suite
  auf iPhone 17 Pro. Dokumentiere die exakten xcodebuild-Kommandos und
  Ergebnisse.
- Visuelle Inspektion: capture die Bestand-Ansicht auf iPhone 17 Pro hell
  und dunkel, pruefe Urgency-Farben, Zitronenregel, kein Fake-Glyph, kein
  Clipping bei Accessibility-Dynamic-Type.

Schreibe den Review-Bericht nach
docs/collaboration/reviews/REVIEW_PR_015_2026-07-18.md und aktualisiere
ausschliesslich deinen eigenen Handoff
(docs/collaboration/handoffs/CLAUDE.md bzw. CODEX.md).

Bei P0/P1: kein Merge. Hinterlasse den Bericht und bitte GLM um Fixes im PR.
Ohne P0/P1: merge PR #15 nach main, aktualisiere als Merge-Agent
docs/collaboration/CURRENT.md (KL-INVENTORY-002-Eintrag: was geliefert wurde,
der angewendete Design-Regel-Interim, der offene visuelle Punkt falls du ihn
nicht selbst geschlossen hast), pushe main, dokumentiere das Ergebnis in
deinem Handoff.
```

### Acceptance gate

- Reproduced test results (commands + outcomes) recorded in the review file.
- Visual inspection either completed and documented, or explicitly left open
  with a clear reason.
- If merged: `CURRENT.md` updated; `main` pushed; both handoffs (reviewer +
  GLM) reflect the merged state.

---

## Mission B — One new parallel iOS domain (to be agreed with the user)

**Branch:** `claude/<domain-branch>` **or** `codex/<domain-branch>`
**Worktree:** the corresponding `kitchenlink-claude` or `kitchenlink-codex`

The user has explicitly said the concrete domain for this mission will be
decided directly between the user and the agent (not pre-assigned here). Do
not start coding until the user has confirmed the scope with you.

Candidate domains already explored by GLM (each technically ready and
disjoint from PR #15's scope; pick one, or propose something else to the
user):

- **Workforce operator UI** — read-only shift plan, analogue to KL-INVENTORY-002.
  Domain complete and tested (KL-WORKFORCE-001, Kimi, merged),
  `WorkforceSandboxWeekFixture` preview-ready (5 employees, 4 shifts, Monday
  only). Note: `Features/Workforce/` is Kimi's module — additive `Views/`
  subdirectory only, same scope-honour pattern as KL-INVENTORY-002.
- **Event-log integration seam** — pull the isolated KL-OFFLINE-003 prototype
  (`prototypes/KitchenLinkEventLog/` Swift package) into the app target,
  author an `EventLogCoordinator`, place an `EventBackedRepository` next to
  `LocalDemoRepository`. Architecturally the most significant next step;
  **requires explicit user approval per `EVENT_LOG_V2.md` §12** ("dieser
  Milestone bedarf einer separaten Nutzerfreigabe gemäß DECISIONS.md").
- **Inventory booking follow-up** — Wareneingang/Verbrauch/Verderb in the
  Inventory surface GLM just built. Depends on PR #15 merge; write scope
  `Features/Inventory/Views/` is shared with GLM's recent work, so coordinate.
- Something else you and the user agree on.

### Read before proposing a domain to the user

- The "What's next" section at the bottom of `docs/collaboration/CURRENT.md`
- `docs/collaboration/WORK_QUEUE.md` (the active strands and open items)
- The KL-INVENTORY-002 section in `WORK_QUEUE.md` (just added by GLM) as the
  pattern template for a new iOS surface
- `docs/discovery/offline-venue-hub/INTEGRATION_REVIEW.md` for which offline-
  hub pieces are blocked vs. ready

### Copy-ready prompt (for whichever agent takes Mission B)

```text
Lies in dieser Reihenfolge: AGENTS.md, docs/collaboration/CURRENT.md,
docs/collaboration/DECISIONS.md, docs/PRODUCT_BLUEPRINT.md und
docs/collaboration/PARALLEL_MISSIONS_2026-07-18.md (Mission B). Wechsle in
deinen Worktree (/Users/test/Developments/kitchenlink-claude oder
/Users/test/Developments/kitchenlink-codex) und lege einen frischen Branch
von origin/main an.

Mission B ist eine neue parallele iOS-Domain. Die konkrete Domain ist NICHT
vorgegeben - sie wird zwischen dir und dem Nutzer direkt vereinbart. Lies
die "What's next"-Sektion in docs/collaboration/CURRENT.md, die aktiven
Stroeme in docs/collaboration/WORK_QUEUE.md und den neuen KL-INVENTORY-002-
Abschnitt als Muster fuer eine iOS-Oberflaeche.

Kandidaten-Domaenen, die GLM bereits erkundet hat (jede technisch ready und
disjunkt vom PR-#15-Scope):
- Workforce-Operator-UI (read-only Schichtplan, analog KL-INVENTORY-002)
- Event-Log-Integrationsnaht (benoetigt explizite Nutzerfreigabe fuer
  Milestone §12)
- Inventory-Buchen (Folgeticket zu PR #15)
- oder etwas ganz anderes

Schlage dem Nutzer EINE Domain mit konkretem Scope, Schreibbereich,
Schaetzung und Begründung vor. Warte auf seine Zusage. Beginne KEINEN Code,
bevor der Scope zwischen dir und dem Nutzer abgestimmt ist. Halte dich dann
an docs/collaboration/PEER_WORKFLOW.md: exklusiver Schreibbereich, eigener
Branch, eigene Tests, eigener Handoff. PR-#15-Scope ist tabu, ausser der
Nutzer entscheidet anders.

Falls du Workforce-Operator-UI waehlst: halte die gleiche MiniMax/Kimi-
Scope-Ehre wie GLM bei KL-INVENTORY-002 (nur additive Views/-Dateien, keine
Edits an Kimis Domain-Core). Falls du Event-Log-Integrationsnaht waehlst:
der Nutzer muss den §12-Milestone explizit freigeben, bevor du anfaengst -
dokumentiere diese Freigabe im Handoff, nicht in DECISIONS.md.
```

### Acceptance gate

- One domain agreed with the user and recorded in the agent's handoff before
  any implementation.
- Branch from fresh `origin/main`, exclusive write scope respected.
- Tests, visual check, and risks in the handoff.
- No touch of PR-#15 / KL-INVENTORY-002 scope unless the user explicitly
  redirected.

---

## Conflict avoidance between Mission A and Mission B

The two missions are designed to be safe in parallel:

- **Mission A** reviews and possibly merges PR #15. Its write scope is
  `docs/collaboration/reviews/`, the reviewer's own handoff, and `CURRENT.md`
  only if it merges. No `kitchenlink/` code edits except coordinated fixes
  pushed to `glm/inventory-operator-ui`.
- **Mission B** implements a new domain in its own `Features/<Domain>/Views/`
  path or equivalent. It does not touch `Features/Inventory/`, `Features/Today/`,
  `Features/Kitchen/`, or `Features/MenuImport/`.

If Mission B is **Inventory booking follow-up**, there IS a shared scope
(`Features/Inventory/Views/`); in that case the two missions cannot run fully
in parallel. Coordinate with GLM via the handoffs or pick a different domain.

## Integrator role for this round

Whoever merges PR #15 (Mission A) updates `CURRENT.md` once. After that, the
integrator role for this round ends. Mission B's integration happens in a
later round, with its own merge agent and `CURRENT.md` update, following the
same peer-workflow rules.
