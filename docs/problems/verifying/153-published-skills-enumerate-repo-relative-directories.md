# Problem 153: Published skills enumerate repo-relative directories — adopter sessions get zero-byte attribution rows from missing trees

**Status**: Verifying
**Reported**: 2026-05-02
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost certain (5) — within RISK-POLICY appetite High but the surface is adopter-facing
**Effort**: S — single SKILL.md edit (`/wr-retrospective:analyze-context` Step 2 lines 56-67) plus an extension to the P151 grep-as-lint bats pattern to catch the directory-enumeration class. No new ADR required — covered under ADR-049's reassessment-criteria amendment clause.

**WSJF**: (15 × 1.0) / 1 = **15.0**

> Surfaced 2026-05-02 by `wr-architect:agent` during P151 review (architect advisory note (e), non-blocking for the P151 fix). Distinct sibling failure mode in the same plugin-boundary class as P151 / ADR-049 — but different failure shape (zero-byte enumeration vs hard-fail dispatch), different surface (directory glob vs file invocation). The P151 grep-as-lint as currently scoped does NOT catch this class; opening P153 keeps the P151 commit scope mechanical and the lint contract precise.

## Description

`packages/retrospective/skills/analyze-context/SKILL.md` lines 56-67 contains repo-relative directory-enumeration glob loops:

```bash
for plugin_dir in packages/*/hooks; do
  plugin=$(basename "$(dirname "$plugin_dir")")
  bytes=$(find "$plugin_dir" -type f -name '*.sh' -print0 2>/dev/null | xargs -0 wc -c 2>/dev/null | tail -1 | awk '{print $1}')
  printf 'PLUGIN-HOOKS %s bytes=%s\n' "$plugin" "${bytes:-0}"
done

for plugin_dir in packages/*/skills; do
  plugin=$(basename "$(dirname "$plugin_dir")")
  bytes=$(find "$plugin_dir" -type f -name 'SKILL.md' -print0 2>/dev/null | xargs -0 wc -c 2>/dev/null | tail -1 | awk '{print $1}')
  printf 'PLUGIN-SKILLS %s bytes=%s\n' "$plugin" "${bytes:-0}"
done
```

When an adopter project (which does not have a `packages/` source tree — adopters install plugins as marketplace cache entries, not as monorepo siblings) runs `/wr-retrospective:analyze-context`, the glob `packages/*/hooks` expands to nothing in the adopter's CWD. The loop body never executes. The skill's deep-layer per-plugin attribution emits **zero rows** instead of populated `PLUGIN-HOOKS <plugin> bytes=<N>` rows. The deep-layer report becomes uninformative without any explicit error — silent degradation, not a hard fail.

This is logically the same class as P151 (repo-relative paths leaking through the plugin boundary) but a **different failure mode**: P151 is hard runtime failure (exit 127 + halt), P153 is silent zero-byte degradation (exit 0 + empty output). Both leak windyroad-internal monorepo layout assumptions through the published plugin boundary.

## Symptoms

- An adopter running `/wr-retrospective:analyze-context` Step 2 sees the per-plugin attribution sections with zero or missing rows, despite plugins being installed in the adopter's marketplace cache. The user has no signal that the data is wrong — the report renders, just without per-plugin breakdown.
- Same applies to any future SKILL.md prose that uses `for d in packages/*/<subdir>; do ... done` loops to walk monorepo packages. The pattern is the same: glob expands to nothing in adopter trees.
- The P151 grep-as-lint pattern (`bash +packages/<plugin>/(scripts|hooks)/<name>\.(sh|py|bats|js|ts)`) does NOT catch this class — the glob loop does not invoke `bash <path>`; it iterates `for X in packages/*/Y; do ...`. Regression-detection is blind to this surface today.

## Workaround

None at the source level — the artefacts ship as-authored. Adopter-side workarounds (none reasonable; documented for completeness):

- Adopter could clone the source repo as a sibling. Same heavyweight workaround as P151's documented none-acceptable list.
- Adopter could set their CWD to the marketplace cache directory before running the skill. Brittle, requires adopter to know the cache layout, defeats the point of the skill being available from any project root.
- Adopter could disable the per-plugin attribution section. Loses the value the deep layer was added for.

