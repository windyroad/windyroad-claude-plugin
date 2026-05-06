# Problem 014: No lightweight aside invocation for governance skills (problems, retros, ADRs)

**Status**: Open
**Reported**: 2026-04-16
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: XL — re-sized up from L 2026-04-20 (AFK iter 2 architect review): ADR-027 conflict requires a new/amended/superseding ADR plus 4 SKILL.md edits, regardless of which reconciliation option the user picks. See "Architect-detected conflict" section below. (Earlier L sizing assumed no ADR-level conflict; re-sized down from original XL when the new-pattern + new-ADR scope was dropped via user direction; now re-sized back up by the architect-flagged ADR-027 collision.)
**WSJF**: 1.5 — (12 × 1.0) / 8
**Type**: technical

## Iter 12 progress (2026-05-03)

**Slice landed this iter**: stale ADR-027 compatibility notes in `packages/retrospective/skills/run-retro/SKILL.md` (Step 2b, Step 2c, Step 4a) rewritten as ADR-032 supersession notes; matching bats greps in `test/run-retro-pipeline-instability-scan.bats` and `test/run-retro-verification-close-housekeeping.bats` re-pointed at the new strings; patch changeset for `@windyroad/retrospective` queued. Commit: `1804168 docs(retrospective): rewrite stale ADR-027 compat notes in run-retro/SKILL.md (P014)`.

**Architect closure-condition delta** (vs. ADR-032 lines 13-19):

