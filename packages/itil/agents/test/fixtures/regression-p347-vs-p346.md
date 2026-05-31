# Behavioural fixture 1 (canonical regression): P347-vs-P346

This is the canonical regression case for the `wr-itil:hang-off-check` agent. It captures the 2026-05-31 P347 wrongly-captured-sibling-of-P346 incident. If the agent receives this fixture's inputs and returns anything other than `HANG_OFF: P346`, the SKILL is insufficient and the regression has re-opened.

Behavioural execution lands under RFC-012 (promptfoo eval harness, proposed). Until RFC-012 ships, this fixture is the documentation of the expected behaviour; the bats fixtures at `../hang-off-check.bats` are structural assertions on the agent's prose contract per ADR-052 Surface 2 carve-out.

## Input 1: New capture description

```
P346 + ADR-079 Phase 2 — empirical foreground relevance-scan today (5 batches,
14 closes) revealed 4 evidence shapes Phase 1 doesn't implement, plus the
1 shape Phase 1 does implement had the highest false-positive rate. The four
shapes: ADR-shipped-with-`human-oversight: confirmed`, named-skill-or-feature-
exists, self-marker-in-body (P289-class), driver-child-ticket-closed (P155 →
P014). Phase 1 false-positive fixes needed for state-suffix, sibling-file, and
rename detection (via `git log --follow`). Behavioural bats extension from 18
to 33 fixtures. `evaluate-relevance.sh` extension. Update
`/wr-itil:review-problems` SKILL.md Step 4.6 + `/wr-itil:manage-problem`
lifecycle table.
```

## Input 2: Filtered candidate set

| Candidate | Title | Path | Matching signals |
|-----------|-------|------|------------------|
| P346 | `/wr-itil:review-problems` has no path to close tickets that are no longer relevant (evidence-based, NOT age-based) — structural outflow gap drives monotonic backlog growth | `docs/problems/open/346-...md` | shared ADR-079 ref; shared `packages/itil/scripts/evaluate-relevance.sh` path; shared `/wr-itil:review-problems` SKILL ref; shared `/wr-itil:manage-problem` SKILL ref; candidate's `## Multi-phase scope` section explicitly names Phase 2 as in-scope |

## Expected verdict

```
HANG_OFF: P346

**Rationale**: P346 is the master ticket for the framework's backlog-flow-control
mechanisms with an explicit Multi-phase scope section. The new capture's
description IS Phase 2 of P346 (additional evidence shapes + Phase 1
false-positive fixes for the `evaluate-relevance.sh` script that P346 Phase 1
introduced). P346's body already names Phase 2 work as in-scope.

**Signals matched**: shared ADR-079 reference; shared
`packages/itil/scripts/evaluate-relevance.sh` file path; shared
`/wr-itil:review-problems` SKILL reference; shared `/wr-itil:manage-problem`
SKILL reference; candidate's `## Multi-phase scope` section explicitly names
Phase 2 as in-scope.

**Where to absorb**: amend P346's Investigation Tasks checklist with the 4
new evidence shapes + Phase 1 false-positive fix items; add a `### Phase 2 —
evidence shape expansion + Phase 1 false-positive fixes` section under the
existing Multi-phase scope section; the shipped commits' attribution
references this absorption.
```

## Why this fixture is canonical

The wrongly-captured P347 sibling of P346 on 2026-05-31 motivated the entire Phase 3 deliverable (this agent's existence). If a future change to the agent's prose contract regresses the verdict on this fixture, the SKILL no longer fulfils its driver. This is the binary tripwire.
