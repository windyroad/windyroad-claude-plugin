# Problem 309: `wr-risk-scorer-drain-register-queue` no-ops on queued slugs that have no register file — creates 0, appends 0, and does NOT truncate the queue

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

`/wr-itil:work-problems` Step 6.4 invokes `wr-risk-scorer-drain-register-queue` (→ `packages/risk-scorer/scripts/drain-register-queue.sh`) to materialise `.afk-run-state/risk-register-queue.jsonl` hints into `docs/risks/R<NNN>-<slug>.active.md` register entries. Per the Step 6.4 contract, when `docs/risks/` is scaffolded (it is — 25 files present) the script should dedupe by `risk_slug` and create one register file per unique unrepresented slug (or append Evidence Log lines to slug-matched existing files).

**Observed 2026-05-26**: the queue held **3 entries** (slugs `external-adopter-name-in-public-repo-ticket-prose`, `new-sessionstart-hook-first-landing-no-dogfood-window`, `new-sessionstart-hook-shipped-without-dogfood-window`, dated 2026-05-24/25). The drain returned:

```
entries_drained=0
new_risks_created=0
evidence_appended=0
next_action=none
```

Independent check: **none of the 3 slugs has a register file** under `docs/risks/` (`grep -rl <slug> docs/risks/` → no match for all three). So the drain should have created 3 new entries — but it created 0, appended 0, AND did not truncate the queue. The 3 entries persist and will be re-evaluated (and re-no-op'd) on every subsequent drain, accumulating indefinitely off-ledger.

This is the inverse of the Step 6.4 intent — the queue exists so above-appetite risk hints reach the register; a silent no-op on unrepresented slugs means those risks never get scaffolded and the queue never clears.

Candidate root-cause directions (to investigate):
1. The script's "skip if `docs/risks/` not scaffolded" guard mis-fires (false-negative on the scaffold-detection).
2. The slug-dedup logic treats the 3 slugs as already-represented (false-positive match against some non-`docs/risks/` state).
3. The JSONL parse silently drops entries (schema drift between the queue-writer hook and the drain reader — e.g. a field renamed).
4. The entries' `report_path` references (`.risk-reports/2026-05-2x-...md`) are missing/unreadable and the drain fail-skips them silently.

## Symptoms

(deferred to investigation)

## Workaround

None applied — the no-op is non-blocking for the AFK loop (Step 6.4 failure is non-halting). The 3 entries remain queued; manual `/wr-risk-scorer:create-risk` or `bootstrap-catalog` can scaffold them if needed.

## Impact Assessment

- **Who is affected**: maintainers relying on Step 6.4 to auto-populate the risk register from AFK above-appetite events (ADR-056 Phase 2b).
- **Frequency**: every Step 6.4 drain with these (or similar unrepresented) queued entries — structurally recurring until fixed.
- **Severity**: risk hints never reach `docs/risks/` (ISO 31000 register currency gap); the queue accumulates undrained off-ledger entries. Non-blocking but defeats the register-population contract.
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Reproduce: run `wr-risk-scorer-drain-register-queue` against the current 3-entry queue and trace why `new_risks_created=0`
- [ ] Determine which of the 4 candidate causes holds (scaffold-guard / dedup-false-positive / JSONL-parse-drop / missing-report_path fail-skip)
- [ ] Decide truncation semantics: should processed-but-unscaffoldable entries be truncated, retained, or surfaced as an error?
- [ ] Create reproduction test (behavioural — 3-entry queue, unrepresented slugs, assert 3 register files created + queue truncated)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: ADR-056 Phase 2b (the drain contract this faults)

## Related

- **ADR-056** — risk-register queue + drain (Phase 2a writer hook, Phase 2b drain). The contract this violates.
- `packages/risk-scorer/scripts/drain-register-queue.sh` — the no-op'ing script.
- `/wr-itil:work-problems` Step 6.4 — the invocation surface where the no-op was observed.
- Captured via /wr-retrospective:run-retro Step 4b Stage 1 (pipeline-instability detection); 2026-05-26.
