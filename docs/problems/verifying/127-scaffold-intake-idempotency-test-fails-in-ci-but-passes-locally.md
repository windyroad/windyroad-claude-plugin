# Problem 127: scaffold-intake idempotency bats fixture (test 645) fails in CI but passes locally — local-vs-CI test divergence on the same commit

**Status**: Verification Pending
**Reported**: 2026-04-26
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: S — narrow surface (one bats fixture in one new skill); fix is one of: (a) make `scaffold_all` produce deterministic output (strip timestamps / session-ids from the done-marker; canonicalise template substitution); (b) tighten the diff comparison in the bats fixture to ignore known-non-deterministic fields; (c) fix the `cp -R . .snapshot-1` snapshot mechanism if the snapshot itself is non-deterministic. Investigation should run the failing test in a CI-like fixture (linux + clean filesystem) to reproduce; once reproduced the fix is a 1-3 line edit to either the SKILL.md template or the bats fixture.
**WSJF**: (9 × 1.0) / 1 = **9.0**

> Surfaced 2026-04-26 by AFK iter 7 P065 commit `8653541` — iter ITERATION_SUMMARY claimed "Full bats suite 1135 ok / 0 failures" but origin CI run `24950750567` and the post-retro CI run `24954418157` (both at HEAD `8653541` and `1e253c3` respectively) reported `not ok 645 fixture: full re-application is idempotent (no diff)` in `packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats:122`. Local-vs-CI test divergence on the same commit blocks @windyroad/itil's release pipeline (CI workflow red on every commit since 8653541; Release + Release Preview workflows still green so adopters aren't blocked, but the CI red signals an unfixed regression).

## Description

`packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats` test 122 asserts the scaffold-intake skill is idempotent: invoking `scaffold_all` twice on the same fixture directory should produce no diff between the post-first-call snapshot and the post-second-call state.

The test shape:

```bash
@test "fixture: full re-application is idempotent (no diff)" {
  scaffold_all
  cp -R . "$TEST_DIR/.snapshot-1"
  scaffold_all
  run diff -ru \
    --exclude='.snapshot-1' \
    --exclude='.git' \
    "$TEST_DIR/.snapshot-1" "$TEST_DIR"
  [ "$status" -eq 0 ]
}
```

In CI, `diff -ru` returns non-zero (a diff exists). Locally on the iter 7 development machine, the test passed (1135/0 reported). The test passes the local invocation but fails origin CI on the same commit SHA — local-vs-CI divergence on a deterministic-by-contract test.

## Symptoms

- CI workflow `Run hook tests` step exits 1 with `not ok 645 fixture: full re-application is idempotent (no diff)` on every commit since `8653541` (P065 fix landed 2026-04-26).
- Local `bats packages/itil/skills/scaffold-intake/test/` reports the test passing.
- The other scaffold-intake bats tests (28 in fixture + 11 in contract + 6 in secrets-absent — total 45) all pass in both environments; only test 645 diverges.
- @windyroad/itil's release pipeline shows CI red on the tip commit; Release + Release Preview workflows pass cleanly, so adopters consuming `@windyroad/itil@0.20.0` are not blocked — but the CI red is a class-of-behaviour signal that test reliability is undermined.

## Workaround

None today. Adopters can ignore the CI red because Release workflow is green. Iter 7's commit `8653541` is in tree on origin/main and the new `/wr-itil:scaffold-intake` skill ships in `@windyroad/itil@0.20.0` (released this session via `release:watch` after the AFK loop's earlier drains). Subsequent retro commits in this session inherit the CI red without contributing to it.

## Impact Assessment

