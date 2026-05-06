# Problem 143: `release-watch.sh` race condition — `gh pr list` queries before changesets/action GitHub workflow has created the release PR

**Status**: Verification Pending
**Reported**: 2026-04-29
**Priority**: 6 (Med) — Impact: Minor (2) x Likelihood: Likely (3) — observed multiple times today; user-visible friction (failed exit, retry required)
**Effort**: S — `scripts/release-watch.sh` add a poll loop on `gh pr list` (e.g. up to 120s with 10s intervals) before exiting on "no open release PR found". Plus matching behavioural bats per ADR-037 + P081.
**WSJF**: 0 (excluded — Verification Pending per ADR-022)
**Type**: technical

> Surfaced 2026-04-28 during `/wr-itil:work-problems` Step 6.5 drains. First `release:watch` invocation immediately after `push:watch` returned `No open release PR found (changeset-release/main -> main)` with exit 1; manual `gh pr list --state open --base main --head changeset-release/main` ~2 min later showed PR #99 OPEN. Re-invocation succeeded. Same race surfaced again briefly during the `@windyroad/itil@0.23.0` drain.

## Description

`scripts/release-watch.sh` calls `gh pr list --head changeset-release/main --base main --state open --limit 1 --json number,url`. When invoked **immediately** after a `push:watch` cycle that landed new changesets on main, the GitHub Actions changesets/action workflow is still running — it hasn't yet created or updated the `changeset-release/main` PR. The `gh pr list` query returns empty. The script exits 1 with `No open release PR found`.

The race window is ~30-60 seconds: changesets/action workflow latency from `push` to `gh pr` creation/update.

The orchestrator's recovery is straightforward (re-invoke `release:watch` after a delay), but the failure mode is non-obvious to users and produces a confusing "no PR" error message that contradicts the visible state in the GitHub UI moments later.

## Symptoms

