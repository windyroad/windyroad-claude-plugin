#!/usr/bin/env bats
# Contract assertions for /wr-itil:transition-problem (P071 split slice 4).
#
# This skill hosts the "advance a ticket's lifecycle" user intent
# previously hidden behind /wr-itil:manage-problem <NNN> known-error
# (and the sibling <NNN> close form). Transition renames the ticket
# file, updates the Status field, and refreshes docs/problems/README.md
# in the same commit per ADR-014 + ADR-022 + P062.
#
# This skill is the AUTHORITATIVE executor for the user-initiated
# transition path per P093: it hosts the Step 7 transition block inline
# (pre-flight checks, P063 external-root-cause detection, git mv + Edit
# + P057 re-stage, Status field edit, ## Fix Released section write for
# the verifying destination, P062 README.md refresh, ADR-014 commit).
# The skill does NOT delegate execution back to /wr-itil:manage-problem;
# the deprecation-window forwarder on manage-problem routes one-way to
# this skill and returns its output verbatim (no round-trip).
#
# The in-skill Step 7 block on manage-problem remains the authoritative
# source for in-skill callers (Step 9b auto-transition, the Parked path,
# Step 9d closure inside review). Per ADR-010 amended "Split-skill
# execution ownership": copy, not move — the user-initiated transition
# path owned by this skill carries an inline scoped copy of the
# mechanic; the host skill's in-house callers keep their inline copy.
#
# Structural assertion — Permitted Exception to the source-grep ban
# (ADR-005 / P011 / ADR-037 contract-assertion pattern).
#
# @problem P071
# @problem P093
# @jtbd JTBD-001 (enforce governance without slowing down — discoverable surface + terminating contract)
# @jtbd JTBD-101 (extend the suite with clear patterns — one skill per distinct user intent, split skills own execution)
#
# Cross-reference:
#   P071: docs/problems/071-argument-based-skill-subcommands-are-not-discoverable.open.md
#   P093: docs/problems/093-transition-problem-and-manage-problem-circular-delegation-for-nnn-status-args.*.md
#   ADR-010 amended (Skill Granularity section) — split naming + forwarder contract + split-skill execution ownership
#   ADR-013 Rule 1 — structured user interaction (tie-break selection, if any)
#   ADR-013 Rule 6 — AFK non-interactive fallback
#   ADR-014 — governance skills commit their own work (this skill owns the transition commit)
#   ADR-022 — .verifying.md suffix on release; Verification Pending distinct from Known Error
#   ADR-037 — contract-assertion bats pattern
#   P057 — git mv + Edit staging trap
#   P062 — README.md refresh on every transition
#   P063 — external-root-cause detection at Open → Known Error

setup() {
  SKILL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL_FILE="${SKILL_DIR}/SKILL.md"
}

@test "SKILL.md exists and has frontmatter" {
  [ -f "$SKILL_FILE" ]
  run head -1 "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ "$output" = "---" ]
}

