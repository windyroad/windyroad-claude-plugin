# Problem 167: Risk register aggregate reads as "don't ship" — sparse coverage + undercredited controls

**Status**: Known Error
**Reported**: 2026-05-04
**Priority**: 3 (Low) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (post-correction; substantive remaining work delegated to P168 — this ticket's residual is the cross-reference + transition only)
**Type**: technical

## Update — 2026-05-04 corrected framing

The original RC3 framing in this ticket (per-action vs lifetime-aggregate appetite distinction) was a **misreading** of the user's intent for `docs/risks/`. User correction during follow-up clarified the model:

- `docs/risks/` is the **persistent catalog of per-action risks** for this project — one universe of risks, documented so the risk-scorer doesn't re-derive the same risk classes on every assessment.
- Per-action assessments (`.risk-reports/`) READ the catalog, filter to risks applicable to THIS action, assess controls FOR THIS ACTION, compute residual against the **same 4/Low appetite**, and add new risk classes back to the catalog if conceived during assessment.
- Same appetite (4/Low) applies uniformly. There is NO per-action vs lifetime aggregation distinction.
- A catalog residual above appetite IS a real signal — baseline controls are not sufficient for the typical action that triggers this risk class.

**Status of the original RCs after correction:**

- RC1 (sparse coverage) — **valid**. Underlying cause clarified: the risk-scorer agent today doesn't bootstrap the catalog from `.risk-reports/` and doesn't consume the catalog during per-action assessments. Both are wasted-effort + missed-risk-class failure modes the user named explicitly.
- RC2 (controls undercredited) — **valid**. Resolved by the Control Composition rule landed in `RISK-POLICY.md` (commit `9e339d0`, 2026-05-04).
- RC3 (per-action vs lifetime appetite) — **superseded**. Same appetite uniformly; framing was incorrect. See the new `## Risk Catalog` section in `RISK-POLICY.md` for the corrected framing.

**Status of the original Phase 1-3 plan (R007-R011 + extensions + re-rate):**

- **Superseded** by the user's direction: delete everything in `docs/risks/` and have the risk-scorer bootstrap the catalog from `.risk-reports/` automatically when the catalog is empty. R007-R011 manual authoring is no longer the right path; the bootstrap behaviour is the substantive design that needs to ship.
- The wipe-and-bootstrap design is captured in a separate problem ticket — see `## Related` for the link.
- The R002/R005 extension idea remains valid as a behavioural target post-bootstrap (the bootstrap should produce richer coverage of SKILL.md drift / surface-area accumulation / ADR drift than R002/R005 currently capture).
- The R001-R006 re-rate is also superseded — the bootstrap will produce fresh entries from `.risk-reports/` rather than re-rating existing entries.

The original ticket body below this section is preserved for audit-trail purposes. Investigation Tasks are updated at the bottom to reflect the corrected scope.

## Description

All 6 standing risks in `docs/risks/` carry residual scores above the project's 4/Low appetite threshold:

| ID | Title | Residual | Band |
|----|-------|----------|------|
| R001 | Confidential information leak via public-repo push | 9 | Medium |
| R002 | Hook regression breaks installed users' workflow | 8 | Medium |
| R003 | Installer corrupts user's Claude Code config | 5 | Medium |
| R004 | Cross-package version drift or publish failure breaks install | 6 | Medium |
| R005 | README / SKILL.md prose drifts from runtime behaviour | 12 | High |
| R006 | Marketplace cache lag delivers stale plugin behaviour | 8 | Medium |

Read in aggregate, the register signals "every standing risk is above appetite — the project shouldn't ship plugins at all". This is a **false signal**: the plugins provide real user value and serve brand-building for AI engineering expertise. The user observed this misleading reading on 2026-05-04 and pushed back on the implication.

The user's hypothesis: the real issue is that **either ratings are too aggressive, OR controls aren't being credited proportionally in residual computation, OR both** — possibly compounded by the register being incomplete (sparse coverage means the write-down captures only the worst-case risks, with no low-severity counterweight).

Sibling work at capture time: an Explore agent compared `.risk-reports/` (181 concrete pipeline-risk reports yielding ~327 unique risk titles) against `docs/risks/` (6 standing risks) and identified 12-14 distinct themes, of which only 2-3 are clearly covered. Result: 5 proposed new standing risks (R007 register-drift, R008 orchestrator-state-drift, R009 hook-deny-message-UX, R010 ADR-ratification-lag, R011 ambient-state-publish) plus extensions to R002/R005 to cover ADR drift and SKILL.md structural prose drift. See "Related" for full output reference.

## Symptoms

- Every active standing risk's residual exceeds the 4/Low appetite threshold.
- Aggregate reading of the register implies the project is operating outside risk appetite across the board.
- No low-severity standing risks exist as counterweight (no Very Low or Low residuals on the register).
- Concrete pipeline-risk reports routinely score 1-4/25 (Very Low / Low) for individual changes, while their corresponding standing-risk parents (R001-R006) score 5-12. Disconnect between per-action exposure and standing-risk inherent framing.
- Register has 6 entries vs `.risk-reports/` containing 181 concrete reports (~327 unique risk titles, 12-14 distinct themes) — order-of-magnitude coverage gap; gap analysis identified 5 systemic theme classes absent from the register.

## Workaround

Corrected catalog framing landed in `RISK-POLICY.md` commit `9e339d0` (new `## Risk Catalog` and `## Control Composition` sections). This eliminates the "register reads as don't ship" misreading at the policy layer — `docs/risks/` is now framed as the persistent catalog of per-action risks consumed by per-action assessments at the same 4/Low appetite uniformly, not as a separate lifetime-aggregation surface above per-action appetite. The substantive structural fix (risk-scorer bootstrap-from-empty + consume-catalog) is delegated to **P168** (see `## Related`).

## Impact Assessment

- **Who is affected**: plugin-maintainer (decision-making on whether changes proceed), tech-lead persona reading the register for governance assurance, solo-developer persona using the register to calibrate risk acceptance.
- **Frequency**: every time the register is consulted (`docs/risks/README.md` is read on review cycles, ADR drafts cite it, problem tickets cross-reference standing risks). Estimated weekly+ during active development.
- **Severity**: Medium — false-negative signal would suppress legitimate work or trigger unnecessary scope-narrowing decisions; false-positive (acting confident despite real risk) is bounded by the per-change pipeline scorer providing fresh action-grade signals.
- **Analytics**: count of register reviews where appetite-band reading was overridden in commentary; count of changes blocked or held citing standing-risk residual without referencing per-action pipeline score.

## Root Cause Analysis

Three candidate root causes, **likely compounding rather than independent**. The sibling gap analysis (see "Related") empirically supports RC1 and RC2; RC3 is a framing observation about how appetite is interpreted.

### RC1 — Sparse coverage biases the register toward worst-case risks (HIGH confidence — empirically confirmed)

The register has 6 entries while `.risk-reports/` carries 181 concrete reports surfacing ~327 unique risk titles clustering into 12-14 themes. Only 2-3 themes are clearly covered by R001-R006. The 9-11 remaining themes — including register-drift, orchestrator state corruption, hook deny-message UX violations, ADR ratification lag, and ambient development state being committed — are absent from the register entirely.

Without a long tail of Very Low and Low standing risks, the aggregate distribution is structurally skewed High. The register reads "don't ship" not because the project is risky overall, but because **the 6 entries that exist were seeded as the most consequential / most-cited risks** (P102 MVP invocation surface, R001 Change Log) — by selection.

Evidence: gap analysis output (sibling work) identified R007-R011 as systemic-theme gaps with concrete cross-references to specific risk reports. 6 entries / 327 titles = 1.8% surface coverage; 6 entries / 12 themes = 50% theme coverage with strong pessimism bias on which themes were captured first.

### RC2 — Standing-risk residual scoring undercredits defense-in-depth control stacks (MEDIUM-HIGH confidence — gap analysis supports)

Looking at R001 specifically: controls listed are
- `secret-leak-gate.sh` hook (regex-block on Edit/Write)
- `RISK-POLICY.md` Confidential Information section (written policy)
- Pipeline Layer 2 confidential-info scan
- `git-push-gate.sh` hook (forces push through `push:watch`)

Four layered controls. Yet residual likelihood drops only from 4 to 3 (one band) and impact stays at 3. The reasoning in R001 is "controls reduce likelihood, not impact; depends on reviewer judgement; secret-regex doesn't catch prose confidentials". This is **conservative on impact (correct — a leak is still a leak)** but **arguably under-credits the layered likelihood**: four independent failure points is structurally Possible→Unlikely territory, not Likely→Possible.

Same pattern across R002 (residual 8 despite TDD enforcement, behavioural-tests-default, marketplace cache update protocol), R005 (residual 12 despite voice-tone-gate, ADR-026 grounding, `wr-c4:check`). Gap analysis observation: "Standing risk controls are architectural (ADR references, policy gates), not instance-specific. When a concrete report applies 10 bats + code review, likelihood drops 3→2; standing risk conservatively assumes not all future commits will have that."

Evidence: R001 lists 4 controls, residual likelihood drops 1 band; R005 lists multiple controls, residual still High. Concrete reports applying the same controls routinely score Very Low residual.

### RC3 — Inherent vs residual framing differs between standing risks and per-change reports (MEDIUM confidence)

Per-change risk reports score the **per-action exposure of one specific commit/push/release**. Standing risks score the **lifetime exposure of the class across all future actions**. These are different quantities. A standing risk with residual 8 = "across the next year of authoring sessions, the cumulative exposure to confidential-info leak is Medium" — that's reasonable. But the appetite threshold (4/Low) was calibrated against **per-pipeline-action** risk (the risk-scorer's blocking behaviour at commit/push/release time), not against lifetime-aggregate.

