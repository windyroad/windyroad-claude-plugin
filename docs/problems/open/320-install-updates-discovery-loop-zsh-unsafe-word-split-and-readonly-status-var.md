# Problem 320: /install-updates Step 2/3 discovery loop is zsh-unsafe — `for X in $VAR` word-split (P133) + `status` is a read-only zsh var

**Status**: Open
**Reported**: 2026-05-27
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Running `/install-updates` this session, the Step 2/3 plugin-discovery + version-compare loop failed twice on zsh:

1. **`for key in $CURRENT_PLUGINS` iterates ONCE under zsh** (P133): `$CURRENT_PLUGINS` is a newline-joined multi-line string; zsh does NOT word-split unquoted variables by default, so the loop body ran a single time with `key` = the entire 11-plugin blob. `npm view` then got a garbage package name and every plugin reported `npm=?  cached=none`. The skill's own Step 2/3 example uses exactly this shape (`for key in $CURRENT_PLUGINS`) despite the skill carrying a P133 warning about it elsewhere — the warning and the example contradict.
2. **`status` is a read-only special variable in zsh**: a version-compare loop using `status=...` died with `(eval):12: read-only variable: status`. Had to rename to `st`.

Both forced rewrites mid-skill (to a `while IFS= read -r` loop + a non-reserved var name) before the version comparison worked.

3. **Version-compare `sort -V | tail -1` false-positives on SHA-named git-source residual dirs** (2026-05-28 recurrence). The cache dir for each plugin contains BOTH semver dirs (`0.8.3`, `0.8.4`) AND an old git-source residual dir named by SHA (`2287c49f7b4b`). A "newest cached" compare of `ls … | grep -E '^[0-9]' | sort -V | tail -1` picks the **SHA** dir — `sort -V` treats `2287c49f7b4b` as version `2287` (> any `0.8.x`), so it sorts last and `tail -1` returns it. Result: EVERY plugin's "newest cached" reads as the SHA, `!= npm latest`, and all 11 plugins false-report `<-- UPDATE` / stale. This is exactly the trap the `feedback_verify_cache_refresh_by_version_dir` memory warns about. The correct compare filters to strict semver dirs: `grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'` before `sort -V | tail -1`. The skill's Step 3 text ("compare against the cache directory … npm latest > highest cached version") does not specify the semver filter, so the naive compare false-positives.

**Recurrence 2026-05-28 (2nd install-updates run this session, post-release):** defect 1 (the `for key in $CURRENT_PLUGINS` word-split) fired AGAIN — confirming it's not a one-off. Defect 3 (SHA-sort) surfaced on the same run. Both caught + worked around mid-skill (while-read loop + semver-filter grep), but the skill's prescribed Step 2/3 snippets still carry both bugs.

## Symptoms

- `/install-updates` Step 3 prints all enabled plugins concatenated on one line, `npm view` empty, all plugins show `cached=none` → false "nothing to update" conclusion (the P092 hazard the skill warns about, reached via the P133 word-split).
- A loop assigning `status=` aborts with `read-only variable: status` under zsh.

## Workaround

Use `while IFS= read -r key; do ...; done < <(printf '%s\n' "$CURRENT_PLUGINS")` (or a bash array per P133) and avoid the reserved names `status` (use `st`), `path`, `pipestatus`, etc.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Fix the install-updates SKILL.md Step 2/3 example: replace `for key in $CURRENT_PLUGINS` with a `while IFS= read` loop (or bash array + `"${ARR[@]}"`) per P133; the skill already cites P133 for its Step 4 array — extend the discipline to Step 2/3.
- [ ] Audit the skill's shell snippets for zsh-reserved variable names (`status`, `path`, `argv`, `pipestatus`).
- [ ] Fix Step 3 version-compare to filter to strict semver dirs (`grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'`) before `sort -V | tail -1`, so SHA-named git-source residual dirs (`2287c49f7b4b`) cannot win the sort and false-flag every plugin stale (defect 3; the `feedback_verify_cache_refresh_by_version_dir` memory's exact trap).

## Dependencies

- **Composes with**: P133 (bash-array portability — same class; the skill's Step 4 already applies it, Step 2/3 does not), P092 (empty `npm view` = wrong name, reached here via the word-split).

## Related

- captured via /wr-retrospective:run-retro Step 2b (Skill-contract violation), 2026-05-27. Witnessed running /install-updates after the architect@0.9.2 release.
