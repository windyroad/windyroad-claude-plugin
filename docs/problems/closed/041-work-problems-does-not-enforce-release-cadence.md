# Problem 041: work-problems does not enforce release cadence

**Status**: Closed
**Reported**: 2026-04-18
**Priority**: 16 (High) — Impact: Significant (4) x Likelihood: Likely (4)
**Effort**: L (architect requires ADR-018 prerequisite before SKILL.md change ships)
**WSJF**: 8.0 (16 × 2.0 / 4)

## Fix Released

Released in `@windyroad/itil@0.4.1` (commit `87c2ecf`, release tag merged
2026-04-18). Step 6.5 now appears in `packages/itil/skills/work-problems/SKILL.md`.

Awaiting user verification: run an AFK loop that accumulates >= 1 patch
changeset and confirm the orchestrator drains the queue (push:watch +
release:watch) before starting the next iteration.

## Description

The `wr-itil:work-problems` AFK orchestrator keeps iterating through problems
even when its own risk-scoring would advise stopping to release first. The
lean-release principle (and P034) require that unreleased changesets stay
within risk appetite. The scorer flags the accumulation via `push` and
`release` score layers, but the orchestrator has no control loop that stops
and releases when the queue hits the appetite threshold (4/25 per
RISK-POLICY.md).

Observed 2026-04-18: in a single AFK loop I worked four scorer-prompt
tightening fixes (P041 → P037 → P038 → P043 in local numbering). Each
successive commit added a patch changeset to `.changeset/`. On the fourth
iteration, the commit-risk score hit 4/25 (at appetite). The loop continued
into a fifth iteration (P036). The user had to manually interrupt with "make
sure you release to avoid going over risk appetite. I shouldn't have to tell
you this" before the loop would stop and ship.

## Symptoms

- 3+ patch changesets accumulate in `.changeset/` without release
- Risk-scorer commit/push scores rise into the Low band (3-4) or Medium (5+)
- Orchestrator continues to spawn new iterations regardless
- User intervention required to force release before the queue exceeds
  appetite
- Downstream consumers receive a batch release with multiple unrelated
  changes instead of small, frequent releases

## Workaround

Manually monitor the risk-scorer's reports between iterations. When commit
or push score enters the Low band, stop the loop, run `npm run push:watch`
followed by `npm run release:watch`, wait for the release to land on npm,
then resume.

## Impact Assessment

- **Who is affected**: Any AFK user relying on `work-problems` to self-pace;
  any downstream consumer of the plugins (batch releases vs lean-release
  principle)
- **Frequency**: Every AFK loop that runs more than ~2-3 iterations on a
  package with patch-level fixes
- **Severity**: Significant — violates the lean-release principle the
  risk-scorer framework is designed to enforce; creates exactly the failure
  mode P034 describes; erodes user trust when the user has to step in to
  release
- **Analytics**: Count patch changesets committed per AFK loop; compare
  against count of releases shipped in the same window

## Root Cause Analysis

### Confirmed Root Cause (2026-04-18)

Source-code evidence from `packages/itil/skills/work-problems/SKILL.md`:

- **Stop conditions (lines 26–33)** are exclusively about backlog state:
  (1) no actionable problems, (2) remaining problems require interactive
  input, (3) remaining problems are blocked. None reference pipeline state,
  changeset count, push score, or release score.
- **Step 7 — Loop (lines 99–101)** unconditionally returns to step 1 after
  each iteration. There is no inter-iteration check on `.changeset/`
  contents, unpushed commits, or the most recent risk-scorer report.
- **Non-Interactive Decision Making table (lines 107–114)** has rows for
  multi-concern split, scope expansion, commit gating, and verification
  needed — but no row for "release queue at appetite".

The orchestrator therefore has no mechanism to detect or respond to the
exact failure described in P034 (cumulative push/release risk). The
preliminary hypothesis is confirmed.

### Architect Verdict (2026-04-18)

The fix as scoped requires a new ADR before the SKILL.md change can ship:

> ADR-018: Inter-iteration release cadence for AFK loops.
> AFK orchestrators MUST drain the release queue when unreleased-change
> risk reaches appetite (per RISK-POLICY.md) before starting a new
> iteration. The check must delegate to `wr-risk-scorer:assess-release`
> rather than re-implementing scoring (preserves the pure-scorer contract
> from ADR-015). The skill may invoke `npm run push:watch` then
> `npm run release:watch` non-interactively per ADR-013 Rule 6 (this
> action is policy-authorised by RISK-POLICY.md, so no `AskUserQuestion`
> is needed). Scope is cross-cutting — applies to any future AFK loop
> (e.g., `work-incidents`), not just work-problems. Cross-link P028
> (auto-release/install) and P040 (fetch origin).

