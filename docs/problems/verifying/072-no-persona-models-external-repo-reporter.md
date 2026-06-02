# Problem 072: No persona in docs/jtbd/ models the external reporter who files against this repo

**Status**: Verification Pending
**Reported**: 2026-04-20
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: M — new persona directory under `docs/jtbd/external-reporter/` (or equivalent name) with `persona.md` and at least one job file (`JTBD-301-file-a-problem-without-pre-classifying.proposed.md` or similar). May extend existing `plugin-developer` or `tech-lead` personas instead. Cross-reference from P055 / P065 / P066 / P067 tickets.
**WSJF**: 2.25 — (9 × 1.0) / 4 — Mid-severity modelling gap. Effort bumped to L once persona naming and job boundaries are decided under user direction; AFK can only stub the skeleton, not pick the name. Interim WSJF uses M; re-rate at Open → Known Error transition.

## Description

The JTBD review during P066 (intake templates problem-first) flagged that no persona currently models the external reporter whose primary relationship with this repo is "I encountered a problem with a windyroad plugin I installed, and I want to report it." The existing three personas in `docs/jtbd/` all describe users whose reporting is incidental, not primary:

- `solo-developer` (JTBD-001, JTBD-005) — an AI-agent-using builder; not a reporter of this suite's defects.
- `tech-lead` (JTBD-201, JTBD-202) — recommends/installs the suite for teams; reporting possible but incidental.
- `plugin-developer` (JTBD-101) — builds inside the monorepo; reporting incidental.

Four recent problem tickets (P055, P065, P066, P067) all reshape the external reporter's experience and reference JTBD-001 / JTBD-101 / JTBD-201 by necessity — but those jobs serve the maintainers processing the report, not the reporter filing it. The reporter's own desired outcomes (low-friction template, no forced pre-classification, clear landing copy in `SUPPORT.md` / `CONTRIBUTING.md`) have no documented job to cite.

This is a modelling gap, not a correctness defect. Every future intake tweak will land without a persona to point back to, producing JTBD reviews that say "aligned with existing maintainer-side jobs; external reporter not modelled" — a finding that accrues weight each cycle.

## Symptoms

- JTBD review during P066 returned "PERSONA UPDATE NEEDED" as the recommended resolution.
- P066, P065, P055, P067 all cite maintainer-side jobs (JTBD-001, JTBD-101, JTBD-201) when their primary beneficiary is the external reporter.
- No file matching `docs/jtbd/**/JTBD-3*` exists — the 300-series persona bucket is empty.
- `docs/jtbd/README.md` enumerates three personas; adding a fourth requires index edits.

## Workaround

Cross-reference maintainer-side jobs indirectly (as P066 does today) and note the gap in the ticket Related section. Works for individual tickets but does not scale — each new intake-adjacent ticket repeats the note.

## Impact Assessment

- **Who is affected**:
  - **External reporters** — their experience has no documented job; future intake changes cite maintainer jobs by proxy.
  - **Maintainers writing tickets** — each new intake-adjacent ticket has to hand-wave the persona fit.
  - **JTBD reviewer agent** — returns advisory findings rather than clean verdicts on intake tickets, growing review noise.
- **Frequency**: Every new intake-adjacent ticket (P055, P065, P066, P067 so far; more expected as the reporting surface grows).
- **Severity**: Medium. Not a correctness defect, but a structural modelling gap that accumulates review cost.
- **Analytics**: N/A.

## Root Cause Analysis

### Structural

The initial `docs/jtbd/` directory was scoped for internal users (solo dev, plugin dev, tech lead) because the repo was not public when the personas were first written. The `e36cf84` OSS intake scaffolding (P055 Part A) made the repo's reporting surface externally-facing without a corresponding persona update. The JTBD plugin's own review agent surfaces the gap each time an intake-adjacent ticket lands.

### Candidate fixes

Two candidate shapes — user direction required to pick one:

