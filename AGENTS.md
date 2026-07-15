# KitchenLink Agent Instructions

Codex, Claude Code and other coding agents use the same project context.

Before changing code or product documents, read in this order:

1. `docs/collaboration/CURRENT.md`
2. `docs/collaboration/DECISIONS.md`
3. `docs/PRODUCT_BLUEPRINT.md`
4. The other agent's latest file in `docs/collaboration/handoffs/`
5. Task-specific specifications and design reviews

## Source Of Truth

- User-approved decisions in `docs/collaboration/DECISIONS.md` override drafts.
- `docs/PRODUCT_BLUEPRINT.md` is the canonical product scope.
- `docs/collaboration/CURRENT.md` describes the integrated project state.
- Design explorations are not approved merely because they exist in the repo.
- The working app remains a sandbox. Demo and simulation paths must continue to
  work until the user explicitly approves production hardening.

## Collaboration

- Never let two agents edit the same working tree concurrently.
- Use a separate Git worktree and branch for parallel implementation work.
- Do not overwrite unrelated uncommitted changes.
- Each agent updates only its own handoff file when finishing a task.
- Only the integrator updates `CURRENT.md` after changes have been merged.
- Add a decision to `DECISIONS.md` only after explicit user approval.
- Record verification performed and any remaining risk in the handoff.

## Delivery

- Keep commits focused and do not combine unrelated agent work.
- Do not deploy, enable live payments or remove sandbox labeling without explicit
  approval.
- Do not commit secrets, local credentials or private Supabase keys.
