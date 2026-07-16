# Agent Round Integration Review

**Date:** 16 July 2026  
**Integration branch:** `codex/agent-round-integration`  
**Reviewed branches:** `claude/design-audit`, `glm/guest-web-architecture`,
`deepseek/offline-venue-hub-review`

## Outcome

| Workstream | Result | Integration decision |
| --- | --- | --- |
| Claude Round-04 audit and reference views | Tests pass; two objective implementation issues corrected on the integration branch | Ready for user visual review; do not merge to `main` before approval |
| GLM guest-web architecture | Useful direction, but transaction and local-guest-path boundaries remain incorrect or underspecified | Do not merge as an accepted ADR |
| DeepSeek venue-hub contract and PoC review | Contains blocking SQLite, durability, retry and current-browser inaccuracies | Do not use as an implementation contract |

No result from another agent was silently rewritten or merged to `main`.

## Claude Review

The audit and implementation commits were replayed onto the integration branch.
The complete Xcode suite and the screenshot harness passed. Independent visual
inspection covered Today and Kitchen on the iPhone 17 Pro simulator.

Two objective corrections were applied without changing the approved Round-04
design direction:

- Kitchen item rows now use their position as SwiftUI identity. Identical item
  labels no longer collapse into duplicate `ForEach` identities.
- Kitchen now requests dark system chrome in addition to its dark environment.
  The screenshot test relaunches without a global light override before checking
  this invariant.

The neutral `Zahlung offen` card remains in Kitchen exactly as specified by
Round 04 and Claude's implementation handoff. Its presence is a product and
visual approval question, not an integration defect.

## GLM Review

The revised ADR correctly moved Cloudflare deployment to the current Workers and
OpenNext path and separated anonymous guest identity from public database access.
It is not yet decision-ready for these reasons:

- A Supabase Edge Function does not make multiple database calls atomic. The
  write path needs one explicit PostgreSQL transaction, normally exposed as a
  transactional RPC and called by the Edge Function after authentication and
  rate limiting. `Edge Function or RPC` is not an equivalent choice.
- The optional installable PWA shell and the mandatory local guest-ordering path
  are different concerns. The Product Blueprint requires local multi-device
  operation in Sandbox Beta; that architecture cannot be deferred wholesale to
  a later PWA stage.
- Anonymous sign-in must account for abuse protection, provider rate limits,
  cleanup and dynamic rendering behavior before it becomes the recommended
  default.

Relevant primary sources:

- <https://supabase.com/docs/guides/auth/auth-anonymous>
- <https://supabase.com/docs/guides/functions/connect-to-postgres>
- <https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/>

## DeepSeek Review

The new event-log contract cannot safely guide implementation yet. Blocking
issues include:

- SQLite does not support `SELECT ... FOR UPDATE`.
- The idempotency check sits outside the write transaction, while the pseudocode
  also confuses the input event sequence with the inserted row identifier.
- Outbox rows can remain in `sending` forever after a crash because there is no
  lease or recovery timestamp.
- A generic HTTP 200/201 is not an authoritative persisted-event acknowledgement.
- WAL durability is asserted without an explicit `PRAGMA synchronous` policy.
- The custom `schema_version` contract is not automatically maintained by GRDB,
  and no payload-schema version is defined for replay.
- Idempotency lacks venue scope and a request fingerprint, so reuse with a
  different payload is not rejected deterministically.

The network PoC also relies on obsolete platform claims. Current Chrome uses a
permission-based Local Network Access model, and Android has system `.local`
resolution through its mDNS resolver. Those paths still require real-device
tests, especially for Safari, but they must not be rejected from stale browser
behavior.

Relevant primary sources:

- <https://www.sqlite.org/wal.html>
- <https://developer.chrome.com/blog/local-network-access>
- <https://source.android.com/docs/core/ota/modular-system/dns-resolver>

## Next Gates

1. Obtain the user's visual approval for Today and Kitchen, including the
   deliberate payment-open card at the pass.
2. Merge only the approved Claude implementation plus the objective fixes.
3. Rewrite the guest write boundary and offline event contract as separate,
   focused tasks before implementation.
4. Start `KL-MENU-004` only after deciding how draft evidence maps reliably to
   its source page.
