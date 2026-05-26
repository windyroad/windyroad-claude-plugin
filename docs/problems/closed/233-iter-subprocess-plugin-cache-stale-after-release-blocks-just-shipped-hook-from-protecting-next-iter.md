# Problem 233: AFK iter subprocess plugin cache stale after release — just-shipped hook does not protect the next iter

**Status**: Closed
**Reported**: 2026-05-17
**Known Error since**: 2026-05-17
**Verification Pending since**: 2026-05-18
**Priority**: 8 (Med-High) — Impact: 4 (Significant — fix shipped today did not prevent the same antipattern from recurring 90 min later; cost ~$15 + 90 min wall-clock in a single iter; pattern will recur on every gate-class hook landing) × Likelihood: 2 (Likely — fires once per gate-class hook release until cache-refresh is automated)
**Effort**: M (deferred — re-rate at next `/wr-itil:review-problems`)
**WSJF**: (8 × 1.0) / 2 = **4.0** (deferred — provisional)
**Type**: technical

> Captured 2026-05-17 by `/wr-retrospective:run-retro` session 3 retro. Driver: P232 fix recurred 90 min after release. Sibling to P232 (parent antipattern), P165 (sibling held-changeset class), P106 (claude plugin install no-op-when-already-installed).

## Description

`@windyroad/itil@0.30.3` released 2026-05-17 ~08:45 AEST shipped the P232 PreToolUse:Bash hook (`itil-bash-polling-antipattern-detect.sh`) that denies `(until|while)...pgrep|pkill -0` polling patterns. AFK orchestrator iter 7 dispatched ~10 min after release (~08:55) used the iter subprocess's CACHED `@windyroad/itil` plugin which predated the release. The iter spawned 4 zsh polling loops with the exact `until ! pgrep -f 'bats packages/itil/scripts/test/skill-invocations'; do sleep 1; done` antipattern. The hook did NOT fire because the cached plugin source did not contain it. Iter deadlocked at ~09:42, manually SIGTERM'd at ~10:31 (90m wall-clock; 0-byte JSON per P147 stuck-before-emit; metadata lost).

Same antipattern P232 was supposed to close, in the same session, with the fix released 90 min prior. The fix is correct; the cache propagation delay made it ineffective for the very next iter.

## Symptoms

- @windyroad/itil@0.30.3 published to npm at ~08:45 (release commit 4016bda).
- Iter dispatched at ~08:55 (10 min after publish).
- Iter subprocess loaded plugin from cached prior version — NOT 0.30.3.
- Hook `itil-bash-polling-antipattern-detect.sh` exists in 0.30.3 source but not in the cached version.
- Iter spawned `until ! pgrep -f 'bats ...'` polling loop; no hook denial; pgrep self-referential deadlock per P232 antipattern.
- Manual SIGTERM at 90m wall-clock; exit 143 + 0-byte JSON; retro lost.

## Workaround

User runs `/install-updates` (or `claude plugin uninstall + install` per P106 contract) BETWEEN release and next iter dispatch to refresh cache. Currently a manual step the orchestrator does not perform.

## Impact Assessment

- **Who is affected**: anyone running `/wr-itil:work-problems` AFK loop where Step 6.5 drain releases a hook-class fix mid-loop. Every gate-class hook release is at risk until cache-refresh is automated.
- **Frequency**: 1 recurrence today (iter 7 of session 3) — second P232 recurrence within 24 hours despite the fix being shipped 90 min prior to the recurrence.
- **Severity**: High. Defeats the entire "ship a hook to prevent recurrence" pattern for the immediate-next-iter case.

## Root Cause Analysis

Claude Code's plugin cache lifecycle:
- `npm install` publishes the new version to the registry
- Plugin cache at `~/.claude/plugins/cache/<owner>/<plugin>/<version>/` does NOT auto-update on npm publish
- `claude plugin install <plugin>` is a no-op when already installed at any version (per P106)
- Cache refresh requires explicit `claude plugin uninstall + install` OR session restart with fresh plugin install

The AFK orchestrator's Step 6.5 release-cadence drain runs `npm run push:watch` + `release:watch` to publish to npm — and then immediately dispatches the next iter without invalidating or refreshing the iter subprocess's plugin cache. The just-shipped fix exists in npm but not in the cache the next iter subprocess will load from.

Compounding factor (P106): `claude plugin install` is silent no-op on already-installed plugins, so even an explicit reinstall between iters wouldn't refresh without the full uninstall + install dance.

## Fix Strategy

Three options enumerated:

**Option A — orchestrator-side cache invalidation between iter and next-iter dispatch**: extend `/wr-itil:work-problems` Step 6.5 (post-release-drain) with explicit `claude plugin uninstall <plugin> + install <plugin>` per package that just shipped, BEFORE dispatching next iter. Composes with P106's existing `/install-updates` skill.