- **Who is affected**: every contributor + every CI consumer of this repo. The CI red on every push since 8653541 introduces a "perpetual broken main" state where developers can't tell which commit broke CI vs which inherited the brokenness from an earlier commit. Same class as P116 (intermediate-commit invisibility) but at a different surface — that's about regressions CI never sees; this is about CI seeing the same regression on every commit because the bug is in tree.
- **Frequency**: every push. Until the test is fixed or skipped, every CI run on main is red.
- **Severity**: Moderate. Not blocking releases (Release workflow green) but corrupts the CI green-on-main signal that other governance contracts depend on (e.g. `release:watch`'s drift-vs-go check, future bisect operations, contributor confidence).
- **Likelihood**: Certain — it's deterministic-failing in CI now.
- **Analytics**: 2 CI runs at HEAD `1e253c3` confirm the failure (databaseId 24954418157 fail; 24954423682 success on Release Preview workflow); 1 CI run at HEAD `8653541` (databaseId 24950750567 fail).

## Root Cause Analysis

### Confirmed root cause (2026-04-26)

**`cp -R . dest` refuses to copy a directory into itself on GNU coreutils** — the bats fixture's snapshot step is

```bash
cp -R . "$TEST_DIR/.snapshot-1"
```

with `$PWD == $TEST_DIR`. GNU `cp` (Linux / Ubuntu CI) detects that the destination is a child of the source and refuses with:

```
cp: cannot copy a directory, '.', into itself, '/tmp/tmp.hMtaSdq3wd/.snapshot-1'
```

(The Alpine BusyBox `cp` in the bats:latest container worded the same condition as `cp: recursion detected, omitting directory './.snapshot-1'`.) BSD `cp` on macOS APFS does NOT detect this case and silently succeeds, which is why the test passed locally on the iter 7 development machine. The non-zero exit from `cp` failed the test (bats halts on uncaptured non-zero); the test name suggested the diff was the failure but the actual failure was the snapshot step, never the diff.

Reproduced 2026-04-26 in `bats/bats:latest` Docker container against the iter 7 commit content. Original three candidate hypotheses ruled out:

- **Candidate 1 (non-deterministic scaffold_all output)**: ruled out — `scaffold_all` only invokes `sed` against fixed templates; the done-marker is `: > .claude/.intake-scaffold-done` (zero-byte file, no timestamp). No timestamp / session-id / hostname surfaces in any template or in the marker.
- **Candidate 2 (cp -R snapshot non-determinism)**: closest to the actual cause — the snapshot mechanism IS the bug, but the failure mode is "GNU cp refuses self-recursion," not mtime / permission divergence. APFS-vs-ext4 case sensitivity and permission bits were not engaged.
- **Candidate 3 (filesystem case-sensitivity)**: ruled out — file paths are fixed and identical across both invocations of `scaffold_all`; no case-divergence path is reached.

### Fix applied

`packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats:122` — snapshot now writes to a sibling `mktemp -d` directory outside `$TEST_DIR`, eliminating the source-into-itself recursion. `diff -ru` runs against the sibling snapshot; the snapshot dir is removed before the assertion runs. No production SKILL.md or template changes — production scaffold logic was already deterministic.

Verification: 29/29 pass on Linux substrate (`bats/bats:latest` Alpine container) AND 29/29 pass on macOS local (BSD coreutils) AFTER the fix. Before the fix, test 21 (post-recount: was test 645 in the full suite) failed deterministically on Linux and passed on macOS.

### Preliminary hypothesis (3 candidates — superseded by confirmed cause above)

**Candidate 1: Non-deterministic output in scaffold_all**. The skill writes templated files (SECURITY.md, CONTRIBUTING.md, SUPPORT.md, problem-report.yml, config.yml) plus a done-marker (`.claude/.intake-scaffold-done`). If any of these embeds a timestamp, session-id, hostname, username, or randomly-ordered iteration over a hash, the second invocation produces different content from the first.

Signals to check: grep the templates for `Date()`, `__DATE__`, `$(date)`, `${SESSION_ID}`, `$(hostname)`, `$USER`. Grep `scaffold_all` itself for the same. Inspect the `.claude/.intake-scaffold-done` file content — if it carries a timestamp, that's the smoking gun.

**Candidate 2: cp -R snapshot mechanism non-determinism**. `cp -R . "$TEST_DIR/.snapshot-1"` recursively copies everything in `$TEST_DIR` BEFORE the second `scaffold_all`. The snapshot dir itself doesn't yet exist when `cp` starts (it's the destination), so it's not copied into itself — but the snapshot's mtime/permissions may differ from the original on filesystems with different `noatime` / `relatime` semantics. CI uses Linux ext4; local likely macOS APFS. APFS preserves nanosecond mtime; ext4 may not. `diff -ru` doesn't compare mtimes by default, but if the test relies on `cp -p` (preserve mode), the failure could be permission-mode mismatch.

Signals to check: run the test in a Linux container locally to reproduce. Check the actual diff output (`bats --tap` to see what diff -ru reports).

**Candidate 3: Filesystem permission / case-sensitivity**. macOS APFS is case-insensitive by default; ext4 is case-sensitive. If `scaffold_all` writes a file whose path differs in case between first and second invocations (e.g. `SECURITY.md` first, then `security.md` second), macOS treats them as the same file (overwrite); Linux treats them as different files (both exist after second call → diff appears). Less likely given the fixed template names but worth ruling out.

### Investigation Tasks

