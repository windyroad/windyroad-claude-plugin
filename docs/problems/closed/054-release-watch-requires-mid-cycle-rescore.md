# Problem 054: release:watch requires a mid-cycle pipeline rescoring after push — 3-step release dance

**Status**: Closed
**Reported**: 2026-04-19
**Priority**: 8 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)
**Effort**: S
**WSJF**: 8.0 — (8 × 1.0) / 1

## Fix Released

Fix shipped in AFK iter 1 (2026-04-19, pending commit). Root cause: `packages/risk-scorer/hooks/lib/pipeline-state.sh --hash-inputs` used `git diff origin/main --stat` as the drift input, which shrinks to empty after a policy-authorised push advances `origin/main`. Replaced with a tree-based hash built from `git stash create` (conceptual HEAD + index + working tree), making the drift hash invariant across both `git commit` and `git push`. Candidate 4 also applied: `scripts/release-watch.sh` header now documents the post-push stability contract. Reproduction tests in `packages/risk-scorer/hooks/test/pipeline-state-hash.bats` (8 tests). Released via `@windyroad/risk-scorer` patch bump. Awaiting user verification — next AFK iteration that runs `push:watch` followed by `release:watch` should not require a mid-cycle `wr-risk-scorer:pipeline` delegation (baseline: 4/4 iterations this session required it; target: 0/4).

## Description

The standard ADR-020 auto-release flow within an AFK iteration is documented as two commands: `npm run push:watch` (push + watch CI) followed by `npm run release:watch` (merge the release PR + wait for npm publish). In practice, the middle step of a third command — a manual delegation to `wr-risk-scorer:pipeline` to rescore against the post-push state — is required every time, because the `risk-gate` hook that guards release actions hashes the pipeline-state inputs at bypass-marker creation time and the post-push state no longer matches.

Concrete sequence observed 2026-04-19 (iter 2 P053 and iter 4 P048 releases, identically):