**Option B — iter subprocess loads plugin from source-tree when running in monorepo**: detect when iter is dispatched inside the plugin's source repo (e.g. `CLAUDE_PROJECT_DIR` matches the plugin's git origin) and load hooks directly from `packages/<plugin>/hooks/` rather than from the cache. Eliminates cache-staleness for in-repo dogfood. Doesn't help adopter projects.

**Option C — invoke `/install-updates` automatically post-release in Step 6.5 (preferred)**: between `release:watch` completion and next-iter dispatch, orchestrator invokes `/install-updates` (which handles the uninstall+install dance per P106). Cleanest user-facing pattern. Highest reuse.

## Dependencies

- **Composes with**: [[P232]] (parent — the antipattern that should have been caught), [[P106]] (claude plugin install no-op-when-already-installed), [[P165]] (sibling hook-rollout dogfood-window class).
- **Blocked by**: (none — /install-updates already exists; orchestrator just needs to invoke it).
- **Blocks**: effective dogfood of any future gate-class hook released mid-AFK-loop.

## Related

- [[P232]] — parent antipattern; its fix was rendered ineffective for the immediate-next-iter by cache staleness
- [[P146]] — grand-parent (bash until-loop deadlock class)
- [[P147]] — stuck-before-emit subclass; metadata loss observed on iter 7's SIGTERM
- [[P106]] — `claude plugin install` no-op-when-already-installed (compounding factor)
- [[P165]] — sibling hook-rollout dogfood-window class

## Change Log

- **2026-05-17** — Captured by `/wr-retrospective:run-retro` session 3 retro. Driver: iter 7 deadlocked at ~10:31 in retro phase with the P232 antipattern that was supposed to have been caught by the hook shipped in `@windyroad/itil@0.30.3` at ~08:45 (90 min prior). Cache-staleness root cause confirmed by inspecting iter subprocess child processes (4 zsh polling loops self-referencing via `pgrep -f`). Captured via direct write (Step 4b Stage 1 mechanical ticketing per ADR-044 framework-resolution boundary); surfaced via Step 2b Pipeline Instability scan (Hook-protocol friction category — "hook silently skipping paths it should").
- **2026-05-17** — Open → Known Error. Phase 1 implementation landed in session 4 iter 5: `/wr-itil:work-problems` Step 6.5 Drain action gains a step-4 `/install-updates` chain after successful within-appetite release drain (Fix Strategy Option C — preferred). Architect approved after empirical evidence at `docs/briefing/afk-subprocess.md` confirmed iter subprocesses re-resolve plugin cache on spawn (not parent-inherited). Changeset `.changeset/p233-work-problems-post-release-cache-refresh-chain.md` declares `@windyroad/itil` minor bump. 14 doc-lint contract assertions in `packages/itil/skills/work-problems/test/work-problems-step-6-5-cache-refresh-chain.bats` per ADR-037. Released-fix verification deferred to subsequent retro evidence on next gate-class hook release (orchestrator AFK loop running the new step 4 should refresh cache + protect next iter from cache staleness empirically).
- **2026-05-18** — Known Error → Verification Pending. Phase 1 fix shipped in `@windyroad/itil@0.31.0` (version-packages commit `c781a29` 2026-05-17 14:40 AEST). Session 6 (this loop, 2026-05-18) provides empirical verification across 5 release cycles: itil 0.32.2 (P252, drain-iter1 07:01:45), itil 0.32.3 (P250, drain-iter2 07:34:51), itil 0.33.0 (P246+P170, drain-iter4 08:36:39), retro 0.19.0 (P247, drain-iter5 09:05:55), itil 0.34.0 (P249, drain-iter6 09:46:38). Direct evidence of Step 4 firing: install-updates churn commit `40fc6a1 chore(settings): reorder enabledPlugins (install-updates churn)` at 09:41:05 AEST. Cross-release behavior proof: iter 2 shipped P250 "drain-on-releasable-material" in itil 0.32.3 at 07:34:51; iter 3's drain at 07:56:29 invoked the new logic (push:watch only, no release:watch on empty changeset) — confirming the orchestrator main turn picked up the just-shipped SKILL.md from refreshed cache, the exact propagation path P233's Phase 1 was designed to enable. The Change Log 2026-05-17 verification criterion specified "next gate-class hook release"; session 6 shipped no gate-class hooks but the equivalent mechanism (cache-refresh chain ran AND just-shipped behavior reached the next iter's orchestrator main turn) is empirically confirmed. No P232 cache-staleness recurrence observed across 6 iter→iter transitions this session. Architect verdict PASS + JTBD verdict PASS (JTBD-006 primary, JTBD-007 composes). Recovery path: `/wr-itil:transition-problem 233 known-error` after reverting the iter commit if cache-staleness regression observed.
