# Problem 334: generate-decisions-compendium.sh uses awk substr() with Unicode `…` ellipsis — not portable between macOS BSD awk and Linux GNU awk; CI drift gate fires on cross-platform regenerations

**Status**: Closed
**Reported**: 2026-05-30
**Closed**: 2026-05-31
**Priority**: 12 (High) — Impact: 3 (Moderate — blocks every `@windyroad/architect` release until compendium is regenerated on Linux or generator hardened) × Likelihood: 4 (Likely — fires every time the compendium is regenerated on macOS and pushed to a Linux CI; recurring on every create-adr / capture-adr / review-decisions confirm/amend)
**Origin**: internal
**Effort**: S (per user-directed fix locus option (a) — swap awk substr() `…` → ASCII `...`)
**WSJF**: 12.0 (re-rated 2026-05-31; was placeholder I=3×L=1; user-pinned fix locus (a) collapses Effort M → S, raising WSJF; CI-blocking surface)
**Type**: technical

## Description

The ADR-077 compendium generator at `packages/architect/scripts/generate-decisions-compendium.sh` uses awk truncation with a Unicode `…` ellipsis character at line 214 (`awk -v n=240 '{ if (length($0) > n) print substr($0,1,n) "…"; else print }'`) and inside `compact_join_bullets` / `truncate_with_ellipsis`. macOS BSD awk and Linux GNU awk handle multi-byte substr() differently, so the byte-output of the generator on identical ADR input is platform-dependent.

Witnessed in session 8 iter 1 (P327 / ADR-077 Slice 3): the iter shipped the drift CI bats (test 2145 "committed compendium matches generator output (CI drift gate)") which asserts the committed `docs/decisions/README.md` is byte-identical to `bash $SCRIPT --check docs/decisions`. Locally on macOS `--check` returns exit 0 (compendium up-to-date — 75 ADRs / 68 in-force / 7 historical). On CI Ubuntu (run 26678401861, commit 252702a) the same `--check` returns non-zero — drift detected — and the release workflow is blocked.

Root cause: the committed compendium was last regenerated locally on macOS (commit aef160c, the rejected-pending-supersede marker work, prior to Slice 3). CI's GNU awk produces different bytes from the same ADR set → drift. The drift gate Slice 3 just shipped is doing its job (catching real cross-platform divergence) but the *cause* of the drift is the generator's awk-substr-with-Unicode-ellipsis pattern, not actual ADR-body drift.

## Symptoms

- `bash packages/architect/scripts/generate-decisions-compendium.sh --check docs/decisions` returns exit 0 on macOS, exit 1 on Linux for the same docs/decisions/ snapshot.
- CI `Run hook tests` job fails at TAP `not ok 2145 committed compendium matches generator output (CI drift gate)`.
- `@windyroad/architect@<next>` release blocked — `release:watch` doesn't fire on red CI.

## Workaround

