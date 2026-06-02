# Problem 105: `/wr-retrospective:run-retro` needs a signal-vs-noise pass on briefing entries to drive session-start curation

**Status**: Verification Pending
**Reported**: 2026-04-22
**Priority**: 16 (High) — Impact: Major (4) x Likelihood: Likely (4)
**Effort**: M
**WSJF**: (16 × 1.0) / 2 = **8.0**

> Split from P100 slice 2 during the 2026-04-22 design session. User framing (2026-04-22): *"basically we want to ask 'what was signal and what was noise' and then adjust accordingly"*. Run-retro gains a signal-vs-noise pass over briefing entries that were in context this session: signal (fired, saved a turn) gets promoted or kept in the Critical Points roll-up; noise (didn't fire, wasted attention, misleading) gets demoted, archived, or deleted. The curation mechanism is the feedback channel the SessionStart hook's value depends on over time.

## Description

P100 slice 1 migrated `docs/BRIEFING.md` into `docs/briefing/<topic>.md` per-topic files + `docs/briefing/README.md` as an index with a curated "Critical Points (Session-Start Surface)" roll-up. Slice 2 (this session) ships the `SessionStart` hook that reads the Critical Points roll-up and injects it at session start.

The Critical Points roll-up is currently curated by human judgment during `/wr-retrospective:run-retro` — the retro author decides which entries are "highest-value rules that save the most wasted turns". Without a feedback signal, curation is unanchored: old entries can linger in the Critical Points list even when they no longer fire, and new high-value entries may sit in a topic file instead of being promoted.

The user's refined framing (2026-04-22, during slice-2 execution): *"basically we want to ask 'what was signal and what was noise' and then adjust accordingly"*. The retro asks, per briefing entry that was in context this session: was it **signal** (fired, saved a turn, genuinely useful) or **noise** (didn't fire, wasted attention, misleading, stale)? Adjust accordingly — promote / keep / demote / archive / delete. Without this feedback loop, the SessionStart hook surfaces whatever the most recent retro author chose, which drifts away from actual usefulness over time.

## Symptoms

- `docs/briefing/README.md`'s Critical Points section is curated by the last run-retro author; no consumer-side signal validates that those are indeed the most helpful entries.
- New high-value briefing entries (e.g., discovered during a session) rely on the same author's judgment to reach the Critical Points roll-up. Slow uplift for entries that aren't obviously load-bearing.
- Stale entries (e.g., a workaround that no longer applies because the underlying bug was fixed) linger in Critical Points until a future author spots them.

## Workaround

Manual curation during run-retro. Retro author reads the Critical Points roll-up and promotes / demotes / archives entries based on memory of which ones helped this session. Burden scales with briefing-tree size.

## Impact Assessment

- **Who is affected**: Every session that reads the SessionStart briefing injection. As the briefing grows, signal-to-noise in Critical Points degrades without a feedback loop.
- **Frequency**: Every retrospective and every session that reads Critical Points (per P100 slice 2).
- **Severity**: Major. Directly affects the quality of the session-start briefing surface — the headline value of P100. A decayed roll-up produces wasted attention at session start.
- **Analytics**: Baseline after P100 slice 2 ships: count Critical Points entries that fire (cited) per session vs. entries that don't. Target: high-firing entries stay / rise in roll-up; low-firing entries drop.

## Root Cause Analysis

### Preliminary Hypothesis

run-retro Step 1 (read BRIEFING) and Step 3 (write learnings) both act on the author's current memory of the session. No step asks the author to classify each briefing entry that was in context this session as **signal** or **noise** and adjust accordingly. A new Step (candidate: 1.5 "Briefing signal-vs-noise pass" between Step 1 and Step 2) would prompt the author to label each exercised entry and propose the adjustment.

### Investigation Tasks

