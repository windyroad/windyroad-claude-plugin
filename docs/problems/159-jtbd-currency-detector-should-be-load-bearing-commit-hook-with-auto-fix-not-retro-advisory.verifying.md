# Problem 159: JTBD currency detector should be a load-bearing commit-hook with auto-fix, not a retro-time advisory; section structure should integrate organically not bolt on a `## Jobs to be Done` block

**Status**: Verification Pending
**Reported**: 2026-05-03
**Priority**: 12 (High) — Impact: Significant (4) x Likelihood: Possible (3)
**Effort**: L — new PreToolUse:Bash hook + auto-fix orchestration via wr-jtbd:agent + ADR-051 amendment + 12-plugin-README re-integration to weave JTBD content organically + behavioural bats covering hook block and auto-fix paths. Could grow to XL if the auto-fix orchestration requires a new shared library or new agent-tool primitives.

**WSJF**: (12 × 1.0) / 4 = **3.0**
**Type**: technical

## Fix Released

**Phase 1 shipped 2026-05-04** in `@windyroad/retrospective@0.17.0` (changeset `wr-retrospective-p159-readme-jtbd-currency-hook.md`). What ships: PreToolUse:Bash hook on `git commit` (`packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh`) that runs the existing detector against the project's `./packages/` + `./docs/jtbd/` and denies on `drift_instances > 0`; ADR-051 amendment with new Decision Driver "Load-bearing-from-the-start for drift class" + Recommended Section Structure rewrite (bolt-on `## Jobs to be Done` rejected; prose-weaving target guidance + persona-primacy preservation + anti-pattern citation added); 19 behavioural bats covering deny/allow/fail-open paths; JTBD-302 + JTBD-007 outcome refresh; 2 tactical bootstrap drift fixes (architect README `capture-adr` mention + itil README `capture-problem` mention). Detector signal post-commit: `TOTAL packages=12 with_jtbd=12 drift_instances=0`.

Phase 2-3 explicitly deferred per orchestrator framing: 12-README prose-weaving refresh + auto-fix orchestration via wr-jtbd:agent grant-Edit decision. P158 closed (retro Step 2b wiring survives as backup advisory). P161 filed for the broader drift-class-generalisation observation.

Awaiting user verification — exercise via:
1. Make a tactical drift in any plugin README (delete a JTBD citation or add a skill dir without README mention).
2. `git add` the change.
3. `git commit -m feat: test` — should be denied with "BLOCKED: P159 JTBD drift in <plugin> (...)".
4. Restore the README — commit allowed.

Verification gate (per ADR-022): user explicitly confirms working before close.

