---
name: wr-retrospective:run-retro
description: Run a session retrospective. Updates docs/BRIEFING.md with learnings and creates problem tickets for failures and friction.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill
---

# Session Retrospective

Reflect on the current session, update the project briefing, and create problem tickets for failures and friction.

## When to use

### Supported invocation surfaces

- **Foreground `/wr-retrospective:run-retro`** — the canonical invocation. The user types the slash command in their parent session; the retro runs with full visibility of the session's tool-call history. This is the only invocation surface every other use case falls back to.
- **`claude -p` subprocess invocation** — supported per **P086** (the AFK `/wr-itil:work-problems` iteration subprocess invokes run-retro before emitting `ITERATION_SUMMARY`). The subprocess has the iteration's tool-call history naturally; retro runs with iteration-bounded scope and produces correct findings for that scope. ADR-032 subprocess-boundary variant covers this surface.

### Anti-pattern: Never invoke as a background agent

Do **NOT** invoke run-retro via `Agent(run_in_background: true)` or any background-subagent surface (the deferred ADR-032 `capture-retro` sibling). Background subagents have isolated context at spawn — they cannot see the parent session's tool-call history, which is run-retro's primary input. A background retro would either produce empty findings, require explicit context-marshalling at spawn (the "shenanigans" the user direction rejected), or post-hoc parse session logs (out of scope today).

The `/wr-retrospective:capture-retro` background sibling listed in early ADR-032 drafts is **deferred pending resolution of the context-marshalling problem** (P088, 2026-04-21 user direction: *"run-retro cannot be done as a subagent, because it won't have the context"*). The other ADR-032 background siblings (`capture-problem`, `capture-adr`) are unaffected — their inputs are self-contained aside payloads, not whole-session histories. See **ADR-032** in-scope-list amendment and **P088** ticket for the full settlement.

This anti-pattern clause does NOT forbid retro inside an AFK iteration subprocess (P086) — that surface is the `claude -p` row above, not the background-agent row. Those two surfaces are distinct: `claude -p` is a fresh main Claude Code session that loads its own context naturally; `Agent(run_in_background: true)` is a subagent spawned inside an existing session whose context is isolated from the parent.

## Steps

### 1. Read the current briefing

Read `docs/briefing/README.md` — the per-topic index, Critical Points summary, and per-file hooks. Then read each topic file referenced in the Topic Index (`docs/briefing/<topic>.md`) to understand what previous sessions captured under each heading. During the P100 transition window the legacy single-file `docs/BRIEFING.md` may still exist as a stub pointer; it is read-only until P100 slice 2 retires it.

### 1.5. Briefing signal-vs-noise pass (P105)

After reading the briefing tree, score every entry in `docs/briefing/*.md` to decide whether it was **signal** (useful this session), **noise** (loaded but not useful), or **decay-only** (not in context at all). This pass drives the Critical Points roll-up curation that the SessionStart hook consumes.

**Scoring rules** (applied per entry, per retro cycle):

| Event | Delta | Trigger |
|-------|-------|---------|
| Signal | +2 | Entry was cited, paraphrased, or acted on during this session. |
| Noise | -1 | Entry was loaded into context but not cited or acted on. |
| Decay | -1 | Applied to **all** entries every retro cycle, regardless of signal/noise status. |

**Grounding requirement (ADR-026)**: every classification MUST carry a specific citation — the tool invocation, reasoning paraphrase, or session position that exercised (or failed to exercise) the entry. Bare classifications are forbidden. The citation is recorded in the retro summary (Step 5) so the user can audit the agent's judgment.

**Thresholds and actions**:

| Score range | Action |
|-------------|--------|
| >= +3 | Promote to Critical Points candidate. The agent adds the entry to the Critical Points roll-up in `docs/briefing/README.md` during Step 3. |
| 0 .. +2 | Keep in the topic file. No roll-up change. |
| <= -3 | Route to the **delete queue**. These entries are surfaced for user confirmation in a single batched `AskUserQuestion` at the end of this step. |

**Per-entry persistence format**: each briefing entry carries a trailing HTML comment block:

```markdown
- Entry text body goes here.
  <!-- signal-score: 2 | last-classified: 2026-04-22 | first-written: 2026-04-15 -->
```

The comment block is appended to the list item (or heading) that contains the entry text. `first-written` is set when the entry is created and never changed; `last-classified` and `signal-score` are updated each retro. If an entry lacks a comment block, treat `signal-score` as `0` and set `first-written` to today.

**Classification ownership (policy-authorised per ADR-013 Rule 5)**: the agent owns silent classification. No `AskUserQuestion` is fired for individual entry promotions, demotions, or keep decisions. The agent applies the ADR-026 heuristic directly: entry cited in a tool call (or paraphrased in reasoning) during the session = signal; never loaded or loaded-but-unused = noise; ambiguous cases still classify but with a tentative flag the next retro resolves.

**Delete queue confirmation**: after scoring all entries, if any entries have a score <= -3:

1. Present a single `AskUserQuestion` with `header: "Delete briefing entries?"` and `multiSelect: false`.
2. The question body lists each delete candidate with its score and the ADR-026 citation that led to the noise classification.
3. Options (up to 4 per prompt, sequential if > 4):
   1. `Confirm all deletions` — description: "Remove all listed entries from their topic files."
   2. `Delete selected only` — description: "The agent will present a follow-up with per-entry checkboxes."
   3. `Keep all (defer to next retro)` — description: "Leave entries in place; scores remain unchanged."
   4. `Review individually` — description: "Present each entry one at a time for keep/delete decision."
4. If the queue is empty, skip the prompt entirely.

If the user chooses `Delete selected only` or `Review individually`, present subsequent `AskUserQuestion` calls as needed, respecting the 4-option cap per ADR-013 Rule 1.

**Tier 1 budget guard**: if promoting all score >= +3 entries would breach the 2 KB / ~10-bullet Critical Points budget (ADR-040), promote only the highest-scored entries until the budget is met and surface the remainder as a budget-overflow advisory in the retro summary.

**Non-interactive / AFK fallback (ADR-013 Rule 6)**: when `AskUserQuestion` is unavailable, classify silently and defer the delete queue to the retro summary (Step 5). Do NOT auto-delete entries in AFK mode. The retro summary's "Signal-vs-Noise Pass" section lists each delete candidate with score and citation so the user can review on return. Same trust-boundary shape as Step 2b and Step 4a.

**Anti-pattern: Do NOT skip the signal-vs-noise pass under any of the following rationalisations** (P332 / P148-class, 2026-05-30):

- "The session is long" / "context is at N tokens" / "the user might want to wrap up" / "wrap-mode focused on captures + dispositions" — session length is not a Step 1.5 skip gate. The pass is mandatory; if AFK fallback applies, the delete queue surfaces in Step 5, not in the void.
- "Deferred to next interactive retro" — deferral to a hypothetical future retro is not a valid skip. The next-retro path is implicit at every session boundary; the deferral language is a P148-class rationalisation that lets the load-bearing work silently drop.
- "Weaker evidence so defer to user pick" — the pass IS the evidence-gathering step. Citing "weaker evidence" without running the pass is circular.
- Fabricating "wrap-mode vs mid-session" exemptions that do not exist in this SKILL — Step 1.5 fires uniformly regardless of when run-retro is invoked.

Per ADR-044 framework-resolution boundary: Step 1.5 is mechanical (silent classification + AFK queue surfacing). The pass MUST emit a populated Signal-vs-Noise table in Step 5 (or, in interactive mode, the delete-queue prompt). An empty / "Deferred" emit without scan evidence is a Step 1.5 violation per P332. Same lost-observation hazard P148 captures: the silent skip has zero recovery affordance, while the populated table preserves the agent's judgement on disk for user audit.

**See also**: P148 (Step 4b Stage 1 anti-pattern driver — same class, different step); P332 (run-retro meta-surface recurrence driver).

### 2. Reflect on this session

Consider the work done in this session and identify:

**What you wish you'd been told up front** — things that were non-obvious and caused wasted effort or wrong assumptions. These should be added to BRIEFING.md "What You Need to Know" if they aren't already there.

**What surprised you** — things that contradicted reasonable expectations. These should be added to BRIEFING.md "What Will Surprise You" if they aren't already there.

**What was harder than it should have been** — friction points, tool limitations, process overhead, confusing code. These should become problem tickets via the `/problem` skill.

**What failed** — things that broke, bugs encountered, hooks that errored, tests that failed unexpectedly. These should become problem tickets via the `/problem` skill.

**What should we make easier or automate** — repetitive manual steps, missing tooling, things that could be scripted. These should become problem tickets via the `/problem` skill.

**What recurring pattern did I (or the assistant) observe that would be better codified?** — a pattern that (a) was invoked multiple times in one session or across sessions, (b) has a deterministic action order or a clear invariant, and (c) is reusable beyond one project. These are **codification candidates** and route through Step 4b below. Do not treat them as problem tickets unless the user explicitly picks that routing option.

**What existing skill, agent, hook, ADR, guide, or other codifiable showed a flaw, gap, or friction this session that a targeted edit would fix?** — the **improvement axis** of the codification surface. Criteria: (a) the flaw is reproducible and specific, (b) the fix is a bounded edit to an existing file, (c) no new concept is being invented. Improvement observations flow through the same Step 4b `AskUserQuestion` call as creation candidates, but their options name the improvement shape (e.g. `Skill — improvement stub`, `ADR — supersede or amend`) and the resulting Step 5 row records `Kind: improve` rather than `Kind: create`. An improvement that touches multiple unrelated concerns must be split using the P016 / P017 concern-boundary pattern before routing. If a single output accumulates ≥ 3 improvements in one session, prefer a single coordinating problem ticket over N separate tickets.

