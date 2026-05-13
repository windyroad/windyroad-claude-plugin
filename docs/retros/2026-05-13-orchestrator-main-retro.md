# Session Retrospective — 2026-05-13 orchestrator main turn (/wr-itil:work-problems)

Scope: orchestrator's main turn covering `/wr-itil:work-problems` invocation through Step 6.75 halt + Step 2.5b user surfacing + interactive briefing rotation + Step 2.5b write-back commits. Sibling retros: iter 1 (`2026-05-13-p162-phase-2a.md`, P162 Phase 2a), iter 2 (`2026-05-13-iter-2-p185-retro.md`, P185 closed).

## Briefing Changes

No new entries this retro pass. The session-relevant briefing edits already shipped at commit `80d4197` (Tier 3 MUST_SPLIT rotation — 3 main files reduced, 2 new archive siblings created) per Step 3 Branch A heuristic (P145 + ADR-040). The orchestrator main turn's session work was orchestration mechanics rather than product-code learning, so the "what would have helped" surface is thin.

## Signal-vs-Noise Pass (P105)

Deferred to next interactive retro. Rationale: orchestrator main turn read briefing files almost exclusively to ROTATE them (Tier 3 MUST_SPLIT remediation in Step 3 Branch A), not as informational input. Two entries were observably cited during operational work:

- `hooks-and-gates.md` (pre-rotation line 11 → now in archive) "`get_current_session_id` helper can pick a stale UUID" — Signal +2. Cited live when P188 capture hit the create-gate marker mismatch; manual touch across 3 candidate session UUIDs was the documented workaround. Entry rotated to archive during this same session — already at archive-tier where signal-promotion is moot.
- `governance-workflow.md` line 10 archive marker — Signal +1. Cited when rotating during this session's Step 3 Branch A. Mechanical structural reference.

