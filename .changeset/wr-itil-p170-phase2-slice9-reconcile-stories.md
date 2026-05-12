---
"@windyroad/itil": minor
---

P170 Phase 2 Slice 9 — `/wr-itil:reconcile-stories` trio (skill + script + bin shim) per ADR-060 amendment 2026-05-10 line 270 + reconcile-rfcs / reconcile-readme sibling pattern.

Three coordinated artefacts land together:

- **`packages/itil/scripts/reconcile-stories.sh`** (~215 lines, executable, exit codes 0/1/2 per ADR-040 advisory-exit contract) — Diagnose-only drift detector for `docs/stories/README.md` vs on-disk story inventory. Builds filesystem truth across 5 lifecycle subdirs (`draft`, `accepted`, `in-progress`, `done`, `archived`); parses README `## Story Rankings` + `## Done` sections; emits structured drift entries (`DRIFT` / `STALE` / `MISMATCH`). Reverse-trace pass when `docs/problems/` / `docs/rfcs/` / `docs/jtbd/` exist on disk: verifies the auto-maintained `## Stories` section on each parent against the story frontmatter's `problems:` / `rfcs:` / `jtbd:` claims (three drift kinds per parent tier: `MISSING_REVERSE_TRACE`, `STALE_REVERSE_TRACE`, `STATUS_MISMATCH`).

- **`packages/itil/bin/wr-itil-reconcile-stories`** (2-line bin shim per ADR-049) — `$PATH`-resolved entrypoint that `exec`s the script.

- **`packages/itil/skills/reconcile-stories/SKILL.md`** (~140 lines) — Agent-applied-edits skill that wraps the diagnose-only script. Step-by-step recovery contract: run script → read drift entries → plan edits (README row updates for `DRIFT`/`STALE`/`MISMATCH`; helper invocation for `*_REVERSE_TRACE` and `STATUS_MISMATCH`) → apply edits → verify clean → single-commit per ADR-014. Forward-pointer to `/wr-itil:manage-story review` for INVEST-scoring refresh if reconciliation window crossed an accepted-gate transition.

10-test behavioural bats per ADR-052 at `packages/itil/scripts/test/reconcile-stories.bats`: script + bin shim existence + executable + exec-pattern; parse-error exits (missing README / missing `## Story Rankings` header); clean exit on empty stories dir + empty README tables; STALE detection when filesystem has a draft story not in README; DRIFT detection when README claims story in Rankings but filesystem has it in done; archived stories correctly hidden from both tables (no false-positive drift); SKILL.md presence + canonical name. All 10 green.

Sibling to `packages/itil/scripts/reconcile-rfcs.sh` (ADR-060 Phase 1 item 5) and `reconcile-readme.sh` (P118 / ADR-014). Differences: no WSJF column (I11 invariant per ADR-060 line 253); 5 lifecycle subdirs not 4; per-state subdir layout (no dual-tolerant flat — story tier is post-RFC-002, native-subdir); no Verification Queue or Parked tier (those are problem-tier-specific).

packages/itil/README.md updated to add the `/wr-itil:reconcile-stories` row to the skills table — closes the P159 JTBD-currency drift gate inline.

Markdown-only edits + bash script + bin shim — no HTML writes; voice-tone-hook-on-HTML blocker from P170 line 297 does NOT apply.
