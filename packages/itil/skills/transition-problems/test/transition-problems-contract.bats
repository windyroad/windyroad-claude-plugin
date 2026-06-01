#!/usr/bin/env bats
# Contract assertions for /wr-itil:transition-problems (P117 plural sibling).
#
# This skill is the BATCH variant of /wr-itil:transition-problem — it
# advances multiple problem tickets through the lifecycle in one
# invocation. Mirrors the P071 singular/plural split precedent
# (work-problem vs work-problems) at a new grain: per-ticket transition
# (singular) vs batch transition (plural).
#
# Why this skill exists (P117):
#   Closing N tickets via the singular skill costs N× SKILL.md reload
#   into the caller's context — this is the very SKILL.md-runtime-size
#   pressure P097 captures. The plural surface eliminates the N× cost
#   by inlining the per-ticket mechanic and looping in-band, single
#   commit at the end per ADR-014 batch grain.
#
# Architect-resolved design points (2026-04-26):
#   1. Partial-failure semantics: skip-and-surface (succeeded pairs
#      commit at end; failed pairs surfaced in summary; zero successes
#      means no commit).
#   2. Argument shape: space-separated `<NNN> <status> <NNN> <status>`
#      pairs — same shape as singular repeated N times. No P prefix,
#      no = separator, no CLI flags.
#   3. Inline per-ticket mechanic — "copy, not move" per ADR-010
#      amended Split-skill execution ownership. NOT Skill-tool
#      re-invocation back into the singular (would reintroduce the
#      N×SKILL.md-reload cost the ticket targets).
#   4. Single commit at end + single README refresh at end (P062
#      mechanic applied at batch grain).
#   5. Three call sites now share the per-ticket mechanic via "copy,
#      not move": singular transition-problem, plural
#      transition-problems (this skill), and manage-problem in-skill
#      Step 7 block.
#
# Structural assertion — Permitted Exception to the source-grep ban
# (ADR-005 / P011 / ADR-037 contract-assertion pattern). SKILL.md is
# explicitly a contract document.
#
# @problem P117
# @problem P071
# @problem P093
# @jtbd JTBD-001 (enforce governance without slowing down — eliminates
#                N×SKILL.md reload tax + ownership-boundary violation)
# @jtbd JTBD-006 (progress backlog while AFK — work-problems may
#                delegate batch closures here without the per-ticket
#                reload cost)
# @jtbd JTBD-101 (extend the suite with clear patterns — singular/plural
#                split mirrors the P071 work-problem/work-problems
#                precedent)
#
# Cross-reference:
#   P117: docs/problems/117-no-batch-transition-for-multiple-problem-tickets.open.md
#   P071: docs/problems/071-argument-based-skill-subcommands-are-not-discoverable.open.md
#   P093: docs/problems/093-transition-problem-and-manage-problem-circular-delegation-for-nnn-status-args.*.md
#   ADR-010 amended (Skill Granularity + Split-skill execution ownership) — copy-not-move guidance
#   ADR-013 Rule 6 — AFK non-interactive fallback
#   ADR-014 — single commit at batch-grain unit of work
#   ADR-022 — .verifying.md suffix
#   ADR-037 — contract-assertion bats pattern; canonical <skill>-contract.bats naming
#   P057 — git mv + Edit staging trap (re-stage per pair)
#   P062 — README.md refresh on transition (applied once at batch grain)
#   P063 — external-root-cause detection at Open → Known Error

setup() {
  SKILL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL_FILE="${SKILL_DIR}/SKILL.md"
  SINGULAR_SKILL_FILE="${SKILL_DIR}/../transition-problem/SKILL.md"
}

@test "SKILL.md exists and has frontmatter" {
  [ -f "$SKILL_FILE" ]
  run head -1 "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ "$output" = "---" ]
}

