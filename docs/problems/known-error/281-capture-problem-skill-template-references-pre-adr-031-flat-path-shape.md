# Problem 281: capture-problem skill template references pre-ADR-031 flat-path shape

**Status**: Known Error
**Reported**: 2026-05-19
**Priority**: 9 (Med High) — Impact: 3 (Moderate — adopter projects accumulate flat-layout tickets; README cache mis-classify risk; cross-adopter inventory drift) x Likelihood: 3 (Likely — structural defect; every adopter following SKILL.md literally hits it; observed once concretely in voder-mcp-hub today)
**Effort**: M — three plausible resolution shapes enumerated (adopter migration / SKILL template literal refresh / agent inference-vs-template precedence rule); template-refresh alone might be S but combined fix sits at M
**WSJF**: 4.5 — (9 × 1.0) / 2 — corrected 2026-05-23: invalid /3 divisor → M divisor 2 (was 3.0)
**Type**: technical
**Fix Shipped**: 2026-05-30 (capture-problem SKILL.md template-refresh sub-shape only; sibling-SKILL drift + adopter migration + inference-vs-template precedence rule deferred to descendants)

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

**Root cause confirmed 2026-05-30** (work-problems iter 7): `packages/itil/skills/capture-problem/SKILL.md` Step 4-5-6 all named the pre-ADR-031 flat shape `docs/problems/<NNN>-<kebab-title>.open.md` (lines 188, 246, 253). Adopter-side agents (voder-mcp-hub) followed the SKILL.md template literally and landed P032 at the flat path despite ADR-031 having been ratified. This repo's recent captures (P279, P280) landed at the correct per-state path because the agent here happened to infer from on-disk inventory — but that inference is undocumented and unenforced, hence the cross-adopter divergence.

**Fix shipped this iter** (template-refresh sub-shape — S-scope per orchestrator's work-problems selection):
- `packages/itil/skills/capture-problem/SKILL.md` lines 188, 246, 253 + the Step 2 prose at line 156 + stale Related-section ticket paths now name `docs/problems/open/<NNN>-<kebab-title>.md` per ADR-031.
- 4 new behavioural bats tests at `packages/itil/skills/capture-problem/test/capture-problem.bats` (P281 regression guards, structural-grep on the SKILL.md contract surface per ADR-052 § Surface 2 escape-hatch).
- The skeleton-fill fixture test was updated to write at the per-state path (was using the now-wrong flat shape).

**Architect verdict**: textual conformance to ratified ADR-031 (accepted + human-oversight: confirmed); no new ADR required for the template refresh itself. The "agent inference vs literal SKILL template precedence" question deserves a NEW ADR — descendant ticket.

**JTBD-lead verdict**: serves JTBD-302 (Trust That the README Describes the Plugin I Just Installed) — the SKILL.md template literal is an adopter-facing contract surface under the same trust-asymmetry constraint READMEs carry. JTBD-302 already covers the expectation; no new JTBD authored.

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems
- [x] Confirm whether `packages/itil/skills/capture-problem/SKILL.md` Step 4 `**File path**:` template still reads `docs/problems/<NNN>-<kebab-title>.open.md` (pre-ADR-031 shape) — **CONFIRMED 2026-05-30**: lines 188, 246, 253 all carried the flat shape.
- [x] Refresh the template to `docs/problems/open/<NNN>-<kebab-title>.md` per ADR-031 / RFC-002 in capture-problem SKILL.md — **DONE 2026-05-30**.
- [ ] Cross-check the same drift in `/wr-itil:capture-rfc`, `/wr-itil:capture-story`, `/wr-itil:capture-story-map`, `/wr-itil:capture-jtbd` (if shipped), `/wr-itil:manage-problem` Step 4, `/wr-itil:manage-rfc`, `/wr-itil:manage-story`, `/wr-itil:manage-story-map` — **DEFERRED to descendant**: sibling-SKILL drift confirmed at `manage-problem/SKILL.md:446`, `review-problems/SKILL.md:48`, `transition-problems/SKILL.md:138`, `transition-problem/SKILL.md:143`, `reconcile-readme/SKILL.md:72-73`, `capture-rfc/SKILL.md:164,249` (`.proposed.md` flat for RFCs). Descendant ticket captured this iter.
- [ ] Document the agent inference-vs-template precedence rule somewhere durable (likely NEW ADR per architect verdict, NOT ADR-031 amendment): "when on-disk inventory uses a different layout than the SKILL.md template names, the agent SHOULD follow on-disk inventory and report the template drift as a problem" — **DEFERRED to descendant**.
- [ ] Investigate the voder-mcp-hub `migrate-problems-layout.sh` to verify it's idempotent + safe to re-run; consider having `wr-itil-reconcile-readme` invoke it (not just diagnose drift) — **DEFERRED to descendant**.
- [ ] Investigate whether `wr-itil-reconcile-readme`'s INLINE_REFRESH classifier (P149) silently swallows flat-layout cross-turn drift instead of routing to HALT_ROUTE_RECONCILE — re-classify as a separate problem if so — **DEFERRED**.
- [x] Create reproduction test (likely a bats fixture that simulates an adopter repo with mixed flat + per-state ticket layout and asserts capture-problem lands new tickets at per-state) — **DONE 2026-05-30** as 4 new tests in `packages/itil/skills/capture-problem/test/capture-problem.bats`.

### Verification

This ticket transitions Open → Known Error this iter (root cause confirmed + capture-problem-specific fix shipped). Promotion to Verifying happens when the changeset releases; closure happens when an adopter capture lands at per-state subdir post-release.

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
