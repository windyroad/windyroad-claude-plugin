# Problem 047: WSJF effort buckets are coarse and not re-rated at lifecycle transitions

**Status**: Verification Pending
**Reported**: 2026-04-19
**Priority**: 6 (Medium) — Impact: Minor (2) x Likelihood: Possible (3)
**Effort**: M — SKILL.md additive edits + bats doc-lint test + in-session audit of 8 L-bucket tickets (estimate confirmed accurate for the scope shipped)
**WSJF**: 6.0 — (6 × 2.0) / 2 → now known-error; transitioned 2026-04-19 after root cause confirmed, fix implemented, and bats guard added
**Type**: technical

## Description

After the 2026-04-19 AFK session shipped three fixes (P028, P044, P042), the predicted S/M/L effort buckets broadly matched the actual work — a useful confirmation. But the session also surfaced **two specific gaps** in how WSJF effort is used that degrade ranking quality without being visible in the predictions themselves:

1. **Effort is never re-rated after the initial estimate.** Effort is set at problem creation (often before root cause is confirmed) and carries unchanged through Known Error transition and into final fix. P028's effort was originally flagged "M if auto-release only, L if auto-install is in scope" — the architect split the concerns mid-session but the stored WSJF was not updated to reflect the narrower scope. P044's effort "M" was well-informed (root cause confirmed, fix strategy written) and stayed accurate; P042's "L" was made before architect selection of a specific sync mechanism and turned out to be on the generous side (closer to M in practice). Neither was re-rated at the Known Error transition.
2. **The L bucket is dangerously wide.** The S/M/L scheme maps to < 1 hr / 1–4 hr / > 4 hr, with no ceiling. In practice L spans "one sitting" (P042) to "multi-week cross-plugin work" (P018 TDD BDD, P022 fabricated estimates, P014 aside invocation). When multiple L problems tie at the same WSJF, AFK orchestrators have no signal to prefer the 1-sitting L over the multi-week L — both appear identical in the ranking.

These are both symptoms of a static, coarse effort model that does not track reality as investigation progresses or as problems cluster at the top end of the bucket range.

Related but distinct from P022 (agents must not fabricate time estimates) — P022 is the global "no estimates without grounded data" rule; this ticket is the specific application to WSJF effort buckets with a concrete re-rating and granularity remediation.

## Symptoms

- AFK loops stall or lose momentum when they reach a cluster of L-bucket problems that look equal by WSJF but differ by an order of magnitude in actual effort (session-observed: P018 + P022 + P014 all at WSJF 4.0, all L — none tractable in a single AFK iteration).
- Problems that get significantly refined during investigation (scope narrowed via architect review, concerns split, fix strategy documented) retain their creation-time effort. Downstream decisions use a stale estimate.
- Users cannot distinguish "L (one sitting)" from "L (multi-week)" at ranking time. This is visible from `docs/problems/README.md` alone — every L appears identical.
- Session retrospectives observe "estimates were mostly right" at the per-ticket level but miss that the bucket scheme itself is the limiting factor at aggregate level.
- `manage-problem review` (step 9b) recalculates WSJF from the stored effort bucket but does not itself challenge whether the bucket is still correct given the latest investigation notes.

## Workaround

- User mentally filters L-bucket problems by reading each file's Effort sub-text (e.g. P042 had "L (sync mechanism design + ADR + implementation + CI guard)" hinting at scope; P018 had no similar sub-text but is clearly multi-week).
- User picks problems by intuition during AFK planning, overriding the ranking.
- User re-rates effort ad-hoc when transitioning a file to Known Error (happened this session for P044 Known Error line: "WSJF: 8.0 (8 × 2.0 / 2) — transitioned 2026-04-19 after root cause confirmed and fix strategy documented", which re-applied the status multiplier but not an effort re-check).

None of these are systemic; each repeats per session and relies on user cognitive overhead.

## Impact Assessment

