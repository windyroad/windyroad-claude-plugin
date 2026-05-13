# Problem 189: Agent invents "deferred" framing on tracked phases without user-deferral direction — projects fictional out-of-scope onto in-scope work

**Status**: Open
**Reported**: 2026-05-13
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Agent labels in-scope phases as "deferred by design" when no user-deferral direction exists — recurring class-of-behaviour at the ticket-body framing surface.

**Today's instance (2026-05-13)**: in response to *"has all the phases for user stories and users story maps from P170 been implemented? Anything deferred?"*, the agent (this conversation, post-context-clear) read P170's body — which contains the phrases *"Phase 3 implementation tasks (deferred)"* and *"Phase 4 implementation tasks (deferred — depends on Phase 2 ship + Phase 2.5 evidence)"* — and rendered them back to the user as **"Phase 3 (deferred by design)"** and **"Phase 4 (deferred by design)"**. User correction: *"release and then implement phase 3 and phase 4. I never deferred those phases."*

The agent had inferred a user-deferral that does not exist in the conversation history. The ticket's *"deferred"* annotation was authored by a prior agent session (likely the one that shipped Phase 2 SHIP at commit `eda6ea0` / `c00c82e`), not by user direction. The annotation has propagated through subsequent sessions as if it carried user-authority weight — and today the propagation hit the "summarize the ticket back to the user" surface and was named.

**Class signature**: agent reads ticket text containing "deferred" → projects user-deferral semantics onto the label → renders deferral back to user as established user-intent → user catches and corrects → cycle repeats next session because the underlying ticket text still carries the label.

**This is the framing-drift cousin of**:
- **P184** ("agent treats conditionally-deferred work as permanently out of scope — prematurely transitions parent ticket when X graduates") — P184 covers the conditional → unconditional projection at the lifecycle-transition surface. This ticket covers the same projection at the ticket-body-framing / response-to-user surface (one step earlier in the chain).
- **P179** ("agent defers requested work into untracked phases — phases are fine, but unticketed phases never get implemented") — P179 covers deferral-without-tracking. This ticket covers deferral-without-user-direction (the phases are tracked; the deferral framing itself is the fiction).
- **P185** ("`/wr-itil:capture-problem` Step 1.5 over-asks") fold-fix surfaced *derive-don't-ask* as a Step 1.5 invariant. This ticket extends the same invariant to *don't-invent-framing-the-user-didn't-give* — a sibling at the ticket-body-mutation surface.

**Why it persists**: every fix sites named in [[P184]] address the transition / treatment surface. None address the **authoring** surface — the moment an agent writes *"deferred"* into a ticket body without a user-deferral utterance to cite. The ticket text becomes self-reinforcing reality across sessions.

## Symptoms

- Tickets accumulate "Phase N (deferred)" / "Phase N implementation tasks (deferred)" / "explicitly deferred" annotations without corresponding user-direction quotes in the same ticket.
- Subsequent sessions render those annotations back to the user as established user-intent, propagating the fiction.
- Class-of-behaviour fires at minimum at: ticket-body authoring, summary-back-to-user, premature lifecycle transitions (P184), and AFK iter scope-decisions ("work is deferred so skip").
- Concrete reproductions: today's P170 Phase 3 + Phase 4 mischaracterization (`docs/problems/verifying/170-...md` lines 137-141); the 2026-05-12 P170 Phase 2 premature-Verifying transition reverted at the same commit chain (line 8 of the ticket).

## Workaround

- User catches the mischaracterization on response and corrects ("I never deferred those phases").
- Current session re-opens the ticket (transition Verifying → Known Error mirroring the Phase-2 reversion mechanism) + strips the "deferred" framing from in-scope phase blocks.
- Cycle does not generalize: next session reads the (now-stripped) ticket fresh, but if any new phase gets a "deferred" annotation without user direction, the pattern recurs.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — primary: user (cost of repeated correction across sessions); secondary: every multi-phase ticket that survives across sessions (P170 is canonical; P159 / P168 / P051 / P169 candidates).
- **Frequency**: (deferred to investigation) — N≥3 known instances in 2 days (P170 Phase 2 reversion 2026-05-12; P170 Phase 3 mischaracterization 2026-05-13; sibling P184 captured 2026-05-12 for the transition surface). Likely higher base rate hidden in tickets where the user hasn't yet asked "anything deferred?".
- **Severity**: (deferred to investigation) — likely Moderate; not blocking ship, but compounds scope-shrinkage across sessions if uncaught.
- **Analytics**: (deferred to investigation) — sweep `docs/problems/` for `"deferred"` occurrences NOT immediately followed by a user-direction quote within ±10 lines.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Audit `docs/problems/` for `"deferred"` annotations lacking proximate user-direction citations; quantify fictional-deferral surface area
- [ ] Identify the authoring surface(s) where "deferred" annotations get written without user-direction citations (ticket-body edits during manage-problem / capture-problem / work-problems iter loops / agent-driven retros)
- [ ] Determine whether the fix is (a) a hook gate on ticket-body writes that contain "deferred" without a nearby user-quote citation, (b) a SKILL.md derive-don't-invent invariant similar to P185's Step 1.5 derive-first refactor, or (c) both
- [ ] Composition assessment with P184 (transition surface) + P179 (untracked-phase deferral) + P185 (derive-don't-ask Step 1.5) — single class with three sites, or three distinct fixes?

## Dependencies

- **Blocks**: (none directly — but compounds with [[P184]] every recurrence)
- **Blocked by**: (none)
- **Composes with**: [[P184]] (transition-surface sibling), [[P179]] (untracked-phase-defer sibling), [[P185]] (derive-don't-ask Step 1.5 invariant), [[P170]] (today's concrete victim — Phase 3 + Phase 4 mischaracterization triggered this capture), [[P178]] (architect-PASS as RCA substitute — same orchestrator-shortcut family), [[P132]] (agents over-ask in interactive sessions — inverse surface; this ticket is "agents over-assert in ticket-body authoring").

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P184** (`docs/problems/open/184-agent-treats-conditionally-deferred-work-as-permanently-out-of-scope.md`) — closest sibling. Today's near-duplicate-check surfaced P184 (title contains "deferred"); the capture proceeded because P184 covers transition-surface projection while this ticket covers authoring-surface invention — distinct cure sites despite shared class.
- **P179** (`docs/problems/open/179-agent-defers-requested-work-into-untracked-phases.md`) — phases-tracked-but-fictional-deferral cousin.
- **P185** (`docs/problems/verifying/185-...md`) — derive-don't-ask Step 1.5 invariant; extends naturally to derive-don't-invent at the ticket-body authoring surface.
- **P170** (`docs/problems/verifying/170-...md`) — the ticket whose "Phase 3 / Phase 4 deferred" annotations triggered today's mischaracterization; this session re-opens P170 Known Error to ship Phase 3 + Phase 4 per user direction.
- **CLAUDE.md** — `MANDATORY — capture on correction` (P078) triggered this capture.
- **User direction recorded 2026-05-13**: *"release and then implement phase 3 and phase 4. I never deferred those phases."*
