---
name: wr-architect:capture-adr
description: Lightweight ADR-capture skill for aside-invocation during foreground work — single-option skeleton, deferred-flagged sections (Considered Options / Decision Drivers / Consequences / Confirmation / Reassessment), single commit, no inline architect-review handoff. Defers full canonical expansion to /wr-architect:create-adr. Use this when the user (or agent mid-iter) wants to record a decision quickly without the ~10-15 turn ceremony of /wr-architect:create-adr. For full-intake new ADR creation with options + drivers + consequences + confirmation, use /wr-architect:create-adr.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Capture ADR Skill

Capture an Architecture Decision Record quickly during foreground work. Lightweight aside-invocation surface that complements the heavyweight `/wr-architect:create-adr` flow. See `REFERENCE.md` in this directory for rationale, edge cases, contract trade-offs, and the ADR-032 foreground-lightweight-capture amendment.

This skill is the foreground-lightweight-capture variant of `/wr-architect:create-adr`'s new-ADR path per ADR-032 (P156 amendment, 2026-05-03). The deferred background-capture variant named in ADR-032's original taxonomy remains deferred per P088 settlement.

## When to invoke

- **Mid-iter design decision**: agent or user lands on a design choice during foreground work and cannot afford the ~10-15 turn ceremony of `/wr-architect:create-adr`.
- **Architect-review verdict capture**: a `wr-architect:agent` review yields a substantive PASS-WITH-NOTES / ISSUES-FOUND verdict whose rationale deserves an ADR-shaped record (today the verdict lands in commit messages and the rationale rots).
- **User-driven design conversations**: user resolves options (a)/(b)/(c) during conversational work; today the settlement gets buried in a problem-ticket RCA section instead of codified.

**Use `/wr-architect:create-adr` instead** when:
- The user wants to walk the full intake flow (Considered Options ≥2, Decision Drivers, full Consequences, Confirmation criteria, Pros/Cons of Options).
- The decision is large enough that the deferred-placeholder pattern is unhelpful (the user already has the canonical-shape content).
- The decision needs immediate architect review + acceptance (capture-adr writes `.proposed.md`; canonical acceptance is a follow-up via `/wr-architect:create-adr` or direct architect-agent review).

## Rule 6 audit (per ADR-032 + ADR-013)

This skill has **zero AskUserQuestion branches** by design. Each potentially-interactive decision is framework-mediated per ADR-044:

| Decision | Resolution |
|----------|-----------|
| Considered Options ≥2 | Mechanical: skeleton writes `1. Option A (chosen) — <one-line>` + `2. (deferred — see /wr-architect:create-adr canonical review)`. The MADR ≥2-options requirement is enforced at acceptance, not at skeleton time; status `proposed` covers skeleton state. |
| Decision drivers | Framework-policy: flag `(deferred to /wr-architect:create-adr canonical review)`. Drivers are typically discovered during canonical expansion. |
| Consequences | Framework-policy: flag `(deferred to /wr-architect:create-adr canonical review)`. Consequences require trade-off analysis the lightweight path does not perform. |
| Confirmation criteria | Framework-policy: flag `(deferred to /wr-architect:create-adr canonical review)`. Testable confirmation is a canonical-review concern. |
| Reassessment criteria | Framework-policy default: 3 months from today (matches `create-adr` Step 4 default); flag `(deferred — refine at canonical review)` for the criteria themselves. |
| Decision-makers / consulted / informed | Framework-policy: write `[unspecified — fill at canonical review]` sentinel + flag at canonical review. |
| Empty `$ARGUMENTS` | Halt-with-stderr-directive: print "capture-adr requires Title + 1-line Context + 1-line Decision in $ARGUMENTS — invoke /wr-architect:create-adr instead for the full intake flow" and exit. AFK orchestrators MUST NOT invoke capture-adr with empty arguments — caller-side contract. |

Per ADR-013 Rule 6 fail-safe: every branch above resolves without user input, so AFK and interactive contexts behave identically.

## Steps

### 1. Parse Title + 1-line Context + 1-line Decision from `$ARGUMENTS`

