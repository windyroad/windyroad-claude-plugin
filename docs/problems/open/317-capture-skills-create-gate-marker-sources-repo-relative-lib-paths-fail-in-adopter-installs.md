# Problem 317: capture-problem / capture-rfc / manage-problem Step 2 create-gate marker step sources repo-relative `packages/itil/hooks/lib/*.sh` — fails in adopter installs (recurring published-path class: P151/P153/P219)

**Status**: Open
**Reported**: 2026-05-27
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

User report (verbatim): *"we've got bad paths in the publish artifacts again. We need to fix this, but we need to make sure it never happens again."*

The published `capture-problem` (and `capture-rfc`, and `manage-problem`) SKILL.md Step 2 instructs writing the P119 create-gate marker by **sourcing repo-relative paths**:

```bash
source packages/itil/hooks/lib/session-id.sh
source packages/itil/hooks/lib/create-gate.sh
get_candidate_session_ids | mark_step2_complete_candidates
```

These `packages/itil/hooks/lib/...` paths exist **only in this plugin-source monorepo**. In an adopter install the plugin lives in `~/.claude/plugins/cache/windyroad/wr-itil/<version>/` and there is no `packages/itil/` in the adopter's repo root — so the `source` lines fail and `get_current_session_id` / `get_candidate_session_ids` / `mark_step2_complete_candidates` are undefined. The create-gate marker is never written → the subsequent `.open.md` Write is denied by the P119 PreToolUse hook (or lands under the wrong SID). **`capture-problem` is broken for every adopter.**

**Concrete evidence (2026-05-27, adopter project `voder-mcp-hub`):**

```
== marker ==
(eval):source:11: no such file or directory: packages/itil/hooks/lib/session-id.sh
(eval):source:12: no such file or directory: packages/itil/hooks/lib/create-gate.sh
(eval):13: command not found: get_current_session_id
```

(The same run also shows `Error: Exit code 127` on the dup-check line and `next id` compute succeeding — the marker step is the failure surface.)

**Irony / why it slips through:** this exact marker code was executed during the 2026-05-27 windyroad-claude-plugin session (for the RFC-008 capture and for this very capture) and **succeeded — only because the cwd IS the plugin-source monorepo**. The SKILL.md is tested/dogfooded in the one environment where the bad path happens to resolve, so the adopter-tree breakage is invisible from the source repo. That is the structural reason this class keeps recurring (P151 → P153 → P219 → this).

## Symptoms

- In an adopter tree, `/wr-itil:capture-problem` (and `capture-rfc`, `manage-problem`) Step 2 emits `source: no such file or directory: packages/itil/hooks/lib/session-id.sh` + `create-gate.sh`, then `command not found: get_current_session_id`.
- The create-gate marker is not written; the new-ticket Write is denied by the P119 hook OR the marker lands under no/the-wrong SID.
- Invisible from the plugin-source repo (the repo-relative path resolves there), so source-repo dogfooding never reproduces it.

## Workaround

(deferred to investigation) — adopters currently cannot capture cleanly; running from the plugin-source repo masks it. No clean adopter-side workaround until the path is resolved via a PATH shim.

## Impact Assessment