1. **New persona `external-reporter` (or `plugin-user` / `reporter`)**.
   - New directory `docs/jtbd/<name>/` with `persona.md` describing the constraint set (low context on repo internals, high context on their own failure mode, not a contributor today).
   - At least one job: `JTBD-301-file-a-problem-without-pre-classifying-it.proposed.md`.
   - Add to `docs/jtbd/README.md` persona index.
   - Update P055, P065, P066, P067 Related sections to cite the new job.

2. **Extend `plugin-developer` persona** to include the "adopter reporting a problem" aspect.
   - Add a new job under `plugin-developer/` covering the intake experience.
   - Keep persona count at 3; the adopter/reporter is a sub-aspect of the plugin-developer persona rather than its own.
   - Simpler but blurs the persona boundary.

**Recommended direction (AFK cannot decide)**: option 1 — the reporter's constraint set (low repo-internals context) differs meaningfully from plugin-developer's (builder with deep context), which argues for a separate persona. User decides the name.

### Investigation Tasks

- [ ] User direction: option 1 (new persona) or option 2 (extend existing persona)
- [ ] If option 1: decide persona name (`external-reporter` / `plugin-user` / `reporter` / other)
- [ ] If option 1: decide job ID numbering (JTBD-301 series vs fitting into an existing series)
- [ ] Draft `persona.md` with constraint set derived from the JTBD review notes
- [ ] Draft first job file with desired outcomes that future intake tickets can cite
- [ ] Update `docs/jtbd/README.md` persona index
- [ ] Cross-reference P055, P065, P066, P067 Related sections to cite the new persona/job
- [ ] Add a bats doc-lint assertion that the persona directory exists and the README index lists it

## Fix Released

Shipped 2026-04-20 (commit pending). User direction captured interactively: persona name `plugin-user`; job ID series JTBD-301+ (new 300-bucket; standard one-persona-per-100-bucket continuation).

- `docs/jtbd/plugin-user/persona.md` — NEW. Models the developer who has installed a `@windyroad/*` plugin and encountered a problem. Constraint set: low context on repo internals, high context on their own failure mode, reporting is incidental to their primary work, may file via an AI agent. Pain points: forced pre-classification, missing intake surfaces, unclear security-disclosure channel, unacknowledged reports, duplicate rejection, cross-plugin ambiguity.
- `docs/jtbd/plugin-user/JTBD-301-report-problem-without-pre-classifying.proposed.md` — NEW. Job statement: "When I hit a problem with a windyroad plugin I installed, I want to describe what I observed in one place without deciding in advance whether it's a bug, a feature gap, or a documentation issue, so I can submit a useful report and get back to my own work." Desired outcomes cover single problem-first template, problem-ticket field parity, declared security channel, Discussions routing for usage questions, scaffolded intake in every adopter, predictable acknowledgement + audit trail, dedup before filing.
- `docs/jtbd/README.md` — persona index extended with a new "Plugin User" section + the JTBD-301 row.

Future intake-adjacent tickets (P065, P067, P070, any successor) can cite JTBD-301 directly instead of relying on the maintainer-side JTBD-001 / JTBD-101 / JTBD-201 by proxy. The persona also anchors the "reporter may be filing via an AI agent" constraint that the current three personas don't capture.

Awaiting user verification: next JTBD-review invocation on an intake-adjacent ticket should cite JTBD-301 as the primary job served; the review agent should no longer return "PERSONA UPDATE NEEDED" on those tickets.

## Related

- **P055** — OSS intake scaffolding; first ticket that made the gap visible but did not flag it.
- **P065** — scaffold-intake skill; downstream of intake templates, same persona.
- **P066** — intake templates problem-first; the JTBD review during this ticket surfaced the gap.
- **P067** — report-upstream classifier problem-first; same reporter persona.
- **ADR-024** — cross-project problem-reporting contract; names the reporter as the subject of the upstream-report skill but does not model them as a persona.
- **JTBD-001 / JTBD-101 / JTBD-201** — currently cited by intake tickets by proxy; this ticket fills the gap so future citations can be direct.
- `docs/jtbd/README.md` — persona index to update.
