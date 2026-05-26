# Problem 308: work-problems Step 6.5 cohort-graduation treats evaluator `status=resolved` as graduate-now, skipping the Rule 4 evidence-floor judgment the holding-README Process requires — AFK false-graduation hazard

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

The cohort-graduation evaluator (`packages/risk-scorer/scripts/evaluate-graduation.sh`) implements ONLY the deterministic Rule 1a ticket-join + Rule 2 VP carve-out + Rule 3b cohort grouping. Its own header (lines 19–22) states explicitly:

> It does NOT compute release-risk and does NOT apply Rule 4 evidence-floor judgement — those are LLM-judgement surfaces owned by the wr-risk-scorer:pipeline agent.

So the evaluator's `status=resolved` means only *"the ticket-join succeeded and the entry is not VP-blocked"* — it is **necessary but not sufficient** for graduation.

But `/wr-itil:work-problems` Step 6.5 cohort-graduation pre-check treats `status=resolved` as a **direct graduate-now trigger**: *"`status=resolved` — graduate. Per ADR-061 Rule 5 + ADR-013 Rule 5, this is policy-authorised silent proceed (no `AskUserQuestion`)."* There is no intervening Rule 4 evidence-floor check in the SKILL prose. The holding-README Process (`docs/changesets-holding/README.md` step 5, line 22) DOES name the evidence floor as a precondition (*"when a held changeset's class-specific evidence floor (ADR-061 Rule 4) has been met AND … → `resolved` → auto-graduate"*) — but the SKILL Step 6.5 prose omits it, so a literal reading silently graduates on the join-only verdict.

**Concrete evidence 2026-05-26**: during a `/wr-itil:work-problems` within-appetite drain, the evaluator emitted `status=resolved` for all 3 held entries:

```
GRADUATION_CANDIDATE: changeset=p288-jtbd-persona-oversight.md | ticket=P288 | priority=9 | class=3a | status=resolved
GRADUATION_CANDIDATE: changeset=p248-effort-tally-core.md | ticket=P248 | priority=6 | class=3a | status=resolved
GRADUATION_CANDIDATE: changeset=p166-p163-external-comms-hook-side-sha256.md | ticket=P163 | priority=6 | class=3a | status=resolved
```

…yet the holding-README's authoritative per-entry evidence notes document all 3 as NOT graduation-ready:
- **p288** — P288 still open; README line 37 (dated 2026-05-26, today): *"sibling `p288-jtbd-persona-oversight.md` stays held (its jtbd-nudge has no clean session-trail evidence yet)."*
- **p248** — P248 still open; reinstate criterion is *"the full P248 build is complete"*, but the build has remaining slices (capture-problem estimate fields, work-problems per-iter append, calibration artifact, retro RMS step, historical backfill).
- **p166-p163** — P166 still `verifying`; hold stays *"until the root cause is fixed AND evidence shows the gate runs clean"*; no positive evidence recorded (negative-evidence driver was P198, now closed, but no clean-gate evidence captured since).

An AFK orchestrator following Step 6.5 literally would have **silently graduated + released all 3 not-evidence-ready features** (incl. p288 which today's README explicitly holds, and p248 whose build is incomplete). This was caught only because the orchestrator was interactive and read the holding-README before acting — an AFK loop would not have.

Candidate fix directions:
1. Step 6.5 must run the **Rule 4 evidence-floor judgment** (delegate to `wr-risk-scorer:pipeline`, or parse the holding-README per-entry evidence note) BEFORE treating `status=resolved` as graduate. The SKILL prose should name this precondition explicitly (it's only in the holding-README Process today).
2. Extend the evaluator to surface README evidence-note state (e.g. detect `Current evidence: NEGATIVE` / `stays held` markers) and emit a `status=evidence-not-met` verdict so the join-only verdict can't be mistaken for graduate-ready.
3. Tighten Step 6.5 to route evidence-unmet/unverified entries to **skip** (preserve hold), not graduate.

## Symptoms

(deferred to investigation)

## Workaround

Orchestrator manually reads `docs/changesets-holding/README.md` per-entry evidence notes and overrides the evaluator's `status=resolved` when the Rule 4 evidence floor is documented as unmet (what happened in the 2026-05-26 session — released P177 only, preserved the 3 holds).

## Impact Assessment

- **Who is affected**: maintainers running `/wr-itil:work-problems` AFK loops with non-empty `docs/changesets-holding/`.
- **Frequency**: fires on every within-appetite drain where held entries' tickets have closed/joined but their evidence floor is unmet — structurally recurring.
- **Severity**: false-graduation ships not-evidence-ready (deliberately-held) features to npm adopters silently in AFK mode; defeats the entire dogfood-graduation safety mechanism (ADR-061). High latent severity; bounded here only by interactive catch.
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Confirm the SKILL-vs-README contract gap (Step 6.5 prose omits the Rule 4 precondition the holding-README Process line 22 names)
- [ ] Decide the fix locus (Step 6.5 prose + orchestrator evidence-judgment vs evaluator emitting an evidence-aware status)
- [ ] Create reproduction test (behavioural — held entry whose ticket is closed but whose README note says NEGATIVE evidence must NOT graduate)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P246 (cohort-graduation pre-check this gap lives in), P162 (dogfood graduation criteria driver)

## Related

- **ADR-061** — dogfood graduation criteria; Rule 4 evidence floor (the skipped check), Rule 5 graduation, Rule 1a join (what the evaluator actually does).
- **P246** — Step 6.5 cohort-graduation pre-check (the surface with the gap).
- **P162** — codify dogfood graduation criteria driver ticket.
- `packages/risk-scorer/scripts/evaluate-graduation.sh` — lines 19–22 disclaim Rule 4 evidence-floor judgment.
- `docs/changesets-holding/README.md` line 22 — the Process step that DOES name the evidence-floor precondition the SKILL prose omits.
- Captured via /wr-itil:capture-problem; expand at next investigation.
