# Iter retro — 2026-06-01 batch K→V transition

**Iter scope**: `/wr-itil:work-problems` AFK iter dispatched `/wr-itil:transition-problems` for 6 release-aged Known Error tickets (P181, P263, P327, P339, P340, P341) whose fixes shipped to npm. Single ADR-014 commit (8867422) covering 6 ticket renames + Status edits + `## Fix Released` sections + README WSJF row removals + Verification Queue insertions + line-3 + README-history rotation.

## Briefing Changes

None this iter. The transition is mechanical lifecycle progression covered by existing SKILL contracts (`/wr-itil:transition-problems`, ADR-022 K→V semantics, P062 README-refresh, P134 line-3 discipline).

## Pipeline Instability

Three iter-local observations from the batch transition:

1. **Signal**: `/wr-itil:transition-problems` SKILL contract specifies space-separated `<NNN> <status>` pairs; orchestrator supplied comma-separated. Agent adapted at parse time (stripped commas before pair-off) and the batch landed clean.
   **Category**: Skill-contract violations (input-tolerance gap).
   **Citation**: orchestrator iter args `263 verifying, 181 verifying, 327 verifying, ...` — SKILL.md `## Arguments` section pre-specifies space-separated only.
   **Dedup status**: new (no matching ticket for `transition-problems` arg-parsing tolerance).
   **Decision**: recorded in retro only — agent adapted successfully; SKILL might benefit from explicit comma-tolerance guidance OR an arg-shape lint, but the observed cost was zero this iter.

2. **Signal**: `Edit` tool refused with `File has not been read yet. Read it first before writing to it.` after `git mv docs/problems/known-error/<NNN>-*.md docs/problems/verifying/<NNN>-*.md` even though the file content had been Read at the OLD path immediately prior — path tracking is keyed to absolute path, not file content / inode.
   **Category**: Skill-contract violations (Edit-tool path-tracking gap downstream of `git mv`).
   **Citation**: 6× `Edit` tool calls returned `<tool_use_error>File has not been read yet. Read it first before writing to it.</tool_use_error>` after the batch `git mv` — recovered by Read-then-Edit at the new path (6 extra Read calls + 6 retry Edits — ~1 turn cost).
   **Dedup status**: new — P057 covers `git mv` + Edit staging-trap at the git layer, but NOT the Edit-tool path-tracking surface. **Iter context notes this is the second occurrence this session** — recurring class.
   **Decision**: candidate for user-ticketed follow-up on return — could be addressed by (a) Edit tool tracking by file content / inode rather than path, (b) `transition-problems` SKILL prescribing Read-after-`git mv` per pair before Status edit, or (c) a session-level memory entry reminding agents to Read after `git mv` if Edit will follow. Recorded in summary; not auto-ticketed because the agent fix-and-continued without broken state shipping.

3. **Signal**: initial Verification Queue insertion placed the 6 new 2026-06-01 entries ABOVE the existing 2026-05-31 entries (P346, P141), contradicting the documented `Released date ASC` sort discipline. Caught + fixed in one extra Edit round (remove + re-insert after P141) before commit; broken state never shipped.
   **Category**: Skill-contract violations (sort-discipline application class).
   **Citation**: VQ Step 4a render rules cite `Released date ASC (oldest at row 1)`; first insertion put 2026-06-01 (newer) ahead of 2026-05-31 (older) — same class as P150 (verifying: README VQ rendered newest-first contradicts oldest-first header).
   **Dedup status**: composes with P150 (which closed the documentation/rendering contradiction); this iter's regression is on the application side (agent didn't apply the now-documented contract correctly on first try).
   **Decision**: recorded in retro only — self-corrected within one Edit round. If recurrence is observed in future iters, candidate for a render-helper script (sort + insert) that bypasses agent judgement entirely.

**README inventory currency**: clean (13 packages; 0 drift_instances per `wr-retrospective-check-readme-jtbd-currency`).

## Verification Candidates

