# Problem 262: P165 README-refresh hook conflicts with capture-problem SKILL's deferred-README-refresh contract — hook wins; SKILL needs update OR hook needs carve-out

**Status**: Verification Pending
**Reported**: 2026-05-18
**Priority**: 6 (Medium) — Impact: 2 (Minor — capture commit denied until workaround applies; not destructive) x Likelihood: 3 (Likely — fires on every capture commit; observed 4× this session for P254/P255/P256/P257)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; either SKILL.md amendment or hook carve-out, architect verdict)

## Description

Surfaced 2026-05-18 during session 6 captures (P254, P255, P256, P257). The `/wr-itil:capture-problem` SKILL.md Step 6 contract explicitly says:

> **Stage list**: ONLY the new ticket file. **Do NOT** stage `docs/problems/README.md`. The deferred-README-refresh contract is the load-bearing distinction from `/wr-itil:manage-problem` — capture-time speed depends on skipping the regenerate-and-stage cycle.

But the P165 README-refresh hook (`packages/itil/hooks/itil-readme-refresh-discipline.sh`) DENIES commits where a new ticket file is staged without `docs/problems/README.md` staged alongside:

```
BLOCKED: P165. P<NNN> needs README refresh: git add docs/problems/README.md. Bypass: BYPASS_README_REFRESH_GATE=1 via .claude/settings.json env (P173).
```

Per the hook's `_readme_refresh_staged_is_ranking_bearing` logic (lines 207-244): any NEW ticket file (status `A`) is treated as ranking-bearing → README MUST be staged. There's no carve-out for `docs(problems): capture` commits.

The hook is the LOAD-BEARING enforcement surface (P165 + ADR-014 amended); the SKILL contract is documentation. Hook wins.

**Workaround used 4× this session**: Edit `docs/problems/README.md` to add the new ticket's row to WSJF Rankings with deferred-placeholder values (e.g. `| 1.5 | P<NNN> | <title> (captured via /wr-itil:capture-problem; Priority/Effort deferred to next /wr-itil:review-problems) | 3 Med | Open | M | 2026-05-18 |`), stage README + ticket together, commit.

## Symptoms

- `git commit -m "docs(problems): capture P<NNN> <title>"` denied with the P165 error above.
- The capture-problem SKILL contract is silent on this hook's existence.
- Adopters following the SKILL contract verbatim will hit this on every capture.

## Workaround

Refresh `docs/problems/README.md` WSJF Rankings with a deferred-placeholder row for the new ticket; stage README alongside the ticket file; commit. The deferred-placeholder shape (`Priority/Effort deferred to next /wr-itil:review-problems`) preserves the SKILL's intent (deferred re-rating) while satisfying the hook's "README must reflect new tickets" enforcement.

## Impact Assessment

- **Who is affected**: Every capture-problem invocation. Observed 4× this session.
- **Frequency**: Likely (3) — fires on every capture commit.
- **Severity**: Minor — workaround works, but the SKILL contract is misleading.

## Root Cause Analysis

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems. (Realized effort M — single-token allow-list addition + SKILL trailer + ADR row + 5 bats fixtures; matched estimate.)
- [x] Architect verdict on the resolution shape:
  - **Option A — Update capture-problem SKILL.md Step 6** to stage README with a deferred-placeholder row. — **REJECTED.** Directly contradicts ADR-032's deferred-README-refresh contract (line 239), which names capture-time speed as the load-bearing distinction from manage-problem; Option A collapses the lightweight variant back toward manage-problem's cost shape ([Decision Conflict] with an accepted-posture amendment).
  - **Option B — Hook carve-out preserving the deferred-refresh contract.** — **CHOSEN, but via the P265 token allow-list, NOT a subject-prefix match.** Register reason-named token `capture-deferred-readme` into `_README_REFRESH_BYPASS_TRAILERS` in `packages/itil/hooks/lib/readme-refresh-detect.sh`; capture-problem Step 6 emits a `RISK_BYPASS: capture-deferred-readme` body trailer. A hard-coded `docs(problems): capture` subject-prefix match was rejected as fragile (couples gate to commit-message prose) and as a registry-invisible second bypass channel; the token reuses the single ADR-014 bypass-token registry of record.
  - **Option C — Hybrid**: subsumed — the chosen shape is "Option C-lite" (SKILL change is the one-line trailer append; the "do NOT stage README" instruction is unchanged).
