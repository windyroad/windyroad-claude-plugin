# Problem 129: P079 inbound assessment pipeline lacks version-aware classification — already-fixed-in-newer / recurred / still-active branches

**Status**: Open
**Reported**: 2026-04-26
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: L — assessment-pipeline classifier extension + recurrence-class lifecycle semantics + integration with closed-ticket history search + bats coverage. Marginal estimate.
**WSJF**: 1.5 — `(12 × 1.0) / 4 = 3.0` marginal; transitive `(12 × 1.0) / max(L=4, P038=XL=8, P064=L=4, P079=L=4, P128=L=4) = 12 / 8 = 1.5` via P038 (P079's parent transitive blocker propagates through). Records the transitive value per ADR-022 / P076. <!-- transitive: L (marginal) → XL (transitive) via P038 (chained through P079) -->
**Type**: technical

## Description

P079 (`docs/problems/079-no-inbound-sync-of-upstream-reported-problems.open.md`) ships an assessment pipeline that processes each inbound report through JTBD-alignment + dual-axis risk evaluation + safe-and-valid / above-threshold / clear-malicious paths (per the 2026-04-26 user direction recorded in P079's "User direction (2026-04-26 interactive AskUserQuestion resolution)" section). The pipeline as currently scoped does NOT include a **version-comparison step** that asks two cross-cutting questions before opening a fresh local problem ticket:

1. **Has this bug already been fixed in a newer version of our plugin than the reporter is on?** If so, the right action is "upgrade to vX.Y.Z" pushback, not opening a new local ticket. Without this branch, the pipeline opens duplicate tickets for issues already shipped fixed.
2. **Did we previously close a ticket against this same bug shape, but the bug surfaced again in a newer version?** That's a regression — the right action is to link the new report to the prior closed ticket, mark it as a recurrence, and route through a recurrence-handling path that surfaces the regression to the maintainer for re-investigation.

Today (and as P079 is currently scoped) the pipeline treats every inbound report as a fresh problem candidate. It does not consult the local closed-ticket history. It does not compare reporter-claimed-version against shipped-version. It does not detect recurrence shape against historical fix bodies.

User direction (2026-04-26, verbatim): *"hey, I just remembered for the reporting upstream, it needs to include version information if it doesn't already and then when we are receiving problems from downstream, we need to consider if the issue has already been fixed in a newer version or if it's recouured in a newer version, etc"*. This ticket captures the **inbound half** — what the receiving pipeline does with version info on a report. The **outbound half** (what reports carry as version info) is captured separately as P128 (companion ticket; strict block per the dependency direction).

This ticket is the **second carve-out from P079**, mirroring the carve-out shape P123 (blocked-user list) established. Like P123, P129 is pre-implementation scope-shaping on a parent (P079) that has not yet shipped. Carving here avoids retrofitting documentation onto a landed implementation.

## Symptoms

- **Already-fixed leak**: a downstream adopter on `@windyroad/itil@0.18.0` files a report describing a bug that's already fixed in `@windyroad/itil@0.20.0`. Pipeline (as currently scoped) opens a fresh local ticket. Maintainer triages, discovers the duplication, closes the new ticket, replies to reporter telling them to upgrade. Net friction: one wasted local ticket + one round-trip + one closed ticket cluttering the closed-ticket history.
- **Recurrence-class invisibility**: a downstream adopter on `@windyroad/itil@0.21.0` files a report whose bug shape matches a closed ticket against `@windyroad/itil@0.15.0`. Pipeline (as currently scoped) opens a fresh local ticket as if it were a new issue. The link to the prior closed ticket is missed; the regression analysis ("what did we change between 0.15.0 and 0.21.0 that could have brought this back?") doesn't fire because the maintainer has no ambient signal that this is a regression.
- **Triage skew**: maintainer's WSJF ranking treats every inbound report as Likelihood-Likely (4) by default. Without the recurrence-vs-net-new distinction, regressions don't get the priority bump they warrant (regressions are higher-likelihood-of-recurrence than net-new bugs because the underlying surface has a known-fragile history).
- **Audit trail gap**: closing a ticket as "duplicate of already-fixed-in-vN" by hand each time is policy-by-discipline, not contract. Different sessions handle the same shape inconsistently.

## Workaround

Maintainer, before opening a local ticket from an inbound report, manually:
1. Reads reporter's claimed version (today: from a freeform `environment` textarea, often missing).
2. Greps `docs/problems/*.closed.md` for similar bug-shape descriptions.
3. Cross-references the closed ticket's released-fix-version (today: usually a commit SHA in `## Fix Released`, requires manual lookup of which package version that SHA shipped in).
4. Compares against reporter's version. Three branches:
   - Reporter's version < first-fix-version → upgrade pushback.
   - No matching closed ticket OR reporter's version ≥ first-fix-version → open a fresh ticket.
   - Reporter's version ≥ first-fix-version AND a matching closed ticket exists → recurrence; manually link.

Error-prone, slow, doesn't scale beyond a single maintainer, and the comparison step requires the reporter's version to actually be present in the report (which P128 closes).

## Impact Assessment

- **Who is affected**:
  - **plugin-user (`JTBD-301` — get heard upstream)**: receives wrong response when their issue is already fixed (a fresh ticket eventually closed, instead of an immediate upgrade pointer). Latency to resolution extends; clarity drops.
  - **plugin-developer (`JTBD-101` — extend the suite)**: sees the same regression-class issues appearing without recurrence framing; spends investigation effort re-deriving root causes that prior closed tickets already documented.
  - **tech-lead (`JTBD-201` — restore service fast with audit trail)**: regression detection is invisible until manual cross-reference; audit trail loses the "this came back" signal needed for post-incident root-cause analysis. Critical when a regression precedes a production-class incident.
  - **solo-developer (`JTBD-001` — governance without slowing down)**: every inbound report requires manual closed-ticket-history grep and version-comparison work the assessment pipeline could automate.
- **Frequency**: every inbound report. Scales with adoption.
- **Severity**: Moderate (3) — non-catastrophic but systemic friction that compounds with closed-ticket-history depth. Higher leverage as the closed-ticket history grows; today the suite has ~70 closed tickets, growing weekly.
- **Likelihood**: Likely (4) — no enforcement today; the user's direction explicitly named both branches as missing. Every report passes through this gap.
- **Analytics**: N/A today. Post-fix candidate metrics: (1) percentage of inbound reports classified as already-fixed-in-newer (proxy for upgrade-pushback efficiency), (2) percentage classified as recurrences (proxy for regression-detection coverage), (3) maintainer time-per-inbound-report (qualitative).

## Root Cause Analysis

### Structural

P079's user-direction (2026-04-26) named the assessment pipeline's required steps:

1. JTBD alignment classifier
2. Risk assessment of the request itself (info-extraction / backdoor / malicious-code)
3. Risk assessment of fixing the reported problem
4. Above-threshold path → pushback comment (P064-gated risk + P038-gated voice-tone)
5. Clear-malicious path → close + add to blocked-user list (P123 carve-out)
6. Safe-and-valid path → create local problem ticket + acknowledgement comment

**No step in this list compares the reporter's version against shipped fixes.** Step 6 unconditionally creates a local ticket. The pipeline as scoped is "either malicious / above-threshold / safe-and-valid" — no fourth axis for "safe-and-valid BUT already fixed" or "safe-and-valid AND a regression of a prior fix".

The closed-ticket-history (`docs/problems/*.closed.md`) carries fix-release information in `## Fix Released` sections (per ADR-022) — release marker (version, commit SHA, or date) + fix summary. That data is the parse surface a version-aware classifier would need; today nothing reads it programmatically.

### Why it wasn't caught earlier

P079's interactive direction-pin (2026-04-26) focused on the malicious-vs-safe binary because the user's primary concern at that moment was attack-surface filtering (info-extraction, backdoor requests, malicious-code injection). The version-comparison axis is a different kind of filtering — it's about historical context, not adversarial intent — and didn't surface in the same direction round.

The user remembered the concern on 2026-04-26 (verbatim): *"hey, I just remembered ... when we are receiving problems from downstream, we need to consider if the issue has already been fixed in a newer version or if it's recouured in a newer version, etc"*. P079's existing user-direction-already-pinned scope captures everything except this version-comparison branch. Carving P129 out of P079 (rather than amending P079's open-ticket scope further) keeps each ticket's effort estimate honest and lets the carve-outs ship independently if priority differs.

### Candidate fix shape

**Option A — Extend P079's classifier with a version-comparison step + Option B for recurrence semantics.**

1. **Insert a new step between P079's Step 1 (JTBD alignment) and Steps 2-3 (risk assessment)**: the version-comparison step. Reads reporter's claimed version (parsed from the inbound report's `## Versions` section per P128's schema) AND walks `docs/problems/*.closed.md` looking for fix bodies whose `## Fix Released` marker resolves to a version ≥ reporter's-version.

2. **Three classification outcomes** the user named:

   - **Already-fixed-in-newer-version**: pipeline halts the safe-and-valid path. Generates a pushback comment ("upgrade to vX.Y.Z; this issue was fixed in <closed-ticket-id>"). Pushback comment goes through external-comms gates (P064 risk + P038 voice-tone) per P079's existing comment-gate plumbing.
   - **Recurred-in-newer-version**: pipeline routes to a recurrence-handling path. Links the new report to the prior closed ticket. Creates a recurrence-class artefact (see Option B below for shape choice).
   - **Still-active-in-current-version**: pipeline continues to the standard safe-and-valid path → create fresh local ticket + acknowledgement.

3. **Closed-ticket-history matcher**: the version-comparison classifier needs a way to match a new inbound report against historical closed tickets. Options:
   - Reuse P070's LLM semantic-match infrastructure (an inline LLM check comparing the inbound report body against each candidate closed ticket's description+root-cause+fix sections). Cheap given the closed-ticket-history size today; may need pre-filter as the corpus grows.
   - gh-search-style keyword pre-filter (cheap, high recall) followed by LLM semantic match (high precision) on the candidates. Mirrors P070's two-stage shape but on internal corpus rather than upstream issues.

   Architect call at implementation time. Lean: two-stage with keyword pre-filter + LLM semantic match — same shape as P070 for skill-cohort consistency.

