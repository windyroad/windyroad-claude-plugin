# @windyroad/tdd

## 0.4.0

### Minor Changes

- d639f1f: P081 Layer A — behavioural-tests-default for skill testing.

  Adds the `review-test` agent at `packages/tdd/agents/review-test.md` that
  classifies test files (bats / vitest / cucumber / pytest / etc.) as
  structural (asserts source-prose content) or behavioural (exercises the
  target). Adds a PostToolUse Edit|Write advisory hook
  `tdd-review-test.sh` that emits an `additionalContext` directive after
  each test-file write, telling the assistant to invoke the agent.

  Two escape hatches per ADR-052:

  - `WR_TDD_REVIEW_TEST=skip` env var (ADR-044 category 3 strategic
    one-time override) — silences advisories for the session.
  - In-file comment `tdd-review: structural-permitted (justification:
<ticket>)` (ADR-044 category 2 deviation approval) — silences
    advisories for that specific file when the behavioural alternative
    is not yet expressible under the current harness primitives.

  Companion ADRs in `docs/decisions/`:

  - ADR-052 (proposed) — behavioural-tests-default for skill testing,
    supersedes ADR-037.
  - ADR-037 — superseded; banner block points readers to ADR-052.
  - ADR-005 — Permitted-Exception scope narrowed to exclude
    prose-document content greps; hook-script safety-construct
    exception preserved.

  Phase 1 advisory only. Promotion to PreToolUse blocking is named in
  ADR-052 reassessment criteria.

## 0.3.1

### Patch Changes

- d59dae1: P096 Phase 2 — `tdd-post-write.sh` (PostToolUse Edit|Write) silenced on no-signal emissions:

  - **Silent on GREEN unchanged**: when `OLD_STATE == NEW_STATE == GREEN`, exit 0 with zero stdout. The assistant already knows the file passes; re-emitting the STATE UPDATE block adds no signal.
  - **RED test-output hash dedupe**: hash the last-50-lines test output keyed by `/tmp/tdd-stdout-hash-${SESSION_ID}-${ENCODED_TEST}`; on match, emit `Test output unchanged from previous emission (hash match).` in place of the full body. Suppresses duplicate failure output across consecutive RED edits of the same impl file.
  - **Drop GREEN ACTION line**: the standing "Tests are passing... You may refactor..." prose is content the assistant already has from the STATE UPDATE block. RED + BLOCKED ACTION lines retained (they carry actionable next-step signal).

  Estimated session injection-byte savings: -1 to -15 KB per typical session, dominated by `tdd-post-write.sh` cumulative reduction.

  7 new behavioural bats tests (`packages/tdd/hooks/test/tdd-post-write-phase2.bats`) cover silent-on-GREEN-unchanged, hash dedupe both branches, GREEN-transition no ACTION line, RED ACTION line preservation, empty-session-id fallback. All green.

  Refs: P096, P095 (session-marker), ADR-038 (progressive disclosure).

## 0.3.0

### Minor Changes

