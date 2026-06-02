# Problem 116: `push:watch` preflight does not count local-only commits before batch-push — CI regressions in intermediate commits stay invisible

**Status**: Verification Pending
**Reported**: 2026-04-24
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: S (preflight in `scripts/push-watch.sh` + warning + bats contract-assertion)
**WSJF**: 0 (Verification Pending — excluded from dev ranking per ADR-022)

> Surfaced during P113's release cycle via run-retro Step 2b pipeline-instability scan (P074 class). My P113 fix commit `b2424c8` pushed to origin; CI failed on tests 699/700/701 in `risk-scorer-structured-remediations.bats`. Those tests had actually regressed two days earlier in commit `64f6d3f` — a commit that lived only locally on `main` alongside four other intermediate commits (`2be1bfa`, `ee316ba`, `ce5cfb6`, `71441f7`, `3cfb479`). None of the intermediate commits had ever been pushed to origin individually, so origin CI had never run against them. My P113 push batched all six commits in one push event; GitHub Actions fires CI only on the pushed-tip SHA, not on every reachable commit. The regression took the blame against my (innocent) P113 commit; `gh run list --branch main` showed CI runs only for the `6b76d13` merge and my `b2424c8` push — a five-commit gap where regressions could hide. This hazard compounds each unpushed commit. The current `push:watch` script does not warn.

## Description

`npm run push:watch` is the sanctioned push surface (git-push-gate hook blocks bare `git push`). It runs the push and watches the resulting CI run. It does not currently inspect the shape of what is being pushed — specifically, it does not count how many commits are about to land on origin in one push event.

When a developer has N ≥ 2 local-only commits since the last push, a batch-push bundles them into one CI run (against the tip SHA). Any CI regression introduced by commit 1..N-1 is invisible to CI until the push happens, and then CI reports against commit N (the tip), not against the commit that actually introduced the regression. The blame trail is wrong; the developer spends diagnostic time tracing "my latest commit" before realising the regression came from an earlier commit in the batch.

This is adjacent to P040 (closed — `work-problems` fetches origin at loop start) and P109 (open — `work-problems` Step 0 prior-session state detection) but distinct. Those cover the orchestrator's loop-entry posture. P116 covers the push cadence across any sequence of local commits, orchestrator-invoked or interactive.

## Symptoms

- `git log @{push}..HEAD --oneline` returns N ≥ 2 commits before the user runs `npm run push:watch`; no warning fires.
- After the push, `gh run list --branch main --limit N+1` shows CI runs for the push tip and the previous known-good commit, with a gap corresponding to the intermediate commits.
- If a regression hid in the middle of the batch, CI reports it against the tip commit — not against the regressing commit. Diagnostic attention starts on the wrong file.
- The longer the period between pushes, the larger the potential invisibility window.

## Workaround

Manual: before `npm run push:watch`, run `git log @{push}..HEAD --oneline | wc -l` (or equivalent). If ≥ 2, either push intermediate commits first (multiple `push:watch` cycles with one commit each), or run the test suite locally for the full range (`npm run verify` or the equivalent project-level batch). This is a manual discipline check; it is not enforced anywhere.

An interim user-script alias could wrap `push:watch` with a preflight count, but that's per-user and drifts from the repo-local sanctioned surface.

## Impact Assessment

- **Who is affected**: every developer on this repo who batches multiple local commits between pushes. In practice: interactive sessions that span multiple work items, AFK orchestrators that accumulate iteration commits, cross-session work on the same branch. Also: any adopter repo that uses the same `push:watch` pattern (the `scripts/push-watch.*` script is part of the windyroad tooling footprint).
- **Frequency**: every batched push. In this session alone the hazard fired on `b2424c8`'s push (six commits batched, one regression hidden). P109 notes the same class at work-problems loop start.
- **Severity**: Moderate. CI still catches the regression at the push tip, so the bug doesn't ship. Cost is diagnostic time + confusion + wrong-blame attribution, not shipped breakage. But diagnostic time compounds — if the hidden regression is deep in a test suite and the tip commit is complex, the debug can consume 30+ minutes that a 5-second preflight warning would have short-circuited.
- **Analytics**: N/A — observed by developer experience; no telemetry.

## Root Cause Analysis

### Confirmed root cause (session 2026-04-24)

