# Problem 158: ADR-051 Phase 1 detector shipped but not wired into run-retro Step 2b

**Status**: Closed
**Closed**: 2026-05-04 (P159 Phase 1 commit migrated the primary consumption surface to PreToolUse:Bash hook; retro Step 2b wiring shipped under `df47ad1` survives as a backup advisory per ADR-051 amended Confirmation criterion 5. The mechanism this ticket asserted is in place and operational; the architectural direction has shifted to load-bearing-from-the-start at commit time, but the retro wiring is still live as a backup signal so the design intent for which P158 was filed is met. See ADR-051 amendment 2026-05-04 for the supersession-as-primary lifecycle decision and the architect verdict that endorsed Closed over re-Open.)
**Reported**: 2026-05-03
**Priority**: 12 (High) — Impact: Significant (4) x Likelihood: Possible (3)
**Effort**: S — wiring the existing `wr-retrospective-check-readme-jtbd-currency` shim into `/wr-retrospective:run-retro` Step 2b. The detector + bin shim + bats fixtures already ship per [ADR-051](../decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md) Phase 1 Confirmation criteria 1-3. The only deferred work is the SKILL.md amendment ADR-051 Confirmation criterion 5 explicitly named ("wiring into `/wr-retrospective:run-retro` Step 2b is deferred to a follow-on iter once the detector is empirically validated against current READMEs").

**WSJF**: (12 × 1.0) / 1 = **12.0**

> Surfaced 2026-05-03 by user during pre-audit docs-currency sweep. Agent (this session, parent of `8df1692`) hand-authored the retroactive ADR-051 README refresh across 12 plugin READMEs without first checking whether the structural mechanism that should have detected the drift was actually wired up. User correction (P078 capture-on-correction): *"did you just manually update all the risks and readme's, or did you fix the problems that was preventing them from being updated and created?"*. Investigation revealed the detector + bin shim are shipped (`packages/retrospective/scripts/check-readme-jtbd-currency.sh` + `packages/retrospective/bin/wr-retrospective-check-readme-jtbd-currency`) and exit-0-always advisory; the gap is the run-retro Step 2b wiring that ADR-051 Confirmation criterion 5 deferred. Audit baseline: detector run on the post-refresh tree reports `TOTAL packages=12 with_jtbd=12 drift_instances=1` (single residual: `retrospective` package skill-inventory-drift). Pre-refresh: detector would have reported `with_jtbd=0 drift_instances ≥ 12`.

## Description

ADR-051 ships in three confirmation phases:

1. Detector script + bin shim + behavioural bats fixtures (Phase 1 deliverable).
2. `@windyroad/retrospective` minor-bump changeset documenting the new advisory (Phase 1 deliverable).
3. Wiring into `/wr-retrospective:run-retro` Step 2b so the detector runs every retro and surfaces drift in the retro summary (Phase 1 follow-on per Confirmation criterion 5 — *"the detector ships as an invocable bin command; wiring into `/wr-retrospective:run-retro` Step 2b is deferred to a follow-on iter once the detector is empirically validated against current READMEs"*).

Phase 1 deliverables 1 + 2 landed under [P152](152-no-pressure-or-nudge-for-documentation-currency.verifying.md)'s parent fix. Phase 1 deliverable 3 was filed as an explicit follow-on and has not landed. Concrete consequence observed in this session: the user discovered drift had accumulated to 12 instances across 12 plugin READMEs at audit-prep time. The detector was capable of catching it; nothing was running the detector. The retroactive content refresh in `8df1692` closed the baseline; without the Step 2b wiring, the next audit cycle will encounter the same drift accumulation pattern.

## Symptoms

- `git ls-files packages/retrospective/scripts/check-readme-jtbd-currency.sh` returns the path (the detector exists).
- `git ls-files packages/retrospective/bin/wr-retrospective-check-readme-jtbd-currency` returns the path (the bin shim exists; resolves on `$PATH` per ADR-049).
- `wr-retrospective-check-readme-jtbd-currency` exits 0 and emits the documented signal vocabulary.
- `grep -n "check-readme-jtbd-currency" packages/retrospective/skills/run-retro/SKILL.md` returns no matches — the detector is not invoked from the retro skill.
- Recent retro summaries (`docs/retros/2026-05-*-iter.md`) do not include README JTBD drift findings — confirming the detector has not been running in retro contexts.
- ADR-051 audit on 2026-05-03 found ≥ 12 drift instances across 12 plugin READMEs; the user surfaced the gap at audit-prep time, not at retro time, because no retro had run the detector.

