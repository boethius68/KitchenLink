---
name: autonomous-dev
description: >-
  Autonomous, hands-off development loop for KitchenLink. Automatically picks tasks from GitHub
  Issues or WORK_QUEUE.md, writes code and tests, runs verification gates, self-heals errors, and
  commits without asking for user approval.
---

# Autonomous Developer Skill (`autonomous-dev`)

This skill enables the agent to operate in **100% autonomous mode** ("Ralph Wiggum" loop pattern), executing features, bugfixes, and refactorings with minimal human oversight.

---

## 1. Operating Rules for Complete Autonomy

1. **Zero Unnecessary Interruption**: Do not pause to ask for permission, preferences, or stylistic choices. Make sensible architectural decisions based on [`docs/PRODUCT_BLUEPRINT.md`](../../docs/PRODUCT_BLUEPRINT.md) and existing code conventions.
2. **State on Disk, Not in Memory**: Track progress in Git commits and the task queue (`docs/collaboration/WORK_QUEUE.md` or GitHub Issues).
3. **Strict Verification Gates**: No task is complete until automated tests pass.
4. **Self-Healing Loop**: If a build or test fails, inspect the error output, fix the root cause, and re-run. Repeat until green.

---

## 2. The Execution Loop

When instructed to run autonomously (or via `/goal`):

```
┌────────────────────────────────────────────────────────┐
│ 1. Pick Next Task (GitHub Issue or WORK_QUEUE.md)       │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ 2. Implement Changes (SwiftUI / Next.js / Supabase)    │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ 3. Run Quality Gates:                                  │
│    • cd guest-web && npm run typecheck                 │
│    • cd guest-web && npm test                          │
│    • cd guest-web && npm run lint                      │
│    • xcodebuild build (if Swift code changed)          │
└───────────────────────────┬────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │ Tests Pass?           │
                ├───────────┬───────────┤
                │ Yes       │ No        │
                │           │           │
                │           ▼           │
                │    Analyze Stack Trace│
                │    & Self-Heal Code   │
                │           │           │
                │           ▲           │
                │           └───────────┘
                ▼
┌────────────────────────────────────────────────────────┐
│ 4. Commit & Log Progress:                              │
│    • git commit -m "feat/fix: ..."                     │
│    • Update ticket / issue state                       │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ 5. Loop to Next Task (or finish if queue is empty)     │
└────────────────────────────────────────────────────────┘
```

---

## 3. Mandatory Verification Commands

Before any commit:

### For Web (`guest-web/`):
```bash
cd guest-web
npm run typecheck
npm test
npm run lint
```

### For iOS (`kitchenlink/`):
```bash
xcodebuild build -project kitchenlink.xcodeproj -scheme kitchenlink -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

---

## 4. Architectural Guardrails

- Never commit secrets, `.env.local`, or API keys.
- Preserve all existing demo fixtures and offline-fallback paths.
- Respect the "Dish-First" UI philosophy and legal 14-allergen/additive transparency.
