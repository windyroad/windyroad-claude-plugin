---
name: wr-itil:work-problems
description: Batch-work ITIL problem tickets while the user is AFK. Loops through the problem backlog by WSJF priority, delegating each problem to wr-itil:manage-problem, and stops when nothing is left to progress. Use this skill whenever the user says things like "work through my problems", "grind problems", "work the backlog", "work problems while I'm away", "process problems AFK", or any request to autonomously work through multiple problem tickets without interactive input. Also trigger when the user asks to "loop" or "batch" problem work, or says they'll be away and wants problems handled.
allowed-tools: Agent, Skill, Bash, Glob, Grep, Read
---

# Work Problems — AFK Batch Orchestrator

Autonomously loop through ITIL problem tickets by WSJF priority, working each one via `wr-itil:manage-problem`, until nothing actionable remains.

The user is AFK during this process, so every decision point that would normally require interactive input should be resolved automatically using safe defaults. The skill reports progress between iterations so the user can review what happened when they return.

## How It Works

Each iteration is one cycle of: scan backlog, pick highest-WSJF problem, work it, report result. The loop continues until a stop condition is met.

## First-run intake-scaffold pointer (P065 / ADR-036)

This skill is one of the two host skills wired to surface the [`/wr-itil:scaffold-intake`](../scaffold-intake/SKILL.md) skill on first invocation in a project that has not yet adopted the OSS intake surface. The contract is documented in [ADR-036](../../../../docs/decisions/036-scaffold-downstream-oss-intake.proposed.md) (Scaffold downstream OSS intake — skill + layered triggers).

**Preamble check** (run once at session start, before Step 0 of the loop):

