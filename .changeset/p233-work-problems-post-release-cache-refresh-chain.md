---
"@windyroad/itil": minor
---

P233 — `/wr-itil:work-problems` Step 6.5 chains `/install-updates` after successful within-appetite release drain so the next iter subprocess loads the just-shipped plugin from a fresh cache

Add a **Post-release cache refresh (P233)** subsection to Step 6.5 Drain action immediately after the existing 3-step `push:watch` → `release:watch` → `Resume the loop` sequence. The new step 4 chains `/install-updates` to refresh the plugin cache before the next iter dispatches, conditional on step 2 (`release:watch`) actually shipping a release to npm.

**Why this is needed**: empirical evidence in `docs/briefing/afk-subprocess.md` (the "Just-shipped gate-class hooks DON'T protect the immediate-next iter" entry, captured today by the session 3 retro) confirms iter subprocesses re-resolve plugin cache on spawn. Without cache refresh between `release:watch` and next-iter dispatch, a just-shipped gate-class hook is inactive in the very next iter — defeating the "ship a hook to prevent recurrence" pattern for the immediate-next-iter case. Demonstrated empirically twice in the current session: P232's hook landed in `@windyroad/itil@0.30.3` at 08:45 but the antipattern recurred at 09:42 in the next iter; P234's hook landed in 0.30.4 source but was inactive in the iter 4 cache.

**Contract guarantees**:

- **Conditional on actual release** — fires only when `release:watch` actually published. Skipped when `push:watch` ran alone (empty `.changeset/`; no new plugin version). Prevents wall-clock + npm-API noise on no-op refreshes every iter.
- **Non-blocking on /install-updates failure** — orchestrator logs the failure and continues. Degrades to current cache-stays-stale behaviour (equivalent to pre-amendment). Loop MUST NOT halt on `/install-updates` failure under any circumstance.
- **Policy authorisation** — rides the same ADR-013 Rule 5 silent-proceed that already covers `push:watch` / `release:watch`. Composes with P106's `claude plugin install` no-op-when-already-installed factor (chained `/install-updates` handles the uninstall+install dance per P106).
- **Mid-loop ask discipline (P130) preserved** — `/install-updates` AskUserQuestion (cache miss / scope delta / `INSTALL_UPDATES_RECONFIRM=1`) is treated AS the install-updates Non-interactive fallback path (dry-run + log; no loop interruption). Authorised by ADR-044 framework-resolution boundary — invocation between iters is a mechanical-stage transition the framework has resolved; surfacing would dilute Step 2.5b accumulated-question discipline.
- **Composition with above-appetite branch** — chain is anchored to within-appetite Drain action step 4 only. Does NOT fire after Rule 5 halt (no release shipped → nothing to refresh) and does NOT fire mid-loop in the auto-apply loop. Convergence back to Drain action fires the chain there.

**Test surface** (`packages/itil/skills/work-problems/test/work-problems-step-6-5-cache-refresh-chain.bats`) — 14 doc-lint contract assertions per ADR-037 Permitted Exception covering subsection identity, conditional-on-release guard, non-blocking guarantee, ADR-013 Rule 5 + ADR-044 + P130 + P106 cross-refs, briefing evidence citation, and Decision Making table row.

**Visible adopter behaviour** — adopters running `/wr-itil:work-problems` will observe an additional `/install-updates` invocation per release-drain (within-appetite branch only, conditional on a release actually shipping). Minor bump per architect verdict — contract-visible new orchestrator behaviour.

Sibling tickets: parent antipattern is the gate-class-hook-released-mid-AFK-loop dogfood-window class shared with P165; compounding factor is P106 (handled by `/install-updates` internally); evidence chain is P232 + P234 (both demonstrated the cache-staleness antipattern in the current session).