- [x] Architect review at implementation time — may warrant amending ADR-040 (Session-start briefing surface, proposed this session) to document the signal-vs-noise feedback loop as part of the curation contract rather than a separate decision. (Architect verdict 2026-04-22 AFK iter 2: amend ADR-040 inline; do NOT mint a new ADR. Three issues raised — see "Architect findings" below.)
- [ ] Decide the signal/noise classification shape: binary (signal / noise), ternary (signal / noise / neutral), or free-text category. User direction points at binary — "what was signal and what was noise" — but "neutral / didn't fire" may still be useful data. **(Architect-recommended: binary; matches user framing. See Outstanding Design Questions Q1.)**
- [ ] Decide the adjustment rules: signal → promote to Critical Points roll-up (or keep if already there); noise → demote to topic file (or archive / delete if stale); what counts as "this session's entries in context" for the pass? **(Architect-recommended: promote/keep/demote/archive single-retro decisions; delete gated behind two-retro-consecutive-noise OR explicit user confirmation. See Outstanding Design Questions Q3.)**
- [ ] Decide who runs the classification: user (prompted during run-retro), assistant (self-reports from tool-call history about which entries were cited / paraphrased / acted on), or both. **(Architect-recommended: assistant pre-classifies via ADR-026 grounding — "entry cited in tool call X at turn N" = signal evidence; "no in-context citation observed this session" = noise evidence — and only prompts user on ambiguous cases per ADR-013 Rule 5 policy-authorise. See Outstanding Design Questions Q1.)**
- [ ] Decide where the signal is persisted: per-entry front-matter in the topic file, index rows in `docs/briefing/README.md`, or a sidecar ledger (e.g., `docs/briefing/.signal-ledger.jsonl`). **(Architect-recommended (mild conviction): per-entry front-matter in topic files — localises data with the entry, survives renames, no new sidecar source-of-truth. See Outstanding Design Questions Q2.)**
- [ ] Amend `/wr-retrospective:run-retro` SKILL.md with the new step and data-shape contract.
- [ ] Amend `docs/decisions/040-session-start-briefing-surface.proposed.md` with a new "Curation feedback contract (P105)" subsection picking the persistence format. **Pre-condition: user answers Outstanding Design Question Q2 below.**
- [ ] Bats coverage: simulate a run-retro invocation against a briefing tree; assert classification → roll-up regeneration.

### Architect findings (2026-04-22 AFK iter 2)

Architect (`wr-architect:agent`) review during P105 work-iteration returned ISSUES FOUND with three blocking design questions and recommended the **investigated outcome** for this iteration. Findings reproduced here verbatim-equivalent so subsequent sessions have the full citation set.

**Issue 1 — Per-entry `AskUserQuestion` fan-out is a hard ADR-013 / ADR-032 conflict.** ADR-032 line 203 explicitly names the cascading-batch fan-out as the P061 anti-pattern. With 8 Critical Points + ~20–40 entries across 6 topic files, naive per-entry prompting is a 28–48-call serial fan-out per retro. Architect proposed three viable collapsed shapes:
  - (a) Single `AskUserQuestion` showing the agent's pre-classification of all in-context entries with `accept all` / `edit before saving` / `review individually` (4-option cap, batch-confirmable, echoes Step 3's existing Use-AskUserQuestion-to-confirm-removals pattern at run-retro SKILL.md line 122).
  - (b) Defer the entire pass via the ADR-032 deferred-question artefact (one artefact, one pending question batch), matching how Step 2b and Step 4a defer in AFK.
  - (c) Policy-authorise per ADR-013 Rule 5: classify silently when a clear rule applies (cited verbatim by tool-call ⇒ signal; not loaded ⇒ noise candidate); only ask on ambiguous cases.

**Issue 2 — Persistence format is a load-bearing architectural choice, not a deferrable detail.** It changes the consumer surface: README rendering, run-retro's read+write contract, and any future "auto-promote when N consecutive signals" rule that ADR-040 lines 84–90 imply via its Tier-1 budget reassessment trigger. The three shapes have meaningfully different consequences:
  - Per-entry front-matter in topic files: localises data with the entry, survives renames, no new source-of-truth — but introduces a new data convention to plain-markdown topic files.
  - README index columns: keeps the index as the curation surface — but couples signal data to the index format and complicates topic-file moves.
  - Sidecar JSONL (`docs/briefing/.signal-ledger.jsonl`): append-only, machine-readable, easy to compute aggregates over — but creates a third source of truth.

  Architect-preferred (mild conviction): **per-entry front-matter**. Recommended landing path: amend ADR-040 inline with a "Curation feedback contract (P105)" subsection (precedent: ADR-032 carries multiple in-place amendments — P077, P084, P086, P075). Do NOT mint a sibling ADR.