## Workaround

Manual: invoke `wr-retrospective-check-readme-jtbd-currency` ad-hoc before retros, releases, or audits and resolve drift findings by hand. The retroactive ADR-051 refresh in `8df1692` used this path. Manual invocation is not a long-term fix — it is the absence of the Phase 1 follow-on wiring.

## Impact Assessment

- **Who is affected**: the **plugin-user persona** (`docs/jtbd/plugin-user/persona.md` / [JTBD-302](../jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md)); every adopter reading any `@windyroad/*` plugin's README. Sibling impact on the **plugin-developer persona** ([JTBD-101](../jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md) — "clear patterns, not reverse-engineering" outcome is degraded when contributors must reverse-engineer runtime behaviour from prose-stale READMEs).
- **Frequency**: every retro that does NOT invoke the detector — currently every retro. Drift accumulates between retros at the rate of plugin-source change × the rate of README hand-refresh, with the former generally exceeding the latter.
- **Severity**: Significant — README drift is the audit-day failure mode the user just experienced. Treated as Impact 4 in the parallel risk-register entry R005.
- **Likelihood**: Possible — the detector exists; the wiring is small; the only reason this gap persists is that it was deferred per ADR-051's Phase 1 staging.
- **Analytics**: detector output on the post-`8df1692` tree: `TOTAL packages=12 with_jtbd=12 drift_instances=1`. Pre-`8df1692` tree (reconstructable): `with_jtbd=0 drift_instances ≥ 12`. The 12-fold difference is the audit-prep manual closure that this ticket's fix would have caught at retro time without manual intervention.

## Root Cause Analysis

### Preliminary Hypothesis

The deferral was deliberate per ADR-051 Confirmation criterion 5 — the rationale was "once the detector is empirically validated against current READMEs". The retroactive ADR-051 refresh in `8df1692` IS that empirical validation: the detector ran cleanly on the post-refresh tree and produced a single legitimate `drift_instance` (`retrospective` skill-inventory-drift). The empirical-validation precondition is now met; the deferred wiring becomes actionable.

### Confirmed Root Cause

ADR-051 Phase 1 deliverable 3 (run-retro Step 2b wiring) was filed as a follow-on iter but never picked up. Phase 1 deliverables 1 + 2 (detector + changeset) landed under P152; deliverable 3 had no carrier ticket until this one.

### Investigation Tasks

- [x] Confirm detector + bin shim are shipped (`git ls-files` matches found 2026-05-03)
- [x] Confirm wiring is absent (`grep -n "check-readme-jtbd-currency" packages/retrospective/skills/run-retro/SKILL.md` returns no matches 2026-05-03)
- [x] Confirm empirical-validation precondition met (`8df1692` detector run reports `drift_instances=1`)
- [x] Wire the detector into run-retro Step 2b as a JTBD currency advisory sub-section (shipped in `df47ad1` / `@windyroad/retrospective@0.16.0`)
- [x] Fix the residual `retrospective` skill-inventory-drift (one-line README addition shipped in `df47ad1`; detector now reports `drift_instances=0`)
- [ ] File a sibling ticket for JTBD-index drift (`docs/jtbd/README.md` vs files-on-disk) — out of scope here

## Fix Strategy

Add a new sub-section to `/wr-retrospective:run-retro` Step 2b labelled "JTBD currency advisory (ADR-051 Phase 1)" that:

1. Invokes `wr-retrospective-check-readme-jtbd-currency` non-interactively (advisory; exit 0 always).
2. Parses the `TOTAL packages=<N> with_jtbd=<M> drift_instances=<K>` line.
3. When `drift_instances == 0`: emits a one-line "JTBD currency advisory: clean (N packages)" to the retro summary's Pipeline Instability section.
4. When `drift_instances ≥ 1`: emits the full per-package drift table to the retro summary's Pipeline Instability section, with each affected package's `drift_hints` enumerated. Per ADR-013 Rule 6, the user reviews on return and tickets via `/wr-itil:manage-problem` per accepted finding (same trust-boundary shape as the existing Step 2b interactive-or-AFK pattern).
5. Failure mode: if the detector exits non-zero (parse error, missing dirs), log the failure to the retro summary but do NOT halt the retro — same fail-open contract as Step 3's `check-briefing-budgets.sh` defensive trip.

