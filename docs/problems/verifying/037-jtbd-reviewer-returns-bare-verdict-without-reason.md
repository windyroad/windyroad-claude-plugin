# Problem 037: JTBD reviewer sometimes returns a bare verdict without remediation reason

**Status**: Verification Pending
**Reported**: 2026-04-17
**Priority**: 6 (Med) — Impact: Moderate (3) x Likelihood: Possible (2)
**Effort**: S
**WSJF**: 6.0 — (6 × 1.0) / 1

## Fix Released

Fix shipped in AFK iter 3 (2026-04-19, pending commit). Root cause: the `wr-jtbd:agent` prompt treated the `/tmp/jtbd-verdict` marker file as the authoritative verdict surface, so the agent could write the file and emit only a file list or a bare `"FAIL"` inline, leaving the caller without actionable guidance. Reframed the agent's output contract into two required channels (inline primary, file internal signal), with explicit prohibitions on bare verdicts and a MUST-agree rule between the two. Added 7-test doc-lint bats file `packages/jtbd/agents/test/jtbd-verdict-contract.bats`. Released via `@windyroad/jtbd` patch bump. Awaiting user verification — next `wr-jtbd:agent` delegation via the Agent tool should produce a structured inline verdict with remediation guidance on FAIL without requiring a re-query.

## Description

When delegated to via the Agent tool (`subagent_type: "wr-jtbd:agent"`), the JTBD reviewer sometimes returns output that lacks a clear verdict body — either a bare `"FAIL"` followed by a list of reviewed files and no remediation guidance, or only a list of files reviewed with no explicit PASS/FAIL verdict at all. This forces the caller to either (a) guess the verdict (risking skipping the gate), or (b) re-query the agent with explicit framing ("explain specifically which job conflicts and what would need to change") to extract actionable guidance.

Observed twice in a single session on 2026-04-17:
1. First invocation for `work-problems` skill returned `"Verdict: FAIL — written to /tmp/jtbd-verdict"` but the referenced file did not exist at that path, and the visible output had no remediation detail. Re-query returned a detailed PASS/FAIL with specific reasons.
2. Later invocation during `/wr-retrospective:run-retro` returned only a list of reviewed files with no verdict text at all. (The architect review in the same batch returned a clear PASS.)

The architect reviewer (`wr-architect:agent`) does not exhibit this inconsistency — its output consistently includes a bolded verdict line and a bulleted list of issues or a PASS rationale.

## Symptoms

- Caller cannot tell whether the gate passed, failed, or was silently inconclusive
- Remediation guidance, when verdict is FAIL, is absent or only accessible via re-query
- Token cost doubles when re-query is needed
- Risk of silently skipping the gate if the caller assumes "no verdict = no issues"

## Workaround

Re-query the JTBD agent with explicit framing: *"Please review X and explain specifically: (1) which job(s) align or conflict, (2) what gap or violation caused FAIL, (3) what would need to change to pass."* This reliably returns actionable detail.

## Impact Assessment

- **Who is affected**: Any Claude session invoking the JTBD reviewer via the Agent tool — i.e., every UserPromptSubmit hook invocation that triggers JTBD review
- **Frequency**: Observed twice in one session; anecdotal evidence suggests ~1 in 4 invocations
- **Severity**: Medium — governance gate is the critical path for project edits; unclear verdicts slow every reviewed change and risk silent gate bypass
- **Analytics**: N/A

## Root Cause Analysis

### Investigation Tasks

- [ ] Determine whether the bare-verdict behaviour is an agent-prompt issue (the agent's own instructions) or a harness issue (output truncation, file-write sink that the caller can't read)
- [ ] Inspect the `wr-jtbd:agent` definition to see if its output contract requires a structured verdict section
- [ ] Compare with `wr-architect:agent` definition to identify what makes architect's output more reliably structured
- [ ] Check if the "verdict written to /tmp/jtbd-verdict" pattern is intentional (file-based verdict sink) and if so, document it or switch to inline output
- [ ] Create a reproduction test that invokes the JTBD agent on a known-PASS change and on a known-FAIL change, asserting the output always contains an unambiguous verdict + actionable reasoning
- [ ] Create INVEST story for permanent fix

## Related

- [JTBD-001](../jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md) — governance enforcement (JTBD agent is a primary enforcer)
- [P021](021-governance-skill-structured-prompts.known-error.md) — structured prompts for governance skills (related pattern: governance agents should produce structured output)
- [P022](022-agents-should-not-fabricate-time-estimates.open.md) — sibling concern about governance-agent output quality
- `wr-jtbd:agent` definition — source of the output inconsistency
