---
name: wr-risk-scorer:create-risk
description: Create a new standing-risk entry in docs/risks/. Examines existing risks, gathers impact/likelihood/controls from the user, writes a file using the entry shape inlined in this skill (no TEMPLATE.md dependency — the entry shape is owned by this skill per user direction 2026-05-04), and updates the register index.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# Risk Register Entry Generator

Create a new standing-risk file in `docs/risks/` using the entry shape inlined in this skill (Step 5 below). The register captures persistent risks (distinct from the ephemeral per-change reports in `.risk-reports/`), and its criteria come from `RISK-POLICY.md`. **No `docs/risks/TEMPLATE.md` exists** — per user direction 2026-05-04 the entry shape lives in this skill (and the bootstrap-catalog extractor that reuses the same shape) so the directory is purely the inventory, not its own scaffolding.

This skill is the invocation surface for populating the register (scaffolded by P033; populated per P102). Per ADR-015, it is a plugin-namespaced on-demand skill. Per ADR-014, the skill commits its own work.

## Steps

### 1. Discover existing risks

Scan for existing risk files:
- Glob `docs/risks/R*.md` (skip `README.md`; there is no `TEMPLATE.md` per user direction 2026-05-04)
- Note the highest numbered risk to determine the next sequence number
- Read any risks related to the topic being discussed (if the user has mentioned a topic)
- If `docs/risks/` does not exist, explain that `/wr-risk-scorer:update-policy` must be run first (it ships the scaffolding) and stop

### 1b. Orchestrator flag-driven path (ADR-059)

When this skill is invoked with `--slug <slug>` and `--prefill <prose>` arguments, SKIP step 2 (interactive gather) and proceed deterministically. This path is the orchestrator-side auto-invoke from the ADR-056 queue drain — consumer skills (`/wr-itil:work-problems`, `/wr-itil:manage-problem` Step 11, `/install-updates`, `/wr-risk-scorer:assess-release`) read `.afk-run-state/risk-register-queue.jsonl`, dedupe by slug, and call this skill once per unique slug under ADR-013 Rule 5 (catalog framing in `RISK-POLICY.md` IS the policy authorisation).

**Flag-driven contract:**

- **`--slug <slug>`** (required for flag-driven path) — kebab-case ADR-056 slug. Filename becomes `R<NNN>-<slug>.active.md`. Slug is the dedupe key — if a `R*-<slug>.active.md` file already exists, append the originating queue line's report path to that file's `## Source Evidence` block instead of creating a new entry.
- **`--prefill <prose>`** (required for flag-driven path) — one-line prose carried into the entry's Description field verbatim.
- **`--report-path <path>`** (optional) — path to the originating `.risk-reports/*.md` file, cited in the `## Source Evidence` block. If absent, the block cites the queue line's `report_path` field directly.

**Deterministic-write defaults** (per ADR-026 grounding sentinel + ADR-056 pending-review pattern):

- **Status**: `Active (auto-scaffolded — pending review)` — distinguishes from human-curated entries while staying in the same lifecycle bucket.
- **Curation**: `**Curation**: pending review (auto-scaffolded YYYY-MM-DD)` — machine-detectable for downstream curation tooling.
- **Description**: prefill verbatim.
- **Inherent / Residual Impact / Likelihood / Score / Band**: ALL emit the ADR-026 sentinel `not estimated — no prior data`. Numeric defaults of `0` or `Low` would falsely look human-affirmed and violate JTBD-201 audit-trail integrity.
- **Within appetite?**: `pending — scoring not estimated` (cannot evaluate without scores).
- **Treatment**: `pending`.
- **Controls**: empty list (controls are project-specific; pending human curation).
- **Owner**: `pending review`.
- **Category**: heuristic-derive from the slug if unambiguous (e.g. `infosec-*` slug → `infosec` category); otherwise `pending review`.

**`## Source Evidence` block (required for flag-driven path)**:

Append to the entry body (or to existing entry if slug-collision):