- **Who is affected**: solo-developer persona (JTBD-006 Progress the Backlog While I'm Away) — AFK ranking quality directly affects what the loop tackles; plugin-developer persona (JTBD-101) — inconsistent effort semantics hurt the "clear patterns" promise of the WSJF framework.
- **Frequency**: every `manage-problem review` and every AFK iteration selection. Not gated behind specific user actions.
- **Severity**: Minor — rankings are slightly off, not broken. The AFK loop still makes progress; it just spends more turns evaluating L-bucket problems before stopping (as observed this session, where three WSJF-4.0 problems were checked and all three bailed for architectural-decision reasons).
- **Analytics**: 2026-04-19 session — three fixes shipped (predicted M+M+L; actual close to M+M+M-to-L), three L-bucket problems bailed at AFK stop-condition #2 (all WSJF 4.0, all required user-judgment trade-offs). Effort-bucket tie-breaking had to resort to "older reported date" (step 3 tie-break rule).

## Root Cause Analysis

### Structural: effort is a single scalar set once

`packages/itil/skills/manage-problem/SKILL.md` step 4 captures effort during problem creation via `AskUserQuestion`. Step 7 (Open → Known Error) pre-flight checks for root cause, investigation task progress, reproduction test, and workaround — it does NOT check whether the effort bucket should be re-rated based on the refined understanding. Step 9b re-assesses Impact and Likelihood (which feed into Severity → WSJF) but the Effort re-rate is only implicit: "Estimate Effort (S/M/L) by reading the root cause analysis and fix strategy" — no explicit instruction to compare against the currently stored bucket or to flag a change.

### Structural: L is an open-ended bucket

S and M have numeric thresholds (< 1 hr, 1–4 hr). L has no upper bound — the SKILL.md defines it as "> 4 hours, multiple files, significant change". In a backlog where 10 problems are L and they range from 4 hours to 4 weeks, WSJF cannot distinguish within that bucket. The 4-hour divisor (4) applied to all L problems means a 4-hour L and a 40-hour L both score identically per unit of severity.

### Candidate fixes

1. **Add an effort re-rate pre-flight to step 7 (Open → Known Error)**: checklist gains "Effort bucket reviewed against the documented fix strategy; update if changed and note the reason". Low-cost SKILL.md edit. Smallest increment toward solving concern (1).
2. **Make step 9b's effort re-rate explicit**: change the SKILL.md wording from "Estimate Effort" to "Re-estimate Effort; if the bucket has changed since last review, update the file and note the reason". Pairs naturally with fix 1.
3. **Add an XL bucket** for > ~1 day of multi-file work. Changes the Effort divisor table (e.g. XL = 8). Requires updating SKILL.md tables and existing L-bucket tickets that should be re-rated XL (P018, P022, P014 are obvious candidates from this session's observation). Addresses concern (2).
4. **Optional qualitative sub-text**: require the effort line to include a short bracketed summary like P042's `L (sync mechanism design + ADR + implementation + CI guard)`. Keeps bucket cardinality low but surfaces scope at ranking time.

Candidates 1–3 are complementary, not alternatives. Candidate 4 is nice-to-have.

### Investigation Tasks

- [x] Architect review on the bucket-granularity change: does adding XL need an ADR (it changes the WSJF math surface of the documented skill)? Expected verdict: additive bucket extension is within `manage-problem` scope; ADR not strictly required but welcome. **Confirmed 2026-04-19 — no ADR required; the change is additive within `manage-problem`'s documented WSJF mechanic.**
- [x] Audit existing L-bucket problems (P018, P022, P014, P033, P045, P012, P019, P034) for XL-vs-L classification and update WSJF accordingly when XL lands. **Done 2026-04-19 — 5 re-rated L → XL (P018, P022, P014, P012, P034); 2 stay L with recorded reasons (P019 within-plugin migration, P045 blocked on upstream); 1 skipped (P033 already Known Error / Fix Released).**
- [x] Draft SKILL.md edits for step 7 pre-flight and step 9b explicit re-rate. Include the failure mode in the pre-flight checklist so reviewers have a concrete question to answer.
- [x] Add bats test asserting the updated pre-flight checklist includes effort re-rate (mirrors P030 test pattern: grep for the specific phrase in SKILL.md). **`manage-problem-effort-buckets.bats` — 4 assertions, all GREEN.**
- [x] Consider whether XL should propagate into `manage-incident` (which also uses severity but explicitly rejects WSJF effort scoring per ADR-011). Likely no change needed — keep scope to `manage-problem`. **Confirmed — XL stays scoped to `manage-problem`; ADR-011 boundary respected.**
- [x] Cross-reference with P022 to keep "fabricated estimates" (P022) and "bucket granularity + re-rating" (P047) aligned. **P047 ships static-bucket granularity + re-rating; P022 will later add actuals-grounded bucket selection on top (its own ADR).**

## Related

- P022: `docs/problems/022-agents-should-not-fabricate-time-estimates.open.md` — sibling principle. P022 is the global rule ("no estimates without grounded data"); P047 is the specific manage-problem/WSJF remediation. P022's investigation task "Retrofit WSJF Effort re-rating in `manage-problem review` to use any available actuals" is partly covered by candidate fix 2 above; when P022 lands, P047 should fold in the actuals-grounding layer.
- P018: `docs/problems/018-tdd-enforce-bdd-example-mapping-principles.open.md` — canonical "L that's really multi-week XL" observed this session.
- P014: `docs/problems/014-aside-invocation-for-governance-skills.open.md` — another "wide L" case from this session.
- P016: `docs/problems/016-manage-problem-should-split-multi-concern-tickets.known-error.md` — concern-splitting interacts with effort re-rating; splitting a problem typically reduces each child's effort. Re-rating pre-flight should naturally catch this.
- `packages/itil/skills/manage-problem/SKILL.md` — the fix target (steps 4, 7, 9b; Effort table).
- ADR-011: `docs/decisions/011-manage-incident-skill.proposed.md` — rejects WSJF effort for incidents; informs scope boundary of P047.
- Session evidence: this session's `[Iteration 1–3]` reports in the AFK run that preceded this ticket showed three L-bucket problems with identical WSJF (4.0) all declining to be worked, proving the granularity gap at the top end.

## Fix Released

Shipped in commit pending (this iteration's `fix(itil): manage-problem WSJF adds XL bucket + re-rate pre-flight (closes P047)` commit). Changes:

1. **XL bucket added** to the Effort table in `packages/itil/skills/manage-problem/SKILL.md` with divisor 8 (multi-day or cross-package work, migration, new ADR required).
2. **Step 7 Open → Known Error pre-flight** gains an explicit effort re-rate checklist item: "Effort bucket reviewed against the now-documented fix strategy; if the bucket changed since creation, update the Effort / WSJF lines and note the reason".
3. **Step 9b step 7** reworded from "Estimate Effort" to "Re-estimate Effort (S / M / L / XL) ... note the reason in a short parenthetical".
4. **Example + live-estimate note** added after the effort table so readers see XL in context and understand effort is a live estimate, not a set-once label.
5. **L-bucket audit** completed for the 8 candidates in the investigation tasks:
   - Reclassified L → XL: P018 (BDD/Example Mapping, new ADR + cross-framework + cross-plugin), P022 (fabricated time estimates, cross-cutting ADR + whole-suite audit), P014 (aside invocation, cross-package coordination + new ADR), P012 (skill testing harness, scope explicitly "undefined" + whole-suite retrofit), P034 (centralise risk reports, cross-plugin pattern).
   - Unchanged L: P019 (deprecate single-file JTBD — re-sized S → L at creation with a specific file-list justification; within-plugin), P045 (auto plugin install — blocked on upstream, not cross-package today).
   - Skipped P033 (already Known Error with Fix Released; effort re-rate belongs to next review).
6. **`work-problems` SKILL.md** updated per architect advisory to reference "S to L or XL" in the scope-creep example paragraphs (non-normative consistency fix).
7. **bats doc-lint test** `manage-problem-effort-buckets.bats` (4 assertions) guards the SKILL.md contract: XL row exists with divisor 8, XL description names its scope, step 7 includes the re-rate item, step 9b uses "Re-estimate Effort" + "note the reason" phrasing.

Awaiting user verification: in a subsequent `manage-problem review` or `work-problems` AFK iteration, the new ranking should:
- Show P018, P022, P014, P012, P034 with WSJF re-computed against /8.
- Surface any Open/Known Error tickets that should have been re-rated during this iteration but weren't (false negatives).
- Exercise the step 7 pre-flight item the next time any Open problem transitions to Known Error.

## Related

- `packages/itil/skills/manage-problem/SKILL.md` — primary fix target (Effort table, step 7 pre-flight, step 9b re-estimate).
- `packages/itil/skills/manage-problem/test/manage-problem-effort-buckets.bats` — new regression test.
- `packages/itil/skills/work-problems/SKILL.md` — non-normative example text updated.
- `docs/problems/README.md` — ranking table refreshed with re-rated XL entries.
- P018, P022, P014, P012, P034: re-rated L → XL in this iteration.
- P019, P045: re-rated at same time, kept as L with recorded justifications.
- P022: `docs/problems/022-agents-should-not-fabricate-time-estimates.open.md` — sibling ticket (grounded-estimate rule); P047 is the bucket-granularity + re-rating remediation, P022 is the broader grounding principle. Land P022 after its own ADR to add actuals-grounded bucket selection on top of P047's static buckets.
- ADR-011: `docs/decisions/011-manage-incident-skill.proposed.md` — confirmed boundary: XL does NOT propagate to `manage-incident` (incidents reject WSJF effort scoring by design).

### Investigation Tasks

- [x] Architect review on the bucket-granularity change (PASS — additive, no ADR required; advisory notes applied).
- [x] JTBD review (PASS — serves JTBD-006 "Progress the Backlog While I'm Away" and JTBD-101 "Extend the Suite").
- [x] Audit existing L-bucket problems for XL reclassification (8 audited, 5 reclassified, 2 unchanged with recorded reasons, 1 skipped — P033 Known Error).
- [x] Draft SKILL.md edits for step 7 pre-flight and step 9b explicit re-rate.
- [x] Add bats test asserting the SKILL.md contract (4 assertions, all GREEN).
- [x] Cross-reference with P022 (actuals-grounding is orthogonal; integrate when P022 lands).
- [x] Confirm XL does not propagate to `manage-incident` (ADR-011 boundary).
