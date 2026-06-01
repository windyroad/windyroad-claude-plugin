# Problem 263: CI gate `claude plugin install --dry-run` per plugin pre-publish — ADR-063 Confirmation #11 implementation

**Status**: Verification Pending
**Reported**: 2026-05-18
**Root cause confirmed**: 2026-05-30 (work-problems AFK iter 6)
**Fix released**: 2026-06-01 — @windyroad/itil@0.43.0 (commit 9158004)
**Priority**: 12 (High) — Impact: 4 (Significant — closes the test-gap class that allowed the P0 manifest break to ship; structural prevention for future plugin.json schema changes) x Likelihood: 1 (Rare — only fires when a future plugin.json schema change creates incompatible top-level keys)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; new CI workflow step + shim script + bats coverage)
**WSJF**: 6.0 — (12 × 1.0) / 2 (Known Error multiplier 1.0 per ADR-022 default)
**Type**: technical

## Description

Surfaced 2026-05-18 by the P0 manifest validity incident (P258 driver). The Phase 3 retroactive rollout (commit d33bb7d, shipped as @windyroad/itil@0.35.1 + 10 sibling plugins) broke `claude plugin install` for all 11 plugins because the new top-level `hooks:` / `skills:` / `agents:` keys with maturity-only records were rejected by Claude Code's manifest validator. The break shipped to npm because CI's pre-publish validation had NO gate that exercised `claude plugin install` against the actual published manifest shape — bats fixtures asserted JSON structure but never ran the installer.

ADR-063 Amendment 2026-05-18 captures this as new Confirmation criterion #11:

> §Confirmation #11 (Manifest validator compatibility): a `claude plugin install <plugin>@windyroad --scope project` against a freshly-published plugin MUST succeed. The Phase 3a bats coverage was insufficient — bats fixtures asserted JSON shape but not installer acceptance. Follow-on iter SHOULD add CI gate that runs `claude plugin install --dry-run` against each plugin pre-publish (P246 sibling-class — gate-the-actual-load-bearing-surface, not a proxy).

This ticket is the implementation of that Confirmation criterion.

## Symptoms

- Without this gate: future plugin.json schema changes can ship to npm with shapes that break `claude plugin install`. Same class as the P0 incident.
- Bats green is not sufficient evidence that the shipped plugin is installable.

## Workaround

(none — this IS the structural prevention; bats green + manual install testing is the current state).

## Impact Assessment

