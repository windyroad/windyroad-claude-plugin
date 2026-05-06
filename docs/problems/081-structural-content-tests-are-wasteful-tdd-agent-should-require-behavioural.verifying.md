# Problem 081: Structural source-content tests are wasteful — TDD agent should reject them and require behavioural tests (+ framework / stub enhancements)

**Status**: Verifying
**Reported**: 2026-04-21
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: L — TDD agent enhancement (new detection + suggestion surface) + testing-framework / stub / harness enhancements (so behavioural tests for LLM-interpreted skills are feasible at all) + amendment / supersession of ADR-005 Permitted-Exception and ADR-037 contract-assertion pattern + retrofit of existing structural bats across the suite (~50+ files across itil, retrospective, architect, risk-scorer, jtbd, voice-tone, style-guide, tdd, connect, discord packages). Architect review at implementation time to decide ADR shape (amend both vs supersede vs draft new) AND to scope the retrofit window (all-at-once vs per-skill-as-touched). L bucket reflects the reasonable-lower bound; may push to XL if the retrofit is bundled into one release, or scope-split across multiple phased tickets if the framework enhancements require new subagent types or Claude Code harness changes.

**WSJF**: 3.0 — (12 × 1.0) / 4 — High severity (every test we write going forward inherits the wrong style; every existing test is now suspect); large effort (framework changes + retrofit). Ranks in the 3.0-tier alongside P014 / P064 / P065. Above the 2.0 XL-tier tickets; below the 6.0 M-tier top-of-queue.
**Type**: technical

## Description

The project ships ~50+ bats files across plugin packages that follow the **structural contract-assertion pattern** blessed by `ADR-037` (skill testing strategy) and `ADR-005`'s Permitted-Exception carve-out. Each file greps its target SKILL.md (or ADR, or hook script) for specific content strings — "SKILL.md cites P077", "Step 5 names the Agent tool", "allowed-tools includes Agent" — and asserts the grep found a match.

User direction (2026-04-21 interactive, verbatim):

> tests that check the source code contents like the following are wasteful and not real tests. The TDD agent should fail these and suggest behavioural tests. The whole point of the tests is to test behaviour. If there are enhancements or changes needed in the testing framework or stubs, then the TDD agent should suggest them

This supersedes (or at minimum amends) ADR-005's Permitted-Exception and ADR-037's contract-assertion pattern. Going forward:

