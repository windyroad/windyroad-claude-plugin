---
"@windyroad/itil": patch
---

evidence-first `Likely verified?` cell shape across the Verification Queue render surface

The `docs/problems/README.md` Verification Queue's `Likely verified?` column previously used a 14-day age-based heuristic (original P048 Candidate 4 default — `yes (N days)` when the release was ≥14 days old, `no (N days)` otherwise). That framing primes a default-yes verdict based on calendar age rather than session-observed evidence — the inverse of the audit-trail discipline the queue is meant to support.

The column now carries an **evidence-first** cell with three canonical values:

- `yes — observed: <evidence>` — session-observed evidence the fix works. A Step 4 user confirmation, an in-session test invocation outcome (per ADR-026 grounding), or a `/wr-retrospective:run-retro` Step 4a close-on-evidence citation.
- `no — not observed` — fix released but no session-observable evidence yet. Default for newly-released tickets. Aging is preserved separately via the `Released` column.
- `no — observed regression` — fix released and the bug recurred this session. Flags the ticket for `.verifying.md` → `.known-error.md` flip-back via `/wr-itil:transition-problem`.

A greppable HTML-comment marker `<!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 -->` rides every render site for cross-skill drift detection, mirroring the established `TIE-BREAK-LADDER-SOURCE` (P138) and `VQ-SORT-DIRECTION` (P150) marker precedents.

Render-site sweep:

- `/wr-itil:review-problems` Step 3 + Step 5 (primary owner; drift-tripwire prose anchored here).
- `/wr-itil:list-problems` Step 2 + Step 3.
- `/wr-itil:manage-problem` Step 5 P094 + Step 7 P062 + Step 9c presentation + Step 9e template.
- `/wr-itil:transition-problem` Step 7.
- `/wr-itil:transition-problems` Step 4a batch render.
- `/wr-itil:reconcile-readme` Step 3 + Step 4 row-insertion.

Behavioural-contract bats fixture `packages/itil/skills/review-problems/test/review-problems-likely-verified-cell-shape.bats` covers marker presence at every render site, canonical-value documentation, drift-re-opens-P186 tripwire prose at the primary owners, age-heuristic regression guards, and the user-visible vocabulary shift in the rendered `docs/problems/README.md` Verification Queue rows. 17/17 green; full sibling suite re-run green (158/158 manage-problem + 150/150 across review-problems / list-problems / transition-problem / transition-problems / reconcile-readme).

Closes P186 (VQ `Likely verified?` column uses age-based heuristic instead of session-observed evidence — sibling proxy-for-evidence anti-pattern to P185 at the review-problems Step 3/5 surface).