```markdown
## Source Evidence (auto-scaffolded YYYY-MM-DD)

Aggregated from N `.risk-reports/` entries (slug: `<slug>`):
- `.risk-reports/<filename>.md`
- `.risk-reports/<filename>.md`
...

Re-rate when human curation lands or when controls change.
```

**Skip AskUserQuestion** under this path entirely. Per CLAUDE.md P132 (inverse-P078): the framework has resolved the decision via ADR-056 queue + ADR-013 Rule 5 policy authorisation. Per-class consent gates re-ask decisions the user already made.

**Existing AskUserQuestion path preserved for human invocation** (no `--slug` / `--prefill` flags) — fall through to Step 2 below for full interactive authoring.

**README.md update**: under flag-driven path, append a row to `docs/risks/README.md` Register table with stub scoring (`—` em-dash) and Treatment column = `pending`. Same shape as Step 6 below but auto-applied without user prompts.

### 2. Gather context from the user

You MUST use the AskUserQuestion tool to collect context that cannot be derived. Do not proceed to step 3 until you have answers. Apply ADR-013 Rule 6 non-interactive defaults if the tool is unavailable (AFK mode): choose the most conservative option for each question and note auto-selection in the output.

Auto-derive where possible (do not ask):
- **ID number** — next free slot per step 3 (do not ask per `feedback_dont_ask_trivial_id_choices.md`).
- **Today's date** — use the current date for `Identified` and `Last reviewed`.
- **Category** — infer from description keywords where unambiguous: "token", "secret", "leak" → `infosec`; "install", "hook", "pipeline" → `operational`. Confirm only if ambiguous.
- **Next review** — default to 6 months from today.

Ask the user (one AskUserQuestion call with grouped questions):

1. **What is the risk?** A short title and 1-2 paragraph description — what could go wrong, for whom, and why it matters. This is the condition, not the control.
2. **Impact level (from `RISK-POLICY.md`)?** 1 Negligible · 2 Minor · 3 Moderate · 4 Significant · 5 Severe. Read the policy's Impact table to the user if they need the descriptions.
3. **Likelihood level?** 1 Rare · 2 Unlikely · 3 Possible · 4 Likely · 5 Almost certain.
4. **Existing controls?** Each control names what it does and where it is implemented (file path or `ADR-NNN`). If none, leave empty.
5. **Residual impact and likelihood** (after controls). If controls are minimal, residual = inherent — do not fabricate reductions. Per ADR-026, quantitative reduction claims must cite evidence (test, hook gate, pipeline report). If no evidence, state "Residual same as inherent pending control evidence" in the Treatment section and set residual = inherent.
6. **Treatment choice?** Accept · Mitigate · Transfer · Avoid. Include brief justification.
7. **Owner?** Persona or role (e.g. `solo-developer`, `plugin-maintainer`, `tech-lead`).

If the user has already provided this context in the conversation (e.g. as arguments, or as part of a pipeline-finding hand-off), use what they have given and only ask about what is missing.

### 3. Determine sequence number and filename

- Next number = **max of the local and origin highest risk numbers**, plus 1 (or 001 if none exist).
- Filename: `R<NNN>-<kebab-case-title>.active.md`
- Pad the number to 3 digits (001, 002, ... 010, 011, etc.)

**Why compare against origin?** Per ADR-019 confirmation criterion 2, ticket-creator skills MUST re-check next-number assignment against `git ls-tree origin/<base>` before assigning. Without it, parallel sessions can mint the same ID for different risks, causing a destructive surgical rebase on push.

```bash
# Local-max number
local_max=$(ls docs/risks/R*.md 2>/dev/null | sed 's/.*\///' | grep -oE '^R[0-9]+' | sed 's/^R//' | sort -n | tail -1)

# Origin-max number — reads remote-tracking ref. `--name-only` required per P056
# to avoid false-matches on blob SHAs.
origin_max=$(git ls-tree --name-only origin/main docs/risks/ 2>/dev/null | sed 's|^docs/risks/||' | grep -oE '^R[0-9]+' | sed 's/^R//' | sort -n | tail -1)

# Take the max of the two and increment.
next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
```