Sibling structural concern (filed as a separate follow-on, not in this ticket's scope): the JTBD index drift (`docs/jtbd/README.md` was missing JTBD-007 + JTBD-302 entries despite the files existing on disk) is not detected by ADR-051's detector. ADR-051 covers plugin-README → JTBD-file currency; it does NOT cover JTBD-index → JTBD-file currency. A sibling detector or an extension to the existing one is the structural fix; this ticket scopes the run-retro wiring only.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — Phase 1 deliverables 1+2 are shipped and the empirical-validation precondition is met)
- **Composes with**: P152 (parent ticket — verifying), R005 (the standing risk this ticket's fix mitigates)

## Related

- [ADR-051](../decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md) — Confirmation criterion 5 names this ticket's scope verbatim.
- [P152](152-no-pressure-or-nudge-for-documentation-currency.verifying.md) — parent ticket; landed Phase 1 deliverables 1 + 2.
- R005 — standing risk this ticket's fix mitigates; treatment text explicitly cites Phase 2 escalation as future work.
- [ADR-013 Rule 6](../decisions/013-structured-user-interaction-for-governance-decisions.proposed.md) — non-interactive fail-safe; the wiring's interactive-or-AFK branch follows the same shape Step 2b's existing categorical detection uses.
- [ADR-040](../decisions/040-session-start-briefing-surface.proposed.md) — declarative-first / advisory-then-escalate pattern; the wiring is advisory-only in Phase 1.
- [ADR-014](../decisions/014-governance-skills-commit-their-own-work.proposed.md) — single-commit grain; the wiring + the `retrospective` README skill-inventory-drift fix + the changeset land in one commit.
- [ADR-021](../decisions/021-changesets-for-releases.proposed.md) — changeset required because `packages/retrospective/skills/run-retro/SKILL.md` is publishable surface (SKILL.md is NOT in the changeset-discipline allow-list per `packages/itil/hooks/lib/changeset-detect.sh`).
- [JTBD-302](../jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md) — primary served job (the README's currency contract).
- [JTBD-007](../jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md) — currency expansion this serves (code-currency → README-content-currency per ADR-051).
- [JTBD-101](../jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md) — composition driver (clear patterns for contributors).
- [P074](074-run-retro-does-not-notice-pipeline-instability.closed.md) — parent of Step 2b's existence; this ticket extends Step 2b's advisory surface with one more sub-section.

## Fix Released

Released in `@windyroad/retrospective@0.16.0` (commit `df47ad1` shipped via release PR #111, merged at `d944388`). Awaiting user verification.

**Verification path**: run `/wr-retrospective:run-retro` in any session against this repo (or any adopter project that has installed `@windyroad/retrospective@0.16.0` and refreshed via `/install-updates`). The retro summary's Pipeline Instability section should now contain a `JTBD currency advisory: clean (12 packages)` line (or a per-package drift code block + advisory failure log when applicable). Confirm the line appears as expected and close the ticket with `/wr-itil:transition-problem 158 close`.

**Exercise evidence (this session)**:

- `wr-retrospective-check-readme-jtbd-currency` post-`8df1692`: `TOTAL packages=12 with_jtbd=12 drift_instances=1` (residual `retrospective` `skill-inventory-drift`).
- `wr-retrospective-check-readme-jtbd-currency` post-`df47ad1` (this fix): `TOTAL packages=12 with_jtbd=12 drift_instances=0` (clean).
- SKILL.md amendment lands the wiring at the documented Step 2b insertion point per ADR-051 Confirmation criterion 5.
- `@windyroad/retrospective@0.16.0` published to npm registry without partial-publish failures (release:watch reported "Release complete").

## Change Log

- 2026-05-03: Initial filing. Driven by user correction during pre-audit docs-currency sweep — agent hand-authored the retroactive refresh in `8df1692` without first checking whether the structural mechanism was wired. Fix scope: SKILL.md amendment + `retrospective` README skill-inventory-drift fix + changeset + commit per ADR-014. Empirical-validation precondition met by `8df1692`'s detector run (`drift_instances=1`).
- 2026-05-03: Fix released in `@windyroad/retrospective@0.16.0` (commit `df47ad1`). Open → Verification Pending. Detector run on post-fix tree reports `drift_instances=0`. Awaiting user verification.
