#!/usr/bin/env bats

# P233: /wr-itil:work-problems Step 6.5 Drain action must chain
# /install-updates AFTER successful release:watch so the next iter
# subprocess loads the just-shipped plugin from cache rather than the
# pre-release cached version.
#
# Empirical driver (briefing/afk-subprocess.md:18): iter subprocesses
# re-resolve plugin cache on spawn; without cache refresh between
# release:watch and next-iter dispatch, the just-shipped hook is
# inactive in the next iter — defeating the "ship a hook to prevent
# recurrence" pattern for the immediate-next-iter case.
#
# Doc-lint contract assertions per ADR-037 Permitted Exception
# (contract-assertion class — same shape as the P140 / P130 / P126 / P135
# sibling fixtures). The asserted prose IS the load-bearing policy
# surface — the chained invocation is documentation-only (the orchestrator
# is a prose-driven agent, not a script); the SKILL.md is the contract.
# Behavioural assertion would require a fixture project + real claude -p
# subprocess that observes a freshly-installed plugin — outside scope.
#
# @problem P233
# @adr ADR-013 (Rule 5 — policy-authorised silent action; chains the
#       same authorisation that covers push:watch / release:watch)
# @adr ADR-014 (one-commit-per-iter; this edit lands in one commit)
# @adr ADR-018 (inter-iteration release cadence; this refines its
#       Drain action sub-block with the post-release cache refresh)
# @adr ADR-030 (repo-local skills — install-updates is the chained
#       skill)
# @adr ADR-037 (skill-testing strategy — contract-assertion class)
# @adr ADR-044 (decision-delegation contract — framework-resolution
#       boundary; install-updates' AskUserQuestion-bearing branches
#       fall through to its Non-interactive fallback under P130)
# @jtbd JTBD-006 (Progress the Backlog While I'm Away — primary;
#       outcome 7 "risk never silently accumulates across AFK iterations"
#       extends to "just-shipped hooks effective on next iter")
# @jtbd JTBD-001 (Enforce Governance Without Slowing Down — composes;
#       just-shipped governance hooks become effective immediately,
#       not after manual /install-updates re-run)
# @jtbd JTBD-007 (Keep Plugins Current Across Projects — persona-level
#       currency anchor that JTBD-006's AFK use case extends)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/packages/itil/skills/work-problems/SKILL.md"
}

@test "work-problems P233: SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

# ── Cache-refresh chain identity ───────────────────────────────────────────

