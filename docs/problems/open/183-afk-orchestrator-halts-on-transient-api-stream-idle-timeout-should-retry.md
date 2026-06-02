# Problem 183: AFK orchestrator halts on transient API stream-idle-timeout — should classify is_error reason and retry transient classes instead of halting the whole loop

**Status**: Open
**Reported**: 2026-05-11
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

`/wr-itil:work-problems` SKILL Step 5 exit-code semantics conflate two distinct subprocess failure classes:

1. **Unrecoverable** — auth failure, quota exhaustion, persistent permission denial, subprocess crash. Halting the loop is correct: user input needed to resolve.
2. **Transient transport-layer** — API stream-idle-timeout, network blip, intermittent CLI streaming hiccup. The subprocess work was making progress; retrying once or twice almost certainly succeeds.

Both classes surface in `claude -p --output-format json` as `is_error: true` in the JSON envelope (and typically a matching non-zero process exit). The current SKILL contract treats both identically: "Non-zero exit → halt the loop. Do NOT spawn the next iteration." This is correct for class 1, wrong for class 2.

User correction 2026-05-11 (verbatim):

> *"These sort of intermittent network issues should NOT trigger a halt. Create a problem ticket."*

### Concrete incident (2026-05-11)

AFK loop iter 3 working ticket P162 (new ADR draft for dogfood-graduation criteria) hit:

```
API Error: Stream idle timeout - partial response received
```

JSON envelope from `.afk-run-state/iter3-p162.json`:
- `is_error: true`
- `subtype: "success"` (success = clean process exit, not work success)
- `num_turns: 16`
- `duration_ms: 492187` (~8min 12s)
- `total_cost_usd: 2.31`
- stderr: empty
- Working tree clean afterwards (no partial commits)

Orchestrator halted the loop per SKILL Step 5, emitted final summary, and stopped. P162 work lost; $2.31 burned; 40+ remaining backlog tickets not progressed.

The cost asymmetry is the failure mode: a 30-second retry would have likely recovered the iter; instead the orchestrator burned a full session's accumulated context to a halt-with-report that required user-side restart of the entire loop.

## Symptoms

- Iter subprocess returns `is_error: true` with reason "API Error: Stream idle timeout - partial response received" (or similar transport-layer phrasing) → loop halts.
- Orchestrator final summary names the halt cause but provides no retry path.
- User must manually re-invoke `/wr-itil:work-problems` to resume; cost of partial-iter work is sunk.
- (deferred to investigation — other reasons under the same `is_error: true` umbrella may also be transient: 5xx upstream errors, rate-limit-with-retry-after, brief network partitions)

## Workaround

User manually re-invokes `/wr-itil:work-problems`. The reconcile preflight in Step 0 + the orchestrator's normal Step 1 backlog scan picks up where things left off (no state corruption since the failed iter's work didn't commit). Cost is the wasted partial-iter spend + the session-restart context overhead.

## Impact Assessment

