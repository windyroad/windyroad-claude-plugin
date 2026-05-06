# Problem 112: `/install-updates` Step 7 `uninstall && install` chain has an unrecoverable failure window — if install fails after uninstall succeeds, the plugin is silently lost

**Status**: Closed
**Reported**: 2026-04-24
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: M
**WSJF**: (9 × 1.0) / 2 = **4.5**
**Type**: technical

> Identified 2026-04-24 during post-release review of commit 5d532cd (P106 fix). The P106 fix changed Step 7 from `claude plugin install <key>@windyroad --scope project` to `claude plugin uninstall <key>@windyroad --scope project && claude plugin install <key>@windyroad --scope project` to work around the silent-no-op issue where `install` does nothing when the plugin is already present. The fix works in the happy path but introduces an atomicity gap: the uninstall and install are two independent commands, and the skill's own prose (`.claude/skills/install-updates/SKILL.md:133`) says *"Do not abort the batch on a single failure — report and continue."* If uninstall succeeds and install fails — marketplace unreachable, network hiccup, rate limit, signature check failure — the plugin is uninstalled, the install step fails, and the batch proceeds to the next plugin without retry or rollback. The user returns to find a plugin silently missing.

## Description

`.claude/skills/install-updates/SKILL.md` Step 7 (post-P106):

```bash
for plugin in $PLUGINS_TO_UPDATE; do
  (cd "$TARGET_DIR" && \
    claude plugin uninstall "wr-$plugin@windyroad" --scope project && \
    claude plugin install "wr-$plugin@windyroad" --scope project)
done
```

And prose: *"Capture per-install exit status. Do not abort the batch on a single failure — report and continue."*

The `&&` chain gives one safety property: if uninstall fails, install is skipped — the plugin stays installed. Good.

The opposite failure is not handled: if uninstall succeeds, install may still fail. In that case the plugin is gone, and the skill reports the failure but moves to the next plugin. The user has to spot the failure in the final table and manually recover.

The P106 fix landed because `claude plugin install <key>` is a silent no-op when the plugin is already installed. The fix chose uninstall-first to force a fresh marketplace download. That's a correct workaround for the no-op bug, but it changes the skill's error model from "install-or-no-op" (both safe for the user) to "install-or-removed" (one of which silently loses a plugin).

## Symptoms

- If `npm view` reports a new version but the marketplace download fails between uninstall and install, the plugin silently disappears.
- The skill's bats test (added 5d532cd) asserts ordering and scope but does not assert recovery behaviour on partial-failure.
- Across a multi-sibling run (typical: current project + 1–3 sibling projects × N plugins), one transient network failure can lose a plugin from one sibling without blocking the others. The user discovers on next session start that a sibling project is missing a plugin it had that morning.
- The failure mode compounds the P045 gap (no auto-install after release) — the install-updates skill is currently the only mechanism distributing updates to sibling projects, so a silent removal there doesn't get healed by any other path.

## Workaround

Today:

- Notice the failure in Step 7's final report table.
- Re-run `/install-updates` for the affected sibling.
- Or manually `claude plugin install <key>@windyroad --scope project` from within the sibling directory.

Neither option is invoked automatically; both depend on the user reading the report carefully.

## Impact Assessment

- **Who is affected**: Any user running `/install-updates` across >1 project, especially post-release when the batch touches multiple plugin keys across siblings.
- **Frequency**: Directly proportional to `(siblings × plugins × per-install failure rate)`. Per-install failure rate is low but non-zero — marketplace HTTP, GitHub rate-limiting, transient DNS, and signature-check edge cases all contribute.
- **Severity**: Moderate. The plugin becomes non-functional in the affected project until detected and reinstalled. If the affected plugin is a gate-provider (architect, jtbd), the sibling project's governance silently stops firing on the next session start.
- **Stealth factor**: The failure is logged but not surfaced interactively. A user running install-updates in the last 30 seconds of a session (common end-of-session pattern per SKILL.md "When to invoke") may miss the failure row entirely.

