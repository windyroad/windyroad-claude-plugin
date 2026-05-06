# Problem 033: No persistent risk register for ISO 31000 / ISO 27001 compliance

**Status**: Known Error
**Reported**: 2026-04-17
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: XL — re-rated from L 2026-04-28 per architect verdict on ADR-047 phase plan; original L sized only the scaffolding slice and missed the back-channel + backfill + behavioural-test scope surfaced by user's "for each risk in .risk-reports there should be something in the register" direction.
**WSJF**: 2.25 — (9 × 2.0) / 8 → now known-error (XL effort)
**Type**: technical

## Description

The risk scorer performs per-change pipeline risk assessment against `RISK-POLICY.md` thresholds, but there is no persistent risk register — a living inventory of identified risks with owners, treatment plans, and residual risk tracking. Both ISO 31000 (general risk management) and ISO 27001 (information security) expect a risk register as a core artifact.

`RISK-POLICY.md` defines the *criteria* (impact/likelihood scales, appetite). `.risk-reports/` contains point-in-time snapshots. `docs/problems/` tracks ITIL problems. None of these is a risk register.

The user wants this kept lean — ideally a `docs/risks/` directory with one file per risk and a `README.md` index (mirroring the `docs/problems/` pattern), rather than a heavyweight spreadsheet or database.

## Symptoms

- No single place to see all standing risks, their current treatment status, and residual scores
- RISK-POLICY.md defines what to measure but not what has been measured
- ISO 31000 clause 6.4.2 (risk treatment) and ISO 27001 clause 6.1.2/6.1.3 (risk assessment / Statement of Applicability) have no backing artifact
- Pipeline risk reports in `.risk-reports/` are ephemeral — they assess a change, not a standing risk

## Workaround

Until the register is populated, risks are implicitly captured across `RISK-POLICY.md` impact examples, problem tickets, and pipeline reports. The scaffolding (directory + README + TEMPLATE) now exists — risks can be added one-by-one as they are identified; there is no requirement to populate the register exhaustively up front.

## Impact Assessment

- **Who is affected**:
  - Tech-lead persona — needs auditability; a risk register is a standard audit artifact
  - Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — governance tooling should model risk management, not just risk scoring
- **Frequency**: Every audit or compliance review; every time someone asks "what are our standing risks?"
- **Severity**: Medium — the pipeline scorer still works; the gap is in persistent risk tracking, not in per-change assessment
- **Analytics**: Identified during discussion of ISO 31000 and ISO 27001 requirements this session

## Root Cause Analysis

### Confirmed Root Cause

The risk-scorer plugin was designed for pipeline risk (per-change scoring at commit/push/release gates). A persistent risk register was never in scope — the plugin solves "is this change risky?" not "what risks does this project carry?" The absence is structural, not accidental: there is no directory, template, or skill targeting standing-risk capture.

### Investigation Tasks

- [x] Design a lean `docs/risks/` directory structure: one `.md` file per risk, `README.md` index with risk matrix summary — **Done**. Pattern mirrors `docs/problems/`: `R<NNN>-<kebab-title>.<status>.md` with status suffixes `.active.md` / `.accepted.md` / `.retired.md`. README carries the register table, retired table, ISO mapping, and relationship-to-other-artefacts diagram.
- [x] Define the risk file template: ID, title, category (ISO 27001 infosec / ISO 31000 general), inherent score, controls, residual score, owner, treatment (accept/mitigate/transfer/avoid), review date — **Done**. `docs/risks/TEMPLATE.md` documents the full field set with inherent vs residual scoring, Controls section citing implementation sources (files or ADRs), Treatment section (Accept/Mitigate/Transfer/Avoid), Monitoring triggers, and Change Log.
- [x] Decide whether risk register management belongs in the risk-scorer plugin or a new plugin — **Deferred to future work**. Current scaffolding is pure docs; no skill is needed for v1 (users add risks manually via file creation, same as ADRs). If/when automation is required, decision can be made then with a concrete use case. Not a blocker for the register to be useful.
- [x] Decide whether the risk-scorer `update-policy` skill should seed the register from RISK-POLICY.md impact examples — **No for v1**. RISK-POLICY.md "Severe" examples (e.g., "publishes packages with malicious/broken bin scripts", "leaks npm auth tokens via CI logs") are candidate risks but seeding them mechanically risks false-positives. Leave seeding manual until a curated first-pass of risks has been written; then consider automation.
- [x] Consider whether the register should be auto-populated from problem tickets — **No — inverse direction is correct**. Problems are concrete defects that may be *realisations* of standing risks; each risk's `Realised-as` section links to relevant problems. Auto-populating risks from problems would conflate the two levels. Manual curation preserves the distinction.