- **Who is affected**: All future @windyroad/* plugin releases. Every adopter installing them.
- **Frequency**: Rare — the gate prevents the rare class of incident that already happened once.
- **Severity**: Significant (4) — prevents P0-class manifest breakages.

## Root Cause Analysis

### Refined root cause (2026-05-30 work-problems AFK iter 6 investigation, empirically grounded against Claude Code CLI 2.1.150)

Empirical probe of `claude plugin validate` against the live monorepo:

| Surface                                                            | Exit | Failure class                                                                                                                                                       |
| ------------------------------------------------------------------ | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `claude plugin validate packages/<all 11>`                         | 1    | At least one ERROR-class issue (e.g. `packages/itil` — YAML Parse error in `skills/transition-problems/SKILL.md` frontmatter).                                      |
| `claude plugin validate --strict packages/<all 11>`                | 1    | All 11 plugins fail because of the `maturity:` unknown-field warning (the ADR-063 chosen safe-extension pattern) + `author:` missing-info warning.                  |
| `claude plugin validate --strict .claude-plugin/marketplace.json`  | 0    | Marketplace manifest is clean under `--strict`.                                                                                                                     |

The **design tension** uncovered:

- ADR-063 Amendment 2026-05-18's chosen safe-extension pattern places maturity records at top-level `maturity:` — an **unrecognised top-level key** — because P258's refined root cause is unambiguous that *unrecognised keys are warning-only and the plugin still loads*. This is the durable design.
- `claude plugin validate --strict` promotes ALL warnings (including `unknown field 'maturity'`) to errors → it would REJECT the very design ADR-063 chose as durable.
- The P258 historical incident's ACTUAL failure class was different: a **recognised top-level key (`hooks`/`skills`/`agents`/`commands`) carrying wrong-typed content** → `Validation errors: hooks: Invalid input, skills: Invalid input`. This is a hard ERROR caught by `claude plugin validate` (non-strict) without needing `--strict`.

The CI gate that catches the historical incident's mechanism AND honours ADR-063's safe-extension pattern is therefore `claude plugin validate` **without `--strict`**. P263's body originally proposed `claude plugin install --dry-run`; P258 Investigation 2026-05-26 refined this to `claude plugin validate --strict`; this iter's empirical probe refines further to non-strict.

The non-strict gate also surfaces a **latent ERROR-class bug** in the current tree: `packages/itil/skills/transition-problems/SKILL.md` has a YAML Parse error in its frontmatter. This bug is OUTSIDE P263's scope (separate ticket capture queued at `## Outstanding`) but its presence is direct evidence that the non-strict gate is load-bearing — it would have caught this bug on first activation.

### Architect verdict (work-problems AFK iter 6, 2026-05-30)

**GREEN** — Option A (non-strict gate) acceptable per ADR-063 Amendment 2026-05-18 + P258 refined root cause. No new ADR warranted. Refinements:

- **Placement**: insert AFTER the existing `Dry-run per-plugin installers` step in `.github/workflows/ci.yml` (after line 107, before `Run hook tests` at line 109) — same per-plugin loop shape, same per-plugin failure framing.
- **Shim pattern per ADR-049**: canonical body at `packages/itil/scripts/plugin-validate-ci-gate.sh`; thin shim at `packages/itil/bin/wr-itil-plugin-validate-ci-gate`. Keeps the loop behaviourally testable (bats fixture runs the script against synthetic manifests).
- **CLI dependency pin**: CI must `npm i -g @anthropic-ai/claude-code@<pinned-version>` before invoking the validator. Pinning protects against Anthropic-side CLI behaviour change silently breaking the gate. Document the pin in a code-comment.
- **Bats coverage (minimum 2, ideally 3)**:
  - Positive case: ADR-063's chosen `maturity:` top-level shape passes non-strict (proves the safe-extension pattern is honoured).
  - Negative case (P258 reproduction): maturity records at top-level `hooks:`/`skills:`/`agents:` → non-strict exit 1.
  - (Eventual) Negative case: SKILL.md frontmatter YAML Parse error → non-strict exit 1 (once the itil YAML bug is fixed under its own ticket).

### JTBD verdict (work-problems AFK iter 6, 2026-05-30)

**PASS** — Primary alignment with `JTBD-101 (Extend the Suite with New Plugins)`: "CI validates required files, package fields, installer dry-runs, and hook tests" is the named Desired Outcome. Secondary alignment with `JTBD-202 (Run Pre-Flight Governance Checks Before Release or Handover)`. All cited JTBDs ratified (`human-oversight: confirmed`). No iter-5-style unratified-JTBD blocker.

### Root cause

**Test-gap class** — `bats` fixtures assert JSON structure but the load-bearing surface is `claude plugin install`'s manifest validator. Per the gate-the-actual-load-bearing-surface principle (P246 sibling-class), the bats coverage is a proxy for the true acceptance criterion; only running the actual validator against each manifest pre-publish closes the gap.

Why this slipped through pre-2026-05-18: the `claude plugin validate` CLI surface was not widely known to be CI-gate-suitable at the time of the d33bb7d rollout; P258 investigation 2026-05-26 surfaced it as the documented pre-publish gate; this ticket consumes that finding.

## Fix Strategy

### Mechanism

Add a new CI step to `.github/workflows/ci.yml` placed AFTER `Dry-run per-plugin installers` (line 100-107) and BEFORE `Run hook tests` (line 109):

```yaml
      - name: Install Claude Code CLI for plugin manifest validation (P263, ADR-063 Confirmation #11)
        run: npm i -g @anthropic-ai/claude-code@<PINNED-VERSION>

      - name: Validate each plugin manifest (P263, ADR-063 Confirmation #11; non-strict per P258 refined RCA)
        run: packages/itil/bin/wr-itil-plugin-validate-ci-gate
```

Canonical body `packages/itil/scripts/plugin-validate-ci-gate.sh`:

```bash
#!/usr/bin/env bash
# Loops over packages/*/.claude-plugin/plugin.json, runs `claude plugin validate`
# (non-strict — see P263 RCA), fails non-zero on any ERROR-class result.
# Per P258 refined RCA: non-strict catches recognised-key-type-mismatch (the
# historical incident class) without rejecting the ADR-063 maturity:
# unrecognised-key safe-extension pattern that --strict would reject.

