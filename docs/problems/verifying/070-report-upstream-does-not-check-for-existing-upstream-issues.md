# Problem 070: /wr-itil:report-upstream does not check for existing upstream issues before filing

**Status**: Verification Pending
**Reported**: 2026-04-20
**Priority**: 12 (High) — Impact: Significant (4) x Likelihood: Possible (3)
**Effort**: M — S → M after user direction 2026-04-20 reshaped the dedup mechanism. Now requires: (1) LLM-based semantic dup detection (not keyword search), (2) new "maintainer annoyance" risk evaluator composing with P064's external-comms risk gate, (3) risk-within-appetite gate on the auto-comment action. Likely shares infrastructure with P064 — architect review at implementation may push to L if the risk-scorer extension is cross-cutting.
**WSJF**: 6.0 — (12 × 1.0) / 2 — Effort re-estimated from S to M after direction pin. Still High severity (duplicate / spammy upstream comments are the most externally-visible failure mode of the skill). Ranks alongside P065 and P068; below P066 / P063 at the top of the queue.

## Direction decision (2026-04-21, user — interactive AskUserQuestion post-AFK-iter-7)

**Dedup mechanism**: **gh search + LLM semantic match** (two-stage).

1. **gh search stage** — query `gh issue list --repo <upstream> --state all --search "<keywords>"` with keywords from the proposed report's title. Returns candidate issues. Cheap pre-filter.
2. **LLM semantic match stage** — evaluate each gh-search candidate's title + body against the proposed report body. Returns match / no-match / partial-match with matching issue URL.

**User note**: *"not sure it needs to be a architect or subagent"* — LLM semantic match does NOT require delegating to `wr-architect:agent`. Lean toward an **inline LLM check** inside the skill's own session (no subagent dispatch) for simplicity; only promote to a dedicated `wr-itil:dedup-check` subagent if architect review flags context-isolation concerns at implementation time. Full `wr-architect:agent` review is overkill for this scope.

Supersedes the 2026-04-20 direction below (which proposed a broader dedup subagent). The gh-search pre-filter trims the LLM's input scope to ~5-10 candidate issues instead of the upstream's full issue list, making the inline LLM check affordable.

## Direction decision (2026-04-20, user — via AskUserQuestion) — superseded by 2026-04-21 above

**Own re-run detection (local ticket already has `## Reported Upstream`)**: do NOT default to auto-commenting. Instead:

- Evaluate whether the NEW evidence (the session's observations, the re-invocation's trigger) would be valuable to upstream maintainers. Cheap / stale / redundant evidence does NOT justify a comment.
- Gate the comment action on a **maintainer-annoyance risk assessment** — likelihood of annoying the maintainer × impact of annoyance on the downstream-upstream relationship. Appetite-driven, same pattern as `wr-risk-scorer:pipeline` but for a different risk domain.
- Only when the risk is within appetite AND the evidence is judged valuable does the skill comment. Otherwise halt with the match surfaced to the user.

**Third-party match detection (different reporter filed similar)**: do NOT use keyword matching — too noisy, high false-positive rate. Instead:

