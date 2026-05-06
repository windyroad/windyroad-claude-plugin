# Problem 147: P121 SIGTERM-clean-flush guarantee is conditional on subprocess having emitted ITERATION_SUMMARY before going idle — needs SKILL.md caveat + behavioural-test second-source for stuck-before-emit subclass

**Status**: Closed
**Reported**: 2026-04-29
**Priority**: 4 (Med) — Impact: Minor (2) x Likelihood: Possible (2) — false confidence in the SKILL.md SIGTERM-recovery prose causes orchestrators to expect clean JSON flush that may not arrive, then accept exit-143 without halt-and-investigate.
**Effort**: S — SKILL.md amendment to `packages/itil/skills/work-problems/SKILL.md` line 27 area (the P121 evidence prose block) + amend the briefing entry already added today (`docs/briefing/afk-subprocess.md` "P121 SIGTERM-clean-flush guarantee is conditional, not universal" entry) into a behavioural-test fixture.
**WSJF**: (4 × 1.0) / 1 = **4.0**
**Type**: technical

## Fix Released

**Release marker**: 2026-05-03 (AFK iter 7; pending `@windyroad/itil` patch via the queued changeset `.changeset/p147-sigterm-conditional-caveat.md`).

**One-sentence fix summary**: `packages/itil/skills/work-problems/SKILL.md` Step 5 gains a new **"SIGTERM exit-flush is conditional, not universal (P147)"** subsection that conditions the P121 clean-flush claim on prior `ITERATION_SUMMARY` emission, names the stuck-before-emit subclass observed at P146 (exit 143 + 0-byte JSON), and documents the metadata-loss-event handling shape (verify via `git log` + `git status --porcelain`, halt the AFK loop, reconstruct cost from the Anthropic billing dashboard); the Related entry adds a P147 cross-reference; the briefing entry at `docs/briefing/afk-subprocess.md` adds the Fixed-2026-05-03 closing line.

**Awaiting user verification**.

