# Problem 012: Skill Testing Harness Scope Undefined

**Status**: Open
**Reported**: 2026-04-16
**Priority**: 6 (Medium) — Impact: Moderate (3) x Likelihood: Possible (2)
**Effort**: XL — new companion ADR for skill testing strategy, per-skill test framework decisions, retrofit of existing skills across the entire suite (itil, retrospective, architect, risk-scorer, jtbd, voice-tone, style-guide, tdd, connect) (L → XL 2026-04-19 per P047: scope explicitly "undefined", suite-wide, new ADR required)
**WSJF**: 0.75 — (6 × 1.0) / 8
**Type**: technical

## Direction decision (2026-04-20, user — AFK loop stop-condition #2)

**ADR scope**: **New companion ADR**, not an ADR-005 amendment. Skills differ enough from hooks (LLM-interpreted prose vs executable bash) that the testing strategy deserves its own decision record (contract testing, golden outputs, skill-specific harness semantics). Mint the next free ADR ID at draft time.

Implication: Investigation Task "amend ADR-005 vs new companion ADR" is resolved. The companion ADR can be drafted as the next AFK iteration, with ADR-005 left as the hook-testing contract.

## Description

ADR-005 scopes `bats-core` testing to **hook** shell scripts (`packages/{plugin}/hooks/test/*.bats`). Skills — the markdown documents Claude interprets at runtime — have no testing strategy. All 23 existing `.bats` files test hooks; no skill has automated tests.

While introducing `manage-incident` (ADR-011), the question surfaced: what does "functional test of a skill" mean when the skill is prose-with-embedded-bash? Several options exist, each with trade-offs. A quick Option A-lite pattern (execute only the embedded bash fragments) was adopted for `manage-incident` as a holding pattern, but the broader question needs a proper decision before a second skill follows suit.

## Symptoms

- ADR-005 says nothing about skill tests.
- ADR-011 had to invent a test location and narrow the test scope to fit within ADR-005's letter, flagged by the architect as an Undocumented Decision.
- Structural SKILL.md assertions (required sections, frontmatter) are currently blocked by P011's source-grep ban — but SKILL.md contracts are arguably structural, not behavioural.
- No way today to catch contract drift between a skill and its documented interface beyond a single mocked handoff assertion.

## Workaround

`manage-incident` ships with Option A-lite tests: execute embedded bash fragments + mocked `Skill`-tool handoff contract, under `packages/itil/skills/manage-incident/test/`. This covers the mechanical parts but not the prose instructions Claude interprets.

## Impact Assessment

- **Who is affected**: plugin authors (JTBD-101), and tech-leads relying on auditability (JTBD-201).
- **Frequency**: Every new skill addition will hit this decision gap until resolved.
- **Severity**: Medium — no user-facing breakage, but test discipline across the suite drifts without a rule.
- **Analytics**: N/A.

## Root Cause Analysis

### Preliminary Hypothesis

ADR-005 was written when skills were thin and skill count was 1. The plugin suite has since grown to multiple skills, and ADR-010 explicitly signals more ITIL skills coming. ADR-005 needs to either extend its scope to skills or explicitly scope skills out and defer to a companion ADR.

### Investigation Tasks