The `push:watch` script (root `package.json` entry + whatever shell wrapper it invokes) has no preflight that inspects `git log @{push}..HEAD`. It assumes a one-commit-per-push cadence that many real sessions do not follow — especially after `/wr-itil:work-problems` AFK loops, cross-session interactive work, or any case where the developer commits-then-pauses-then-commits-then-pushes.

GitHub Actions' own behaviour (CI fires on the push event against the tip SHA; no retroactive CI on reachable commits) is not changeable from this repo. The only leverage is in the push surface itself.

### Investigation Tasks

- [x] Confirm the hazard mechanism on this machine (P113 investigation — done; `gh run list --branch main` output shows the five-commit invisibility gap).
- [x] Read `scripts/push-watch.*` (or wherever `npm run push:watch` dispatches) to confirm current behaviour has no preflight. Architect decision needed on the preflight contract shape. — Previously inline in `package.json` `push:watch`; extracted to `scripts/push-watch.sh` per architect Q1 verdict.
- [x] Decide the preflight contract. **Architect verdict (session 2026-04-24): (a) warn-and-proceed.** Rationale: `push:watch` runs as a shell script with no TTY in the AFK drain path; ADR-013 Rule 6 mandates non-interactive fail-safe and Rule 5 says policy-authorised actions proceed silently. A hard-block contract would violate ADR-018's drain guarantee. Single-path warn-to-stderr preserves the contract and surfaces the hazard to interactive users who can Ctrl-C.
- [x] Decide the threshold + messaging. **Architect verdict (session 2026-04-24): N = 2.** Rationale: hazard is strictly-increasing in N; one invisible-to-CI commit (N=2) is exactly the P113 failure mode. Warning is stderr prose, zero blocking cost, so over-warning carries no operational cost — only signal value.
- [x] AFK compatibility. **Architect verdict (session 2026-04-24): single-path warn-and-proceed answers Q3 by construction.** The preflight never blocks, so there is no AFK vs interactive fork to take. ADR-019 preflight semantics are loop-start concerns; ADR-018/ADR-020's push:watch is a drain concern.
- [x] Add a bats contract-assertion that a simulated N ≥ 2 local-commit state triggers the preflight warning (RED first, then implement, then GREEN per TDD). — `packages/shared/test/push-watch-preflight.bats` (10 assertions, all green). `packages/shared/test/push-watch-anchoring.bats` retargeted at the extracted script (P060 anchoring contract preserved).
- [ ] Update REFERENCE / briefing docs. — briefing/releases-and-ci.md already carries the "Local commit accumulation between pushes masks CI regressions on intermediate commits" entry from P113's retrospective; REFERENCE update deferred until a second session observes the preflight firing in practice.

### Reproduction test

Behavioural: from a clean main on `origin/main == HEAD`, create two commits locally without pushing. Run `npm run push:watch`. Current behaviour: push proceeds silently; CI runs on tip only. Desired behaviour: preflight warns (or prompts per the chosen contract).

### Fix Strategy

**Shape**: **improvement to an existing script surface** (Option 3 — other codification shape). Target: `scripts/push-watch.*` + root `package.json` wiring. Not a new skill; this is a script-level preflight addition.

**Mechanism**:

```bash
# Pseudocode for the preflight
local_only_count=$(git log @{push}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$local_only_count" -ge 2 ]; then
  echo "WARNING: $local_only_count local-only commits will batch-push. Intermediate commits never ran origin CI."
  echo "Hidden regressions in commits 1..$((local_only_count - 1)) will be attributed to the tip commit by GitHub Actions."
  git log @{push}..HEAD --oneline
  # Interactive: AskUserQuestion (push all / push one at a time / abort and rebase-for-per-commit-push)
  # AFK: auto-proceed with warning recorded in the push log
fi
```

`@{push}` is git's push-ref for the current branch; when origin is reachable it resolves to the last pushed tip SHA. If `@{push}` is undefined (branch has never been pushed), the preflight can fall back to `origin/main..HEAD` or print a "this is a new branch; skipping preflight" note.

