# Problem 323: JTBD review (file edits + plans) does not flag changes built on an UNRATIFIED persona or job — no build-upon guard exists on the JTBD surface at all (twin of P318 on the ADR surface)

**Status**: Open
**Reported**: 2026-05-27
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

`ADR-068` (JTBD/persona human-oversight marker + confirm drain) is the deliberate sibling of `ADR-066` (ADR human-oversight marker + review-decisions drain). It built three things mirroring the ADR side:

1. The `human-oversight: confirmed` + `oversight-date` frontmatter marker on personas and jobs.
2. `wr-jtbd-detect-unoversighted` (bulk detector) + the session-start nudge.
3. `/wr-jtbd:confirm-jobs-and-personas` (interactive drain) + born-confirmed `/wr-jtbd:update-guide`.

Those are **enforcement surfaces 1 (record-time confirm) and 2 (interactive drain)** — the JTBD twins of the ADR side's `create-adr` born-confirmed + `review-decisions` drain.

But the ADR side has a **third enforcement surface** that the JTBD side has never had: `ADR-074` / `RFC-010` / `P318` (shipped 2026-05-27) added an `[Unratified Dependency]` verdict to the **architect agent** — when a change or plan explicitly cites or implements an ADR that lacks the marker, the agent emits `ISSUES FOUND` and refuses to let it stand until the ADR is ratified. That is the always-on, broadest gate: it fires on every project-file edit (PreToolUse architect gate) and every plan (`/wr-architect:review-design`).

**The JTBD surface has no equivalent.** The jtbd agent (`packages/jtbd/agents/agent.md`) reviews changes for *alignment* with documented jobs/personas — Job Gap, Persona Mismatch, Missing Annotation, Job/Persona Update Needed — but it has **zero awareness of the `human-oversight: confirmed` marker**. It will happily PASS a change that is built on, cites, or serves a persona or job whose substance has never been human-confirmed.

Verified 2026-05-27: `grep -ciE 'human-oversight|unratified|oversight' packages/jtbd/agents/agent.md` → **0**. The marker is read only by the bulk detector + the drain skill, never at the build-upon / review surface.

**Consequence**: a change that explicitly serves an unratified persona or job passes JTBD review with no flag. Work gets built on auto-derived, never-human-confirmed user-need definitions — the exact `P315` failure class (dependent work built before the substance is confirmed), at the JTBD layer instead of the ADR layer. This is the unrecorded asymmetry surfaced when the user asked: *"we just created controls to make sure the ADRs get ratified BEFORE implementation, do we have similar for personas and jobs to be done?"* The answer was: surfaces 1 & 2 yes, surface 3 no.

### Live instance — the solo-developer persona

`docs/jtbd/solo-developer/persona.md` is **unratified** — `grep -c 'human-oversight' docs/jtbd/solo-developer/persona.md` → **0**. It was deliberately left unratified during the 2026-05-25 P288/ADR-068 drain: when presented for confirmation the user declined as-named (*"I don't know why this is just a solo-developer and not software development teams in general"*) and captured `P289` (broaden + rename → `developer`); the marker is withheld until that rename lands. Meanwhile 8 jobs carry `persona: solo-developer` frontmatter and ongoing work references the persona — yet nothing flags that this work builds on an unratified, pending-rework user-need definition. Surface 3 would catch it.

## Symptoms

- The jtbd agent reviews a file edit / plan that implements, cites (`@jtbd JTBD-NNN`, `persona: <name>`), or authors the flow for an unratified persona/job; verdict is PASS (or flags only alignment gaps) — never "this builds on unratified `<persona|JTBD-NNN>`; ratify its substance via `/wr-jtbd:confirm-jobs-and-personas` first."

## Workaround

Run `/wr-jtbd:confirm-jobs-and-personas` proactively to drain the unoversighted set (17 jobs/personas per P288), so build-upon happens only against ratified artifacts. This is the surfaces-1-&-2 path; it does not gate the ad-hoc-foreground-edit path the way surface 3 would.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [x] **DONE 2026-05-27** — confirmed the gap is real, not a deliberate design choice. `ADR-068` predates `ADR-074`/`RFC-010`; when ADR-068 was authored (2026-05-25) the architect surface-3 control did not yet exist (shipped 2026-05-27), so there was nothing to mirror. The asymmetry is a sequencing artifact, not an intentional carve-out — nothing in ADR-068 or the jtbd agent records a decision to *omit* surface 3.
- [x] **DONE 2026-05-27** — confirmed the jtbd agent has no marker-awareness (`grep` → 0) and that the solo-developer persona is the live unratified instance.
- [x] **DONE 2026-05-27** — confirmed a **bulk** detector exists (`wr-jtbd-detect-unoversighted`) but there is **no single-artifact predicate** sibling of the architect side's `packages/architect/scripts/is-decision-unconfirmed.sh`. The fix likely needs that predicate (or the agent greps frontmatter directly — the jtbd agent has `Bash` + `Grep`, unlike the architect agent which has only `Grep`).