- [ ] Survey all existing skills (`manage-problem`, `manage-incident`, `update-guide`, `setup-tests`, `run-retro`, `extend-suite`, `generate` for c4/wardley, `send`/`setup` for connect, `configure`/`access` for discord) — what fraction of each skill's logic is executable bash vs prose instruction?
- [ ] Decide: amend ADR-005 (add Skill Testing section) vs. new companion ADR
- [ ] Decide: are structural SKILL.md assertions a Permitted Exception to P011's source-grep ban?
- [ ] Decide: formalise `packages/{plugin}/skills/<name>/test/*.bats` as the skill-test location
- [ ] Decide: if logic needs to be testable beyond the bash fragments, extract to `packages/{plugin}/lib/` shell libraries (noting this conflicts with ADR-011's rejection of shared-lib extraction as premature)
- [ ] Create reproduction test (a SKILL.md contract assertion that fails today due to no harness)
- [ ] **Evaluate adopting Anthropic's `skill-creator` eval harness pattern** (https://github.com/anthropics/claude-plugins-official/blob/main/plugins/skill-creator/skills/skill-creator/SKILL.md). Materially expands the option space beyond bash-fragment execution + mocked handoff. Key elements to consider adopting:
  - `evals/evals.json` — prompts with `assertions` array, one eval case per scenario
  - `eval_metadata.json` per case, `grading.json` with load-bearing fields `text` / `passed` / `evidence` (viewer depends on these)
  - `scripts/aggregate_benchmark` → `benchmark.json` / `benchmark.md` with pass_rate, time, tokens, mean±stddev, delta
  - Dual-run pattern: spawn with-skill AND baseline (without-skill) subagents in the same turn; snapshot `old_skill` when improving. Captures differential value of the skill, not just absolute pass.
  - Workspace layout: `<skill>-workspace/iteration-N/eval-<name>/{with_skill,without_skill,old_skill}/outputs/`
  - Grader + analyzer subagents (`agents/grader.md`, `agents/analyzer.md`)
  - HTML review UI (`eval-viewer/generate_review.py`, `--static` for headless/CI)
  - Guidance: "make skill descriptions a little bit 'pushy'" (undertriggering); "keep SKILL.md under 500 lines"; "subjective skills are better evaluated qualitatively — don't force assertions"
- [ ] Add "Option: adopt Anthropic skill-creator eval harness" to the ADR so MADR's minimum-two-options rule is met with a stronger comparison (architect note).
- [ ] Design how centralised `~/.claude/skill-reports/<plugin>/` data (P034) feeds into eval cases — real-world skill outputs as ground-truth for improvement iterations across all plugins (architect, jtbd, itil, risk-scorer, voice-tone, style-guide, tdd, c4, wardley)
- [ ] Check P011's source-grep ban compatibility: a grader-subagent dual-run is functional/behavioural, not source-grep, so it is compatible with ADR-005's P011 clause (architect note).
- [ ] When resolving P012, flag ADR-005 with `[Reassessment Triggered]` — its own reassessment criterion ("If Claude Code adds a way to test agent behavior programmatically") is arguably now met by this upstream evidence (architect note).

## Decision record

**ADR-037** (Skill testing strategy — contract-assertion bats companion to ADR-005) — drafted 2026-04-21. Companion ADR per the pinned direction; does NOT supersede ADR-005. SKILL.md framed as a **contract document** (parallel to `hooks.json` in ADR-005). Contract-assertions on SKILL.md structural invariants (sections, cited ADRs, `allowed-tools` content, marker strings verbatim) are the sanctioned pattern. P011 source-grep ban preserved via the contract-vs-behavioural distinction. Anthropic's `skill-creator` eval harness evaluated as a first-class considered option and deferred with 7 named reassessment triggers. ADR-005 flagged `[Reassessment Triggered]` per this ticket's investigation task. Shared helper library at `packages/shared/test/skill-test-helpers.bash` via ADR-017 sync pattern. Retrofit tracked here.

This ticket (P012) remains **Open** as the execution tracker. Closes when:
- `packages/shared/test/skill-test-helpers.bash` lands with the baseline helper library.
- Every `@windyroad/*` skill has at least one `<skill>-contract.bats` (phased retrofit; ~10-15 new files across ~8 plugins).
- `packages/shared/test/skill-contract-coverage.bats` enforces coverage (with allowlist during Phase 1; allowlist removed at Phase 2).
- ADR-017 drift check for the helper library runs in CI.
- `@jtbd` / `@problem` traceability annotations land per ADR-025 inheritance.

## Related

- **ADR-037** — decision record for this ticket. Closes the design question.
- ADR-005 (`docs/decisions/005-plugin-testing-strategy.proposed.md`) — testing strategy to extend or amend
- ADR-011 (`docs/decisions/011-manage-incident-skill.proposed.md`) — adopted Option A-lite as a holding pattern pending this problem's resolution
- ADR-010 (`docs/decisions/010-rename-wr-problem-to-wr-itil.proposed.md`) — signals more skills coming, making this decision time-bound
- JTBD-101 (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`) — plugin authors need a clear pattern
- JTBD-201 (`docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md`) — auditability constraint
- Anthropic official `skill-creator` eval harness — https://github.com/anthropics/claude-plugins-official/blob/main/plugins/skill-creator/skills/skill-creator/SKILL.md (substantial prior art for testing SKILL.md documents)
- P034 (`docs/problems/034-centralise-risk-reports-for-cross-project-skill-improvement.open.md`) — centralised `~/.claude/skill-reports/<plugin>/` storage providing real-world output data as eval inputs for the skill-creator improvement cycle across all plugins (not just risk-scorer)