This raises the effort from M to L. WSJF = (16 × 2.0) / 4 = **8.0**
(unchanged numerically because the status multiplier rises from 1.0 to
2.0 at the same time as effort drops from M to L — coincidence, not a
no-op).

### JTBD Verdict (2026-04-18)

PASS — advances JTBD-006 (Progress the Backlog While I'm Away). The
behaviour is implicit in JTBD-006's audit-trail and risk-appetite
desired outcomes; no persona update required, but consider appending a
desired-outcome bullet to JTBD-006 explicitly covering release cadence:
"Releases happen automatically when unreleased-change risk reaches
appetite."

P034 (release risk accumulation) covers the underlying enforcement mechanism
in the scorer itself; this ticket covers the orchestrator-level response to
that signal.

### Fix Strategy (post-architect-review)

Ship in this order:

1. **ADR-018 — Inter-iteration release cadence for AFK loops** (prerequisite)
   - Path: `docs/decisions/018-inter-iteration-release-cadence-for-afk-loops.proposed.md`
   - Rule: AFK orchestrators MUST drain the release queue when the next
     iteration would push commit/push/release risk to or above appetite
     (4/25 per RISK-POLICY.md), before starting that iteration.
   - Mechanism: delegate to `wr-risk-scorer:assess-release` (preserve the
     pure-scorer contract from ADR-015). Do NOT re-implement scoring inside
     work-problems.
   - Non-interactive authorisation: per ADR-013 Rule 6, the release action
     is policy-authorised by RISK-POLICY.md, so no `AskUserQuestion` is
     required to proceed.
   - Scope: cross-cutting — applies to any future AFK orchestrator
     (e.g., `work-incidents`), not just work-problems. Cross-link P028
     (auto-release/install) and P040 (fetch origin).

2. **Update `packages/itil/skills/work-problems/SKILL.md`** (after ADR-018)
   - Insert a new step between current step 6 (Report progress) and step 7
     (Loop): "Step 6.5 — Release-cadence check". Logic: invoke
     `wr-risk-scorer:assess-release`; if push or release score ≥ appetite
     band, run `npm run push:watch` then `npm run release:watch`, wait for
     release to land, then continue.
   - Add a stop-condition variant: "Release queue at appetite — released
     and resuming" (a pause, not a terminal stop).
   - Add a row to the Non-Interactive Decision Making table:
     `Pipeline risk at appetite | Drain release queue before next iteration`.

3. **Optional desired-outcome update to JTBD-006** (non-blocking)
   - Path: `docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`
   - Append: "Releases happen automatically when unreleased-change risk
     reaches appetite."

4. **Reproduction test (deferred)**
   - A bats test that asserts `work-problems/SKILL.md` references both
     `assess-release` and `release:watch` in its inter-iteration logic.
   - Defer until ADR-018 lands so the assertion target is stable.

### Workaround (non-permanent)

The user (or this skill operator) manually applies the rule via the
feedback memory entry `feedback_release_cadence.md`: fetch origin before
starting; release when commit risk hits appetite. Operator vigilance is
the workaround until the fix ships.

### Investigation Tasks

- [x] Confirm the orchestrator has no current hook into the pipeline-state
      scorer report (confirmed via SKILL.md source read, 2026-04-18)
- [x] Architect review (ALIGNMENT — ADR-018 required as prerequisite)
- [x] JTBD review (PASS — advances JTBD-006)
- [x] Author ADR-018 (2026-04-18, commit a530912)
- [x] Determine whether `release:watch` can run non-interactively on
      failure paths — decided: stop the loop and report, no retry
      (codified in Step 6.5)
- [x] Create reproduction bats test
      (`packages/itil/skills/work-problems/test/work-problems-release-cadence.bats`,
      7 assertions covering ADR-018 confirmation criteria)
- [x] Implement the SKILL.md change (Step 6.5 added between Step 6 and
      Step 7; Non-Interactive Decision Making table updated with
      pipeline-risk-at-appetite row)
- [ ] Create INVEST story for permanent fix — N/A (Step 6.5 IS the fix;
      no further breakdown needed)
- [ ] User verification: run an AFK loop that accumulates >= 1 patch
      changeset and confirm the orchestrator drains the queue before
      starting the next iteration

## Related

- P040: work-problems does not fetch origin before starting — companion
  issue from the same incident
- P034: Risk scorer ignores release risk accumulation — scorer-layer
  equivalent; this ticket is the orchestrator-layer response to the signal
  P034 provides
- P039: Autonomous loops conflate diagnose with implement — broader
  autonomy-pattern concern; this ticket is a narrower orchestrator cadence
  issue
- `/Users/tomhoward/.claude/projects/-Users-tomhoward-Projects-windyroad-claude-plugin/memory/feedback_release_cadence.md`
  — personal feedback memo with the rule of thumb
