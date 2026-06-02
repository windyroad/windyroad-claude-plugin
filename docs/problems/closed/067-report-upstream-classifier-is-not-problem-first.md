# Problem 067: /wr-itil:report-upstream classifier is not problem-first — picks bug / feature / question and emits a bug-shaped default

**Status**: Closed
**Reported**: 2026-04-20
**Fix Released**: 2026-04-21 (ADR-033 drafted; SKILL.md Steps 3 + 5 rewritten; bats contract test extended to 15 assertions; `@windyroad/itil` minor bump changeset queued).
**Closed**: 2026-04-24 — verified in-session via run-retro Step 4a. For P113 the ADR-033 classifier matched primary-problem tokens (`problem`, `root cause`, `workaround`, `reproduction`, scoped-npm `@windyroad/itil`); template discovery on `anthropics/claude-code` fell through to `bug_report.yml` (backward-compat fallback per ADR-033 since upstream has no `problem-report.yml`). Filed issue body (anthropics/claude-code#52831) uses structured problem-shape content under the bug template — exactly the ADR-033 mixed-primary-and-fallback path.
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: M — update `packages/itil/skills/report-upstream/SKILL.md` Step 3 (classification heuristic) and Step 5 (structured default body), plus the 9-assertion bats doc-lint test. Likely a sibling-ADR note or an update to ADR-024's Decision Outcome steps 3 and 5 to reflect the problem-first framing.
**WSJF**: 4.5 — (9 × 1.0) / 2 — Mid-priority; should ship after P066 (which establishes the problem-first shape) so the skill's new default matches the intake shape this repo ships.

## Direction decision (2026-04-20, user — AFK pre-flight via AskUserQuestion)

**ADR path**: draft a **sibling ADR** that supersedes only ADR-024 Decision Outcome Steps 3 + 5. Matches the ADR-022 precedent for lifecycle-language supersession; cleaner audit trail than amending ADR-024 in place. Candidate title: "Report-upstream classifier is problem-first (supersedes ADR-024 Steps 3 + 5)".

**Ship ordering**: P066 (intake templates problem-first in this repo) lands before P067. Rationale: P067's preference order expects `problem-report.yml` in upstream `.github/ISSUE_TEMPLATE/` — this repo becomes the reference shape, so its templates must be problem-first first.

**Defaults AFK can apply without further user input**:
- Upstream template preference order: `problem-report.yml` → `problem.yml` → `problem-report.md` → `problem.md` → `bug-report.yml` → `bug.yml` → `bug-report.md` → `bug.md` → `feature-request.yml` → `feature.yml` → `feature-request.md` → `question.yml` → `question.md` → structured default.
- Structured default sections: `## Description` → `## Symptoms` → `## Workaround` → `## Impact` → `## Environment` → `## Cross-reference`.
- Classification heuristic widens to include problem / issue / concern / defect / gap markers in addition to bug / feature / question for backward compatibility with upstream ecosystem norms.
- Bats test assertions: add problem-first preference assertion; add problem-shaped default assertion; keep ecosystem-compatibility assertions for the bug/feature/question fallback.

## Description

`/wr-itil:report-upstream` (P055 Part B, shipped in `@windyroad/itil@0.8.0`, per ADR-024) currently follows a bug/feature/question mental model:

1. **Step 3 classification heuristic** (SKILL.md lines 80–91): maps local ticket title patterns to `bug`, `feature`, or `question`, then picks a matching upstream template (`bug-report.yml`, `feature-request.yml`, `question.yml`). There is no `problem` classification.
2. **Step 5 structured default** (SKILL.md lines 117–148): when the upstream has no matching template, the skill emits a bug-shaped body: `## Summary` → `## Steps to reproduce` → `## Expected behaviour` → `## Actual behaviour` → `## Environment`. This shape assumes the report is a bug — which contradicts ITIL problem management (the report is a problem; whether it's a bug is triage's call).

The intended behaviour (per user direction 2026-04-20): be problem-focused. Pick the most appropriate upstream template if one exists — including a `problem-report.yml` if the upstream has adopted the Windy Road pattern — otherwise emit a problem-shaped structured default whose sections mirror the local problem ticket: Description → Symptoms → Workaround → Impact → Environment.

Both concerns (the classifier and the default) live in the same skill file and must move together. Sibling ticket P066 fixes the intake templates in this repo so they become problem-first; this ticket fixes the outbound skill so its output aligns with the same discipline.

## Symptoms

- `packages/itil/skills/report-upstream/SKILL.md` Step 3 enumerates only `bug`, `feature`, `question` classifications (no `problem`).
- Step 3 template-matching preferences list `bug-report.yml`, `bug.yml`, `bug-report.md`, `bug.md` for "bug"; `feature-request.yml` etc. for "feature"; no preference list for a `problem-report.yml` / `problem.yml` target.
- Step 5 structured default emits a bug-shaped body (`Summary` / `Steps to reproduce` / `Expected behaviour` / `Actual behaviour` / `Environment`). When the local ticket is not a bug — e.g. a documentation gap, a cross-cutting observability request, an architectural concern — the output shape forces the content into a bug frame.
- Upstream issues filed via the skill on upstreams that lack templates carry the bug-shaped prose even when the local ticket itself was problem-shaped.
- The 9-assertion bats doc-lint test at `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` asserts the bug/feature/question classification language without asserting problem-first framing — so the current test passes despite the misalignment.
- ADR-024 Decision Outcome Step 3 enshrines the bug/feature/question classification. Until the ADR is updated or a sibling ADR reframes it, the SKILL.md aligns with its authoritative contract — which is itself misaligned with the project's ITIL framing.

## Workaround

Downstream agents invoking `/wr-itil:report-upstream` today get a bug-shaped default for any local ticket whose upstream has no templates. User has to manually re-shape the prose before the actual `gh issue create` lands — but the voice-tone-gate path (ADR-028) reviews prose only, not structure, so shape issues pass through.

## Impact Assessment

- **Who is affected**:
  - **Downstream agents calling `/wr-itil:report-upstream`** — every report lands with a bug-shaped default unless the upstream has a matching template. For problem-shaped local tickets (most of them), the frame is wrong.
  - **Upstream maintainers receiving reports** — receive bug-framed prose for reports that are really architectural or documentation problems; triage harder.
  - **Plugin-developer persona (JTBD-101)** — the "clear patterns" promise is that downstream behaviour mirrors this project's discipline. The skill's current output contradicts the discipline.
  - **Solo-developer persona (JTBD-001)** — user has to either rewrite the prose or accept the misalignment. "Enforce governance without slowing down" fails.
- **Frequency**: Every `/wr-itil:report-upstream` invocation whose target upstream has no matching template. Frequency scales with downstream adoption of the skill (P055 Part B, released 2026-04-20).
- **Severity**: Medium. Content-correct but structurally mis-framed. Not a data leak (P064 covers that) and not a tone issue (P038 / ADR-028 cover that) — a shape issue at the outbound surface.
- **Analytics**: N/A — no tracker metrics on structured-default vs template-matched outbound reports today.

## Root Cause Analysis

### Structural

ADR-024 was drafted 2026-04-20 alongside P055 Part B. The classification language inherited the npm-ecosystem bug/feature/question norm because upstreams overwhelmingly ship templates in that shape — the reasoning was "match what's there". The problem-first framing was not applied even though the skill's origin (the `/wr-itil:manage-problem` conventions) is explicitly problem-management. The default-body shape inherited the same assumption.

The structural fix:

- Classification becomes **problem-first with best-fit fallback**: look for an upstream `problem-report.yml` / `problem.yml` first; if absent, pick the best-fit of `bug-report` / `feature-request` / `question` based on the local ticket's shape (preserving backward compatibility with existing upstream conventions); if nothing matches, fall through to the problem-shaped structured default.
- Structured default becomes problem-shaped: `## Description` → `## Symptoms` → `## Workaround` → `## Impact` → `## Environment` → `## Cross-reference`.
- The bats test adds assertions for the problem-first preference list and the problem-shaped default body.
- ADR-024 updated (or extended by a sibling ADR) to document the new classification order and default shape.

### Candidate fix

Option 1 (recommended): **Problem-first with best-fit fallback**.

- Step 3 preference order: `problem-report.yml` / `problem.yml` / `problem-report.md` / `problem.md` → `bug-report.yml` / `bug.yml` etc → `feature-request.yml` etc → `question.yml` / Discussions routing → structured default.
- Step 5 default body:
  ```markdown
  ## Description

  <one-paragraph synthesis of the local ticket's Description>

  ## Symptoms

  <bullet list from local ticket's Symptoms>

  ## Workaround

  <from local ticket, or "None identified yet." if absent>

  ## Impact

  - Who is affected: <from local ticket's Impact Assessment>
  - Frequency: <from local ticket>

  ## Environment

  - Package / repo: <inferred from upstream repo name or local ticket>
  - Version: <detected via npm ls or local ticket's notes>
  - Claude Code version: <claude --version>
  - OS: <uname -srm>

  ## Cross-reference

  Reported from <downstream-repo-url>/<local-ticket-relative-path>

  This issue is tracked locally as P<NNN> in the downstream project's docs/problems/ directory.
  ```
- Step 3's classification heuristic widens: look for `problem`, `issue`, `concern`, `defect`, `gap` in the local ticket title and body; treat the shape as problem-first and let template-matching decide whether to coerce to bug/feature/question for backward compatibility.

Option 2 (rejected): **Keep bug/feature/question and ignore problem-report templates**. Preserves the ADR-024 language exactly but perpetuates the misalignment.

Option 3 (rejected): **Always use the problem-shape default, ignore upstream templates**. Simpler, but loses the "respect upstream maintainers' curated required-fields" benefit that ADR-024 Option 1 was chosen for.

### Investigation Tasks

- [ ] Update `packages/itil/skills/report-upstream/SKILL.md` Step 3 classification heuristic to be problem-first with best-fit fallback.
- [ ] Update Step 5 structured default body to the problem shape.
- [ ] Update Step 3's template preference list to look for `problem-report.yml` / `problem.yml` first.
- [ ] Update the 9-assertion bats doc-lint test — replace or supplement the bug/feature/question-only assertions with problem-first assertions (at least: "SKILL.md mentions problem-report template preference", "SKILL.md structured default uses Description / Symptoms / Workaround / Impact sections").
- [ ] Update ADR-024 Decision Outcome Step 3 + Step 5 (or draft a sibling ADR superseding the relevant steps) — the contract shift needs to be authoritative, not silent.
- [ ] Update ADR-024's "Considered Options" to note that the original option 3 ("Always use Windy-Road-structured default") has been partially reopened — we're now doing structured-default that matches OUR discipline, not the ecosystem norm, while still respecting upstream templates when they exist.
- [ ] Ensure P066 ships first (or in the same release batch) so the intake templates this repo ships match the outbound skill's preference order.
- [ ] Architect review on whether this is an ADR amendment or a new ADR. Precedent: ADR-022 replaced part of the problem lifecycle language from an earlier ADR — same pattern applies here for steps 3 and 5.
- [ ] Add a note to `packages/itil/skills/report-upstream/SKILL.md` references section pointing at P067 (and P066) as the problem-first reform.

## Decision record

**ADR-033** (Report-upstream classifier is problem-first — supersedes ADR-024 Steps 3 + 5) — drafted 2026-04-21. Partial-supersession pattern per ADR-022 precedent. New preference order: problem-first classifier tokens (problem / issue / concern / defect / gap / scoped-npm references) primary; bug / feature / question demoted to backward-compat fallbacks for upstreams that haven't adopted problem-first templates yet. Problem-shaped structured default body (Description → Symptoms → Workaround → Affected plugin → Frequency → Environment → Evidence → Cross-reference) replaces ADR-024's bug-shaped default; bug/feature/question bodies retained for fallback use. Template-discovery preference extends to `problem-report.yml` + `problem.yml` before the existing bug/feature/question candidates.

ADR-024 gains an `## Amendments` section near the top pointing at ADR-033 with the specific step numbers carved out. ADR-024 stays `.proposed.md` — not renamed.

This ticket (P067) remains **Open** as the execution tracker. Closes when:
- `packages/itil/skills/report-upstream/SKILL.md` Step 3 and Step 5 rewritten per ADR-033.
- Template-discovery preference order updated.
- `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` extended with the new preference-order + problem-shaped-body assertions.
- Cross-references to ADR-033 land in SKILL.md's Related section.

## Fix Released

- **2026-04-21** — `packages/itil/skills/report-upstream/SKILL.md` Step 3 rewritten as problem-first classifier with best-fit backward-compat fallback (preference order: problem → bug → feature → question). Classifier tokens widened to include problem / issue / concern / defect / gap / scoped-npm references / `root cause` / `reproduction` / `workaround`.
- **2026-04-21** — Step 5 structured default body rewritten to problem shape: Description → Symptoms → Workaround → Affected plugin / component → Frequency → Environment → Evidence → Cross-reference. Bug / feature / question bodies retained as fallback-only templates.
- **2026-04-21** — Template-discovery preference order extended: `problem-report.yml` / `problem.yml` / `problem-report.md` / `problem.md` searched before `bug-report.yml` / `feature-request.yml` / `question.yml` candidates.
- **2026-04-21** — `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` extended from 9 to 15 assertions with problem-first checks: ADR-033 cross-reference, classifier-token coverage, template-preference ordering, problem-shaped section order for the structured default, and backward-compat fallback retention.
- **2026-04-21** — SKILL.md References section cites ADR-033 alongside ADR-024; cross-references added at the top of Step 3 and Step 5 so the authority is visible inline.
- **ADR-033** — drafted at `docs/decisions/033-report-upstream-classifier-problem-first.proposed.md` (partial supersession of ADR-024 Steps 3 + 5; status: proposed). ADR-024 already carries the `## Amendments` back-pointer (2026-04-21).
- **Changeset** — `@windyroad/itil` minor bump queued at `.changeset/p067-report-upstream-problem-first.md`; ships with the next release cut.

## Verification

Ticket transitions to Closed when:

- [ ] The `@windyroad/itil` minor-bumped release ships via Changesets (post-merge automation).
- [ ] A downstream `/wr-itil:report-upstream` invocation on a problem-first local ticket (e.g. a real P<NNN>) emits a problem-shaped structured default body against an upstream with no template — verifying the runtime path matches the SKILL.md prose.
- [ ] A downstream `/wr-itil:report-upstream` invocation against an upstream with `problem-report.yml` selects that template in preference to `bug-report.yml`.

## Related

- **ADR-033** (Report-upstream classifier is problem-first) — decision record for this ticket. Closes the design question.
- **P055** — parent; Part B shipped `/wr-itil:report-upstream` with the bug/feature/question shape.
- **P066** — sibling; this repo's intake templates adopt problem-first. Must ship first (or alongside) so the skill's preference order matches the shape this project ships.
- **P063** — manage-problem does not trigger report-upstream; related wiring gap.
- **P064** — no risk-scoring gate on external comms; neighbouring external-comms reform.
- **P065** — no scaffold-intake skill for downstream projects; downstream-side of the same intake-shape discipline.
- **ADR-024** — the contract currently enshrining bug/feature/question. Needs amendment or sibling ADR to document the problem-first shift.
- **ADR-022** — precedent for lifecycle-language amendment (the Verification Pending status replaced part of the earlier lifecycle description).
- `packages/itil/skills/report-upstream/SKILL.md` lines 80–91 (Step 3 classification) and lines 117–148 (Step 5 structured default) — the two edit surfaces.
- `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` — existing 9 assertions need updates for problem-first framing.
- **JTBD-004** (Connect Agents Across Repos to Collaborate) — the skill's primary JTBD; the outbound shape should match our problem-management discipline when we initiate cross-repo handoffs.
- **JTBD-101** (Extend the Suite with Clear Patterns) — problem-first is the "clear pattern".
- **JTBD-201** (Restore Service Fast with an Audit Trail) — problem-shaped outbound reports align with the bi-directional linkage discipline.
