# KitchenLink Agent Instructions

Codex and Claude Code use the same project context. Earlier work from other
models remains part of the project history, but no new tasks are assigned to
them until the user changes this decision.

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

- Claude Code and Codex are equal technical collaborators. Neither is the
  permanent lead, gatekeeper or owner of integration.
- The user is the product and design authority. Only the user can approve new
  product scope, visual direction, production activation or other decisions
  reserved in `DECISIONS.md`.
- `main` is a shared integration branch and belongs to no agent. Feature work is
  performed in agent-owned branches and worktrees.
- Never let two agents edit the same working tree concurrently.
- Use a separate Git worktree and branch for parallel implementation work.
- Do not overwrite unrelated uncommitted changes.
- Each agent updates only its own handoff file when finishing a task.
- Either agent may propose, implement, review, challenge or integrate work under
  the same rules. Approval from one specific agent is never mandatory.
- The agent performing a merge updates `CURRENT.md` after the merge. There is no
  permanent integrator role.
- Add a decision to `DECISIONS.md` only after explicit user approval.
- Record verification performed and any remaining risk in the handoff.
- Follow `docs/collaboration/PEER_WORKFLOW.md` for task claiming, pull requests,
  reviews and integration.

## Delivery

- Keep commits focused and do not combine unrelated agent work.
- Do not deploy, enable live payments or remove sandbox labeling without explicit
  approval.
- Do not commit secrets, local credentials or private Supabase keys.
