#!/usr/bin/env bats

# P130: /wr-itil:work-problems orchestrator must NOT call AskUserQuestion
# mid-loop. The loop's purpose is progress + accumulation; user-interaction
# is reserved for framework-prescribed halt points (Step 0, Step 2.5/2.5b,
# Step 6.5 Rule 5 + CI-failure, Step 6.75 dirty-unknown). The user is
# transient — presence-detection is unreliable and is not the goal; the
# orchestrator must accumulate questions and surface them at halt points.
#
# Per the user's reframe (ticket P130 lines 95-123), the original dual-mode
# dispatch fix-shape was rejected. The fix is SKILL.md prose discipline:
# enumerate the framework-prescribed halt points + assert no mid-iter asks
# elsewhere + state the accumulated-question discipline (direction-setting
# only; no BUFD; no questions answerable by research/exploration/
# experimentation).
#
# Doc-lint contract assertions per ADR-037 Permitted Exception (structural
# checks on prose contract, sibling shape with P126 / P135 fixtures).
#
# @problem P130
# @adr ADR-044 (Decision-Delegation Contract — framework-resolution boundary)
# @adr ADR-013 Rule 1 (as amended by ADR-044) + Rule 6 (non-interactive fail-safe)
# @adr ADR-032 (subprocess-boundary contract — unchanged)
# @adr ADR-037 (skill-testing-strategy — Permitted Exception for prose contract)
# @jtbd JTBD-006 (Progress the Backlog While I'm Away)
# @jtbd JTBD-001 (Enforce Governance Without Slowing Down)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/packages/itil/skills/work-problems/SKILL.md"
}

@test "work-problems P130: SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

# ── Mid-loop ask discipline subsection presence ─────────────────────────────

