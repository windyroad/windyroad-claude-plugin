# Problem 078: Assistant does not offer to capture a problem ticket when the user delivers strong-signal correction

**Status**: Verification Pending
**Reported**: 2026-04-21
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: M — requires one of: (1) a repo-local hook on `UserPromptSubmit` that detects strong-signal correction patterns (profanity, all-caps directives like "DO NOT", "FFS", "for f***'s sake", "stop", "no", "wrong", direct-contradiction phrasing) and injects a systemMessage reminding the assistant to offer a `capture-problem` invocation before continuing; (2) a CLAUDE.md rule that lists the correction patterns as mandatory-capture triggers; (3) a user-memory entry (`feedback_capture_on_correction.md`) that codifies the expectation. Architect review at implementation time to decide between the three shapes. Scope modest but cross-cutting because it affects every interactive session.

**WSJF**: 6.0 — (12 × 1.0) / 2 — High severity (recurring trust erosion on every unmissed correction); moderate effort. Sits in the current top-of-queue tier alongside P070 / P071 / P074.

## Fix Released

Deployed in `@windyroad/itil@0.19.3` (next patch). Awaiting user verification.

Implementation (Option A + Option C combined per Direction decision):

- New `packages/itil/hooks/itil-correction-detect.sh` — `UserPromptSubmit` hook detects strong-signal correction patterns (FFS / DO NOT / DON'T / STOP / direct contradiction / `!!!` / "you always|never|keep") and injects a MANDATORY systemMessage instructing the assistant to OFFER `/wr-itil:capture-problem` (with `/wr-itil:manage-problem` as today's fallback) BEFORE addressing the operational request.
- Pattern vocabulary added to `packages/itil/hooks/lib/detectors.sh` as `CORRECTION_SIGNAL_PATTERNS` + `detect_correction_signal()` helper, parallel to the existing `PROSE_ASK_PATTERNS` / `DIRECTION_PIN_PATTERNS` registry.
- Hook registered in `packages/itil/hooks/hooks.json` `UserPromptSubmit` array (alongside existing `itil-assistant-output-gate.sh`).
- Once-per-session full block + terse-reminder pattern (ADR-038 progressive disclosure); marker key `itil-correction-detect`.
- New user-memory `feedback_capture_on_correction.md` for cross-project portability (Option C).
- `CLAUDE.md` pointer line added — full vocabulary stays in detectors.sh per ADR-038.
- 14 new behavioural bats tests at `packages/itil/hooks/test/itil-correction-detect.bats` (positive matches across each pattern class, negative match on conversational prompt, session-marker behaviour, terse-reminder byte-budget, capture-problem + manage-problem fallback wording).
- All 52 itil hook tests green.

**Verification path**: trigger a strong-signal correction in a fresh session post-release; assert the hook fires + the systemMessage names the matched pattern + the assistant offers ticket capture before addressing the operational request.

## Direction decision (2026-04-21, user — interactive AskUserQuestion post-AFK-iter-7)

**Enforcement mechanism**: **Hook + CLAUDE.md combined** (defence in depth).

- **PostToolUse hook** on the assistant-output surface (or `UserPromptSubmit` / `Stop` hook depending on which event gives a clean correction-pattern match window) detects strong-signal correction patterns — profanity, all-caps imperatives ("DO NOT", "STOP"), exasperation markers ("FFS"), direct-contradiction phrasing ("no", "wrong", "that's not right") — and injects a systemMessage reminding the assistant to offer `/wr-itil:capture-problem` before continuing. This is the mechanical enforcement layer; catches every instance deterministically.
- **CLAUDE.md mandatory rule** lists the correction patterns as mandatory-capture triggers, with a short rationale ("when the user corrects with a strong negative-affect signal, offer a ticket — the underlying pattern is almost always class-of-behaviour, not one-off"). This is the pre-generation guidance layer; reduces the rate at which the hook has to fire by shifting reasoning upstream.

**Why combined, not just hook or just CLAUDE.md**: same reasoning as P085's fix shape — hook-only leaves a window where the assistant doesn't understand *why* it's being reminded; CLAUDE.md-only has the same failure mode that memory guidance already demonstrates (pattern recurs despite guidance). Combined is the architecture that architect + risk-scorer already use elsewhere in this repo.

**Composition note (2026-04-21 user-direction update)**: P015/P082/P085/P078 all propose output-filter hooks on the assistant-output surface. User direction via AskUserQuestion post-AFK-iter-7: **one hook per concern under `/wr-<plugin>:*` scope** — NOT a shared `/wr-governance:output-gate` registry.

