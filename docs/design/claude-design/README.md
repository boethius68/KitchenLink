# Claude Design Rounds

Claude Design exports are versioned as immutable numbered rounds.

## Structure

```text
docs/design/claude-design/
  inbox/                 Temporary location for new ZIP exports
  round-01/
    source-export.zip    Original export
    export/              Locally viewable HTML export
    thumbnail.webp
    REVIEW.md            Codex/user review and next prompt
  round-02/
    source-export.zip
    export/
    thumbnail.webp
    REVIEW.md
  round-03/
    source-export.zip
    export/
    thumbnail.webp
    REVIEW.md
  round-04/
    source-export.zip
    export/
    thumbnail.webp
    REVIEW.md
```

## Import A New Export

1. Save the downloaded ZIP in `docs/design/claude-design/inbox/`.
2. Choose the next unused round number.
3. Run:

```bash
./scripts/import-claude-design.sh \
  docs/design/claude-design/inbox/<export>.zip \
  round-02
```

4. Review the imported HTML visually.
5. Add `REVIEW.md` to that round.
6. Keep the source export unchanged.

The inbox is not the source of truth and its ZIP files are ignored by Git. The
numbered round directory is the durable artifact.
