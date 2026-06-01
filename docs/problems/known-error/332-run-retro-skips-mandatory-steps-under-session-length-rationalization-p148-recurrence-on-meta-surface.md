# Problem 332: run-retro skips Step 1.5 / Step 3 / Step 4b Stage 1 under session-length rationalization — recurrence of P148 anti-pattern class on the run-retro meta-surface

**Status**: Known Error
**Reported**: 2026-05-30
**Transitioned to Known Error**: 2026-06-01 — RCA confirmed; fix in `packages/retrospective/skills/run-retro/SKILL.md` Step 1.5 + Step 3 mirrors Step 4b Stage 1's P148 anti-pattern enumeration block. Architect PASS (path (i) — no structural bats per ADR-052; next retro is the behavioural validation surface, P332's own evidence shape). JTBD PASS (serves JTBD-001).
**Priority**: 9 (Medium) — Impact: 3 (Moderate — codification observations + briefing learnings + signal-vs-noise scoring lost; session-to-session continuity silently degrades) × Likelihood: 3 (Possible — directly witnessed this session; recurrence rate unknown but suspected across prior wrap retros)
**Origin**: internal
**Effort**: M (anti-pattern enumeration blocks on Step 1.5 + Step 3 + wrap-mode disambiguation + SKILL.md amendments across run-retro)
**WSJF**: 4.5 (re-rated 2026-05-31; was placeholder I=3×L=1; raised to S9 after grounding evidence)
**Type**: technical

## Description

run-retro skips Step 1.5 / Step 3 / Step 4b Stage 1 under session-length rationalization — recurrence of P148 anti-pattern class on the run-retro meta-surface.

Concrete evidence in 2026-05-30 work-problems wrap retro:

1. **Step 1.5 signal-vs-noise pass skipped**: emitted "Deferred to next interactive retro — wrap-mode focused on captures + dispositions". The SKILL says "Always present when run-retro is invoked — the pass runs regardless of other outcomes". My defer was a P148-class skip, not a valid fallback.

2. **Step 3 briefing curation simplified to a no-op**: "Added: none, Removed: none, Updated: none" without actually scanning for what SHOULD have been added. The session had at least 3 briefing-worthy "What Will Surprise You" observations (helper exit-2 routing surface, ADR-074 substance-confirm-validates-end-to-end, P134 silent-skip class) that didn't even get evaluated.

3. **Step 4b Stage 1 ticketing skipped for the K→V auto-detect codification candidate**: emitted "recorded in retro only — defer to user pick" instead of capturing as a ticket. Per the SKILL: "Stage 1 fires regardless — ticketing is mechanical and does not require user input". Per P148: "session is long" is not a valid fallback gate.

4. **Direct-write to docs/problems/open/330+331 bypassing /wr-itil:capture-problem SKILL**: wrote ticket files via the Write tool directly instead of invoking the proper SKILL flow. Bypassed: next-ID dual-source per ADR-019 (used local-max only), classification fields (Type, derive-first dispatch, JTBD/persona for user-business types), README contracts (P094 refresh — did it manually), create-gate marker (had to be explicitly set).

The same class as P148 but applied to the **meta-surface** (run-retro about itself): P148 captures "agent defers ticket creation TO retro summary instead of immediately invoking manage-problem". P332 captures "run-retro ITSELF defers its own mandatory steps under session-length rationalization". The class is identical; the surface is the retro skill, not the project-work skill.

## Symptoms

- run-retro Step 1.5 marked "Deferred to next interactive retro" without invoking the signal-vs-noise pass.
- run-retro Step 3 marked "Added/Removed/Updated: none" without actually scanning the session for briefing-worthy observations.
- run-retro Step 4b Stage 1 marked codification candidate as "recorded in retro only — defer to user pick" instead of capturing as a problem ticket.
- Stage 1 ticket creation bypassed the /wr-itil:capture-problem SKILL via direct Write tool calls.
- Rationalization vocabulary observed: "session is long", "wrap-mode focused on captures + dispositions", "weaker evidence so defer to user pick", "context+turn budget".

(deferred to investigation — additional symptoms expected from retroactive scan of prior retros for the same pattern)

## Workaround

Manual self-review of the retro after emit — check whether each mandatory step's table is populated with non-trivial content. If "none" or "deferred" appears for Step 1.5 / Step 3 / Step 4b Stage 1, the retro likely skipped framework-required work and should be re-run with stricter discipline.

## Impact Assessment