For each codification candidate, also identify the **Kind** (`create` for a new output, `improve` for a targeted edit to an existing output) and the **best shape** for the codification. The Windy Road suite supports many shapes — pick the one that fits the pattern, not the one you happened to learn first:

- **Skill** — deterministic multi-step sequence the user invokes by name (e.g. `wr-itil:ship-fix`). Worked example: `fetch origin → check changesets → score risk → commit → push → release → sync manifest → mark Fix Released`.
- **Agent** — bounded investigation or review the main agent should delegate to (e.g. a performance-specialist the architect calls in for runtime-path changes). Place under `packages/<plugin>/agents/`.
- **Hook** — event-driven enforcement or prompt injection (PreToolUse, PostToolUse, UserPromptSubmit). Use when "I keep forgetting to X before Y" — hooks make X unmissable without adding memory load.
- **Settings entry** — `.claude/settings.json` changes: allowlisted commands, env vars, hook wiring. Best fit when a session repeatedly hits permission prompts for the same benign tool.
- **Shell or Node script** — reusable repo-level tooling in `scripts/` (e.g. `sync-install-utils.sh`, `sync-plugin-manifests.mjs`). Best fit for multi-step shell sequences worth scripting.
- **CI step** — `.github/workflows/*.yml` insertion. Best fit for "we'd have caught that earlier with a CI check".
- **ADR** — architectural decision worth recording. Route to `/wr-architect:create-adr`.
- **JTBD** — job-to-be-done record for a persona. Route to `/wr-jtbd:update-guide`.
- **Guide** — voice, style, or risk policy edit. Route to `/wr-voice-tone:update-guide`, `/wr-style-guide:update-guide`, or `/wr-risk-scorer:update-policy`.
- **Test fixture** — regression test for a recurring failure pattern (bats fixture, unit test). Best fit when the observation is "this kept breaking the same way".
- **Memory** — per-user or per-project memory note in `~/.claude/.../memory/`. Best fit for short, user-habit observations that aren't a codifiable sequence (e.g. "I always forget to run `npm run verify` before pushing").

**Note (P075)**: the shape list enumerates **codification outputs** — not ticketing. Every codifiable observation becomes a problem ticket in Step 4b Stage 1 regardless of shape. The shape choice is recorded as the ticket's proposed fix strategy (Stage 2), not as an alternative to ticketing. The legacy `Problem ticket` shape row has been removed; it represented a foregone decision (every observation is ticket-worthy) that is now mechanical in Stage 1.

If no shape fits — the observation is a one-off learning, not a repeating pattern — it belongs in BRIEFING.md (Step 3), not Step 4b.

Counter-examples (what does **not** become a codification candidate):
- "The commit gate rejected my work twice because X was misconfigured" — diagnostic, project-specific. Still flows through Step 4b Stage 1 ticketing; the fix strategy (Stage 2) is captured as free-text under `Other codification shape` (e.g. hook tweak, script adjustment).
- "I always forget to run `npm run verify` before pushing" — short, user-habit rather than codifiable sequence → **memory** shape or **BRIEFING.md** note.

### 2b. Pipeline-instability scan (P074)

Step 2's reflection prompts are framed around the product-code work the session was trying to do. They under-report **pipeline-level instability** — bugs, regressions, or friction in the tools the session itself relied on (hooks, skills, subagent protocols, release scripts, TTL / marker contracts). Agents read the prompts and list "what I was trying to build" instead of "what was in the way of building it". Step 2b is a dedicated evidence-scan step that recovers those observations before Step 4's ticketing flow fires, so pipeline friction reaches the WSJF queue instead of accumulating off-ledger across sessions.

The shape mirrors P068's Step 4a Verification-close housekeeping: glob / evidence-scan / categorise / dedup / prompt. The ownership boundary is the same — run-retro surfaces the detection and delegates ticket creation to `/wr-itil:manage-problem` via the Skill tool; run-retro does not rename, edit, or commit problem-ticket files on its own (per ADR-014).

**Ownership boundary**: run-retro surfaces the detection and its specific citations; `/wr-itil:manage-problem` creates or updates the ticket and commits per ADR-014. run-retro does not write `.open.md` files directly — it delegates through the ticketing skill so the audit trail, WSJF scoring, and concern-boundary analysis all apply consistently. This matches Step 4a's boundary to manage-problem Step 7 and Step 4b Stage 1's boundary to manage-problem creation.

**Signal categories** — each detection is tagged with the primary category. A detection may match multiple categories; pick the one whose fix path is most concrete.

1. **Hook-protocol friction** — gate-marker TTL expiries mid-work (e.g. architect-hook 3600s TTL per ADR-009 expiring while drafting a very long file — was 1800s before P107), marker-vs-file deadlocks (a gate demands PASS before a Write; the agent refuses to PASS on a file that doesn't exist yet), hook-exemption scope gaps, hooks firing on paths they shouldn't, hooks silently skipping paths they should.
2. **Skill-contract violations** — skill steps that collide (e.g. ADR-027 Step 0 colliding with ADR-031 auto-migration Step 0), skills that return empty on paths they should handle (e.g. work-problems false-zero-bail on flat-layout adopter repos), skills whose AskUserQuestion options exceed the 4-option cap (per P061), skills that silently swallow error states the contract says should halt.
3. **Release-path instability** — `push:watch` / `release:watch` misbehaviour (P054, P060 class — reporting success on a stale SHA's workflow run), changeset authoring defects (P073), release-PR body issues, npm publish failing on metadata mismatch.
4. **Subagent-delegation friction** — architect / jtbd / risk-scorer / style-guide / voice-tone agents returning `DEFERRED` or `ISSUES FOUND` that block progress, PASS markers failing to write, agent prompts timing out, agent outputs missing the specific citations ADR-026 requires.
5. **Repeat-work friction** — the same workaround applied ≥ 3 times in one session (each application is signal; the third triggers a ticket candidate). Includes: the same `git add` re-stage after `git mv` (P057), the same marker-refresh pattern after an agent returns DEFERRED, the same hook-bypass incantation.
6. **Session-wrap silent drops** — cases where run-retro itself under-reports (the meta case this step fixes). Detect by comparing the set of `## Fix Released` updates in this session against the set of observations in the retro summary; a `.verifying.md` rename without a matching retro entry is suspect.

**Steps:**

1. **Glob / scan**: walk session history for signal matches from each category above. Candidate patterns to search:
   - Hook TTL expiry → log lines containing `review expired (Ns old, TTL Ms)`, `marker refresh`, `PreToolUse hook blocking error`.
   - Marker-vs-file deadlock → sequences where a Write was blocked, an agent was invoked for the marker, and the agent returned `DEFERRED` or similar non-PASS.
   - `push:watch` / `release:watch` failures → non-zero exits on those scripts, or observable SHA-mismatch in `gh run list` output.
   - Subagent DEFERRED / ISSUES FOUND that blocked progress → agent outputs matching those markers.
   - Repeat workaround → the same `Bash` command pattern appearing ≥ 3 times with the same outcome.

2. **Evidence-scan grounding (ADR-026)**: every detected signal MUST carry specific citations — the tool invocation (command or agent call), a session position marker (turn number, timestamp, or commit SHA), and the observable outcome (exit status, error message, marker content). Bare "pipeline was flaky this session" does not qualify. An example acceptable citation: *"architect hook TTL expired at turn N while drafting `docs/decisions/031-…proposed.md` (log line `review expired (1814s old, TTL 1800s)`), forcing a marker-refresh round-trip"*. If no specific citation can be produced, the detection is NOT logged — false positives are worse than silent drops here because each false positive produces a ticket.

3. **Categorise**: tag each detection with its primary category from the six above.

4. **Dedup against existing tickets**: for each detection, search `docs/problems/*.open.md` and `docs/problems/*.known-error.md` for tickets whose description or symptoms match the detection's category + signal pattern. If a matching ticket exists: route the detection through Step 4 as an **update** (append new evidence to the existing ticket's `## Symptoms` or `## Root Cause Analysis` section via the manage-problem update path). If no match: route as a **new ticket** with the detection's category, citations, and a suggested title. The matching heuristic is category + signal-pattern keyword overlap — LLM-based dup classification (as discussed in P070) is not required here; local-ticket dedup runs against a small enough corpus that keyword overlap on the category + primary signal word is acceptable.

5. **Interactive path (ADR-013 Rule 1)**: for each detection, invoke `AskUserQuestion` with the detection summary + specific citations inline so the user can decide without reading session logs. Options (exactly four, per ADR-013 Rule 1 cap):
   1. `Create new ticket` — description: "Delegate to /wr-itil:manage-problem to create a problem ticket with the detection's category, citations, and suggested title."
   2. `Append to P<NNN>` — description: "An existing ticket covers this signal; delegate to /wr-itil:manage-problem to append new evidence to its Root Cause Analysis section."
   3. `Record in retro report only (not ticket-worthy)` — description: "The detection is session-local friction that does not warrant a persistent ticket; record it in the Pipeline Instability section of the retro summary only."
   4. `Skip — false positive` — description: "The evidence-scan matched on a false positive; the observed behaviour was correct. Do not record."

6. **Non-interactive / AFK fallback (ADR-013 Rule 6)**: when `AskUserQuestion` is unavailable (autonomous retro, batch session-wrap), do NOT auto-create tickets — record each detection in the retro summary's new **Pipeline Instability** section with its category, citations, and dedup status (`new` or `matches P<NNN>`). The user reviews on return and runs `/wr-itil:manage-problem` per accepted detection. Same trust-boundary shape as Step 4a's AFK deferral: surface the evidence, defer the decision. This matches the user's documented preference (feedback_verify_from_own_observation.md memory): surface observations from the agent's own in-session activity, but ticket-creation decisions remain user-confirmed.

**README inventory currency advisory (ADR-069, P294).** Beyond the categorical pipeline-instability detection above, Step 2b also runs the README inventory-currency detector on every retro to surface drift between each plugin's shipped skills and the skills its README names. (Under superseded ADR-051 this detector also flagged JTBD-ID-citation drift; ADR-069 superseded that — READMEs market the persona's problem derived FROM the JTBD but MUST NOT cite IDs — so the detector is now skill-inventory-only.) The surfacing channel is the retro summary's Pipeline Instability section.

