# Problem 101: `wr-retrospective` has no context-usage analysis — opaque where session tokens are consumed; no guidance on what to trim

**Status**: Verification Pending
**Reported**: 2026-04-22
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: XL (re-rated 2026-04-26 — architect verdict expanded scope from L to XL: new sibling ADR-043 + amendments to ADR-026 / ADR-014 + new skill + new diagnostic script + 2 bats fixtures + Step 2c block in run-retro SKILL.md)
**WSJF**: (12 × 2.0) / 8 = **3.0**

> Status transitioned Open → Known Error 2026-04-26 — root cause confirmed, fix path clear, fix landing in this commit. ADR-043 (Progressive context-usage measurement and reporting for retrospective sessions) is the architect-verdict-resolved settlement of the Fix Strategy. Verification Pending follows the next release per ADR-022.

> User direction 2026-04-22: *"context tends to bloat over time. It would be nice if the retrospective plugin could analyse where tokens are being consumed (maybe the same way that https://github.com/getagentseal/codeburn does) and suggest improvements or flag problems, either as part of the run-retro skill or as part of a new skill. I'd prefer it to be part of run-retro, but if it's really heavy and consumes lots of tokens to execute, then I don't want to do it every retro as that would be its own bloat."*

## Description

Context-budget problems (P091 and its cluster P095/P096/P097/P098/P099/P100) are detected and addressed **reactively** — the user notices bloat, opens a ticket, the cluster audits a specific surface, fixes land per surface. There is no **proactive measurement** baked into the normal workflow. Each retro session ends without the assistant ever computing "where did the tokens go this session" and without suggesting "these files / hooks / skills ate the largest budget this session — consider trimming."

