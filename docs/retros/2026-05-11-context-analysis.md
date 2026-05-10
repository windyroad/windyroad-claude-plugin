# Context Analysis — 2026-05-11

> Source: `/wr-retrospective:analyze-context` (deep layer per ADR-043).
> Methodology: byte-count-on-disk + per-plugin decomposition + per-turn attribution (when session log available).
> Cheap-layer baseline: `packages/retrospective/scripts/measure-context-budget.sh`.
> Invocation context: I002-mitigation session retro. Triggered by run-retro Step 2c surfacing ≥+20% delta in 5 of 7 measured buckets.

## Bucket Totals

| Bucket | Bytes | % of measured | Δ vs 2026-04-29 |
|--------|-------|---------------|-----------------|
| decisions | 1,235,889 | 43.0% | +51.8% (+421,545 vs 814,344) |
| skills | 704,302 | 24.5% | +23.1% (+132,324 vs 571,978) |
| hooks | 301,115 | 10.5% | +21.1% (+52,569 vs 248,546) |
| problems | 286,459 | 10.0% | -85.6% (-1,700,484 vs 1,986,943) — methodology artefact, see Suggestions §4 |
| memory | 192,370 | 6.7% | +12.8% (+21,900 vs 170,470) |
| briefing | 104,629 | 3.6% | +30.9% (+24,751 vs 79,878) |
| jtbd | 40,866 | 1.4% | +62.7% (+15,739 vs 25,127) |
| project-claude-md | 4,277 | 0.1% | 0% (no change) |
| framework-injected | not-measured | — | reason=framework-injected-no-on-disk-source |
| **Total measured** | **2,869,907** | **100%** | **-26.6% (-1,031,656 vs 3,901,563)** |

Total drop is driven by the problems-bucket methodology artefact (-1,700,484); excluding that bucket, real growth across all other buckets is +668,828 bytes (+23.4% over the comparable prior).

## Per-Plugin Decomposition

### Hooks (aggregate from cheap layer: 301,115 bytes)

| Plugin | Bytes | % of hooks |
|--------|-------|------------|
| itil | 95,780 | 31.8% |
| risk-scorer | 69,552 | 23.1% |
| tdd | 26,937 | 8.9% |
| architect | 22,930 | 7.6% |
| jtbd | 21,287 | 7.1% |
| voice-tone | 19,191 | 6.4% |
| style-guide | 19,156 | 6.4% |
| shared | 13,749 | 4.6% |
| retrospective | 10,477 | 3.5% |
| connect | 2,056 | 0.7% |
| **sum** | **301,115** | **100%** |

Sum-check: per-plugin sum equals cheap-layer aggregate exactly (no test/ or external surface unaccounted).

### Skills (aggregate from cheap layer: 704,302 bytes)

| Plugin | Bytes | % of skills |
|--------|-------|-------------|
| itil | 479,816 | 68.1% |
| retrospective | 89,015 | 12.6% |
| risk-scorer | 50,312 | 7.1% |
| architect | 23,485 | 3.3% |
| wardley | 11,926 | 1.7% |
| connect | 11,434 | 1.6% |
| jtbd | 9,684 | 1.4% |
| style-guide | 3,895 | 0.6% |
| voice-tone | 3,834 | 0.5% |
| tdd | 3,369 | 0.5% |
| c4 | 660 | 0.1% |
| **sum** | **687,430** | **97.6%** |
| (unattributed delta) | 16,872 | 2.4% — likely test/ fixtures or REFERENCE.md siblings the helper doesn't aggregate |

Sum-check: per-plugin sum 687,430 vs cheap-layer aggregate 704,302 — 16,872 byte gap. Marked `not estimated — helper-aggregation gap` per ADR-026.

## Top-N Offenders