**Evidence**:
- 2026-04-24 observation: my P113 push batched six commits (2be1bfa..b2424c8); `gh run list --branch main --limit 15` output confirmed CI ran only on 6b76d13 and b2424c8, with the five intermediate commits invisible to CI.
- Test regression in commit 64f6d3f (flipped `action_class` assertions to negative and added prose mentioning `action_class`, creating a grep collision; `packages/risk-scorer/agents/test/risk-scorer-structured-remediations.bats` tests 699-701 became red) lived for one day between 2026-04-23 and 2026-04-24 before my P113 push surfaced it. A preflight warning at the time of 64f6d3f's commit author's next push would have flagged the multi-commit batch and prompted per-commit-push, surfacing the regression against 64f6d3f directly.

## Dependencies

- **Blocks**: confident blame attribution on batched-push CI failures. Does not block anything release-wise.
- **Blocked by**: architect decision on preflight contract shape (Q1-Q3 above).
- **Composes with**: P040 (origin-fetch preflight — closed), P109 (work-problems Step 0 prior-session state — open). P116's scope is orthogonal: both P040 and P109 cover orchestrator loop-entry; P116 covers push cadence across any sequence.

## Related

- **P040** (closed) — `work-problems` fetches origin at loop start. Adjacent preflight surface; P116 extends to the push cadence layer.
- **P109** (open) — `work-problems` Step 0 detects prior-session partial-work state (untracked files, stale worktrees). Adjacent session-continuity surface; P116 extends to origin-CI cadence.
- **P113** (closed) — where the hazard surfaced. P113's fix trajectory required two release cycles partly because the first cycle hit the uncovered 64f6d3f regression that the batched-push masked.
- **P074** (pipeline-instability-scan, run-retro Step 2b) — routed this observation into the ticket queue.
- **ADR-032** (governance skill invocation patterns) — AFK compatibility question (Q3 above) routes through this ADR.
- **briefing/releases-and-ci.md** — entry added this session: "Local commit accumulation between pushes masks CI regressions on intermediate commits."

## Fix Strategy (Stage 2 placeholder)

Stage 2 fix-strategy recording is pending user AskUserQuestion per run-retro Step 4b Stage 2. Candidate shape: Option 3 (Other codification shape — script improvement to `scripts/push-watch.*` + `package.json` wiring). Will be updated after the AskUserQuestion.

## Fix Released

Shipped in the same commit as this status transition (session 2026-04-24, AFK `/wr-itil:work-problems` iteration). Awaiting user verification.

**Changes:**
- `scripts/push-watch.sh` (new) — extracted the `push:watch` command body out of `package.json` and added the preflight block: counts `git rev-list --count @{push}..HEAD` (falling back to `origin/main..HEAD` when `@{push}` is undefined) and prints a stderr WARNING naming the hazard when the count is ≥ 2. Preserves the P060 anchoring contract (`--commit=$(git rev-parse HEAD)`, `|| exit $?`, `--branch main`, per-run exit-code propagation).
- `package.json` — `push:watch` now delegates to `bash scripts/push-watch.sh`.
- `packages/shared/test/push-watch-preflight.bats` (new) — 10 contract-assertions on the preflight surface, including the warn-and-proceed guarantee (push line must appear after the preflight block in source order so a future "exit on threshold" rewrite fails the test).
- `packages/shared/test/push-watch-anchoring.bats` — retargeted at `scripts/push-watch.sh` so the P060 anchoring contract is tested at the new location.

**ADR citations**: ADR-013 (Rule 5 policy-authorised silent proceed + Rule 6 non-interactive fail-safe), ADR-018 (inter-iteration release cadence), ADR-020 (governance auto-release for non-AFK flows), ADR-037 (contract-assertion skill testing — extended to shell-script packaging files), ADR-005 (plugin testing strategy — Permitted Exceptions for structural assertions).

**JTBD citations**: JTBD-002 (Ship AI-Assisted Code with Confidence — primary; CI signal now surfaces the regressing commit, not the innocent tip), JTBD-006 (Progress the Backlog While I'm Away — secondary; AFK orchestrators accumulate multi-commit batches and the warning becomes a post-hoc pointer in the push log).

**Verification in production**: the user's next `npm run push:watch` invocation with ≥ 2 local-only commits on the branch should print the WARNING block to stderr and proceed with the push. Exit code behaviour and P060 anchoring should remain unchanged. All 18 bats assertions across the two push-watch test files are green in-session (`npm test` summary: 790 ok / 0 not_ok).