The expected `$ARGUMENTS` shape is free-text describing **(a) Title**, **(b) one-line Context** (the problem being solved), and **(c) one-line Decision** (the chosen option in one sentence).

Parsing heuristic: split on the first newline (Title) and second newline (Context); the rest is Decision. If only one line is supplied, treat it as Title and use deferred-flag placeholders for Context + Decision. If two lines, treat as Title + Decision and defer Context.

Empty `$ARGUMENTS` halts per the Rule 6 audit above.

Derive a kebab-case title slug from the first 8-10 non-stopword tokens of the Title (matching the existing `create-adr` slug derivation pattern).

### 2. Compute the next ADR ID

Same P056-safe `local_max + origin_max + 1` formula as `/wr-architect:create-adr` Step 3:

```bash
local_max=$(ls docs/decisions/*.md 2>/dev/null | sed 's/.*\///' | grep -oE '^[0-9]+' | sort -n | tail -1)
origin_max=$(git ls-tree --name-only origin/main docs/decisions/ 2>/dev/null | sed 's|^docs/decisions/||' | grep -oE '^[0-9]+' | sort -n | tail -1)
next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
```

`--name-only` is required (P056): without it, each `git ls-tree` line includes the 40-char blob SHA which can contain three-digit runs that the digit-extraction regex false-matches.

Log the renumber decision in the operation report if origin and local diverged.

### 3. Skeleton-fill the MADR template

**File path**: `docs/decisions/<NNN>-<kebab-title>.proposed.md`

