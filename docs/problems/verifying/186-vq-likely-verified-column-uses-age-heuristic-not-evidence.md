# Problem 186: VQ `Likely verified?` column uses age-based heuristic (≥14 days = yes) instead of session-observed evidence — sibling proxy-for-evidence anti-pattern to P185

**Status**: Verification Pending
**Reported**: 2026-05-12
**Priority**: 10 (High) — Impact: 2 (Minor — VQ display heuristic misframes closure signal in installed SKILL; published packages unaffected; no incorrect closure because user still confirms each close, but the framing primes default-yes on age) x Likelihood: 5 (Almost certain — every `/wr-itil:review-problems` pass re-renders the column; observed today on the P016/P017/P024/P047/P048 prompt batch where the heuristic surfaced 5 candidates and user critiqued 3 of them as not-evidence)
**Effort**: M (rewrite `Likely verified?` semantics from age-based to session-observed-evidence; update Step 3 + Step 5 render contracts in `/wr-itil:review-problems` SKILL.md + sibling drift-detection across `/wr-itil:list-problems` + `/wr-itil:manage-problem` Steps 5/7/9c/9e + `/wr-itil:transition-problem(s)` + `/wr-itil:reconcile-readme`; behavioural bats for cell-render contract; full sibling-skill contract suites re-run)
**WSJF**: 5.0 = (Severity 10 × Status Multiplier 1.0 Open) / Effort divisor 2 (M)

## Description

VQ `Likely verified?` column uses age-based heuristic (≥14 days = yes) instead of session-observed evidence — sibling proxy-for-evidence anti-pattern to P185 at the review-problems Step 3/5 surface. User critique 2026-05-12 during Step 4 prompt batch: "I don't like 'it's been a while, so likely verified' approach. We want firm evidence. For these, it should be things you actually observe."

## Symptoms

(deferred to investigation)

## Workaround

(deferred to investigation)

## Impact Assessment

- **Who is affected**: (deferred to investigation)
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems (re-rated inline 2026-05-12 — Severity 10 High, Effort M, WSJF 5.0; same pass as capture per "newly captured ticket in this review pass" carve-out)
- [x] Audit existing VQ entries in `docs/problems/README.md` for over-staged `yes (N days)` rows lacking direct session-evidence (2026-05-15 AFK iter — 69 age-marker rows re-rendered to `no — not observed`; P024 + P048 prose-evidence rows collapsed to canonical shape; total 71 `no — not observed` cells in VQ post-iter)
- [x] Decide canonical cell shape — adopted 2026-05-15 AFK iter: `yes — observed: <evidence>` / `no — not observed` / `no — observed regression`; aging surfaces separately via the `Released` column. Architect verdict PASS (clean composition of ADR-022 + ADR-014 + ADR-026 + P138 / P150 fix-shape precedent; no new ADR required)
- [x] Decide evidence-detection mechanism — adopted 2026-05-15 AFK iter: Step 4 user confirmation populates `yes — observed: user confirmed <YYYY-MM-DD>`; `run-retro` Step 4a close-on-evidence path populates `yes — observed: <retro citation>`; default for newly-released tickets is `no — not observed`; regression observations populate `no — observed regression — <citation>` and flag for `.verifying.md` → `.known-error.md` flip-back
- [x] Sweep co-located SKILL.md files for cross-file drift (P138 / P150 pattern): review-problems Step 3 + Step 5; list-problems Step 2 + Step 3; manage-problem Step 5 P094 + Step 7 P062 + Step 9c + Step 9e; transition-problem Step 7; transition-problems Step 4a; reconcile-readme Step 3 + Step 4 — all carry the canonical `<!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 -->` marker analogous to P138's TIE-BREAK-LADDER-SOURCE and P150's VQ-SORT-DIRECTION markers; drift-tripwire prose ("drift re-opens P186") at primary owners (review-problems + manage-problem)
- [x] Behavioural bats: `packages/itil/skills/review-problems/test/review-problems-likely-verified-cell-shape.bats` — 17/17 green covering marker presence at every render site (6 contract assertions), canonical cell-value documentation at every site (3 assertions), drift-re-opens-P186 contract prose (2 assertions), age-heuristic-no-longer-authoritative regression guards (2 assertions), template-row vocabulary shift (2 assertions), behavioural assertions on the rendered docs/problems/README.md VQ section (2 assertions: new vocabulary present + new-shape count > old-shape count). Full sibling suite re-run green: 158/158 manage-problem, 150/150 review-problems/list-problems/transition-problem/transition-problems/reconcile-readme combined — no regressions
- [ ] Investigate P048 design-intent vs implementation-drift on the heuristic — was age explicitly chosen or did framing slip during implementation? **Deferred** — orthogonal forensics question; does not block the cell-shape fix. Architect verdict (2026-05-15): "P048's design-intent investigation is institutional knowledge worth preserving but not on the closure path of either ticket. The P048 VQ row already carries the prose 'no — user rejected age-as-evidence framing this session; held pending P186 heuristic-replacement fix', so the audit trail is intact." Picked up in a follow-up iter if backlog priority warrants.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P185 (sibling proxy-for-evidence anti-pattern at /wr-itil:capture-problem Step 1.5 — same fix pattern), P048 (original VQ-detection ticket that introduced the 14-day default — this ticket reopens design-intent vs implementation-drift question), P132 (inverse-P078 / over-ask SKILL-surface variant)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

