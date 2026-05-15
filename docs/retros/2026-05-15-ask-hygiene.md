# Ask Hygiene — 2026-05-15

Session scope: Finish RFC for P079 (Slices B-G), release + install, retro.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| (none) | (no AskUserQuestion calls fired this session) | n/a | All decisions resolved by framework or user-pinned direction; agent acted on obvious decisions per `feedback_act_on_obvious_decisions` + P132 / ADR-044 framework-resolution boundary |

**Lazy count: 0**
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

Trend across recent retros (read from `packages/retrospective/scripts/check-ask-hygiene.sh` if present): N/A — first trail entry for this session.

## Second retro append — 2026-05-15 (inbound-discovery pipeline + Step 0b)

Session scope: ship work-problems Step 0b auto-pre-flight + process 31 inbound upstream reports end-to-end through ADR-062 Step 4.5e + dogfood capture-problem on P197 meta-capture.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | Capture pattern | correction-followup | Gap: user delivered strong-affect correction ("DONT skip using the capture-problem skill. FFS"); agent offered ticket capture per P078 |
| 2 | Problem type | taste | Gap: type classification for P197 was genuinely ambiguous (technical + JTBD-shaped signals); SKILL Step 1.5 prescribes AskUserQuestion on ambiguity (ADR-044 cat 5) |
| 3 | Fix scope (31-issues) | direction | Gap: filter-drift resolution; 4 distinct paths with different downstream commitments — user-direction territory |
| 4 | Pipeline scope (31-reports) | direction | Gap: budget-direction on processing scale; 4 paths with visible cost trade-offs |
| 5 | Continue 30? | direction | Gap: budget-reality check after workflow validated end-to-end for one report; user could re-direct mid-batch |

**Lazy count: 0**
**Direction count: 3**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 1**
**Correction-followup count: 1**

Trend: 2 retros 2026-05-15, both `lazy=0`. R6 gate (lazy ≥2 across 3 consecutive retros) not at risk.

## Third retro append — 2026-05-15 (post-correction recovery)

Session scope: user correction recovery — P229 capture (ack-comment JTBD-301 violation) + retroactive JTBD-alignment audit of 22 inbound-pipeline tickets.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | Problem type (P229 capture) | taste | Gap: type classification for P229 was genuinely ambiguous — root cause is unmet plugin-user need (JTBD-301 verdict-shape) AND fix surface is SKILL.md prose; SKILL Step 1.5 prescribes AskUserQuestion on ambiguity (ADR-044 cat 5) |

**Lazy count: 0**
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 1**
**Correction-followup count: 0**

Trend: 3 retros 2026-05-15, all `lazy=0`. R6 gate (lazy ≥2 across 3 consecutive retros) not at risk.

## Fourth retro append — 2026-05-15 (P162 Phase 4 AFK iter)

Iter scope: P162 Phase 4 documentation amendments — docs/changesets-holding/README.md Process step 5 + ADR-018 + ADR-020 Rule 8 disjunct prose. AFK orchestrator subprocess; `AskUserQuestion` forbidden mid-loop per task constraints (P135 / ADR-044 framework-resolution boundary).

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| (none) | (no AskUserQuestion calls fired this iter — AFK constraint) | n/a | Framework constraint: AFK iter subprocesses defer all interactive surfaces to `outstanding_questions` queue for loop-end batched presentation. Same shape as prior 2026-05-13 P162 Phase 2a iter (also `lazy=0`). |

**Lazy count: 0**
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

Trend: 4 retros 2026-05-15, all `lazy=0`. R6 gate (lazy ≥2 across 3 consecutive retros) not at risk.
