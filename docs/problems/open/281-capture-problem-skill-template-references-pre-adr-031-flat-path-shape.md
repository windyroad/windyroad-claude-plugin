# Problem 281: capture-problem skill template references pre-ADR-031 flat-path shape

**Status**: Open
**Reported**: 2026-05-19
**Priority**: 9 (Med High) — Impact: 3 (Moderate — adopter projects accumulate flat-layout tickets; README cache mis-classify risk; cross-adopter inventory drift) x Likelihood: 3 (Likely — structural defect; every adopter following SKILL.md literally hits it; observed once concretely in voder-mcp-hub today)
**Effort**: M — three plausible resolution shapes enumerated (adopter migration / SKILL template literal refresh / agent inference-vs-template precedence rule); template-refresh alone might be S but combined fix sits at M
**WSJF**: 3.0 — (9 × 1.0) / 3 — Mid-priority Med-High severity; sibling cluster around capture-skill template drift
**Type**: technical

## Description

The published `/wr-itil:capture-problem` skill still places ticket files at the pre-ADR-031 / pre-RFC-002 **flat-layout-with-status-suffix** path shape (`docs/problems/<NNN>-<slug>.open.md`) instead of the current **per-state-subdir** shape (`docs/problems/<state>/<NNN>-<slug>.md`) — at least sometimes, and at least in some downstream adopter projects.

Concrete evidence from a separate AFK orchestrator session captured 2026-05-19:

- Project: `voder-mcp-hub` (an adopter using `@windyroad/itil` 0.35.6, the same release this `wr-itil` SKILL ships from).
- Capture event: P032 (`docs/problems/032-xero-list-contacts-fuzzy-search-misses-active-contacts.open.md`) landed at the **flat path** at the repo root in commit `6c73880`.
- Expected per ADR-031 / RFC-002: `docs/problems/open/032-xero-list-contacts-fuzzy-search-misses-active-contacts.md` (per-state subdir, `.md` suffix only, no `.open.` infix).
- Adjacent siblings P013, P017, P022 etc are all per-state-subdir — proving the project IS migrated and is otherwise consistent.
- Active session-level diagnosis attributed it to `/wr-itil:capture-problem` writing to the SKILL.md `**File path**:` template (flat-shape) literally, OR to a stale pre-migration cached invocation.

In this repo (`windyroad-claude-plugin`), recent captures P279 + P280 (today) DID land at the correct per-state path (`docs/problems/open/<NNN>-<slug>.md`). So the divergence is either:

1. **Adopter-side migration gap**: the `voder-mcp-hub` migration script (e.g. `migrate-problems-layout.sh`, named in the active session log) may not have been run, OR it ran but the SKILL template kept writing to the old shape and `wr-itil-reconcile-readme`'s INLINE_REFRESH carve-out swallowed the cross-turn drift instead of routing to a full migration.
2. **SKILL template literal-text drift**: `packages/itil/skills/capture-problem/SKILL.md` Step 4 still reads `**File path**: docs/problems/<NNN>-<kebab-title>.open.md` (the flat shape). Agents that follow the template literally (instead of inferring from observed on-disk layout) WILL place files at the flat path in projects where on-disk inference doesn't override the template.
3. **Agent inference-vs-template precedence is undocumented**: this repo's agents observed `docs/problems/open/`, `docs/problems/known-error/`, etc. and used those; the adopter-side agent presumably did the same observation but landed at the flat path anyway — suggesting either (a) the observation was skipped, (b) the SKILL template overrode the observation, or (c) a stale cached skill version was in play.

The user's framing — "capture problem is still using old locations sometimes" — matches (1) OR (2) OR (3); each is plausible and all three deserve diagnostic work.

## Symptoms

(deferred to investigation)

- New problem tickets land at `docs/problems/<NNN>-<slug>.open.md` (flat) in adopter projects whose on-disk inventory otherwise uses `docs/problems/<state>/<NNN>-<slug>.md` (per-state).
- README.md WSJF rankings + Verification Queue + Closed sections may silently mis-classify these flat-layout tickets (depends on whether `wr-itil-reconcile-readme` is dual-tolerant for ALL section types, not just the `next_id` enumeration carved out as dual-tolerant in the Step 3 helper).
- Downstream tooling that hard-codes `docs/problems/<state>/` (per-state) may not see the flat tickets at all.
- INLINE_REFRESH classifier may swallow this drift if it treats flat-layout tickets as same-iter staged (rather than cross-turn drift requiring a HALT_ROUTE_RECONCILE).

