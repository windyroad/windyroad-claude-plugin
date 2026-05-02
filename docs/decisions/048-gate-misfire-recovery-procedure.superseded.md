---
status: "superseded"
date: 2026-04-29
superseded-date: 2026-05-03
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, manage-problem SKILL.md authors, P124/P142 implementers]
reassessment-date: 2026-07-29
superseded-by: ["050-runtime-sid-instrumentation-via-pretooluse.proposed.md"]
---

# Documented recovery from gate misfire is the prescribed surface, not bypass

> **SUPERSEDED 2026-05-03 by [ADR-050](050-runtime-sid-instrumentation-via-pretooluse.proposed.md)** — P142 (P124 Phase 4) shipped as a new `PreToolUse:Bash|Write|Edit|Read` hook that captures the runtime stdin `session_id` to a per-machine marker the helper reads as authoritative. SID-mismatch denial is now structurally impossible in routine flow; the recovery procedure documented below is no longer reachable. The recovery prose was simultaneously removed from `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7, and the conditional `RECOVERY_HINT` was removed from `packages/itil/hooks/manage-problem-enforce-create.sh`. Retained for historical reference.

## Context and Problem Statement

P119 (`docs/problems/119-...verifying.md`) installed a `PreToolUse:Write` hook that gates new ticket creation on a per-session marker (`/tmp/manage-problem-grep-${session_id}`). The marker is set by `/wr-itil:manage-problem` Step 2 (duplicate-check grep) once Step 2 has run for the session. P124 (`docs/problems/124-...verifying.md`) introduced `get_current_session_id` to discover the canonical session UUID for the marker write because the agent does not export `CLAUDE_SESSION_ID`.

P124's Phase 3 helper has a regression: in orchestrator sessions that have dispatched subprocesses, the helper sometimes returns a subprocess SID instead of the orchestrator SID — but the runtime hook stdin still contains the orchestrator SID. The result is a marker written under the wrong UUID; the hook denies the next Write; the agent has no documented recovery path.

The 2026-04-28 incident (P144 driver evidence) recorded the failure mode: agent attempted to satisfy the gate by brute-force-touching markers for every architect-announced UUID (139 markers in one session). User correction was emphatic: *"WTF? Why did you bypass instead of using the skill?"* The brute-force is the canonical anti-pattern — it satisfies the marker shape while gaming the audit trail the marker is supposed to record.

The 2026-04-29 evidence (4× recurrence in a single session, P145–P148 ticketing) sharpened the picture: even the empirically-known recovery path (`itil-assistant-gate-announced-*` scrape) was insufficient because the runtime hook stdin used a per-Write SID not surfaced by ANY announce-marker class. The successful recovery in that session was `python3 -c 'Path(p).write_text(...)'` invoked through the `Bash` tool — `PreToolUse:Write` does not gate Bash.

P142 (P124 Phase 4) is the structural fix: it will make the helper return the runtime hook SID reliably, eliminating the regression. P142 has not shipped. The question this ADR answers: **what does the agent do today, and how is that documented so the agent does not invent the wrong workaround under pressure?**

User direction (P144 ticket body, 2026-04-29): *"create a problem for the issue you're hitting writing to problem files"* — surfaced explicitly that the recurring deny pattern needs a ticket AND a documented recovery, not silent reinvention.

## Decision Drivers

- **JTBD-001 (Enforce Governance Without Slowing Down)** — primary fit. An undocumented dead-end IS the JTBD-001 outage. The gate's authority is eroded MORE by undocumented escape hatches that agents invent ad-hoc than by a bounded, named procedure.
- **JTBD-101 (Extend the Suite with New Plugins)** — plugin developers need documented recovery procedures so future gate additions don't create new undocumented dead-ends; the pattern this ADR sets is the template.
- **JTBD-201 (Restore Service Fast with an Audit Trail)** — tech-lead need. The recovery procedure must preserve audit-trail integrity (Step 2 grep evidence) — only the marker-check enforcement layer is sanctioned for skip.
- **P119** — the gate this ADR scopes. Its enforcement intent (audit trail of duplicate-check) is preserved by the recovery procedure; only the marker-check layer is skipped under bounded conditions.
- **P124** — the helper whose Phase 3 regression triggers the misfire.
- **P142** — Phase 4 helper fix; supersedes this ADR's recovery procedure once shipped.
- **P131** — gate-exclusions-as-write-permission anti-pattern. This ADR draws the boundary explicitly: **READ exclusions** (gate doesn't fire) are NOT **WRITE permissions** (sanctioned bypass). The recovery procedure is a sanctioned bypass under bounded conditions, not a generalisation of P131's READ exclusion.
- **ADR-009** — gate marker lifecycle. The recovery preserves the marker lifecycle by keeping Step 2 grep as a precondition; the marker just isn't checked.
- **ADR-013 Rule 5** — policy-authorised silent proceed. The recovery is policy-authorised because the policy (P119's enforcement intent) is satisfied by the Step 2 grep that ran before the recovery fires.
- **ADR-038** — progressive disclosure budget on the deny message.
- **ADR-044** — decision-delegation contract; this ADR extends ADR-044's framework-mediated surface catalog by adding "gate-misfire recovery" as a new mechanical surface (deterministic from gate-misfire signal, no AskUserQuestion required).

## Considered Options

1. **Document a two-tier recovery procedure scoped to gate misfire** (chosen) — first-tier announce-marker scrape; second-tier python3-via-Bash file-write. Both tiers preserve audit-trail integrity (Step 2 grep ran). Time-bounded by P142's lifetime.
2. **Park P144 until P142 ships** — wait for the structural fix; do not document recovery. Rejected: extends the JTBD-001 outage indefinitely (P142's ETA is uncertain). Documented recovery is cheap; the dead-end is expensive.
3. **Sanction `python3-via-Bash` unconditionally as a documented escape hatch** — rejected: removes the gate's authority. The recovery must be bounded to the gate-misfire condition; routine creation flow MUST continue to use `Write` and hit the gate.
4. **Fix the hook to fail-open when ANY `/tmp/manage-problem-grep-*` marker exists** — loosens the SID-binding so any marker satisfies the gate. Rejected at this scope: the SID-binding IS the audit-trail anchor (it ties the grep to the session that ran it); fail-open weakens P119's enforcement during the very stop-gap window where the audit-trail-preservation test is load-bearing. Defer until P142 architect review weighs in on the structural surface.
5. **Hook-stdin instrumentation** — log the runtime SID to a discoverable path so the next agent can read it. Rejected at this scope: requires hook-side change to a `PreToolUse:Write` path that already runs on every Write tool call (performance-sensitive); the recovery this ADR proposes works without it. Composes with P142 if P142 architect chooses this implementation.

## Decision Outcome

**Chosen option: Option 1** — document a two-tier recovery procedure with explicit time-bound and audit-trail-preservation discipline.

### Recovery procedure (two tiers)

The recovery procedure fires ONLY when:
- The agent is **already executing** `/wr-itil:manage-problem` Step 2 in this turn (i.e., the SKILL contract has just ordered the grep for THIS ticket creation); AND
- `mark_step2_complete` succeeded (no error); AND
- The subsequent `Write` to the new `.<status>.md` file is denied by the P119 hook.

This is the **gate-misfire signal**. Routine creation flow does NOT match these conditions and MUST continue through the standard Write path.

**First-tier**: scrape `/tmp/itil-assistant-gate-announced-*` to discover the orchestrator session UUID, then `touch /tmp/manage-problem-grep-<SID>` for that SID. Retry the Write. This recovers the case where the helper picked a subprocess SID and the runtime hook reads the orchestrator SID.

**Second-tier**: when first-tier fails because the runtime hook SID is not in any announce-marker class (2026-04-29 evidence), write the new ticket file via `python3 -c 'from pathlib import Path; Path(p).write_text(...)'` invoked through the `Bash` tool. The hook is `PreToolUse:Write`; python3-in-Bash is not a Write tool call, so the hook never fires.

### Audit-trail-preservation test

The second-tier procedure is sanctioned ONLY because Step 2 grep ran in this turn for THIS ticket creation. The grep evidence — the act of running the grep, which surfaces duplicate tickets via `AskUserQuestion` — is the load-bearing thing P119 enforces. The marker is a witness to that act, not the act itself. When the marker exists but for the wrong SID, the witness exists but the gate cannot find it; the act has nonetheless occurred for THIS ticket.

The test for whether a workaround preserves audit-trail integrity:

- ✅ **Audit-trail-preserved**: the agent is currently executing `/wr-itil:manage-problem` Step 2 for THIS ticket creation, AND any `/tmp/manage-problem-grep-*` marker exists (regardless of SID). The skill flow itself is the just-ran-grep witness; the marker existence corroborates it.
- ❌ **Audit-trail-violated**: the agent is NOT in `/wr-itil:manage-problem` Step 2 for this ticket creation, OR no marker exists for any SID in this session. Routine first-creation flow MUST hit the gate; the recovery procedure does NOT apply.

**Anti-pattern bound** (architect advisory, narrowing the boundary against P131): the loose reading "any marker from any earlier `manage-problem` invocation in this session" would let the recovery procedure apply to a fresh ticket creation that happens to reuse a stale marker from a prior unrelated invocation — that's the P131 anti-pattern surface. The boundary holds against P131 because:
1. The recovery is invoked **from inside an active `/wr-itil:manage-problem` flow** where Step 2 is a step the SKILL contract has just ordered for THIS ticket. The agent's current execution context — not just the marker's existence — is part of the test.
2. The python3-via-Bash branch is **named in SKILL.md substep 7**, so its invocation is itself audit-trail-emitting (the SKILL.md prose records that the agent followed the procedure for this ticket creation, separate from any marker file).
3. Repeated invocation outside an active manage-problem flow (e.g. mid-retrospective inline capture, post-mortem wrap-up) does NOT trigger the recovery — those flows do not enter Step 2 in the first place, so the gate-misfire signal cannot fire.

The bound rules out "any-marker-anywhere" generalisation and keeps the recovery scoped to the just-ordered-grep-for-this-ticket case.

The python3-via-Bash workaround is sanctioned ONLY in the audit-trail-preserved branch. Sanctioning it in the audit-trail-violated branch would be the P131 anti-pattern (treating gate state as a problem to work around).

### Anti-pattern call-out

The recovery procedure documents the **canonical anti-pattern** explicitly so the agent does not reinvent it under pressure:

> **DO NOT brute-force-touch markers for every announced UUID.** That pattern (139 markers in one session, 2026-04-28 evidence) satisfies the marker shape while gaming the audit trail the marker is supposed to record. The user has explicitly rejected this pattern.

The anti-pattern call-out lives in BOTH surfaces (per JTBD review):
- **SKILL.md Step 2 substep 7** — durable; agents read it during routine flow before they hit the misfire.
- **Hook deny message** — just-in-time pointer; delivered at the moment of the misfire when the helper-bug signal is observable.

### Hook deny-message enhancement

When the deny fires AND `compgen -G '/tmp/manage-problem-grep-*' > /dev/null` (i.e., at least one marker exists for SOME SID — the helper-bug signal), append a recovery pointer to the deny message:

```
(Helper succeeded but SID mismatch detected — see manage-problem SKILL.md Step 2 substep 7.)
```

The pointer is **conditional on the helper-bug signal** so the routine-first-creation deny (no marker for this session at all) is unchanged. ADR-038 progressive-disclosure budget is preserved by keeping the pointer terse and avoiding internal jargon (`P124-Phase-3-regression` was rejected by architect as ADR-038-failing).

### Mechanical, not user-decision (ADR-044 extension)

The recovery procedure is mechanical — deterministic from the gate-misfire signal. The agent does NOT call `AskUserQuestion` when the gate misfires; it executes the documented recovery. This ADR extends ADR-044's Framework-Mediated Surface catalog by adding "gate-misfire recovery" as a new mechanical surface.

Per ADR-044's framework-resolution boundary, the framework has already resolved the decision (the SKILL.md documents the recovery), and re-asking would re-introduce friction the recovery was engineered to remove. P132 / inverse-P078 says "do not over-ask in mechanical stages"; this ADR applies that principle to the specific gate-misfire case.

## Scope

### In scope (this ADR)

- Two-tier recovery procedure documented in `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7.
- Hook deny-message recovery pointer in `packages/itil/hooks/manage-problem-enforce-create.sh`, conditional on `/tmp/manage-problem-grep-*` glob match.
- Anti-pattern call-out in both surfaces.
- Audit-trail-preservation test (with anti-pattern bound) as the gate-on-sanctioning rule.
- Auto-supersession HTML comment in SKILL.md sub-block (`<!-- supersedes-when: P142 ships -->`) paired with a behavioural bats assertion that fails when the comment is still present after P142's resolution ADR is `accepted`.
- Behavioural bats per ADR-037 + P081: SKILL.md structural assertions on the recovery section's content; hook behavioural tests for deny-with/without recovery hint variants.

