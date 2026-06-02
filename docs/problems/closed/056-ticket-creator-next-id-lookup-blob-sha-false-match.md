# Problem 056: Ticket-creator next-ID lookup greps blob SHAs, producing wrong `origin_max` values

**Status**: Closed — verified in AFK-iter-7 session 2026-04-21 (4+ clean next-ID computations for P085/P086/P087/P088; sequence 085→086→087→088 with no blob-SHA false-match)
**Reported**: 2026-04-20
**Priority**: 4 (Low) — Impact: Minor (2) x Likelihood: Unlikely (2)
**Effort**: S — one-line fix in two SKILL.md files + bats regression
**WSJF**: 4.0 — (4 × 1.0) / 1

## Description

The next-ID computation bash snippet used by both `wr-itil:manage-problem` (Step 3) and `wr-architect:create-adr` (Step 3) runs `git ls-tree origin/<base> docs/problems/` (or `docs/decisions/`) and then `grep -oE '[0-9]{3}'` to extract IDs. Without `--name-only`, each `git ls-tree` line looks like `<mode> <type> <sha>\t<path>` — the blob SHA is a 40-character hex string that CAN contain runs of three consecutive decimal digits. `grep -oE '[0-9]{3}'` picks those up alongside the real filename prefix.

Observed 2026-04-20 when opening P055: `local_max=054` (correct) but `origin_max=997` (nonsense — came from a blob hash). The per-line `sort -n | tail -1` then picked 997, and the increment logic would have computed `998` as the next ID. The skill's own bash block only returned the right value by coincidence — in a repo with more blobs, the collision is more likely.

Same bug lives in `create-adr` Step 3. This session's six ADR openings (024–029) happened to not expose the bug because `local_max == origin_max` in every case, so the final `max + 1` was correct regardless of noisy input.

## Symptoms

- `origin_max` variable returns a value bearing no relation to any existing problem or ADR ID (e.g. 997, 851, 132) in repos with moderate git history.
- When `origin_max > local_max`, the next-ID increment uses the wrong baseline — a future ticket could mint ID `998` when the real next-ID is `056`.
- Parallel-session ID collision guard (P043) is intended to use this lookup; a false-match undermines its correctness.
- Both `wr-itil:manage-problem` and `wr-architect:create-adr` are affected — same bug in two files.

## Workaround

Visual sanity-check the `origin_max` value before accepting the computed `next` ID. If the value is wildly higher than the local maximum, re-run manually with `git ls-tree --name-only origin/main docs/problems/` (or `docs/decisions/`) piped through `sed 's|^<path>/||'` + `grep -oE '^[0-9]+'`.

## Impact Assessment

- **Who is affected**: any invocation of `/wr-itil:manage-problem` (new ticket) or `/wr-architect:create-adr` (new ADR) in a repo with non-trivial git blob history.
- **Frequency**: every new-artefact creation in affected skills. False-positive rate scales with blob count.
- **Severity**: Minor — visual sanity-check catches it; the final user-facing value is usually correct because `local_max` and `origin_max` frequently agree. But the collision guard from P043 is weakened.
- **Analytics**: observed once this session during P055 creation.

## Root Cause Analysis

### Structural

`git ls-tree <ref> <path>` default output shape is `<mode> <type> <sha>\t<path>`. The SHA is a 40-hex-char string; any `[0-9]{3}` regex over the full line can match digits inside it. The skill's bash pipeline assumes each line's extractable digit-run is a filename prefix, which is only true if `--name-only` is passed.

### Fix strategy

Both SKILL.md files share the same remediation:

```bash
# Before
origin_max=$(git ls-tree origin/main docs/problems/ 2>/dev/null | grep -oE '[0-9]{3}' | sort -n | tail -1)

# After
origin_max=$(git ls-tree --name-only origin/main docs/problems/ 2>/dev/null | sed 's|^docs/problems/||' | grep -oE '^[0-9]+' | sort -n | tail -1)
```

- `--name-only` drops mode/type/SHA columns, leaving only the path.
- `sed 's|^docs/problems/||'` strips the path prefix so `grep -oE '^[0-9]+'` anchors at the start of the filename.
- Same pattern for `docs/decisions/` in `create-adr`.

### Affected files

- `packages/itil/skills/manage-problem/SKILL.md` — Step 3 bash snippet, two lookups (local + origin).
- `packages/architect/skills/create-adr/SKILL.md` — Step 3 bash snippet, two lookups (local + origin). (Local lookup already uses `ls` which is fine; only the origin lookup needs the fix.)

### Investigation Tasks

- [x] Reproduce: observed 2026-04-20 opening P055, `origin_max=997` from a blob SHA.
- [x] Apply the `--name-only` + `sed` fix to both SKILL.md files in one commit.
- [x] Add bats doc-lint tests asserting both skills' Step 3 bash uses `--name-only` (grep assertion).
- [x] Verify the fix does not regress the P043 collision-guard behaviour — both `local_max` and `origin_max` still resolve to filename prefixes and the increment logic is unchanged. Sanity-checked end-to-end: `origin_max=057` (problems) and `origin_max=029` (decisions), matching the real tips.
- [ ] Consider extracting the next-ID computation into a shared helper in `packages/shared/lib/` so future ticket-creator skills don't repeat the pattern. Follow-up, not blocking.

## Fix Released

Fixed in AFK iter 2 of 2026-04-20 session (@windyroad/itil@0.7.2 + @windyroad/architect@0.4.1, pending release). Both SKILL.md Step 3 bash snippets now use `git ls-tree --name-only origin/main <path>` + `sed` path-strip + anchored `^[0-9]+` regex. Two new bats doc-lint tests (4 assertions each, 8 total) assert the presence of `--name-only` and the absence of the buggy bare pattern. Sanity-checked in the same commit: the corrected pipeline returns `origin_max=057` (problems) and `origin_max=029` (decisions), matching the actual tips. Before the fix, the manage-problem pipeline returned `origin_max=997` from a blob SHA on 2026-04-20. Awaiting user verification at the next `manage-problem` (new ticket) or `create-adr` (new ADR) invocation in a session where `origin` has non-trivial git history — the computed next-ID should match `local_max + 1` without the visual sanity-check workaround.

## Related

- **P040** (fetch origin before starting) — sibling concern; closed 2026-04-19.
- **P043** (next-ID collision guard in ticket-creator skills) — the collision guard this bug undermines; closed 2026-04-19.
- `packages/itil/skills/manage-problem/SKILL.md` — primary fix target.
- `packages/architect/skills/create-adr/SKILL.md` — secondary fix target (same pattern).
- BRIEFING.md — observation noted in the 2026-04-20 retro.
- ADR-019 (AFK orchestrator preflight) — the preflight invariant assumes the next-ID logic is sound; weakening it here could cascade.
