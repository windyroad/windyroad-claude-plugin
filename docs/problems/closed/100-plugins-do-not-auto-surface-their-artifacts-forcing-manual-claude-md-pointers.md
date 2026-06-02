# Problem 100: `wr-retrospective` does not auto-surface `docs/BRIEFING.md` to the agent at session start — cross-session learnings go unread in adopter projects

**Status**: Closed
**Reported**: 2026-04-22
**Priority**: 20 (High) — Impact: Major (4) x Likelihood: Almost certain (5)
**Effort**: L
**WSJF**: (20 × 1.0) / 4 = **5.0**

> Identified 2026-04-22 by the user during P098 verification. My P098 project-level `CLAUDE.md` added pointers to `docs/problems/README.md` and `docs/BRIEFING.md`; the user correctly observed: *"we shouldn't have to add these things to CLAUDE.md. It should be automatic."* Follow-up clarification: *"I'm not sure if docs/problems/README.md needs to be surfaced unless we are explicitly doing stuff with problems."* — scoping the ticket narrowly to `docs/BRIEFING.md` (cross-cutting session learnings that benefit any task) while leaving `wr-itil`'s backlog on its current on-demand model (skill-invocation only) as the intended behaviour, not a gap.

## Description

Some windyroad plugins already advertise their generated / curated artifacts to the agent on every user prompt via UserPromptSubmit hooks — the agent learns the artifact exists, who owns it, and when the gate applies. Examples:

| Plugin | Hook | Artifact advertised | Status |
|---|---|---|---|
| `wr-architect` | `architect-detect.sh` | `docs/decisions/` | Automatic ✓ |
| `wr-jtbd` | `jtbd-eval.sh` | `docs/jtbd/` | Automatic ✓ |
| `wr-risk-scorer` | commit-gate chain | `RISK-POLICY.md` | Automatic ✓ |
| `wr-style-guide` | `style-guide-eval.sh` | `docs/STYLE-GUIDE.md` | Automatic ✓ |
| `wr-voice-tone` | `voice-tone-eval.sh` | `docs/VOICE-AND-TONE.md` | Automatic ✓ |
| `wr-tdd` | `tdd-inject.sh` | test script + current state | Automatic ✓ |

**`wr-retrospective` fails this pattern for cross-session learnings:**

| Plugin | Artifact | Current discovery path | Problem |
|---|---|---|---|
| `wr-retrospective` | `docs/BRIEFING.md` | Only read when run-retro's Step 1 fires (i.e. only when the user invokes the retrospective). `retrospective-reminder.sh` is a Stop hook — write-path nudge at session *end*, not a read affordance at session *start*. | Accumulated learnings are write-only; future sessions never load them. BRIEFING.md holds cross-cutting learnings (hook behaviour, release cadence, session-wide traps) that benefit ANY task, not just retrospective work — the file's value depends on unconditional session-start discovery. |

Consequence: in every project that uses `@windyroad/retrospective` but does NOT manually hand-author a project-level `CLAUDE.md` pointer (i.e. every adopter project except this one after P098), `docs/BRIEFING.md` is effectively a dead letter. The retrospective plugin's entire value proposition — "capture learnings so future sessions benefit" — relies on discovery, and the discovery is missing.

The user's framing (2026-04-22): *"I'm more worried that in other projects, the agent isn't reading the briefing that run-retro creates. The retro need to do more here to put it in front of the agent."*

**Out of scope — `wr-itil`'s `docs/problems/README.md`** (user direction 2026-04-22): *"I'm not sure if docs/problems/README.md needs to be surfaced unless we are explicitly doing stuff with problems."* The problem backlog is contextual — relevant only when the user is doing problem-management work. The current on-demand model (skill-invocation surfaces the backlog via `/wr-itil:list-problems`, `/wr-itil:work-problem`, etc.) matches the "discover when relevant" principle. Unconditional session-start surfacing would be noise for the majority of sessions that aren't touching the backlog. This ticket therefore scopes to `docs/BRIEFING.md` only. If a future design finds a meaningful context trigger for surfacing the backlog (e.g. "problem ticket file open in IDE"), a sibling ticket can capture that — but the default-silent-until-invoked behaviour for `wr-itil` is intentional.

**Principle**: **a plugin that produces a cross-session artifact with cross-cutting applicability should advertise it via its own UserPromptSubmit hook**, following the ADR-038 progressive-disclosure + once-per-session budget pattern. Contextual artifacts (relevant only during specific work) stay on on-demand discovery.

## Symptoms