### Fix Strategy

Lean scaffolding only — no automation for v1:

1. Create `docs/risks/` directory
2. Create `docs/risks/README.md` as the register index with empty register/retired tables, ISO mapping, structural diagram, and "How to add/review" instructions
3. Create `docs/risks/TEMPLATE.md` documenting the risk file format
4. Leave the register empty — populate incrementally as risks are identified (same philosophy as ADRs and problems)

Future work (not in scope for this problem):
- Skill to create/review risks (analogous to `create-adr` / `manage-problem`)
- Linkage from risk-scorer pipeline reports to the register (e.g., above-appetite reports suggest candidate risks)
- ISO 27001 Statement of Applicability derived from the register

## Fix Released

Implemented 2026-04-17:
- `docs/risks/README.md` — register index with ISO 31000 / ISO 27001 clause mapping, empty register and retired tables, structural relationship diagram, and authoring/review instructions
- `docs/risks/TEMPLATE.md` — per-risk file template covering inherent risk, controls, residual risk, treatment (Accept/Mitigate/Transfer/Avoid), monitoring, related artefacts, and change log

Awaiting user verification that the scaffolding matches intent before populating the register with initial risks.

## Related

- `RISK-POLICY.md` — defines risk criteria but not the risk inventory
- `.risk-reports/` — ephemeral per-change assessments
- `docs/problems/` — ITIL problem management (similar directory-of-files pattern reused here)
- `docs/risks/README.md` — the new register index
- `docs/risks/TEMPLATE.md` — per-risk file template
- `docs/decisions/047-install-updates-scaffolds-governance-artefacts.proposed.md` — Phase 1 design ADR (this iter)
- `packages/risk-scorer/` — current risk scoring plugin; Phase 2 back-channel implementation site
- `.claude/skills/install-updates/` — Phase 1 scaffolding implementation site
- P034 (`docs/problems/034-centralise-risk-reports-for-cross-project-skill-improvement.open.md`) — centralising ephemeral `.risk-reports/` to `~/.claude/`; may share the same centralised storage infrastructure
- P102 (`docs/problems/102-no-invocation-surface-for-risk-register.open.md`) — follow-up ticket captures the deferred population mechanism. Surfaced 2026-04-22 after the user observed the register had stayed empty for 5 days in Verification Pending. P033's Fix Strategy explicitly deferred the invocation surface to "future work"; P102 is that future work made concrete.
- P110 — pipeline back-channel hint; Phase 2 consumer of ADR-047's scaffolding output

## Regression Evidence (2026-04-28 — user-surfaced verification failure)

User-directed reopen during interactive `/wr-itil:manage-problem` session. User report verbatim: *"have a look at the sibling projects that we install into. None of them have risks documented in doc/risks, so that feature isn't working"*. User confirmed *"yes, P033 is what I'm talking about"* — direct verification failure of the P033 / P102 / P110 fix triplet (all currently in Verifying).

### Sibling-project survey (2026-04-28)

Surveyed 7 adopter projects on the user's machine (those with `@windyroad/*` plugins enabled in `.claude/settings.json`):