None of these are reasonable. The fix has to be at the source — the deep-layer attribution must walk plugins via a path that resolves in adopter trees (e.g. `~/.claude/plugins/cache/<owner>/<plugin>/<version>/` for installed plugins, or sniff the running plugin set from the agent's available `bin/` entries on `$PATH`).

## Impact Assessment

- **Who is affected**: The **plugin-user persona** (`docs/jtbd/plugin-user/persona.md`) — same persona affected by P151. Adopters running `/wr-retrospective:analyze-context` get an under-informative deep-layer report.
- **Frequency**: Every `/wr-retrospective:analyze-context` invocation in any adopter project. Surface frequency is much lower than P151 (analyze-context is invoked on user demand, not as Step 0 of every problem-management invocation), but every invocation degrades silently.
- **Severity**: Moderate — the skill renders a report, just with reduced informational value; no hard failure; no data loss. Distinct from P151's "skill cannot proceed at all" severity. Per RISK-POLICY Impact-3 ("non-trivial UX degradation; user has to work around it or accept reduced value").
- **Likelihood**: Almost certain — known gap, no controls in place. Same as P151's likelihood-5 rating but on a less-frequently-invoked surface.
- **Analytics**: Direct grep evidence (2026-05-02): `grep -nE 'for [a-z_]+ in packages/' packages/*/skills/*/SKILL.md` returns the two loops in `analyze-context` SKILL.md. No other directory-enumeration pattern was found in published skills today, but the absence of a CI lint means future SKILL.md authors can re-introduce the pattern without detection.

## Root Cause Analysis

### Preliminary Hypothesis

Same root cause as P151 — published SKILL.md was authored against the source-repo working tree where `packages/<plugin>/` is the natural traversal root. No build step or path-resolution layer rewrites these references when the plugin is published to the marketplace cache. ADR-049 codified the rule for `bash <script>` invocations but the rule is logically the same for any repo-relative path embedded in SKILL.md prose — the ADR's reassessment criterion 3 explicitly anticipates this extension ("e.g. to cover non-bash invocations such as `python3 packages/<plugin>/scripts/<name>.py`, or repo-relative directory traversals like `for d in packages/*/hooks; do ...`").

### Resolution Strategy — Candidate 1 (walk the marketplace cache instead)

Replace the source-tree traversal with a marketplace-cache traversal. The cache layout is well-defined: `~/.claude/plugins/cache/<owner>/<plugin>/<version>/`. The adopter agent has read access to its own cache. A loop like `for plugin_dir in ~/.claude/plugins/cache/*/*/*/; do ... done` would resolve in any adopter session.

Trade-off: source-repo dev sessions (where the plugin is ALSO available via local `--plugin-dir`) might not appear under `~/.claude/plugins/cache/` and would themselves degrade silently. The fix needs a unified resolution that works in both adopter sessions and source-repo dev sessions.

### Resolution Strategy — Candidate 2 (sniff the running plugin set from `$PATH`)

Each installed plugin's `bin/` is on `$PATH` (verified during P151 investigation, 2026-05-02). The agent can enumerate `$PATH`-visible bin directories whose paths look like a plugin cache (`*/bin/`), then walk back to each plugin's root for the per-plugin attribution. Works in adopter sessions and source-repo dev sessions identically.

Trade-off: requires the deep-layer attribution to consume a `$PATH`-derived plugin list rather than a `packages/*/` glob. More complex than the current loop. Probably wants a small helper script (which itself ships under `bin/wr-retrospective-list-plugins` per ADR-049) rather than inline bash in SKILL.md.

### Resolution Strategy — Candidate 3 (extend ADR-049 grep-as-lint)

Independent of which Candidate 1/2 fix lands, the cross-plugin grep-as-lint at `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` should be extended to catch directory-enumeration patterns: `for [a-z_]+ in packages/[a-z*][a-z0-9*-]*/`. Catches future regressions of this class regardless of which underlying fix is chosen.

### Investigation Tasks

- [x] Confirm marketplace cache layout is stable across Claude Code versions (Candidate 1 viability check) — verified empirically during P151 investigation; cache layout `~/.claude/plugins/cache/<owner>/<plugin>/<version>/` documented in ADR-049 Context.
- [x] Pick between Candidate 1 (cache walk) and Candidate 2 (`$PATH` sniff). Architect concurrence — chose **hybrid Candidate 1+2**: source-tree first (preserves windyroad dev-session output), `$PATH`-derived plugin-cache walk fallback. Architect APPROVED 2026-05-02 citing ADR-049 reassessment-criteria clause 3 — no new ADR required.
- [x] Implement chosen fix in `packages/retrospective/skills/analyze-context/SKILL.md` lines 56-67 — replaced with single `wr-retrospective-list-plugin-attribution "${CLAUDE_PROJECT_DIR:-.}"` invocation.
- [x] Extend `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` to catch `for X in packages/*/Y; do` patterns (Candidate 3 — independent of the implementation choice) — added `@test "no published SKILL.md contains 'for X in packages/<plugin>/<subdir>; do ...' directory-enumeration loop"` matching `for +<var>+ in +packages/<plugin-or-glob>/(hooks|skills|scripts|bin)`.
- [x] Audit `packages/*/skills/*/SKILL.md` for any other repo-relative directory traversals not yet detected — grep-as-lint now covers all current and future skills automatically; no other matches found at fix-land time.

### Resolution

Implemented as a hybrid of Candidate 1 (cache walk) + Candidate 2 (`$PATH` sniff) + Candidate 3 (lint extension):

- New helper `packages/retrospective/scripts/list-plugin-attribution.sh` probes for `<project-root>/packages/*/{hooks,skills}` first; if neither glob expands, sniffs `$PATH` for entries shaped like `*/cache/<owner>/<plugin>/<version>/bin` and back-walks each plugin's root for hooks + skills byte counts. Emits identical row shape to the previous inline loop (`PLUGIN-HOOKS <plugin> bytes=<N>` / `PLUGIN-SKILLS <plugin> bytes=<N>`) plus a `PLUGIN-ATTRIBUTION not-measured reason=no-plugin-source-resolvable` ADR-026 sentinel when neither resolves. Sorted output for stable diffs. Exit 0 always (advisory; matches `measure-context-budget.sh` contract).
- New 3-line shim `packages/retrospective/bin/wr-retrospective-list-plugin-attribution` per ADR-049 naming grammar (`wr-<plugin>-<kebab-script-name>`).
- `packages/retrospective/skills/analyze-context/SKILL.md` Step 2 prose replaced with single invocation; resolution-order documentation inlined for adopter-agent context.
- `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` extended with the directory-enumeration `@test` block + a new shim smoke test (11 tests total, all green).
- New bats coverage at `packages/retrospective/scripts/test/list-plugin-attribution.bats` pins script behavioural contract (10 tests: existence, exit code, source-tree output shape per plugin, multi-plugin enumeration, cache-fallback from synthetic cache layout, sentinel branch, ADR-038 ≤150-byte per-row budget).
- Architect APPROVED + JTBD ALIGNED (plugin-user JTBD-301 adjacency, plugin-developer JTBD-101 "clear patterns, not reverse-engineering").
- Changeset: `.changeset/wr-retrospective-p153-list-plugin-attribution-shim.md` (`@windyroad/retrospective` patch).

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — P151's ADR-049 has already landed by the time P153 is open, so the architectural foundation is in place)
- **Composes with**: P151 (same plugin-boundary class — sibling failure mode), P137 (same plugin-boundary class — semantic-reference leakage)

## Related

- P151 — `docs/problems/151-published-skills-reference-repo-relative-script-paths.verifying.md` (sibling — `bash <script>` invocations failing the same way; ADR-049 fixes that surface; this ticket extends the pattern to directory traversals).
- P137 — `docs/problems/137-published-plugin-artifacts-reference-internal-ids-confuses-adopter-agents.open.md` (sibling plugin-boundary class — semantic references vs P153's executable references; same audit-trail family).
- ADR-049 — `docs/decisions/049-plugin-script-resolution-via-bin-on-path.proposed.md` (reassessment-criteria clause 3 explicitly names this surface as a future extension scope).
- `packages/retrospective/skills/analyze-context/SKILL.md` lines 56-67 — the two specific loop sites identified.
- `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` — the grep-as-lint to extend.