| Surface | Bytes | Bucket | Comparable prior |
|---------|-------|--------|------------------|
| `packages/itil/skills/work-problems/SKILL.md` | 100,611 | skills/itil | P098 split-SKILL+REFERENCE pattern (`scripts/repo-local-skills/install-updates/{SKILL,REFERENCE}.md`) reclaimed REFERENCE-content out of SKILL runtime |
| `packages/itil/skills/manage-problem/SKILL.md` | 84,259 | skills/itil | Same as above (P098 + P097 SKILL.md size cluster) |
| `packages/retrospective/skills/run-retro/SKILL.md` | 73,377 | skills/retrospective | Same as above |
| `docs/decisions/` (21 ADRs in proposed state, aggregate) | 1,235,889 | decisions | not estimated — no comparable prior for ADR-content-removal-from-context (ADRs are read by architect-agent only on review, not loaded into main agent context unless cited) |
| `docs/briefing/releases-and-ci.md` | 15,522 (post-this-retro edits) | briefing | P145 MUST_SPLIT split-by-date archive — 2026-05-11 governance-workflow.md split precedent (this retro applied that pattern) |
| `docs/briefing/hooks-and-gates.md` | 13,182 | briefing | Same as above (P145 split-by-date) |
| `packages/itil/hooks/` (aggregate) | 95,780 | hooks/itil | ADR-038 + canonical+sync pattern (`shared/` 13,749 already extracted) |
| `packages/risk-scorer/hooks/` (aggregate) | 69,552 | hooks/risk-scorer | Same as above |

## Per-Turn Attribution

per-turn attribution: not measured — no session log accessible.

Session JSONL files searched: `${CLAUDE_PROJECT_DIR}/.afk-run-state/*.jsonl` returned `outstanding-questions.jsonl` + `risk-register-queue.jsonl` only — neither carries per-turn token usage data. Main-turn interactive sessions (this one) do not produce a turn-by-turn token-usage log on disk. Per ADR-026 line 90: marking ungrounded rather than fabricating.

## Suggestions

1. **skills/itil — P097 SKILL+REFERENCE split for the three SKILL.md > 50KB files.** Apply the ADR-038 progressive-disclosure pattern (`SKILL.md` carries runtime steps; sibling `REFERENCE.md` carries rationale, edge cases, ADR-cross-references) to: `packages/itil/skills/work-problems/SKILL.md` (100,611 bytes), `packages/itil/skills/manage-problem/SKILL.md` (84,259 bytes), `packages/retrospective/skills/run-retro/SKILL.md` (73,377 bytes). Comparable prior: `scripts/repo-local-skills/install-updates/{SKILL,REFERENCE}.md` (P098 reference implementation, 2026-04-22). Estimated byte saving: ~30–50% of each file moves to REFERENCE = ~30–50KB per skill = ~90–150KB reclaimed across the cluster. P097 (`SKILL.md files mix runtime-necessary steps with maintainer-facing rationale`) is the codification-tracking ticket; this report's measurements provide updated empirical evidence for P097's WSJF re-rate.

2. **briefing — apply P145 split-by-date Branch A rotation to the 2 MUST_SPLIT files**. `docs/briefing/hooks-and-gates.md` (13,182 bytes, ratio 2.575×) and `docs/briefing/releases-and-ci.md` (15,522 bytes, ratio 3.031×) both exceed 2× ceiling. Comparable prior: `docs/briefing/governance-workflow.md` 2026-05-11 split-by-date archive (this retro) — moved 6 entries to `governance-workflow-archive.md`, file size 13,481 → ~9,400 bytes. Estimated byte saving: ~3–5KB per file (~6–10KB total). The next `/wr-retrospective:run-retro` Tier 3 budget pass will mandate these rotations per Branch A; pre-empting reduces next-retro overhead.