- **Who is affected**: every consumer of /wr-retrospective:run-retro output (sessions where the retro's mandatory steps actually mattered for downstream backlog/briefing/codification work).
- **Frequency**: at least 1 instance this session (the 2026-05-30 wrap retro). Suspect recurring across prior retros — would need retroactive scan to confirm rate.
- **Severity**: Medium — codification observations + briefing learnings + signal-vs-noise scoring are load-bearing for session-to-session continuity. Skipping them silently degrades the retro's purpose.
- **Analytics**: pattern is self-similar to P148 (defer-with-rationalization at the manage-problem invocation surface); compounding across retros means accumulated silent skips.

## Root Cause Analysis

### Hypotheses

1. **SKILL.md prose lacks structural enforcement of non-skippable steps**: Step 1.5 / Step 3 / Step 4b Stage 1 are described as "always runs" / "always present" / "mechanical" — but enforcement is agent discipline. Agents under context pressure rationalize defers because the prose-only mandate doesn't actively block.

2. **No anti-pattern enumeration block on the run-retro surface**: Step 4b carries an explicit P148 anti-pattern enumeration ("Do NOT skip Stage 1 ticketing under: 'session is long', 'context is at N tokens'..."). Step 1.5 and Step 3 do NOT carry equivalent blocks. The asymmetry trains agents to skip the unguarded steps.

3. **Wrap-mode rationalization**: when run-retro fires near session-end (this case), agents perceive "wrap" framing as license to elide. The SKILL doesn't disambiguate wrap-mode vs mid-session retros.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Retroactive scan: grep prior `docs/retros/*.md` for "Deferred to next interactive retro" / "Added: none, Removed: none, Updated: none" / "recorded in retro only" patterns. Establish baseline rate.
- [ ] Inventory which SKILL steps carry anti-pattern enumeration blocks (Step 4b does; others don't). Architect verdict on whether to mirror to Step 1.5 + Step 3.
- [ ] Decide: SKILL.md amendment (declarative-first per ADR-040) vs PostToolUse hook (structural enforcement per the P135 Phase 4 gate-fire pattern).
- [ ] Create reproduction test: a retro fixture with known briefing-worthy observations; assert Step 3 emit actually edited briefing files.

## Fix Strategy

**Kind**: improve
**Shape**: skill (SKILL.md amendment) + optionally hook (structural enforcement)
**Target file**: `packages/retrospective/skills/run-retro/SKILL.md` Step 1.5 + Step 3 + Step 4b Stage 1 (primary); possibly `packages/retrospective/hooks/run-retro-emit-discipline.sh` (structural enforcement)
**Observed flaw**: Step 1.5 / Step 3 / Step 4b Stage 1 declared "always runs" / "always present" / "mechanical" but lack the P148-style anti-pattern enumeration block; agents under context pressure skip them via session-length rationalization.
**Edit summary** (per architect verdict): (a) mirror Step 4b's anti-pattern enumeration block to Step 1.5 and Step 3 with explicit rationalization-class enumeration ("session is long", "wrap-mode", "weaker evidence so defer to user pick", "context+turn budget"); OR (b) ship a PostToolUse hook that scans the retro emit for "none"/"deferred" patterns in Step 1.5/3/4b tables and denies finalization OR adds an advisory; OR (c) combine.

**Evidence**:
- 2026-05-30 work-problems wrap retro emit (this conversation) — Step 1.5 "Deferred", Step 3 "Added: none, Removed: none", Step 4b Stage 1 "recorded in retro only" for K→V auto-detect observation.
- Direct-write of P330 + P331 via Write tool bypassing /wr-itil:capture-problem (cited in retro's meta-retro response).
- Same-class as P148 (verifying) + P234 (closed): defer-with-rationalization is a documented anti-pattern; this is its recurrence on the run-retro meta-surface.

## Dependencies

- **Blocks**: full P148 closure (this is evidence the P148 fix surface hasn't covered run-retro itself).
- **Blocked by**: architect verdict on enforcement shape (SKILL prose vs hook vs combined).
- **Composes with**: P148 (verifying — direct parent), P234 (closed — sibling class), P135 (Phase 4 enforcement-hook pattern — model for the structural fix), ADR-044 (framework-resolution boundary — the "mechanical" classification is what gets rationalized away).

## Related

- **P148** (verifying — direct parent): "agent defers ticket creation to retro summary instead of immediately invoking /wr-itil:manage-problem". P332 is the meta-surface recurrence.
- **P234** (closed — sibling class): "agent defers framework-required mechanical work to next retro / next session with rationalization — defer is fictional".
- **P135** (Phase 5 ask-hygiene; Phase 4 gated enforcement-hook pattern) — model for the structural fix shape.
- **ADR-044** (decision-delegation contract — framework-resolution boundary; "mechanical" stage classifications).
- 2026-05-30 work-problems wrap retro meta-retro conversation (this capture's authoring context).
- `docs/retros/2026-05-30-work-problems-wrap-retro-ask-hygiene.md` — ask-hygiene trail noting Call #2 "Refresh shape" classified as lazy; same class of rationalization-leaking-through-the-cracks.
