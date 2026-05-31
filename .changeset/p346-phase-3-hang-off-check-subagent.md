---
"@windyroad/itil": minor
---

P346 Phase 3 — capture-time hang-off discipline via fresh-context subagent

Ships the `wr-itil:hang-off-check` subagent (read-only; Read/Glob/Grep) that
arbitrates the absorb-into-parent-vs-proceed-as-new decision at the
`/wr-itil:capture-problem` Step 2 + `/wr-itil:manage-problem` Step 2 dispatch
sites. The subagent runs in fresh context (no session-context bias on the
calling main agent) and emits a structured verdict — `HANG_OFF: P<NNN>`
when the new capture's scope belongs as an Investigation Tasks expansion /
Phase N section on a candidate parent, or `PROCEED_NEW` when no candidate
absorbs the new scope.

Mechanical pre-filter on the dispatch sites bounds the candidate set (cap 5
per ADR-032 latency-bound contract); wider sets short-circuit to
PROCEED_NEW so capture stays under JTBD-001's 60s flow budget. AFK
safe-default: ambiguous-multi-parent collapses to PROCEED_NEW per ADR-013
Rule 6. JTBD-301 firewall preserved: dispatch fires on maintainer-side
captures only, never on plugin-user-side issue-report intake.

Architecturally codified as ADR-032's 5th invocation pattern (Foreground
fresh-context-subagent-as-decision-arbiter) under the P346 amendment
2026-05-31. RFC-013 traces P346's three-phase fix work (Phase 1+2 outflow
via ADR-079 evidence-based relevance-close pass; Phase 3 inflow via this
subagent) per ADR-071 unconditional Problem→RFC trace.

Closes the wrongly-captured-sibling failure mode (the 2026-05-31 P347
captured-then-closed-as-duplicate-of-P346 incident is the canonical
regression — `packages/itil/agents/test/fixtures/regression-p347-vs-p346.md`
documents the expected HANG_OFF: P346 verdict shape). Three canonical
fixtures ship for behavioural verification; bats coverage is structural per
ADR-052 Surface 2 (P176 harness-gap carve-out) with behavioural execution
landing under RFC-012 (promptfoo eval harness — proposed).