If the local choice would have collided with an origin risk file created since the last fetch, the `git ls-tree` lookup catches it here and the renumber is automatic. Log the renumber in the user-facing report (e.g. "Bumped next risk number from R012 → R013 to avoid collision with origin").

### 4. Compute scores and bands

Use the Risk Matrix from `RISK-POLICY.md`:

- **Inherent Score** = Impact × Likelihood
- **Residual Score** = Impact × Likelihood (after controls)
- **Band** (for each) per the Label Bands table: 1-2 Very Low · 3-4 Low · 5-9 Medium · 10-16 High · 17-25 Very High
- **Within appetite?** = residual score ≤ `RISK-POLICY.md`'s appetite threshold (read the threshold at runtime; do not hardcode)

### 5. Write the risk file

Write the file to `docs/risks/` using the entry shape below (the canonical entry shape — owned by this skill per user direction 2026-05-04; the same shape is used by `extract-risks-from-reports.sh` for bootstrap-derived entries):

```markdown
# Risk R<NNN>: <Title>

**Status**: Active
**Category**: <infosec | operational | brand | delivery>
**Identified**: <YYYY-MM-DD>
**Owner**: <persona or role>
**Last reviewed**: <YYYY-MM-DD>
**Next review**: <YYYY-MM-DD + 6 months>

## Description

<1-2 paragraph description from step 2.>

## Inherent Risk

Impact × Likelihood *before* controls.

- **Impact**: <level> (<label>)
- **Likelihood**: <level> (<label>)
- **Inherent Score**: <product>
- **Inherent Band**: <band>

## Controls

- **<control-name>** — <what it does>. Implemented in <file path or ADR-NNN>.

## Residual Risk

Impact × Likelihood *after* controls.

- **Impact**: <level> (<label>)
- **Likelihood**: <level> (<label>)
- **Residual Score**: <product>
- **Residual Band**: <band>
- **Within appetite?**: <Yes | No>

## Treatment

<Accept | Mitigate | Transfer | Avoid>. <Justification.>

## Monitoring

- **Trigger to re-assess**: <event or threshold>
- **Metrics**: <if any>

## Related

- Criteria: `RISK-POLICY.md`
- Realised-as: <links to `docs/problems/P<NNN>` if any>
- Treatment ADRs: <links if any>
- Personas affected: <links to `docs/jtbd/<persona>/persona.md`>

## Change Log

- <YYYY-MM-DD>: Initial identification.
```

### 6. Update the register index

`docs/risks/README.md` has a **Register** table that MUST reflect the new risk. Append a row with the following columns:

```
| R<NNN> | <Title> | <Category> | <Inherent Score> | <Residual Score> | <Treatment verb> | <Owner> | <Next review date> |
```

This step is not optional: the README drifts from the register without it, and the ISO 27001 audit signal depends on the index being accurate.

### 7. Confirm with the user

Present the written file path, inherent/residual bands, and any `Within appetite?: No` flag. Ask via AskUserQuestion:

1. Does the description accurately capture the risk?
2. Are the inherent and residual scores defensible?
3. Is the treatment choice appropriate for the residual band?
4. Should the owner or next review date be adjusted?

Apply any feedback by editing the file and re-updating the README row if scores/treatment change.

### 8. Commit the risk (ADR-014)

Per ADR-014, this skill commits its own work. Stage both files and commit:

```bash
git add docs/risks/R<NNN>-<title>.active.md docs/risks/README.md
git commit -m "docs(risks): open R<NNN> <title>"
```

The commit message convention `docs(risks): open R<NNN> <title>` matches `docs/risks/README.md` step 6 and mirrors `docs(problems): open P<NNN>` used by `/wr-itil:manage-problem`.

If the commit-gate pattern-matches `git commit` text and blocks, run `/wr-risk-scorer:assess-release` first to produce a fresh pipeline marker, then retry the commit.

$ARGUMENTS