### Root cause

The JTBD oversight machinery (ADR-068) was built as a faithful sibling of the ADR machinery *as it stood on 2026-05-25* — which at that point covered only surfaces 1 (born-confirmed record) and 2 (interactive drain). The architect's build-upon guard (surface 3) is a **later** addition (ADR-074 / RFC-010, 2026-05-27). The sibling relationship was never re-synced after surface 3 landed, so the JTBD side silently fell one surface behind. The jtbd agent's review contract (`agent.md`) only ever encoded *alignment* checks (does this serve a documented job? does it fit the persona?) and was never extended to ask *is the job/persona it depends on actually ratified?*.

### Design notes for the fix (mirror RFC-010 on the JTBD surface)

- Add an `[Unratified Dependency]` verdict to `packages/jtbd/agents/agent.md`: when a change or plan **explicitly cites/implements/serves** a specific persona or job (`@jtbd JTBD-NNN` annotation, `persona: <name>` frontmatter, or it is authoring that artifact's flow), check the cited artifact's frontmatter for `human-oversight: confirmed`. If absent AND the artifact is not superseded → emit `ISSUES FOUND` / `FAIL` with action "ratify `<persona|JTBD-NNN>` via `/wr-jtbd:confirm-jobs-and-personas` before this lands."
- **Key on the marker, never on `status:`** — same orthogonal-axis design as ADR-066/ADR-074. Building on a ratified job whose `status` is still `proposed` is fine.
- **Bound to explicit cite/implement** (the inverse-P078 / P132 over-fire guard). The jtbd agent already matches every change to a job ID for its PASS verdict — surface 3 must NOT fire on mere ambient alignment, only on an explicit dependency, or it will fire on essentially every change.
- **Noise note**: unlike the ADR side (4/65 unratified, near-silent), the JTBD unratified set is currently large (17 per P288). Until the P288 drain completes, surface 3 will fire more often. That is arguably the desired forcing function, but the explicit-cite bound keeps it proportionate. The fix should NOT wait on the P288 drain.
- The jtbd agent has `Bash`, so it may run a single-artifact predicate (`is-job-or-persona-unconfirmed.sh`, to be added as the sibling of `is-decision-unconfirmed.sh`) OR grep frontmatter directly. Predicate-vs-grep is a fix-design decision for the architect to weigh.
- Mirror RFC-010's structural-permitted test (`ADR-052` Surface 2, P176) for the verdict-presence assertion.

## Impact Assessment

- **Who is affected**: maintainers + any adopter project with `docs/jtbd/` and unratified personas/jobs. Symmetric to P318's reach.
- **Frequency**: every file edit / plan that depends on an unratified persona/job — currently 17 unoversighted artifacts in scope.
- **Severity**: governance integrity — auto-derived user-need definitions ride into dependent work unconfirmed (the P315 failure class at the JTBD layer).

## Dependencies

- **Composes with**: `P288` / `ADR-068` (built surfaces 1 & 2 — this adds surface 3), `ADR-074` (the substance-before-build contract this extends to the JTBD surface), `ADR-066` (orthogonal status/oversight axes + the "unconfirmed = marker absent + not superseded" predicate definition), `RFC-010` / `P318` (the architect-side twin this mirrors).
- **Blocked by**: none — implementation can begin immediately; must NOT wait on the P288 drain.
- **Closes**: the JTBD-surface half of the build-on-unratified gap (the ADR-surface half is P318).

## Related

- **P318** — the ADR-surface twin (architect agent flags build-on-unratified ADR). This is its JTBD mirror.
- **P315** — grandparent (substance-confirm-before-build); both P318 and P323 are its uncovered foreground surfaces, on the ADR and JTBD layers respectively.
- **P288** / **ADR-068** — built the JTBD oversight marker + detector + drain (surfaces 1 & 2); the 17-artifact drain is the current unratified set this surface-3 control would gate against.
- **P289** — broaden + rename `solo-developer` → `developer`; the solo-developer persona is the live unratified instance demonstrating this gap.
- **RFC-010** — the architect-surface implementation this fix mirrors.
- captured via /wr-itil:capture-problem, 2026-05-27, in response to the user's "do we have similar for personas and jobs to be done?" governance question.

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| (to be created) | — | JTBD review flags changes built on an unratified persona or job |
