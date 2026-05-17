# Problem 249: No process for issue reporters to check for responses — symmetric gap to inbound discovery

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 9 (Medium) — Impact: 3 (Moderate — symmetric gap leaves reporters without acknowledgement signal; degrades inbound-channel quality and the feedback loop completing ADR-062's "every submitted report receives a verdict" contract) × Likelihood: 3 (Possible — fires whenever we report upstream via `/wr-itil:report-upstream` AND whenever an external reporter files via our intake)
**Effort**: M (new skill `/wr-itil:check-upstream-responses` + workflow for both interpretations; composes with existing `report-upstream` cross-reference seam)
**WSJF**: 9/2 = **4.5** (Open multiplier 1.0; re-rated 2026-05-17 from placeholder during `/wr-itil:review-problems` — ties with P247/P246 sibling fictional-defer / symmetric-gap class)
**Type**: technical

## Description

You've made changes to the itil plugin to check for issues that have been reported by users (inbound discovery / assessment pipeline — P079 / ADR-062 / `/wr-itil:report-upstream`), but there is an issue now that those that report issues don't have any regular process for checking for responses.

The symmetric gap: we built the half where WE (the maintainer) detect inbound issues filed against our projects. But the reporter side — the persona that filed the issue — has no regular process for checking whether their report has been acknowledged, triaged, transitioned, or resolved.

**Two interpretations of "reporter", both valid**:

1. **Internal reporter (us reporting upstream)**: when we use `/wr-itil:report-upstream` to file an issue against an upstream repository (e.g. anthropics/claude-code, or a downstream plugin user's project), we have no regular process to check whether the upstream maintainer has responded, triaged, or closed our report. We file and forget; responses sit in GitHub unread until we manually visit the issue. Sibling to P080 (bidirectional update — the other direction: we should push status back to upstream-reported tickets we've ingested).

2. **External reporter (plugin user reporting to us)**: when a plugin user files an issue against our repo via `.github/ISSUE_TEMPLATE/problem-report.yml`, they have no regular process to check whether we (the maintainer) have triaged, ingested via `/wr-itil:report-upstream`'s inbound counterpart, or transitioned the ticket. They get GitHub's default notification once, then nothing structured.

Both interpretations are gaps. Both deserve the same shape of fix: a regular "check for responses to issues I reported" surface. The shape differs per persona:
- For us: a `/wr-itil:check-upstream-responses` skill (or hook on session start) that polls the GitHub issues we've filed and surfaces new responses.
- For external reporters: better triage feedback (e.g. ack comments per inbound report — P229 captures the bureaucratic-ack-comments anti-pattern; that's the inverse axis of THIS ticket).

## Symptoms

(deferred to investigation)

Initial signal: P229 (inbound discovery ack comments are bureaucratic, not verdict-shaped, JTBD-301 violation) is the inverse of this ticket. P229 says our ack-back to external reporters is the wrong shape. This ticket says THE WHOLE FEEDBACK LOOP from our side back to the reporter (us-as-reporter checking upstream; external-reporter checking us) doesn't exist as a structured surface.

## Workaround

Currently manual: visit the GitHub issue URL directly to see if there's a response. No batched view, no notification surface, no `/wr-itil:`-prefixed slash command.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — initial: every reporter persona (us-as-upstream-reporter; plugin-user-as-our-reporter; external-repo-reporter per P072).
- **Frequency**: per-report cycle — every report has the gap; gap fires whenever the reporter wonders "did anything happen?".
- **Severity**: (deferred to investigation) — initial: moderate. The feedback-loop gap erodes the trust that the inbound discovery half builds. Asymmetric surfaces (we observe inbound; reporters can't observe outbound) feel half-done.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — was reporter-side observability designed for ADR-062's inbound assessment pipeline? If yes, why is the symmetric surface missing? If no, what was the framing that omitted it?
- [ ] Decide scope — interpretation 1 (us-as-upstream-reporter) vs interpretation 2 (external-reporter-as-our-reporter) vs BOTH. Multi-concern split per P016 may be warranted (split into P249a + P249b).
- [ ] Design the check-for-responses surface (Skill? Hook? CI nudge? GitHub Action?). Likely `/wr-itil:check-upstream-responses` for interpretation 1.
- [ ] Cross-reference P080 (bidirectional update) — that ticket covers the inverse direction (we push status back to upstream-reported tickets we've ingested). Together with this ticket, the full feedback loop is captured.
- [ ] Cross-reference P229 (bureaucratic ack comments) — that ticket covers the SHAPE of inbound acks; this ticket covers the EXISTENCE of outbound check-for-responses. Sibling axes.
- [ ] Cross-reference P072 (no persona model for external repo reporter) — if interpretation 2 is in scope, the external-reporter persona JTBD may need to land first.
- [ ] Create reproduction test — bats fixture: file a test issue upstream, simulate response, verify the check-for-responses surface reports it.

## Dependencies

- **Blocks**: completing the upstream-reporting feedback loop (the inbound half is shipped; the outbound check-for-responses half is missing)
- **Blocked by**: potentially P072 (external-reporter persona) if interpretation 2 is in scope; potentially P080 (bidirectional update) if the surfaces compose
- **Composes with**: P079 (inbound assessment pipeline parent), P080 (bidirectional update), P229 (ack-comment shape), P072 (external-reporter persona), ADR-062 (inbound discovery)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P079** — no inbound sync of upstream-reported problems (parent: the inbound half this ticket is the missing outbound counterpart of)
- **P080** — no bidirectional update of upstream-reported problems (the inverse axis: we push status back to upstream-reported tickets we've ingested; together with this ticket, both directions of feedback loop are captured)
- **P229** — inbound discovery ack comments are bureaucratic, not verdict-shaped (JTBD-301 violation; covers the SHAPE of acks where this ticket covers the EXISTENCE of checks)
- **P072** — no persona models external repo reporter (if interpretation 2 in scope, the persona JTBD may need to land first)
- **P129** — P079 inbound assessment pipeline lacks version-aware classification (sibling assessment-pipeline improvement)
- **P196** — agent reports RFC document completion as fix-shipped (related: reporting semantics asymmetry)
- **ADR-062** — inbound upstream-report discovery assessment pipeline (parent ADR for the inbound half; this ticket may motivate an amendment to cover the outbound symmetric surface)
- `/wr-itil:report-upstream` SKILL.md — the report-filing surface; the natural place to chain or sibling the check-for-responses surface
- `.github/ISSUE_TEMPLATE/problem-report.yml` — the plugin-user-side inbound surface; interpretation 2 fix may compose here