## Fix Released

2026-05-15 (AFK iter; pending `@windyroad/itil` patch — fold-fix Open → Verification Pending per ADR-022 P143 amendment). Ships:

- **Evidence-first `Likely verified?` cell shape** — three canonical values across every VQ render site: `yes — observed: <evidence>` (session-observed evidence the fix works), `no — not observed` (default for newly-released tickets), `no — observed regression` (fix released, bug recurred). Supersedes the original P048 Candidate 4 14-day age-based heuristic; aging is preserved separately via the existing `Released` column.
- **Greppable HTML-comment marker** `<!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 -->` at every render site for cross-skill drift detection — analogous to P138's `TIE-BREAK-LADDER-SOURCE` and P150's `VQ-SORT-DIRECTION` markers.
- **Render-site sweep** — `/wr-itil:review-problems` Step 3 + Step 5; `/wr-itil:list-problems` Step 2 + Step 3; `/wr-itil:manage-problem` Step 5 P094 + Step 7 P062 + Step 9c + Step 9e; `/wr-itil:transition-problem` Step 7; `/wr-itil:transition-problems` Step 4a; `/wr-itil:reconcile-readme` Step 3 + Step 4. Drift-tripwire prose ("drift re-opens P186") at primary owners (review-problems + manage-problem).
- **Step 4 verification-prompt path updated** — surface `yes — observed: …` rows first for batch-close; `no — observed regression` rows flagged for `.verifying.md` → `.known-error.md` flip-back via `/wr-itil:transition-problem`.
- **`docs/problems/README.md` Verification Queue re-rendered** — 69 age-marker rows (`no (N days)` / `yes (N days)` shape) re-rendered to canonical `no — not observed`; P024 + P048 prose-evidence rows collapsed to the canonical shape (their prose preserved in git history / ticket bodies). Total 71 `no — not observed` cells in VQ post-iter.
- **Behavioural bats** — `packages/itil/skills/review-problems/test/review-problems-likely-verified-cell-shape.bats` 17/17 green covering: marker presence at every render site (6 contract assertions); canonical cell-value documentation at every site (3 assertions); drift-re-opens-P186 contract prose at primary owners (2 assertions); age-heuristic-no-longer-authoritative regression guards (2 assertions); template-row vocabulary shift (2 assertions); behavioural assertions on the rendered `docs/problems/README.md` VQ section (2 assertions). Full sibling suite re-run green: 158/158 manage-problem + 150/150 review-problems / list-problems / transition-problem / transition-problems / reconcile-readme — no regressions.

Architect verdict (2026-05-15): **PASS** — clean composition of ADR-022 + ADR-014 + ADR-026 + ADR-052 + P138 / P150 fix-shape precedent; no new ADR required. Marker grammar matches the established `TIE-BREAK-LADDER-SOURCE` / `VQ-SORT-DIRECTION` shape.

JTBD verdict (2026-05-15): **PASS** — JTBD-001 primary (governance grounded in evidence rather than calendar proxy); JTBD-006 composes (`observed: <evidence>` cell IS the audit trail AFK contract requires; no new halt class); JTBD-301 / JTBD-302 unaffected (plugin-user persona does not see VQ).

Deferred to a follow-up iter (orthogonal to the cell-shape fix): Task 7 — P048 design-intent vs implementation-drift forensics on whether the 14-day age default was an explicit choice or framing slip.

Awaiting user verification. The user verifies on next `/wr-itil:review-problems` invocation: VQ rows must use the new vocabulary (`no — not observed` is the dominant value; `yes — observed: <evidence>` populates when Step 4 confirms; `no — observed regression` populates when a session-observed regression fires). Recovery path if rollback needed: `/wr-itil:transition-problem 186 known-error` to flip back to Known Error, then revert the cell-shape commit.