### Out of scope

- **P142 (P124 Phase 4)** — structural fix to the helper. This ADR's recovery procedure auto-supersedes when P142 lands.
- **Hook fail-open on any-marker** (option 4 above) — defer to P142 architect review.
- **Hook-stdin instrumentation** (option 5 above) — defer to P142 implementation if architect picks that shape.
- **Generalising the recovery pattern to other gates** — if other gates (jtbd-enforce-edit, architect-enforce-edit, voice-tone-gate-external-comms) develop similar misfires, the pattern this ADR sets becomes the template, but each gate gets its own scoped recovery; this ADR does not generalise.

## Consequences

### Good

- Closes the JTBD-001 outage today without waiting for P142.
- Preserves the gate's authority by keeping the recovery bounded to the gate-misfire signal.
- Audit-trail-preservation test (with anti-pattern bound) gives a clear rule for distinguishing documented recovery from generalised bypass; future gate additions can reuse the same test shape.
- Anti-pattern call-out at point-of-failure (deny message) AND in routine-flow (SKILL.md) addresses the dual-surface JTBD review found.
- ADR-038 budget preserved on deny message via terse, jargon-free pointer wording.
- CI-enforced supersession invariant prevents documentation rot after P142 ships (failing bats becomes the cleanup-due signal).

