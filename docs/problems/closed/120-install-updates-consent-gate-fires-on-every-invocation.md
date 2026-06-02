# Problem 120: `/install-updates` consent gate fires on every invocation despite the answer being invariably "all confirmed siblings"

**Status**: Closed
**Reported**: 2026-04-25
**Fix Released**: 2026-04-25 (AFK iter; repo-local skill per ADR-030 — no changeset)
**Priority**: 10 (High) — Impact: Minor (2) x Likelihood: Almost Certain (5)
**Effort**: S
**WSJF**: 0 (Verification Pending — multiplier 0 per ADR-022)

## Fix Released

Shape A landed (architect APPROVED-WITH-AMENDMENTS verdict converged + JTBD PASS + style-guide PASS + voice-tone PASS):

- `.claude/skills/install-updates/SKILL.md` Step 6 split into 6a (cache check), 6b/6c (gate fire on cache miss), 6d (cache write at end of successful run). Cache-hit path skips the gate entirely per ADR-013 Rule 5 (policy-authorised silent proceed); cache-miss-with-stale-cache fires the gate with previous answer surfaced as `(Recommended)`. Two escape hatches preserve dry-run access: `INSTALL_UPDATES_RECONFIRM=1` envvar or `rm .claude/.install-updates-consent`. ADR-034 cited as parallel-pattern precedent (`.claude/.auto-install-consent`).
- `.claude/skills/install-updates/REFERENCE.md` — new "Consent cache (P120)" section documenting cache file shape (JSON `{"scope":[...],"cached_at":"<ISO>"}`), set-equality match rule, invalidation rules (sibling-set change invalidates; plugin-list change does not; no time expiry), Rule 5 governance, ADR-034 parallel pattern, escape hatches, Step 6.5 still runs on cache-hit.
- `.gitignore` — adds `.claude/.install-updates-consent` AND `.claude/.auto-install-consent` (sibling for ADR-034 when its hook lands).
- `.claude/skills/install-updates/test/install-updates-consent-cache.bats` — NEW; 15 doc-lint contract assertions per ADR-037 Permitted Exception (cache file path, gate-on-cache language, sibling-set-change invalidation, cache-write language, ADR-034 citation, Rule 5 citation, escape hatches, set-equality rule, Step 6.5 runs on cache-hit). 15/15 green.
- `docs/decisions/030-repo-local-skills-for-workflow-tooling.proposed.md` — Confirmation criterion amendment "Consent cache carve-out (P120, 2026-04-25 amendment)" specifying set-equality match, dry-run override path, Step 6.5 still runs on cache-hit.
- `docs/decisions/034-auto-install-on-next-session-start.proposed.md` — sibling-marker coexistence note added under Consequences › Bad clarifying that the two consent markers (`.claude/.auto-install-consent` for ADR-034, `.claude/.install-updates-consent` for P120) are independent.

Architect verdict required corrections applied: Rule 5 (not Rule 6) citation throughout SKILL.md / REFERENCE.md / ticket Related section; dry-run override via `INSTALL_UPDATES_RECONFIRM=1` envvar OR cache-file deletion; Step 6.5 still runs on cache-hit; set-equality match rule explicit; sibling-marker coexistence note in ADR-034.

Verification path: next interactive `/install-updates` invocation in this workspace where the sibling set has been answered before. **Expected**: gate skipped; install proceeds with the cached scope; cache file written at end. Sibling-set change between invocations should re-prompt with previous answer surfaced.

Repo-local skill per ADR-030 — effective on next `/install-updates` invocation; no changeset, no plugin republish required.

> Surfaced 2026-04-25 by direct user correction at the end of an AFK `/wr-itil:work-problems` loop that triggered `/install-updates`: *"the install-updates skill wastes time asking me to confirm. Yes it should install in all 6 projects. Don't ask me again"*. The strong-signal correction (P078 trigger) is durable behaviour evidence — every prior `/install-updates` invocation in this workspace has answered the consent gate with `All N projects (Recommended)`. The gate has zero decision content; it is a productivity tax on every release.

## Description

`.claude/skills/install-updates/SKILL.md` Step 6 (consent gate per ADR-030 Confirmation) requires `AskUserQuestion` on every invocation listing the user's sibling-project install plan. P061 fixed the 4-option cap shape (Verifying); the gate's *contract* is that it MUST fire on every invocation regardless of prior answer.

Empirical observation: the answer is **always** `All N projects (Recommended)` for this workspace's solo-developer + 5-sibling layout. The user has never selected `Current project only` or `Dry-run`. The gate has no decision content — it is friction.

The gate is structurally appropriate when the install plan crosses an unfamiliar trust boundary (e.g. a contractor receiving the workspace; a one-shot install from a checked-out CI runner). For the steady-state solo-developer-with-stable-sibling-set case, the gate's risk-of-wrong-answer is zero and the cost-per-invocation is one round-trip + user attention drain. The cost-benefit is upside-down.

## Symptoms

