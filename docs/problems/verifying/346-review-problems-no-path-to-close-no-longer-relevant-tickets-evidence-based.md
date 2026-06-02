# Problem 346: `/wr-itil:review-problems` has no path to close tickets that are no longer relevant (evidence-based, NOT age-based) — structural outflow gap drives monotonic backlog growth

**Status**: Verifying
**Reported**: 2026-05-31
**Priority**: 9 (High) — Impact: 3 × Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems; severity raised at capture per user direction "I'm worried about the trajectory")
**Origin**: internal
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; design + ADR + SKILL.md amendment + behavioural bats — likely M, possibly L if relevance-evidence taxonomy is broad)

## Multi-phase scope

This is the master ticket for the framework's backlog-flow-control mechanisms. Phase 1 ships outflow (relevance-close on file-no-longer-exists shape). Phase 2 extends outflow to 4 more evidence shapes + Phase 1 false-positive fixes. Phase 3 ships inflow discipline (capture-time hang-off check) to prevent capturing siblings when existing tickets can absorb. Phases re-open the lifecycle (Verifying → Open) when new phases land.

### Phase 1 — relevance-close pass (shipped 2026-05-31, iter 4, @windyroad/itil@0.40.0)

- Status: shipped + verified in-session
- ADR: `docs/decisions/079-evidence-based-relevance-close-pass.proposed.md`
- Script: `packages/itil/scripts/evaluate-relevance.sh`; shim `packages/itil/bin/wr-itil-evaluate-relevance`
- SKILL Step: `/wr-itil:review-problems` Step 4.6
- Bats: 18/18 GREEN on `packages/itil/scripts/test/evaluate-relevance.bats`
- Smoke test 2026-05-31 against 143 active tickets: 6 CLOSE-CANDIDATE / 44 KEEP / 93 SKIP — conservative
- Evidence shape: file-no-longer-exists (single shape; smoke-test surfaced ~60% false-positive rate from rename / state-suffix / sibling-file class — fixed in Phase 2)

### Phase 2 — evidence shape expansion + Phase 1 false-positive fixes (shipped 2026-05-31, iter 5)

- Status: shipped via wrongly-captured sibling-ticket P347 (now Closed as duplicate-of-P346); deliverable artefacts stay shipped
- Driver: empirical foreground relevance-scan today (5 batches, 14 closes) revealed 4 evidence shapes Phase 1 doesn't implement; the 1 shape Phase 1 does implement had the highest false-positive rate
- Commits (attributed to P347 historically; substance belongs to this ticket):
  - `6980e13 docs(decisions): amend ADR-079 with Phase 2 (4 evidence shapes + Phase 1 false-positive fixes)`
  - `b160eb8 feat(itil): P347 + ADR-079 Phase 2 — 4 more evidence shapes + Phase 1 false-positive fixes`
  - `3bdd1d7 docs(itil): P347 + ADR-079 Phase 2 — review-problems Step 4.6 + manage-problem lifecycle sync to 5 shapes`