- **Who is affected**: AFK-loop personas (JTBD-006 "Progress the Backlog While I'm Away"). Every long AFK session is exposed once the API surface hiccups even briefly.
- **Frequency**: (deferred to investigation — needs sampling; informally 1+ per AFK session of >1hr duration based on this iter's evidence + prior pattern.)
- **Severity**: Medium — work isn't lost (no commits land), but in-iter cost (~$2-7 per typical iter) is burned and the user-facing UX is "loop stopped because the network blinked".
- **Analytics**: count of `/wr-itil:work-problems` halts where final iter's JSON shows `is_error: true` with reason matching a transient classifier (stream timeout, transient network, retryable 5xx). Compare against the unrecoverable bucket (auth, quota, persistent denial).

## Root Cause Analysis

SKILL Step 5 "Exit-code semantics" paragraph:

> `claude -p` exits non-zero when the subprocess fails hard — subprocess crash, auth failure, unresolvable permission denial, API/quota exhaustion. The orchestrator reads the exit code BEFORE parsing `.result`:
> - Exit 0 → parse ITERATION_SUMMARY from `.result` field; proceed to Step 6.
> - Non-zero exit → halt the loop; report the exit code, stderr, and any partial `.result` in the final summary. Do NOT spawn the next iteration.

The enumeration of "fails hard" causes implies an unrecoverable framing, but the actual `claude -p` CLI exits non-zero (and writes `is_error: true`) on a much broader set of conditions including transient streaming errors. The SKILL took the conservative position that ANY non-zero is halt-worthy — appropriate when the failure-class taxonomy is opaque, but unnecessarily defensive once a transient class is concretely observed.

The architectural parallel is Step 6.5's P140 "Failure handling" amendment: the original uniform-halt rule was relaxed to a closed allow-list of mechanically-fixable failure classes with fix-and-continue routing (P081-class stale-grep-string, hook stub mismatch, test ID drift, environmental flake) + 3-retry cap. The same shape applies here: a closed allow-list of retryable `is_error` reason classes (stream-idle-timeout, transient network, retryable 5xx) with retry-with-backoff + bounded retry cap, halt for everything else.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Catalog observed `is_error: true` reason strings from `.afk-run-state/iter*.json` corpus. Classify each into retryable-transient vs unrecoverable. Document the closed allow-list in SKILL Step 5.
- [ ] Design the retry mechanism: backoff schedule (1min / 5min / 15min?), retry cap (3 per iter per session-of-work-problems), retry-budget accounting (do retries roll over across iters? — probably no, per-iter cap).
- [ ] Decide retry-vs-skip routing: does a retried iter that fails 3x in a row halt the whole loop (matching P140 3-retry-cap behaviour), or skip to the next ticket (matching Step 4's user-answerable skip-reason pattern)?
- [ ] Update SKILL Step 5 "Exit-code semantics" with the new classifier + retry path. Cross-reference P140 as the architectural sibling.
- [ ] Add behavioural bats coverage: fake `claude -p` shim that emits each retryable-transient reason; assert orchestrator retries; assert non-retryable reasons still halt.
- [ ] Audit related skills (`/wr-itil:manage-problem`, `/wr-itil:transition-problems`, `/wr-itil:work-problem`) — do their dispatch surfaces have the same conflation?

## Dependencies

- **Blocks**: AFK loop reliability for long sessions; JTBD-006 "Progress the Backlog While I'm Away" outcome 1 ("loop continues until natural stop"). Without this, every transient API blip is a forced loop restart.
- **Blocked by**: (none)
- **Composes with**: P140 (Step 6.5 fix-and-continue closed allow-list — architectural sibling for the failure-classification + retry-cap pattern), P121 (idle-timeout SIGTERM — separate transient-recovery surface at the orchestrator-side rather than subprocess-side), P147 (SIGTERM stuck-before-emit subclass — also exit-code-semantics adjacent)

## Related

- `packages/itil/skills/work-problems/SKILL.md` Step 5 "Exit-code semantics" — surface to amend.
- `packages/itil/skills/work-problems/SKILL.md` Step 6.5 "Failure handling" (P140) — architectural sibling pattern to mirror.
- P140 (`docs/problems/*p140-*.md`) — closed allow-list + fix-and-continue + 3-retry-cap precedent.
- P121 (`docs/problems/closed/121-afk-orchestrator-should-sigterm-stuck-subprocesses-after-idle-timeout.md`) — orchestrator-side transient recovery (SIGTERM on idle).
- P147 (`docs/problems/*p147-*.md`) — SIGTERM stuck-before-emit subclass; related metadata-loss surface.
- `.afk-run-state/iter3-p162.json` — concrete incident JSON envelope (preserved for the SKILL Step 5 classifier-design investigation task).
- Captured via /wr-itil:capture-problem; expand at next investigation.
