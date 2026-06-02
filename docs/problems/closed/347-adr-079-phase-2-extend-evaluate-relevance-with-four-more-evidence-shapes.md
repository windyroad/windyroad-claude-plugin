# Problem 347: ADR-079 Phase 2 — extend `evaluate-relevance.sh` with 4 more evidence shapes + fix Phase 1 file-no-longer-exists false-positive class

**Status**: Closed
**Reported**: 2026-05-31
**Released**: 2026-05-31 (Phase 2 shipped iter 5 — 3-commit bundle in the @windyroad/itil minor release window)
**Closed**: 2026-05-31
**Priority**: 9 (Med High) — Impact: 3 (Moderate — Phase 1 covers only 1 of 5 empirically-observed shapes; 13 of today's 14 closes used shapes Phase 1 doesn't implement; the relevance-close skill currently won't surface most reasonable candidates without Phase 2) × Likelihood: 3 (Likely — every review-problems Step 4.6 invocation hits this coverage gap)
**Origin**: internal
**Effort**: L (deferred — re-rate at next /wr-itil:review-problems; multi-file: ADR-079 amendment + 4 new shapes in script + Phase 1 fix + behavioural bats per shape + SKILL Step 4.6 amendment + changeset)

## Closed as no longer relevant — duplicate of P346 (wrongly-captured sibling that should have been Phase 2 of P346)

**Closure date**: 2026-05-31 (foreground consolidation, user-directed)
**Closure reason**: duplicate-of-P346 — this ticket was a wrongly-captured sibling. The Phase 2 work it tracks IS the next slice of P346's problem-trace, not a new problem. ADR-079 was authored against P346 in iter 4; Phase 2 of ADR-079 is Phase 2 of P346 by construction.
**Evidence (per ADR-026 grounding + ADR-079 evidence-based relevance-close pass)**:
- P346 (`docs/problems/open/346-...md`) is the canonical problem-trace for ADR-079 — iter 4's commit `c5e2eb5` authored ADR-079 against P346
- P346's Description enumerates BOTH inflow and outflow structural concerns; Phase 1 (closure) shipped, Phases 2+ (evidence-shape expansion + capture-time hang-off check) are outstanding work folded into P346 on this consolidation
- User correction (verbatim, 2026-05-31): *"We didn't need a new problem ticket, there was an existing one. This is part of the issue. You keep creating new problem tickets even when there are existing ones you can hang off."* + *"What about p346?"* + *"And yes, close p347"*
- Memory `feedback_hang_off_existing_ticket_before_capturing_new` captured this lesson with the P347-vs-P346 case as the concrete example
- The Phase 2 work itself (iter 5's commits `6980e13` + `b160eb8` + `3bdd1d7` + `8c8a256`) is real implementation work and ships — only the attribution to a new ticket was wrong
- The Phase 2 commits' "P347" references stay as historical capture-surface; the audit trail still resolves via this closure pointer to P346

**Relevance evidence shape**: duplicate-of (ADR-079 Phase 2 work belongs in P346 as Phase 2 expansion, not a sibling ticket — surfaced via the user's read-the-Description-of-candidate-parent-tickets discipline that the SKILL's narrow 3-keyword title-only dup-check failed to enforce)
**Authorising decision**: P346 user direction 2026-05-31 (verbatim above). Phase 2's deliverable artefacts stay shipped (ADR-079 amended, evaluate-relevance.sh extended to 5 shapes, 33/33 bats GREEN, SKILL Step 4.6 amended, @windyroad/itil minor + patch changesets queued); only the ticket attribution moves to P346.

**Cross-reference**: see P346 `## Phase 2 — evidence shape expansion` section for the work this ticket tracked, and P346 `## Phase 3 — capture-time hang-off check` section for the mechanism designed to prevent recurrence of the wrong-attribution class.

## Description

ADR-079 Phase 1 shipped today (2026-05-31, work-problems iter 4, @windyroad/itil@0.40.0): `packages/itil/scripts/evaluate-relevance.sh` implements ONE evidence shape (`file-no-longer-exists`), wired into `/wr-itil:review-problems` Step 4.6, with 18/18 GREEN bats.

The foreground relevance-scan that ran later in the same session (5 batches, 14 closes) revealed two structural gaps in the shipped implementation:

**Gap 1 — Phase 1 covers 1 of 5 empirically-observed evidence shapes.**

Today's 14 closes broke down across 4 shapes Phase 1 does NOT implement:

| Shape | Closes using it | Mechanical check |
|---|---|---|
| 1. file-no-longer-exists | (Phase 1 — shipped) 0 of 14 in this scan | grep ticket body for `packages/...sh` / `docs/...md` refs; verify each via `ls` |
| 2. ADR-shipped-with-`human-oversight: confirmed` | 8 (P012/P015/P018/P022/P033/P039/P292/P194) | grep ticket body for `ADR-NNN` refs; for each ref, verify file exists AND frontmatter has `human-oversight: confirmed` |
| 3. named-skill-or-feature-exists | 6 (P014/P034/P045/P079/P190/P289) | grep for SKILL.md / `packages/<plugin>/...` paths in ticket body; verify each path exists |
| 4. self-marker-in-body | 1 (P289 — explicit; many sibling cases of P345) | grep ticket body for literal: `Close to (Verifying\|Closed)`, `DONE 2026-`, `fix shipped session N`, `awaiting K→V` |
| 5. driver-child-ticket-closed | contributory factor in several closes | parse ticket's `## Related` for `P<NNN>` refs; check if any are in `docs/problems/closed/` |

The Phase 1 file-no-longer-exists shape had ZERO closes in today's scan — and produced 3 false-positives out of 5 candidates in the iter-4 smoke test (60% false-positive rate). The most-shipped shape has the highest defect rate; the 4 unimplemented shapes are how the actual closes landed.

**Gap 2 — Phase 1 file-no-longer-exists shape needs 3 specific false-positive fixes.**

Smoke test post-batch-1 surfaced 5 candidates; 3 were false-positives with diagnosable causes:

- **P180** — script declared `docs/incidents/I002-...investigating.md` gone; actual file is at `docs/incidents/I002-...restored.md` (state-suffix renamed, content present). Fix: detect state-suffix variants per ADR-031 layout (`.investigating` / `.mitigating` / `.restored` / `.closed.md`).
- **P244** — script declared `plugin-maturity-list.sh` gone; sibling files `plugin-maturity-render.sh` + `plugin-maturity-populate.sh` exist (work shipped under different filename within same dir). Fix: detect sibling files via dir-glob slug-similarity.
- **P251** — script declared `docs/decisions/060-...accepted.md` gone; the ADR exists at a slug-different `*.accepted.md` path (filename slug renamed, file content present). Fix: use `git log --follow` for rename detection, OR fuzzy-match on the `<state>.md` suffix-prefix.

P091 and P242 may be true positives but the underlying class is "feature never built", not "feature removed". Phase 1 conflates these; treating an unimplemented feature as "no longer relevant" risks losing the tracking signal for outstanding work.

## Symptoms

- `/wr-itil:review-problems` Step 4.6 surfaces a narrow slice of candidates; 13 of 14 closes today happened OUTSIDE the relevance-close skill, foreground-only, via manual evidence-cite.
- Iter-4 smoke test of Phase 1 against 143 active tickets surfaced 6 CLOSE-CANDIDATE / 44 KEEP / 93 SKIP — but post-batch-1 verification showed 60% of the CLOSE-CANDIDATE set were false-positives.
- The relevance-evidence shapes that actually worked today (ADR-confirmed, skill-exists, self-marker, child-closed) are not in the evaluator's vocabulary.

## Workaround

(deferred to investigation — current workaround is the manual foreground scan pattern, which produced 14 closes today but is not codified)

## Impact Assessment

- **Who is affected**: every maintainer running `/wr-itil:review-problems`; every adopter relying on the relevance-close pass to surface stale tickets.
- **Frequency**: every review-problems invocation hits the coverage gap; every relevance-evaluation pass on a real backlog encounters the false-positive class.
- **Severity**: HIGH in aggregate — without Phase 2 the SKILL is a partial implementation that misses the dominant closure-evidence shapes; adopters' first impression of the skill will be "it doesn't surface anything useful".
- **Analytics**: 14 closes today across 5 batches = labeled fixture set; each batch's evidence-shape annotated in the commit messages + `docs/problems/closed/<NNN>-*.md` body sections.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Read today's 14 closure bodies (batch 1: P014/P034/P045/P079; batch 2: P012/P015/P018/P022/P039; batch 3: P190/P289; batch 4: P033; batch 5: P194/P292) and extract the precise grep patterns each used
- [ ] Amend ADR-079 Considered Options to add Phase 2 scope covering shapes 2-5 + Phase 1 fix; verbatim cite the labeled fixture set as evidence
- [ ] Extend `packages/itil/scripts/evaluate-relevance.sh` to implement shapes 2-5
- [ ] Fix Phase 1 shape's rename + state-suffix + sibling-file detection per the 3 named false-positives
- [ ] Add behavioural bats per new shape, calibrated against the 14 labeled fixtures
- [ ] Update `/wr-itil:review-problems` Step 4.6 SKILL prose to handle multi-shape evaluator output + surface-batch-confirm flow (the methodology that worked: surface batch → AskUserQuestion confirm → batched closure commit)
- [ ] Add caveat-handling: when a candidate has partial-scope evidence (e.g. umbrella with 1 of N phases shipped), the evaluator should recommend "close with caveat <X>" not "close clean" (see P039 shared-template caveat, P194 deep-dive bloat caveat)
- [ ] Verify the multi-phase umbrella case (P136 ADR-044 alignment audit) is correctly classified as KEEP, not CLOSE-CANDIDATE
- [ ] Verify shape coverage against the lifecycle extension (Known Error → Closed bypassing Verifying — P033 case)
- [ ] Add `@windyroad/itil` minor changeset (Phase 2 is feature work)
- [ ] Add reproduction test: synthetic backlog with N candidates per shape → assert evaluator correctly classifies each

## Dependencies

- **Blocks**: ADR-079 reaching "full Phase 2" maturity for adopter use; relevance-close skill becoming the dominant outflow mechanism for the backlog (P346 driver)
- **Blocked by**: (none — Phase 1 already shipped + 14 labeled fixtures available; can start immediately)
- **Composes with**: ADR-022 (lifecycle conventions — Phase 2 extends KE→Closed support), ADR-026 (grounding — evidence shapes must cite per ADR-026), ADR-052 (behavioural-tests-default — new bats per shape), ADR-014 (commit grain — likely 1 commit per shape, OR 1 batched commit per Phase 2 release), ADR-049 (PATH shims — `wr-itil-evaluate-relevance` already exists)

## Related

- **P346** (`docs/problems/verifying/346-review-problems-no-path-to-close-no-longer-relevant-tickets-evidence-based.md`) — Phase 1 driver; today's iter 4 shipped Phase 1 against P346.
- **ADR-079** (`docs/decisions/079-evidence-based-relevance-close-pass.proposed.md`) — Phase 1 scope; this ticket drives the Phase 2 amendment.
- **P345** — Fix-titled commits do not transition the ticket lifecycle. P289 closed today is a direct instance of the P345 class — the work shipped, the body marked "Close to Verifying", but no lifecycle transition fired. Shape 4 (self-marker-in-body) would mechanically detect this class.
- **P136** (`docs/problems/open/136-adr-044-alignment-audit-master.md`) — KEEP test fixture (umbrella with Phase 2 done, Phase 3 outstanding; correct classification is KEEP not CLOSE-CANDIDATE).
- **P303** (`docs/problems/open/303-architect-gate-deadlocks-multi-adr-changes.md`) — KEEP test fixture (no shipped evidence; recent observation).
- **P326** (`docs/problems/open/326-staged-index-cleared-after-risk-scorer-pipeline.md`) — KEEP test fixture (recent observation, no shipped evidence yet).
- **Labeled CLOSE-CANDIDATE fixtures (14 today)**: batch 1 — `docs/problems/closed/014-aside-invocation-for-governance-skills.md`, `docs/problems/closed/034-centralise-risk-reports-for-cross-project-skill-improvement.md`, `docs/problems/closed/045-auto-plugin-install-after-governance-release.md`, `docs/problems/closed/079-no-inbound-sync-of-upstream-reported-problems.md`. Batch 2 — `docs/problems/closed/012-skill-testing-harness.md`, `docs/problems/closed/015-tdd-vague-gherkin-detection.md`, `docs/problems/closed/018-tdd-enforce-bdd-example-mapping-principles.md`, `docs/problems/closed/022-agents-should-not-fabricate-time-estimates.md`, `docs/problems/closed/039-autonomous-loops-conflate-diagnose-with-implement.md`. Batch 3 — `docs/problems/closed/190-agent-designs-user-asked-classification-fields-instead-of-derive-or-eliminate.md`, `docs/problems/closed/289-broaden-and-rename-solo-developer-persona-to-developer.md`. Batch 4 — `docs/problems/closed/033-no-persistent-risk-register.md`. Batch 5 — `docs/problems/closed/194-adrs-accumulate-forward-chronology-evidence-inline-instead-of-archiving-decisions-bucket-dominates-context.md`, `docs/problems/closed/292-reconcile-adr-018-release-cadence-with-p250-lean-release-sooner-and-dogfood-location.md`. Each body carries the `## Closed as no longer relevant` section with cited evidence shape + verified file paths.

(captured via /wr-itil:capture-problem; expand at next investigation)

## Fix Released

Phase 2 shipped 2026-05-31 across 3 commits in the same release window:

- **6980e13** (Phase A) `docs(decisions): amend ADR-079 with Phase 2 (4 evidence shapes + Phase 1 false-positive fixes)` — ADR-079 Phase 2 amendment + decisions compendium regen (ADR-077 condition C1).
- **b160eb8** (Phase B) `feat(itil): P347 + ADR-079 Phase 2 — 4 more evidence shapes + Phase 1 false-positive fixes` — `packages/itil/scripts/evaluate-relevance.sh` extended Phase 1 → Phase 2 (shapes 2-5, `CLOSE-CANDIDATE-WITH-CAVEAT` + `KEEP-WITH-NOTE`, state-suffix + sibling-file + rename detection); `packages/itil/scripts/test/evaluate-relevance.bats` 18 → 33 fixtures all GREEN; `.changeset/p347-relevance-close-pass-phase-2.md` `@windyroad/itil` minor.
- **3bdd1d7** (Phase C) `docs(itil): P347 + ADR-079 Phase 2 — review-problems Step 4.6 + manage-problem lifecycle sync to 5 shapes` — `/wr-itil:review-problems` Step 4.6 prose updates (5 shapes table + surface-batch-confirm flow + caveat handling + cumulative shape field); `/wr-itil:manage-problem` lifecycle table Closed-row cited-shape list extended; `.changeset/p347-phase2-skill-prose-sync.md` `@windyroad/itil` patch.

**Architect verdict 2026-05-31**: PASS-with-conditions — C1 compendium regen ✓; C2 structured caveat ✓; A1 future-work disambiguation honoured; A2 line-anchored shape-4 regex; A3 `human-oversight:` marker absence preserved per ADR-066.

**JTBD verdict 2026-05-31**: PASS — JTBD-001/006/101 aligned; JTBD-201 cite dropped per minor observation (audit-trail served by JTBD-001 + JTBD-006).

**Behavioural second-source**: 33/33 bats GREEN. Real-backlog smoke test against labeled fixtures: P012 → `CLOSE-CANDIDATE-WITH-CAVEAT` (shapes 2 + 5 + multi-phase-mixed-progress caveat); P136 → `KEEP-WITH-NOTE` (sibling-file class); P303/P326 → `SKIP` (age gate). All match the labeled-set expectations from the 2026-05-31 foreground relevance-scan.

**Bug surfaced during implementation** (worth a sibling capture if it recurs): bash `printf "%03d" "034"` interprets leading-zero input as octal (decimal 28). Fixed in-script via `n_clean` leading-zero strip; could be a broader-script-ecosystem class if it surfaces elsewhere.

Awaiting Verifying → Closed once `@windyroad/itil` minor release lands and the relevance-close pass exercises Phase 2 shapes against the real backlog through `/wr-itil:review-problems` Step 4.6.
