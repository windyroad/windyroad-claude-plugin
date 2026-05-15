# @windyroad/voice-tone

## 0.5.0

### Minor Changes

- 0fda8a5: P038 voice-tone evaluator half of ADR-028 amended external-comms gate

  Ships the voice-tone half of the external-comms PreToolUse gate alongside the
  existing risk evaluator (P064 / commit a0713f3, 2026-04-26). When both plugins
  installed, both gates fire on the same outbound prose call (gh issue/pr/api,
  npm publish, .changeset/\*.md) and each denies until its own evaluator has
  emitted PASS. Composition at the firing level — per-evaluator markers, no
  shared composite marker (ADR-028 amendment 2026-05-14 ratifies the simplified
  design and supersedes the original combined-marker scheme).

  Adds:

  - packages/voice-tone/hooks/external-comms-gate.sh (byte-identical sync from
    packages/shared/hooks/external-comms-gate.sh)
  - packages/voice-tone/hooks/lib/leak-detect.sh (synced; voice-tone evaluator
    does NOT run leak pre-filter per EXTERNAL_COMMS_LEAK_PREFILTER=no in .conf)
  - packages/voice-tone/hooks/external-comms-evaluator.conf (per-package
    evaluator config — id + subagent + verdict prefix + assess skill + policy file)
  - packages/voice-tone/hooks/external-comms-mark-reviewed.sh (PostToolUse:Agent
    for subagent_type wr-voice-tone:external-comms; writes per-evaluator marker
    external-comms-voice-tone-reviewed-<KEY> on PASS)
  - packages/voice-tone/agents/external-comms.md (new subagent prompt;
    reviews drafts against docs/VOICE-AND-TONE.md; emits structured
    EXTERNAL_COMMS_VOICE_TONE_VERDICT + EXTERNAL_COMMS_VOICE_TONE_KEY)
  - packages/voice-tone/skills/assess-external-comms/SKILL.md (on-demand
    delegation skill per ADR-015)

  Changes:

  - packages/shared/hooks/external-comms-gate.sh — canonical hook now sources
    per-package external-comms-evaluator.conf (evaluator id + subagent type +
    verdict prefix + assess skill + policy file + leak-prefilter flag); marker
    filename includes evaluator id (external-comms-<id>-reviewed-<KEY>).
  - packages/risk-scorer/hooks/external-comms-gate.sh — synced byte-identical
    from canonical (now sources its own .conf).
  - packages/risk-scorer/hooks/external-comms-evaluator.conf — new per-package
    config for the risk evaluator.
  - packages/risk-scorer/hooks/risk-score-mark.sh — writes marker filename
    external-comms-risk-reviewed-<KEY> (was external-comms-reviewed-<KEY>).
  - scripts/sync-external-comms-gate.sh — CONSUMERS list adds voice-tone.
  - ADR-028 — ## Amendments section appended (2026-05-14); ratifies per-evaluator
    marker scheme, drops age_bucket and evaluator_set from marker key,
    documents per-package config file pattern.
  - ADR-015 — Scope table gains wr-risk-scorer:external-comms (retroactive — P064
    iter never landed the row) + wr-voice-tone:external-comms (P038).

  Test coverage (all behavioural per ADR-037 + P081):

  - packages/voice-tone/hooks/test/external-comms-gate.bats — 13 assertions
  - packages/risk-scorer/hooks/test/external-comms-gate.bats — extended to 13
  - packages/shared/test/external-comms-gate-canonical.bats — extended to 12
  - packages/shared/test/sync-external-comms-gate.bats — extended to 9

  Architect + JTBD reviews PASSED 2026-05-14 (ADR-028 amendment + ADR-015 update

  - implementation). Risk reviewer PASS (clean technical implementation doc; no
    Confidential Information class matched). BYPASS_RISK_GATE used for the
    changeset write because the risk-scorer agent cannot compute the exact sha256
    key (P166 — agents lack shell tool access for shasum) so the marker would not
    match the gate's computation; substantive review verdict PASS recorded above.

  Closes P038. ADR-028 remains proposed for one release cycle post-land per
  ADR-006 deliberation discipline.

## 0.4.0

### Minor Changes

