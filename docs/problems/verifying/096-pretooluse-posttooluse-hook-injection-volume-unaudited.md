# Problem 096: PreToolUse / PostToolUse hook injection volume across windyroad plugins

**Status**: Verification Pending — Phase 1 audit done 2026-04-26; Phase 2 per-hook trims landed 2026-04-26 (iter 6 AFK loop); Phase 3 (ADR-045 codifying hook injection budget policy for PreToolUse/PostToolUse hooks) landed 2026-04-28 (AFK iter). Awaiting user verification.
**Reported**: 2026-04-22
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Possible (3) — re-rated 2026-04-26 from 12 High after audit confirmed silent-on-pass design across 33/36 hooks
**Effort**: M — re-rated 2026-04-26 from L after audit narrowed Phase 2 scope to 3 hook surfaces (`tdd-post-write.sh`, `plan-risk-guidance.sh`, `retrospective-reminder.sh`) plus optional shared-helper extraction
**WSJF**: excluded from ranking (Verification Pending multiplier 0 per ADR-022)

> Split from P091 meta (session-wide context budget) on 2026-04-22. This ticket owns the audit + remediation of the per-tool-call hook cluster. Phase 1 audit completed 2026-04-26. Phase 2 per-hook trims landed 2026-04-26. Phase 3 (ADR-045) landed 2026-04-28.

## Fix Released

ADR-045 (Hook injection budget policy for PreToolUse and PostToolUse hooks) committed in this AFK iteration's commit (post-Phase-2 codification of the five reusable patterns: silent-on-pass default, side-effect-only silent, silent-on-unchanged-state, hash-dedupe of repeated body content, once-per-session gating reuse). Awaiting user verification — verify by reading `docs/decisions/045-hook-injection-budget-for-pre-and-post-tool-use-hooks.proposed.md` and confirming the pattern catalogue + per-band byte budget table match the as-implemented Phase 2 hooks. Released to npm by the next `/wr-itil:work-problems` Step 6.5 release drain after this commit lands.

## Description

Windyroad plugins register a large inventory of `PreToolUse`, `PostToolUse`, and `Stop` hooks that fire on every matching tool call. The original ticket (2026-04-22) hypothesised that many of these emit prose into the conversation context unconditionally, mirroring the pattern P095 confirmed for `UserPromptSubmit`. The Phase 1 audit (2026-04-26) confirms this only for two outliers (`tdd-post-write.sh`, `plan-risk-guidance.sh`) and the one Stop reminder; the rest of the cluster is **silent on pass and only emits on deny**.

### Hook inventory (refreshed 2026-04-26 — supersedes the 2026-04-22 list)

The original ticket's inventory was incomplete. The current state (from `packages/*/hooks/hooks.json`) is:

**PreToolUse Edit|Write matcher (8 hooks):**
- `wr-architect/hooks/architect-enforce-edit.sh`
- `wr-jtbd/hooks/jtbd-enforce-edit.sh`
- `wr-tdd/hooks/tdd-enforce-edit.sh`
- `wr-style-guide/hooks/style-guide-enforce-edit.sh`
- `wr-voice-tone/hooks/voice-tone-enforce-edit.sh`
- `wr-risk-scorer/hooks/secret-leak-gate.sh`
- `wr-risk-scorer/hooks/wip-risk-gate.sh`
- `wr-risk-scorer/hooks/risk-policy-enforce-edit.sh`

**PreToolUse Bash matcher (6 hooks):**
- `wr-risk-scorer/hooks/git-push-gate.sh`
- `wr-risk-scorer/hooks/risk-score-commit-gate.sh`
- `wr-itil/hooks/p057-staging-trap-detect.sh` *(new since 2026-04-22)*
- `wr-itil/hooks/pre-publish-intake-gate.sh` *(new since 2026-04-22)*
- (also fires on Edit|Write) `wr-risk-scorer/hooks/external-comms-gate.sh` — matcher `Bash|Edit|Write`

**PreToolUse Write matcher (1 hook, new):**
- `wr-itil/hooks/manage-problem-enforce-create.sh` *(P119)*

**PreToolUse ExitPlanMode matcher (2 hooks):**
- `wr-architect/hooks/architect-plan-enforce.sh`
- `wr-risk-scorer/hooks/risk-score-plan-enforce.sh`