Reading both numbers against the same appetite threshold creates the false signal. A standing residual of 8 is NOT directly comparable to a pipeline residual of 4 — the time window and aggregation are different.

Evidence: `RISK-POLICY.md` Risk Appetite section says "Pipeline gates block when cumulative residual risk exceeds 4" — explicit per-action framing. Standing-risk residuals are per-class lifetime estimates. The register's appetite-comparison column ("Within appetite? No") applies the per-action threshold to a lifetime number.

The gap-analysis Recommend further: "Residual ≥ appetite is intentional for policy-critical risks" — i.e. R001 (confidential leak) and R005 (README drift) sit Medium/High on purpose because they map to brand-reputation or policy breaches that warrant continuous "in flight" monitoring. This complicates RC3: the register may legitimately have above-appetite residuals on policy-critical risks; what's missing is the explicit framing that "above appetite for standing risks ≠ above appetite for per-action pipeline".

### Investigation Tasks

> **Note (2026-05-04 corrected framing)**: the task list below is the original (pre-correction) plan. The active task list is in the **Updated Investigation Tasks** section directly below this block. Original tasks preserved for audit trail.

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [x] Confirm or reject RC1 by counting risk-report theme classes absent from `docs/risks/` — **CONFIRMED** by sibling Explore agent output (5 systemic gap themes identified)
- [x] Confirm or reject RC2 — **PARTIAL CONFIRMATION** by gap analysis (controls observed not credited proportionally; needs structural fix)
- [x] ~~Confirm or reject RC3 by checking whether `RISK-POLICY.md` defines a separate appetite threshold for standing-risk residuals vs per-action pipeline residuals~~ — **SUPERSEDED**: RC3 was a misreading; same appetite (4/Low) applies uniformly per corrected framing.
- [ ] ~~Open R007 (problem-ticket register drifts from README/filesystem state — brand)~~ — **SUPERSEDED** by wipe-and-bootstrap approach
- [ ] ~~Open R008 (multi-step orchestrator drift or session-state corruption — operational)~~ — **SUPERSEDED**
- [ ] ~~Open R009 (hook user-facing deny-message violates UX/disclosure budget — brand/operational)~~ — **SUPERSEDED**
- [ ] ~~Open R010 (ADR shipped before ratification or amended mid-implementation — operational)~~ — **SUPERSEDED**
- [ ] ~~Open R011 (ambient development state accidentally published — operational)~~ — **SUPERSEDED**
- [ ] ~~Extend R002 to cover SKILL.md structural prose drift and surface-area accumulation control class~~ — **SUPERSEDED**
- [ ] ~~Extend R005 to cover ADR/documentation-boundary drift as concrete drift pattern~~ — **SUPERSEDED**
- [x] ~~Decide whether `RISK-POLICY.md` needs a separate standing-risk appetite~~ — **RESOLVED**: same appetite uniformly. Catalog framing landed in commit `9e339d0`.
- [ ] ~~Re-rate R001-R006 residuals after R007-R011 land~~ — **SUPERSEDED** by wipe-and-bootstrap approach
- [ ] ~~Add control-composition / defense-in-depth subsection to `docs/risks/TEMPLATE.md`~~ — **PARTIALLY RESOLVED**: rule landed in `RISK-POLICY.md` `## Control Composition` section, commit `9e339d0`. TEMPLATE.md may still benefit from a citation.
- [ ] Create reproduction test: register-coverage assertion comparing observed risk-report theme set against the standing-risk class set (test ↔ ADR-026 grounding pattern) — **STILL VALID** but probably belongs in the wipe-and-bootstrap ticket as Confirmation criterion.