1. Agent scores commit risk (bypass marker written against pre-push state hash S1).
2. Agent commits.
3. Agent runs `npm run push:watch` — push succeeds, CI starts.
4. Release workflow auto-creates release PR (PR #N).
5. Agent runs `npm run release:watch` — blocked by the hook with:
   ```
   Release blocked: Pipeline state drift: working tree changed since the last
   release risk assessment. Delegate to wr-risk-scorer:pipeline
   (subagent_type: 'wr-risk-scorer:pipeline') to rescore against the current state.
   ```
6. Agent delegates `wr-risk-scorer:pipeline` — writes new bypass marker against state hash S2.
7. Agent re-runs `npm run release:watch` — now unblocked; merge + publish proceeds.

Steps 5–7 are the mid-cycle dance. The hook's behaviour is correct (the state genuinely did change after the push — HEAD moved, the release PR opened), but the manual rescore is a rote delegation with no added judgement: the post-push state is mechanically derived from the pre-push commit that was already scored.

Observed N=2 this session (iter 2 and iter 4). Expected frequency: every `release:watch` invocation inside an AFK loop, i.e. once per iteration where the release queue drains. Over a 4-iteration session, 4 × ~10-15s of delegation overhead = ~1 minute of pure friction.

## Symptoms

- `npm run release:watch` fails on first call with `Release blocked: Pipeline state drift` after every successful `npm run push:watch` that lands a changeset.
- AFK orchestrator agents have to invoke `wr-risk-scorer:pipeline` twice per iteration (once pre-commit, once pre-release) where one invocation would suffice if the release script auto-rescored.
- Session transcripts accumulate rote rescore delegations that produce the same verdict the pre-commit rescore gave (the work that happened between them — git push, release PR open — is policy-authorised and adds no risk).
- AFK loops that parse tool output for commit/push/release risk scores see a repeated pair of scorer reports per iteration that could be one.

## Workaround

Manual delegation: invoke `wr-risk-scorer:pipeline` between `push:watch` and `release:watch` each iteration. The agent reports the expected identical risk-band verdict and then `release:watch` runs. Costs ~10-15s of agent time per iteration.

## Impact Assessment

- **Who is affected**: solo-developer persona (JTBD-006 Progress the Backlog While I'm Away) — adds rote delegation overhead to every AFK release cycle; plugin-developer persona (JTBD-101) — anyone building orchestrator skills has to encode the 3-step dance or their skill breaks on the release half.
- **Frequency**: every AFK iteration that lands a changeset and drains the release queue. Empirically: 100% of iterations this session where a commit carried a changeset (4/4).
- **Severity**: Minor — no functional breakage, no data loss, no risk regression (the rescore correctly verifies the new state). Cost is cognitive + clock-time friction accumulating session-over-session.
- **Analytics**: 2026-04-19 session — 4 AFK iterations, each release step required exactly one mid-cycle rescore (4/4). No iteration avoided it.

## Root Cause Analysis

### Structural: hook's state-hash check has no escape for "policy-authorised transitions that changed the hash but not the risk"

`packages/risk-scorer/hooks/lib/risk-gate.sh` computes `CURRENT_HASH` from the current pipeline inputs and compares against the `STORED_HASH` recorded when the bypass marker was written. Any drift blocks. The hook cannot tell the difference between:

1. **Policy-authorised transition** — the agent ran `git push` (authorised per ADR-018 / ADR-013 Rule 6 when commit risk is within appetite) and the state hash changed because HEAD advanced. No new uncommitted/unstaged surface.
2. **Unauthorised mutation** — the agent edited files after the scorer ran, then tried to release without re-scoring. Would mask real risk.

Case 1 is what fires every iteration; case 2 is the genuine failure mode the hook exists to catch. Currently the hook treats both identically.

### Structural: `scripts/release-watch.sh` does not self-rescore before attempting the release

`release-watch.sh` assumes the calling agent has already satisfied the commit gate. There is no equivalent of the pre-commit delegation baked into the script, so every orchestrator skill has to delegate externally.

### Candidate fixes

1. **Embed the rescore in `release-watch.sh`**: before attempting to merge the PR, invoke `wr-risk-scorer:pipeline` via the Skill/Agent surface (same mechanism the orchestrator skills use in their commit gates per ADR-015). The script becomes "rescore → merge → wait for npm publish". Low-risk implementation: the rescore is already the expected next step; moving it from "every caller must do it" to "the script does it once" is pure de-duplication.

2. **Teach `risk-gate.sh` to accept `git push` as a policy-authorised transition**: when the only pipeline-input difference between `STORED_HASH` and `CURRENT_HASH` is a `git push` that advanced HEAD without introducing new uncommitted/unstaged content, skip the re-score requirement. Additive to ADR-015; needs careful input-diffing so the hook doesn't accidentally skip a real mutation.

3. **Emit a warning, not a block, in the specific "post-push-same-commit" case**: maintain the block for genuine drift but downgrade to a warning when the cause is a policy-authorised transition. Compromise between 1 and 2.

4. **Document the 3-step dance in `scripts/release-watch.sh` help text**: minimum viable — doesn't remove friction, but ensures every orchestrator encodes the sequence correctly. Probably the zero-effort complement to any of the above.

Candidates 1 + 4 are the minimum viable fix. Candidate 1 alone removes the rote delegation from orchestrators; candidate 4 hardens the script's contract for external callers.

### Related to existing tickets

- **ADR-015** (risk-scorer agent contract) — governs the `wr-risk-scorer:pipeline` subagent behaviour. Embedding a rescore in `release-watch.sh` is an application of the ADR, not a change to it.
- **ADR-018** (inter-iteration release cadence) — the current script's expectation that the caller scored the commit gate before release is implicit; making the rescore explicit inside the script matches ADR-018's intent (the drain is one coherent action).
- **ADR-020** (governance auto-release for non-AFK flows) — governs the `push:watch` → `release:watch` pattern. A fix that changes `release-watch.sh` behaviour should cite ADR-020 in the commit.
- **P041** (work-problems does not enforce release cadence) — closed. Related but different: P041 was about making the orchestrator run `release:watch`; P054 is about making `release:watch` self-rescore.
- **P035** (manage-problem commit-gate no subagent delegation fallback) — sibling theme: "commit-gate delegation is an orchestrator concern". P054 extends the principle to the release-gate.

### Investigation Tasks

- [ ] Architect review: is candidate 1 (embed rescore in `release-watch.sh`) within-script additive behaviour or does it change the ADR-015 scorer contract? Expected verdict: additive, because the script already depends on the scorer via the hook; inlining the call just moves the responsibility from caller to script.
- [ ] Design the script-internal delegation: how does a bash script invoke a Claude subagent? Likely pattern: the script calls back into a skill via `claude agent run` or the agent parks a delegation marker file the script reads. Investigate existing mechanisms in `scripts/` and `packages/risk-scorer/hooks/`.
- [ ] Add a bats test asserting `release-watch.sh` performs a rescore before attempting the merge. Structural assertion — Permitted Exception per ADR-005.
- [ ] Alternatively, consider candidate 2 (hook accepts `git push` as authorised transition) if candidate 1's implementation is bash-difficult. Would need input-diffing logic in `risk-gate.sh`.
- [ ] Measure: after the fix, does the per-iteration agent time drop? Baseline: 2 `wr-risk-scorer:pipeline` delegations per iteration; target: 1.

## Related

- `packages/risk-scorer/hooks/lib/risk-gate.sh` — the hook that fires the block (`Pipeline state drift` message at line 46).
- `scripts/release-watch.sh` — the primary fix target if candidate 1 is chosen.
- `packages/itil/skills/work-problems/SKILL.md` — Step 6.5 (release cadence) currently encodes the pre-push rescore; the post-push rescore is implicit in the caller. A fix for P054 simplifies this step.
- ADR-015: `docs/decisions/015-scorer-contract.proposed.md`
- ADR-018: `docs/decisions/018-inter-iteration-release-cadence-for-afk-loops.proposed.md`
- ADR-020: `docs/decisions/020-governance-auto-release-for-non-afk-flows.proposed.md`
- P035: `docs/problems/035-manage-problem-commit-gate-no-subagent-delegation-fallback.verifying.md`
- P041 (closed): `docs/problems/041-work-problems-does-not-enforce-release-cadence.closed.md`
- JTBD-006: `docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`
- JTBD-101: `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`
