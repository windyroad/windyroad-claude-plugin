# Problem 141: AFK iter `packages/<plugin>/` commits without changesets — orchestrator-main-turn back-fill is fragile recovery, hook-level enforcement preferable

**Status**: Verification Pending
**Reported**: 2026-04-29
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3) — observed twice in single session (40% miss rate across 5 publishable iters)
**Effort**: M — new PreToolUse:Bash hook matching `git commit`; deny when staged diff includes `packages/<plugin>/` files but `.changeset/<plugin>-*.md` is not staged. Plus matching behavioural bats per ADR-005 + P081 (architect verdict 2026-05-02: ADR-005 is the plugin-testing-strategy ADR; ADR-037 is skill-scoped, not applicable to hook bats).
**WSJF**: (9 × 2.0) / 2 = **9.0**
**Type**: technical

> Surfaced 2026-04-28 / 2026-04-29 across the long `/wr-itil:work-problems` AFK loop session: iter 2 (P130 commit `b9da37e`) shipped `packages/itil/skills/work-problems/SKILL.md` + new bats without authoring `.changeset/wr-itil-p130-*.md`. Orchestrator main-turn back-filled at `dcc65b4`. Iter 7 (P134 commit `a8b6f18`) shipped 5-SKILL changes + new advisory script + 13 new bats without changeset. Orchestrator back-filled at `ac2425e`. Pattern: 2/5 publishable iters omitted changesets. Recovery cost: ~2× orchestrator main-turn commits + ~$2 risk-scorer round-trips per recovery.

## Description

`/wr-itil:work-problems` iteration subprocesses (per ADR-032 subprocess-boundary variant) are dispatched with explicit `manage-problem` SKILL.md guidance to author changesets. The iter prompt template even includes a "CHANGESET DISCIPLINE" reminder. Despite this, ~40% of publishable iters in the 2026-04-28 session omitted changesets — the prompt-time reminder is insufficient.

The recovery pattern (orchestrator main-turn back-fill) is:
1. Step 6.5 risk-scorer detects the missing changeset (or it goes undetected until release-time)
2. Orchestrator main turn writes a `.changeset/wr-<plugin>-<ticket>-*.md` file from session evidence
3. Risk-scorer rescore + commit gate
4. Commit "docs(orchestrator-repair): add missing P<NNN> changeset for <SHA>"
5. Continue loop

This works but:
- Adds ~5 min per recovery
- Splits one logical fix across 2 commits (the original iter commit + the back-fill)
- Relies on the orchestrator noticing — silent omissions could ship to npm without the changelog entry

A PreToolUse:Bash hook on `git commit` that detects the pattern and denies with a clear directive would prevent the omission at the source.

## Symptoms

- Iter commit lands `packages/<plugin>/` files without `.changeset/<plugin>-*.md` in the same commit
- Orchestrator's Step 6.5 risk scorer or main-turn observation catches it (sometimes)
- Recovery requires 1-2 additional orchestrator main-turn commits
- Cumulative session cost: 2 back-fills × ~5min = 10min wall-clock + ~$4 across this session
- Pattern recurs across multiple sessions

## Workaround

Orchestrator main-turn back-fill (described above). Manual; relies on noticing the omission.

## Impact Assessment

- **Who is affected**: every `/wr-itil:work-problems` AFK loop session that ships `packages/<plugin>/` fixes. Higher-frequency than per-incident: every long session is a candidate for one or more iter omissions.
- **Frequency**: ~40% of publishable iters in the 2026-04-28 evidence session.
- **Severity**: Moderate. Each omission costs ~5min recovery + risk of silent npm-publish-without-changelog if undetected.
- **Likelihood**: Likely. Iter prompt-time reminder is insufficient signal; subprocess agents under context pressure systematically miss the requirement.
- **Analytics**: 2026-04-28 session: 2 back-fills (`ac2425e` for P130, orchestrator-main-turn for P134). 5 publishable iters total. 40% miss rate.

## Root Cause Analysis

### Investigation Tasks