1. The TDD agent (the `wr-tdd` plugin's gate + review skills) must **detect** structural source-content tests when they are added and **reject** them.
2. The TDD agent must **suggest behavioural alternatives** — what the test should actually assert about the target's behaviour.
3. When the suggested behavioural test is not yet expressible under the current testing framework / stubs (e.g. a skill's behaviour depends on Claude interpreting SKILL.md prose and dispatching tool calls — not trivially unit-testable with bats), the TDD agent must **propose framework / stub / harness enhancements** that would make the behavioural test feasible.

A behavioural test for a skill asserts what the skill DOES when invoked — its tool-call sequence, its final artefact state, its output message — not what its SKILL.md SAYS. The two are correlated (SKILL.md is what Claude interprets) but a structural grep is strictly weaker: it confirms the author wrote certain words, not that Claude does the right thing when reading them. Structural assertions are "a prose-level sniff test" that pass on misleading phrasing, tautologically-worded contracts, and copy-paste drift as long as the keywords line up.

This gap composes with the open `P012` (skill testing harness scope undefined) and amends its direction: the harness we design must be BEHAVIOURAL-first, not structural-first. The user's 2026-04-20 direction on P012 was "new companion ADR (ADR-037)"; today's direction narrows ADR-037's scope from "structural contract-assertion as default" to "structural as last resort, behavioural as default".

## Symptoms

- Every skill ships with a bats file that greps its SKILL.md for keywords. The grep passes whenever the author types the expected phrase; it says nothing about whether Claude will do the right thing at runtime.
- Tests like `SKILL.md cites P077`, `SKILL.md Step 5 names the Agent tool`, `SKILL.md allowed-tools includes Agent` are **self-referential** — they pass iff the author wrote the required marker, not iff the skill exhibits the required behaviour.
- Contract drift is trivially easy: an author can change the SKILL.md prose in a way that passes the grep but changes the behaviour (e.g. "names the Agent tool" passes on any mention of "Agent tool", including `"Do NOT use the Agent tool"`).
- Regression detection is limited to "did someone delete the keyword from SKILL.md". Behavioural regressions (Claude interprets the skill differently after a version bump; a hook's script no longer honours the contract despite the SKILL.md saying it should; a skill's delegation target changed from `/wr-itil:manage-problem` to some other path) slip through.
- The `wr-tdd` plugin's Red-Green-Refactor gate currently has no opinion on structural tests — authors write them, they pass, gate advances. The plugin mistakes "keyword present" for "behaviour correct".
- Tests of this shape mislead human readers: someone reviewing a PR sees "19 tests pass" and assumes the skill is covered, when in reality nothing about its behaviour was exercised.
- **Block legitimate progressive-disclosure trims.** When authors compress SKILL.md prose (e.g. replacing a verbose heading with an equivalent shorter phrasing), the structural greps fire on the missing exact string and fail CI. Observed 2026-04-22 during the P098 `install-updates` SKILL.md trim: commit `c106e62` shortened Step 6 from "Sibling count > 3 — grouping fallback (P061)" to "Siblings > 3 (P061 `maxItems=4` fallback)" — a semantics-preserving compression — but the bats file `.claude/skills/install-updates/test/install-updates-consent-gate-sibling-cap.bats` greped for the verbatim longer phrase. CI run `24750456039` failed hook-tests step on 5 not-ok lines (718/719/721/722/723). Remediation commit `84c920e` restored the exact verbatim strings (`Sibling count > 3 — grouping fallback (P061)`, `caps \`maxItems\` at 4`, `name every detected sibling in the question body text`, `Sibling count ≤ 3`, `original contract applies`, `Either shape (≤ 3 or > 3 fallback) satisfies the ADR-030 Confirmation consent gate`). The compression trim was preserved around the restored strings, but the cost was one extra commit + one extra CI cycle + one risk-score round. This is the predicted failure mode: structural tests block semantics-preserving refactors that behavioural tests would ignore.

## Workaround

Accept the gap. Structural tests catch SOME drift (author deleted the keyword) and that's non-zero. But every structural test should carry a known-limitation note ("this is a content-present sniff test, not a behavioural assertion") and the Red-Green-Refactor cycle should demand a behavioural-test follow-up ticket on each. No such convention today — structural tests ship solo.

## Impact Assessment

- **Who is affected**:
  - **solo-developer persona** (`JTBD-001` — enforce governance without slowing down) — governance signals (test-green ≡ safe-to-commit) are trusted by the developer; structural-only tests make test-green an unreliable signal.
  - **plugin-developer persona** (`JTBD-101` — extend the suite) — downstream plugin authors inherit the wrong pattern when they copy the shipped contract-assertion bats as a template. The anti-pattern propagates.
  - **tech-lead persona** (`JTBD-201` — audit trail) — PR review, release assessment, and retrospective reviews all treat test-green as evidence of behaviour; structural-only evidence breaks that chain.
- **Frequency**: every new test. Every retrofit of an existing test. Every CI run that reports "477/477 green".
- **Severity**: High. Systematic misalignment of test-effort with test-value. Every structural test costs author + maintainer effort while delivering substantially less coverage than a behavioural test would.
- **Analytics**: N/A today. Post-fix candidate metrics: (1) ratio of structural-to-behavioural assertions in the shipped suite, (2) bugs caught by behavioural tests that structural tests missed, (3) TDD-agent-rejection count per week as a leading indicator of pattern adoption.

## Scope clarification (2026-04-27 — user direction)

The "TDD agent" in this ticket title is **literal**: a Claude Code agent definition under `packages/tdd/agents/`, NOT a hook with grep patterns. An earlier `/wr-itil:work-problems` AFK iter started building a grep-based PreToolUse hook; the user corrected: *"you can't detect the bad tests with grep — it needs to work with bats, vitest, cucumber, etc. You need an LLM to do this which is why I said 'agent'"* (P078 contradiction-signal pattern).

The structural-vs-behavioural distinction is **semantic** (what does the test assert?), not **syntactic** (what tokens appear?). It must work across at minimum: bats, vitest, jest, mocha, cucumber/`.feature`, pytest. A grep-based detector would catch this project's dominant case (bats greping SKILL.md) but would miss vitest tests that read SKILL.md via `fs.readFileSync` and assert on substrings, cucumber Then-steps that reduce to source-content checks, etc. LLM judgment is the only viable detection mechanism.

**Implementation plan**: see `## Implementation Plan` section below (drafted 2026-04-27 by the Plan agent). Plan covers: agent definition (`packages/tdd/agents/review-test.md`), invocation surface (recommend PostToolUse advisory + on-demand `/wr-tdd:review-test` skill — NOT PreToolUse blocking until Phase 3 retrofit completes), ADR-044 supersession of ADR-037, ADR-005 narrowing amendment (architect verdict 2026-04-27: Option B with scope adjustment), behavioural bats coverage (dogfood — no greps of agent source), per-framework exemplars in the agent prompt (bats / vitest / cucumber / pytest paired snippets), escape hatches (env var `WR_TDD_REVIEW_TEST=skip` + in-file comment `tdd-review: structural-permitted (justification: …)`), and four documented architectural trade-offs.

**Composes-with note**: P081 + P130 (`/wr-itil:work-problems` orchestrator presence-aware dispatch) both pioneer the "Claude Code agent for project-internal judgment" pattern. P081 lands the agent template + invocation surface conventions that P130 can reuse.

## Root Cause Analysis

### Structural

**ADR-005** (BATS hook testing) carves out a Permitted Exception to the source-grep ban for "structural assertions" — specifically, bats files asserting that hook scripts contain required safety constructs (e.g. `set -euo pipefail`). The exception was scoped narrowly but has been read as blanket permission for structural grep in general.

**ADR-037** (skill testing strategy — proposed) blessed the **contract-assertion pattern**: per-skill `test/*-contract.bats` files that grep SKILL.md for the skill's documented contract elements. This was chosen because "behavioural tests for LLM-interpreted skills are not trivially expressible" and structural-grep was the accessible alternative. The ADR explicitly named structural-grep as DEFAULT for skills, marking it as "a pragmatic lower bound pending a behavioural harness".

**`wr-tdd` plugin** ships a Red-Green-Refactor gate (TDD state tracked per test file) but has no opinion on the KIND of test being written. Structural-grep test files pass through the RED→GREEN→REFACTOR cycle same as behavioural ones. No detection, no suggestion, no framework-enhancement hinting.

**`bats-core` framework** provides file-level test isolation + setup/teardown + assertions. It does NOT provide stubs for Claude's interpretation, for Agent-tool invocations, for Skill-tool delegation, or for subagent return contracts. A behavioural test of a skill today would require:
- Simulating or running Claude against the SKILL.md + args
- Mocking or intercepting tool calls (Write / Edit / Bash / Skill / Agent)
- Asserting on tool-call sequences + final artefact state

None of that infrastructure exists. The shipped pattern (structural grep) is the path of least resistance — and it's what the codebase now does by default.

### Why the pattern was adopted

`P011` (grep-based bats tests fragile — closed) drove the initial tightening: grep on source code is a fragile coupling because renaming a function breaks the test even when the behaviour is unchanged. ADR-005's Permitted Exception was the compromise: structural grep is acceptable for things that ARE structural contracts (e.g. safety constructs in hook scripts, required sections in SKILL.md frontmatter). The exception stopped short of allowing arbitrary keyword-grep but that nuance was lost in practice — "structural grep is sometimes OK" became "structural grep is default for anything contract-like".

`P012` (skill testing harness scope undefined) identified the missing piece: behavioural testing of skills requires a harness that doesn't exist. The 2026-04-20 direction pin chose a companion ADR (ADR-037) but did not preclude a future amendment that raises the behavioural-testing bar.

`ADR-037` landed structural-grep-as-default because the alternative was "no tests at all". The direction today is: raise the bar — structural-grep is last resort, not default.

### Candidate fix

The work has three layers:

**Layer A: TDD agent detection + rejection + suggestion.**

`wr-tdd` plugin gains new behaviour in its gate + review surfaces:
1. **Detect** structural-grep patterns in new bats files (heuristic: `run grep ... "$SKILL_FILE"` / `"$HOOK_FILE"` / equivalent paths; assertion tests `$status -eq 0`; no `run <target-command>` that invokes the target skill/hook with arguments).
2. **Reject** new structural tests at gate time. The gate reports "This test appears structural (greps source content) rather than behavioural (exercises the target). Structural tests are wasteful per P081 + ADR-005 amended. Please write a behavioural test."
3. **Suggest** behavioural alternatives per test. For the specific target being tested, propose what the behavioural assertion should look like (e.g. "For skill X delegating via Skill tool: simulate invocation with known args and assert the Skill-tool call carries the expected target + arguments").
4. **Propose framework / stub enhancements** when the behavioural alternative is not yet expressible. Concrete examples: a subagent stub that returns a scripted ITERATION_SUMMARY; a Skill-tool invocation interceptor that captures `(target, args)` tuples; a Write/Edit recorder that asserts on final file state without touching the real filesystem.

**Layer B: Framework / stub / harness enhancements.**

Make behavioural testing feasible at all. Concrete candidates:
- **Skill-invocation harness** — a bats helper that loads a SKILL.md, runs it against a scripted model (either a stubbed LLM that executes the SKILL.md's embedded bash deterministically, OR a real Claude API call in a recording-mode CI environment), captures tool-call sequences, and returns them for assertion.
- **Tool-call interceptor** — mocks for `Skill`, `Agent`, `Write`, `Edit`, `Bash`, `AskUserQuestion` that return pre-scripted results and record the invocation parameters.
- **Subagent return stub** — for skills that spawn subagents (ADR-032 + P077), a stub that returns a pre-scripted summary block without actually spawning a subagent.
- **Filesystem sandbox** — a temp-dir-rooted filesystem for skills that create / rename / commit files; assertions on final tree state rather than on SKILL.md content.
- **AskUserQuestion stub** — a pre-scripted answer table for skills that branch on user answers.

The harness shape is `P012`'s scope. This ticket's Layer B is "flesh out the harness so Layer A's behavioural-test suggestions are actually expressible".

**Layer C: ADR-005 amendment + ADR-037 supersession (or amendment).**

- **ADR-005 Permitted Exception** — narrow the scope. Structural grep is still permitted for hook scripts' safety constructs (`set -euo pipefail`), but NOT for content-assertion on SKILL.md / ADR / prose documents. The exception becomes "hook-safety-construct-only", not "anything that looks structural".
- **ADR-037** — supersede or amend. The contract-assertion pattern becomes "permitted as a pragmatic last-resort when Layer B's harness cannot express the behavioural assertion, AND the skill's Review-documentation section explicitly cites the missing harness capability and links a P081-descendant ticket tracking the enhancement". Default flips from structural to behavioural.
- **New ADR (alternative)** — if the amendments are substantial, draft a new ADR (e.g. "Skill testing defaults to behavioural") that supersedes both ADR-005's Permitted Exception scope and ADR-037's contract-assertion default. Architect review decides ADR shape.

**Layer D: Retrofit of existing structural bats.**

~50+ existing files across plugin packages are now technically-debt. Retrofit strategy options:
1. **Big-bang retrofit** — one AFK sprint converts all structural bats to behavioural + harness-calls. High-effort, high-risk.
2. **Incremental-as-touched** — each skill's bats gets retrofitted the next time the skill is edited. Lower-risk, multi-release.
3. **Deprecation window** — existing structural bats continue to pass but get a "deprecated, not behavioural" warning annotation. Fails only on NEW structural tests. Eventually all deprecated-structural get retrofitted.

Architect review at implementation decides retrofit strategy.

### Lean direction

No direction pinned yet — architect review at implementation is required because the ADR-005 / ADR-037 change is substantive and the harness design (Layer B) is cross-cutting.

**Preferred starting shape** (subject to architect review):
- Layer A: ship first. TDD-agent detection + rejection + suggestion. No framework changes needed — it's a rule change in the TDD gate.
- Layer B: second. Framework enhancements rolled out per need. Bats helpers + stubs + harness primitives land as each skill retrofits or as each new skill wants behavioural tests.
- Layer C: alongside Layer A. ADR-005 amendment + ADR-037 supersession drafted as this ticket's architect-review outcome.
- Layer D: incremental-as-touched (Option 2). Big-bang retrofit is too risky; deprecation window is over-engineered. Each skill retrofits next time it's edited.

### Related sub-concerns

**Sub-concern 1**: hook scripts are different from skills. A hook is executable bash — behavioural testing is "run the hook, assert on exit code + stdout/stderr + side effects". ADR-005's Permitted Exception covers hook safety-construct structural checks, which stay valid (a `set -euo pipefail` assertion isn't replaceable by a behavioural test without re-running every hook under a test harness that knows the expected failure cases). This ticket's scope is primarily SKILL.md and ADR-prose grep, not hook safety-constructs.

**Sub-concern 2**: test-the-ADR-itself grep. Some bats files grep ADRs for specific clauses (e.g. `ADR-037 contract-assertion pattern`). These are meta-structural — asserting that the authoring discipline was followed. Architect review decides whether these are in-scope for rejection (probably yes — ADRs are prose documents like SKILL.md).

**Sub-concern 3**: policy-file grep (`RISK-POLICY.md`, `CLAUDE.md`, `PERMISSIONS.md`). These are neither hooks nor skills but policy documents. Same calculus as SKILL.md grep — wasteful without a behavioural binding. Architect review decides scope.

**Sub-concern 4**: bats-core limitation. bats is a shell test runner, not an LLM interpretation harness. Any serious behavioural testing of skills probably needs either (a) a new test runner purpose-built for LLM-interpreted prose, OR (b) a bats helper library that wraps a stubbed model or a real API call. Architect + P012 review decide.

**Sub-concern 5**: cost of behavioural tests. Real API calls cost tokens + latency; stubbed interpretation may drift from real Claude behaviour. Architect review decides: recording-mode fixture? deterministic stub? mix of both?

**Sub-concern 6**: retrospective application to this commit. This ticket's OWN reproduction test should be a BEHAVIOURAL test of the TDD agent's detection — not a structural grep of the TDD agent's SKILL.md. Architect review flags the shape of the first test this ticket's fix MUST pass.

### Investigation Tasks

- [ ] Architect review: decide ADR shape (amend ADR-005 + ADR-037 separately, amend ADR-037 while scoping ADR-005's Permitted Exception down, or new ADR that supersedes both). Decide retrofit strategy (big-bang / incremental / deprecation-window).
- [ ] Draft the ADR change(s). Land the new direction as the authoritative definition of "what counts as a meaningful test".
- [ ] Implement Layer A: TDD agent detection + rejection + suggestion surface. Hook fires at Write on new `*.bats` / `*.test.ts` / `*.spec.ts` files. Produces a structured rejection message with behavioural-alternative suggestion + framework-enhancement proposal.
- [ ] Implement Layer B: at least ONE framework primitive (e.g. Skill-tool invocation interceptor) so the rejection message has a credible "here's how to write the behavioural version" payload. Additional primitives land as subsequent tickets.
- [ ] End-to-end test the TDD agent: author a structural bats file; verify the agent rejects with the right suggestion shape. Author a behavioural test using the new framework primitive; verify the agent accepts.
- [ ] Retrofit strategy execution: pick Option 1/2/3 per architect; execute. Note: this is likely its own sibling ticket — do not conflate with the agent + framework work.
- [ ] Update the `wr-tdd` plugin's SKILL.md / CLAUDE.md documentation to describe the new rule. Future plugin authors land on the behavioural-default pattern.
- [ ] Update ADR-037's Confirmation bats — if ADR-037 itself has structural-grep assertions (which it does — it's one of the meta-structural offenders), they become the first retrofit candidates. Target the dogfood.
- [ ] Cross-check with P012 direction: P012's harness-definition scope narrows to behavioural-first; amend P012's direction record to reflect this session's refinement.
- [ ] Cross-check with P018 (TDD enforce BDD + Example Mapping) — composition possibility: BDD's behaviour-driven shape naturally aligns with this ticket's behavioural-default direction.

## Fix Released

P081 Layer A implemented in `@windyroad/tdd` 0.4.0 (2026-05-03 AFK iter 13):

- **ADR-052** (`docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md`) — supersedes ADR-037; behavioural tests are the default for skill testing; structural-grep on prose documents permitted only with documented justification + linked harness-gap ticket. Includes per-framework exemplars (bats / vitest / cucumber / pytest), Migration section for the ~50 existing structural bats (incremental-as-touched), and reassessment criteria for Phase-2 promotion to PreToolUse blocking.
- **ADR-037 superseded** — renamed to `037-skill-testing-strategy.superseded.md` with banner block + frontmatter `status: superseded` + `superseded-by: [052-...]`. Audit-trail preserved.
- **ADR-005 amended** — Permitted-Exception sub-clause added (excludes prose-document content greps; preserves hooks.json / file-existence / safety-construct exceptions); `[Reassessment Triggered 2026-05-03 per ADR-052]` flag in Reassessment Criteria.
- **`review-test` agent** at `packages/tdd/agents/review-test.md` — semantic test classifier; multi-framework; emits JSON-in-fenced-block verdict `{verdict, evidence, suggestion, harness_gap}`. `harness_gap` MUST cite a ticket ID or be `null` per ADR-026 grounding. Mechanical/silent classification per project CLAUDE.md P132 — never calls AskUserQuestion.
- **`tdd-review-test.sh`** at `packages/tdd/hooks/tdd-review-test.sh` — PostToolUse Edit|Write advisory hook. Silent on: non-test files, outside-PWD, env-skip, justification-comment, file-not-on-disk. Emits `additionalContext` directive on test-file writes telling assistant to invoke the agent.
- **`hooks.json` extended** — new entry registered alongside `tdd-post-write.sh` (composes; no modification of existing).
- **`tdd-review-test.bats`** at `packages/tdd/hooks/test/tdd-review-test.bats` — 15 behavioural tests covering all six advisory paths (test-file → directive; non-test → silent; env-skip → silent; bash-comment → silent; ts-comment → silent; outside-PWD → silent; non-existent-file → silent; advisory text mentions ADR-052 + both escape hatches; exit always 0). Dogfood: NO source greps. All 71 TDD hook tests GREEN.
- **Changeset** `@windyroad/tdd` minor (0.3.1 → 0.4.0) at `.changeset/p081-review-test-agent-and-hook.md`.

Architect review (PASS): both review rounds returned PASS / ISSUES-RESOLVED with all 6 prior issues incorporated (ADR numbering correction 044→052, supersession-banner mirroring ADR-027, Migration section in ADR-052, ADR-044 escape-hatch category citations, ADR-026 grounding for `harness_gap`, ADR-005 narrowing as additive sub-clause + parallel reassessment-triggered flag, ADR-035 scope-out for verdict store).

JTBD review (PASS): JTBD-001/101/201 anchors confirmed; JTBD-006 AFK-loop friction respected via mechanical-stage carve-out (no AskUserQuestion); JTBD-302/ADR-013 Rule 6 Phase-1-advisory shape matches the README-drift-advisory precedent set by ADR-051.

Layer B (framework primitives) and Layer D (retrofit of ~50 existing structural bats) remain out of this iter's scope. Layer B lands as harness-gap tickets descend from P012; Layer D is incremental-as-touched per ADR-052 Migration section.

Awaiting user verification that the PostToolUse advisory fires on next test-file edit and the agent returns a sane verdict.

## Related

- **P011** (`docs/problems/011-grep-based-bats-tests-fragile.closed.md`) — prior art on grep-based test fragility. This ticket extends P011's conclusion from "grep is fragile" to "grep is weak — prefer behavioural".
- **P012** (`docs/problems/012-skill-testing-harness.open.md`) — the testing-harness scope ticket. This ticket's Layer B narrows P012's direction to behavioural-first.
- **P018** (`docs/problems/018-tdd-enforce-bdd-example-mapping-principles.open.md`) — TDD enforce BDD + Example Mapping. Composes directly: BDD's Given-When-Then cadence IS the behavioural shape this ticket's rule demands.
- **P015** (`docs/problems/015-tdd-vague-gherkin-detection.open.md`) — TDD vague-Gherkin detection. Sibling concern in the TDD-agent-quality axis.
- **ADR-005** (`docs/decisions/005-bats-hook-testing.proposed.md`) — Permitted Exception scope narrows under this ticket's direction.
- **ADR-037** (`docs/decisions/037-skill-testing-strategy.proposed.md`) — contract-assertion pattern supersedes or amends under this ticket's direction.
- All existing `*-contract.bats` files across `packages/*/skills/*/test/` and `packages/*/hooks/test/` — retrofit candidates under Layer D.
- **JTBD-001**, **JTBD-101**, **JTBD-201** — personas whose test-green-means-safe contract this ticket restores.

## Session note (author)

This ticket was authored after the user flagged the pattern during manage-problem slice-4 halt recovery (2026-04-21 session). The slice-4 bats files I committed as the halt recovery ARE the kind of structural-grep tests this ticket identifies as wasteful — they're dogfood examples of the problem. When Layer A + Layer B ship, those files become the first retrofit candidates.

The user's frustration ("these are wasteful, not real tests") was a strong-signal correction. Per `P078` (assistant-offers-problem-ticket-on-user-correction) direction, that signal maps directly to this ticket's creation. `P078`'s implementation — when it ships — should surface this pattern automatically the next time a structural-grep bats file passes through Write/Edit without a paired behavioural test.

## Fresh Evidence (2026-04-23)

`packages/retrospective/skills/run-retro/test/run-retro-signal-vs-noise.bats` (P105) is a pristine example of the anti-pattern: 15 `@test` blocks, every assertion is `run grep -F` or `run grep -n` against `SKILL_MD`. It asserts presence of prose strings ("Signal | +2", "Noise | -1", "delete queue", "ADR-026") but says nothing about whether Claude, when prompted with the skill, actually performs a signal-vs-noise pass, scores entries correctly, or gates deletions behind AskUserQuestion. The test passes on misleading phrasing and fails on semantics-preserving compression — exactly the failure mode predicted in the Symptoms section.

This is not isolated to this project. The user reports similar structural-test proliferation in `../bbstats`.

## Alternative Framework Direction

Anthropic's `skill-creator` evaluation framework (https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md) provides a behavioural-first testing pattern that is directly applicable:

- **Parallel A/B subagent runs** (`with_skill/` vs `without_skill/` vs `old_skill/`) — exercises the skill's actual behaviour by spawning real Claude sessions against realistic prompts, then comparing outputs.
- **Quantitative assertions** on objectively verifiable results — pass rates, timing, token deltas — surfaced in `evals/evals.json` and aggregated into `benchmark.json` / `benchmark.md`.
- **Human-in-the-loop eval viewer** for subjective/behavioural assessment where quantitative assertions are insufficient.
- **Grading subagent** produces structured `grading.json` with `text`, `passed`, and `evidence` fields.

For this project's skill-testing needs, the Anthropic pattern suggests:
1. **Eval prompts** that exercise the skill end-to-end (e.g. "run a retrospective on this briefing state" for `run-retro`).
2. **Assertions on tool-call sequences** — did the skill invoke Write, Edit, Bash, Skill, Agent in the expected order?
3. **Assertions on artefact state** — did the skill produce the expected file changes, README updates, or problem transitions?
4. **Baseline comparison** — old skill vs new skill on the same prompt, measuring regression/progression.

This is Layer B's concrete shape. The TDD agent should reference this framework when proposing behavioural alternatives to structural tests.

## Implementation Plan

> Drafted 2026-04-27 by the Plan agent during a `/wr-itil:work-problems` session, after user clarification: structural-vs-behavioural test detection requires LLM judgment (not grep) because the distinction is semantic and must work across bats / vitest / cucumber / jest / pytest / .feature files.

### Plan §1 — Agent definition

Create `packages/tdd/agents/review-test.md` (NEW — `agents/` directory does not yet exist in `packages/tdd/`; `package.json` already lists `agents/` in `files`, so the npm packaging is ready).

Frontmatter shape (mirrors `packages/architect/agents/agent.md`):

```yaml
---
name: review-test
description: Classifies a test file as STRUCTURAL (asserts source content of SKILL.md / ADR / hook / agent / policy prose) or BEHAVIOURAL (exercises the target and asserts on its outputs/side-effects/tool-calls). Returns a verdict, evidence, and a behavioural-alternative suggestion. Use after a test file is added or modified, or on demand via /wr-tdd:review-test. Multi-framework: bats, vitest, jest, mocha, cucumber/.feature, pytest.
tools: [Read, Glob, Grep]
model: inherit
---
```

Body sections (cap ~400 lines):

1. **Role** — semantic test classifier; LLM judgment, not regex.
2. **Inputs** — test file path(s) + optional target file (skill/hook/ADR) inferred from sibling layout.
3. **Detection method** — read full test source; for each `@test` / `it()` / `Scenario:` / `def test_…`, identify the assertion target. STRUCTURAL when the assertion's content reduces to "source string X appears in document Y" where Y is prose (SKILL.md, ADR, RISK-POLICY.md, *.proposed.md, agent.md). BEHAVIOURAL when assertion observes target invocation outputs, exit codes, written artefacts, captured tool-calls, or final filesystem state.
4. **Per-framework exemplars** (the prompt-training core) — paired snippets:
   - **bats** STRUCTURAL `run grep -F "string" "$SKILL_MD"` vs BEHAVIOURAL `run bash "$HOOK" <<<"$json"; [ "$status" -eq 2 ]`.
   - **vitest** STRUCTURAL `expect(readFileSync('SKILL.md','utf8')).toContain('Step 5')` vs BEHAVIOURAL `expect(await runSkill(input)).toMatchObject({...})`.
   - **cucumber** Then-step that greps a doc vs Then-step asserting world.lastOutput.
   - **pytest** `assert "Step 5" in open('SKILL.md').read()` vs `assert run_skill(args).artefact == expected`.
   - **shell** ad-hoc `grep -q ... && echo PASS`.
5. **Verdict shape** — JSON-in-fenced-block: `{verdict: "structural"|"behavioural"|"mixed"|"unclear", evidence: [{test_name, line, why}], suggestion: "…", harness_gap: "…"|null}`.
6. **Escape hatch recognition** — accept tests carrying the comment `# tdd-review: structural-permitted (justification: …)` (or `// tdd-review: …`) and emit `verdict: "structural-justified"`. Surfaces the existing-bats migration path without auto-failing.
7. **Output formatting** — ADR-013 Rule 1 interactive default; Rule 6 AFK fail-safe.

### Plan §2 — Invocation surface (recommend B+C combined)

Three options:

- **A. PreToolUse hook routes test-file edits to the agent** — blocks Write of `*.bats` / `*.test.*` / `*.spec.*` / `*.feature` until the agent emits a non-structural verdict. Highest safety; risks blocking refactors of existing structural tests.
- **B. PostToolUse hook scans + emits warning context** — agent runs after Write, verdict surfaces as `additionalContext`; non-blocking. Lowest friction.
- **C. On-demand `/wr-tdd:review-test` skill** — author or pre-release explicit invocation; zero auto-trigger.

**Recommend B + C combined**: PostToolUse non-blocking surfaces the verdict every time a test file lands, on-demand skill exists for batch retrofit work (Phase 3). PreToolUse blocking (A) is too coarse while ~50 existing structural bats remain in-tree. Add env-var escape hatch `WR_TDD_REVIEW_TEST=skip` for AFK loops + retrofit branches.

PostToolUse hook delegates to the agent via Agent-tool invocation through a context message (matches `wr-architect:review-design` pattern). Hook detects "test file just written" and emits a context block telling the assistant to invoke `review-test` agent.

### Plan §3 — ADR work (architect verdict 2026-04-27)

**New ADR-044** (`docs/decisions/044-behavioural-tests-default-for-skill-testing.proposed.md`) — sections per MADR 4.0:

- frontmatter: `supersedes: [037-skill-testing-strategy]`, `consulted: [wr-architect:agent]`, `reassessment-date: 2026-10-26`.
- Context: P081 user direction; structural greps caught dominant case but missed semantically-drifted prose; ADR-037 contract-assertion default reverses.
- Decision drivers: JTBD-001/101/201; P081; ADR-037 supersession.
- Considered options: (1) supersede ADR-037, (2) amend ADR-037 in place, (3) status quo. Pick (1).
- Decision outcome: behavioural-default; structural permitted only with documented justification comment + linked harness-gap ticket.
- Behavioural exemplars across frameworks (one snippet each: bats, vitest, cucumber, pytest).
- Documented-justification escape hatch: exact comment shape recognised by the agent.
- Migration note: Phase 3 retrofit of ~50 existing structural bats deferred to per-skill incremental retrofits as each skill is touched.
- Reassessment criteria: when behavioural harness primitives mature; when existing-structural-bats ratio drops below threshold.

**ADR-005 amendment** — append one paragraph to "Permitted exceptions" section: *"The Permitted Exception clause excludes SKILL.md, agent.md, *.proposed.md, RISK-POLICY.md, and other prose-document content greps. See ADR-044 (Behavioural-tests-default for skill testing). Hook-script safety-construct structural greps (e.g. `set -euo pipefail` presence) remain permitted."* Do NOT supersede ADR-005 — its hook-testing authority is unaffected.

### Plan §4 — Hook integration

Add PostToolUse Edit|Write entry in `packages/tdd/hooks/hooks.json` pointing to a new `packages/tdd/hooks/tdd-review-test.sh`. The hook:

1. Reads tool input JSON, extracts `file_path`.
2. Returns immediately if file extension is not `.bats` / `.test.{ts,tsx,js,jsx,py,rb}` / `.spec.{…}` / `.feature` or path is outside `$PWD`.
3. Returns immediately if `WR_TDD_REVIEW_TEST=skip` set.
4. Returns immediately if file contains `tdd-review: structural-permitted` justification comment.
5. Emits `additionalContext` block telling assistant to invoke `review-test` agent against changed file before continuing.

Composes with existing `tdd-post-write.sh` rather than modifying it (separation of concerns: post-write owns RGR state; review-test owns kind-of-test classification).

### Plan §5 — Bats coverage (dogfood — behavioural)

`packages/tdd/hooks/test/tdd-review-test.bats`:

- Feed JSON with `.tool_input.file_path` pointing at fixture `.bats` file → assert hook stdout contains expected `additionalContext` directive.
- Feed JSON for non-test file → assert no output.
- Feed JSON with `WR_TDD_REVIEW_TEST=skip` env → assert no output.
- Feed JSON for file containing justification comment → assert no output.
- Behavioural shape per ADR-005's `run_hook_with_file` pattern. NO greps of `tdd-review-test.sh` source. NO greps of `review-test.md` agent source.

Direct agent behavioural testing (`packages/tdd/agents/test/review-test-classification.bats`) deferred — requires harness P012 / P081-Phase-2 will build.

### Plan §6 — Changeset

`@windyroad/tdd` — **minor bump** (0.3.1 → 0.4.0). New agent + new hook + new on-demand skill = additive feature surface, no breaking change.

### Plan §7 — Critical files

- `packages/tdd/agents/review-test.md` (NEW)
- `packages/tdd/hooks/tdd-review-test.sh` (NEW)
- `packages/tdd/hooks/hooks.json` (extend PostToolUse Edit|Write array)
- `docs/decisions/044-behavioural-tests-default-for-skill-testing.proposed.md` (NEW)
- `docs/decisions/005-plugin-testing-strategy.proposed.md` (one-paragraph amendment)
- `packages/tdd/hooks/test/tdd-review-test.bats` (NEW dogfood behavioural test)

Reference patterns: `packages/architect/agents/agent.md` (agent prompt shape), `packages/risk-scorer/agents/pipeline.md` (mode-specific agent precedent), `packages/tdd/hooks/tdd-post-write.sh` (PostToolUse pattern).

### Plan §8 — Architectural trade-offs

**Trade-off 1 — Invocation surface**: Recommend PostToolUse advisory + on-demand skill. PreToolUse blocking too coarse during retrofit window. Promote after Phase 3 completes.

**Trade-off 2 — Agent dispatch**: Recommend Agent-tool delegation via context-message pattern (matches `review-design`). Direct sub-process LLM calls would need the hook to ship API credentials + handle network failures + respect rate limits — out of scope for a hook script.

**Trade-off 3 — ADR shape**: Architect: supersede ADR-037 (its "SKILL.md as contract document" framing is the entire reversed premise). Amend ADR-005 with one-paragraph carve-out (its hook-testing authority is unaffected). Asymmetry is correct.

**Trade-off 4 — Existing-test escape hatch**: Recommend BOTH env var (`WR_TDD_REVIEW_TEST=skip` for AFK / retrofit) AND in-file comment (`tdd-review: structural-permitted (justification: …)` for permanent permitted-structural cases). Marker files would orphan on commit and add invisible state — reject.

### Implementation order

1. Land ADR-044 + ADR-005 amendment first (architecture in place before code references it).
2. Author `packages/tdd/agents/review-test.md` (agent prompt) — review against per-framework exemplars in §1.4.
3. Author `packages/tdd/hooks/tdd-review-test.sh` + extend `hooks.json` (invocation surface).
4. Author `packages/tdd/hooks/test/tdd-review-test.bats` behavioural fixture.
5. Add changeset `@windyroad/tdd` minor.
6. Commit per ADR-014 — likely 2-3 commits depending on review-skill split.
7. Drain via Step 6.5 (push:watch + release:watch) once cumulative push/release risk converges within appetite.

### Reassessment

If, after Phase 1 lands, the PostToolUse-advisory surface is observed to be widely IGNORED (assistant skips invoking `review-test` on most test edits), promote to PreToolUse blocking (Option A) — but only after Phase 3 retrofit completes. Track this as P081 follow-up.