@test "work-problems P130: SKILL.md names a 'Mid-loop ask discipline' subsection (orchestrator main turn)" {
  # The architect-approved placement is inside Non-Interactive Decision
  # Making section as a subsection. The heading must exist as a navigable
  # markdown anchor so cross-references resolve.
  run grep -nE '^#{3,4} Mid-loop ask discipline' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection scopes itself to the orchestrator main turn (not the subprocess)" {
  # The subprocess-layer constraint (Step 5's iteration-prompt body)
  # already exists; this subsection is the orchestrator-main-turn
  # equivalent. The scope must be explicit so future readers do not
  # confuse the layers.
  run grep -nE 'orchestrator main turn|orchestrator.s main turn' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Core invariant: no mid-iter AskUserQuestion ─────────────────────────────

@test "work-problems P130: subsection asserts no mid-loop AskUserQuestion between iters except at framework halts" {
  # The load-bearing rule. The orchestrator must NOT call AskUserQuestion
  # between iterations EXCEPT at the framework-prescribed halt points.
  run grep -nE 'MUST NOT call .?AskUserQuestion.? between iter' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection cites the loop's purpose as progress + accumulation" {
  # The reframed direction (ticket lines 95-123): the loop's purpose is
  # progress + accumulation, not interactive-vs-AFK routing. This phrasing
  # must appear so future authors do not re-introduce mid-loop asks under
  # 'the user might be present' rationalisations.
  run grep -nE 'progress \+ accumulation|progress and accumulation' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection states presence-detection is unreliable and not the goal" {
  # The transient-user framing. Without this, future authors may try to
  # add presence-detection (the originally-rejected fix-shape).
  run grep -nE 'presence[- ]detection is unreliable|presence is unreliable|user as transient|treat the user as transient' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Halt-point enumeration ──────────────────────────────────────────────────

@test "work-problems P130: subsection enumerates Step 0 session-continuity as a permitted halt point" {
  run grep -nE 'Step 0.*session[- ]continuity' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection enumerates Step 2.5 / 2.5b loop-end emit as a permitted halt point" {
  run grep -nE 'Step 2\.5.*loop[- ]end|Step 2\.5b' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection enumerates Step 6.5 above-appetite Rule 5 halt as a permitted halt point" {
  run grep -nE 'Step 6\.5.*Rule 5|above[- ]appetite Rule 5' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection enumerates Step 6.75 dirty-for-unknown-reason as a permitted halt point" {
  run grep -nE 'Step 6\.75.*dirty[- ]for[- ]unknown|Step 6\.75.*unknown reason' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Accumulated-question discipline at surface time ─────────────────────────

@test "work-problems P130: subsection states direction-setting only at surface time" {
  # ADR-044's six-class taxonomy: only the user-answerable categories
  # qualify. Direction-setting is the canonical example.
  run grep -nE 'Direction[- ]setting only|direction[- ]setting only' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection forbids BUFD-style questions" {
  # No big-design-up-front; small actionable questions. Anti-BUFD is a
  # project-wide value (cited in ADR-044's anti-BUFD-for-framework-
  # evolution clause).
  run grep -nE 'No BUFD|no BUFD' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection forbids questions answerable by research / exploration / experimentation" {
  # The agent should investigate itself rather than sub-contract routine
  # work back to the user.
  run grep -nE 'research.*exploration.*experimentation|prototype.*read code.*experiments' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── ADR citations ──────────────────────────────────────────────────────────

@test "work-problems P130: subsection cites ADR-044 (primary) as the framework-resolution authority" {
  # ADR-044 is the parent decision narrowing ADR-013 Rule 1 to framework-
  # unresolved decisions. The subsection must cite it so future readers
  # follow the cross-reference for the full picture.
  run grep -nE 'ADR-044' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection cites ADR-013 Rule 1 as amended by ADR-044" {
  # The narrowing happens at ADR-013 Rule 1's amendment. The subsection
  # must name the rule so the chain is traceable.
  run grep -nE 'ADR-013.*Rule 1|Rule 1.*amended by ADR-044' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P130: subsection cites ADR-013 Rule 6 as the non-interactive fail-safe underlying constraint" {
  # When AFK, Rule 6 is the underlying constraint that forbids
  # AskUserQuestion. The subsection cites it so the subprocess-boundary
  # connection is explicit.
  run grep -nE 'ADR-013.*Rule 6|Rule 6.*non[- ]interactive fail[- ]safe' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── ADR-032 subprocess-boundary unchanged ──────────────────────────────────

@test "work-problems P130: subsection cross-references ADR-032 subprocess-boundary contract as unchanged" {
  # The architect's flag: this fix does NOT amend ADR-032. The subsection
  # must say so explicitly to prevent future readers thinking the
  # subprocess-boundary contract is in scope.
  run grep -nE 'subprocess[- ]boundary contract.*unchanged|ADR-032.*unchanged' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Subprocess vs orchestrator layer cross-reference ───────────────────────

@test "work-problems P130: subsection cross-references Step 5's per-subprocess constraint as the parallel layer" {
  # The orchestrator-main-turn discipline parallels Step 5's iteration-
  # prompt-body 'Do not call AskUserQuestion' constraint. Both layers
  # together enforce the discipline end-to-end.
  run grep -nE "Step 5.*iteration[- ]prompt.*AskUserQuestion|Step 5's iteration[- ]prompt" "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Step 5's iteration-prompt body augmented with transient-user framing ───

@test "work-problems P130: Step 5 iteration-prompt body includes transient-user framing" {
  # The reframed direction's core insight: the user is transient even
  # when present. The iteration-prompt body (already-existing
  # 'NEVER call AskUserQuestion mid-loop in AFK') gains the transient
  # framing so future iter authors understand why the constraint is
  # absolute.
  run grep -nE 'transient|disappear for hours' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Decision Table row reflects the discipline ─────────────────────────────

@test "work-problems P130: Non-Interactive Decision Making table carries a row for mid-loop ask discipline" {
  # The decisions table (line ~487) summarises the orchestrator's
  # non-interactive defaults. A row naming mid-loop ask discipline keeps
  # the table consistent with the new subsection.
  run grep -nE '\| Mid-loop ask|mid[- ]loop AskUserQuestion|mid-loop ask between iter' "$SKILL_MD"
  [ "$status" -eq 0 ]
}