- [x] Confirm hook-level enforcement is the right shape vs. iter-prompt strengthening (architect-design call). **Architect verdict 2026-05-02**: hook approved — same enforcement-layer pattern as P125's staging-trap hook (per-invocation deterministic, no markers). Iter-prompt guidance has demonstrably failed.
- [x] Define the detection logic:
  - **PreToolUse:Bash matching `git commit`**: parse `git diff --cached --name-only` to enumerate staged paths. If any path matches `packages/<plugin>/*` (excluding allow-list), check that at least one `.changeset/*.md` (excluding `.changeset/README.md` and `.changeset/config.json`) is also staged. If not, deny.
  - **Bypass mechanism**: env var `BYPASS_CHANGESET_GATE=1` (architect-confirmed audit-traceable affordance via shell history).
  - **Allow-list paths** (architect verdict 2026-05-02 — permissive scope):
    - Files entirely under `packages/<plugin>/test/`, `packages/<plugin>/scripts/test/`, `packages/<plugin>/hooks/test/` — test code; no publishable behaviour change.
    - `packages/<plugin>/README.md` and `*.md` paths under `packages/<plugin>/docs/` — documentation; changeset bots ignore.
    - **NOT in allow-list**: `SKILL.md` (it IS the publishable contract per ADR-037 framing), `*.sh` hook source, `*.bash` scripts, plugin.json manifest, hooks.json, `*.json` configs, `*.ts`/`*.js` source.
  - The deny fires when the staged set contains AT LEAST ONE non-allow-listed `packages/<plugin>/*` file AND no `.changeset/*.md` is staged.
- [x] Decide deny shape: **hard deny with `BYPASS_CHANGESET_GATE` env var override**. Hard deny because the orchestrator can't decide changeset semantics; agent must explicitly author or explicitly bypass. Env var is the documented escape hatch for non-publishable commits.
- [x] Behavioural bats per ADR-005 + P081 covering: deny on staged packages/<plugin>/ source without changeset; allow with changeset; allow test-only paths; allow doc-only paths under README.md / docs/; allow BYPASS env var override; allow non-Bash tool; allow non-`git commit` Bash; fail-open outside git work tree; fail-open on parse error.
- [x] Plugin manifest registration: hook registered in `packages/itil/hooks/hooks.json` as a third `PreToolUse:Bash` matcher entry alongside `p057-staging-trap-detect.sh` and `pre-publish-intake-gate.sh`. (Note: `packages/itil/.claude-plugin/plugin.json` does not carry hook entries in this project's convention — `hooks.json` is the canonical registration site loaded automatically by the Claude Code plugin loader. The ticket's original "plugin manifest" phrasing was imprecise; the architect-approved scope confines manifest changes to `hooks.json`.)

### Confirmed root cause (2026-05-02)

Iter subprocesses operate under context pressure (heavy SKILL.md + ticket body + architect/JTBD prompt content). The "author a changeset" reminder competes with N other reminders and is sometimes dropped — observed at 40% miss rate across 5 publishable iters in the 2026-04-28 evidence session. Hook-level enforcement makes the requirement unmissable without adding to the iter's context budget; the deny fires deterministically at `git commit` time regardless of how heavily-loaded the iter context is.

## Fix Strategy

**Kind**: create

**Shape**: hook (PreToolUse:Bash matching `git commit`) + helper

**Files**:
- `packages/itil/hooks/itil-changeset-discipline.sh` — entry hook; parses tool_name + command from PreToolUse JSON; gates on `git commit` substring; delegates detection to helper; emits `permissionDecision: deny` JSON when helper signals trap.
- `packages/itil/hooks/lib/changeset-detect.sh` — `detect_changeset_required` helper. Returns 0 (allow) / 1 (deny). Echoes the offending plugin slug on stdout when 1.
- `packages/itil/hooks/test/itil-changeset-discipline.bats` — behavioural bats per ADR-005 + P081 (no source-grep; payload-on-stdin assertions on emitted JSON).
- `packages/itil/hooks/hooks.json` — register the hook as a third `PreToolUse:Bash` matcher.

**Scope**: deny `git commit` when staged diff includes any non-allow-listed `packages/<plugin>/*` file but no `.changeset/*.md` (excluding `README.md` / `config.json`) is staged. Allow when at least one valid changeset is staged, when staged `packages/<plugin>/*` files are entirely allow-listed (test paths or doc paths), or when `BYPASS_CHANGESET_GATE=1` is set.

