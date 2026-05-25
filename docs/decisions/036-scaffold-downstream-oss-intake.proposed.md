---
status: "proposed"
date: 2026-04-21
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-07-21
---

# Scaffold downstream OSS intake — skill + layered triggers

## Context and Problem Statement

`.github/ISSUE_TEMPLATE/`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md` — the six intake files P055 Part A shipped for this repo (corrected to problem-first shape by P066, commit `ed36f69`) — do not propagate to downstream adopters. A project that installs `@windyroad/itil` gains the `manage-problem` / `work-problems` / `report-upstream` / new `capture-*` skill surface but does NOT automatically gain an intake surface for its OWN reporters. Every adopter repo hits a blank issue form, has no declared security-disclosure channel, and falls through to the `/wr-itil:report-upstream` skill's structured default body because no template matches — even when the downstream project would benefit from its own problem-first intake.

This is the ecosystem-level version of P066's intake reform: P066 fixed THIS repo's intake; P065 extends the fix to every adopter via a scaffolding skill. The user's direction (pinned 2026-04-20): new `/wr-itil:scaffold-intake` skill in `@windyroad/itil` (not a new plugin), layered triggers (first-run prompt from manage-problem / work-problems + pre-publish PreToolUse gate; optional CI check deferred), own ADR (not an extension of ADR-024). Templates seeded from the P066-corrected `.github/ISSUE_TEMPLATE/problem-report.yml` + SECURITY.md + SUPPORT.md + CONTRIBUTING.md.

Architect review (2026-04-21): the skill is foreground-synchronous per ADR-032 (users want to review scaffolded files before they commit; no background pattern makes sense). First-run prompt from foreground `manage-problem` / `work-problems` hits `AskUserQuestion` in main-agent context — no ADR-013 Rule 6 conflict. Pre-publish gate follows the deny-plus-delegate pattern (ADR-009 + risk-scorer / architect / jtbd gate precedents). ADR-009 marker TTL/drift applies to the decline marker.

## Decision Drivers

- **JTBD-001** (Enforce Governance Without Slowing Down) — "no manual step needed to trigger reviews". Scaffolding fires at first ITIL invocation or publish, not by user memory.
- **JTBD-101** (Extend the Suite with New Plugins) — "clear patterns, not reverse-engineering". Adopters stop hand-authoring six intake files by copying from this repo.
- **JTBD-301** (Report a Problem Without Pre-Classifying It) — directly serves the "Intake files exist in every `@windyroad/*` repo AND in every downstream project that installs the suite — scaffolding is provided, not hand-authored" desired outcome.
- **JTBD-006** (Progress the Backlog While I'm Away) — AFK behaviour is silent-note-no-auto-scaffold; JTBD-006's "does not trust agent to make judgement calls" constraint respected.
- **P065** — driver ticket.
- **P066** — parent (verifying). Ships the problem-first intake shape this skill propagates.
- **P055 Part A** — original intake-file set; template seed source.
- **ADR-024** (Cross-project problem reporting) — sibling plugin-in-itil decision; ADR-036 is the reciprocal-scaffolding side. New own ADR per pinned direction (not an extension of ADR-024).
- **ADR-032** (Governance skill invocation patterns) — skill-pattern taxonomy; scaffold-intake is foreground-synchronous.
- **ADR-013** (Structured user interaction) — Rule 1 for the first-run prompt; Rule 6 for AFK fail-safe.
- **ADR-009** (Gate-marker lifecycle) — decline marker follows TTL/drift semantics.

## Considered Options

1. **Skill in `@windyroad/itil` + PreToolUse publish gate + first-run prompt + optional CI** (chosen) — user-pinned direction shaped by architect review.
2. **New `@windyroad/oss-hygiene` plugin** — rejected per P065 direction. Narrow capability; no architectural justification for a new package publish.
3. **Companion to `@windyroad/agent-plugins`** (the umbrella installer) — rejected. Wrong scope: that's the marketplace installer, not a downstream-consumable plugin.
4. **Include/exclude CI check in v1** — chosen: optional `--ci` flag emits `.github/workflows/intake-check.yml`; NOT default. v1 ships skill + first-run prompt + pre-publish gate. CI follow-up.
5. **Always auto-scaffold in AFK** — rejected. Violates JTBD-006 "does not trust agent to make judgement calls"; auto-writing template files into a previously-empty `.github/` without user opt-in is too aggressive for AFK defaults.
6. **No pre-publish gate (first-run prompt only)** — rejected. First-run prompt only fires on ITIL skill invocations; some adopters might publish a package without ever running an ITIL skill. Pre-publish gate is the hard-stop at the actual "external reporters can now file" boundary.

## Decision Outcome

**Chosen option: Option 1** — skill + layered triggers (first-run + pre-publish) + optional CI follow-up.

### Skill contract

- **Location**: `packages/itil/skills/scaffold-intake/SKILL.md`. Placement in `@windyroad/itil` matches ADR-024 + P055 Part B precedent (report-upstream lives in itil).
- **Invocation**: `/wr-itil:scaffold-intake` — no argument-subcommands (per ADR-010 amended). Optional flags: `--dry-run` (preview without writing), `--force` (overwrite existing files; off by default), `--project-name <name>` / `--project-url <url>` (override auto-detected substitutions), `--ci` (also emits `.github/workflows/intake-check.yml`).
- **Pattern**: foreground synchronous per ADR-032. No `capture-*` background sibling (scaffolding is stateful interactive repo modification, not an aside capture).

### Detection and inference

1. Detect project name from `package.json` `name` field; fallback to the repo directory basename.
2. Detect project URL from `package.json` `repository.url` field; fallback to `git remote get-url origin`.
3. Enumerate installed `@windyroad/*` plugins from `.claude-plugin/plugin.json` (if present) or from the project's `package.json` dev-dependencies.
4. Detect security-contact from `SECURITY.md` if present OR from an explicit `--security-contact <path>` flag; fallback to "Use GitHub Security Advisories (SECURITY.md will be scaffolded to explain the disclosure path)".
5. Check existence of each target file: `.github/ISSUE_TEMPLATE/config.yml`, `.github/ISSUE_TEMPLATE/problem-report.yml`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`.

### Template seeds

Template source files live at `packages/itil/skills/scaffold-intake/templates/`:

- `config.yml.tmpl` — seeded from this repo's current `.github/ISSUE_TEMPLATE/config.yml` (post-P066).
- `problem-report.yml.tmpl` — seeded from this repo's `.github/ISSUE_TEMPLATE/problem-report.yml` (post-P066, problem-first shape).
- `SECURITY.md.tmpl` — seeded from this repo's SECURITY.md.
- `SUPPORT.md.tmpl` — seeded from this repo's SUPPORT.md (P066 "Report a problem" wording).
- `CONTRIBUTING.md.tmpl` — seeded from this repo's CONTRIBUTING.md (P066 "Problems" wording).
- `intake-check.yml.tmpl` (optional, `--ci` flag only) — asserts the four intake files exist in a downstream repo; fails the PR if absent.

Template substitution tokens (mustache-style, no runtime dependency):

| Token | Value |
|---|---|
| `{{project_name}}` | Detected project name |
| `{{project_url}}` | Detected project URL |
| `{{plugin_list}}` | Comma-separated installed `@windyroad/*` plugins |
| `{{security_contact}}` | Security-disclosure path |
| `{{year}}` | Current year (for CONTRIBUTING.md copyright) |

### Interactive flow (foreground synchronous per ADR-032)

1. Enumerate missing files; enumerate present-but-outdated files (compare content hash against template hash).
2. `AskUserQuestion` per file OR batched (4-option cap per ADR-013 Rule 1; batch as "scaffold all missing" / "scaffold with review" / "dry-run" / "cancel" when the missing list is small). The skill asks which files to scaffold.
3. For each confirmed file, write the substituted template. Report the write + diff.
4. **Idempotent present-file behaviour**: files already present are reported as "already present — <diff-if-different>"; NOT silently overwritten. User opts into overwrite via `--force` OR via an `AskUserQuestion` diff-and-replace prompt (whichever flow fits ADR-013 Rule 1 best — architect to confirm at implementation time).
5. Commit the scaffolded files per ADR-014. Commit message: `docs: scaffold OSS intake (ISSUE_TEMPLATE, SECURITY, SUPPORT, CONTRIBUTING)`.

### Rule 6 audit (per ADR-032)

| AskUserQuestion branch | Resolution |
|---|---|
| "Which files to scaffold?" (foreground invocation) | Foreground synchronous — user is in-session; AskUserQuestion fires normally. |
| "Overwrite existing file with updated template?" | Foreground synchronous; same. |
| First-run prompt from `manage-problem` / `work-problems` (foreground invocation) | Foreground synchronous per the hosting skill's pattern. |
| First-run prompt invoked from an AFK orchestrator iteration | **Fail-safe (Rule 6)**: do NOT fire AskUserQuestion. Append a pending-intake-scaffold note to the orchestrator's iteration report; do NOT scaffold. Defer the prompt to the user's next interactive session. No ADR-032 pending-questions artefact here — the deferral is a one-shot per-session note, not a question-with-a-pre-captured-state. |

### Trigger surfaces (layered)

**Trigger 1: First-run prompt from `manage-problem` / `work-problems`** (per P065 direction).

- When `/wr-itil:manage-problem` or `/wr-itil:work-problems` fires in a project AND the project's `.github/ISSUE_TEMPLATE/` is missing AND `.claude/.intake-scaffold-declined` is NOT present AND `.claude/.intake-scaffold-done` is NOT present, the host skill emits a one-shot `AskUserQuestion`:
  > `header: "Scaffold OSS intake?"`
  > `question: "This project has no intake surface. Scaffold `.github/ISSUE_TEMPLATE/`, SECURITY.md, SUPPORT.md, CONTRIBUTING.md now?"`
  > Options: `Scaffold now`, `Not now (ask again next session)`, `Decline (never prompt in this project)`.
- **Markers**:
  - `.claude/.intake-scaffold-done` — written after successful scaffold. Suppresses future prompts in this project.
  - `.claude/.intake-scaffold-declined` — written on "Decline". Suppresses indefinitely (user can delete the file to reset).
  - Both markers follow ADR-009 semantics: persistent (not TTL-expired) but drift-detectable (file presence = policy).
- **AFK behaviour (Rule 6)**: no prompt. Silent note in orchestrator iteration report. User sees the pending-scaffold on next interactive session.

**Trigger 2: Pre-publish PreToolUse gate** (hard stop).

- New hook at `packages/itil/hooks/pre-publish-intake-gate.sh`. PreToolUse on Bash.
- Matches `npm publish` commands and `gh pr merge <N>` on branches matching `changeset-release/*` (the changesets Release PR pattern).
- Checks for presence of the four intake files (`.github/ISSUE_TEMPLATE/config.yml`, `.github/ISSUE_TEMPLATE/problem-report.yml`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`). If ANY are missing, deny with: `Pre-publish intake check failed. <N> of 4 intake files missing. Run /wr-itil:scaffold-intake to scaffold, or set INTAKE_BYPASS=1 to override (documented exceptions only).`
- **Override envvar**: `INTAKE_BYPASS=1 npm publish` (consistent with `RISK_BYPASS` naming per architect advisory; renamed from P065's originally-suggested `BYPASS_INTAKE_GATE=1`).
- **Observable**: deny emission + systemMessage. Audit trail captured in review-reports per ADR-035 once that lands.

**Trigger 3: Optional CI check** (deferred to v2 / follow-up).

- `--ci` flag on `scaffold-intake` emits `.github/workflows/intake-check.yml` asserting the four files exist on every PR. Fails CI if missing.
- Not shipped by default; documented as a v1-follow-up. Each trigger layer is additive.

### Plugin-manifest registration

- `packages/itil/.claude-plugin/plugin.json` declares the new skill AND the new pre-publish hook.
- Bats doc-lint asserts the skill + hook are registered.

## Scope

### In scope (this ADR)

- Skill placement in `@windyroad/itil`.
- Template seeding from this repo's P066-corrected intake files.
- Mustache-style template substitution (no runtime dep).
- Idempotent behaviour + `--force` override + `--dry-run` preview.
- Trigger 1 (first-run prompt) in `manage-problem` + `work-problems` SKILL.md.
- Trigger 2 (pre-publish gate) — new hook.
- Markers `.claude/.intake-scaffold-done` + `.claude/.intake-scaffold-declined` + `INTAKE_BYPASS` override.
- Rule 6 audit per ADR-032.
- Bats fixture test simulating a mock downstream repo (scaffold + idempotency).
- Cross-references in `manage-problem` / `work-problems` / `report-upstream` SKILL.md.

### Out of scope (follow-up tickets or future ADRs)

- Trigger 3 (CI check) — ships via `--ci` flag in v1 but NOT applied by default. Adopter opts in.
- Multi-language intake templates (non-English issue forms). Follow-up.
- Template evolution strategy (when this repo's intake shape changes, how do downstream adopters know to re-scaffold?). First-pass: the scaffold-intake skill's present-file-diff detection handles it at next invocation; formal upgrade path is a follow-up.
- RapidAPI / Shopify / marketplace listings scaffolding — different surface entirely.
- ADR-002 package inventory update adding scaffold-intake's template files as an asset class — treat templates as skill-local content (`packages/itil/skills/scaffold-intake/templates/`), no new asset class needed.

## Consequences

### Good

- P065 closes at design level. Ecosystem-wide intake coverage achievable in one command per adopter.
- Adopters get the P066-corrected problem-first shape by default — no hand-authoring, no reverse-engineering.
- Layered triggers: soft prompt weeks before the hard stop at publish. Matches ADR-018 cadence-layered-defences pattern.
- Idempotent + markers = safe to run repeatedly; no accidental overwrites.
- Foreground-synchronous = user reviews scaffolded content; no surprise writes in AFK.
- ADR-009 marker semantics reused; no new primitive.
- `INTAKE_BYPASS` matches `RISK_BYPASS` naming convention.

### Neutral

- Scaffold-intake's presence in `@windyroad/itil` grows the plugin's responsibility scope slightly (problem-management + upstream-reporting + OSS-intake-scaffolding). Acceptable — all three are intake-shape-discipline surfaces.
- Plugin-manifest gains one skill + one hook entry. Both additive.
- First-run prompt adds one interactive turn per project on first `manage-problem` / `work-problems` invocation. Acceptable; one-shot, marker-suppressed.

### Bad

- **Template drift**: this repo's intake files evolve; adopter repos scaffolded from an older version stay frozen. Mitigated by the scaffold-intake skill's diff detection at re-run, but there's no automated "re-scaffold on template update" path. Follow-up design.
- **Pre-publish gate surprise**: adopters who publish for the first time under `@windyroad/itil` see the gate deny with no prior warning. Mitigated by Trigger 1's soft prompt having usually fired earlier; if the adopter declined or never ran ITIL skills, the publish gate is the first surprise. `INTAKE_BYPASS` is the escape hatch; `--dry-run` documents the deny surface.
- **Decline-marker staleness**: a project that declined scaffolding 12 months ago would benefit from being re-prompted if the team changed. ADR-009 markers have no natural TTL here — the marker is a policy decision, not a review clearance. Leave permanent until deleted; the reassessment criterion captures this.
- **Substitution-token misfit**: a project with an unusual `package.json` shape (no `name`, no `repository.url`) gets auto-detection fallbacks that may produce wrong substitutions. Mitigated by `--project-name` / `--project-url` override flags and by `--dry-run`.
- **Scaffolded SECURITY.md contact may be generic**: if the adopter hasn't set a contact, the scaffold produces a generic GitHub Security Advisories pointer. Better than nothing; follow-up configurable template path.
- **AFK pending-scaffold notes accumulate**: if an adopter runs AFK orchestrators frequently before opening an interactive session, the orchestrator reports accumulate "pending intake scaffold" notes. Acceptable; the note is a one-liner and the user sees them on return.

## Confirmation

### Source review (at implementation time)

- `packages/itil/skills/scaffold-intake/SKILL.md` exists with the foreground-synchronous pattern documented, the Rule 6 audit section present, the four triggers enumerated, the `INTAKE_BYPASS` envvar cited.
- `packages/itil/skills/scaffold-intake/templates/` contains the five `.tmpl` files (`config.yml.tmpl`, `problem-report.yml.tmpl`, `SECURITY.md.tmpl`, `SUPPORT.md.tmpl`, `CONTRIBUTING.md.tmpl`) plus the optional `intake-check.yml.tmpl`.
- `packages/itil/hooks/pre-publish-intake-gate.sh` exists and ships with `@windyroad/itil`.
- `packages/itil/.claude-plugin/plugin.json` declares the new skill + the pre-publish hook.
- Trigger 1 wiring in `packages/itil/skills/manage-problem/SKILL.md` + `packages/itil/skills/work-problems/SKILL.md` — both cite ADR-036's first-run-prompt contract with the marker path + AFK fail-safe.
- Cross-reference in `packages/itil/skills/report-upstream/SKILL.md` noting the upstream-reporting flow now has a downstream-intake-scaffolding sibling.

### Bats structural tests

- `packages/itil/skills/scaffold-intake/test/scaffold-intake-contract.bats` — SKILL.md structural checks (ADR-036 cited, ADR-032 foreground pattern cited, Rule 6 audit section present, four triggers enumerated, `INTAKE_BYPASS` cited).
- `packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats` — fixture test: spin up a mock empty downstream repo; invoke the skill; assert all 4 intake files are scaffolded with correct substitutions; re-invoke; assert idempotent "already present" report.
- `packages/itil/skills/scaffold-intake/test/scaffold-intake-secrets-absent.bats` — sentinel test: the skill's own output must not leak absolute paths or hardcoded-from-elsewhere content; only substitution-token outputs.
- `packages/itil/hooks/test/pre-publish-intake-gate.bats` — asserts the gate denies on missing intake files; permits on all 4 present; honours `INTAKE_BYPASS=1`.
- `packages/itil/skills/manage-problem/test/manage-problem-first-run-intake-prompt.bats` — asserts `manage-problem` SKILL.md has the first-run prompt clause citing ADR-036 and the AFK fail-safe.
- `packages/itil/skills/work-problems/test/work-problems-first-run-intake-prompt.bats` — same shape for work-problems.

### Behavioural replay (at implementation time)

1. Fresh empty project. Invoke `/wr-itil:scaffold-intake`. Verify: all 4 files scaffolded with correct substitutions from `package.json`; `.claude/.intake-scaffold-done` marker written.
2. Re-invoke in the same project. Verify: idempotent "already present" report for each file; no writes.
3. Fresh empty project. Invoke `/wr-itil:manage-problem`. Verify: first-run prompt fires via AskUserQuestion; on "Decline", `.claude/.intake-scaffold-declined` written; subsequent `manage-problem` invocations do NOT re-prompt.
4. Project with 3 of 4 intake files present. Invoke `npm publish`. Verify: gate denies with the 4-file missing list + suggestion.
5. AFK orchestrator session starts fresh project. Verify: no first-run prompt fires; iteration report contains a pending-intake-scaffold note; no scaffold happens.
6. Invoke `/wr-itil:scaffold-intake --dry-run`. Verify: full preview of all file contents without writes.
7. Invoke `/wr-itil:scaffold-intake --force` on project with outdated templates. Verify: AskUserQuestion diff-and-replace path; writes accepted files.

## Pros and Cons of the Options

### Option 1: Skill in @windyroad/itil + layered triggers (chosen)

- Good: aligns P065 pinned direction + architect + JTBD reviews; reuses ADR-009 marker pattern + deny-plus-delegate gate pattern.
- Bad: scope growth of `@windyroad/itil`; template drift follow-up.

### Option 2: New @windyroad/oss-hygiene plugin

- Good: narrow capability surface.
- Bad: adds a package publish for little win; reciprocal-scaffolding is a natural pair with report-upstream in `@windyroad/itil`.

### Option 3: Companion to @windyroad/agent-plugins

- Good: centralises adopter-facing setup.
- Bad: wrong scope; installer is not a downstream-consumable plugin.

### Option 4: Bundled CI check in v1

- Good: catches missing intake at PR-time too.
- Bad: not every adopter uses GH Actions; optional flag is a better default.

### Option 5: Auto-scaffold in AFK

- Good: zero friction for AFK-heavy adopters.
- Bad: violates JTBD-006 "does not trust agent to make judgement calls".

### Option 6: First-run prompt only, no publish gate

- Good: one trigger layer only.
- Bad: misses adopters who never run ITIL skills before publishing.

## Reassessment Criteria

Revisit this decision if:

- Adopter adoption stays near zero 3+ months post-release. Signal: the triggers aren't firing, or the prompt is being declined too often. Revisit trigger design.
- Pre-publish gate decline rate spikes (>30% of publish attempts blocked). Signal: gate too aggressive; consider softer warn-mode variant.
- Template drift becomes an operational pain (adopter repos stale across 6+ months of template evolution). Signal: design the automated re-scaffold path.
- A non-English intake request emerges. Signal: multi-language template scope.
- `INTAKE_BYPASS` usage outpaces normal scaffolding. Signal: the gate is systematically being bypassed; rethink gate ergonomics.
- ADR-032 Pending-questions contract becomes more convenient than the one-shot AFK note for the first-run prompt. Signal: migrate Trigger 1 to use the pending-questions path for consistency.

## Related

- **P065** — driver ticket; execution tracks here.
- **P066** — parent (Verification Pending); template seed source.
- **P055** — original intake set.
- **ADR-024** — report-upstream sibling; reciprocal pair.
- **ADR-032** — skill-pattern taxonomy; scaffold-intake is foreground-synchronous.
- **ADR-013** — Rule 1 (interactive prompt) + Rule 6 (AFK fail-safe).
- **ADR-009** — marker lifecycle precedent for `.claude/.intake-scaffold-*` markers.
- **ADR-010 amended** — scaffold-intake follows "one skill per distinct user intent" rule.
- **ADR-033** — report-upstream classifier problem-first; downstream-adopter-scaffolded templates match the upstream skill's preference order.
- **ADR-014** — commit discipline.
- **ADR-002** — no package inventory change; templates are skill-local.
- **ADR-035** — pre-publish gate emits review-report per ADR-035 once both land.
- **JTBD-301** — plugin-user persona; primary beneficiary of ecosystem-wide intake.
- **JTBD-001**, **JTBD-101**, **JTBD-006** — secondary.
- `packages/itil/skills/scaffold-intake/` (future) — skill location.
- `packages/itil/hooks/pre-publish-intake-gate.sh` (future) — hook location.
- `.github/ISSUE_TEMPLATE/problem-report.yml` — template seed source (post-P066).
