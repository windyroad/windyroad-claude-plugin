---
name: wr-architect:create-adr
description: Create a new Architecture Decision Record (MADR 4.0) in docs/decisions/. Examines existing decisions, asks about the problem and options, and writes a properly formatted ADR.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# Architecture Decision Record Generator

Create a new ADR in `docs/decisions/` following MADR 4.0 format. The wr-architect:agent reviews these files to enforce architectural compliance.

## Steps

### 1. Discover existing decisions

Scan for existing ADRs:
- Glob `docs/decisions/*.md` (skip `README.md`)
- Note the highest numbered decision to determine the next sequence number
- Read any decisions related to the topic being discussed (if the user has mentioned a topic)
- If `docs/decisions/` does not exist, create it

### 2. Gather context from the user

You MUST use the AskUserQuestion tool to collect the decision context. Do not proceed to step 3 until you have answers.

Ask the user:

1. **What is the decision about?** A brief title and the problem being solved.
2. **What options were considered?** At least 2 alternatives (including "do nothing" if applicable). For each option, ask for key pros and cons.
3. **What was chosen and why?** The selected option and the primary reason.
4. **Who are the decision-makers?** Who made or is making this decision.
5. **Any consequences to note?** Known good, neutral, or bad outcomes.

If the user has already provided this context in the conversation (e.g., as arguments), use what they've given and only ask about what's missing.

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

### 6. Handle supersession (if applicable)

If the user mentions this decision replaces an existing one:
1. Add `supersedes: [NNN-old-decision-title]` to the new decision's frontmatter
2. Rename the old decision file from `.accepted.md` (or `.proposed.md`) to `.superseded.md` using `git mv`
3. Update the old decision's frontmatter status to `superseded`
4. Add a "Superseded by" section to the old decision referencing the new one
5. **Re-stage the renamed file explicitly after the `Edit` tool runs**: `git add docs/decisions/<NNN>-<title>.superseded.md`. `git mv` stages only the rename — the subsequent frontmatter and "Superseded by" edits must be added again before commit, or they leak into the next commit (P057 staging trap).

$ARGUMENTS