@test "SKILL.md frontmatter name is wr-itil:transition-problem (P071 + ADR-010 amended)" {
  # Split naming convention per ADR-010 amendment: <verb>-<object>.
  # The verb is "transition" (not "resolve", "advance", or
  # "change-status") because the original subcommand form was
  # `/wr-itil:manage-problem <NNN> known-error` — a status transition
  # with a declarative destination. The P071 ticket's split proposal
  # names this skill explicitly; the test locks the name in.
  run grep -n "^name: wr-itil:transition-problem$" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md frontmatter description names the transition intent (P071)" {
  # Description must name "transition" / "status" / one of the
  # destination names (known-error / verifying / closed) so Claude Code
  # autocomplete surfaces the user intent rather than a generic name.
  run grep -inE "^description:.*(transition|status|lifecycle|advance)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "^description:.*(known.error|verification|closed|verify)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md frontmatter allowed-tools includes Skill (retained for orchestrator composition)" {
  # Although this skill no longer delegates Step 7 execution to
  # /wr-itil:manage-problem (P093 fix — inline execution), the Skill
  # tool remains in allowed-tools so the skill can be invoked from
  # orchestrators (e.g. /wr-itil:work-problems) and so it can invoke
  # /wr-itil:report-upstream when P063 external-root-cause detection
  # fires option 1. Dropping Skill from allowed-tools would break both
  # composition paths.
  run grep -nE "^allowed-tools:.*Skill" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md frontmatter allowed-tools includes Bash (ticket-file discovery)" {
  # Step 1 discovers the ticket file for a given ID by listing
  # docs/problems/<NNN>-*.md. That's a Bash invocation; without the
  # tool in allowed-tools, the discovery step cannot run.
  run grep -nE "^allowed-tools:.*Bash" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md documents all three lifecycle transition destinations (ADR-022)" {
  # The canonical lifecycle per ADR-022: Open → Known Error → Verification Pending → Closed.
  # The skill must name each destination so users can pick the right
  # transition. Missing any destination would leave a gap in the
  # split coverage and force users back to the deprecated forwarder.
  run grep -inE "known.error" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "verifying|verification.pending" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "\.closed\.md|closed" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md hosts the transition execution inline (P093 — no round-trip to manage-problem)" {
  # P093 inversion: the split skill owns BOTH intent selection AND
  # execution. The pre-flight / P063 external-root-cause detection /
  # staging-trap / README refresh stack is hosted inline here so a
  # contract-literal agent invoking /wr-itil:transition-problem NNN
  # <status> reaches a terminal state — no recursion into
  # /wr-itil:manage-problem.
  #
  # "No round-trip" scope: the SKILL.md body MUST NOT contain a
  # delegation-imperative instruction that routes Step 7 execution back
  # to /wr-itil:manage-problem. Citations to manage-problem in the
  # Related section or as a sibling skill reference are permitted —
  # this assertion targets delegation-imperative language only.
  #
  # Per ADR-010 amended "Split-skill execution ownership": copy, not
  # move. The Step 7 block on manage-problem stays in place for
  # in-skill callers (Step 9b auto-transition, Parked path, Step 9d
  # closure inside review). This skill carries a scoped inline copy for
  # the user-initiated transition path only.
  run grep -inE "delegate.{0,40}(to |/)?/?wr-itil:manage-problem|Skill tool.{0,40}manage-problem|manage-problem.{0,40}(via|through)? ?the Skill tool" "$SKILL_FILE"
  [ "$status" -ne 0 ]
}

@test "SKILL.md documents the inline Step 7 execution mechanics (P093 — authoritative executor)" {
  # Positive assertion: the skill must describe the full Step 7
  # mechanic so a contract-literal agent has enough information to
  # execute the transition without reading manage-problem's SKILL.md.
  # Each mechanic is represented by at least one identifying phrase;
  # missing any of them would leave a gap the execution path can fall
  # through.
  run grep -inE "pre-flight|pre.flight" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "git mv" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "git add" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "Fix Released" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "git commit|commit per ADR-014" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites the P057 staging-trap rule (transitive contract)" {
  # The delegated Step 7 block on manage-problem implements the
  # staging-trap rule (re-stage after git mv + Edit). This skill must
  # reference P057 so the transitive-contract dependency is legible —
  # if the manage-problem Step 7 rule changes, this skill's delegation
  # contract changes with it.
  run grep -inE "P057|staging.trap|re-stage" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites the P062 README.md refresh rule (transitive contract)" {
  # The delegated Step 7 block refreshes docs/problems/README.md on
  # every transition. This skill must reference P062 so the
  # downstream-refresh expectation is legible to callers (and so the
  # skill does not mistakenly skip the refresh on the assumption that
  # "the README is someone else's job").
  run grep -inE "P062|README\.md.*refresh|refresh.*README\.md" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites ADR-022 (Verification Pending is a first-class status)" {
  # Known Error → Verification Pending is the transition most users
  # will type this skill for (it fires on every released fix). The
  # skill must cite ADR-022 so the semantic distinction — "Verification
  # Pending means fix SHIPPED, not fix-path-clear" — stays legible.
  run grep -inE "ADR-022" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md documents the AFK non-interactive branch (ADR-013 Rule 6)" {
  # When /wr-itil:work-problems invokes this skill inside an AFK
  # subagent iteration, AskUserQuestion is unavailable — the skill
  # must degrade gracefully. Common case: Known Error → Verification
  # Pending fires automatically in the release-commit orchestration.
  run grep -inE "AFK|non-interactive|ADR-013 Rule 6|Rule 6" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md does not carry a deprecated-arguments frontmatter flag (clean-split skill)" {
  # Architect advisory: transition-problem is a clean-split skill. The
  # deprecated-arguments flag is only valid on host skills with
  # forwarder routes — transition-problem is a forwarder TARGET, not
  # a host. The status argument (known-error / verifying / close) is
  # a *data parameter*, not a word-subcommand, per the P071 split rule.
  run grep -E "^deprecated-arguments:" "$SKILL_FILE"
  [ "$status" -ne 0 ]
}