Two options:
1. **Regenerate on Linux**: SSH to a Linux box (or use a Docker container) and run `bash packages/architect/scripts/generate-decisions-compendium.sh docs/decisions`, commit the result, push. CI will then pass on the byte-for-byte Linux-generated compendium.
2. **gawk locally**: install GNU awk via Homebrew (`brew install gawk`) and regenerate locally with `gawk` aliased to `awk` (or modify the script's shebang/awk-invocation to prefer `gawk` when available).

Neither is durable — every adopter contributor on macOS will hit this.

## Impact Assessment

- **Who is affected**: every adopter contributor to `@windyroad/architect` (or any `@windyroad/*` plugin) running on macOS who regenerates the compendium. The drift gate is now a release-blocking surface.
- **Frequency**: every time the compendium is regenerated on macOS and pushed to a Linux CI.
- **Severity**: High — blocks releases; the surface is recurring (regen happens on every create-adr / capture-adr / review-decisions confirm/amend).
- **Analytics**: (deferred to investigation — would benefit from a CI-side regen-and-cmp test that catches the divergence on every PR, not just release time.)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Confirm the awk-substr divergence on a minimal repro (single ADR with a Title or Confirmation that needs truncation)
- [ ] Decide fix locus: (a) replace `awk substr() "…"` with `awk substr() "..."` (ASCII three dots) — simplest, breaks the round-trip but loses the visual `…`; (b) move the truncation logic to perl/python which handle Unicode consistently; (c) pin to gawk in the shebang + document the brew install dependency; (d) regenerate compendium in CI from the canonical Linux awk and commit the result via a release-time bot
- [ ] Create reproduction test that runs the generator under both BSD and GNU awk in CI and asserts byte-identical output

## Dependencies

- **Blocks**: `@windyroad/architect@<next>` release (CI red on session 8 iter 1's compendium-drift gate; release workflow won't run)
- **Blocked by**: (none)
- **Composes with**: P327 (parent ticket — ADR bodies dominate session token usage; the compendium is the load-cost reduction surface), ADR-077 (the design ADR for the compendium)

## Related

- **P327** (`docs/problems/open/327-adr-bodies-dominate-session-token-usage.md`) — driver ticket; this is a deferred-implementation defect in P327's Slice 3.
- **ADR-077** (`docs/decisions/077-decisions-compendium-as-token-cheap-load-surface.proposed.md`) — Confirmation item (g) "CI drift-detection bats"; the bats fires correctly, but the underlying generator is cross-platform-fragile.
- `packages/architect/scripts/generate-decisions-compendium.sh:214` — the line that uses `awk substr() "…"`.
- `packages/architect/scripts/test/generate-decisions-compendium.bats:60-65` — the failing test (line 62 assertion).
- CI run 26678401861 (session 8 iter 1, commit 252702a) — concrete witness.
- Captured via /wr-retrospective:run-retro on 2026-05-30 (session 8 work-problems wrap retro).

## Fix Strategy

**Kind**: improve
**Shape**: script (improvement to existing generator)
**Target file**: `packages/architect/scripts/generate-decisions-compendium.sh`
**Observed flaw**: awk's substr() with Unicode `…` produces machine-dependent byte output between macOS BSD awk and Linux GNU awk
**Edit summary**: Replace `awk substr() "…"` with either (a) ASCII three-dot ellipsis `...`, (b) perl/python truncation, or (c) shebang pin to gawk with a documented brew install dependency. Prefer option (a) as the minimum-blast-radius change.
**Evidence**: CI run 26678401861 test 2145 failure; local `--check` passes vs CI `--check` fails on byte-identical input.

## Resolution

Closed 2026-05-31 (work-problems AFK iter 1, verification close-on-evidence per ADR-044). User-pinned fix locus (a) ASCII `...` shipped in `@windyroad/architect@0.12.2` via a two-layer change: (1) replace Unicode `…` (U+2026) with ASCII `...` in `compact_join_bullets` truncation, `truncate_with_ellipsis`, and the `Chosen:` 240-char trim awk; (2) `export LC_ALL=C` at the top of `packages/architect/scripts/generate-decisions-compendium.sh` so both BSD and GNU awk operate on raw bytes consistently (BSD already does by default; GNU under any UTF-8 locale was counting characters — without LC_ALL=C, ADR bodies containing em-dashes or smart quotes still drifted because `length()` and `substr()` diverged at the truncation threshold).

Commit chain:
- `3945878 fix(architect): P334 awk substr Unicode portability — ASCII '...' for cross-platform compendium`
- `3e53a94 fix(architect): P334 follow-up — LC_ALL=C wrap for compendium generator`
- `e9f7ce4 fix(architect): regenerate compendium with @windyroad/architect@0.12.2 (unblocks CI test 2145)`

Released in `@windyroad/architect@0.12.2` (CHANGELOG entry per ADR-021 references P334 + P328 sibling). Verified in-session:
- Local `bash packages/architect/scripts/generate-decisions-compendium.sh --check docs/decisions` returns exit 0 (compendium up-to-date — 76 ADRs / 69 in-force / 7 historical) on macOS BSD awk.
- CI workflow "CI" on commit `bad2eac` (main, run `26701674556`) succeeded — the cross-platform drift gate test 2145 passes on Linux GNU awk.

Both halves of the contract held: the witnessing failure mode (macOS-regen + Linux-CI drift) cannot recur because both platforms now operate on byte-identical raw-byte arithmetic. Sibling P328 (broader BSD-vs-GNU UTF-8 class) intentionally sidesteps the LC_ALL coupling at the caller layer — out of scope for this ticket.

Reversible via `/wr-itil:transition-problem 334 known-error` if a divergent platform (musl awk, BusyBox awk, etc.) surfaces drift on a future CI matrix expansion.
