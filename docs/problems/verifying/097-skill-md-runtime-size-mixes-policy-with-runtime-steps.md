# Problem 097: SKILL.md files mix runtime-necessary steps with maintainer-facing rationale, bloating every skill invocation

**Status**: Verification Pending
**Reported**: 2026-04-22
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: L
**WSJF**: 0 (Verification Pending — excluded from ranking per ADR-022)

> Split from P091 meta (session-wide context budget) on 2026-04-22. Size data collected during the P091 audit is already damning — the RCA is confirmed on magnitude. What remains unproven is the fix path: whether the "runtime steps vs reference material" split is achievable without runtime support from Claude Code. Hence Open, not Known Error, until the fix path is validated.

## Fix Released

P097's defined scope (Phase 1 declarative contract + empirical baseline + Phase 2-3 carve-out) is complete. Residual extraction work is properly tracked in sibling tickets P241 / P242 / P243.

**Phase 1 declarative contract** — shipped 2026-05-03 via `@windyroad/retrospective` minor bump:
- ADR-054 (proposed) `docs/decisions/054-skill-md-runtime-budget-policy.proposed.md` codifying `[runtime]` / `[reference]` / `[deprecated]` per-paragraph taxonomy, sibling-REFERENCE.md pattern, ≤ 20-pointer / ≤ 1.6 KB pointer-overhead ceiling, WARN ≥ 8 KB / MUST_SPLIT ≥ 16 KB byte budgets, mechanical/silent lazy-load reads per ADR-044, opportunistic-as-touched migration shape per ADR-052
- Advisory detector `packages/retrospective/scripts/check-skill-md-budgets.sh` (read-only, exit 0 always, exit 2 on parse error)
- Bin shim `packages/retrospective/bin/wr-retrospective-check-skill-md-budgets` per ADR-049 grammar
- 21 behavioural bats in `packages/retrospective/scripts/test/check-skill-md-budgets.bats` (all behavioural per ADR-052; no greps of script source)
- Dogfood baseline: 20 SKILL.md files OVER WARN; 9 MUST_SPLIT — the dogfood output IS the Phase 2-3 prioritisation backlog

**Empirical baseline** — shipped 2026-05-17 (`/wr-itil:work-problems` AFK iter 8):
- First canonical ADR-054 worked example: `packages/retrospective/skills/analyze-context/SKILL.md` → sibling `REFERENCE.md` extraction
- Measured: SKILL.md 15,638 → 14,426 bytes (−1,212 / −7.7%); REFERENCE.md 2,249 bytes new
- 18/18 sibling structural-grep bats remain green (no contract regression); 21/21 detector bats remain green
- Architect verdict PASS (scope ADR-054-compliant; outside P081-blocked top-10 cohort); JTBD verdict PASS (JTBD-001 / JTBD-006 / JTBD-101 served); Risk verdict CONTINUE / Very Low (mechanical content move, user-invoked skill, single-skill blast radius)

**Phase 2-3 carve-out** — captured 2026-05-17 per P179 umbrella-per-cohort granularity (architect Q6):
- **P241** — ADR-054 sibling-REFERENCE.md extraction MUST_SPLIT cohort (10 skills incl. work-problems / manage-problem / run-retro); `Blocked by: P081` Layer B
- **P242** — ADR-054 sibling-REFERENCE.md extraction for project-local `.claude/skills/install-updates/`; coupling-dependent block (may unblock independently of P241)
- **P243** — ADR-054 sibling-REFERENCE.md extraction WARN-band cohort (24+ skills OVER WARN but below MUST_SPLIT); defer-permitted per ADR-054 line 100, opportunistic per-touch with escalation to P241 on heavy-coupling

**Phase 4 ADR codification** — ADR-054 reaches `proposed` state; acceptance flows through the standard wr-architect human-oversight drain (P283 / ADR-066 mechanism), not P097's responsibility.

### Verification

