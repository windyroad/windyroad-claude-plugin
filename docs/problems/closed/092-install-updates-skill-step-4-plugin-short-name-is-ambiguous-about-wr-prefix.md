# Problem 092: `/install-updates` Step 4 `<plugin-short-name>` placeholder is ambiguous about the `wr-` prefix

**Status**: Closed
**Reported**: 2026-04-22
**Closed**: 2026-04-24 — verified in-session via run-retro Step 4a. This session's `/install-updates` run applied `npm_name="@windyroad/${plugin_key#wr-}"` to all 11 windyroad plugin keys (architect, c4, connect, itil, jtbd, retrospective, risk-scorer, style-guide, tdd, voice-tone, wardley); `npm view` returned valid version for every one (no empty-version false-negative). Only `wr-itil` flagged as needing update (0.18.0 → 0.18.1); 10 plugins correctly reported as up-to-date. Transformation contract held end-to-end.
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost certain (5)
**Effort**: S
**WSJF**: (15 × 1.0) / 1 = **15.0**

## Description

`.claude/skills/install-updates/SKILL.md` Step 4 tells the skill to check npm for each plugin's latest version:

```bash
npm view "@windyroad/<plugin-short-name>" version
```

The `<plugin-short-name>` placeholder is not defined anywhere in the SKILL.md. The windyroad plugin naming convention diverges in a non-obvious way:

- **Plugin name** (Claude Code registration + marketplace cache key): `wr-itil`, `wr-architect`, etc.
- **Source directory** under `packages/`: `itil`, `architect`, etc.
- **npm package name**: `@windyroad/itil`, `@windyroad/architect`, etc. — matches the source directory, NOT the plugin name.

Using `@windyroad/wr-itil` (wrong — this is the plugin name) returns empty output with exit 0 from `npm view`, silently. Using `@windyroad/itil` (correct — source directory / npm package name) returns the real version.

Observed 2026-04-22 during a `/install-updates` invocation: the assistant used the marketplace plugin name as the npm package name for all 11 plugins, got empty output for every one, and falsely concluded "npm view returns empty — the windyroad plugins aren't on npm public registry." User corrected with the npm URL `https://www.npmjs.com/package/@windyroad/itil` (public). The skill fell through to comparing `marketplace.json` versions against cached versions, which gave a coincidentally-correct "nothing to install" result — but if a plugin had been ahead on npm vs the cache, the naming bug would have masked the divergence silently, and the skill would have reported "already up to date" when a re-install was actually needed.

## Symptoms

- `npm view "@windyroad/wr-<name>" version` returns empty output with exit 0 for every plugin.
- The per-plugin npm-latest vs cached comparison bypasses itself silently because the "latest" side is empty.
- The skill may report "already up to date" even when a plugin has a newer npm version than the installed cache.
- An LLM reading the skill's Step 4 and its own empty `npm view` output may conclude "the plugins are private" instead of "I used the wrong package name" — and communicate that to the user.

## Workaround

Manually strip the `wr-` prefix when constructing the npm package name:

```bash
npm view "@windyroad/$(plugin_short_name_without_wr_prefix)" version
```

For example, for plugin `wr-itil`, the npm package is `@windyroad/itil`.

## Impact Assessment

- **Who is affected**: Every user of `/install-updates`. The skill is shipped as a repo-local skill (ADR-030) and may be copied into downstream windyroad adopter projects.
- **Frequency**: Every `/install-updates` invocation, because the npm-view step runs unconditionally across every enabled plugin.
- **Severity**: Moderate — version-skew detection silently bypasses itself. Coincidental correctness this run (nothing was ahead on npm), but the bug is latent and will cause a missed re-install the first time a plugin publishes ahead of its cached copy.
- **Analytics**: No direct metric; session transcripts carrying the false conclusion text ("the plugins aren't on npm public registry") are the primary evidence.

## Root Cause Analysis

### Root cause — confirmed