- Adopter projects that use `@windyroad/retrospective` have BRIEFING.md files accumulating retros-worth of learnings that no session at start reads.
- This repo's project-level `CLAUDE.md` (created in P098) hand-authors a `docs/BRIEFING.md` pointer that the retrospective plugin should have emitted itself.
- The asymmetry with already-automatic plugins (architect, jtbd, risk-scorer, style-guide, voice-tone, tdd) makes the gap stand out: six plugins emit their cross-cutting artifact pointers automatically; `wr-retrospective` doesn't.

## Workaround

The P098 project-level `CLAUDE.md` pointer pattern. **This is a workaround, not a fix.** It only solves the gap for the one project that adds the pointers; every other adopter still pays the cost. Also bloats every session that *does* use the workaround, since the pointer itself triggers eager read of a potentially-bloated file (composes with P099).

## Impact Assessment

- **Who is affected**: Every adopter of `@windyroad/retrospective`. Secondary: this repo's continued use of project-level `CLAUDE.md` pointers as a workaround (introduced in P098).
- **Frequency**: Every session across every adopter project. BRIEFING.md is effectively never read at session start without the workaround.
- **Severity**: Major. Defeats the purpose of cross-session knowledge capture. Every retrospective's learnings go unread unless the user manually invokes the retro or manually adds a pointer.
- **Analytics**: Measurement harness from P091. Consumer-side: count sessions that read BRIEFING.md in adopter projects (expected: near-zero). Producer-side: count BRIEFING.md appends over the same period (expected: one per retro session). Ratio indicates dead-letter rate.

## Root Cause Analysis

### Confirmed (2026-04-22 audit)

- `~/CLAUDE.md` has no reference to `docs/BRIEFING.md` or `docs/problems/README.md` (grepped).
- `packages/retrospective/hooks/` has one hook (`retrospective-reminder.sh`) and it is a **Stop** hook, not UserPromptSubmit. Its prose is a write-path reminder ("run /retrospective ... update docs/BRIEFING.md") fired when Claude Code stops — not a read affordance fired at prompt submit.
- Six other windyroad plugins already emit UserPromptSubmit artifact-advertisement prose (per the table above). The architectural pattern is proven and ADR-038-governed; `wr-retrospective` hasn't adopted it. `wr-itil` is intentionally on-demand (user confirmed out-of-scope for this ticket).

### Design flaw (same P091 meta pattern, inverted)

