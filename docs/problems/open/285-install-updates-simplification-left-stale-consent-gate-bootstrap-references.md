# Problem 285: install-updates global-cache-refresh simplification left stale references to the retired consent gate + Step 6.5 bootstrap across downstream surfaces

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Commit `7a14b8b` (2026-05-25) narrowed `/install-updates` to a single global-cache refresh run, retiring (a) the sibling-discovery + per-sibling install loop, (b) the `AskUserQuestion` consent gate + P120 consent cache + P061 sibling-cap fallback, and (c) the Step 6.5 risk-register bootstrap auto-trigger (ADR-059 verdict A6). ADR-030, ADR-059, and ADR-047 were amended in the same commit. The edit was deliberately scoped to `SKILL.md` + those 3 ADRs + tests + a P280 note per the directed plan.

Several **downstream surfaces that were out of that directed scope** still reference the now-retired consent gate and Step 6.5 bootstrap. They cause **no test failures today** (every cross-referencing bats assertion targets its own surface's file; the stale items are comments/prose), but they are doc-currency drift that will mislead future readers. Both `wr-architect:agent` and `wr-jtbd:agent` flagged these as tracked follow-ups during the `7a14b8b` gate review ("don't leave untracked").

Surfaces to reconcile:

1. **`scripts/repo-local-skills/install-updates/REFERENCE.md`** (repo-local — no release needed) — still documents the consent gate ("First action is a consent gate"), the P120 consent cache section, the P061 fallback section, and the "Governance-artefact scaffold (P033)" / Step 6.5 bootstrap section. All retired. This is the SKILL's own progressive-disclosure companion (ADR-038), so the contradiction is most acute here.
2. **`packages/risk-scorer/skills/bootstrap-catalog/SKILL.md`** (~line 9/12; PUBLISHED — needs changeset) — dangling forward-ref asserting "the auto-trigger surface (per ADR-059 verdict A6) is `/install-updates` Step 6.5."
3. **`packages/risk-scorer/skills/create-risk/test/create-risk-flag-driven.bats`** (lines ~12-13; PUBLISHED — needs changeset) — header comment references the install-updates Step 6.5 bootstrap auto-trigger as a consuming orchestrator.
4. **`packages/itil/skills/work-problems/test/work-problems-step-6-5-cache-refresh-chain.bats`** + **`packages/itil/skills/work-problems/SKILL.md`** Step 6.5 Drain prose (PUBLISHED — needs changeset) — reference install-updates' now-removed `AskUserQuestion` consent gate / `INSTALL_UPDATES_RECONFIRM` / dry-run / Step 5b/5c branches (e.g. the P130 "AskUserQuestion-available-but-forbidden" routing prose, ADR-044 citation). The chained `/install-updates` invocation itself survives; only the consent-gate framing is stale.
5. **`packages/risk-scorer/agents/pipeline.md`** (PUBLISHED — needs changeset) — empty-catalog nudge may still point at "`/install-updates` … bootstrap". The `risk-scorer-catalog-consumption.bats` assertion is an OR (`bootstrap-catalog|/install-updates.*bootstrap`), so it stays green either way; the nudge text should drop the install-updates pointer in favour of `/wr-risk-scorer:bootstrap-catalog`.
6. **`docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md`** (lines ~16/19; docs — no release needed) — outcome prose still describes the sibling-loop mechanism ("current project and its siblings") and the sibling-consent gate. The job *intent* (every active project picks up the latest code) is unchanged and still satisfied by the global cache; the prose should be reframed from mechanism-language to outcome-language so a future reviewer doesn't read the removed sibling loop as a missing feature (JTBD gate advisory, 7a14b8b review).

## Symptoms

- A reader of REFERENCE.md, bootstrap-catalog SKILL.md, work-problems Step 6.5 prose, or JTBD-007 sees a consent gate / Step 6.5 bootstrap / sibling-loop that no longer exists in install-updates.
- No automated test fails — the drift is silent prose/comment rot.

## Workaround

(deferred to investigation) — none needed for behaviour; readers must cross-check against ADR-030 / ADR-059 amendments 2026-05-25.

## Impact Assessment

- **Who is affected**: future maintainers reading any of the 6 surfaces; the architect/JTBD gates on subsequent edits to those files.
- **Frequency**: on-read; surfaces 2-5 will also confuse the next risk-scorer / itil release reviewer.
- **Severity**: Low — doc-currency drift, no behavioural defect, no test failure.
- **Analytics**: `grep -rn 'Step 6.5\|consent gate\|install-updates-consent\|INSTALL_UPDATES_RECONFIRM' packages/ scripts/repo-local-skills/install-updates/REFERENCE.md docs/jtbd/` after the fix should return only intentional historical-note references.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] **REFERENCE.md** (repo-local) — trim consent-gate / P120 cache / P061 fallback / Step 6.5 scaffold sections to match the global-cache-refresh SKILL; can land without a release.
- [ ] **JTBD-007** (docs) — reframe outcome bullets (lines ~16/19) from sibling-loop mechanism to global-cache outcome language; can land without a release.
- [ ] **Published-plugin surfaces (need changeset + release)** — bootstrap-catalog SKILL.md A6 ref (item 2); create-risk-flag-driven.bats comment (item 3); work-problems SKILL.md Step 6.5 Drain prose + its bats comments (item 4); pipeline.md empty-catalog nudge (item 5). Batch these into a risk-scorer + itil patch release.
- [ ] Confirm no NEW test breakage after each edit (the work-problems / catalog-consumption asserts are surface-local and OR-shaped — verify they stay green).

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: ADR-030 (consent-gate retirement, amendment 2026-05-25), ADR-059 (A6 retirement, amendment 2026-05-25), ADR-047 (install-updates coupling dissolved), P280 (sibling settings.json churn — same simplification), P120 (consent-gate-fires — closed; this is the doc-cleanup tail of its retirement), P061 (sibling-cap fallback — verifying).

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- Commit `7a14b8b` — the install-updates global-cache-refresh simplification that produced this drift.
- `scripts/repo-local-skills/install-updates/SKILL.md` — the rewritten skill (source of truth for current behaviour).
- ADR-030 / ADR-059 amendments 2026-05-25 — the authoritative record of what was retired.
- Flagged by wr-architect:agent + wr-jtbd:agent during the 7a14b8b ADR-014 gate review.
