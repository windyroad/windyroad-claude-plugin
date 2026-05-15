# Problem 200: wr-voice-tone:agent returns blanket FAIL when docs/VOICE-AND-TONE.md is missing

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

> **safe-high-fix-risk flag** (per dual-axis-risk classifier): the proposed "fail-open with prompt" option would change a gate from blanket-FAIL to fail-open in the missing-policy-file branch, which weakens voice-tone enforcement for all adopters who haven't yet opted in. The alternate "self-bootstrap on first run" option additionally aligns with "Adopter-attack-surface expansion" (hook-driven write into adopter repos). Maintainer should weigh gate-strength-vs-adopter-friction before picking an implementation path.

## Description

`@windyroad/voice-tone`'s `wr-voice-tone:agent` subagent returns blanket FAIL on every invocation in projects that do not have `docs/VOICE-AND-TONE.md`. The agent's reported reason: "the guide is missing and must be created before this copy can be approved".

The gate is wired correctly (it runs on every commit-gate flow and on `gh issue create` per ADR-028), but its input artefact is absent and the agent has no graceful path. There are two reasonable upstream behaviours, neither implemented today:

1. **Self-bootstrap on first run** — when `docs/VOICE-AND-TONE.md` is missing, the agent could invoke `/wr-voice-tone:update-guide` (or equivalent bootstrap path) inline rather than fail. This matches the framing "the plugin should self bootstrap".
2. **Fail-open with prompt** — when the guide is missing, treat the gate as PASS-with-warning and emit a one-line `Run /wr-voice-tone:update-guide to enable voice-tone reviews` message. Adopter projects that haven't opted in to voice-tone shouldn't be blanket-blocked.

Either is an improvement over the current blanket FAIL.

## Symptoms

- Every commit-gate flow that delegates to `wr-voice-tone:agent` in a project without `docs/VOICE-AND-TONE.md` returns FAIL.
- The FAIL is meta-level — content reviews PASS independently — so the FAIL becomes background noise that has to be ignored manually.
- Observed 6+ times across a single 2026-05-13 work-problems session (3 iter subprocess commits + 3 follow-up commits), always overridden.

## Workaround

For the dry-aged-deps project (downstream witness), `docs/VOICE-AND-TONE.md` was bootstrapped via `/wr-voice-tone:update-guide` to close the gap locally. The upstream improvement still benefits every other adopter project that hasn't opted in yet.

## Impact Assessment

- **Who is affected**: every adopter project without `docs/VOICE-AND-TONE.md` — JTBD-003 (Compose Only the Guardrails I Need) violation (per JTBD classifier).
- **Frequency**: every commit-gate flow in such projects.
- **Severity**: Moderate — gate's signal-to-noise degraded; adopters learn to ignore the FAIL, which weakens its protective effect.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Architect call: weigh the safe-high-fix-risk concerns (load-bearing-safety-removal on fail-open / adopter-attack-surface-expansion on self-bootstrap) against the JTBD-003 violation. Likely outcome: hybrid (Option B fail-open default + Option A behind `--auto-bootstrap` flag).
- [ ] Implement chosen option in `packages/voice-tone/agents/voice-tone.md` + `packages/voice-tone/hooks/external-comms-gate.sh` missing-guide branch.
- [ ] Behavioural test for the missing-guide path.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P038 (voice-tone external-comms gate — same evaluator), P064 (closed — external-comms parent gate), P124 (wr-voice-tone:agent guide-missing handling — sibling concern from a different invocation context).

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/124 (filed 2026-05-13 from downstream voder-ai/dry-aged-deps project ticket P005).
- **Pipeline classification** (review-problems Step 4.5e): JTBD-alignment=aligned-with-existing-JTBD (JTBD-003 + JTBD-001); dual-axis-risk=**safe-high-fix-risk** (cache_audit_note: high-fix-risk-flag — surfaces at next interactive review); route=safe-and-valid + flag.
- **Affected plugin**: @windyroad/voice-tone.
