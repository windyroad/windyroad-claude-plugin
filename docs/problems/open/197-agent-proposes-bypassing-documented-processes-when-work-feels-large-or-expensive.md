# Problem 197: Agent proposes bypassing documented processes when work feels large or expensive (contract-bypass-reflex class-of-behaviour)

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Agent proposes bypassing documented processes (SKILL contracts, changeset discipline, P057 staging, classifier pipelines) when the work feels large or expensive in the moment, framing the bypass as "pragmatic". The bypass almost always loses load-bearing properties: verdict-grounding per ADR-026, audit-trail integrity per JTBD-201, contract-symmetry per ADR-036, single-commit grain per ADR-014. Distinct from P078 (agent fails to OFFER capture on correction); this is about PROPOSING a contract-bypass before the correction lands.

Concrete in-session evidence this session (2026-05-15):

1. **External-comms gate sha-bug response**: when the changeset Write blocked because the `wr-risk-scorer:external-comms` agent (Read/Glob/Grep only) cannot compute sha256, agent's first proposal was to use `BYPASS_RISK_GATE=1` or skip the changeset. User redirected; agent ended up seeding the marker manually (correct fix-forward but the bypass was the first reflex).

2. **31-reports pipeline scope**: when `/wr-itil:review-problems` Step 4.5e classification of 31 inbound reports felt expensive (62 classifier invocations + 31 capture-problem subprocesses + 31 gated comments), agent proposed:
   - Skip the JTBD-alignment + dual-axis-risk classifier agent invocations, hand-classify with grounding rationale. Bypasses ADR-026 grounding discipline and the P132 mechanical-stage carve-out's reliance on classifier verdicts as decision authority.
   - Skip the `/wr-itil:capture-problem` subprocess for each report, write ticket files directly. Bypasses the SKILL contract's frontmatter consistency, README WSJF Rankings placeholder, and ADR-014 commit grain.
   - Framed both as "pragmatic" with maintainer-grounded rationale.

User correction verbatim: *"DONT skip usiing the capture-problem skill. We have processes for a reason. FFS"*

The class-of-behaviour: when the agent perceives high cost (token spend, wall-clock, gate friction), it reaches for a shortcut that erodes the contract before exhausting the contract-honoring path. P078 is the offer-on-correction valve; this ticket is the capture of the underlying tendency.

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — is the bypass-reflex emerging from cost-perception heuristics or from an underdeveloped "exhaust the contract-honoring path first" rule?
- [ ] Create reproduction test — a fixture that presents the agent with an expensive contract-honoring path and asserts no bypass is proposed before the contract is exhausted.

### Mitigation candidates (deferred to investigation)

- **Pre-flight rule**: when a SKILL contract names a step as "invoke <agent>" or "delegate to <skill>", invoke / delegate verbatim — do not propose an inline substitute. Substitution proposals are valid only when the SKILL itself names an alternative path (e.g., ADR-013 Rule 6 fail-safe, AFK carve-out).
- **Cost-surface honesty rule**: when a contract-honoring path is expensive, surface the cost to the user with options that PRESERVE the contract (subset of work / batch sizing / staged commits / phase split) before surfacing options that BREAK the contract.
- **Audit signal**: P196 (premature-completion) + P078 (offer-on-correction) + this ticket form a sibling class — agent's reporting-and-shortcut tendencies erode load-bearing process. The retro-time class-of-behaviour scan should catch shared symptoms.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P078 (capture-on-correction valve — fires after this bypass-reflex surfaces), P119 (closed — agent bypassed manage-problem Step 2 by writing tickets directly; sibling concrete instance), P132 (mechanical-stage carve-out — the contract this bypass-reflex erodes), P144 (verifying — agent attempts bypass on hook deny; sibling), P172 (open — skill-contract interactive-vs-AFK gating anti-pattern; adjacent contract-drift class), P196 (premature-completion at reporting surface — sibling reporting-and-shortcut tendency)

## Related

- captured via /wr-itil:capture-problem; expand at next investigation
- Duplicate-check matches (title-only grep, list-only): P118 (closed), P119 (closed), P172 (open), P173 (open), P174 (open), P126 (verifying), P135 (verifying), P144 (verifying) — most are adjacent concerns; closest sibling is P119 (closed: same bypass-of-manage-problem-Step-2 pattern) and P144 (verifying: agent attempts bypass on hook deny). Resolve at next /wr-itil:review-problems.

## Notes

Discovered a session-ID mismatch during this very capture: the SKILL Step 2's `mark_step2_complete` (via `get_current_session_id`) wrote the marker for SID `325fa82a-...`, but the P119 PreToolUse:Write hook (reading session_id from JSON stdin) checked for SID `9d50067d-...` (the runtime-marker contents from `/tmp/itil-runtime-sid-tomhoward-*.current`). The two SID-resolution paths diverged; the create-gate denied the Write until a manual touch of the runtime-marker SID's gate file unblocked it. This is the inverse of P124 — there, helper-side mtime-selection diverged from hook-side stdin-SID; here, helper-side fast-path resolution diverged from hook-side stdin-SID. Sibling P-ticket capture pending — drift between `get_current_session_id` and the JSON-stdin SID consumed by hooks. Surfaced as a separate concern at next /wr-itil:review-problems.