- `docs/decisions/054-skill-md-runtime-budget-policy.proposed.md` present
- `packages/retrospective/scripts/check-skill-md-budgets.sh` executes against this repo with `OVER WARN` / `MUST_SPLIT` summary; `wr-retrospective-check-skill-md-budgets` bin shim resolves on `$PATH`
- `packages/retrospective/skills/analyze-context/SKILL.md` carries lazy-load pointer; sibling `REFERENCE.md` present
- P241, P242, P243 sibling tickets present in `docs/problems/open/` with `Blocked by: P081` (P241) recorded
- 21/21 behavioural bats in `packages/retrospective/scripts/test/check-skill-md-budgets.bats` green
- Behavioural confirmation that the original symptom (top-10 SKILL.md bloat) is closing: trends on `check-skill-md-budgets` output across 2–3 retro cycles as P241 / P243 extractions land

## Description

Every `/wr-<plugin>:<skill>` invocation loads the full `SKILL.md` file into the conversation context. Windyroad `SKILL.md` files have grown to carry content for multiple audiences — runtime operators, maintainers, ADR-tracking, deprecation notices, worked examples — and most of that weight loads on every invocation even when only the runtime steps are needed.

Measured sizes across windyroad packages (top 10 by byte count, 2026-04-22 audit):

| Skill | Bytes | Lines | Est. tokens |
|-------|------:|------:|------------:|
| `/wr-itil:manage-problem` | 55032 | 699 | ~14000 |
| `/wr-itil:work-problems` | 39265 | 388 | ~9800 |
| `/wr-retrospective:run-retro` | 36292 | 290 | ~9100 |
| `/wr-itil:report-upstream` | 21489 | 360 | ~5400 |
| `/wr-itil:manage-incident` | 19845 | 302 | ~5000 |
| `/wr-itil:review-problems` | 16566 | 197 | ~4100 |
| `/wr-itil:mitigate-incident` | 14255 | 211 | ~3600 |
| `/wr-itil:restore-incident` | 13362 | 195 | ~3300 |
| `/wr-itil:close-incident` | 12198 | 181 | ~3000 |
| `/wr-itil:work-problem` | 12407 | 130 | ~3100 |

**Windyroad SKILL.md total: 360,686 bytes / ~90k tokens across 46 skills.** Direct observation from this session: invoking `/wr-itil:work-problem` followed by `/wr-itil:manage-problem` loaded ~67KB / ~17k tokens of SKILL.md content. Two skill invocations = ~8% of the 200K context window spent on skill reference material.

Also in scope: the local `.claude/skills/install-updates/SKILL.md` at 13524 bytes / 238 lines — project-local, directly editable here.

## Symptoms

- Invoking any governance skill (especially the ITIL ones) adds thousands of tokens to the conversation before the skill does any work.
- Sessions that invoke multiple skills back-to-back (common in problem work, incident management, retrospectives) burn context on SKILL.md bodies that mostly re-state policy the assistant already knows.
- The largest SKILL.md files (manage-problem, work-problems, run-retro) are the ones most commonly invoked during AFK loops — the cost compounds.

## Workaround

None for end-users. Design-space mitigations:

