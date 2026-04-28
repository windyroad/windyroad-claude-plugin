---
name: wr-itil:manage-problem
description: Create, update, or transition a problem ticket using an ITIL-aligned problem management workflow with WSJF prioritisation. Supports creating new problems, updating root cause analysis, transitioning status, and closing problems.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill
deprecated-arguments: true
---

# Problem Management Skill

Create, update, or transition problem tickets following an ITIL-aligned problem management process. This skill is the authoritative definition of the problem management workflow — no separate process document is needed.

## Output Formatting

When referencing problem IDs, ADR IDs, or JTBD IDs in prose output, always include the human-readable title on first mention. Use the format `P029 (Edit gate overhead for governance docs)`, not bare `P029`. Tables with separate ID and Title columns are fine as-is.

## First-run intake-scaffold pointer (P065 / ADR-036)

This skill is one of the two host skills wired to surface the [`/wr-itil:scaffold-intake`](../scaffold-intake/SKILL.md) skill on first invocation in a project that has not yet adopted the OSS intake surface. The contract is documented in [ADR-036](../../../../docs/decisions/036-scaffold-downstream-oss-intake.proposed.md) (Scaffold downstream OSS intake — skill + layered triggers).

**Preamble check** (run before Step 0 of any operation):

1. Look for the four intake paths: `.github/ISSUE_TEMPLATE/config.yml`, `.github/ISSUE_TEMPLATE/problem-report.yml`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`.
2. Look for `.claude/.intake-scaffold-declined` (explicit decline marker — never re-prompt).
3. Look for `.claude/.intake-scaffold-done` (done marker — already scaffolded).

If any intake file is missing AND both markers are absent, surface the scaffold-intake skill:

| Mode | Behaviour |
|---|---|
| **Foreground (interactive)** | Fire one-shot `AskUserQuestion` per ADR-013 Rule 1: header `"Scaffold OSS intake?"`, three options — **Scaffold now** (delegate to `/wr-itil:scaffold-intake`), **Not now (ask again next session)** (no marker; re-prompt next time), **Decline (never prompt in this project)** (write `.claude/.intake-scaffold-declined`). |
| **AFK orchestrator (Rule 6 fail-safe)** | Do **not** fire `AskUserQuestion`. Append a one-line `"pending intake scaffold"` note to the iteration's `ITERATION_SUMMARY` notes field. Do **not** auto-scaffold — JTBD-006 forbids the agent from making this judgement call. The user catches up on next interactive session. |

The preamble check is a one-shot; the `.intake-scaffold-done` and `.intake-scaffold-declined` markers (ADR-009 persistent-marker semantics) suppress re-prompts in subsequent sessions without TTL expiry.

## Operations

- **Create**: `problem <title or description>` — creates a new open problem
- **Update**: `problem <NNN> <update details>` — updates an existing problem (add root cause, evidence, fix strategy)
- **Transition**: `problem <NNN> known-error` — moves to known-error when root cause is confirmed
- **List**: `problem list` — shows all open problems sorted by priority
- **Work**: `problem work` — runs a review first, then begins working the highest-WSJF problem
- **Review**: `problem review` — re-assess all open problems: update priorities per RISK-POLICY.md, estimate effort, calculate WSJF, and update files

**Closing problems:** Problems are closed ONLY after the user verifies the fix in production — not when the fix is committed or released. The workflow (per ADR-022):
1. When the fix is released: `git mv` the file from `.known-error.md` to `.verifying.md`, update the Status field to "Verification Pending", AND add a `## Fix Released` section (e.g., `Deployed in v0.26.X. Awaiting user verification.`). All three edits land in the same commit per ADR-014.
2. When the user explicitly confirms ("it's fixed", "verified", "working"): `git mv` from `.verifying.md` to `.closed.md`, update the Status field to "Closed", and reference the problem in the commit message (e.g., "Closes P008").
3. Never assume the fix works — always wait for explicit user confirmation before closing.

The `.verifying.md` suffix distinguishes "fix released, awaiting user verification" from "root cause confirmed, fix not yet implemented" (the Known Error meaning pre-release). See ADR-022 for rationale.

## Problem Lifecycle

| Status | File suffix | Meaning | Entry criteria |
|--------|-----------|---------|----------------|
| **Open** | `.open.md` | Reported, under investigation | New problem identified |
| **Known Error** | `.known-error.md` | Root cause confirmed, fix path clear, **fix NOT yet released** | Root cause documented, reproduction test exists, workaround in place |
| **Verification Pending** | `.verifying.md` | Fix released, awaiting user verification (ADR-022) | Fix shipped; `## Fix Released` section written; user action remaining |
| **Parked** | `.parked.md` | Blocked on upstream or suspended by user decision | Upstream blocker identified, or user explicitly suspends; reason and un-park trigger documented |
| **Closed** | `.closed.md` | Fix verified in production | User explicitly confirms the released fix works |

**Parked problems** are excluded from WSJF ranking and work selection. They are listed separately in review output so users can see them without them polluting the backlog. To park a problem:
1. **If the park reason is `upstream-blocked`**, run the external-root-cause detection block at Step 7 first (see "External-root-cause detection (P063)"). Park without recording the upstream dependency in `## Related` would be the canonical audit-trail gap this block closes.
2. `git mv docs/problems/<NNN>-<title>.<current>.md docs/problems/<NNN>-<title>.parked.md`
3. Update the Status field to "Parked"
4. Add a `## Parked` section with: reason for parking, expected trigger to un-park, date parked

To un-park: `git mv` back to `.open.md` (or `.known-error.md` if root cause is confirmed), update Status, remove `## Parked` section.

**Verification Pending problems** are also excluded from WSJF ranking — their remaining work is user-side verification, not dev effort. They appear in a dedicated "Verification Queue" section in review output so the user can see what's waiting on them without mixing with dev-work ranking. See step 9c for the queue layout.

**Allowed optional appendages**: a problem ticket file may carry a `## Reported Upstream` section appended after the standard sections. This is written by the `/wr-itil:report-upstream` skill (per ADR-024 Confirmation criterion 3a) and records the upstream issue or advisory URL, the matched template, and the disclosure path. The presence or absence of this section does not affect WSJF ranking or status transitions.

**Test-driven resolution:** When root cause is identified, create a failing test that reproduces the problem. Skip/disable the test if a feature-disabling workaround is applied. Re-enable the test when the permanent fix is implemented — the test passing confirms resolution.

## WSJF Prioritisation

Problems are ranked using Weighted Shortest Job First (WSJF):

**WSJF = (Severity × Status Multiplier) / Effort**

**Severity** = Impact × Likelihood (1-25) from `RISK-POLICY.md`. Read the impact levels, likelihood levels, and risk matrix from the policy — do not hardcode them here.

**Status Multiplier** (known-errors have confirmed root cause and clear fix path — higher value per unit of work):

| Status | Multiplier |
|--------|-----------|
| Known Error | 2.0 |
| Open | 1.0 |
| Verification Pending | 0 (excluded) |
| Parked | 0 (excluded) |

`Verification Pending` and `Parked` tickets are excluded from the main dev-work ranking per ADR-022 (verification) and the Parked policy above. `Verification Pending` remaining work is user-side confirmation, not dev effort, so mixing it into the dev-work queue would distort WSJF. Both are surfaced in dedicated sections (see step 9c) — not in the ranked table.

**Effort** (estimated fix size — smaller effort = higher priority):

| Effort | Divisor | Description |
|--------|---------|-------------|
| S | 1 | < 1 hour, single file, quick fix |
| M | 2 | 1-4 hours, few files, moderate change |
| L | 4 | 4 hours – 1 day, multiple files, significant change within a single plugin |
| XL | 8 | > 1 day, multi-day or cross-package work (multiple plugins, migration, new ADR required) |

**Example**: A Known Error with severity 8 (Impact 4 × Likelihood 2) and Small effort:
WSJF = (8 × 2.0) / 1 = **16.0** — do this first.

An Open problem with severity 6 (Impact 3 × Likelihood 2) and Large effort:
WSJF = (6 × 1.0) / 4 = **1.5** — lower priority despite medium severity.

An Open problem with severity 8 (Impact 2 × Likelihood 4) and Extra-Large effort (multi-day, cross-package):
WSJF = (8 × 1.0) / 8 = **1.0** — defer until severity climbs or scope shrinks.

When estimating effort, read the problem's root cause analysis and fix strategy. If effort is unknown, default to M (2). Effort is a **live estimate**, not a set-once label: re-rate it when root cause is confirmed, when architect review narrows or expands scope, and during each `manage-problem review`. A note capturing the reason for any bucket change makes the ranking audit-able (see steps 7 and 9b).

### Transitive dependencies (P076)

