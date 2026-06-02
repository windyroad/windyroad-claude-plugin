# Problem 282: Agent records validation evidence in ticket body but doesn't close verifying ticket — V→Closed transition skipped when validation lands inline

**Status**: Verification Pending
**Reported**: 2026-05-19
**Priority**: 12 (High) — Impact: 3 (Moderate — Verification Queue accumulates effectively-closed tickets; audit-trail decoupled from validation-work record; cross-ticket lifecycle reasoning degraded) x Likelihood: 4 (Almost Certain — affects every session where any agent edits a `.verifying.md` body to add Fix Direction / Validation Note / Confirmation Log content; pattern observable in this very session — 94 verifying tickets and growing)
**Effort**: M — define evidence-keyword vocabulary + add body-content scan to `/wr-itil:transition-problem` SKILL + optional PostToolUse hook on `.verifying.md` Edit; architect verdict on trigger surface (SKILL vs hook vs hybrid)
**WSJF**: 6.0 — (12 × 1.0) / 2 — corrected 2026-05-23: invalid /3 divisor → M divisor 2 (was 4.0)

## Description

Class-of-behaviour problem captured 2026-05-19 from observation in adopter project `voder-mcp-hub`:

- Ticket: `docs/problems/verifying/027-bank-feed-needs-search-api-llm-paginates-poorly.verifying.md`
- Status: **Verification Pending** (`.verifying.md` suffix)
- Ticket body content (observable in image):
  - A `## Description` section documenting the original bug (LLM paginated incorrectly when answering "did they pay").
  - A `**META-RECURSIVE VALIDATION**:` note INSIDE the body: *"After self-diagnosing, the LLM invoked `voder_record_feedback` openly: 'I'm going to flag this to the Voder team as a friction signal so they can look at why it slipped through.' P018's openness mandate fired exactly as designed; the feedback tool captured this exact failure mode while it was happening."* — labelled **End-to-end validation of P018.**
  - A `### Fix direction (per user, 2026-05-19)` section enumerating the chosen fix shape (Server-side search API in `@voder/skript`) for THIS ticket (P027).

What the agent did:
- Recorded the validation event of a DIFFERENT ticket (P018) inline in P027's body.
- Recorded fix direction for THIS ticket (P027) inline in its body.
- LEFT P027 in `verifying` state — did not transition it.

What the user expected (per the capture-problem args):
- The agent should have CLOSED P027 (the user said: *"P027 records the validation of P018, yet P027 remains 'verifying'. The agent should have closed it"*).

**Ambiguity in the user's framing — two plausible expected-behaviour readings, both pointing at the same agent-behaviour class**:

1. **Reading A — closure derivable from cross-ticket validation evidence**: P027 itself is in `verifying`, and its body documents validation work on a related ticket (P018). The user's framing suggests the agent should infer "if I'm doing validation work that demonstrates the openness mandate is firing AND the fix-direction for this ticket is settled with the user, the verifying-state work is effectively complete; transition the ticket to closed".
2. **Reading B — body-content-evidence trigger general case**: when ANY agent edits a `.verifying.md` ticket body to record substantive evidence (validation observation, fix-direction settlement, successful test run, in-session confirmation), the agent should detect "the body now contains close-justifying evidence" and offer/perform the V→Closed transition.

Either reading captures the same defect: agents write durable evidence INTO ticket bodies but don't pair that with the corresponding lifecycle transition. The ticket-state-machine and the ticket-body-content stay decoupled in agent behaviour despite carrying conjugate semantic load.

**Sibling tickets** (NOT duplicates):

- **P068** (verifying, but actually about THIS exact class for /wr-retrospective:run-retro specifically) — *"run-retro does not close .verifying.md tickets that have been observed as verified in the session"*. P068 narrows the gap to the session-wrap moment; P282 broadens it to "any agent edit that records close-justifying evidence in a verifying ticket's body".
- **P228** (open) — K→V transition not happening at release time. P282 is the V→C analogue: a missing-transition class one step further down the state-machine.
- **Feedback memory `feedback_verify_from_own_observation.md`**: *"When asked which Fix Released tickets to close, verify from my own in-session observations instead of deferring everything to the user."* The same user-feedback principle scaled from "asked which to close" to "edited a verifying ticket's body".

