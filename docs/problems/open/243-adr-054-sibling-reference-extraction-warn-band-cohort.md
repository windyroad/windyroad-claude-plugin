# Problem 243: ADR-054 sibling-REFERENCE.md extraction — WARN-band cohort (OVER but not MUST_SPLIT)

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 4 (Low-Medium) — Impact: 2 x Likelihood: 2 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: L (deferred — re-rate at next /wr-itil:review-problems)
**WSJF**: 1.0 — (4 × 1.0) / 4 — re-rated 2026-05-23: P081 verifying→0; transitive = marginal L (was 1.5)

## Description

P097 Phase 2-3 umbrella follow-on for the remaining WARN-band cohort — SKILL.md files OVER the 8,192-byte WARN threshold but below the 16,384-byte MUST_SPLIT threshold. Per ADR-054 § "Byte budgets and OVER / MUST_SPLIT semantics" (line 100), WARN is **rotation-candidate** (deferral permitted, maintainer decides extraction priority based on invocation frequency × token cost). MUST_SPLIT is no-defer; WARN is defer-permitted but capture-required per P179.

The first empirical extraction (`analyze-context`, P097 iter 8 — 15.6KB → 14.4KB, still WARN-band) demonstrates the pattern is viable for WARN-band targets without P081 Layer B dependency (low-coupling bats stay green after extraction). This umbrella tracks the remaining WARN-band targets that follow the same low-coupling pattern.

## Cohort (2026-05-17 dogfood baseline, excluding `analyze-context` which is in-progress)

| Skill | Bytes | Plugin |
|-------|------:|--------|
| `/wr-itil:capture-problem` | 30,984 | itil — also MUST_SPLIT (escalate to P241 if heavy coupling) |
| `/wr-itil:capture-story` | 26,494 | itil — also MUST_SPLIT (escalate to P241 if heavy coupling) |
| `/wr-itil:capture-rfc` | 21,828 | itil — also MUST_SPLIT (escalate to P241 if heavy coupling) |
| `/wr-itil:manage-rfc` | 18,863 | itil — also MUST_SPLIT (escalate to P241 if heavy coupling) |
| `/wr-itil:manage-story` | 16,532 | itil — also MUST_SPLIT (escalate to P241 if heavy coupling) |
| `/wr-architect:create-adr` | 16,351 | architect |
| `/wr-risk-scorer:bootstrap-catalog` | 16,590 | risk-scorer — also MUST_SPLIT (escalate to P241 if heavy coupling) |
| `/wr-retrospective:analyze-context` | 14,426 | retrospective (in-progress — empirical baseline) |
| `/wr-itil:reconcile-readme` | 14,147 | itil |
| `/wr-itil:restore-incident` | 13,362 | itil |
| `/wr-itil:capture-story-map` | 12,783 | itil |
| `/wr-itil:close-incident` | 12,320 | itil |
| `/wr-architect:capture-adr` | 12,269 | architect |
| `/wr-risk-scorer:create-risk` | 12,066 | risk-scorer |
| `/wr-wardley:generate` | 11,926 | wardley |
| `/wr-itil:scaffold-intake` | 11,619 | itil |
| `/wr-itil:link-incident` | 10,451 | itil |
| `/wr-risk-scorer:assess-inbound-report` | 10,089 | risk-scorer |
| `/wr-risk-scorer:update-policy` | 9,644 | risk-scorer |
| `/wr-connect:setup` | 9,143 | connect |
| `/wr-itil:list-problems` | 8,756 | itil |
| `/wr-itil:manage-story-map` | 8,720 | itil — borderline |
| `/wr-itil:reconcile-stories` | 8,482 | itil — borderline |
| `/wr-itil:list-stories` | 8,272 | itil — borderline |

Note: skills marked "also MUST_SPLIT" are over the 16,384-byte cliff — if their bats coupling proves heavy at touch-time, escalate to P241 (the MUST_SPLIT umbrella). If their coupling proves low (like `analyze-context`), they stay in this WARN-band umbrella and extract opportunistically.

## Symptoms

- WARN-band skills load 8-16KB per invocation each. Aggregate across multiple invocations per session is meaningful but lower-priority than MUST_SPLIT cohort.
- `wr-retrospective-check-skill-md-budgets` emits 24+ OVER lines on every run; signal-vs-noise on the budget advisory degrades.

## Workaround

Per-skill opportunistic-as-touched extraction. ADR-054 explicitly permits WARN-band deferral; this ticket captures the cohort scope without forcing immediate action.

## Impact Assessment

- **Who is affected**: JTBD-001 / JTBD-006 / JTBD-101 personas (smaller per-skill blast radius than P241 cohort).
- **Frequency**: per-skill invocation frequency varies — `list-problems` / `list-stories` are high-frequency advisory tools; `capture-*` skills are aside-invocation per ADR-039 (lower frequency).
- **Severity**: Low-Medium aggregate; case-by-case for individual skills based on invocation frequency.
- **Analytics**: `wr-retrospective-check-skill-md-budgets` rows.

## Root Cause Analysis

### Confirmed

Same root cause class as the rest of P097: mixed `[runtime]` + `[reference]` content. Lower acuteness than MUST_SPLIT — each skill is individually digestible but the cohort is large.

### Hypothesised on fix path

`analyze-context` (P097 iter 8) demonstrates that WARN-band skills with low bats coupling can extract without P081 Layer B dependency. Reasonable hypothesis: most WARN-band skills follow this pattern. Per-skill verification at touch-time is the path.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Per skill at next touch-point: enumerate bats coupling; if low, extract per ADR-054 (Path A: simple bats grep-target retargeting or simple in-runtime-section retention); if heavy, escalate to P241 (the MUST_SPLIT umbrella behind P081 Layer B)
- [ ] Track per-iter byte-count delta in `docs/retros/*-context-analysis.md` reports
- [ ] When the cohort drops to ≤ 6 entries, retire this umbrella ticket (sub-threshold for umbrella-vs-per-skill cost trade-off)

## Fix Strategy

Per-touch opportunistic, prioritised by invocation frequency × token cost (per ADR-054 § 100). High-frequency advisory skills (`list-problems`, `list-stories`) first; rarely-invoked capture skills last. One commit per skill per ADR-014.

## Dependencies

- **Blocks**: (none — descendant of P097)
- **Blocked by**: (none — WARN-band is defer-permitted per ADR-054 line 100; per-skill coupling varies but most expected to follow `analyze-context` low-coupling pattern)
- **Composes with**: P097 (parent driver), P241 (MUST_SPLIT cohort — escalation target for heavy-coupling WARN-band finds), P242 (install-updates project-local), ADR-054, ADR-052

## Related

- **P097** — driver / parent ticket; `analyze-context` empirical baseline lands in P097 iter 8 (2026-05-17).
- **P241** — MUST_SPLIT cohort umbrella; escalation target when WARN-band skill proves heavy-coupling.
- **P242** — install-updates project-local sibling.
- **ADR-054** — governing decision; WARN-band rotation-candidate per § "Byte budgets and OVER / MUST_SPLIT semantics".
- **ADR-052** — behavioural-default test discipline; informs Path A vs Path B picks per WARN-band touch.