> **Serves**: JTBD-001 (enforce governance without slowing down — queue must not lie), JTBD-006 (progress the backlog while I'm away — AFK orchestrator iterates top-down on a trustworthy rank), JTBD-201 (restore service fast with an audit trail — ranking decisions must be defensible post-hoc).

Effort is scored per-ticket as a **marginal** estimate (the work this ticket adds on top of its upstream dependencies). When a ticket has upstream dependencies — other tickets that must close first before this one can reach "done" — the ticket's effective effort for WSJF purposes is the **transitive closure** of its marginal effort plus all blocking upstreams, not the marginal alone.

**Rule**:

```
Effort(T)_transitive = max(
  Effort(T)_marginal,
  max{ Effort(U)_transitive | U ∈ Blocked_by(T) }
)

WSJF(T) = (Severity(T) × StatusMultiplier(T)) / Effort(T)_transitive
```

A dependent ticket cannot reach its "done" state without the upstream work happening first. Scoring the dependent at its marginal-only effort lies about what it costs to deliver — the **queue** would rank it higher than its blocker even though the blocker's work is strictly contained within it.

**Dependency signal**: drive the closure from the ticket's `## Dependencies` section (see the Step 5 template). Only `**Blocked by**` entries propagate effort; `**Composes with**` does NOT propagate — compositional overlap shares surface but neither side strictly blocks.

**Upstream status carve-out**: an upstream ticket in `.closed.md`, `.verifying.md`, or `.parked.md` contributes **0** to the transitive closure. Closed upstream work is done; verifying upstream work is user-side (not dev effort and excluded from dev ranking per the WSJF multiplier table); parked upstream work is suspended (excluded from ranking until un-parked). Without this carve-out, a ticket blocked by a closed ticket would inherit XL forever.

**Cycle handling**: when two or more tickets mutually block each other (e.g., shared gate-surface tickets that each list the other under `**Blocked by**`), treat the strongly-connected component as a **bundle**. The bundle's effective effort is `max{ marginal | members }`. All bundle members surface the same WSJF in review output — the shared WSJF is a **computed artefact** of the rendering, not written as a field into individual ticket files. Bundle members retain their individual Status suffixes and individual ticket files (ADR-022 suffix-based lifecycle).

**Re-rate on upstream status change**: when a dependency transitions to `.closed.md` / `.verifying.md` / `.parked.md`, the dependent ticket's transitive closure shrinks and the effort drops accordingly. Step 9b catches this automatically — no transition-time graph re-walk is required.

**Worked example**: P073 has marginal effort S (one surface-row add). P073 is blocked by P038 (XL). Then:

```
Effort(P073)_transitive = max(S=1, Effort(P038)_transitive) = max(1, 8) = 8
WSJF(P073) = (Severity(P073) × 1.0) / 8 = 12 / 8 = 1.5
```

P073's WSJF matches P038's by construction — P073 cannot out-rank the ticket whose work is strictly contained within it. Contrast with the marginal-only (incorrect) computation: `12 / 2 = 6.0`, which would mis-rank P073 as "top of queue" despite being blocked.

**Determinism**: the rule is deterministic from the graph — no `AskUserQuestion` branch is required when Step 9b re-rates a ticket. The re-rate fires silently and is logged in the review output per the Step 9b re-rate message format.

**Reassessment criteria**: this rule lives inline in manage-problem's SKILL.md (following ADR-022's precedent for inline WSJF additions). If a second skill (e.g., manage-incident or a future cross-plugin `work-backlog` orchestrator) adopts the `## Dependencies` section and the transitive-effort rule, extract to a sibling ADR at that point — wider adoption justifies the ADR cost that today's single-skill scope does not.

## Working a Problem

What "work" means depends on the problem's status:

**Open problem (no confirmed root cause):**
1. Read the problem description and any preliminary hypotheses
2. Investigate the root cause — read relevant source code, run experiments, query prod data. Do NOT guess.
3. Document findings in the Root Cause Analysis section with evidence
4. Create a failing reproduction test (can be skipped/disabled)
5. Identify a workaround (even "delete and re-enter" counts)
6. Update the problem file with all findings
7. **Transition to Known Error immediately** — once root cause and workaround are documented, `git mv` the file to `.known-error.md` and update the Status field. Do not wait for a separate review.
8. If the fix is small enough, continue straight to implementing it (becoming a Known Error → Closed flow in one session)

**Known Error (root cause confirmed, fix path clear):**
1. Read the root cause analysis and fix strategy
2. Implement the fix following the project's development workflow (plan if needed, architect review, tests, etc.)
3. Include the problem doc closure in the fix commit (`git mv` to `.closed.md`, update Status)
4. Push, create changeset, release per the lean release principle

**Scope expansion during work:** If investigation or architect review reveals that the problem's scope has grown significantly (e.g., effort re-sized from S to L, additional files discovered), use `AskUserQuestion` before continuing:
- Option 1: `Continue with expanded scope` — keep working this problem at its new size
- Option 2: `Update problem and re-rank` — save findings to the problem file, re-score WSJF, and re-run the work selection to let the user pick from the updated queue
- Option 3: `Pick a different problem` — park this one and work something else
- Use `header: "Scope change"` and `multiSelect: false`

**In both cases:** After completing work on one problem, run `problem work` again to pick up the next highest-WSJF problem. Keep going until the user says stop or no more problems are actionable.

## Steps

### 0. README reconciliation preflight (P118)

Before parsing the request, run the diagnose-only reconciliation check. The contract here catches **cross-session drift** that per-operation refresh paths (P094 refresh-on-create + P062 refresh-on-transition) cannot retroactively see — if any past session committed a ticket change without staging the README refresh, the next manage-problem invocation reads a stale README that lies about what is open / verifying / closed.

```bash
bash packages/itil/scripts/reconcile-readme.sh docs/problems
```

Exit-code routing:
- **Exit 0 (clean)**: continue to Step 1.
- **Exit 1 (drift detected)**: structured diff lines printed to stdout, one per drift entry (≤150 bytes per ADR-038 progressive-disclosure budget). **Halt this invocation** with a directive to invoke `/wr-itil:reconcile-readme` (interactive mode) or auto-route through the same skill in non-interactive mode (per ADR-013 Rule 6, AFK orchestrator). The reconciliation must complete and commit before this manage-problem invocation proceeds — proceeding into ticket creation / update / transition with a stale README would re-encode the drift into the post-operation refresh and propagate the lie.
- **Exit 2 (parse error)**: README missing or malformed. Halt with the parse-error message; this needs investigation, not mechanical reconciliation. AFK orchestrators halt-with-report per ADR-013 Rule 6.

This is a **preflight CHECK only** — manage-problem does NOT itself apply edits. The edit application lives in `/wr-itil:reconcile-readme`'s Step 4 with narrative preservation. Per architect verdict on P118 (Q3): manage-problem and work-problems Step 0 invoke the script (cheap mechanical check); transition-problem does NOT (P062 already covers transition-time refresh inside the same commit, redundant preflight there would pay the cost on every transition).

This step is a robustness layer ON TOP of P094 + P062, not a supersession of either — both per-operation contracts remain in force at Step 5 (creation refresh) and Step 7 (transition refresh).

### 1. Parse the request

Determine the operation from `$ARGUMENTS`:
- If arguments start with a number (e.g., "011") **followed by a status word** (`known-error`, `verifying`, or `close`), **delegate to `/wr-itil:transition-problem`** via the Skill tool. See "Deprecated-argument forwarders" below.
- If arguments start with a bare number (e.g., "011" with no status word after it), this is an update flow — handled inline by the ticket-body edit steps (Step 6).
- If arguments contain "list", **delegate to `/wr-itil:list-problems`** via the Skill tool. See "Deprecated-argument forwarders" below.
- If arguments contain "work", **delegate to `/wr-itil:work-problem`** via the Skill tool. See "Deprecated-argument forwarders" below.
- If arguments contain "review", **delegate to `/wr-itil:review-problems`** via the Skill tool. See "Deprecated-argument forwarders" below.
- Otherwise, this is a new problem creation

#### Deprecated-argument forwarders (ADR-010 amended + P071)

Per ADR-010's amended Skill Granularity section, word-argument subcommands that name distinct user intents are being split into their own named skills. During the deprecation window, this skill's Step 1 parser retains the legacy argument routes as **thin-router forwarders** that re-invoke the new named skill via the Skill tool AND emit a one-line systemMessage with the canonical deprecation notice so the user learns the new invocation shape.

**Forwarder for `list`** (P071 split slice 1 — new skill `/wr-itil:list-problems`):

When `$ARGUMENTS` contains the word `list` as a top-level argument (not inside a ticket body edit), delegate to `/wr-itil:list-problems` via the Skill tool and emit this systemMessage verbatim:

> `/wr-itil:manage-problem list is deprecated; use /wr-itil:list-problems directly. This forwarder will be removed in @windyroad/itil's next major version.`

The forwarder does NOT re-implement the list logic locally — it invokes the Skill tool with `wr-itil:list-problems` and returns the new skill's output verbatim. Duplicating the logic would harden the deprecation window into a permanent fork.

**Forwarder for `review`** (P071 split slice 2 — new skill `/wr-itil:review-problems`):

When `$ARGUMENTS` contains the word `review` as a top-level argument (not inside a ticket body edit), delegate to `/wr-itil:review-problems` via the Skill tool and emit this systemMessage verbatim:

> `/wr-itil:manage-problem review is deprecated; use /wr-itil:review-problems directly. This forwarder will be removed in @windyroad/itil's next major version.`

The forwarder does NOT re-implement the review logic locally — it invokes the Skill tool with `wr-itil:review-problems` and returns the new skill's output verbatim. Duplicating the Step 9 re-scoring / auto-transition / verification-prompt / README-refresh stack would harden the deprecation window into a permanent fork.

**Forwarder for `work`** (P071 split slice 3 — new skill `/wr-itil:work-problem`, singular):

When `$ARGUMENTS` contains the word `work` as a top-level argument (not inside a ticket body edit), delegate to `/wr-itil:work-problem` via the Skill tool and emit this systemMessage verbatim:

> `/wr-itil:manage-problem work is deprecated; use /wr-itil:work-problem directly. This forwarder will be removed in @windyroad/itil's next major version.`

The forwarder does NOT re-implement the selection logic locally — it invokes the Skill tool with `wr-itil:work-problem` and returns the new skill's output verbatim. Duplicating the freshness-check / AskUserQuestion selection / delegate-to-`manage-problem <NNN>` stack would harden the deprecation window into a permanent fork. Note the singular/plural distinction: the forwarder targets `/wr-itil:work-problem` (singular, one ticket per invocation), NOT `/wr-itil:work-problems` (plural AFK orchestrator). The two names coexist intentionally per P071.

**Forwarder for `<NNN> <status>` transitions** (P071 split slice 4 — new skill `/wr-itil:transition-problem`):

When `$ARGUMENTS` starts with a three-digit ticket ID followed by a status word (`known-error`, `verifying`, or `close`), delegate to `/wr-itil:transition-problem` via the Skill tool and emit the canonical deprecation notice verbatim, naming the specific argument form the user supplied:

> `/wr-itil:manage-problem <NNN> <status> is deprecated; use /wr-itil:transition-problem <NNN> <status> directly. This forwarder will be removed in @windyroad/itil's next major version.`

The parser must distinguish a **bare `<NNN>`** (update flow — handled inline by Step 6) from a **`<NNN> <status>` pair** (transition — delegated). The status-word tokens that trigger the transition forwarder are fixed: `known-error`, `verifying`, `close`. Any other suffix after `<NNN>` routes to the inline update flow per Step 6. This preserves the two legitimate shapes the original subcommand carried while splitting the transition intent out cleanly.

The forwarder does NOT re-implement the Step 7 transition logic locally — it invokes the Skill tool with `wr-itil:transition-problem` and returns the new skill's output verbatim. Duplicating the pre-flight-checks / P063-external-root-cause-detection / P057-staging-trap / P062-README-refresh stack would harden the deprecation window into a permanent fork. Per ADR-010 amended "Split-skill execution ownership" (P093), the forwarder is **one-way** — `/wr-itil:transition-problem` hosts its own inline Step 7 block and does NOT re-invoke `/wr-itil:manage-problem`. The in-skill Step 7 block below stays in place for in-skill callers (Step 9b auto-transition, the Parked path, Step 9d closure inside review); the split skill carries a scoped inline copy for the user-initiated transition path only ("copy, not move"). Lifecycle completeness (known-error + verifying + close) is covered per ADR-022's three-status mandate.

### 2. For new problems: Check for duplicates FIRST

Before creating, search existing problems for similar issues. The user may not know a problem already exists.

1. Extract keywords from the description/title (e.g., "foul drawn", "checkpoint", "delete", "stuck saving")
2. Search all files in `docs/problems/` for those keywords using Grep
3. Read the title and status of each match
4. If matches are found, present them to the user via `AskUserQuestion`:
   - "I found existing problems that may be related: P011 (stuck saving, CLOSED), P023 (foul drawn garbled, OPEN). Would you like to: (a) Update an existing problem, (b) Create a new problem anyway, (c) Cancel?"