@test "work-problems P233: Step 6.5 Drain action carries a post-release cache-refresh subsection citing P233" {
  # The amendment must self-identify so future readers tracing back from
  # the ticket find the load-bearing prose without keyword-guessing.
  run grep -nE 'cache.refresh.*P233|P233.*cache.refresh|post.release.cache.*P233|P233.*post.release.cache' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P233: Drain action chains /install-updates after successful release:watch" {
  # Core contract: after release:watch returns success, the orchestrator
  # invokes /install-updates to refresh the plugin cache. Without this
  # chain, the next iter subprocess loads the pre-release cached version
  # (P233's empirical root cause).
  run grep -nE '/install-updates|install-updates skill' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P233: cache-refresh is conditional on actual release (skipped when no changeset)" {
  # The chain MUST NOT fire when release:watch was a no-op (empty
  # .changeset/ after push). No new plugin version exists → nothing to
  # refresh. Without this guard, the orchestrator burns wall-clock and
  # noise on a no-op /install-updates invocation every iter.
  run grep -niE 'only.*release.*actually|when.*release.*shipped|skip.*when.*no.changeset|conditional on.*release' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P233: cache-refresh is non-blocking on /install-updates failure" {
  # If /install-updates fails (cache miss + non-interactive fallback,
  # marketplace fetch error, transient flake), the orchestrator MUST NOT
  # halt the loop. Degrades to current behaviour — cache stays stale;
  # equivalent to pre-amendment behaviour. Loop continues.
  run grep -niE 'non.blocking.*install.updates|install.updates.*non.blocking|do not halt.*install.updates|install.updates.*failure.*continue' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Empirical evidence citation ────────────────────────────────────────────

@test "work-problems P233: cache-refresh subsection cites briefing/afk-subprocess.md evidence" {
  # The architect FLAG resolution required the evidence that subprocesses
  # re-resolve cache on spawn (rather than inherit parent-resolved
  # plugins). The briefing entry is dispositive — cite it inline so
  # future readers don't re-litigate the question.
  run grep -nE 'afk-subprocess|briefing.*subprocess.*cache' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── ADR-013 Rule 5 policy authorisation ────────────────────────────────────

@test "work-problems P233: cache-refresh chain rides ADR-013 Rule 5 (same authorisation as push:watch / release:watch)" {
  # The chain MUST be silent — invocation between iters is a mechanical
  # post-release step the framework has resolved. Same ADR-013 Rule 5
  # citation already covers push:watch / release:watch in the within-
  # appetite drain; the cache-refresh extends the same authorisation.
  run grep -nE 'ADR-013 Rule 5|Rule 5 policy-authorised|policy-authorised.*ADR-013' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Mid-loop ask discipline preservation (P130) ────────────────────────────

@test "work-problems P233: cache-refresh prose cites install-updates Non-interactive fallback for AskUserQuestion routing" {
  # If install-updates' Step 5b/5c consent gate fires (cache miss /
  # scope delta / INSTALL_UPDATES_RECONFIRM=1), the orchestrator main
  # turn MUST NOT surface AskUserQuestion mid-loop per P130. Cite the
  # install-updates Non-interactive fallback as the routing.
  run grep -niE 'Non.interactive fallback|non-interactive fallback' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P233: cache-refresh prose cites ADR-044 framework-resolution boundary for AskUserQuestion-available-but-forbidden routing" {
  # Architect advisory: cite ADR-044 alongside the Non-interactive
  # fallback ref so future readers can trace the "AskUserQuestion-
  # available-but-forbidden" reasoning back to the framework-resolution
  # boundary — not just the install-updates-side dry-run mechanic.
  run grep -nE 'ADR-044' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Composition with above-appetite branch ─────────────────────────────────

@test "work-problems P233: cache-refresh fires only after within-appetite Drain action (not after above-appetite Rule 5 halt)" {
  # Above-appetite Rule 5 halt terminates without a release; no cache
  # refresh fires. Within-appetite convergence loops back to Drain
  # action; cache refresh fires there. The prose must not place the
  # chain inside the above-appetite branch.
  run grep -niE 'within.appetite.*drain.*cache|cache.refresh.*within.appetite|after.*drain.*action' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Non-Interactive Decision Making table row ──────────────────────────────

@test "work-problems P233: Decision Making table carries a post-release cache-refresh row" {
  # The decision table is the AFK reader's quick-reference; without a
  # row here the cache-refresh chain is buried in Step 6.5.
  run grep -nE '\|.*[Pp]ost.release cache|\|.*[Cc]ache refresh|\|.*[Pp]lugin cache refresh' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P233: Decision Making table row cites P233" {
  # Per ADR-037 doc-lint pattern + existing P140 / P126 / P135 sibling
  # rows — every Decision Making table row that documents a P-driven
  # refinement cites the driver ticket.
  run grep -nE '\|.*cache refresh.*P233|\|.*P233.*cache refresh|\|.*post.release.*P233|\|.*P233.*post.release' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

# ── Composition cross-references ───────────────────────────────────────────

@test "work-problems P233: cache-refresh prose cross-references P106 (claude plugin install no-op-when-already-installed)" {
  # P106 is the compounding factor that makes /install-updates' explicit
  # uninstall + install dance necessary (vs. naive claude plugin
  # install which silent-no-ops). Cite it so future readers don't try
  # to simplify the chain.
  run grep -nE 'P106' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "work-problems P233: cache-refresh prose cross-references P130 (orchestrator main-turn ask discipline preserved)" {
  # P130 is the constraint the Non-interactive fallback routing exists
  # to satisfy. Citation makes the dependency auditable.
  run grep -nE 'P130' "$SKILL_MD"
  [ "$status" -eq 0 ]
}