### Updated Investigation Tasks (post-correction)

- [x] Land catalog framing + composition rule in `RISK-POLICY.md` — **DONE** (commit `9e339d0`).
- [x] Re-rate Priority and Effort — **DONE** (Effort dropped M → S inline at this transition; Priority unchanged at 3 / Low).
- [x] Cross-reference the wipe-and-bootstrap ticket from `## Related` once captured — **DONE** (P168 link added below).
- [ ] Optionally: TEMPLATE.md citation pointer to the `## Control Composition` rule.
- [x] Transition to `.known-error.md` once the wipe-and-bootstrap ticket is captured and cross-referenced — **DONE** (this transition; substantive remaining work delegated to P168; root cause documented).

## Dependencies

- **Blocks**: (none yet — the R007-R011 standing-risk creates and R002/R005 extensions are dependents but live in `docs/risks/` not `docs/problems/`, so no problem-ticket blocking links)
- **Blocked by**: (none)
- **Composes with**: P168 (substantive design successor — wipe-and-bootstrap + consume-catalog), P033 (created the register), P034 (cross-project risk-report aggregation), P102 (register invocation surface), P110 (register passive triggers), P162 (counterfactual risk assessment for held changesets — directly adjacent on rating-quality dimension)

## Related

- `docs/problems/168-risk-scorer-doesnt-consume-catalog-or-bootstrap.open.md` — **substantive design successor**. Captures the wipe-and-bootstrap + consume-catalog implementation work that supersedes this ticket's original Phase 1-3 plan (manual R007-R011 authoring + R002/R005 extensions + R001-R006 re-rate). P167's residual scope post-correction is the policy-framing landing (done in commit `9e339d0`) + this transition; the design work lives in P168.
- `RISK-POLICY.md` — Risk Appetite section defines the 4/Low threshold; clarifying its scope (per-action vs lifetime) is part of RC3.
- `docs/risks/README.md` — register index showing all 6 residuals above appetite.
- `docs/risks/R001-confidential-info-leak-via-public-repo-push.active.md` — canonical example for RC2 control-undercrediting analysis.
- `docs/risks/TEMPLATE.md` — risk file shape; investigation task proposes adding "control composition / defense-in-depth" subsection.
- `.risk-reports/` — 181 concrete reports; the gap analysis input.
- ADR-026 (agent-output grounding) — relevant if Investigation Task on register-coverage assertion is pursued.
- Sibling gap analysis: Explore agent invoked from this ticket's parent /wr-itil:manage-problem session on 2026-05-04. Output identified 5 new risk classes (R007 register-drift, R008 orchestrator-state-drift, R009 hook-deny-UX, R010 ADR-ratification-lag, R011 ambient-state-publish), 2 risk extensions (R002 +SKILL.md structural prose, +surface-area accumulation; R005 +ADR documentation drift), and the rating-disconnect hypothesis. Realism check: 80-90% systemic-theme coverage is realistic; 100% concrete-instance coverage is not (and not desirable — instance-level micro-risks are better managed via process discipline than standing-risk registration).
- Captured via /wr-itil:capture-problem; root cause hypotheses populated inline at capture time per user request ("determine the root cause"); investigation tasks reflect the gap analysis output.
