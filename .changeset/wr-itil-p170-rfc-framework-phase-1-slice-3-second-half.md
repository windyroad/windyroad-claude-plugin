---
"@windyroad/itil": minor
---

P170 / ADR-060 Slice 3 (second half): RFC ↔ problem auto-maintained reverse-trace + commit-message trailer advisory hook

Slice 3 of `docs/plans/170-rfc-framework-story-map.md` second half — closes ADR-060 Phase 1 item 10 + item 12 + Confirmation criterion 3. Two commits compose:

**Commit A — B5.T8: skill-side primary surface for the auto-maintained `## RFCs` reverse-trace section**

Adds `packages/itil/scripts/update-problem-rfcs-section.sh` — idempotent helper rewriting the `## RFCs` table on a problem ticket file based on which RFCs claim it via frontmatter `problems:` list. Lazy-empty discipline (zero traced RFCs → section absent) per JTBD-101 atomic-fix-adopter friction guard. Section placement: before `## Fix Released` if present (ADR-022), else at EOF. 15 behavioural bats cases.

`/wr-itil:capture-rfc` Step 6 + `/wr-itil:manage-rfc` Steps 7 + 9e invoke the helper inline so the cross-tier reverse trace stays current at every commit per ADR-014 single-commit grain.

`packages/itil/scripts/reconcile-rfcs.sh` extends with a reverse-trace pass when a `problems-dir` arg is supplied — three drift kinds: `MISSING_REVERSE_TRACE`, `STALE_REVERSE_TRACE`, `STATUS_MISMATCH`. 9 new bats cases (27 green total; backward-compat preserved for the 18 first-half cases).

**Commit B — B5.T9: commit-message `Refs: RFC-<NNN>` trailer advisory hook**

Adds `packages/itil/hooks/itil-rfc-trailer-advisory.sh` — PostToolUse:Bash hook detecting `git commit` invocations whose HEAD commit-message carries `Refs: RFC-<NNN>` trailers (parsed via `git interpret-trailers`). Emits stderr advisory when the driving problem ticket's `## RFCs` table is stale. Drift-detection backstop for ARBITRARY commits authored outside the RFC skills (`feat(...)` / `fix(...)` / `chore(...)` carrying the trailer but bypassing the skill-side inline refresh).

Advisory-only per ADR-014 single-commit grain (never auto-fixes; never follows up with a second commit). Fail-open per ADR-013 Rule 6 on missing inputs / parse errors. Silent-on-pass per ADR-045 Pattern 1; advisory band ≤300 bytes. Multi-`Refs:` malformed-per-finding-8 detection (one commit advances at most one RFC per ADR-060 finding 8). `BYPASS_RFC_TRAILER_ADVISORY=1` env-var escape. 15 behavioural bats cases.

**Atomic graduation contract**

Composes with `wr-itil-p170-rfc-framework-phase-1.md` (Slices 1 + 2 — `12725a3`) and `wr-itil-p170-rfc-framework-phase-1-slice-3.md` (Slice 3 first half — `4c906c4` + `4c90a16`) per ADR-060 finding 12: entire P170 / RFC-001 commit chain graduates atomically; ADR-042 auto-apply paused until RFC-001 reaches `closed`. This changeset moves to `docs/changesets-holding/` immediately after this commit per the held-area README "Process" Step 2.