`.claude/skills/install-updates/SKILL.md` Step 4 uses a placeholder (`<plugin-short-name>`) whose semantics diverge from the name used everywhere else in the skill. Steps 2 and 3 operate on the marketplace plugin name (`wr-itil`) — enabled-plugin key in `.claude/settings.json`, marketplace cache directory, rename-mapping table. Step 4 then uses what looks like the same name but in fact needs the `wr-`-stripped form for the npm package. The SKILL.md does not call this divergence out. The word "short-name" does not cue it either — `wr-itil` is already a short name compared to `@windyroad/wr-itil`.

### Fix strategy

Edit `.claude/skills/install-updates/SKILL.md` Step 4:

1. Replace the `<plugin-short-name>` placeholder with an explicit naming convention: `npm package name = "@windyroad/" + marketplace-key.replace(/^wr-/, "")`, i.e. the source-directory name under `packages/`.
2. Add a worked example showing the transformation: plugin `wr-itil` → npm package `@windyroad/itil`; plugin `wr-architect` → npm package `@windyroad/architect`.
3. Add a note: "An empty `npm view` response with exit 0 means the package name is wrong, NOT that the package is private. Verify the name before concluding the package doesn't exist."
4. Optionally: record the canonical transformation in a bash-quotable one-liner the skill can copy-paste, e.g. `npm_name="@windyroad/${plugin_key#wr-}"`.

### Investigation tasks

- [x] Investigate root cause (confirmed — SKILL.md Step 4 placeholder is ambiguous).
- [ ] Create reproduction test (straightforward — invoke `npm view "@windyroad/wr-itil" version` and assert empty output with exit 0; invoke `npm view "@windyroad/itil" version` and assert non-empty output). *Deferred — not blocking the SKILL.md clarity fix; a behavioural test would exercise the transformation, which this clarity edit already documents inline.*
- [x] Implement fix — edit Step 4 per the fix strategy above. *Applied 2026-04-22 AFK iter 1 — `.claude/skills/install-updates/SKILL.md` Step 4 now uses `npm_name="@windyroad/${plugin_key#wr-}"` with worked examples, ADR-002 naming-convention pointer, and an "empty `npm view` means wrong name, not private" callout.*
- [ ] Verify the fix in a subsequent session by re-running `/install-updates` and checking that the per-plugin npm-view results return real versions.

## Fix Strategy

- **Kind**: improve
- **Shape**: skill
- **Target file**: `.claude/skills/install-updates/SKILL.md` Step 4
- **Observed flaw**: The `<plugin-short-name>` placeholder is ambiguous; it reads as "use the marketplace plugin name" but the correct value for npm is the source-directory name (marketplace key minus the `wr-` prefix).
- **Edit summary**: Replace the placeholder with an explicit naming convention + worked example + note that empty `npm view` output means "wrong name," not "private package."
- **Evidence**:
  1. Bash turn `npm view "@windyroad/wr-itil" version` (+ 10 more plugins) returned empty output × 11 this session.
  2. Assistant false conclusion "npm view returns empty — the windyroad plugins aren't on npm public registry."
  3. User correction with npm URL `https://www.npmjs.com/package/@windyroad/itil` (public).

Chosen per run-retro Step 4b Stage 2 Option 2 (`Skill — improvement stub`). The fix is a bounded edit to an existing SKILL.md — no new concept, no new plugin, no new ADR required.

## Fix Released

- **Released**: 2026-04-22 (AFK iter 1) — repo-local skill (ADR-030), no npm release required; fix effective next `/install-updates` invocation.
- **Commit**: pending (this iteration).
- **Verification**: next `/install-updates` run should query real npm names (e.g. `@windyroad/itil`) and return non-empty version strings. An empty response across all plugins means the fix regressed.

## Related

- **P058** (install-updates regex misses digit plugin names) — same skill, different defect (regex scope). Distinct from this naming-convention bug.
- **P059** (install-updates no plugin rename handling) — same skill, different defect (rename migration). Distinct.
- **P061** (install-updates Step 6 consent gate sibling cap) — same skill, different defect (consent-gate fallback). Distinct.
- **ADR-030** — governing decision for repo-local skills. install-updates is the first repo-local skill example cited by this ADR; correctness of its SKILL.md is load-bearing on the pattern's credibility.
- **BRIEFING.md** — the 2026-04-22 entry added this session captures the user-facing surprise ("empty `npm view` means wrong name, not private package").