- Fetch each candidate upstream issue's body via `gh issue view <n> --json body,title`.
- Delegate to an **LLM-based semantic comparator** (new subagent or wrapper skill, e.g. `wr-itil:agent` in the `same-problem-classifier` shape or a dedicated `issue-dup-classifier` subagent) that reads `{local ticket description, candidate upstream issue body}` and returns a verdict: `same-problem` / `different-problem` / `uncertain`.
- For `same-problem` verdicts, apply the same maintainer-annoyance risk assessment as the own-re-run branch before considering a comment. For `uncertain`, surface to the user.
- The `gh issue list` still runs to get candidates (can't escape that), but keyword-scored ranking is replaced by LLM adjudication per candidate.

**AFK non-interactive branch**: **auto-comment if the risk is within appetite**. This is a policy-authorised action per ADR-013 Rule 6 when the maintainer-annoyance risk evaluator returns a within-appetite score AND the comment content is within the P064 external-comms leak gate (both gates must pass). Otherwise halt and save the drafted report to the local ticket's `## Drafted Upstream Report` section — same pattern as the security-path halt per ADR-024 Consequences.

**Architectural implications**:

1. **New risk domain** (maintainer-annoyance) — extends `wr-risk-scorer` with a new evaluator. Composes with P064's external-comms leak evaluator on the same surface. Architect review: should this be one combined `wr-risk-scorer:external-comms` subagent with multiple evaluators, or two separate subagents? Lean: one subagent, multiple evaluators — matches the risk-scorer pipeline subagent's multi-layer pattern.
2. **LLM semantic comparator** — new subagent or skill. Shape: reads two prose bodies, returns structured verdict. Architect review: new standalone subagent vs extension of an existing governance agent. Lean: new subagent `wr-itil:same-problem-classifier` (or similar), placed under `packages/itil/agents/` following ADR-011's action-skill peer precedent.
3. **ADR amendments**:
   - ADR-024: add Step 4b + Step 5c to Decision Outcome; remove own-re-run deferral from "Out of scope".
   - P064's sibling ADR (when drafted): include maintainer-annoyance as a declared evaluator on the external-comms surface.
4. **Dependency on P064**: the maintainer-annoyance gate should ship AFTER or ALONGSIDE P064's external-comms leak gate so they compose. If P070 ships first and P064 lands later, expect a bundling commit that wires them together.

**Defaults AFK can apply without further user input**:
- Risk appetite threshold for maintainer-annoyance: same as commit-layer appetite per RISK-POLICY.md (Low, ≤4/25) unless a specific appetite for this domain is declared in a separate policy update.
- Evidence-valuable heuristic (first pass): new session-observed repro paths that aren't already in the upstream issue body; new reproduction environment that differs from the upstream issue's declared environment; new root-cause hypothesis that contradicts the upstream issue's current hypothesis. Stale evidence (same repro, same hypothesis) does NOT qualify.
- LLM comparator fallback: if the subagent is unavailable (e.g. rate-limit), halt and surface — do NOT proceed blind.



## Description

`/wr-itil:report-upstream` (P055 Part B, `@windyroad/itil@0.8.0`, ADR-024) currently proceeds from Step 4 (security-path routing) straight to Step 5 (public-issue path) or Step 6 (security path) with NO check for existing upstream issues. Two distinct duplication windows are exposed:

**(A) Own re-run duplication**: if the agent invokes the skill twice for the same local ticket (e.g. the first invocation was interrupted, or an AFK loop iterated on the same ticket, or the local ticket was re-evaluated after new evidence), the skill re-files a second upstream issue. ADR-024 explicitly scoped this out with a follow-up ticket note (lines 100 of ADR-024): *"Rate-limiting or deduplication on the upstream side — if the agent re-runs the skill for the same local ticket, it should detect the existing Reported Upstream section and offer to update rather than open a duplicate. Initial contract: error on re-run; follow-up ticket can add update-mode."* — but the skill doesn't even error on re-run today; it just silently fires a second `gh issue create`.

**(B) Third-party duplication**: if another reporter (or another agent in a parallel session) has already filed a similar issue against the upstream, the skill doesn't notice. Every invocation searches the upstream's `.github/ISSUE_TEMPLATE/` but never searches the upstream's existing `issues` list for overlap. Result: spammy duplicate tickets, upstream-maintainer annoyance, and a reputation cost that hits exactly the JTBD-004 outcome the skill is designed to protect.

Both windows are closed by the same architectural fix: a new Step 4b dedup check that runs after classification (Step 3) and security-path routing (Step 4) but before the `gh` call in Steps 5 / 6. The check has two branches (own re-run; third-party search) that share the same insertion point, prompt surface, and error path, which is why this is one ticket rather than two.

## Symptoms

- **Own re-run**: `grep -F 'Reported upstream' docs/problems/<NNN>-*.md` confirms a local ticket already has a `## Reported Upstream` section, but if the skill is re-invoked against the same upstream + ticket, a second issue is filed and the local ticket gains a second `Reported upstream:` line in `## Related`. Silent duplication.
- **Third-party duplication**: no `gh issue list --search` or equivalent is run. The skill proceeds with `gh issue create` regardless of whether the upstream has 47 existing issues whose titles or bodies match the local ticket's keywords.
- ADR-024 line 100 names the own-re-run case as "follow-up ticket" — this is that ticket (but scoped to cover the third-party case too, since both resolve at the same insertion point).
- The 9-assertion bats doc-lint test at `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` has no dedup assertions — nothing enforces the step's presence today.
- A Windy Road adopter exercising the skill for the first time in an AFK loop could plausibly file the same upstream issue 3-5 times before the loop hits another stop condition. Worst-case: an upstream maintainer blocks the reporter.

## Workaround

User manually greps the local ticket for `## Reported Upstream` before invoking the skill (or trusts the agent to remember across sessions, which is unreliable). For third-party dedup, user manually browses the upstream tracker before the agent fires — which defeats the skill's purpose.

## Impact Assessment

- **Who is affected**:
  - **Upstream maintainers receiving reports from this skill** — duplicate issues clutter their triage queues. Reputational cost rolls onto the Windy Road suite and the reporting downstream project.
  - **Downstream agents invoking the skill** — a second invocation that should have been a no-op (or an update-mode) instead creates noise. JTBD-004's "cross-repo coordination" outcome is undermined at exactly the point where coordination matters.
  - **Solo-developer persona (JTBD-001)** — the "without slowing down" promise fails when the user has to manually verify upstream trackers before invoking the skill.
  - **Plugin-developer persona (JTBD-101)** — the "clear pattern" promise fails when the pattern ships with a known duplication hole.
  - **Downstream adopters in AFK mode** — autonomous loops without dedup will replicate upstream reports every iteration. Worst-case disaster scenario.
- **Frequency**: Every re-invocation (own re-run) is a hit on branch A. Every invocation against a non-empty upstream tracker is a possible hit on branch B. Cumulative frequency scales with downstream adoption.
- **Severity**: Significant. Not a security leak (P064 covers that) nor a voice issue (P038/ADR-028) — a behaviour issue. Dupe issues are the most externally-visible failure mode of this skill.
- **Analytics**: N/A today. Post-fix, the Step 4b dedup branches can log "dedup skipped because match found" for audit.

## Root Cause Analysis

### Structural

ADR-024 drafted fast (2026-04-20, same day as P055 Part B implementation). The skill's first contract bet on "deliver the happy path and follow up on dedup"; line 100 of the ADR explicitly records this trade-off. The follow-up ticket was identified but not filed until now. Meanwhile the third-party-dedup case was simply unscoped — the ADR's "Out of scope" block covers own-re-run but not third-party search.

Both duplication windows resolve at the same architectural point: **between security-path routing (Step 4) and the outbound `gh` call (Steps 5 / 6)**. One Step 4b insertion covers both.

### Candidate fix

Insert a new Step 4b with two branches sharing the same `AskUserQuestion` surface:

**Step 4b.1 — Own re-run check:**
```bash
# Detect if the local ticket already has a `## Reported Upstream` section.
LOCAL_URL=$(grep -A5 '^## Reported Upstream' "$LOCAL_TICKET" | grep -oE 'https?://[^ )]+' | head -1)
if [ -n "$LOCAL_URL" ]; then
  echo "Local ticket already has ## Reported Upstream section: $LOCAL_URL"
  # AskUserQuestion options: (a) Update the existing upstream report (not yet implemented — halt), (b) File a new one anyway (override), (c) Cancel.
  # Non-interactive branch: halt with clear error message naming the existing URL.
fi
```

**Step 4b.2 — Third-party search:**
```bash
# Search upstream issues for likely duplicates.
KEYWORDS=$(extract_3-5_keywords_from "$LOCAL_TICKET_TITLE + $LOCAL_TICKET_DESCRIPTION")
MATCHES=$(gh issue list --repo "$UPSTREAM_OWNER_REPO" --search "$KEYWORDS in:title,body" --state all --json number,title,state,url --limit 10)
if [ "$(echo "$MATCHES" | jq length)" -gt 0 ]; then
  echo "Upstream has $(echo "$MATCHES" | jq length) potentially matching issues:"
  echo "$MATCHES" | jq -r '.[] | "- #\(.number) [\(.state)] \(.title) — \(.url)"'
  # AskUserQuestion options: (a) Comment on an existing issue instead (pass issue number to a new Step 5c "comment path"), (b) File a new issue anyway (explicit override — user has reviewed and judged them distinct), (c) Cancel.
  # Non-interactive branch: halt with the match list in the error.
fi
```

Both branches use `AskUserQuestion` per ADR-013 Rule 1 in interactive mode and halt-with-error in non-interactive / AFK mode per ADR-013 Rule 6. In AFK mode the halt is a loop-stopping event with the drafted report saved to the local ticket's `## Drafted Upstream Report` section (same pattern as the security-path halt per ADR-024 Consequences lines 116, 123) — matching the skill's existing halt-and-surface discipline.

**New Step 5c "comment path"** (if user picks option (a) on the third-party check): instead of `gh issue create`, run `gh issue comment <number>` with a condensed cross-reference body ("Seeing this too from <downstream-repo>/<local-ticket>; additional repro steps + context below"). The local ticket's `## Reported Upstream` section records the comment URL rather than an issue URL, with disclosure-path value `commented-on-existing-issue`.

### ADR amendments

Amend ADR-024 in two places:

1. Scope / "In scope" — add Step 4b dedup check to the Decision Outcome step list.
2. Scope / "Out of scope" line 100 — remove the own-re-run deferral (now in scope). Keep the third-party ADR language if we chose to add it in one amendment pass.

No new ADR required — this is an ADR-024 amendment because the ADR itself anticipated the follow-up.

### Investigation Tasks

- [ ] Confirm ADR-024 amendment path: edit in place (amendment) vs sibling ADR. Lean: amendment, since ADR-024 line 100 already names this as "follow-up".
- [ ] Draft the Step 4b branch A (own re-run) logic and the Step 4b branch B (third-party search) logic. Share the `AskUserQuestion` payload.
- [ ] Draft Step 5c (comment path) as a branch off the existing public-issue path.
- [ ] Decide keyword-extraction heuristic for third-party search: simple (title words minus stop-words) vs rich (summarise via LLM classifier). Lean: simple, with `--search` doing fuzzy matching. Rich extraction can ship as an enhancement.
- [ ] Add bats doc-lint assertions for: Step 4b presence, own-re-run detection language, third-party search language (`gh issue list --search`), Step 5c comment-path, AFK non-interactive halt-and-save behaviour.
- [ ] Update the skill's "AFK behaviour summary" table with the new dedup halt-and-surface branch.
- [ ] Cross-reference from the `## Reported Upstream` section shape: if Step 5c fires (comment path), the section records `Disclosure path: commented-on-existing-issue <URL>` rather than `public issue`.
- [ ] Exercise end-to-end: (1) open a local ticket, invoke the skill, verify it files upstream; (2) re-invoke the same skill for the same ticket, verify Step 4b.1 halts; (3) open a second local ticket whose keywords overlap with an existing upstream issue, invoke the skill, verify Step 4b.2 offers the comment path; (4) exercise the AFK halt-and-save branch.

## Related

- **ADR-024** — cross-project problem-reporting contract. Line 100 explicitly scoped dedup out with "follow-up ticket can add update-mode"; this is that ticket. Amendment rather than sibling ADR because the original contract anticipated the extension.
- **P055** — parent (closed); shipped the skill that this ticket extends.
- **P063** — manage-problem does not trigger report-upstream for external root cause. Tangential — both are skill-trigger gaps on the report-upstream surface.
- **P067** — report-upstream classifier problem-first. Shares the SKILL.md edit surface; bundle commits if they land in the same iteration.
- **ADR-013** — structured user interaction. Rule 1 governs the Step 4b AskUserQuestion; Rule 6 governs the AFK halt-and-save branch.
- **ADR-014** — governance skills commit their own work. Any local ticket edit (comment-path cross-reference, drafted-report save) follows the standard work → score → commit ordering.
- `packages/itil/skills/report-upstream/SKILL.md` — the SKILL.md gaining Step 4b + Step 5c.
- `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` — existing 9 assertions; gains 3-5 new dedup assertions.
- **JTBD-004** (Connect Agents Across Repos to Collaborate) — primary fit; dedup is the difference between "cross-repo coordination" and "cross-repo spam".
- **JTBD-001** (Enforce Governance Without Slowing Down) — dedup protects the user from having to police upstream duplicates.
- **JTBD-006** — AFK persona constraint; Step 4b's halt-and-surface branch protects AFK loops from duplicate-firing.

## Fix Released

Released in the same commit as this transition (AFK iter 2 of `/wr-itil:work-problems`, 2026-04-25). Awaiting user verification.

Fix summary:

- `packages/itil/skills/report-upstream/SKILL.md` — added Step 4b (dedup check, two branches: own re-run grep + third-party `gh issue list --search` with inline LLM semantic match per Direction decision 2026-04-21); added Step 5c (comment path — `gh issue comment <n>` with cross-reference body); extended Step 7 back-write disclosure-path enumeration with `commented-on-existing-issue`; updated AFK behaviour summary table with the dedup-halt branch (interim static heuristic — halt-and-save the drafted report; auto-comment branch deferred until `wr-risk-scorer:external-comms` lands per ADR-028 line 117).
- `docs/decisions/024-cross-project-problem-reporting-contract.proposed.md` — amendment 2026-04-25 documents Step 4b + Step 5c in the Decision Outcome step list, narrows the "Out of scope" dedup bullet to scope only the residual `update-mode` follow-up, and adds the new disclosure-path string + Confirmation criterion.
- `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` — 9 new assertions covering Step 4b presence, own-re-run language, third-party `gh issue list --search` language, inline LLM judgement (no subagent), Step 5c comment path, `commented-on-existing-issue` literal, AFK static heuristic, `## Drafted Upstream Report` save shape, AFK behaviour summary dedup-halt row.

Architect verdict (2026-04-25): the maintainer-annoyance risk evaluator named in the Direction decision was DEFERRED to compose with the `wr-risk-scorer:external-comms` subagent declared in ADR-028 (per ADR-028 line 117 — third-evaluator extension point). This kept the P070 fix at Effort M and avoided cross-cutting work that would block on P064 (open, WSJF 3.0, Effort L). The AFK auto-comment branch is on an interim static heuristic (always halt-and-save) until the evaluator ships; the bundling commit when ADR-028's evaluator lands will re-wire the AFK branch to the policy-authorised gate combination.

Verification path: a downstream invocation of `/wr-itil:report-upstream` should now (a) detect an existing `## Reported Upstream` section on a re-run and halt with the existing URL surfaced, (b) search the upstream's existing issues before firing `gh issue create`, and (c) in AFK mode, halt-and-save the drafted report to `## Drafted Upstream Report` rather than auto-comment.

Verification queue ranking: ranked by release age, oldest first. P070 is released 2026-04-25; user may verify on next interactive session by exercising the skill against a real upstream.