## Symptoms

(deferred to investigation)

- Verification Queue accumulates tickets whose bodies contain validation evidence, fix-direction acceptance, or successful-test-run records — but whose status is still `verifying`.
- Agents edit `.verifying.md` ticket bodies to add evidence sections (Fix direction (per user, ...), Validation note, Confirmation log) without considering the lifecycle implication.
- Adopter projects (e.g. voder-mcp-hub) show the same pattern — the issue is in the shared SKILL surfaces (manage-problem Step 4 update path, transition-problem, work-problems iteration loops) not in any single project's local config.
- The agent's mental model treats ticket body and ticket status as orthogonal axes; the user's mental model treats them as semantically yoked (if the body documents closure-justifying work, the status should reflect that).
- **Prior-session `yes — observed` rows never auto-close (2026-05-26 evidence).** The README Verification Queue `Likely verified?` column (P186) is the durable evidence signal — a ticket verified across subsequent sessions carries `yes — observed: <citations>`. But NO automatic surface consumes that column to close the ticket: run-retro Step 4a (step 8 same-session exclusion) and manage-problem Step 9d both scan the *current* session's activity for evidence. A ticket verified in a *prior* session — its evidence already on disk in the README column AND its body Change Log — is structurally invisible to both close surfaces forever, because the evidence is not in any later session's tool-call history. Closure then only happens when a human manually asks (as it did 2026-05-26).

## Workaround

(deferred to investigation)

Plausible workarounds pending diagnosis:

- **User-side**: explicitly invoke `/wr-itil:transition-problem` after every body edit that adds close-justifying content.
- **Agent-side checklist**: before completing any `.verifying.md` body edit, scan the new content for evidence-of-validation phrasings (e.g. *"End-to-end validation of"*, *"fix direction (per user, ...)"*, *"confirmed in session"*, *"successfully exercised"*) and offer the V→Closed transition.
- **Hook-side trigger**: a PostToolUse hook on Edit of `.verifying.md` could detect "evidence keywords added" + offer transition; risk: false-positive rate on housekeeping edits (typo fixes, formatting).
- **SKILL-side**: extend `/wr-itil:manage-problem` body-edit path and `/wr-itil:transition-problem` to do a body-content scan before exiting.

## Impact Assessment

- **Who is affected**: (deferred to investigation)
  - Solo-developer persona — Verification Queue noise; tickets sit in `verifying` after their evidence is already on disk.
  - Tech-lead persona — audit trail of ticket lifecycle decoupled from audit trail of validation work; cross-ticket reasoning (e.g. P018 validated via P027) doesn't surface in the lifecycle index.
  - AFK orchestrators — same as P068; verifying queue stays full of effectively-closed work.