**Template** (deferred-placeholder pattern — flag every section the capture didn't fill, with the literal pointer string `(deferred to /wr-architect:create-adr canonical review)` so canonical-expansion tooling can detect and expand mechanically):

```markdown
---
status: "proposed"
date: <YYYY-MM-DD>
decision-makers: [unspecified — fill at canonical review]
consulted: []
informed: []
reassessment-date: <YYYY-MM-DD + 3 months>
---

# <Title>

> Captured via /wr-architect:capture-adr (foreground-lightweight aside-invocation per ADR-032 P156 amendment). Run /wr-architect:create-adr on this ID to expand the deferred sections canonically.

## Context and Problem Statement

<one-line Context from $ARGUMENTS, or "(deferred to /wr-architect:create-adr canonical review)" if not supplied>

## Decision Drivers

- (deferred to /wr-architect:create-adr canonical review)

## Considered Options

1. **Option A (chosen)** — <one-line summary derived from Decision in $ARGUMENTS>
2. (deferred — see /wr-architect:create-adr canonical review)

## Decision Outcome

Chosen option: **"Option A"**, because <one-line Decision from $ARGUMENTS, or "(deferred to /wr-architect:create-adr canonical review)" if not supplied>.

## Consequences

### Good

- (deferred to /wr-architect:create-adr canonical review)

### Neutral

- (deferred to /wr-architect:create-adr canonical review)

### Bad

- (deferred to /wr-architect:create-adr canonical review)

## Confirmation

(deferred to /wr-architect:create-adr canonical review)

## Pros and Cons of the Options

### Option A

- (deferred to /wr-architect:create-adr canonical review)

## Reassessment Criteria

(deferred to /wr-architect:create-adr canonical review — default reassessment-date 3 months from capture)
```

The deferred-placeholder pattern is load-bearing — `/wr-architect:create-adr` (and any future canonical-expansion auto-detect path) keys off the literal pointer string `(deferred to /wr-architect:create-adr canonical review)` to surface captured ADRs for expansion.

The numbered-options placeholder (`1. Option A (chosen) ...` + `2. (deferred ...)`) preserves the MADR ≥2-options surface for any doc-lint that asserts numbered-option presence; status `proposed` covers the skeleton state for canonical-acceptance review.

### 4. Write the file

Single `Write` to `docs/decisions/<NNN>-<kebab-title>.proposed.md`.

### 5. Commit per ADR-014 — single commit, no architect-review handoff

**Stage list**: ONLY the new ADR file.

```bash
git add docs/decisions/<NNN>-<kebab-title>.proposed.md
```

Satisfy the commit gate per ADR-014 — same two-path pattern as `manage-problem` Step 11 / `capture-problem` Step 6:

- **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
- **Fallback**: invoke `/wr-risk-scorer:assess-release` via the Skill tool when the subagent type is unavailable in the current tool surface.

Commit message:

```
docs(decisions): capture ADR-<NNN> <title>
```

The `capture` verb is the audit signal that this ADR landed via the lightweight aside path (vs. `add` / `accept` for canonical create-adr's full intake). The status remains `proposed` until canonical review accepts it.

### 6. Report

After the commit, report:

- The new ADR file path and ID.
- Trailing pointer: `Run /wr-architect:create-adr <NNN> next to expand the deferred sections canonically (Considered Options ≥2, Decision Drivers, Consequences, Confirmation, Reassessment Criteria).`
- Note any renumber-from-origin-collision log line from Step 2.

The trailing pointer is **not optional** — it is the user-visible signal that the skeleton needs canonical expansion before acceptance review.

**Confirm-every-ADR gate (ADR-064):** a capture-adr skeleton is recorded `proposed` with a pre-pinned decision but WITHOUT human review of the options. It must NOT be promoted to `accepted` until it has been through a `/wr-architect:create-adr` (or equivalent) `AskUserQuestion` review-and-confirm pass. Capture records the decision quickly; the confirm — not the capture — is what gives it human oversight. This is prong 1 of P283 (lift auto-/quick-recorded decisions to human-confirmed before they stand).

## Composition with create-adr

| Concern | create-adr | capture-adr |
|---------|------------|-------------|
| Considered Options | AskUserQuestion gathering ≥2 options + pros/cons | Single-option skeleton with chosen flagged + deferred placeholder |
| Decision Drivers | AskUserQuestion gathering | Deferred flag |
| Consequences | AskUserQuestion gathering Good/Neutral/Bad | Deferred flag (Good/Neutral/Bad sections present, content deferred) |
| Confirmation | AskUserQuestion gathering testable criteria | Deferred flag |
| Reassessment criteria | AskUserQuestion gathering | 3-month default date + deferred-flag criteria |
| Frontmatter | Full populated frontmatter | Sentinel values (`unspecified — fill at canonical review`) + 3-month reassessment |
| Decision-boundary check (Step 2b) | Multi-decision split via AskUserQuestion | Out of scope (one ADR per invocation) |
| Supersession (Step 6) | Handles `git mv .accepted.md → .superseded.md` | Out of scope (capture is creation only) |
| Confirm-with-user (Step 5) | AskUserQuestion review pass | Out of scope |
| Commit grain | One commit per intake | One commit per capture |
| Use case | Full-intake new ADR; user wants to walk the flow | Aside-invocation; capture-and-continue |

The two skills share the `docs/decisions/*.proposed.md` directory and the next-ID formula. Cross-skill ordering: capture-adr writes a skeleton at `<NNN>`; later `/wr-architect:create-adr <NNN>` (or direct Edit) expands the deferred sections in place. Auto-detect-and-expand path is a follow-up (see "Composition" in REFERENCE.md).

## Related

- **P156** (`docs/problems/156-ship-capture-adr-skill.open.md`) — driver ticket.
- **P014** (`docs/problems/014-aside-invocation-for-governance-skills.open.md`) — parent / master tracker.
- **P155** (`docs/problems/155-ship-capture-problem-skill.verifying.md`) — sibling capture-problem skill.
- **P157** — sibling pending-questions-surface hook.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — foreground-lightweight-capture variant amendment (P156 amendment, 2026-05-03).
- **ADR-038** — progressive-disclosure pattern (SKILL.md + REFERENCE.md split).
- **ADR-044** — decision-delegation contract (framework-mediated mechanical-stage carve-outs).
- **ADR-049** — bin/ on PATH (capture-adr is self-contained; no shim required, same as create-adr).
- **ADR-052** — behavioural-tests-default for skill testing.
- `packages/architect/skills/create-adr/SKILL.md` — heavyweight intake counterpart.
- `packages/architect/agents/agent.md` — wr-architect:agent review surface; reviews `.proposed.md` skeletons during canonical-expansion delegation.

$ARGUMENTS