**Mechanism**: invoke `wr-retrospective-check-readme-jtbd-currency` (resolves on `$PATH` to `packages/retrospective/scripts/check-readme-jtbd-currency.sh` per ADR-049 naming grammar; filename retained per ADR-069). The script walks `packages/*/README.md` and, for each, checks that every directory under `packages/<plugin>/skills/` is named in the README, emitting:

- Per-package: `README package=<name> skills=<N> in_readme=<M> drift_hints=<csv>`
- Trailing summary: `TOTAL packages=<N> drift_instances=<K>`

Drift-hint vocabulary: `skill-inventory-drift` (inventory-only per ADR-069). Always exits 0 — the script is advisory per ADR-013 Rule 6 / ADR-040 declarative-first; the commit-hook `retrospective-readme-jtbd-currency.sh` is the load-bearing surface.

**Interpretation**:

1. **`drift_instances == 0`** — emit a one-line `README inventory currency: clean (<N> packages)` to the retro summary's Pipeline Instability section.
2. **`drift_instances ≥ 1`** — emit the detector's full per-package output as a fenced code block in the Pipeline Instability section. Each affected package's `drift_hints` enumerate the specific findings. Per ADR-013 Rule 6, the user reviews on return and tickets via `/wr-itil:manage-problem` per accepted finding (same trust-boundary shape as the categorical detection above — surface the evidence; defer the ticket-creation decision).
3. **Detector failure** — if the detector exits non-zero (parse error, missing `packages/` or `docs/jtbd/` directories, runtime exception), log the failure inline as `JTBD currency advisory failed: <stderr>` but do NOT halt the retro. Same fail-open contract as Step 3's `check-briefing-budgets.sh` defensive trip — the cheap layer trips silently and degrades to a one-line pointer rather than blocking the retro.

**Already load-bearing (ADR-069)**: the commit-hook `retrospective-readme-jtbd-currency.sh` denies `git commit` when `drift_instances ≥ 1` (skill-inventory-drift), per the carried-forward load-bearing-from-the-start-for-drift-class driver. This Step 2b advisory is the backup / cross-cutting surface — it catches drift in sessions that bypass the commit-hook (`BYPASS_JTBD_CURRENCY=1`) and summarises across packages; it is not the gate.

**Interaction with other surfaces:**

- **Step 4a (Verification-close housekeeping, P068)** — same evidence-scan shape applied to a different surface. Both share the glob / scan / categorise / specific-citation / interactive-or-AFK pattern. Step 4a scans for successful exercise of `.verifying.md` fixes; Step 2b scans for tool-level friction. They fire independently and produce independent retro-summary sections.
- **Step 4 (problem-ticket creation)** — Step 2b feeds Step 4. A detection surfaced in Step 2b that the user accepts becomes a Step 4 creation or update via the manage-problem delegation. Step 4b's Stage 1 two-stage codification flow (P075) applies to pipeline-instability tickets the same way it applies to Step 2 reflection tickets — the detection IS the codify-worthy observation.
- **ADR-032 supersession note** (was: ADR-027 compatibility note): ADR-027's Step-0 subagent auto-delegation has been superseded by **ADR-032** (Governance skill invocation patterns). No Step-0 subagent migration applies to run-retro under ADR-032's foreground-synchronous pattern — Step 2b's evidence scan executes directly in main-agent context, where the session's tool-call history is natively visible. The hypothetical session-activity-summary marshalling this note previously discussed is obviated by the supersession; preserved here as audit-trail continuity for prior cross-references.

### 2c. Context-usage measurement (cheap layer, P101)

Per **ADR-043** (Progressive context-usage measurement and reporting for retrospective sessions), every retro emits a per-source-bucket context-usage summary so bloat is detected at session-time rather than after the user notices. The cheap layer runs unconditionally in every retro (interactive and AFK) at a static-budget-bounded ~2.5 KB output ceiling — well under the 5% / 200K cheap-layer envelope. Anything richer (per-turn attribution, per-plugin decomposition, suggestion generation) is the deep layer's responsibility, invoked by explicit user direction via `/wr-retrospective:analyze-context`.

**Ownership boundary**: this step measures and surfaces; it does NOT trim, edit, or refactor any source surface. Trim decisions stay with the user (or a follow-up problem ticket via Step 4 / Step 4b). The cheap layer is a read-only observability surface, not an enforcement gate.

**Steps:**

1. **Invoke the diagnostic script**:

   ```bash
   wr-retrospective-measure-context-budget "${CLAUDE_PROJECT_DIR:-.}"
   ```

   The `wr-retrospective-measure-context-budget` command is a `$PATH`-resolved shim shipped in `packages/retrospective/bin/` that dispatches the canonical `packages/retrospective/scripts/measure-context-budget.sh` body. ADR-049 — never invoke the canonical script via repo-relative path; the path does not resolve in adopter trees.

   The script is read-only, exits 0 on advisory output and 2 on parse error (project root missing). It emits one row per bucket: `BUCKET <name> bytes=<N>` for measured surfaces, `BUCKET <name> not-measured reason=<reason>` for absent or framework-injected surfaces, plus a trailing `THRESHOLD bytes=<N>` row for the configurable ceiling. See `packages/retrospective/scripts/test/measure-context-budget.bats` for the exact contract.