- [ ] Reproduce the failure locally — run the bats test in a Linux Docker container (`docker run -v $PWD:/work -w /work bats/bats:latest packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats`) or via GitHub Actions debug mode.
- [ ] Once reproduced, capture the actual `diff -ru` output to identify the specific file + content that differs.
- [ ] Implement the candidate fix (likely Candidate 1: strip non-deterministic content from the done-marker or the templates).
- [ ] Add a regression bats: re-run the test 10× and assert all pass — catches future non-determinism that may pass once and fail once.
- [ ] Update `docs/briefing/releases-and-ci.md` "Iter retro's '1135/0 bats green' claim does NOT guarantee CI green on the same commit" entry with this ticket's resolution.

### Fix Strategy

**Kind**: improve

**Shape**: bats fixture / SKILL.md template (depending on RCA outcome)

**Target files** (likely):
- `packages/itil/skills/scaffold-intake/templates/<file>.tmpl` — strip non-deterministic content (timestamps, session-ids).
- `packages/itil/skills/scaffold-intake/SKILL.md` — Step that writes the done-marker; ensure deterministic content (e.g. just `1` rather than `$(date -Iseconds)`).
- `packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats` — add the 10× regression assertion.
- `.changeset/wr-itil-p127-*.md` — patch entry.

**Out of scope**: extending the idempotency assertion to other skills' fixtures. Cross-platform CI matrix (running CI on macOS in addition to Linux). Both deferred — if the fix lands cleanly, the local-vs-CI divergence is closed for this skill; broader hardening is a separate concern.

## Dependencies

- **Blocks**: any release that wants CI green on main (currently CI is red on every commit since `8653541`; release pipeline still works because Release workflow runs separately and passes).
- **Blocked by**: (none — fix is bounded; investigation is mechanical reproduction).
- **Composes with**: P065 (Known Error — the parent feature this test was added for; fix here closes the test gap). P116 (closed — intermediate-commit invisibility; adjacent class but distinct surface). P126 (open — orchestrator failure-handling halt path; this ticket's CI failure was the halt cause that triggered P126's surfacing).

## Fix Released

Released in `@windyroad/itil@0.21.1` (commit `482b54a` fix → release commit `4387824`, merge `12c24d8`):
- Snapshot directory moved outside `$TEST_DIR` so the snapshot itself isn't included in the second-pass diff
- `packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats:122` test 645 idempotency assertion now stable across local + CI environments

Awaiting user verification that CI workflow `Run hook tests` passes on tip commit and downstream adopters' scaffold-intake runs remain idempotent.

## Related

- **P065** (`docs/problems/065-no-skill-scaffolds-intake-files-in-downstream-projects.known-error.md`) — parent feature ticket. P065 shipped the scaffold-intake skill + fixture in commit `8653541`; this ticket's regression is on the fixture's idempotency assertion. P065 stays Known Error until both this ticket lands AND P065's release ships clean (currently held in changesets-holding pending P127 + dogfood).
- **P116** (`docs/problems/116-...closed.md`) — adjacent CI-visibility class. P116 was about CI never seeing intermediate commits; this is about CI seeing the same regression on every commit. Different failure mode, same family.
- **P126** (`docs/problems/126-work-problems-failure-handling-halt-bypasses-step-2-5-routing.open.md`) — this ticket's regression was the halt cause. P126 captures the orchestrator-side gap; P127 captures the test-fixture-side gap. Both surfaced from the same iter-7 commit's local-vs-CI divergence; both ship independently.
- **P064** (`docs/problems/064-no-risk-scoring-gate-on-external-comms.known-error.md`) — adjacent risk-evaluator surface; held in changesets-holding pending dogfood. P127 doesn't block P064's release directly but contributes to the "CI red on main" signal that complicates P064's reinstate decision.
- `packages/itil/skills/scaffold-intake/test/scaffold-intake-fixture.bats:122` — primary fix target.
- `packages/itil/skills/scaffold-intake/SKILL.md` — possible fix target if templates carry non-determinism.
- `docs/briefing/releases-and-ci.md` — "Iter retro's '1135/0 bats green' claim does NOT guarantee CI green on the same commit" entry; updates on resolution.
- **JTBD-001** (Enforce Governance Without Slowing Down) — primary fit. Local-vs-CI divergence undermines test-green-as-safety-signal; fixing restores governance reliability.
- **JTBD-101** (Extend the Suite with New Plugins) — composes; downstream adopters of the scaffold-intake skill see the test red on import and can't trust the skill's idempotency claim until the test is fixed.
- 2026-04-26 session evidence: AFK iter 7 P065 fix shipped commit `8653541`; iter retro claimed 1135/0 green; CI run `24950750567` at that commit reported test 645 fail; post-retro push at HEAD `1e253c3` reproduced the same failure (CI run `24954418157`). Release Preview + Release workflows passed at both commits, so adopters not blocked.
