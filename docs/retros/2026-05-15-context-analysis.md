# Context Analysis — 2026-05-15

> Source: `/wr-retrospective:analyze-context` (deep layer per ADR-043).
> Methodology: byte-count-on-disk + per-plugin decomposition + per-turn attribution (when session log available).
> Cheap-layer baseline: `packages/retrospective/scripts/measure-context-budget.sh` (commit 0fda8a5 vintage).

## Bucket Totals

| Bucket | Bytes | % of measured | Δ vs prior |
|--------|-------|---------------|------------|
| decisions | 1,346,837 | 41.0% | not estimated — no prior data (no `<!-- context-snapshot:` trailer in prior retro reports) |
| skills | 823,837 | 25.1% | not estimated — no prior data |
| hooks | 338,195 | 10.3% | not estimated — no prior data |
| problems | 306,740 | 9.3% | not estimated — no prior data |
| memory | 217,269 | 6.6% | not estimated — no prior data |
| briefing | 119,103 | 3.6% | not estimated — no prior data |
| jtbd | 41,549 | 1.3% | not estimated — no prior data |
| project-claude-md | 4,277 | 0.1% | not estimated — no prior data |
| framework-injected | not measured | — | reason=framework-injected-no-on-disk-source |

Total measured: **3,279,807 bytes (3.13 MiB)**. Threshold (cheap-layer alert): 10240 bytes per bucket — most buckets are an order of magnitude over.

## Per-Plugin Decomposition

### Hooks (aggregate from cheap layer: 338,195 bytes)

| Plugin | Bytes | % of hooks |
|--------|-------|------------|
| itil | 107,407 | 31.8% |
| risk-scorer | 73,213 | 21.6% |
| voice-tone | 37,033 | 10.9% |
| tdd | 26,937 | 8.0% |
| architect | 23,394 | 6.9% |
| jtbd | 21,658 | 6.4% |
| style-guide | 19,635 | 5.8% |
| shared | 16,385 | 4.8% |
| retrospective | 10,477 | 3.1% |
| connect | 2,056 | 0.6% |

Aggregate sanity check: 337,195 bytes via per-plugin sum vs 338,195 cheap-layer aggregate (1,000-byte delta — cheap-layer enumerates more paths; treat per-plugin as floor estimate).

### Skills (aggregate from cheap layer: 823,837 bytes)

| Plugin | Bytes | % of skills |
|--------|-------|-------------|
| itil | 593,603 | 72.1% |
| retrospective | 89,015 | 10.8% |
| risk-scorer | 50,315 | 6.1% |
| architect | 23,491 | 2.9% |
| wardley | 11,926 | 1.4% |
| connect | 11,434 | 1.4% |
| jtbd | 9,684 | 1.2% |
| voice-tone | 9,573 | 1.2% |
| style-guide | 3,895 | 0.5% |
| tdd | 3,369 | 0.4% |
| c4 | 660 | 0.1% |

Aggregate sanity check: 806,965 bytes via per-plugin sum vs 823,837 cheap-layer aggregate (16,872-byte delta — cheap-layer counts include `bin/` shims and skill assets the per-plugin enumerator excludes; treat per-plugin as floor estimate).

## Top-N Offenders

| Surface | Bytes | Bucket | Comparable prior |
|---------|-------|--------|------------------|
| `docs/decisions/060-problem-rfc-story-framework-...md` | 92,688 | decisions | not estimated — no prior data |
| `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` | 73,933 | decisions | not estimated — no prior data |
| `packages/itil/skills/work-problems/SKILL.md` | 103,041 | skills/itil | P097 (`SKILL.md files mix runtime-necessary steps with maintainer-facing rationale`) is the evolving budget anchor; no concrete reclamation yet — the ticket itself proposes the runtime-vs-rationale split but is `Known Error`, not yet shipped |
| `packages/itil/skills/manage-problem/SKILL.md` | 91,316 | skills/itil | P097 |
| `packages/retrospective/skills/run-retro/SKILL.md` | 73,377 | skills/retrospective | P097 |
| `docs/decisions/059-pipeline-consume-catalog-and-bootstrap-from-reports.proposed.md` | 48,255 | decisions | not estimated — no prior data |
| `docs/decisions/061-dogfood-graduation-criteria.proposed.md` | 39,006 | decisions | not estimated — no prior data |
| `packages/itil/skills/report-upstream/SKILL.md` | 37,123 | skills/itil | P097 |
| `docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md` | 38,104 | decisions | not estimated — no prior data |

The `decisions` bucket dominates context (41% of measured); five ADRs each exceed 38 KB. `skills/itil` dominates the `skills` bucket (72%); three SKILL.md files exceed 73 KB.

## Per-Turn Attribution

per-turn attribution: not measured — no session log accessible. The `.afk-run-state/outstanding-questions.jsonl` + `risk-register-queue.jsonl` files exist but are orchestrator state, not per-turn token-usage logs. Session-log parser to reach into `~/.claude/projects/*/*.jsonl` is out of scope per the P088 settlement (context-marshalling deferred).

