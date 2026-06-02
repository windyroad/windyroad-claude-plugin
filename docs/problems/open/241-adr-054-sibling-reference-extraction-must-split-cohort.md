# Problem 241: ADR-054 sibling-REFERENCE.md extraction — MUST_SPLIT cohort (9 skills + 1 risk-scorer skill)

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 9 (Medium-High) — Impact: 3 x Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: XL (deferred — re-rate at next /wr-itil:review-problems)
**WSJF**: 1.13 — (9 × 1.0) / 8 — re-rated 2026-05-23: P081 verifying→0 per P076; marginal XL dominates (was 1.5)

## Description

P097 Phase 2 + Phase 3 umbrella follow-on per architect verdict (2026-05-17 work-problems iter 8 Q6). Apply the ADR-054 sibling-`REFERENCE.md` extraction pattern to the 10 SKILL.md files currently above the MUST_SPLIT threshold (16,384 bytes). The first empirical instance (P097 iter 8 — `analyze-context` extraction) shipped the proof-of-pattern; this umbrella tracks the heavy-coupling cohort that requires P081 Layer B harness primitives before the structural-grep bats can retrofit to behavioural without losing coverage.

Per ADR-054 § "Phase 2-3 sequencing" (line 109): *"the block is not 'wait for full Layer B coverage' but 'wait until enough harness primitives ship that the structural-grep bats anchoring `manage-problem` (80 assertions across 14 files) can be retrofitted to behavioural without losing coverage'."*

Per architect Q6 verdict: umbrella ticket (not per-skill) avoids problems-README accumulator-bloat (P094 anti-pattern). Per-skill commit grain (ADR-014) is preserved — each touch ships its own SKILL.md+REFERENCE.md extraction + changeset.

## Cohort (2026-05-17 dogfood baseline)

Current MUST_SPLIT cohort per `wr-retrospective-check-skill-md-budgets`:

| Skill | Bytes | Plugin |
|-------|------:|--------|
| `/wr-itil:work-problems` | 115,651 | itil |
| `/wr-itil:manage-problem` | 100,309 | itil |
| `/wr-retrospective:run-retro` | 73,377 | retrospective |
| `/wr-itil:report-upstream` | 37,123 | itil |
| `/wr-itil:review-problems` | 35,806 | itil |
| `/wr-itil:manage-incident` | 35,274 | itil |
| `/wr-itil:transition-problems` | 25,216 | itil |
| `/wr-itil:transition-problem` | 23,070 | itil |
| `/wr-itil:mitigate-incident` | 17,632 | itil |
| `/wr-itil:work-problem` | 16,812 | itil |
| `/wr-risk-scorer:bootstrap-catalog` | 16,590 | risk-scorer |

## Symptoms

- Every invocation of these governance skills loads tens of KB of mixed runtime+rationale into the conversation context. Top-3 grew 50-144% in the eleven days between P091's first audit (2026-04-22) and ADR-054's drafting (2026-05-03); subsequent measurement (2026-05-17) shows continued accumulation.
- AFK orchestrator loops fire multiple of these skills per iter — token cost compounds.
- Without extraction, the ADR-054 advisory detector emits 10+ MUST_SPLIT lines on every run; signal-vs-noise on the budget surface degrades.

## Workaround

Per-skill opportunistic-as-touched extraction per ADR-054 § "Phase 2-3 sequencing" (line 111) when P081 Layer B harness primitives unblock. Until then, no workaround — the byte weight is already being paid on every invocation.

## Impact Assessment

- **Who is affected**: JTBD-001 / JTBD-006 / JTBD-101 personas — every windyroad-plugin user, especially AFK orchestrator consumers.
- **Frequency**: every invocation of any of the 10 cohort skills.
- **Severity**: High aggregate (cumulative token-weight per session); each skill is High-individually for `work-problems` / `manage-problem` / `run-retro` (top-3, multi-KB-per-invocation overhead).
- **Analytics**: `wr-retrospective-check-skill-md-budgets` runs read-only against the source tree. Per-iter delta tracked via the HTML-comment trailer in `docs/retros/*-context-analysis.md` (when `/wr-retrospective:analyze-context` runs).