**Option B (companion to Option A) — Recurrence-class lifecycle**:

When a recurrence is detected, the pipeline needs somewhere to record the recurrence. Two candidate shapes:

- **Option B-1**: New lifecycle status `.recurred.md` (peer of `.open.md` / `.known-error.md` / `.verifying.md` / `.closed.md` per ADR-022). The closed ticket stays closed; a NEW ticket gets the `.recurred.md` suffix linking to the original. Lifecycle: `.recurred.md` → `.known-error.md` → `.verifying.md` → `.closed.md` (treated as a fresh investigation pass with prior-fix lineage).
- **Option B-2**: Append a `## Recurrences` section to the existing closed ticket, listing each recurrence event as a sub-entry (date, reporter, new-version, link-to-new-incident-ticket). Closed ticket stays closed; recurrence is documented in-place. The new investigation work spawns a fresh `.open.md` ticket marked as a recurrence in its `## Description` section but lifecycle-wise indistinguishable from any other open ticket.

**Lean direction (per architect verdict 2026-04-26)**: Option B-2. Reasons:
- Doesn't expand the ADR-022 suffix vocabulary (load-bearing across `manage-problem`, `manage-incident`, `work-problems`, README rendering).
- Composes cleanly with ADR-031 (`docs/problems/` directory layout proposed migration) — a `## Recurrences` appendage section behaves identically across flat-layout and per-state-subdirectory layouts.
- Mirrors ADR-024 Step 7's `## Reported Upstream` "appendage section" pattern — both treat closure-state tickets as receiving structured appendages without status changes.
- Architect call stays open at implementation time — the leaning is recorded but not pinned.

