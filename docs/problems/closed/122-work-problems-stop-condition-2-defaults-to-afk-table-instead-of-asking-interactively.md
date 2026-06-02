# Problem 122: `/wr-itil:work-problems` stop-condition #2 defaults to the AFK Outstanding Design Questions table when AskUserQuestion is available — interactive users get no questions

**Status**: Closed
**Reported**: 2026-04-26
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost Certain (5)
**Effort**: M — extended `packages/itil/skills/work-problems/SKILL.md` Step 2.5 routing so the default branch calls `AskUserQuestion` when available; Outstanding Design Questions table is the AskUserQuestion-unavailable fallback. The legacy "default for this skill is non-interactive" prose was replaced with the architect-FLAG cross-skill principle ("orchestrator main turns default to AskUserQuestion when available; AFK persona served by subprocess-boundary contract under ADR-032, not by suppressing AskUserQuestion at the orchestrator layer"). Step 6.5 Decisions Table row updated to match. New behavioural bats `work-problems-step-2-5-routing.bats` (8 doc-lint contract assertions per ADR-037) pins the new contract. Cross-skill helper `lib/runtime-mode.sh` deferred per architect verdict — the iter subprocess's AFK contract is enforced at the prompt-template layer (Step 5 Constraint #3), not by stop-condition #2's branch.
**WSJF**: (15 × 1.0) / 2 = **7.5**

## Fix Released

Released 2026-04-26 (interactive iter following the design-question round that exposed the bug). Pending `@windyroad/itil` patch publish via `.changeset/wr-itil-p122-step-2-5-interactive-default.md`. Changes:

- `packages/itil/skills/work-problems/SKILL.md` Step 2.5 prose flipped: AskUserQuestion is the default branch; table emit is the explicit fallback when AskUserQuestion is unavailable.
- Cross-skill principle paragraph added (architect FLAG): "orchestrator main turns default to AskUserQuestion when available; AFK persona is served by the subprocess-boundary contract under ADR-032, not by suppressing AskUserQuestion at the orchestrator layer." This makes the principle discoverable for future AFK orchestrators without requiring the shared-helper code that the original ticket scope anticipated.
- Step 6.5 Decisions Table row for "Stop-condition #2 with user-answerable skip-reasons" rewritten to match the flipped default + cite ADR-013 Rule 1 + P122.
- `packages/itil/skills/work-problems/test/work-problems-step-2-5-routing.bats` (NEW, 8 doc-lint contract assertions per ADR-037 Permitted Exception): SKILL.md exists; legacy "default for this skill" prose removed at Step 2.5; "Default branch" prose present; subprocess-boundary principle present; user-answerable skip-reason scoping preserved (P103 anti-pattern boundary); 4-question batching cap preserved; table-fallback-when-unavailable preserved; Decisions Table row names AskUserQuestion as default. 8/8 green; full project bats green.

Verification path: invoke `/wr-itil:work-problems` interactively against a backlog with at least one user-answerable design question that triggers stop-condition #2; confirm `AskUserQuestion` fires (not the deferred Outstanding Design Questions table). Awaiting user verification on the next interactive AFK loop that hits stop-condition #2.

P103 anti-pattern boundary verified preserved: AskUserQuestion still scoped to `user-answerable` skip-reasons only (test 5 pins `user-answerable` term in the SKILL.md prose); `architect-design` and `upstream-blocked` continue to skip without asking.

Out-of-scope-but-noted: shared `lib/runtime-mode.sh` helper (architect verdict — deferred; iter subprocess AFK contract handled by Step 5 prompt template). Cross-skill rollout to other AFK orchestrators (none exist today; the principle prose makes future adopters discoverable).

> Surfaced 2026-04-26 by direct user correction at the end of the 2026-04-25 AFK `/wr-itil:work-problems` loop's iter 3 stop. The orchestrator (Opus 4.7 main turn, with `AskUserQuestion` available in its tool surface) hit stop-condition #2 with 12 well-defined design questions across 5 skipped tickets (P079 ×6, P080 ×2, P082 ×1, P115 ×2, P117 ×1) and emitted them as a deferred Outstanding Design Questions table. The user verbatim correction: *"this was a really good example of where there are many outstanding design questions, but nothing was asked"* (P078 strong-signal token: ironic "really good example" framing + direct contradiction "nothing was asked").

