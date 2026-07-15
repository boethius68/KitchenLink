# KitchenLink Current State

**Updated:** 15 July 2026
**Integration branch:** `main`
**Phase:** Product definition and visual design exploration
**Release status:** Internal sandbox, not production

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
- Codex recommends `Blende` as the brand base and only the status logic from
  `Takt`; the user has not approved that recommendation yet.
- Round 01 and its review are under `docs/design/claude-design/round-01/`.

## Code

- A functioning SwiftUI sandbox prototype exists.
- The shared collaboration and design state must be present on `origin/main`
  before Claude Code and Codex start parallel worktrees from it.
- No production deployment, live payment activation or final fiscal integration
  is approved.

## Agent Setup

- Shared instructions are available through `AGENTS.md` and `CLAUDE.md`.
- Claude Code `2.1.150` is installed locally.
- The official Claude Design MCP endpoint is registered in the Claude user
  configuration. Interactive authentication with `/design-login` is still
  required.
- New Claude Design ZIP files can be imported with
  `scripts/import-claude-design.sh`.

## Next Decision

Decide whether `Blende` becomes the sole visual basis for Claude Design Round 02.
After that, refine logo, typography, operational status semantics, no-photo guest
state and iPad kitchen/service screens.