**PreToolUse EnterPlanMode matcher (1 hook):**
- `wr-risk-scorer/hooks/plan-risk-guidance.sh` — **always-on advisory**

**PostToolUse Agent matcher (5 mark-reviewed hooks):**
- `wr-architect/hooks/architect-mark-reviewed.sh`
- `wr-jtbd/hooks/jtbd-mark-reviewed.sh`
- `wr-style-guide/hooks/style-guide-mark-reviewed.sh`
- `wr-voice-tone/hooks/voice-tone-mark-reviewed.sh`
- `wr-risk-scorer/hooks/risk-score-mark.sh`

**PostToolUse Agent|Bash matcher (5 slide-marker hooks, new since 2026-04-22):**
- `wr-architect/hooks/architect-slide-marker.sh` *(P111)*
- `wr-jtbd/hooks/jtbd-slide-marker.sh`
- `wr-style-guide/hooks/style-guide-slide-marker.sh`
- `wr-voice-tone/hooks/voice-tone-slide-marker.sh`
- `wr-risk-scorer/hooks/risk-slide-marker.sh`

**PostToolUse Edit|Write matcher (3 hooks):**
- `wr-architect/hooks/architect-refresh-hash.sh`
- `wr-tdd/hooks/tdd-post-write.sh` — **always-on advisory**
- `wr-risk-scorer/hooks/wip-risk-mark.sh`

**PostToolUse Bash matcher (1 hook):**
- `wr-risk-scorer/hooks/risk-hash-refresh.sh`

**PostToolUse Skill matcher (1 hook):**
- `wr-tdd/hooks/tdd-setup-marker.sh`

**Stop matcher (3 hooks, +1 since 2026-04-22):**
- `wr-tdd/hooks/tdd-reset.sh`
- `wr-retrospective/hooks/retrospective-reminder.sh` — **always-on advisory**
- `wr-itil/hooks/itil-assistant-output-review.sh` *(P085)*

**Total**: 36 hooks across 9 plugins (was 26 in the 2026-04-22 inventory; +10 reflects P085 / P111 / P119 / P125 / P065 / P064 deliveries between 2026-04-22 and 2026-04-26).

## Symptoms

- **Confirmed (Phase 1 audit, 2026-04-26):** three hooks emit prose unconditionally on every firing of their matcher; the remaining 33 hooks are silent on pass and emit only on deny / verdict-FAIL paths.
- The two PreToolUse always-on emitters fire on niche events (PostToolUse:Edit|Write for `tdd-post-write.sh`, PreToolUse:EnterPlanMode for `plan-risk-guidance.sh`); the Stop hook fires once per session.
- Per-deny budgets are dominated by `permissionDecisionReason` prose (200-700 bytes per deny). The shared helpers (`review_gate_deny`, `risk_gate_deny`, `tdd_deny_json`, `create_gate_deny`) all produce JSON of comparable size — wrap is uniform.

## Workaround

None for end-users. Design-space mitigations (now informed by the audit findings):

1. **Trim the always-on emitters** — `tdd-post-write.sh` is the largest cumulative offender; `plan-risk-guidance.sh` is the largest per-call offender. See Fix Strategy Phase 2.
2. **Once-per-file gating for first-deny prose** is unnecessary — the existing session-marker pattern (architect / review-gate / risk-gate) already silences the deny after one successful agent review per session. Repeated edits on the same file emit 0 bytes once the marker is in place.
3. **PostToolUse `*-mark-reviewed.sh` hooks**: confirmed to emit nothing into the conversation (writes marker file only). No remediation needed.
4. **PostToolUse `*-slide-marker.sh` hooks** (5x): confirmed silent. The five hooks are line-by-line near-duplicates differing only in marker path — candidate for shared-helper consolidation (mechanical, not injection-volume driven).

## Impact Assessment

