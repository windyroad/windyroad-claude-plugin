---
status: accepted
rfc-id: rfc-first-trace-invariant-not-enforced-at-fix-time
reported: 2026-05-17
decision-makers: [Tom Howard]
problems: [P251]
adrs: [ADR-071, ADR-072, ADR-073, ADR-070, ADR-060, ADR-051, ADR-052, ADR-042, ADR-044]
jtbd: [JTBD-008, JTBD-001, JTBD-006, JTBD-101]
stories: []
---

# RFC-005: RFC-first trace invariant not enforced at fix-time

**Status**: accepted
**Reported**: 2026-05-17
**Problems**: P251
**ADRs**: ADR-071 (unconditional RFC-first — the governing decision), ADR-072 (fix-time gate placement: Open→Known Error), ADR-073 (orchestrator dispatch hard-block), ADR-070 (RFCs hold no independent decisions — why this RFC carries none), ADR-060 (parent framework; I13 invariant added under RFC-006), ADR-051 (load-bearing structural hook), ADR-052 (behavioural-test coverage), ADR-042 (held-changeset graduation), ADR-044 (decision-delegation contract)
**JTBD**: JTBD-008 (primary — decompose-fix-into-coordinated-changes), JTBD-001 (governance composition), JTBD-006 (AFK orchestrator throughput), JTBD-101 (atomic-fix-adopter — friction guard now the thin-RFC path per ADR-071)

> **Retrofitted 2026-05-26 under RFC-006 (ADR-070).** This RFC originally carried its own decisions (facets F1–F7) inline, plus a "Considered Options / Alternatives Rejected" section — exactly the P310 blind spot ADR-070 closes. It has been reduced to **scope + decomposition + traces**. The decisions it used to hold now live in the ADR ledger: gate placement → **ADR-072**, orchestrator dispatch stance → **ADR-073**, RFC-first-is-unconditional → **ADR-071** (which **repudiated** the atomic-fix carve-out the original F2/F7/I13 carried). The I13 invariant text is added to ADR-060 under RFC-006 slice 4. RFC-005 now ships only the **gate mechanism** (schema + hook + skill enforcement + bats); it makes no decisions of its own.

## Summary

ADR-060 I1 enforces the RFC→Problem trace at RFC capture time. The inverse direction — Problem→RFC trace at fix-time — is NOT enforced (P251). Problems routinely accrete inline `## Root Cause Analysis` → `### Investigation Tasks` → `## Fix Strategy` checklists as fix work uncovers scope, rather than the agent scoping an RFC before commencing.

RFC-005 ships the **mechanism** that enforces the Problem→RFC trace at fix-time: the problem-ticket `rfcs:` frontmatter schema, the structural commit-time hook, the `/wr-itil:manage-problem` Step 7 + `/wr-itil:work-problems` Step 5 enforcement, and the behavioural coverage. The gate is **unconditional** — there is no atomic-fix carve-out and no effort threshold (per ADR-071); its lifecycle placement is `Open → Known Error` (per ADR-072); the orchestrator-dispatch stance is hard-block-and-skip (per ADR-073).

## Driving problem trace

- **P251** (`docs/problems/open/251-rfc-first-trace-invariant-not-enforced-fixes-start-without-rfc-story-map-or-jtbd-trace.md`) — RFC-first trace invariant not enforced at fix-time; fixes start without an RFC. Captured 2026-05-17 via user correction during `/wr-itil:work-problems`. JTBD trace: JTBD-008. Persona: solo-developer.

## Scope

RFC-005 extends ADR-060's I-series with the symmetric Problem→RFC trace at fix-time (the I13 invariant, added to ADR-060 under RFC-006 slice 4). It ships the **enforcement mechanism only** — every choice among ≥2 viable options that this RFC used to embed is now an ADR (per ADR-070):

- **Gate placement** — fires at `Open → Known Error` and at the `git commit` that lands the staged transition. Decision: **ADR-072**.
- **Unconditional, no carve-out** — every problem fix traces to an RFC; there is no effort threshold and no `--rfc-deferred` override. Decision: **ADR-071** (repudiates the original F2 carve-out). The atomic-fix-adopter friction guard (JTBD-101) is preserved as the thin-RFC (`stories: []`) minimal-ceremony path, not as an exemption from RFC trace.
- **Orchestrator dispatch** — `/wr-itil:work-problems` Step 5 hard-blocks an RFC-less fix and advances to the next-highest-WSJF candidate (the loop does not terminate), surfacing `/wr-itil:capture-rfc P<NNN>` recovery routing. Decision: **ADR-073**.
- **Structural enforcement** — the gate ships as a PreToolUse:Bash hook on day one, not advisory prose. Application of **ADR-051** (load-bearing-from-the-start).
- **Story-map composition deferred** — I13 enforces the RFC trace only; story-map presence at fix-time is transitively assured by ADR-060 I7/I8 and is out of scope here. Scope boundary; revisit only if RFC-003 ships and dogfood evidence shows a gap.

Problem-ticket frontmatter gains `rfcs: [RFC-<NNN>, ...]` (cardinality `0..N`: `0` permitted pre-`Known Error`; `≥ 1` required at the `Open → Known Error` gate, unconditionally). The shape mirrors ADR-060 I1's RFC→Problem `problems:` array (symmetric bidirectional trace).