1. **Runtime-steps vs reference-material split**: each SKILL.md becomes a lean runtime file that carries only the step-by-step instructions needed to execute the skill. Policy, rationale, ADR cross-refs, worked examples, deprecation notices, and historical decisions move to a sibling `REFERENCE.md` (or per-topic files in a `docs/` subdir). The runtime-loaded SKILL.md links to the reference file; Claude reads it on-demand via the Read tool only when the situation needs that context.
2. **Aggressive trimming**: many of the longest blocks in large SKILL.md files are duplicated narrative (e.g. manage-problem's deprecated-argument-forwarders section repeats the same four-forwarder protocol four times, once per subcommand). Collapse duplicated structure using templates, tables, or a single parameterised description.
3. **Skill splitting (already started via P071)**: the P071 phased split of `manage-problem` into dedicated skills (`list-problems`, `review-problems`, `work-problem`, `transition-problem`) started this work. Continuing the split reduces any one skill's runtime footprint. Candidate for further split: `manage-problem` itself still carries all four forwarder blocks + all lifecycle transition logic; could narrow to "create + update only" with transitions fully delegated.

All three are plugin-controllable — no Claude Code runtime support is required. The "lazy-load REFERENCE.md on demand" pattern works today: the skill invocation loads the lean SKILL.md, and the skill's runtime steps include a `Read` of REFERENCE.md only when the situation matches. Today this is manual; tomorrow this is the standard pattern.

## Impact Assessment

- **Who is affected**: Every user invoking any windyroad governance skill. Highest impact: AFK orchestrator loops (`work-problems`, `run-retro`) that fire multiple big skills per iteration.
- **Frequency**: Every skill invocation.
- **Severity**: High on the ITIL skills (manage-problem is the biggest single-file context consumer in the plugin set). Moderate elsewhere.
- **Analytics**: Measurement harness from P091 meta. Can also count skill-invocation frequency across a representative AFK log.

## Root Cause Analysis

### Confirmed on magnitude (2026-04-22 audit — see Description table)

SKILL.md files are large. The measurement is direct.

### Hypothesised on fix path (needs design validation)

The design question is whether `REFERENCE.md` lazy-loading (runtime SKILL.md stays lean, reference material lives elsewhere and is Read on demand) actually preserves skill behaviour. Two risks:

1. **Assistant may not know when to consult REFERENCE.md.** The lean SKILL.md must explicitly flag which situations require reading the reference. If it doesn't, the assistant will try to execute without the context and miss edge cases the full SKILL.md used to carry inline.
2. **Some narrative in the current SKILL.md is essential at every invocation, not optional context.** For example, the "Staging trap (P057)" warning in manage-problem Step 7 is safety-critical — it must fire on every transition, not live behind a Read. Separating "must-always-see" from "read-if-situation-applies" is a judgement call per skill.

### Investigation tasks

- [ ] Pick the top-three offenders (manage-problem, work-problems, run-retro) and line-audit each SKILL.md: tag every section as `[runtime]` (must stay inline), `[reference]` (can move to REFERENCE.md), or `[deprecated]` (can be deleted entirely).
- [ ] Measure the runtime-footprint reduction for each of the three after the split. Target: ≥50% byte reduction per file without losing any `[runtime]`-tagged content.
- [ ] Build a prototype split for manage-problem. Validate that all existing bats contract tests still pass and a real `/wr-itil:manage-problem 091 known-error` flow still works end-to-end.
- [ ] Draft or extend ADR: either a new "SKILL.md runtime budget policy" ADR, or a section in the "Hook injection budget policy" ADR (P091 anchor) covering the same principles for skill content.
- [ ] Apply the same line-audit + split to `.claude/skills/install-updates/SKILL.md` (project-local, ~13.5KB).
- [ ] Roll out the split pattern across the remaining top-10 SKILL.md files.

## Fix Strategy

**Phase 1 (audit + design validation)**: line-tag manage-problem; build a prototype split; confirm contract tests pass.

**Phase 2 (top-3 rollout)**: split manage-problem, work-problems, run-retro. Measure byte reduction.

**Phase 3 (full rollout)**: apply the pattern across the remaining top-10. Project-local `install-updates` gets the same treatment.

**Phase 4 (ADR)**: codify the `[runtime]`/`[reference]`/`[deprecated]` tagging convention and the REFERENCE.md pattern.

## Phase 1 Audit (2026-04-27)

Phase 1 line-tag + prototype-split attempt for `packages/itil/skills/manage-problem/SKILL.md`. Outcome: **partial-progress — extraction blocked on bats coupling**. SKILL.md was NOT modified; the 116-test contract suite remains green.

### Current state

| Metric | At ticket open (2026-04-22) | Phase 1 measurement (2026-04-27) | Delta |
|---|---:|---:|---:|
| `manage-problem/SKILL.md` bytes | 55,032 | 69,180 | +14,148 (+25.7%) |
| Lines | 699 | 804 | +105 |
| Contract bats — `manage-problem/test/` | not tallied | 116 (green baseline) | — |

The file has grown ~14KB / ~3.6k tokens since the audit four days ago — Phase 2 P096 work, P118 README reconciliation preflight, P124 session-id helper, etc. all landed prose. Pressure is increasing, not decreasing.

### Bats coupling — the dominant Phase 1 finding

`packages/itil/skills/manage-problem/test/` contains 116 contract assertions across 18 bats files. **80 of those assertions are `grep "<phrase>" "$SKILL_FILE"`** — explicit structural grep against SKILL.md content. The bats are spread across 14 of the 18 files (the other 4 mostly assert SKILL.md exists / has frontmatter). Per the bats file headers, every structural test is annotated as a `Permitted Exception to the source-grep ban (ADR-005 / P011)`.

Every structural-grep test pins a specific phrase to SKILL.md — and SKILL.md only. None of the existing bats consult a sibling REFERENCE.md. Moving content from SKILL.md to REFERENCE.md without updating the bats produces test failures in proportion to how much `[reference]` content moves.

### Section-by-section bats density

Loose mapping of the SKILL.md outline against grepped phrases. **bats-locked** = at least one specific phrase from this region is asserted by a structural test; **safe candidate** = no direct assertions found.

| Section | Lines | Anchors | Status |
|---|---|---:|---|
| Frontmatter (`deprecated-arguments: true`) | 1–6 | 1 | bats-locked |
| Output Formatting | 12–14 | 3 | bats-locked |
| First-run intake-scaffold pointer (P065 / ADR-036) | 17–33 | 0 | safe candidate |
| Operations + Closing problems | 35–49 | partial | partial |
| Problem Lifecycle table + Parked + Verification Pending | 51–73 | many | bats-locked |
| WSJF Prioritisation core (formula + multiplier + effort tables) | 75–110 | 5 | bats-locked |
| Transitive dependencies (P076) | 112–152 | 19 | heavily bats-locked |
| Working a Problem (Open / Known Error / Scope expansion) | 154–181 | 3 | partial |
| Step 0 README reconciliation preflight (P118) | 183–199 | 0 | safe candidate |
| Step 1 Parse + 4 deprecated-argument forwarders (P071) | 201–247 | 24 | heavily bats-locked |
| Step 2 Check duplicates | 249–274 | 2 | partial |
| Step 3 Assign next ID (ADR-019, P056, P124) | 276–300 | 4 | bats-locked |
| Step 4 Gather information | 302–314 | 0 | safe candidate |
| Step 4b Concern-boundary analysis (P016) | 316–336 | 6 | bats-locked |
| Step 5 Write file + README refresh (P094) | 338–411 | 4 | partial |
| Step 6 Update + conditional README refresh (P094) | 413–445 | 0 | safe candidate |
| Step 7 Status transitions + staging trap (P057) + README refresh (P062) | 447–557 | 11 | heavily bats-locked |
| Step 8 List | 559–561 | 0 | safe candidate |
| Step 9 Review (9a–9e + fast-path + Verification Queue + P048) | 563–717 | 12 | heavily bats-locked |
| Step 10 Quality checks | 719–731 | 0 | safe candidate |
| Step 11 Report (commit conventions + ADR-014) | 733–752 | 0 | safe candidate |
| Step 12 Auto-release (ADR-020 / ADR-042) | 754–803 | 0 | safe candidate |

### What can safely move to REFERENCE.md today

Sum of safe-candidate sections (no bats anchors): ~17 + 17 + 13 + 33 + 3 + 13 + 20 + 50 ≈ **166 lines / ~12–15KB / ~3–3.7k tokens**. About **18–22% byte reduction** if all safe sections moved.

The catch: every safe-candidate section is a **runtime procedural step** (preflight, gather info, update flow, list, quality checks, report, auto-release). Moving them to REFERENCE.md would defeat the runtime-vs-reference distinction the ticket articulates — these steps must execute on every relevant invocation, not be loaded on-demand.

The genuinely-`[reference]`-tagged content (rationale paragraphs, worked examples, deprecated-forwarder explanatory prose, Reassessment Criteria narrative, "Why a helper instead of inline ..." design-decision logs) is precisely the content the bats anchor. The ≥50% reduction target the ticket sets is unreachable while structural greps stay in force.

### Deferred-design questions (need user input before Phase 2)

1. **Resolve the bats coupling.** Two paths, mutually exclusive at the per-skill level:
   - **Path A — bats-update first.** Generalise every `grep "$SKILL_FILE"` to scan `SKILL.md` + `REFERENCE.md` together. Mechanical. Cements structural tests as the contract surface and runs counter to P081's user-direction-validated finding ("tests that check the source code contents are wasteful and not real tests").
   - **Path B — resolve P081 first.** P081 (Open, WSJF 3.0, L effort) replaces structural greps with behavioural assertions. Once P081 lands the framework/stubs and the retrofit, P097 Phase 2–3 can extract `[reference]` content freely. Slower up-front but aligns with user direction, removes the structural-bats blocker for *every* skill in the project, and unblocks P097's full byte-reduction target.

   Path B is the WSJF-correct choice — P081 is high-severity (every new test inherits the wrong style) and unblocks the entire SKILL.md-budget cluster. P097 Phase 2–3 should be marked `Blocked by: P081` until that resolves.

2. **`[runtime]` vs `[reference]` taxonomy for ambiguous sections.** Several large blocks resist clean classification:
   - **Deprecated-argument forwarders (Step 1)**: the forwarder dispatch IS runtime — it routes user invocations to the new skills. The repetitive prose explaining "why duplicating logic would harden the deprecation window into a permanent fork" (3× the same ~80-byte sentence) is reference. A future ADR (Phase 4) could codify a `[deprecated-runtime-with-reference-rationale]` triple-tag pattern.
   - **Transitive dependencies subsection (P076)**: the rule + Bash heuristic are runtime (review-step consumers); the worked example, cycle-handling explanation, and Reassessment-criteria paragraph are reference. The bats grep `## Dependencies` header + `**Blocked by**` bullets, but not the worked-example prose — so this is a sub-section split rather than a whole-section move.
   - **Step 7 transition lifecycle**: every git-mv block is runtime safety-critical (P057 staging trap fires on every transition). The "## README.md refresh on every transition (P062)" mechanism explanation is reference. But the trigger phrase `git log.*README\.md` is bats-anchored.

   Phase 4's ADR needs to specify the line-tag granularity: per-section, per-paragraph, or per-sentence. Per-sentence is mechanically required for sections like Step 7 where one paragraph mixes runtime triggers with rationale.

3. **REFERENCE.md discoverability budget.** The ADR-038 progressive-disclosure pattern requires the runtime SKILL.md to flag *which situations* require reading REFERENCE.md (e.g. "If the transition target is `verifying.md`, read REFERENCE.md § Verification Pending lifecycle for the staging-trap edge cases."). Each pointer adds 60–100 bytes. With ~15 estimated pointer-sites in manage-problem, that's ~1KB of pointer overhead — eating ~7% of the 12–15KB safe-candidate savings. Phase 4's ADR needs to budget this.

### Phase 1 deliverable

This audit IS the Phase 1 deliverable. SKILL.md was deliberately not modified — the bats coupling makes any extraction beyond the safe-candidate sections regression-positive. Updating the bats (Path A) preempts P081's user-validated direction; deferring to P081 (Path B) is the WSJF-correct sequencing.

**Recommended next-step record for Phase 2**: do not start P097 Phase 2 until P081 is at least at `Known Error` with a credible behavioural-test framework prototype. Mark P097 Phase 2 as `Blocked by: P081` in the Dependencies graph so the transitive-effort rule (P076) carries the block.

## Phase 1 Declarative Contract (2026-05-03)

Phase 1 declarative-first deliverable lands per the ADR-051 / ADR-052 / ADR-053 contract-first / measurement-second / rollout-third precedent. Re-measurement during this iter showed sizes have grown 50-144% since the 2026-04-22 audit:

| Skill | 2026-04-22 | 2026-05-03 | Δ |
|---|---:|---:|---:|
| `/wr-itil:work-problems` | 39,265 | 95,861 | +144% |
| `/wr-itil:manage-problem` | 55,032 | 82,808 | +50% |
| `/wr-retrospective:run-retro` | 36,292 | 70,105 | +93% |

Pressure is **accelerating**. Phase 1 ships the declarative contract to slow the accumulation; Phase 2-3 unblocks behind P081 Layer B for the actual extraction.

### Phase 1 deliverable

- **ADR-054** (proposed) — `docs/decisions/054-skill-md-runtime-budget-policy.proposed.md`. Codifies:
  - Per-paragraph content classification taxonomy: `[runtime]` (must stay inline) / `[reference]` (move to sibling REFERENCE.md) / `[deprecated]` (delete after window).
  - Sibling REFERENCE.md per-skill pattern with explicit "Read REFERENCE.md § X for Y" lazy-load pointers.
  - Per-skill pointer-overhead ceiling (≤ 20 pointers / ≤ 1.6 KB) — prevents defeating the byte budget by spamming pointers.
  - Byte budgets: WARN ≥ 8,192 bytes (rotation candidate, defer permitted); MUST_SPLIT ≥ 16,384 bytes (no defer). Vocabulary mirrors ADR-040 / P145 OVER / MUST_SPLIT pair on the briefing-tree surface verbatim — adopters learn one concept across two surfaces.
  - REFERENCE.md reads are mechanical / silent per CLAUDE.md P132 + ADR-044 silent-framework category.
  - Phase 2-3 migration shape: opportunistic-as-touched per ADR-052 verbatim (not big-bang).
- **Advisory detector** — `packages/retrospective/scripts/check-skill-md-budgets.sh`. Read-only; exit 0 always; exit 2 on parse error. Walks `<root>/packages/*/skills/*/SKILL.md` + `<root>/.claude/skills/*/SKILL.md`. Output sorted by `<plugin>/<skill>` identifier. Env-var overrides via `SKILL_MD_WARN_BYTES` / `SKILL_MD_MUST_SPLIT_BYTES`.
- **Bin shim** — `packages/retrospective/bin/wr-retrospective-check-skill-md-budgets` per ADR-049 grammar.
- **Behavioural bats fixture** — `packages/retrospective/scripts/test/check-skill-md-budgets.bats`. 21 tests, all behavioural per ADR-052 (no greps of script source).
- **Changeset** — `@windyroad/retrospective` minor bump.

### Dogfood baseline (2026-05-03 first run against repo)

20 SKILL.md files OVER WARN; 9 MUST_SPLIT (manage-incident, manage-problem, mitigate-incident, report-upstream, review-problems, transition-problem, transition-problems, work-problems, run-retro). The dogfood output IS the Phase 2-3 prioritisation backlog — extraction order will be driven by `bytes / invocation-frequency` once P081 Layer B unblocks.

### Phase 2-3 explicitly deferred

Phase 2 (top-3 offender extraction: manage-problem, work-problems, run-retro) and Phase 3 (remaining top-10 + project-local install-updates) are **`Blocked by: P081`** Layer B — the harness primitives needed to retrofit the 80 structural-grep bats assertions on manage-problem alone (identified in the 2026-04-27 audit) without losing coverage. The unblock criterion lives on P081's ticket, not this ticket.

## Empirical baseline (2026-05-17 — work-problems iter 8)

First concrete application of ADR-054's sibling-`REFERENCE.md` pattern: `packages/retrospective/skills/analyze-context/SKILL.md`. Picked as a low-coupling WARN-band target outside the P081-blocked top-10 cohort, to validate the mechanic end-to-end before P081 Layer B unblocks the heavy-coupling extraction work.

**Architect verdict** (PASS, 2026-05-17): scope ADR-054-compliant; `analyze-context` (rank ~14 by size, OVER WARN only, NOT in top-10 MUST_SPLIT cohort) is outside Phase 2-3's named block — the P081 dependency does not bind. Token-by-token verification confirmed all 19 structural-grep assertions in the sibling bats anchor runtime sections that don't move; bats remain green post-extraction.

**JTBD verdict** (PASS): JTBD-001 / JTBD-006 / JTBD-101 served; first canonical empirical example of the ADR-054 pattern for downstream plugin authors to copy.

**Risk verdict** (CONTINUE / Very Low): mechanical content move; user-invoked skill (per ADR-043 never-auto-fires); single-skill blast radius.

**Extraction shape**:
- Moved `## Composition with sibling measurements` (~700B) and `## ADRs cited` (~1KB) from `SKILL.md` → new sibling `REFERENCE.md`
- Added 2 lazy-load pointer lines to `SKILL.md` per ADR-054 § "Sibling REFERENCE.md pattern" (~280B total — well under the 1.6KB ceiling)
- REFERENCE.md uses single `# analyze-context — Reference` H1 + one-line orientation paragraph per architect verdict (no frontmatter required per ADR-054 line 88)

**Measurement**:

| File | Before | After | Δ |
|---|---:|---:|---:|
| `analyze-context/SKILL.md` bytes | 15,638 | 14,426 | **-1,212 (-7.7%)** |
| `analyze-context/REFERENCE.md` bytes | — | 2,249 | new |
| Structural-grep bats (sibling test/) | 18 green | 18 green | no regression |
| `check-skill-md-budgets.sh` bats | 21 green | 21 green | no regression |
| Skill remains OVER WARN | yes | yes | acceptable per ADR-054 § "Phase 2-3 sequencing" (WARN-band is rotation-candidate; full bring-under-budget is opportunistic follow-on) |

**Phase 2-3 follow-ons captured per P179 carve-out** (umbrella-per-cohort granularity per architect Q6):
- **P241** — ADR-054 sibling-REFERENCE.md extraction MUST_SPLIT cohort (10 skills incl. work-problems / manage-problem / run-retro). `Blocked by: P081` Layer B.
- **P242** — ADR-054 sibling-REFERENCE.md extraction for project-local `.claude/skills/install-updates/`. Coupling-dependent block; may unblock independently of P241.
- **P243** — ADR-054 sibling-REFERENCE.md extraction WARN-band cohort (24+ skills OVER WARN but below MUST_SPLIT). Defer-permitted per ADR-054 line 100; opportunistic per-touch with escalation to P241 if heavy-coupling discovered.

## Dependencies

- **Blocks**: P241 (MUST_SPLIT cohort umbrella), P242 (install-updates project-local), P243 (WARN-band cohort umbrella)
- **Blocked by**: (none for empirical-baseline scope; P241 inherits the P081 Layer B block)
- **Composes with**: P091 (parent meta), P095 (sibling — UserPromptSubmit), P096 (sibling — PreToolUse/PostToolUse), P098 (sibling — project-owned context contributors)

## Related

- **P091 (Session-wide context budget — meta)** — parent.
- **P095 (UserPromptSubmit hook injection)** — sibling; different surface but same "verbose prose by default" design flaw.
- **P096 (PreToolUse/PostToolUse hook injection)** — sibling.
- **P071 (Argument-based skill subcommands are not discoverable)** — P071's phased split already reduced manage-problem's size by extracting subcommands into dedicated skills. This ticket continues that trimming pressure.
- **P098 (Project-owned context contributors — global CLAUDE.md, local skills, memory)** — sibling covering non-plugin surfaces. Project-local `install-updates` SKILL.md sits at the boundary — included in P097's Phase 3 because the fix pattern is the same as other windyroad SKILL.md files.
- **ADR anchor**: "Hook injection budget policy" OR a dedicated "SKILL.md runtime budget policy" (TBD during Phase 4).