## Root Cause Analysis

### Preliminary Hypothesis

The root cause is upstream: `claude plugin install` should update to the marketplace's latest version when the plugin is already installed, instead of silently no-opping. The P106 workaround (uninstall-first) is the correct local fix *given* the upstream behaviour, but it trades one silent failure (no update) for another (lost plugin on transient install failure).

Fix-shapes in order of architectural cleanliness:

1. **Upstream: report to Anthropic / Claude Code team.** `claude plugin install` when the plugin exists should either refresh to latest or return a non-zero exit with a clear "already at target; use --force to refresh" message. Until then the P106 workaround is load-bearing.

2. **Retry on install failure.** Wrap the `install` command in a bounded retry (e.g., 3× with exponential backoff). Addresses transient network failures. Does not help with hard failures (missing package, signature mismatch) but narrows the window significantly.

3. **Install-first with cache-bust.** If there's a way to force a fresh marketplace download without uninstalling first (e.g., `claude plugin marketplace update windyroad --force` followed by a `plugin install`), that keeps the plugin present throughout. Depends on whether the marketplace cache-bust is reliable enough to guarantee the subsequent install reads new bits.

4. **Rollback on install failure.** If uninstall-succeeded → install-failed, re-install the prior cached version as a rollback step. Requires knowing the prior installed version (already captured pre-Step 7 per the Before/After table) and having confidence it's still reachable in the cache.

5. **Interactive consent on any partial-failure.** If install fails after uninstall, halt the batch and `AskUserQuestion` — "plugin X was removed but couldn't be reinstalled; retry / rollback to cached / leave removed?" Only works for interactive invocations; doesn't help the AFK case.

Shape 2 (retry) is the smallest change and the most common source of failure. Shape 4 (rollback) is the completest. A combined 2+4 gives bounded retry on transient failure and rollback on hard failure.

### Investigation Tasks

- [ ] Confirm whether `claude plugin marketplace update windyroad` before install can bypass the need for uninstall — if yes, Shape 3 becomes viable and removes the whole failure window.
- [ ] Catalogue `claude plugin install` failure modes observed in the wild — transient network, rate-limit, signature, registry 404. Which are retryable, which are hard?
- [ ] Decide: retry + rollback (Shapes 2+4) vs interactive halt (Shape 5) vs cache-bust rewrite (Shape 3).
- [ ] Extend bats coverage: failing-install simulation (mock `claude` to fail the install step after a successful uninstall) + assert the plugin is either restored or the batch halts.
- [ ] Consider escalating the upstream report — P106 already documented the silent-no-op; this ticket documents the uninstall-dependent workaround's cost.

### Fix Strategy

**Shape**: Skill improvement — defer until failure is observed or ADR-030 amendment lands.

**Target file**: `.claude/skills/install-updates/SKILL.md` Step 7 + bats harness.

**Evidence**:
- SKILL.md line 128–130 (Step 7 command chain) + line 133 ("Do not abort the batch on a single failure — report and continue") — the two together create the window.
- bats test `packages/itil/skills/*/install-updates-uninstall-before-install.bats` (added 5d532cd) asserts Step 7 ordering and scope, not failure recovery.
- P106 (`docs/problems/106-install-updates-step-7-uses-install-not-update-updates-silently-no-op.closed.md`) — the upstream behaviour this workaround depends on.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: Upstream `claude plugin install` behaviour (not in repo scope); decision on fix-shape preference (retry vs rollback vs cache-bust rewrite).
- **Composes with**: P045 (auto plugin install after governance release — would reduce reliance on install-updates as the sole distribution mechanism), P106 (the no-op bug that drove the uninstall-first workaround).

## Related