None. The 6 K→V transitions ARE this iter's work; same-session exclusion applies per Step 4a sub-step 8 — a session cannot verify its own fix beyond "the rename + Status edit landed". Subsequent-session exercise is the meaningful signal.

## Tickets Deferred

None. Pipeline Instability observations above are recorded under the AFK Rule 6 evidence-surfacing branch (Step 2b: `surface the evidence; defer the decision`), not under Step 4b Stage 1 — they are session-local friction observations awaiting user judgment on ticket worthiness, not framework-mediated direction-class observations.

## Topic File Rotation Candidates

Skipped — Step 3 budget pass did not run (no briefing edits this iter; no overflow signal).

## Context Usage (Cheap Layer)

| Bucket | Bytes | Δ vs prior | Notes |
|--------|-------|------------|-------|
| problems | 4,317,371 | not measured — no prior snapshot trailer parsed | dominant bucket; expected (large ticket corpus) |
| decisions | 1,757,518 | not measured | second-largest (ADR corpus + compendium) |
| skills | 1,008,498 | not measured | third-largest (the windyroad-claude-plugin suite source) |
| hooks | 443,813 | not measured | |
| memory | 386,571 | not measured | |
| briefing | 98,947 | not measured | well under per-topic-file aggregate cap |
| jtbd | 47,091 | not measured | |
| project-claude-md | 4,277 | not measured | |

Threshold: 10240 bytes (per-bucket cheap-layer envelope). `problems` / `decisions` / `skills` / `hooks` / `memory` exceed; this is the standing context-budget signal P327 + P194 address. Per-plugin breakdown available in `/wr-retrospective:analyze-context` (deep layer).

Deep analysis recommended — no prior snapshot present in current `docs/retros/*-context-analysis.md` set; first measurement of this project under the cheap-layer protocol per session-tracking; defer to next user-invoked deep run.

## Ask Hygiene (P135 Phase 5 / ADR-044)

The iter fired **0 AskUserQuestion calls** — entire iter ran under the AFK constraint `Do NOT call AskUserQuestion mid-loop (AFK)`. All decisions were framework-mediated (ADR-022 K→V semantics, ADR-014 commit grain, ADR-049 PATH-shim invocation, ADR-076 reported-first tier, P062 README refresh, P134 line-3 discipline). No lazy deferral surface; no R6 numeric gate fire candidate from this iter.

**Lazy count: 0**
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

Cross-session TREND per `check-ask-hygiene.sh`: `lazy_first=0 lazy_last=0 delta=+0` — within R6 reassessment envelope.

## Codification Candidates

None this iter. The 3 Pipeline Instability observations recorded above are detection-stage, not framework-resolved codification candidates — Stage 1 Step 4b ticketing is deferred per the explicit recurring/direction-setting classification:

- Observation (1) — **direction-setting** (SKILL-contract input-tolerance is a design choice — comma-tolerance vs strict-space gives a UX tradeoff; not framework-resolved). Queue at iter end if recurrence observed in a future iter.
- Observation (2) — **recurring class-of-behaviour** with 2× in-session occurrence; would normally route to mechanical-auto-ticket via `/wr-itil:capture-problem`. Deferred this iter due to AFK constraint + the observation being a TOOL-layer concern (Edit-tool path tracking) where the fix locus is outside the windyroad-claude-plugin codebase (it's an Anthropic-side Edit tool affordance). Candidate for session-level memory entry on return rather than a problem ticket.
- Observation (3) — **session-local agent error** (caught + fixed within one Edit round, no broken state shipped). Not recurring beyond this iter; not codification-worthy unless future iters show the pattern recurring.

## No Action Needed

- The K→V transition itself is mechanical lifecycle progression covered by `/wr-itil:transition-problems` SKILL contract + ADR-022 semantics + P062 README refresh + P134 line-3 discipline. No new codification required.
- The retro-on-iter shape (this file) per P086.

---

**Commit grain**: this retro commits its own work per ADR-014. The iter commit (8867422) is separate from this retro commit. No push (orchestrator owns release cadence).
