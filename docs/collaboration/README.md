# KitchenLink Agent Collaboration

This directory is the handoff layer between the user, Codex and Claude Code. Git
is the synchronization mechanism; chat history is not a source of truth.

## Directory Roles

- `CURRENT.md`: integrated state of the project, maintained after merges
- `DECISIONS.md`: append-only log of explicitly approved product decisions
- `handoffs/CODEX.md`: latest Codex work and remaining risks
- `handoffs/CLAUDE.md`: latest Claude Code work and remaining risks
- `templates/HANDOFF_TEMPLATE.md`: required handoff format

## Start A Task

1. Pull or sync the latest repository state.
2. Read `AGENTS.md`, `CURRENT.md`, `DECISIONS.md` and the other agent's handoff.
3. Confirm that the task does not overlap files currently owned by another agent.
4. Use a dedicated worktree for parallel code changes.
5. Implement and verify the task.
6. Update only the working agent's handoff file.
7. Commit and push the task branch.
8. Merge intentionally, then update `CURRENT.md` in the integration branch.

## Sequential Work

If only one agent is active, both Codex and Claude Code may be launched from the
main checkout:

```bash
cd /Users/test/Developments/kitchenlink
claude
```

Do not leave Codex editing the same checkout while Claude Code is running there.

For the one-time Claude Code and Claude Design setup, follow
`SETUP_CLAUDE.md`.

## Parallel Work

Before the first parallel task, the current state must be committed and preferably
pushed. Claude worktrees otherwise start from `origin/HEAD` and will not see local
uncommitted files.

From the repository root:

```bash
claude --worktree <task-name>
```

Claude Code then creates an isolated checkout under
`.claude/worktrees/<task-name>/`. Its edits cannot overwrite the main worktree.
Codex should use its own `codex/<task-name>` branch or worktree for concurrent
changes.

Use the main checkout as the integration point. Do not copy changed source files
between worktrees manually; merge commits or cherry-pick focused commits.

## Claude Design

Claude Design on web or desktop does not continuously watch this local folder.
Use one of these paths:

1. Connect the GitHub repository and sync the selected design/product files before
   a design round.
2. From Claude Code, use `/design-sync` and the Claude Design MCP connection.
3. Export a ZIP into `docs/design/claude-design/inbox/` and import it as a numbered
   round with `scripts/import-claude-design.sh`.

Keep design rounds immutable. Feedback belongs in each round's `REVIEW.md`; a new
iteration gets a new directory.
