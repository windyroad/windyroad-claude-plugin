---
"@windyroad/itil": minor
---

P170 / ADR-060 Slice 3: reconcile-rfcs.sh + wr-itil-reconcile-rfcs bin shim

Slice 3 of `docs/plans/170-rfc-framework-story-map.md` first half — adds the diagnose-only mechanical drift detector for `docs/rfcs/README.md` (mirrors `reconcile-readme.sh` per P118) and the `$PATH` shim per ADR-049 naming grammar.

Composes with the Phase 1 framework code shipped in commit `12725a3` (capture-rfc + manage-rfc skill skeletons + P119 hook generalisation). This changeset will be moved to `docs/changesets-holding/` immediately after this commit per the held-area README "Process" Step 2 — same atomicity contract as `wr-itil-p170-rfc-framework-phase-1.md` (ADR-060 finding 12: entire RFC-001 commit chain graduates atomically; ADR-042 auto-apply paused until RFC-001 reaches `closed`).

**New script**: `packages/itil/scripts/reconcile-rfcs.sh` — read-only drift detector for `docs/rfcs/README.md` vs filesystem RFC inventory. Exit 0 = clean, exit 1 = drift, exit 2 = parse error. Drift line format mirrors `reconcile-readme.sh`'s ADR-038 progressive-disclosure budget (≤150 bytes per row; per-line `DRIFT|MISSING|STALE|MISMATCH` keyword + ID + section + status fields).

**New bin shim**: `packages/itil/bin/wr-itil-reconcile-rfcs` — `$PATH`-resolved entry point per ADR-049 naming grammar.

**Behavioural bats**: `packages/itil/scripts/test/reconcile-rfcs.bats` — 18 cases covering existence + executable, parse-error path, clean path (proposed/accepted/in-progress all WSJF-tier), drift paths (DRIFT / MISSING in WSJF / MISSING in VQ / STALE in VQ / MISMATCH in Closed), output budget (ADR-038 ≤150 bytes/row), stable sort order, ADR-049 bin shim contract.

Slice 3 outstanding tasks (deferred to subsequent invocations): B5.T8 (auto-maintained `## RFCs` section on problem tickets), B5.T9 (commit-message `Refs: RFC-<NNN>` trailer recognition hook).