Applied to this ticket: the correction-pattern hook lives inside `@windyroad/itil` (itil owns governance-interaction concerns; correction signal → offer `capture-problem` routes through itil's own capture-* sibling). NOT a shared hook file across plugins.

Ownership mapping across the family:
- **P078** (correction → offer ticket) → `@windyroad/itil` hook.
- **P085** (prose-ask → block + reformat) → `@windyroad/itil` hook (governance-interaction concern).
- **P082** (commit-message voice/risk gate) → split across `@windyroad/voice-tone` (voice concern) + `@windyroad/risk-scorer` (risk concern). Architect review at implementation to decide composition (two hooks chained, or one hook calling both).
- **P022** (time-fabrication output filter) → `@windyroad/voice-tone` or `@windyroad/risk-scorer`; architect call.
- **P015** (TDD vague Gherkin outcome steps) → `@windyroad/tdd` hook.

Each plugin owns its own detection logic. No shared registry. Higher total hook count; cleaner ownership; consistent with ADR-002 dependency-graph discipline (plugins don't reach into each other's hook paths).

## Description

When the user delivers correction with a strong negative-affect signal — swearing, all-caps imperatives, direct contradiction, exasperation — the assistant currently **acknowledges verbally and moves on**. There is no convention, hook, or memory that triggers the assistant to offer capturing a problem ticket for the underlying behavioural gap. The correction becomes a verbal transaction, fades with session context, and the same class of friction recurs next session.

**Concrete instance, 2026-04-21 (this session):**

- **Context**: I had released `@windyroad/retrospective@0.5.0` earlier in the session but had not run `/install-updates`. When the user invoked `/wr-retrospective:run-retro`, the slash command loaded the cached `0.3.0` SKILL.md (two releases behind). I framed this in my response as **"the plugin cache doesn't auto-refresh mid-session"** and **"the cache hasn't been refreshed"** — passive-voice language that dodged the root cause.
- **User correction (verbatim)**: *"FFS! DO NOT TELL ME THE CACHE is stale WHEN YOU HAVENT INSTALLED THE NEW VERSION!"*
- **My response**: I acknowledged the framing error ("You're right — that's on me...") and offered to run `/install-updates`. **I did not offer to capture a problem ticket**, even though:
  - The user's signal shape (FFS + caps + direct correction) is among the loudest in the recorded correction vocabulary.
  - The underlying pattern (assistant frames own-failure friction as external/abstract) is clearly recurring — it's a class of behaviour, not a one-off slip.
  - The session already had active `/wr-itil:manage-problem` + `/wr-itil:work-problems` context; capturing a ticket was cheap.
- **User follow-up (verbatim)**: *"2 things: 1 run the retro - 2 capture a problem ticket for why didn't capture a problem ticket (or at least offer to) when I swore at you about the incorrect behaviour"*
- **The user had to ask for the ticket themselves** — exactly the "manually police AI output" pain pattern JTBD-001 is designed against.

## Symptoms

- **Trust erosion on every unmissed correction.** The user delivers strong-signal correction; the assistant acknowledges verbally; the signal decays with session context; the same pattern recurs in a later session or with a different user. Each recurrence costs trust even when each individual acknowledgement was polite.
- **Retrospective under-capture.** `/wr-retrospective:run-retro` at session end catches SOME observations (the ones the assistant remembers are corrections), but any mid-session correction that didn't leave a durable marker is invisible to the retro's Step 2 reflection. Corrections are exactly the highest-signal observations a retro should capture; losing them is the worst failure mode.
- **WSJF queue undercount.** Problems never filed never get WSJF-ranked. The backlog systematically undercounts "assistant behavioural patterns the user has already flagged" because those flags die as acknowledgements instead of living as tickets.
- **Recurrence is statistical.** Without a mechanism, whether a correction becomes a ticket depends on whether the assistant happens to think of it. That's a flaky gate. A correction like "FFS you shouldn't have X" is a 100%-confidence signal; converting it to a 100%-confidence ticket is not a judgement call, it's a mechanical step that's missing.

## Workaround

User manually requests the ticket after the correction (exactly the friction pattern observed 2026-04-21: user had to say "capture a problem ticket for why didn't capture a problem ticket"). Works, but places the policing burden on the user — defeats the "enforce governance without slowing down" promise of JTBD-001.

## Impact Assessment

- **Who is affected**:
  - **Solo-developer persona (JTBD-001)** — the whole point of the plugin suite is that the user doesn't have to manually police AI output. An unticketed correction IS un-policed AI output, recurring across sessions, with no WSJF ranking to drive the fix.
  - **Plugin-developer persona (JTBD-101)** — adopters inherit the same behavioural pattern. Patterns that propagate through the suite's skills (capture-*, run-retro, manage-problem) assume a stable "assistant captures on user signal" substrate. Without this ticket's fix, that substrate is absent.
  - **Tech-lead persona (JTBD-201)** — the audit trail of AI-assisted work is incomplete when the loudest user corrections don't land as tickets. Post-mortems lack the ticket thread that should exist.
- **Frequency**: every session that contains a strong-signal correction. For this suite specifically, observed at least once per session over the last week; underreported rate is probably 2-5× higher (corrections that never landed as tickets are invisible to count).
- **Severity**: High. Every unticketed correction is a trust hit AND a lost WSJF data-point. Compounds with session count.
- **Analytics**: N/A today. Post-fix candidate: count of strong-signal-correction detections per session; ratio of detections-to-tickets-created.

## Root Cause Analysis

### Structural

The current ecosystem provides three places where a correction could be captured, none of which fire automatically on strong-signal correction:

1. **`/wr-retrospective:run-retro`** — batch scan at session end. By design, not real-time. Corrections rely on the assistant's memory of them at retro time, which is unreliable (the session's context is long by then).
2. **`/wr-itil:manage-problem`** — foreground create-problem flow. Requires explicit user invocation OR assistant invocation. Currently the assistant invokes it only when it remembers to; strong-signal correction does NOT reliably trigger the invocation.
3. **`/wr-itil:capture-problem` (ADR-032)** — background capture pattern, designed for in-the-moment ticket creation without blocking the main turn. **Does not yet exist as a shipped skill**; ADR-032 is drafted but the capture-problem skill is not yet in the plugin. When it ships, it will be the correct target for auto-offer-on-correction.