- Every `/install-updates` invocation fires `AskUserQuestion` with the same 4 options (per P061's > 3 fallback) or the original-contract one-option-per-sibling shape (≤ 3 case).
- User picks `All N projects (Recommended)` every time.
- Multi-iter AFK loops that release multiple times (e.g. this 2026-04-25 session shipped 4 releases) only invoke `/install-updates` once at the end, but the friction-per-invocation cost is real even for that single hit.
- The same workspace's sibling list (5 projects: addressr-mcp, addressr-react, addressr, bbstats, windyroad) is stable across sessions; no change in answer expected.
- User correction shape: "wastes time" + "Don't ask me again" — both are P078 strong-signal correction tokens. The frustration is durable.

## Workaround

User picks `All N projects (Recommended)` every invocation. Costs one keystroke + UI round-trip. No bypass available without modifying the skill.

## Impact Assessment

- **Who is affected**: Every `/install-updates` invocation in any workspace where the user's answer is stable across invocations. For this workspace specifically: every invocation, observed for at least the past week.
- **Frequency**: Every release-loop end-of-session (≥ once per session that ships releases). For multi-release sessions (this 2026-04-25 session shipped 4) the cost is a constant — gate fires once per skill invocation, not per release.
- **Severity**: Minor — productivity friction, no functional break, no risk of wrong install.
- **Likelihood**: Almost Certain — observed in every recent invocation; no controls in place.
- **Analytics**: Direct user correction this session (verbatim above) constitutes the strongest possible signal under P078's correction-detect contract.

## Root Cause Analysis

### Structural

ADR-030 Confirmation lists the consent gate as a required first action. The contract was written to handle the **first-touch** case (an unfamiliar workspace where the user must explicitly opt into sibling installs). It has no carve-out for the **steady-state** case (a workspace where the user's answer is stable and the friction has zero decision content).

P045's ADR-034 design (`.claude/.auto-install-consent` per-project marker for the SessionStart auto-install hook) anticipates exactly this pattern at a different surface — once consent is granted via a successful interactive `/install-updates` run, the SessionStart hook can act on the marker without re-prompting. The architecture for "remember consent" already exists in the suite's design vocabulary; this ticket extends the same pattern to the manual `/install-updates` invocation path.

### Candidate fix shapes

**Shape A — Persistent consent cache (recommended).** After a successful `/install-updates` run where the user picked `All N projects` (or a specific subset), write the chosen scope to `.claude/.install-updates-consent` (per-project, parallel to ADR-034's `.claude/.auto-install-consent` shape). Subsequent invocations:

1. Read `.claude/.install-updates-consent`. If present and the on-disk sibling set matches the cached scope, **skip Step 6 entirely** and proceed to Step 7 install with the cached scope.
2. If the sibling set has changed (a new sibling was added, or one was removed) since the cache was written, fire Step 6 with the new set surfaced and the previous answer pre-selected as `(Recommended)`.
3. The cache file is local-only (gitignored — same shape as existing `.claude/settings.local.json`). It is **not committed** — consent is per-machine.

**Shape B — Explicit `--yes` / `--all` flag.** Add a flag to the skill invocation surface that bypasses Step 6. User invokes `/install-updates --all` on the loop end-of-session and the consent gate is silenced. Lower-friction than Shape A on first invocation; Shape A is lower-friction on subsequent invocations.

**Shape C — Combination.** Shape A persistence + Shape B flag. The flag is the manual override (e.g. for the very first run); the persistence handles the steady state.

**Architect lean** (provisional): Shape A. Matches P045 ADR-034's existing pattern for the auto-install surface. Matches the principle behind P085 (act on obvious — the answer IS obvious once it has been answered). User correction is unambiguous on the *behaviour* desired; mechanism is a documented architectural pattern.

### ADR amendments

ADR-030 Confirmation needs amendment:

- Confirmation criterion currently reads "consent gate as first action". Amend to: "consent gate as first action UNLESS a per-project consent cache (`.claude/.install-updates-consent`) exists AND its cached scope matches the current sibling set. When the cache hits, skip the gate; when the cache misses or mismatches, fire the gate as today."

No new ADR required if Shape A is chosen — this is an ADR-030 Confirmation amendment, parallel to how ADR-022's amendments handle Verification Pending lifecycle adjustments.

### Investigation Tasks

- [ ] Confirm the cache file shape (`.claude/.install-updates-consent`) — JSON with `scope` (list of confirmed sibling project names) and `cached_at` (ISO timestamp)? Or simpler: a single-line file with just the scope value? Lean: JSON for forward-compat with future scope variants.
- [ ] Decide cache invalidation rules:
  - Sibling-set change (new project added, or existing project deleted) — invalidate, re-prompt.
  - Plugin-list change (a sibling enables a new plugin) — DO NOT invalidate; cache is about *which projects to install in*, not *which plugins to install*.
  - Time-based expiry — NO. Consent doesn't have a half-life on a stable workspace.
- [ ] Decide flag interaction (if Shape C): does `--all` write the cache, or just bypass for that invocation? Lean: `--all` writes the cache (treat the explicit flag as an even stronger consent signal than the AskUserQuestion answer).
- [ ] Update SKILL.md Step 6 to gate on the cache file's presence + match.
- [ ] Add bats doc-lint assertions: cache-file shape, Step 6 gate language for the cache-hit path, Step 6 gate language for the cache-miss-with-stale-cache path (sibling-set change), Step 6 gate language for the cache-miss-no-cache path (first run).
- [ ] Add `.claude/.install-updates-consent` to `.gitignore` if not already covered by `.claude/settings.local.json`-style ignores.
- [ ] Verify no interaction with P045's planned `.claude/.auto-install-consent` — these are two separate marker files for two separate consent surfaces (manual `/install-updates` vs. SessionStart auto-install). They should not collide; if they end up sharing structure, refactor at P045 implementation time.

### Fix Strategy

**Shape**: SKILL.md amendment + cache-file convention.

**Target files**:
- `.claude/skills/install-updates/SKILL.md` — Step 6 gate-on-cache check; Step 6 cache-write at the end of a successful invocation; Step 6 cache-mismatch re-prompt path.
- `.gitignore` — add `.claude/.install-updates-consent` if not covered.
- `.claude/skills/install-updates/test/install-updates-consent-cache.bats` — NEW. 4-6 doc-lint assertions per ADR-037 (Permitted Exception): cache file path, gate-on-cache language in Step 6, sibling-set-change invalidation language, cache-write language.
- `docs/decisions/030-repo-local-skills.proposed.md` — Confirmation criterion amendment (consent cache exemption).

**Out of scope**: SessionStart auto-install (P045 / ADR-034 — separate ticket). Sibling discovery rules (Step 3 — unchanged). Rename-mapping handling (Step 6.5 — unchanged).

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P045 (auto plugin install on session start) — both surfaces want consent persistence; if Shape A lands first, P045's ADR-034 SessionStart hook can read the same cache file (or a sibling) when its own consent path runs. P061 (consent-gate sibling-cap fallback — Verifying) — same Step 6 surface, different concern.

## Related

- **P061** (`docs/problems/061-install-updates-step-6-consent-gate-sibling-cap.verifying.md`) — same Step 6 surface; P061 fixed the option-count shape, this ticket fixes the gate-firing-frequency shape. Composable: this fix can land on top of P061's grouping fallback without conflict.
- **P045** (`docs/problems/045-auto-plugin-install-after-governance-release.open.md`) — sibling concern at the SessionStart-hook surface. ADR-034 already specifies `.claude/.auto-install-consent`; this ticket extends the same pattern to the manual `/install-updates` surface.
- **P085** (`docs/problems/085-assistant-asks-when-obvious-and-uses-prose-instead-of-askuserquestion.verifying.md`) — same anti-pattern at a different layer. P085 is the assistant-side "act on obvious" rule; P120 is the skill-side equivalent for `/install-updates`. The architectural lesson (act on obvious / cache stable answers) is consistent.
- **P078** (`docs/problems/078-assistant-does-not-offer-problem-ticket-on-user-correction.verifying.md`) — the trigger that surfaced this ticket. The user's correction language ("wastes time", "Don't ask me again") matched the strong-signal vocabulary; this ticket is the captured-on-correction outcome.
- **ADR-030** (`docs/decisions/030-repo-local-skills.proposed.md`) — Confirmation criterion that defines the consent gate. This ticket's fix amends Confirmation to describe the cache-hit exemption.
- **ADR-034** (auto-install on next session start) — already specifies `.claude/.auto-install-consent` for the SessionStart surface. Architectural precedent for this ticket's `.claude/.install-updates-consent`.
- **ADR-013 Rule 5** — policy-authorised silent proceed. Architect verdict 2026-04-25 (this iteration): cache-hit is a Rule 5 case, NOT Rule 6. Rule 5 explicitly authorises silent proceed when a stable user authorisation is on file; the cached on-disk consent IS the policy authorisation. Rule 6 governs cases where AskUserQuestion is unavailable, which is unrelated.
- `.claude/skills/install-updates/SKILL.md` Step 6 — the gate this ticket modifies.
- `.claude/skills/install-updates/REFERENCE.md` — rationale doc; may need a sibling section on the cache contract.
- **JTBD-001** (Enforce Governance Without Slowing Down) — primary fit. "Without slowing down" fails when every release-loop ends with a redundant consent prompt.
- **JTBD-006** (Progress the Backlog While I'm Away) — composes: AFK loops that drain releases land on the user's terminal with the same redundant consent gate at the wake-up tick.
- 2026-04-25 session evidence: this ticket was filed in response to the verbatim user correction at the end of the 2026-04-25 AFK `/wr-itil:work-problems` loop, after `/install-updates` shipped 36/36 installs across 6 projects (1 current + 5 siblings). Every prior `/install-updates` invocation in this workspace's git history has produced the same answer.
