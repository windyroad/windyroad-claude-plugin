# @windyroad/problem

## 0.23.2

### Patch Changes

- 3a1c109: P141: enforce changeset discipline at `git commit` time via new PreToolUse:Bash hook `packages/itil/hooks/itil-changeset-discipline.sh`. The hook denies `git commit` invocations whose staged set includes `packages/<plugin>/*` source files but no `.changeset/*.md` (excluding `README.md`) is staged. Detection delegates to `packages/itil/hooks/lib/changeset-detect.sh::detect_changeset_required`, which categorises staged paths into changeset / publishable-source / allow-listed-test / allow-listed-doc / non-publishable buckets. Allow paths emit zero bytes per ADR-045 Pattern 1 (silent-on-pass); deny paths emit a single-line directive ≤300 bytes naming the offending plugin slug, the `bun run changeset` recovery command, the `BYPASS_CHANGESET_GATE=1` escape hatch, and the P141 cite. Hook registered in `packages/itil/hooks/hooks.json` as a third `PreToolUse:Bash` matcher alongside `p057-staging-trap-detect.sh` and `pre-publish-intake-gate.sh`. Allow-list per architect verdict 2026-05-02 — test paths (`test/`, `hooks/test/`, `scripts/test/`), package `README.md`, and `*.md` under package `docs/`. `SKILL.md` is deliberately NOT in the allow-list (it IS the publishable contract per ADR-037 framing). 21 behavioural bats per ADR-005 + P081 in `packages/itil/hooks/test/itil-changeset-discipline.bats` cover deny shapes, allow paths, BYPASS env var, ADR-045 silent-on-pass, fail-open contracts (parse error / outside git tree). Closes the orchestrator-main-turn back-fill anti-pattern observed at 40% miss rate across 5 publishable iters in the 2026-04-28 AFK loop session — `/wr-itil:work-problems` iter subprocesses operating under heavy SKILL.md + ticket-body + architect/JTBD prompt context pressure dropped the prompt-time changeset reminder; hook-level enforcement makes the requirement unmissable without adding to the iter's context budget. Composes-with P073 (changeset author-time gate at Write/Edit on `.changeset/*.md` — different surface, defence-in-depth). No new ADR required — same enforcement-layer pattern as P125 staging-trap hook (per-invocation deterministic, no markers).
- 148d189: P151: replace `bash packages/itil/scripts/<name>.sh` invocations in published SKILL.md with `$PATH`-resolved bin shim wrappers per ADR-049. Adopter sessions running `/wr-itil:manage-problem`, `/wr-itil:work-problems`, and `/wr-itil:reconcile-readme` previously hard-failed at Step 0 with `bash: No such file or directory: packages/itil/scripts/reconcile-readme.sh` because the repo-relative path does not resolve in adopter trees. Two new shim wrappers ship in `packages/itil/bin/` — `wr-itil-reconcile-readme` and `wr-itil-check-problems-readme-budget` — each a 3-line `exec "$(dirname "$0")/../scripts/<name>.sh" "$@"` body relaying to the canonical script. Three SKILL.md invocation sites updated (`manage-problem` Step 0 L189, `work-problems` Step 0 L89, `reconcile-readme` Step 1 L44) plus two documentation references (`manage-problem` SKILL.md L465 / L477) rewritten to name the bin-wrapper. ADR-049 codifies the rule: plugin-bundled scripts invoked from SKILL.md MUST resolve via `bin/` on `$PATH`, never via repo-relative paths; naming grammar `wr-<plugin>-<kebab-script-name>` is fixed. Cross-plugin grep-as-lint bats at `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` (8 tests) catches regressions at CI. The canonical script bodies under `packages/itil/scripts/` are unchanged; existing `packages/itil/scripts/test/*.bats` continue to test the canonical path. Sibling JTBD-301 plugin-user persona unblocked.

## 0.23.1

### Patch Changes

- cc79ae2: P140 Phase 1 — `/wr-itil:work-problems` Step 6.5 Failure handling adds diagnose-then-classify routing with fix-and-continue branch. Previous behaviour was a uniform halt-on-CI-failure rule that converted mechanically-fixable failures (1-line stale-grep-string updates, transient flakes) into ~45min queue stalls during AFK loops, regressing JTBD-006 "Progress the Backlog While I'm Away" without governance benefit.

  What changes (declarative SKILL.md amendment only):

  - **Step 6.5 Failure handling subsection** in `packages/itil/skills/work-problems/SKILL.md` rewritten to add:

    - Diagnostic preamble — orchestrator MUST first run `gh run view <run-id> --log-failed` and cite the output verbatim in the fix-and-continue commit message or halt summary (ADR-026 grounding).
    - Closed fixable-in-iter allow-list: P081-class stale-grep-string, hook stub mismatch, test ID drift, environmental flake. **Closed** — adding a class is itself a deviation-candidate per ADR-044 framework-resolution boundary.
    - Ambiguous classification defaults to halt (no diagnose-then-guess).
    - Fix-and-continue branch: 1 Edit → ADR-014 commit gate flow (architect / JTBD / risk-scorer per retry) → push → re-watch CI → resume on pass / increment retry counter on fail.
    - 3-retry cap per iteration (not per failure-class) before fallback to halt branch.
    - Halt branch preserved for genuinely-unrecoverable: auth failure, npm publish rejection, semantic test requiring user judgment, repeated transient failures, anything outside the closed allow-list.
    - Step 2.5b cross-reference (P126) preserved on the halt branch.

  - **Non-Interactive Decision Making table** carries a new row "CI failure during Step 6.5 drain (within-appetite branch)" routing through fix-and-continue + 3-retry cap.

  - **Mid-loop ask discipline subsection** (P130) Step 6.5 CI-failure halt-point bullet narrowed to outside-allow-list / 3-retry-cap-reached scope. Failures inside the allow-list route to fix-and-continue, not this halt point.

  Why: 2026-04-28 session evidence — Step 6.5 drain hit CI failure on test 1375 (P081-class stale `'skip Step 6'` literal vs current `'skip Steps 5b/5c'` SKILL.md prose); 1-line fix; re-pushed; CI passed; release shipped. User correction was explicit and class-level: _"this shouldn't be a halt. This should be a fix and continue"_. P140 codifies this as policy.

  Composition: fix-and-continue is policy-authorised per ADR-013 Rule 5 (closed allow-list IS the policy). Each retry's commit rides standard ADR-014 commit gate flow per ADR-042 Rule 3 precedent (retries each ride their own commit through architect / JTBD / risk-scorer review). No governance bypass. Inverse of P132 (over-ask in interactive sessions) on the failure-handling surface; composes with P081 (stop-gap — fix-and-continue elides the friction P081's full retrofit eliminates structurally), P130 (mid-loop ask discipline — fix-and-continue does NOT introduce mid-iter asks), P135 (decision-delegation contract).

  Files shipped:

  - `packages/itil/skills/work-problems/SKILL.md` — Step 6.5 Failure handling rewrite + Decision table row + halt-point bullet narrowing.
  - `packages/itil/skills/work-problems/test/work-problems-step-6-5-fix-and-continue.bats` — NEW 28 behavioural contract assertions per ADR-037 + P081.
  - `docs/problems/140-...open.md` → `.verifying.md` — Status flip + Phase 1 shipped section per ADR-022 fold-fix convention.
  - `docs/problems/README.md` — WSJF Rankings + Verification Queue refresh per P062.

  Out of scope (deferred per ticket Fix Strategy):

  - Phase 2 `packages/itil/scripts/diagnose-ci-failure.sh` advisory classifier — observe Phase 1 declarative discipline over 30 days; load-bearing classifier may not be necessary if agent behaviour aligns to the SKILL.md prose.
  - Full P081 retrofit of structural-grep tests — separate ticket.

  Architect: PASS — Phase 1-only scope correct; ADR-014 invariant preserved (retries each ride own commit through gates, ADR-042 Rule 3 precedent); fix-and-continue branch belongs inside Failure handling subsection (sibling to halt branch, not separate subsection); no new ADR needed (ADR-013 Rule 5 + ADR-044 + in-skill prose suffice). Advisory: closed-allow-list scope-creep guard added per architect FLAG (extension is a deviation-candidate). Stale-decision check: ADR-018 reassessment 2026-07-18 within window; ADR-014 reassessment 2026-10-16 within window.
  JTBD: PASS — JTBD-006 primary (restores "progress continues without me being present" while preserving "stops gracefully on a blocker"); JTBD-001 + JTBD-002 compose intact (per-retry gates preserve governance); persona-misread risk addressed via closed-list framing + ambiguous-defaults-to-halt + per-iteration cap clarification.
  TDD: 28/28 new bats green; full 203-test work-problems suite green (no regression).

- 4697624: P144: document gate-misfire recovery procedure in `manage-problem` Step 2 substep 7 (two-tier — announce-marker scrape + python3-via-Bash fallback) and add a conditional recovery hint to the `manage-problem-enforce-create.sh` deny message that fires only when `compgen -G '/tmp/manage-problem-grep-*'` matches at least one marker for SOME SID (the helper-bug signal). ADR-048 sanctions and scopes the procedure with explicit P142-auto-supersession criteria and an audit-trail-preservation test that rules out the P131 any-marker-anywhere anti-pattern.

  The recovery surfaces a documented forward path for orchestrator sessions where the P124 helper returns a subprocess SID instead of the orchestrator SID — the canonical 2026-04-28 failure mode where the agent reached for the brute-force-marker anti-pattern (139 markers in one session). The two-tier procedure preserves audit-trail integrity (Step 2 grep DID run for THIS ticket creation) and explicitly forbids the brute-force pattern at both surfaces (durable in SKILL.md, just-in-time in hook deny hint). Auto-supersedes when P142 (P124 Phase 4) ships and the helper returns the runtime hook SID reliably; the SKILL.md sub-block carries an HTML supersession comment paired with a CI-enforced bats invariant so the cleanup becomes a CI-fail signal once P142's resolution ADR is `accepted`.

## 0.23.0

### Minor Changes

