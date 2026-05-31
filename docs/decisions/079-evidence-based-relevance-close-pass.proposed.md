---
status: "proposed"
date: 2026-05-31
decision-makers: [unspecified — fill at canonical review]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-08-31
---

# Evidence-based relevance-close pass for the problem backlog (Phase 1: file-no-longer-exists)

> Captured via /wr-architect:capture-adr (foreground-lightweight aside-invocation per ADR-032 P156 amendment). Run /wr-architect:create-adr on this ID to expand the deferred sections canonically. Substance pinned by user direction 2026-05-31 verbatim (see Context). **Confirm-every-ADR gate (ADR-064)**: this ADR is recorded `proposed` with a pre-pinned decision but WITHOUT human review of the alternatives — MUST NOT be promoted to `accepted` until it has been through a `/wr-architect:create-adr` (or equivalent) `AskUserQuestion` review-and-confirm pass; `human-oversight:` frontmatter intentionally absent until then per ADR-066 line 50.

## Context and Problem Statement

The `/wr-itil:review-problems` skill has no path to close tickets that have become **no longer relevant**. Today's only closure paths are (a) ship a fix → Verifying → Closed, (b) Park (upstream/external block), or (c) no path at all for "this isn't worth doing anymore", "duplicates X", "the thing it's about no longer exists in the codebase". The result is a structural outflow gap: capture is automatic and cheap (P078 capture-on-correction, P342 retro auto-capture, ADR-062 inbound discovery, agent-observed mid-iter friction) while close requires real work + budget. The system is structurally guaranteed to grow ticket counts over time — captured in P346 with concrete trajectory data (47 days, 345 tickets, +2.82/day Active, no zero ETA).

User direction (verbatim, 2026-05-31): *"Ok, I'm happy for a skill executed as part of review problems that closes tickets that are no longer relevant, but not just because they are old"*.