@test "SKILL.md cites P071 and ADR-010 amended (traceability per ADR-037)" {
  # ADR-037 traceability: the skill spec cites the problem it closes
  # and the ADR that authorises the split.
  run grep -inE "P071|ADR-010" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md documents the ticket-ID data-parameter shape (not a word-subcommand)" {
  # The ticket ID (<NNN>) is a data parameter per P071's split rule.
  # The status destination (known-error / verifying / close) is ALSO
  # a data parameter — the user supplies it alongside the ID. This is
  # the same shape as /wr-itil:report-upstream <NNN>: data parameters
  # are fine, word-subcommands routing to distinct user intents are not.
  run grep -inE "<NNN>|ticket.{0,5}ID|ID.*argument|data parameter" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────
# P331 — Inline P134 rotation mechanism (anti-skip contract)
#
# Before P331's fix, the P134 line-3 rotation discipline was documented
# at this skill's Step 7 (and 5 sibling surfaces) as a single-sentence
# cross-document reference of shape:
#
#   "Update the 'Last reviewed' line per the **Last-reviewed line
#    discipline (P134)** contract documented in `manage-problem`
#    SKILL.md Step 5"
#
# Agents reading the SKILL in a single-pass execution context did not
# cross-navigate to manage-problem Step 5 and executed the obvious
# "regenerate README.md" + "git add" steps without first archiving the
# displaced line 3 to README-history.md. Iter-7 + iter-8 of 2026-05-30's
# AFK work-problems session silently skipped the rotation in 2 of 9
# transition-bearing iters (~22%).
#
# Positive control: reconcile-readme Step 5 inlines the same 3-step
# Mechanism as an enumerated numbered list AT the execution site — that
# surface fires correctly. The asymmetry confirms the bug class is
# "cross-document reference at execution sites" vs "inlined mechanism".
#
# The fix elevates the rotation from a one-liner to a 4-step inline
# Mechanism block (Read line 3 / Append-if-non-empty BEFORE rewrite /
# Rewrite line 3 / Stage both). The assertions below lock the inline
# block's presence at this skill's Step 7 execution site so future
# refactors don't silently regress to the cross-doc one-liner.

@test "SKILL.md inlines the P134 rotation Mechanism Read step at Step 7 (P331)" {
  # The mechanism must explicitly call out reading line 3 before
  # rewriting it. The canonical read pattern is `awk 'NR==3'` (matching
  # reconcile-readme Step 5's worked example); `head -3` or `sed -n '3p'`
  # are acceptable equivalents.
  run grep -iE "awk +'NR==3'|head +-3|sed +-n +'3p'|line 3.{0,40}(read|of \`docs/problems/README.md\`)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md inlines the P134 rotation Mechanism Append-BEFORE-Rewrite ordering (P331)" {
  # The ordering rule is load-bearing: the displaced line 3 MUST be
  # appended to README-history.md BEFORE the Edit-tool rewrite of line
  # 3. Without this rule, the Edit replace destroys the displaced
  # content. The assertion checks for explicit ordering language
  # (BEFORE / before rewriting / before step 3) co-located with the
  # README-history.md target.
  run grep -inE "(BEFORE|before).{0,80}(rewrit|step 3|Edit)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites README-history.md as the rotation archive target at Step 7 (P331)" {
  # The archive sibling docs/problems/README-history.md is named at the
  # rotation step. Without an explicit named target, the agent has no
  # destination to append to.
  run grep -E "README-history\.md" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md cites P331 + P134 at the inlined rotation mechanism (traceability per ADR-037)" {
  # The inlined mechanism block cites P331 (this ticket) and P134
  # (the originating discipline ticket) so future readers can trace
  # the load-bearing rationale.
  run grep -inE "P331" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -inE "P134" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