## Description

`packages/itil/skills/work-problems/SKILL.md` Step 2.5 has both interactive and non-interactive branches for stop-condition #2 question surfacing. The branches are correctly defined; the **routing signal** is wrong. Step 2.5's prose says:

> JTBD-006's persona constraint ("autonomously work without needing interactive input") makes the non-interactive path the default for this skill — AskUserQuestion is the exception, not the rule.

The orchestrator (this session, on a freshly-invoked interactive turn) followed that default. AskUserQuestion was in the tool surface; the user was at the keyboard; 12 questions were enumerated and ready to ask. The orchestrator emitted the table anyway and stopped.

The **runtime** signal — is AskUserQuestion available? is the user demonstrably at the keyboard (their prompt arrived ≤ N minutes ago)? — should drive the branch. JTBD-006 is the **persona** for the AFK case but is not the **default routing signal** for every invocation. An interactive invocation of `/wr-itil:work-problems` is not an AFK invocation just because the skill is named that way; the user may be batch-running for autonomy OR may be supervising in-the-moment.

## Symptoms

- Interactive `/wr-itil:work-problems` invocation hits stop-condition #2 → orchestrator emits the table and exits → user reads the table and has to manually open follow-up tickets / interactive sessions to actually answer the questions.
- The user's typed prompt happens within seconds of the stop, demonstrating they are at the keyboard, but the orchestrator never asks.
- 2026-04-25 / 2026-04-26 session: 12 questions across 5 skipped tickets surfaced as a table; user correction within minutes invoking `/wr-itil:manage-problem` to capture this very ticket.
- Composes with P085 (verifying — "use AskUserQuestion when input is needed, never prose-ask"): both tickets are about the same anti-pattern — when input IS needed and AskUserQuestion IS available, USE it.
- Tensioned with P103 (verifying — "work-problems orchestrator escalates resolved release decisions via AskUserQuestion — defeats AFK"): the fix here MUST NOT broaden the AskUserQuestion surface to resolved-policy decisions. The skip-reason taxonomy from P053 already segregates `user-answerable` (ask) from `architect-design` and `upstream-blocked` (don't ask) — the fix uses the same boundary.

## Workaround

User manually invokes `/wr-itil:manage-problem`, `/wr-architect:create-adr`, or another design-conversation skill against each surfaced question, OR manually copies the table into a follow-up prompt. Both costs the user keystrokes + cognitive context-reload that the orchestrator was supposed to save.

## Impact Assessment

- **Who is affected**: every interactive user of `/wr-itil:work-problems` whose backlog contains tickets with user-answerable design questions. Empirically: every such user, every such session, since stop-condition #2's introduction (P053, 2026-04-19).
- **Frequency**: Almost Certain — fires whenever stop-condition #2 fires AND at least one skipped ticket carries a user-answerable design question. The 6.0-tier of the current backlog is dominated by such tickets (P079, P080, P115, P117 — 4 of the top 7).
- **Severity**: Moderate — productivity friction + cognitive context loss. The user spent ~$30 of session cost in the AFK loop, then the orchestrator stopped at the moment their input would have been most efficient (questions already enumerated, context already loaded). The user's correction language is durable (P078 strong-signal token).
- **Likelihood**: Almost Certain — observed every time the conditions fire on this session's evidence. The default-AFK routing rule guarantees the miss.
- **Analytics**: Direct user correction this session; structurally enforced by SKILL.md Step 2.5's "default for this skill" phrasing.

## Root Cause Analysis

### Structural

`packages/itil/skills/work-problems/SKILL.md` Step 2.5's interactive-vs-AFK routing has the right two branches but the wrong **default-selection rule**:

```
JTBD-006's persona constraint ("autonomously work without needing interactive input")
makes the non-interactive path the default for this skill
```

This conflates **persona** with **runtime mode**. JTBD-006 IS one persona served by this skill, but not the only one — the same skill is invoked interactively by JTBD-001 (governance enforcement during a hands-on session) and ad-hoc by JTBD-101 (plugin author validating their changes). The persona doesn't determine the runtime mode; the runtime detection does.

The correct routing signal is **runtime tool availability + recency-of-user-prompt**:

- If `AskUserQuestion` is in the orchestrator's tool surface AND the user's prompt arrived within ~N minutes (the session is demonstrably interactive) → call AskUserQuestion (batched, ≤4 questions per call, sequential calls if >4).
- If `AskUserQuestion` is NOT available (subprocess context, restricted permission mode) OR the user is genuinely AFK (long since last prompt, or explicit `--non-interactive` flag, or running under an AFK orchestrator wrapper) → emit the Outstanding Design Questions table.

### Detection-signal candidates

- **Tool surface check**: `AskUserQuestion` available in the orchestrator's surface — necessary but not sufficient (the AFK orchestrator HAS it but should still suppress in batch mode).
- **Explicit AFK marker**: an env var `WORK_PROBLEMS_AFK_MODE=1` or a CLI flag `--afk` that the user sets when invoking; absent → interactive default.
- **Recency-of-prompt heuristic**: the session's last user prompt timestamp (available via session context) — if recent (< X min), interactive; if old / no prompt at session start, AFK. Less reliable.
- **Subprocess-vs-main-turn distinction**: `claude -p` subprocess invocations are AFK by construction; main-turn invocations are interactive by construction. This maps cleanly to the existing P084 / ADR-032 subprocess-boundary pattern. **Likely the cleanest detection signal** — the iter subprocess workers always default to AFK; the orchestrator's main turn defaults to interactive.

### Cross-skill consistency note

The same default-AFK rule appears (or could appear) in other Step 2.5-class question-surfacing skills. The fix here should be a **shared helper** in `packages/itil/hooks/lib/detectors.sh` (or a new `lib/runtime-mode.sh`) that all skills can call, returning `interactive | afk` deterministically. Composes with P085's detector registry pattern.

### Investigation Tasks

- [ ] Confirm the cleanest runtime-detection signal among the four candidates above. Lean: subprocess-vs-main-turn (cleanly maps to ADR-032).
- [ ] Decide the SKILL.md Step 2.5 wording: interactive as default, AFK as explicit fallback OR balanced "detect runtime mode" wording with both branches as peers? Lean: "detect runtime mode" — neither branch is "the default" abstractly; the detection drives the choice.
- [ ] Decide whether the Outstanding Design Questions table is also emitted **alongside** an interactive AskUserQuestion call (table for the audit trail; questions for the immediate answer). Or interactive call answers populate the table after the fact. Lean: ask first, then surface the answers in the summary so the audit trail captures BOTH the questions and the user's verbal answers.
- [ ] Compose with P103 (verifying): the fix MUST NOT broaden AskUserQuestion to resolved-policy decisions. Confirm the skip-reason taxonomy boundary holds.
- [ ] Add behavioural bats: interactive default fires AskUserQuestion when ≥1 user-answerable question; AFK fallback emits table when subprocess-mode or `--afk` flag set; mixed-skip-reason scenarios (some user-answerable, some architect-design) only ask the user-answerable ones.
- [ ] Decide if a similar fix is needed in `packages/itil/skills/work-problems/SKILL.md` Step 4 architect-design skip-reason — when AskUserQuestion is available, COULD ask the architect-design questions too (escalating to architect agent if needed) rather than skip silently. Out of scope for this ticket; capture as P122-Part-B if scope warrants.

### Fix Strategy

**Shape**: Skill amendment + behavioural bats + (optional) shared runtime-mode helper.

**Target files**:
- `packages/itil/skills/work-problems/SKILL.md` — Step 2.5 routing rewrite + Step 4 classifier compatibility check.
- `packages/itil/hooks/lib/runtime-mode.sh` — NEW (or extend existing detector lib). Exports `is_interactive_runtime` returning `interactive` / `afk`. Detection: subprocess-vs-main-turn primary signal + `--afk` explicit override.
- `packages/itil/skills/work-problems/test/work-problems-step-2-5-routing.bats` — NEW. 6-8 behavioural assertions covering: interactive default fires AskUserQuestion on user-answerable questions; AFK explicit emits table; mixed taxonomy only asks user-answerable; ≤4-question cap; sequential calls when >4; subprocess-mode auto-AFK.
- `packages/itil/agents/test/runtime-mode.bats` — NEW. Helper unit tests covering the four detection candidates above.
- `.changeset/wr-itil-p122-*.md` — patch entry.

**Out of scope**: extending AskUserQuestion to architect-design or upstream-blocked skip-reasons (P122-Part-B if warranted). Cross-skill rollout to other AFK orchestrators (`/wr-itil:work-problem` singular, future cross-plugin orchestrators) — out of scope but the shared helper from this ticket makes that adoption trivial.

## Dependencies

- **Blocks**: (none directly — fix is bounded to work-problems Step 2.5)
- **Blocked by**: (none — composes orthogonally with P085 / P103 / P053)
- **Composes with**: P085 (verifying — assistant-side AskUserQuestion correctness; this ticket extends the same principle to the orchestrator-side stop-condition #2 surface), P103 (verifying — work-problems anti-pattern of asking resolved-policy decisions; this ticket's fix must respect the boundary by scoping to user-answerable questions only), P053 (closed — established the surface and skip-reason taxonomy this ticket consumes), P084 (closed — subprocess-vs-main-turn distinction is the proposed detection signal)

## Related

- **P053** (`docs/problems/053-work-problems-does-not-surface-outstanding-design-questions-at-stop.closed.md`) — established Step 2.5 surface, skip-reason taxonomy, and the interactive-vs-AFK branches. This ticket fixes the **routing signal** for those branches.
- **P085** (`docs/problems/085-assistant-asks-when-obvious-and-uses-prose-instead-of-askuserquestion.verifying.md`) — assistant-side rule: when input is needed AND AskUserQuestion is available, USE it (never prose-ask). This ticket extends the same principle to the orchestrator-side stop-condition #2 surface.
- **P103** (`docs/problems/103-work-problems-orchestrator-escalates-resolved-release-decisions-via-askuserquestion.verifying.md`) — opposite anti-pattern: don't ask resolved-policy questions. The fix here MUST stay within the user-answerable skip-reason boundary.
- **P078** (`docs/problems/078-assistant-does-not-offer-problem-ticket-on-user-correction.verifying.md`) — the trigger that surfaced this ticket. The user's correction matched the strong-signal vocabulary; this ticket is the captured-on-correction outcome (the user invoked `/wr-itil:manage-problem` directly rather than waiting for the OFFER, so the OFFER step was satisfied by the user-initiated capture).
- **P084** (`docs/problems/084-work-problems-iteration-worker-has-no-agent-tool-so-architect-jtbd-gates-block.closed.md`) — subprocess-vs-main-turn distinction (proposed detection signal here). The iteration-worker subprocess is AFK by construction; the orchestrator's main turn is interactive by construction. Maps cleanly.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 1 (route through AskUserQuestion) vs Rule 6 (fail-safe to non-interactive). This ticket's fix corrects the Step 2.5 default that currently skips Rule 1.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — subprocess-boundary variant defines the runtime mode boundary. The proposed detection signal aligns with this ADR's pattern.
- `packages/itil/skills/work-problems/SKILL.md` Step 2.5 — primary fix target.
- **JTBD-001** (Enforce Governance Without Slowing Down) — primary fit. The current default loses interactive users' time; the fix restores it.
- **JTBD-006** (Progress the Backlog While I'm Away) — composes (the AFK persona is preserved by the explicit-fallback branch; subprocess-mode auto-detection ensures iteration workers continue to suppress).
- **JTBD-101** (plugin-developer ad-hoc hands-on supervision) — composes; the same skill invocation in interactive mode now serves their session.
- 2026-04-26 session evidence: this ticket was filed in response to the verbatim user correction at iter 3 stop of the AFK `/wr-itil:work-problems` loop (12 user-answerable questions surfaced as table when AskUserQuestion was available). The session ran iter 1 (P120) + iter 2 (P121) + auto-apply + drain successfully; the failure mode is specifically the stop-condition #2 surface, not the iteration loop itself.