**Issue 3 — Step 1.5 ownership boundary + grounding + delete guard rail.** Three sub-points:
  - Match Step 2b/Step 4a ownership-boundary phrasing: be explicit about what Step 1.5 writes directly vs. what it surfaces. Step 3 already writes briefing files (precedent); Step 1.5 should follow Step 3's pattern OR explicitly defer writes to a "Step 1.5 commit batch" so the audit trail is one commit, not N.
  - Apply ADR-026 grounding: every signal/noise classification carries its citation (tool-call invocation that loaded/cited the entry; or "no in-context citation observed this session"). No bare classifications.
  - Treat `delete` as a distinct decision class — promote/keep/demote/archive are reversible; delete is not. Apply ADR-013 Rule 5 only to reversible actions; gate hard-delete behind two-retro-consecutive-noise OR explicit user confirmation. Otherwise a single retro can silently nuke a learning that would have been useful three sessions later.

**ADR-staleness check (architect)**: ADR-027 (Step-0 auto-delegation) is **superseded** by ADR-032; the orchestrator brief had pre-loaded "ADR-027" as relevant — the live decision is ADR-032's "Pattern taxonomy" — foreground synchronous (line 64). Step 1.5 fits the foreground-synchronous pattern; no Step-0 delegation is required.

### JTBD findings (2026-04-22 AFK iter 2)

JTBD review (`wr-jtbd:agent`) returned **PASS**.

- Primary alignment: JTBD-001 (Enforce Governance Without Slowing Down — `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md:18`); JTBD-005 (Invoke Governance Assessments On Demand — `JTBD-005:18`); JTBD-202 (Pre-Flight Governance Check — `docs/jtbd/tech-lead/JTBD-202-pre-flight-governance-check.proposed.md:19`).
- AFK-defer fallback explicitly endorsed by JTBD-006 line 30 ("Does not trust the agent to make judgment calls") and line 20 ("Problems requiring my judgment … are queued for my return, not guessed at").
- Soft watch-item: large deferred queue risks the "speed without sacrificing quality" outcome at JTBD-001 line 18. Implementation should cap or batch the per-entry prompts (one consolidated summary rather than N individual `AskUserQuestion` turns on return). This compounds Issue 1 — both reviewers independently flag the per-entry fan-out as the implementation risk.
- No JTBD doc updates required to land P105; ADR-040 already names P105 as the consumer-side gap and this change closes it within existing job definitions.

### Outstanding Design Questions

These questions block landing Step 1.5 and the ADR-040 amendment. Two converge on the same axis (interactive shape + classification owner — Q1) so they are batched. Each is user-answerable; the architect has provided a mildly-recommended default for each.

**Q1 — Interactive shape + classification owner.** Pick one:
  - **(a) (architect-preferred) Assistant pre-classifies + single batched-confirm `AskUserQuestion`.** Assistant scans the session's in-context briefing entries, applies an ADR-026-grounded heuristic (entry cited in tool call ⇒ signal; not loaded ⇒ noise candidate; ambiguous flagged), and emits a single 4-option `AskUserQuestion` with `accept all` / `edit before saving` / `review individually` / `defer all`. Avoids the per-entry fan-out (Issue 1).
  - **(b) Deferred-question artefact batch (ADR-032 Step 2b/4a pattern).** Same pre-classification, but the entire pass routes through the ADR-032 deferred-question artefact: one artefact carrying N pending questions surfaced on the next interactive session.
  - **(c) Policy-authorise silent classification.** Classify silently with the ADR-026 heuristic; never prompt for the routine cases; only ask on ambiguous entries (heuristic confidence < threshold).
  - **(d) User runs the classification interactively.** Original ticket framing — assistant lists entries, user answers per-entry. Rejected by architect (Issue 1) and by JTBD soft watch-item; included for completeness.

**Q2 — Persistence format.** Pick one:
  - **(a) (architect-preferred) Per-entry front-matter in topic files.** Each briefing entry gets a YAML front-matter-like block (or inline HTML comment) carrying its signal counter and last-classified date. Localises data with the entry; survives renames.
  - **(b) Index columns in `docs/briefing/README.md`.** Add `Signal` and `Last classified` columns to the Topic Index table. Keeps the index as the curation surface.
  - **(c) Sidecar JSONL: `docs/briefing/.signal-ledger.jsonl`.** Append-only ledger; entry IDs key into topic files. Easy to compute aggregates; creates a third source of truth.

