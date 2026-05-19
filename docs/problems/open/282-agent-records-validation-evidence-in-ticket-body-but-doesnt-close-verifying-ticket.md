# Problem 282: Agent records validation evidence in ticket body but doesn't close verifying ticket — V→Closed transition skipped when validation lands inline

**Status**: Open
**Reported**: 2026-05-19
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

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

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- Concrete instance: `voder-mcp-hub` P027 (`docs/problems/verifying/027-bank-feed-needs-search-api-llm-paginates-poorly.verifying.md`) — body contains "End-to-end validation of P018" + "Fix direction (per user, 2026-05-19)" sections; status `verifying`; agent did not transition.
- P068 — narrower close-on-evidence ticket for `/wr-retrospective:run-retro` (sibling, NOT duplicate).
- P228 — K→V analogue; sibling missing-transition class.
- ADR-022 — Verification Pending state machine.
- `feedback_verify_from_own_observation.md` — user-memory grounding.
- `packages/itil/skills/transition-problem/SKILL.md` — canonical transition surface; likely amendment target.
- `packages/itil/skills/manage-problem/SKILL.md` Step 4 update path — likely amendment target.
- `packages/retrospective/skills/run-retro/SKILL.md` Step 4a — composes with this; P068's fix may overlap.