- **P106** (`docs/problems/106-install-updates-step-7-uses-install-not-update-updates-silently-no-op.closed.md`) — upstream silent-no-op; this ticket is the cost-of-the-workaround follow-on.
- **P045** (`docs/problems/045-auto-plugin-install-after-governance-release.open.md`) — auto plugin install after release; reduces the blast radius of install-updates partial failure.
- **ADR-030** (`docs/decisions/030-repo-local-skills-for-workflow-tooling.proposed.md`) — install-updates is repo-local per this ADR; any Step 7 hardening lands here.
- **ADR-004** (`docs/decisions/004-marketplace-distribution.proposed.md`) — `--scope project` invariant; any fix-shape must preserve this.
- **JTBD-007** (`docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md`) — keep plugins current across projects; this ticket is a reliability concern for that job.
- **Upstream report pending** — external dependency identified; invoke `/wr-itil:report-upstream` when ready to file against the `claude-code` repo (the underlying `claude plugin install` silent-no-op + install-failure-mode taxonomy that motivated the uninstall-first workaround and the retry/rollback hardening).

## Fix Released

**Released**: 2026-04-25 (AFK work-problems iter — P112 worked)

**Shape**: Repo-local skill hardening (ADR-030). Shapes 2 + 4 from the Preliminary Hypothesis combined (bounded retry on transient failure + rollback-style recovery on exhaustion). Architect GO on shape; JTBD PASS on alignment with JTBD-006 + JTBD-007. No changeset required per ADR-030 (repo-local skills are versioned by repo git history, not published packages).

**Changes landed**:

- `.claude/skills/install-updates/SKILL.md` Step 7 — introduces `install_with_retry_rollback` bash function: uninstall once, retry install 3× with exponential backoff (1s, 2s, 4s), on exhaustion refresh the marketplace cache (`claude plugin marketplace update windyroad`) and attempt one rollback install. Prints one of `installed` / `restored` / `lost`. For-loop driver captures per-plugin status into `PROJECT_STATUS` for the Step 8 report. `--scope project` preserved throughout (ADR-004).
- `.claude/skills/install-updates/SKILL.md` Step 8 — final-report table gains two example rows demonstrating `✓ restored (rollback)` and `✗ lost (rollback failed)` statuses. New Status vocabulary paragraph defines all four tokens (`✓ installed`, `✓ restored (rollback)`, `✗ lost (rollback failed)`, `✗ failed`) so users can interpret retry/rollback outcomes from the report.
- `.claude/skills/install-updates/test/install-updates-step-7-retry-rollback.bats` — 7 behavioural contract assertions per ADR-037 / P081 (behavioural over structural). Extracts the `install_with_retry_rollback` function from SKILL.md, sources it under a PATH-shadowing `claude` mock, and verifies: first-try success (no retry, no rollback), retry-then-success (no rollback), all-retries-exhaust-then-rollback-succeeds (status `restored`), all-retries-and-rollback-fail (status `lost`, non-zero exit), uninstall-runs-exactly-once, final-report documents new Status vocabulary, `--scope project` invariant preserved.

**Gates**: architect GO (Shape 2+4; no new ADR; no changeset per ADR-030 point 5) + JTBD PASS (serves JTBD-007 reliability outcome + JTBD-006 AFK audit-trail constraint) + risk-scorer WIP 3/25 Low + full bats suite 837/837 green.

**Verification**: the next `/install-updates` invocation that encounters a transient install failure (marketplace rate-limit, network hiccup) should either succeed within the retry budget or report `restored` / `lost` in the final table rather than silently losing a plugin. Synthetic verification path: temporarily mock `claude plugin install` to fail, run `/install-updates`, observe the Step 8 Status column lands `restored` or `lost` instead of dropping the plugin silently.

**Upstream dependency**: P112's root cause is still the upstream `claude plugin install` silent-no-op (P106) that drove the uninstall-first workaround. The retry/rollback hardening narrows the blast radius but does not remove the underlying dependency. Invoke `/wr-itil:report-upstream` interactively to file the broader install-failure-mode taxonomy against `claude-code` when ready.

