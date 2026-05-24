---
name: wr-architect:create-adr
description: Create a new Architecture Decision Record (MADR 4.0) in docs/decisions/. Examines existing decisions, asks about the problem and options, and writes a properly formatted ADR.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# Architecture Decision Record Generator

Create a new ADR in `docs/decisions/` following MADR 4.0 format. The wr-architect:agent reviews these files to enforce architectural compliance.

## Needs-Direction handoff + confirm-every-ADR (ADR-064)

When a `wr-architect:agent` review returns a **NEEDS DIRECTION** verdict (a new decision with 2+ viable options and no pinned direction, per ADR-064), the option choice is the user's, not the agent's — this skill is the translation surface. The architect's named question + options become the Step 2 cat-1 `AskUserQuestion` calls (Considered Options / Decision Outcome), and the Step 5 confirm is the load-bearing **review-and-confirm-every-ADR** gate: an ADR must not stand as a human-oversighted decision (reach `accepted`) without that confirm pass. A `/wr-architect:capture-adr` skeleton — zero-ask precisely because its decision was pre-pinned in `$ARGUMENTS` — must be run through this skill's confirm before promotion to `accepted`. When direction IS already pinned (same-turn / same-session / accepted ADR / RISK-POLICY.md / CLAUDE.md mandatory rule), act on it — do not re-ask (P132 inverse-P078 guard).

## Steps

### 1. Discover existing decisions

Scan for existing ADRs:
- Glob `docs/decisions/*.md` (skip `README.md`)
- Note the highest numbered decision to determine the next sequence number
- Read any decisions related to the topic being discussed (if the user has mentioned a topic)
- If `docs/decisions/` does not exist, create it

### 2. Gather context (P132 derive-first; ADR-044 category-4 silent-framework on derivable fields; category-1 direction-setting only on user-judgment fields)

**Shared dispatch helper**: this surface invokes `packages/architect/lib/derive-first-dispatch.sh` for the canonical slug derivation (Title) and I2-isomorphic stderr advisory format. The canonical source-of-truth lives at `packages/shared/derive-first-dispatch.sh`; the architect package carries a synced per-package copy at `packages/architect/lib/derive-first-dispatch.sh` per ADR-017 (Shared code duplicated into per-package lib/ kept in sync). The same helper is sourced by `/wr-itil:capture-problem` Step 1.5, `/wr-itil:manage-incident` Step 4, and `/wr-itil:manage-problem` Step 4 (each from its own per-package `packages/itil/lib/` copy); drift in the advisory shape across the four surfaces re-opens P132.

**Derive-first dispatch.** ADR creation is fundamentally user-judgment-bound — only the user knows the decision space, the alternatives considered, and the chosen-option rationale. But the **declaration-skeleton fields** (Title, status, date, reassessment-date, context-and-problem-statement) carry observable evidence in the user's prose, the working tree, and the wall-clock — the framework can resolve them without firing `AskUserQuestion`. The retained `AskUserQuestion` surfaces (Decision Drivers, Considered Options, Decision Outcome, Consequences, Confirmation, decision-makers) are the genuine **category-1 direction-setting** fields.

The P132 inverse-P078 trap (`docs/problems/known-error/132-...md`) is the load-bearing motivation. create-adr Step 2 is the **fourth declaration-skill surface** under Phase 2a to ship the derive-first dispatch (after `/wr-itil:capture-problem` Step 1.5, `/wr-itil:manage-incident` Step 4, and `/wr-itil:manage-problem` Step 4). The pattern is I2-isomorphic across all four — the stderr advisory shape `<skill>: derived <field>=<value> from <source>; <reversibility>` is identical beyond substituted values per the helper's `emit_stderr_advisory` function (architect verdict 2026-05-16 P132 Phase 2a-iii-B: pattern lock-in across the 4-surface set).

Resolve each field via the following dispatch. **The order is load-bearing** — every derivable field resolves silently with a stderr advisory citing the source; only user-judgment fields fire `AskUserQuestion`.