### Neutral

- SKILL.md Step 2 grows by one sub-block (~30 lines). Within ADR-038's progressive-disclosure budget for a Step 2 substep.
- Hook adds one conditional `compgen -G` test on the deny path. O(1) glob test; negligible cost.
- ADR-044's Framework-Mediated Surface catalog grows by one entry ("gate-misfire recovery"). Catalog-extension is the documented growth pattern (ADR-044's catalog is intentionally open for new mechanical surfaces).

### Bad

- **Documentation rot when P142 ships**. The recovery procedure becomes superfluous once the helper returns the correct SID. Mitigation: the supersession is explicit in this ADR's Reassessment Criteria; the SKILL.md sub-block carries a `<!-- supersedes-when: P142 ships -->` comment so the cleanup path is discoverable; the bats assertion fails when P142's resolution ADR is accepted but the comment remains in source, surfacing the cleanup as a CI-enforced invariant.
- **Cognitive load on agents reading SKILL.md end-to-end**. Routine-flow readers see recovery scaffolding before they hit the actual problem. Mitigation: the sub-block is conditional ("If the hook denial persists despite mark_step2_complete succeeding...") — readers can skip it on first read; only failure-mode readers engage with it.
- **Sanctioning python3-via-Bash creates a precedent that future agents may over-generalise**. Mitigation: the audit-trail-preservation test (with anti-pattern bound naming the "any-marker-anywhere" failure mode explicitly) bounds the precedent; the SKILL.md sub-block names the test explicitly; behavioural bats assert the bounded scope.