| Project | RISK-POLICY.md | docs/risks/ scaffolded | docs/risks/*.md count | .risk-reports/ count |
|---------|---------------|------------------------|----------------------|---------------------|
| addressr-mcp | yes | NO | 0 | 32 |
| addressr-react | yes | NO | 0 | 20 |
| addressr | yes | yes (scaffolded but empty) | 0 | 37 |
| bbstats | yes | yes | 3 | 74 |
| luxury-escapes-interview | no | NO | 0 | 0 |
| very-fetching | yes | NO | 0 | 22 |
| windyroad | yes | NO | 0 | 70 |

**Aggregate**: 6/7 projects have `RISK-POLICY.md`. ALL 6 have `.risk-reports/` accumulating (per-change risk-scoring is working). Only **1/6 has populated `docs/risks/`** (bbstats with 3 risks). 4/6 don't even have `docs/risks/` scaffolded. The risk REGISTER is not getting populated despite ~285 cumulative pipeline risk reports across all six projects suggesting plenty of register-worthy events.

### Why the fix triplet hasn't closed the gap

The Verification Queue claims P033 / P102 / P110 are fixed:
- **P033** — `docs/risks/` directory + README + TEMPLATE scaffolded (passive scaffolding via `/wr-risk-scorer:create-risk` skill). But the scaffolding doesn't auto-fire on adopter projects — 4/6 don't have the directory at all.
- **P102** — `/wr-risk-scorer:create-risk` skill ships as the invocation surface. But the skill is opt-in — agents/users have to know to invoke it. No discovery path on adopter projects.
- **P110** — `RISK_REGISTER_HINT:` passive trigger from `wr-risk-scorer:pipeline` agent emits hints that should prompt register entry creation. But the hint is consumed at the orchestrator/assistant level — agents in adopter sessions either don't see it or don't act on it (every adopter session that produced a `.risk-reports/` entry was a candidate; 285 cumulative reports vs ~3 register entries = ~99% miss rate).

**The actual gap**: there is no install-updates-time scaffolding of `docs/risks/` in adopter projects, AND there is no on-pipeline-fire behavioural enforcement that creates a register entry when above-appetite residual / confidentiality / user-stated-precondition signals fire. The triplet shipped the *plumbing* but not the *trigger that actually pulls the register into existence*.

### Fix candidates

1. **Install-updates Step X**: when an adopter project has `RISK-POLICY.md` but no `docs/risks/`, scaffold the directory + README + TEMPLATE on next install-updates run. Idempotent (skip if `docs/risks/` exists). Composes-with ADR-036 (downstream OSS intake scaffold) but at a different surface.
2. **Post-pipeline-fire enforcement**: when `wr-risk-scorer:pipeline` emits `RISK_REGISTER_HINT:`, the calling skill (e.g. `/wr-risk-scorer:assess-release`, `/wr-itil:work-problems` Step 6.5, `/wr-itil:manage-problem` Step 11) MUST follow up with an explicit `/wr-risk-scorer:create-risk` invocation. Today the hint is advisory; the consumption is unenforced.
3. **Pipeline back-channel** (P110 candidate b — re-evaluate): the `wr-risk-scorer:pipeline` agent itself writes the register entry (not just hint) when above-appetite residual fires. Trades agent-side autonomy for guaranteed population. Architect-design call.
4. **Behavioural test**: a contract assertion that a session producing a `.risk-reports/` entry above appetite ALSO produces a `docs/risks/R<NNN>-*.active.md` entry within the same session. Today there is no such assertion, so the gap persists.

### Implications for P033 / P102 / P110

All three should arguably reopen alongside P033. Per ADR-022, "Verification Pending" means "fix released, awaiting user verification" — the user has now verified the fix DOESN'T work. Reverting to Known Error is the correct lifecycle move. P102 and P110 are siblings that need the same treatment for the same reason; an architect-design call decides whether to bundle the reopen-and-fix in one ticket or split.

### Next iter shape

This ticket (P033 known-error) drives the next implementation iter. Architect verdict on which fix candidate(s) to ship — lean toward (1) install-updates scaffolding (cheap, idempotent, immediate adopter-project benefit) AND (2) post-pipeline-fire enforcement (closes the trigger gap that's the root cause of the 99% miss rate). Defer (3) and (4) to follow-on iters if (1) + (2) prove insufficient.


### User direction refinement (2026-04-28, mid-investigation): 1:N report→register mapping

Verbatim user direction: *"for each risk mentioned in the .risk-reports, there should be something in the risk register"*.

This refines the fix scope and elevates **Fix candidate 3 (pipeline back-channel)** to load-bearing. The contract:

- Every `.risk-reports/<timestamp>.md` entry that identifies an inherent risk (regardless of residual classification) MUST correspond to a `docs/risks/R<NNN>-*.active.md` entry.
- The mapping is **N reports : 1 register entry** — recurring risks (e.g. "session-context-budget-exhaustion" appearing in 50+ reports across many sessions) collapse to ONE register entry that all matching reports cite.
- The register entry is the **standing-risk record**; the reports are point-in-time evidence. The register tracks the inherent/residual scoring, controls applied, and treatment decision; the reports are timestamps proving the risk has fired.
- New register entries SHOULD be created automatically by the `wr-risk-scorer:pipeline` agent when a report identifies a risk that doesn't yet have a register entry. Existing entries SHOULD have their evidence-log updated (a new "fired-on" timestamp + a citation back to the report file).

**Fix-implementation implications**:

- The P110 RISK_REGISTER_HINT mechanism is necessary but not sufficient — hints alone preserve the 99% miss rate observed in the survey. The pipeline agent itself must take action.
- Architect-design call: does the pipeline agent (a) write the register entry directly, or (b) emit a structured directive that the calling skill (`/wr-risk-scorer:assess-release`, etc.) MUST consume by invoking `/wr-risk-scorer:create-risk` before continuing? Trade-off: agent-side autonomy vs. orchestrator-side enforcement.
- The fix needs an audit step: a one-time backfill pass over existing `.risk-reports/` to identify all distinct risks (deduplicate by risk-name) and create register entries for each one. Without this, the register stays empty even after the trigger lands. The backfill is per-project (each adopter project runs it once on next session start, gated by a marker so it doesn't re-fire).
- Behavioural test (Fix candidate 4 elevation): contract assertion that every risk-id appearing in `.risk-reports/*.md` has a matching `docs/risks/R<NNN>-*.md` entry. This becomes a load-bearing test, not just a future polish item.
- Install-updates scaffolding (Fix candidate 1) remains needed for the 4/6 projects that don't even have `docs/risks/` — the back-channel can't write into a non-existent directory.

**Effort re-estimate**: original L estimate may need to inflate to XL given the new scope (back-channel + backfill + behavioural test + install-updates scaffolding + cross-plugin coordination between risk-scorer, install-updates, and any consumer skill). Architect verdict at next-iter time confirms or trims.

## Phase Plan (2026-04-28 — architect-confirmed)

Architect verdict in iter 2026-04-28 (this iter): split the XL fix into 4 phases. Phase 1 ships now; Phases 2-4 are deferred follow-up tickets/iters.

### Phase 1 — install-updates governance-artefact scaffolding

Phase 1 is itself split into Phase 1a (design, this iter) and Phase 1b (implementation, follow-up iter) because the implementation site lives under `.claude/skills/install-updates/` which the iter dispatcher's write-protection direction blocks for AFK iters.

#### Phase 1a — design ADR (THIS ITER, 2026-04-28)

- **ADR-047** (`docs/decisions/047-install-updates-scaffolds-governance-artefacts.proposed.md`) — install-updates scaffolds governance artefacts when policy file is present but artefact is missing.
- Architect-approved trigger contract: per-sibling, fires when `RISK-POLICY.md` is present AND `docs/risks/` is absent. Idempotent per-file create-if-absent. No marker.
- ADR-013 Rule 5 (consent-cached silent proceed) + Rule 6 (AFK fail-safe) audit baked in.
- Final-report integration spec'd: scaffold rows alongside install rows in Step 7 table.
- JTBD review: PASS (JTBD-001 primary fit, JTBD-006 AFK transparency, JTBD-202 audit-trail).
- Re-rate Effort L → XL committed (this iter).

#### Phase 1b — install-updates SKILL.md + templates + bats test (LANDED, iter 18, 2026-05-03)

Implementation site is `scripts/repo-local-skills/install-updates/` (per P139 — source-of-truth lives outside `.claude/`, with relative symlinks at `.claude/skills/install-updates/`). ADR-047's `.claude/skills/...` paths predate the P139 relocation; semantically equivalent because the symlinks resolve transparently.

Files landed:

- `scripts/repo-local-skills/install-updates/SKILL.md` — new "Step 6.5: Scaffold governance artefacts (per-sibling)" between Step 6 (Install) and Step 7 (Final report). Trigger contract: `RISK-POLICY.md` present AND `docs/risks/` absent → scaffold both files. Per-file create-if-absent — never overwrite. ADR-013 Rule 5/6 audit baked in. Step 7 final-report shape grows scaffold rows alongside install rows.
- `scripts/repo-local-skills/install-updates/templates/risk-register-README.md.tmpl` — adopter-flavoured (no R001 row, no "Last reviewed" date). ISO 31000 / 27001 mapping preserved. Empty register + retired tables.
- `scripts/repo-local-skills/install-updates/templates/risk-register-TEMPLATE.md.tmpl` — verbatim copy of this repo's `docs/risks/TEMPLATE.md`.
- `scripts/repo-local-skills/install-updates/REFERENCE.md` — new "Governance-artefact scaffold (P033)" section with deep context: why install-updates is the trigger surface, full trigger contract, idempotency rationale (no-marker), ADR-013 audit table, template source-of-truth, template-drift mitigation, Phase-1-only scope.
- `scripts/repo-local-skills/install-updates/test/install-updates-p033-register-scaffold.bats` — 11 behavioural-fixture tests against mock adopter directories (per ADR-052). Asserts scaffold + skip-existing + RISK-POLICY-absent + partial-state + idempotency + ISO-clause-survival. All pass; no regressions in the 47 prior tests.

Closes the "directory doesn't exist" half of the 99% miss rate. Surveyed 4/6 adopters benefit on next install-updates run after Phase 1b ships and the marketplace cache refreshes.

**Phase 1 does NOT close P033 — only the scaffolding precondition lands.** Master ticket remains Known Error pending Phase 2 (back-channel; load-bearing per user direction). Phase 2 is the next iter shape.

### Phase 2 — pipeline back-channel (load-bearing per user direction)

Phase 2 is split into Phase 2a (queue-write, this iter — LANDED) and Phase 2b (drain steps in consumer skills — deferred).

#### Phase 2a — agent emits, hook queues (LANDED iter 19, 2026-05-03 — ADR-056)

Architect-design call resolved: **agent emits, hook queues, calling skill drains** (ADR-056 Option 4 queue-and-drain). Rejected alternatives: agent-side write (violates `Read, Glob`-only purity), direct hook-write to `docs/risks/` (workspace-delta BLOCKER per ADR-014 + ADR-016 — files would drift forward through unrelated commits).

Files landed iter 19:

- `docs/decisions/056-risk-register-back-channel-write-contract.proposed.md` — sub-ADR (Phase 2 of multi-phase fix). Specifies queue-and-drain shape, 3-column hint format, dual-parse contract (3-col preferred + 2-col legacy fallback), pending-review entry treatment via ADR-026 sentinel, Phase 3 backfill explicitly out-of-scope.
- `packages/risk-scorer/agents/pipeline.md` — `Risk Register Hand-Off` section extended. 3-column hint format `<reason-tag> | <risk-slug> | <prose>`. Slug-computation rules added. Dual-parse compatibility note for in-flight prompt caches.
- `packages/risk-scorer/hooks/risk-score-mark.sh` — pipeline-handler block extended with `RISK_REGISTER_HINT:` parse-and-append section. Appends one JSONL line per valid bullet to `.afk-run-state/risk-register-queue.jsonl` (gitignored). Dual-parse handling (3-col + 2-col fallback). Best-effort error handling. Silent on stdout (ADR-045 Pattern 2).
- `packages/risk-scorer/hooks/test/risk-score-mark-register-queue.bats` — 12 behavioural-fixture tests covering 3-col path, 2-col legacy path, mixed-shape, silence semantics, malformed-bullet skip, append-only semantics, directory creation, ADR-045 Pattern 2 silent-on-success. All GREEN. No regression in adjacent suites (17/17 in `risk-score-mark.bats` + `risk-scorer-register-hint.bats`).

What Phase 2a does: every pipeline run that emits a `RISK_REGISTER_HINT:` block enqueues a register entry to `.afk-run-state/risk-register-queue.jsonl`. The queue is the durable artefact bridging pipeline-fire → register-population. No `docs/risks/R<NNN>-*.md` files are written by the hook directly — that responsibility moves to Phase 2b drain steps.

What Phase 2a does NOT do: drain the queue to materialise actual register files. Adopters running Phase 2a-only see queue-file growth but no `docs/risks/` population. P033 status remains Known Error pending Phase 2b.

#### Phase 2b — consumer-skill drain steps (PARTIAL — work-problems Step 6.4 LANDED iter 20, 2026-05-03)

**Iter 20 progress (2026-05-03)**: shared drain script + first consumer wired up.

Files landed iter 20:

- `packages/risk-scorer/scripts/drain-register-queue.sh` — canonical drain script (bash + python3). Reads `.afk-run-state/risk-register-queue.jsonl`, dedupes by `risk_slug`, writes `docs/risks/R<NNN>-<slug>.active.md` from a fixed shape with `Status: Active (auto-scaffolded — pending review)` + ADR-026 sentinel `not estimated — no prior data` for ungrounded scoring fields + `Curation: pending review` field, appends Evidence Log to existing slug matches, updates `docs/risks/README.md` Register table with em-dash stub rows, stages writes via `git add`, truncates queue on success. Dual-source ID (local-max + origin-max +1) per ADR-019.
- `packages/risk-scorer/bin/wr-risk-scorer-drain-register-queue` — `bin/`-on-`$PATH` shim per ADR-049 naming grammar. Two-line `exec "$(dirname "$0")/../scripts/drain-register-queue.sh" "$@"`.
- `packages/risk-scorer/package.json` `files` array — added `"scripts/"` so the canonical script ships in the npm tarball (ADR-049 packaging requirement). Sibling-finding: itil's `files` array has the same gap (its existing `bin/wr-itil-*` shims exec into `../scripts/` which isn't shipped); requires its own ticket / iter to fix.
- `packages/risk-scorer/scripts/test/drain-register-queue.bats` — 16 behavioural-fixture tests per ADR-052: shim resolution, empty-queue no-op, missing-`docs/risks/` no-op, single-hint creation, README-row-append, multi-hint dedupe, two-slug sequential IDs, existing-match Evidence Log append, queue-truncation contract, no-truncate-on-no-op, stdout key=value shape, file-staging contract, origin-max collision avoidance (ADR-019), malformed-line skip. All GREEN.
- `packages/itil/skills/work-problems/SKILL.md` — new `### Step 6.4: Drain risk-register queue (per ADR-056 Phase 2b)` between Step 6 (Report progress) and Step 6.5 (Release-cadence check). Step 6.4 invokes the shim, parses key=value output, commits via standard ADR-014 commit-gate flow when `next_action=commit-staged`. Step 6 progress-report template extended with `Risk register: N entries scaffolded (pending review)` line per JTBD-006 outcome 4 (auditability of AI-assisted work).

**Effect**: every AFK work-problems iter that produces a pipeline `RISK_REGISTER_HINT` now materialises register entries before the next iter starts. Queue size is bounded per-iter. Phase 1 scaffolding precondition (ADR-047, landed iter 18) gates the drain — adopters without `docs/risks/` see queue accumulation, awaiting install-updates next-run scaffold.

**Phase 2b remaining (deferred to subsequent iters)**:
- `/wr-itil:manage-problem` Step 11 drain (pre-commit) — fires on synchronous problem-management sessions.
- `/install-updates` Step 6.6 drain (after Step 6.5 scaffold) — closes the loop where Phase 1 just landed and Phase 2 hints have queued in the same install pass.
- `/wr-risk-scorer:assess-release` drain (pre-release-decision) — fires when release-time pipeline run hints accumulate.

The shared `wr-risk-scorer-drain-register-queue` shim is the single integration surface — each remaining consumer skill needs one new step block invoking the shim plus the same key=value parse / commit pattern.

#### Phase 2b — consumer-skill drain steps remaining

Each remaining consumer skill that fires after a pipeline run gains a Step-N drain that:

1. Reads `.afk-run-state/risk-register-queue.jsonl`.
2. Groups lines by `risk_slug` (dedupe — N reports : 1 register entry per user direction).
3. Per unique slug: writes new `docs/risks/R<NNN>-<slug>.active.md` from template (with `not estimated — no prior data` ADR-026 sentinel for stubbed scoring fields, `Status: Active (auto-scaffolded — pending review)`, `**Curation**: pending review`) OR appends Evidence Log entry to existing match.
4. Updates `docs/risks/README.md` Register table.
5. Single `docs(risks): scaffold R<NNN> ... (N entries from queue)` commit per ADR-014.
6. Truncates the queue file.

Drain-step targets (each its own per-skill-grain commit):
- `/wr-itil:work-problems` Step N drain (post-iter or post-loop)
- `/wr-itil:manage-problem` Step 11 drain (pre-commit)
- `/install-updates` Step 6.6 drain (after Step 6.5 scaffold)
- `/wr-risk-scorer:assess-release` drain (pre-release-decision)

Shared library (e.g. `packages/risk-scorer/lib/drain-register-queue.sh`) likely the right factoring — single source of truth, multiple invocation surfaces.

#### Phase 2 acceptance (post Phase 2b)

Every `.risk-reports/<timestamp>.md` produced after Phase 2b ships has a matching `docs/risks/R*-<slug>.active.md` entry within the next consumer-skill invocation.

### Phase 3 — backfill (deferred)

- One-time pass per adopter project: enumerate distinct risks across existing `.risk-reports/*.md`; create register entries for each.
- Per-project marker (`.claude/.risk-register-backfill-done`) gates re-fire.
- Run-shape options:
  - As an `/install-updates` Step 6.6 (if scaffolding fired AND backfill marker absent).
  - As a `/wr-risk-scorer:backfill-register` on-demand skill.
  - Architect call deferred.
- Acceptance: bbstats-style ~3 risks materialise per surveyed adopter on first run; subsequent runs skip via marker.

### Phase 4 — behavioural contract test (deferred)

- Test asserts: every distinct `risk-id` (or risk-name canonicalisation) in `.risk-reports/*.md` corresponds to a `docs/risks/R<NNN>-*.active.md` or `.accepted.md` entry.
- Lives in the risk-scorer plugin's test suite; runs on every `assess-release` / `assess-wip` invocation as a sanity check.
- Failure mode: warn-with-list, not hard fail (would block legitimate work); above-appetite reports without register entries upgrade to deny.
- Acceptance: pre-Phase-2 baseline is 99% miss rate; post-Phase-2 + Phase-3 backfill should drop to <5% miss rate within a steady-state 30-day window.

### Phase ordering rationale

- Phase 1 (scaffolding) is the precondition for Phase 2 (back-channel can't write into a non-existent directory) and Phase 3 (backfill needs the directory). Must land first.
- Phase 2 is the load-bearing fix per user direction. Highest priority once Phase 1 is in place.
- Phase 3 closes the historical gap (pre-Phase-2 reports without register entries). Lower priority than Phase 2 but blocks Phase 4's contract assertion (backfill must complete before contract can pass).
- Phase 4 enforces the contract. Last because it depends on Phases 2+3 to materialise the entries it asserts.

### Out of scope for P033 entirely

- Sibling skill `/wr-risk-scorer:scaffold-register` (on-demand surface). Not needed if install-updates trigger covers the use case. Add only if user demand surfaces.
- Multi-language register templates. Out of scope.
- Generalised `policy-file → directory-scaffold` registry covering ADR / JTBD / style-guide / voice-tone surfaces. Possible follow-up ADR if Phase 1 pattern proves out across multiple policy-file → directory pairs.

