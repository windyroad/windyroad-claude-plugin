# Problem 034: Centralise risk reports for cross-project skill improvement

**Status**: Open
**Reported**: 2026-04-17
**Priority**: 6 (Medium) — Impact: Moderate (3) x Likelihood: Unlikely (2)
**Effort**: XL — home-dir storage pattern under `~/.risk-reports/` (or similar), skill-improvement feedback loop design for 8+ plugins (architect, jtbd, itil, voice-tone, style-guide, tdd, wardley, c4), new ADR (L → XL 2026-04-19 per P047: cross-project, cross-plugin, new ADR required)
**WSJF**: 0.75 — (6 × 1.0) / 8
**Type**: technical

## Direction decision (2026-04-20, user — AFK loop stop-condition #2)

**Storage location**: **Home directory, `~/.risk-reports/` or similar**. Per-user central store, not per-project, not external service, not git-synced to a central repo. Keeps the data on the user's machine (no third-party confidentiality exposure per RISK-POLICY.md), aggregates across every project the user touches, and avoids the overhead of wiring a sync step into every project's release pipeline.

Implication: the ADR draft narrows to:
- Exact path: `~/.risk-reports/<project-slug>/<YYYY-MM-DD-HH-MM-SS>.md` (or similar — path shape TBD during drafting).
- Write mechanism: `wr-risk-scorer:pipeline` subagent and/or `/wr-risk-scorer:assess-release` skill writes a copy to the central store alongside (or instead of) the local `.risk-reports/` copy.
- Read mechanism: a new `/wr-risk-scorer:review-history` skill (or similar) queries the central store to surface patterns for skill improvement.
- No external service. No cross-machine sync. Local-first.

**Options rejected**:
- Per-project `.risk-reports/` synced to a central git repo (`windyroad/risk-reports`) — rejected: adds sync plumbing, couples projects to a specific upstream, confidentiality review required for anything that touches an org-level repo.
- External service (Grafana/Datadog/custom) — rejected: third-party dependency, confidentiality exposure.
- Local-only, defer cross-project aggregation — rejected: the user wants the aggregation.

## Description

Each project stores pipeline risk reports in a local `.risk-reports/` directory (git-ignored). There are ~340 reports across 7 projects in `/Users/tomhoward/Projects/`. These reports contain structured risk assessment data (inherent/residual scores, controls applied, bypass justifications) that is valuable for improving the risk-scorer skill — but the data is scattered across project roots and inaccessible from a single location.

Two improvements are needed:

1. **Centralised storage**: Move or mirror risk reports to a location accessible across projects — e.g., `~/.claude/risk-reports/<project-name>/` — so that skill improvement workflows can aggregate data without scanning every project directory.

2. **Skill improvement feedback loop for all plugins**: Use centralised reports as input to a skill-creator-style improvement cycle (P012 covers the eval harness design). This is not just about risk-scorer — every plugin that produces structured output (architect compliance checks, JTBD alignment reviews, problem reviews, TDD state transitions, voice-tone reviews, style-guide reviews) should collect real-world outputs and feed them into an eval/improvement loop. The risk-scorer's `.risk-reports/` pattern is the proof-of-concept; the goal is a generic `~/.claude/skill-reports/<plugin-name>/` pattern that all plugins can adopt.

## Symptoms

- Risk reports are only visible within the project that generated them
- No way to compare risk scoring quality across projects (e.g., does the scorer over-score docs changes in bbstats the same way it does here?)
- The `risk-score.sh` UserPromptSubmit hook injects recent reports as context but only from the current project
- Skill improvement requires manually gathering reports from multiple directories
- Other plugins (architect, jtbd, itil, voice-tone, style-guide, tdd, wardley, c4) produce structured outputs but have no feedback collection at all
- No plugin has a systematic improvement cycle — improvements happen ad-hoc based on user frustration rather than data-driven evaluation

## Workaround

Manually browse `/Users/tomhoward/Projects/*/.risk-reports/` to find reports. The `risk-score.sh` hook auto-deletes reports older than 7 days, so historical data is lost.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-001) — governance tooling should self-improve from real usage data
  - Plugin-developer persona (JTBD-101) — extending or improving plugins requires understanding how they perform across projects
- **Frequency**: Every time someone wants to assess or improve skill quality
- **Severity**: Medium — the risk-scorer works; this is about improving it systematically rather than fixing a defect
- **Analytics**: ~340 reports across 7 projects as of 2026-04-17; reports auto-deleted after 7 days

## Root Cause Analysis

### Preliminary Hypothesis

The `.risk-reports/` storage was designed for session-scoped context injection (the `risk-score.sh` hook reads recent reports to provide scoring context). Cross-project aggregation and skill improvement were not in scope when the storage was designed.

### Investigation Tasks

- [ ] Design `~/.claude/risk-reports/<project-name>/` directory structure
- [ ] Decide retention policy: should centralised reports survive longer than the 7-day auto-delete in project-local storage?
- [ ] Update `risk-score-mark.sh` (PostToolUse hook) to write reports to both locations, or replace project-local storage entirely
- [ ] Update `risk-score.sh` (UserPromptSubmit hook) to read from centralised location
- [ ] Survey other plugins for structured output that could benefit from the same pattern:
  - architect: ADR compliance check results
  - jtbd: alignment check results
  - itil: problem review rankings
  - tdd: test cycle state transitions
- [ ] Design a generic `~/.claude/skill-reports/<plugin-name>/` pattern if multiple plugins should collect feedback
- [ ] Evaluate whether Anthropic's `skill-creator` eval harness (P012) can consume these reports as eval inputs
- [ ] Consider privacy: `~/.claude/` is user-global; ensure no project-specific secrets leak into report filenames or content

## Decision record

**ADR-035** (Centralised review reports for cross-project skill improvement — JSONL at `~/.claude/review-reports/`) — drafted 2026-04-21. Architect advisory correction: store name renamed from P034's tentative `~/.risk-reports/` to `~/.claude/review-reports/` (cross-plugin framing, not risk-scorer-exclusive). JSONL schema locked in Decision Outcome. Report-writing mandatory for every invocation of all `@windyroad/*` reviewer agents (architect, jtbd, voice-tone, risk-scorer, style-guide). New `/wr-risk-scorer:review-history` on-demand skill reads the aggregated store; run-retro P051 improvement-axis integrates consuming patterns. Per-project opt-out marker `.claude/.review-reports-opt-out`; AFK first-run defers opt-in via ADR-032 pending-questions artefact. Reviewer-agent report lines inherit P037 reason/evidence contract and ADR-026 grounded-claim discipline.

This ticket (P034) remains **Open** as the execution tracker. Closes when:
- Per-agent amendments land (each reviewer agent's doc carries the report-writing clause).
- `packages/shared/review-reports-schema.json` (JSON Schema draft) lands.
- `/wr-risk-scorer:review-history` skill lands.
- run-retro Step 2 prompt extension citing review-history lands.
- Bats coverage: schema conformance, opt-out marker honour, secret redaction sentinel test.
- Retention + size cap enforcement in review-history invocation pass.

## Related

- **ADR-035** (Centralised review reports) — decision record for this ticket.
- P033 (`docs/problems/033-no-persistent-risk-register.open.md`) — persistent risk register (standing risks vs ephemeral reports); centralised storage may host both
- P012 (`docs/problems/012-skill-testing-harness.open.md`) — skill testing/eval harness; centralised reports are a data source for skill improvement evals
- `packages/risk-scorer/hooks/risk-score-mark.sh` — the only place reports are written; needs modification
- `packages/risk-scorer/hooks/risk-score.sh` — reads reports for context injection; needs to read from new location