1. Look for the four intake paths: `.github/ISSUE_TEMPLATE/config.yml`, `.github/ISSUE_TEMPLATE/problem-report.yml`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`.
2. Look for `.claude/.intake-scaffold-declined` (explicit decline marker — never re-prompt).
3. Look for `.claude/.intake-scaffold-done` (done marker — already scaffolded).

If any intake file is missing AND both markers are absent: this skill is **always invoked from an AFK orchestrator context** (per the skill's allowed-tools and persona). The Rule 6 fail-safe applies unconditionally:

- Do **not** fire `AskUserQuestion`.
- Do **not** auto-scaffold.
- Append a one-line `"pending intake scaffold"` note to the iteration's `ITERATION_SUMMARY` notes field. The note is a per-iteration audit trail signal — accumulating one line per AFK iter is acceptable per ADR-036 § Bad consequences and JTBD-006 "audit trail — every action taken during AFK mode should be traceable".

The user reviews the pending note on their next interactive session and runs `/wr-itil:scaffold-intake` (or `/wr-itil:manage-problem` with the foreground prompt branch) at that point. JTBD-006 forbids the agent from making this judgement call autonomously.

### Step 0: Preflight (per ADR-019)

Before opening the work loop, reconcile local state with origin so the orchestrator does not iterate against a stale backlog or create tickets with IDs that collide with parallel sessions (P040).

**Mechanism:**

1. Run `git fetch origin`.
2. Compare local `HEAD` with `origin/<base>` (default `main`; otherwise the branch the user is on).
3. Branch on the divergence shape:

| Local vs origin | Action |
|---|---|
| HEAD at or ahead of origin/<base> | Proceed to Step 1 |
| origin/<base> ahead, local has no unpushed commits (pure fast-forward) | Run `git pull --ff-only` non-interactively. Log the count of pulled commits in the AFK iteration log. Proceed to Step 1. |
| origin/<base> ahead, local has unpushed commits (non-fast-forward) | STOP the loop. Report the divergence with `git log --oneline HEAD..origin/<base>` and `git log --oneline origin/<base>..HEAD`. Do NOT attempt to rebase or merge non-interactively — that is a judgment call the persona forbids in AFK mode. |

**Network failure**: if `git fetch origin` returns a network error, stop and report. Default behaviour is fail-closed — the user can retry when network is restored.

**Non-interactive authorisation**: per ADR-013 Rule 6, `git fetch origin` and `git pull --ff-only` are policy-authorised actions (no semantic merge, no destructive overwrite). `git pull --rebase`, `git merge`, and any operation that resolves conflicts are NOT policy-authorised — they require user input.

**Cross-cutting**: this rule applies to every AFK orchestrator skill. The next-ID collision guard (ADR-019 confirmation criterion 2) belongs in the ticket-creator skills (`manage-problem` and `wr-architect:create-adr`), not here — see the related problem ticket for that work.

#### Session-continuity detection pass (per P109)

After the fetch/divergence check, Step 0 MUST run a session-continuity detection pass. The divergence check handles "did origin move under us"; this pass handles the distinct failure mode "did the prior session leave partial work that changes what iter 1 should do". A prior AFK subprocess can exit mid-ticket (quota 429, user-cancel, subprocess crash) and leave observable state in the working tree that the orchestrator must classify before opening the work loop.

**Signals to enumerate** (each maps to one `git status --porcelain` / filesystem / `git worktree` probe):

| Signal | Detection |
|---|---|
| Untracked `docs/decisions/*.proposed.md` | `git status --porcelain docs/decisions/` filtered for `??` entries ending `.proposed.md` — drafted but unlanded ADRs from a prior iter. |
| Untracked `docs/problems/*.md` | `git status --porcelain docs/problems/` filtered for `??` entries ending `.md` — drafted but unlanded problem tickets. |
| `.afk-run-state/iter-*.json` error markers | Files under `.afk-run-state/` containing `"is_error": true` OR `"api_error_status" >= 400` — prior iteration hit quota or API error; its work is likely partial. Success files (`"is_error": false`) are ignored. Contract source: ADR-032 subprocess artefact. |
| Stale `.claude/worktrees/*` dirs + matching `claude/*` branches | `git worktree list` filtered on `claude/*` branches adjacent to `.claude/worktrees/*` directories — prior subagent worktrees that were not cleaned up. Detection only — mutation (cleanup) is out of scope and requires a separate ADR. |
| Uncommitted modifications to SKILL.md / source / ADR files | `git status --porcelain` filtered for `M ` / ` M` entries on `packages/*/skills/*/SKILL.md`, `packages/*/hooks/*`, `docs/decisions/*.proposed.md`, or other source paths the prior session was mid-authoring. |

**Classification**: when any signal is present, build a structured Prior-Session State report listing each hit (signal category, path, one-line summary). An empty signal set means clean pass-through to Step 1.

**Routing on interactive-vs-AFK (per ADR-013 Rule 1 / Rule 6):**

- **Interactive** (`AskUserQuestion` is available AND the loop was not started in AFK mode): prompt the user with the Prior-Session State report and four options — **Resume the prior work** (land the drafted files as iter 1), **Discard the draft** and restart from scratch, **Leave-and-lower-priority** (skip the dirty paths and work the next backlog item that doesn't touch them), **Halt the loop** (too much dirty state to proceed non-interactively). Route the chosen branch before opening Step 1.
- **Non-interactive / AFK** (default for this skill per JTBD-006): do NOT call `AskUserQuestion`. Halt the loop with the structured Prior-Session State report in the AFK summary. Per ADR-013 Rule 6 fail-safe: ambiguous session-continuity state requires user input; non-interactive recovery would mask the bug this check is meant to surface. This matches Step 6.75's "dirty for unknown reason → halt" stance at the Step 0 layer — the orchestrator does not silently proceed past partial work.

**Step 2.5b cross-reference (P126)**: before emitting the final AFK summary for a Step 0 session-continuity halt, run Step 2.5b's surfacing routine. The routine is gated on ≥1 accumulated user-answerable skip; at Step 0 no iters have run yet so the gate is normally empty and Step 2.5b returns immediately, but the cross-reference is named here for contract uniformity — every halt path that emits a final summary routes through Step 2.5b regardless of whether the gating clause is empty in the typical case (`halt-paths-must-route-design-questions-through-Step-2.5b`).

**Network failure halt (Step 0 fetch failure)**: if `git fetch origin` returns a network error, the loop halts and reports per the rule above. Before emitting the final AFK summary for a network-failure halt, run Step 2.5b's surfacing routine — same Step 2.5b cross-reference as the session-continuity halt. The gating clause is normally empty at Step 0 (no iters have run), but the cross-reference is named here for contract uniformity (`halt-paths-must-route-design-questions-through-Step-2.5b`).

Step 6.75 treats a Step-0-resolved-with-user-confirmation state as `dirty-for-known-reason`: if the interactive branch's Resume option landed the drafted ADR as iter 1, the iter's commit clears the dirty state and the rest of the loop proceeds normally.

#### README reconciliation preflight (per P118)

After the session-continuity detection pass, Step 0 MUST run the diagnose-only README reconciliation check. The orchestrator reads `docs/problems/README.md`'s WSJF Rankings table to pick the highest-WSJF actionable ticket (Step 3); if that table lies about which tickets are open vs verifying vs closed, the orchestrator burns iterations on no-op tickets — exactly the failure class P118 captures (a prior session committed a ticket transition without staging the README refresh, and no subsequent session systematically reconciled).

```bash
bash packages/itil/scripts/reconcile-readme.sh docs/problems
```

Exit-code routing:
- **Exit 0 (clean)**: continue to Step 1.
- **Exit 1 (drift detected)**: structured diff lines printed to stdout, one per drift entry (≤150 bytes per ADR-038 progressive-disclosure budget). Per ADR-013 Rule 6 (non-interactive AFK fail-safe), invoke `/wr-itil:reconcile-readme` to apply the corrections + commit a `chore(problems): reconcile README ...` commit, then proceed to Step 1. The reconciled README is the orchestrator's source of truth for Step 3 ranking — a stale read at Step 1 would propagate the lie into the iteration's selection.
- **Exit 2 (parse error)**: README missing or malformed. Halt the loop with the parse-error message and the structured Prior-Session State report — this is a deeper repair that needs investigation, not mechanical reconciliation.

This is a robustness layer ON TOP of P094 + P062, not a supersession — both per-operation contracts remain in force inside each iteration's manage-problem / transition-problem invocation.

### Step 1: Scan the backlog

Read `docs/problems/README.md` if it exists and is fresh (check via git history — see manage-problem step 9 for the cache freshness check). If stale or missing, scan all `.open.md` and `.known-error.md` files in `docs/problems/`, extract their WSJF scores, and rank them.

**README row order matches Step 3 tie-break selection (P138)**: as of P138, the README's WSJF Rankings table is rendered with the multi-key sort `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)`. The cache-fresh path can therefore read the rendered table top-to-bottom and the first row is the orchestrator's pick — no in-memory tie-break re-application needed. The slow path scan must apply the same multi-key sort. <!-- TIE-BREAK-LADDER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 -->

Exclude:
- `.closed.md` files (done)
- `.parked.md` files (blocked on upstream)
- `.verifying.md` files (Verification Pending — fix released, awaiting user verification per ADR-022; surfaced in the Verification Queue section, never in dev-work ranking)
- Problems with no WSJF score (need a review first — run `/wr-itil:manage-problem review` as the first iteration if scores are missing)

### Step 2: Check stop conditions

Stop the loop and report a summary if any of these are true:

1. **No actionable problems** — zero open or known-error problems remain
2. **All remaining problems require interactive input** — e.g., they all need user verification (known-errors with `## Fix Released`), or their scope expanded beyond what's safe to auto-resolve
3. **All remaining problems are blocked** — investigation hit a dead end, or the fix requires changes outside the project

**Step 2.5 fires unconditionally at loop end** (P135 Phase 3 / ADR-044) — promoted from "fallback when stop-condition #2" to **default loop-end emit shape**. Anti-BUFD framing per ADR-044: the AFK loop is the empirical-discovery engine; direction-class observations + deviation-candidates accumulate from real friction across iters; loop-end batched presentation is the user-facing deliverable. Per-iter surfacing was the old (now-superseded) pattern; Phase 3 makes batch-at-loop-end the default for ALL stop conditions, not just #2.

For stop-conditions #1 and #3 (no actionable problems / all blocked), Step 2.5 still runs — it reads the accumulated `outstanding_questions` queue from `.afk-run-state/outstanding-questions.jsonl` and presents the batch. Empty queue → no `AskUserQuestion` fires; non-empty queue → batched per ADR-013 Rule 1 cap (≤4 per call, sequential if >4).

### Step 2.5: Surface accumulated outstanding questions at loop end (P135 Phase 3 — default emit shape)

Per ADR-044 framework-resolution boundary: human input is for direction-setting / deviation-approval / one-time-override / silent-framework / taste / authentic-correction (six categories). Across N iters, those observations accumulate at iter level (`ITERATION_SUMMARY.outstanding_questions`) and persist to a session-level queue file. Loop-end Step 2.5 reads, ranks, and presents the batch.

**1. Read the accumulated queue.** Read `.afk-run-state/outstanding-questions.jsonl` — each line is one entry per the ITERATION_SUMMARY `outstanding_questions` schema (see Step 5 Output contract). De-duplicate identical entries (same `category` + same `question` text + same `existing_decision` for deviation-approval).

**2. Rank the entries.** Apply the ranking precedence: deviation-approval (highest) > direction > one-time-override > silent-framework > taste > correction-followup. Within each category, preserve iter-order (oldest first) so the user reads the queue in temporal sequence.

**3. Branch on interactivity.**

- **Default branch — call `AskUserQuestion` when available** (the orchestrator's main turn is interactive by construction; the user is presumed at the keyboard at loop end). Batch the entries into one or more `AskUserQuestion` calls per ADR-013 Rule 1 cap. Header per category: `"Outstanding direction"`, `"Approve deviation from existing decision"`, `"One-time override"`, etc. For deviation-approval entries, options are `Approve + amend ADR` / `Approve + supersede ADR` / `Approve + one-time exception` / `Reject (existing decision stands)` / `Defer (need more evidence)` — the 5-option shape matching the `proposed_shape` field. For other entries, options are extracted from the entry's `question` text or candidate fixes. Write answers back to the corresponding ticket files so the next AFK loop does not re-ask.

- **Fallback branch — emit `### Outstanding Design Questions` table** when `AskUserQuestion` is unavailable (restricted permission mode, hook-disabled tool surface). The table lists each entry with its `category`, `question`, `existing_decision` / `contradicting_evidence` for deviation-approval entries, and `ticket_id`. The user answers on return.

**4. Cleanup.** After all entries are resolved (whether via `AskUserQuestion` or table), truncate `.afk-run-state/outstanding-questions.jsonl` to empty. The next AFK loop starts with a clean queue.

**5. Emit the final summary + `ALL_DONE`.** The summary includes the Outstanding Design Questions table when Step 2.5b's fallback branch fired (see Output Format). When Step 2.5b's default branch fired (`AskUserQuestion` was available), the answers have already been written back; the table is omitted from the summary.

```
ALL_DONE
```

This sentinel line allows external scripts to detect completion.

### Step 2.5b: Surface accumulated user-answerable skips (reusable surfacing routine, P122 + P126)

Step 2.5b is the single source of truth for routing accumulated user-answerable skip-reasons through `AskUserQuestion`-when-available-else-table. It is the sub-step that Step 2.5 (stop-condition #2) AND every halt path that fires after iters have accumulated skipped tickets cross-references — keeping the surfacing logic in one place rather than duplicated across each halt path.

**Gating clause — fire only when at least one accumulated user-answerable skip exists.** Iterate the skip list collected by Step 4's classifier and count entries whose `skip_reason_category == user-answerable`. If the count is zero, return immediately and let the caller emit its summary directly. This guards empty-skip halts (e.g. Step 0 fetch-failure halt before any iters have run) from triggering an unnecessary round-trip.

**1. Extract the question set.** For every skipped ticket whose classifier skip-reason is `user-answerable` (see Step 4's taxonomy), extract its outstanding question(s) from the ticket body — typically from a "Pacing decision", "Naming decision", or outstanding "Investigation Tasks" section. Cap at 4 questions per `AskUserQuestion` call per Anthropic's tool documentation; the same cap applies regardless of whether Step 2.5b was invoked from stop-condition #2 or a halt path.

**2. Branch on interactivity per ADR-013 Rule 1 / Rule 6.**

- **Default branch — call `AskUserQuestion` when available** (the orchestrator's main turn is interactive by construction; the user is presumed at the keyboard). Batch the questions into one `AskUserQuestion` call (or more, if >4 questions, issued sequentially). Header: `"Outstanding design questions"`. For each question, set the prompt from the extracted text and the options from the ticket's candidate fixes or option list. Write each answer back to the corresponding ticket file so the next AFK loop does not re-ask. This is ADR-013 Rule 1 applied to the orchestrator's main-turn surface.
- **Fallback branch — emit `### Outstanding Design Questions` table** when `AskUserQuestion` is unavailable (restricted permission mode, hook-disabled tool surface, or any other context where the structured-question primitive cannot fire). The table lists each question with its Ticket ID, the question text, and one-line context. The user answers on return. This is ADR-013 Rule 6 fail-safe — fall back to a structured summary when the structured-interaction primitive is unavailable.

**Return.** Hand control back to the caller. The caller is responsible for emitting its own final summary (and the `ALL_DONE` sentinel for stop-condition #2; halt paths each have their own outcome label per Step 6 / ADR-042 Rule 5 / Step 6.75 / etc.).

**Cross-skill principle (architect FLAG, P122 + P126)**: orchestrator main turns default to `AskUserQuestion` when available; the AFK persona (JTBD-006) is served by the **subprocess-boundary contract under ADR-032** (iteration subprocess workers are AFK by construction via `claude -p` — they exit at `ITERATION_SUMMARY` and never reach the orchestrator's stop or halt surfaces), NOT by suppressing `AskUserQuestion` at the orchestrator layer. Step 5's iteration-prompt template carries the per-subprocess AFK contract (constraint: "Do not call `AskUserQuestion`"); the orchestrator's stop and halt surfaces fire only in the main turn where the user is presumed present. P122 established this principle at Step 2.5; P126 extends it to every halt path that emits a final AFK summary (the principle: **halt-paths-must-route-design-questions-through-Step-2.5b** — every halt path that fires after iters have accumulated user-answerable skips MUST run Step 2.5b before emitting its summary).

### Step 3: Pick the highest-WSJF problem

Select the problem with the highest WSJF score. If there's a tie, prefer:
1. Known Errors over Open problems (they have a confirmed fix path — less risk of wasted effort)
2. Smaller effort over larger (faster throughput)
3. Older reported date (longer wait = higher urgency)

### Step 4: Classify each problem

Read the problem file and apply these deterministic rules:

| Problem state | Action | Skip-reason category |
|---|---|---|
| `.verifying.md` (Verification Pending, per ADR-022) | **Skip** — fix released, awaiting user verification | user-answerable (verification) |
| Known Error with fix strategy documented | **Work it** — implement the fix (on release, transition to `.verifying.md` per ADR-022) | — |
| Known Error without fix strategy | **Work it** — produce a fix strategy, then implement | — |
| Open problem with preliminary hypothesis or investigation notes | **Work it** — continue the investigation | — |
| Open problem with no leads (empty Root Cause Analysis) | **Work it** — read the relevant code, form a hypothesis, document findings | — |
| Problem previously attempted twice without progress in this session | **Skip** — mark as stuck, needs interactive attention | user-answerable (direction) |
| Open problem with outstanding user-answerable design question (naming, direction, pacing, scope) | **Skip** — surface the question at stop (Step 2.5) | user-answerable (design) |
| Open problem needing architect design judgment (new-ADR-level question) | **Skip** — note the architect-design blocker; Step 2.5 may elevate via a pre-triggered architect call in `--deep-stop` mode | architect-design |
| Open problem blocked on upstream dependency or Claude Code capability gap | **Skip** — but first append the pending-upstream-report marker to the ticket's `## Related` section (see P063 — run the manage-problem SKILL.md external-root-cause detection AFK fallback before skipping). The marker wording is fixed: `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready`. Use the already-noted check to avoid duplicates. | upstream-blocked |

The default is to work the problem. Only skip when the rule explicitly says so. This is an AFK loop — forward progress matters more than avoiding dead ends, because dead ends are cheap (findings are saved) and interactive input is expensive (user is absent).

**Skip-reason taxonomy.** Every skipped ticket is tagged with one of three categories so Step 2.5 can select which ones to surface as questions:

- **user-answerable** — the user can answer directly (verification, naming, direction, pacing, scope). Step 2.5 surfaces these as questions (interactive) or in the Outstanding Design Questions table (non-interactive / AFK).
- **architect-design** — requires architect judgment first; may escalate to a new ADR. Step 2.5 can optionally pre-trigger the architect agent in `--deep-stop` mode to produce a concrete user-answerable question. Otherwise noted as "pending architect review".
- **upstream-blocked** — external dependency, Claude Code capability gap, or waiting on third-party fix. Truly terminal for this loop — no user question would change anything. Report the blocker and move on. **Before skipping, run the manage-problem external-root-cause detection AFK fallback** (per P063): grep the ticket for the stable marker `- **Upstream report pending** —` or `- **Reported Upstream:**` / a `## Reported Upstream` section; if none is present, append `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready` to the ticket's `## Related` section. This preserves the outbound audit trail across AFK iterations so the user can see the deferred action on return.

Record the category alongside the skip reason in the iteration report so Step 2.5 can read the categories deterministically.

**Time-box each problem** to avoid runaway investigation: the delegated `manage-problem` skill's internal logic decides scope. If investigation reveals the scope has grown (e.g., effort was estimated S but turns out to be L or XL), save findings to the problem file, update the WSJF score, and move to the next problem. Never sink unbounded effort into one problem during AFK mode.

If a problem is skipped by this step, add it to a "skipped" list with the reason and loop back to step 3 for the next one.

### Step 5: Work the problem (dispatch via `claude -p` subprocess, per P084)

**Dispatch each iteration to a fresh `claude -p` subprocess via Bash** — do NOT spawn via the Agent tool, do NOT invoke `/wr-itil:manage-problem` inline via the Skill tool.

- **Skill-tool inline invocation** expands manage-problem's SKILL.md (500+ lines) into the main orchestrator's context every iteration, accumulates across the AFK loop, and causes silent early-stop (`ALL_DONE` without a documented stop condition firing). This was the original pre-P077 failure mode.
- **Agent-tool dispatch to a `general-purpose` subagent** (the P077 amendment) works for context isolation but fails at the governance-gate layer: subagents spawned via the Agent tool do NOT have the Agent tool in their own surface (three-source evidence — ToolSearch probe, Claude Code docs at `code.claude.com/docs/en/subagents.md`, empirical runtime error `"No such tool available: Agent. Agent is not available inside subagents."`). Without Agent, the iteration worker cannot set architect + JTBD PreToolUse edit-gate markers (only settable via Agent-tool PostToolUse hook), cannot satisfy the risk-scorer commit gate, and silently halts on every gate-covered iteration. P084 diagnoses and closes this gap.
- **`claude -p` subprocess dispatch** (this step, per P084 / ADR-032 amendment): the subprocess is a full main Claude Code session with Agent available in its own surface. Governance review runs at full depth via the normal `wr-architect:agent` / `wr-jtbd:agent` / `wr-risk-scorer:pipeline` delegation path inside the subprocess; PostToolUse marker hooks fire correctly matching the subprocess's own `$CLAUDE_SESSION_ID`; the commit gate unlocks natively. Context isolation preserved by the process boundary (each subprocess is a distinct process with its own session state; orchestrator's main context only sees the stdout). This is the AFK iteration-isolation wrapper — subprocess-boundary variant under ADR-032.

**Dispatch command shape (Bash, backgrounded with idle-timeout poll loop per P121):**

```bash
ITERATION_PROMPT=$(cat <<'PROMPT_EOF'
<iteration prompt body — see below>
PROMPT_EOF
)

ITER_JSON=$(mktemp)
DISPATCH_START_EPOCH=$(date +%s)
IDLE_TIMEOUT_S="${WORK_PROBLEMS_IDLE_TIMEOUT_S:-3600}"

claude -p \
  --permission-mode bypassPermissions \
  --output-format json \
  "$ITERATION_PROMPT" \
  < /dev/null \
  > "$ITER_JSON" 2>&1 &
ITER_PID=$!

SIGTERM_SENT=0
while kill -0 "$ITER_PID" 2>/dev/null; do
  sleep 60
  NOW=$(date +%s)
  LAST_COMMIT_EPOCH=$(git log -1 --format=%at HEAD 2>/dev/null || echo "$DISPATCH_START_EPOCH")
  # LAST_ACTIVITY_MARK = max(DISPATCH_START_EPOCH, last commit timestamp).
  # The dispatch-start floor handles skip-iterations that produce no commit:
  # they are bounded by IDLE_TIMEOUT_S since dispatch start, not by an
  # arbitrarily-stale repo commit. See trade-off paragraph below.
  if (( LAST_COMMIT_EPOCH > DISPATCH_START_EPOCH )); then
    LAST_ACTIVITY_MARK=$LAST_COMMIT_EPOCH
  else
    LAST_ACTIVITY_MARK=$DISPATCH_START_EPOCH
  fi
  IDLE_SECONDS=$(( NOW - LAST_ACTIVITY_MARK ))
  if (( IDLE_SECONDS > IDLE_TIMEOUT_S )) && (( SIGTERM_SENT == 0 )); then
    kill -TERM "$ITER_PID" 2>/dev/null || true
    SIGTERM_SENT=1
    echo "[work-problems] iter idle ${IDLE_SECONDS}s > ${IDLE_TIMEOUT_S}s threshold — SIGTERM sent to PID $ITER_PID" >&2
  fi
done

wait "$ITER_PID" 2>/dev/null
ITER_EXIT=$?
SUBPROCESS_OUTPUT=$(<"$ITER_JSON")
rm -f "$ITER_JSON"
```

**Flag rationale:**

- `--permission-mode bypassPermissions` — handles non-interactive permission prompts. Without this, Bash/Edit/Write calls inside the subprocess halt on approval prompts (no TTY). Alternative modes (`acceptEdits`, `auto`, `dontAsk`) are acceptable if adopters need narrower permission scopes; `bypassPermissions` is the broadest and the empirically-verified path.
- `--output-format json` — deterministic structured output. The subprocess's final agent message lands in the JSON response's `.result` field; orchestrator extracts `ITERATION_SUMMARY` from that field. Plain-text output would require fragile scraping.
- `< /dev/null` — explicit stdin-closed redirect (P089 Gap 1). Without this, `claude -p` waits up to 3s for stdin data in non-TTY contexts and then prints `Warning: no stdin data received in 3s, proceeding without it. If piping from a slow command, redirect stdin explicitly: < /dev/null to skip, or wait longer.` to stderr. The warning is on stderr — if the caller separates stderr and stdout streams, the warning is harmless. But the orchestrator captures via `2>&1` (required because the CLI emits progress prose on stderr that must not interleave between JSON responses when multiple invocations chain). Under the `2>&1` merge the stderr warning prefixes the stdout JSON and breaks `jq` / `json.load` / `JSON.parse` extraction at "line 1, column 1: Expecting value". The redirect suppresses the warning at source. First observed AFK-iter-7 iter 1 (2026-04-21); workaround is the Anthropic CLI help's own suggestion.

**No per-iteration budget cap.** The dispatch deliberately omits `--max-budget-usd`. Per user direction 2026-04-21: the natural stop condition for an AFK loop is quota exhaustion, not an arbitrary per-iteration dollar cap. A cap would halt iterations before quota is actually exhausted, wasting remaining budget. Runaway-iteration risk is bounded by quota + the orchestrator's Step 6.75 halt on unexpected dirty state + exit-code handling below.

**Idle-timeout SIGTERM (P121).** The poll loop above is the orchestrator-side guard against stuck iteration subprocesses — iters that complete their semantic work (commits land, retro runs, `ITERATION_SUMMARY` is emitted into the agent output stream) but then sit waiting on a hook timeout, a backgrounded subagent that never resolved, or some other CLI-level idle behaviour before exiting. Without the guard the orchestrator polls indefinitely; the JSON file stays 0 bytes (the CLI only flushes on exit) and wall-clock burns for ~$8/hour of subprocess overhead with no API turns. The 2026-04-25 P118 iter 5 evidence: 121 min wall-clock; final commit at ~100 min; manual SIGTERM at 121 min produced a clean 5649-byte JSON response with `is_error: false`, full `## Session Retrospective` section, parseable `ITERATION_SUMMARY` block, and `duration_ms: 2992935` (49.9 min — the real-work portion). SIGTERM is therefore a safe recovery primitive for this stuck-state class — empirically a clean exit-flush, not a destructive interrupt. Behavioural confirmation lives in `test/work-problems-step-5-idle-timeout-sigterm.bats` (P121 ships with this fixture as the second-source the production observation needed). The default `IDLE_TIMEOUT_S=3600` (60 min) leaves headroom for genuinely long architectural iters; the `WORK_PROBLEMS_IDLE_TIMEOUT_S` env-var overrides per-environment for adopters who run very long iters or want a tighter guard. The orchestrator's Step 6 progress line SHOULD annotate `(SIGTERM_SENT)` when the branch fires so the user can distinguish a SIGTERM-recovered iter from a normal completion (per JTBD-006 audit-trail expectation).

**LAST_ACTIVITY_MARK signal trade-off.** The mark is `max(DISPATCH_START_EPOCH, last commit timestamp)`. The dispatch-start floor is intentional: skip-iterations that produce no commit (Step 4 routes a ticket to `action: skipped`) are bounded by `IDLE_TIMEOUT_S` since dispatch start, not by an arbitrarily-stale prior-commit timestamp. This protects against false-positive SIGTERM at iter T=0 when the most recent commit happens to be hours old. The trade-off is the inverse: a skip-iter that runs for `IDLE_TIMEOUT_S` (60 min default) will SIGTERM even though it never had a chance to commit. The 60-min default is well past the typical skip-iter wall-clock (a normal skip completes in seconds), so the trade-off rarely fires in practice; adopters who run unusually long skip-evaluation iters (e.g. deep architect-design probes) should raise `WORK_PROBLEMS_IDLE_TIMEOUT_S` accordingly. Alternative signals considered and rejected: `stat -f%m "$ITER_JSON"` (binary — file mtime only changes on subprocess exit, useless during the idle gap); subprocess RSS-change tracking (noisy; spikes during Agent-tool expansions confound the signal). The git-log signal is the cheapest reliable progress indicator the orchestrator already has.

**Iteration prompt body (self-contained — the subprocess has no prior conversation context):**

1. **Context**: this is one iteration of the AFK work-problems loop. The user is AFK. The orchestrator selected `P<NNN> (<title>)` as the highest-WSJF actionable ticket.
2. **Task**: apply the `/wr-itil:manage-problem` workflow for `work highest WSJF problem that can be progressed non-interactively as the user is AFK`. Follow manage-problem SKILL.md verbatim, including architect / jtbd / style-guide / voice-tone gate reviews and the commit gate (manage-problem Step 11). Because this subprocess has the Agent tool in its own surface, the normal review-via-subagent paths work — no inline-verdict fallback needed.
3. **Constraints**: commit the completed work per ADR-014. Do NOT push, do NOT run `push:watch`, do NOT run `release:watch` — the orchestrator's Step 6.5 owns release cadence. Do NOT invoke `capture-*` background skills (AFK carve-out — ADR-032). Do NOT use `ScheduleWakeup` under any circumstance (P083 — iteration workers must not self-reschedule). **NEVER call `AskUserQuestion` mid-loop in AFK** (P135 / ADR-044): direction / deviation-approval / one-time-override / silent-framework observations queue at `ITERATION_SUMMARY.outstanding_questions` for loop-end batched presentation. Per-iter `AskUserQuestion` calls are sub-contracting framework-resolved decisions back to the user (lazy deferral per Step 2d Ask Hygiene Pass classification). Non-interactive defaults apply per ADR-013 Rule 6 + ADR-044's framework-resolution boundary. **Treat the user as transient** (P130): even when observably present at orchestrator dispatch time, the user may answer one question and disappear for hours; presence is not a reliable signal and is not the goal. The iter's job is to progress the ticket and accumulate questions for batched surfacing — not to ask "is it OK to proceed?" at a mechanical-stage boundary.
4. **Retro-on-exit (P086)**: before emitting `ITERATION_SUMMARY`, invoke `/wr-retrospective:run-retro`. Retro runs INSIDE this subprocess so its Step 2b pipeline-instability scan has access to the iteration's rich tool-call history (hook misbehaviour, repeat-workaround patterns, subagent-delegation friction, release-path instability). Retro may create tickets or update `docs/BRIEFING.md` — run-retro commits its own work per ADR-014; any tickets it creates ride into either the iteration's own commit (if retro runs before the main commit) or a retro-owned follow-up commit, and the orchestrator picks them up on the next Step 1 scan. Proceed to `ITERATION_SUMMARY` emission regardless of retro findings — retro is non-blocking (do not block on retro): if retro fails or surfaces findings, the iteration still returns a summary so the AFK loop does not silently halt on a flaky retro run.
5. **Output**: end the final message with the `ITERATION_SUMMARY` block defined below — this is how the orchestrator consumes the iteration's result.

**Return-summary contract** (unchanged from the P077 amendment — the parse shape is dispatch-mechanism-agnostic). The subprocess's final message MUST end with this structured block, extracted by the orchestrator from the JSON `.result` field:

```
ITERATION_SUMMARY
ticket_id: P<NNN>
ticket_title: <title>
action: worked | skipped
outcome: closed | verifying | known-error | investigated | scope-expanded | partial-progress | skipped
committed: true | false | skipped
commit_sha: <sha>                                  # required when committed=true
reason: <one-line>                                 # required when committed=false or action=skipped
skip_reason_category: user-answerable | architect-design | upstream-blocked  # required when action=skipped
outstanding_questions: [<entry per ADR-044 6-class taxonomy — see schema below>]  # mandatory non-empty when iter touched a direction / deviation-approval / one-time-override / silent-framework decision; otherwise empty array
remaining_backlog_count: <N>
notes: <one-line>
```

**`outstanding_questions` schema (P135 Phase 3 / ADR-044)**: each entry is tagged with its category for loop-end Step 2.5 ranking. Two shapes:

```
# Standard direction / one-time-override / silent-framework / taste / correction-followup entry:
{
  category: "direction" | "one-time-override" | "silent-framework" | "taste" | "correction-followup"
  question: "<one-line — the genuine human-value question this iter surfaced>"
  context: "<one-line — the in-iter situation that surfaced it>"
  ticket_id: "P<NNN>"  # the iter's ticket; loop-end groups by ticket
}

# Deviation-candidate entry (the anti-BUFD-for-framework-evolution shape per ADR-044):
{
  category: "deviation-approval"
  existing_decision: "<ADR-NNN section / SKILL.md path:line / RISK-POLICY clause>"
  contradicting_evidence: "<tool invocation + observable outcome per ADR-026 grounding>"
  proposed_shape: "amend" | "supersede" | "one-time"
  rationale: "<one-line — why current evidence contradicts the existing decision>"
  ticket_id: "P<NNN>"
}
```

When the iter encounters an existing decision (ADR / SKILL contract / WSJF rule / RISK-POLICY entry) that current evidence contradicts, the agent does **NOT auto-deviate**. Instead it queues a `deviation-approval` entry per the schema. Loop-end Step 2.5 presents it as `AskUserQuestion` with options matching the proposed shape: `Approve + amend ADR` / `Approve + supersede ADR` / `Approve + one-time exception` / `Reject (existing decision stands)` / `Defer (need more evidence)`. The agent never auto-deviates; never blindly follows against evidence. **Not-queueing-when-strong-contradicting-evidence-exists is a regression** per the Phase 3 bats coverage (`work-problems-deviation-candidate-shape.bats`).

Architect review (R2) requires the commit state fields (`committed` / `commit_sha` / `reason`) so **Step 6.75's Dirty-for-known-reason branch stays evaluable** from the summary alone. JTBD review requires `ticket_id` / `action` / `skip_reason_category` / `outstanding_questions` so Step 2.5 and the Output Format's Completed / Skipped / Outstanding Design Questions tables can be populated deterministically without the orchestrator having to re-parse ticket files.

**Between-iter aggregation (P135 Phase 3)**: orchestrator's main turn appends each iter's `outstanding_questions` entries to a session-level queue file at `.afk-run-state/outstanding-questions.jsonl` between Step 6 (report) and Step 6.5 (release-cadence check). Each line is one JSON-encoded entry per the schema above. Loop-end emit (Step 2.5) reads the queue file, de-duplicates, ranks (deviation-approval > direction > one-time-override > silent-framework > taste > correction-followup), and presents as batched `AskUserQuestion` per ADR-013 Rule 1 cap (≤4 per call, sequential if >4). Per ADR-032 pending-questions artefact precedent.

**Mid-loop UserPromptSubmit handling (P135 Phase 3 / R4)**: when the orchestrator receives a user message DURING an iter (e.g. the user returns mid-loop and sends a new directive), the orchestrator MUST let the in-flight iter complete naturally to its `ITERATION_SUMMARY` emission BEFORE surfacing the new direction or the accumulated queue. Do NOT abort the iter mid-flight (no SIGTERM to the iter PID; no kill signal). The corrective for the 2026-04-27 iter-9-killed overcorrection: the user's correction was about future iter dispatch shape, not about the in-flight iter; killing wasted ~$5 + 25 min in-flight work. The handler waits for the natural exit, surfaces the queue + the new direction together, then routes per the user's response.

**Per-iteration cost metadata.** Alongside `.result`, the `claude -p --output-format json` response carries cost + usage fields in the same JSON blob. The orchestrator MUST extract these **named fields only** into per-iteration totals and session aggregates — nothing else from the JSON should be surfaced to the user or logged (PII guard: the response also carries `session_id`, `model`, `stop_reason`, and other envelope fields; the extraction is **scoped to the named fields** below so future contributors do not unconsciously broaden it).

Extracted fields (explicit field list):

- `.total_cost_usd` — dollar cost for the iteration.
- `.duration_ms` — wall-clock duration of the iteration subprocess.
- `.usage.input_tokens` — prompt tokens.
- `.usage.output_tokens` — generated tokens.
- `.usage.cache_creation_input_tokens` — tokens written to the prompt cache on this invocation.
- `.usage.cache_read_input_tokens` — tokens read from the prompt cache on this invocation (cache-read is the signal for warm-cache reuse across subsequent subprocess invocations in the same Bash session; high values here indicate the iteration benefited from prior-invocation caching).

Use `jq` (or an equivalent JSON parser) to extract them:

```bash
# $SUBPROCESS_OUTPUT holds the full JSON response body from claude -p.
read -r ITER_COST ITER_DURATION_MS ITER_INPUT ITER_OUTPUT ITER_CACHE_WRITE ITER_CACHE_READ < <(
  jq -r '[.total_cost_usd, .duration_ms, .usage.input_tokens, .usage.output_tokens, .usage.cache_creation_input_tokens, .usage.cache_read_input_tokens] | @tsv' <<<"$SUBPROCESS_OUTPUT"
)
# Accumulate into session totals for the ALL_DONE Session Cost section.
SESSION_COST=$(awk "BEGIN { printf \"%.4f\", ${SESSION_COST:-0} + $ITER_COST }")
SESSION_DURATION_MS=$(( ${SESSION_DURATION_MS:-0} + ITER_DURATION_MS ))
SESSION_INPUT_TOKENS=$(( ${SESSION_INPUT_TOKENS:-0} + ITER_INPUT ))
SESSION_OUTPUT_TOKENS=$(( ${SESSION_OUTPUT_TOKENS:-0} + ITER_OUTPUT ))
SESSION_CACHE_WRITE_TOKENS=$(( ${SESSION_CACHE_WRITE_TOKENS:-0} + ITER_CACHE_WRITE ))
SESSION_CACHE_READ_TOKENS=$(( ${SESSION_CACHE_READ_TOKENS:-0} + ITER_CACHE_READ ))
```

Do NOT extract `session_id`, `model`, `stop_reason`, `permission_denials`, `uuid`, or any other field from the JSON response. Those are subprocess-envelope fields that serve no user-visible purpose and risk leaking subprocess-internal identifiers into orchestrator output.

**Authority hierarchy (P089 Gap 2).** `total_cost_usd` and `usage.*` do NOT have the same reliability envelope — treat them accordingly when aggregating:

- `.total_cost_usd` is **authoritative for dollar cost** — cumulative across the subprocess's entire lifetime by contract. Use it as the sole source of truth for the Session Cost "Total cost (USD)" column and any cost-based stop condition.
- `.usage.*` token fields are **best-effort approximate** — the Anthropic CLI returns the final API response envelope, which is per-turn by construction. When the subprocess exits on a normal final turn the fields accumulate real usage; when the subprocess exits via a background-task completion-notification ack (a closing turn that only acknowledges a backgrounded task finished), the fields reflect ONLY that final ack turn and undercount dramatically. Detectable anomaly shape: the subprocess reports a final-turn-sized usage (handful of input tokens, hundreds of output tokens) alongside a wall-clock duration from the Bash wrapper's own timer that is orders of magnitude larger than the JSON's `duration_ms` field — the cumulative dollar cost still matches real spend, so the mismatch is self-evident on inspection.

Aggregation rule: sum `.total_cost_usd` into the session total and trust it; sum `.usage.*` into the session totals for cache-reuse ratio reasoning but label them best-effort in the Session Cost table. This asymmetry is correct-by-CLI-contract (cost is a session cumulative; usage is a per-response envelope); the orchestrator documents the asymmetry so adopters do not silently under-count tokens. First observed AFK-iter-7 iter 5 (2026-04-21): 1071s wall-clock / 60+ tool-use subprocess returned `duration_ms: 8546, num_turns: 1, usage.* ≈ 137K tokens, total_cost_usd: 6.08` — cost cumulative and correct, tokens reflecting only the final ack turn.

**Exit-code semantics.** `claude -p` exits non-zero when the subprocess fails hard — subprocess crash, auth failure, unresolvable permission denial, API/quota exhaustion. The orchestrator reads the exit code BEFORE parsing `.result`:

- Exit 0 → parse `ITERATION_SUMMARY` from `.result` field; proceed to Step 6.
- Non-zero exit → halt the loop; report the exit code, stderr, and any partial `.result` in the final summary. Do NOT spawn the next iteration. The user returns to a stopped loop with a clear failure reason (e.g. "quota exhausted — resume when quota resets").

**Quota as the natural stop.** The AFK loop runs until quota is exhausted or a stop-condition from Step 2 fires. There is no per-iteration dollar cap; running iterations until quota is actually exhausted maximises backlog progress per quota cycle. Quota-exhaust on a `claude -p` invocation surfaces as a non-zero exit and the orchestrator halts cleanly per the rule above.

**Hook session-id isolation.** Each `claude -p` subprocess has its own `$CLAUDE_SESSION_ID`. Gate markers at `/tmp/architect-reviewed-<ID>`, `/tmp/jtbd-reviewed-<ID>`, `/tmp/risk-scorer-*-<ID>` are scoped to the subprocess's own hook interactions and never shared with the orchestrator's main-turn SESSION_ID. This is the correct behaviour — the orchestrator's main turn runs its own gate flow if it edits gated paths; the subprocess's gate flow is independent. Implementations MUST NOT wire cross-process marker sharing.

**Inter-iteration continuity.** Step 6.5 (release-cadence check) and Step 6.75 (inter-iteration verification) stay in the **main orchestrator's turn**, NOT the iteration subprocess. Rationale: release-cadence and `git status --porcelain` are orchestration-level concerns; `push:watch`/`release:watch` are long-running waits that would waste iteration-subprocess context; the orchestrator needs to see the summary from one iteration before deciding whether to drain before the next. Orchestrator detects subprocess commits by reading the working tree (`git status --porcelain`) and the parsed `ITERATION_SUMMARY.commit_sha` — not session-state continuity with the subprocess.

The manage-problem skill (running inside the iteration subprocess) will:

- Run a review if the cache is stale.
- Select and work the highest-WSJF problem.
- Use its built-in non-interactive fallbacks (auto-split multi-concern problems, auto-commit when risk is within appetite).
- Delegate architect / JTBD / risk-scorer reviews via the Agent tool (available in the subprocess's surface) at the depth defined in each review skill's SKILL.md.
- Commit completed work per ADR-014 (the iteration subprocess's commit inside its own session — the orchestrator does NOT commit from its main turn).

### Step 6: Report progress

After each iteration, report:
- Which problem was worked (ID + title)
- What was done (investigated, transitioned to known-error, fix implemented, etc.)
- The outcome (success, partially progressed, skipped, scope expanded)
- How many problems remain in the backlog
- The iteration's cost metadata — format: `($<cost>, <duration_s>s, <total_tokens_K>K tokens)`. Cost comes from the `.total_cost_usd` field extracted in Step 5; duration from `.duration_ms`; total tokens is the sum of `.usage.input_tokens + .usage.output_tokens + .usage.cache_creation_input_tokens + .usage.cache_read_input_tokens`.

Format as a brief status line, not a wall of text. The user will read these when they return.

**Example:**
```
[Iteration 1] Worked P029 (Edit gate overhead for governance docs) — implemented fix, closed. 8 problems remain. ($0.32, 23s, 171K tokens)
[Iteration 2] Worked P021 (Governance skill structured prompts) — investigated root cause, transitioned to known-error. 7 problems remain. ($0.85, 47s, 432K tokens)
[Iteration 3] Skipped P016 (Multi-concern ticket splitting) — fix released, awaiting user verification. Worked P024 (Risk scorer WIP flag) — implemented fix, closed. 6 problems remain. ($1.12, 62s, 541K tokens)
```

### Step 6.5: Release-cadence check (per ADR-018, above-appetite branch per ADR-042)

After the iteration's commit lands but before starting the next iteration, check whether the unreleased queue would push pipeline risk to or above appetite. This prevents silent accumulation of unreleased changesets across AFK iterations (P041). **The orchestrator MUST NOT release above appetite under any circumstance** — above-appetite states route to the ADR-042 auto-apply loop or halt.

**Mechanism — delegate, do not re-implement scoring:**

1. Invoke the risk scorer to score cumulative pipeline state. Two paths are valid (per ADR-015):
   - **Primary**: delegate to subagent type `wr-risk-scorer:pipeline` via the Agent tool.
   - **Fallback**: if that subagent type is not available, invoke skill `/wr-risk-scorer:assess-release` via the Skill tool. The skill wraps the same pipeline subagent.
2. Read the returned `RISK_SCORES: commit=X push=Y release=Z` line and the `RISK_REMEDIATIONS:` block (if present).
3. **Classify the residual**:
   - **Within appetite (≤ 3/25)** — no drain needed. Proceed to Step 6.75.
   - **At appetite (= 4/25)** — drain the queue per the Drain action below, then proceed to Step 6.75.
   - **Above appetite (≥ 5/25)** — route to the **Above-appetite branch** below. Do NOT drain. Do NOT proceed to Step 6.75 until either (a) the auto-apply loop re-converges within appetite and drain succeeds, or (b) Rule 5 halt fires.

**Drain action (non-interactive, policy-authorised per ADR-013 Rule 6):**

1. Run `npm run push:watch` (push + wait for CI to pass).
2. If `.changeset/` is non-empty after push, run `npm run release:watch` (merge the release PR + wait for npm publish).
3. Resume the loop only after the release lands on npm.

**Failure handling**: If `release:watch` fails (CI failure, publish failure), stop the loop and report the failure in the AFK summary. Do not retry non-interactively — the user must intervene. **Step 2.5b cross-reference (P126)**: before emitting the final AFK summary for a Failure handling / CI failure / release:watch halt, run Step 2.5b's surfacing routine. The routine is gated on ≥1 accumulated user-answerable skip; this halt path empirically frequently has accumulated skips from prior iters (the original P126 surface), so the gate is normally satisfied and Step 2.5b's AskUserQuestion-default branch fires (`halt-paths-must-route-design-questions-through-Step-2.5b`). The CI-failure cause itself remains a halt with bug-signal — Step 2.5b surfaces *prior-iter accumulated user-answerable skips only*; it does NOT ask the user how to remediate the CI failure (that requires the user to inspect the failing CI run on return).

`push:watch` and `release:watch` are policy-authorised actions when residual risk is within appetite per RISK-POLICY.md, so no `AskUserQuestion` is required for the drain itself (ADR-013 Rule 5).

#### Above-appetite branch (per ADR-042)

**Invariant**: the orchestrator MUST NOT release above appetite. There is no code path in Step 6.5 that releases at residual push/release ≥ 5/25. The orchestrator MUST NOT call `AskUserQuestion` as a shortcut out of the auto-apply loop — the scorer is the decision surface, not the user. The branch terminates in either a within-appetite drain or a Rule 5 halt.

**Auto-apply loop (ADR-042 Rule 2):**

1. Parse the scorer's `RISK_REMEDIATIONS:` block. Expected shape per ADR-015 / ADR-042 Rule 2a (5 columns):
   ```
   RISK_REMEDIATIONS:
   - R1 | <description> | <effort S/M/L> | <risk_delta -N> | <files affected>
   - R2 | ...
   ```
2. Read the descriptions. Decide what to do. The agent MAY follow a scorer suggestion, adapt it, or do something else entirely. There is no requirement to rank all suggestions upfront or iterate through them in order.
3. **Verification Pending carve-out (ADR-042 Rule 2b)**: if a remediation targets a commit attached to a `.verifying.md` ticket, do NOT auto-revert it. Skip that suggestion and decide on the next one.
4. Apply the chosen action using standard primitives (git, Edit, Bash). Example actions the agent might take:
   - `move-to-holding`: `git mv .changeset/<name>.md docs/changesets-holding/<name>.md`. Append the entry to `docs/changesets-holding/README.md` under "Currently held" per ADR-042 Rule 6. Amend the iteration's commit to fold the move (per ADR-042 Rule 3 amend-based folding — preserves ADR-032 one-commit-per-iteration invariant).
   - `revert-commit`: `git revert --no-edit <sha>`. The scorer SHOULD supply the target commit SHA in the `description` column (e.g., "Revert commit 9a1f96c that introduced the risky gate"). Before executing, verify the SHA is NOT attached to a `.verifying.md` ticket (Rule 2b carve-out). After revert, amend the iteration's commit to fold the revert. If `git revert` produces merge conflicts, route to Rule 5 halt with the conflict detail — do not attempt non-interactive conflict resolution.
5. Re-invoke the risk scorer (same delegation path as step 1 above — subagent preferred, skill fallback). Read the new `RISK_SCORES:` line.
6. **Loop classification**:
   - **Re-score within appetite (≤ 4/25)** — proceed to Drain action above. Done with the above-appetite branch.
   - **Re-score still above appetite (≥ 5/25)** — continue working to reduce risk. The agent reads the new remediations and decides what to do next. Loop.
   - **No remediations remain** or **the agent has exhausted its own ideas** — Rule 5 halt.

**Governance gates per auto-apply (ADR-042 Rule 3):** each auto-apply that requires a commit (the amend in step 4 above) goes through the standard ADR-014 commit flow — architect review, JTBD review, risk-scorer gate. A gate rejection falls through to Rule 5 halt. The scorer's suggestions do NOT bypass gates.

**Rule 5 halt (exhaustion):** when the auto-apply loop exhausts without convergence, or any gate/operation fails, halt the loop. Do NOT proceed to Step 6.75. Do NOT spawn the next iteration. Emit the iteration summary with:

- `outcome: halted-above-appetite`
- The final `RISK_SCORES:` line
- An "Auto-apply trail" subsection listing each remediation attempted with outcome
- Any Verification Pending ticket IDs implicated per Rule 2b
- A one-line scorer-gap note (e.g., "scorer produced only `move-to-holding` remediations; residual still ≥ 5/25 after exhaustion — extend scorer vocabulary per P108")

**Step 2.5b cross-reference (P126)**: before emitting the Rule 5 halt iteration summary, run Step 2.5b's surfacing routine. The routine is gated on ≥1 accumulated user-answerable skip; Rule 5 halts that fire late in a long AFK loop frequently have accumulated skips from prior iters, so Step 2.5b's AskUserQuestion-default branch typically fires (`halt-paths-must-route-design-questions-through-Step-2.5b`). **Critical guard (architect FLAG)**: Step 2.5b surfaces *prior-iter accumulated user-answerable skips only* — it does NOT ask the user how to remediate the above-appetite state itself; the halt-causing scorer-gap remains a halt-with-bug-signal per ADR-042 Rule 5 invariant ("never release above appetite", scorer is the decision surface, not the user). Surfacing prior-iter skips does not retry the above-appetite remediation, does not bypass the never-release-above-appetite invariant, and does not convert the halt into a non-halt — it just takes the existing prior-iter user-input round-trip with it.

Halt is a **bug signal** — the scorer should always have progressively more aggressive remediations available once P108 lands. Until then, exhaustion is expected when the only path to within-appetite requires a non-`move-to-holding` class.

**Audit trail (ADR-042 Rule 6):** append one line per auto-apply to the iteration summary's Auto-apply trail subsection, including remediation ID, action class, pre/post scores, action taken, and description citation. For `move-to-holding` actions, also append to `docs/changesets-holding/README.md` "Currently held".

### Step 6.75: Inter-iteration verification (P036)

Before spawning the next iteration's subagent, verify the working tree state against the expected outcome of the iteration that just completed. This is defence-in-depth: P035 closed the most-likely commit-gate failure path, but a subagent could still fail to commit for reasons the fallback does not cover (a failure inside `/wr-risk-scorer:assess-release`, a git conflict, a malformed commit message). Without this check, silent failures accumulate across iterations and the final summary reports commits that did not land.

**Mechanism:**

1. Run `git status --porcelain`.
2. Classify the output into one of three cases:

| Status | Expected when | Action |
|---|---|---|
| Clean (empty output) | The subagent committed successfully (the default happy path) | Proceed to Step 7 |
| Dirty for a known reason | A deliberate hand-off to the next iteration (e.g. the subagent chose to skip the commit and report "uncommitted state" because risk was above appetite — per the Non-Interactive Decision Making table above). Reason MUST be stated in the iteration report. | Include the dirty state in the next iteration's subagent context and proceed to Step 7 |
| Dirty for an unknown reason | Neither of the above — the subagent reported success but the tree is not clean, or the tree is dirty without a documented reason in the iteration report | **Halt the loop.** Report the `git status --porcelain` output, the last subagent's reported outcome, and the divergence. Do NOT spawn the next iteration. |

**Rationale**: the orchestrator previously treated the subagent's reported outcome as truth. Any lie, partial write, or silent failure in the subagent propagated into the summary. The `git status --porcelain` check is the cheapest possible independent verification — policy-authorised, no network, no judgement required — and it catches exactly the class of failure the subagent cannot self-report.

**Step 2.5b cross-reference (P126)**: before emitting the final AFK summary for a Step 6.75 dirty-for-unknown-reason halt, run Step 2.5b's surfacing routine. The routine is gated on ≥1 accumulated user-answerable skip; Step 6.75 halts fire between iters and frequently have accumulated skips from prior iters, so Step 2.5b's AskUserQuestion-default branch typically fires (`halt-paths-must-route-design-questions-through-Step-2.5b`). The dirty-for-unknown-reason halt itself remains a halt with bug-signal — Step 2.5b surfaces *prior-iter accumulated user-answerable skips only*; it does NOT ask the user how to recover the dirty state (that remains a Rule 6 user-input requirement on return).

**Out of scope for this step**: attempting recovery from an unknown-reason dirty state. Per ADR-013 Rule 6, conflict resolution and ambiguous state require user input; non-interactive recovery would mask the bug this check is meant to surface.

### Step 7: Loop

Go back to step 1. The backlog may have changed — new problems may have been created during fixes, priorities may have shifted, and the README.md cache will be stale.

## Non-Interactive Decision Making

When `AskUserQuestion` is unavailable or the user is AFK, the skill (and the delegated manage-problem skill) should resolve decisions automatically:

| Decision Point | Non-Interactive Default |
|---|---|
| How each iteration runs (iteration delegation) | Dispatch to a fresh `claude -p --permission-mode bypassPermissions --output-format json` subprocess via Bash per Step 5 — NOT Agent-tool dispatch (the Agent-tool-spawned subagent has no Agent in its own surface, so governance gates cannot be satisfied — P084), and NOT inline Skill-tool invocation (expands manage-problem into the orchestrator's context and burns turns — P077). The subprocess is a full main Claude Code session with Agent available, so architect / JTBD / risk-scorer reviews run at full depth; the orchestrator consumes the `ITERATION_SUMMARY` return-shape from the subprocess's JSON stdout. No per-iteration budget cap — natural stop is quota exhaustion. This is the AFK iteration-isolation wrapper — subprocess-boundary variant under ADR-032. Per P084 + P077 + ADR-032. |
| Retro at iteration end (per-iteration lessons captured) | Iteration subprocess invokes `/wr-retrospective:run-retro` before emitting `ITERATION_SUMMARY` so Step 2b pipeline-instability scan runs inside the subprocess's tool-call history. Retro commits its own work per ADR-014; orchestrator picks up retro-created tickets on next Step 1 scan. Non-blocking: if retro fails or surfaces findings, iteration still emits summary — do not halt the AFK loop on a flaky retro. Per P086 + ADR-032 subprocess-boundary retro-on-exit clause. |
| Which problem to work | Highest WSJF, no prompt needed |
| Multi-concern split | Auto-split (manage-problem step 4b fallback) |
| Scope expansion during work | Update problem file, re-score WSJF, move to next problem instead of continuing |
| Commit when risk within appetite | Auto-commit (manage-problem step 9e fallback) |
| Commit when risk above appetite | Skip commit, report uncommitted state |
| Pipeline risk at appetite (push or release = 4/25) | Drain release queue (`push:watch` then `release:watch`) before next iteration — per ADR-018 (Step 6.5) |
| Pipeline risk above appetite (push or release >= 5/25) | Auto-apply scorer remediations incrementally (ADR-042 Rule 2). The agent reads suggestions and decides what to do. Re-score after each apply; drain when within appetite. **Never release above appetite** (ADR-042 Rule 1) — no AskUserQuestion shortcut. Halt the loop with `outcome: halted-above-appetite` if the loop exhausts without convergence (ADR-042 Rule 5). Verification Pending commits excluded from auto-revert (Rule 2b). Per ADR-042 (Step 6.5 Above-appetite branch). |
| Origin diverged before start | Pull `--ff-only` if trivial; stop with report (`git log HEAD..origin/<base>` and reverse) if non-fast-forward — per ADR-019 (Step 0) |
| Prior-session partial work detected at start (session-continuity dirty: untracked `docs/decisions/*.proposed.md` / `docs/problems/*.md`, `.afk-run-state/iter-*.json` with `is_error: true` or `api_error_status >= 400`, stale `.claude/worktrees/*`, uncommitted SKILL.md/source/ADR edits) | Halt the loop with a structured Prior-Session State report in the AFK summary. Do NOT attempt non-interactive resume. Interactive invocations prompt via `AskUserQuestion` with 4 options (resume / discard / leave-and-lower-priority / halt). Per P109 + ADR-013 Rule 6 (Step 0 session-continuity detection pass). |
| Fix verification needed | Skip problem, add to "needs verification" list |
| Stop-condition #2 with user-answerable skip-reasons | Default: call AskUserQuestion (batched, ≤4 per call, sequential when >4) — the orchestrator's main turn is interactive by construction per ADR-032 subprocess-boundary; user is presumed at the keyboard. Fallback: emit Outstanding Design Questions table when AskUserQuestion is unavailable (Rule 6 fail-safe). Per ADR-013 Rule 1 + P122 (Step 2.5). |
| Halt-path final summary with accumulated user-answerable skips (CI failure / Rule 5 above-appetite / dirty-unknown / session-continuity / fetch failure) | Run Step 2.5b's surfacing routine before emitting the halt path's final AFK summary. Step 2.5b is gated on ≥1 accumulated user-answerable skip — empty-skip halts skip the routine. Step 2.5b surfaces *prior-iter accumulated user-answerable skips only*; it does NOT ask the user how to remediate the halt cause itself (CI failure / above-appetite state / dirty-unknown state remain halt-with-bug-signal). Per ADR-013 Rule 1 + ADR-032 + P126 (`halt-paths-must-route-design-questions-through-Step-2.5b`). |
| Unexpected dirty state between iterations | Halt the loop. Report the `git status --porcelain` output, the last iteration's reported outcome, and the divergence — per P036 (Step 6.75). Run Step 2.5b before emitting the halt summary if ≥1 accumulated user-answerable skip from prior iters (P126). Do NOT attempt non-interactive recovery of the dirty state itself. |
| External root cause detected at Open → Known Error, or at park with `upstream-blocked` reason | Append the stable `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready` marker to the ticket's `## Related` section; do NOT auto-invoke `/wr-itil:report-upstream` (Step 6 security-path branch is interactive — per ADR-024 Consequences). Use the already-noted grep check to avoid duplicate lines. Per P063 + ADR-013 Rule 6. |
| Mid-loop ask between iters in the orchestrator's main turn | Forbidden except at framework-prescribed halt points (Step 0 session-continuity / fetch-failure halt; Step 2.5 / 2.5b loop-end emit; Step 6.5 above-appetite Rule 5 halt; Step 6.5 CI-failure / release:watch halt; Step 6.75 dirty-for-unknown-reason halt). The loop's purpose is **progress + accumulation**; mechanical-stage transitions between iters are framework-resolved and MUST NOT prompt the user. Per ADR-044 framework-resolution boundary + ADR-013 Rule 1 (as amended by ADR-044) + P130. |

### Mid-loop ask discipline (orchestrator main turn) — P130

The orchestrator MUST NOT call `AskUserQuestion` between iterations except at the framework-prescribed user-interaction halt points listed below. The loop's purpose is **progress + accumulation** — progress every ticket the agent can advance autonomously, accumulate user-answerable questions as a side-effect, and surface the accumulated batch only at a halt point. This rule applies whether the user is observably present or not, because **presence-detection is unreliable** and is not the goal — the user may answer one question and disappear for hours; the orchestrator's job is to keep advancing the backlog and stage the user-interaction surface for whenever the user actually returns. Treat the user as transient.

**Framework-prescribed halt points (the only orchestrator-main-turn surfaces where `AskUserQuestion` is permitted):**

- **Step 0 session-continuity halt** — Prior-Session State report; user routes resume / discard / leave-and-lower / halt (interactive branch only; AFK branch halts with the structured report per ADR-013 Rule 6).
- **Step 0 fetch-failure halt** — `git fetch origin` network failure; halt-with-report so the user retries on return.
- **Step 2.5 / Step 2.5b loop-end emit** — accumulated `outstanding_questions` queue presented as batched `AskUserQuestion` (or fallback Outstanding Design Questions table per ADR-013 Rule 6). This is the framework's prescribed user-interaction point; do NOT dilute it by asking earlier.
- **Step 6.5 above-appetite Rule 5 halt** — auto-apply loop exhausted without convergence; halt-with-batched-questions per the Step 2.5b cross-reference (Step 2.5b surfaces *prior-iter accumulated user-answerable skips only* — the halt-causing scorer-gap remains a halt-with-bug-signal per ADR-042 Rule 5).
- **Step 6.5 CI-failure / `release:watch` failure halt** — push:watch or release:watch failed; halt-with-batched-questions per the Step 2.5b cross-reference.
- **Step 6.75 dirty-for-unknown-reason halt** — `git status --porcelain` divergence; halt-with-batched-questions per the Step 2.5b cross-reference.

**No mid-iter ask points.** Every other point in the orchestrator's main turn (between Step 5 dispatch completing and Step 6.5 release-cadence check; between Step 6.75 verification and Step 7 loop-back; between Step 7 and Step 1 next-iteration; between consecutive iters generally) is a mechanical-stage transition that the framework has already resolved. Do NOT introduce ad-hoc `AskUserQuestion` calls at those points to confirm "is it OK to proceed?" or "want me to start the next iter?" — proceeding IS the framework-resolved default. Continue iterating until quota or stop-condition #1/#2/#3 fires.

**Accumulated-question discipline at surface time** (per ADR-044's six-class authority taxonomy — questions that reach the user must be load-bearing):

- **Direction-setting only** — questions that ONLY the user can answer because they reflect goals, intent, or trade-offs the framework has not yet captured. Other accumulated observations (deviation-approval, one-time-override, silent-framework, taste, correction-followup) follow the same shape as the deviation-candidate schema in Step 5's `outstanding_questions` contract.
- **No BUFD** — don't pre-judge architectural decisions before evidence accumulates. Small, actionable questions; not galaxy-brain ones. The deviation-candidate surface (per ADR-044's anti-BUFD-for-framework-evolution clause) is the place where iter-discovered misfits accumulate; the user resolves with full context at loop end.
- **No questions answerable by research / exploration / experimentation** — the agent should prototype, read code, run experiments to answer those itself rather than sub-contracting routine investigative work back to the user. The user is the source for genuine direction-setting decisions, not for "what does this hook do" or "which file holds X" — those are research questions the agent owns.

**Cross-references:**

- **Step 5's iteration-prompt body** carries the per-subprocess "Do not call `AskUserQuestion`" constraint; this subsection carries the orchestrator-main-turn equivalent. Together they enforce the same discipline at both the subprocess layer and the main-turn layer end-to-end.
- **ADR-044** is the parent decision narrowing ADR-013 Rule 1 to framework-unresolved decisions; this subsection is one of its load-bearing implementation surfaces.
- **ADR-013 Rule 1** (as amended by ADR-044) restricts `AskUserQuestion` to framework-unresolved decisions; the framework-prescribed halt enumeration above is the orchestrator-layer interpretation of that narrowing.
- **ADR-013 Rule 6** is the non-interactive fail-safe — when `AskUserQuestion` is unavailable (restricted permission mode, hook-disabled tool surface), the framework-prescribed halts fall back to structured-summary table emission rather than skipping the user-interaction.
- **ADR-032** subprocess-boundary contract is unchanged — this subsection is orchestrator-main-turn discipline; the iteration-subprocess dispatch shape (P084 + P121 + P086 + P089) is untouched.

## Edge Cases

**Review needed first**: If no problems have WSJF scores, run `/wr-itil:manage-problem review` as the first iteration to score everything, then proceed to the work loop.

**Scope creep during investigation**: If investigating an open problem reveals the scope is larger than expected (effort re-sized from S to L, or L to XL), save findings to the problem file, update the WSJF score, and move to the next problem. Don't sink unlimited effort into one problem during AFK mode — the user can decide when they return.

**Circular work**: If the same problem keeps appearing as highest-WSJF across iterations without making progress, skip it after the second attempt and note it as "stuck — needs interactive attention".

**Git conflicts**: If a commit fails due to conflicts, stop the loop and report the conflict. Don't try to resolve conflicts non-interactively.

## Output Format

The skill should produce a final summary when the loop ends:

```
## Work Problems Summary

### Completed
| # | Problem | Action | Result |
|---|---------|--------|--------|
| 1 | P029 (Edit gate overhead) | Implemented fix | Closed |
| 2 | P021 (Structured prompts) | Investigated root cause | Transitioned to Known Error |

### Skipped
| Problem | Skip-reason category | Reason |
|---------|---------------------|--------|
| P016 (Multi-concern splitting) | user-answerable (verification) | Awaiting user verification |

### Outstanding Design Questions

(Emitted only when stop-condition #2 fires AND at least one skipped ticket has a `user-answerable (design/direction/pacing/scope)` skip-reason. Populated by Step 2.5 in non-interactive / AFK mode per ADR-013 Rule 6.)

| Ticket | Question | Context |
|--------|----------|---------|
| P049 (Known Error overloaded) | What should the new status be called, and what file suffix? | Decide so the rename/migration commit can land unambiguously. |
| P051 (run-retro improvement axis) | Ship in this AFK loop or next? | P050 is still fresh; rewriting Step 2/4b/5 twice in one session may churn. |

### Remaining Backlog
| WSJF | Problem | Status |
|------|---------|--------|
| 9.0 | P012 (Skill testing harness) | Open |

### Session Cost

Extracted from each iteration subprocess's `claude -p --output-format json` response (source: measured-actual, not estimated — per ADR-026 grounding). Renders identically in interactive and AFK modes; no decision branch, so output-side only. Cache-read column surfaces the warm-cache-reuse signal observed across subsequent subprocess invocations in the same Bash session.

**Authority note (per P089 Gap 2 — see Step 5 Authority hierarchy):** the "Total cost (USD)" column is authoritative (CLI reports `.total_cost_usd` as a session cumulative). The token columns are **best-effort** — they accumulate each iteration's `.usage.*` response fields, which reflect only the final-turn API envelope and can undercount when a subprocess exits via a background-task completion-notification ack. Cost-based reasoning trusts the cost column; token-based reasoning (cache-reuse ratios, cost-envelope calibration) reads the token columns with that caveat in mind.

| Metric | Value |
|--------|-------|
| Iterations run | 3 |
| Successful (committed) | 2 |
| Skipped | 1 |
| Total cost (USD) | $2.29 |
| Mean cost per iteration | $0.76 |
| Total input tokens | 42 |
| Total output tokens | 1,531 |
| Cache-creation tokens | 78,000 |
| Cache-read tokens (reuse) | 1,064,000 |
| Total duration | 2m 12s |

ALL_DONE
```

When every skipped ticket is in the `upstream-blocked` category (stop-condition #3) or there are no skipped tickets (stop-condition #1), omit the Outstanding Design Questions section entirely rather than rendering an empty heading. The Session Cost section always renders when at least one iteration ran.

## Related

- **P121** (`docs/problems/121-afk-orchestrator-should-sigterm-stuck-subprocesses-after-idle-timeout.verifying.md`) — driver for Step 5's backgrounded-poll-loop dispatch shape (replacing the prior foreground-synchronous form) and the idle-timeout SIGTERM branch. The 2026-04-25 P118 iter 5 evidence: an iteration subprocess sat idle ~70 min after its final commit, then SIGTERM produced a clean JSON exit-flush. Fix: orchestrator backgrounds the subprocess, polls every 60s, computes `LAST_ACTIVITY_MARK = max(DISPATCH_START_EPOCH, git log -1 --format=%at HEAD)`, and sends SIGTERM when `now - LAST_ACTIVITY_MARK > WORK_PROBLEMS_IDLE_TIMEOUT_S` (default 3600s = 60 min). Behavioural second-source: `test/work-problems-step-5-idle-timeout-sigterm.bats` exercises a fake `claude -p` shim that sleeps past the threshold and asserts SIGTERM, JSON exit-flush, env-var override, and within-threshold no-fire. Step 6's per-iter progress line SHOULD annotate `(SIGTERM_SENT)` when the branch fires so users can distinguish recovered iters from natural completions. ADR-032's subprocess-boundary variant amended 2026-04-26 with the backgrounded-poll-loop refinement.
- **P089** (`docs/problems/089-work-problems-step-5-dispatch-robustness-stdin-warning-and-cost-metadata-edge-case.verifying.md`) — driver for Step 5's `< /dev/null` dispatch redirect and the Per-iteration cost metadata "Authority hierarchy" paragraph. Gap 1: stdin warning contaminated stderr-merged JSON captures; closed by adding `< /dev/null` to the canonical dispatch command. Gap 2: `.usage.*` undercounts when subprocess exits via a background-task completion ack while `.total_cost_usd` stays cumulative-authoritative; closed by documenting the authority hierarchy in Step 5 and the Session Cost output section so adopters trust cost and label token totals best-effort.
- **P086** (`docs/problems/086-afk-iteration-subprocess-does-not-run-retro-before-returning.verifying.md`) — driver for Step 5's retro-on-exit clause. Iteration subprocesses exit without running retro, so per-iteration friction (hook misbehaviour, repeat-workaround patterns, pipeline instability) evaporates on exit. Fix: iteration prompt body names `/wr-retrospective:run-retro` as a closing step before `ITERATION_SUMMARY` emission; retro runs inside the subprocess so Step 2b pipeline-instability scan has the full tool-call history; run-retro commits its own work per ADR-014; orchestrator picks up retro-created tickets on the next Step 1 scan.
- **P084** (`docs/problems/084-work-problems-iteration-worker-has-no-agent-tool-so-architect-jtbd-gates-block.open.md`) — driver for Step 5's subprocess-boundary dispatch. Supersedes P077's Agent-tool dispatch on the same Step 5 surface because Agent-tool-spawned subagents cannot themselves invoke Agent (platform restriction), which prevents governance gate markers from being set inside the iteration worker.
- **P077** (`docs/problems/077-work-problems-step-5-does-not-delegate-to-subagent.verifying.md`) — parent amendment. Established the AFK iteration-isolation wrapper sub-pattern and the `ITERATION_SUMMARY` return contract. P084 is the refinement that swaps the spawn mechanism; the isolation intent and return contract are preserved verbatim.
- **P083** (`docs/problems/083-work-problems-iteration-worker-prompt-does-not-forbid-schedulewakeup.open.md`) — iteration prompt body forbids `ScheduleWakeup`. Applies equally to subprocess-dispatched iterations.
- **P036** — inter-iteration verification (Step 6.75); remains in the orchestrator's main turn.
- **P040** — origin-fetch preflight (Step 0); unchanged.
- **P109** — session-continuity detection pass added to Step 0 after the fetch/divergence check. Enumerates five signals (untracked `docs/decisions/*.proposed.md`, untracked `docs/problems/*.md`, `.afk-run-state/iter-*.json` error markers, stale `.claude/worktrees/*` dirs, uncommitted SKILL.md/source/ADR edits). Routes interactive via `AskUserQuestion` with 4 options, AFK via halt-with-report per ADR-013 Rule 6.
- **P041** — release-cadence drain (Step 6.5); remains in the orchestrator's main turn.
- **P053** — Outstanding Design Questions surfacing at stop-condition #2 (Step 2.5); fed by the iteration subagent's `outstanding_questions` field.
- **P122** (`docs/problems/122-work-problems-stop-condition-2-defaults-to-afk-table-instead-of-asking-interactively.verifying.md`) — established the AskUserQuestion-default-when-available routing at Step 2.5. The routing prose (default branch, Rule 6 fallback, cross-skill principle, user-answerable scoping) was originally landed under Step 2.5; P126 moved it into the reusable Step 2.5b sub-step.
- **P126** (`docs/problems/126-work-problems-failure-handling-halt-bypasses-step-2-5-routing.known-error.md`) — extended the principle to every halt path that emits a final AFK summary. Step 2.5b is the single source of truth that Step 2.5, Step 0 (session-continuity + fetch-failure), Step 6.5 (Failure handling + Rule 5 above-appetite), and Step 6.75 (dirty-for-unknown-reason) all cross-reference. The principle: `halt-paths-must-route-design-questions-through-Step-2.5b`. Behavioural second-source: `test/work-problems-step-2-5b-cross-halt-routing.bats`.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 6 non-interactive fail-safe applies to every iteration-subagent decision surface.
- **ADR-014** (`docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`) — preserved under the iteration subagent; the subagent commits its own work.
- **ADR-015** (`docs/decisions/015-on-demand-assessment-skills.proposed.md`) — Agent-tool-vs-Skill-tool delegation precedent (Step 6.5's wording mirror).
- **ADR-018** (`docs/decisions/018-release-cadence.proposed.md`) — release cadence stays in the orchestrator's main turn, not the iteration subagent.
- **ADR-019** (`docs/decisions/019-afk-orchestrator-preflight.proposed.md`) — preflight stays in the orchestrator's main turn.
- **ADR-022** (`docs/decisions/022-problem-verification-pending.proposed.md`) — iteration outcomes map into the return-summary's `outcome` field (`verifying` for a released fix, `known-error` for a root-cause-confirmed ticket awaiting release, etc.).
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — pattern taxonomy parent; Step 5 implements the AFK iteration-isolation wrapper — subprocess-boundary variant per the P084 amendment (2026-04-21), refining the P077 Agent-tool amendment. The P077 amendment remains in the ADR as the historical Agent-tool variant; the subprocess variant is the lead for new adopters.
- **ADR-037** (`docs/decisions/037-skill-testing-strategy.proposed.md`) — doc-lint bats contract-assertion pattern used by `test/work-problems-step-5-delegation.bats`.
- **JTBD-001**, **JTBD-006**, **JTBD-101**, **JTBD-201** — personas whose reliability expectations the iteration-isolation wrapper restores.