- `npm run release:watch` exits 1 with `No open release PR found (changeset-release/main -> main). Has it already been merged, or are there no pending changesets?`
- `npm view @windyroad/itil version` shows the prior version (release didn't ship)
- Manual `gh pr list` 30-120s later shows the release PR OPEN
- Re-invoking `release:watch` succeeds
- The `npm run release:watch | tee` pattern (used by orchestrators) returns exit 0 because tee doesn't propagate the script's exit code — masks the failure unless caller specifically checks the log content

## Workaround

Wait 30-120s after `push:watch` completes before invoking `release:watch`. Manual delay; no automation.

## Impact Assessment

- **Who is affected**: every `/wr-itil:work-problems` Step 6.5 drain; every `/wr-itil:manage-problem` Step 12 auto-release; manual `release:watch` invocations.
- **Frequency**: every release cycle where the user invokes `release:watch` immediately after `push:watch`. Most cycles.
- **Severity**: Minor. Not a hard block (recoverable by retry). Adds confusion — error message contradicts GitHub UI state.
- **Likelihood**: Likely. The race window is wide enough (30-120s) that quick retries hit it routinely.
- **Analytics**: 2026-04-28 session — race fired at least twice (release for `@windyroad/itil@0.22.1` first attempt at 17:28; recovered on retry at 17:32. Same pattern surfaced briefly during `@windyroad/itil@0.23.0` drain.)

## Root Cause Analysis

### Investigation Tasks

- [ ] Audit `scripts/release-watch.sh` Step 1 (lines 40-48 — `gh pr list` query + empty-result deny). Confirm the script exits immediately on empty `gh pr list` without any wait/poll.
- [ ] Decide poll-loop bounds:
  - **Wait window**: 120s (covers worst-case changesets/action latency observed in this session).
  - **Poll interval**: 10s (cheap; avoids hammering GitHub API).
  - **Max iterations**: 12 (= 120s / 10s).
- [ ] Decide poll-loop semantics:
  - On empty `gh pr list`, sleep 10s and retry.
  - On 12 consecutive empty results, exit 1 with the existing `No open release PR found` message + new addition: "Polled for 120s. The changesets/action workflow may have failed to open a release PR — check Actions tab."
  - On non-empty result, proceed to existing `gh pr merge` flow.
- [ ] Add a verbose-mode flag (`--verbose` or env var) to print poll progress so the user can see the script is actively polling, not stuck.
- [ ] Behavioural bats per ADR-037 + P081 covering: empty `gh pr list` for full 120s (exit 1 with new message); `gh pr list` becomes non-empty mid-poll (proceed to merge); `gh pr list` returns the PR immediately (no poll, fast path).

### Preliminary hypothesis

The script was authored for the synchronous case (release PR exists at invocation time). The asynchronous changesets/action workflow timing creates a race window the script doesn't handle. Adding a bounded poll loop is a minimal change (~10 lines of bash) that closes the race deterministically.

## Fix Strategy

**Kind**: improve

**Shape**: shell-script (existing at `scripts/release-watch.sh`)

**Target file**: `scripts/release-watch.sh`

**Observed flaw**: Step 1 (lines 40-48) exits immediately on empty `gh pr list`. Doesn't account for changesets/action workflow latency (~30-120s between push and PR creation/update).

**Edit summary**: wrap the `gh pr list` query in a poll loop. Up to 12 iterations × 10s = 120s. Exit 1 only after the full 120s of empty results. Add verbose-mode progress output. Behavioural bats per ADR-037 + P081.

**Evidence**: 2026-04-28 session — race fired at ~17:28 (release for 0.22.1); manual recovery by re-invoking `release:watch` 2 min later. Pattern surfaced again briefly during 0.23.0 drain.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P140 (Step 6.5 fix-and-continue — release-path failures could include this race; P140's "environmental flake" allow-list class includes this pattern), P054 (push-watch / release-watch reporting on stale SHA — sibling family of release-script timing bugs)

## Related

- **P140** (`docs/problems/140-...verifying.md`) — fix-and-continue on CI failure; this race is one of the "environmental flake" cases P140's allow-list captures.
- **P054** (`docs/problems/054-...closed.md`) — release-watch SHA-mismatch family; P143 is a different timing bug at the same surface.
- **scripts/release-watch.sh** — the target file.
- **ADR-018** — release cadence; P143 refines `release:watch` reliability.
- **ADR-022 fold-fix amendment (2026-04-29)** — this commit's transition follows the new "Open → Verification Pending in one commit" path documented in ADR-022's `## Fold-fix Open → Verification Pending in one commit` section; cited as a precedent.
- 2026-04-28 session evidence: race fired at ~17:28 (release for 0.22.1) and again briefly during the 0.23.0 drain. Manual recovery via retry.

## Fix Released

Released in the same commit (fold-fix Open → Verification Pending per ADR-022 amendment, 2026-04-29). Awaiting user verification on the next `/wr-itil:work-problems` Step 6.5 drain or manual `npm run release:watch` invocation immediately after `npm run push:watch`.

**What changed**:

- `scripts/release-watch.sh` — added `find_release_pr` shell function wrapping `gh pr list` in a 12-attempt × 10s = 120s poll loop. The function emits a tab-separated `<number>\t<url>` on success; exits 1 only after the full 120s of empty results. Verbose progress to stderr gated on `RELEASE_WATCH_VERBOSE=1`. The empty-poll exit message now points at the Actions tab so the user can investigate workflow failures directly.
- `packages/itil/scripts/test/release-watch-poll-loop.bats` — behavioural bats per ADR-037 + P081. Awk-extracts `find_release_pr`, sources it, PATH-shadow-mocks `gh` with comma-delimited iteration sequences ("ok", "empty,empty,ok", 12×"empty"), stubs `sleep` to count without burning wall-clock. Asserts: fast-path one-call no-sleep on immediate PR; three-call two-sleep on iteration-3 PR; 12-call 11-sleep exit-1 on full-empty; verbose-mode-on prints progress; default-off does not; tab-separated parseable output.

**Verification path**: next session-end release drain (`/wr-itil:work-problems` Step 6.5) should no longer surface the "No open release PR found" race against changesets/action workflow latency. The orchestrator's first `release:watch` invocation after `push:watch` should poll silently up to 120s and proceed once the PR appears, instead of exiting 1 on the first empty query.

**Exercise evidence**: bats green 7/7 in this iteration. End-to-end exercise will land on the next AFK release-drain cycle this session or in a subsequent session — at which point the user can transition this ticket to Closed.