**Q3 — Delete guard rail.** Pick one:
  - **(a) (architect-preferred) Two-retro-consecutive-noise lifecycle for delete.** Promote/keep/demote/archive are single-retro decisions per Q1 above; an entry classified `noise` in two consecutive retros enters a delete queue surfaced for explicit user confirmation. Avoids one-shot accidental loss of cross-session learnings.
  - **(b) Explicit user confirmation required at delete time, single-retro.** Delete is always single-retro but ALWAYS requires a separate `AskUserQuestion` confirmation (no policy-authorise short-cut). Higher per-retro friction; lower latency for genuine stale entries.
  - **(c) Soft delete only (archive bin).** No hard delete. Entries marked for deletion move to `docs/briefing/_archive/<topic>.md`; recoverable via git OR via manual revert. Closest to "no information loss" semantics.

Once the user answers Q1–Q3, a follow-up iteration can land Step 1.5 in `packages/retrospective/skills/run-retro/SKILL.md` + the ADR-040 inline amendment + bats coverage in one commit per ADR-014 (precedent: Step 3 already writes to the briefing tree; Step 1.5 follows that pattern).

### User answers (2026-04-22 interactive session post-iter-2)

User answered all three via `AskUserQuestion` after iter 2 surfaced the questions. Direction verbatim captured; answers supersede the architect's recommendations where they diverge.

**Q1 (shape + classification owner) — user chose (c) + rationale supersedes Q1 framing.** *"you, the agent are supposed to give your opinion on what was genuinely useful and what felt like noise. No point asking me. The briefing isn't for me"*. Lands as **policy-authorise silent classification** (ADR-013 Rule 5). The agent owns the classification fully; no `AskUserQuestion` at retro time. The briefing is for the agent — who knows what fired — not the user. Agent applies the ADR-026 heuristic directly: entry cited in tool call (or paraphrased in reasoning) during the session = signal; never loaded or loaded-but-unused = noise; ambiguous cases still classify but with a tentative flag the next retro resolves. Removes the entire per-entry fan-out problem (Architect Issue 1); removes the deferred-question batch (option b); removes the per-entry interactive path (option d).

**Q2 (persistence format) — deferred to agent judgement.** *"you tell me"*. **Chosen: per-entry front-matter in topic files (architect-preferred, mild conviction)**. Rationale in the Q3 new scoring context (see below): score + last-classified timestamp stored with each entry localises data with the content, survives file renames and entry reorderings, keeps a single source of truth per entry. Sidecar JSONL considered and rejected — the event log is elegant for replay but creates a third source of truth and risks drift when entries are edited without ledger updates. Index columns rejected — adding signal columns to `docs/briefing/README.md` reaches into the index rendering surface and couples the classification with the README regeneration cadence, which should stay decoupled from per-entry state.

**Q3 (delete guard rail) — user proposed a new shape: scoring with decay.** *"I was thinking of giving items a score, when they are genuinly useful they get a +1, when they are noise they get a -1, overtime they all get a -1"*. Supersedes Q3's three original options with a richer lifecycle:

- **Per-entry score**: integer, starts at `0` when the entry is first written.
- **Signal event**: `+1` when the agent classifies the entry as signal in a retro (entry was cited / paraphrased / acted on during the session).
- **Noise event**: `-1` when the agent classifies the entry as noise (entry was loaded but not used OR the entry's claim was contradicted by session observations).
- **Decay event**: `-1` per retro-cycle applied to ALL entries ("overtime they all get a -1"). Decay runs each retro regardless of per-entry classification so entries that neither fire nor are flagged as noise still drift downward. An entry that consistently fires accrues `+1` net per retro (signal + decay nets `0`, wait — actually `+1 − 1 = 0`; need to confirm semantics). Alternative: signal = `+2` to net `+1` after decay. **Open**: exact numeric values for signal/noise vs decay to achieve the intended monotonicity; initial landing can try `signal=+2, noise=-1, decay=-1` so a consistently-useful entry nets `+1/retro` and a consistently-noise entry nets `-2/retro`.
- **Promotion / demotion / deletion thresholds** (initial proposal — revisit after first-run data): score `>= +3` = promote to Critical Points (session-start surface) candidate; `0..+2` = keep in topic file; `<= -3` = delete candidate (route to delete queue for a single batched `AskUserQuestion` confirmation per the user's "information-loss guard rail" concern). Archive bin deprecated in favour of git-history-as-archive.
- **Advantages over two-retro-consecutive-noise**: one noise event doesn't undo a high-signal history; decay-pressure surfaces genuinely stale entries even when they're never explicitly noised; the score is a single greppable integer in front-matter.

### Resolved Step 1.5 landing plan (post-user-answers)

1. **Front-matter shape** (Q2): each topic file entry gets a trailing HTML comment block:

   ```markdown
   - Entry text body goes here.
     <!-- signal-score: 2 | last-classified: 2026-04-22 | first-written: 2026-04-15 -->
   ```

   HTML comments render invisibly in markdown; `first-written` aids decay-vs-staleness debug story.

2. **Agent Step 1.5 classification loop** (Q1): silent policy-authorise per ADR-013 Rule 5. Agent:
   - Reads each topic file's entries + their current scores.
   - Applies ADR-026-grounded classification per entry: scans the session's tool-call history + reasoning; cites the tool invocation or paraphrase that makes the entry signal / noise / decay-only.
   - Updates each entry's score per Q3 rules (signal `+2`, noise `-1`, decay `-1`).
   - Applies threshold adjustments (promote to Critical Points / demote / route to delete queue).
   - Commits via ADR-014 + ADR-022 staging convention (governance-docs exclusion means no architect/JTBD gate for the retro's own writes).

3. **ADR-040 amendment** (precedent: ADR-032 carries multiple in-place amendments — P077, P084, P086, P075): add a "Curation feedback contract (P105)" subsection naming the signal-score + decay + thresholds + delete-queue contract.

4. **Bats coverage**: simulate one retro pass against a fixture `docs/briefing/` tree with three entries (high-signal / noise / decay-only); assert the score update + threshold → action mapping. Per ADR-037 contract-assertion pattern.

5. **Delete queue surfacing**: the ONE remaining `AskUserQuestion` in the whole flow. Step 1.5's final action is a single-call `AskUserQuestion` asking the user to confirm deletion for each entry whose score dropped `<= -3`. Empty queue → skip the prompt entirely; 1–4 options when the queue has entries (ADR-013 Rule 1 cap; > 4 queues sequentially). Preserves the "information-loss guard rail" without re-introducing per-entry user prompts for the 99% of retros where nothing is eligible for deletion.

This plan is now gated only on implementation, not on further design input. A subsequent iteration can land it.

### Fix Strategy

Investigation complete this session (2026-04-22 AFK iter 2). Implementation is gated on user resolution of Outstanding Design Questions Q1–Q3 above. Expected landing shape once Q1–Q3 are answered:

1. New run-retro Step 1.5 ("Briefing signal-vs-noise pass") between Step 1 and Step 2 — content shape per Q1 answer.
2. Persistence convention per Q2 answer — implemented as a content-shape rule in the SKILL.md and reflected in any briefing rendering tooling.
3. Delete lifecycle per Q3 answer — codified inside Step 1.5's adjustment-rules subsection.
4. ADR-040 inline amendment ("Curation feedback contract (P105)") naming the persistence format and the curation-feedback contract.
5. Bats coverage simulating one retro pass against a fixture briefing tree; assert classification → roll-up regeneration.

Effort remains M (single-skill change + single ADR amendment + one bats fixture). Follow-up iteration scope is bounded; no new ADR mint expected.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none — slice 2 of P100 must land first so the consumer surface exists, but P100 slice 2 does not literally block P105; P105 can be designed in parallel)
- **Composes with**: P100, ADR-040

## Related

- **P100 (`wr-retrospective` does not auto-surface `docs/BRIEFING.md`)** — parent. Slice 2 of P100 ships the SessionStart hook that reads Critical Points. P105 closes the curation-feedback gap that the hook's value depends on over time.
- **ADR-040 (Session-start briefing surface — directory + indexed README + helpfulness curation)** — the ADR authored during P100 slice 2 names helpfulness curation in its title as a future concern; P105 is that concern made actionable.
- **`docs/briefing/README.md`** — the Critical Points roll-up is the consumer-facing artefact this feedback loop curates.

## Fix Released

Deployed in `@windyroad/retrospective` via commit implementing:
- New Step 1.5 "Briefing signal-vs-noise pass (P105)" in `packages/retrospective/skills/run-retro/SKILL.md`
- ADR-040 inline amendment "Curation feedback contract (P105)" in `docs/decisions/040-session-start-briefing-surface.proposed.md`
- Bats contract-assertion test `packages/retrospective/skills/run-retro/test/run-retro-signal-vs-noise.bats`

Awaiting user verification.