**Bats coverage**: assessment-pipeline classifier behaviour tests (per ADR-037 + P081 — behavioural over structural):
- Synthetic inbound report with version < closed-ticket fix-version → assert pushback path fires; no new local ticket; comment body asserts upgrade phrasing.
- Synthetic inbound report with version ≥ closed-ticket fix-version + matching bug-shape → assert recurrence path fires; assert appendage to closed ticket OR new `.recurred.md` ticket per chosen shape; assert linkage in both directions.
- Synthetic inbound report with no matching closed ticket → assert standard new-ticket path fires unchanged.

### Investigation Tasks

- [ ] Architect review: confirm Option A pipeline-step shape + Option B-2 recurrence-lifecycle shape (lean) at implementation time. Confirm closed-ticket matcher infrastructure (P070-style two-stage vs. simpler heuristic).
- [ ] Compose with P128's schema: confirm the `## Versions` section's parse surface gives the classifier enough info to extract reporter-version reliably. If P128's schema fields turn out insufficient, surface the requirement back to P128 BEFORE either ticket implements.
- [ ] Compose with P079's pipeline: integrate the version-comparison step at the JTBD-alignment ↔ risk-assessment seam. Confirm the comment-gate plumbing (P064 + P038) handles the pushback-comment path the same way as P079's existing pushback-comment path for above-threshold-risk.
- [ ] Build the closed-ticket-history matcher (per the matcher-options decision in the candidate fix). The matcher needs: closed-ticket glob (`docs/problems/*.closed.md` or `docs/problems/closed/*.md` per ADR-031 future); body-section parser for `## Fix Released` (extract version marker); semantic comparator (P070-shape or simpler).
- [ ] Implement the version-comparison classifier. Three-way output: `already-fixed` / `recurred` / `still-active`. Each output routes to a distinct downstream branch.
- [ ] Document the recurrence-lifecycle decision (B-1 vs B-2) and ship the implementation. If B-2 (lean), the chosen shape extends ADR-022's "Allowed optional appendages" enumeration with the new `## Recurrences` section. If B-1, ADR-022 amends the suffix vocabulary; weight that risk before choosing.
- [ ] End-to-end test: file a synthetic inbound report against a synthetic adopter project; confirm each of the three classification outcomes routes correctly. Cover regression-of-recurrence (a recurred ticket later closed and recurred again).
- [ ] Bats coverage per ADR-037 + P081 (behavioural over structural — test the classifier's three outputs on synthetic inputs, not the implementation's internal data structures).
- [ ] Compose-with-but-don't-bundle: defer to architect at implementation time on whether to extract a shared classifier component for `/wr-itil:report-upstream`'s outbound-side dedup-on-existing-issues (P070). The cross-skill sharing has surface; it does NOT belong in P129's scope (architect verdict 2026-04-26).
- [ ] Update P079's pipeline documentation to reference the carve-out + the integration seam.