## Tasks

Ordered slice decomposition (one-purpose-per-commit per ADR-014). Slices land in a held-changeset window per ADR-042 / P162; the held window stays paused until B6 bats green + B8 dogfood close. The gate mechanism is **unconditional** throughout (no carve-out branch, no override hatch).

- [x] **B1** — Add the I13 invariant (trace-to-RFC at fix-time) to ADR-060's Mandatory invariants. **Moved to RFC-006 slice 4** (the unconditional, no-carve-out I13 lands with the ADR-060 line-97 amendment per ADR-070/071). The ADR-060 gate-surface taxonomy extends to include `manage-problem <NNN> --to known-error`.
- [ ] **B2** — Extend problem-ticket frontmatter schema: add `rfcs: [RFC-<NNN>, ...]` (`0..N`). Update the problem-ticket template + `/wr-itil:capture-problem` to populate `rfcs: []` by default; update `/wr-itil:manage-problem` to append RFC references when a fix decomposes mid-flight.
- [ ] **B3** — Ship the I13 structural hook at `packages/itil/hooks/itil-i13-rfc-trace-gate.sh` (PreToolUse:Bash). Fires when `git commit` stages a `docs/problems/open/ → docs/problems/known-error/` transition with empty/absent `rfcs:` frontmatter — **for every effort level, no override hatch** (ADR-071). Emits `permissionDecision: "deny"` naming `/wr-itil:capture-rfc P<NNN>` as recovery. Wire into `.claude/settings.json` PreToolUse handlers.
- [ ] **B4** — Update `/wr-itil:manage-problem` Step 7 to enforce the I13 gate at `Open → Known Error` (per ADR-072). Add the recovery-routing prose surface alongside the hook (prose + hook compose; hook is load-bearing). No `--rfc-deferred` flag (carve-out repudiated).
- [ ] **B5** — Update `/wr-itil:work-problems` Step 5 dispatch with the I13 hard-block + skip-to-next behaviour (per ADR-073). Structured-log dispatch denials to `logs/i13-iter-dispatch-denials.jsonl`. Surface recovery prompt naming `/wr-itil:capture-rfc P<NNN>`. Loop does NOT halt; advance to next-highest WSJF candidate.
- [ ] **B6** — Behavioural bats per ADR-052 covering: (a) I13 hook denies an RFC-less `Open → Known Error` transition at every effort level (S/M/L/XL — no carve-out); (b) hook passes an RFC-traced transition; (c) work-problems Step 5 refuses an RFC-less problem and admits an RFC-traced one; (d) ADR-060 I2 uniformity — manage-problem / work-problems behaviour identical regardless of `type:` value when `rfcs:` is populated.
- [ ] **B7** — Migration sweep: enumerate `docs/problems/open/` + `docs/problems/known-error/` tickets lacking an RFC trace (no effort filter — the gate is unconditional). Produce a survey at `docs/audits/i13-rollout-survey-2026-05-17.md` with per-ticket RFC-author-effort estimates. Informs B8 dogfood selection + the rollout-grandfathering decision.
- [ ] **B8** — Forward-dogfood: capture an RFC against a real `Open` problem from the B7 survey, run it through `Open → Known Error` under the I13 gate, ship a fix slice, confirm the gate fires. Mirrors ADR-060 Phase 1 forward-dogfood. Document the evidence inline.
- [ ] **B9** — Wire the ADR-073 reassessment criterion (repeated same-ticket dispatch denials → soften toward assisted-capture) into `/wr-retrospective:run-retro` Step 2b advisory signal collection. Log path `logs/i13-iter-dispatch-denials.jsonl` becomes a retro input.
- [ ] **B10** — Held-changeset graduation: ADR-042 auto-apply paused for the RFC-005 commit chain until B6 bats green + B8 dogfood confirms the gate fires. Graduate atomically per ADR-060 architect finding 12.

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12)

## Related

- **P251** — driving problem ticket; captured 2026-05-17 via user correction.
- **ADR-071** — every fix goes through an RFC (the unconditional governing decision; repudiated the F2 carve-out RFC-005 originally carried).
- **ADR-072 / ADR-073** — the gate-placement + orchestrator-dispatch decisions re-homed from RFC-005's F1/F4 under RFC-006 slice 1a.
- **ADR-070** — RFCs hold no independent decisions (the reason this RFC was retrofitted to carry none).
- **RFC-006** — the implementation RFC that re-homed RFC-005's decisions and ships the unconditional I13 + ADR-060 line-97 amendment.
- **ADR-060** — parent framework. RFC-005 ships the symmetric Problem→RFC direction; the I13 invariant text lands in ADR-060 under RFC-006 slice 4.
- **ADR-051** — load-bearing-from-the-start; structural hook over prose-only.
- **ADR-052** — behavioural-tests-default; B6 task contract.
- **JTBD-008** — primary anchor. **JTBD-101** — atomic-fix-adopter friction guard, now the thin-RFC path (per ADR-071). **JTBD-006** — AFK orchestrator throughput (ADR-073 dispatch stance). **JTBD-001** — per-edit governance composition.
- **P165** — sibling structural hook shape; PreToolUse:Bash gate on staged ticket surfaces.
- **P196 / P189** — sibling premature-completion / fictional-defer failure modes at the RFC/SKILL surfaces.