- a8711ab: P131 Phase 2 — `.claude/` user-space write protection. NEW `packages/itil/hooks/itil-claude-space-protection.sh` PreToolUse:Write|Edit hook denies agent writes to project-scoped `.claude/` paths NOT in the user-space allow-list, unless an approval marker is present. NEW shared helper `packages/itil/hooks/lib/claude-space-gate.sh` exporting `is_protected_claude_path` / `has_approval_marker` / `claude_space_deny`.

  Why: `.claude/` is user-controlled config space (settings, memory, MCP servers, user-authored skills/hooks/commands/agents, Claude Code's own state in `projects/` and `worktrees/`). Agents misread the architect/JTBD/TDD/style-guide/voice-tone/risk-scorer gate-exclusion lists as "approved write zones" and write project-generated content (plans, audits, scratch state) under `.claude/`, polluting user space. Project-generated content belongs in `docs/` (plans, audits) or inline in problem-ticket bodies.

  Allow-list (project-relative): `.claude/{settings.json, settings.local.json, MEMORY.md, .install-updates-consent, scheduled_tasks.lock}` + `.claude/{skills, commands, agents, hooks, projects, worktrees}/*` subtrees + `.claude/*.local.json` (root-depth only) + `.claude/.agent-write-approved-*` markers themselves.

  Approval-marker bypass: user creates `.claude/.agent-write-approved-<sha256-of-rel-path>` to pre-authorize specific paths. Persistent (no TTL); user creates once per path. Distinct semantic class from ADR-009 session-scoped /tmp markers — this is a persistent path-keyed approval-marker class, precedent-shaped on `.claude/.install-updates-consent` (ADR-030 / P120).

  Out of scope (unaffected): Read|Glob|Grep on `.claude/` paths, paths outside `$PWD` project root (~/.claude/, other repos' .claude/), `.claude/` subtree edits hitting allow-listed paths.

  Deny message: ~440 bytes (under ADR-038 progressive-disclosure 500-byte cap), names P131 + suggests `docs/plans/` / `docs/audits/` / inline-ticket alternatives + names approval-marker bypass + references project CLAUDE.md MANDATORY rule. Silent on allow path per ADR-045 Pattern 1. Fail-open on parse error per ADR-013 Rule 6.

  Files shipped:

  - `packages/itil/hooks/itil-claude-space-protection.sh` — NEW PreToolUse:Write|Edit hook.
  - `packages/itil/hooks/lib/claude-space-gate.sh` — NEW shared helper.
  - `packages/itil/hooks/hooks.json` — registers the new hook.
  - `packages/itil/hooks/test/itil-claude-space-protection.bats` — NEW 34 behavioural assertions per ADR-037 + P081 covering deny path, allow-list, outside-.claude paths, approval-marker bypass, Read|Glob|Bash unaffected, allow-list anchor depth, deny-message contract, byte budget, silent-on-pass.
  - `docs/problems/131-...known-error.md` → `.verifying.md` — Status flip + Phase 2 shipped section per ADR-022 fold-fix convention.
  - `docs/problems/README.md` — WSJF Rankings + Verification Queue refresh per P062.

  Architect: PASS-WITH-NOTES — allow-list amended to add `MEMORY.md`, `commands/`, `agents/`, `hooks/` subtrees + anchor `*.local.json` to root depth; ADR formalising user-space-vs-project-space distinction deferred to Phase 3 per ticket Fix Strategy line 113; marker format consistent with ADR-009 (new persistent semantic class, not conflict).
  JTBD: ALIGNED PASS — JTBD-001 primary (governance without breaking user editing flows; allow-list preserves "no manual policing"); JTBD-006 strong fit (originating P131 incident was AFK orchestrator writing `.claude/plans/p081-...md`; Phase 2 prevents recurrence); JTBD-101 no conflict; JTBD-202 indirect.
  Voice-tone: PASS advisory-only (`docs/VOICE-AND-TONE.md` not yet authored).
  Style-guide: PASS out-of-scope.
  TDD: 34/34 new bats green; full 129-test itil hooks suite green (no regression).

  Phase 3 remaining (deferred): formalising-ADR; doc-reframe in remaining 4 gate-hook prose surfaces (tdd, style-guide, voice-tone, risk-scorer); `docs/briefing/hooks-and-gates.md` topic file update.

### Patch Changes

- e85d2e1: P123 — `packages/itil/hooks/lib/block-list.sh` shared helper for the inbound-report block-list mechanism. Per ADR-046's v1 implementation contract — audit-log-only — the helper exposes `is_blocked(<hash>)`, `add_block(<hash> <evidence-ticket> <provenance>)`, `remove_block(<hash> <reason>)`, and `list_blocks()`. Caller-supplied opaque hex hashes (SHA-256 width validated); helper does not compute hashes — keeping the surface GitHub-agnostic per ADR-046 §Reassessment.

  Persistence: `docs/blocked-reporters.json` (per-repo JSON array, tracked in git, hashes only — no usernames). Audit log: sibling `docs/blocked-reporters.audit.jsonl` (append-only JSONL, five-field shape per ADR-046 Q2 — `{type, reporter_id_hash, evidence_ticket, timestamp, author}`).

  ADR-046 Q1/Q2/Q3 already adopted (proposed defaults accepted via prior batch AskUserQuestion at iter 9 quota-halt 2026-04-28); this iter ships the audit-log-only v1 slice and transitions ADR-046 `proposed → accepted`. Q3's "agent-monitored review-cycle" direction is resolved; un-block monitor implementation deferred to a future iter beyond this v1 slice (per ADR-046 §Q3 Adopted note).

  No enforcement integration in this slice. P079's inbound-discovery filter and `/wr-itil:report-upstream`'s outbound pre-check land when those features ship — out of scope for P123 per the ticket's pacing decision (line 78). The persistence layer is the foundation those iters consume; without it they would re-derive the shape from ADR-046 inline.

  Files shipped:

  - `packages/itil/hooks/lib/block-list.sh` — NEW shared helper, four functions.
  - `packages/itil/hooks/test/block-list.bats` — NEW behavioural bats: 10 assertions covering round-trip, idempotent add, remove path, audit-log presence (block + unblock), list_blocks shape, and hex-shape validation rejections (non-hex + wrong-length).
  - `docs/blocked-reporters.json` — NEW empty array per-repo persistent block list.
  - `docs/decisions/046-blocked-reporters-persistence.proposed.md` → `.accepted.md` — Status flip; Q1/Q2/Q3 confirmed adopted.
  - `docs/problems/123-...known-error.md` → `.verifying.md` — Status flip + Fix Released section per ADR-022 fold-fix convention.
  - `docs/problems/README.md` — WSJF Rankings + Verification Queue refresh per P062.

  Architect: ALIGNED-with-notes / PASS no new ADR — ADR-046 governs; helper-doesn't-hash separation locked in; JSONL audit-log shape obvious local choice.
  JTBD: ALIGNED / PASS — JTBD-101 (Extend the Suite) primary persona served by foundation-only slice; JTBD-001 + JTBD-202 compose; no regression vs zero-defence today.
  TDD: 10/10 green; full itil hooks suite 95/95 green (no regression).

- 4d2a55d: P133 — zsh-portability gap in shell-snippet examples. Phase 1 immediate fix at the proximate failure surface (`scripts/repo-local-skills/install-updates/SKILL.md:167`) plus defensive rename in the load-bearing `reconcile-readme.sh` script.

  The 2026-04-27 session hit two distinct zsh-vs-bash failures in `/install-updates` Step 7: (1) `local status=...` errored with `read-only variable: status` because zsh has `$status` as a read-only built-in alias for `$?`; (2) `for plugin in $PLUGINS_TO_UPDATE` (where the variable was a space-separated string) silently iterated **once** under zsh because zsh does NOT word-split unquoted variables by default. All 24 install operations were marked `lost` until the wrapper was rewritten to use a bash array.

  Changes:

  - `scripts/repo-local-skills/install-updates/SKILL.md` Step 6 inner loop now uses bash-array iteration (`PLUGINS_TO_UPDATE=(itil retrospective risk-scorer tdd)` + `for plugin in "${PLUGINS_TO_UPDATE[@]}"`) — portable across bash and zsh. New portability note explains why array form (not unquoted iteration). This is the proximate failure surface that broke the 2026-04-27 session.
  - `packages/itil/scripts/reconcile-readme.sh` defensive rename `status` → `ticket_status` at the two assignment sites (lines 65-72 filesystem-truth build phase + lines 174-191 drift-detection loop). Script has a hard `#!/usr/bin/env bash` shebang so it never runs under zsh directly, but the rename eliminates the latent footgun for any future caller that sources or copies the pattern. Inline comment cross-references P133.
  - `packages/itil/scripts/test/reconcile-readme.bats` new behavioural regression test (`run env status=junk "$SCRIPT" "$FIXTURE_DIR"`) confirming drift detection is independent of any caller-controlled `status` env var. 17/17 green (16 prior + 1 new).

  Audit findings (in-scope but clean — recorded for the verifying-transition note):

  - `packages/itil/skills/{work-problems,manage-problem,transition-problem}/SKILL.md` — no bash-isms in fenced shell snippets (greps for `for x in $VAR`, `local status=`, unquoted `${array[@]}` returned no matches).
  - `packages/retrospective/skills/run-retro/SKILL.md` — same.
  - `packages/itil/hooks/*.sh` and `packages/itil/hooks/lib/*.sh` — all have `#!/bin/bash` shebangs; safe.

  Phase 2 (repository-wide audit + remediation) and Phase 3 (CI/pre-commit lint detecting bash-isms in committed snippets) deferred to compose with **P136** (ADR-044 alignment audit master) per architect direction.

  Architect ALIGN (no new ADR; alignment with ADR-014 ONE-commit batching, ADR-022 verifying-transition criteria, ADR-030 repo-local-skills source-of-truth governance). JTBD ALIGN (JTBD-001 solo-developer primary fit — silent-failure surface eliminated; JTBD-007 keep-plugins-current direct outcome; JTBD-101 plugin-developer downstream pattern). Style PASS (no UI/visual styling). Voice PASS (no banned patterns).

  Transitions P133 Open → Verification Pending per ADR-022.

- ac2425e: P134 — `docs/problems/README.md` line-3 "Last reviewed" parenthetical accumulator-bloat truncation contract. Applies the P099 reusable triplet (ADR-040 line 92 explicitly names "problems index" as a covered surface) to the problems index: line 3 had grown unbounded to 76,582 bytes — past 62KB it broke the Read tool entirely (25K-token whole-file cap), forcing awk/grep workarounds on every inspection task.

  The fix mirrors P099's `check-briefing-budgets.sh` shape at the new surface:

  - New advisory `packages/itil/scripts/check-problems-readme-budget.sh` (read-only diagnostic; mirrors P099 patterns)
  - 13 new behavioural assertions in `packages/itil/scripts/test/check-problems-readme-budget.bats` (13/13 green)
  - New canonical "Last-reviewed line discipline (P134)" subsection in `packages/itil/skills/manage-problem/SKILL.md`; Step 5 P094 / Step 6 P094 / Step 7 P062 reference it inline (one fragment ≤ 1024 bytes soft, 5120 bytes hard ceiling, displaced fragments rotate to forward-chronology `docs/problems/README-history.md` archive sibling)
  - Same discipline applied to `transition-problem`, `transition-problems`, `review-problems`, and the load-bearing `reconcile-readme` (whose prior "ever-growing prose paragraph" convention was the source-of-bloat surface)
  - New `docs/problems/README-history.md` archive sibling — forward-chronology log; legacy 76,582-byte content seeded under a 2026-04-28 heading; line 3 trimmed in the same commit as one-shot remediation

  Read-tool symptom verified closed in same session: orchestrator's initial Read of `docs/problems/README.md` returned `File content (48677 tokens) exceeds maximum allowed tokens (25000)` BEFORE; AFTER the fix, `Read offset=1 limit=12` succeeds cleanly (line 3 now 800 bytes, 95× reduction).

  Architect PASS no new ADR (ADR-040 line 92 reusable-pattern note explicitly covers this surface). JTBD PASS (JTBD-001 primary fit — Read-tool affordance restored; JTBD-006 + JTBD-101 compose). 535/535 green across affected bats suites (240/240 manage-problem family + 295/295 hooks/work-problems family).

  Transitions P134 Open → Verification Pending per ADR-022.

## 0.22.1

### Patch Changes

- 8bf58c8: P085 — `packages/itil/hooks/lib/detectors.sh` Prose-ask detector phrasing-list extension covering 2026-04-28 regression evidence (ticket reopened from Verification Pending). The 2026-04-24 fix (UserPromptSubmit gate + Stop review hook + detector registry) shipped at minor but the canonical phrasing list missed the "Awaiting your direction" / "Pending your decision" / "Once you confirm" shapes the orchestrator emitted at Step 6.75 halt-summary today.

  Specific evidence (Citation 1, this session ~17:25): orchestrator main turn emitted _"Awaiting your direction on whether to add it + resume on P123, or end the session."_ — a binary-choice prose-ask. Empirical verification: existing pattern list returned exit-code 1 on this text. Detector extension closes the gap.

  Files shipped:

  - `packages/itil/hooks/lib/detectors.sh` — `PROSE_ASK_PATTERNS` extended with four new entries: `Awaiting your (direction|input|decision|response|confirmation|answer|reply)`, `Pending your (direction|input|decision|response|confirmation|answer|reply)`, `Once you confirm`, `Awaiting your direction on whether` (specific shape from Citation 1, retained alongside the broader pattern for observability — first-match return reports the more specific phrase).
  - `packages/itil/hooks/test/itil-assistant-output-review.bats` — 5 new behavioural bats per ADR-037 + P081: Citation 1 verbatim shape, plus four adjacent phrasings each fed through a JSONL transcript to the Stop hook with `stopReason` assertion. Clean-turn negative test unchanged remains green.

  Citation 2 (over-ask when framework prescribes the answer — _"FFS, why are you stopping to ask. what does the decision framework tell you to do?"_) is class-of-behaviour overlap with P132 (Open, WSJF 4.5 — Agents over-ask in interactive sessions). Framework-knowability detection requires a hook that reads SKILL.md decision tables and reasons about whether the question is mechanically answerable; that is a substantially harder problem than the phrasing-list extension here. Deferred to P132's broader fix per architect verdict (composes with ADR-044 R6 numeric gate).

  Transitions P085 Known Error → Verification Pending per ADR-022.

- 8212d4f: P124 Phase 3 — `packages/itil/hooks/lib/session-id.sh::get_current_session_id` within-system selection changed from first-glob-match (alphabetical) to most-recent-mtime (`ls -t | head -1`). Phase 2's portability fix (the for-loop existence check that replaced bash-only `shopt -s nullglob`) is preserved; Phase 3 layers mtime selection on top of it.

  Why Phase 2 alone wasn't enough: glob expansion under both bash and zsh enumerates matches in ASCII-alphabetical order by default. Phase 2's "first match wins" inner loop returned the alphabetically-first present marker. On a developer machine accumulating one `${system}-announced-${SID}` marker per past session in /tmp (observed 103 stale architect markers in a single regression run on 2026-04-28), the alphabetically-first UUID was a stale prior-session UUID. Helper returned a wrong SID; the create-gate hook (P119) read the live SID from its stdin JSON and denied the Write; recovery required brute-touching `manage-problem-grep-` for every known SID (81–103 markers per recovery in evidence).

  Phase 3 fix: within-system selection switches to most-recent-mtime via `ls -t "${marker_dir}/${system}-announced-"* 2>/dev/null | head -1`. `-announced-` markers per ADR-038 are write-once-per-session (no `touch`-refresh, no sliding TTL — unlike `-reviewed-` markers governed by ADR-009 + P111), so mtime IS the announcing session's first-prompt timestamp. Newest mtime within a single system's `-announced-` glob unambiguously identifies the live session. The outer system priority loop (architect → jtbd → tdd → itil-assistant-gate → itil-correction-detect → style-guide → voice-tone) is preserved verbatim.

  `packages/itil/hooks/test/session-id.bats` gains one new behavioural assertion per ADR-037 + P081: write three architect-announced markers with controlled mtimes (`sleep 1` between writes) where the alphabetically-first UUID has the OLDEST mtime; assert helper returns the newest-mtime UUID, not the alphabetical-first. Phase 2's existing 7 assertions remain green; suite is now 8/8.

- dcc65b4: P130 — `packages/itil/skills/work-problems/SKILL.md` Mid-loop ask discipline (orchestrator main turn). Tightens the orchestrator's ask discipline per the user-reframed Fix Strategy: presence-detection is unreliable and is not the goal; treat the user as transient (may answer one question and disappear for hours). The loop's purpose is progress + accumulation; mechanical-stage transitions between iters are framework-resolved.

  The orchestrator MUST NOT call `AskUserQuestion` between iters except at framework-prescribed halt points: Step 0 session-continuity / fetch-failure; Step 2.5 / 2.5b loop-end emit; Step 6.5 above-appetite Rule 5 + CI-failure / release:watch halts; Step 6.75 dirty-for-unknown-reason. Continue iterating until quota exhausts or a stop-condition fires.

  Accumulated user-answerable questions follow strict discipline at surface time:

  - Direction-setting decisions only (no BUFD)
  - No questions answerable by research / exploration / experimentation — the agent should prototype, read code, run experiments to answer those itself
  - Each surfaced question must carry enough context for an informed decision (architect's recommended option, alternatives, trade-offs, concrete consequences of each path)

  Files shipped:

  - `packages/itil/skills/work-problems/SKILL.md` — new "Mid-loop ask discipline (orchestrator main turn)" subsection inside Non-Interactive Decision Making; framework-prescribed halt-point enumeration; transient-user framing; accumulated-question discipline; cross-references to Step 5's per-subprocess constraint.
  - `packages/itil/skills/work-problems/SKILL.md` Step 5 iteration-prompt body — augmented with the transient-user framing.
  - `packages/itil/skills/work-problems/test/work-problems-no-mid-loop-asking.bats` — 20 new behavioural assertions per ADR-037 + P081 covering the no-mid-iter-asks invariant and the framework-prescribed halt-point allow-list.

  ADR-032 unchanged — the subprocess-boundary contract is preserved verbatim. Out of scope per the reframe: presence-signal helper (`packages/itil/hooks/lib/presence-signal.sh`), dual-mode dispatch, stream-json live-tail observation surface.

  Composes with P132 (over-ask in interactive sessions — same family of agent-discipline gaps; P132's enforcement hook serves P130's reframed direction) and P135 / ADR-044 (decision-delegation contract — framework-resolution boundary).

  Transitions P130 Known Error → Verification Pending per ADR-022.

## 0.22.0

### Minor Changes

- 74822b5: `/wr-itil:manage-problem` + `/wr-itil:review-problems` + `/wr-itil:work-problems`: render `docs/problems/README.md` WSJF Rankings table in tie-break-ladder order with a `Reported` date column so the rendered top-to-bottom row order matches the orchestrator's tie-break selection 1:1 (P138).

  Multi-key sort spec `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)` documented at all five render-block sites (`manage-problem` SKILL.md Step 5 P094 + Step 7 P062 + Step 9c presentation + Step 9e template, `review-problems` SKILL.md Step 3 + Step 5 README template, `work-problems` SKILL.md Step 1) with stable greppable cross-coupling marker `<!-- TIE-BREAK-LADDER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 -->` at each site so future tie-break ladder changes know to update every render block. New behavioural + structural bats coverage `manage-problem-readme-tie-break-order.bats` 13/13 green covers marker presence, sort spec verbatim, Reported column in templates, drift-warning prose, AND a behavioural fixture sort with 4 same-WSJF tickets differing by Status/Effort/Reported asserting post-sort row order matches the tie-break ladder result. `docs/problems/README.md` re-rendered against the new sort: the WSJF 6.0 tier now shows P123 → P135 → P082 instead of P135 → P123 → P082, matching `/wr-itil:work-problems` Step 3 selection 1:1 (the exact case that triggered this ticket — user saw orchestrator pick P123 while README showed P135 on top, assumed orchestrator was broken).

  Closes P138 (Open → Verification Pending per ADR-022).

## 0.21.7

### Patch Changes

- 1f0b9fc: P124 Phase 2 — `packages/itil/hooks/lib/session-id.sh::get_current_session_id` is now zsh-portable. The Phase 1 implementation used `shopt -s nullglob` (a bash builtin) inside a subshell; under zsh — the agent's actual interactive shell on macOS — this errored with `command not found: shopt` and let the subshell glob expression fall through to a literal unmatched-pattern string, returning a wrong/stale UUID. Citation: ticket "Regression Evidence (2026-04-27)", main-turn P130 capture line 119: `get_current_session_id:33: command not found: shopt`. Recovery required brute-forcing 81 marker files for one ticket creation.

  Phase 2 replaces the `shopt`-subshell with a portable `for f in "${marker_dir}/${system}-announced-"*; do [ -e "$f" ] || continue; marker="$f"; break; done` existence-check loop. Identical behaviour under bash, zsh, and POSIX dash. The fixed marker-system priority order (architect → jtbd → tdd → itil-assistant-gate → itil-correction-detect → style-guide → voice-tone) is preserved verbatim from Phase 1. The `&&` short-circuit empty-SID contract preserved (no `/tmp/manage-problem-grep-` empty-tail file ever created).

  `packages/itil/hooks/test/session-id.bats` gains one new behavioural assertion per ADR-037 + P081: helper invoked under `zsh -c` returns the same UUID as under `bash -c`, exits 0, emits no `shopt: command not found` on stderr. Existing 6 Phase 1 assertions remain green; suite is now 7/7. Test skips cleanly if `zsh` is not on PATH.

  Architect verdict (PASS, advisory): Phase 2 implements only the `shopt` portability fix; the ticket's "Fix Strategy (Phase 2)" section also named a glob-ordering ASCII→mtime fix, but that is intentionally not in Phase 2 scope — Phase 1's switch to `-announced-` markers + the system-priority discipline already supersedes the mtime-sort idea (see Phase 1 architect refinement on `-reviewed-` marker fragility under ADR-009 sliding TTL + P111).

  JTBD alignment confirmed (jtbd-lead PASS): JTBD-001 (Enforce Governance Without Slowing Down) primary — eliminates the 81-marker brute-force recovery cost on first ticket creation per session. JTBD-006 (Progress the Backlog While I'm Away) composes — AFK loops creating tickets mid-iter no longer risk wedging on Step 2 deny.

## 0.21.6

### Patch Changes

- c5b91ef: P136 Phase 2 (ADR-044 alignment audit — manage-incident SKILL.md) per the inline plan on `docs/problems/136-adr-044-alignment-audit-master.open.md`.

  Third per-skill amendment in the suite-wide audit (after `work-problem` singular at `@windyroad/itil@0.21.4` and `mitigate-incident` at `0.21.5`). **Closes Phase 2 of P136** — all three high-ask SKILLs (work-problem singular, mitigate-incident, manage-incident) are now aligned with ADR-044's framework-resolution boundary and 6-class authority taxonomy.

  Manage-incident's audit found **0 lazy-deferrals to remove** (incident-declaration is fundamentally interactive — all 4 call surfaces are genuine user-authority surfaces per the 6-class taxonomy). Two refactors and two cosmetic cross-references shipped.

  **Surface 1 — Step 2 duplicate-check REFACTOR (closes ADR-013 Confirmation #1 regression).** The prior prompt body at line 134 contained `"Would you like to (a) update an existing incident, (b) declare a new incident anyway, or (c) cancel?"` — both the `would you like` phrasing and the `(a)/(b)/(c)` parenthetical match the regex in ADR-013 Confirmation criterion #1 (`grep -inE "Options:.*\(a\)\|Your call:\|which would you like\|which way?"` — must return zero matches outside test fixtures). The refactor lifts the 3 options into the `AskUserQuestion` `options[]` mechanism (with `header: "Active incidents found"`) and rewrites the prompt body as plain prose ("Choose how to proceed:"). Behavioural change: none — same 3 options, same outcome paths. Compliance fix.

  **Surface 2 — Step 4 gather-info KEEP + cosmetic ADR-044 cat-1 cross-ref.** Title / Symptoms / Scope / Start time / Severity are user-knowledge inputs that the framework cannot infer; this is canonical category-1 (direction-setting). No behavioural change.

  **Surface 3 — Step 6 evidence-first gate REFACTOR (cross-skill consistency with mitigate-incident).** The prior prose at line 208 was an open backfill prompt: `"ask via AskUserQuestion what evidence supports it"`. The refactor aligns with `/wr-itil:mitigate-incident` Step 3's 3-option pattern (Add evidence / Record anyway with audit-trail bypass / Cancel) and includes the documented `[<timestamp> UTC] Evidence-gate bypassed by user — reason: <justification>` audit-trail prose so post-incident review can grep every bypassed gate. Behavioural change: ADDS an explicit documented bypass option that previously had no documented escape hatch (the implicit bypass existed — a user could type "no evidence" and the skill would comply — but it was un-audited). The refactor converts implicit-soft-gate to explicit-hard-gate-with-audit-trail. Annotated as ADR-044 **category-2 (deviation-approval)** surface.

  **Surface 4 — Step 14 risk-above-appetite KEEP + cosmetic ADR-044 cat-3 cross-ref.** Annotated as the **category-3 (one-time-override)** surface for cross-skill consistency with mitigate-incident Step 8.

  **Cascading prose updates**: NEW Related section added (manage-incident previously had no Related section); enumerates P136, ADR-044, ADR-013 amended Rule 1, ADR-013 Confirmation criterion #1, ADR-011, ADR-014/015/018/020/026/042, P071, P081, JTBD-001/101/201.

  **Bats coverage** (P136 Phase 2 / per inline plan R5-equivalent):

  - `packages/itil/skills/manage-incident/test/manage-incident-adr-044-contract.bats` (NEW companion file) — 11 contract assertions covering: Step 2 negative regression guards (`would you like`, `(a)/(b)/(c)`); Step 2 ADR-044 cat-1 cross-ref; Step 2 retains 3-option choices (positive guard); Step 4 ADR-044 cat-1 cross-ref; Step 6 3-option pattern (Add / Record-anyway / Cancel); Step 6 ADR-044 cat-2 cross-ref; Step 6 bypass-marker prose; Step 14 ADR-044 cat-3 cross-ref; bats marker present; SKILL.md cites P136 + ADR-044.
  - The companion file carries the `tdd-review: structural-permitted` marker per P081 + P136 bridge. The sibling functional file `manage-incident.bats` deliberately avoids structural-grep on SKILL.md prose (P011 ban); the new companion is the dedicated structural-grep-permitted home for the ADR-044 alignment contract during the bridge window.
  - All 11 new + 14 existing manage-incident assertions green; full itil package suite still green.

  **Architect + JTBD review verdict**: PASS. Architect explicitly noted the Surface 1 refactor **closes an existing ADR-013 Confirmation criterion #1 violation** at line 134 (line numbers verified). JTBD reviewer addressed the Surface 3 trade-off favorably: making the bypass explicit _strengthens_ JTBD-201's "auditability of AI-assisted incident work" outcome by converting an implicit, undocumented evidence-gate bypass into an explicit, audit-trailed bypass option; the cool-headed-commitment is preserved because `Add evidence` remains the friction-free default and bypass requires conscious second choice. JTBD-101 (extend the suite) advanced — adopters now get one consistent evidence-gate pattern across both incident skills.

  **P136 audit-log update**: `docs/problems/136-adr-044-alignment-audit-master.open.md` Investigation Tasks checklist marks Phase 2 manage-incident complete. **Phase 2 is now 3/3 done** — all high-ask SKILLs audited. Phase 3 (medium/low-ask SKILLs, ~26 surfaces) is the next phase, deferred to a future session per per-skill release cadence (R1).

  Refs: P136 (master), ADR-044 (anchor), ADR-011 (incident lifecycle + evidence-first), ADR-013 amended Rule 1, ADR-013 Confirmation criterion #1 (regression closed), ADR-010, ADR-014, ADR-015, ADR-018, ADR-020, ADR-026, ADR-042, P057, P071, P081, P135, JTBD-001 / JTBD-101 / JTBD-201.

## 0.21.5

### Patch Changes

- 2b6ce32: P136 Phase 2 (ADR-044 alignment audit — mitigate-incident SKILL.md) per the inline plan on `docs/problems/136-adr-044-alignment-audit-master.open.md`.

  Second per-skill amendment in the suite-wide audit (after `work-problem` singular at `@windyroad/itil@0.21.4`). Removes the lazy-deferral argument-backfill `AskUserQuestion` from Step 1 / Arguments section and adds inline ADR-044 cross-references on the two retained user-authority surfaces (evidence-first gate; risk-above-appetite commit).

  **Surface 1 — argument backfill becomes fail-fast (AMEND).** Replaces the `ask via AskUserQuestion` instructions at lines 20 / 50 / 52 with a fail-fast usage message + exit. Argument malformation is a typo-class signal, not a decision; the slash command IS the input contract. Re-typing in 1 second beats a multi-turn `AskUserQuestion` dialogue, and the suite now has consistent argument-backfill semantics across `transition-problem` Step 1, `work-problem` singular, and `mitigate-incident` Step 1. The new Step 1 emits an explicit `Usage:` block (incident ID format + action shape + `/wr-itil:list-incidents` pointer for ID discovery) so adopters and first-time users get a discoverable contract.

  **Surface 2 — evidence-first gate (KEEP + cross-ref).** ADR-011's evidence-first rule IS the existing decision; "Record anyway" IS the user-approved deviation; user IS the right authority. Annotated as the ADR-044 **category-2 (deviation-approval)** surface. The 3-option vocabulary (Add evidence / Record anyway / Cancel) and the `## Audit trail` note appended on bypass are both unchanged. The cross-reference makes the framework-resolution boundary visible at the call site (Step 3 + the Evidence-first gate header).

  **Surface 3 — risk-above-appetite commit (KEEP + cross-ref).** In incident-mitigation context, the tech lead may need to ship a mitigation despite higher residual risk to restore service fast (JTBD-201). The rule (RISK-POLICY appetite) still stands; this specific case is a strategic exception. Annotated as the ADR-044 **category-3 (one-time-override)** surface. The 3-option vocabulary (commit anyway / remediate / park) is unchanged; the ADR-013 Rule 6 fail-safe (skip + report when `AskUserQuestion` is unavailable) is preserved.

  **Bats coverage** (P136 Phase 2 / per inline plan R5-equivalent):

  - `packages/itil/skills/mitigate-incident/test/mitigate-incident-contract.bats` (UPDATED) — 7 new contract assertions: Step 1 fail-fast usage block; Step 1 negative regression guard against `AskUserQuestion` re-entry for argument backfill; Arguments section negative regression guard; Step 3 ADR-044 category-2 cross-reference; Step 8 ADR-044 category-3 cross-reference; positive guard that `AskUserQuestion` is RETAINED for Surfaces 2 + 3 (frontmatter `allowed-tools` + Step 3 prose + Step 8 prose); `tdd-review: structural-permitted` marker present per P081 + P136 bridge. All 20 assertions green; all 534 itil package skill tests still green.
  - File carries the `tdd-review: structural-permitted` marker per the P136 Phase 2 inline plan's bridge-marker rule (P081 Phase 2 owns the canonical retrofit).

  **Architect + JTBD review verdict**: PASS. Architect cited the `transition-problem` Step 1 precedent line-for-line as the matching shape for Surface 1; no conflicts with ADR-011, ADR-013 amended, ADR-014, ADR-015, ADR-018, ADR-020, ADR-026, ADR-042, ADR-044, P057, P062, P071. JTBD-201 (restore service fast with audit trail) advanced — fail-fast preserves "restore fast" by avoiding multi-turn dialogue during high-adrenaline incident response; evidence-first audit-trail outcome unchanged. JTBD-001 (governance without slowing down) advanced — consent-gate-for-the-obvious removed from Surface 1; legitimate consent gates retained on Surfaces 2 + 3. JTBD-101 (extend the suite) cleaner adopter contract — argument backfill is now consistent across `transition-problem` / `work-problem` / `mitigate-incident`. JTBD-006 (AFK backlog) neutral — incident skills are interactive by definition; no AFK-loop regression.

  **P136 audit-log update**: `docs/problems/136-adr-044-alignment-audit-master.open.md` Investigation Tasks checklist marks Phase 2 mitigate-incident complete (2 of 3 high-ask SKILLs done; manage-incident next).

  Refs: P136 (master), ADR-044 (anchor), ADR-011 (incident lifecycle), ADR-013 amended Rule 1, ADR-010, ADR-014, ADR-015, ADR-018, ADR-020, ADR-026, ADR-037, P057, P071, P081, P135, JTBD-001 / JTBD-006 / JTBD-101 / JTBD-201.

## 0.21.4

### Patch Changes

- c5879a2: P136 Phase 2 (ADR-044 alignment audit — work-problem singular SKILL.md) per the inline plan on `docs/problems/136-adr-044-alignment-audit-master.open.md`.

  First per-skill amendment in the suite-wide audit. Removes the lazy-deferral `AskUserQuestion` from Step 2 ticket selection and converges the interactive and AFK paths to a single framework-mediated tie-break ladder per ADR-044's Framework-Mediated Surface (Prioritisation row).

  **Step 2 — selection becomes framework-mediated.** The agent applies the WSJF formula + 5-rung tie-break ladder (1: WSJF score descending; 2: Known Error before Open; 3: smaller effort first; 4: older reported date wins; 5: ticket number ascending) and reports the chosen ticket + the rung that decided. No `AskUserQuestion` fires for selection. The ladder mirrors the logic the plural orchestrator (`/wr-itil:work-problems`) Step 3 already uses, removing the prior interactive-vs-AFK asymmetry that was the lazy-deferral surface ADR-044 was written to close. User-override path documented explicitly: `/wr-itil:work-problem <NNN>` skips the ladder; mid-flow correction (ADR-044 category 6 / P078) is the long-tail catcher.

  **Step 4 — scope-expansion gets explicit ADR-044 cross-reference.** No behavioural change. The 3-option scope-change `AskUserQuestion` (Continue / Re-rank / Pick different) is now annotated as the work-item-tactical analog of ADR-044's framework-tactical 5-option deviation-approval vocabulary (Approve+amend / Approve+supersede / Approve+one-time / Reject / Defer). Effort growth IS the contradicting evidence against the WSJF score that ranked the ticket; the user IS the right authority for the shape — the `AskUserQuestion` here is genuine, not lazy.

  **Cascading prose updates** (per architect advisory): frontmatter `description` reframed from "Interactive singular variant" to "framework-mediated selection (WSJF + tie-break ladder per ADR-044); singular variant"; overview, Scope bullet list, Ownership Boundary, and Related sections updated for ADR-044 citation discipline. ADR-013 amended Rule 1 reference now scoped to Step 4 only (the retained `AskUserQuestion` surface).

  **Bats coverage** (P136 Phase 2 / per inline plan R5-equivalent):

  - `packages/itil/skills/work-problem/test/work-problem-contract.bats` (UPDATED) — 6 new assertions covering: framework-mediated selection prose; tie-break-rung-citation report shape (JTBD-201 audit-trail); user-override-path-via-direct-NNN-invocation literal-form (with substring-trap guard against `/wr-itil:work-problems` plural); negative regression guard against `AskUserQuestion`-driven selection re-emerging in Step 2; ADR-044 category-2 cross-reference in Step 4; `tdd-review: structural-permitted` marker present (P081 + P136 bridge). All 25 assertions green; all 534 itil package skill tests still green.
  - File carries the `tdd-review: structural-permitted` marker per the P136 Phase 2 inline plan's bridge-marker rule (P081 Phase 2 owns the canonical retrofit).

  **Architect + JTBD review verdict**: PASS. No conflicts with existing decisions (ADR-013 amended, ADR-010 amended Skill Granularity, ADR-014, ADR-022, ADR-026, ADR-032, ADR-040, ADR-042, P031, P062, P077). JTBD-001 (enforce governance without slowing down) advanced — one consent gate per session removed; deterministic ladder IS the governance enforcement. JTBD-006 (AFK backlog) simplified — singular and plural now share one selection algorithm. JTBD-101 (extend the suite) cleaner — adopters inherit one path instead of two. JTBD-201 (audit trail) preserved/improved — agent's "I picked P\<NNN\> using rung X" report is reproducible from README state.

  **P136 audit-log update**: `docs/problems/136-adr-044-alignment-audit-master.open.md` Investigation Tasks checklist marks Phase 2 work-problem singular complete (1 of 3 high-ask SKILLs done; mitigate-incident next).

  Refs: P136 (master), ADR-044 (anchor), ADR-013 amended Rule 1, ADR-010 amended Skill Granularity, ADR-014 (commit grain), ADR-026 (grounding for tie-break-rung citations), ADR-032 + P077 (work-problems plural delegation), ADR-037 (contract-assertion bats pattern), P031 (cache-freshness check), P062 (review-problems canonical README writer), P081 (structural-grep retrofit; bridge marker), JTBD-001 / JTBD-006 / JTBD-101 / JTBD-201.

## 0.21.3

### Patch Changes

- 328f92a: P135 Phase 3 (AFK loop redesign — `@windyroad/itil`) per ADR-044 (Decision-Delegation Contract).

  Redesigns the `/wr-itil:work-problems` AFK loop to be the empirical-discovery engine ADR-044 describes. Direction-class observations + deviation candidates accumulate from real friction across iters; loop-end Step 2.5 presents the batched questions as the primary deliverable.

  **ITERATION_SUMMARY.outstanding_questions schema** (Phase 3 + R7):

  - Field is now mandatory non-empty when iter touched a direction / deviation-approval / one-time-override / silent-framework decision; otherwise empty array.
  - Each entry tagged with category for Step 2.5 ranking.
  - New **deviation-candidate entry shape**: when iter encounters an existing decision (ADR / SKILL / WSJF / RISK-POLICY) that current evidence contradicts, agent queues a candidate with `existing_decision` citation + `contradicting_evidence` citation per ADR-026 grounding + `proposed_shape ∈ {amend, supersede, one-time}` + `rationale`. Agent does NOT auto-deviate; never blindly follows against evidence. Not-queueing-when-strong-contradicting-evidence-exists is a regression per the bats coverage.

  **Step 2.5 (loop-end emit)** — promoted from "fallback when stop-condition #2" to **default loop-end emit shape**. Reads `.afk-run-state/outstanding-questions.jsonl`, de-duplicates, ranks (deviation-approval > direction > one-time-override > silent-framework > taste > correction-followup), presents as batched `AskUserQuestion` per ADR-013 Rule 1 cap. Deviation-candidate entries get the 5-option `AskUserQuestion` (Approve+amend / Approve+supersede / Approve+one-time / Reject / Defer); other entries get options extracted from the entry's `question` text.

  **Between-iter aggregation**: orchestrator's main turn appends each iter's `outstanding_questions` entries to the session-level queue file at `.afk-run-state/outstanding-questions.jsonl` between Step 6 (report) and Step 6.5 (release-cadence check). Queue cleared after Step 2.5 resolves all entries. Per ADR-032 pending-questions artefact precedent.

  **Mid-loop UserPromptSubmit handler** (R4) — when orchestrator receives user message during an iter, the in-flight iter MUST complete naturally to its `ITERATION_SUMMARY` emission BEFORE the orchestrator surfaces the queue + new direction. **Do NOT abort the iter mid-flight** (no SIGTERM to iter PID). Direct corrective for the 2026-04-27 iter-9-killed overcorrection — the user's correction was about future iter dispatch shape, not the in-flight iter; killing wasted ~$5 + 25 min in-flight work.

  **Bats coverage** (Phase 3 R4 + R7):

  - `packages/itil/skills/work-problems/test/work-problems-mid-loop-userpromptsubmit-handler.bats` (NEW per R4) — 7 assertions covering handler clause documentation, complete-naturally-to-ITERATION_SUMMARY contract, no-SIGTERM forbiddance, no-abort-mid-flight forbiddance, iter-9 precedent citation, queue-after-iter contract, $5+25min cost grounding.
  - `packages/itil/skills/work-problems/test/work-problems-deviation-candidate-shape.bats` (NEW per R7) — 12 assertions covering schema documentation (existing_decision / contradicting_evidence / proposed_shape fields), no-auto-deviate contract, never-blindly-follow assertion, regression assertion (not-queueing-is-a-regression), 5-option loop-end emit, deviation-approval-highest ranking, jsonl persistence, ADR-032 precedent citation, anti-BUFD-for-framework-evolution rationale citation.

  19/19 new bats green.

  **Per-phase release cadence (R1) + preview-tag rollout (R2)**: Phase 3 ships `@windyroad/itil` patch via npm `preview` tag first (changesets dist-tag); exercise end-to-end against a real `/wr-itil:work-problems` AFK session verifying no-mid-loop-AskUserQuestion + outstanding-questions jsonl + mid-loop UserPromptSubmit handler all behave per spec; only after end-to-end verification, promote `preview` → `latest` via `npm dist-tag` promotion. If verification fails on `preview`, fix-and-republish without affecting `latest` consumers.

  Refs: P135 (master), ADR-044 (anchor), ADR-014 (commit grain), ADR-026 (grounding), ADR-032 (pending-questions artefact precedent), ADR-013 Rule 1 narrowing precedent, P124 (verifying-flip-back precedent for deviation-approval reversibility), P122 / P126 (Step 2.5b surfacing routine precedent).

## 0.21.2

### Patch Changes

- fae42aa: P135 Phase 2 (Skill amendments — `@windyroad/itil` half) per ADR-044 (Decision-Delegation Contract).

  Removes per-action `AskUserQuestion` calls in `work-problems`, `manage-problem`, and `transition-problem` where the framework has already resolved the decision (lazy deferral per Step 2d Ask Hygiene Pass classification). Replaces with silent agent-action + summary surfacing. User correction via the P078 capture-on-correction surface (authentic-correction per ADR-044 category 6).

  **`work-problems` Step 5 dispatch (iter prompt body)**: added explicit constraint clause: _"NEVER call `AskUserQuestion` mid-loop in AFK"_. Direction / deviation-approval / one-time-override / silent-framework observations queue at `ITERATION_SUMMARY.outstanding_questions` for loop-end batched presentation per the existing Step 2.5b surfacing routine. Per-iter `AskUserQuestion` calls are sub-contracting framework-resolved decisions back to the user.

  **`manage-problem` Step 9d verification close**: replaced per-`.verifying.md` `AskUserQuestion` with close-on-evidence: agent collects in-session evidence per ADR-026 grounding; when concrete and unambiguous, delegates to `/wr-itil:transition-problem <NNN> close` (per ADR-014 commit grain) WITHOUT firing `AskUserQuestion`. Ambiguous-evidence path preserved (left as Verification Pending). Closes are reversible (`/wr-itil:transition-problem <NNN> known-error` flip-back); recovery path documented inline.

  **`transition-problem` Step 5 P063 external-root-cause detection**: replaced the 3-option `AskUserQuestion` (invoke-now / defer-and-note / not-actually-upstream) with the silent default behaviour (defer-and-note marker). The marker wording is fixed; recovery is user-initiated (false-positive marker append OR direct `/wr-itil:report-upstream` invocation). AFK and interactive modes use identical behaviour.

  **Bats coverage** (Phase 2 R5):

  - `packages/itil/skills/manage-problem/test/manage-problem-step-9d-recovery-path.bats` (NEW per R5) — 10 assertions covering close-on-evidence dispatch, ADR-044 / ADR-026 / ADR-022 citations, reversibility affirmation, recovery skill invocation naming, P124 precedent citation, ambiguous-evidence preservation, authentic-correction routing, output-table-with-citation contract.

  Refs: P135 (master), ADR-044 (anchor), ADR-014 (commit grain), ADR-022 (lifecycle), ADR-026 (grounding), ADR-013 Rule 1 narrowing precedent, P063 (external-root-cause detection), P078 (authentic-correction surface), P124 (verifying-flip-back precedent), P132 (inverse-P078 enforcement).

## 0.21.1

### Patch Changes

- 6c46694: work-problems: extracted Step 2.5's surfacing routine into a reusable `Step 2.5b — Surface accumulated user-answerable skips` sub-step that every halt path cross-references before emitting its final AFK summary (P126).

  P122 fixed the routing at Step 2.5 stop-condition #2 — when ≥1 user-answerable skip is accumulated, default to `AskUserQuestion`-when-available, fall back to the Outstanding Design Questions table only when the structured-question primitive is unavailable per ADR-013 Rule 6. P126 extends the same contract to the remaining halt paths: Step 0 session-continuity halt, Step 0 fetch-failure halt, Step 6.5 Failure handling (CI / publish failure), Step 6.5 ADR-042 Rule 5 above-appetite halt, Step 6.75 dirty-for-unknown-reason halt. Each halt path now names a one-paragraph cross-reference pointing at Step 2.5b, gated on `≥1 accumulated user-answerable skip`. Step 2.5 itself now delegates to Step 2.5b — single source of truth for the surfacing logic.

  The Rule 5 cross-reference carries an architect-FLAG guard: Step 2.5b surfaces _prior-iter accumulated user-answerable skips only_ — it does NOT ask the user how to remediate the above-appetite state itself. The halt-causing scorer-gap remains a halt with bug-signal per ADR-042 Rule 5 invariant ("never release above appetite"; the scorer is the decision surface, not the user). The same `prior-iter only` framing is documented for the Failure-handling halt (CI failure remains user-investigation-on-return) and the Step 6.75 dirty-unknown halt (dirty-state recovery remains a Rule 6 user-input requirement on return).

  The Decisions Table at the bottom of `SKILL.md` gains a `Halt-path final summary with accumulated user-answerable skips` row naming the cross-halt routing. The `Unexpected dirty state between iterations` row is amended to mention the Step 2.5b call before the halt summary.

  `docs/briefing/afk-subprocess.md` adds a `halt-paths-must-route-design-questions-through-Step-2.5b` entry alongside the existing P122 entry, traceable across the principle's evolution.

  15 behavioural contract assertions in `packages/itil/skills/work-problems/test/work-problems-step-2-5b-cross-halt-routing.bats` pin the contract per ADR-037 + P081 — Step 2.5b heading present, gating clause named, AskUserQuestion default branch preserved, Rule 6 table fallback preserved, each halt path cross-referenced (5 paths × 1 each = 5 assertions), Rule 5 guard prose present, Decisions Table row present, briefing entry cross-references P122. Full work-problems suite 136/136 green.

  JTBD-001 (Enforce Governance Without Slowing Down) primary — extends interactive-question routing to every halt path that accumulates skipped user-answerable design questions. JTBD-006 (Progress the Backlog While I'm Away) — the AFK return ritual is enhanced not disrupted; empty-skip halts skip the routine via the gating clause, so users who hit Step 0 fetch-failure with no iters run see no question prompt. The cross-skill principle paragraph in Step 2.5b generalises to any future AFK orchestrator that hits the same surface — defer the AFK persona to the subprocess boundary, not to the orchestrator's question-surfacing branch.

  No new ADR — extension of P122's already-documented routing principle under ADR-013 Rule 1 / Rule 6 + ADR-032 subprocess-boundary contract.

## 0.21.0

### Minor Changes

- 8653541: P065: scaffold downstream OSS intake — new `/wr-itil:scaffold-intake` skill + pre-publish PreToolUse gate

  The `@windyroad/itil` plugin now ships a foreground-synchronous skill that scaffolds the five OSS intake files every project in the ecosystem needs to receive structured problem reports and route security disclosure properly:

  - `.github/ISSUE_TEMPLATE/config.yml`
  - `.github/ISSUE_TEMPLATE/problem-report.yml` (P066-corrected problem-first shape)
  - `SECURITY.md`
  - `SUPPORT.md`
  - `CONTRIBUTING.md`

  Templates live at `packages/itil/skills/scaffold-intake/templates/*.tmpl` and use mustache-style substitution (`{{project_name}}`, `{{project_url}}`, `{{plugin_list}}`, `{{security_contact}}`, `{{year}}`) with no runtime dependency. The skill is idempotent: present files are skipped unless `--force`; full re-application produces no diff. Re-invocation reports diffs for outdated-present files.

  **Trigger surfaces (layered)** per ADR-036:

  1. **First-run prompt** — wired into `manage-problem` and `work-problems` SKILL.md preambles. Foreground branch fires `AskUserQuestion` with three options (scaffold now / not now / decline). AFK branch (per ADR-013 Rule 6 + JTBD-006) appends a one-line "pending intake scaffold" note to the iteration's `ITERATION_SUMMARY` and never auto-scaffolds. Markers `.claude/.intake-scaffold-{done,declined}` follow ADR-009 persistent-marker semantics.
  2. **Pre-publish PreToolUse gate** — new hook `pre-publish-intake-gate.sh` denies `npm publish` and `gh pr merge ... changeset-release/*` when intake files are missing AND no decline marker AND `INTAKE_BYPASS=1` is not set. Override path: `INTAKE_BYPASS=1 npm publish`.
  3. **CI check** — deferred to v2 via `--ci` flag (emits `.github/workflows/intake-check.yml`).

  `packages/itil/hooks/hooks.json` registers the new PreToolUse:Bash hook. Skill is auto-discovered from the directory; no manifest change required.

  Cross-reference paragraph added to `packages/itil/skills/report-upstream/SKILL.md` documenting the reciprocal-pair shape (report-upstream files at upstream intake; scaffold-intake creates downstream intake).

  39 new behavioural bats tests:

  - `packages/itil/hooks/test/pre-publish-intake-gate.bats` (10 tests — allow + deny matrix across surfaces, markers, and bypass).
  - `packages/itil/skills/scaffold-intake/test/scaffold-intake-contract.bats` (15 tests — SKILL.md structural invariants per ADR-037).
  - `packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats` (7 tests — empty repo, idempotent re-run, partial repo with pre-existing CONTRIBUTING.md).
  - `packages/itil/skills/scaffold-intake/test/scaffold-intake-secrets-absent.bats` (7 tests — no /Users, /home, Windows paths, credential shapes, hardcoded author-repo references).
  - `packages/itil/skills/manage-problem/test/manage-problem-first-run-intake-prompt.bats` (4 tests — wiring point fixed).
  - `packages/itil/skills/work-problems/test/work-problems-first-run-intake-prompt.bats` (4 tests — wiring point fixed).

  Closes P065 → Verification Pending. ADR-036 stays `proposed` (no status change required at implementation time).

### Patch Changes

- 482b54a: P127: scaffold-intake idempotency bats fixture — snapshot dir now lives outside `$TEST_DIR` to fix Linux CI failure

  The `fixture: full re-application is idempotent (no diff)` test in `packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats` was failing on Linux CI but passing on macOS local — a test-harness portability bug, not a production-skill bug. Root cause: `cp -R . "$TEST_DIR/.snapshot-1"` ran with `$PWD == $TEST_DIR`, so the destination was a child of the source. GNU `cp` (Linux / Ubuntu CI) refuses this case with `cp: cannot copy a directory, '.', into itself, ...`; BSD `cp` on macOS APFS silently allows it. The non-zero exit aborted the test on Linux only.

  Fix: take the snapshot into a sibling `mktemp -d` directory outside `$TEST_DIR`, eliminating the source-into-itself recursion. No production SKILL.md or template changes — `scaffold_all` was already deterministic. The idempotency assertion shape is unchanged: still `cp` first state → re-run `scaffold_all` → `diff -ru` against snapshot.

  Verification: 29/29 scaffold-intake bats pass on both Linux (`bats/bats:latest` Alpine container) and macOS local. Restores CI green-on-main for `@windyroad/itil` (CI was red on every commit since `8653541`).

  Closes P127 → Verification Pending pending CI confirmation.

## 0.20.0

### Minor Changes

- 17b594b: P117: new plural sibling skill `/wr-itil:transition-problems` for batch lifecycle transitions

  `@windyroad/itil` gains a plural sibling to `/wr-itil:transition-problem` that batch-advances multiple tickets through the lifecycle in one invocation, mirroring the P071 singular/plural split precedent (`work-problem` vs `work-problems`).

  - New skill `packages/itil/skills/transition-problems/SKILL.md` — accepts a space-separated list of `<NNN> <status>` pairs (e.g. `/wr-itil:transition-problems 063 close 067 close 092 close 094 close`). Loops the singular's per-ticket mechanic inline (pre-flight checks, P063 external-root-cause detection per pair, `git mv` + Edit + P057 re-stage per pair). Refreshes `docs/problems/README.md` ONCE at the end (P062 at batch grain — single render reflecting all surviving renames). Commits ALL surviving transitions in ONE commit per ADR-014 batch-grain unit-of-work.
  - Partial-failure semantics: skip-and-surface — failed pairs (discovery / invalid-transition / pre-flight / git-op) are recorded and continue to the next pair; succeeded pairs commit at the end. Zero-success means no commit + failure summary. Aligned with ADR-014 "complete unit of work" applied at the batch grain and ADR-013 Rule 6's no-non-interactive-destructive-rollback rule.
  - Inline per-ticket mechanic per ADR-010 amended "Split-skill execution ownership" — "copy, not move". The plural carries an inline scoped copy of the singular's Steps 2–6; per-pair commit (singular Step 8) is replaced by the single batch commit at the end. Three call sites now share the per-ticket mechanic via copy-not-move: singular `transition-problem`, plural `transition-problems` (this skill), and `manage-problem` in-skill Step 7.
  - Behavioural contract bats `packages/itil/skills/transition-problems/test/transition-problems-contract.bats` — 20 assertions covering frontmatter shape, allowed-tools, citations (P117, ADR-010 amended, P057, P062, P063, ADR-022, ADR-013 Rule 6, ADR-037), inline-mechanic positive assertions (`pre-flight`, `git mv`, `git add`, `Fix Released`), no-Skill-tool-delegation negative assertion, single-commit-at-end semantics (positive + no-per-pair-commit negative), single-README-refresh-at-end, partial-failure skip-and-surface, argument shape (no `P` prefix, no `=`/`:` separator, no flag-style), no `deprecated-arguments` frontmatter (clean-split sibling), and a cross-file drift-detection assertion that the staging-trap `git add docs/problems/` phrase appears in BOTH this skill's SKILL.md and the singular's SKILL.md so the inline-copy invariant fails fast on drift.

  Closes P117 → Verification Pending. Eliminates the N×SKILL.md reload tax + ownership-boundary violation that batch callers (run-retro Step 4a, manage-problem Step 9d, work-problems release-batched closures) currently face.

## 0.19.7

### Patch Changes

- ef4c9e9: manage-problem: Step 2 substep 7 now sources the new agent-side session-ID discovery helper (`packages/itil/hooks/lib/session-id.sh`) instead of the brittle `${CLAUDE_SESSION_ID:-default}` fallback that wrote the create-gate marker under the wrong UUID and triggered a Write deny on every first ticket of a session (P124).

  `get_current_session_id` returns the canonical session UUID by reading `CLAUDE_SESSION_ID` if exported, else by scraping the most-reliable per-session announce marker (`/tmp/<system>-announced-<UUID>`, set on prompt 1 of every session per ADR-038 by architect / jtbd / tdd / style-guide / voice-tone / itil-assistant-gate / itil-correction-detect). It exits non-zero when no session can be discovered so callers can `&&`-chain the marker write and never land an empty-UUID `/tmp/manage-problem-grep-` file the hook will never match.

  Selection order is fixed (architect first, then jtbd / tdd / itil-assistant-gate / itil-correction-detect / style-guide / voice-tone) so discovery is deterministic and reproducible across invocations. Announce markers are write-once-per-session per ADR-038 — no mtime sliding (unlike `-reviewed-` gate markers which `touch`-refresh on every gate check per ADR-009 + P111), so the helper sidesteps the multi-session `/tmp` mtime-fragility flagged in architect review.

  The skill now calls the existing `mark_step2_complete` helper from `create-gate.sh` for the marker write itself — single source of truth for the marker-path convention.

  6 behavioural bats assertions in `packages/itil/hooks/test/session-id.bats` pin the contract per ADR-037 + P081 (env-var fast path, env-var ignores markers, architect-marker scrape, jtbd-marker fallback, no-markers empty+non-zero exit, deterministic priority order). Helper is itil-local for now (only manage-problem needs agent-side SID discovery today); promote to `packages/shared/` per ADR-017 if a second skill adopts the pattern.

  ADR-038 Related cross-references the new helper as the agent-side READ companion to its hook-side WRITE helpers.

- 3f6e021: P057 staging-trap recurrence is now denied at commit time by a new `PreToolUse:Bash` hook (`packages/itil/hooks/p057-staging-trap-detect.sh`) that fires on `git commit` invocations and surfaces the recovery command inline. Documentation alone did not prevent recurrence — P125 evidence: P122 batch shipped commit `e7564ff` with rename-only after multiple retros had cited the rule. The hook removes reliance on agent attention.

  Detection delegates to a new shared helper `packages/itil/hooks/lib/staging-detect.sh::detect_p057_trap`. The helper runs `git diff --staged --name-status` and `git diff --name-only`; if any staged rename's `<new>` path also appears in the working-tree modification list, the trap is present. The helper echoes the trap'd path on stdout and emits a one-line recovery hint on stderr, returning 1 (deny) or 0 (allow / fail-open). Cost is bounded — two `git diff` invocations per commit invocation (~10-50ms on this repo's working tree).

  Fail-open contract mirrors `lib/create-gate.sh`: outside a git working tree, on parse-incomplete input, or when `git diff` errors for any reason, the helper returns 0 — a hook that fails-closed on hostile environments would block legitimate commits in non-git contexts. ADR-013 Rule 1's "deny redirects to recovery" contract is satisfied via the mechanical-recovery shape — re-staging a file is a single command, no skill round-trip required.

  10 behavioural bats assertions per ADR-005 + P081 (`packages/itil/hooks/test/p057-staging-trap-detect.bats`) pin the contract: trap detected → deny with file + recovery + P057 cite; trap recovered via re-stage → allow; pure rename → allow; modify-only batch → allow; empty batch → allow; non-Bash tool → allow; non-commit Bash command → allow; empty JSON (parse-incomplete) → allow (fail-open); deny message names file + `git add <FILE>` + P057 cite; deny message stays under ADR-038 progressive-disclosure budget (<400 bytes; observed ~348 bytes).

  Hook registered in `packages/itil/hooks/hooks.json` under `PreToolUse` with `matcher: "Bash"`. `docs/briefing/agent-interaction-patterns.md` line 8 cites the new hook as the enforcement layer the documentation alone didn't provide. JTBD-001 (Enforce Governance Without Slowing Down) primary fit. JTBD-006 (Progress the Backlog While I'm Away) composes — AFK iter loops are the highest-frequency offenders.

## 0.19.6

### Patch Changes

- 8f21b87: work-problems: Step 2.5 stop-condition #2 routing now defaults to AskUserQuestion when available; Outstanding Design Questions table is the AskUserQuestion-unavailable fallback (P122).

  The legacy prose ("JTBD-006's persona constraint makes the non-interactive path the default for this skill — AskUserQuestion is the exception, not the rule") conflated persona with runtime mode and caused the orchestrator's main turn to suppress AskUserQuestion in interactive sessions. The orchestrator IS always main turn (interactive by construction); JTBD-006's AFK persona is served by the iteration subprocess workers under the ADR-032 subprocess-boundary contract — they never reach stop-condition #2.

  Cross-skill principle (architect FLAG): orchestrator main turns default to AskUserQuestion when available; AFK persona is served by the subprocess-boundary contract under ADR-032, not by suppressing AskUserQuestion at the orchestrator layer.

  Step 6.5 Decisions Table row for "Stop-condition #2 with user-answerable skip-reasons" updated to match the flipped default. New `work-problems-step-2-5-routing.bats` (8 doc-lint contract assertions per ADR-037) pins the new contract. Full project bats green.

  P103 anti-pattern boundary preserved: AskUserQuestion still scoped to `user-answerable` skip-reasons only; `architect-design` and `upstream-blocked` continue to skip without asking.

## 0.19.5

### Patch Changes

- 65b9019: `/wr-itil:work-problems` Step 5 backgrounds the iteration subprocess and runs a 60s poll loop with an idle-timeout SIGTERM branch. When `now - LAST_ACTIVITY_MARK > WORK_PROBLEMS_IDLE_TIMEOUT_S` (default 3600s = 60 min), the orchestrator sends SIGTERM to the stuck `claude -p` PID. SIGTERM empirically produces a clean JSON exit-flush — the subprocess responds with a valid `is_error: false` envelope and parseable `ITERATION_SUMMARY` block within seconds. Override the threshold per-environment via the `WORK_PROBLEMS_IDLE_TIMEOUT_S` env var. Closes P121. ADR-032 amended with the backgrounded-poll-loop refinement under the subprocess-boundary variant; new behavioural fixture in `test/work-problems-step-5-idle-timeout-sigterm.bats` provides the second-source for the production observation that motivated the fix.

## 0.19.4

### Patch Changes

- 9c50d03: `docs/problems/README.md` now self-heals from cross-session drift (P118).

  A new diagnose-only script `packages/itil/scripts/reconcile-readme.sh` checks
  the README's WSJF Rankings, Verification Queue, and Closed sections against
  the on-disk ticket files (`docs/problems/<NNN>-*.<status>.md`). Exit codes:
  0 = clean, 1 = drift detected (one structured row per drift entry to stdout,
  ≤150 bytes per ADR-038 progressive-disclosure budget), 2 = parse error.

  A new skill `/wr-itil:reconcile-readme` wraps the script with an agent-applied-
  edits pattern that preserves the README's narrative content (the "Last reviewed"
  prose paragraph at the top and the per-row closure-via free text in the Closed
  section). Full README regeneration is forbidden — narrative content is human-
  curated session memory.

  Two preflight invocation surfaces fire the script before doing anything else:

  - `/wr-itil:manage-problem` Step 0 — halt-with-directive on drift before parsing
    the request, so ticket creation / update / transition never proceeds against
    a stale README that would re-encode the lie into the post-operation refresh.
  - `/wr-itil:work-problems` Step 0 — auto-apply via `/wr-itil:reconcile-readme`
    in AFK mode (per ADR-013 Rule 6) so the orchestrator's Step 3 ranking reads
    ground truth.

  `/wr-itil:transition-problem` deliberately does NOT invoke the script — P062's
  existing transition-time refresh inside the same commit already covers that
  surface; redundant preflight there would pay the cost on every transition.

  This is a robustness layer ON TOP of P094 (refresh-on-create, Closed) and P062
  (refresh-on-transition, Closed) — both per-operation contracts remain in force.
  The reconciliation contract catches drift introduced by past sessions where the
  single-commit-transaction discipline was skipped (bug, partial-progress hand-
  off, conflict resolution, etc.) and that no per-operation contract can
  retroactively detect or correct.

  ADR-014 amended with a "Reconciliation as preflight robustness layer" sub-rule
  (P118, 2026-04-25). ADR-022 Confirmation criterion 3 extended with a
  reconciliation invariant cross-referencing the new script.

## 0.19.3

### Patch Changes

- 22b9a17: P078 — Hook now offers ticket capture on strong-signal correction.

  A new `UserPromptSubmit` hook (`itil-correction-detect.sh`) detects strong-affect correction signals in the user's prompt — `FFS`, all-caps imperatives (`DO NOT`, `DON'T`, `STOP`), direct contradiction (`that's wrong`, `you're not listening`), exasperation markers (`!!!`), meta-correction (`you always`, `you never`, `you keep`) — and injects a `MANDATORY` reminder telling the assistant to OFFER `/wr-itil:capture-problem` (with `/wr-itil:manage-problem` as today's fallback) BEFORE addressing the operational request. Once-per-session full block + terse-reminder pattern (ADR-038).

  Without this, strong-signal corrections decay with session context and the same class-of-behaviour pattern recurs next session, with the user having to manually request the ticket every time.

  Pattern vocabulary lives in `packages/itil/hooks/lib/detectors.sh::CORRECTION_SIGNAL_PATTERNS`. Detection is intentionally aggressive (case-insensitive); false positives degrade gracefully (one extra advisory line — the offer is non-blocking).

## 0.19.2

### Patch Changes

- 84124f6: `/wr-itil:report-upstream` gains Step 4b dedup + Step 5c comment path (P070): close the two duplication windows that were the skill's most externally-visible failure mode. Step 4b.1 own re-run check greps the local ticket for an existing `## Reported Upstream` URL and halts-and-surfaces if present. Step 4b.2 third-party search uses `gh issue list --repo <upstream> --search "<keywords>" --state all --json ... --limit 10` as a cheap pre-filter, then performs an inline LLM semantic match against each candidate's body via `gh issue view <n> --json body,title` (no subagent dispatch — per Direction decision 2026-04-21, the gh-search prefilter trims input to ~5-10 candidates which keeps the inline check affordable). Step 5c comment path lands cross-references via `gh issue comment <n>` when a dedup match is selected, and the local ticket records `Disclosure path: commented-on-existing-issue <URL>` in `## Reported Upstream` rather than `public issue`.

  **Modified files:**

  - `packages/itil/skills/report-upstream/SKILL.md` — adds Step 4b (own re-run + third-party search branches), Step 5c (comment path), and extends Step 7 disclosure-path enumeration with `commented-on-existing-issue`.
  - `docs/decisions/024-cross-project-problem-reporting-contract.proposed.md` — Decision Outcome adds Step 4b + Step 5c; Out-of-scope dedup bullet narrowed to residual `update-mode`; Confirmation criterion 2 gains the new bats coverage line; Related lists P070 as driver.
  - `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` — 9 new behavioural assertions (Step 4b presence, own-re-run detection language, third-party `gh issue list --search` language, Step 5c comment-path, AFK halt-and-save behaviour, disclosure-path enumeration); file 24/24 green.

  **AFK behaviour (interim):** halt-and-save the drafted report to the local ticket's `## Drafted Upstream Report` section per ADR-013 Rule 6. The maintainer-annoyance risk evaluator that would gate auto-comment is **DEFERRED** to compose with `wr-risk-scorer:external-comms` per ADR-028 line 117 — keeps P070 effort at M and avoids cross-cutting work blocking on P064. When P064 lands, a follow-up bundling commit will wire the maintainer-annoyance evaluator + P064 leak gate together so the AFK auto-comment branch can fire at appetite.

  **Architect verdict**: PASS x3 (overall shape, bats, ADR-024 amendment) — confirmed inline LLM check (no subagent) is the right scope and that maintainer-annoyance evaluator deferral is the right architectural call. **JTBD verdict**: PASS — JTBD-004 primary fit (cross-repo coordination protected from spam); JTBD-001 / JTBD-006 / JTBD-101 protected by halt-and-surface fallback. **Risk**: 2/25 Very Low; reduces silent-duplicate risk on the report-upstream surface.

  P070 (Open → Verification Pending). Verification path: exercise the skill twice against the same upstream + local ticket (4b.1 should halt on second run); exercise against an upstream with overlapping existing issues (4b.2 should offer comment path or halt-and-save in AFK).

- ccc8ffc: `/wr-itil:manage-problem` Step 2 duplicate-check enforcement (P119): close the structural gap that lets agents bypass the duplicate-prevention grep by writing tickets directly to `docs/problems/` via the Write tool. Adds a `PreToolUse:Write` hook that gates new-file creation under `docs/problems/<NNN>-*.<status>.md` on a per-session marker set by Step 2. Without the marker the agent gets a `permissionDecision: deny` directing them back into the skill — where Step 2 grep + `AskUserQuestion` for matches fires before the new file lands.

  **New files:**

  - `packages/itil/hooks/manage-problem-enforce-create.sh` — PreToolUse:Write hook. Matches `docs/problems/<NNN>-*.<status>.md` new-file paths (numeric-prefix basename test, ADR-031 forward-compat). Allow-lists `docs/problems/README.md` (chicken-and-egg — regenerated by Steps 5/6/7) and existing files (Edit-flow / status transitions). Only Write is gated; Edit on existing tickets is the transition-problem surface.
  - `packages/itil/hooks/lib/create-gate.sh` — sibling of `lib/review-gate.sh`. Different semantics (no TTL drift detection — the marker is just "Step 2 ran for this session"), so kept separate per architect direction. Per-session scope (`/tmp/manage-problem-grep-${SESSION_ID}`) — single marker covers all new tickets in a skill invocation, enabling Step 4b multi-concern split without re-grep blocking.
  - `packages/itil/hooks/test/manage-problem-enforce-create.bats` — 16 behavioural assertions (deny path, allow path, multi-concern split compatibility, README exemption, Edit-flow exemption, status-suffix coverage, ADR-031 forward-compat, marker hygiene).

  **Modified files:**

  - `packages/itil/hooks/hooks.json` — registers the new `PreToolUse:Write` matcher.
  - `packages/itil/skills/manage-problem/SKILL.md` Step 2 — adds substep 7: write the create-gate marker after the grep completes. Adds a "Hook contract (P119)" callout explaining the deny shape and warning against manual marker-setting.

  **Architect verdict**: APPROVED — fits ADR-009 gate-marker lifecycle + ADR-038 progressive disclosure without amendment; per-session marker scope confirmed; ADR-031 forward-compat advisory addressed in matcher. **JTBD verdict**: PASS — closes JTBD-001 governance-skip pain point; preserves JTBD-006 AFK queue integrity; protects JTBD-201 audit trail. **Tests**: 38/38 itil hooks; 876/876 full suite; no regressions.

  P119 (Open → Verification Pending).

## 0.19.1

### Patch Changes

- cbf178e: work-problems Step 5 dispatch robustness (P089): two bounded refinements within the shipped 0.13.0 `claude -p` subprocess dispatch + 0.14.0 cost-metadata extraction contract — no ADR amendment, no CLI change.

  **Gap 1 — stdin-warning redirect.** The canonical Step 5 dispatch command now ends with `< /dev/null` to suppress the `claude -p` 3-second stdin-wait warning. The warning is emitted to stderr, which is fine when streams are consumed separately; under the orchestrator's `2>&1` merge (required to keep stderr prose from interleaving between chained invocations) the warning prefixed stdout and broke `jq` / `json.load` / `JSON.parse` extraction of `.result` and cost metadata. The redirect is the Anthropic CLI help's own suggested workaround. First observed AFK-iter-7 iter 1 (2026-04-21); iter 2-7 used the workaround.

  **Gap 2 — authority hierarchy for cost vs usage.** Added an Authority hierarchy paragraph to the Per-iteration cost metadata block and a matching Authority note to the Output Format Session Cost section. `.total_cost_usd` is cumulative-authoritative by CLI contract and is the trusted dollar signal; `.usage.*` is a per-turn response envelope and can reflect only the final-turn ack when the subprocess exits via a background-task completion notification — observed AFK-iter-7 iter 5 where a 1071s wall-clock / 60+ tool-use run reported `duration_ms: 8546, num_turns: 1, usage.* ≈ 137K tokens, total_cost_usd: 6.08` (cost correct, tokens final-turn-only). Session Cost output now renders the cost column as authoritative and labels token totals best-effort. Detection criterion (final-turn-sized usage alongside wall-clock-orders-of-magnitude-larger-than-`duration_ms`) stated descriptively; no change to the named-field extraction list.

  No SKILL.md contract break; no runtime behaviour change in the orchestrator. Tests: 6 new assertions in `work-problems-step-5-delegation.bats` (30/30 passing).

## 0.19.0

### Minor Changes

- 77f0542: P109: work-problems Step 0 preflight detects prior-session partial-work state

  `/wr-itil:work-problems` Step 0 (AFK orchestrator preflight) gains a **session-continuity detection pass** after the existing `git fetch origin` + divergence check. This closes the gap where an AFK loop restarted after a quota (429) / error / user-cancel would silently iterate past partial work left in the working tree.

  **Signals enumerated** (each maps to one `git status --porcelain` / filesystem / `git worktree` probe):

  - Untracked `docs/decisions/*.proposed.md` — drafted but unlanded ADRs from a prior iter.
  - Untracked `docs/problems/*.md` — drafted but unlanded problem tickets.
  - `.afk-run-state/iter-*.json` files with `"is_error": true` OR `"api_error_status" >= 400` — prior iteration hit quota or API error (ADR-032 subprocess artefact contract). Success files (`"is_error": false`) are ignored.
  - Stale `.claude/worktrees/*` directories + matching `git worktree list` entries on `claude/*` branches — prior subagent worktrees not cleaned up. Detection only — mutation/cleanup is out of scope and would require a separate ADR.
  - Uncommitted modifications to `packages/*/skills/*/SKILL.md`, `packages/*/hooks/*`, `docs/decisions/*.proposed.md`, or other source paths the prior session was mid-authoring.

  **Routing per ADR-013 Rule 1 / Rule 6**:

  - **Interactive**: `AskUserQuestion` with 4 options — **Resume the prior work** (land drafted files as iter 1), **Discard the draft**, **Leave-and-lower-priority** (skip the dirty paths), **Halt the loop**.
  - **Non-interactive / AFK** (default for this skill per JTBD-006): halt the loop with a structured Prior-Session State report in the AFK summary. Matches Step 6.75's "dirty for unknown reason → halt" stance at the Step 0 layer — the orchestrator does not silently proceed past partial work.

  **Surfaces**:

  - `packages/itil/skills/work-problems/SKILL.md` Step 0 — adds the session-continuity detection subsection plus a decision-matrix row in the Non-Interactive Decision Making table.
  - `docs/decisions/019-afk-orchestrator-preflight.proposed.md` — extended (within its 2026-07-18 reassessment window); no new ADR created. Confirmation criterion 5 added for the contract-assertion bats.
  - `packages/itil/skills/work-problems/test/work-problems-preflight-session-continuity.bats` — 16 contract-assertion tests per ADR-037 covering signal enumeration, interactive/AFK routing, and the decision-matrix row.

  Closes P109 → Verification Pending.

## 0.18.1

### Patch Changes

- b2424c8: P113: declare `Skill, Agent` in `wr-itil:report-upstream` allowed-tools

  The `report-upstream` skill body (`packages/itil/skills/report-upstream/SKILL.md` Step 9 / line 330) invokes the `wr-risk-scorer:pipeline` subagent (requires the `Agent` tool) and falls back to `/wr-risk-scorer:assess-release` per ADR-015 (requires the `Skill` tool). Neither was declared in the SKILL.md frontmatter `allowed-tools` field. `report-upstream` was the only itil skill that declared `AskUserQuestion` without also declaring `Skill` — and the only itil skill missing from Claude Code's TUI slash-command autocomplete despite being present in the agent-side skill enumerator.

  Candidate mechanism (to confirm post-release per the verification path on P113): Claude Code's TUI autocomplete appears to validate declared-vs-used tools in skill frontmatter and silently drop skills whose bodies invoke tools not declared in `allowed-tools`, while the server-side enumerator (which populates the agent's available-skills list) is more lenient. If the hypothesis holds, adding `Skill, Agent` restores `/wr-itil:report-upstream` to the autocomplete surface without changing runtime behaviour. If the hypothesis is wrong, P113 reopens for upstream escalation to Anthropic.

  Closes P113 → Verification Pending.

## 0.18.0

### Minor Changes

- 8ad3d3b: ADR-041: auto-apply scorer remediations when above appetite; never release above appetite

  Land ADR-041 closing P103 (`/wr-itil:work-problems` escalated resolved above-appetite release decisions) and P104 (partial-progress painted the release queue into a corner).

  Behaviour:

  - `work-problems` Step 6.5 gains an above-appetite branch. When `push` or `release` residual risk lands ≥ 5/25, the orchestrator auto-applies scorer remediations in rank order (largest `|risk_delta|` first) until residual risk converges within appetite (≤ 4/25). Each auto-apply amends the iteration's main commit per ADR-041 Rule 3 (preserves ADR-032 one-commit-per-iteration invariant).
  - `manage-problem` Step 12 and `manage-incident` Step 15 terminal release sequences inherit the same above-appetite branch; each auto-apply is its own commit since there is no iteration wrapper in non-AFK mode.
  - **Never release above appetite**: there is no code path in either lineage that drains at ≥ 5/25. Exhaustion halts the loop/skill per ADR-041 Rule 5.
  - **Closed action-class enumeration (Rule 2a)**: ADR-041 v1 ships with `move-to-holding` implemented (`git mv .changeset/<name>.md docs/changesets-holding/<name>.md`). Classes `revert-commit`, `amend-commit`, `feature-flag`, `rollback-to-tag` are deferred to P108. Unsupported class descriptions route to Rule 5 halt.
  - **Verification Pending carve-out (Rule 2b)**: auto-revert never fires against commits attached to `.verifying.md` tickets; Rule 5 halt names the VP ticket(s).
  - **Governance gates apply per auto-apply (Rule 3)**: the scorer proposes; architect + JTBD + risk-scorer gates authorise. No scorer-bypass path.
  - **Audit trail (Rule 6)**: iteration/skill reports emit an Auto-apply trail subsection (one line per apply); `docs/changesets-holding/README.md` "Currently held" appends for `move-to-holding` actions.
  - **Holding-area blessed (Rule 7)**: `docs/changesets-holding/` promoted from provisional to authoritative. ADR-041 cited as the governing decision; provisional banner removed.

  Supersedes the implicit above-appetite branch of ADR-018 Step 6.5 and the explicit above-appetite branch of ADR-020 §6; both ADRs cross-reference ADR-041 from the same commit. At-or-below-appetite drain behaviour in both is unchanged.

  Authorised by ADR-013 Rule 5 (policy-authorised silent proceed): `RISK-POLICY.md` appetite + ADR-041 Rule 2a enumeration constitute the policy for the auto-apply loop.

  Follow-up work tracked in **P108** (`docs/problems/108-scorer-remediation-action-class-vocabulary.open.md`) — scorer contract extension (structured `action_class` column in `RISK_REMEDIATIONS:`) + orchestrator parsers for the four deferred classes. Until P108 lands, ADR-041 v1's scope is the `move-to-holding` subset.

  Closes P103, P104. Opens P108.

## 0.17.2

### Patch Changes

- 8d28266: P094 — `/wr-itil:manage-problem` now refreshes `docs/problems/README.md` on new-ticket creation (Step 5, unconditional) and on ranking-changing updates (Step 6, conditional on Priority / Effort / WSJF line changes). Step 11's staging language extends the single-commit rule from Step 7 transitions to cover Step 5 creation and Step 6 ranking-change updates so README.md rides every commit that alters on-disk ticket ranks. Closes P094.

## 0.17.1

### Patch Changes

- d2fa4c6: P093 — resolve `/wr-itil:transition-problem` ↔ `/wr-itil:manage-problem` circular delegation for `<NNN> <status>` args.

  `/wr-itil:transition-problem` now hosts the Step 7 transition block inline: pre-flight checks per destination (Open → Known Error / Known Error → Verifying / Verifying → Close), P063 external-root-cause detection with the AFK fallback, `git mv` + Status edit + P057 explicit re-stage, `## Fix Released` section write on the `.verifying.md` destination, P062 README refresh, and the ADR-014 commit through the risk-scorer pipeline gate. The skill no longer re-invokes `/wr-itil:manage-problem` — the round-trip clause that created the infinite-delegation cycle has been stripped from `manage-problem`'s Step 1 `<NNN> <status>` forwarder paragraph.

  Per architect guidance, the fix follows a "copy, not move" shape: the in-skill Step 7 block on `manage-problem` stays intact for in-skill callers (Step 9b auto-transition, the Parked path, Step 9d closure inside review). The split skill carries a scoped inline copy for the user-initiated transition path only.

  ADR-010 amended with a new **"Split-skill execution ownership"** sub-rule (2026-04-22) codifying the "copy, not move" principle so the same trap does not recur in future clean-split skills.

  Existing `transition-problem-contract.bats` test 7 inverted in place to assert no round-trip; test 8 added for inline Step 7 mechanics. Full itil sweep: 736/736 green.

## 0.17.0

### Minor Changes

- d938a04: P067 — `/wr-itil:report-upstream` classifier is now problem-first per ADR-033. The Step 3 classifier picks `problem` shape as primary (tokens: problem / issue / concern / defect / gap / scoped-npm reference / root cause / reproduction / workaround) and demotes bug / feature / question to backward-compat fallback shapes. The Step 5 structured default body is problem-shaped (Description / Symptoms / Workaround / Affected plugin / Frequency / Environment / Evidence / Cross-reference); bug-shaped / feature-shaped / question-shaped bodies are retained as fallback-only templates for the corresponding backward-compat branches. Template-discovery preference order now searches `problem-report.yml` / `problem.yml` / `problem-report.md` / `problem.md` before bug / feature / question template candidates. ADR-033 partially supersedes ADR-024 Decision Outcome Steps 3 and 5; ADR-024 Steps 1, 2, 4, 6, 7, 8 and all Consequences remain in force. Ships after P066's intake-template reform (2026-04-20) so the skill's preference order matches the reference intake shape this repo now ships.
- 73c48b7: P076 — WSJF scoring in `/wr-itil:manage-problem` now models transitive dependencies. Ticket effort is split into `marginal` (the ticket's own added work) and `transitive` (`max(marginal, max{ Blocked_by upstreams })`); WSJF uses the transitive effort so a dependent ticket can never out-rank a ticket whose work is strictly contained within it. Additions:

  - New `### Transitive dependencies (P076)` subsection in `packages/itil/skills/manage-problem/SKILL.md` WSJF Prioritisation section defining the rule, the `**Blocked by**` signal, the `**Composes with**` non-propagation carve-out, the `.closed.md` / `.verifying.md` / `.parked.md` upstream-contributes-0 carve-out, cycle-bundling semantics, a worked example (P073 marginal S + blocked by P038 XL → transitive XL → WSJF 1.5), a concrete re-rate message format (`P<NNN>: Effort <OLD> → <NEW> (transitive via <UPSTREAM>)`), and a reassessment-criteria note for future sibling-ADR extraction if a second skill adopts the `## Dependencies` convention.
  - New `## Dependencies` section in the Step 5 problem-ticket template with `**Blocks**` / `**Blocked by**` / `**Composes with**` rows (bare IDs, empty lists allowed) and a concrete example block.
  - New Step 9b.1 dependency-graph-traversal pass in `manage-problem` and a mirrored Step 2.5 in `/wr-itil:review-problems` (the executor split per P071) that builds the `**Blocked by**` adjacency map, topologically sorts, propagates effort, writes an `<!-- transitive: <bucket> via <UPSTREAM> -->` audit comment on the Effort line, and reports each re-rate in the step-3 review output.
  - New `manage-problem-transitive-dependencies.bats` contract + behavioural test file (21 assertions — 15 structural contract assertions per ADR-037 plus 6 behavioural fixture tests exercising the transitive-closure algorithm directly so prose-drift like `min` instead of `max`, or a missing carve-out for closed upstreams, is caught at test time).
  - Three new contract assertions on `review-problems-contract.bats` covering the new Step 2.5 pass, canonical-rule citation, and re-rate message shape.

  No new ADR authored (following ADR-022's inline-amendment precedent for WSJF additions); reassessment trigger documented inline. Backward-compatible — tickets without a `## Dependencies` section behave as before (empty closure → transitive == marginal).

## 0.16.0

### Minor Changes

- 6f3265a: P086: AFK iteration subprocess now runs `/wr-retrospective:run-retro` before emitting `ITERATION_SUMMARY`

  The AFK `/wr-itil:work-problems` iteration subprocess previously emitted `ITERATION_SUMMARY` and exited without running retro, discarding every per-iteration friction observation — hook TTL expiries, marker-vs-file deadlocks, repeat-workaround patterns, subagent-delegation friction, release-path instability. Across a 5-iteration AFK loop that's 20–50 tool-level observations the backlog never sees, degrading JTBD-006's "clear summary on return" outcome and JTBD-101's "new friction patterns become ticketable" promise.

  `packages/itil/skills/work-problems/SKILL.md` Step 5 iteration prompt body gains a closing step (step 4) naming `/wr-retrospective:run-retro` before the `ITERATION_SUMMARY` emission step. Retro runs INSIDE the subprocess so its Step 2b pipeline-instability scan has access to the iteration's full tool-call history; retro commits its own work per ADR-014 (run-retro delegates ticket creation to `/wr-itil:manage-problem`); orchestrator picks up retro-created tickets on the next Step 1 scan naturally — no cross-process marker sharing required. Retro is non-blocking: if retro fails or surfaces findings, the iteration still emits `ITERATION_SUMMARY` so the AFK loop does not halt on a flaky retro run.

  `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` subprocess-boundary variant gains a matching "Retro-on-exit (P086 amendment)" clause under the Pattern contract block, parallel to how P084 amended P077 — the retro contract is the subprocess-boundary variant's closing-step invariant alongside spawn command, stdout parse shape, exit-code semantics, hook session-id isolation, post-subprocess state re-read, and orchestration boundary.

  `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` gains four doc-lint contract assertions (P086): iteration prompt names `/wr-retrospective:run-retro`; retro ordered BEFORE `ITERATION_SUMMARY` emission; retro named as non-blocking closing step; ADR-014 cited for retro commit ownership.

  Architect review PASS (no ADR invariant violated; amendment shape parallels P084→P077). JTBD review PASS (JTBD-006 + JTBD-101 primary alignment; JTBD-001 no-regression — retro runs inside subprocess, orchestrator main turn unaffected).

## 0.15.0

### Minor Changes

- 4a25a60: P071 split slices 6b + 6c + 6d: new `/wr-itil:restore-incident`, `/wr-itil:close-incident`, and `/wr-itil:link-incident` skills

  `/wr-itil:manage-incident <I> restored`, `/wr-itil:manage-incident <I> close`, and `/wr-itil:manage-incident <I> link P<M>` are deprecated; the three remaining incident-lifecycle user intents now have their own skills so the `/` autocomplete surfaces each one directly (JTBD-001 + JTBD-101 + JTBD-201). These are slices 6b + 6c + 6d of the P071 phased-landing plan, bundled in one commit because each mirrors slice 6a (mitigate-incident, commit 248edad) verbatim except for the transition each owns. Bundling amortises cache-warmup + full bats re-run cost across three identical-pattern splits; per-slice separability is preserved via one contract-bats file per skill.

  - `packages/itil/skills/restore-incident/SKILL.md` — NEW split skill (slice 6b).
    `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill`
    — diverges from close-incident + link-incident because restore invokes
    `/wr-itil:manage-problem` via the Skill tool for the problem-handoff
    (ADR-011 Decision Outcome point 4) and uses AskUserQuestion for the
    "create problem / no problem required" branch. Owns the
    `.mitigating.md → .restored.md` rename, the Status field update, the
    "Service restored" Timeline entry, and the `## Linked Problem` or
    `## No Problem` section write. Pre-flight enforces at least one
    recorded mitigation attempt + a captured verification signal per
    ADR-011. Re-invocation on an already-`.restored.md` file is
    idempotent (Case B) — does not re-edit the Status field.
  - `packages/itil/skills/restore-incident/test/restore-incident-contract.bats`
    — NEW 12 contract assertions (ADR-037 pattern; @problem P071 + @jtbd
    JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability).
  - `packages/itil/skills/close-incident/SKILL.md` — NEW split skill (slice 6c).
    `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — no
    AskUserQuestion (the linked-problem gate is a hard check with a message,
    not a decisional prompt), no Skill tool (no cross-skill invocation).
    Owns the `.restored.md → .closed.md` rename, the Status field update,
    and the "Incident closed" Timeline entry. Gate accepts linked problems
    in `.known-error.md`, `.verifying.md` (ADR-022 extension), or
    `.closed.md` state; `.open.md` blocks close with a pointer to
    `/wr-itil:transition-problem`. `## No Problem` section bypasses the
    gate. Already-closed invocations short-circuit idempotently.
  - `packages/itil/skills/close-incident/test/close-incident-contract.bats`
    — NEW 13 contract assertions (ADR-037 pattern; @problem P071 +
    @jtbd JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability;
    includes the ADR-022 `.verifying.md` gate-allowance regression guard).
  - `packages/itil/skills/link-incident/SKILL.md` — NEW split skill (slice 6d).
    `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — two data
    parameters (incident ID + problem ID) and no decisional prompts.
    Owns the `## Linked Problem` section write / update, including the
    retroactive-link-from-No-Problem conversion (Case C) which also
    appends a `Retroactive link to P<MMM>` Timeline entry so the audit
    trail records the revision.
  - `packages/itil/skills/link-incident/test/link-incident-contract.bats`
    — NEW 11 contract assertions (ADR-037 pattern; @problem P071 +
    @jtbd JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability).
  - `packages/itil/skills/manage-incident/SKILL.md` — Step 1 parser now
    recognises three additional shapes (`<I###> restored`, `<I###> close`,
    `<I###> link P<MMM>`) and delegates via the Skill tool; emits the
    canonical deprecation systemMessage verbatim for each. Steps 8
    (restore), 9 (close), and 11 (link) reduced to thin-router notes
    pointing at the new skills. `deprecated-arguments: true` already
    pinned from slice 5.
  - `packages/itil/skills/manage-incident/test/manage-incident-restore-forwarder.bats`
    — NEW 4 forwarder contract assertions.
  - `packages/itil/skills/manage-incident/test/manage-incident-close-forwarder.bats`
    — NEW 4 forwarder contract assertions.
  - `packages/itil/skills/manage-incident/test/manage-incident-link-forwarder.bats`
    — NEW 4 forwarder contract assertions.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment.

  This completes the `/wr-itil:manage-incident` subcommand split. All five
  word-verb subcommands (`list`, `mitigate`, `restored`, `close`, `link`)
  are now first-class named skills. `manage-incident` retains two
  responsibilities: (1) declare a new incident (no arguments) and (2)
  update an existing incident body (`<I###> <details>` — data parameter
  only, not a verb subcommand). All five forwarders will be removed
  together in `@windyroad/itil`'s next major version.

  P071 phased-landing plan status: slices 1 (list-problems), 2
  (review-problems), 3 (work-problem singular), 5 (list-incidents), 6a
  (mitigate-incident), 6b (restore-incident), 6c (close-incident), and 6d
  (link-incident) shipped. Slice 4 (`transition-problem`) shipped in a
  prior release. All planned slices are now complete; P071 is eligible
  for transition to `.verifying.md` pending user sign-off per ADR-022.

- 38756a8: P071 split slice 5: new `/wr-itil:list-incidents` skill

  `/wr-itil:manage-incident list` is deprecated; the list-incidents user
  intent now has its own skill so the `/` autocomplete surfaces it directly
  (JTBD-001 + JTBD-101 + JTBD-201). This is slice 5 of the P071 phased-landing
  plan, mirroring slice 1 (list-problems) verbatim.

  - `packages/itil/skills/list-incidents/SKILL.md` — NEW read-only skill
    (`allowed-tools: Read, Bash, Grep, Glob` — no Write, no Edit, no
    AskUserQuestion). Reads `.investigating.md`, `.mitigating.md`, and
    `.restored.md` files from `docs/incidents/`; sorts by severity per
    ADR-011 ("Severity, not WSJF" — incidents are time-bound events where
    the WSJF effort divisor is meaningless).
  - `packages/itil/skills/list-incidents/test/list-incidents-contract.bats`
    — NEW 10 contract assertions (ADR-037 pattern; @problem P071 + @jtbd
    JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability).
  - `packages/itil/skills/manage-incident/SKILL.md` — `deprecated-arguments:
true` frontmatter flag per ADR-010 amended; Step 1 `list` argument now
    routes to a thin-router forwarder that delegates via the Skill tool and
    emits the canonical deprecation notice verbatim.
  - `packages/itil/skills/manage-incident/test/manage-incident-list-forwarder.bats`
    — NEW 4 contract assertions for the forwarder contract.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment. Full itil bats suite green (241/241 + 14 new = 255/255).

  Remaining phased-landing slices tracked on P071: `mitigate-incident`,
  `restore-incident`, `close-incident`, `link-incident` (the remaining
  manage-incident splits).

- 248edad: P071 split slice 6a: new `/wr-itil:mitigate-incident` skill

  `/wr-itil:manage-incident <I###> mitigate <action>` is deprecated; the
  mitigate-incident user intent now has its own skill so the `/` autocomplete
  surfaces it directly (JTBD-001 + JTBD-101 + JTBD-201). This is slice 6a of
  the P071 phased-landing plan, mirroring slice 5 (list-incidents) closely
  except that mitigate-incident takes the `<I###> <action>` data parameters
  — permitted under ADR-010 amended (only word-verb-arguments must be split
  out; data parameters like IDs and free-text action strings remain).

  - `packages/itil/skills/mitigate-incident/SKILL.md` — NEW split skill.
    `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion,
Skill` — diverges from list-incidents's read-only set because mitigation
    renames `.investigating.md → .mitigating.md` on the first attempt and
    appends to the Mitigation attempts timeline. Preserves the ADR-011
    evidence-first gate (≥1 hypothesis with cited evidence) on the first
    mitigation transition, the reversible-mitigation preference
    (rollback → feature flag → restart → route traffic → scale → fix), and
    the Sev 4-5 lightweight path per ADR-011 Step 12 edge case.
  - `packages/itil/skills/mitigate-incident/test/mitigate-incident-contract.bats`
    — NEW 13 contract assertions (ADR-037 pattern; @problem P071 + @jtbd
    JTBD-001 + @jtbd JTBD-101 + @jtbd JTBD-201 traceability).
  - `packages/itil/skills/manage-incident/SKILL.md` — Step 1 parser now
    recognises the `<I###> mitigate <action>` shape and delegates via the
    Skill tool; emits the canonical deprecation systemMessage verbatim.
    Step 7 reduced to a thin-router note pointing at the new skill (the
    rename + evidence-gate implementation lives in `/wr-itil:mitigate-incident`
    now). `deprecated-arguments: true` already pinned from slice 5.
  - `packages/itil/skills/manage-incident/test/manage-incident-mitigate-forwarder.bats`
    — NEW 4 contract assertions for the mitigate forwarder.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment.

  Remaining phased-landing slices tracked on P071: `restore-incident`
  (slice 6b), `close-incident` (slice 6c), `link-incident` (slice 6d) —
  the remaining manage-incident splits.

## 0.14.0

### Minor Changes

- 7670ffb: Extend `/wr-itil:work-problems` Step 5 to extract per-iteration cost + token metadata from each `claude -p --output-format json` response. Surface it in Step 6's per-iteration progress line and the ALL_DONE Output Format's new "Session Cost" section.

  **Why:** the subprocess-dispatch swap shipped in 0.13.0 landed real per-iteration cost inside the JSON response alongside `.result`, but the orchestrator was throwing it away. Without surfacing it, the user has no feedback loop for calibrating AFK loop sizing decisions (e.g. the 2026-04-21 "max out the token usage, they are wasted unused" direction needs actuals to calibrate against). Cost metadata is already emitted — this change just wires it into the user-visible output.

  **Extracted fields (explicit list; PII guard):** `.total_cost_usd`, `.duration_ms`, `.usage.input_tokens`, `.usage.output_tokens`, `.usage.cache_creation_input_tokens`, `.usage.cache_read_input_tokens`. SKILL.md names the extraction scope explicitly so future contributors don't unconsciously broaden it to include `session_id`, `model`, `stop_reason`, `permission_denials`, `uuid`, or other subprocess-envelope fields.

  **Step 6 per-iteration format:** `[Iteration N] Worked P<NNN> — <action>. <K> problems remain. ($<cost>, <duration_s>s, <total_tokens_K>K tokens)`.

  **ALL_DONE Session Cost section:** aggregate totals (cost, iterations, mean cost per iteration, input/output/cache-creation/cache-read tokens, duration). Cache-read column surfaces the warm-cache-reuse signal observed across subsequent subprocess invocations in the same Bash session. Renders identically in interactive and AFK modes; no decision branch (output-side only, per ADR-013 Rule 6).

  **Source citation (per ADR-026):** Session Cost numbers are extracted measured-actuals from each iteration's `claude -p` JSON output — not estimates. Cited in the section header so downstream audits can trust the numbers.

  Architect + JTBD reviews PASS (both 2026-04-21). Bats doc-lint: 9 new assertions on the extraction language + Session Cost section shape; 54/54 work-problems suite green.

## 0.13.0

### Minor Changes

- 260768f: P084 fix: `/wr-itil:work-problems` Step 5 dispatches iterations via a `claude -p` subprocess instead of Agent-tool-spawned `general-purpose` subagents.

  **Why:** Agent-tool-spawned subagents do NOT have the Agent tool in their own surface (platform restriction; three-source evidence — ToolSearch probe, Claude Code docs, empirical runtime error). Without Agent, the iteration worker could not satisfy architect + JTBD PreToolUse edit-gate markers (only settable via Agent-tool PostToolUse hook) nor the risk-scorer commit gate. Every AFK iteration on a gate-covered path (`packages/`, ADRs, SKILL.md edits, hook edits) silently halted. The subprocess variant is a full main Claude Code session with Agent available, so governance reviews run at full depth and gate markers set natively.

  **Dispatch command:** `claude -p --permission-mode bypassPermissions --output-format json <iteration-prompt>`.

  **No per-iteration budget cap.** Per user direction, the AFK loop's natural stop condition is quota exhaustion, not an arbitrary dollar cap. A cap would halt iterations before quota is actually exhausted, leaving remaining backlog unprocessed. Quota-exhaust surfaces as a non-zero `claude -p` exit and the orchestrator halts cleanly per Step 6.75's exit-code handling.

  **What stays the same:** the `ITERATION_SUMMARY` return-summary contract is preserved verbatim (orchestrator extracts from the JSON `.result` field instead of the Agent-tool return value). Step 0 preflight (ADR-019), Step 6.5 release-cadence drain (ADR-018), and Step 6.75 inter-iteration verification (P036) all remain in the orchestrator's main turn unchanged. Every non-Step-5 block in the skill is untouched.

  **Adopter-tunable:** adopters with narrower permission scopes may substitute `--permission-mode acceptEdits` / `auto` / `dontAsk` for `bypassPermissions`. Adopters who genuinely need a per-iteration cap (multi-tenant billing, etc.) can add `--max-budget-usd` in their own fork — not the default.

  See `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` for the full subprocess-boundary sub-pattern contract (amendment dated 2026-04-21) and `docs/problems/084-work-problems-iteration-worker-has-no-agent-tool-so-architect-jtbd-gates-block.open.md` for the full diagnosis + probe evidence.

## 0.12.0

### Minor Changes

- 91da109: P071 split slice 4: new `/wr-itil:transition-problem` skill (+ manage-problem forwarder)

  `/wr-itil:manage-problem <NNN> known-error` / `<NNN> verifying` / `<NNN> close`
  is deprecated; the transition-a-ticket user intent now has its own skill so
  Claude Code `/` autocomplete surfaces it directly (JTBD-001 + JTBD-101).
  This is phase 4 of the P071 phased-landing plan.

  - `packages/itil/skills/transition-problem/SKILL.md` — NEW thin-router
    selection skill. Arguments: `<NNN>` (ticket ID) + `<status>` (one of
    `known-error`, `verifying`, `close`). Both are data parameters per the
    P071 split rule (ADR-010 amended); neither is a word-subcommand.
    Execution delegates to `/wr-itil:manage-problem <NNN> <status>` via the
    Skill tool — the authoritative Step 7 block (pre-flight checks + P057
    staging trap + P063 external-root-cause + P062 README refresh) stays
    on the host skill.
  - `packages/itil/skills/transition-problem/test/transition-problem-contract.bats`
    — NEW 14 contract assertions (ADR-037 pattern; @problem P071 +
    @jtbd JTBD-001 + @jtbd JTBD-101 traceability).
  - `packages/itil/skills/manage-problem/SKILL.md` — Step 1 parser updated
    to distinguish bare `<NNN>` (update flow, handled inline by Step 6)
    from `<NNN> <status>` (transition — delegated to the new skill). New
    "Forwarder for `<NNN> <status>` transitions" section added to the
    Deprecated-argument forwarders block, with the canonical deprecation
    notice (per ADR-010 amended template).
  - `packages/itil/skills/manage-problem/test/manage-problem-transition-forwarder.bats`
    — NEW 5 contract assertions for the forwarder contract.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment.

  Remaining phased-landing slices tracked on P071: `list-incidents`,
  `mitigate-incident`, `restore-incident`, `close-incident`,
  `link-incident` (the `manage-incident` splits).

  **Recovery note:** this slice shipped after the iter-5 AFK halt per P036.
  The iteration subagent wrote the files correctly (19/19 bats green) but
  returned prematurely without committing, triggering Step 6.75's
  dirty-for-unknown-reason branch. Work verified sound post-hoc and
  committed here as the halt recovery. A follow-up ticket captures the
  iteration-worker-must-not-ScheduleWakeup contract gap (separate from
  P077's delegation-mechanism fix).

- ffa85a7: feat(itil): P071 split slice 3 — /wr-itil:work-problem (+ manage-problem forwarder)

  Phase 3 of P071's phased-landing plan: the "pick the highest-WSJF ticket and work it" user intent gets its own skill so `/` autocomplete surfaces it directly. Previously hidden behind `/wr-itil:manage-problem work` — a word-argument subcommand that Claude Code autocomplete does not surface.

  CRITICAL naming distinction: `/wr-itil:work-problem` is **singular** — one ticket per invocation, interactive `AskUserQuestion` selection. It is distinct from the already-existing plural `/wr-itil:work-problems` (AFK batch orchestrator). The two names coexist per P071's acknowledged trade-off; the singular skill is the per-iteration execution unit the plural orchestrator delegates into via the Agent tool (P077 + ADR-032).

  `/wr-itil:work-problem` (new skill):

  - Frontmatter: `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill, Agent` — the selection tool surface plus delegation to `/wr-itil:review-problems` (refresh) and `/wr-itil:manage-problem <NNN>` (execution).
  - Step 1 reads `docs/problems/README.md` if fresh (git-history staleness test per P031); delegates to `/wr-itil:review-problems` for the refresh if stale (P062 canonical-writer discipline — no fork).
  - Step 2 fires `AskUserQuestion` selection: Recommended single top-WSJF option, or per-tied-ticket peer options for multi-way ties, with per-option rationale. Never prose "(a)/(b)/(c)" (P053 + ADR-013 Rule 1 regression guard).
  - Step 3 delegates the execution to `/wr-itil:manage-problem <NNN>` via the Skill tool — thin-router discipline; the full investigate/transition/fix/release workflow stays on a single authoritative host.
  - Step 4 fires the standard scope-change `AskUserQuestion` (Continue / Re-rank / Pick-different) on effort drift.
  - Step 5 reports the outcome; does NOT loop automatically (that's the plural orchestrator's job).
  - AFK branch (ADR-013 Rule 6): when invoked inside a `/wr-itil:work-problems` iteration, skips `AskUserQuestion` and executes the pre-selected ticket. Within-day tiebreak matches the orchestrator spec.

  `/wr-itil:manage-problem` (deprecated-argument forwarder for `work`):

  - Step 1 `work` argument now delegates to `/wr-itil:work-problem` via the Skill tool and emits the canonical systemMessage verbatim per ADR-010's pinned template: `"/wr-itil:manage-problem work is deprecated; use /wr-itil:work-problem directly. This forwarder will be removed in @windyroad/itil's next major version."`
  - Forwarder does not re-implement the selection logic (thin-router per ADR-010).
  - `deprecated-arguments: true` frontmatter flag already present from slice 1; no change.

  Tests (ADR-037 contract-assertion pattern):

  - `packages/itil/skills/work-problem/test/work-problem-contract.bats` — 19 assertions covering: frontmatter (name singular + regression guard against plural drift; description names pick/highest-WSJF + singular distinction; allowed-tools AskUserQuestion + Skill); singular-vs-plural naming-distinction documentation; delegation to `/wr-itil:manage-problem` (anti-fork); defer-to-`/wr-itil:review-problems` for cache refresh (P062 ownership); git-history freshness test (P031); `AskUserQuestion` selection prompt fires (ADR-013 Rule 1); prose-selection fallback forbidden (P053); AFK branch documented (Rule 6); scope-expansion 3-option shape; one-ticket-per-invocation singular contract; no `deprecated-arguments: true` flag on clean-split skill; no word-argument subcommand branching regression; P071 + ADR-010 + P077 + ADR-032 traceability citations.
  - `packages/itil/skills/manage-problem/test/manage-problem-work-forwarder.bats` — 5 assertions covering: forwarder targets `/wr-itil:work-problem` (singular); singular-vs-plural name-collision guard; canonical deprecation notice emission; no inline re-implementation; parser-line pattern matches slice-1 + slice-2 shape.

  Cross-references:

  - P071 (docs/problems/071-\*.open.md) — originating ticket; phased plan's slice 3.
  - ADR-010 amended (Skill Granularity section) — canonical split-naming + forwarder contract.
  - ADR-013 Rule 1 — structured user interaction; Rule 6 — AFK fallback.
  - ADR-014 — governance skills commit their own work; delegated manage-problem owns per-ticket commits.
  - ADR-032 + P077 — plural AFK orchestrator delegates iterations via Agent tool; this singular skill is the canonical execution unit.
  - P031 — git-history freshness test; P062 — review-problems canonical README cache writer.
  - P053 + ADR-013 Rule 1 — no prose-selection fallback.

## 0.11.0

### Minor Changes

- d8ab4c5: P071 split slice 2: new `/wr-itil:review-problems` skill

  `/wr-itil:manage-problem review` is deprecated; the review-problems user
  intent now has its own skill so the `/` autocomplete surfaces it directly
  (JTBD-001 + JTBD-101). This is phase 2 of the P071 phased-landing plan
  (list-problems shipped as slice 1 in `@windyroad/itil@0.10.0`).

  - `packages/itil/skills/review-problems/SKILL.md` — NEW skill carrying
    the full review stack: re-read `RISK-POLICY.md`, re-score every
    `.open.md` / `.known-error.md` ticket (Impact × Likelihood × Effort →
    WSJF), auto-transition Open → Known Error when root cause + workaround
    are documented, fire the Verification Queue prompt (`.verifying.md`
    per ADR-022 + P048 Candidate 4 `Likely verified?` heuristic), rewrite
    `docs/problems/README.md`, and commit per ADR-014 + ADR-015.
    `allowed-tools`: `Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion,
Skill` — the tool surface the governance-scoped write path demands
    (contrast with `list-problems`'s read-only surface).
  - `packages/itil/skills/review-problems/test/review-problems-contract.bats`
    — NEW 16 contract assertions (ADR-037 pattern; `@problem P071` +
    `@jtbd JTBD-001` + `@jtbd JTBD-101` traceability). Covers: frontmatter
    name, description intent language, allowed-tools surface (Write +
    Edit + Skill + AskUserQuestion required), glob scope (.open.md /
    .known-error.md / .verifying.md / .parked.md), README-refresh ownership
    boundary, Verification Queue prompt contract (ADR-022 fix-summary
    requirement), auto-transition path, ADR-014/015 commit-gate, P057
    staging-trap citation, RISK-POLICY.md reuse (no hardcoded scale),
    P071/ADR-010 citation, clean-split no-deprecated-arguments flag, and
    regression guard against word-argument subcommand branching.
  - `packages/itil/skills/manage-problem/SKILL.md` — Step 1 `review`
    argument now routes to a thin-router forwarder that delegates to
    `/wr-itil:review-problems` via the Skill tool and emits the canonical
    deprecation notice verbatim per ADR-010's pinned template. Parser
    line updated from "run the review (step 9) only" to "delegate to
    `/wr-itil:review-problems`". Step 9's inline review logic stays in
    the file during the deprecation window (for historical reference +
    the inline `work` path that still flows through Step 9 pre-slice 3)
    but is no longer the primary entry point.
  - `packages/itil/skills/manage-problem/test/manage-problem-review-forwarder.bats`
    — NEW 4 contract assertions for the review-forwarder contract:
    target-skill reference, canonical deprecation notice, delegate /
    Skill tool language (no re-implementation), and parser-line shape.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment.

  Remaining phased-landing slices tracked on P071: `work-problem`
  (singular; coexists with `/wr-itil:work-problems` AFK plural),
  `transition-problem`, plus the `manage-incident` splits
  (`list-incidents`, `mitigate-incident`, `restore-incident`,
  `close-incident`, `link-incident`).

## 0.10.1

### Patch Changes

- a0ec231: P077 fix: work-problems Step 5 delegates iterations via the Agent tool

  `/wr-itil:work-problems` Step 5 previously used an ambiguous "Invoke the
  manage-problem skill" line that read as a Skill-tool (in-process) invocation.
  That expanded manage-problem's 500+ line SKILL.md into the main orchestrator's
  context every iteration, accumulated across the AFK loop, and caused silent
  early-stop (`ALL_DONE` without a documented stop condition firing).

  Step 5 now delegates each iteration to a `general-purpose` subagent via the
  Agent tool. Option B per P077 — iteration work is general engineering, not
  specialised domain expertise, so a typed iteration-worker subagent would just
  re-export manage-problem's content. The AFK iteration-isolation wrapper
  sub-pattern is documented in ADR-032 (amended 2026-04-21).

  - `packages/itil/skills/work-problems/SKILL.md` Step 5 — rewritten with
    explicit Agent-tool delegation (`subagent_type: general-purpose`),
    self-contained prompt shape, and structured return-summary contract
    (`ticket_id` / `ticket_title` / `action` / `outcome` / `committed` /
    `commit_sha` / `reason` / `skip_reason_category` / `outstanding_questions` /
    `remaining_backlog_count` / `notes`). Architect R2: commit-state fields keep
    Step 6.75's Dirty-for-known-reason branch evaluable. JTBD extension:
    skip-reason category and outstanding-questions fields let Step 2.5 populate
    the Outstanding Design Questions table deterministically.
  - `allowed-tools` frontmatter — adds `Agent` (closes the pre-existing latent
    bug where Step 6.5 already required Agent-tool delegation).
  - Non-Interactive Decision Making table — new row documents iteration
    delegation default.
  - `## Related` section — new; cites P077, P036, P040, P041, P053, and ADR-013
    / ADR-014 / ADR-015 / ADR-018 / ADR-019 / ADR-022 / ADR-032 / ADR-037.
  - `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats`
    — NEW, 10 contract assertions (ADR-037 pattern; `@problem P077` +
    `@jtbd JTBD-006` traceability).
  - `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` —
    amended with the "AFK iteration-isolation wrapper (P077 amendment)"
    sub-pattern under foreground synchronous. No supersession.
  - `docs/problems/077-...open.md` → `.verifying.md` with `## Fix Released`
    section per ADR-022.

  Inter-iteration continuity preserved: Step 6.5 (release cadence / ADR-018)
  and Step 6.75 (inter-iteration verification / P036) stay in the main
  orchestrator's turn. The iteration subagent commits its own work per ADR-014
  but MUST NOT run `push:watch`/`release:watch`.

## 0.10.0

### Minor Changes

- 412443f: P071 split slice 1: new `/wr-itil:list-problems` skill

  `/wr-itil:manage-problem list` is deprecated; the list-problems user intent
  now has its own skill so the `/` autocomplete surfaces it directly (JTBD-001

  - JTBD-101). This is phase 1 of the P071 phased-landing plan (audit landed
    in the prior commit — 2 offenders, both in @windyroad/itil).

  * `packages/itil/skills/list-problems/SKILL.md` — NEW read-only skill
    (`allowed-tools: Read, Bash, Grep, Glob` — no Write, no Edit, no
    AskUserQuestion). Reuses the git-log-based README cache freshness check
    from `manage-problem review` per P031 + architect Q4.
  * `packages/itil/skills/list-problems/test/list-problems-contract.bats` —
    NEW 9 contract assertions (ADR-037 pattern; @problem P071 + @jtbd
    JTBD-001 + @jtbd JTBD-101 traceability).
  * `packages/itil/skills/manage-problem/SKILL.md` — `deprecated-arguments:
true` frontmatter flag per ADR-010 amended; Step 1 `list` argument now
    routes to a thin-router forwarder that delegates via the Skill tool and
    emits the canonical deprecation notice verbatim.
  * `packages/itil/skills/manage-problem/test/manage-problem-list-forwarder.bats`
    — NEW 4 contract assertions for the forwarder contract.

  Deprecation window: until `@windyroad/itil`'s next major version per
  ADR-010 amendment. Full bats suite green (467/467).

  Remaining phased-landing slices tracked on P071: `work-problem`,
  `review-problems`, `transition-problem`, plus the `manage-incident`
  splits (`list-incidents`, `mitigate-incident`, `restore-incident`,
  `close-incident`, `link-incident`).

## 0.9.0

### Minor Changes

- 6ee6adc: **manage-problem + work-problems**: wire the external-root-cause detection surface so `manage-problem` prompts for `/wr-itil:report-upstream` invocation when root cause points upstream (closes P063).

  New behaviour:

  - `manage-problem` Step 7 (Open → Known Error transition) scans Root Cause Analysis for strict external markers: explicit `upstream` / `third-party` / `external` / `vendor` labels, or scoped-npm pattern `@[\w-]+/[\w-]+`. On hit, fires `AskUserQuestion` with three options: invoke `/wr-itil:report-upstream` now, defer and note in ticket, or mark false positive.
  - Parked lifecycle gains a pre-park hook: parking with `upstream-blocked` reason runs the same detection.
  - AFK non-interactive fallback (per ADR-013 Rule 6) appends the stable marker `- **Upstream report pending** — external dependency identified; invoke /wr-itil:report-upstream when ready` to the ticket's `## Related` section. The skill is NOT auto-invoked (its Step 6 security-path is interactive per ADR-024 Consequences).
  - `work-problems` `upstream-blocked` skip category now runs the AFK fallback before skipping so accumulated upstream dependencies surface in the ticket body when the user returns.
  - Already-noted grep check prevents duplicate marker lines on subsequent runs.

  No new public skill or command; no ADR changes. Closes a discoverability gap between `manage-problem` (caller) and `/wr-itil:report-upstream` (callee, shipped in 0.8.0).

### Patch Changes

- 7e19eab: **manage-problem**: refresh `docs/problems/README.md` on every Step 7 status transition and stage it in the same commit (closes P062).

  Before this change, status transitions (Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed, Parked) did NOT refresh the README.md cache — only the `review` operation did. The next session's fast-path freshness check correctly detected the lag and forced a full rescan (self-healing but wasteful), and human readers browsing README.md between sessions saw outdated WSJF rankings and an incomplete Verification Queue.

  SKILL.md Step 7 now includes a dedicated "README.md refresh on every transition (P062)" block describing the mechanism (regenerate in-place with the new filename set and Status; stage in the same commit; update the "Last reviewed" parenthetical). Step 11 commit convention requires `docs/problems/README.md` in the transition commit's stage list — including folded-fix commits where the `.verifying.md` transition rides with a `fix(<scope>): ...` commit.

  The refresh is a render, not a re-rank: existing WSJF values on ticket files are trusted; no full re-scoring pass fires. That remains Step 9's job.

  Cache stays fresh by construction — the Step 9 fast-path freshness check should return empty on any invocation after a transition commit.

## 0.8.0

### Minor Changes

- 8788489: Add `/wr-itil:report-upstream` skill — file a local problem ticket as a structured upstream issue or private security advisory with bidirectional cross-references. Implements the contract in ADR-024 (Cross-project problem-reporting contract).

  The skill discovers upstream `.github/ISSUE_TEMPLATE/` via `gh api`, classifies the local ticket (bug / feature / question / security), picks the best-matching template (or falls through to a structured default when none exist), routes security-classified tickets via the upstream's `SECURITY.md` (GitHub Security Advisories, `security@` mailbox, or other declared channel — never auto-opens a public issue for a security-classified ticket), and back-writes a `## Reported Upstream` section + `## Related` line into the local ticket.

  Three distinct AFK branches are encoded in the skill: public-issue path proceeds (voice-tone gate per ADR-028 may delegate-and-retry); declared-channel security path proceeds via `gh api .../security-advisories`; missing-`SECURITY.md` security path saves the drafted report and halts the orchestrator (loop-stopping event per ADR-024 Consequences). Above-appetite commit-gate uses the ADR-013 Rule 6 fail-safe.

  Step-0 auto-delegation per ADR-027 is deliberately deferred — `report-upstream` is in ADR-027's "held for reassessment" set with the explicit note "narrow workflow; decided at implementation time". The skill's main-agent context is the right place to evaluate the security-path branch and surface the missing-SECURITY.md `AskUserQuestion`.

  Includes a doc-lint bats test (Permitted Exception per ADR-005) covering all five ADR-024 Confirmation criterion 2 assertions plus the architect-required ADR-027 / ADR-028 / three-AFK-branch documentation. Closes P055 Part B; P055 Part A (intake scaffolding) shipped earlier in the same session.

## 0.7.2

### Patch Changes

- f9bfa56: Fix the next-ID origin-max lookup in `manage-problem` Step 3 and `create-adr` Step 3 (P056). The prior bash pipeline ran `git ls-tree origin/main <path>/ | grep -oE '[0-9]{3}'` — default `git ls-tree` output includes the 40-char blob SHA, whose hex run can contain three consecutive decimal digits that the regex falsely matches (observed `origin_max=997` on 2026-04-20 opening P055). The fix adds `--name-only` to drop mode/type/SHA columns and pipes through `sed` to strip the path prefix, so the anchored `grep -oE '^[0-9]+'` only picks up real filename IDs. ADR-019's next-ID invariant and P043's collision guard both presume this pipeline is sound; this change restores the invariant. Two new bats doc-lint tests (8 assertions) guard the contract.
- 3bf2074: Document the `git mv` + Edit + `git add` staging-ordering trap (P057) in `manage-problem` Step 7 and `create-adr` Step 6. `git mv` alone stages only the rename — subsequent `Edit`-tool modifications must be re-staged explicitly (`git add <new>`) before commit. Without the re-stage, transition commits capture the rename but drop the `Status:` / `## Fix Released` content edits, which then leak into an unrelated later commit and corrupt the audit trail (observed 2026-04-19 in P054's `.verifying.md` transition).

  Changes:

  - `manage-problem` Step 7: new warning block applying to all three transition arrows (Open → Known Error, Known Error → Verification Pending, Verification Pending → Closed), plus an explicit `git add <new>` line in each code block.
  - `manage-problem` Step 11: commit convention now recommends `git add -u` as a safety-net for tracked modifications.
  - `create-adr` Step 6: supersession rename now instructs authors to `git add` the file again after the frontmatter + "Superseded by" edits.
  - Two new bats doc-lint tests guard the contract in both SKILL.md files.

## 0.7.1

### Patch Changes

- c5f8039: Add inter-iteration verification to `wr-itil:work-problems` AFK orchestrator (closes P036). After the release-cadence check and before the next iteration, the skill now runs `git status --porcelain` and halts the loop if the working tree is dirty for a reason not stated in the last iteration's report. This is defence-in-depth behind P035's fallback: it catches silent subagent commit failures (a failure inside the assess-release skill, a git conflict, a malformed commit message) that would otherwise accumulate across iterations and corrupt the final summary. Non-interactive default recorded in the decision table. Recovery is explicitly out of scope per ADR-013 Rule 6 — the check surfaces the bug, the user decides. Includes a 6-test doc-lint bats regression file.

## 0.7.0

### Minor Changes

- 151b993: manage-problem Verification Queue detection (P048, minimal-scope).

  - **Fast-path cache hit**: step 9d now explicitly fires even when
    `docs/problems/README.md` is fresh (candidate 1). Prevents the prior
    regression where verification prompts were suppressed on cache hit —
    which is exactly when the user is most likely to verify.
  - **Verification Queue presentation**: step 9c now emits a
    `Likely verified?` column in the Verification Queue with
    `yes (N days)` / `no (N days)` values based on release age
    ≥ 14 days (candidate 4). 14-day default documented as a within-skill
    tunable (architect review confirmed not policy-level yet).
  - Step 9d surfaces the highlighted (`yes`) tickets first in the
    verification prompt so the user can batch-close long-standing
    verifications.
  - 5 new structural bats assertions in
    `manage-problem-verification-detection.bats`; full project suite
    269/269 green (+5).
  - Candidates 2 (standalone `verify-fixes` op), 3 (exercise observation
    records — new file-level state dimension), and 5 (AFK-mode
    orchestrator hook) are deferred pending an architect ADR-scope
    decision.

## 0.6.0

### Minor Changes

- 4e93bcf: Add Verification Pending `.verifying.md` problem-lifecycle status per ADR-022
  (P049 — the SKILL.md contract half; existing-file migration follows in a
  separate commit per ADR-022 Scope).

  - **manage-problem SKILL.md**: lifecycle table gains Verification Pending
    status and `.verifying.md` suffix; WSJF multiplier table documents
    Verification Pending = 0 (excluded from dev ranking); Known Error →
    Verification Pending transition documented (git mv + Status field +
    `## Fix Released` in one commit per ADR-014); step 9b skips
    `.verifying.md` files; step 9c gains a Verification Queue section; step
    9d targets `*.verifying.md` via glob; step 9e README template gains the
    Verification Queue section; closing workflow and commit-convention
    prose updated.
  - **work-problems SKILL.md**: step 1 scan excludes `.verifying.md`; step 4
    classifier row `Known Error with ## Fix Released` → `.verifying.md`
    (suffix-based, no file-body scan).
  - **manage-incident SKILL.md**: step 9 linked-problem close gating accepts
    `.verifying.md` alongside `.known-error.md` and `.closed.md`.
  - **docs/problems/README.md**: "Known Errors (Fix Released — pending
    verification)" shadow table replaced with "Verification Queue" citing
    ADR-022.
  - 11 new structural bats assertions in
    `manage-problem-verification-pending.bats`; full project suite
    264/264 green (+11).

## 0.5.0

### Minor Changes

- a0600d9: Surface outstanding design questions at work-problems stop-condition #2 (P053).

  - Step 2 branches on stop-condition: #2 now routes to a new Step 2.5 before
    emitting `ALL_DONE`; #1 and #3 keep the direct-emit behaviour.
  - Step 2.5 extracts user-answerable questions from skipped tickets. In
    interactive invocations, batches up to 4 into one `AskUserQuestion` call
    per ADR-013 Rule 1 (Anthropic's documented per-call cap). In
    non-interactive / AFK invocations (the JTBD-006 persona default), emits
    an `### Outstanding Design Questions` table in the post-stop summary
    per ADR-013 Rule 6 fail-safe.
  - Step 4 classifier gains a skip-reason taxonomy column:
    `user-answerable` / `architect-design` / `upstream-blocked`. Step 2.5
    selects the user-answerable subset to surface.
  - Output Format template includes an `### Outstanding Design Questions`
    section (Ticket / Question / Context), emitted only when
    stop-condition #2 fires with ≥1 user-answerable skip.
  - Non-Interactive Decision Making table documents the AFK-default path.
  - 7 structural bats assertions added in
    `work-problems-stop-condition-questions.bats`; full project suite
    253/253 green (+7).

## 0.4.5

### Patch Changes

- 5c677cc: manage-problem: add XL effort bucket and effort re-rate pre-flight (P047)

  - Effort table in `manage-problem` SKILL.md gains an **XL** bucket (divisor 8) for multi-day or cross-package work, with a new sub-example showing how WSJF flattens at XL and a live-estimate note pointing to steps 7 and 9b.
  - **Step 7** Open → Known Error pre-flight gains a checklist item requiring the effort bucket to be re-rated against the now-documented fix strategy, with the reason captured in the problem file.
  - **Step 9b** step 7 reworded from "Estimate Effort" to "Re-estimate Effort (S / M / L / XL) ... note the reason in a short parenthetical" so the review re-rate is unmissable.
  - `work-problems` SKILL.md example paragraphs updated non-normatively to reference "S to L or XL" for consistency.
  - New doc-lint test `manage-problem-effort-buckets.bats` (4 assertions) guards the new contract.

## 0.4.4

### Patch Changes

- 39e026c: itil: governance skills auto-release when changesets are queued (P028)

  Extends the terminal commit step of `manage-problem` and `manage-incident`
  so non-AFK governance invocations drain the release queue automatically
  after their own commit lands, rather than ending at `git commit` and
  relying on the user to remember `npm run push:watch` and
  `npm run release:watch`.

  Mechanism (per new ADR-020):

  - After commit, delegate to `wr-risk-scorer:assess-release` (subagent
    `wr-risk-scorer:pipeline` with Skill fallback per ADR-015).
  - If `push` and `release` scores are both within appetite (≤ 4/25 per
    `RISK-POLICY.md`) AND `.changeset/` is non-empty, run
    `npm run push:watch` followed by `npm run release:watch`.
  - Fail-safe identical to ADR-018: stop on `release:watch` failure, no
    retry. Above-appetite risk skips the drain and reports clearly.
  - Skipped automatically when the skill is invoked inside an AFK
    orchestrator — those flows handle release cadence via ADR-018 Step 6.5
    and must not double-release.

  Scope matches ADR-014 (manage-problem, manage-incident). The remaining
  governance skills (`create-adr`, `run-retro`, `update-guide`,
  `update-policy`) inherit ADR-020 automatically once they adopt ADR-014.

  Splits the original P028 auto-install concern into P045 (deferred
  pending Claude Code in-session plugin reload). Closes P028 pending user
  verification.

## 0.4.3

### Patch Changes

- 359ec7c: ticket-creators: next-ID collision guard against origin (P043)

  Adds the next-ID collision guard from ADR-019 confirmation criterion 2 to
  both ticket-creator skills:

  - `manage-problem` step 3 (Assign the next ID): now computes max of
    local-max and `git ls-tree origin/<base>` max, then increments. Catches
    collisions between local work and parallel sessions before the ticket
    file is written.
  - `create-adr` step 3 (Determine sequence number): same mechanism applied
    to `docs/decisions/`.

  Both skills cite ADR-019 and log renumber decisions in the user-facing
  report. Sibling fix to P040 (work-problems Step 0 preflight, shipped in
  @windyroad/itil@0.4.2): preflight catches divergence at loop start; this
  ticket catches collisions at ticket-creation time as a defence in depth.

  Adds bats tests (3 assertions per skill) verifying ADR-019 references and
  the collision-guard pattern.

  Closes P043 pending user verification.

## 0.4.2

### Patch Changes

- 9c6019e: work-problems: add preflight to reconcile with origin before iteration (P040)

  Adds Step 0 (Preflight) to the work-problems AFK orchestrator per ADR-019.
  Before opening the work loop, the orchestrator now runs `git fetch origin`
  and compares local HEAD with `origin/<base>`. On trivial fast-forward
  divergence, it pulls non-interactively (`git pull --ff-only`). On
  non-fast-forward divergence (local has unpushed commits AND origin has
  advanced), it stops with a clear divergence report (`git log --oneline
HEAD..origin/<base>` and reverse). Non-interactive rebase or merge is
  explicitly forbidden — the persona requires user judgment for those.

  Network failure on `git fetch origin` defaults to fail-closed (stop and
  report); the user can retry when network is restored.

  Adds row to Non-Interactive Decision Making table covering origin
  divergence. Adds bats test (7 assertions) covering ADR-019 confirmation
  criteria: skill cites ADR-019; references `git fetch origin` and
  `pull --ff-only`; has discrete preflight step; non-interactive table
  covers it; explicitly forbids non-interactive merge/rebase.

  The next-ID collision guard (ADR-019 confirmation criterion 2) belongs in
  ticket-creator skills (manage-problem, wr-architect:create-adr) and is
  tracked in a separate problem ticket.

  Closes P040 pending user verification.

## 0.4.1

### Patch Changes

- 87c2ecf: work-problems: enforce inter-iteration release cadence (P041)

  Adds Step 6.5 (Release-cadence check) to the work-problems AFK orchestrator
  per ADR-018. After each successful iteration, the orchestrator now invokes
  `wr-risk-scorer:assess-release` (or its pipeline subagent) and, if `push` or
  `release` score is at or above appetite (4/25 per RISK-POLICY.md), drains
  the queue with `npm run push:watch` then `npm run release:watch` before
  starting the next iteration. The drain runs non-interactively per ADR-013
  Rule 6 (policy-authorised when within appetite). On `release:watch`
  failure, the loop stops and reports — no non-interactive retry.

  Also adds a row to the Non-Interactive Decision Making table covering the
  new behaviour, and a bats test asserting the SKILL.md references both
  `assess-release` and `release:watch` (ADR-018 confirmation criterion).

  Closes P041 pending user verification of the next AFK loop.

## 0.4.0

### Minor Changes

- a36a084: Add `wr-itil:work-problems` AFK batch orchestrator skill and document a commit-gate fallback in `wr-itil:manage-problem` (JTBD-006).

  - **New skill** `wr-itil:work-problems` — loops through ITIL problem tickets by WSJF priority, delegating each iteration to `wr-itil:manage-problem` non-interactively. Stops gracefully when nothing remains actionable. Emits `ALL_DONE` sentinel for external detection. Deterministic Step 4 classification rules (skip known-errors with Fix Released; work everything else).
  - **Fix** `wr-itil:manage-problem` commit gate now documents a two-path delegation (closes P035). Primary: delegate to `wr-risk-scorer:pipeline` subagent-type via the Agent tool. Fallback: invoke `/wr-risk-scorer:assess-release` via the Skill tool when the subagent-type is unavailable (e.g., when `manage-problem` is itself running inside a spawned subagent). Per ADR-015 both produce equivalent bypass markers. Non-interactive fail-safe preserved for the risk-above-appetite branch only — silent-skip for delegation-unavailable is no longer sanctioned.

## 0.3.3

### Patch Changes

- 83b8be7: fix(manage-problem): add Parked lifecycle status and README.md fast-path cache (closes P027)

  - Adds `.parked.md` suffix and Parked status to problem lifecycle table
  - `problem work` checks README.md freshness before triggering full 18-file re-scan
  - Step 9e writes/overwrites `docs/problems/README.md` after every full re-rank
  - Parked problems excluded from WSJF ranking; shown in separate Parked table

## 0.3.2

### Patch Changes

- 8a15336: Fix `--update` flag failing with "Plugin not found" (P025). The `updatePlugin` command was missing the `@windyroad` marketplace suffix and `--scope project`, causing all `npx @windyroad/<pkg> --update` invocations to fail. The correct command is now used: `claude plugin update "<name>@windyroad" --scope project`.

## 0.3.1

### Patch Changes

- e8216b1: Governance skills now commit their own completed work (P023, ADR-014).

  **@windyroad/itil**: `manage-problem` and `manage-incident` skills no longer end with "Do not commit — the user will commit when ready." They now instruct the agent to stage files, delegate to `wr-risk-scorer:pipeline` for a risk assessment, and commit automatically using a conventional commit message referencing the problem or incident ID. If risk is above appetite, an `AskUserQuestion` prompt is presented before committing. Non-interactive fail-safe per ADR-013 Rule 6.

  New ADR-014 documents the cross-skill commit pattern, commit message convention, and risk-gate delegation sequence.

## 0.3.0

### Minor Changes

- e5eb0bd: Add `manage-incident` skill for evidence-first incident response with automatic handoff to problem management.

  The new `/wr-itil:manage-incident` skill implements an ITIL-aligned incident workflow focused on **restoring service fast** while keeping a disciplined audit trail. Hypotheses must cite evidence before any mitigation. Reversible mitigations (rollback, feature flag, restart) are preferred over forward fixes. On restoration, the skill automatically invokes `manage-problem` to create or update the underlying root-cause ticket, linking the incident to a `P###`.

  Incidents use a separate `I###` namespace in `docs/incidents/` so lifecycles, prioritisation (severity for incidents, WSJF for problems), and audit trails stay clean. See ADR-011 and JTBD-201 for the full design.

### Patch Changes

- 23d0d10: Require structured `AskUserQuestion` prompts at all governance-skill decision branches (P021, ADR-013).

  **@windyroad/itil**: `manage-problem` skill now requires `AskUserQuestion` for WSJF tie-breaks, problem selection, and scope-change decisions. Prose "(a)/(b)/(c)" option lists are prohibited.

  **@windyroad/risk-scorer**: All three scorer agents (pipeline, wip, plan) now enforce below-appetite silence — no advisory prose, "Your call:", or suggestions when scores are within appetite. Above-appetite output uses structured `RISK_REMEDIATIONS:` blocks instead of free-text suggestions.

  New ADR-013 establishes the cross-cutting standard: every governance-skill branch point with ≥2 options must use `AskUserQuestion`; scoring agents stay pure output-only.

## 0.2.0

### Minor Changes

- 6eeef94: Rename `@windyroad/problem` → `@windyroad/itil` (plugin `wr-problem` → `wr-itil`, skill `/wr-problem:update-ticket` → `/wr-itil:manage-problem`). Makes room for peer ITIL skills (incident, change) under the same plugin. Hard rename, no shim — per ADR-010.

  **Migration**: if you had `@windyroad/problem` installed, uninstall it (`npx @windyroad/problem --uninstall`) then install `@windyroad/itil`. The skill command changes from `/wr-problem:update-ticket` to `/wr-itil:manage-problem`. `@windyroad/retrospective`'s dependency is updated automatically.

## 0.1.3

### Patch Changes

- 7ee97ba: Add README.md to every package and rewrite the root README with better engagement, problem statement, and project-scoped install documentation.

## 0.1.2

### Patch Changes

- eda2a15: Fix release preview to use pre-release versions (e.g., 0.1.2-preview.42) instead of exact release versions, preventing version collision with changeset publish.

## 0.1.1

### Patch Changes

- 3833199: Fix: bundle shared install utilities into each package so bin scripts work when installed via npx.