5. If the user chooses to update, switch to the update flow for that problem ID
6. If no matches found, proceed to create
7. **After the grep completes** (whether duplicates were found or not), write the per-session create-gate marker so the `PreToolUse:Write` hook (`packages/itil/hooks/manage-problem-enforce-create.sh`, P119) allows the subsequent Write of the new `.open.md` file. The marker is `/tmp/manage-problem-grep-${SESSION_ID}` and the agent writes it via Bash by sourcing the session-id discovery helper (P124) and calling the existing `mark_step2_complete` helper:

   ```bash
   source packages/itil/hooks/lib/session-id.sh
   source packages/itil/hooks/lib/create-gate.sh
   sid=$(get_current_session_id) && mark_step2_complete "$sid"
   ```

   `get_current_session_id` (P124) returns the canonical session UUID by reading `CLAUDE_SESSION_ID` if exported, else by scraping the most-reliable per-session announce marker (`/tmp/<system>-announced-<UUID>`, set on prompt 1 of every session per ADR-038 by architect / jtbd / tdd / style-guide / voice-tone / itil-assistant-gate / itil-correction-detect hooks). It exits non-zero if no session can be discovered — the `&&` short-circuits the marker write so the agent never lands `/tmp/manage-problem-grep-` (an empty UUID would never match the hook's stdin-JSON `session_id` and would silently fail later). `mark_step2_complete` (existing helper from `create-gate.sh`) writes the marker file under the canonical path; the marker is per-session (single marker covers all new tickets for the rest of this session), enabling Step 4b multi-concern splits and same-session unrelated-ticket creation without re-running the grep.

   **Why a helper instead of inline `${CLAUDE_SESSION_ID:-default}`**: the agent's process does NOT export `CLAUDE_SESSION_ID` today; the hook side reads `session_id` from its stdin JSON payload (per the Claude Code PreToolUse contract). The prior fallback wrote the marker under `default` while the hook checked the real UUID — mismatch caused the Write deny on every first ticket of a session until the agent ad-hoc scraped a UUID-bearing marker. The helper canonicalises that scrape so every agent context discovers the SID the same way. P124.

**Search strategy**: Search problem filenames AND file content. A match on the filename (kebab-case title) or the Description/Symptoms sections counts. Cast a wide net — false positives are cheap (user chooses), but false negatives mean duplicate problems.

**Hook contract (P119)**: writing a `.open.md` (or any `.<status>.md`) file under `docs/problems/` without first running this Step 2 grep + marker-touch is blocked by the `manage-problem-enforce-create.sh` PreToolUse hook with a `permissionDecision: deny` directing the agent back to this skill. Agents that try to bypass the skill (e.g. mid-retrospective inline capture, post-mortem wrap-up, or any "I'll just write it directly" shortcut) will hit the deny and be redirected here. Do not work around the deny by setting the marker manually — the marker exists to record that this Step 2 ran, and a marker without a grep is the audit-trail gap P119 closes.

### 3. For new problems: Assign the next ID

Compute the next ID as the **max of the local and origin highest IDs**, plus one, zero-padded to 3 digits. Comparing against `origin/<base>` is required by ADR-019 (confirmation criterion 2): without it, parallel sessions can mint the same ID for different problems and force a destructive surgical rebase on push (P040 incident).

```bash
# Local-max ID
local_max=$(ls docs/problems/*.md 2>/dev/null | sed 's/.*\///' | grep -oE '^[0-9]+' | sort -n | tail -1)

# Origin-max ID — `git ls-tree origin/<base>` reads remote-tracking ref
# without requiring a fetch in this step (Step 0 preflight is the place
# where the fetch happens). Default base is `main`; if the user is on
# another branch, swap accordingly.
#
# `--name-only` is required (P056): without it, each ls-tree line is
# `<mode> <type> <sha>\t<path>` and the 40-char blob SHA can contain
# three-digit runs that `grep -oE '[0-9]{3}'` false-matches (observed
# `origin_max=997` on 2026-04-20 opening P055). `sed` strips the path
# prefix so the anchored `grep -oE '^[0-9]+'` only picks up filename IDs.
origin_max=$(git ls-tree --name-only origin/main docs/problems/ 2>/dev/null | sed 's|^docs/problems/||' | grep -oE '^[0-9]+' | sort -n | tail -1)

# Take the max of the two and increment.
next=$(printf '%03d' $(( $(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
```

If the local choice would have collided with an origin ticket created since the last fetch, the `git ls-tree origin/<base>` lookup catches it here and the renumber is automatic. Log the renumber decision in the operation report (e.g. "Bumped next ID from 042 → 043 to avoid collision with origin").

### 4. For new problems: Gather information

If the arguments contain a description, extract what you can. For anything missing, use `AskUserQuestion` to gather:

- **Title**: Short kebab-case-friendly description
- **Description**: What is happening? What should happen instead?
- **Priority**: Impact (1-5) × Likelihood (1-5) per RISK-POLICY.md

Do NOT ask for fields that can be inferred:
- **Reported date**: Use today's date
- **Status**: Always "Open" for new problems
- **Symptoms**: Infer from description if possible
- **Workaround**: Default to "None identified yet." unless obvious from context

### 4b. For new problems: Concern-boundary analysis (multi-concern check)

Before writing the problem file, perform a concern-boundary analysis on the gathered description to prevent conflated tickets that make WSJF scoring meaningless (P016).

**Self-check**: Read the description and root cause information gathered in step 4. Answer: "How many distinct root causes are present? If fixed independently, how many separate fix paths exist?"

- **Single concern** (one root cause, one fix path): proceed directly to step 5.
- **Multiple concerns** (two or more distinct root causes, different components, or if the architect review flagged this needs its own ADR): present a split prompt.

**Split prompt** — use `AskUserQuestion`:
- `header: "Multi-concern problem"`
- `multiSelect: false`
- Options:
  1. `Split into separate problems (Recommended)` — description: "Create one problem ticket per distinct concern, with consecutive IDs. Each ticket gets its own priority, WSJF score, and fix path."
  2. `Keep as a single problem` — description: "Create one ticket covering all concerns. Use this only if the concerns are so tightly coupled that they cannot be fixed independently."

**Non-interactive fallback**: When `AskUserQuestion` is unavailable (e.g., non-interactive/AFK mode), automatically split into separate problems and note the auto-split in output. Do not block creation.

**Split implementation**: When splitting, assign consecutive IDs (e.g., if next ID is 035, create P035 and P036). Create each problem file independently. Cross-reference each ticket in the other's "Related" section.

**Scope**: This step applies only to **new problem creation** (steps 2–5). It does NOT apply to updates, status transitions, or reviews of existing tickets.

### 5. For new problems: Write the problem file

**File path**: `docs/problems/<NNN>-<kebab-case-title>.open.md`

**Template**:

```markdown
# Problem <NNN>: <Title>

**Status**: Open
**Reported**: <YYYY-MM-DD>
**Priority**: <score> (<label>) — Impact: <label> (<n>) x Likelihood: <label> (<n>)

## Description

<description>

## Symptoms

<bullet list of observable symptoms>

## Workaround

<workaround or "None identified yet.">

## Impact Assessment

- **Who is affected**: <personas>
- **Frequency**: <when/how often>
- **Severity**: <High/Medium/Low — reason>
- **Analytics**: <data source or N/A>

## Root Cause Analysis

### Investigation Tasks

- [ ] Investigate root cause
- [ ] Create reproduction test
- [ ] Create INVEST story for permanent fix

## Dependencies

- **Blocks**: <tickets that can't close until this one does — bare IDs, comma-separated; leave empty if none>
- **Blocked by**: <tickets that must close first — bare IDs, comma-separated; drives the transitive-effort rule; leave empty if none>
- **Composes with**: <tickets whose work overlaps but neither blocks the other — does NOT propagate effort; leave empty if none>

## Related

<links to related files, problems, ADRs>
```

The `## Dependencies` section uses **bare ticket IDs** (`P038`, not `[P038](./038-...)` link syntax) — review output renders to links on demand. An empty row is valid and explicit: `- **Blocked by**: (none)` reads better than omitting the row. The transitive-effort rule in the WSJF Prioritisation section consumes this section at review time.

**Concrete example** (for P073 referencing two upstreams):

```markdown
## Dependencies

- **Blocks**: (none)
- **Blocked by**: P038, P064
- **Composes with**: (none)
```

#### README.md refresh on new ticket (P094)

After writing the new `.open.md` file, regenerate `docs/problems/README.md` to insert the new ticket's row into the WSJF Rankings, and stage the refreshed README in the same commit as the new ticket. Without this refresh, new tickets are absent from the ranked table until the next `/wr-itil:review-problems` invocation or the next Step 7 transition — staleness accumulates silently on every creation-only session.

**Mechanism**: use the same rendering rules as Step 7's P062 block (glob `docs/problems/*.open.md` / `*.known-error.md` / `*.verifying.md` / `*.parked.md`; rank open/known-error by WSJF; list verifyings in the Verification Queue ordered by release age; list parkeds in the Parked section). The refresh is a **render, not a re-rank** — existing WSJF values on the other ticket files are trusted per P062's established discipline. Only the new ticket's own WSJF is consumed from its freshly-written file.

**WSJF Rankings tie-break sort (P138)**: rows in the WSJF Rankings table are sorted by the multi-key `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)` so the rendered top-to-bottom row order matches `/wr-itil:work-problems` SKILL.md Step 3's tie-break selection 1:1. The first key (WSJF desc) sets the tier; within a tier the next three keys are the canonical tie-break ladder (Known Error before Open; smaller effort before larger; older Reported date before newer); ID asc is the deterministic final tiebreaker for full-tie cases. The table MUST include a `Reported` column so the third tie-break input is visible to README readers — without it, users cannot reconcile the rendered order against the orchestrator's selection. <!-- TIE-BREAK-LADDER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 --> Any future change to the tie-break ladder MUST update this render block, the Step 7 P062 block, the Step 9e template, AND `/wr-itil:review-problems` SKILL.md Step 3 / Step 5 — drift here re-opens P138.

1. After `Write`-ing the new `.open.md` file (and, for multi-concern splits per step 4b, after all split files are written), regenerate `docs/problems/README.md` in-place reflecting the new filename set.
2. Update the "Last reviewed" line per the **Last-reviewed line discipline (P134)** subsection below — name the new ticket as the most-recent fragment (e.g. `P<NNN> opened — <one-line title>`); displaced prior fragments rotate to `docs/problems/README-history.md`.
3. `git add docs/problems/README.md` — the stage list at Step 11 must include it alongside the new `.open.md` file (Step 11's `git add -u` catch-all handles tracked-file modifications; the new README render lands via this path when README.md already exists in git, and via an explicit `git add docs/problems/README.md` when it is newly created). When line-3 truncation displaces prior content, also `git add docs/problems/README-history.md`.

For the multi-concern split path (step 4b), the refresh fires **once** after all split tickets are written, not per-split — a single render captures the full new set in one pass.

#### Last-reviewed line discipline (P134)

The "Last reviewed" line (line 3 of `docs/problems/README.md`) was designed as a short audit marker — one ticket name + one transition reason — but historically accumulated multi-paragraph session-summary fragments unbounded ("Prior:" stacking on every refresh). At ~62 KB / 76 KB it crossed the Read-tool 25K-token whole-file limit and could no longer be window-read at any offset/limit. P134 closes the accumulator on this surface; sibling to P099 on `docs/briefing/<topic>.md`.

**Contract** — applies to every refresh that touches line 3 (Step 5 P094 creation, Step 6 P094 conditional update, Step 7 P062 transition; mirrored in `transition-problem`, `transition-problems`, `review-problems`, `reconcile-readme`):

1. **Single most-recent fragment only on line 3.** The "Last reviewed" parenthetical names ONE event — the operation this refresh covers. Do NOT prepend a `Prior:` segment, do NOT stack multi-paragraph rationale, do NOT carry history forward inline.
2. **Soft cap: ≤ 1024 bytes per fragment.** Authoring guidance — keep the fragment dense and audit-meaningful (ticket ID + verb + one-line summary + ADR/JTBD anchors when load-bearing). Multi-paragraph rationale belongs in retros, ticket bodies, and ADR amendments — never on line 3.
3. **Archive sibling: `docs/problems/README-history.md`.** When this refresh would displace prior line-3 content, append the displaced content to `README-history.md` BEFORE writing the new line 3. Forward-chronology — newest fragment goes at the bottom under a date heading (`## YYYY-MM-DD`). The archive is a log; it's grep-and-tail territory, not display-tier (which is why its chronology diverges from the README's reverse-chrono surface convention).
4. **Hard ceiling: 5120 bytes on line 3.** Matches ADR-040 Tier 3 envelope. Surfaced advisory-only by `packages/itil/scripts/check-problems-readme-budget.sh` — the script emits `OVER docs/problems/README.md line=3 bytes=<N> threshold=<N>` when the ceiling is breached. Always exits 0 (advisory; overflow is signal, not failure).

**Mechanism** (when authoring a refresh):

1. Read the current line 3 of the README (e.g. `awk 'NR==3' docs/problems/README.md`).
2. If the current line 3 is non-empty AND the new fragment is not a near-duplicate (same ticket + same verb in the same session): append the current line 3 verbatim to `docs/problems/README-history.md` under a `## YYYY-MM-DD` heading (creating the heading on first append for that date; subsequent same-day appends nest under the existing heading).
3. Compose the new line 3 as a single paragraph naming the operation only. Keep ≤ 1024 bytes.
4. Replace line 3 of README.md with the new paragraph.
5. Stage both files in the same commit as the ticket change per ADR-014: `git add docs/problems/README.md docs/problems/README-history.md`.

**Fast-path interaction**: the Step 9 freshness check uses git-mtime on `docs/problems/README.md`, NOT the prose contents of line 3. Truncating line 3 does NOT degrade the fast-path contract.

**Cross-references**: ADR-040 line 92 (reusable accumulator-doc pattern — explicitly names "problems index"), ADR-038 (progressive disclosure), ADR-014 (single-commit governance), `packages/itil/scripts/check-problems-readme-budget.sh`, `packages/itil/scripts/test/check-problems-readme-budget.bats`.

### 6. For updates: Edit the existing file

Find the file matching the problem ID:
```bash
ls docs/problems/<NNN>-*.md 2>/dev/null
```

Apply the update — this could be:
- Adding root cause evidence to the "Root Cause Analysis" section
- Checking off investigation tasks
- Adding a "Fix Strategy" section
- Adding "Related" links
- Updating priority based on new information

#### README.md refresh on conditional update (P094)

If the update changed the ticket's **Priority**, **Effort**, or **WSJF** line, regenerate `docs/problems/README.md` to reflect the new ranking and stage it in the same commit as the update. If the update was to other sections (Root Cause Analysis, Symptoms, Related, Dependencies, etc.) and did NOT change the ranking-bearing fields, skip the refresh — the rendered table would be identical and the cost is not load-bearing.

**Trigger rule**: refresh if any of these lines changed between pre-edit and post-edit:

- `**Priority**: ...` (Impact × Likelihood line)
- `**Effort**: ...`
- `**WSJF**: ...`

If the edit touched only `## Root Cause Analysis`, `## Symptoms`, `## Workaround`, `## Dependencies`, `## Related`, or other non-ranking sections, skip the refresh. A conservative check is: run a diff of the pre-edit vs post-edit file and grep for any of the three field labels above in the diff's `+` / `-` lines; if none match, skip.

**Mechanism** (when the trigger fires):

1. Regenerate `docs/problems/README.md` using the same render rules as Step 7's P062 block — render, not re-rank. Trust every other ticket's stored WSJF; consume only this ticket's updated WSJF from the post-edit file.
2. Update the "Last reviewed" line per the **Last-reviewed line discipline (P134)** subsection in Step 5 above — name the re-rated ticket as the most-recent fragment (e.g. `P<NNN> re-rated — <old-WSJF> → <new-WSJF>`); displaced prior fragments rotate to `docs/problems/README-history.md`.
3. `git add docs/problems/README.md` so the refresh rides the same commit as the ticket update per ADR-014. When line-3 truncation displaces prior content, also `git add docs/problems/README-history.md`.

**Dependency ripple**: if this update changed the ticket's Effort, and the ticket is an upstream of other tickets (any ticket's `## Dependencies` → `**Blocked by**` list references this ID), the transitive-effort rule (P076) says dependents may need to re-rate too. The surgical render in this step does NOT re-walk the graph — that is Step 9b.1's job. If the dependency graph is known to be non-trivial, prefer `/wr-itil:review-problems` instead of a bare update; the review path handles the re-walk deterministically. The conditional refresh here is sufficient for the common case of a self-only re-rate.