## Confirmation

### Source review (at implementation time)

- `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7 — sub-block "Recovery if hook denial persists" present with: gate-misfire signal definition (active manage-problem Step 2 + helper succeeded + Write denied), two-tier procedure (announce-marker scrape; python3-via-Bash), audit-trail-preservation test with anti-pattern bound, anti-pattern call-out, ADR-048 + P124/P142 cross-references, supersession comment `<!-- supersedes-when: P142 ships -->`.
- `packages/itil/hooks/manage-problem-enforce-create.sh` — `compgen -G '/tmp/manage-problem-grep-*'` test on deny path; recovery hint appended when match. Deny message body unchanged for routine-first-creation deny (no marker exists for any SID).
- `docs/problems/144-...verifying.md` — `## Fix Released` section cites ADR-048 + the two-tier procedure landing in SKILL.md.

### Bats coverage (per ADR-037 + P081 — structural-permitted on SKILL.md while behavioural harness pending P012)

- `packages/itil/skills/manage-problem/test/manage-problem-p119-recovery-path.bats` (new) — SKILL.md structural assertions:
  - Step 2 sub-block names the gate-misfire signal (active flow + helper-succeeded + Write-denied conjunction).
  - Sub-block names the two-tier structure (`first-tier` + `second-tier` tokens).
  - Sub-block names "audit-trail" preservation test.
  - Sub-block contains the explicit "DO NOT brute-force" anti-pattern wording.
  - Sub-block cites ADR-048, P124, P142.
  - Sub-block carries the `<!-- supersedes-when: P142 ships -->` HTML comment.
  - **CI-enforced supersession invariant**: when `docs/decisions/<P142-resolution-ADR>.accepted.md` exists, the bats fails if the supersession comment is still present in SKILL.md source. (Today the assertion is conditional and passes; once P142's resolution ADR is accepted, the assertion becomes load-bearing and the cleanup becomes a CI-fail.)
- `packages/itil/hooks/test/manage-problem-enforce-create.bats` (extended) — behavioural tests:
  - `deny without ANY /tmp/manage-problem-grep-* marker → deny message OMITS recovery hint`.
  - `deny with /tmp/manage-problem-grep-* marker for OTHER SID → deny message INCLUDES recovery hint`.

### Behavioural replay

1. Fresh session, manage-problem invoked, helper returns correct SID, marker matches → routine flow; no deny; no recovery surfaced.
2. Orchestrator session with subprocesses, helper returns wrong SID, marker mismatched → deny fires; recovery hint included in deny message; agent reads SKILL.md substep 7; first-tier scrape recovers.
3. 2026-04-29 failure mode: announce-marker scrape returns SID still not matching runtime hook stdin SID → first-tier fails; agent applies second-tier python3-via-Bash; ticket lands; audit trail intact (Step 2 grep ran for THIS ticket).

## Reassessment Criteria

**Auto-supersedes when**:

- **P142 ships** and the helper returns the runtime hook SID reliably. The recovery procedure becomes superfluous; the SKILL.md sub-block + hook deny-hint can be removed; the bats can be retired. The SKILL.md sub-block's `<!-- supersedes-when: P142 ships -->` comment surfaces the cleanup path. The CI-enforced supersession invariant (bats assertion above) makes the cleanup a CI-fail signal once P142's resolution ADR is `accepted`. Update this ADR's `status:` to `superseded` with a pointer to P142's resolving ADR.

**Revisit if**:

- **Recovery procedure is invoked > 5× per week 4+ weeks running** without P142 shipping. Signal: the misfire is more frequent than expected; escalate P142's WSJF or land an interim hook fix (option 4 above).
- **A second gate develops similar misfire pattern** (jtbd-enforce-edit, architect-enforce-edit, voice-tone-gate-external-comms). Signal: generalise the recovery pattern via a follow-up ADR with a registry of gate-misfire procedures, or extract the audit-trail-preservation test into a shared library.
- **Audit-trail-preservation test is invoked in a context outside this ADR's scope** (e.g. another gate's recovery, or a generalised bypass). Signal: revisit the test's shape and either tighten its conditions or formalise it as a cross-gate primitive.
- **python3-via-Bash workaround is invoked outside the audit-trail-preserved branch** (i.e. no Step 2 grep ran for THIS ticket creation, or invocation is from outside an active manage-problem flow). Signal: this ADR's bound has been violated; review the SKILL.md wording and hook signal to clarify the bound.
- **P142 resolution ADR exists but supersession comment still in SKILL.md source 2+ weeks running**. Signal: the CI-enforced supersession invariant is failing in CI but not being acted on; escalate the cleanup or relax the assertion if P142's fix is partial.