- **Who is affected**: Every user of the windyroad plugin set doing any tool-driven work (Edit, Write, Bash). Essentially every session.
- **Frequency**: Every matching tool call — much higher firing frequency than `UserPromptSubmit`.
- **Severity (now measured)**: Moderate cumulative, **not** the High the original ticket hypothesised. The audit confirms the design-space already follows the "silent on pass / verbose on deny" pattern P095 lacked. Concrete numbers:
  - Typical 30-turn session with ~60 tool calls firing this cluster: **~1-3 KB** baseline injection from `tdd-post-write.sh` (assuming ~5-10 impl/test edits at ~200-400 bytes each), **0 bytes** from `plan-risk-guidance.sh` (most sessions don't enter plan mode), **~200 bytes** from `retrospective-reminder.sh`, **0-3 KB** from one-off denies (first-edit-of-session per gate, secret-leak detections, push/changeset gates).
  - Worst case (multi-plan session + many test runs surfacing failure output): **5-15 KB** dominated by `tdd-post-write.sh` test output.
- **Severity comparison**: P095 (`UserPromptSubmit` cluster) emitted ~5-10 KB *per prompt* on standing prose alone. This per-tool-call cluster's baseline is **lower per session** than P095's per-prompt cost. The original Severity Moderate × Likely (12) overstates impact; revised estimate is closer to Moderate × Possible (9) given the silent-on-pass property. **Effort revisits**: Phase 2 scope is narrower than originally planned (3 hook surfaces, not 13).
- **Analytics**: Measurement harness from P091 meta is reused for before/after on a representative session.

## Root Cause Analysis

### Audit findings (Phase 1 — 2026-04-26)

Per-hook injection profile, measured from hook source code (`packages/*/hooks/*.sh`):

| # | Hook | Matcher | Pass bytes | Fail/Deny bytes | Always-on? |
|---|------|---------|-----------:|----------------:|:----------:|
| 1 | `architect/architect-enforce-edit.sh` | PreToolUse Edit\|Write | 0 | ~470 | No |
| 2 | `architect/architect-plan-enforce.sh` | PreToolUse ExitPlanMode | 0 | ~360 | No |
| 3 | `architect/architect-mark-reviewed.sh` | PostToolUse Agent | 0 | n/a | No |
| 4 | `architect/architect-refresh-hash.sh` | PostToolUse Edit\|Write | 0 | n/a | No |
| 5 | `architect/architect-slide-marker.sh` | PostToolUse Agent\|Bash | 0 | n/a | No |
| 6 | `jtbd/jtbd-enforce-edit.sh` | PreToolUse Edit\|Write | 0 | ~360 | No |
| 7 | `jtbd/jtbd-mark-reviewed.sh` | PostToolUse Agent | 0 | n/a | No |
| 8 | `jtbd/jtbd-slide-marker.sh` | PostToolUse Agent\|Bash | 0 | n/a | No |
| 9 | `tdd/tdd-enforce-edit.sh` | PreToolUse Edit\|Write | 0 | ~280 | No |
| 10 | **`tdd/tdd-post-write.sh`** | PostToolUse Edit\|Write | **150-1500** | n/a | **Yes** |
| 11 | `tdd/tdd-setup-marker.sh` | PostToolUse Skill | 0 | n/a | No |
| 12 | `tdd/tdd-reset.sh` | Stop | 0 | n/a | No |
| 13 | `style-guide/style-guide-enforce-edit.sh` | PreToolUse Edit\|Write | 0 | ~390 | No |
| 14 | `style-guide/style-guide-mark-reviewed.sh` | PostToolUse Agent | 0 | n/a | No |
| 15 | `style-guide/style-guide-slide-marker.sh` | PostToolUse Agent\|Bash | 0 | n/a | No |
| 16 | `voice-tone/voice-tone-enforce-edit.sh` | PreToolUse Edit\|Write | 0 | ~395 | No |
| 17 | `voice-tone/voice-tone-mark-reviewed.sh` | PostToolUse Agent | 0 | n/a | No |
| 18 | `voice-tone/voice-tone-slide-marker.sh` | PostToolUse Agent\|Bash | 0 | n/a | No |
| 19 | `risk-scorer/secret-leak-gate.sh` | PreToolUse Edit\|Write | 0 | ~250 | No |
| 20 | `risk-scorer/wip-risk-gate.sh` | PreToolUse Edit\|Write | 0 | ~210 | No |
| 21 | `risk-scorer/git-push-gate.sh` | PreToolUse Bash | 0 | ~300-700 | No |
| 22 | `risk-scorer/risk-score-commit-gate.sh` | PreToolUse Bash | 0 | ~420-700 | No |
| 23 | `risk-scorer/external-comms-gate.sh` | PreToolUse Bash\|Edit\|Write | 0 | ~440-900 | No |
| 24 | `risk-scorer/risk-policy-enforce-edit.sh` | PreToolUse Edit\|Write | 0 | ~480 | No |
| 25 | `risk-scorer/risk-score-plan-enforce.sh` | PreToolUse ExitPlanMode | 0 | ~280 | No |
| 26 | **`risk-scorer/plan-risk-guidance.sh`** | PreToolUse EnterPlanMode | **750-1500** | n/a | **Yes** |
| 27 | `risk-scorer/wip-risk-mark.sh` | PostToolUse Edit\|Write | 0 | n/a | No |
| 28 | `risk-scorer/risk-score-mark.sh` | PostToolUse Agent | 0 | n/a | No |
| 29 | `risk-scorer/risk-hash-refresh.sh` | PostToolUse Bash | 0 | n/a | No |
| 30 | `risk-scorer/risk-slide-marker.sh` | PostToolUse Agent\|Bash | 0 | n/a | No |
| 31 | `itil/manage-problem-enforce-create.sh` | PreToolUse Write | 0 | ~600 | No |
| 32 | `itil/p057-staging-trap-detect.sh` | PreToolUse Bash | 0 | ~440 | No |
| 33 | `itil/pre-publish-intake-gate.sh` | PreToolUse Bash | 0 | ~750 | No |
| 34 | `itil/itil-assistant-output-review.sh` | Stop | 0 | ~370 (on prose-ask match) | No |
| 35 | **`retrospective/retrospective-reminder.sh`** | Stop | **~200** | n/a | **Yes** |
| 36 | `connect/session-start.sh` | SessionStart | (out of scope — SessionStart, not Pre/Post) | — | — |

**Notes**:

- "Pass bytes" = stdout the assistant has to read on the typical happy path (gate passes / verdict OK). All 30+ hooks except #10, #26, #35 are 0 bytes on pass.
- "Fail/Deny bytes" = stdout on the deny path. Variable; depends on `permissionDecisionReason` length. Most denies fall in 200-500 byte range.
- "Always-on?" = does the hook emit bytes on every firing regardless of state? Three Yes outliers (#10, #26, #35) drive the cumulative budget; the remaining 33 hooks contribute zero except on the rare deny.
- The five `*-slide-marker.sh` hooks (#5, #8, #15, #18, #30) all do exactly one thing: call `slide_marker_on_subprocess_return` for one or two marker paths. Pure copy-paste with different marker names. Candidate for cross-plugin consolidation (mechanical, not byte-driven — they emit 0 bytes today).

### Top-3 offenders by per-call injection bytes

1. **`risk-scorer/plan-risk-guidance.sh`** (PreToolUse:EnterPlanMode) — emits 750-1500 bytes always-on `systemMessage` every time the user enters plan mode. Largest per-call.
2. **`tdd/tdd-post-write.sh`** (PostToolUse:Edit|Write) — emits 150-1500 bytes always-on `TDD STATE UPDATE` block on every Edit/Write of an impl or test file. Highest **cumulative** volume per session due to firing on every relevant file write.
3. **`retrospective/retrospective-reminder.sh`** (Stop) — emits ~200 bytes `stopReason` once per session. Low total but always-on.

The 33 remaining hooks contribute non-zero bytes only on deny / verdict-FAIL paths; in a session with no governance violations they emit 0 bytes total.

### Cross-plugin duplication

1. **`*-slide-marker.sh` (5 hooks)** — identical structure (source `gate-helpers.sh`, parse session id, call `slide_marker_on_subprocess_return` once or twice). Each is ~25 lines of nearly-identical boilerplate. **Candidate**: single shared hook in `packages/shared/hooks/` parameterised by marker-path list, or a parameterised registration in `hooks.json`. Risk: each plugin's hooks.json wires its own command; consolidation requires the host plugin to register a hook that knows about all plugin marker paths, or a per-plugin thin caller of a shared script with a marker-list argument.
2. **`*-mark-reviewed.sh` (5 hooks)** — three sub-shapes: text-grep verdict (architect), file-based verdict (jtbd / style-guide / voice-tone via `lib/review-gate.sh`'s already-shared helpers), structured-line verdict (risk-scorer for `risk-scorer:plan / :policy / :external-comms`). The jtbd / style-guide / voice-tone trio is already 80% shared via `review-gate.sh`. The architect / risk-scorer outliers have distinct verdict shapes that resist further sharing without a verdict-source plug-in.
3. **Edit|Write enforce-edit hooks (architect, jtbd, style-guide, voice-tone)** — all three of jtbd / style-guide / voice-tone already share `lib/review-gate.sh`. architect uses sibling `lib/architect-gate.sh`. The shared exclusion-list (changeset / MEMORY.md / .claude/plans / docs/jtbd / docs/PRODUCT_DISCOVERY.md / RISK-POLICY.md / .risk-reports / docs/BRIEFING.md) is **duplicated verbatim across 4-5 hooks** — candidate for `lib/exclusions.sh` extraction. Mechanical not injection-volume driven; reduces hook-source surface area but not stdout bytes.

### Investigation tasks

- [x] For each hook in the inventory, measure stdout byte count on a gate-pass case and a gate-fail case. Table the results above.
- [x] Identify hooks that emit instructional prose on gate-pass (candidates for "emit nothing on pass"). **Result: 3 hooks (#10, #26, #35).**
- [x] Identify hooks that emit verbose reasoning on skip (candidates for "silent skip"). **Result: 0 hooks — every gate exits silently on skip.**
- [x] Identify hooks that could benefit from once-per-file or once-per-session gating. **Result: not needed for the deny-path cluster; the existing per-session marker pattern in `lib/architect-gate.sh` / `lib/review-gate.sh` / `lib/risk-gate.sh` already handles this. P096 Phase 2 added once-per-session gating to `plan-risk-guidance.sh` (always-on advisory, EnterPlanMode).**
- [x] Apply the audit findings to each of the 3 always-on hooks. **(Phase 2 landed 2026-04-26.)**
- [x] Extend the reproduction-test bats suite to cover the remediated hooks. **(Phase 2 — `packages/tdd/hooks/test/tdd-post-write-phase2.bats` + `packages/risk-scorer/hooks/test/plan-risk-guidance-once-per-session.bats`.)**

## Fix Strategy

### Phase 1 (audit) — DONE 2026-04-26

Audit complete. Findings tabled above. Effort revised from L → M for Phase 2 (3 hook surfaces, not 13 as originally feared).

### Phase 2 (per-hook edits) — DONE 2026-04-26

Landed in iter 6 AFK loop (commit pending — same commit as this ticket transition).

Specific recommendations from the audit + as-implemented notes:

1. **`tdd/tdd-post-write.sh`** — the always-on `TDD STATE UPDATE` block is largest cumulative offender.
   - **Silent on GREEN unchanged** ✅ implemented: when `OLD_STATE == NEW_STATE == GREEN`, the hook exits 0 with zero stdout before the STATE UPDATE block is built. Verified by `tdd-post-write-phase2.bats` test 1-2.
   - **Suppress test output on RED for known-failing test** ✅ implemented: hash-keyed by `/tmp/tdd-stdout-hash-${SESSION_ID}-${ENCODED_TEST}`. On match, emits "Test output unchanged from previous emission (hash match)." in place of the last-50-lines block. Verified by `tdd-post-write-phase2.bats` test 3-4.
   - **Drop GREEN ACTION line** ✅ implemented: case branch removed; RED + BLOCKED ACTION lines retained. Verified by `tdd-post-write-phase2.bats` test 5-6.

2. **`risk-scorer/plan-risk-guidance.sh`** — emits 750-1500 bytes on every EnterPlanMode.
   - **Once-per-session gating** ✅ implemented via shared `lib/session-marker.sh` (P095 / ADR-038 pattern). System name: `risk-scorer-plan-guidance`. First EnterPlanMode emits the full advisory body; subsequent entries within the same session emit a ≤150-byte terse reminder (imperative signal word + gate name + risk numbers + cross-ref to RISK-POLICY.md). Verified by `plan-risk-guidance-once-per-session.bats` (7 tests, green).
   - **Trim systemMessage** ✅ implemented: the "release queue first / split / risk-reducing" listing was compressed to a single sentence with `See RISK-POLICY.md` cross-ref. First-emit body is now ~600 bytes (down from ~1000-1500); subsequent-emit reminder is ~270 bytes JSON (~150 bytes payload).
   - **Sync infrastructure** ✅ added: `risk-scorer` joined `scripts/sync-session-marker.sh` `CONSUMERS` array (sixth UserPromptSubmit consumer + first PreToolUse consumer of the helper). New byte-identical copy at `packages/risk-scorer/hooks/lib/session-marker.sh`. Bats drift coverage extended in `packages/shared/test/sync-session-marker.bats` (now lists 7 consumers).

3. **`retrospective/retrospective-reminder.sh`** — no change. Audit confirmed already minimal.

4. **Cross-plugin consolidation (mechanical, post-Phase 2)** — extract `lib/exclusions.sh` and consider `slide-marker.sh` consolidation. **Deferred to follow-up iter** — low priority vs the Phase 2 trims; reduces source surface area but not injection bytes.

### Estimated savings (post-Phase 2)

- `tdd-post-write.sh`: GREEN-unchanged path drops from ~150-300 bytes/edit to 0 bytes/edit. RED hash-match path drops from ~300-1500 bytes/edit to ~80 bytes/edit. Estimated session savings 1-3 KB on a typical 5-10-impl-edit session.
- `plan-risk-guidance.sh`: first-emit body ~600 bytes (down from ~1000-1500); subsequent-emit drops from ~1000 bytes to ~270 bytes. Per-session savings on a multi-plan session ~700 bytes per repeat plan-mode entry.
- Aggregate: -1 to -15 KB per typical session, dominated by `tdd-post-write.sh` cumulative reduction.

### Phase 3 (ADR) — DONE 2026-04-28

[ADR-045](../decisions/045-hook-injection-budget-for-pre-and-post-tool-use-hooks.proposed.md) — "Hook injection budget policy for PreToolUse and PostToolUse hooks" — landed as a sibling to ADR-038 in this AFK iteration's commit. Architect verdict (PASS, sibling-ADR confirmed) and JTBD verdict (PASS, JTBD-001/002/003/006/101 cited) preceded the draft.

The ADR codifies five reusable patterns from Phase 2 as repository-canon for future hook authors:

1. **Silent-on-pass default** — PreToolUse enforcement gates emit 0 bytes on pass (33/36 audited hooks already comply).
2. **Side-effect-only silent** — `*-mark-reviewed.sh`, `*-slide-marker.sh`, `*-refresh-hash.sh`, `*-mark.sh`, `tdd-reset.sh` write markers but emit 0 bytes.
3. **Silent-on-unchanged-state** — `tdd-post-write.sh` GREEN-unchanged path.
4. **Hash-dedupe of repeated body content** — `tdd-post-write.sh` RED test-output hash; ≤80 bytes hash-match acknowledgement.
5. **Once-per-session gating for always-on advisories** — `plan-risk-guidance.sh` reuses shared `lib/session-marker.sh` from ADR-038; ≤700 bytes first-emit, ≤150 bytes terse reminder.

Per-band byte budget table codifies Phase 2 measurements as policy. Bats coverage already in place from Phase 2 (`tdd-post-write-phase2.bats`, `plan-risk-guidance-once-per-session.bats`, `session-marker.bats`, `sync-session-marker.bats`).

Ticket transitions to Verification Pending per ADR-022 in this same commit.

## Related

- **P091 (Session-wide context budget — meta)** — parent meta ticket.
- **P095 (UserPromptSubmit hook injection)** — sibling cluster; Known Error; provides the shared session-marker helper this ticket's Phase 2 reuses.
- **P097 (SKILL.md runtime size)** — sibling cluster.
- **P029 (Edit gate overhead disproportionate for governance documentation changes)** — adjacent; scope-exclusion logic is partially shared with the enforce-edit hooks audited here.
- **ADR anchor**: "Hook injection budget policy" (tracked on P091).
