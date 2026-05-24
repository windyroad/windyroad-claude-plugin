# R010: Semver / backward-compatibility violation on plugin contracts

Each `@windyroad/*` plugin is independently versioned via Changesets; bump class (patch / minor / major) is declared in the changeset frontmatter. Semver violations occur when the bump class understates the breaking-change content: a behaviour change labelled "minor" that's actually breaking. Adopters under `^` semver pull non-breakingly and discover the break later.

The agentic context amplifies the risk: SKILL.md prose IS the contract adopters consume by reading; an agent prompt change that shifts behaviour silently is a contract change adopters won't notice until they hit the new behaviour. Prompt-cache lag (R006-adjacent) extends the divergence window.

## Recogniser

**Path patterns** (any match → consider this entry):

- `.changeset/*.md` (the bump-class declaration surface)
- `packages/*/skills/*/SKILL.md` (adopter contract — Step-N flow shape, AskUserQuestion call sites)
- `packages/*/agents/*.md` (agent prompts adopters' SKILL.md may invoke)
- `packages/*/hooks/hooks.json` (event-matcher changes)
- `packages/*/bin/*` (CLI flag shapes adopters' shell scripts depend on)

**Diff-content keywords** (any match → consider):

- `: patch` or `: minor` declaration in changeset where the diff is to a SKILL.md / agent.md / hooks.json
- Step removed / renamed / reordered in SKILL.md
- AskUserQuestion call shape changed (question text, options, options-count, multiSelect flag)
- Hook event matcher changed (`PreToolUse:Edit` → `PreToolUse:Edit|Write`)
- Hook deny-message wording changed (deny BEHAVIOUR change, not just wording)

**Anti-patterns** (looks like R010 but isn't):

- Pure refactor with no semantic change — `chore` / `patch` is fine.
- README badge / link updates — `chore` fine.
- Wording-only change to hook deny message that doesn't change WHEN the hook denies — `patch` fine.
- New feature added without removing/changing existing behaviour — `minor` is correct.

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | yes | Bump-class declared at commit time |
| push | yes | cumulative |
| release | **primary** | Adopters experience the breakage at upgrade |
| external-comms | no | Internal contract surface |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 4 (Significant) — adopter pulls under `^` semver expecting non-breaking; gets break; their downstream code/SKILL/automation fails. Per L64.
- **Likelihood**: 3 (Possible) — bump-class miscategorisation is uncommon but real; without controls, hook-prose-as-patch case is recurring.
- **Inherent score**: 12
- **Inherent band**: High

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| Changesets bump-class field declaration | Author declares patch / minor / major in `.changeset/*.md` | 1 | -1 likelihood | Bump +2 (no classification surface exists; gate forces it but author skipped) |
| `itil-changeset-discipline.sh` (P141) | `git commit` includes `packages/*/source` change AND a `.changeset/*.md` is staged | 2 | -1 likelihood (forces classification surface) | Hard-block; if `BYPASS_CHANGESET_GATE=1`, bump +2 |
| ADR-056 dual-parse contract pattern | When agent-prompt or hook contract changes shape, ship new shape AND backward-compat fallback | 3 (specific to in-flight cached-prompts sub-class) | -1 likelihood for that sub-class | Bump +1 for cached-prompts sub-class |
| Architect review on every SKILL/agent/hook edit | Project-file edit | n/a (broad path; same as R009 control 2) | 0 paths (already counted under R009) | n/a |
| `/wr-itil:report-upstream` skill (ADR-024) | Adopter reports a post-release breakage | n/a (post-hoc adopter feedback channel) | 0 paths | n/a |

Lifetime residual likelihood = 1 (Rare; capped at floor).

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| Changeset declares `: patch` AND diff includes SKILL.md prose change | +1 | Suspect under-classification — examine whether prose change is behavioural |
| Changeset declares `: patch` AND diff includes hook deny-message OR matcher change | +2 | Hook prose changes that ship under patch are the canonical under-classification mode |
| Changeset declares `: minor` AND diff REMOVES a Step from SKILL.md flow | +1 | Removal is breaking; should be `major` |
| Diff includes ADR-056-style dual-parse contract preserving backward-compat | -1 | Pattern application reduces in-flight cached-prompt risk |
| Adopter has not yet run `/install-updates` to refresh marketplace cache after this push | +1 (impact-shaping) | Cached-prompts window extends divergence time |
| AskUserQuestion call shape changed (text / options / multiSelect) | +1 | UX-contract change adopters' SKILL.md may consume by name |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 1 (Rare) — three paths (bump-class declaration + P141 enforce + ADR-056 dual-parse for cached-prompts sub-class) stack to capped reduction.
- **Residual score**: 4
- **Residual band**: Low — at appetite.

**At appetite**. Could drop further with automated breaking-change detection (CI surface diffing published-surface signatures and recommending bump class); doesn't currently exist; deferred until evidence justifies.

## Watch-out

- Sub-class of R005 (release coordination) but distinct: R005 is **changeset queue shape** (multiple bumps coordinating); R010 is **bump-class semantic accuracy** (is `minor` actually correct for THIS change?).
- Hook prose changes shipping under `patch` but actually shifting behaviour are the recurring under-classification mode.
- Agent prompt changes are particularly prone — they ARE the contract adopters consume by reading SKILL.md. Adding a new mandatory step is at minimum minor; removing or reordering is major.
- ADR-056's dual-parse pattern is the in-flight-cached-prompts mitigation — apply whenever an agent-prompt contract changes shape, even under a major bump (adopters' cached prompts won't refresh until ~7-day TTL).

## See also

- **Generalisation**: R009 (functional defects) — R010 is the adopter-contract specialisation.
- **Sibling**: R005 (release coordination) — R010 + R005 frequently co-occur on hook-prose-changeset commits.
- **Drivers / ADRs**: ADR-056 (dual-parse pattern), ADR-018 (release cadence), ADR-014 (commit grain — bumps and source ride together), ADR-024 (report-upstream adopter-feedback channel), ADR-042 (auto-apply for high-risk bumps).
