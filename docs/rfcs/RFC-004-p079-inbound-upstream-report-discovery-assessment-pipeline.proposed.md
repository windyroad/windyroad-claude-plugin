---
status: proposed
rfc-id: p079-inbound-upstream-report-discovery-assessment-pipeline
reported: 2026-05-15
decision-makers: [Tom Howard]
problems: [P079]
adrs: [ADR-062]
jtbd: [JTBD-001, JTBD-101, JTBD-201, JTBD-202, JTBD-006, JTBD-301]
---

# RFC-004: P079 inbound upstream-report discovery + assessment pipeline (ADR-062 implementation rollout)

**Status**: proposed
**Reported**: 2026-05-15
**Problems**: P079
**ADRs**: ADR-062
**JTBD**: JTBD-001, JTBD-101, JTBD-201, JTBD-202, JTBD-006, JTBD-301

## Summary

Ships the inbound discovery + assessment pipeline framework that closes P079's invisible-inbound-report gap. Peer of ADR-024's outbound contract. Decomposed across seven slices (A-G per P079's 2026-05-14 RCA extensions); Slices A and D landed under commit `ca4f6e4` as the foundational architecture scaffold. This RFC captures the remaining execution and the integration seam for P129's version-aware classifier carve-out.

## Driving problem trace

**P079** (`docs/problems/open/079-no-inbound-sync-of-upstream-reported-problems.md`) — plugin-user files a structured `problem-report.yml` issue on `windyroad/agent-plugins`; report sits in `gh issue list` until the maintainer remembers to look; `/wr-itil:manage-problem review` and `/wr-itil:work-problems` are local-only and never surface it. Breaks the end-to-end promise of P055 (intake templates) + ADR-024 (outbound contract) + ADR-036 (downstream scaffold) + JTBD-301 (plugin-user persona's "Report a Problem Without Pre-Classifying It"). User direction (2026-04-21 + 2026-04-26 interactive AskUserQuestion resolution) extended the close-the-loop work into a multi-step assessment pipeline (JTBD alignment + dual-axis risk + branches to {auto-acknowledge with local ticket | pushback comment | policy-violation close with verdict comment}, all external comms riding P064 + P038 gates per ADR-028 amended). ADR-062 pins all design decisions; this RFC carries execution.

## Scope

(deferred — populate at /wr-itil:manage-rfc accepted transition)

## Tasks

- [ ] (deferred — populate at /wr-itil:manage-rfc accepted transition)

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12; lands in Slice 3 task B5.T9)

## Related

(captured via /wr-itil:capture-rfc; expand at next /wr-itil:manage-rfc invocation)