- **Who is affected**: every adopter project that uses `@windyroad/itil` capture/manage skills (the create-gate marker step is on the hot path of `capture-problem`, `capture-rfc`, `manage-problem`).
- **Frequency**: (deferred) — fires on every capture in an adopter tree.
- **Severity**: (deferred) — likely high (core capture workflow broken for adopters; the plugin's primary value surface).
- **Analytics**: (deferred)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [x] **Fix DONE (2026-05-27, RFC-009)**: replaced all repo-relative `source packages/...` marker/lib steps with ADR-049 PATH-shim commands (`wr-itil-mark-create-gate`, `wr-itil-mark-rfc-capture-gate`, `wr-itil-migrate-problems-layout`, `wr-itil-check-upstream-cache-staleness`) that resolve their libs via `$(dirname)`. Applied across capture-problem, manage-problem, work-problems, and added the missing marker step to capture-rfc.
- [x] **Structural prevention DONE ("never happens again")**: extended `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` with line-anchored guards for `source packages/...` + `|| echo packages/...`. Any future repo-relative ref in a shipped SKILL fails CI. Composes with P263 (orthogonal manifest-validation layer).
- [x] **Audit DONE**: full shipped-SKILL sweep found 24 refs (7 KIND A source + 17 KIND B fallback); all fixed. Sibling class P151/P153/P219 — the lint now covers their failure modes too.

## Resolution (2026-05-27 — RFC-009)

Fix-complete. 24 broken refs eliminated; the screenshotted create-gate marker bug (capture-problem/capture-rfc/manage-problem) is fixed; structural-prevention lint is live (15 bats GREEN). Design dogfooded ADR-074 (architect Needs-Direction → user confirmed Option C). 105 affected bats GREEN. **Close to Verifying when RFC-009 releases** (this session's changeset). The P151/P153/P219 merge-vs-distinct decision is deferred to /wr-itil:review-problems (the lint now structurally covers all of them).

## Scope finding (2026-05-27 investigation)

The create-gate marker step is one of **24 broken repo-relative references** in shipped SKILLs (much wider than the screenshot instance):

- **7 HARD `source packages/...` references** (always break in adopters — `source` needs a real file path):
  - `manage-problem/SKILL.md`: `source packages/itil/lib/migrate-problems-layout.sh` (L217); `source packages/itil/hooks/lib/session-id.sh` + `create-gate.sh` (L340–341)
  - `capture-problem/SKILL.md`: `source packages/itil/hooks/lib/session-id.sh` + `create-gate.sh` (L159–160)
  - `work-problems/SKILL.md`: `source packages/itil/lib/migrate-problems-layout.sh` (L130); `source packages/itil/lib/check-upstream-cache-staleness.sh` (L157)
- **17 SHIM-FALLBACK references** of the form `bash "$(wr-itil-script-path 2>/dev/null || echo packages/itil/scripts)/<x>.sh"` across manage-story, reconcile-stories, capture-story, manage-rfc, manage-story-map, capture-rfc, capture-story-map. **`wr-itil-script-path` shim DOES NOT EXIST** — so the repo-relative `|| echo` fallback ALWAYS fires in adopter trees. Effectively hard-broken, just silently.
- 3 comment-only examples in `hooks/lib/*.sh` reinforce the bad pattern (copy-paste hazard).

**P263 does NOT cover this** — it scopes manifest-structure validation (`claude plugin validate`), not runtime path resolution. So structural prevention needs a NEW lint.

**Genuine design decision (needs substance-confirm before building, per ADR-074):** `source`-d libraries can't use the ADR-049 `exec`-shim pattern (a subshell can't export functions back to the caller). Resolution strategies differ for the two reference kinds: a directory-resolver shim (`wr-itil-lib-path` / create the missing `wr-itil-script-path`) that the SKILLs `source "$(wr-itil-lib-path)/x.sh"` from, vs converting source-based helpers into PATH-invoked standalone scripts. This is the substantive choice to confirm.

## Dependencies

- **Composes with**: P263 (CI `--dry-run` per-plugin pre-publish gate — the structural-prevention vehicle), ADR-049 (bin-on-PATH shim pattern — the fix vehicle for this instance).
- **Sibling instances (same recurring class)**: P151 (published skills reference repo-relative script paths), P153 (published skills enumerate repo-relative directories), P219 (manage-problem SKILL.md uses repo-relative script path that fails for plugin-installed users), P281 (capture-problem SKILL template references pre-ADR-031 flat-path shape).

## Related

- **P151 / P153 / P219** — almost certainly the same root class; this is a new concrete surface (the Step 2 create-gate **marker** write specifically). Review-problems should decide merge-vs-keep-distinct and whether a single "no repo-relative paths in published artifacts + CI lint" parent ticket should absorb them.
- **P263** — structural-prevention CI gate; the "never happens again" requirement points here.
- Evidence: adopter project `voder-mcp-hub`, 2026-05-27 (screenshot supplied by user).
- captured via /wr-itil:capture-problem, 2026-05-27. The 3-keyword dup-check (publish|adopter|path) surfaced P151/P153/P219/P263/P281 — listed above for the next /wr-itil:review-problems merge decision.

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| RFC-009 | proposed | Adopter-safe path resolution in shipped SKILLs (P317 — 24 repo-relative references) |