Full per-entry decay-only application deferred — overhead-vs-signal ratio is poor for orchestrator-main-turn retros (most briefing entries weren't loaded at all; per-entry HTML-comment updates for ~80 entries across 14 files would burn substantial context with low signal yield).

## Problems Created/Updated

- **P188** (commit `4739f90`) — captured class-of-behaviour: AFK orchestrator Step 2.5b AskUserQuestion option-sets assume AFK-only paths even when the user's answering proves interactivity. Surfaced via user correction signal during Q4 framing.
- **P163** (commit `6a07d92`) — Investigation Tasks updated: user direction selected fix shape (a) grant external-comms agent narrow Bash for sha256; Fix Strategy section populated; bundled with TMPDIR-variance fix per Q3.
- **P162** (commit `6a07d92`) — Change Log appended: user direction defers Phase 2b atomic-cohort work until an active atomic-cohort accumulates in `docs/changesets-holding/`.

## Tickets Deferred

(None — Stage 1 ticketing fired correctly for P188; the user-direction observations on P163 / P162 were write-backs to existing tickets, not new captures.)

## Verification Candidates

(None — P185 closed via fold-fix commit `29b2e4d` this same session; same-session verifications are excluded per Step 4a step 8. No other `.verifying.md` tickets had specific in-session evidence.)

## Pipeline Instability

| Signal | Category | Citations | Decision |
|--------|----------|-----------|----------|
| Iter 2 retro wrote `docs/retros/2026-05-13-{ask-hygiene,iter-2-p185-retro}.md` but did NOT commit them — caused Step 6.75 dirty-for-unknown-reason halt. Root cause likely the external-comms agent sha256 marker key friction the retro itself documented. | Skill-contract violations | Iter 2 subprocess `ITERATION_SUMMARY` reported `committed: true` for the P185 fold-fix at `29b2e4d`, but `git status --porcelain` after iter exit showed `?? docs/retros/2026-05-13-*.md`. Orchestrator halted at Step 6.75 per SKILL contract. User-direction "do it interactively now" resolved by committing retros at `d66ec33` post-Step-2.5b. | Appended to **P163** (commit `6a07d92`) — direction selected fix shape (a) grant agent Bash for sha256 + bundle with TMPDIR-variance per Q3. The iter-retro-not-committing is downstream symptom of the same root cause class. |
| `get_current_session_id` helper picked a session ID that didn't match the live PreToolUse hook's `session_id` — first P188 capture Write was denied by the create-gate hook. Workaround: manual `touch` of `/tmp/manage-problem-grep-<SID>` for 3 candidate session UUIDs. | Hook-protocol friction | Bash subshell returned `sid=5c0ba9f1-...` from `get_current_session_id`; the actual runtime-SID marker chain held `307ee9b3-...`; the live announce-marker for THIS orchestrator session was elsewhere. Three candidate UUIDs (from runtime-SID + most-recent announce + helper return) all marker-touched before the Write succeeded. | Recorded in retro only — covered by existing **hooks-and-gates-archive.md** entry on `get_current_session_id` stale-UUID workaround (rotated this session at commit `80d4197`). The fix path lives in P124-class candidate amendments (helper prefers runtime-SID by mtime closest to current process start). Re-observation strengthens the case but no new ticket needed. |
| AFK orchestrator's Step 2.5b option-shape framing was AFK-biased even though AskUserQuestion firing proves interactivity — user correction "you're not being very smart" on Q4 briefing-rotation framing. | Skill-contract violations | Step 2.5b AskUserQuestion call presented 4 options for Q4 (Defer to interactive retro / Dedicated AFK rotation iter now / Capture as P-ticket + defer / Skip rotation for this loop) — none included "do it interactively now (you're here)". User correction surfaced the framing defect; "do it interactively now" was the right answer. | Captured as **P188** (commit `4739f90`) per P078 OFFER pattern (capture-on-correction). Sibling to P132 / P175 / P185 / P186 / P187 (same fixed-mode-assumption anti-pattern across SKILL / render / control-flow surfaces). |

**JTBD currency advisory**: not run this retro (orchestrator main turn; deferred-with-cause per scope-narrow precedent — the README-JTBD-currency surface was already validated by `8df1692` and ran clean on iter retros earlier today).

## Topic File Rotation Candidates

| Topic file | Bytes | Threshold | Proposed rotation | Decision |
|------------|-------|-----------|-------------------|----------|
| `docs/briefing/hooks-and-gates-archive.md` | 12795 | 5120 | split-by-date or split-by-subtopic (MUST_SPLIT, 2.50× ceiling) | flagged — archive-of-archive routinely grows past 2× ceiling per rotation; surfacing as observation, no rotation applied this retro (archive-sibling-rotation is a meta-pattern requiring its own design decision; capture-as-ticket if recurs) |
| `docs/briefing/governance-workflow-archive.md` | 10154 | 5120 | n/a (1.98× ceiling, OVER but NOT MUST_SPLIT — under 2× threshold) | leave-as-is (within Branch B trim/defer envelope) |
| `docs/briefing/releases-and-ci-archive.md` | 9941 | 5120 | n/a (1.94× ceiling, OVER but NOT MUST_SPLIT) | leave-as-is (Branch B envelope) |
| `docs/briefing/hooks-and-gates.md` | 9683 | 5120 | n/a (1.89× ceiling, OVER but NOT MUST_SPLIT — just rotated) | leave-as-is — main file dropped from 3.81× to 1.89× this session; further rotation premature. |
| Other OVER files (afk-subprocess-mechanics.md, afk-subprocess-recovery.md, agent-hook-gate-quirks.md, governance-workflow.md, governance-workflow-surprises.md, plugin-distribution.md, releases-and-ci.md, agent-interaction-patterns.md) | 6684–9434 | 5120 | n/a (all 1.31–1.84× — within Branch B envelope) | leave-as-is (no signal-scoring drove trim-noise threshold this retro) |

**Observation worth surfacing**: archive siblings created during a MUST_SPLIT rotation routinely land just over the 2× ceiling themselves (12795 hooks-and-gates-archive.md at 2.50×). This is a meta-pattern — the rotation pattern relocates content into a sibling that itself can MUST_SPLIT. Two paths forward (NOT acted on this retro):

1. Accept archive-tier as a separate budget envelope (e.g. 4× ceiling) where MUST_SPLIT doesn't fire on `-archive.md`-suffixed files.
2. Cascading rotation: when an archive sibling itself MUST_SPLITs, rotate again into `-archive-archive.md` or split-by-date sub-archives.

Worth a P-ticket capture next retro if the pattern recurs.

## Ask Hygiene (P135 Phase 5 / ADR-044)

Trail emitted to `docs/retros/2026-05-13-orchestrator-main-ask-hygiene.md` (sibling file). Summary:

- **Lazy count: 0**
- **Direction count: 4** (Step 2.5b 4-question batched call — all direction-class per ADR-044 categories 1-2)
- Other categories: 0

Q4 had a **framing defect** (AFK-biased option-set when user was interactive) — captured as P188. The question itself was correctly classified as direction; the framing defect is an option-shape pattern at the question-author surface, not a misclassification.

Cumulative across today's 3 retros (iter 1 + iter 2 + orchestrator main): **0 lazy across 3 retros**. R6 gate remains far from threshold (≥2 across 3 consecutive retros).

## Codification Candidates

No new candidates this retro. The session-observed friction maps to:

- **P188** (captured this session) — option-shape framing defect class
- **P163** (updated this session) — external-comms agent sha256 + TMPDIR bundle direction
- **P162** (updated this session) — Phase 2b defer direction
- **P145** (existing) — Tier 3 rotation pattern, already addressed by this session's rotation

The "archive-sibling-can-MUST_SPLIT" observation surfaced under Topic File Rotation is a candidate for the next retro if it recurs — not ticketing this retro per P145's "wait for recurrence" envelope.

## No Action Needed

- ADR-013 Rule 1 / Rule 5 / Rule 6 — operating correctly
- ADR-014 commit grain — preserved across all 5 unpushed commits this session
- ADR-032 subprocess-boundary dispatch — both iters cleanly returned `ITERATION_SUMMARY`; the dirty-retro-state class is a known iter-vs-orchestrator contract-tension, not a dispatch defect
- ADR-044 framework-resolution boundary — all 4 Step 2.5b questions correctly classified as direction; lazy count 0

## Session Cost (cheap-layer measurement deferred — orchestrator-main-turn scope)

Full cheap-layer context-usage measurement (Step 2c) deferred — orchestrator main turn context-bytes are dominated by the iter dispatch JSON responses (cumulatively ~31 MB of cache-read across 2 iter subprocesses), 4 risk-scorer pipeline subagent invocations (~1.5K tokens each), and the briefing-rotation EDIT flow. Per-bucket attribution requires either runtime instrumentation (out of scope) or a deep-layer pass (`/wr-retrospective:analyze-context`); cheap layer's per-source-bucket script is best-fit for repo-resident artefacts, not for in-session tool-use envelopes.

Per-iter (measured-actual per ADR-026):

| Iter | Ticket | Outcome | Cost | Duration | Cache-read |
|------|--------|---------|------|----------|------------|
| 1 | P162 | Phase 2a → partial-progress | $11.61 | 21m | 13.0M tokens |
| 2 | P185 | fold-fix Open → Verifying | $14.06 | 23m | 17.8M tokens |
| Total | | | **$25.67** | 44m iter wall-clock | 30.8M cache-read |

Orchestrator main turn cost not directly measured in this session shape — would require a separate context-analysis pass via the deep layer.