### 7. For status transitions

**Open → Known Error** (rename file, update content):

Known Error means "root cause confirmed, fix path clear, fix NOT yet released" (per ADR-022). Releasing the fix is a separate Known Error → Verification Pending transition — do NOT stay on `.known-error.md` after the fix ships.

Pre-flight checks before allowing transition:
- [ ] Root cause is documented (not just "Preliminary Hypothesis")
- [ ] At least one investigation task is checked off
- [ ] A reproduction test exists or is referenced
- [ ] A workaround is documented (even if "feature disabled")
- [ ] Effort bucket re-rated against the now-documented fix strategy; if the bucket changed since creation, update the Effort / WSJF lines and note the reason (P047 — creation-time estimates drift as scope clarifies)

If any check fails, report which checks failed and ask the user to address them before transitioning.

#### External-root-cause detection (P063)

Before renaming the file, scan the ticket's Root Cause Analysis section for external-root-cause markers. The same detection fires when parking a ticket with the `upstream-blocked` reason (see the Parked lifecycle entry at the top of this skill — it routes back to this block).

**Strict detection tokens** (any of the following within the Root Cause Analysis section counts as a hit):

- Literal label words: `upstream`, `third-party`, `external`, `vendor`.
- Scoped npm package pattern: `@[\w-]+/[\w-]+` (e.g. `@anthropic/claude-code`, `@windyroad/itil`).

Bash heuristic:

```bash
if grep -iE '\b(upstream|third-party|external|vendor)\b|@[[:alnum:]_-]+/[[:alnum:]_-]+' "$problem_file"; then
  external_root_cause_detected=1
fi
```

Detection is intentionally **strict** (explicit label or scoped-npm package only) to avoid prompt fatigue (P063 Direction decision). A passing reference to a bare package name (`gh`, `npm`) does NOT trigger the prompt.

**Already-noted check** — before firing the prompt, grep the ticket for the stable marker `- **Upstream report pending** —` (written by option 2 / the AFK fallback below) or `- **Reported Upstream:**` / a `## Reported Upstream` section (written by `/wr-itil:report-upstream` Step 7 back-write per ADR-024 Confirmation criterion 3a). If any of those are already present, skip the prompt — the detection has already fired on a prior run.

**If the detection fires and nothing has been noted yet**, use `AskUserQuestion`:

- `header: "External root cause detected"`
- `multiSelect: false`
- Options:
  1. `Invoke /wr-itil:report-upstream now` — halt the transition; the skill runs (it writes the `## Reported Upstream` appendage per ADR-024 Confirmation criterion 3a); the transition resumes afterwards.
  2. `Defer and note in ticket` — append a pending-upstream-report line to the ticket's `## Related` section using the stable marker `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready`. The marker wording is fixed so subsequent runs (and the work-problems `upstream-blocked` skip path) can detect "already noted" without re-firing.
  3. `Not actually upstream` — proceed without invocation; append the same marker with text `- **Upstream report pending** — false positive; detection misfire` so the prompt does not re-fire on later reviews.

**Non-interactive (AFK) branch** (per ADR-013 Rule 6): when `AskUserQuestion` is unavailable, default to option 2 — append the pending-upstream-report line with the stable `- **Upstream report pending** —` marker. Do NOT auto-invoke `/wr-itil:report-upstream`; its Step 6 security-path branch is interactive and would halt the orchestrator anyway (per ADR-024 Consequences). The appended line lets the user see the deferred action when they return.

**Scope**: this detection block fires at two points —

- **Open → Known Error transition** (this step, primary insertion point).
- **Parking path with `upstream-blocked` reason** — the parking workflow runs the same detection before `git mv` to `.parked.md`. Parking an upstream-blocked ticket without having noted (or reported) the upstream dependency is the canonical audit-trail gap this block closes.

The work-problems orchestrator's `upstream-blocked` skip path (see `packages/itil/skills/work-problems/SKILL.md` classifier table) runs the AFK fallback before skipping, so ticket bodies accumulate the marker even when the orchestrator never invokes `manage-problem` on them.

> **Staging trap (P057).** `git mv` stages only the rename — it does NOT pick up subsequent `Edit`-tool content changes. After the `Edit` tool modifies the renamed file (Status field, `## Fix Released` section, etc.), re-stage it explicitly: `git add <new>`. Without the explicit re-stage, the transition commit captures the rename-only change and the content edit leaks into the next commit, corrupting the audit trail. This rule applies to every `git mv` block below (Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed) and to the supersession rename in `create-adr` Step 6.

```bash
git mv docs/problems/<NNN>-<title>.open.md docs/problems/<NNN>-<title>.known-error.md
# ... use the Edit tool to update the Status field ...
git add docs/problems/<NNN>-<title>.known-error.md
```

Update the "Status" field in the file to "Known Error".

**Known Error → Verification Pending** (fix released, per ADR-022):

When the fix for a Known Error ships, transition the ticket in a single commit:

```bash
git mv docs/problems/<NNN>-<title>.known-error.md docs/problems/<NNN>-<title>.verifying.md
# ... use the Edit tool to update Status and add the `## Fix Released` section ...
git add docs/problems/<NNN>-<title>.verifying.md
```

Then edit the file:
- Update the "Status" field to "Verification Pending"
- Add a `## Fix Released` section with: release marker (version, commit SHA, or date), one-sentence fix summary, "Awaiting user verification" line, and any exercise evidence from the releasing session.

Re-stage the `.verifying.md` file explicitly after the `Edit` tool runs (P057). The second `git add` above is NOT redundant — `git mv` alone stages only the rename, not the subsequent content edit.

Both the `git mv` and the file edits belong in the same commit as the fix implementation per ADR-014 (governance skills commit their own work). The `.verifying.md` suffix signals to every downstream consumer (work-problems classifier, review step 9d, README rendering) that the remaining work is user-side verification — no file-body scan needed.

**Verification Pending → Closed** (user confirms):

Only the user can make this call. When they explicitly confirm the fix works in production:

```bash
git mv docs/problems/<NNN>-<title>.verifying.md docs/problems/<NNN>-<title>.closed.md
# ... use the Edit tool to update the Status field to "Closed" ...
git add docs/problems/<NNN>-<title>.closed.md
```

Update the "Status" field to "Closed". Reference the problem ID in the closure commit message (e.g., "Closes P008"). Step 9d's verification prompt is the structured path that fires this transition during `manage-problem review`. Re-stage the `.closed.md` file explicitly after the Edit (P057 staging trap).

#### README.md refresh on every transition (P062)

Every Step 7 status transition (Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed, Parked — regardless of source or destination suffix) regenerates `docs/problems/README.md` and stages it in the same commit so the dev-work table, Verification Queue, Parked section, and "Last reviewed" line never lag the on-disk ticket inventory. Without this step, README.md accumulates staleness between `review` invocations; the next `work` fast-path check correctly detects the lag and forces a full rescan (self-healing but wasteful), and any human browsing the file between transitions sees outdated rankings.

The refresh uses the same rendering rules as Step 9e (glob `docs/problems/*.open.md` / `*.known-error.md` / `*.verifying.md` / `*.parked.md`; rank open/known-error by WSJF; list verifyings in the Verification Queue ordered by release age; list parkeds in the Parked section) but skips the full re-scoring pass — existing WSJF values on the ticket files are trusted. The refresh is a render, not a re-rank.

**WSJF Rankings tie-break sort (P138)**: rows in the WSJF Rankings table are sorted by the multi-key `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)` so the rendered top-to-bottom row order matches `/wr-itil:work-problems` SKILL.md Step 3's tie-break selection 1:1. Within each WSJF tier, rows are ordered by the canonical tie-break ladder: Known Error before Open, smaller Effort before larger, older Reported date before newer. The table MUST include a `Reported` column so the third tie-break input is visible to README readers. <!-- TIE-BREAK-LADDER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 --> Any future change to the tie-break ladder MUST update this render block, the Step 5 P094 block, the Step 9e template, AND `/wr-itil:review-problems` SKILL.md Step 3 / Step 5 — drift here re-opens P138.

**Mechanism:**

1. After renaming + Editing + `git add`-ing the transitioned ticket file (per the staging-trap rule above), regenerate `docs/problems/README.md` in-place reflecting the new filename set and the transitioned ticket's new Status.
2. `git add docs/problems/README.md` — stage the refreshed README with the same commit as the transition.
3. Update the "Last reviewed" line per the **Last-reviewed line discipline (P134)** subsection in Step 5 above — name the transition as the most-recent fragment (e.g. `P<NNN> <status> — <one-line fix summary>`); displaced prior fragments rotate to `docs/problems/README-history.md`. When the rotation displaces prior content, the staged file set MUST include both `docs/problems/README.md` AND `docs/problems/README-history.md` per ADR-014 single-commit grain.