> Surfaced 2026-05-03 by user during pre-audit docs-currency sweep, immediately after the just-shipped retro wiring (`df47ad1` / `@windyroad/retrospective@0.16.0`). User correction (P078 capture-on-correction): *"the drift detector shouldn't be part of the retro. It should be something we are always running and fixing"*. Follow-up clarifications via AskUserQuestion: surface = `git commit` hook with detector running on the post-commit tree, **especially when the staged set does NOT touch README.md** (because that's the most common drift class — contributor added a skill/hook/agent and forgot to update the README); auto-fix = use the JTBD framing to inform existing prose, NOT bolt on a separate `## Jobs to be Done` section.

## Description

ADR-051 Phase 1 ships the JTBD currency detector as an exit-0-always advisory script invoked at retro time. P158 just shipped the wiring of that detector into `/wr-retrospective:run-retro` Step 2b. Both decisions are wrong relative to the user's design intent for drift detectors:

1. **Retro-time advisory is too late.** Retros run on user discretion; drift accumulates between retros at the rate of plugin-source change × the rate of README hand-refresh. The retro emits a one-line clean signal or a per-package code block — but the contributor who introduced the drift has already shipped the commit by the time retro fires.

2. **Per-edit gating on README files misses the actual drift class.** The most common drift mode is *contributor adds a skill/hook/agent and forgets to update the README*. The contributor's commit doesn't touch README.md at all — so a hook that only fires on README edits would never see the drift. The right surface is `git commit` (any commit), with the detector running on the post-commit tree regardless of which files were staged.

3. **Section-shaped auto-fix is wrong.** ADR-051's Recommended Section Structure clause (`## Jobs to be Done` heading + persona-grouped subsections) was applied to all 12 plugin READMEs in `8df1692` — the JTBD blocks were tacked on at the bottom as standalone tail sections. The user's framing rejects this shape: the JTBD framing should *inform* the existing What It Does / Skills / How It Works prose, not be a separate appendage. Auto-fix is therefore not a regex substitution — it's an agent-judgment surface where the wr-jtbd:agent reads the plugin's actual surface (skills, hooks, agents from `plugin.json` + skill bodies) and weaves JTBD-NNN citations into the existing prose where they fit naturally.

The detector itself doesn't need to change — it greps for `JTBD-\d{3}` citations *anywhere* in the README. Inline citations satisfy the rule the same as section-grouped ones. What needs to change is (a) the surface (commit-hook not retro-call), (b) the auto-fix shape (agent-driven prose-weaving not section-bolting), and (c) ADR-051's Recommended Section Structure clause that drove the wrong shape.

This composes with a broader pattern observation: the advisory-then-escalate trajectory (ADR-040 / ADR-013 Rule 6 / ADR-051 Phase 1 advisory → Phase 2 R6-gated → Phase 4+ load-bearing) may be the wrong default for *drift detectors* generally. Drift is mechanical and detectable per-commit; the gradualism makes sense for design questions and policy ADRs but not for "did you keep the docs in sync with the code". Sibling concern surfaced for a separate ticket if architect review confirms the generalisation.

## Symptoms

- The retro Step 2b wiring (`df47ad1`) only fires when the user explicitly runs `/wr-retrospective:run-retro`. Between retros, drift accumulates with no signal.
- The 12 plugin READMEs refreshed in `8df1692` carry a tacked-on `## Jobs to be Done` section at the bottom rather than weaving JTBD framing into existing prose. The framing reads like compliance theatre instead of audience-focused value description.
- The most common drift mode (contributor adds a skill/hook/agent without updating the README) cannot be caught by per-edit hooks on README.md alone — the offending commit doesn't touch README.md.
- ADR-051's Decision Outcome and Confirmation criterion 5 explicitly recommend the section structure that has now been observed to misframe value.
- ADR-051's Phase 1 → Phase 2 → Phase 4+ trajectory (advisory → R6-gated → load-bearing) defers load-bearing enforcement; the user's correction asserts load-bearing should be the default for drift class.

## Workaround

The retro wiring (P158, `df47ad1`, `@windyroad/retrospective@0.16.0`) is harmless as an after-the-fact backup advisory. It does not need to be reverted. Manual invocation of `wr-retrospective-check-readme-jtbd-currency` ad-hoc before commits is also a workaround until the hook lands.

## Impact Assessment

- **Who is affected**: the **plugin-user persona** (`docs/jtbd/plugin-user/JTBD-302`); every adopter reading any `@windyroad/*` plugin's README. Sibling impact on the **plugin-developer persona** ([JTBD-101](../jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md) — "clear patterns, not reverse-engineering" outcome is degraded when contributors must reverse-engineer runtime behaviour from prose-stale READMEs). Solo-developer / tech-lead impact through the broader R005 standing risk.
- **Frequency**: drift accumulates on every commit that touches `packages/<plugin>/*` source without also touching `packages/<plugin>/README.md`. In an active development cycle that's most commits.
- **Severity**: Significant (4) — README drift is the audit-day failure mode the user surfaced earlier this session. Scaffolded into R005 at Impact 4.
- **Likelihood**: Possible (3) — the retro wiring has shipped so first-degree drift will eventually surface at retro time; the per-commit gap remains, but is bounded by retro frequency.
- **Analytics**: detector evidence post-`8df1692`: `TOTAL packages=12 with_jtbd=12 drift_instances=1`. The 12 plugin READMEs all carry the bolted-on `## Jobs to be Done` shape (12-of-12); the retro wiring catches drift but does not catch *misshapen* JTBD blocks the way the user wants.

## Root Cause Analysis

### Preliminary Hypothesis

ADR-051's Phase 1 design treated JTBD currency as a design-question-class concern (advisory-then-escalate), when in fact it is a drift-class concern (load-bearing-from-the-start). Drift detectors should be:

1. **Always-running** at the closest enforcement surface to the failure mode (here: `git commit`).
2. **Auto-fixing** where the fix is mechanical or agent-judgable (here: weaving JTBD content into existing prose via wr-jtbd:agent).
3. **Surface-agnostic** to whether the affected file is in the staged set (here: detect from the post-commit tree).

The Recommended Section Structure clause (`## Jobs to be Done` heading + persona-grouped subsections) optimised for detector-greppability and AI-agent-discoverability over audience-framing-quality. The user's framing rejects this trade-off.

### Investigation Tasks

- [ ] Architect review: confirm the load-bearing-from-the-start direction for drift detectors generally (not just this one). Surface as a separate ticket if confirmed.
- [ ] JTBD review: confirm the prose-weaving auto-fix shape against JTBD-302 / JTBD-007 / JTBD-101. The current sectioned shape was JTBD-approved at ADR-051 design time; the new shape needs explicit re-approval.
- [ ] ADR-051 amendment: revise Recommended Section Structure clause and Confirmation criterion 5 to reflect the new direction. Consider whether the amendment triggers a new ADR (supersession) or an in-place amendment.
- [ ] Design the PreToolUse:Bash hook on `git commit`: detector-on-post-commit-tree shape, block-and-redirect message, BYPASS env override consistent with `git-push-gate.sh` / changeset-discipline.
- [ ] Design the auto-fix orchestration: wr-jtbd:agent reads the plugin surface + persona/job files + existing README prose, produces an Edit instruction sequence, applies it, re-runs the detector to confirm `drift_instances=0`. Define the contract for "fix attempted but human still needs to review".
- [ ] Behavioural bats: cover the hook (drift-block / no-drift-pass / non-commit-bypass / BYPASS env / fail-open on non-git tree) and the auto-fix orchestration (mechanical-fix-passes / human-judgment-falls-through / re-run-confirms-zero).
- [ ] Re-integrate the 12 plugin READMEs: remove the standalone `## Jobs to be Done` sections and weave JTBD-NNN citations into the existing What It Does / Skills / How It Works prose where they fit. Per ADR-051 the JTBD-\d{3} regex still resolves; only the surface shape changes.
- [ ] Decide the lifecycle handling for P158 (verifying): the retro wiring is the wrong primary surface, but it ships as a useful backup advisory. Does P158 close on the basis of "retro wiring is no longer the primary surface but still exists" or does it transition back to known-error pending re-design? Architect call.

## Fix Strategy

Phase 1: ship the PreToolUse:Bash hook + auto-fix orchestration + ADR-051 amendment. Phase 2: re-integrate the 12 plugin READMEs (large content task — agent-driven, not regex). Phase 3: archive or close the retro wiring per the lifecycle decision in Investigation Tasks.

Detailed phasing pending architect/JTBD review.

## Dependencies

- **Blocks**: (none — this is the structural fix; future drift-detector-class tickets compose with it but don't strictly block on it)
- **Blocked by**: (none — Phase 1 detector + bin shim already shipped under P152; the wiring under P158 doesn't block this ticket because the new hook surface is independent of the retro wiring; ADR-051 amendment is part of this ticket's own scope)
- **Composes with**: P152 (parent — closed/verifying); P158 (verifying — retro wiring; this ticket supersedes the design direction); R005 (standing risk this ticket's fix mitigates more aggressively); P141 (sibling PreToolUse:Bash gate on git commit — changeset-discipline; same shape as proposed hook)

## Related

- [ADR-051](../decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md) — parent decision; **Recommended Section Structure** clause + **Confirmation criterion 5** both need amendment to reflect commit-hook-with-prose-weaving direction.
- [P152](152-no-pressure-or-nudge-for-documentation-currency.verifying.md) — parent-parent ticket; landed Phase 1 detector + bin shim + bats.
- [P158](158-adr-051-phase-1-detector-shipped-but-not-wired-into-retro-step-2b.verifying.md) — sibling; shipped the retro wiring this ticket supersedes as primary. Retro wiring stays as advisory backup.
- R005 — standing risk. Treatment text references Phase 2 escalation; this ticket is the load-bearing variant.
- [ADR-040](../decisions/040-session-start-briefing-surface.proposed.md) — declarative-first / advisory-then-escalate pattern. This ticket's design is the load-bearing-from-the-start variant for drift class.
- [ADR-042](../decisions/042-auto-apply-scorer-remediations-open-vocabulary.proposed.md) — auto-apply scorer remediations precedent for "auto-fix at gate time"; sibling shape.
- [ADR-013 Rule 5](../decisions/013-structured-user-interaction-for-governance-decisions.proposed.md) — policy-authorised silent-action precedent for the auto-fix path.
- [ADR-014](../decisions/014-governance-skills-commit-their-own-work.proposed.md) — single-commit grain; auto-fix should ride the same commit as the triggering one when feasible.
- [P141](141-changeset-discipline-as-pretooluse-bash-hook.verifying.md) — sibling PreToolUse:Bash gate on `git commit` for the changeset-discipline failure mode; same hook shape as proposed here.
- [JTBD-302](../jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md) — primary served job; currency contract enforced at every commit not just at retro.
- [JTBD-007](../jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md) — currency expansion served by load-bearing enforcement.
- [JTBD-101](../jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md) — composition driver; clear patterns for contributors.

**Sibling out-of-scope (separate ticket if architect confirms)**: revisit advisory-then-escalate as the default for drift-class detectors generally — pattern may be over-applied.

## Change Log

- 2026-05-03: Initial filing. Driven by user correction during pre-audit docs-currency sweep — *"the drift detector shouldn't be part of the retro. It should be something we are always running and fixing"*. Supersedes the design direction shipped in P158 (`df47ad1`). Captures the broader observation that drift detectors should be load-bearing-from-the-start, distinct from advisory-then-escalate's design-question gradualism (potential separate ticket pending architect confirmation).