**Deny budget**: ≤300 bytes (architect amendment per ADR-045 deny-path band; tighter than ADR-038's 400-byte ceiling). Names plugin slug + `bun run changeset` recovery + P141 cite.

**Allow-path silence**: 0 bytes per ADR-045 Pattern 1 (silent-on-pass). Hook exits 0 with no stdout/stderr on the allow path.

**Triggers**: every `git commit` Bash invocation.

**Prior uses (this session)**:
- 2026-04-28 iter 2 P130 (`b9da37e`) — packages/itil/skills/work-problems/SKILL.md + bats; no changeset; back-fill at `dcc65b4`
- 2026-04-28 iter 7 P134 (`a8b6f18`) — 5 SKILL.md + scripts/check-problems-readme-budget.sh + 13 bats; no changeset; back-fill at `ac2425e`

**Composes-with**: P073 (changeset author-time gate — same surface, different layer; P073 fires at `.changeset/*.md` Write/Edit, P141 at `git commit`), P140 (Step 6.5 fix-and-continue — orchestrator main-turn changeset back-fill IS one of the fix-and-continue patterns; if the hook prevents the omission, fewer Step 6.5 recoveries needed).

**Out of scope**: detecting omissions on already-pushed commits (that's release-cycle territory); auto-authoring the changeset (requires LLM judgment about scope/severity).

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P073, P140, P135 (decision-delegation contract — hook IS framework-resolved enforcement)

## Related

- **P073** (`docs/problems/073-...open.md`) — changeset author-time gate; same family of friction at a different surface.
- **P140** (`docs/problems/140-...verifying.md`) — fix-and-continue on CI failure; orchestrator main-turn back-fill is one fix-and-continue pattern P141 could prevent.
- **P135** (`docs/problems/135-...verifying.md`) — decision-delegation contract.
- **ADR-014** — governance skills commit their own work.
- **ADR-018** — release cadence.
- **ADR-009** — gate marker conventions.
- 2026-04-28 session evidence: iter 2 + iter 7 omissions documented in commits `dcc65b4` and `ac2425e` (orchestrator main-turn back-fills).

## Fix Released

**Released in**: @windyroad/itil next patch — see commit landing this transition + `.changeset/wr-itil-p141-changeset-discipline-hook.md`.

**Fix summary**: New `PreToolUse:Bash` hook `packages/itil/hooks/itil-changeset-discipline.sh` denies `git commit` invocations whose staged set includes `packages/<plugin>/*` source files but no `.changeset/*.md` is staged. Detection delegates to `lib/changeset-detect.sh::detect_changeset_required`, which categorises staged paths and returns 1 when a publishable source file is staged without a matching changeset. Allow paths (silent per ADR-045 Pattern 1): test paths (`test/`, `hooks/test/`, `scripts/test/`), package READMEs, `*.md` under package `docs/`, non-`packages/` paths, presence of any `.changeset/*.md` (excluding `README.md`), or `BYPASS_CHANGESET_GATE=1` env var. Deny path emits a single-line directive (≤300 bytes) naming the offending plugin slug, the `bun run changeset` recovery, and the bypass env var.

**Hook registered** in `packages/itil/hooks/hooks.json` as a third `PreToolUse:Bash` matcher alongside `p057-staging-trap-detect.sh` and `pre-publish-intake-gate.sh`.

**Tests**: 21 behavioural bats in `packages/itil/hooks/test/itil-changeset-discipline.bats` per ADR-005 + P081 — payload-on-stdin assertions on emitted JSON (no source-grep). Coverage: deny on staged source without changeset (3 shapes — SKILL.md, hook .sh, plugin.json); deny message naming + ≤300-byte band; allow with valid changeset; allow test-only paths (3 shapes); allow doc-only paths (2 shapes); deny SKILL.md (NOT in allow-list per architect amendment); allow .github/ + top-level docs/ (non-publishable); allow BYPASS env var; ADR-045 Pattern 1 silent-on-pass; non-Bash bypass; non-`git commit` Bash bypass; `.changeset/README.md` does not count as a real changeset; mixed source+test set still requires changeset; fail-open on parse error + outside git tree.

Full `packages/itil/hooks/test/` suite green: 153/153 (132 prior + 21 new). No regressions.

**Awaiting user verification**:
- Confirm the deployed hook fires on a `packages/<plugin>/` commit without a changeset in a fresh AFK loop session.
- Confirm allow paths (test-only, doc-only, BYPASS env) do not deny.
- Spot-check the deny message renders cleanly in deny output (≤300 bytes; names slug + recovery).

**Caveats per session-start briefing**: hooks load from the marketplace cache, not the source path — the new hook will fire on adopter agents only after `@windyroad/itil` is released and re-installed (`uninstall + install` per P106). The orchestrator owns release cadence per ADR-018.