- [x] Implement chosen option + bats coverage. (5 behavioural fixtures: token-scoped allow + deny-without-trailer-even-when-subject-says-capture + deny-on-docs(problems):open + unregistered-token-still-denies.)

### Resolution (architect-verdict-driven; framework-resolvable — no new ADR)

The fix preserves the ADR-032 deferred-README-refresh contract verbatim. Implementation surfaces:

1. `packages/itil/hooks/lib/readme-refresh-detect.sh` — `capture-deferred-readme` added to `_README_REFRESH_BYPASS_TRAILERS`.
2. `packages/itil/skills/capture-problem/SKILL.md` Step 6 — commit message gains the `RISK_BYPASS: capture-deferred-readme` trailer (second `-m` paragraph); "do NOT stage README" unchanged.
3. `docs/decisions/014-...proposed.md` — bypass-token table row + asymmetry paragraph (within existing reassessment window; no new ADR).
4. `packages/itil/hooks/test/itil-readme-refresh-discipline.bats` — 5 P262 fixtures.

**Asymmetry vs. `adr-031-migration` (load-bearing):** `capture-deferred-readme` clears the **P165 README-refresh gate ONLY**. It is intentionally NOT registered in `risk-score-commit-gate.sh` (which hard-greps only `adr-031-migration`) — a capture commit is real work and must be risk-scored normally, unlike the rename-only ADR-031 migration commit. JTBD review PASS (serves JTBD-006 AFK-cadence, JTBD-001 governance-without-slowdown, JTBD-101 lightweight ceremony; JTBD-301 plugin-user firewall untouched).

## Dependencies

- **Blocks**: (none — workaround works)
- **Blocked by**: (none)
- **Composes with**: P165 (README-refresh hook driver), P155 (capture-problem skill driver), P173 (BYPASS env propagation), P094 (refresh-on-create contract), P265 (RISK_BYPASS-trailer allow-list mechanism this fix extends), P277 (P165 iter-staged-vs-cross-turn distinction — orthogonal; the token carve-out does not touch it)

## Related

- `packages/itil/hooks/itil-readme-refresh-discipline.sh` — hook source.
- `packages/itil/skills/capture-problem/SKILL.md` Step 6 — SKILL contract.
- P165 — README-refresh hook driver.
- P155 — capture-problem skill driver.
- P094 — refresh-on-create contract.

(captured via /wr-retrospective:run-retro Step 4b Stage 1; expand at next investigation)

## Fix Released

Fixed via the `capture-deferred-readme` RISK_BYPASS allow-list token. Surfaces: `packages/itil/hooks/lib/readme-refresh-detect.sh` (token registered), `packages/itil/skills/capture-problem/SKILL.md` Step 6 (trailer emitted), `docs/decisions/014-...proposed.md` (bypass-token table row + README-gate-only asymmetry), `packages/itil/hooks/test/itil-readme-refresh-discipline.bats` (5 P262 fixtures). Changeset queued for `@windyroad/itil`. Awaiting user verification — exercise: run `/wr-itil:capture-problem` and confirm the `docs(problems): capture P<NNN> ...` commit lands without the P165 deny (and that `docs(problems): open` / a capture-subject-without-trailer still denies).

**Exercised in-session**: the full hook bats suite passes 48/48 including the 5 new P262 fixtures — `P262 allow: capture commit with RISK_BYPASS: capture-deferred-readme trailer → allow silently` confirms the carve-out; `P262 deny: capture-subject commit WITHOUT the trailer still denies` confirms it is token-scoped, not subject-scoped (ADR-026 grounding).
