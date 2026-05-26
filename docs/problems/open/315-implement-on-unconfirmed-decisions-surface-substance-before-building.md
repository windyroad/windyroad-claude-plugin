# Problem 315: Agent implements dependent work on genuine new decisions before human-confirming their SUBSTANCE — surfaces only meta-questions

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 8 (Medium) — Impact: 4 x Likelihood: 2 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

When the agent records a genuine new decision (a choice among ≥2 viable options that the framework cannot resolve) and then builds dependent work on it, it confirms only the **meta-question** (e.g. "one ADR or two?") with the user — not the **load-bearing substance** of the decision (the actual choice). The substance rides unconfirmed until a post-hoc `/wr-architect:review-decisions` drain, by which point dependent artifacts have already been built on it. If the drain then rejects the decision, the dependent work was built on sand.

**Concrete instance (this session, 2026-05-26):** implementing ADR-070/071 via RFC-006, the agent extracted RFC-005's F1/F4 into **ADR-072** (fix-time gate placement = `Open → Known Error`) + **ADR-073** (hard-block RFC-less dispatch). It surfaced ONE `AskUserQuestion` — the *grain* ("one ADR or two?") — and treated the decisions' *substance* as architect-resolved (a faithful extraction of RFC-005 F1/F4). It then built dependent work on them: the RFC-005 retrofit references them, ADR-060's new **I13** invariant encodes both, and RFC-006's slices shipped. Both were born `proposed` without an oversight marker (per the architect's "born-proposed, drain later" guidance for the marker) — but the agent conflated "don't born-confirm the marker" with "OK to implement before confirmation."

At the post-hoc review-decisions drain, the user **rejected both** (ADR-072's placement was built on a wrong Known Error model; ADR-073's hard-block should be auto-create) — so I13 + the RFC-005 retrofit had been written against an incorrect gate design (rework: P314). User frustration (verbatim): *"I'm a bit frustrated that you didn't get my confirmation on those ADRs before you implemented them."*

The correct shape: a genuinely-contested decision the framework can't resolve must have its **substance** human-confirmed BEFORE dependent work is built on it (the way ADR-070/071 were directly ratified via AskUserQuestion at decision time) — not deferred to a post-hoc drain, and not substituted by confirming only a meta/grain question.

## Symptoms

- An `AskUserQuestion` surfaces a decision's framing/grain (e.g. ADR count, file split) but not the substantive choice it records.
- Dependent artifacts (other ADRs, RFC slices, invariants, code) are built on a born-`proposed` decision before any human confirms its substance.
- The post-hoc review-decisions drain is the FIRST time the human sees the substantive choice — and a rejection there means dependent work must be reworked.

## Workaround

When extracting/recording a genuine decision (≥2 viable options, framework can't resolve), surface its SUBSTANCE via AskUserQuestion before building on it. The architect's Needs-Direction verdict (ADR-064) should name the substantive choice, and the main agent should confirm THAT (not just the grain) before dependent work proceeds.

## Impact Assessment

- **Who is affected**: any multi-artifact implementation that extracts/records new decisions and builds on them in the same pass.
- **Frequency**: the "born-proposed + implement, drain later" pattern is the documented ADR-066 flow, so this can recur whenever genuine decisions are recorded mid-implementation.
- **Severity**: Moderate-to-significant — built-on-sand rework when the drain rejects (this session: I13 + RFC-005 retrofit + RFC-006 slices against a wrong gate design).

## Confirmed design (2026-05-27 — user-ratified via AskUserQuestion)

The contract substance was human-confirmed BEFORE any artifact was built — dogfooding the fix on its own fix. Architect returned a Needs-Direction verdict naming three encoding options; the user confirmed **Option A** via `AskUserQuestion`.

- **The contract (ADR-074):** for a genuine choice among ≥2 viable options the framework cannot resolve (ADR-044 cat-1), the **substantive chosen option** must be human-confirmed via `AskUserQuestion` **before any dependent work is built on it**. Confirming a meta/grain question (e.g. "one ADR or two?") does NOT satisfy this. "Decision recorded" (born-`proposed` marker OK per ADR-066) is distinct from "decision built upon" (needs substance-confirm first).
- **Enforcement surface 1 — architect-verdict layer:** thin amend to ADR-064 — Needs-Direction must name the *substantive* choice, not a grain question; "confirm before recording" is not satisfied by a meta question alone.
- **Enforcement surface 2 — process guard:** at the `/wr-itil:work-problems` + `/wr-itil:manage-problem` propose-fix (ADR-060 I13) surface — check whether the fix builds on a born-`proposed` decision whose substance is unconfirmed; if so, surface via `AskUserQuestion` (interactive) or queue to `outstanding_questions` (AFK) before dependent work lands. **NOT** a PreToolUse hook (semantic judgment → would over-fire).
- **ADR-066 carve-out:** the born-`proposed` marker covers recording, not implementation licence.
- **ADR-044 composition:** the substance-confirm-before-build ask is cat-1 and is EXCLUDED from the lazy-AskUserQuestion regression metric; trigger is narrow (only when a ≥2-option decision is about to be BUILT ON) — never obvious/single-option/pinned (inverse-P078 / P132 guard).

## Fix Strategy

**Kind**: improve — **Shape**: ADR + amendments + skill process-guard.

- **Design layer — DONE 2026-05-27 (this session, committed):** ADR-074 created born-`human-oversight: confirmed`; ADR-064 amended (grain-vs-substance clause at Shape B + translation contract); ADR-066 carve-out clause (marker ≠ implementation licence). Architect Needs-Direction + user AskUserQuestion confirm; JTBD PASS.
- **Implementation layer — DONE 2026-05-27 via RFC-008 (rides an RFC traced to this problem per ADR-071):** built the propose-fix process guard in `/wr-itil:manage-problem` (T3) + `/wr-itil:work-problems` (T4) at the ADR-060 I13 surface, using the new `wr-architect-is-decision-unconfirmed` predicate (T5, ADR-049 PATH shim — adopter-safe per P317); sharpened the `wr-architect:agent` Needs-Direction prompt to name substance not grain (T1); added the ADR-044 lazy-count exclusion in run-retro Step 2d + `check-ask-hygiene.sh` (T2). Testable surfaces (T1/T2/T5) behavioural-GREEN; T3/T4 skill-flow assertions deferred to the P176 harness (structural-permitted per ADR-052 Surface 2). Remaining: RFC-008 lifecycle transition + release via `/wr-itil:manage-rfc`. **This problem is fix-complete pending release** — close to Verifying when RFC-008 releases.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [x] Decide the contract: substance must be human-confirmed before dependent work; born-`proposed` is fine for the MARKER only. → **ADR-074** (decided + confirmed 2026-05-27).
- [x] Where does the contract live: new ADR + thin amend ADR-064 + carve-out ADR-066, enforced at architect-verdict layer + propose-fix/I13 process guard. → **Option A confirmed** via AskUserQuestion 2026-05-27.
- [x] Distinguish from lazy-AskUserQuestion (ADR-044 Step 2d): recorded in ADR-074 as the cat-1 lazy-count exclusion + narrow build-on trigger (inverse-P078 guard).

## Dependencies

- **Composes with**: ADR-064 (architect Needs-Direction + main-agent AskUserQuestion ownership), ADR-066 (oversight marker + review-decisions drain — born-proposed-then-drain), ADR-044 (decision-delegation taxonomy; this is the under-ask inverse of the lazy-count metric), P310 (RFC-decision blind spot), P283 (oversight drain origin).
- **Blocks / drove**: P314 (the gate-design rework that resulted from building on the rejected ADR-072/073).

## Related

- **ADR-072 / ADR-073** — the built-on-then-rejected decisions (this session's instance).
- **P314** — the rework caused by this failure mode.
- captured via /wr-architect:review-decisions Reject path + P078 capture-on-correction, 2026-05-26.

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| RFC-008 | proposed | Confirm-substance-before-build enforcement (ADR-074 mechanical layer) |