- ADR-027 renamed to `.superseded.md` — done (pre-iter)
- Step-0 subagent-delegation language removed from `manage-problem` / `create-adr` / `manage-incident` SKILL.md files — already absent in those files (ADR-027's mandate was never operationally implemented). For `run-retro`, the trailing stale-compat-note debt landed this iter.
- Three new `capture-*` SKILL.md files — **NOT YET**. `capture-retro` deferred per P088. `capture-problem` and `capture-adr` are the live deliverables.
- `packages/itil/hooks/pending-questions-surface.sh` — **NOT YET**.
- Bats coverage per ADR-032 Confirmation — partially landed (run-retro structural greps re-pointed); the three new-skill contract tests + the hook test are not yet authored.
- `.claude-plugin/plugin.json` entries — **NOT YET**.

**Planned split deferred to a future iter**: architect (this iter) approved decomposing the remaining work into three subordinate child tickets (ship-capture-problem, ship-capture-adr, ship-pending-questions-surface-hook) using P135's master + child convention. The split was not executed this iter because each new ticket creation goes through `manage-problem-enforce-create.sh` (P119), which mandates a serial `/wr-itil:manage-problem` Step 2 duplicate-check per ticket — three serial skill invocations exceeds the iter-scope budget AND each Step 2 has an AskUserQuestion-on-duplicate-detection branch that violates the `NEVER call AskUserQuestion mid-loop` AFK constraint. A future iter that opens these three child tickets in foreground (interactive) is the right surface.

## Decision record

## Decision record

**ADR-032** (Governance skill invocation patterns — foreground + background with deferred-question resumption) — drafted 2026-04-21 post-user-direction. Supersedes ADR-027. Pattern taxonomy: **foreground synchronous** (existing skills, no Step 0), **background capture** (NEW `capture-*` siblings), **foreground edit-gate** (unchanged), **foreground commit-gate** (unchanged). The "log Y, keep working on X" promise delivered via three new skills: `/wr-itil:capture-problem`, `/wr-retrospective:capture-retro`, `/wr-architect:capture-adr`. AskUserQuestion branches in background skills defer via a persistent pending-questions artefact in `docs/problems/open/`; a new UserPromptSubmit hook (`packages/itil/hooks/pending-questions-surface.sh`) surfaces them to the main agent on next pause. AFK orchestrator iterations stay synchronous per ADR-018 / ADR-019 carve-out.

This ticket (P014) remains Open as the **execution tracker** for ADR-032's implementation. Closes when:
- ADR-027 has been renamed to `.superseded.md` (done in the ADR-032 landing commit).
- Three new SKILL.md files exist at `packages/itil/skills/capture-problem/SKILL.md`, `packages/retrospective/skills/capture-retro/SKILL.md`, `packages/architect/skills/capture-adr/SKILL.md`.
- Existing `manage-problem` / `create-adr` / `run-retro` / `manage-incident` SKILL.md files have their Step-0 subagent-delegation language removed.
- `packages/itil/hooks/pending-questions-surface.sh` ships.
- Bats coverage per ADR-032's Confirmation section lands.
- Plugin manifests (`.claude-plugin/plugin.json` for itil, retrospective, architect) list the new skills.

The three reconciliation options below (supersede / coexist / reject) are resolved: **Option 1 chosen** — supersede ADR-027. The new ADR (ADR-032) takes user's 2026-04-21 direction further than Option 1 originally contemplated — it's not just "background-subagent model" but a pattern taxonomy that keeps foreground synchronous skills intact for full-intake flows AND adds background `capture-*` siblings for aside captures.

## Architect-detected conflict (2026-04-20 AFK iter 2 — resolved 2026-04-21 per ADR-032)

**Status: BLOCKED on user decision.** During AFK iter 2, the architect review for the proposed P014 edits flagged a direct conflict with **ADR-027 (Governance skill auto-delegation, 2026-04-20)** — accepted the same day as the direction decision below, addressing the same SKILL.md files (manage-problem, create-adr, run-retro, work-problems' per-iteration call) but with a fundamentally different execution model.

| Aspect | ADR-027 (existing) | P014 direction (proposed) |
|---|---|---|
| Invocation entry path | Main agent → skill's own Step 0 spawns subagent | External orchestrator/in-flight task → background subagent → skill |
| Execution model | **Synchronous** — main agent waits for subagent's final report, returns it verbatim | **Asynchronous** — `run_in_background: true`, notification on completion |
| Mandatory? | Yes — "Do NOT execute steps 1-N of this SKILL.md in main-agent context under any circumstance" | Optional convention for orchestrator-side aside captures |
| ADR | ADR-027 (proposed, 2026-04-20) | None — direction said "no new ADR needed" |
| Source files affected | All in-scope SKILL.md (Step 0 mandatory) | Same SKILL.md (additive section near top) + orchestrator pointers |

The 2026-04-20 P014 direction (below) appears to have been written **without cross-referencing ADR-027 of the same date**. Three reconciliation options the user must pick from:

1. **Supersede ADR-027** with a new ADR adopting the background-subagent model. Rename ADR-027 to `.superseded.md`. Re-author P014's three governance-skill SKILL.md sections under the new model. Removes synchronous Step-0 across the suite.
2. **Coexist additively** — write P014's new sections so they explicitly reference ADR-027 and clarify disjoint paths ("ADR-027: main-agent → skill internal Step-0 subagent, synchronous; P014: external orchestrator → background subagent invocation, asynchronous"). Ordering: ADR-027's Step 0 stays first; the new "Background-subagent invocation" section follows. File a new ADR documenting the cross-skill convention so the SKILL.md text can cite an ADR ID rather than "the P014 direction".
3. **Reject P014 as subsumed by ADR-027** — close P014 as resolved. ADR-027's synchronous delegation already removes the "main-turn-consumed" pain (the subagent does the heavy intake; the main agent only sees the final report). The aside-vs-blocking distinction may not matter in practice if the subagent's intake is fast enough.

Additional architect concerns (apply to options 1 and 2 — reject option resolves them by elision):

- **Rule 6 mis-citation**: the proposed convention text says ADR-013 Rule 6 "covers any AskUserQuestion gaps so the subagent does not block". Rule 6 actually says fail-safe = block/defer, not silently proceed. Each governance skill's actual Rule-6 coverage at each `AskUserQuestion` branch must be audited before the convention can claim "won't block".
- **Nesting depth**: an orchestrator → background-subagent → skill-Step-0-subagent chain is 3 levels (the max ADR-027 calls "routinely expected"). Adding a 4th level of nesting is a reassessment trigger for ADR-027.
- **Audit-trail gap**: a background subagent's filed artefact is not surfaced in the orchestrator's iteration summary. JTBD-201 audit-trail promise weakens unless the orchestrator-pointer text mandates that each background-spawn is logged in the iteration summary.

**Effort re-rate**: L → XL — three reconciliation options, each requiring a new or amended ADR plus the 4 SKILL.md edits. Even option 3 (reject) requires a P014 closure note, ADR-027's cross-reference, and an explicit decision audit trail. The original L estimate assumed no ADR-level conflict.

**WSJF re-rate**: was 3.0 (12 × 1.0 / 4); now **1.5** (12 × 1.0 / 8) given XL effort. Drops below P015 (2.25) and P055 (2.25) in the queue but remains higher than the 1.5-tier siblings due to severity.

**Next iteration**: skip P014 with skip-reason `architect-design`. The Outstanding Design Questions table at stop-time should surface: "P014 — which reconciliation option (supersede ADR-027, coexist additively, or reject as subsumed)?"

## Direction decision (2026-04-20, user — AFK loop stop-condition #2)

**Pattern shape**: **Governance skills should use background agents for aside-type work** (user quote). Instead of a new structured-prompt convention, a new "aside" subagent type, or a new wrapping skill, the existing subagent machinery is used with `run_in_background: true`. Each governance skill (manage-problem, run-retro, create-adr) invokes a background subagent to do the full intake against a compact aside payload — the main turn keeps working on its original task while the subagent files the stub.

Implication:
- No new ADR needed (existing Agent tool + subagent types suffice).
- Effort re-sized from XL (ADR + cross-package pattern) to L (per-skill convention + examples).
- Investigation Tasks simplify: no new pattern design, no new subagent-type definition, no new skill surface. Scope is a documented convention in each of manage-problem, run-retro, and create-adr SKILL.md that shows how to receive an aside as a background-subagent task with a compact prompt and return a structured "filed" confirmation.
- Next AFK iteration: add the convention to the three SKILL.md files + an example invocation, and update the orchestrator skills (work-problems, run-retro) that might notice aside-worthy material mid-loop.

This replaces the previous "new pattern + ADR" framing entirely.

## Description

There is no lightweight way to invoke a governance artefact skill (problem-capture, retrospective, ADR creation) while working on something else. Today, invoking `/wr-itil:manage-problem`, `/wr-retrospective:run-retro`, or `/wr-architect:create-adr` consumes the current turn: each pulls the full skill into context, walks a multi-step intake, and displaces whatever task was in flight. In practice this means real-time discoveries ("I notice Y while working on X", "we should retro this later", "that's a decision worth recording") either derail the main task, or go uncaptured and get forgotten.

The desired behaviour is `/btw`-style: **working on X, notice Y, log Y as a stub, keep working on X, don't forget Y**. The aside should add cognitive load proportional to the thought being captured (one line), not proportional to the full skill's workflow.

This problem covers three known instances of the same pattern — but the pattern itself is the target. Resolving it one skill at a time would repeat the multi-concern failure mode captured in P016/P017.

**In-scope skills:**
- `/wr-itil:manage-problem` — log a problem noticed mid-task
- `/wr-retrospective:run-retro` — queue a retro without running the full wizard now
- `/wr-architect:create-adr` — stub an ADR when a decision is made but not ready to author

## Symptoms

- Users silently skip logging problems, queuing retros, or capturing ADRs mid-flow because the full intake is too heavy for a drive-by observation.
- When users do invoke these skills mid-task, the main task context is buried under multi-turn intake prompts (duplicate search, AskUserQuestion, architect/JTBD delegation, file writes). Recovery to the prior task is manual.
- Artefacts created mid-flow are often under-specified because the author is distracted; the full intake doesn't actually buy higher quality when the trigger was an aside.
- No convention for "stub" artefacts (problem, retro entry, ADR) — intentionally thin and expected to be fleshed out later at end-of-session or by a subsequent review pass.
- The three skills are solving the same pattern independently; whichever lands first risks setting a narrow precedent the others then don't fit.

## Workaround

- Take a note in conversation and rely on end-of-session retro to capture it (fragile — retro may not run; session may end abruptly).
- Ask the user to do it (breaks the "don't interrupt them either" goal).
- Write a free-form todo memory entry (pollutes memory with transient items).

None of these produce a real artefact with an ID, priority, or a home in `docs/`.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — "without slowing down" is exactly this tension, and it applies to problems, retros, and ADRs equally.
  - Tech-lead persona (JTBD-201 Restore Service Fast) — noticing latent problems + capturing decisions during incidents is common; aside capture matters more under time pressure.
  - Plugin-developer persona (JTBD-101) — inconsistent mid-task invocation across governance skills makes "clear patterns" harder.
- **Frequency**: Every non-trivial session. Real work surfaces multiple noticed-in-passing observations across all three categories.
- **Severity**: High. The suite's entire governance discipline depends on capture being cheap. If capture is expensive, capture stops happening across every artefact type, and the discipline silently erodes.
- **Analytics**: N/A. Observed this session in two user statements:
  - "is there a way to run skills like `/wr-itil:manage-problem` as an aside, similar to how `/btw` works?"
  - "`/wr-retrospective:run-retro` is another one that would be handy to run in the background, or with as little interruption to the main flow as possible. Same for creating ADRs."

## Root Cause Analysis

Three contributing factors:

1. **Skill invocation is turn-consuming by design.** Claude Code slash commands and Skills occupy the current turn. There is no built-in dispatcher that runs a skill in a side-channel and returns control to the prior task. ADR-011 covers cross-skill invocation (skill-to-skill), not user-initiated mid-turn asides.
2. **No skill has a capture-only mode.** Every governance skill (manage-problem, run-retro, create-adr) assumes the user intends to do full intake. None have a "just stub it and remind me later" mode. Even if an aside mechanism existed, each skill would still be heavyweight.
3. **No shared aside pattern.** If each skill solves this independently, the three implementations will diverge. A shared "aside invocation" pattern (hook, shim, or stub-mode protocol) applied consistently across governance skills is the right abstraction level.

### Investigation Tasks

- [ ] Decide the aside mechanism — must work for all three skills, not one. Options: (a) a capture-only sub-skill per governance skill (`manage-problem-stub`, `retro-stub`, `adr-stub`) sharing a common stub-file protocol; (b) a single cross-plugin `/btw` or `/aside` command that dispatches to the appropriate skill's stub-mode based on keyword; (c) sub-agent dispatch via the Agent tool that runs the full flow in isolated context and returns a one-line receipt; (d) hook-driven capture that writes a stub file from a single user line without invoking Claude at all.
- [ ] Author ADR — now scoped to the full pattern, not just problems. Candidate path: `docs/decisions/012-aside-invocation-pattern.proposed.md` (renamed from the narrower `-capture-` title). Must cover: invocation mechanism; how control returns to the main turn; stub-vs-full artefact contract shared across problems/retros/ADRs; interaction with ADR-011's `Skill`-tool handoff (don't fork the full skills); tension with P016/P017 (intake-splitting adds friction — P014 wants less friction; the pattern must resolve both).
- [ ] Design the stub file contract per artefact type:
  - **Problem stub**: `## Description` + `Reported` + Status=Open + `needs-triage` marker. `manage-problem review` finishes intake later.
  - **Retro stub**: one-line observation + trigger context. `run-retro` ingests queued stubs when next invoked.
  - **ADR stub**: `## Context` + decision headline + Status=draft. `create-adr` expands when author is ready.
- [ ] Define the command surface. Per-skill aside (`/wr-itil:capture`, `/wr-retrospective:capture`, `/wr-architect:capture`) or one dispatcher (`/btw <kind>: <one-liner>`)? Naming falls under ADR-010's scope.
- [ ] Resolve tension with P016/P017. Those problems want MORE intake rigor (split multi-concern inputs). P014 wants LESS. Pattern must allow both: aside creates a stub; later "review" pass runs the full intake including concern-splitting on the queued stubs.
- [ ] Create reproduction tests: simulate sessions where the user types the aside mid-task for each artefact type; verify (1) the stub is created, (2) the main task context is preserved, (3) a subsequent full-skill invocation picks up and completes the stub.

## Related

- User questions this session (two triggers, two skills):
  - "is there a way to run skills like `/wr-itil:manage-problem` as an aside, similar to how `/btw` works?"
  - "`/wr-retrospective:run-retro` is another one that would be handy to run in the background... Same for creating ADRs."
- ADR-011 (proposed): `docs/decisions/011-manage-incident-skill.proposed.md` — cross-skill invocation via `Skill` tool; neighbour pattern but not user-initiated asides
- ADR-010 (proposed): `docs/decisions/010-plugin-command-naming.proposed.md` — command surface naming
- ADR-002 (proposed): `docs/decisions/002-monorepo-per-plugin-packages.proposed.md` — skill inventory/layout
- Tension: `docs/problems/016-manage-problem-should-split-multi-concern-tickets.open.md` — wants more intake rigor
- Tension: `docs/problems/017-create-adr-should-split-multi-decision-records.open.md` — wants more intake rigor
- Affected skills:
  - `packages/itil/skills/manage-problem/SKILL.md`
  - `packages/retrospective/skills/run-retro/SKILL.md`
  - `packages/architect/skills/create-adr/SKILL.md`
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`
- JTBD-101: `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`
- JTBD-201: `docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md`