- **Frequency**: (deferred to investigation) — likely per-session for any session that edits `.verifying.md` bodies, which is most non-trivial sessions.
- **Severity**: (deferred to investigation) — Medium pending diagnosis; recoverable via `/wr-itil:transition-problem` invocation after the fact, but the user-friction of having to remember-to-prompt is itself a friction class.
- **Analytics**: (deferred to investigation) — count of `.verifying.md` tickets whose body Last-Modified-Date is older than N days yet whose status is still verifying, OR whose body contains evidence-keywords without a paired closure event.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Reconcile scope vs P068: is P282 a SUPERSET, or are P068 and P282 distinct surfaces (run-retro vs general agent-edit path)? Architect verdict on whether to merge or keep separate
- [ ] Define the evidence-keyword vocabulary that should trigger the V→Closed offer (likely `End-to-end validation`, `validated`, `confirmed in session`, `Fix direction (per user`, `successfully exercised`, etc.)
- [ ] Decide trigger surface: SKILL contract amendment vs PostToolUse hook vs both — architect verdict
- [ ] Implement chosen trigger with behavioural test fixture (a `.verifying.md` ticket edited with evidence content; assert V→Closed transition fires OR is offered)
- [ ] Investigate the adjacent K→V analogue per P228 — same trigger-shape (body-content scan) applies to fix-released detection
- [ ] Consider whether `/wr-retrospective:run-retro` Step 4a (the verification-queue close pass) should ALSO do the body-content scan as a session-wrap belt-and-braces check
- [ ] **Add a prior-session-evidence close surface (2026-05-26).** Step 4a's same-session exclusion (step 8) correctly prevents a session verifying its own fix, but it ALSO permanently excludes rows whose `Likely verified?` README column already reads `yes — observed: …` from a prior session — those never get picked up by any later Step 4a run. Design a surface (Step 4a addendum, Step 9d addendum, or a dedicated review pass) that scans the README `Likely verified?` column for pre-existing `yes — observed` rows and surfaces/closes them independent of current-session activity. Same-session exclusion stays; prior-session-recorded `yes — observed` becomes its own close trigger.
- [ ] Create reproduction fixture (a `.verifying.md` ticket; agent edits it to add a Fix direction section; assert agent offers V→Closed transition)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — investigation can begin immediately)
- **Composes with**:
  - **P068** (run-retro doesn't close verifying tickets — narrower surface of same class)
  - **P228** (K→V transition not happening at release time — sibling missing-transition class)
  - **ADR-022** (Verification Pending state machine — the transition this ticket is about)
  - **`/wr-itil:transition-problem` SKILL** — the canonical transition surface; likely needs the body-content scan
  - **`/wr-itil:manage-problem` SKILL** Step 4 update path — likely needs the body-content scan when edits land on `.verifying.md`
  - **feedback_verify_from_own_observation.md** — user-memory grounding for the agent-should-verify-from-own-observations principle scaled to ticket body content

## Fix Released

Shipped 2026-05-30 (`/wr-itil:work-problems` AFK orchestrator session 8 iter 6; pending `@windyroad/retrospective` patch — orchestrator owns release cadence per its constraints). Fold-fix Open → Verification Pending per ADR-022 P143 amendment (root cause documented inline; fix strategy named the trigger-surface architect verdict; effort matched the M bucket; workaround documented).

**Architect verdict** (PASS, this session): no new ADR required. The trigger-surface choice (SKILL extension vs PostToolUse hook vs hybrid vs Step 4a addendum drain) is implementation grain inside the envelope of ADR-022 (Verification Pending lifecycle) + ADR-014 (governance commits its own work) + ADR-074 (substance-confirm-before-build trip-wire DOES NOT FIRE because the semantic substance — "body-content evidence on a `.verifying.md` should yoke to V→Closed" — is already pinned by ADR-022 + `feedback_verify_from_own_observation.md`). All four candidate options (a/b/c/d) are within thin-extension territory; the choice is a category-1 implementation pick, not a load-bearing direction-setting decision.

**JTBD verdict** (PASS, this session): ranks **(c) > (d) > (a) > (b)**. Option (c) — Step 4a prior-session evidence drain — serves the solo-developer persona's manual-policing-AI-output constraint strongest because it consumes the README `Likely verified?` column's `yes — observed: <citations>` cell, which is **explicit durable on-disk evidence** (recorded by P186's evidence-first cell mechanism), not inference on a current edit. JTBD-006 honoured: prior-session-recorded evidence on disk is the safe-default signal, not a guess.

**Shape shipped (option (c))**: `packages/retrospective/skills/run-retro/SKILL.md` Step 4a gains **sub-step 9: Prior-session evidence drain (P282)** placed after sub-step 8's same-session exclusion. The drain reads `docs/problems/README.md`'s Verification Queue table, filters to rows whose `Likely verified?` cell begins with `yes — observed:`, preserves the same-session exclusion via `git log --since=<session-start>` rename detection, and dispatches `/wr-itil:transition-problem <NNN> close` per the existing sub-step 5-7 cross-plugin contract. Source distinction `(prior-session README cell)` rides the Decision column of the Step 5 Verification Candidates table so the user can audit drained-from-cell closures separately from current-session-evidence closures. Composition note documents the AFTER-ordering vs sub-steps 5-7. Recovery path inherited from sub-step 6 (`/wr-itil:transition-problem <NNN> known-error` flip-back) — closes are reversible.

**Test coverage**: `packages/retrospective/skills/run-retro/test/run-retro-step-4a-prior-session-evidence-drain.bats` — NEW. 12 assertions (11 structural per ADR-005 Permitted Exception + 1 behavioural fixture exercising the `yes — observed:` row-detection heuristic against a sample README VQ table) covering the drain stage's presence, README source, P186 cell-shape filter, same-session exclusion inheritance, /wr-itil:transition-problem dispatch, P135 R3 dispatch outcome contract, Decision-column source distinction, P135 R5 recovery path, AFTER-ordering composition, 2026-05-26 evidence citation, and explicit `**Closes P282**` ticket-link. Full run-retro suite: 150/150 green (was 138; +12 from new fixture).

**Out of scope (left for sibling tickets if next-session evidence shows insufficient)**:

- **Option (a)** — body-content scan in `/wr-itil:transition-problem` Step 4 pre-flight: within thin-extension territory per architect verdict but only fires on explicit user invocation; doesn't address the "agent doesn't invoke transition-problem" gap. Capture sibling ticket if needed.
- **Option (b)** — PostToolUse hook on `.verifying.md` Edit: within thin-extension per architect (must be advisory-only per ADR-045 hook budget) but carries false-positive risk on housekeeping edits (typo fixes, formatting); JTBD ranked weakest. Capture sibling ticket if needed.
- **K→V analogue per P228**: distinct sibling missing-transition class one step earlier in the state machine. Stays separate per architect verdict — fold would erase the surface distinction P282 itself preserved.
- **Body-content scan in `/wr-itil:manage-problem` Step 4 update path**: candidate (a)-equivalent at the manage-problem surface. Capture sibling ticket if needed.

**Awaiting user verification**: next `/wr-retrospective:run-retro` invocation, with `docs/problems/README.md` Verification Queue carrying ≥1 row whose `Likely verified?` cell begins with `yes — observed:` from a prior session, should surface the drain dispatching `/wr-itil:transition-problem <NNN> close` per row — the Step 5 Verification Candidates table records each drained close with Decision `closed via transition-problem (prior-session README cell)` and the cell's citation text inline. Concrete repro fixture: the 8 `yes — observed:` rows currently in this repo's README (P246, P250, P262, P266, P267, P283 plus this session's own additions) — sub-step 9 should drain those that are not in the current-session exclusion list.

**Recovery path** if the drain misfires: `/wr-itil:transition-problem <NNN> known-error` flips the wrongly-closed ticket back to known-error per ADR-022. Per-close reversibility is the design property that justifies silent dispatch per ADR-044.

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- Concrete instance: `voder-mcp-hub` P027 (`docs/problems/verifying/027-bank-feed-needs-search-api-llm-paginates-poorly.verifying.md`) — body contains "End-to-end validation of P018" + "Fix direction (per user, 2026-05-19)" sections; status `verifying`; agent did not transition.
- **2026-05-26 verifying-queue review session evidence (this repo).** User asked to review the verifying queue and close any closeable. Of 91 `verifying/` rows, 8 carried `yes — observed: …` in the README `Likely verified?` column — verified across prior sessions (4/5/6, multiple release cycles) — yet ALL 8 still sat in `verifying`. None had been auto-closed despite the durable recorded evidence; closure required the user to manually prompt. 3 were ripe (P132/P233/P234 — multi-session evidence, zero regression, author marked window met) and closed this session; 5 held for legitimate reasons (P246/P250 author "in-flight", P266 same-artefact, P262/P283 same-day same-session). Concrete accumulation cost: the README Verification Queue section reached **134 KB**, exceeding the Read-tool 25K-token whole-file cap — the queue could not be read in a single tool call, forcing persisted-output + paged reads. Confirms the Impact-line "Verification Queue accumulates effectively-closed tickets" with a measured readability failure, and motivates the prior-session-evidence close surface Investigation Task above.
- P068 — narrower close-on-evidence ticket for `/wr-retrospective:run-retro` (sibling, NOT duplicate).
- P228 — K→V analogue; sibling missing-transition class.
- ADR-022 — Verification Pending state machine.
- `feedback_verify_from_own_observation.md` — user-memory grounding.
- `packages/itil/skills/transition-problem/SKILL.md` — canonical transition surface; likely amendment target.
- `packages/itil/skills/manage-problem/SKILL.md` Step 4 update path — likely amendment target.
- `packages/retrospective/skills/run-retro/SKILL.md` Step 4a — composes with this; P068's fix may overlap.