3. **decisions — track but defer**. The decisions bucket (1,235,889 bytes, +51.8% delta) is on-disk only — ADRs are not loaded into main-agent context unless explicitly cited via `@adr` references in SKILL.md or briefing files. Architect-agent reviews load ADRs via grep/Read but the per-review cost is bounded by the prompt scope, not by the bucket size. The +51.8% delta reflects new ADR drafts (ADR-049 / ADR-050 / ADR-051 / ADR-059 / ADR-060 / ADR-044 + amendments) accumulated since 2026-04-29. Estimated byte saving via promotion: not estimated — no prior data on `proposed → accepted` reducing context usage (the file rename doesn't change the byte count).

4. **problems — fix the measurement methodology, not the surface**. The -85.6% delta (1,986,943 → 286,459) is a measurement artefact: `packages/retrospective/scripts/measure-context-budget.sh` measures `docs/problems/*.md` with a flat-layout glob; RFC-002 T5 migrated tickets to `docs/problems/<state>/*.md` per-state subdirs (commit `e31bd6a`, shipped via I002 mitigation H3 graduation 2026-05-10 in `@windyroad/risk-scorer@0.7.1`). The script (cached version) doesn't recurse into subdirs. **Fix**: the in-repo `measure-context-budget.sh` should be amended to dual-tolerant flat + per-state-subdir enumeration, mirroring RFC-002 T2/T3/T4 widening pattern. Estimated byte saving: zero (this is correctness, not reduction). Sibling pattern: `packages/itil/scripts/reconcile-readme.sh` (RFC-002 T4) ships dual-tolerant glob enumeration; same shape applies here. Eligible as P097-tier or new ticket — flag at next `/wr-itil:review-problems`.

5. **hooks/itil + hooks/risk-scorer (165KB combined, 54.9% of hooks bucket)** — apply ADR-028 / ADR-038 canonical+sync pattern to extract more hook helpers into `packages/shared/hooks/lib/`. Current `shared/` is 13,749 bytes (4.6% of hooks); itil and risk-scorer are 95,780 + 69,552. Comparable prior: ADR-028 `external-comms-gate.sh` extracted to `packages/shared/hooks/lib/` (P064). Estimated byte saving: not estimated — needs per-hook audit to identify duplicate-across-plugins logic candidates.

## Policy Breaches

| Budget | Offender | Bytes | Citation |
|--------|----------|-------|----------|
| Tier 3 (≤5120 bytes per topic file) | `docs/briefing/hooks-and-gates.md` | 13,182 | ADR-040 + P145 MUST_SPLIT (ratio 2.575×) |
| Tier 3 (≤5120 bytes per topic file) | `docs/briefing/releases-and-ci.md` | 15,522 | ADR-040 + P145 MUST_SPLIT (ratio 3.031×) |
| Tier 3 OVER (≤5120 bytes per topic file) | `docs/briefing/afk-subprocess-mechanics.md` | 9,093 | ADR-040 |
| Tier 3 OVER | `docs/briefing/afk-subprocess-recovery.md` | 9,397 | ADR-040 |
| Tier 3 OVER | `docs/briefing/agent-hook-gate-quirks.md` | 9,434 | ADR-040 |
| Tier 3 OVER | `docs/briefing/agent-interaction-patterns.md` | 6,684 | ADR-040 |
| Tier 3 OVER | `docs/briefing/governance-workflow-archive.md` | 5,274 | ADR-040 |
| Tier 3 OVER | `docs/briefing/governance-workflow-surprises.md` | 8,269 | ADR-040 |
| Tier 3 OVER | `docs/briefing/governance-workflow.md` | 9,411 | ADR-040 (post-this-retro split; reduced from 13,481) |
| Tier 3 OVER | `docs/briefing/plugin-distribution.md` | 8,975 | ADR-040 |
| P097 SKILL.md size cluster (>50KB) | `packages/itil/skills/work-problems/SKILL.md` | 100,611 | P097 (`docs/problems/open/097-skill-md-files-mix-runtime-and-rationale.md`) |
| P097 SKILL.md size cluster (>50KB) | `packages/itil/skills/manage-problem/SKILL.md` | 84,259 | P097 |
| P097 SKILL.md size cluster (>50KB) | `packages/retrospective/skills/run-retro/SKILL.md` | 73,377 | P097 |

13 breaches total (2 MUST_SPLIT, 8 OVER-but-not-MUST, 3 P097 SKILL.md cluster). The 2 MUST_SPLIT entries trigger Branch A non-deferrable rotation at next `/wr-retrospective:run-retro` Tier 3 pass per P145.

<!--
context-snapshot:
  total-bytes: 2869907
  hooks: 301115
  skills: 704302
  memory: 192370
  briefing: 104629
  decisions: 1235889
  problems: 286459
  jtbd: 40866
  project-claude-md: 4277
  framework-injected: not measured
  measurement-method: byte-count-on-disk
  measured-at: 2026-05-11T00:00:00Z
  retro-iter: post-i002-mitigation
  notes-on-deltas:
    - problems-bucket: -85.6% is methodology artefact (flat-glob vs per-state-subdir post-RFC-002-T5); fix tracked as Suggestions §4
    - decisions-bucket: +51.8% reflects new ADR drafts (ADR-049/050/051/059/060/044) accumulated since 2026-04-29
    - briefing-bucket: +30.9% post-this-retro edits added 24,751 bytes; rotations applied (governance-workflow split) but 2 MUST_SPLIT remain
-->