- b60f576: P170 Phase 2 Slice 2.5 — hook exemption globs for the governance-managed story-map + story surfaces (ADR-060 § Phase 2 amendment 2026-05-12 lines 481-496). Adds path-based exemptions for `docs/story-maps/**/*.html` and `docs/stories/**/*.md` across four PreToolUse enforce-edit hooks:

  - `packages/architect/hooks/architect-enforce-edit.sh` — case-statement exemption alongside existing `docs/problems/` and `docs/jtbd/` entries
  - `packages/jtbd/hooks/jtbd-enforce-edit.sh` — same case-statement exemption pattern
  - `packages/style-guide/hooks/style-guide-enforce-edit.sh` — exemption short-circuit BEFORE the `*.css|*.html|*.jsx|...` opt-in extension check
  - `packages/voice-tone/hooks/voice-tone-enforce-edit.sh` — exemption short-circuit BEFORE the `*.html|*.jsx|...` opt-in extension check; closes the empirical block documented at P170 line 297 (STORY-MAP-001 bootstrap rejected on first HTML write)

  `packages/risk-scorer/hooks/risk-policy-enforce-edit.sh` left untouched — it gates only `RISK-POLICY.md` and never fires on story-maps/stories paths, so no exemption is needed (the ADR's "5 hooks" framing is structurally inaccurate at this surface; documented in commit body).

  Behavioural bats coverage (per ADR-052) across all four hooks: 6 new test cases each in architect-enforce-scope + jtbd-enforce-scope (extending existing files); new style-guide-enforce-scope.bats (5 cases) + new voice-tone-enforce-scope.bats (6 cases). 159 total tests across the four affected plugins' hook suites pass with zero regressions.

  Unblocks Phase 2 Slices 3-6 (story-map skills) and Slice 14 (STORY-MAP-001 bootstrap migration) per architect finding 1 on the P170 Phase 2 Slice 3 design review 2026-05-12 — these slices were blocked because their behavioural bats fixtures must perform HTML writes that the unmodified hooks rejected outright. Takes effect for adopters (including this repo) after the next marketplace release cycle + `/install-updates` + session restart.

## 0.3.1

### Patch Changes

- 1fe2cad: Gate markers now survive long-running Agent and Bash subprocesses (P111).

  A new PostToolUse hook (`*-slide-marker.sh`) fires on Agent and Bash tool
  completion in the parent session. If the parent already holds a valid gate
  marker, the hook touches it — sliding the TTL window forward — so the wall-
  clock time spent inside an Agent-tool subagent or a `claude -p` iteration
  subprocess no longer counts against the parent's TTL.

  The slide is bounded:

  - The hook only TOUCHES an existing marker. It NEVER creates one — creation
    still requires a real gate review with verdict parsing in
    `*-mark-reviewed.sh`.
  - The hook skips the touch when `tool_response.is_error` is true. A failed
    subprocess does not extend the parent's trust window.
  - For risk-scorer, only the score files (`commit`, `push`, `release`) are
    slid. The `*-born` markers are deliberately invariant under sliding so
    the 2×TTL hard-cap from P090 still bounds total marker life.

  This replaces the symptom-treatment of P107 (TTL bumped 1800s → 3600s) with
  the architectural fix per ADR-009's new "Subprocess-boundary refresh"
  subsection. Adopters who configured a non-default `ARCHITECT_TTL` /
  `REVIEW_TTL` / `RISK_TTL` envvar do not need to change anything.

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

## 0.2.1

### Patch Changes

- 8a15336: Fix `--update` flag failing with "Plugin not found" (P025). The `updatePlugin` command was missing the `@windyroad` marketplace suffix and `--scope project`, causing all `npx @windyroad/<pkg> --update` invocations to fail. The correct command is now used: `claude plugin update "<name>@windyroad" --scope project`.

## 0.2.0

### Minor Changes

- fe1b903: Gate markers now persist across prompts (ADR-009). Removed Stop-hook reset scripts from all 5 review plugins. Marker lifecycle is now governed entirely by TTL (30 min default, configurable via `*_TTL` env vars) + drift detection of policy files. Resolves P001 — reviews no longer need to re-run on every prompt. Note: this is a behaviour change; users who relied on fresh-review-every-prompt should set a shorter TTL.

## 0.1.4

### Patch Changes

- ec16630: Add project-root check to all enforce hooks (P004). Absolute file paths outside the current project (e.g., ~/.claude/channels/discord/access.json) are no longer gated — gates now only fire on files within the project root.

## 0.1.3

### Patch Changes

- 7ee97ba: Add README.md to every package and rewrite the root README with better engagement, problem statement, and project-scoped install documentation.

## 0.1.2

### Patch Changes

- eda2a15: Fix release preview to use pre-release versions (e.g., 0.1.2-preview.42) instead of exact release versions, preventing version collision with changeset publish.

## 0.1.1

### Patch Changes

- 3833199: Fix: bundle shared install utilities into each package so bin scripts work when installed via npx.
