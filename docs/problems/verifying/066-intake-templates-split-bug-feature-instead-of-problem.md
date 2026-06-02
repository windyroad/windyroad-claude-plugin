# Problem 066: Intake templates split bug / feature instead of a problem-first template — misaligned with ITIL problem management

**Status**: Verification Pending
**Reported**: 2026-04-20
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: S — replace `.github/ISSUE_TEMPLATE/bug-report.yml` and `feature-request.yml` with a single `problem-report.yml` (or reshape existing fields around problem-report structure), update `config.yml` chooser copy, and adjust labels. One-to-three file edits.
**WSJF**: 12.0 — (12 × 1.0) / 1 — Small effort, high-severity intake misalignment. Ranks alongside P063 at the top of the dev-work queue.

## Direction decision (2026-04-20, user — AFK pre-flight)

**Ship order**: P066 lands **first** across the problem-first reform (before P067). Rationale: this repo's templates become the reference shape that P067's skill preference order targets; P067 depends on P066's shape being in place.

**Defaults AFK can apply without further user input**:
- Replace `bug-report.yml` + `feature-request.yml` outright (not thin forwarders). New file: `.github/ISSUE_TEMPLATE/problem-report.yml` with fields mirroring the manage-problem ticket structure.
- Title prefix: `[problem]`. Labels: `problem`, `needs-triage`.
- Update `config.yml` chooser copy — remove "bugs and feature requests only" phrasing; point at "Report a problem" as the primary path. Keep Discussions + Security Advisories contact links.
- Update `SUPPORT.md` + `CONTRIBUTING.md` to reference "Report a problem" rather than bug/feature.
- No new ADR needed for P066 itself — the shape change rides under the ADR-024 amendment that P067 ships (sibling ADR per that ticket's decision).

## Description

The intake templates shipped in commit `e36cf84` (P055 Part A) are structured as `bug-report.yml` + `feature-request.yml` — forcing every reporter to pre-classify the report as bug OR feature. This is backwards for an ITIL-aligned project: ITIL problem management treats an inbound report as a **problem** whose cause, symptoms, workaround, and eventual fix strategy are surfaced by the triage process, not pre-decided by the reporter. A reporter often does not know whether a misbehaviour is a defect (bug) or a missing capability (feature), and asking them to choose adds friction and produces mis-classified reports that downstream triage has to re-bucket anyway.

The intake surface this project ships should mirror the problem template used in `docs/problems/<NNN>-<title>.open.md`: Description → Symptoms → Workaround → Impact Assessment → Root Cause Analysis. The reporter describes what they observed; triage (the `/wr-itil:manage-problem` work flow) decides whether the root cause is a defect, a missing feature, a documentation gap, or something else. That's the whole point of having problem management as a separate discipline.

The fix: replace the split templates with a single `problem-report.yml` whose fields mirror the problem-ticket structure, and reshape `config.yml`'s chooser copy to offer "Report a problem" as the primary path (with Discussions for usage questions and Security Advisories for vulnerabilities still linked as alternatives).

This ticket covers **this repo's intake**. The sibling ticket P067 covers the `/wr-itil:report-upstream` skill's classification logic (which currently also splits bug/feature/question when picking upstream templates and emits a bug-shaped structured default).

## Symptoms

- `.github/ISSUE_TEMPLATE/bug-report.yml` forces reporter to classify as "bug" (labels: `bug`, `needs-triage`; title prefix `[bug]`).
- `.github/ISSUE_TEMPLATE/feature-request.yml` forces reporter to classify as "feature" (labels: `enhancement`, `needs-triage`; title prefix `[feature]`).
- No `problem-report.yml` exists.
- `config.yml`'s contact-links copy ("Issue tracker is for bugs and feature requests only") reinforces the bug/feature dichotomy as official.
- Reporters who notice an odd behaviour whose classification is unclear (is this a bug, a missing sibling capability, or a documentation gap?) have no template that matches their mental model — they either pick the wrong one or abandon the report.
- The intake template shape does not match the problem-ticket shape that `/wr-itil:manage-problem` produces internally; signals collected at intake have to be mapped by triage into the Description / Symptoms / Workaround / Impact / Root Cause structure anyway.
- Users coming from an ITIL background see the bug/feature split as a signal that this project does not actually practise problem management, undermining the suite's positioning.

## Workaround

Reporters choose the closest template and maintainer re-labels after triage. Or reporters open a blank issue (blocked today by `blank_issues_enabled: false` in `config.yml`) or file via Discussions and the issue gets re-opened later. Both produce mis-classified intake and friction.

## Impact Assessment

- **Who is affected**:
  - **External reporters of this repo** — face a classification decision they should not have to make. Either pick wrong or give up.
  - **Solo-developer persona (JTBD-001)** — inbound reports arrive mis-labelled; triage work grows. "Enforce governance without slowing down" fails on intake.
  - **Tech-lead persona (JTBD-201)** — audit trail starts with a wrong classification that triage has to correct; the record is noisier than necessary.
  - **Plugin-developer persona (JTBD-101)** — adopters who model their own intake on this repo's templates (see P065) propagate the bug/feature split into their own projects — compounding the misalignment across the ecosystem.
- **Frequency**: Every inbound report via the issue tracker.
- **Severity**: High for intake alignment. Not a correctness defect, but a structural mismatch between how this project describes itself (ITIL problem management) and how it asks users to report. Credibility-relevant.
- **Analytics**: N/A today — intake volume is early (public repo recently surfaced); misclassification rate would require tracker metrics.

## Root Cause Analysis

### Structural

P055 Part A was scoped as "ship OSS-hygiene intake files" and the reference shape borrowed from the npm-ecosystem norm (most projects ship bug-report + feature-request). The ITIL-problem-management framing was not applied to the template design even though it is the project's own methodology. ADR-024 names the intake templates as the "reference shape" that `/wr-itil:report-upstream` targets — but that reference shape inherited the ecosystem norm rather than this project's own discipline.

### Candidate fix

Two options considered:

1. **Replace bug-report + feature-request with a single problem-report template (recommended)**.
   - New file: `.github/ISSUE_TEMPLATE/problem-report.yml` with fields mirroring the problem-ticket structure — Description, Symptoms, Workaround, Impact (who/frequency), Environment.
   - Title prefix: `[problem]`. Labels: `problem`, `needs-triage`.
   - Remove `bug-report.yml` and `feature-request.yml`.
   - Update `config.yml` chooser copy: "Report a problem" becomes the primary path; contact-links phrasing stops calling the tracker "bugs and feature requests only".

2. **Keep bug/feature and add problem as a third option**.
   - Less disruptive to ecosystem norms but keeps the misalignment visible. Rejected — the whole point is to declare that this project does problem management end-to-end, not problem-and-also-bug-and-also-feature.

**Labels**: Once triage identifies the nature, the ticket can be additionally labelled (e.g. `defect`, `enhancement`, `docs`, `question` — all sub-categories under `problem`). Labels stop being the primary classifier; the status lifecycle drives work selection.

**Cross-reference with manage-problem**: The intake fields should map 1:1 to the problem-ticket sections so triage is mechanical:

| Intake field | Maps to problem ticket section |
|---|---|
| `description` | `## Description` |
| `symptoms` | `## Symptoms` |
| `workaround` | `## Workaround` |
| `affected-plugin` / `affected-component` | Part of `## Impact Assessment` "who is affected" |
| `frequency` | Part of `## Impact Assessment` "frequency" |
| `environment` | Free-form block for Claude Code version, OS, plugin version |
| `evidence` | Links to transcript / repro session / screenshot — feeds into Investigation Tasks |

### Investigation Tasks

- [ ] Draft `.github/ISSUE_TEMPLATE/problem-report.yml` with the fields above.
- [ ] Decide whether to keep the `bug-report.yml` + `feature-request.yml` files as thin forwarders ("did you mean to report a problem?") or remove them outright. Preference: remove — the redirect adds UI noise for no signal benefit once `problem-report.yml` is the primary path.
- [ ] Update `.github/ISSUE_TEMPLATE/config.yml` chooser copy — swap "Issue tracker is for bugs and feature requests only" for problem-centred phrasing.
- [ ] Decide labels: `problem`, `needs-triage`. Remove `bug` / `enhancement` from intake; keep them (optionally) as post-triage sub-labels.
- [ ] Update `SUPPORT.md` to point to "Report a problem" rather than "Report a bug / Request a feature".
- [ ] Update `CONTRIBUTING.md` to describe the problem-report flow.
- [ ] Check that P065 (scaffold-intake skill) is noted with this change — once the templates are problem-centric, the scaffolding templates must be too, so P065's template source references should point to the corrected shape, not the current `e36cf84` shape.
- [ ] Add a bats doc-lint test asserting the templates are problem-centric (problem-report.yml exists; no bug-report.yml or feature-request.yml; config.yml doesn't enumerate "bugs and features only").
- [ ] Cross-reference P067 in this ticket's Related section — the upstream classification fix should land alongside (or shortly after) this one so the pattern stays coherent.

## Fix Released

Shipped 2026-04-20 (AFK iter 6, commit pending). Intake surface now problem-first:

- `.github/ISSUE_TEMPLATE/problem-report.yml` — NEW. Fields mirror the manage-problem ticket shape: Description, Symptoms, Workaround, Affected plugin (dropdown), Frequency, Environment, Evidence, Additional context. Title prefix `[problem]`, labels `problem` + `needs-triage`.
- `.github/ISSUE_TEMPLATE/bug-report.yml` — REMOVED.
- `.github/ISSUE_TEMPLATE/feature-request.yml` — REMOVED.
- `.github/ISSUE_TEMPLATE/config.yml` — chooser copy updated to describe the tracker as a problem-management surface; Discussions + Security Advisories contact links preserved.
- `SUPPORT.md` — "Bug reports" + "Feature requests" sections replaced with a single "Report a problem" section.
- `CONTRIBUTING.md` — "Bugs and feature requests" opener replaced with "Problems".
- `packages/shared/test/intake-templates.bats` — NEW. 11 structural doc-lint assertions (Permitted Exception per ADR-005) verifying problem-first shape, template presence/absence, retained Discussions/Security contact links, and corresponding SUPPORT/CONTRIBUTING copy.

Architect review PASSED (ADR-024 Scope explicitly carves intake scaffolding out of the "requires its own ADR" rule; ADR-005 permits structural doc-lint). JTBD review PASSED aligned with JTBD-001, JTBD-101, JTBD-201; flagged the adjacent gap that no persona models the external reporter — captured as follow-up ticket P072.

Awaiting user verification: open https://github.com/windyroad/agent-plugins/issues/new/choose and confirm the single "Report a problem" template renders with the expected fields and no bug/feature options remain.

## Related

- **P072** — follow-up; JTBD persona gap for external reporters surfaced during this ticket's review.
- **P055** — parent; Part A shipped the misaligned templates (commit `e36cf84`). This ticket corrects Part A's shape.
- **P065** — scaffold-intake skill; the template source this ticket corrects becomes the skill's seed. Update the seed reference after this ticket ships.
- **P067** — sibling; `/wr-itil:report-upstream` classifier should follow the problem-first discipline as well.
- **P063** — trigger wiring for report-upstream; tangentially related (all four P055 follow-ups are about the intake/reporting loop).
- **P064** — risk-scoring gate on external comms; neighbouring external-comms reform.
- **ADR-024** — cross-project problem-reporting contract. ADR-024 Decision Outcome Step 3 names bug/feature/question as the classification heuristic; once this ticket ships, ADR-024 should be updated (or a sibling ADR added) noting the problem-first framing.
- `packages/itil/skills/manage-problem/SKILL.md` — the template whose structure intake should mirror (Description → Symptoms → Workaround → Impact → Root Cause).
- Commit `e36cf84` — current misaligned template versions; the starting state.
- **JTBD-101** (Extend the Suite with Clear Patterns) — "clear patterns" includes declaring our discipline at the intake surface, not borrowing ecosystem norms that contradict it.
- **JTBD-001** (Enforce Governance Without Slowing Down) — intake alignment reduces triage work.
- **JTBD-201** (Restore Service Fast with an Audit Trail) — audit trail starts with correct classification.