2. **Read the prior snapshot** (when present):

   ```bash
   prior_report=$(ls -1r docs/retros/*-context-analysis.md 2>/dev/null | head -1)
   ```

   If `$prior_report` is non-empty and the file contains a `<!-- context-snapshot:` HTML-comment trailer (per ADR-043's snapshot-persistence shape), parse the trailer fields for the prior bucket totals. **First-retro / no-prior path**: emit the bucket table without a delta column and label it `no prior snapshot — first measurement this project` per ADR-026's `not estimated — no prior data` sentinel. Do NOT silently omit the column — the absence is itself signal.

3. **Render the cheap-layer report** as a `## Context Usage (Cheap Layer)` section in the retro summary (see Step 5). The section MUST contain:
   - A per-bucket table (one row per script-emitted bucket, sorted by bytes descending). Columns: `Bucket | Bytes | % of total | Δ vs prior`.
   - A top-5 offenders block when ≥ 5 buckets carry non-zero byte counts. Top-5 cites the bucket name + byte count + measurement-method (per ADR-026).
   - A one-line affordance: `Per-plugin breakdown available in /wr-retrospective:analyze-context (deep layer).`
   - When the deep layer's last run is older than 14 days OR a bucket's delta exceeds +20% since prior snapshot, append the one-line note: `Deep analysis recommended — invoke /wr-retrospective:analyze-context.` This is a non-blocking advisory, never a prompt.

4. **Forbidden phrases (ADR-026)**: the cheap-layer report MUST NOT contain qualitative-only phrases. Banned: `load is negligible`, `microseconds only`, `minimal`, `small change`, `trim X to reduce bloat` (without comparable prior). Concrete byte counts + measurement-method citations are mandatory; ungrounded fields use the explicit `not measured — <reason>` sentinel.

5. **Defensive trip (fail-open)**: if the script exits non-zero or the rendered report exceeds the `THRESHOLD bytes=<N>` ceiling at runtime, skip the bucket table and emit the one-line pointer `cheap layer disabled — invoke /wr-retrospective:analyze-context for context measurement`. Log the trip in Step 2b's Pipeline Instability section so the regression is captured as a ticket candidate per the existing flow.

6. **AFK behaviour (ADR-013 Rule 6)**: identical to interactive mode. The cheap layer is silent (no `AskUserQuestion`); the bucket table + advisory line ride the retro summary. AFK orchestrators read the summary on iteration close.

**Interaction with other surfaces:**

- **`P099` Tier 3 advisory** (`check-briefing-budgets.sh`) — measures **per-topic-file** budget on `docs/briefing/<topic>.md`. The cheap layer aggregates this into a single `briefing` bucket row; the per-file detail is drillable via P099's existing surface. No double-counting.
- **`P105` signal-vs-noise pass** (Step 1.5 of this skill) — measures **per-entry** signal scores on briefing entries. The cheap layer's `briefing` bucket is upstream of the per-entry signal scores; deep layer cites both as evidence sources.
- **Step 4 / 4b — codification flow**: when the cheap layer surfaces a delta-from-prior anomaly that the user wants to investigate, the deep layer (`/wr-retrospective:analyze-context`) is the correct routing target — it produces a `docs/retros/<date>-context-analysis.md` report with per-turn attribution and suggestion generation. The cheap layer never auto-routes.
- **`/wr-retrospective:analyze-context` (deep layer)** — invoked only by explicit user direction. Never auto-fires from this step. Deep-layer report writes the HTML-comment-trailer snapshot that subsequent runs of this step read.
- **ADR-032 supersession note** (was: ADR-027 compatibility note): no Step-0 subagent migration applies — under ADR-032's foreground-synchronous pattern the script invocation runs in main-agent context as written. The migration shape this note previously discussed is obviated by the supersession.

### 2d. Ask Hygiene Pass (P135 Phase 5 / ADR-044)

Per **ADR-044** (Decision-Delegation Contract — framework-resolution boundary), every retro emits a per-session classification of the agent's `AskUserQuestion` calls so the **lazy-AskUserQuestion-count** regression metric is visible at session-time rather than after the user notices the friction. The pass runs unconditionally in every retro (interactive and AFK). Output is a structured table in the Step 5 retro summary; persistence is a one-shot trail file consumed by `packages/retrospective/scripts/check-ask-hygiene.sh` for cross-session trend analysis.

**Ownership boundary**: this step measures and surfaces; it does NOT block, gate, or auto-correct any AskUserQuestion call. The lazy-count metric is the regression signal; correction is the user's call (via direction-setting / deviation-approval / authentic-correction per ADR-044 categories).

**Steps:**

1. **Enumerate AskUserQuestion calls** in the session's tool-use history. For each call, capture: the `header` field, the `question` text, the call ordinal (1..N), and the session-position marker (turn / commit / artefact reference per ADR-026 grounding).

2. **Classify each call** per ADR-044's 6-class authority taxonomy:

   | Classification | Definition | Lazy? |
   |---|---|---|
   | **direction** | New tickets / new ADRs / new SKILLs / additions to suite that were not derivable from existing framework — **including confirming the SUBSTANCE of a genuine ≥2-option decision before dependent work is built on it (ADR-074 (Confirm a decision's substance before building dependent work))** | NO |
   | **deviation-approval** | Existing decision found wrong under current evidence; user approves amend / supersede | NO |
   | **override** | One-time exception to a still-valid rule (not a rule-change) | NO |
   | **silent-framework** | No ADR / JTBD / policy / WSJF / risk-score / SKILL applies; genuine new territory | NO |
   | **taste** | Authentic preference on novel artefact where no guide settles | NO |
   | **correction-followup** | Clarifying a user-issued correction (P078 surface) | NO |
   | **lazy** | Framework resolves the decision; ask is sub-contracting agent work back to user | **YES (regression metric)** |

   Classification ownership is silent agent judgement (per ADR-044 mechanical-stage discipline — no AskUserQuestion-about-AskUserQuestion meta-loop). The agent applies the framework-resolution heuristic: for each call, can the framework (ADR / JTBD / policy / WSJF / SKILL contract) resolve the decision? If yes → lazy. If no AND the call falls into one of the 5 non-lazy categories → that category. Borderline cases default to lazy (conservative — prefer false-positive lazy classification over silently underreporting friction).

   **ADR-074 exclusion (substance-confirm-before-build).** A `substance-confirm-before-build` ask — surfacing the SUBSTANTIVE chosen option of a genuine ≥2-option decision the framework cannot resolve, before any dependent work is built on it — classifies as **direction** (cat-1), NOT lazy. The framework deliberately does NOT resolve such a decision (it is the user's to own); the ask is the correct behaviour ADR-074 mandates, not sub-contracting. Grounding: `Gap: genuine ≥2-option decision, framework cannot resolve, about to be built on (ADR-074)`. Do not let the conservative "borderline → lazy" default mis-score it — the trigger is narrow (a decision about to be BUILT ON), so it is unambiguously direction, never lazy. Counting it as lazy would pressure the agent back toward the P315 under-ask failure.

3. **Per-call grounding (ADR-026)**: each classification MUST cite the framework artefact that resolves the decision (for lazy) OR the framework gap (for non-lazy). Bare classifications are forbidden. Citation format: `Framework: <ADR / SKILL.md path / policy reference>` for lazy; `Gap: <one-line rationale>` for non-lazy.

4. **Emit the in-session table** as a `## Ask Hygiene` section in the Step 5 retro summary (see Step 5 template). Columns: `Call # | Header | Classification | Citation`. Plus a `**Lazy count: <N>**` line for cheap-script parsing, plus per-category count lines (`**Direction count: <N>**`, etc.).

5. **Persist trail entry** at `docs/retros/<YYYY-MM-DD>-ask-hygiene.md` (one file per retro; date in filename for natural sort-by-date). Same structured shape as the Step 5 emit. The advisory script `packages/retrospective/scripts/check-ask-hygiene.sh` consumes these files for cross-session trend.

6. **Defensive trip (fail-open)**: if classification produces ambiguous results OR the trail file write fails, skip the persistence step but ALWAYS emit the in-session table (even if classifications are flagged as `unclear`). Better to surface partial data than no data.

7. **AFK behaviour (ADR-013 Rule 6 / ADR-044)**: identical to interactive mode. The pass is silent (no AskUserQuestion-about-the-classifications); the table + trail entry ride the retro summary; AFK orchestrators read the summary on iteration close.

8. **R6 numeric gate auto-flag** (P135 / ADR-044 Reassessment Trigger): after computing this retro's lazy count, invoke `packages/retrospective/scripts/check-ask-hygiene.sh` to read the cross-session trail and detect the R6 condition (lazy count remains **≥2 across 3 consecutive retros** including this one). When the gate fires, **auto-queue a deviation-candidate** in the orchestrator's `outstanding_questions` queue (per the AFK loop's Phase 3 schema in `packages/itil/skills/work-problems/SKILL.md` ITERATION_SUMMARY contract):
   ```
   {
     category: "deviation-approval"
     existing_decision: "ADR-044 Reassessment / declarative-first; P135 Phase 4 gated on R6"
     contradicting_evidence: "<3 consecutive retros' lazy counts: e.g. 3, 2, 4 — citations to docs/retros/<date>-ask-hygiene.md per retro>"
     proposed_shape: "amend"
     rationale: "R6 numeric gate fired (lazy count ≥2 across 3 consecutive retros after Phase 2/3 land); declarative-first declared insufficient; Phase 4 enforcement hook now warranted per P135 plan."
     ticket_id: "P135"
   }
   ```
   The deviation-candidate surfaces at loop end (Step 2.5) with the standard 5-option `AskUserQuestion` (Approve+amend / Approve+supersede / Approve+one-time / Reject / Defer). The framework reminds itself; no manual remembering required. When this retro is invoked outside an AFK loop (interactive `/wr-retrospective:run-retro`), the same auto-queue logic surfaces the candidate via the orchestrator's main turn AskUserQuestion at retro end — same shape.

**Forbidden phrases (anti-friction)**: the in-session table MUST NOT include qualitative-only phrases on the lazy count. Banned: `lazy count is acceptable`, `within tolerance`, `improving`, `regression contained`. Concrete numbers + the trend script's TREND line are the truth surface.

**Interaction with other surfaces:**

- **`P099` Tier 3 advisory** (`check-briefing-budgets.sh`) and **`P101` cheap-layer measurement** (`check-context-budget.sh`) follow the same advisory-script pattern that `check-ask-hygiene.sh` adopts. Reusable triplet (script + bats + ADR-tier-policy precedent).
- **`P132` enforcement hook** (Phase 4 of the P135 plan, gated on Phase 1-3 declarative being insufficient — R6 numeric gate: lazy count ≥2 across 3 consecutive retros after Phase 2/3 land) consumes the same lazy-count trail to decide whether to fire.
- **`P078` capture-on-correction** is the inverse pattern; ADR-044 category 6 (`correction-followup`) is the surface where P078 catches operate. Bounded — should be rare.
- **`/wr-retrospective:analyze-context` deep layer** — separate measurement surface (context bytes, not AskUserQuestion calls). Both share the `docs/retros/` trail directory; no double-counting because file naming differs (`<date>-ask-hygiene.md` vs `<date>-context-analysis.md`).

### 3. Update the briefing tree

Edit `docs/briefing/<topic>.md` files — each topic file is per-subject (`hooks-and-gates.md`, `releases-and-ci.md`, `governance-workflow.md`, `afk-subprocess.md`, `plugin-distribution.md`, `agent-interaction-patterns.md`). Select the topic file whose scope matches the learning; if no file fits, add a new topic file under `docs/briefing/` and update `docs/briefing/README.md`'s Topic Index accordingly.

For each accepted learning:

- **Add** new entries to the matching topic file under the right section ("What You Need to Know" or "What Will Surprise You"). If the learning spans topics, pick the file whose fix-path is most concrete and cross-reference from the other topic file.
- **Remove** stale items that are no longer true. A learning is stale when:
  - The issue has been fixed (e.g., "CI doesn't test v2" after v2 tests are added)
  - It's now documented elsewhere (e.g., in an ADR, CLAUDE.md, or README)
  - The codebase has changed enough that it's no longer relevant
- **Update** items where the details have changed.
- Keep each topic file naturally bounded — per-topic files replace the legacy under-2000-token budget on a single file. If a topic file grows past ~20 entries, consider splitting further.

After editing topic files, update `docs/briefing/README.md`:

- Refresh per-file summaries in the Topic Index if the topic file's character changed.
- Promote an entry into the Critical Points section when its signal-score is >= +3 (agent-driven per Step 1.5). The session-start surface is small and curated; the agent promotes the highest-scored entries first, respecting the Tier 1 budget guard. Demotion from Critical Points happens automatically when an entry's score drops below +3 after decay. The remaining user-interactive boundary is the delete queue (score <= -3), which is resolved per Step 1.5's silent-classification model — the agent applies the signal-vs-noise heuristic and removes / trims / compresses without asking, surfacing the chosen actions in the Step 5 retro summary so the user can correct via the P078 capture-on-correction surface if a removal was wrong.

**Removals are silent (P135 / ADR-044)**: per the ADR-044 framework-resolution boundary, removals follow Step 1.5's silent-classification model — agent owns the remove / trim / compress decision; user reads the Step 5 summary and corrects via authentic-correction (ADR-044 category 6) if an entry was removed in error. Per-removal `AskUserQuestion` is sub-contracting framework-resolved decisions back to the user (lazy deferral per Step 2d Ask Hygiene Pass classification).

**Anti-pattern: Do NOT emit "Added: none / Removed: none / Updated: none" without actually scanning the session for briefing-worthy observations** (P332 / P148-class, 2026-05-30):

- "Wrap-mode focused on captures + dispositions" / "session was about other work" — wrap framing is not a skip gate. Step 3 fires regardless of session focus; the briefing tree is the durable cross-session continuity surface, and a session that touched the codebase by definition produced observations worth screening against "What You Need to Know" / "What Will Surprise You".
- "No surprises this session" without per-section scan evidence — bare "none" rows MUST cite the scan that produced them. If no scan ran, the row is a P148-class silent skip.
- "Context is at N tokens" / "the user might want to wrap up" — same session-length rationalisation P148 closes at Step 4b. Step 3 carries the same class: prose-only mandate without explicit anti-pattern enumeration trains agents to skip the unguarded step.
- "Deferred to next interactive retro" — same P148-class fictional-defer the Step 1.5 anti-pattern block above captures. The next-retro path is implicit at every session boundary; deferring scan work to it lets the observation silently drop.

Per ADR-044 framework-resolution boundary: Step 3 is silent agent action (per the "Removals are silent" clause above + ADR-040 + ADR-013 Rule 5). The scan IS the framework-mediated action; declaring "Added / Removed / Updated: none" without scan evidence is sub-contracting framework-resolved work back to the user via the retro summary — the exact lost-observation hazard P148 closes. A bare "none" row is acceptable ONLY when the per-section scan ran and produced zero accepted candidates; the Step 5 summary's Briefing Changes section MUST encode that scan evidence (e.g. "scanned N candidate observations, 0 accepted") to distinguish a scanned-empty result from a silent skip.

**See also**: P148 (Step 4b Stage 1 anti-pattern driver — same class, different step); P332 (run-retro meta-surface recurrence driver).

#### Tier 3 budget rotation pass (P099)

After all topic-file edits, Step 1.5 delete-queue persistence, and the README refresh have completed, run the per-topic-file budget pass. ADR-040 Tier 3 names a 2-5 KB / topic envelope; this pass promotes that budget from informational to advisory enforcement.

**Mechanism**: invoke `packages/retrospective/scripts/check-briefing-budgets.sh` (read-only diagnostic) against `docs/briefing/`. Output has two line shapes:

```
OVER <basename> bytes=<N> threshold=<N>
MUST_SPLIT <basename> reason=ratio-exceeds-2x
```

`OVER` lines fire for every file at or above the configured threshold. `MUST_SPLIT` lines fire (in addition to `OVER`) for files at or above 2× the threshold — promoting ADR-040's reassessment trigger ("≥ 3 topic files exceed 2× the configured ceiling for ≥ 2 consecutive retro cycles") from policy-revisit-time to per-cycle enforcement (P145).

The script's threshold defaults to `5120` bytes (the upper bound of ADR-040's Tier 3 envelope) and is overridable via `BRIEFING_TIER3_MAX_BYTES`. Empty stdout means no files are over budget — skip the rest of this pass.

**Ordering**: this pass runs as the FINAL action of Step 3, after edits + Step 1.5 delete-queue persistence + README refresh. It must observe post-edit byte counts so the deletes the user confirmed in Step 1.5 are reflected in the measurement.

**Silent agent-picked rotation (P135 / ADR-044)** — per the ADR-044 framework-resolution boundary, rotation is silent agent judgement applied to each `OVER` line. The agent has all the inputs needed: file mtimes (split-by-date), Step 1.5 signal scores per entry (trim-noise), header structure within the file (split-by-subtopic). No `AskUserQuestion` per file; surfacing 4 options × 6 over-budget files trains the user to pick "defer" 6 times to escape the cascade — worse than no rotation.

**Two heuristic branches** depending on whether the file's `OVER` line is accompanied by a `MUST_SPLIT` line:

**Branch A — file has MUST_SPLIT line (ratio ≥ 2.0× ceiling, P145)**: the do-nothing options are not eligible. The accumulated ratio is concrete evidence that prior retros' defers have failed to converge — picking `trim-noise` or `leave-as-is` again is the recurring-defer anti-pattern P145 closes. Pick from this narrowed set:

- If a coherent sub-topic boundary exists (a sub-section that's grown big enough to stand alone, ≥1 KB; e.g. a worked example in a topic that's grown to its own sub-section): **split-by-subtopic** — extract to `docs/briefing/<sub-topic>.md`, update README Topic Index.
- Else: **split-by-date** — this is the **safe default** when no sub-topic boundary is obvious. Older entries archive cleanly without semantic judgement (mtime-sort + median-age threshold), so the action is mechanical and AFK-safe. Archive oldest entries to `docs/briefing/<topic>-archive.md`. Do NOT pick split-by-subtopic with a weak boundary just because it appears first in the heuristic — split-by-date is preferred when the boundary is unclear because it has zero false-split risk.

**Branch B — file has only OVER line (ratio between 1.0× and 2.0× ceiling)**: rotation is required. Being OVER threshold IS the evidence; "wait for more signal to accumulate" is the fictional-defer anti-pattern P247 closes (sibling-class to P246's calendar-trigger anti-pattern at the cohort-graduation surface). Per the P246 principle (evidence-based, not time-based — user direction verbatim 2026-05-17: *"The 14 files are over the limit, but you are deferring splitting them. Why? When are you hoping they will get dealt with?"*), the agent picks the best-fit rotation shape from the three concrete options below; fall-through is **split-by-date** as the safe default (zero false-split risk per Branch A precedent), NOT "leave-as-is".

- If a coherent sub-topic boundary exists (≥1 KB sub-section): **split-by-subtopic** — extract to `docs/briefing/<sub-topic>.md`, update README Topic Index.
- Else if the file has clear date-stratified entries (HTML-comment `first-written` fields per Step 1.5) AND ≥30% of bytes are entries older than the median age: **split-by-date** — archive oldest entries to `docs/briefing/<topic>-archive.md`.
- Else if Step 1.5 surfaced ≥3 noise-classified entries in this file this retro: **trim-noise** — apply the Step 1.5 noise-trim decisions inline; if the trim alone brings the file below threshold, record `trim-noise` as the rotation action with the per-entry deltas in the Step 5 summary. If the file is still OVER after trim, fall through to split-by-date in the same retro turn — do NOT defer.
- Else (no subtopic boundary AND no date stratification AND no ≥3 noise entries): **split-by-date (safe default)** — mtime-sort entries, archive the oldest half to `docs/briefing/<topic>-archive.md`. This is the same safe-default Branch A uses when its boundary is unclear; the fall-through here aligns Branch B with Branch A's evidence-based rotation discipline. Per ADR-013 Rule 5 (policy-authorised silent proceed) + ADR-044 framework-mediated surface ("Briefing add / remove / rotate" line 77), the rotation is silent agent judgement — no per-file `AskUserQuestion`.

Apply the chosen rotation; record the choice + rationale + per-file delta (`bytes before` → `bytes after`) in the Step 5 summary `Topic File Rotation` section. User reads the summary and corrects via authentic-correction (ADR-044 category 6) if the rotation was wrong (rotations are reversible — `git mv` the archive sibling back; restore deletions from git).

This is the same silent-classification model as Step 1.5 delete-queue removals (P135 lesson: removals + rotations both follow Step 1.5 ownership; per-file `AskUserQuestion` is sub-contracting framework-resolved decisions back to the user — lazy deferral per Step 2d Ask Hygiene Pass classification). AFK and interactive modes use identical behaviour — no `AskUserQuestion` differentiation needed.

**Why advisory, not fail-closed**: the rotation is a judgment call (which sub-topic to extract, which archive shape to use). A CI-fail-on-overflow would block routine retros mid-session, directly violating JTBD-001 ("enforce governance without slowing down"). The advisory shape mirrors ADR-038's chosen response to the analogous honour-system byte-budget problem: bats catch script-contract drift; the script itself surfaces signal at runtime without halting.

**Reusable pattern note** (JTBD-101): this triplet — read-only advisory script + behavioural bats fixture + ADR-tier-budget amendment — is the documented shape for any accumulator-doc surface that needs progressive-disclosure enforcement. Future surfaces (risk register per P102, ADR index, problems index) can mirror it without re-deriving.

### 4. Create or update problem tickets

For each item identified in "What was harder than it should have been", "What failed", and "What should we make easier or automate", use the `/problem` skill to:

- Check if a problem ticket already exists in `docs/problems/`
- If yes: update it with new evidence from this session
- If no: create a new problem ticket

### 4a. Verification-close housekeeping (P068)

Problems whose fix shipped but whose closure is still pending (`docs/problems/*.verifying.md` per ADR-022) accumulate across sessions. When this session's activity exercised a pending fix successfully, run-retro surfaces the evidence so the user can close on observed fact rather than by calendar age (P048's `Likely verified` heuristic) or deferred user review (manage-problem Step 9d's baseline user-initiated path). This step extends those paths with **session-context evidence**; the close decision remains the user's.

**Ownership boundary**: run-retro surfaces evidence and asks; `/wr-itil:manage-problem` Step 7 Verification Pending → Closed transition (rename + Status edit + P057 re-stage + ADR-014 commit per ADR-022) is invoked via the Skill tool to perform the actual file rename and commit. run-retro does **not** rename, edit the Status field, or commit — those remain `manage-problem`'s responsibility. ADR-014 lists run-retro as out of scope for its own commits; the delegated manage-problem call commits per ADR-014 + ADR-022 and that boundary is preserved.

**Steps:**

1. **Glob**: enumerate `docs/problems/*.verifying.md docs/problems/verifying/*.md` (dual-tolerant — RFC-002 migration window covers BOTH the flat `docs/problems/<NNN>-<title>.verifying.md` filename-suffix surface per ADR-022 AND the per-state subdir `docs/problems/verifying/<NNN>-<title>.md` surface per ADR-031).

2. **Read the `## Fix Released` section** of each file and extract the fix-summary keyword set: release marker (version, commit SHA, or date), affected source path(s), new test file path(s), and any named skill / hook / gate the fix exercises.

3. **Evidence scan** against the session's in-context activity. For each ticket, collect specific citations (tool invocation, timestamp or position in the session, and the observable outcome). Accepted evidence classes:
   - **Test invocations** that ran the fix's test file or a superset and returned zero (e.g. `npx bats packages/itil/skills/manage-problem/test/manage-problem-external-root-cause-detection.bats` — 14/14 passed at session position N).
   - **Commits** whose diff covered the fix's source path (cite the commit SHA and path).
   - **Skill invocations** that rely on the fix (e.g. `manage-problem` using P056's corrected next-ID lookup; cite the invocation and the observable that the fix contract held — "ID 072 computed without origin_max blob-SHA false-match").
   - **Hook firings** on gate paths the fix established (cite the tool call that triggered the hook and the hook's observed behaviour).
   - **Release cycles** (`push:watch` / `release:watch`) that shipped a commit dependent on the fix (cite the workflow run ID and exit status).

4. **Categorise** each `.verifying.md` ticket into one of three buckets:
   - **Exercised successfully in-session** — at least one citation from step 3. Record the ticket as a close-candidate. Citations MUST be specific (tool invocation + observable outcome), not bare counts — per ADR-026 grounding. If no specific citation can be produced, the ticket does NOT go in this bucket regardless of how often the fix's area was touched.
   - **Not exercised in-session** — no citation collected. Leave as Verification Pending; nothing surfaces for this ticket.
   - **Exercised with regression** — the fix's contract observably failed (test red, hook misfired, skill produced incorrect output). This is a distinct problem, not a closure candidate. Flag it in the retro report as a new problem ticket (route via Step 4) with the regression evidence, and leave the `.verifying.md` file alone.

5. **Close-on-evidence (silent agent action per P135 / ADR-044)** — for each close-candidate in the "Exercised successfully in-session" bucket, the agent delegates to `/wr-itil:transition-problem <NNN> close` (per ADR-014 commit grain) WITHOUT firing `AskUserQuestion`. The framework has resolved this decision: `.verifying.md` files with specific in-session evidence (test invocation + observable outcome per ADR-026 grounding) ARE verified per ADR-022's evidence semantics. Per-candidate `AskUserQuestion` is sub-contracting the framework-resolved decision back to the user (lazy deferral per Step 2d Ask Hygiene Pass classification).

   The Step 5 retro summary's `## Verification Candidates` table records each close action with the citation that triggered it AND a documented recovery path (per the cross-plugin dispatch + recovery-path bats coverage in P135 Phase 2 — `run-retro-step-4a-cross-plugin-dispatch.bats` + `run-retro-step-4a-recovery-path.bats`). User reads the summary; if a close was wrong, user invokes the recovery path: `/wr-itil:transition-problem <NNN> known-error` (or equivalent) — closes are reversible. User disagreement surfaces via authentic-correction (ADR-044 category 6 / P078 capture-on-correction surface) — the agent does not need permission per-close because the recovery path is cheap and reversible.

6. **Recovery path (P135 R5)**: if the user disagrees with a close-on-evidence action surfaced in the Step 5 summary, the recovery path is documented inline in the summary alongside each close: `Recovery: rerun /wr-itil:transition-problem <NNN> known-error to reopen` (or the verifying-flip-back path used in the 2026-04-27 P124 regression flip-back). Recovery is a single-skill invocation; the close is fully reversible.

7. **Cross-plugin dispatch contract (P135 R3)**: when delegating to `/wr-itil:transition-problem`, surface the result in the Step 5 summary:
   - On dispatch success (transition-problem returned 0, ticket renamed + Status updated): record `closed via transition-problem` in the Decision column.
   - On dispatch failure (transition-problem returned non-zero, ticket NOT renamed): record `dispatch-failed: <one-line>` in the Decision column. Do NOT mark closed in the summary table. Surface the failure for user attention; recovery path is "user investigates the dispatch error".
   - On dispatch unavailable (transition-problem skill not on the plugin set in this project): record `dispatch-unavailable: ticket left as Verification Pending` in the Decision column. Graceful fallback — do not silently swallow the close-candidate.

8. **Same-session verifyings excluded** (unchanged from P068 design): `.verifying.md` tickets for fixes that ship in the currently-running session (e.g. P127, P065, P126, P101 just transitioned this session) are NOT close-candidates — a session cannot verify its own fix beyond "bats passed at commit time"; subsequent-session exercise is the meaningful signal. Same-session verifyings are skipped in step 4 categorisation.

9. **Prior-session evidence drain (P282)** — surfaces tickets whose `## Fix Released` section was written in a prior session AND whose `docs/problems/README.md` Verification Queue `Likely verified?` cell already records `yes — observed: <citations>` from that prior session. Sub-steps 1-8 above scan the CURRENT session's tool-call activity for evidence; this sub-step consumes durable on-disk evidence that was structurally invisible to those scans — the evidence is not in any later session's tool-call context, so without this drain a prior-session-verified ticket stays in `verifying` forever.

   **Why a separate stage**: the same-session exclusion in sub-step 8 correctly prevents a session from verifying its own fix. Without this stage, a ticket whose evidence landed in a prior session has no surface that ever re-considers it — closure depends on a user manually prompting. 2026-05-26 evidence in this repo (P282 Related section): 8/91 `verifying/` rows carried `yes — observed: …` from prior sessions; none auto-closed; the README Verification Queue grew to 134 KB exceeding the Read-tool 25K-token whole-file cap, forcing persisted-output + paged reads.

   **Sub-steps:**

   a. **Read `docs/problems/README.md`** Verification Queue table (the section starts at the `## Verification Queue` heading and ends at the next `## ` heading). Parse each row's `Likely verified?` cell — the last `|`-delimited column.

   b. **Filter to evidence-bearing rows**: cell value begins with `yes — observed:` — the canonical P186 evidence-first cell shape (`yes — observed: <citations>` / `no — not observed` / `no — observed regression`). The `no — *` rows are skipped (no durable evidence yet); the `yes — observed:` rows are the close-candidates.

   c. **Same-session exclusion (inherited from sub-step 8)**: skip rows whose `.verifying.md` rename was committed in the current session. Detect via `git log --since=<session-start> --diff-filter=R --name-status` filtered to renames into `docs/problems/verifying/`. A ticket whose `yes — observed:` cell was written in the current session has its rename in the current session's git log and is excluded from the drain — sub-steps 5-7 already handled it via the in-session evidence flow.

   d. **Dispatch close** per the same cross-plugin contract as sub-step 5: invoke `/wr-itil:transition-problem <NNN> close` via the Skill tool. The dispatch success / failure / unavailable outcomes are recorded in the Step 5 Verification Candidates table per sub-step 7's contract — uniform treatment regardless of evidence source.

   e. **Record source distinction** in the Decision column: append `(prior-session README cell)` to the Decision text. The Citations column carries the README cell's `yes — observed: <citations>` text verbatim so the user can audit the evidence that drove the close.

   **Composition**: this sub-step fires AFTER sub-steps 5-7 dispatched any current-session evidence. Each transition-problem dispatch refreshes the README per P062, so by the time sub-step 9 reads the README the rows handled by sub-steps 5-7 are already gone — the remaining `yes — observed:` rows are exactly the prior-session set.

   **Recovery path (inherited from sub-step 6)**: a wrong close is reversible via `/wr-itil:transition-problem <NNN> known-error` (or the `.verifying.md` flip-back path used in the 2026-04-27 P124 regression). Recovery is a single-skill invocation.

   **Closes P282** (V→Closed transition skipped when validation lands inline) — the README `Likely verified?` cell is the durable encoding of prior-session validation evidence; consuming it pairs the lifecycle transition with the evidence already on disk. The body-content-scan trigger surfaces (option (a) `/wr-itil:transition-problem` Step 4 pre-flight; option (b) PostToolUse hook on `.verifying.md` Edit) named in P282's Investigation Tasks are within thin-extension territory but deferred per the architect+JTBD verdicts ranking (c) highest persona-service — if the prior-session drain proves insufficient on next-session evidence, capture a sibling ticket for the body-content scan surface.

**ADR-032 supersession note** (was: ADR-027 compatibility note): ADR-027's Step-0 subagent auto-delegation was superseded by **ADR-032** (Governance skill invocation patterns). No Step-0 subagent migration applies to run-retro — Step 4a's evidence scan runs directly in main-agent context, where session-activity citations are natively grounded per ADR-026. The hypothetical session-activity-summary marshalling this note previously discussed is obviated by the supersession; preserved here as audit-trail continuity for prior cross-references.

**Interaction with other surfaces**:
- **manage-problem Step 9d** (baseline user-initiated verification review per P048) still fires on `/wr-itil:manage-problem review` — it is the age-based heuristic path. Step 4a here is the evidence-based session-wrap path. The two compose: a ticket that is both "≥ 14 days old" (Step 9d highlight) AND "exercised successfully this session" (Step 4a candidate) should be surfaced in both paths independently; closing via either path moves the ticket to `.closed.md` and de-lists it from both queues.
- **Skipped in this step**: `.verifying.md` tickets for fixes that ship in the currently-running session (e.g. P066, P063 just transitioned to `.verifying.md` this session) — a session cannot verify its own fix beyond "bats passed at commit time"; subsequent-session exercise is the meaningful signal. Treat same-session verifyings as "not exercised in-session" for closure purposes unless a later-session exercise path is in the citation list.

### 4b. Two-stage codification — ticket first, fix strategy second (P075)

Every codification candidate identified in Step 2 flows through a **two-stage flow**. Stage 1 is mechanical — every candidate becomes a problem ticket; ticketing is not a user decision. Stage 2 is a per-ticket `AskUserQuestion` recording the **proposed fix strategy** as the codification shape.

**User rationale (P075)**: the legacy 19-option flat list presented a ticket-this-or-pick-another-shape choice as one option among many, but in practice the ticketing axis has a foregone answer — every codify-worthy observation is also problem-worthy. Re-asking the ticketing question is redundant. Flipping the flow collapses the redundant decision: ticket first (mechanical), fix strategy second (user-interactive).

**Skill candidate / Codification candidate backward compatibility**: the legacy `Skill candidate` and `Codification candidate` AskUserQuestion headers are superseded by Stage 2's `Proposed fix` header. The P044 / P050 / P051 enforcement intents are preserved — they now ride in Stage 2 Options 1–3 on a per-ticket basis rather than as one option among many for a single batch prompt.

#### Stage 1: Ticket every codify-worthy observation (mechanical — no user decision)

For every codifiable observation identified in Step 2:

1. **Apply P016 concern-boundary analysis**: if the observation covers multiple independent concerns, split into N observations before ticketing. One ticket per concern.
2. **Classify the observation per the P342 trust-boundary taxonomy** (mirror of `/wr-itil:work-problems` Step 5 iter-prompt body's classification — same trust-boundary fires whether retro runs in iter context OR standalone in main turn):
   - **Recurring class-of-behaviour observation** (sibling iters / sessions hit same pattern; SKILL-contract drift; hook misbehaviour; framework-gap; pipeline instability with concrete fix path): **mechanical-auto-ticket** via `/wr-itil:capture-problem` (or `/wr-itil:manage-problem` if capture sibling not yet available). This is the mechanical-stage carve-out per **Step 4a precedent** (verification close-on-evidence — same trust-boundary). Per ADR-013 Rule 5 (policy-authorised silent proceed) + ADR-044 framework-resolution boundary: the retro IS the system designed to mechanically observe recurring patterns; ticketing them is mechanical, not user-decision.
   - **Direction-setting observation** (genuine user-judgment-bound question — design choice, deviation-approval, framework boundary): route to `outstanding_questions` queue when retro runs inside an AFK iter (via the `ITERATION_SUMMARY.outstanding_questions` schema documented in `packages/itil/skills/work-problems/SKILL.md` Step 5); surface at retro-end interactively when retro runs standalone in main turn. These observations preserve the user's authority surface and MUST NOT auto-ticket.
   - **Ambiguous** (retro cannot cleanly distinguish recurring-class from direction-setting): **default to mechanical-auto-ticket** per the P342 trust-boundary asymmetry. The ticket lifecycle (`/wr-itil:manage-problem` Step 9d / `/wr-itil:review-problems` Step 4) will surface any embedded direction-setting question through the standard problem-review flow. Defaulting to queue would re-introduce the silent-queue-accumulation hazard P342 closes; defaulting to ticket has zero observation-drop risk.

   This is silent agent judgement — no `AskUserQuestion` per observation. The classification taxonomy is framework-resolved per ADR-044; per-observation `AskUserQuestion` would re-route mechanical decisions back to the user (lazy-deferral surface per Step 2d Ask Hygiene Pass). The work-problems Step 5 iter-prompt body carries the symmetric mirror — both surfaces use the same taxonomy.
3. **Invoke `/wr-itil:manage-problem`** via the Skill tool to create a problem ticket. The observation text becomes the ticket Description; the retro narrative populates the Root Cause Analysis; the `## Related` section cites this retro run. (Once the ADR-032 `capture-*` background sibling ships for manage-problem, Stage 1 can delegate to `/wr-itil:capture-problem` instead so ticketing runs out of the foreground turn; same contract, different invocation mode.)

**ADR-032 note**: Stage 1 is a legitimate **foreground-spawns-N-background fanout** pattern — run-retro's foreground context spawns one background capture invocation per observation (when the background sibling exists). ADR-032's Confirmation section must carry this case; cite `ADR-032` (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) explicitly when the background path lands.

**Ownership boundary** (same as Step 4a): run-retro surfaces the observation and delegates ticket creation to `/wr-itil:manage-problem`. The delegated skill renames, edits, and commits per ADR-014. run-retro does not commit its own work.

**Non-interactive / AFK branch**: Stage 1 fires regardless — ticketing is mechanical and does not require user input (per ADR-044 framework-resolution boundary; Stage 1 is in the framework-mediated zone — the agent reads the framework, ticket-creates per observation, and reports).

**Valid fallback gates** — the ONLY conditions under which an observation may be recorded in the retro summary's "Tickets Deferred" section instead of ticketed via `/wr-itil:manage-problem`:

- `cause: skill_unavailable` — the Skill tool is gated out of the current tool surface, OR `/wr-itil:manage-problem` is not registered in this project's plugin set, OR a structural prerequisite (git access, `docs/problems/` directory) is unreachable. The fallback is a graceful-degradation branch when the mechanical action is physically impossible.

Every "Tickets Deferred" entry MUST carry an explicit `cause:` field naming one of the valid gates. Entries without `cause:`, or with a cause not in the allowlist, are Step 4b Stage 1 violations and are surfaced by `packages/retrospective/scripts/check-tickets-deferred-cause.sh` (advisory; advisory-only initial mode per ADR-040 declarative-first). If the script reports violations, the retro summary renders them under a labelled `Step 4b Stage 1 violations — observations dropped without skill-unavailability cause` subsection.

**Anti-pattern: Do NOT skip Stage 1 ticketing under any of the following rationalisations** (P148, 2026-04-29):

- "The session is long" / "context is at N tokens" / "the user might want to wrap up" — session length is not a Stage 1 fallback gate. The user's wrap-up wish is satisfied AT NEXT SESSION, not by deferring observations to a possibly-not-read retro-summary table.
- "`/wr-itil:manage-problem` lifecycles are heavyweight in this state" — the lifecycle weight is fixed and budgeted; perceived heaviness is not a fallback gate.
- "I'll defer this to the retro summary's Tickets Deferred section instead" — the Tickets Deferred section is the SKILL-UNAVAILABLE branch only. Routing observations there because the agent prefers a lighter path is the failure mode P148 documents.
- Fabricating lighter-path subcommands that do not exist (`manage-problem create-fast` and similar) to justify deferring — the only supported invocation surfaces are the ones in `packages/itil/skills/manage-problem/SKILL.md` Operations table.

**Evidence (P148, 2026-04-29)**: an observation deferred under a non-`skill_unavailable` cause "could have very easily been lost if I was in a rush" (user correction phrasing — captures the lost-observation hazard exactly). Deferred observations depend on the user reading the retro summary AND ticketing before context expires AND the entries still being accurate when re-read days later. Each gating clause adds drop risk; Stage 1 ticketing has zero drop risk because the ticket exists in `docs/problems/` from the moment of creation.

**See also**: ADR-044 framework-mediated surface; P148 (anti-pattern driver ticket); P145 (sibling defer-pattern at the Tier 3 rotation prompt — same class of behaviour, different surface).

#### Stage 2: Record proposed fix strategy on each ticket (silent agent action per P135 / ADR-044)

For each ticket created in Stage 1, the agent picks the obvious-fit codification shape from the catalog below and writes it to the ticket's `## Fix Strategy` section WITHOUT firing `AskUserQuestion`. The framework has resolved the catalog (skill / agent / hook / settings / script / CI / ADR / JTBD / guide / test fixture / memory / internal-code); applying that catalog per observation is a mechanical decision, not a human-value question. Per-ticket `AskUserQuestion` is sub-contracting framework-resolved decisions back to the user (lazy deferral per Step 2d Ask Hygiene Pass classification).

The four shape choices remain (see Stub templates below for what each one writes), but the AGENT picks based on the observation's signal:

1. **Skill — create stub** — pick when the observation describes a recurring multi-step user-invoked sequence not yet codified (e.g. "I keep doing X-then-Y-then-Z manually"). Stub names a new skill.
2. **Skill — improvement stub** — pick when the observation is a targeted flaw in an existing SKILL.md (specific path, specific line, specific edit summary). Stub names the target file + edit.
3. **Other codification shape** — pick when the observation fits a non-skill catalog entry (agent / hook / settings / script / CI / ADR / JTBD / guide / test fixture / memory / internal-code). Free-text captures the shape + routing target (e.g. `/wr-architect:create-adr` for ADR-shaped fixes, `/wr-jtbd:update-guide` for JTBD-shaped, `/wr-voice-tone:update-guide` for voice-shaped).
4. **Self-contained work — no codification stub** — pick when the observation is a bounded one-shot edit with no recurring-pattern signal observed this session.

**Recording**: append a `## Fix Strategy` section to the ticket (or edit the existing section if present). Record the chosen Option, the shape, and the stub fields (per the templates below). The fix strategy lives on the ticket — not in the retro summary — so it travels with the problem through its lifecycle.

**User correction surface**: if the agent picks the wrong shape, the user edits the ticket's `## Fix Strategy` section directly (no orchestrator turn-around needed) — the per-ticket correction is cheap. The Step 5 retro summary's `Codification Candidates` table records each picked shape so the user can scan all picks at once and correct any wrong ones in one editing pass.

**Reversibility note**: shape choices are reversible (just re-edit the ticket); per-ticket `AskUserQuestion` is the inverse-correctness anti-pattern P132 + ADR-044 capture (high friction for low decision-irreversibility).

#### Stub templates by Option

When Stage 2 selects Option 1 (`Skill — create stub`), write the following into the ticket's `## Fix Strategy` section:

- **Kind** — `create`
- **Shape** — `skill`
- **Suggested name** — `wr-<plugin>:<verb>-<object>` per ADR-010 amended skill-granularity rule.
- **Scope** — one sentence on what the skill does and when it should fire.
- **Triggers** — 2-3 example user prompts or events.
- **Prior uses** — 2-3 observed invocations from this session.

When Stage 2 selects Option 2 (`Skill — improvement stub`), write:

- **Kind** — `improve`
- **Shape** — `skill`
- **Target file** — existing SKILL.md path (e.g. `packages/itil/skills/manage-problem/SKILL.md`).
- **Observed flaw** — one sentence.
- **Edit summary** — one sentence describing the targeted edit.
- **Evidence** — 1-3 session observations showing the flaw.

When Stage 2 selects Option 3 (`Other codification shape`), write free-text on the ticket's `## Fix Strategy` section including: the codification shape (agent / hook / settings / script / CI / ADR / JTBD / guide / test fixture / memory / internal code), a suggested stub (`Suggested name:` / `Target file:` / `Event + trigger:` as fits the shape), the routing target skill (`/wr-architect:create-adr`, `/wr-jtbd:update-guide`, `/wr-voice-tone:update-guide`, `/wr-style-guide:update-guide`, `/wr-risk-scorer:update-policy`), and 1-3 session observations. Free-text capture keeps the ADR-013 Rule 1 4-option cap intact without cascading follow-up batches (architect Q4 lean (b); P061 anti-pattern avoided).

When Stage 2 selects Option 4 (`Self-contained work — no codification stub`), write a single-line note: "Self-contained work — bounded one-shot edit, no recurring-pattern signal observed this session." The `## Fix Strategy` section records the Option 4 choice so future sessions know codification was considered and deferred with cause.

#### Interaction with P044 / P050 / P051 / P068 / P074

- **P044** (recommend new skills) — Stage 2 Option 1 (`Skill — create stub`) carries P044's enforcement intent. P044's AFK recommend-skills semantics migrate to the deferred-question fallback (Stage 2 defers per ticket in AFK).
- **P050** (recommend other codifiables) — Stage 2 Option 3 (`Other codification shape`) carries P050's shape-generalisation into free-text capture.
- **P051** (improvement axis) — Stage 2 Option 2 (`Skill — improvement stub`) carries P051's improvement axis for skill shape; non-skill improvements ride in Option 3's free-text capture with an explicit `improve` marker.
- **P068** (verification-close housekeeping) — unaffected. Step 4a stays as-is, independent of Step 4b's restructure.
- **P074** (pipeline-instability scan) — when P074 ships its Step 2b, detected instability signals feed Stage 1 as additional ticket sources. The ticket-first flow is the natural common funnel P074's RCA identifies.

#### Coordinating-ticket rule

If a single target output accumulates ≥ 3 improvement observations in one session, Stage 1 should create **one coordinating ticket** scoped as "apply N improvements to <target>" rather than N separate tickets. Stage 2 on that ticket picks Option 2 (for skill-shape targets) or Option 3 with the coordinating-ticket free-text. This reduces ticket churn and keeps the affected output's improvement queue coherent.

### 5. Summary

Present a summary to the user:

```
## Session Retrospective

### Briefing Changes
- Added: [items added — cite `docs/briefing/<topic>.md` per entry]
- Removed: [items removed with reasons]
- Updated: [items modified]
- README index refreshed: [per-file summaries or Critical Points changes]

### Signal-vs-Noise Pass (P105)

(Emitted only when Step 1.5 scored briefing entries. Always present when run-retro is invoked — the pass runs regardless of other outcomes. In non-interactive / AFK mode, the delete queue is surfaced here instead of firing `AskUserQuestion`.)

| Entry | Topic file | Old score | New score | Classification | Citation |
|-------|-----------|-----------|-----------|----------------|----------|
| <one-line entry summary> | `docs/briefing/<topic>.md` | <old> | <new> | signal / noise / decay-only | <tool call or reasoning paraphrase> |

**Critical Points changes**: list any entries promoted to or demoted from the Critical Points roll-up.

**Delete queue** (only when non-empty): list each score <= -3 candidate with its score and citation. In interactive mode, note the user's decision (`confirmed / deferred / kept`). In AFK mode, label each as `deferred to next interactive session`.

**Budget overflow** (only when triggered): list any score >= +3 entries that were NOT promoted because the Tier 1 budget was already met.

### Problems Created/Updated
- [problem ticket]: [summary]

### Tickets Deferred

(Emitted only when Step 4b Stage 1 took the SKILL-UNAVAILABLE fallback per the AFK branch above — every row MUST cite a `Cause` field naming a valid fallback gate. Omit this section entirely when no observations were deferred. P148.)

| Observation | Cause | Citation |
|-------------|-------|----------|
| <one-line observation summary> | `skill_unavailable` | <retro-step-citation, e.g. `Step 2b detection`, `Step 4a verification candidate`> |

The `Cause` column accepts only `skill_unavailable` (per `packages/retrospective/scripts/check-tickets-deferred-cause.sh` allowlist). Rows with any other cause — or no `Cause` column — are Step 4b Stage 1 violations; the script surfaces them as such on its next run. Session-length rationalisations, perceived heaviness, or fabricated subcommands are NOT valid causes (see the AFK branch's anti-pattern enumeration in Step 4b).

### Verification Candidates

(Emitted only when Step 4a found `.verifying.md` tickets with specific in-session citations. Omit this section entirely when no candidates were found — or when the interactive path closed them all during Step 4a. Populated in non-interactive / AFK mode per ADR-013 Rule 6 — the user closes on return.)

| Ticket | Fix summary | In-session citations | Decision |
|--------|-------------|----------------------|----------|
| P<NNN> | <one-sentence fix summary> | <specific invocations + observable outcomes> | closed via manage-problem / left Verification Pending / flagged for manual review / flagged (non-interactive) |

### Pipeline Instability

(Emitted only when Step 2b detected pipeline-level friction with specific citations. Omit this section entirely when no detections were made — or when the interactive path ticketed or dismissed them all during Step 2b. Populated in non-interactive / AFK mode per ADR-013 Rule 6 — the user reviews on return and tickets via `/wr-itil:manage-problem` per accepted detection.)

| Signal | Category | Citations | Decision |
|--------|----------|-----------|----------|
| <one-line signal summary> | Hook-protocol friction / Skill-contract violations / Release-path instability / Subagent-delegation friction / Repeat-work friction / Session-wrap silent drops | <specific invocations + session-position markers + observable outcomes> | new ticket via manage-problem / appended to P<NNN> / recorded in retro only / skipped (false positive) / flagged (non-interactive) |

### Topic File Rotation Candidates

(Emitted only when Step 3's Tier 3 budget pass surfaced topic files at or above the configured threshold via `check-briefing-budgets.sh`. Omit this section entirely when no candidates were found — or when the interactive path resolved them all during Step 3. Populated in non-interactive / AFK mode per ADR-013 Rule 6 — the user reviews on return and applies the chosen rotation shape per candidate. P099.)

| Topic file | Bytes | Threshold | Proposed rotation | Decision |
|------------|-------|-----------|-------------------|----------|
| `docs/briefing/<topic>.md` | <N> | <N> | split-by-subtopic / split-by-date / trim-noise / defer | applied / deferred / flagged (non-interactive) |

### Ask Hygiene (P135 Phase 5 / ADR-044)

(Emitted unconditionally by Step 2d. Mirrors the trail file persisted at `docs/retros/<YYYY-MM-DD>-ask-hygiene.md` for cross-session trend via `packages/retrospective/scripts/check-ask-hygiene.sh`. Lazy count is the regression metric per ADR-044 — target 0.)

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | <header> | direction \| deviation-approval \| override \| silent-framework \| taste \| correction-followup \| **lazy** | `Framework: <ADR / SKILL / policy>` for lazy; `Gap: <one-line>` for non-lazy |

**Lazy count: <N>**
**Direction count: <N>**
**Override count: <N>**
**Silent-framework count: <N>**
**Taste count: <N>**
**Correction-followup count: <N>**

### Codification Candidates

| Kind | Shape | Suggested name / Target file | Scope / Flaw | Triggers / Evidence | Decision |
|------|-------|-----------------------------|--------------|----------------------|----------|
| create  | skill | [suggested name] | [scope] | [examples] | created stub / routed to <skill> / skipped / flagged (non-interactive) |
| create  | agent | ... | ... | ... | ... |
| improve | skill | [target file path] | [observed flaw] | [1-3 session observations] | improvement stub / routed to <skill> / skipped / flagged (non-interactive) |
| improve | hook  | ... | ... | ... | ... |

### No Action Needed
- [learnings that were already captured]
```

The `Kind` column takes values `create` or `improve` — the create / improve axis defined in Step 2 and Step 4b. Creation rows use the `Suggested name` / `Scope` / `Triggers` field semantics; improvement rows reuse the same columns with `Target file` / `Observed flaw` / `Evidence` semantics (per the stub-recording guidance in Step 4b). The decision column carries the same vocabulary for both Kinds, with `improvement stub` replacing `created stub` for Kind=improve rows.

If the "Codification Candidates" table has no rows, omit it rather than rendering an empty header. The legacy "Skill Candidates" heading is preserved as a worked-example row in the Shape column so downstream tooling that grepped for "Skill Candidates" continues to find skill-shaped entries within the unified table.

$ARGUMENTS