## Workaround

(deferred to investigation)

Plausible workarounds pending diagnosis:

- Adopter-side: `git mv docs/problems/<NNN>-<slug>.open.md docs/problems/open/<NNN>-<slug>.md` after every flat-shape capture, then `/wr-itil:reconcile-readme` to refresh the README.
- Maintainer-side: refresh the SKILL.md `**File path**:` template to name the per-state shape AND document agent inference-vs-template precedence.
- Tooling-side: extend `migrate-problems-layout.sh` to be idempotent + safe to re-run, and have `wr-itil-reconcile-readme` Step 0 call it (NOT just diagnose).

## Impact Assessment

- **Who is affected**: (deferred to investigation) — at minimum `voder-mcp-hub` today; possibly other adopters on the same `@windyroad/itil` release window.
- **Frequency**: (deferred to investigation) — at least once observed today (P032 in voder-mcp-hub); recurrence rate unknown.
- **Severity**: (deferred to investigation) — Medium pending diagnosis: ticket-inventory drift is recoverable via `git mv` + reconcile, but silently mis-classified tickets in README sections can mask real WSJF priority signals and so degrade backlog quality over time.
- **Analytics**: (deferred to investigation) — would need to scan all `@windyroad/itil` adopter repos for flat-layout tickets created after RFC-002 acceptance; out of scope for capture.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Confirm whether `packages/itil/skills/capture-problem/SKILL.md` Step 4 `**File path**:` template still reads `docs/problems/<NNN>-<kebab-title>.open.md` (pre-ADR-031 shape)
- [ ] If yes — refresh the template to `docs/problems/<state>/<NNN>-<slug>.md` per ADR-031 / RFC-002; cross-check the same drift in `/wr-itil:capture-rfc`, `/wr-itil:capture-story`, `/wr-itil:capture-story-map`, `/wr-itil:capture-jtbd` (if shipped), `/wr-itil:manage-problem` Step 4, `/wr-itil:manage-rfc`, `/wr-itil:manage-story`, `/wr-itil:manage-story-map`
- [ ] Document the agent inference-vs-template precedence rule somewhere durable (likely ADR-031 amendment OR a SKILL-level contract clause): "when on-disk inventory uses a different layout than the SKILL.md template names, the agent SHOULD follow on-disk inventory and report the template drift as a problem"
- [ ] Investigate the voder-mcp-hub `migrate-problems-layout.sh` to verify it's idempotent + safe to re-run; consider having `wr-itil-reconcile-readme` invoke it (not just diagnose drift)
- [ ] Investigate whether `wr-itil-reconcile-readme`'s INLINE_REFRESH classifier (P149) silently swallows flat-layout cross-turn drift instead of routing to HALT_ROUTE_RECONCILE — re-classify as a separate problem if so
- [ ] Create reproduction test (likely a bats fixture that simulates an adopter repo with mixed flat + per-state ticket layout and asserts capture-problem lands new tickets at per-state)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — investigation can begin immediately)
- **Composes with**:
  - **ADR-031** (per-state-subdir ticket layout decision)
  - **RFC-002** (dual-tolerant migration window — `next_id` enumeration helper already dual-tolerant per architect finding 2)
  - **P262** (P165 README refresh hook conflicts with capture-problem deferred-refresh contract — adjacent surface)
  - **P199** (capture-problem → manage-problem same-session halt at Step 0 reconcile — adjacent surface)
  - **P149** (INLINE_REFRESH carve-out classifier — may be silently swallowing this drift)
  - **P155** (ship capture-problem skill — closed; this is post-ship drift)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- Image-evidence: voder-mcp-hub session terminal dated 2026-05-19, showing P032 at flat path + active diagnosis attributing it to `/wr-itil:capture-problem` template literal OR migration gap.
- Commit reference (adopter-side): `6c73880` in `voder-mcp-hub`.
- This SKILL surface (`packages/itil/skills/capture-problem/SKILL.md`) Step 4 template literal — likely the load-bearing drift site for option (2) above.
- Sibling capture skills (capture-rfc, capture-story, capture-story-map) — cross-check the same template-shape drift; if uniform across sibling skills, the fix is a multi-skill SKILL.md refresh (probably one changeset, multiple files).
