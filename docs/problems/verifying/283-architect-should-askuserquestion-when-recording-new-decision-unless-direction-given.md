# Problem 283: Architect agent should always use AskUserQuestion to gather direction when recording a new decision — unless an explicit direction has already been given

**Status**: Verification Pending
**Reported**: 2026-05-23
**Priority**: 9 (Med High) — Impact: 3 (Moderate — ADRs land with autocratically-chosen options that drift from user intent; user must re-direct in follow-up turns; degraded audit-trail of "why this option"; recurrent friction class) x Likelihood: 3 (Likely — affects every ADR-creation flow that lacks pre-pinned direction; sibling-class to P085 main-agent prose-ask pattern)
**Effort**: XL — re-rated M → XL 2026-05-23 (P047) when the user folded the retroactive review of the 52 existing `.proposed.md` ADRs into scope as **prong 2** (user direction: *"two-pronged fix: 1) make the skill ask. 2) review the existing ADRs"*). **Prong 1** (architect Needs-Direction verdict + new ADR + `agent.md` edit + ADR-026 reparenting fold-in + create-adr/capture-adr handoff + confirm-gate + dual tests) is M-L on its own. **Prong 2** (read + `AskUserQuestion`-confirm 52 proposed ADRs; gate proposed→accepted on confirm) is a multi-day interactive sweep = XL on its own. Aggregate time-to-close = XL.
**WSJF**: 2.25 — (9 × 2.0) / 8 — Known Error × XL effort (the prong-2 52-ADR review sweep dominates time-to-close). NOTE: prong 1 ("make the skill ask") is the urgent, high-value sub-task — it stops *new* poor auto-decisions — and is worked FIRST within the Known-Error fix-task order, despite the aggregate XL rank. (Prior values: Open 3.0 mis-scored /3; transition Known-Error M 9.0; scope-expanded to XL 2.25.)

## Fix Released