This direction pins two hard constraints: (1) the relevance-close pass MUST execute as part of `/wr-itil:review-problems`, NOT as a standalone skill — composes with the WSJF re-rank flow; (2) the relevance signal MUST be observable per ADR-026 grounding — age may be a *gating* condition (don't bother evaluating fresh tickets) but never the *closing* condition.

## Decision Drivers

- **User direction 2026-05-31** (verbatim above) — primary driver; pins both constraints.
- **ADR-026 (Agent output grounding)** — every close decision must satisfy cite + persist + uncertainty. Age-based heuristics ("> 30 days" alone) FAIL this contract; observable evidence (file existence, git-grep verdict) PASSES.
- **ADR-022 (Verification Pending lifecycle)** — extended (not modified) by this ADR. The lifecycle today is Open → Known Error → Verifying → Closed; this ADR adds a sanctioned non-linear transition Open|Known Error → Closed-with-reason that bypasses Verifying when no fix was released. Precedent for the extend-not-modify pattern: ADR-026 line 109 extends ADR-022 with `Actual Effort:` field without modifying lifecycle mechanics.
- **JTBD-001 (Enforce Governance Without Slowing Down)** — under-60s review-flow served by smaller queue.
- **JTBD-006 (Progress the Backlog While I'm Away)** — AFK pre-flight surface extension; mechanical evidence is NOT judgment-call.
- **JTBD-101 (Extend the Suite with Clear Patterns)** — Phase 1 = ONE evidence shape per slice; each future shape gets its own bats fixture + verdict line.
- **JTBD-201 (Restore Service Fast with an Audit Trail)** — `## Closed as no longer relevant` section preserves audit trail; reversible via `git revert`.
- **P334 / P336 close-on-evidence precedent** — the close pattern is already proven for a sub-class of "no longer relevant" (the fix shipped without the lifecycle close); this ADR generalises it to the broader "no-fix-needed" class.

## Considered Options

1. **Option A (chosen)** — Phase 1 auto-close on ONE evidence shape: "file no longer exists in codebase". A new Step 4.6 in `/wr-itil:review-problems` SKILL.md invokes the canonical evaluator script (`packages/itil/scripts/evaluate-relevance.sh` via the ADR-049 PATH shim `wr-itil-evaluate-relevance`). The script extracts file-path references from each `.open.md` / `.known-error.md` ticket body matching well-known repo subdirs `(packages|docs|.changeset|src|test|scripts)/...\.(md|sh|ts|tsx|js|jsx|json|yml|yaml|bats|py|txt|html)`, excludes self-references (`docs/problems/*`), and runs `git ls-files --error-unmatch` on each. A `CLOSE-CANDIDATE` verdict fires when ALL extracted paths return zero AND at least one was extracted AND the ticket is ≥ 7 days old. The auto-close action writes a `## Closed as no longer relevant` section (evidence shape + closed-on date + paths checked + reversibility clause per ADR-026 cite+persist+uncertainty) then `git mv` Open/Known Error directly to Closed (bypassing Verifying — no fix was released). All relevance-closes from one review pass batch into ONE commit per ADR-014 (mirroring `/wr-itil:transition-problems` P139 batch grain).
2. (deferred — see /wr-architect:create-adr canonical review for full taxonomy: surface-with-options interactive variant; per-evidence-shape cadence; closed-ticket reopen surface; alternative path-extraction regexes; alternative age-gate thresholds)

## Decision Outcome

Chosen option: **"Option A — Phase 1 auto-close on file-no-longer-exists evidence shape"**, because the file-existence signal is the most mechanical and highest-confidence of the candidate shapes (closest analog to P334/P336 evidence-close), the audit-trail contract is fixed (ADR-026 cite+persist+uncertainty), and the implementation is contained to one iter without sinking unbounded design effort. Subsequent evidence shapes (ADR-supersession, duplicate-of-X, "concern no longer concerning", SKILL-contract-superseded, incidentally-fixed-by-unrelated-commit) are deferred to sibling tickets — each shape gets its own bats fixture + its own verdict-line extension to the same script without re-design.

This is an **ADR-022 extension (not modification)** mirroring ADR-026 line 109's precedent — the lifecycle table in `/wr-itil:manage-problem` SKILL.md gains a row for the new Open|Known Error → Closed-with-reason transition; ADR-022's status-transition mechanics for Open / Known Error / Verifying / Closed remain unchanged.

## Consequences

### Good

- (deferred to /wr-architect:create-adr canonical review — preliminary: queue truthfulness improves; under-60s review-flow restored; backlog trajectory has a structural outflow path; audit trail preserved per ADR-026; reversible per `git revert`)

### Neutral

- (deferred to /wr-architect:create-adr canonical review)

### Bad

- (deferred to /wr-architect:create-adr canonical review — preliminary: false positives possible on tickets whose paths were renamed without ticket-body update; mitigated by reversibility + ≥7-day age gate)

## Confirmation

(deferred to /wr-architect:create-adr canonical review — preliminary: `packages/itil/scripts/test/evaluate-relevance.bats` exercises 5 scenarios: all-absent-old → CLOSE-CANDIDATE; mixed-present → KEEP; fresh → SKIP; no-paths → SKIP; self-references-only → SKIP)

## Pros and Cons of the Options

### Option A

- (deferred to /wr-architect:create-adr canonical review — preliminary: see Decision Drivers + Decision Outcome above)

## Reassessment Criteria

(deferred to /wr-architect:create-adr canonical review — default reassessment-date 2026-08-31; preliminary triggers: ≥3 false-positive closes within 60 days; user direction to expand Phase scope; emergence of an additional evidence shape with mechanical-confidence comparable to file-no-longer-exists)

## Related

- **P346** (`docs/problems/open/346-review-problems-no-path-to-close-no-longer-relevant-tickets-evidence-based.md`) — driver ticket.
- **ADR-022** (`docs/decisions/022-problem-lifecycle-verification-pending-status.proposed.md`) — **extended** (not modified) per the precedent ADR-026 line 109 set. The new Open|Known Error → Closed-with-reason transition rides ADR-022's lifecycle.
- **ADR-026** (`docs/decisions/026-agent-output-grounding.proposed.md`) — cite + persist + uncertainty contract honoured by the `## Closed as no longer relevant` audit section.
- **ADR-014** (`docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`) — commit grain for the batched relevance-close commits.
- **ADR-049** (PATH shim convention) — `wr-itil-evaluate-relevance` shim resolves the canonical script via `lib/` sibling per RFC-009 / P317.
- **ADR-052** (Behavioural tests default) — bats coverage per the standard contract.
- **ADR-013 Rule 5** (Below-appetite policy-authorised silent proceed) + **ADR-044 category 4** (silent framework action) — file-existence is empirical, not user judgment; AFK silent-proceed is correctly invoked.
- **ADR-066** — born-`proposed` without `human-oversight: confirmed`; orchestrator-level drain via `/wr-architect:review-decisions` ratifies later.
- **P334**, **P336** — close-on-evidence precedent for sub-class "fix shipped without lifecycle close".
- **JTBD-001**, **JTBD-006**, **JTBD-101**, **JTBD-201** — personas served (JTBD review verdict 2026-05-31: ALIGNED).
