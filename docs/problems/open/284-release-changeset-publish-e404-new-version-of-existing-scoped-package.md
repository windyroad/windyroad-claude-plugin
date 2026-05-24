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

### Update 2026-05-24 — confirmed PERSISTENT, not transient (retry exhausted)

The retry path was exercised on user direction "release". Pushing the held docs commits re-triggered the `Version or Publish` workflow → **identical E404 on `architect@0.8.0`** (run `26343483749`, `2026-05-23T21:02:56Z` — byte-identical error to the first failure run `26334143231`). **Two independent CI runs, same failure → the E404 is persistent, NOT a transient registry/replication blip.** Transient cause is RULED OUT; root cause is access/registry-side and architect-specific.

**`main` is now in a self-perpetuating-failure state**: `architect@0.8.0` is committed on origin (package.json + plugin.json + CHANGELOG.md) but unpublishable, and `.changeset/` is empty, so the changesets action's "publish unpublished packages" path retries `architect@0.8.0` on EVERY push to main and fails. Quality-Gates CI passes; only the separate Release/publish workflow fails. This will recur on every push until resolved.

**Two un-stick paths (user decision — credential/registry-side, cannot be done by the agent):**
1. **Fix npm access + re-publish** (preferred — ships ADR-064): on npmjs.org, confirm the publish token (`NPM_TOKEN` secret) has **write/publish access to `@windyroad/architect` specifically** — a granular/automation token's package allowlist may omit architect, or architect's package-level collaborator settings may differ from the siblings. npm returns **E404 instead of E403** to avoid leaking package existence to an unauthorised principal, so an access gap presents exactly as this 404. After fixing access, re-run `npm run release:watch` (or `gh workflow run Release`) to publish `architect@0.8.0`.
2. **Revert the version bump** (abandons the 0.8.0 release for now): `git revert` the `chore: version packages` commit `6bda66e` portion that bumped architect (or manually reset architect's package.json/plugin.json/CHANGELOG to 0.7.4 and re-stage the changeset). Stops the per-push Release failure but leaves ADR-064's Needs-Direction verdict feature unreleased until access is fixed.

Other diagnostics: not a `publishConfig.access` defect (architect's package.json is structurally identical to siblings); package exists (architect 0.7.4 + 0.7.4-preview.* on npm).

### Update 2026-05-24 (2) — LEADING HYPOTHESIS CORRECTED: expired NPM_TOKEN (not architect-specific access)

User insight: "nothing about the token changed config-wise. Or… maybe it expired." This corrects a flawed inference in Update (1). **"All 11 siblings publish fine" was WRONG reasoning** — the siblings did NOT publish, they **SKIPPED** ("already published on npm" → only an unauthenticated `npm info` read, which needs no token). The **only actual write/PUT this run was `architect@0.8.0`**, so the token's *write* capability was exercised on exactly one package. Sibling skips do NOT prove the write token works → a token-wide auth failure (expiry/revocation) is fully consistent with the evidence, NOT ruled out.

**Timeline evidence (decisive):**
- Last successful publish across the *entire* `@windyroad` scope: **2026-05-18T20:39:52Z** (full batch — itil 0.35.7, retrospective 0.20.4, all preview.365). No npm write since.
- First failed write: **2026-05-23T13:37Z** (architect@0.8.0 — the first publish attempt since May 18).
- ⇒ The token stopped working in the **May 18 → 23 window**. `NPM_TOKEN` secret set 2026-04-08; a ~45-day token would lapse ~May 23. architect@0.8.0 was simply the first write to hit the expired token.
- Corroboration: this environment's **local npm token is also E401** ("authentication token seems to be invalid"). E404-on-PUT is how npm masks an expired/unauthorised-token write rejection (avoids leaking package existence).

**Revised fix (replaces Update-1 path 1):** regenerate the npm publish token on npmjs.org (automation/granular token with publish access to the `@windyroad` scope), update the **`NPM_TOKEN`** GitHub Actions secret (and likely **`NPM_AUTH_TOKEN`** — both set 2026-04-08; the Release workflow env references `NPM_TOKEN` / `NODE_AUTH_TOKEN`). Then re-run `npm run release:watch` (or `gh workflow run Release`) — architect@0.8.0 publishes and main un-sticks. Investigation task: set the new token with a longer expiry or no-expiry automation token, and consider a CI pre-publish `npm whoami` step that fails loudly on auth expiry rather than surfacing as a cryptic per-package E404.

The revert path (Update-1 path 2) remains valid as a fallback to un-stick main without fixing the token, but is unnecessary if the token is simply refreshed.

### Update 2026-05-24 (3) — ROOT CAUSE CONFIRMED: npm 2FA, token lacked "Bypass 2FA"

Replacing the secret with a freshly-generated token (still whoami=`tompahoward`, valid) changed the CI publish error from the masked **E404** to an explicit **`EOTP This operation requires a one-time password from your authenticator`** (run `26362679413`, 2026-05-24T13:33Z). That is the real root cause: the `tompahoward` npm account has **2FA enabled for writes/publishes**, and the publish token did not bypass it. CI cannot supply an interactive OTP, so `changeset publish` failed. The original E404 was the same underlying auth-insufficiency, masked by npm (404 instead of 403/EOTP) for the first token.

So BOTH earlier hypotheses were wrong: not architect-specific access (Update 1), not expiry (Update 2). The expiry timeline (last write May 18, first fail May 23) was a coincidence of "first write attempt in a while" — the token was simply never able to publish under 2FA. (Note: the May 18 publishes must have used a token that DID bypass 2FA; the Apr-08 secret evidently lost/never-had the bypass for the architect write path.)

**Resolution**: user regenerated the npm token with **"Bypass 2FA" enabled** (npm Automation-class / granular token that skips the OTP gate in CI) and updated the "Npmjs" 1Password `api token` field. The agent re-pulled it via `op`, reset both `NPM_TOKEN` + `NPM_AUTH_TOKEN` GitHub secrets (2026-05-24T13:38Z), and re-triggered the Release. **Closes when architect@0.8.0 publishes.**

**Standing follow-up (still valid regardless of this fix)**: add a CI pre-publish `npm whoami` / token-validity assertion so a future auth failure (expiry, missing-2FA-bypass, scope gap) fails loudly with a clear message instead of surfacing as a cryptic per-package E404. The E404→EOTP masking cost three diagnostic round-trips this session.

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