## Suggestions

1. **decisions / ADR-060** — At 92,688 bytes, `docs/decisions/060-problem-rfc-story-framework-...accepted.md` is the single largest measured surface in the deep report. The ADR carries the unified problem/RFC/story ontology + Phase 1 framework + Phase 2 dogfood evidence inline. Comparable prior: not estimated — no prior data. Candidate trim direction: extract the Phase 2 dogfood-evidence body to a separate `docs/decisions/060-amendments/` history file once the framework has shipped its full graduation cycle (currently in `accepted` status, dogfood ongoing). Estimated byte saving: not estimated — no prior data. Stage 1 ticket worthy — captures a recurring class (ADRs accumulate forward-chronology evidence inline rather than archiving).

2. **skills/itil — three largest SKILL.md files** — `work-problems` (103 KB) + `manage-problem` (91 KB) + `report-upstream` (37 KB) all exceed the P097 ticket's runtime-vs-rationale split threshold. Comparable prior: P097 (`SKILL.md files mix runtime-necessary steps with maintainer-facing rationale, bloating every skill invocation`) is the named driver ticket; status is `Known Error` (RCA documented, fix path clear, fix not yet released). Estimated byte saving: not estimated — P097's proposed split has not shipped a comparable prior; the reclamation pattern is described but not yet measured. Suggestion: prioritise P097 implementation; the work-problems SKILL.md alone is 12.5% of the entire `skills` bucket.

3. **decisions / ADR-032** — At 73,933 bytes, the second-largest ADR. Comparable prior: not estimated — no prior data. The ADR covers governance-skill invocation patterns; significant content accumulated as the suite evolved. Candidate trim direction: extract the worked-example matrix to a separate companion file once the invocation pattern stabilises. Estimated byte saving: not estimated — no prior data.

4. **memory** — At 217 KB, `memory` is the fifth-largest bucket. Per [`feedback_act_on_obvious_decisions`](../../.claude/projects/-Users-tomhoward-Projects-windyroad-claude-plugin/memory/MEMORY.md) + 13 other feedback memories, accumulation is by design (each memory is load-bearing for behavioural correction). Comparable prior: not estimated — no prior data on memory trim cycles. Candidate review: surface stale memories at retro-time via the `feedback_*` files' last-relevant-cited date. Estimated byte saving: not estimated — no prior data.

5. **briefing** — At 119 KB across 14 topic files, briefing exceeds the ADR-040 Tier 3 envelope on 8 files. Comparable prior: P099 (`docs/BRIEFING.md grows unbounded via run-retro appends — violates progressive disclosure`) shipped advisory enforcement via `check-briefing-budgets.sh`. The advisory fired this session (8 files OVER); rotation deferred per the goal-pinned scope. Estimated byte saving: ~5-10 KB per rotated file (split-by-date archive shape). Stage 1 ticket worthy — repeat-deferral pattern (P145 / P135 ratio-≥2x branch).

## Policy Breaches

| Budget | Offender | Bytes | Citation |
|--------|----------|-------|----------|
| P097 (SKILL.md >50 KB threshold) | `packages/itil/skills/work-problems/SKILL.md` | 103,041 | P097 Known Error |
| P097 (SKILL.md >50 KB threshold) | `packages/itil/skills/manage-problem/SKILL.md` | 91,316 | P097 Known Error |
| P097 (SKILL.md >50 KB threshold) | `packages/retrospective/skills/run-retro/SKILL.md` | 73,377 | P097 Known Error |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/hooks-and-gates-archive.md` | 12,795 | MUST_SPLIT branch (≥2× ceiling) — `check-briefing-budgets.sh` fired |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/governance-workflow-archive.md` | 10,154 | OVER (≥2× ceiling) — MUST_SPLIT branch |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/releases-and-ci-archive.md` | 9,941 | OVER — `check-briefing-budgets.sh` fired |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/hooks-and-gates.md` | 9,683 | OVER |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/agent-hook-gate-quirks.md` | 9,434 | OVER |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/afk-subprocess-recovery.md` | 9,397 | OVER |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/afk-subprocess-mechanics.md` | 9,093 | OVER |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/plugin-distribution.md` | 8,975 | OVER |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/governance-workflow-surprises.md` | 8,269 | OVER |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/governance-workflow.md` | 7,252 | OVER |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/releases-and-ci.md` | 7,208 | OVER |
| ADR-040 Tier 3 (5120 bytes per topic file) | `docs/briefing/agent-interaction-patterns.md` | 6,684 | OVER |

13 of 14 topic files breach Tier 3. Branch A (MUST_SPLIT) applies to the two archive files at ≥2× ceiling; remaining files are Branch B (OVER but <2× ceiling).

<!--
context-snapshot:
  total-bytes: 3279807
  hooks: 338195
  skills: 823837
  memory: 217269
  briefing: 119103
  decisions: 1346837
  problems: 306740
  jtbd: 41549
  project-claude-md: 4277
  framework-injected: not measured
  measurement-method: byte-count-on-disk
  measured-at: 2026-05-14T14:09:58Z
-->