@test "SKILL.md frontmatter name is wr-itil:transition-problems (plural sibling)" {
  # Plural naming convention per ADR-010 amended Skill Granularity rule.
  # The trailing 's' marks the plural sibling — same shape as
  # list-problems, review-problems, work-problems.
  run grep -n "^name: wr-itil:transition-problems$" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md frontmatter description names the batch intent (P117)" {
  # Description must name "batch" / "multiple" / "many" so Claude Code
  # autocomplete distinguishes the plural from the singular at the
  # autocomplete-discoverability surface.
  run grep -inE "^description:.*(batch|multiple|many)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  # Description must also surface at least one of the destination
  # status names so the user can correlate the skill with the
  # lifecycle it operates on.
  run grep -inE "^description:.*(known.error|verification|verifying|closed|close|lifecycle|transition|advance)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md frontmatter allowed-tools includes Bash + Edit + Read + Skill + Agent" {
  # Bash: ticket-file discovery + git mv + git add + git commit.
  # Edit: Status field updates + ## Fix Released section writes.
  # Read: ticket file inspection + README.md refresh source-of-truth.
  # Skill: orchestrator composition (work-problems may delegate here).
  # Agent: risk-scorer commit-gate delegation per ADR-014 + ADR-015.
  run grep -nE "^allowed-tools:.*Bash" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -nE "^allowed-tools:.*Edit" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -nE "^allowed-tools:.*Read" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -nE "^allowed-tools:.*Skill" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -nE "^allowed-tools:.*Agent" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites P117 (originating ticket) and ADR-010 amended (split authorisation)" {
  run grep -inE "P117" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "ADR-010" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites the work-problem/work-problems precedent (P071 singular/plural split)" {
  # Plugin-developers reading this skill should immediately recognise
  # the singular/plural split pattern. P071 + the work-problem/
  # work-problems precedent is the explicit source.
  run grep -inE "P071|work-problem" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md documents inline per-ticket mechanic — no Skill-tool delegation back to singular" {
  # Architect-resolved design point 3: inline per-ticket mechanic per
  # ADR-010 amended "copy, not move". Delegating back to the singular
  # via the Skill tool would re-introduce the N×SKILL.md-reload cost
  # this ticket targets — the core motivation for P117. The skill must
  # NOT contain delegation-imperative language routing pair execution
  # back to /wr-itil:transition-problem via Skill-tool invocation.
  #
  # Citations to the singular in the Related section or as a sibling
  # source-of-truth are PERMITTED — this assertion targets
  # delegation-imperative wording only.
  run grep -inE "delegate.{0,40}(to |/)?/?wr-itil:transition-problem|Skill tool.{0,40}transition-problem|invoke /?wr-itil:transition-problem.{0,40}per pair|loop.{0,40}invoke /?wr-itil:transition-problem" "$SKILL_FILE"
  [ "$status" -ne 0 ]
}

@test "SKILL.md documents the per-pair mechanic inline (Step 7 staging-trap rule + ## Fix Released)" {
  # Positive assertion: the skill must describe the per-pair mechanic
  # inline so a contract-literal agent has enough information to
  # execute the batch without reading the singular's SKILL.md.
  # Each mechanic is represented by at least one identifying phrase.
  run grep -inE "pre-flight|pre.flight" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "git mv" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "git add" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "Fix Released" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md documents single-commit-at-end batch semantics (ADR-014 batch grain)" {
  # Architect-resolved design point 4 + user direction: ONE commit
  # covering all surviving transitions. The skill must say so
  # explicitly and must NOT instruct per-pair commits.
  run grep -inE "single commit|one commit|commit.{0,15}(at the )?end|batch commit|one (shared )?commit covering" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  # Negative: no per-pair-commit instruction. Match wording like
  # "commit each pair", "commit per pair", "commit per ticket".
  run grep -inE "commit (each|per) (pair|ticket|transition)" "$SKILL_FILE"
  [ "$status" -ne 0 ]
}

@test "SKILL.md documents single README refresh at end (P062 at batch grain)" {
  # Architect-resolved design point 4: single render reflecting all
  # surviving renames, not N renders. Cite P062 explicitly so the
  # transitive contract is legible.
  run grep -inE "P062" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "(refresh|render|regenerate).{0,50}(README|once|at end|at the end)|README.{0,80}(once|at end|at the end)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md documents partial-failure skip-and-surface semantics" {
  # Architect-resolved design point 1: failed pairs are skipped, NOT
  # halted; succeeded pairs commit at end; zero successes means no
  # commit. The skill must make this explicit so users know what
  # outcome to expect when one ID is mistyped or one ticket is missing.
  run grep -inE "partial.failure|partial failure|failed pair|skip.{0,30}(failed|invalid)|surface.{0,30}(failure|failed)|succeeded pair" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  # Zero-success path must be explicit: no commit if zero pairs
  # succeeded.
  run grep -inE "zero (pairs )?succeed|no successful|no pairs? succeed|all (pairs? )?fail" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites P057 staging-trap rule (per-pair re-stage)" {
  # The per-pair mechanic implements P057's re-stage rule (git add
  # after Edit). Citation makes the transitive contract dependency
  # legible.
  run grep -inE "P057|staging.trap|re-stage" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites P063 external-root-cause detection (Open → Known Error per pair)" {
  # P063 detection fires on every Open → Known Error transition,
  # including those done via batch. The plural inherits the singular's
  # AFK fallback (append the stable Upstream report pending marker).
  run grep -inE "P063|external.root.cause|upstream report pending" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites ADR-022 (.verifying.md suffix on release)" {
  # Known Error → Verification Pending is a common batch transition
  # destination (release-batched closures). ADR-022 governs the
  # .verifying.md suffix + ## Fix Released section semantics.
  run grep -inE "ADR-022" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites ADR-013 Rule 6 AFK fallback (inherited from singular)" {
  run grep -inE "AFK|non-interactive|ADR-013 Rule 6|Rule 6" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites ADR-037 / contract-assertion drift detection note (split-skill ownership)" {
  # ADR-010 amended "copy, not move" creates drift risk between
  # singular and plural. The skill's documentation should name the
  # drift management strategy so future maintainers know how the
  # copies stay in sync.
  run grep -inE "ADR-010 amended|Split-skill execution ownership|copy.{0,5}not.{0,5}move" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md documents the argument shape (space-separated <NNN> <status> pairs)" {
  # Argument shape per architect-resolved design point 2: repeating
  # the singular's shape, no P prefix, no = separator, no CLI flags.
  run grep -inE "<NNN>.{0,30}<status>|space.separated|pair.{0,5}of (arguments|tokens)|repeating .{0,30}arguments" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  # Negative: no flag-style or = separator should be documented as
  # the canonical shape.
  run grep -inE "^\s*--pairs\b|<NNN>=<status>|<NNN>:<status>" "$SKILL_FILE"
  [ "$status" -ne 0 ]
}

@test "SKILL.md does not carry a deprecated-arguments frontmatter flag (clean-split sibling)" {
  # Architect: transition-problems is a clean-split sibling. The
  # deprecated-arguments flag is only valid on host skills with
  # forwarder routes — transition-problems is a clean addition with
  # no prior subcommand surface to deprecate.
  run grep -E "^deprecated-arguments:" "$SKILL_FILE"
  [ "$status" -ne 0 ]
}

@test "SKILL.md names singular sibling in Related (ADR-037 traceability + drift management)" {
  # Drift management: the plural carries an inline copy of the
  # singular's per-ticket mechanic. The Related section must name the
  # singular as the source-of-truth for the mechanic so future
  # maintainers know where to update both copies in sync.
  run grep -inE "wr-itil:transition-problem\b|/wr-itil:transition-problem|transition-problem/SKILL\.md|packages/itil/skills/transition-problem" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md and singular SKILL.md share the staging-trap pattern wording (drift detection)" {
  # The per-pair mechanic on the plural carries an inline copy of the
  # singular's git mv + Edit + git add re-stage rule. Drift detection
  # at the contract level: the canonical 'git add' phrase must appear
  # in both files so a future edit that drops the re-stage from one
  # is immediately visible.
  [ -f "$SINGULAR_SKILL_FILE" ]
  run grep -cE "git add docs/problems/" "$SINGULAR_SKILL_FILE"
  singular_count="$output"
  run grep -cE "git add docs/problems/" "$SKILL_FILE"
  plural_count="$output"
  [ "$singular_count" -ge 1 ]
  [ "$plural_count" -ge 1 ]
}

# ──────────────────────────────────────────────────────────────────────
# P331 — Inline P134 rotation mechanism (anti-skip contract; plural mirror)
#
# See the singular contract bats for the full rationale. At batch grain
# the rotation still fires ONCE per batch (per Step 4a) — but the
# Mechanism prose must be inlined here at the execution site too, so a
# contract-literal agent invoking transition-problems doesn't skip the
# archive step under the same one-liner-cross-doc failure mode P331
# captured at the singular's Step 7. The cross-skill drift between
# singular and plural is detected by the shared-substring assertions
# below — if the singular inlines the mechanism but the plural still
# carries the one-liner, the assertions fail.

@test "SKILL.md inlines the P134 rotation Mechanism Read step at Step 4a (P331)" {
  # Same Read pattern as the singular — `awk 'NR==3'` or equivalent
  # before the line 3 rewrite. Inline mechanism at the execution site
  # so the rotation cannot be silently skipped on the cross-doc trip
  # to manage-problem Step 5.
  run grep -iE "awk +'NR==3'|head +-3|sed +-n +'3p'|line 3.{0,40}(read|of \`docs/problems/README.md\`)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md inlines the P134 rotation Mechanism Append-BEFORE-Rewrite ordering (P331)" {
  # Ordering rule load-bearing per the singular — see the singular's
  # rationale comment. Plural inherits the rule at batch grain.
  run grep -inE "(BEFORE|before).{0,80}(rewrit|step 3|Edit)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites README-history.md as the rotation archive target at Step 4a (P331)" {
  run grep -E "README-history\.md" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites P331 + P134 at the inlined rotation mechanism (traceability per ADR-037)" {
  run grep -inE "P331" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "P134" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md and singular SKILL.md share the P134 Read-step pattern (drift detection)" {
  # The canonical Read-step pattern `awk 'NR==3'` (or equivalent) must
  # appear in BOTH the singular SKILL.md and this plural SKILL.md.
  # Inline-copy drift between the two re-opens P331; this assertion
  # surfaces the drift as a contract failure.
  [ -f "$SINGULAR_SKILL_FILE" ]
  run grep -cE "awk +'NR==3'|head +-3|sed +-n +'3p'" "$SINGULAR_SKILL_FILE"
  singular_count="$output"
  run grep -cE "awk +'NR==3'|head +-3|sed +-n +'3p'" "$SKILL_FILE"
  plural_count="$output"
  [ "$singular_count" -ge 1 ]
  [ "$plural_count" -ge 1 ]
}