set -e
fail=0
for pkg in packages/*/.claude-plugin/plugin.json; do
  plugin_dir=$(dirname "$(dirname "$pkg")")
  name=$(basename "$plugin_dir")
  echo "--- $name ---"
  if ! claude plugin validate "$plugin_dir"; then
    echo "FAIL: $name plugin manifest validation"
    fail=1
  fi
done
[ "$fail" = "0" ] || exit 1
```

Thin shim `packages/itil/bin/wr-itil-plugin-validate-ci-gate` per ADR-049 PATH-on-shim pattern.

Bats coverage `packages/itil/scripts/test/ci-plugin-validate-gate.bats`:

- **Fixture A (positive)**: synthetic plugin manifest with top-level `maturity: { schema_version: "2.0", band: "Experimental" }` per ADR-063 Amendment 2026-05-18 → script exits 0 (warning ignored under non-strict). Proves safe-extension pattern is honoured.
- **Fixture B (negative — P258 reproduction)**: synthetic plugin manifest with maturity records at top-level `hooks: { foo: { schema_version: "1.0", band: "Experimental" } }` → script exits 1 (recognised-key type mismatch caught). Proves historical incident class is caught.

### Implementation phasing

This iter completes RCA + Fix Strategy + Open → Known Error. Implementation (script + shim + bats + CI step + CLI version pin research) is the next iter's work — deferred from this iter because:

- TDD state IDLE — requires test-first scaffolding sequencing (bats fixture before script).
- Claude Code CLI version-pin requires empirical research (Anthropic CLI release cadence, install flake history). Brief but distinct from RCA scope.
- M ceiling — RCA + Fix Strategy + transition is the M-bounded slice.

### Documentation refinement (lands with implementation)

When P263 implementation lands, amend `docs/decisions/063-plugin-maturity-presentation-layer.proposed.md` §Confirmation #11 with a one-line note documenting the prose-to-implementation refinement: from speculative `claude plugin install --dry-run` (line 128 prose) to `claude plugin validate` (non-strict) per P258 refined RCA + P263 implementation. The amendment closes the documentation hygiene gap so future readers don't trip on the prose/implementation divergence.

This amendment is a SINGLE decision-file edit — does NOT hit the multi-decision-file architect-gate deadlock (P303).

## Outstanding

- **Capture as separate ticket — itil YAML Parse error in `packages/itil/skills/transition-problems/SKILL.md`**: `claude plugin validate packages/itil` (non-strict) reports `frontmatter: YAML frontmatter failed to parse: YAML Parse error: Unexpected token. At runtime this skill loads with empty metadata (all frontmatter fields silently dropped)`. Latent bug, no longer silent under P263's gate once implemented. Iter constraint forbade `/wr-itil:capture-*` mid-loop; surface via orchestrator at iter wrap. Surfaced by P263 iter 6 empirical probe.
- **Claude Code CLI version-pin**: implementation iter must empirically research the Anthropic CLI release cadence + install-flake history to choose a sensible pin policy (exact-version vs minor-version-floor). Current observed version: `2.1.150 (Claude Code)`.
- **ADR-063 §Confirmation #11 implementation-note amendment**: queued to land with implementation commit (single decision-file edit, gate-safe).

## Dependencies

- **Blocks**: (none — current bats coverage is the stand-in; the gate is the structural reinforcement)
- **Blocked by**: (none — implementation can start immediately)
- **Composes with**: P258 (root-cause driver ticket — manifest validator schema constraints; refined recognised/unrecognised distinction is what unlocks the non-strict gate design), P246 (sibling fictional-defer class — gate-the-load-bearing-surface), ADR-063 Amendment 2026-05-18 (the source authority), ADR-049 (PATH-on-shim pattern for the script).

## Change Log

- 2026-05-18: Captured via /wr-retrospective:run-retro Step 4b Stage 1 by the P0 manifest validity incident (P258 driver).
- 2026-05-26: P258 investigation refined the gate surface from speculative `claude plugin install --dry-run` to documented `claude plugin validate --strict`. Cross-reference added to ticket body.
- 2026-05-30 (session 9 work-problems AFK iter 6): Empirical probe against Claude Code CLI 2.1.150 surfaced the design tension — `--strict` would reject the ADR-063 `maturity:` safe-extension pattern that all 11 plugins use. Refined gate design to NON-strict (catches the P258-actual recognised-key type-mismatch class without rejecting the safe-extension pattern). Architect GREEN, JTBD PASS (primary alignment JTBD-101). Latent itil YAML Parse error in `transition-problems/SKILL.md` surfaced (separate ticket capture queued). Transitioned Open → Known Error with implementation-ready Fix Strategy.
- 2026-05-30 (session 9 work-problems AFK iter 7): Phase 1 implementation landed. New canonical body `packages/itil/scripts/plugin-validate-ci-gate.sh` + ADR-049 shim `packages/itil/bin/wr-itil-plugin-validate-ci-gate` + 11/11-green behavioural bats `packages/itil/scripts/test/plugin-validate-ci-gate.bats` (Fixture A positive ADR-063 safe-extension shape; Fixture B negative P258 reproduction). CI workflow wired the gate after `Dry-run per-plugin installers` with pinned `@anthropic-ai/claude-code@2.1.150`. ADR-063 §Confirmation #11 amended with implementation-note documenting the prose→implementation refinement chain. Changeset `@windyroad/itil` minor. Architect PASS + JTBD PASS + risk PASS + voice/tone PASS gates cleared. KE remains — orchestrator owns K→V transition after release lands.
- 2026-06-01 (work-problems AFK iter): K→V transition via batched `/wr-itil:transition-problems` after @windyroad/itil@0.43.0 shipped (commit 9158004 packaged via `1d1d6a8 chore: version packages`). Awaiting user verification that the CI workflow's new plugin-validate gate runs green pre-publish across all 11 plugins.

## Fix Released

Released 2026-06-01 in **@windyroad/itil@0.43.0** (fix commit `9158004`). Phase 1 ships the non-strict `claude plugin validate` CI gate (canonical body + ADR-049 shim + 11-green bats + pinned `@anthropic-ai/claude-code@2.1.150`) per ADR-063 Confirmation #11. Awaiting user verification: next CI run on a release-bearing PR should exercise the new step green; future plugin.json schema regressions should be caught pre-publish.

## Related

- `.github/workflows/ci.yml` — surface to amend (place new step after line 107).
- `docs/decisions/063-plugin-maturity-presentation-layer.proposed.md` Amendment 2026-05-18 — source authority + Confirmation #11 prose to refine.
- `docs/decisions/049-bin-path-shim.proposed.md` (if exists) — PATH-on-shim pattern for the new CI gate script.
- `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md` — primary JTBD alignment.
- P258 — root cause ticket; refined recognised/unrecognised key distinction.
- P246 — sibling-class "gate-the-actual-load-bearing-surface".
- Commit 3cfa6fc — the hotfix that ships the corrected shape.
- Commit d33bb7d — the broken Phase 3 retroactive rollout.
