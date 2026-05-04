# R003: Hook regression / behaviour change ships to adopters

A change to a `packages/*/hooks/*.sh` file (or `hooks.json` event registration, hook prose budget, or a detector that hooks consume) ships under a regular minor/patch bump. Hooks fire on every gated tool call across every adopter session — any regression (false-deny, false-allow, syntax error, byte-budget overflow) propagates to every installed user the moment they update the plugin cache.

Cascade fan-out is high; detection latency is long; rollback path is slow (npm publish + marketplace cache update + per-adopter reinstall, days); AFK orchestrator iters can compound a regression overnight.

## Recogniser

**Path patterns** (any match → consider this entry):

- `packages/*/hooks/*.sh`
- `packages/*/hooks/hooks.json`
- `packages/*/hooks/lib/*.sh`
- `packages/*/hooks/test/*.bats`

**Diff-content keywords** (any match → consider):

- `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, `SessionStart`
- `permissionDecision`, `additionalContext`, `hookSpecificOutput`, `denyMessage`
- `bash hooks/`, `chmod +x` near hooks/
- `BYPASS_*_GATE=1` (env-var bypass added/removed)

**Anti-patterns** (looks like R003 but isn't):

- Hook prose changes that ALSO change the SKILL.md contract → score as **R010** (semver violation), not R003 alone.
- Test-only additions to `packages/*/hooks/test/` without source change → score as **R009** (defect coverage), not R003.
- A new hook landing for the first time (not a regression of an existing surface) — still R003 but with elevated impact (no dogfood evidence yet); flag specifically.

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | yes | Hook source change lands here; behavioural regression observable from this layer |
| push | yes | cumulative |
| release | **primary** | Layer where adopters first see the regression on cache refresh |
| external-comms | no | Hook is internal runtime; outbound-prose lens doesn't apply |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 4 (Significant) — `RISK-POLICY.md` L64: "Installed plugins degrade developer workflow — hooks fire incorrectly". Hook regression is the canonical instance.
- **Likelihood**: 4 (Likely) — every hook change risks behavioural regression; without dogfood discipline, source-tree-locally-tested-only hooks ship straight to adopters.
- **Inherent score**: 16
- **Inherent band**: High

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| Held-changeset / dogfood-window pattern (`docs/changesets-holding/`, ADR-042 Rule 7) | Hook-bearing changeset is held in `docs/changesets-holding/` AND has documented reinstate trigger | 1 | -1 likelihood | Bump +1 (regression ships without in-repo dogfood) |
| Behavioural bats per ADR-052 (`packages/*/hooks/test/*.bats`) | Bats coverage exists for the changed hook surface | 2 | -1 likelihood | Bump +1; flag as R009 sub-class too |
| P141 changeset-discipline gate (`itil-changeset-discipline.sh`) | Plugin source change includes a `.changeset/*.md` declaring bump class | 3 | -1 likelihood | Hard-block at commit gate; if bypassed, bump +2 |
| ADR-045 hook injection budget policy | Hook prose changed (≤300 bytes deny; ≤150 bytes additionalContext) | n/a (impact-shaping) | 0 paths | Risk of context-overflow regression class; bump impact +1 if exceeded |
| CLAUDE.md "marketplace cache" briefing | Always (declarative) | n/a | 0 paths | Lower author-mindfulness; not runtime |

Lifetime residual likelihood under all three paths firing-and-passing = 1 (Rare; capped at floor).

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| New hook landing for the first time (not a regression of an existing hook) | +1 | No dogfood evidence yet; held-changeset pattern is mid-cycle, not catching regressions |
| Wide-matcher change (`PreToolUse:Bash\|Write\|Edit\|Read`) | +1 | Cascade fan-out higher than narrow matchers |
| Cross-shell behaviour change (zsh / dash compatibility tweak) | +1 | Tested on macOS bash typically; adopter shells differ |
| Same-commit-self-block: hook gates `git commit` AND ships in same commit | +1 | Bootstrap commit can self-block; bypass needed |
| Hook-prose change shipped under `patch` bump | +1 (and consider also-flag as R010) | Under-classification; behavioural change deserves minor at minimum |
| Held-changeset window has been ≥7 days with no false-positives | -1 | Dogfood evidence is empirical; reduce per-action concern |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 1 (Rare) — held-changeset + bats + changeset-discipline gate stack to capped reduction.
- **Residual score**: 4
- **Residual band**: Low — within appetite (at floor).

**At appetite**. Controls stack working; further reduction has diminishing returns. Sustain held-changeset discipline as primary control.

## Watch-out

- Cross-shell portability is a recurring sub-class — hooks tested on macOS bash may fail on adopter zsh / dash.
- Bundled-plugin hooks with broad matchers have higher cascade than narrow ones; flag wide-matcher changes specifically.
- Same-commit-self-block: a hook that gates `git commit` and ships in the same commit can self-block if the commit doesn't satisfy the new gate (P141 amendment for bootstrap commits).

## See also

- **Generalisation**: R009 (functional defects) — R003 is the hook-surface specialisation.
- **Sibling**: R005 (release coordination) — hook changes are nearly always changeset-bearing.
- **Drivers / ADRs**: P085, P064, P141, P119, P124, P159, P162, ADR-042 (Rule 7 held-area), ADR-052 (behavioural-tests), ADR-045 (injection budget).