**Scope**: fires for every Step 7 rename. Applies equally to:
- Standalone transition commits (e.g. `docs(problems): P<NNN> known error — <summary>`).
- **Folded-fix commits** where the `.verifying.md` transition rides with the fix implementation commit (e.g. `fix(<scope>): <description> (closes P<NNN>)` — per Step 11's convention for Known Error → Verification Pending). In both cases the refreshed README.md joins the same commit as the rename + content edit; never split across commits.

**Fast-path interaction**: the Step 9 fast-path freshness check (`git log -1 --format=%H -- docs/problems/README.md` followed by `git log --oneline "${readme_commit}..HEAD" -- 'docs/problems/*.md'`) remains the authoritative staleness test. When this refresh fires on every transition, that check should return empty on any subsequent invocation — the cache stays fresh by construction. If the check still reports "stale", something skipped the refresh (bug) and the slow-path is the correct recovery.

### 8. For list: Show summary

Read all `.open.md` and `.known-error.md` files in `docs/problems/`. Extract ID, title, priority, and status. Sort by priority (highest first). Display as a markdown table.

### 9. For review: Re-assess all open problems

This is a batch operation that reviews every open/known-error problem and updates it.

**Fast-path for `work` (skip full re-scan when cache is fresh):**

Before running the full review, check whether `docs/problems/README.md` exists and is up to date using **git history** (not filesystem mtime, which is unreliable in worktrees and fresh checkouts — see P031):

```bash
readme_commit=$(git log -1 --format=%H -- docs/problems/README.md 2>/dev/null)
# Cache is stale if: no README commit, OR problem files committed since README, OR uncommitted problem file changes
if [ -z "$readme_commit" ] || \
   git log --oneline "${readme_commit}..HEAD" -- 'docs/problems/*.md' ':!docs/problems/README.md' 2>/dev/null | grep -q .; then
  echo "stale"
fi
```

If the command produces **no output** (no problem files have been committed or modified since the last README.md update), the cache is fresh:
- Read `docs/problems/README.md` only — it contains the ranked table from the last review
- Skip steps 9a–9b entirely
- Proceed to step 9c (work selection) using the cached table
- **Step 9d always fires even on the fast-path cache hit** (P048 Candidate 1): the verification prompt surface must not depend on whether the cache is fresh — pending verifications accumulate across sessions and the user expects the prompts to appear on every `review`. Skipping 9d alongside 9a–9b would suppress verification prompts whenever the cache is fresh, which is exactly when the user is most likely to verify.
- Note in the output: "Using cached ranking from [timestamp in README.md]"

If the command prints "stale", or `README.md` does not exist in git, run the full review (steps 9a–9e) and refresh the cache.

**Step 9a: Read the risk framework**

Read `RISK-POLICY.md` to get the current impact levels (1-5), likelihood levels (1-5), risk matrix, and label bands. These are the authoritative definitions — do not use outdated scales.

**Step 9b: For each open/known-error problem (skip `.parked.md` and `.verifying.md` files entirely):**

Parked problems and Verification Pending problems are excluded from WSJF ranking — do not read, score, or update them in this step. Parked tickets are shown in a dedicated Parked section in step 9c; Verification Pending tickets are shown in a dedicated Verification Queue section in step 9c (ranked by release age, not WSJF — per ADR-022).

1. Read the problem file
2. Read the codebase context — check if the problem's root cause has been investigated, if there are related fixes in git history, or if the problem is stale
3. **Re-assess Impact** (1-5) using the product-specific impact levels from RISK-POLICY.md. Ask: "If this problem occurs during a live game, what is the worst business consequence?"
4. **Re-assess Likelihood** (1-5) using the likelihood levels from RISK-POLICY.md. Ask: "Given the current codebase, how likely is this to affect the user?"
5. **Calculate Severity** = Impact × Likelihood
6. **Look up Label** from the risk matrix label bands
7. **Re-estimate Effort** (S / M / L / XL) by reading the root cause analysis and fix strategy. Consider: how many files, how complex, does it need planning, is it cross-package or migration-heavy (XL territory)? If the bucket has changed since last review, update the Effort line in the problem file and note the reason in a short parenthetical (e.g. "L → XL — architect review added ADR + migration script"). P047.
8. **Calculate WSJF** = (Severity × Status Multiplier) / Effort Divisor
9. **Update the Priority line** in the problem file if the score changed
10. **Auto-transition to Known Error**: If an open problem has confirmed root cause AND a workaround documented (even "feature disabled"), automatically transition it to known-error:
    - `git mv docs/problems/<NNN>-<title>.open.md docs/problems/<NNN>-<title>.known-error.md`
    - Update the Status field to "Known Error"
    - This happens automatically — do not ask the user

**Step 9b.1: Dependency-graph traversal — propagate transitive effort (P076)**

After every `.open.md` / `.known-error.md` ticket has a marginal effort, run a **second pass** that walks the dependency graph and propagates effort up per the transitive-dependency rule (see the WSJF Prioritisation section's "Transitive dependencies" subsection). This is a deterministic re-rate — no `AskUserQuestion` required.

1. **Build the graph**: for each `.open.md` / `.known-error.md` ticket, parse the `## Dependencies` section. Record `Blocked by` edges (bare IDs) into an adjacency map. Ignore `Composes with` (does not propagate) and `Blocks` (derivable from inverse).
2. **Classify upstream status**: for each upstream ID referenced in any `Blocked by` edge, resolve the file suffix. Upstreams in `.closed.md`, `.verifying.md`, or `.parked.md` contribute **0** to the closure per the carve-out. Upstreams in `.open.md` or `.known-error.md` contribute their own transitive effort.
3. **Topologically sort** the open/known-error subgraph so upstream tickets are scored before their dependents. If a cycle is detected (two or more tickets mutually `Blocked by` each other), treat the strongly-connected component as a **bundle** with effort = `max{ marginal | members }`.
4. **Compute transitive effort** for each ticket in topological order using `Effort_transitive = max(marginal, max{ upstream transitive })`. Cycle-bundle members all receive the bundle's effort.
5. **Update Effort and WSJF lines**: if a ticket's transitive effort differs from its marginal, edit the Effort line to the transitive bucket (S → M / L / XL as needed), recompute WSJF, and update the Priority and WSJF lines. Write a short audit trail in a `<!-- transitive: <bucket> via <UPSTREAM> -->` HTML comment on the Effort line so the next review can distinguish a manually-set marginal from a propagated transitive.
6. **Report each re-rate** in the review summary using the concrete format:

   ```
   P<NNN>: Effort <OLD> → <NEW> (transitive via <UPSTREAM>)
   ```

   Example: `P073: Effort S → XL (transitive via P038)`. The shape is fixed so downstream audit tools can grep it deterministically.

7. **Cycle-bundle output**: for cycle bundles, surface a shared WSJF line covering all members, e.g. `Bundle [P038, P064]: effort XL (cycle), WSJF 3.0 (shared)`. The shared WSJF is a computed artefact of the review rendering — do NOT write a shared-bundle field into the individual ticket files.

The re-rate pass is part of Step 9b's output — a re-rate row appears in the step 9c ranked table with the transitive effort (not the marginal). Hide the marginal from the main table but preserve it in the ticket's HTML-comment audit trail so a future review knows where the propagation came from.

**Step 9c: Present summary and select problem to work**

After reviewing all problems, present a WSJF-ranked table for open/known-error problems (the main dev-work queue). Sort rows by `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)` so row order matches `/wr-itil:work-problems` Step 3 tie-break selection 1:1 (P138):

| WSJF | ID | Title | Severity | Status | Effort | Reported | Notes |
|------|-----|-------|----------|--------|--------|----------|-------|

Then present a separate **Verification Queue** section for `.verifying.md` files (per ADR-022 — ranked by release age, oldest first; no WSJF because the multiplier is 0). Highlight each ticket whose release age is **≥ 14 days** (the within-skill default per P048 Candidate 4 — tunable; if it needs cross-skill consistency later, promote to policy) with a `likely verified` marker in the final column. This makes the Verification Queue not just a list but a ranked view of which verifications are most likely ready to close:

| ID | Title | Released | Fix summary | Likely verified? |
|----|-------|----------|-------------|------------------|

The `Likely verified?` column takes values:
- `yes (N days)` — release age ≥ 14 days; the user is unlikely to revert a landed fix after this long. Surface these first in step 9d's verification prompt so the user can batch-close them.
- `no (N days)` — release age < 14 days; may still be in validation. Fire step 9d for these too, but without the highlight.

Then present a separate **Parked** section listing `.parked.md` files (no ranking):

| ID | Title | Reason | Parked since |
|----|-------|--------|-------------|

Highlight:
- Problems whose priority changed (↑ or ↓)
- Problems that were auto-transitioned to known-error
- Problems that may be stale (reported > 2 weeks ago with no investigation progress)
- Problems that have been fixed but not closed (check git history for fix commits)
- Verification Pending tickets whose fix has been exercised repeatedly without regression (P048 detection layer — candidate for closure verification)

**When the operation is `work` (not just `review`), select the problem to work using `AskUserQuestion`:**

- If one problem has a strictly higher WSJF than all others, present it as the recommended option:
  - Option 1: `Work P<NNN>: <title> (Recommended)` — with description showing WSJF score and status
  - Option 2: `Pick a different problem` — let the user name a specific ID
- If two or more problems tie for the highest WSJF, present the tied problems as options:
  - One option per tied problem: `Work P<NNN>: <title>` — with description showing WSJF and a one-line rationale for why this one
  - Final option: `Pick a different problem`
- Use `header: "Next problem"` and `multiSelect: false`

**Never present the selection as prose "(a)/(b)/(c)" or "which would you like?"** — always use `AskUserQuestion` so the decision is structured and auditable.

**Step 9d: Check for pending verifications**

Target `docs/problems/*.verifying.md` via glob — do NOT scan `.known-error.md` bodies for a `## Fix Released` section (per ADR-022, Verification Pending is a first-class status, not a substring marker). For each `.verifying.md` file, the agent collects in-session evidence per Step 4a's "Exercised successfully in-session" pattern (test invocation + observable outcome per ADR-026 grounding). When evidence-citation is concrete and unambiguous, the agent **closes the ticket on evidence** by delegating to `/wr-itil:transition-problem <NNN> close` (per ADR-014 commit grain) WITHOUT firing `AskUserQuestion` — per ADR-044 framework-resolution boundary, evidence-grounded close is a framework-mediated decision (the agent applies ADR-022's evidence semantics; per-candidate ask is sub-contracting that resolution back to the user as lazy deferral per Step 2d Ask Hygiene Pass classification).

When evidence is **ambiguous, contested, or absent** (no specific in-session citation), leave the ticket as Verification Pending — same exclusion path as Step 4a. The user surfaces concerns via the P078 capture-on-correction surface (authentic-correction per ADR-044 category 6) if a close-on-evidence action was wrong; closes are reversible via `/wr-itil:transition-problem <NNN> known-error` (the verifying-flip-back path used in the 2026-04-27 P124 regression flip-back). The Step 9d output table records each close action with its triggering citation + the documented recovery path.

**Step 9e: Update files and refresh README.md cache**

Edit each problem file where the priority changed. Then write/overwrite `docs/problems/README.md` with the current ranked table so future `work` invocations can skip the full re-scan.

**WSJF Rankings tie-break sort (P138)**: rows in the WSJF Rankings table are sorted by the multi-key `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)` so the rendered top-to-bottom row order matches `/wr-itil:work-problems` SKILL.md Step 3's tie-break selection 1:1. Within a WSJF tier, rows are ordered by the canonical tie-break ladder: Known Error before Open, smaller Effort before larger, older Reported date before newer. The `Reported` column MUST appear so the third tie-break input is visible to README readers. <!-- TIE-BREAK-LADDER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 --> Any future change to the tie-break ladder MUST update this template, the Step 5 P094 block, the Step 7 P062 block, AND `/wr-itil:review-problems` SKILL.md Step 3 / Step 5 — drift here re-opens P138.

```markdown
# Problem Backlog

> Last reviewed: <ISO timestamp>
> Run `/wr-itil:manage-problem review` to refresh.

## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort | Reported |
|------|-----|-------|----------|--------|--------|----------|
| <score> | P<NNN> | <title> | <severity> | <status> | <effort> | <YYYY-MM-DD> |
...

## Verification Queue

Fix released, awaiting user verification (driven off `docs/problems/*.verifying.md` via glob — per ADR-022). Ranked by release age, oldest first:

| ID | Title | Released | Fix summary |
|----|-------|----------|-------------|
| P<NNN> | <title> | <release marker> | <one-sentence fix summary> |
...

## Parked

| ID | Title | Reason | Parked since |
|----|-------|--------|-------------|
| P<NNN> | <title> | <reason> | <date> |
...
```

Then commit all changed files per ADR-014:
1. `git add` the changed problem files and `docs/problems/README.md`
2. Satisfy the commit gate — two paths are valid (either produces a bypass marker):
   - **Primary**: delegate to the `wr-risk-scorer:pipeline` subagent-type via the Agent tool
   - **Fallback**: if the `wr-risk-scorer:pipeline` subagent-type is not available in the current tool set (e.g., this skill is itself running inside a spawned subagent), invoke the `/wr-risk-scorer:assess-release` skill via the Skill tool. Per ADR-015 it wraps the same pipeline subagent and produces an equivalent bypass marker via the `PostToolUse:Agent` hook. Do not silently skip the gate because the primary path is unavailable — the fallback exists specifically to close this gap (see P035).
3. `git commit -m "docs(problems): review — re-rank priorities"`

If `AskUserQuestion` is unavailable and risk is above appetite, skip the commit and report the uncommitted state (ADR-013 Rule 6 fail-safe). This applies only to the risk-above-appetite branch, not to the delegation-unavailable case above.

### 10. Quality checks

After creating or updating a problem file, verify:

- **ID uniqueness**: No duplicate IDs in `docs/problems/`
- **Naming convention**: File matches `<NNN>-<kebab-case>.<status>.md`
- **Required sections**: Description, Impact Assessment, and Investigation Tasks exist
- **Priority calculation**: Score = Impact × Likelihood, label matches score
- **No orphaned references**: If the problem references other problems by number, verify those files exist
- **Status consistency**: The Status field in the frontmatter matches the filename suffix

**Priority label mapping**: Read the label bands from `RISK-POLICY.md` — do not hardcode them here.

### 11. Report

After any operation, report:
- The file path created/modified
- The problem ID and title
- The current status
- Any quality check warnings

Commit the completed work per ADR-014 (governance skills commit their own work):
1. `git add` all created/modified files for this operation — **including any file renamed via `git mv` that was then modified by the `Edit` tool** (P057 staging trap — `git mv` alone stages only the rename, not the subsequent content edit). `git add -u` is a safe catch-all for tracked modifications. **For any Step 7 status transition** (Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed, or Parked) — including folded-fix commits where the `.verifying.md` transition rides with a `fix(<scope>): ...` commit — the stage list MUST include `docs/problems/README.md` refreshed per Step 7's "README.md refresh on every transition" block (P062). Skipping the refresh leaks staleness to the next session's fast-path. **For any Step 5 new-ticket creation** (single or multi-concern split) and for any Step 6 update that changed Priority / Effort / WSJF, the stage list MUST include `docs/problems/README.md` refreshed per the P094 blocks in those steps. Creation-path and ranking-change-update-path refreshes are treated identically to Step 7 transitions — single-commit transaction, README alongside the ticket.
2. Satisfy the commit gate — two paths are valid (either produces a bypass marker):
   - **Primary**: delegate to the `wr-risk-scorer:pipeline` subagent-type via the Agent tool (subagent_type: `wr-risk-scorer:pipeline`)
   - **Fallback**: if the `wr-risk-scorer:pipeline` subagent-type is not available in the current tool set (e.g., this skill is itself running inside a spawned subagent), invoke the `/wr-risk-scorer:assess-release` skill via the Skill tool. Per ADR-015 it wraps the same pipeline subagent and the `PostToolUse:Agent` hook writes an equivalent bypass marker. Do not silently skip the gate because the primary path is unavailable — the fallback exists specifically to close this gap (see P035).
3. `git commit -m "<message>"` using the convention for the operation type:
   - New problem: `docs(problems): open P<NNN> <title>`
   - Known Error transition: `docs(problems): P<NNN> known error — <root cause summary>`
   - Verification Pending transition: usually folded into the `fix(<scope>): ... (closes P<NNN>)` commit that ships the fix — the `git mv` to `.verifying.md` and the `## Fix Released` section land together. If transitioning without a fix commit, use `docs(problems): P<NNN> verification pending — <release marker>`.
   - Problem closed: `docs(problems): close P<NNN> <title>`
   - Review/re-rank: `docs(problems): review — re-rank priorities`
   - Fix implemented: `fix(<scope>): <description> (closes P<NNN>)` — include problem file changes (rename to `.verifying.md` + `## Fix Released` section) in the same commit per ADR-022
4. If risk is above appetite: use `AskUserQuestion` to ask whether to commit anyway, remediate first, or park the work. If `AskUserQuestion` is unavailable, skip the commit and report the uncommitted state clearly (ADR-013 Rule 6 fail-safe). This applies only to the risk-above-appetite branch, not to the delegation-unavailable case above.

### 12. Auto-release when changesets are queued (ADR-020)

**Skip this step if the skill is running inside an AFK orchestrator** (e.g. `/wr-itil:work-problems`). Orchestrators handle release cadence themselves per ADR-018 (Step 6.5). Detect via the presence of an orchestrator marker in the invoking prompt — look for phrases like "AFK", "work-problems", "batch-work", or the sentinel `ALL_DONE` convention. When in doubt, defer to the orchestrator by skipping this step.

Otherwise, after the commit in step 11 lands, drain the release queue so the fix actually lands on npm without requiring manual user action.

**Mechanism — delegate, do not re-implement scoring (per ADR-015):**

1. Invoke the release scorer. Two paths are valid:
   - **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
   - **Fallback**: if that subagent type is not available, invoke skill `/wr-risk-scorer:assess-release` via the Skill tool. The skill wraps the same pipeline subagent.
2. Read the returned `RISK_SCORES: commit=X push=Y release=Z` line.
3. **Drain condition**: if `push` and `release` are both within appetite (≤ 4/25, "Low" band per `RISK-POLICY.md`), AND `.changeset/` is non-empty, proceed to the drain action. Otherwise, skip the drain and report the unreleased state.

**Drain action (non-interactive, policy-authorised per ADR-013 Rule 6):**

1. Run `npm run push:watch` (push + wait for CI to pass).
2. If `.changeset/` remains non-empty after push (i.e. a release PR is pending), run `npm run release:watch` (merge the release PR + wait for npm publish).
3. Report the release: "Released <package>@<version>. Fix is now live on npm."

**Failure handling**: If `release:watch` fails (CI failure, publish failure), stop and report the failure clearly. Do not retry non-interactively — the user must intervene.

**Above-appetite branch (per ADR-042)**: If push or release risk is above appetite (≥ 5/25), the skill MUST auto-apply scorer remediations incrementally until residual risk converges within appetite, OR halt the skill per ADR-042 Rule 5 if the scorer cannot produce a convergent plan. **The skill MUST NOT release above appetite under any circumstance.** The skill MUST NOT call `AskUserQuestion` as a shortcut out of the auto-apply loop.

**Auto-apply mechanism (ADR-042 Rule 2):**

1. Parse the scorer's `RISK_REMEDIATIONS:` block. Expected shape per ADR-015 / ADR-042 Rule 2a (5 columns):
   ```
   RISK_REMEDIATIONS:
   - R1 | <description> | <effort S/M/L> | <risk_delta -N> | <files affected>
   - R2 | ...
   ```
2. Read the descriptions. Decide what to do. The agent MAY follow a scorer suggestion, adapt it, or do something else entirely. There is no requirement to rank all suggestions upfront or iterate through them in order.
3. **Verification Pending carve-out (ADR-042 Rule 2b)**: skip remediations that target a commit attached to a `.verifying.md` ticket. Do NOT auto-revert VP commits.
4. Apply the chosen action using standard primitives (git, Edit, Bash). Example actions:
   - `move-to-holding`: `git mv .changeset/<name>.md docs/changesets-holding/<name>.md` + append to holding-area README "Currently held" per ADR-042 Rule 6. Since the non-AFK skill has no iteration wrapper to amend into, each auto-apply is its own commit (ADR-042 Rule 3). Each commit goes through the standard ADR-014 commit flow — architect + JTBD + risk-scorer gates.
   - `revert-commit`: `git revert --no-edit <sha>`. The scorer SHOULD supply the target commit SHA in the `description` column. Before executing, verify the SHA is NOT attached to a `.verifying.md` ticket (Rule 2b carve-out). After revert, commit the revert as a standalone auto-apply commit (no amend folding in non-AFK mode). If `git revert` produces merge conflicts, route to Rule 5 halt with the conflict detail.
5. Re-score via the same delegation path as step 1 above.
6. **Loop**: re-score within appetite → drain per the Drain action above. Re-score still above → continue working to reduce risk. The agent reads the new remediations and decides what to do next. Loop. Exhausted or unsupported class → Rule 5 halt.

**Rule 5 halt (non-AFK mode)**: halt the skill. Emit the terminal report naming:
- The final `RISK_SCORES:` line
- An "Auto-apply trail" subsection listing each remediation attempted with outcome
- Any Verification Pending ticket IDs implicated per Rule 2b
- A one-line scorer-gap note (e.g., "scorer produced only `move-to-holding`; residual still ≥ 5/25 after exhaustion — extend scorer vocabulary per P108")

The user resolves interactively — typical resolutions include splitting the commit, feature-flagging the change, or opening a problem ticket documenting the scorer gap.

`push:watch` and `release:watch` are policy-authorised actions when residual risk is within appetite per RISK-POLICY.md, so no `AskUserQuestion` is required for the drain itself (ADR-013 Rule 5). Auto-apply actions under Rules 2–7 are also policy-authorised per ADR-013 Rule 5 — `RISK-POLICY.md` appetite + ADR-042 eligibility constitute the policy.

$ARGUMENTS
