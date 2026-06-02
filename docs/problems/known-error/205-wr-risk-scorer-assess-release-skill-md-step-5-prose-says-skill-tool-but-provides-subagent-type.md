# Problem 205: wr-risk-scorer:assess-release SKILL.md step 5 prose says "Skill tool" but provides subagent_type

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The `wr-risk-scorer:assess-release` SKILL.md step 5 contains a contract violation in its delegation prose. The text reads *"Invoke the pipeline subagent via the `Skill` tool"* but provides `subagent_type: wr-risk-scorer:pipeline` (an Agent-tool parameter, not a Skill-tool parameter). Following the prose verbatim with the Skill tool fails because there is no SKILL named `wr-risk-scorer:pipeline` — only the AGENT subagent_type carries that identifier.

## Workaround

Recognise the mismatch and use the Agent tool with `subagent_type: wr-risk-scorer:pipeline`. The prose intent is the Agent tool; the "Skill tool" naming is the documentation defect.

## Impact Assessment

- **Who is affected**: every agent or maintainer following the SKILL.md verbatim. JTBD-301/JTBD-302 trust contract violated.
- **Frequency**: every `/wr-risk-scorer:assess-release` invocation.
- **Severity**: Moderate (verbatim-following fails; recoverable by recognising intent).

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Fix `packages/risk-scorer/skills/assess-release/SKILL.md` step 5 prose: either change tool to "Agent tool" (keeps subagent_type), OR change parameter to `skill: wr-risk-scorer:pipeline` if a SKILL of that name exists / should exist.
- [ ] Audit other SKILL.md files for the same prose-vs-parameter mismatch.

## Dependencies

- **Composes with**: ADR-015 (governance skills delegate to subagent / skill fallback), ADR-051 (README-content-currency — extends to SKILL.md prose).

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/110
- **Pipeline classification**: JTBD-aligned (JTBD-301/JTBD-302/JTBD-101); safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/risk-scorer.