**Exercise evidence (in-session, AFK iter 7)**:
- TDD red-green-refactor cycle confirmed: 3 of 4 new bats cases failed before the SKILL.md prose amendment (test 12 at the conditional-caveat phrase, test 13 at the metadata-loss-event handling shape, test 14 at the P147 citation); the behavioural stuck-before-emit fake-shim test 11 (`JSON_BYTES=0` after SIGTERM-before-emit) was self-contained and green from authoring. All 14 of 14 tests pass after the SKILL.md edit.
- Behavioural fixture re-creates the 2026-04-29 P146 incident shape: a fake `claude_no_emit` shim traps SIGTERM and exits 0 WITHOUT writing any stdout (mirroring the deadlocked-before-emit case where `claude -p --output-format json`'s single-blob-on-exit write has nothing to flush). The orchestrator-shape harness fires SIGTERM after the idle threshold and the assertion pins `JSON_BYTES=0` — exactly the falsifying observation that motivated this ticket.
- Doc-lint contract assertions guard the conditional caveat against silent prose drift (Permitted Exception under ADR-037, co-located with the existing P121 prose-drift guards in the same fixture per the architect's APPROVE verdict).

**Verification path**: any future stuck-before-emit subprocess incident in `/wr-itil:work-problems` AFK loops (the most likely re-entry: another iteration-internal polling-loop bug like P146 that deadlocks AFTER commits land but BEFORE `ITERATION_SUMMARY` emission) should now be handled correctly: orchestrator observes exit 143 + 0-byte JSON, halts the loop per exit-code semantics rather than silently continuing, surfaces the metadata-loss event with `git log` / `git status --porcelain` evidence in the AFK summary, and notes that cost reconstruction requires the Anthropic billing dashboard. If a future incident instead silently continues past exit-143 + 0-byte JSON, the SKILL.md prose amendment failed to land or the orchestrator's exit-code handling is regressed.

**Composes-with**: P121 (parent — orchestrator-side SIGTERM mechanism unchanged; this ticket is documentation accuracy + handling shape, not behavioural change), P146 (sibling — the polling-regex iteration-internal bug that produced the falsifying evidence; remains an independent failure class), ADR-005 (test-first), ADR-037 (Permitted Exception for the co-located doc-lint assertions), ADR-014 (single-commit-per-batch — SKILL.md + bats + briefing + ticket transition + README + changeset all in one commit).

## Description

`packages/itil/skills/work-problems/SKILL.md` Step 5's "Idle-timeout SIGTERM (P121)" subsection contains the prose claim:

> SIGTERM is therefore a safe recovery primitive for this stuck-state class — empirically a clean exit-flush, not a destructive interrupt.

This claim was true for P118's evidence (2026-04-25): the subprocess had completed semantic work AND emitted ITERATION_SUMMARY before going idle; SIGTERM at 121 min produced a clean 5649-byte JSON. The claim does NOT hold when the subprocess is stuck BEFORE ITERATION_SUMMARY emission.

Today (2026-04-29 iter 1, P143): subprocess deadlocked in a polling-regex bug (P146) AFTER commits landed but BEFORE ITERATION_SUMMARY emission. Manual SIGTERM at 08:51 produced exit 143 with a **0-byte** JSON file. `claude -p --output-format json` emits the entire response as a single JSON blob ON normal exit; SIGTERM-before-blob-write means no JSON is ever written. The 0 bytes are the result of the redirect being set up but no output ever flushed.

The SKILL.md prose generalises P118's evidence into a universal claim. The generalisation is incorrect.

## Symptoms

- 2026-04-29 iter 1 PID 23580: SIGTERM at 08:51:34 → exit 143 → `/tmp/wp-iter1.json` 0 bytes both before and after SIGTERM.
- Lost: full subprocess metadata (ITERATION_SUMMARY block, total_cost_usd, duration_ms, usage.* token totals). Cost reconstruction requires Anthropic billing dashboard query.
- Lost: cost metadata for orchestrator's Session Cost section in the AFK summary; Session Cost was rendered "unavailable" today as a result.
- Lost: outstanding_questions field that Step 2.5b would have surfaced — fortunately iter 1 didn't accumulate any.
- Contrast P118 evidence: SIGTERM at 121min produced 5649-byte clean JSON with full ITERATION_SUMMARY + Session Retrospective sections. The two evidence points are at opposite ends of the same SKILL.md claim.

## Workaround

When SIGTERM-recovery is needed:

1. **Verify ITERATION_SUMMARY was emitted before SIGTERM** by checking the agent's recent stdout / stderr stream for the `ITERATION_SUMMARY` block before sending SIGTERM. If not visible, expect 0-byte JSON.
2. **If 0-byte JSON observed after SIGTERM**: verify work integrity independently via `git log` (commits landed?) + `git status --porcelain` (tree clean?), and treat the iteration as completed-without-metadata. Halt the AFK loop per exit-code semantics; reconstruct cost from Anthropic billing dashboard.
3. **Continue NOT to send SIGTERM at the orchestrator's automatic 60-min threshold** as a workaround — the threshold is the right guardrail; the bug is the prose claim about what happens after SIGTERM. Manual mid-loop SIGTERM (like today's at 08:51) is fine for wall-clock recovery; the metadata is the lost asset.

## Impact Assessment

- **Who is affected**: every AFK orchestrator that hits a stuck-before-emit deadlock. Today: 1 incident (iter 1). With P146 unfixed, this can recur on every Step 11 commit-gate that uses TAP-mode bats output.
- **Frequency**: per-incident with P146 unfixed; rare otherwise.
- **Severity**: Minor (2) on a per-incident basis — work integrity is preserved (commits land, tree state is independently verifiable), only metadata is lost. The metadata loss is operational pain, not data loss.
- **Likelihood**: Possible (2) — bug is in a prose claim that orchestrators rely on; today's incident was the first reproducible falsification of the claim.
- **Analytics**: 2 evidence points (P118 "true at high latency" 2026-04-25, P146 incident 2026-04-29 "false at lower latency"). Sample size of 2 across 4 days.

## Root Cause Analysis

### Investigation Tasks

- [ ] Read `packages/itil/skills/work-problems/SKILL.md` line 27 area "Idle-timeout SIGTERM (P121)" subsection carefully. Identify the prose claim to amend.
- [ ] Identify the conditional caveat: "SIGTERM produces clean JSON exit-flush IF the subprocess has already emitted ITERATION_SUMMARY through the agent stream before going idle". When ITERATION_SUMMARY has not yet emitted, the JSON file stays 0 bytes.
- [ ] Add behavioural-test second-source: `packages/itil/skills/work-problems/test/work-problems-step-5-idle-timeout-sigterm.bats` already covers the post-emit-flush case (per P121's confirmation criterion). Extend with a stuck-before-emit fake-shim test that asserts 0-byte JSON on SIGTERM-before-emit.
- [ ] Decide whether to also extend the orchestrator's poll loop to detect "subprocess emitted ITERATION_SUMMARY-shaped output yet?" before deciding to SIGTERM. If yes, that's a behavioural change beyond the prose caveat — defer to a sibling ticket.

### Preliminary hypothesis

P118's 2026-04-25 evidence was the only data point when the SKILL.md prose claim was authored. The generalisation "SIGTERM produces clean exit-flush" was a single-source generalisation that today's incident falsifies. The fix is bounded: amend the prose claim with the conditional caveat + add a behavioural test as the second-source the prose now needs.

This is a **documentation accuracy** problem, not a behavioural change. The orchestrator-side SIGTERM mechanism is fine. What's broken is the agent's expectation about what the JSON file contains after SIGTERM.

## Fix Strategy

**Kind**: improve

**Shape**: skill (`packages/itil/skills/work-problems/SKILL.md` Step 5 "Idle-timeout SIGTERM (P121)" subsection prose) + behavioural bats (`packages/itil/skills/work-problems/test/work-problems-step-5-idle-timeout-sigterm.bats` extension)

**Target file**: `packages/itil/skills/work-problems/SKILL.md` line 27 area

**Observed flaw**: the prose claim "SIGTERM is therefore a safe recovery primitive for this stuck-state class — empirically a clean exit-flush, not a destructive interrupt" is true only when the subprocess has completed ITERATION_SUMMARY emission before going idle.

**Edit summary**:

1. Amend the SKILL.md prose to add the conditional caveat: "...empirically a clean exit-flush WHEN the subprocess has already emitted `ITERATION_SUMMARY` through the agent stream before going idle. When SIGTERM fires before emission (e.g. the subprocess deadlocks in a backgrounded-task wait that fires AFTER commits land but BEFORE ITERATION_SUMMARY emission), the JSON file stays 0 bytes — `claude -p --output-format json` writes the response only on normal exit. Treat exit 143 + 0-byte JSON as a metadata-loss event: verify work integrity via `git log` + `git status --porcelain`, halt the AFK loop, and reconstruct cost from the Anthropic billing dashboard. Cost-of-metadata-loss < cost-of-stuck-subprocess; SIGTERM remains the right recovery primitive."
2. Add behavioural-test second-source: extend `work-problems-step-5-idle-timeout-sigterm.bats` with a fake-shim case that exits via SIGTERM before any agent-stream output, asserts the JSON file is 0 bytes, and asserts the orchestrator's expected "metadata-loss event" handling.
3. Update `docs/briefing/afk-subprocess.md` entry that already landed today (commit `9f53ad3`'s briefing edit) to cite this ticket once it lands.

**Evidence**:
- P118 (2026-04-25): SIGTERM at 121min → clean 5649-byte JSON. Subprocess had emitted ITERATION_SUMMARY before going idle.
- P146 / today (2026-04-29): SIGTERM at 68m34s → 0-byte JSON. Subprocess deadlocked BEFORE ITERATION_SUMMARY emission.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none — fix is independent)
- **Composes with**: P146 (sibling — if P146 fixes the iteration polling-regex bug, the stuck-before-emit class that surfaced this SIGTERM-flush gap becomes rare). Even with P146 fixed, the SKILL.md prose claim should still carry the conditional caveat for any future stuck-before-emit failure mode.

## Related

- **P121** (`docs/problems/121-afk-orchestrator-should-sigterm-stuck-subprocesses-after-idle-timeout.verifying.md`) — parent ticket. Established the orchestrator-side SIGTERM mechanism. Today's incident demonstrates the prose accuracy gap, not a mechanism defect — P121 stays verifying.
- **P146** — sibling ticket (this same retro) for the polling-regex bug that produced today's stuck-before-emit case.
- **P118** (`docs/problems/118-...verifying.md` / closed) — original evidence source for the SIGTERM-clean-flush claim.
- **`packages/itil/skills/work-problems/SKILL.md`** Step 5 / line 27 — Edit target for prose caveat.
- **`packages/itil/skills/work-problems/test/work-problems-step-5-idle-timeout-sigterm.bats`** — behavioural-test second-source.
- **`docs/briefing/afk-subprocess.md`** — entry already landed today (commit `9f53ad3`) capturing the conditional-claim observation; can be cross-referenced once this ticket lands.
