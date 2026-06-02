# Problem 230: README-refresh-discipline hook misfires on narrative-only ticket edits when no ranking-bearing field changed AND reconcile-readme.sh exit=0

**Status**: Closed
**Reported**: 2026-05-15
**Closed**: 2026-05-16
**Priority**: 6 (Med) — Impact: 2 (Minor — false-positive deny adds friction but recovery is mechanical; no data loss) × Likelihood: 3 (Likely — fires on every Change Log / Investigation Task checkbox edit where ranking-bearing fields unchanged AND README already in sync)
**Effort**: S (deferred — re-rate at next `/wr-itil:review-problems`)
**WSJF**: (6 × 1.0) / 1 = **6.0** (deferred — provisional)

> Captured 2026-05-15 by `/wr-itil:work-problems` AFK loop iter 1 surfacing pass per user direction. Sibling to [[P231]] (BYPASS env-var deny-message correction) — same hook, distinct fix.

## Description

`packages/itil/hooks/itil-readme-refresh-discipline.sh` (with `packages/itil/hooks/lib/readme-refresh-detect.sh`) denies `git commit` on **narrative-only** ticket edits — e.g. appending a Change Log entry or ticking an Investigation Task checkbox — when **no ranking-bearing field has changed** AND `packages/itil/scripts/reconcile-readme.sh` reports `exit=0` against the current README. The hook treats every ticket edit as potentially-drift-bearing without inspecting whether the staged diff touches Priority / Effort / Status / WSJF / Title fields, and without consulting the reconcile-readme exit code first.

## Symptoms

- iter 1 (2026-05-15) hit the trap on a P162 ticket Change Log entry + Phase 4 Investigation Task checkbox tick — no ranking-bearing field changed; `reconcile-readme.sh` exit=0; hook still denied with `BLOCKED: P165. P162 needs docs/problems/README.md refresh.`
- Workaround: substantive narrative edit to `docs/problems/README.md` "Last reviewed" line forces README into the staged set even though no actual inventory drift exists — manipulation of the README to satisfy the hook rather than because the README needs refreshing.

## Workaround

Substantive narrative edit to `docs/problems/README.md` "Last reviewed" line + `git add` + retry. Works but adds 1 file-write + 1 retry per narrative-only ticket edit cycle.

## Impact Assessment

- **Who is affected**: anyone editing a problem ticket's Change Log or Investigation Tasks without touching ranking-bearing fields.
- **Frequency**: every Change Log entry / every Investigation Task tick — Iter 1 hit once; iter 3 + 4 may have hit (deferred to investigation).
- **Severity**: Minor (mechanical recovery; no data loss).

## Root Cause Analysis

### Investigation Tasks

- [x] Audit `readme-refresh-detect.sh` for the staged-diff parsing — confirmed the helper had no distinction; every staged ticket-path triggered the deny when README was unstaged.
- [x] Confirm the reconcile-readme exit-code disjunct — confirmed for the **narrative-only** edit class only; architect verdict (Option Y) preserves the ADR-014 single-commit invariant for ranking-bearing edits regardless of reconcile state.
- [x] Behavioural bats: narrative-only edit + exit=0 reconcile → hook passes silently (covered + green).
- [x] Behavioural bats: ranking-bearing edit + reconcile drift → deny (covered + green).
- [x] Behavioural bats: ranking-bearing edit + exit=0 reconcile → **deny** per ADR-014 single-commit grain (architect rejected the "race → allow" framing; reconcile is a robustness layer, not a supersession of per-operation refresh).

## Fix Strategy

**Implemented** — Option Y, architect-approved:

Extend `packages/itil/hooks/lib/readme-refresh-detect.sh` with a narrative-only short-circuit. After the existing bypass + fail-open + trap-detection guards, branch on ranking-bearing detection:

- **Ranking-bearing** = field-line diff matching `^[+-]**(Priority|Effort|Status|WSJF|Type)**:` OR title diff `^[+-]# Problem` OR `git diff --staged --name-status -M` shows A/D entries on ticket paths OR R<NN> rename involving ticket paths. Falls through to existing deny logic.
- **Narrative-only** = no ranking-bearing change. Consult `packages/itil/scripts/reconcile-readme.sh` against `docs/problems`; if exit=0, return 0 (allow silently). Otherwise fall through to deny.

Ranking-bearing edits remain gated by ADR-014 single-commit grain regardless of reconcile state — reconcile is a robustness layer on top of per-operation refresh, not a supersession.

## Resolution

Closed 2026-05-16 by `/wr-itil:work-problems` AFK loop iter 2.

- `packages/itil/hooks/lib/readme-refresh-detect.sh` — extended with `_readme_refresh_staged_is_ranking_bearing` + `_readme_refresh_reconcile_clean` helpers; narrative-only short-circuit at the top of `detect_readme_refresh_required` after the no-ticket / has-readme early returns.
- `packages/itil/hooks/test/itil-readme-refresh-discipline.bats` — 7 new behavioural cases (2 narrative-only allow, 2 ranking-bearing field deny, 1 git mv rename deny, 1 narrative+drift deny, 1 P231 deny-message assertion). 29/29 green.
- Sibling [[P231]] closed in the same commit (Option A — deny message advertises `.claude/settings.json` env path + P173 reference; replaces misleading inline-prefix advertisement).

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: [[P231]] (BYPASS env-var deny-message correction — same hook surface, sibling fix)

## Related

(captured via `/wr-itil:capture-problem` equivalent — direct write at /wr-itil:work-problems orchestrator main-turn wrap)

## Change Log

- **2026-05-15** — Opened by `/wr-itil:work-problems` AFK orchestrator main-turn wrap, per user answer "Yes — capture as two separate tickets" to README-refresh question after iter 1 surfaced the friction.
- **2026-05-16** — Closed by `/wr-itil:work-problems` iter 2. Option Y implementation landed (narrative-only short-circuit with reconcile-readme as authority for narrative class; ranking-bearing remains ADR-014-gated). 29/29 hook bats green. Folded with [[P231]] Option A deny-message correction in single commit per ADR-014 single-commit grain.