## Dependencies

- **Blocks**: (none) — no other open ticket lists P129 in `Blocked by`.
- **Blocked by**: P079 (parent — pipeline must exist before this carve-out can extend it), P128 (companion — version-comparison classifier requires the inbound report to carry parsable version info per P128's schema; strict block, not just compose-with), P038 (voice-tone gate on external comms — pushback-comment path goes through this gate; P079's pipeline is already blocked-by P038, so the dependency rides through P079), P064 (risk-scoring gate on external comms — same pushback-comment path goes through this gate; rides through P079).
- **Composes with**: P070 (`.verifying.md` — semantic-comparator infrastructure could be reused for closed-ticket-history matching), P123 (sibling carve-out from P079's clear-malicious branch — no functional overlap but shares the carve-out shape precedent), ADR-022 (lifecycle suffix vocabulary — Option B-2 leans toward NOT expanding this), ADR-024 (outbound contract — `## Reported Upstream` appendage pattern is the precedent for `## Recurrences`), ADR-031 (directory layout — closed-ticket-history matcher must support both flat and per-state-subdirectory layouts), ADR-036 (downstream scaffolding — the inbound-report Versions schema this ticket consumes propagates through scaffolded intakes), ADR-037 (bats doc-lint — new classifier contracts require coverage)

## Related

- **P128** (`docs/problems/128-report-upstream-report-body-lacks-consolidated-versions-section.open.md`) — companion ticket; outbound half of the same 2026-04-26 user direction. Strict block per dependency direction (this ticket needs P128's schema to parse reporter-version reliably).
- **P079** (`docs/problems/079-no-inbound-sync-of-upstream-reported-problems.open.md`) — parent surface; the assessment pipeline this carve-out extends. Carve-out shape mirrors P123's precedent.
- **P123** (`docs/problems/123-blocked-user-list-mechanism-for-inbound-report-management.open.md`) — sibling carve-out from P079; established the carve-out-pre-implementation precedent.
- **P070** (`docs/problems/070-report-upstream-does-not-check-for-existing-upstream-issues.verifying.md`) — semantic-comparator infrastructure that the closed-ticket-history matcher could reuse. Cross-skill sharing deferred to implementation-time architect call (P129 stays inbound-only per architect verdict 2026-04-26).
- **P064** (`docs/problems/064-no-risk-scoring-gate-on-external-comms.known-error.md`) — risk-gate the pushback-comment path consumes. Inherited transitively through P079.
- **P038** (`docs/problems/038-no-voice-tone-gate-on-external-comms.open.md`) — voice-tone gate the pushback-comment path consumes. Inherited transitively through P079.
- **P080** (`docs/problems/080-no-bidirectional-update-of-upstream-reported-problems.open.md`) — bidirectional-update sibling concern (outbound-lifecycle-update direction); composes loosely.
- **ADR-014** — governance skills commit their own work; the implementation work this ticket captures lands per ADR-014.
- **ADR-022** — lifecycle suffix-based status; Option B-2 leans toward extending the "Allowed optional appendages" enumeration (no new suffix). Option B-1 amends the suffix vocabulary; choose carefully.
- **ADR-024** — outbound contract; `## Reported Upstream` appendage section is the precedent shape for `## Recurrences`.
- **ADR-031** — `docs/problems/` directory layout; closed-ticket-history matcher must support both flat layout (current) and per-state-subdirectory layout (proposed).
- **ADR-033** — outbound report-body classifier; this ticket's pipeline consumes the schema ADR-033 emits on the outbound side (mirror direction).
- **ADR-036** — downstream scaffolding; the version-info schema this ticket consumes propagates through scaffolded intakes.
- **ADR-037** — bats doc-lint; new classifier contracts require behavioural coverage per P081.
- **JTBD-001** (solo-developer — governance without slowing down; eliminates manual closed-ticket-history grep + version-comparison effort)
- **JTBD-101** (plugin-developer — extend the suite by composing with P079's pipeline)
- **JTBD-201** (tech-lead — restore service fast with audit trail; recurrence detection is the missing regression-signal layer)
- **JTBD-301** (plugin-user — get heard upstream; right response when issue is already-fixed-in-newer is upgrade pushback, not a fresh ticket round-trip)
