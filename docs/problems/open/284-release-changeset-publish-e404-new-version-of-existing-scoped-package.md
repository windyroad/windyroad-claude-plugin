# Problem 284: Release pipeline halts — `changeset publish` E404 on a new version of an existing scoped package (@windyroad/architect@0.8.0)

**Status**: Open
**Reported**: 2026-05-23
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

Observed 2026-05-23 during `/wr-itil:work-problems` Step 6.5 release-cadence drain (iter 1, after closing P073).

The Release PR #154 (`changeset-release/main`) merged on `origin/main` — commit `6bda66e` ("chore: version packages") bumped `packages/architect/package.json` AND `packages/architect/.claude-plugin/plugin.json` to `0.8.0`, consumed `.changeset/architect-needs-direction-verdict.md`, and generated `packages/architect/CHANGELOG.md`. The merge then triggered the `Version or Publish` workflow, whose `changeset publish` step **failed**:

```
🦋  info @windyroad/architect is being published because our local version (0.8.0) has not been published on npm
🦋  info Publishing "@windyroad/architect" at "0.8.0"
🦋  error an error occurred while publishing @windyroad/architect: E404 Not Found - PUT https://registry.npmjs.org/@windyroad%2farchitect - Not found
🦋  error '@windyroad/architect@0.8.0' is not in this registry.
npm error code E404
packages failed to publish:
@windyroad/architect@0.8.0
##[error]The process '...npm' failed with exit code 1
```

**Resulting inconsistency**: `origin/main` declares architect `0.8.0` (package.json + plugin.json + CHANGELOG.md), but npm `latest` is `0.7.4`. A version-committed-but-publish-failed split.

**Key diagnostics (rule out the obvious causes):**

- All sibling packages published or correctly skipped in the SAME run with the SAME `NPM_TOKEN` (`@windyroad/itil@0.35.7`, `@windyroad/risk-scorer@0.10.3`, `@windyroad/voice-tone@0.5.3`, etc. all "already published" → skipped cleanly). Architect alone 404'd.
- `@windyroad/architect@0.7.4` + `0.7.4-preview.*` ARE on npm (`npm view @windyroad/architect dist-tags` → `latest: 0.7.4`, `preview: 0.7.4-preview.365`). The package exists; the scope and token generally work.
- `packages/architect/package.json` is structurally identical to the publishing siblings: no `publishConfig`, not `private`. So this is NOT a missing `publishConfig.access: public` defect.
- E404-on-PUT for an existing scoped package is the npm symptom that can mean (a) a transient registry/replication issue, or (b) the token's granular access does not include write to `@windyroad/architect` specifically (npm sometimes returns 404 rather than 403 to avoid leaking package existence). The sibling-publishes-fine evidence argues against a blanket token failure but does not rule out per-package granular access.

CI run: https://github.com/windyroad/agent-plugins/actions/runs/26334143231

## Symptoms

- `npm run release:watch` reports `Release failed` with `Version or Publish` check failing on `npm ... exit code 1`.
- `changeset publish` logs `E404 Not Found - PUT https://registry.npmjs.org/@windyroad%2farchitect` for a single package while siblings succeed.
- `origin/main` package.json / plugin.json version diverges from npm `latest` for the affected package.
- **Loop-blocking**: every subsequent `/wr-itil:work-problems` Step 6.5 drain that produces releasable material re-attempts `architect@0.8.0` (changeset detects it unpublished) and re-hits the E404 — so the AFK loop halts at the first releasable iteration until this is resolved.

## Workaround

Re-run `npm run release:watch` — `changeset publish` re-detects `0.8.0` as unpublished and retries. If the E404 was transient (npm registry/replication), the retry succeeds. If it persists across retries, the cause is access-related: check the npm token's granular write access to `@windyroad/architect` on npmjs.org (package collaborator / access settings), and confirm the token's package-scope allowlist (if a granular token) includes architect.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — maintainer release path; AFK orchestrator loop continuity (JTBD-006); adopters waiting on the architect plugin's published version.
- **Frequency**: (deferred to investigation) — first observed 2026-05-23; recurs on every release attempt while architect 0.8.0 stays unpublished.
- **Severity**: (deferred to investigation) — blocks the release pipeline (recurs every release) but recovery is a re-run; no data loss; version inconsistency is recoverable.
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Determine whether the E404 was transient (re-run `release:watch` and observe) or persistent (access-related)
- [ ] If persistent: audit the npm publish token's granular write access to `@windyroad/architect` specifically vs the other `@windyroad/*` packages; confirm package collaborator settings on npmjs.org
- [ ] Consider a release-pipeline guard: detect version-committed-but-publish-failed split (origin package.json version > npm latest) and surface it loudly rather than leaving a silent inconsistency
- [ ] Consider whether work-problems Step 6.5 Failure handling should special-case "publish E404 on a single package while siblings succeed" (currently halts as ambiguous npm publish rejection — correct per P140, but a documented one-retry-then-halt policy may fit the closed allow-list discussion)
- [ ] Create reproduction test if a deterministic cause is found

## Dependencies

- **Blocks**: release of `@windyroad/architect@0.8.0` (ADR-064 Needs-Direction verdict feature); any work-problems AFK loop that reaches a releasable iteration
- **Blocked by**: (none — recovery is in-hand via re-run)
- **Composes with**: (none confirmed)

## Related

- **P143** — adjacent release-watch failure class (race: PR not yet created by changesets action; distinct from publish-rejection).
- **P140** — work-problems Step 6.5 Failure handling diagnose-then-classify; this failure classified as genuinely-unrecoverable npm-publish-rejection → halt (ambiguous E404 does not match the closed fixable-in-iter allow-list).
- **ADR-018** / **ADR-020** — release cadence + auto-release-on-changesets; the pipeline this defect halts.
- **ADR-021** — plugin manifest version sync; architect plugin.json correctly bumped to 0.8.0 by the version step, but npm publish lagged → manifest now ahead of npm.
- **ADR-064** — the architect Needs-Direction verdict feature whose 0.8.0 release this blocks.
- CI run: https://github.com/windyroad/agent-plugins/actions/runs/26334143231 (captured via /wr-itil:capture-problem; expand at next investigation)