- db104da: P095 — UserPromptSubmit hooks across all five windyroad plugins now emit the full MANDATORY instruction block only on the first prompt of a session; subsequent prompts emit a ≤150-byte terse reminder. Reclaims ~120KB / ~30k tokens per 30-turn session in a 3-active-hook project (~80% of the prior per-prompt hook preamble). Detection and enforcement semantics are unchanged — the `PreToolUse` edit gate remains the enforcement surface; only the reminder prose is gated.

  **New:**

  - Canonical helper `packages/shared/hooks/lib/session-marker.sh` with `has_announced` + `mark_announced` functions (empty-SESSION_ID fallback: no-op, never crashes).
  - Five per-plugin byte-identical copies at `packages/<plugin>/hooks/lib/session-marker.sh` for `architect`, `jtbd`, `tdd`, `style-guide`, `voice-tone`. Distributed via `scripts/sync-session-marker.sh` with `--check` mode + `npm run check:session-marker` + CI step per ADR-017 / ADR-028.
  - ADR-038 "Progressive disclosure + once-per-session budget for UserPromptSubmit governance prose" codifies the pattern, the marker-path convention (`/tmp/${SYSTEM}-announced-${SESSION_ID}`), the ≤150-byte per-prompt budget, the four-element terse-reminder shape (MANDATORY signal word + gate name + trigger artifact + delegation affordance), and the `tdd-inject.sh` dynamic-state carve-out.

  **Changed:**

  - `packages/architect/hooks/architect-detect.sh` — gates the full MANDATORY ARCHITECTURE CHECK block behind `has_announced "architect" "$SESSION_ID"`; subsequent prompts emit `MANDATORY architecture gate active (docs/decisions/ present). Delegate to wr-architect:agent before editing project files.` Absent-`docs/decisions/` branch unchanged.
  - `packages/jtbd/hooks/jtbd-eval.sh` — same pattern for the JTBD CHECK; terse reminder cites `docs/jtbd/ present` and `wr-jtbd:agent`. Absent-`docs/jtbd/README.md` branch unchanged.
  - `packages/tdd/hooks/tdd-inject.sh` — special case per ADR-038 carve-out: static prose (STATE RULES table, WORKFLOW, IMPORTANT) is gated; dynamic TDD state (IDLE/RED/GREEN/BLOCKED) and tracked test files list emit every prompt. No-test-script fallback branch unchanged.
  - `packages/style-guide/hooks/style-guide-eval.sh` — same pattern; terse reminder cites `docs/STYLE-GUIDE.md present` and `wr-style-guide:agent`.
  - `packages/voice-tone/hooks/voice-tone-eval.sh` — same pattern; terse reminder cites `docs/VOICE-AND-TONE.md present` and `wr-voice-tone:agent`.

  **Tests (bats):**

  - `packages/shared/test/session-marker.bats` — 9 unit tests for the helper.
  - `packages/shared/test/sync-session-marker.bats` — 6 drift-check tests.
  - `packages/architect/hooks/test/architect-detect-once-per-session.bats` — 8 behavioural tests.
  - `packages/jtbd/hooks/test/jtbd-eval-once-per-session.bats` — 8 behavioural tests.
  - `packages/tdd/hooks/test/tdd-inject-once-per-session.bats` — 8 behavioural tests, including the dynamic-state carve-out assertion.
  - `packages/style-guide/hooks/test/style-guide-eval-once-per-session.bats` — 7 behavioural tests.
  - `packages/voice-tone/hooks/test/voice-tone-eval-once-per-session.bats` — 7 behavioural tests.
  - Full suite: 735/735 green.

  Backward-compatible for consumers: first-prompt output is byte-identical to the pre-change behaviour; only the second+ prompts see the terse reminder. Downstream tooling that parses the MANDATORY block text (none known) would still see the full text on the first prompt.

  Closes P095. Transitions the ticket from `.known-error.md` to `.verifying.md` per ADR-022.

## 0.2.3

### Patch Changes

- a3813d6: Fix TDD gate to recognise Cucumber `.feature` files as tests (closes P013).

  - `tdd_classify_file()`: adds `*.feature` to test classification — writing a `.feature` file now transitions TDD state from IDLE to RED, enabling BDD/Cucumber projects to participate in the Red-Green-Refactor cycle without fake `*.test.js` wrappers
  - `tdd_find_test_for_impl()`: adds Cucumber pair-detection — step definition files in `step_definitions/` directories associate with the matching `.feature` file in the parent directory (e.g. `features/step_definitions/checkout.steps.js` → `features/checkout.feature`)

## 0.2.2

### Patch Changes

- 8a15336: Fix `--update` flag failing with "Plugin not found" (P025). The `updatePlugin` command was missing the `@windyroad` marketplace suffix and `--scope project`, causing all `npx @windyroad/<pkg> --update` invocations to fail. The correct command is now used: `claude plugin update "<name>@windyroad" --scope project`.

## 0.2.1

### Patch Changes

- ec16630: Add project-root check to all enforce hooks (P004). Absolute file paths outside the current project (e.g., ~/.claude/channels/discord/access.json) are no longer gated — gates now only fire on files within the project root.

## 0.2.0

### Minor Changes

- c980e8c: Per-test-file TDD state tracking, scoped test runs, and deadlock fix

  - State is now tracked per test file instead of globally — a failing Countdown test no longer blocks editing Hero
  - PostToolUse runs only the relevant test file after writes, not the full suite
  - Only timeout (exit 124) transitions to BLOCKED; all other non-zero exits become RED, fixing the deadlock where importing a non-existent component would block creating it
  - Enforcement hook checks the associated test's state for each impl file independently
  - Inject hook displays per-file states with test file identification
  - New functions: tdd_find_test_for_impl, tdd_read_state_for_impl, tdd_get_all_states, tdd_suggest_test_path, tdd_run_test_file

## 0.1.4

### Patch Changes

- 7ee97ba: Add README.md to every package and rewrite the root README with better engagement, problem statement, and project-scoped install documentation.

## 0.1.3

### Patch Changes

- adbd9e6: Fix TDD setup skill chicken-and-egg problem: allow edits during test setup by checking a PostToolUse:Skill marker, and fix skill name reference from wr-tdd:create to wr-tdd:setup-tests

## 0.1.2

### Patch Changes

- eda2a15: Fix release preview to use pre-release versions (e.g., 0.1.2-preview.42) instead of exact release versions, preventing version collision with changeset publish.

## 0.1.1

### Patch Changes

- 3833199: Fix: bundle shared install utilities into each package so bin scripts work when installed via npx.