| Field | Dispatch | ADR-044 category |
|-------|----------|------------------|
| **Title** | Derive silently. Kebab-case the first 8-10 non-stopword tokens of the user's prose problem-statement (same slug derivation as `/wr-itil:capture-problem` Step 1.4, `/wr-itil:manage-incident` Step 4, and `/wr-itil:manage-problem` Step 4 — uses the shared helper's `derive_kebab_slug` function). Emit stderr advisory: `create-adr: derived title='<slug>' from problem-statement; re-invoke with the desired title or rename the file if the slug is wrong`. Do NOT fire AskUserQuestion. | category-4 silent-framework |
| **status** (frontmatter) | Always `proposed` for new ADRs per Step 4 template convention. No ask, no advisory needed — SKILL convention is unambiguous. | category-4 silent-framework |
| **date** (frontmatter) | Today's date (`date +%Y-%m-%d`) per Step 4 template. No ask, no advisory needed — wall-clock derivation is unambiguous. | category-4 silent-framework |
| **reassessment-date** (frontmatter) | Today + 3 months (`date -v+3m +%Y-%m-%d` on BSD-date / `date -d '+3 months' +%Y-%m-%d` on GNU-date) per Step 4 template. Emit stderr advisory: `create-adr: derived reassessment-date='<YYYY-MM-DD>' from today+3-months default; re-invoke with --reassessment-date= or edit the frontmatter to override`. | category-4 silent-framework |
| **Context and Problem Statement** | Pull verbatim from `$ARGUMENTS` prose into the Step 4 template's `## Context and Problem Statement` section. **Fallback**: when `$ARGUMENTS` carries NO problem prose (only flags or empty body), fire AskUserQuestion as the genuine category-1 direction-setting surface — *"only the user knows the problem being solved."* Question text: *"What problem does this ADR solve? Why is a decision needed now?"* This is the prose-fallback path; the typical maintainer invocation carries the problem-statement in arguments. | category-1 direction-setting (fallback only; category-4 silent-framework on the typical path where prose is present) |
| **decision-makers** | Retain AskUserQuestion. Architect verdict 2026-05-16: silent derivation from `git config user.name` would conflate "who committed the ADR" with "who made the decision" — a multi-party decision is one of the canonical mis-attribution risks ADR-013's identity model rejects. Once-per-ADR ask is low-friction in absolute terms. Question text: *"Who are the decision-makers?"* | category-1 direction-setting |
| **Decision Drivers** | Retain AskUserQuestion. Only the user knows which factors weighted the decision. This is the create-adr-equivalent of manage-problem Step 4's Description (the user-judgment surface). | category-1 direction-setting |
| **Considered Options** | Retain AskUserQuestion. Only the user knows the alternatives evaluated. ADR-044 cat-5 (taste) would only apply if the framework could offer 2+ valid options — but the alternative space is genuinely user-knowledge (the framework can offer "do nothing" + a status-quo option but the actual alternatives are the user's). Architect verdict 2026-05-16: confirmed cat-1 over cat-5. Per MADR 4.0: ≥2 alternatives including "do nothing" where applicable. | category-1 direction-setting |
| **Decision Outcome** / **Rationale** | Retain AskUserQuestion. The chosen option + primary reason for the choice. | category-1 direction-setting |
| **Consequences** (Good / Neutral / Bad) | Retain AskUserQuestion. Only the user knows the expected consequences of the decision. | category-1 direction-setting |
| **Confirmation** | Retain AskUserQuestion. Testable verification criteria. | category-1 direction-setting |
| **consulted** / **informed** (frontmatter) | Default to empty list per Step 4 template; fold into the decision-makers AskUserQuestion call if the user surfaces stakeholders. | category-4 silent-framework (default empty); category-1 (when user cites stakeholders) |

**Inferred fields (no ask, no advisory needed)**:

- **supersedes** (frontmatter): empty list by default; populated only via Step 6 supersession handling when the user explicitly cites a superseded decision.

**Stderr advisory contract**: each derived field emits a SINGLE line to stderr (NOT stdout, NOT in the ADR body) via the shared helper's `emit_stderr_advisory` function in `packages/architect/lib/derive-first-dispatch.sh`. The canonical format produced by the helper:

```
create-adr: derived <field>=<value> from <source>; <reversibility-clause>
```

The advisory text shape is I2-isomorphic — same sentence structure across all four derive-first declaration-skill surfaces (`capture-problem`, `manage-incident`, `manage-problem`, `create-adr`) beyond substituted values + source names. The helper is the single source-of-truth for this format; drift here re-opens P132. Embedding the advisory in stdout would risk machine-readers parsing it as an ADR-body line; embedding it in the ADR body would violate the MADR 4.0 schema. Stderr is the correct channel — visible to interactive maintainers in the terminal; invisible to ADR consumers; loggable by orchestrators that capture subprocess stderr.

**ADR-026 cost-source grounding**: each derived field cites its source in the advisory (problem-statement token sequence for Title; today's date for date / reassessment-date; default convention for status). The `re-invoke or update if mis-rated` clause carries the reversibility marker ADR-026 mandates for ungrounded outputs.

**AFK fail-safe (ADR-013 Rule 6)**: under AFK orchestration, derivable fields (Title / status / date / reassessment-date / Context-when-prose-present) resolve without interactive input. The 6 retained cat-1 AskUserQuestion surfaces (decision-makers / Decision Drivers / Considered Options / Decision Outcome / Consequences / Confirmation) WILL halt AFK execution — that is **correct behaviour** because ADR creation is genuinely user-judgment-bound (the user authors the decision; the framework cannot). JTBD-006 protection: AFK orchestrators that need ADR creation should call `/wr-architect:capture-adr` (the lightweight aside surface) for the skeleton + Title derivation, then defer the cat-1 field collection to the user's next interactive session via the capture-adr deferred-flagged-sections mechanism.

**Cross-skill consistency note**: this is the **fourth declaration-skill surface** to ship the derive-first dispatch (after `/wr-itil:capture-problem` Step 1.5, `/wr-itil:manage-incident` Step 4, and `/wr-itil:manage-problem` Step 4 in commits b7cc645 / 43255d2 / 30fd22b). Phase 2a-iii-B (2026-05-16) closes Phase 2a's full 4-surface scope — the I2-isomorphic stderr advisory format is now locked-in across `capture-problem`, `manage-incident`, `manage-problem`, AND `create-adr` via the shared helper at `packages/shared/derive-first-dispatch.sh` with synced per-package lib/ copies. Per ADR-017, drift between copies is caught by `npm run check:derive-first-dispatch` in CI.

If the user has already provided context in `$ARGUMENTS` or earlier conversation, use what they've given and only fire AskUserQuestion for the cat-1 fields still missing.

### 2b. Decision-boundary analysis (multi-decision check)

Before writing the ADR file, perform a decision-boundary analysis on the gathered context to prevent conflated ADRs that block independent status transitions and weaken auditability (P017).

**Self-check**: Read the context gathered in step 2. Answer: "How many distinct decisions are present? If each could be independently accepted, rejected, or superseded without affecting the others, they are distinct."

- **Single decision** (one coherent question with one chosen option): proceed directly to step 3.
- **Multiple decisions** (two or more distinct questions, different components, or different decision drivers that do not share the same trade-off): present a split prompt.

**Split prompt** — use `AskUserQuestion`:
- `header: "Multi-decision input"`
- `multiSelect: false`
- Options:
  1. `Split into separate ADRs (Recommended)` — description: "Create one ADR per distinct decision, with consecutive IDs. Each ADR can be accepted, rejected, or superseded independently."
  2. `Keep as a single ADR` — description: "Create one ADR covering all decisions. Use this only if the decisions are so tightly coupled that they cannot be made independently."

**Non-interactive fallback**: When `AskUserQuestion` is unavailable (e.g., non-interactive/AFK mode), automatically split into separate ADRs with consecutive IDs and note the auto-split in output. Do not block creation.

**Split implementation**: When splitting, assign consecutive IDs. Cross-reference each ADR in the other's Related section or as a linked decision in the consequences.

**Scope**: Scoped to new ADR creation only (steps 2–5). Does not apply to supersession handling (step 6), where the scope of the new decision is already known and bounded.

### 3. Determine sequence number and filename

- Next number = **max of the local and origin highest decision numbers**, plus 1 (or 001 if none exist).
- Filename: `NNN-decision-title-in-kebab-case.proposed.md`
- Pad the number to 3 digits (001, 002, ... 010, 011, etc.)

**Why compare against origin?** Per ADR-019 confirmation criterion 2, ticket-creator skills MUST re-check next-number assignment against `git ls-tree origin/<base>` before assigning. Without it, parallel sessions can mint the same ADR number for different decisions, causing a destructive surgical rebase on push (this was the failure mode that motivated ADR-019 itself).

```bash
# Local-max number
local_max=$(ls docs/decisions/*.md 2>/dev/null | sed 's/.*\///' | grep -oE '^[0-9]+' | sort -n | tail -1)

# Origin-max number — reads remote-tracking ref; no fetch needed here
# because `wr-architect:agent` upstream callers (e.g. work-problems) run
# the Step 0 preflight that does the fetch.
#
# `--name-only` is required (P056): without it, each ls-tree line is
# `<mode> <type> <sha>\t<path>` and the 40-char blob SHA can contain
# three-digit runs that `grep -oE '[0-9]{3}'` false-matches. `sed` strips
# the path prefix so the anchored `grep -oE '^[0-9]+'` only picks up
# filename IDs.
origin_max=$(git ls-tree --name-only origin/main docs/decisions/ 2>/dev/null | sed 's|^docs/decisions/||' | grep -oE '^[0-9]+' | sort -n | tail -1)

# Take the max of the two and increment.
next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
```

If the local choice would have collided with an origin ADR created since the last fetch, the `git ls-tree origin/<base>` lookup catches it here and the renumber is automatic. Log the renumber in the user-facing report (e.g. "Bumped next ADR number from 020 → 021 to avoid collision with origin").

### 4. Write the ADR

Write the file to `docs/decisions/` with this structure:

```markdown
---
status: "proposed"
date: YYYY-MM-DD
decision-makers: [from user input]
consulted: [from user input, or empty list]
informed: [from user input, or empty list]
reassessment-date: YYYY-MM-DD  # 3 months from today
---

# Title

## Context and Problem Statement

[What problem does this solve? Why is a decision needed now?]

## Decision Drivers

- [Key factors influencing the decision]

## Considered Options

1. **Option A** - Brief description
2. **Option B** - Brief description

## Decision Outcome

Chosen option: **"Option X"**, because [primary justification].

## Consequences

### Good

- [Positive outcomes]

### Neutral

- [Trade-offs that are neither clearly good nor bad]

### Bad

- [Negative outcomes or risks accepted]

## Confirmation

[How to verify implementation compliance. Concrete, testable criteria.]

## Pros and Cons of the Options

### Option A

- Good: [advantage]
- Bad: [disadvantage]

### Option B

- Good: [advantage]
- Bad: [disadvantage]

## Reassessment Criteria

[When should this decision be revisited? What conditions would trigger a review?]
```

Use today's date for the `date` field. Set `reassessment-date` to 3 months from today unless the user specifies otherwise.

### 5. Confirm with the user

Present the written ADR and use AskUserQuestion to ask:
1. Does the problem statement accurately capture the situation?
2. Are the pros/cons fair and complete?
3. Are the confirmation criteria testable?
4. Should anyone else be listed as consulted or informed?

Apply any feedback by editing the file.

**Born-confirmed write (ADR-066).** Once the user confirms the ADR via this AskUserQuestion pass, write the human-oversight marker into the frontmatter — insert immediately after the `date:` line:

```yaml
human-oversight: confirmed
oversight-date: YYYY-MM-DD   # today
```

This is the load-bearing born-confirmed gate: an ADR recorded through create-adr enters the world already human-oversighted (it does not appear in `/wr-architect:review-decisions`' unoversighted set). Do NOT write the marker if the user has not confirmed (rejected / still-iterating ADRs stay unmarked). The marker is orthogonal to `status:` — a `proposed` ADR can be `human-oversight: confirmed`.

### 6. Handle supersession (if applicable)

If the user mentions this decision replaces an existing one:
1. Add `supersedes: [NNN-old-decision-title]` to the new decision's frontmatter
2. Rename the old decision file from `.accepted.md` (or `.proposed.md`) to `.superseded.md` using `git mv`
3. Update the old decision's frontmatter status to `superseded`
4. Add a "Superseded by" section to the old decision referencing the new one
5. **Re-stage the renamed file explicitly after the `Edit` tool runs**: `git add docs/decisions/<NNN>-<title>.superseded.md`. `git mv` stages only the rename — the subsequent frontmatter and "Superseded by" edits must be added again before commit, or they leak into the next commit (P057 staging trap).

$ARGUMENTS
