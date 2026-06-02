# Problem 269: Amend `plugin-maturity-populate.sh` to write `rollup_invocations_30d` on plugin root rollup for compound rendering

**Status**: Verifying
**Reported**: 2026-05-18
**Root cause confirmed**: 2026-05-18
**Fix released**: 2026-05-18 (`@windyroad/itil@0.35.4` — source commit `7ca47ef` "fix(maturity): P087 Phase 3 (P269) — amend populate to write rollup_invocations_30d + bootstrapping on plugin root for compound rendering" + retroactive rollout `f3c0d26` + doc-lint fold-fix `3040b69` + retro `d945727`; version-packages commit `28ac9e7`; PR #150 merge commit `6127ed8` 2026-05-18; released session 8 loop-end Step 6.5 drain; transitions Open → Verifying per ADR-022 P143 fold-fix amendment — changeset removal in `28ac9e7` IS the canonical fix-shipped signal; verification window remains in-flight — 5 AFK iterations across ≥2 sessions of low-risk iters; recovery path: `/wr-itil:transition-problem 269 known-error` after reverting the iter commits)
**Priority**: 3 (Medium) — Impact: 3 × Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)
**WSJF**: 9/3 = **3.0** (raw Priority/Effort retained per README display convention)

## Description

The P087 Phase 3 compound-rendering pipeline has a contract gap between Phase 3a (`packages/itil/scripts/plugin-maturity-populate.sh`) and Phase 3b (`packages/itil/scripts/plugin-maturity-render.sh`):

- **Phase 3b renderer** expects the plugin root rollup to carry `rollup_invocations_30d` + bootstrapping flags so it can render the bootstrapping compound form `*Maturity: <Band> (suite-bootstrap window; <N> invocations / 30d).*` per ADR-063 §Bootstrapping clause rendering.
- **Phase 3a populate** writes the rollup as `{schema_version, band}` only per ADR-063 §rollup schema. No `rollup_invocations_30d` field.

When the renderer runs against the populated state, it falls through to the bare-band form (`*Maturity: <Band>.*`) instead of the compound form. The bootstrapping window evidence is invisible in rendered READMEs even though it's correctly computed inside Phase 3a's band derivation.

Observed 2026-05-18 P087 iter-10 retroactive rollout: renderer's compound-rendering fall-through fired on all 12 plugins. Phase 3b architect verdict + JTBD verdict both PASSED assuming compound rendering works, but the rollout was contract-correct under the current renderer behaviour.

**User-directed fix** (session 7 loop-end Step 2.5 routing 2026-05-18): **amend populate to write `rollup_invocations_30d` to rollup** rather than amending renderer to derive on-fly.

Fix details:

1. Extend `packages/itil/scripts/plugin-maturity-populate.sh` rollup-emission block to compute `rollup_invocations_30d = sum(invocations_30d across non-null per-surface entries)` during the populate pass.
1a. Also write `bootstrapping: <bool>` to the rollup using the existing module-scope `bootstrapping_active` flag (architect Adjustment E, 2026-05-18 review). The renderer's compound-form predicate at `plugin-maturity-render.sh` line 144-147 is AND-gated on **both** `bootstrapping` AND `rollup_invocations_30d` — writing only one of them leaves the compound-render path unfireable. Single-ticket closure: one observable outcome (compound rendering fires) requires both fields, so they ship together rather than splitting into sibling tickets.
2. Update ADR-063 §rollup schema to include `rollup_invocations_30d: integer | null` (null when ALL per-surface entries are null-sentinel, e.g. hook-only plugins) AND `bootstrapping: bool` (populate-time snapshot of the bootstrapping-window state — not a render-time recompute).
3. Add Phase 3a populate bats coverage: rollup carries `rollup_invocations_30d` field; sum matches per-surface values; null when no countable surfaces.
4. Add Phase 3b renderer bats coverage: compound rendering fires when `rollup_invocations_30d` is present + bootstrapping flag is active; falls through to bare-band when missing or null.
5. Add Phase 3c doc-lint coverage (`packages/itil/scripts/test/plugin-maturity-doc-lint.bats`): assert rollup `rollup_invocations_30d` field shape per amended ADR-063.
6. Retroactive rollout: re-run populate against the live monorepo with the amended script; one ADR-014 commit + one multi-package patch changeset per ADR-021.

Architect-design alternative considered + rejected (per user direction): renderer-side derive (renderer sums per-surface evidence at render time during bootstrapping). Would avoid schema change but puts the logic in the rendering layer where it should be a property of the populate-time-evidence. Single-source-of-truth principle favors populate-side write.

## Symptoms

- Live monorepo READMEs render bare-band form for all 12 plugins during the bootstrapping window — the `(suite-bootstrap window; <N> invocations / 30d).` evidence is invisible.
- ADR-063 §Bootstrapping clause states evidence must be visible during the window; current rendering violates that intent.

## Workaround

None applied — fall-through bare-band form is functionally correct (just less informative).

## Impact Assessment

- **Who is affected**: anyone reading plugin READMEs during the bootstrapping window (suite_oldest_days < 60).
- **Frequency**: every README render during bootstrapping window — fires for all 12 plugins until the window closes (~2026-06-06 anticipated lapse derived from `max(days_shipped across plugins) < 60`).
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — confirm the sum-of-per-surface-invocations approach handles hook-only surfaces (null sentinel) correctly
- [ ] Create reproduction test (Phase 3a populate bats + Phase 3b renderer bats + Phase 3c doc-lint bats per the fix details above)
- [ ] Schedule rollout: amend populate + ADR-063 schema + add coverage + re-run populate + render against live monorepo + single multi-package patch changeset

## Dependencies

- **Blocks**: (P087 closure path — compound-rendering gap is the last named outstanding-question on P087)
- **Blocked by**: (none)
- **Composes with**: P087 (parent ticket), P237 (Phase 3a Verifying), P238 (Phase 3b Verifying), P239 (Phase 3c Verifying), P244 (F9 in-suite display shim — Open), ADR-063 (rollup schema), ADR-053 (Bootstrapping clause)

## Related

(captured at /wr-itil:work-problems session 7 Step 2.5 user-direction routing — user picked populate-side write over renderer-side derive)

- P087 line-133 retroactive-rollout investigation task — noted compound-rendering gap
- P087 Phase 3b iter-8 architect verdict — assumed compound rendering works
- P087 Phase 3c iter-5 architect adjustment A3 — header-comment scope-limit on compound-vs-bare badge form (doc-lint is agnostic to form; this ticket carries the form-level fix)
- ADR-063 §rollup schema + §Bootstrapping clause rendering
- `packages/itil/scripts/plugin-maturity-populate.sh` rollup-emission block
- `packages/itil/scripts/plugin-maturity-render.sh` compound-rendering fall-through