Codeburn (user reference: https://github.com/getagentseal/codeburn) is the conceptual model: analyze token consumption, attribute to source, suggest improvements. The windyroad suite's equivalent would live in `wr-retrospective` since retros already reflect on "what hurt this session" — token bloat is a natural axis to add.

**User's delivery-mode preference**:
1. **Preferred**: integrate into `run-retro` as a new Step. Output a per-surface breakdown (hooks, skills, memory, BRIEFING, MCP preamble, framework listings) + top-N offenders + actionable suggestions.
2. **Fallback**: if the analysis itself is expensive enough to be its own bloat source (e.g. > 5% of session budget per invocation), factor out to a separate skill `/wr-retrospective:analyze-context` (or similar) invoked on demand, and have `run-retro` emit only a lightweight summary line pointing at it.
3. **Rejected shape**: running expensive analysis on every retro. The whole point is reducing context bloat; if the analyzer is itself bloat, the feature is self-defeating.

## Symptoms

- Every session pays preamble cost (~30–40% of 200K window per P091's estimate); users only find out where it went by reverse-audit after bloat becomes visible (e.g. early compaction, slow turns).
- Each P091-cluster child ticket (P095/P097/P098/P099/P100) was identified by human observation, not by automated measurement.
- The P091 meta's investigation task *"Build a measurement harness (`packages/shared/bin/measure-context-budget.sh` or equivalent) that counts hook output bytes per firing, totals a representative N-turn session's injections, and reports before/after deltas"* is unimplemented — this ticket supersedes that task with a broader analyzer + suggestion layer.
- No metric is reported at retro time for "hook preamble bytes this session", "SKILL.md bytes loaded this session", "memory files loaded this session", etc.

## Workaround

Manual audit on user observation. Examples this session: user noticed bloat on CLAUDE.md pointers; user flagged BRIEFING.md accumulator pattern; user identified `wr-retrospective` missing session-start announcement. Each required human pattern-spotting to start.

## Impact Assessment

- **Who is affected**: Every session in every adopter project. Primary signal: long retrospective-heavy or AFK-loop sessions that hit compaction earlier than expected.
- **Frequency**: Every session contributes context cost; the absence of measurement means the cost compounds before it's noticed.
- **Severity**: Moderate. Reactive audits have worked so far but don't scale — as the plugin surface grows, more context sources will silently accumulate. Proactive measurement catches issues before the user has to notice.
- **Analytics**: This ticket is itself the analytics layer for the P091 cluster.

## Root Cause Analysis

### Confirmed (2026-04-22)

- `packages/retrospective/skills/run-retro/SKILL.md` has no step that measures or reports context usage. Steps cover: read BRIEFING, reflect on the session, scan pipeline instability (Step 2b), update BRIEFING (Step 3), create / update tickets (Step 4), verification housekeeping (Step 4a), codification (Step 4b), summary (Step 5). None measure tokens.
- `packages/retrospective/hooks/` contains one hook (`retrospective-reminder.sh`) — a Stop hook reminding the user to run retro. No measurement hook.
- P091 meta explicitly names the measurement harness as an investigation task but hasn't acted on it. The broader analyzer-and-suggestion shape this ticket proposes subsumes that task.
- Codeburn's design (cited by the user) — treating token consumption as a first-class observable with attribution + recommendations — is the right conceptual frame. Claude Code exposes session-level cost/token metadata via `claude -p --output-format json` (per BRIEFING line 50: `total_cost_usd`, `duration_ms`, `usage.{input,output,cache_creation,cache_read}_tokens`) and per-iteration `.jsonl` logs (BRIEFING line 53). The raw measurement surface exists; `wr-retrospective` just doesn't use it yet.

### Investigation tasks

- [x] Confirm no existing context-usage analysis step in run-retro (2026-04-22 audit).
- [x] Codeburn study (2026-04-26) — divergent design chosen: byte-count-on-disk + jsonl `usage` hybrid rather than codeburn's pure LLM-side approach. Documented in ADR-043 Considered Options 1-4 + Reassessment Criteria.
- [x] Measurement-surface enumeration (2026-04-26) — settled in ADR-043 "Measurement methodology" section: `wc -c` on disk for the cheap layer (hooks / skills / briefing / decisions / problems / jtbd / project-claude-md / memory + framework-injected sentinel); `usage` aggregation from `${CLAUDE_PROJECT_DIR}/.afk-run-state/*.jsonl` or `claude -p --output-format json` for the deep layer.
- [x] Granularity decision (2026-04-26) — per-source-bucket aggregation in the cheap layer; per-plugin decomposition + per-turn attribution in the deep layer. ADR-043 "Per-plugin attribution" section.
- [x] Integration-surface decision (2026-04-26) — Option (c) two-layer chosen per architect verdict + user direction. Cheap layer integrated into `run-retro` Step 2c; deep layer is the new `/wr-retrospective:analyze-context` skill.
- [x] Suggestion / flagging heuristic design (2026-04-26) — settled in ADR-043: ADR-026-grounded suggestions citing comparable-prior reclamations (P095/P099/P100) + concrete byte counts; `not estimated — no prior data` sentinel when no prior exists. Banned qualitative phrases enumerated.
- [x] Reporting shape decision (2026-04-26) — separate `docs/retros/<date>-context-analysis.md` artefact for the deep layer; inline summary block in run-retro's retro summary for the cheap layer. Both obey progressive-disclosure conventions per ADR-038. The deep-layer artefact carries an HTML-comment `context-snapshot:` trailer (precedent: ADR-040).
- [x] Architect review at design-time (2026-04-26, agentId aeb2fc262d343ceda) — ISSUES FOUND resolved in this commit. Verdict: Option B (sibling ADR), HTML-comment-trailer snapshot, byte-counting-on-disk + not-measured sentinels, static upper-bound frequency guard. Resolution: ADR-043 authored + ADR-026 amended (analyze-context skill added to per-agent prompt list) + ADR-014 amended (commit-message convention row added).
- [x] JTBD review (2026-04-26, agentId adbfca919bb33bbee) — PASS. Confirmed served jobs: JTBD-001 (Enforce Governance Without Slowing Down) primary, JTBD-006 (Progress the Backlog While I'm Away) for AFK loops, JTBD-005 (Invoke Governance Assessments On Demand) for the deep skill. Architect's nominated JTBD-101 dropped (plugin-developer concern is documentation-pattern-reuse, not a job served). Plugin-developer attribution affordance (per-plugin decomposition in deep layer) and OSS-adopter silence affordance (`not measured` sentinels everywhere) flagged and addressed.

## Fix Strategy

**Two-layer design (reflects user's A-then-C preference chain)**:

1. **Cheap layer — integrated into `run-retro`**. A new Step 2c that runs every retro, costs < 5% of session budget, and reports:
   - Per-source bucket byte/token totals (rough attribution).
   - Top-5 offenders by size.
   - Simple delta-from-last-retro if available.
   - A pointer to the deep analyzer when anything looks anomalous.

2. **Deep layer — standalone skill `/wr-retrospective:analyze-context`**. On-demand analyzer that runs richer heuristics — per-turn attribution, suggestion generation, policy-breach detection, per-plugin deep-dive. Invoked by the user when the cheap layer surfaces a concern, or periodically (every Nth retro, user choice). Output shape: a markdown report saved to `docs/retros/<date>-context-analysis.md` (lives long-term; composes with P099's bloat rules — the report itself must follow progressive-disclosure conventions).

3. **Frequency guard on the cheap layer**: if the cheap layer's own cost exceeds the budget (< 5% of session), the layer is unfit — move it entirely to on-demand. User's explicit rejection: "I don't want to do it every retro as that would be its own bloat."

4. **Architectural amendment**: the ADR anchor on P091 ("Progressive disclosure for governance tooling context") grows to cover this ticket too, or a sibling ADR is authored specifically for context-usage measurement. Architect decides at implementation time.

## Dependencies

- **Blocks**: (none directly; but once this ships, P091's investigation-task "Build a measurement harness" gets checked off as subsumed)
- **Blocked by**: (none)
- **Composes with**: P091 (parent meta — this ticket subsumes its measurement-harness task), P099 (BRIEFING bloat — analysis would flag it; report output must itself obey P099 discipline), P100 (artifact surfacing — analysis could trigger surfacing recommendations), P088 (run-retro context visibility — the deep layer needs to see the full session context, matching P088's concern)

## Fix Released

Released in `@windyroad/retrospective@0.10.0` (commit `75238fb` fix → release commit `4387824`, merge `12c24d8`):
- Two-layer context-usage analyzer per ADR-043 (Progressive context-usage measurement and reporting)
- Cheap layer: lightweight summary integrated into `run-retro` Step 2c
- Deep layer: new `/wr-retrospective:analyze-context` skill for on-demand analysis
- Per-surface breakdown (hooks, skills, memory, BRIEFING, MCP preamble, framework listings) + top-N offenders + actionable suggestions
- ADR-026 amended (per-agent prompt amendments target list); ADR-014 amended (commit-message convention row for deep-skill output)

Awaiting user verification: next `/wr-retrospective:run-retro` invocation should emit the Step 2c summary line; on-demand `/wr-retrospective:analyze-context` should produce the deep-layer breakdown without itself bloating beyond the 5%-of-budget soft cap.

## Related

- **ADR-043** (Progressive context-usage measurement and reporting for retrospective sessions) — sibling-ADR settlement of this ticket's Fix Strategy. Authored 2026-04-26 in this commit per architect verdict (agentId aeb2fc262d343ceda).
- **ADR-026 amendment** — `packages/retrospective/skills/analyze-context/SKILL.md` added to the "Per-agent prompt amendments" target list (lines 94–101). Amended within ADR-026's reassessment window.
- **ADR-014 amendment** — `docs(retros): context analysis YYYY-MM-DD` row added to the Commit Message Convention table for the deep skill's output. Amended within ADR-014's reassessment window.
- **P091** (Session-wide context budget — meta) — parent meta. This ticket subsumes P091's measurement-harness investigation task with a broader analyzer-and-suggestion shape.
- **P095 / P097 / P098 / P099 / P100** — sibling P091 children. P101 is the proactive-detection layer; the others were reactive-remediation for specific surfaces. Once P101 ships, similar future surfaces should get caught at retro time rather than requiring human observation.
- **P088** (run-retro cannot see full context when invoked as subagent/subprocess) — adjacent run-retro quality issue. The deep analyzer in this ticket needs to see full session context, making P088's resolution a soft prerequisite for option (b)/(c) delivery modes.
- **P050 / P044** (run-retro codification axes) — adjacent. This ticket adds a new reflection axis ("context usage") alongside the existing ones.
- **Codeburn** (https://github.com/getagentseal/codeburn) — user reference for the conceptual shape. Investigate at implementation time for analysis axes + suggestion patterns + measurement approach.
- **ADR-038** (progressive disclosure for governance tooling context) — the pattern anchor. A sibling ADR (or amendment) will govern the measurement contract, sampling policy, and report shape for P101.
- **ADR-023** (wr-architect performance review scope) — byte-budget glob (`performance-budget-*`) is the existing precedent for making performance metrics discoverable. This ticket's analyzer should emit findings in a format compatible with that glob so the architect review can consume them.

## Fix Strategy — self-contained-work vs recurring-pattern classification

Per run-retro Step 4b Stage 2 / P075: this ticket is not a one-shot bounded edit; it introduces a new analytic surface with measurement, heuristics, reporting, and delivery-mode options. Marked as `create` Kind, `skill` shape (for the deep layer) + `skill — improvement` (for the cheap layer embedded in run-retro). Stage 2 recording: `Other codification shape` is also implicated if the ADR and report-output conventions land as their own files. Free-text fix-strategy recording is captured inline in the Fix Strategy section above.