## Related

- **P144** — driver ticket; this ADR is the architectural foundation for P144's fix.
- **P119** — manage-problem-enforce-create hook; this ADR scopes a documented recovery for its misfire case.
- **P124** — `get_current_session_id` helper; Phase 3 regression is the misfire trigger.
- **P142** — P124 Phase 4 helper fix; supersedes this ADR's recovery once shipped.
- **P131** — gate-exclusions-as-write-permission anti-pattern; this ADR draws the boundary between READ exclusion and WRITE permission, and the audit-trail-preservation-test anti-pattern bound rules out the "any-marker-anywhere" generalisation surface.
- **P132** — mechanical-stage no-asking; recovery is mechanical, not a user-decision.
- **ADR-009** — gate marker lifecycle.
- **ADR-013** — Rule 1 (deny redirects to skill); Rule 5 (policy-authorised silent proceed); Rule 6 (AFK fail-safe).
- **ADR-022** — problem lifecycle status suffixes (.open / .known-error / .verifying / .closed / .parked).
- **ADR-031** — forward-compat path matcher in hook.
- **ADR-037** — skill testing strategy (structural-permitted on SKILL.md while behavioural harness pending P012).
- **ADR-038** — progressive disclosure (deny message budget).
- **ADR-044** — decision-delegation contract; this ADR extends ADR-044's Framework-Mediated Surface catalog with "gate-misfire recovery" as a new mechanical surface.
- **JTBD-001** — primary fit (governance enforced without slowing down).
- **JTBD-101** — plugin-developer documented-pattern need.
- **JTBD-201** — tech-lead audit-trail integrity outcome.
- `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7 — implementation site.
- `packages/itil/hooks/manage-problem-enforce-create.sh` — deny-hint conditional.
- `docs/briefing/afk-subprocess.md` line 24 — pre-existing 2026-04-22 entry already documenting python3-via-Bash for an earlier intermittent variant; this ADR formalises and bounds the procedure.