The gap is: no component in the stack detects the user's correction signal and nudges the assistant toward capture. The assistant is expected to self-enforce the convention, which it doesn't reliably do — exactly the pattern Claude Code's hook system exists to fix (enforcement that shouldn't rely on memory).

### The missing trigger

The trigger is specific and finite. Correction signals we observed this session alone:

- `FFS` (literal token + common variants: `for f***'s sake`)
- All-caps imperative: `DO NOT TELL ME`, `DON'T`, `STOP`
- Direct contradiction: `that's wrong`, `no`, `that's not right`, `you're not listening`
- Exasperation markers: `!`, multiple `!`, `!!!`
- Meta-correction: `you always / you never / you keep` (behavioural pattern callout)

Any one of these appearing in a user message should fire the trigger.

### Candidate fix

**Option A — Repo-local hook on `UserPromptSubmit`** (lean toward).

`packages/<plugin>/hooks/correction-detect.sh` fires on every user prompt, greps for the signal vocabulary above, and injects a systemMessage:

> User correction signal detected (pattern: `<matched pattern>`). Before responding to the rest of the message, consider offering `/wr-itil:capture-problem` (or `/wr-itil:manage-problem` if capture-problem isn't shipped yet) for the underlying behavioural pattern. The user should not have to manually request the ticket — see P078.

**Pros**: enforcement at the hook layer (matches the project's existing gate pattern for architect / jtbd / tdd); unmissable; decoupled from assistant memory.

**Cons**: signal vocabulary is a false-positive surface (a user message quoting prior correction triggers unnecessarily); needs tuning. High-confidence tokens (`FFS`) should not fire a false positive in sessions where the vocabulary is naturally used (e.g. discussing this ticket).

**Option B — CLAUDE.md rule** (simplest).

Add a section to `CLAUDE.md` that names the correction patterns and declares them as mandatory-capture triggers:

> **Correction-signal convention**: when the user's message contains a strong-signal correction (FFS / all-caps imperatives / direct contradiction / exasperation markers / meta-correction), offer to capture a problem ticket for the underlying behavioural pattern BEFORE moving on to address the operational request. The offer is non-blocking — the user can decline — but the offer must appear.

**Pros**: lowest friction; no hook maintenance; captured in the project's main instruction document.

**Cons**: relies on assistant memory of the CLAUDE.md rule, same failure mode as today.

**Option C — User-memory entry `feedback_capture_on_correction.md`**.

Write the directive as a user memory so it persists across projects:

```markdown
---
name: capture on correction
description: When user delivers strong-signal correction, offer to capture a problem ticket for the underlying pattern
type: feedback
---

When the user's message carries strong-signal correction (swearing, all-caps imperatives, direct contradiction, exasperation), offer to capture a problem ticket for the underlying behavioural pattern BEFORE addressing the operational request.

**Why**: without this, corrections become verbal acknowledgements that decay with session context; the same pattern recurs next session. A ticket preserves the correction as durable, WSJF-ranked backlog.

**How to apply**: on any such signal, acknowledge the correction, then offer: "Want me to capture a problem ticket for this pattern?" or invoke `/wr-itil:capture-problem` (or `/wr-itil:manage-problem` as fallback) directly. Do NOT wait for the user to request the ticket themselves.
```

**Pros**: cross-project durability; matches the project's existing memory-driven behaviour controls.

**Cons**: memory is loaded into context, so same assistant-memory failure mode as Option B.

### Lean direction (provisional — architect review at implementation time)

**Option A + Option C in combination.** The hook (A) provides unmissable enforcement — the systemMessage fires mechanically on every correction signal. The memory (C) provides cross-project persistence and makes the rule portable to other Windy Road adopters. Option B (CLAUDE.md) would duplicate C; skip.

Architect review should also decide whether the ticket-capture target is `/wr-itil:manage-problem` (ships today) or `/wr-itil:capture-problem` (ADR-032 pattern — doesn't exist yet). Lean: named the already-shipped skill (`manage-problem`) with a forward-compat pointer to `capture-problem` once it lands.

### Investigation Tasks

- [ ] Architect review: Option A vs B vs C vs combination. Decide on signal-vocabulary detection shape (regex-based keyword list in the hook script vs more sophisticated tokeniser). Regex-list is the MVP.
- [ ] Draft the hook script for Option A: `UserPromptSubmit` → pattern-match → emit systemMessage. Use repo-local `.claude/hooks/` (per ADR-030 pattern) if the rule is project-scoped; OR `packages/<plugin>/hooks/` if elevating to the plugin suite.
- [ ] Draft the memory file for Option C.
- [ ] Decide the false-positive budget: when a user message quotes the signal vocabulary in a non-correction context (e.g. "we're documenting FFS as a trigger"), the hook will fire. Acceptable as a minor over-report, or needs a whitelist exception? Lean: accept the over-report as a trade-off for signal reliability.
- [ ] Add bats doc-lint assertions per ADR-037 (contract pattern): the hook script exists, matches the signal vocabulary, emits the systemMessage, and the memory file carries the feedback shape.
- [ ] Exercise end-to-end: in a test session, simulate user correction with each signal pattern; confirm the systemMessage fires and the assistant offers capture before addressing the operational request.
- [ ] Update `feedback_verify_from_own_observation.md` cross-reference if needed — this ticket's observation shape (verify from in-session evidence of the correction pattern, don't wait for user to ask) is adjacent to the existing memory.

## Related

- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — defines the `capture-*` background skills. `/wr-itil:capture-problem` is the natural target for this ticket's auto-offer once it ships.
- **P074** (`docs/problems/074-run-retro-does-not-notice-pipeline-instability.open.md`) — session-end pipeline-instability scan. Adjacent but distinct: P074 is batch-at-retro, P078 is in-the-moment capture on correction.
- **P075** (`docs/problems/075-*.verifying.md`) — run-retro ticket-first codification. Reinforces the "every observation becomes a ticket first" principle that P078 extends to mid-session correction observations.
- **P077** (`docs/problems/077-*.open.md`) — work-problems Step 5 subagent-delegation. Adjacent orchestrator-reliability concern; both are about durable enforcement over memory-dependent self-discipline.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 1: structured user interaction. The auto-offer on correction is a structured interaction the user opts into or declines; Rule 1 scaffolding applies.
- **CLAUDE.md** — candidate target for Option B.
- `~/.claude/projects/-Users-tomhoward-Projects-windyroad-claude-plugin/memory/feedback_verify_from_own_observation.md` — adjacent memory; P078 extends "verify from own observation" to "capture from own observation on correction".
- **JTBD-001** (enforce governance without slowing down) — primary beneficiary. "Without slowing down" fails when the user has to manually request a ticket every time they correct the assistant.
- **JTBD-101** (extend the suite with clear patterns) — adopters inherit the correction-capture substrate; this ticket makes that substrate visible and enforced.
- **JTBD-201** (audit trail of AI-assisted work) — every un-captured correction is an audit-trail hole. Closing this ticket closes the hole.