**Release marker**: Prong 1 — `@windyroad/architect@0.8.0` (ADR-064 architect Needs-Direction verdict + born-confirmed create-adr; already live). Prong 2 mechanism — `@windyroad/architect@0.9.0` + `@windyroad/itil@0.35.12` (commit `b2e64f6`, ADR-066: `human-oversight` marker + `wr-architect-detect-unoversighted` + `architect-oversight-nudge.sh` + `/wr-architect:review-decisions`), released via the AFK loop drain 2026-05-26 with in-repo dogfood evidence.
**Fix summary**: Prong 1 stops NEW poor auto-decisions (architect emits a Needs-Direction verdict → main agent routes through AskUserQuestion; capture-adr skeletons can't reach `accepted` without a confirm). Prong 2 ships the decision-oversight mechanism (born-confirmed going forward; cheap grep detector; session-start nudge; on-demand drain skill) AND drained this repo's existing unoversighted set (10 ADRs reviewed 2026-05-26: 4 confirmed, 2 amended+confirmed [ADR-060 canonical-spine, ADR-043 auto-trigger requirement], 2 rejected-pending-supersede [ADR-034 no-network-auto-install, ADR-055 strip-not-expose-IDs], 2 deferred [ADR-047/P297, ADR-063/P300]).
**Awaiting user verification**: confirm on a fresh interactive session that the `architect-oversight-nudge` fires at session start reporting the unoversighted count (the residual 4: ADR-034, ADR-055, ADR-047, ADR-063 — all unoversighted by design pending their rework/unblock) and that `/wr-architect:review-decisions` drains correctly. NOTE: the 3 reworks surfaced by the drain are NOT P283 scope and are ALREADY tracked as existing Open tickets (no new tickets needed — the 2026-05-25 drain pass had already captured them): **P299** (supersede ADR-034 — per-project auto-install wrong / no network auto-install), **P298** (supersede ADR-055 — strip internal IDs from published artefacts, don't prefix/expose), **P295** (implement the ADR-043 deep-layer auto-trigger / automatic cadence).
**Drain residual**: after this drain, the unoversighted set is 4 ADRs — ADR-034 + ADR-055 (rejected, awaiting supersede) and ADR-047 + ADR-063 (deferred, blocked by P297/P300). The nudge will correctly continue flagging these until superseded/unblocked.

## Description

Class-of-behaviour observation 2026-05-23: when the `wr-architect:agent` subagent (or the `/wr-architect:create-adr` / `/wr-architect:capture-adr` skills) is recording a new architecture decision (proposing or capturing a new ADR), it should **always** route the direction-gathering through the `AskUserQuestion` tool — not via prose asks, not via silent autocratic decision, not by deferring all options to the user without structuring them.

The user-stated rule: *"the architect should always use the askuserquestion tool to get direction when recording a new decision unless an explicit direction has been given."*

Two carve-outs implied by the rule:

1. **Explicit direction already given** — if the user has already pinned a direction in the same turn / same session (e.g. *"go with Option A"*, *"use the per-state-subdir shape"*, *"yes, take the bypass route"*), the architect must act on that direction without re-asking. This is the "act on obvious" half of P085 / `feedback_act_on_obvious_decisions.md` scaled down to the architect surface.
2. **AskUserQuestion is the required ask shape** — when direction is NOT given, prose asks ("Want me to use Option A or Option B?", "Should I prefer the in-line refresh or the deferred refresh?") are non-compliant. The structured AskUserQuestion tool is mandatory. This is the P085 Facet B rule scaled down to the architect surface.

**Implementation reality complication**: the architect agent's tool surface (per `wr-architect:agent` definition) currently lists only `Read, Glob, Grep`. AskUserQuestion is NOT in that surface. So the architect agent CANNOT directly call AskUserQuestion in its current form. Three plausible resolution shapes for investigation:

- **Shape A — Extend the architect agent's tool surface** to include AskUserQuestion. Lets the subagent ask directly. Risk: subagents can typically only call tools synchronously within their own context; whether AskUserQuestion can be invoked from a subagent depends on the harness — needs verification.
- **Shape B — Architect emits a structured "needs-direction" verdict** that the calling skill (or main agent) translates into an AskUserQuestion call. The architect's job becomes "name the options + name the question"; the main agent's job becomes "execute the ask". This is the cleaner separation-of-concerns.
- **Shape C — Architect-driven SKILL contract amendments** for `/wr-architect:create-adr` and `/wr-architect:capture-adr`: the skill explicitly invokes AskUserQuestion for direction-gathering BEFORE delegating to the architect subagent, OR after receiving its verdict, depending on whether direction is already pinned. The architect subagent stays read-only-tools; the skill orchestration owns the ask.

The user's framing doesn't disambiguate which shape they want — capture-problem captures the observation; the architect verdict on the implementation shape belongs in the investigation (which is itself a recursion: the architect verdict on this ticket should... use AskUserQuestion).

**User intent clarification (2026-05-23)**: *"the reason for P283 is because I've been noticing that some of the automatically decided decisions are poor, so we're going to lift them up and make them human decisions. As part of the work, I guess we should use the askuserquestion tool to review and confirm every ADR."* This (a) confirms the resolution direction — auto-decided decisions drift, so lift them to human decisions (validates Shape B + AskUserQuestion-for-direction), and (b) adds a go-forward requirement: **every ADR must get an `AskUserQuestion` review-and-confirm** before it stands as a decision. create-adr Step 5 (confirm-with-user) already does this for full-intake ADRs; the gap is that capture-adr skeletons (`.proposed.md`, zero-ask by carve-out) stand as proposed decisions WITHOUT a confirm pass — so the fix must make the confirm-gate load-bearing across both surfaces (a capture-adr skeleton must not reach `accepted` without a create-adr/AskUserQuestion confirm). **Decision (2026-05-23, user)**: this is a **two-pronged fix held in P283** (not split to a sibling): *"The problem is that we have poor automatically made decisions. This needs a two pronged fix: 1) make the skill ask. 2) review the existing ADRs."* Prong 1 = the architect-contract / recording-flow fix (stop NEW poor auto-decisions). Prong 2 = a retroactive review-and-confirm sweep of the 52 existing `.proposed.md` ADRs (clean up EXISTING poor auto-decisions; gate proposed→accepted on an `AskUserQuestion` confirm). Both prongs are fix tasks under this ticket — see Fix Strategy.

## Symptoms

(deferred to investigation)

- Architect proposes ADRs with Decision Drivers / Considered Options sections filled out autocratically, without first surfacing "which driver is load-bearing?" or "which option do you want?" to the user via AskUserQuestion.
- Architect agent issues prose asks in its verdict text ("I recommend Option B but you might prefer Option A — which?") instead of structured-ask output.
- The user has to repeatedly re-direct the architect's chosen option in follow-up turns, when a single AskUserQuestion at decision-recording time would have settled it cleanly.
- `/wr-architect:create-adr` and `/wr-architect:capture-adr` SKILLs do not call AskUserQuestion before invoking the architect agent for option-resolution decisions.
- Sibling ADR-013 Rule 1 (AskUserQuestion mandate for governance decisions) is treated as main-agent-only; the architect subagent has been treated as exempt.

## Workaround

Confirmed (any one suffices until the permanent fix lands):

- **User-side**: explicitly pin direction in the prompt that invokes the recording flow (*"record this ADR but use Option B"*) — hits the existing "explicit direction has been given" carve-out, so no decision-recording gap exists.
- **Main-agent-side** (already-correct path): record decisions via `/wr-architect:create-adr`, NOT by writing an ADR directly off the architect subagent's prose recommendation. create-adr already routes the cat-1 direction-setting fields (Decision Drivers, Considered Options, Decision Outcome, Consequences, Confirmation, decision-makers) through `AskUserQuestion` (Step 2 retained surfaces + Step 2b multi-decision split + Step 5 confirm). The gap is ONLY hit when the main agent shortcuts that flow and writes the ADR autocratically from the architect's prose verdict.
- **Skill-side**: `/wr-architect:capture-adr` is already safe — it is zero-ask *because* it only fires when the user has pre-pinned the one-line decision in `$ARGUMENTS` (the carve-out) and halts-with-directive on empty args.

## Impact Assessment

- **Who is affected**: (deferred to investigation)
  - Solo-developer persona — has to manually re-direct architect-proposed options multiple times per ADR; friction class.
  - Tech-lead persona — ADRs land with options that don't reflect the user's actual direction; audit trail of "why this option" is degraded.
  - AFK orchestrators — architect-proposed ADRs may land with autocratically-chosen options that drift from user intent across long loops; correction lag is high.
- **Frequency**: (deferred to investigation) — every ADR creation that lacks pre-pinned direction.
- **Severity**: (deferred to investigation) — Medium pending diagnosis; recoverable via follow-up redirection but the friction class is recurrent.
- **Analytics**: (deferred to investigation) — count of ADRs amended within 1-3 turns of initial creation as a proxy for direction-mismatch; count of `wr-architect:agent` outputs containing prose-ask patterns vs structured-option outputs.

## Root Cause Analysis

**Confirmed 2026-05-23** (investigation + `wr-architect:agent` verdict). Root cause: the architect *agent* verdict surface has no structured "needs-direction" output type. When the architect detects an undocumented decision with 2+ viable options and no pinned direction, its only verdict vocabulary is PASS / ISSUES FOUND — so it either autocratically recommends one option in its verdict text, or prose-asks ("I recommend B but you might prefer A — which?"). The main agent then has no contract telling it to translate that into `AskUserQuestion` before recording. The two recording skills are NOT the gap (see below).

### Findings

1. **Shape A (extend the architect subagent's tool surface to include AskUserQuestion) is rejected — it is ADR-013's documented rejected Option A.** Evidence: ADR-013 (`013-...proposed.md`) lines 33-45 — "Option A: Expand tool grants on all agents — Add `AskUserQuestion` to every governance agent's `tools:` frontmatter," rejected with Con "Breaks the pure scorer pattern… Agents invoked via Task tool cannot enter plan mode on the parent's behalf — plan mode is a primary-agent affordance." Suite-wide confirmation: NO subagent declares `AskUserQuestion` (architect / jtbd / risk-scorer×7 / style-guide / tdd / voice-tone all declare only Read/Glob/Grep; jtbd adds Bash). The canonical implementing precedent is `packages/tdd/agents/review-test.md` line 167: *"You MUST NOT call `AskUserQuestion` even when classification is genuinely ambiguous; emit `verdict: "unclear"` and let the main agent escalate."* `AskUserQuestion` is primary-agent UX (memory `feedback_askuserquestion_is_universal.md`), not a subagent affordance.

2. **`/wr-architect:create-adr` is already compliant.** Step 2 derive-first dispatch retains `AskUserQuestion` for the 6 cat-1 direction-setting fields (decision-makers, Decision Drivers, Considered Options, Decision Outcome, Consequences, Confirmation), plus Step 2b multi-decision split and Step 5 confirm-with-user. The "unless direction given" carve-out is present ("use what they've given and only fire AskUserQuestion for the cat-1 fields still missing").

3. **`/wr-architect:capture-adr` is already compliant by carve-out.** Documented "zero AskUserQuestion branches by design" — but only fires when the user has pre-pinned the one-line decision in `$ARGUMENTS` (the "explicit direction has been given" case) and halts-with-directive on empty args. It records the user's already-given decision into a skeleton; it never resolves option-direction autocratically.

4. **The genuine gap is the architect-agent verdict surface (Shape B).** No structured "needs-direction" verdict type exists; the main-agent translation contract is undocumented.

5. **Scope vs P085 / P135 reconciled.** P085 (main-agent prose-ask master class) and P135/ADR-044 (decision-delegation-contract) are siblings, not duplicates — P283 is the architect-*agent* verdict-surface instance. ADR-044's Reassessment clause pre-authorises a new sibling ADR for "a new pattern with its own ask-vs-act distinction not covered by this ADR" (architect verdict Q2). Keep P283 separate; cite ADR-013 Rules 2-3 + ADR-044's 6-class taxonomy as parents.

6. **"Explicit direction has been given" defined.** Counts as given: same-turn option pin, same-session pin, or project-policy pin (an existing accepted ADR, RISK-POLICY.md appetite, or a CLAUDE.md mandatory rule that already resolves the option). When direction is given, the architect emits a "direction already given" note and the main agent acts without asking — the "act on obvious" half (`feedback_act_on_obvious_decisions.md`, P085).

### Investigation Tasks

- [x] Verify whether `wr-architect:agent` can call AskUserQuestion — **No.** Read-only Read/Glob/Grep surface; suite-wide non-interactive verdict-emitter convention (precedent: tdd `review-test.md` L167). Shape A rejected (= ADR-013 Option A).
- [x] Architect verdict on implementation shape — **Shape B + thin Shape C; reject A** (architect ISSUES FOUND verdict 2026-05-23; PASS on shape, ISSUES = "needs a new sibling ADR + two fold-in items").
- [x] Reconcile scope vs P085 — sibling, keep separate (architect-agent verdict-surface instance of the main-agent prose-ask class).
- [x] Reconcile scope vs P135 / ADR-044 — new sibling ADR citing ADR-044 taxonomy (Reassessment clause pre-authorises).
- [x] Define "explicit direction has been given" precisely — done (finding 6).
- [x] **Prong 1** Implement Shape B + thin Shape C — DONE 2026-05-23: ADR-064; `agent.md` NEEDS DIRECTION verdict + `[Needs Direction]` issue type + "When to emit" section; create-adr/capture-adr handoff + confirm-every-ADR notes.
- [x] **Prong 1** Record the new sibling ADR — DONE: ADR-064 written via the asking flow (architect PASS, user-confirmed via AskUserQuestion "Record as drafted"). Demonstrates P283 in action.
- [x] **Prong 1** Fold in the ADR-026 reparenting on `agent.md` — DONE: added "per ADR-026, specialised by ADR-023" parent citation to the Runtime-Path Performance Review section (discharges ADR-026 Confirmation item 1; the separate ADR-023-prose P022→ADR-026 update stays deferrable until ADR-026 acceptance).
- [x] **Prong 1** Dual test surface — structural doc-lint DONE (`architect-needs-direction-verdict.bats`, 6 tests passing; framed as ADR-052 Surface 2 `structural-justified` citing P176, NOT the old ADR-005 Permitted Exception — per architect correction). Behavioural skill-translation test BLOCKED on P176 (no skill-invocation harness); tracked in ADR-064 Confirmation items 2-3.
- [x] **Prong 2** Build the cross-project decision-oversight mechanism (see Fix Strategy item 6) — DONE: ADR-066 (`human-oversight` + `oversight-date` frontmatter marker, orthogonal to `status:`), `wr-architect-detect-unoversighted` cheap grep detector, `architect-oversight-nudge.sh` SessionStart nudge (self-suppresses under `WR_SUPPRESS_OVERSIGHT_NUDGE=1` in AFK), `/wr-architect:review-decisions` drain skill, born-confirmed `create-adr`. Built 2026-05-25; held as `p283-oversight-mechanism` changeset; **graduated + released 2026-05-26 per user direction** (`@windyroad/architect@0.9.0` + `@windyroad/itil@0.35.12`) with in-repo dogfood evidence (nudge fires against this repo's 10-ADR unoversighted set + self-suppresses under the AFK guard). Sibling `p288-jtbd-persona-oversight` stays held.
- [x] **Prong 2** Drain this repo's unconfirmed set — DONE 2026-05-26 (interactive sweep via the review-decisions mechanism, run by the orchestrator in-turn because the freshly-installed skill was not yet in the session registry — identical detect→AskUserQuestion-confirm→write-marker flow). The set was **10 unoversighted** (not the ~52 estimated at capture — the bulk had already been confirmed; 48/57 carried the marker). Outcome:
  - **Confirmed (marker written)**: ADR-018 (release cadence), ADR-019 (AFK preflight), ADR-052 (behavioural-tests-default), ADR-054 (SKILL.md runtime budget).
  - **Amended + confirmed**: ADR-060 (accepted — canonical execution spine clarified to Problem→RFC→story-map(s)→stories, ADRs alongside); ADR-043 (deep context-analysis layer MUST be auto-triggered, not on-demand-only — implementation tracked as follow-up).
  - **Rejected (NO marker — supersede follow-up needed)**: ADR-034 (auto-install on session start — user: "should not reach out to the network and randomly install new versions; that would be horrible"; proposed-only, never implemented → supersede with a no-auto-install decision), ADR-055 (namespace-prefixed internal IDs — user: "we do not expose IDs in published artifacts"; prefix sweep never applied → supersede with a strip-IDs decision per P137 candidate A).
  - **Deferred (blocked)**: ADR-047 (blocked by P297 — governance-artefact scaffold as SessionStart hook), ADR-063 (blocked by P300 — maturity-presentation schema F1-vs-F2 + badge). Stay unoversighted until P297/P300 resolve.
  - **Follow-ups surfaced by the drain** — ALREADY tracked as existing Open tickets (the 2026-05-25 drain pass captured them; verified 2026-05-26, no new tickets created): (a) **P299** supersede ADR-034 → no-network-auto-install; (b) **P298** supersede ADR-055 → strip internal IDs from published artefacts (not prefix); (c) **P295** implement the ADR-043 deep-layer auto-trigger / automatic cadence (threshold/tiered escalation from the cheap layer).

## Fix Strategy

**Two-pronged (user direction 2026-05-23).** Prong 1 (items 1-5) stops NEW poor auto-decisions; prong 2 (item 6) cleans up EXISTING ones. Prong 1 is worked first (urgent — stops the bleeding).

### Prong 1 — make the recording flow ask (Shape B + thin Shape C; reject Shape A)

Adopt **Shape B + a thin Shape C slice; reject Shape A** (architect verdict 2026-05-23). Reproduction/confirmation is referenced here rather than committed at transition time (the test is part of the fix; manage-problem Open-flow permits "test exists OR is referenced").

1. **New sibling ADR** — define the architect **Needs Direction** verdict type (third verdict alongside PASS / ISSUES FOUND): when the architect detects an undocumented decision with 2+ viable options AND no pinned direction, emit a structured block naming the question + the candidate options (each grounded in what was read, per ADR-026); when direction IS pinned, emit a "direction already given" note. Document the main-agent translation contract: on a Needs-Direction verdict the main agent translates it into `AskUserQuestion` (never a prose ask) before recording the decision — unless direction is already given. Codify the suite-wide invariant "all reviewer subagents are non-interactive verdict-emitters; `AskUserQuestion` is a primary-agent/skill affordance only" (promote from undocumented norm to decision). Cite ADR-013 Rules 2-3, ADR-044 6-class taxonomy, and `tdd/review-test.md` as precedent.
2. **`packages/architect/agents/agent.md`** — add the Needs-Direction verdict to the "How to Report" + issue-types sections. Opportunistically fold in the outstanding ADR-026 reparenting on the performance-review section (lines ~65-88 currently cite only ADR-023; ADR-026 Confirmation item 1 requires the P022 → ADR-026 reparent).
3. **`/wr-architect:create-adr` + `/wr-architect:capture-adr`** — thin handoff note documenting that a Needs-Direction architect verdict routes through the skill's existing `AskUserQuestion` surfaces (both skills are already compliant; the note makes the handoff explicit, not a new ask).
4. **Tests** — (a) structural doc-lint bats guard that `agent.md` carries the Needs-Direction verdict type (Permitted Exception to the source-grep ban per ADR-005/P011, matching `architect-output-formatting.bats` / `architect-performance-review.bats`); (b) a behavioural test on the skill/main-agent translation side (the side with a deterministic surface). Keep the two assertions distinct, mirroring the ADR-013 Rule 2 / Rule 3 split.
5. **Confirm-every-ADR gate (user direction 2026-05-23)** — make the `AskUserQuestion` review-and-confirm load-bearing for *every* ADR, not just full-intake create-adr runs. create-adr Step 5 already confirms; the new ADR (item 1) must additionally specify that a capture-adr `.proposed.md` skeleton CANNOT transition to `accepted` without a create-adr/AskUserQuestion confirm pass — closing the "auto-decided skeleton stands as a decision" gap the user flagged. Document this as a Confirmation criterion on the new ADR.

### Prong 2 — review the existing ADRs (retroactive sweep)

6. **Retroactive review-and-confirm sweep of the 52 existing `.proposed.md` ADRs.** Root concern: poor *automatically-made* decisions already live in `docs/decisions/` as proposed ADRs that no human picked. Sweep them: for each, surface the chosen option + the alternatives via `AskUserQuestion` so the user confirms, amends, or rejects the auto-made call. Multi-day interactive work — best run as focused sittings, not one blocking pass. This is the prong that drives the XL effort rating.

7. **Cross-project decision-oversight mechanism (design settled 2026-05-23, user; built under this ticket per user direction "keep it all inside P283 prong 2").** Adopter projects that use the architect plugin have the same problem — decisions recorded without human oversight. Ship a reusable, token-cheap mechanism in the architect plugin:

   - **Oversight marker (ADR-009 persistent-marker pattern).** An ADR frontmatter field — `human-oversight: confirmed` + `oversight-date: YYYY-MM-DD` — recording that a human reviewed and confirmed the decision. **Orthogonal to `status:`** — an ADR can be `accepted` (production-validated) yet never human-*oversighted* (auto-decided then shipped), so oversight needs its own axis. (Exact field name to confirm at build via the asking flow.)
   - **Born-confirmed going forward.** ADR-064 (prong 1) makes `create-adr` ask + confirm; any ADR recorded through that flow is written `human-oversight: confirmed` automatically. The new-decision leak is closed, so the unconfirmed set only ever shrinks.
   - **Cheap detection (the token-efficiency answer).** The "needs oversight" set = ADRs whose frontmatter lacks the marker. Detection is a **grep over frontmatter — no body reads, no per-ADR LLM call.** Steady-state cost ≈ one grep; only unconfirmed ADRs get read + presented. Once drained, ongoing cost is ~zero.
   - **Trigger — DECISION 2026-05-23 (user): session-start nudge + drain skill** (AskUserQuestion options: nudge+skill / skill-only / confirm-on-touch → chose nudge+skill). A cheap grep at session start (like the briefing-currency nudge) reports `N decisions lack human oversight — run /wr-architect:review-decisions`; a new **`/wr-architect:review-decisions`** skill drains the unconfirmed set in batches via `AskUserQuestion` (cluster by topic, load-bearing ADRs first), writing the marker on each confirm. Never re-asked (ADR-009 marker persists).
   - **Scope — DECISION 2026-05-23 (user): keep in P283 prong 2** (declined the "new ticket + ADR; P283 depends on it" split — the AskUserQuestion offered both). The mechanism is built here; prong-2 task 2 ("drain this repo's unconfirmed set") consumes it.
   - **Recording:** the mechanism itself is an architecture decision (frontmatter-schema change + new skill + session-start hook) — record it as its own ADR (e.g. ADR-065) via the now-asking create-adr flow when built. This is the eat-our-own-dogfood loop: the oversight mechanism's own ADR goes through the oversight flow.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — investigation can begin immediately)
- **Composes with**:
  - **P085** (assistant prose-asks vs AskUserQuestion master class — same axis, broader scope)
  - **P135** (decision-delegation-contract-master — ADR-044 framework-resolution boundary surface)
  - **ADR-013** (structured user interaction for governance decisions — Rule 1 AskUserQuestion mandate)
  - **ADR-044** (decision-delegation contract — category 5 taste vs category 4 silent-framework boundary)
  - **`/wr-architect:create-adr` SKILL** (canonical ADR-creation surface; likely amendment target)
  - **`/wr-architect:capture-adr` SKILL** (lightweight aside-capture variant; threshold question)
  - **`wr-architect:agent` definition** (tool-surface extension question — Shape A)
  - **`feedback_act_on_obvious_decisions.md`** (carve-out grounding — the "unless direction given" half)
  - **`feedback_askuserquestion_is_universal.md`** (universal-primary-agent-UX grounding — extending the rule from main-agent to subagent surfaces)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- P085 — assistant prose-asks vs AskUserQuestion master class (sibling, NOT duplicate; P085 is main-agent scope, P283 is architect-subagent scope).
- P135 — decision-delegation-contract-master.
- ADR-013 — structured user interaction for governance decisions.
- ADR-044 — decision-delegation contract.
- `feedback_act_on_obvious_decisions.md` — carve-out grounding.
- `feedback_askuserquestion_is_universal.md` — extending rule from main-agent to subagent.
- `packages/architect/agents/agent.md` — `wr-architect:agent` definition; tool-surface question (Read/Glob/Grep only — confirmed). The edit target for the Needs-Direction verdict type.
- `packages/tdd/agents/review-test.md` (L167) — implementing precedent for the non-interactive subagent verdict-emitter pattern (`verdict: "unclear"` → main agent escalates).
- ADR-013 (`013-...proposed.md`) lines 33-45 — Option A = Shape A, documented-rejected ("Breaks the pure scorer pattern").
- ADR-026 (`026-...proposed.md`) Confirmation item 1 — the outstanding `agent.md` P022 → ADR-026 reparenting debt to fold in.
- `packages/architect/skills/create-adr/SKILL.md` — canonical ADR-creation surface.
- `packages/architect/skills/capture-adr/SKILL.md` — lightweight aside-capture variant.