Six plugins got the ADR-038 pattern right: advertise, once per session, with a terse reminder. `wr-retrospective` got an inverted failure for its cross-cutting artifact: the file exists, but no announcement channel exists at session start. The producer (run-retro) writes to disk; the consumer (next session's assistant) has no passive awareness the file has content to offer.

### Investigation tasks

- [x] Grep the plugin hook layer for UserPromptSubmit artifact announcements (confirmed 2026-04-22: 6 of 8 plugins advertise cross-cutting artifacts; retrospective does not).
- [x] Confirm `retrospective-reminder.sh` is a Stop hook, not UserPromptSubmit (confirmed — its settings event is `Stop`).
- [x] Scope check: should `wr-itil`'s `docs/problems/README.md` be in this ticket's scope? (No — user direction 2026-04-22: "I'm not sure if docs/problems/README.md needs to be surfaced unless we are explicitly doing stuff with problems." Contextual artifacts stay on on-demand discovery.)
- [ ] Design the UserPromptSubmit announcement shape for `wr-retrospective`. Candidates: (a) once-per-session full file load, (b) once-per-session terse pointer + topic index ("Session learnings: 34 entries across 5 topics — see `docs/BRIEFING.md`"), (c) once-per-session top-N-most-recent entries, (d) lazy affordance ("BRIEFING.md has been updated N times this month — consider loading on demand"). Progressive disclosure favours (b) or (d). Interacts with P099's lean-BRIEFING shape — if P099 ships topical archives, the announcement points to the archive index not the full file.
- [ ] Decide whether the hook shares the canonical `session-marker.sh` (per ADR-038 distribution pattern) with once-per-session gating, or emits every prompt with a dynamic-state carve-out (per `tdd-inject.sh` precedent — BRIEFING.md append count IS dynamic session state, so the carve-out applies for delta-announcements). Expected shape: once-per-session for the index pointer; per-prompt terse state line for the append-count delta.
- [ ] Audit `docs/PRODUCT_DISCOVERY.md`: which plugin (if any) owns it? If none, this ticket doesn't cover it; flag as out-of-scope.
- [ ] Author or amend the ADR: extend ADR-038's Scope from "UserPromptSubmit governance prose" to include cross-cutting artifact announcement, or author a thin sibling ADR. Architect decides at implementation time.

## Fix Strategy

**Progressive-disclosure artifact announcement via UserPromptSubmit** — extend the ADR-038 pattern from "gate-active reminders" to "cross-cutting artifact reminders".

1. **`wr-retrospective` UserPromptSubmit hook** (new). On every prompt, emit a ≤ 150-byte terse announcement when `docs/BRIEFING.md` exists:
   - First prompt of session: terse pointer + recent-append count + topic index path (e.g. "BRIEFING.md has N learnings across M topics — load on demand, per-topic archives in `docs/briefing/`").
   - Subsequent prompts: silent, or a shorter "N new learnings since last session" line if new content has appeared since the session-marker was written.
   - Implementation ≈ mirror of `style-guide-eval.sh` / `voice-tone-eval.sh` shape with once-per-session marker per ADR-038. Dynamic-state carve-out (the append count) allowed per the `tdd-inject.sh` precedent.

2. **ADR amendment or sibling**: ADR-038's Scope currently names the UserPromptSubmit *governance gate* cluster (architect/jtbd/tdd/style-guide/voice-tone). Adding BRIEFING.md expands to *cross-cutting artifact announcement* — a related but distinct category. Architect review at implementation time decides amendment vs sibling.

3. **Retire the project-level CLAUDE.md BRIEFING pointer**: once the hook ships, the BRIEFING.md pointer this repo added in P098 becomes redundant. Revert it (keeping the project CLAUDE.md lean with only genuinely-project-specific content — e.g. the plugin-dev-not-web-UI framing and the Windy Road positioning statement migrated from the pruned `project_state.md` memory). Separately: the project CLAUDE.md pointers for `docs/decisions/`, `docs/jtbd/`, `RISK-POLICY.md`, `docs/STYLE-GUIDE.md`, `docs/VOICE-AND-TONE.md` are redundant with existing plugin hooks *today* — this revert should happen as part of P098's verification, not pending P100.

4. **Out of scope**:
   - **`docs/problems/README.md` / `wr-itil`** — contextual artifact. User direction: "only surface when explicitly doing problem work." The current on-demand model (skill-invocation) is correct.
   - **`docs/PRODUCT_DISCOVERY.md`** — no plugin currently owns this file, so there's no announcement hook to add. If/when a plugin adopts product discovery, the same progressive-disclosure announcement pattern applies.

## Dependencies

- **Blocks**: (none directly; shipping P100's fix retires P098's project-CLAUDE.md BRIEFING pointer as a workaround, and the fix pattern lets P099's BRIEFING.md trim be truly progressive — see Related)
- **Blocked by**: (none)
- **Composes with**: P091, P098, P099

## Related

- **P091 (Session-wide context budget — meta)** — parent meta ticket. This is the fourth child audited (after P095/P096/P097/P098/P099). P100 flips the P098 audit's direction: rather than the user shrinking context consumption, this ticket has plugins carrying the disclosure themselves so users don't have to.
- **P098 (Project and user-owned context contributors)** — sibling. Verifying. The project-level `CLAUDE.md` pointer mechanism I introduced in P098 is the workaround this ticket supersedes. When P100 ships, P098's pointer list becomes obsolete; the project CLAUDE.md should retain only genuinely-project-specific content (plugin-dev framing, Windy Road positioning). Note on P098's verification: the CLAUDE.md pointers should be trimmed or removed pending P100's fix — leaving them causes an unnecessary eager-read of a bloated file (composes with P099).
- **P099 (BRIEFING.md grows unbounded via run-retro appends)** — sibling. Composes with this ticket: P099's fix (lean BRIEFING + topical archives + rotation) makes the P100 hook's "load on demand" affordance honest. Without P099, the hook advertises a 5000-token file. Without P100, P099's lean BRIEFING is still never read at session start. Together: the file is lean AND discoverable AND progressively loaded.
- **P094 (manage-problem does not refresh README.md on ticket creation)** — adjacent. P094 is about keeping the `docs/problems/README.md` cache fresh on ticket creation; P100 is about making the file discoverable at session start. P094's fix makes P100's announcement honest.
- **P044, P050, P088 (run-retro quality)** — adjacent run-retro quality tickets. Different surfaces; composes with this one on the same SKILL.md only incidentally.
- **ADR-038** — progressive disclosure + once-per-session budget for UserPromptSubmit governance prose. This ticket extends the pattern to artifact-announcement UserPromptSubmit hooks. Amendment vs sibling decided at implementation time.
- **ADR-017 / ADR-028** — canonical+sync distribution pattern. The new hooks in `wr-retrospective` and `wr-itil` likely reuse `session-marker.sh` from ADR-038's distribution, so the canonical+sync scaffold applies.

## Design Update (2026-04-22)

User-directed design shape captured via `AskUserQuestion` pre-work prior to kicking off `/wr-itil:work-problems`. Supersedes the Fix Strategy above where they conflict.

**Mechanism** — SessionStart hook if Claude Code supports one; UserPromptSubmit once-per-session (ADR-038) as fallback. Implementation starts by confirming SessionStart hook existence.

**Output shape — user correction to the prior "pointer-only" framing** — *"a short header + pointer to docs/BRIEFING.md is NOT progressive disclosure as that would be all or nothing."* True progressive disclosure for BRIEFING is tiered:

1. **Split `docs/BRIEFING.md` → `docs/briefing/<topic>.md` directory** — per-topic files, each naturally bounded in length.
2. **Maintain `docs/briefing/README.md`** — index + per-file summaries.
3. **Session-start injection** — summary-of-the-summary (the critical points only) + pointer to the README. The README then points down into individual files on demand. Tiered, not all-or-nothing.

**run-retro workflow addition** — user proposed: *"Maybe the retro should also ask how helpful each point was."* Helpfulness rating during retrospective drives curation — promote critical points into the roll-up, demote or archive stale ones. Scope decision (keep in P100 vs split) deferred to implementation.

**Sequencing with P099** — ship P100's tiered structure first. P099 (BRIEFING unbounded growth) becomes lower priority or is effectively subsumed, since per-topic files are naturally bounded and the README roll-up stays curated via the helpfulness loop.

**Scope unchanged** — BRIEFING surface only. `docs/problems/README.md` / `wr-itil` remains on-demand.

### Revised investigation tasks (supersede the prior list where they overlap)

- [ ] Confirm whether Claude Code supports a SessionStart hook. If yes, that is the injection surface; if no, fall back to UserPromptSubmit once-per-session.
- [ ] Design the BRIEFING dir partitioning scheme (topic boundaries, per-file shape, README roll-up format, critical-points extraction rule).
- [ ] Design the run-retro helpfulness-rating mechanism (in-retro prompt shape; storage; effect on README roll-up). Decide whether to keep in P100 or split into a sibling ticket.
- [ ] Migration plan for existing `docs/BRIEFING.md` content in adopter projects (one-time split; run-retro gains a "first-time migration" branch).
- [ ] Architect review at implementation time — likely ADR sibling to ADR-038 (directory migration + helpfulness feedback loop + SessionStart-or-UserPromptSubmit hook is structural, not an amendment).
- [ ] Effort re-rating candidate: M → L given the directory migration + README maintenance + hook + SKILL changes. Let `/wr-itil:review-problems` handle the recalculation rather than stamping it here.

## Slice 1 partial progress (2026-04-22 AFK iter 4)

Landed in commit: **refactor(briefing): migrate docs/BRIEFING.md to docs/briefing/ tree (P100 slice 1)** (see commit sha in the closing commit message). This slice is structural migration + writer-side alignment only. The session-start discovery surface (SessionStart hook + ADR) remains in slice 2.

**Slice 1 scope (shipped)**
- `docs/briefing/` directory created with six per-topic files: `hooks-and-gates.md`, `releases-and-ci.md`, `governance-workflow.md`, `afk-subprocess.md`, `plugin-distribution.md`, `agent-interaction-patterns.md`.
- `docs/briefing/README.md` index with per-file summaries + Critical Points section (the future SessionStart-hook surface).
- `docs/BRIEFING.md` rewritten as a transitional stub pointing to `docs/briefing/README.md`.
- `packages/retrospective/skills/run-retro/SKILL.md` Steps 1, 3, and 5 updated to target the new layout (JTBD review finding #1 — without this, a retro between slices would either corrupt the stub or drop learnings).
- `packages/architect/hooks/architect-enforce-edit.sh` + `architect-detect.sh` + `architect-detect-scope.bats` extended with the `docs/briefing/` exemption (architect review finding #1 — without this, the whole new tree is gated).
- `packages/jtbd/hooks/jtbd-enforce-edit.sh` + `jtbd-eval.sh` + `jtbd-eval-scope.bats` extended with the same exemption.
- Three changesets: `@windyroad/architect` patch, `@windyroad/jtbd` patch, `@windyroad/retrospective` minor (writer-side layout change).
- Effort re-rated M -> L (WSJF 10.0 -> 5.0) to reflect the remaining slice 2 scope.

**Slice 2 scope (pending)**
- SessionStart hook in `packages/retrospective/hooks/` (or UserPromptSubmit fallback) that emits the Critical Points summary + README pointer at session start.
- Sibling ADR to ADR-038 covering the directory migration + helpfulness-rating loop + SessionStart injection.
- run-retro helpfulness-rating loop during retros (drives curation of which entries reach Critical Points).
- Retire `docs/BRIEFING.md` transitional stub.
- (If the retrospective-reminder.sh Stop hook prose needs re-pointing to `docs/briefing/`, bundle with slice 2.)

**Writer-side transition policy (JTBD finding #1 resolution)**
Chose option (a): include the run-retro SKILL.md update in slice 1. A retro run between slice 1 and slice 2 will now write to the new per-topic files via the updated Step 3 and will not touch the transitional stub.

**ADR timing (architect finding #2 resolution)**
Chose the acceptable path: slice 1 lands without a governing ADR; slice 2 authors the sibling ADR alongside the hook + helpfulness loop. The Design Update section of this ticket holds the nascent decision drivers until slice 2's ADR draft quotes them.

**Investigation tasks status after slice 1**
- [x] Confirm SessionStart hook support — confirmed (`packages/retrospective/hooks/hooks.json` already uses one).
- [x] Design the BRIEFING dir partitioning scheme — implemented with 6 topic files + README index + Critical Points surface.
- [ ] Design the run-retro helpfulness-rating mechanism — deferred to slice 2.
- [x] Migration plan for existing `docs/BRIEFING.md` — executed (transitional stub + writer-side SKILL.md update).
- [ ] Architect review at implementation time — slice 1 reviewed (ISSUES FOUND resolved via bundling); slice 2 ADR review pending.
- [x] Effort re-rating — M -> L applied.


## Fix Released

Implemented 2026-04-22 in interactive slice 2 (commit pending as `fix(retrospective): ...`). Released as `@windyroad/retrospective@0.7.0`.

**Slice 1 (prior — commit 5d367e9):** `docs/BRIEFING.md` → `docs/briefing/<topic>.md` tree with `docs/briefing/README.md` index (per-topic files: afk-subprocess, agent-interaction-patterns, governance-workflow, hooks-and-gates, plugin-distribution, releases-and-ci). `run-retro` SKILL.md rewritten writer-side (Steps 1, 3, 5). Architect + JTBD hooks added `docs/briefing/*` exemptions.

**Slice 2 (this release):**

- New hook script `packages/retrospective/hooks/session-start-briefing.sh` — reads `docs/briefing/README.md`, extracts the `## Critical Points (Session-Start Surface)` section via awk, emits as prose. Silent exit if the briefing tree is absent (no-op for adopters without a retro yet).
- `packages/retrospective/hooks/hooks.json` gains a second `SessionStart` entry with `"matcher": "startup"` targeting the new script. The existing `check-deps.sh` entry remains matcher-less.
- `docs/BRIEFING.md` (slice-1 migration stub) deleted per user direction ("delete it entirely").
- `@windyroad/retrospective` bumps 0.6.0 → 0.7.0 (minor).
- Held retrospective-minor changeset reinstated from `docs/changesets-holding/` to `.changeset/` with scope body expanded to cover slice 1 + slice 2 combined.
- **ADR-040 (proposed)** "Session-start briefing surface — SessionStart hook over tiered directory + indexed README" authored; sibling to ADR-038; caps Tier 1 boot injection at ≤ 2 KB / ≤ 500 tokens; documents reuse vs net-new.
- Smoke-test: running the hook script against this repo emits the full 8-bullet Critical Points roll-up as expected (~1.5 KB output — within Tier 1 budget).

**Outstanding follow-ups (non-blocking for P100 closure):**

- **P105 (opened 2026-04-22)** — signal-vs-noise pass in run-retro; curates Critical Points roll-up over time so it does not drift stale. Referenced in ADR-040's "Bad consequences" section as the closure path for that drift.
- **P102 (opened 2026-04-22)** — same pattern (no invocation surface populates an expected artefact) applied to `docs/risks/`.

Awaiting user verification that the SessionStart hook actually fires and injects the Critical Points prose in a fresh Claude Code session after `@windyroad/retrospective@0.7.0` is installed.
