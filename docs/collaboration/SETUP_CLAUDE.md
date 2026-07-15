# Claude Code One-Time Setup

Claude Code is installed at `/Users/test/.local/bin/claude`. The official Claude
Design MCP endpoint is registered in the user configuration, but login is still
required.

## 1. Open The Shared Project

Close or pause any Codex task that is editing files, then run:

```bash
cd /Users/test/Developments/kitchenlink
claude
```

Accept the workspace trust prompt if Claude shows it. Claude Code will read the
root `CLAUDE.md`, which points to the shared collaboration state.

## 2. Connect Claude Design

Inside Claude Code, run:

```text
/design-login
```

Complete the browser login. Back in Claude Code, run:

```text
/design-sync
```

Select the KitchenLink design project or the design system Claude should sync.

## 3. Verify Context

Send Claude this first message:

```text
Lies AGENTS.md, docs/collaboration/CURRENT.md,
docs/collaboration/DECISIONS.md, docs/PRODUCT_BLUEPRINT.md und
docs/collaboration/handoffs/CODEX.md. Fasse danach nur den aktuellen Stand,
offene Entscheidungen und die Regeln für die Zusammenarbeit mit Codex zusammen.
Ändere noch keine Dateien.
```

The summary should state that the product is still a sandbox and that no Claude
Design territory has been approved.

## 4. Start Parallel Tasks Only After A Checkpoint

Verify that the current shared checkpoint has been committed and pushed. After
that, a separate Claude task can be started with:

```bash
cd /Users/test/Developments/kitchenlink
claude --worktree <task-name>
```

Example:

```bash
claude --worktree design-round-02
```

Do not use this command before the checkpoint is visible on the remote if Claude
must see the current work. By default a new worktree starts from the clean
repository state, not from uncommitted files.

## 5. Finish A Claude Task

Before Claude stops, instruct it:

```text
Aktualisiere docs/collaboration/handoffs/CLAUDE.md mit Umfang, geänderten Dateien,
Verifikation, offenen Risiken und genau einem empfohlenen nächsten Schritt.
Committe danach nur die Dateien dieses Tasks auf deinem Worktree-Branch.
```

Codex or the user then reviews the commit before it is merged into the integration
branch.