- 4 new evidence shapes added to `evaluate-relevance.sh`:
  - ADR-shipped-with-`human-oversight: confirmed` (8 of today's 14 closes used this)
  - named-skill-or-feature-exists (6 of today's 14 closes used this)
  - self-marker-in-body (P289-class — explicit "Close to Verifying" in body without lifecycle transition)
  - driver-child-ticket-closed (P155-closed → P014-closeable)
- Phase 1 file-no-longer-exists fixes: state-suffix detection (P180 false-positive class) + sibling-file detection (P244 false-positive class) + rename detection via `git log --follow` (P251 false-positive class)
- Caveat-handling: `CLOSE-CANDIDATE-WITH-CAVEAT` for partial-scope cases (P039 shared-template, P194 deep-dive bloat)
- Bats: 33/33 GREEN (extended from 18 to 33 fixtures; 14 CLOSE-CANDIDATE labeled fixtures + 3 KEEP test fixtures + regression fixtures per false-positive class)
- Changesets: `.changeset/p347-relevance-close-pass-phase-2.md` (@windyroad/itil minor) + `.changeset/p347-phase2-skill-prose-sync.md` (@windyroad/itil patch)

### Phase 3 — capture-time hang-off check via subagent (DESIGN — implementation outstanding)

**Driver**: today's wrongly-captured P347 illustrated a gap in the SKILL itself. The capture-problem Step 2 3-keyword title-only duplicate check is too narrow to catch hang-off candidates (parent tickets where new work fits as a Phase / Investigation Task extension). User correction 2026-05-31 (verbatim): *"we need to have the ticket creation process do more effort in finding existing ticket to add to."*

**Architecture (user-directed: "use a subagent to avoid bias from existing context, then you probably can make it much simpler")**:

A subagent invocation avoids the main agent's session-context bias — the main agent (mid-work, with rich session context) pattern-matches existing capture flows and fails to recognise hang-off opportunities. A fresh subagent with no session context reasons cleanly about candidate parents.

**Specification**:

1. **New subagent** at `packages/itil/agents/hang-off-check.md`
   - Inputs: new capture's description + filtered candidate ticket list (`open/` + `verifying/`, mechanically pre-filtered to those sharing ≥1 ADR-NNN ref / SKILL path / file path with the description)
   - Outputs: structured verdict — `HANG_OFF: P<NNN>` (with rationale citing which candidate ticket absorbs the new scope and how) OR `PROCEED_NEW` (with rationale per candidate explaining why none absorb)
   - Spawns fresh; reads only the inputs; no session context bias
   - Same architectural pattern as `wr-architect:agent` / `wr-jtbd:agent` / `tdd:review-test` (bias-free verdicts via fresh-context subagent invocation — codified as ADR-032's 5th invocation pattern under the P346 amendment 2026-05-31)
2. **`/wr-itil:capture-problem` Step 2 amendment**
   - After the existing narrow title-only grep, run the mechanical pre-filter (cheap; bounds the input set)
   - If filtered candidate set non-empty: delegate to `wr-itil:hang-off-check` subagent
   - Act on verdict: `HANG_OFF` → halt-and-route the calling agent to amend the named ticket's body (Investigation Tasks expansion / Phase N section addition); `PROCEED_NEW` → proceed to Step 3
3. **`/wr-itil:manage-problem` Step 2 amendment** — same dispatch
4. **Behavioural bats**
   - Fixture 1 (regression for today's miss): feed the subagent P347's description + candidate set containing P346 → assert `HANG_OFF: P346`
   - Fixture 2: feed it a genuinely-new description with no real candidates → assert `PROCEED_NEW`
   - Fixture 3: subtle sibling-vs-parent case (e.g. P070 vs new report-upstream surface ticket on a different SKILL) → assert `PROCEED_NEW` with reasoned rationale

**Why a subagent (not in-SKILL checks)**: the main agent is biased by session context — it has just been working on the ADR/SKILL/script and pattern-matches existing flows ("I captured X then dispatched iter; do the same shape for Y"). A subagent invocation starts fresh, reads only the structured inputs, and reasons about candidate absorption without the bias. This collapses what would otherwise be 5+ defensive checks into "subagent reasons about absorption". Matches the project's established architectural pattern for bias-free verdicts.

**Negative regression fixture**: this very session's P347-vs-P346 case is the canonical test — if the subagent receives P347's description + P346 in the candidate set, it MUST return `HANG_OFF: P346`. Failing fixture = the SKILL is insufficient.

## Description

The `/wr-itil:review-problems` skill has no path to close tickets that have become **no longer relevant**. The only closure paths today are (a) ship a fix → Verifying → Closed, (b) Park (upstream/external block), or (c) no path at all for "this isn't worth doing", "duplicates X", "incremental optimisation on a working system", or "the thing it's about no longer exists".

The result is a structural outflow gap: capture is automatic and cheap (P078 capture-on-correction, P342 retro auto-capture, ADR-062 inbound discovery, agent-observed mid-iter friction) while close requires real work + budget (~$5-15 / ~15-30 min per iter). The system is structurally guaranteed to grow ticket counts over time. At time of capture (2026-05-31, 47 days in): 102 Open + 40 Known Error + 116 Verifying + 83 Closed + 4 Parked = 345 total; trajectory +2.82/day Active, +2.64/day Verifying, no zero ETA.

User direction at capture (verbatim, 2026-05-31): *"Ok, I'm happy for a skill executed as part of review problems that closes tickets that are no longer relevant, but not just because they are old"*

**Two hard constraints from this direction:**

1. **Executed as part of `/wr-itil:review-problems`** — not a standalone skill. The relevance-check pass becomes a step (likely Step 4.x) of the existing review-problems flow. Composes with WSJF re-rank.
2. **Evidence-based, NOT age-based** — the relevance signal MUST be observable per ADR-026 grounding. "Older than 30 days" is **not** a sufficient signal on its own. Age may be a *gating* condition (don't bother evaluating relevance on a 2-day-old ticket) but never the *closing* condition.

**Candidate "no longer relevant" evidence shapes** (deferred to investigation — full taxonomy via ADR):

- The file / function / path / symbol named in the ticket no longer exists in the codebase (git grep returns empty).
- The framework decision (ADR / RFC) the ticket depends on was superseded by a later decision.
- The observed behaviour the ticket flags is now intentional (e.g. covered by a later ADR's Decision Outcome).
- The ticket is a duplicate of another ticket (same title-keyword shape, same Description hash, same fix locus).
- The "concern" the ticket captures is no longer concerning (e.g. RISK-POLICY.md re-classification dropped it below appetite).
- The ticket is a meta-observation about a SKILL contract that has since been superseded.
- The ticket's underlying root cause was incidentally fixed by an unrelated commit (close-on-evidence pattern that worked for P334/P336).

**Out of scope at capture** (defer to design iter):

- Should the relevance pass auto-close, or surface candidates with options (close-as-stale / close-as-dup-of / close-as-wont-do / keep)?
- Should the pass run on every `/wr-itil:review-problems` invocation, or only when triggered (e.g. queue size threshold, calendar cadence)?
- Per ADR-014 governance: does each relevance-close ride its own commit, or batched?
- Audit trail: how does the closed ticket capture WHY it was closed (evidence cite)?
- Should the pass also surface Verifying tickets that have been Verifying for >N days as candidates for evidence-close (the P334/P336 pattern)?

## Symptoms

- Backlog grows monotonically (+2.82/day Active over the last 7 days; no plateau).
- 102 currently-Open tickets, many from April-May 2026, no closure pressure other than per-ticket work.
- Per-iter outflow ≤ 1 ticket; per-session capture rate often ≥ 1 (retro + correction + observation paths).
- User-perceived asymptote: even after a productive AFK loop closing high-WSJF tickets, the Active count does not drop materially.

## Workaround

(deferred to investigation — current workaround is manual close via `/wr-itil:transition-problem` from Open directly to Closed, but this is one-at-a-time and lacks an evidence-citation contract)

## Impact Assessment

- **Who is affected**: every maintainer running `/wr-itil:work-problems` or reviewing `docs/problems/README.md`; every adopter who sees the backlog as a quality signal.
- **Frequency**: every session reads the backlog; every retro adds to it; every inbound-discovery pass adds to it.
- **Severity**: HIGH in aggregate — the trajectory is unsustainable as a strategy for "get to a useful steady state". Without a structural outflow path, backlog growth is a function of usage, not effort.
- **Analytics**: 47 days of data; 345 tickets created; 25% closed; rising trend on both Active and Verifying lines per the open-problems-tracker dashboard 2026-05-31 16:26.

## Root Cause Analysis

### Investigation Tasks

Phase 1 — relevance-close pass (DONE 2026-05-31 iter 4):
- [x] Draft a relevance-evidence taxonomy ADR — ADR-079 captured
- [x] Decide auto-close vs surface-with-options — surface-with-options for Phase 1 + 1-shape conservative
- [x] Design the audit-trail contract — `## Closed as no longer relevant` body section with ADR-026 cite
- [x] SKILL.md amendment to `/wr-itil:review-problems` — Step 4.6 added
- [x] Behavioural bats coverage per ADR-052 — 18 fixtures GREEN (Phase 1) → 33 fixtures GREEN (Phase 2)
- [x] Consider integration with `/wr-itil:transition-problem` — kept; relevance-close composes with existing transition mechanism
- [x] Reproduction test — smoke test against 143 active tickets, 6 CLOSE-CANDIDATE / 44 KEEP / 93 SKIP

Phase 2 — evidence shape expansion (DONE 2026-05-31 iter 5):
- [x] Empirically catalogue evidence shapes via foreground relevance-scan — 14 closes labeled across 5 batches
- [x] Amend ADR-079 with Phase 2 Considered Options — `6980e13`
- [x] Extend `evaluate-relevance.sh` with 4 new shapes — `b160eb8`
- [x] Fix Phase 1 false-positive class (state-suffix / sibling-file / rename) — `b160eb8`
- [x] Add Phase 2 bats fixtures (regression + KEEP cases) — extended to 33/33 GREEN
- [x] Update SKILL Step 4.6 + manage-problem lifecycle table — `3bdd1d7`
- [x] Add `@windyroad/itil` minor + patch changesets — queued for next release

Phase 3 — capture-time hang-off check (DONE 2026-05-31 iter 6):
- [x] Author `packages/itil/agents/hang-off-check.md` subagent (inputs/outputs per Phase 3 spec above) — commit `89c0ea7`
- [x] Amend `/wr-itil:capture-problem` Step 2 to dispatch the subagent after mechanical pre-filter — Step 2 split into 2a (existing) + 2b (NEW dispatch) — commit `f9a7d6a`
- [x] Amend `/wr-itil:manage-problem` Step 2 to dispatch the same subagent — sub-step 2.8 added (parallel shape to 2b; JTBD-301 firewall skips plugin-user-ingestion path) — commit `f9a7d6a`
- [x] Add behavioural bats: P347-vs-P346 regression fixture (assert HANG_OFF: P346); genuinely-new fixture (assert PROCEED_NEW); subtle sibling-vs-parent fixture — `packages/itil/agents/test/hang-off-check.bats` + `test/fixtures/regression-p347-vs-p346.md` + `test/fixtures/proceed-new-genuinely-new.md` + `test/fixtures/proceed-new-subtle-sibling.md` — 32 structural assertions GREEN per ADR-052 Surface 2; behavioural execution lands under RFC-012 (promptfoo eval harness — proposed) — commit `89c0ea7`
- [x] Add `@windyroad/itil` minor changeset for the Phase 3 feature — TWO changesets (subagent + SKILL wiring; ADR-014 single-commit grain split across slices 3b + 3c) — commits `89c0ea7` + `f9a7d6a`
- [x] Codify the fresh-context-subagent architectural pattern — ADR-032 amended with 5th invocation pattern (P346 amendment, 2026-05-31) per architect issue #1 — commit `d58d408`
- [x] RFC trace per ADR-071 unconditional Problem→RFC — RFC-013 created tracing Phases 1+2+3 — commit `d58d408`
- [x] Fix architect-flagged ADR-046 mis-citation in P346 body Phase 3 section — commit `d58d408`
- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems — observed effort: L (subagent + 2 SKILL amendments + 3 bats fixtures + 32 structural assertions + 3 canonical fixture markdowns + ADR-032 amendment + RFC-013 + 2 changesets + plugin.json registration + P346 body update)

Cross-cutting:
- [ ] After Phase 3 ships, re-evaluate the trajectory chart (the dashboard at `/wr-architect:agent` accessible via `/wr-itil:list-problems`) — expected: backlog growth slows due to inflow discipline + outflow continues from Phase 1+2

## Dependencies

- **Blocks**: (none directly — but the backlog trajectory dashboard improves once this lands)
- **Blocked by**: (none — direction is pinned; design iter can start immediately)
- **Composes with**: ADR-022 (lifecycle status), ADR-026 (grounding), ADR-014 (commit grain — likely one relevance-close per commit, or one batched commit per pass)

## Related

- **P078** — capture-on-correction; one of the inflow sources.
- **P342** — retro auto-capture; the largest internal inflow source.
- **ADR-062** — inbound discovery pipeline; external inflow source.
- **P334**, **P336** — recent evidence-close-on-already-shipped-fix examples; the close pattern is already proven for a sub-class of "no longer relevant" (the fix shipped without the lifecycle close).
- **P262** — README-refresh-discipline hook; composes with the new relevance-close action (each relevance-close mutates the rankings table).
- User direction 2026-05-31 (verbatim above): scope constraints — "executed as part of review problems", "not just because they are old".
- `docs/problems/README.md` — the backlog index whose growth this gap drives.

(captured via /wr-itil:capture-problem; expand at next investigation)

## Fix Strategy

Phase 1 scope per ADR-079: auto-close on ONE evidence shape — "file no longer exists in codebase" — closest analog to P334/P336 close-on-evidence. Subsequent shapes (ADR-supersession, duplicate-of-X, "concern no longer concerning", SKILL-contract-superseded) deferred to sibling tickets per ADR-079 Phase 1 scope discipline.

Implementation surface:
- `docs/decisions/079-evidence-based-relevance-close-pass.proposed.md` — design ADR (captured via /wr-architect:capture-adr; `proposed` status, no `human-oversight: confirmed` per ADR-066 line 50 — orchestrator-level drain ratifies later).
- `packages/itil/scripts/evaluate-relevance.sh` — canonical evaluator body: age gate ≥ 7 days, file-path extraction from well-known repo subdirs, self-reference exclusion, `git ls-files --error-unmatch` existence check, structured `CLOSE-CANDIDATE` / `KEEP` / `SKIP` verdict + exit-code routing (0/1/2/3).
- `packages/itil/bin/wr-itil-evaluate-relevance` — ADR-049 PATH shim (adopter-safe; resolves canonical script via sibling lookup per RFC-009 / P317).
- `packages/itil/scripts/test/evaluate-relevance.bats` — 18 behavioural fixtures per ADR-052 (script existence + shim dispatch + usage / error / age gate / no-extractable-paths / CLOSE-CANDIDATE / KEEP / custom age gate / verdict-shape output contract).
- `packages/itil/skills/review-problems/SKILL.md` Step 4.6 — Relevance-close pass between Step 4.5 (Inbound-discovery) and Step 5 (README rewrite). Iterates open + known-error tickets, invokes the shim, batches CLOSE-CANDIDATE auto-closes into ONE commit per ADR-014 / P139 mirroring `/wr-itil:transition-problems` batch grain.
- `packages/itil/skills/manage-problem/SKILL.md` — lifecycle table Closed row extended with the ADR-079 alternative entry path (Open|Known Error → Closed bypassing Verifying when no fix was released). ADR-022 extension (not modification) per the ADR-026 line 109 precedent.
- `.changeset/p346-evidence-based-relevance-close-pass.md` — `@windyroad/itil` minor.

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| RFC-013 | proposed | P346 backlog flow control multi-phase |

## Fix Released

Phase 1 shipped in this commit (Open → Verifying via ADR-022 P143 fold-fix amendment — pre-flight checks satisfied inline; root cause + fix strategy + workaround + effort all documented in this ticket body; SKILL + script + shim + bats + changeset + manage-problem extension ride this single commit per ADR-014 single-commit grain).

- **Architect verdict** 2026-05-31: ALIGNED-WITH-NITS (must-do nit: explicit ADR-022 extension cite — done in ADR-079; minor nit: do not auto-stamp `human-oversight: confirmed` — honoured).
- **JTBD verdict** 2026-05-31: ALIGNED across JTBD-001 (under-60s review-flow served by smaller queue), JTBD-006 (AFK pre-flight surface extension; mechanical evidence not judgment-call), JTBD-101 (extensible pattern per evidence shape), JTBD-201 (audit trail preserved).
- **Behavioural second-source**: 18/18 GREEN bats fixtures.
- **Real-backlog smoke test (2026-05-31, 143 open/known-error tickets)**: 6 CLOSE-CANDIDATE (4.2%), 44 KEEP, 93 SKIP — conservative behaviour confirmed; no false-positive closes on tickets with live file references. The 6 CLOSE-CANDIDATEs (P091/P180/P242/P244/P251/P212) reference paths verified absent in `git ls-files`.

Awaiting user verification. Verification path: run `/wr-itil:review-problems` after release lands → confirm Step 4.6 fires the relevance-close pass + correctly batches the surfaced CLOSE-CANDIDATE tickets into one commit + Step 5's README refresh rides the same commit.

**Phase 3 shipped 2026-05-31 iter 6** via 3 commits per ADR-014 single-commit grain:

- **Commit `d58d408`** (governance prerequisites): ADR-032 amendment (5th invocation pattern row + "Foreground fresh-context-subagent-as-decision-arbiter variant (P346 amendment, 2026-05-31)" section) + RFC-013 (multi-phase trace per ADR-071) + P346 body ADR-046 mis-citation fix + auto-added `## RFCs` reverse-trace section.
- **Commit `89c0ea7`** (subagent + tests + changeset): `packages/itil/agents/hang-off-check.md` (read-only reviewer; HANG_OFF: P<NNN> | PROCEED_NEW verdict; JTBD-301 firewall; AFK safe-default; @jtbd JTBD-001/006/101/201 annotation) + `packages/itil/agents/test/hang-off-check.bats` (32 assertions GREEN) + 3 canonical fixture markdowns + plugin.json maturity registration + `.changeset/p346-phase-3-hang-off-check-subagent.md`.
- **Commit `f9a7d6a`** (SKILL wiring + companion changeset): `/wr-itil:capture-problem` Step 2 split into 2a (existing title-only grep) + 2b (NEW mechanical pre-filter + subagent dispatch) + `/wr-itil:manage-problem` Step 2 sub-step 2.8 (parallel shape; JTBD-301 firewall skips plugin-user-ingestion path) + `.changeset/p346-phase-3-wire-hang-off-check-into-skills.md`.

- **Architect verdict** 2026-05-31 iter 6: ALIGNED-WITH-NITS (issue #1 — codify the 5th invocation pattern, done as ADR-032 amendment; issue #2 — ADR-046 mis-citation, fixed; issue #3 — RFC trace per ADR-071, done as RFC-013).
- **JTBD verdict** 2026-05-31 iter 6: ALIGNED-WITH-NITS across JTBD-001 (60s flow budget protected via candidate-cap short-circuit), JTBD-006 (AFK safe-default: ambiguous → PROCEED_NEW), JTBD-101 (reusable fresh-context-subagent primitive), JTBD-201 (rationale + per-candidate explanation captured in audit trail), JTBD-301 firewall (maintainer-side only; plugin-user-ingestion path skipped).
- **Risk-scorer verdict** 2026-05-31: WITHIN-APPETITE on all three commits (4/25 Low across commit/push/release layers).
- **Behavioural second-source**: 32/32 GREEN bats fixtures on `hang-off-check.bats`; 3 canonical fixture markdowns documenting the expected verdict shape for promptfoo behavioural execution under RFC-012 (proposed).
- **Negative regression coverage**: the P347-vs-P346 case from this very session is the canonical fixture at `packages/itil/agents/test/fixtures/regression-p347-vs-p346.md`. If a future change regresses the subagent's verdict on this fixture, the SKILL no longer fulfils its driver.

Verification path for the user (post-release): run `/wr-itil:capture-problem` with a description carrying signals shared with an existing open/verifying parent; confirm Step 2b mechanical pre-filter surfaces the candidate, hang-off-check subagent dispatches, returns HANG_OFF: P<NNN> with rationale, and capture-problem halts with a structured directive for the orchestrator. Smoke against a known-distinct capture; confirm PROCEED_NEW + rationale appended to the new ticket's `## Related` section.

Deferred to sibling tickets per ADR-079 Phase 1 scope discipline:
- ADR-supersession evidence shape (a ticket depending on an ADR that has since been superseded by a later decision).
- Duplicate-of-X evidence shape (a ticket whose title-keyword shape / Description hash / fix locus matches another ticket).
- "Concern no longer concerning" evidence shape (RISK-POLICY re-classification dropped severity below appetite).
- SKILL-contract-superseded evidence shape (a ticket whose meta-observation about a SKILL contract has since been resolved by a contract update).
- Verifying-ticket aging surface (P334/P336-class evidence-close for Verifying tickets exercised repeatedly without regression).