## Root Cause Analysis

### Confirmed

SKILL.md files grow per-iter as new ADRs, P-tickets, and clarifications land. ADR-054 § Context line 27: *"without a normative budget, every per-iter ADR / P-ticket addition adds prose to the runtime hot path."* The advisory detector is the substrate; the budget is normative; the extraction is the unblocked work.

### Hypothesised on fix path (P081 Layer B dependency)

Per P097 Phase 1 audit (2026-04-27): 80 of 116 contract assertions on `manage-problem` are `grep "$SKILL_FILE"` structural greps. Moving `[reference]`-tagged content from `manage-problem/SKILL.md` to `manage-problem/REFERENCE.md` without behavioural alternatives for those 80 assertions causes proportional bats failure. Per ADR-052 supersession of ADR-037 + the user direction underlying P081, the path forward is behavioural bats — Path B per P097 Phase 1 § "Deferred-design questions" (2026-04-27).

P081 Layer B (harness primitives) is the unblock criterion. Once at least one primitive matures (e.g. SKILL-invocation harness OR tool-call interceptor OR subagent-return stub), the cohort retrofit can proceed opportunistically per ADR-052 § Migration.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Wait on P081 Layer B harness-primitive landing
- [ ] Once unblocked: pick top-1 (work-problems at 115KB) for first heavy-coupling extraction; calibrate `[runtime]`/`[reference]` boundary on the largest target; harvest learnings into ADR-054 amendment if needed
- [ ] Roll out per-skill opportunistic-as-touched extraction across the cohort
- [ ] Verify each commit drops the touched skill below MUST_SPLIT (16,384 bytes) OR documents a credible follow-up path
- [ ] Re-measure cohort byte counts after each commit; track delta in the most-recent `docs/retros/*-context-analysis.md` report

## Fix Strategy

**Per-touch opportunistic** per ADR-054 § "Phase 2-3 sequencing" + ADR-052 § Migration. When a maintainer next edits any cohort SKILL.md:
1. Either retrofit the touched skill's bats to behavioural (preferred — Path B per P097 Phase 1 audit)
2. Or carry an in-file justification comment per ADR-052 escape hatch
3. Then extract `[reference]`-tagged content to sibling `REFERENCE.md` per ADR-054 § "Sibling REFERENCE.md pattern"
4. Verify SKILL.md drops below MUST_SPLIT (16,384 bytes); if not, capture follow-on for additional `[runtime]`/`[reference]` calibration

One commit per skill per ADR-014 batch grain.

## Dependencies

- **Blocks**: (none — descendant of P097)
- **Blocked by**: P081 Layer B (harness primitives for behavioural retrofit of structural-grep bats — manage-problem cohort coupling specifically)
- **Composes with**: P097 (parent driver), P242 (install-updates project-local sibling), P243 (WARN-band cohort sibling), ADR-054 (governing decision), ADR-052 (behavioural-default test discipline)

## Related

- **P097** — driver / parent ticket; this is the umbrella for its Phase 2-3 extraction work.
- **P081** — Layer B blocker; P081 Layer A landed in ADR-052.
- **ADR-054** — `docs/decisions/054-skill-md-runtime-budget-policy.proposed.md`; sibling-REFERENCE.md pattern + byte budgets + opportunistic-as-touched migration shape.
- **ADR-052** — `docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md`; behavioural-default test discipline + migration shape this ticket inherits.
- **P179** — agent-defers-without-tracking carve-out; umbrella ticket capture satisfies P179 contract.
- **P094** — problems-README size budget; one-umbrella-per-cohort avoids accumulator-bloat per P094 anti-pattern.
- **P097 iter 8** — first empirical extraction (`analyze-context`, 2026-05-17) — proves the sibling-file mechanic works end-to-end before P081 Layer B unblocks the heavy-coupling cohort.
