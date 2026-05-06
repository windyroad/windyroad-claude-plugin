# Problem 058: `install-updates` SKILL.md under-reports plugins whose names contain digits (regex `[a-z-]+` skips `wr-c4`)

**Status**: Closed
**Reported**: 2026-04-20
**Priority**: 4 (Low) — Impact: Minor (2) x Likelihood: Unlikely (2)
**Effort**: S — one-line regex fix in two places + bats regression test
**WSJF**: 0 (Verification Pending — see ADR-022)
**Type**: technical

## Fix Released

Released in working tree 2026-04-20 (AFK iter 1, P058 worked). Changes:

- `.claude/skills/install-updates/SKILL.md` Step 2 (line 41) and Step 3 (line 58): regex `[a-z-]+` → `[a-z0-9-]+`. Now matches `wr-c4@windyroad` and any future digit-bearing plugin name.
- `.claude/skills/install-updates/test/install-updates-regex-matches-digits.bats`: NEW. 4 bats assertions — doc-lint guard, negative-regression guard, behavioural fixture-grep against `wr-c4`/`wr-itil`/`wr-jtbd`. First bats test under a repo-local skill per ADR-030's "bats tests optional" clause.
- `package.json` line 19: bats `--recursive` glob extended with `.claude/skills/*/test/`. Architect-flagged in same review (the prior glob silently skipped repo-local skill tests — same defect class as P058 itself, ironically). Realises ADR-030 Decision Outcome point 6 wiring.

Exercise evidence: `npm test` ran 363 assertions, all pass. Tests 360–363 are the new P058 bats checks.

Awaiting user verification: confirm next `/install-updates` invocation lists `wr-c4@windyroad` in current/sibling-project discovery (e.g. `bbstats`, `addressr-react`, `addressr`, `windyroad`).

## Description

`.claude/skills/install-updates/SKILL.md` Step 2 and Step 3 each use the regex `"wr-[a-z-]+@windyroad"` to discover windyroad plugins enabled in `.claude/settings.json`. The character class `[a-z-]+` does NOT match digits, so any plugin whose name contains a digit — currently `wr-c4` — is silently skipped from the inventory.

Observed 2026-04-20 on the first invocation of `/install-updates`: the sibling scan reported `bbstats` as having 10 plugins (wr-architect, wr-connect, wr-itil, wr-jtbd, wr-retrospective, wr-risk-scorer, wr-style-guide, wr-tdd, wr-voice-tone, wr-wardley) but MISSED `wr-c4@windyroad`. Confirmed by direct `grep` on `../bbstats/.claude/settings.json`: `wr-c4@windyroad` was present and enabled.

`wr-c4` is the only currently-published windyroad plugin with a digit in its name. If wr-c4 ever releases an update, `/install-updates` will silently skip it on every project that has it enabled. No error is raised; the report is just incomplete.

## Symptoms

- `/install-updates` sibling scan lists fewer plugins than the project actually has enabled.
- Silent under-match: no warning, no error — the plugin is simply absent from the report and the install loop.
- A `wr-c4` bump would ship to npm but never be re-installed by `/install-updates` unless the user notices and runs `claude plugin install wr-c4@windyroad --scope project` manually.
- Any future windyroad plugin with a digit in its package name (`wr-<something>2`, `wr-3d`, etc.) would be affected identically.

## Workaround

Manually run `claude plugin install wr-c4@windyroad --scope project` in each project that has `wr-c4` enabled, after running `/install-updates`. Or before the fix lands, grep the settings.json directly:

```bash
grep -oE '"wr-[a-z0-9-]+@windyroad"' .claude/settings.json
```

## Impact Assessment

- **Who is affected**: any project that has `wr-c4@windyroad` enabled. Currently: `addressr-react`, `addressr`, `bbstats`, `windyroad`, and this repo (if enabled here). Future: any plugin whose name contains a digit.
- **Frequency**: every `/install-updates` invocation silently skips wr-c4. Not visible without a direct grep.
- **Severity**: Minor — the miss is invisible (no error) but the plugin simply doesn't get refreshed. The user has to notice and run manual install. Unlikely to cause damage, but it directly undermines the skill's one job ("refresh every windyroad plugin install").
- **Analytics**: observed 2026-04-20 first invocation of `/install-updates` (this session).

## Root Cause Analysis

### Structural

Regex character class `[a-z-]+` includes lowercase letters and hyphen but NOT digits. The install-updates SKILL.md has this pattern in two places:

```
grep -oE '"wr-[a-z-]+@windyroad"' .claude/settings.json
grep -qE '"wr-[a-z-]+@windyroad"' "$d.claude/settings.json"
```

Both must be updated. The fix is a one-character addition: `[a-z-]+` → `[a-z0-9-]+`. Package names allowed per npm/Claude Code convention are lowercase + digits + hyphens, so the expanded class covers the full space.

### Fix strategy

1. Edit `.claude/skills/install-updates/SKILL.md` Step 2 and Step 3 regexes: `[a-z-]+` → `[a-z0-9-]+` (two edits).
2. Add a bats doc-lint test at `.claude/skills/install-updates/test/install-updates-regex-matches-digits.bats` (the first test for a repo-local skill per ADR-030's "bats tests optional" contract) asserting that the regex matches `wr-c4@windyroad` in a synthetic settings.json fixture.
3. Optional: add a second assertion that `wr-problem@windyroad` (all letters, current workaround fixture) also matches, to prevent a regression in the other direction.

### Affected files

- `.claude/skills/install-updates/SKILL.md` — Step 2 and Step 3 regex (one-line change each).
- `.claude/skills/install-updates/test/install-updates-regex-matches-digits.bats` — new bats regression test.

### Investigation Tasks

- [x] Reproduce: observed 2026-04-20, `bbstats` sibling scan missed `wr-c4` which is enabled in `../bbstats/.claude/settings.json`.
- [ ] Apply the one-character regex fix to both locations in the SKILL.md.
- [ ] Add bats doc-lint assertion. First bats test under `.claude/skills/<name>/test/` per ADR-030's "bats tests optional" contract — also exercises the "wired into `npm test` via `bats --recursive`" clause.
- [ ] Verify `npm test` picks up the new bats file via the `--recursive` glob (no package.json changes needed if the glob already covers `.claude/skills/*/test/`). If the glob doesn't cover repo-local skill tests, widen it.

## Related

- **ADR-030** — establishes the repo-local skill pattern, including the "bats tests optional under `.claude/skills/<name>/test/`" clause. This problem exercises that clause for the first time.
- **`.claude/skills/install-updates/SKILL.md`** — primary fix target.
- **P056** (closed, Verification Pending) — sibling ticket for a similar regex-correctness bug in the next-ID lookup (`git ls-tree` without `--name-only`). Same class of defect: a regex that looks right but under-matches.
- **BRIEFING.md** — could gain a line about "char-class regex bugs in bash grep pipelines" as a recurring pattern; P058 + P056 are two instances in one session.
