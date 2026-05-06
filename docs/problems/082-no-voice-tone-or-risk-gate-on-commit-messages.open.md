# Problem 082: No voice-and-tone or content-risk-scoring gate on commit messages

**Status**: Open
**Reported**: 2026-04-21
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: XL <!-- transitive: XL via P038 (marginal: M) --> — transitive XL per P076 (`## Dependencies` → Blocked by P038 Open XL). Marginal-only work on top of P038 (voice-tone gate) + P064 (external-comms risk gate, now `.verifying.md` — contributes 0 per P076 carve-out) infrastructure: add `git commit` message-body interception to the same `PreToolUse:Bash` hook family, wire through the voice-tone rewrite skill (from P038) and the external-comms risk scorer (from P064). Commit messages are a NEW surface in the P038 / P064 / P073 surface-inventory family but the plumbing reuses their hook-and-skill pattern verbatim. Re-rate marginal back to S or M after P038 lands; transitive collapses to marginal once upstreams clear.

**WSJF**: 1.5 — (12 × 1.0) / 8 — Severity 12 (High); transitive Effort XL (divisor 8) via P038 per P076 — P082 cannot out-rank the upstream whose work is strictly contained within it. Sits alongside P038 / P073 in the 1.5 tier of the external-comms surface-completion cluster (P064 already verifying — contributes 0). Re-rates back to (12 × 1.0) / 2 = 6.0 once P038 lands and the marginal-only effort applies. Cluster is more valuable when all four land together than any one in isolation.
**Type**: technical

## Direction decision (2026-04-21, user — interactive AskUserQuestion post-AFK-iter-7)

**Plugin ownership** (per P015/P022/P078/P085 shared-architecture decision 2026-04-21): commit-message gate is split across `@windyroad/voice-tone` (voice concern — AI-sounding output, em-dashes, hedging) and `@windyroad/risk-scorer` (content-risk concern — leaking metrics, secrets, confidentials). NOT a shared `/wr-governance:output-gate` registry.

Implementation options for the dual-concern case (architect call at implementation):

- **Two hooks chained** (one per plugin) — voice-tone fires first on `PreToolUse:Bash` matching `git commit`, then risk-scorer. Each owns its own verdict. Simpler; potential order-dependence.
- **One hook in one plugin, calling the other via Agent tool** — e.g. voice-tone's hook invokes the risk-scorer pipeline subagent inline. Single invocation point; cross-plugin dependency.
- **Unified external-comms gate per ADR-028 amended** — ADR-028 already frames external-comms (GitHub issues, PRs, changesets) as a combined voice+risk surface. Extending ADR-028 to include commit messages is the cleanest architectural path. Lean toward this — commit messages ARE external-comms (reach every reader of git log, PR commits tab, CHANGELOG, npm readme).

Blocked on P038 (voice-tone gate on external comms) + P064 (risk-scoring gate on external comms) — both are the parent surface. P082 is marginal-only work on top of both. Per P076 transitive-dependency rule: if P038 or P064 have not landed, P082's WSJF drops.

## Pacing decision (2026-04-26 user direction — post-AFK-loop /wr-retrospective:run-retro AskUserQuestion)

**Wait for P038 to land first.** P064's risk-evaluator half shipped this session (commit `a0713f3`; changeset held in `docs/changesets-holding/` for dogfood per ADR-042 Rule 2). P038 is still Open. The user explicitly chose to wait rather than ship a marginal P082 now using existing risk-scorer infra alone. Rationale: P082 + P064 + P038 + P073 all compose at the `PreToolUse:Bash` matcher level once P038's voice-tone evaluator lands; shipping a marginal commit-message gate now would require a second iter to add voice-tone after P038 lands (effort double-spend) and would surface in npm releases as an incomplete feature. WSJF stays at 1.5 under the P076 transitive rule until P038 ships; AFK loops should skip P082 with `upstream-blocked` reason category citing P038 (and the README ranking should reflect WSJF 1.5 not 6.0 — re-rate at next `/wr-itil:review-problems` invocation).

## Description

User direction (2026-04-21 interactive, verbatim):

> there is no voice-and-tone review or content risk scoring review of commit messages

Commit messages populate multiple reader-facing surfaces:

1. **`git log`** — every contributor, every reviewer, every `git blame` follow-up reads this. In-repo but permanent.
2. **GitHub PR commits tab** — reviewers see commit titles and bodies on open PRs.
3. **GitHub release page body** — when a tagged release auto-generates release notes from commits since the last tag, commit messages become the release note body.
4. **CHANGELOG** — while changesets author the primary changelog text (scope of P073), individual commit summaries are referenced.
5. **`git shortlog` / contributor reports** — aggregated commit titles become part of the project's public history.

No gate intercepts `git commit -m "..."` today. The `packages/risk-scorer/hooks/risk-gate.sh` fires on commit-time for **changeset risk** (the state of the staged changes + unpushed queue), not the **message content**. The `packages/voice-tone/` plugin governs voice-and-tone for in-repo text but has no `PreToolUse` hook on `git commit` to enforce that governance at write time.

P038 (voice-tone external-comms gate) enumerates `gh issue comment`, `gh pr create`, `gh pr comment`, `npm publish` README diff, RapidAPI/marketplace — but NOT `git commit`. P064 (external-comms risk gate) enumerates the same surfaces — also NOT `git commit`. P073 (changeset authoring gate) extends P038/P064 to `.changeset/*.md` — not `git commit`. The commit-message surface is a distinct gap.

Commits authored this session (2026-04-21) include:
- `a0ec231` — 60+ line body with ADR citations and architecture rationale.
- `d8ab4c5` / `ffa85a7` / `91da109` — P071 slice commits with phased-landing notes.
- `6ed71dc` — P074 fix commit.
- `2ecb258` / `40335ab` — problem-ticket-creation commits with multi-paragraph bodies.

None were gated for voice-tone or risk content. No leak was observed (I reviewed each before committing), but the audit trail has no record of a check. If an agent (me) drafts a commit message with AI-tell patterns ("I've implemented...", "it seems..."), em-dashes at the wrong cadence, an accidental client name, or hedging language that violates the voice profile, the message ships to `git log` and every downstream surface with no pre-flight rewrite.

## Symptoms

- `git commit -m "..."` writes the message to `git log` with no voice-tone or risk check recorded.
- AI-tell patterns ("I've ...", "it seems", "I'd suggest") in commit bodies propagate to `git log`, PR commits tab, release-page auto-notes, and CHANGELOG references.
- Commit messages that reference unannounced features, client names, credentials, or other sensitive content slip through to `origin/main` without a risk-score recorded.
- The existing `packages/risk-scorer/hooks/risk-gate.sh` runs on every commit to score **changeset risk** (state of the staged changes) — it does NOT score **message content risk**. Two orthogonal risk axes, one gate, partial coverage.
- P038's claim that voice-tone plugin "govern[s] voice-and-tone only for in-repo text (READMEs, docs, commit messages)" is aspirational — the enforcement surface for commit messages is missing.
- Regression risk: commit messages authored by subagents (during AFK iterations) inherit no gate. The iteration subagent's own discipline is the only check.

## Workaround

Author reviews each commit message manually before running `git commit`. Fragile — the same "manually police AI output" pain P038 calls out for `gh issue comment` applies here verbatim. Particularly fragile during AFK loops where iteration subagents draft commit messages without user review.

## Impact Assessment

- **Who is affected**:
  - **solo-developer persona** (`JTBD-001` — enforce governance without slowing down) — commit message is the first surface where AI output escapes session context. Un-gated messages undermine the governance-without-slowing-down promise at the authorship boundary.
  - **plugin-developer persona** (`JTBD-101` — extend the suite with clear patterns) — downstream plugin authors copying this repo's commit conventions inherit the gap; their commit messages are also ungated.
  - **tech-lead persona** (`JTBD-201` — audit trail) — audit trail for external-visible text should cover every authored surface; commit messages are missed. "Every gate fired" claims are partial.
  - **every reader of `git log`** — contributors, reviewers, bisecters, release-note consumers. Reputation + confusion risk compounds.
- **Frequency**: every commit. This session: 6 commits, none gated.
- **Severity**: High. Surface is high-volume and high-visibility; gap is uniform across every invocation.
- **Analytics**: N/A today. Post-fix candidates: (1) commit-message-gate invocation count, (2) rewrite rate (what fraction of messages needed a rewrite — signal on AI-tell drift), (3) risk-above-appetite rate on commit-message-content scoring.

## Root Cause Analysis

### Structural

`packages/risk-scorer/hooks/` contains commit-time and push-time hooks focused on **changeset** risk (what's being committed / pushed), not **content** risk (what the message body says about the change). No sibling hook covers `PreToolUse:Bash` with a `git commit` command-line interception.

`packages/voice-tone/hooks/` contains edit-gate hooks that fire on `Write` / `Edit` of tracked files matching a voice-gated pattern. `git commit -m "..."` doesn't write a file the voice-tone edit-gate intercepts — the message goes into the commit metadata via `git commit -m` argument.

P038's "Enforcement surface" direction pin (2026-04-20): "PreToolUse hook intercepts `gh issue comment`, `gh pr create`, `gh pr comment`, `npm publish` (with README diff), and RapidAPI/marketplace update calls". `git commit` not named.

P064's surface inventory (inherited from P038 + the external-comms amendment to ADR-028): same inventory. Both tickets scope to "external" surfaces — commit messages are "in-repo" in a strict sense, even though they propagate externally.

### Candidate fix

**Option A: Extend P038 + P064 surface inventory to include `git commit -m`.**

Add a new row to both tickets' PreToolUse surface tables: intercept `Bash(git commit*)`, read the message body from `-m <msg>` arg OR from `.git/COMMIT_EDITMSG` (editor flow), run the voice-tone rewrite (P038) + content risk scorer (P064), block or rewrite as appropriate. P082 becomes a marginal surface-addition ticket dependent on P038 + P064 landing first (P076 transitive closure).

Pros: single authoritative surface inventory; no duplicate hook plumbing.
Cons: P082 can't ship independently; waits on P038 (XL) + P064 (L).

**Option B: Stand-alone commit-message gate as a sibling hook under `@windyroad/voice-tone` + `@windyroad/risk-scorer`.**

Ship P082's plumbing without waiting for P038 + P064. Intercept `Bash(git commit*)` directly, invoke a minimal voice-tone rewrite subagent + a minimal content-risk scorer subagent, block or rewrite. The subagents can later be consolidated with P038 + P064's fuller infrastructure as those tickets land.

Pros: ships now (no transitive-XL wait); delivers value on the most-frequent surface (every commit) first.
Cons: short-term parallel infrastructure; consolidation work later.

**Option C: Hybrid — extend ADR-028 External-comms gate to include commit messages as a fourth surface class.**

ADR-028 amended (this session) already groups voice-tone + risk gates for `gh` / `npm` / changeset surfaces. Add commit messages as a fourth surface class in the ADR-028 inventory; P082 becomes a surface-amendment ticket co-lining with P038 / P064 / P073 as part of a cluster release.

Pros: single ADR, single surface inventory, consistent architecture.
Cons: P082 still waits on P038 + P064 implementation even if the ADR is amended now.

### Lean direction

No direction pinned. Architect review at implementation time decides. Lean call (personal opinion, subject to architect revision): **Option B ship-now**, with follow-up ticket to consolidate into P038 + P064 infrastructure once those land. Every commit is ungated today; waiting for XL/L upstream tickets compounds the gap on a per-commit cadence.

### Related sub-concerns

**Sub-concern 1**: editor flow vs `-m` flow. `git commit` without `-m` opens an editor; the message is written to `.git/COMMIT_EDITMSG` and read back. The hook must handle both flows. Editor-flow is rarer in AI-driven commits (HEREDOC / `-m` dominates) but a generic gate should cover both.

**Sub-concern 2**: amend flow. `git commit --amend` rewrites the most-recent commit's message. The gate must fire on amend too — otherwise authors can bypass by amending after a gated commit lands.

**Sub-concern 3**: merge commit messages. `git merge` / `git rebase` auto-generate merge messages ("Merge pull request #XX"). Gate those? Architect review decides — probably skip for merge-autos unless the author edits.

**Sub-concern 4**: `git commit --no-verify`. Hooks bypass with `--no-verify`. The gate should honour that bypass per the repo's existing no-verify policy (ADR-013 Rule 6 escape hatch), but ensure the bypass is recorded in the audit trail so it's not silently invisible.

**Sub-concern 5**: AFK iteration subagents authoring commit messages. The iteration-worker subagent spawned per work-problems iteration (P077) drafts commit messages without user review. The gate must fire at the subagent's `git commit` too — which it will if the gate is a `PreToolUse:Bash` hook at the tool layer (fires regardless of which agent issued the command).

**Sub-concern 6**: cross-reference with P064's maintainer-annoyance evaluator (from P070). Commit messages likely need a different risk evaluator (content-leak / AI-tell / tone) rather than maintainer-annoyance. The risk-scorer surface is pluggable per-domain — architect review decides evaluator shape.

### Investigation Tasks

- [ ] Architect review: pick Option A / B / C. ADR shape (amend ADR-028 or add new sub-pattern).
- [ ] Enumerate every `git commit` invocation flow (`-m` / editor / `--amend` / `--no-verify` / merge-auto) + expected gate behaviour for each.
- [ ] Design the hook: `PreToolUse:Bash` pattern `git commit*`; parse message-body source; invoke voice-tone + risk subagents; approve / rewrite / block.
- [ ] Define the content-risk evaluator shape (distinct from maintainer-annoyance, release-risk, commit-changeset-risk — a fourth evaluator domain).
- [ ] Compose with existing `packages/risk-scorer/hooks/risk-gate.sh` — one hook calling both evaluators (changeset + content) or two hooks in sequence.
- [ ] Bats doc-lint assertions (behavioural where possible per P081): simulate a commit with AI-tell content; assert the hook fires + rewrites; assert a sensitive-content commit gets blocked + surfaces why.
- [ ] End-to-end test: author a real commit with a drafted message containing em-dashes + AI-tell patterns; confirm the gate rewrites before the commit lands.
- [ ] Audit trail integration: gate output lands in `.risk-reports/` alongside existing gate outputs; `run-retro` Step 2b (now shipped per P074) detects commit-message-gate-skipped-or-failed as a pipeline-instability signal.
- [ ] If P038 + P064 have landed by implementation time: collapse the stand-alone plumbing into their infrastructure. If not: ship stand-alone per Option B; consolidate later.
- [ ] Update the voice-tone plugin's SKILL.md / README to remove the aspirational "govern[s] commit messages" language until the gate actually fires.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: P038, P064
- **Composes with**: P073

P038 (Open, XL) propagates XL transitive effort per P076. P064 (`.verifying.md`) contributes 0 per the upstream-status carve-out — listed for traceability so the link survives if P064 ever flips back to `.known-error.md`. P073 shares surface (changeset authoring) but neither blocks the other — the gate-mechanism plumbing is shared but `.changeset/*.md` and `git commit -m "..."` are distinct write paths.

## Related

- **P038** (`docs/problems/038-no-voice-tone-gate-on-external-comms.open.md`) — voice-tone gate for external-comms. P082 extends its surface inventory to include commit messages (Option A) or parallels its pattern (Option B).
- **P064** (`docs/problems/064-no-risk-scoring-gate-on-external-comms.open.md`) — content risk gate for external-comms. P082 extends or parallels.
- **P073** (`docs/problems/073-no-voice-tone-or-risk-gate-on-changeset-authoring.open.md`) — same surface-completion cluster; covers `.changeset/*.md` bodies. P082 covers commit messages. Sibling concerns.
- **P070** (`docs/problems/070-report-upstream-does-not-check-for-existing-upstream-issues.open.md`) — maintainer-annoyance risk evaluator. P082's content-risk evaluator is a sibling evaluator domain.
- **P076** (`docs/problems/076-wsjf-does-not-model-transitive-dependencies.open.md`) — transitive-dependency rule used in this ticket's effort + WSJF re-rates.
- **P081** (`docs/problems/081-structural-content-tests-are-wasteful-tdd-agent-should-require-behavioural.open.md`) — tests for the new hook must be behavioural per this direction; don't ship structural-grep assertions on the hook script.
- **ADR-028** (`docs/decisions/028-external-comms-gate.proposed.md` — amended this session for external-comms cluster) — amendment target or sibling ADR for the commit-message surface class.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 6 non-interactive fail-safe for AFK iteration-subagent commit-message gates.
- **ADR-014** (`docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`) — skills that commit their own work (manage-problem, create-adr, run-retro, etc.) must pass through this new gate.
- **ADR-015** (`docs/decisions/015-on-demand-assessment-skills.proposed.md`) — risk-scorer subagent-type precedent; content-risk evaluator follows same pattern.
- `packages/risk-scorer/hooks/risk-gate.sh` — current commit-time hook (changeset-risk only); extension target for content-risk composition.
- `packages/voice-tone/hooks/` — current edit-gate hooks; no commit-time sibling exists yet.
- **JTBD-001**, **JTBD-101**, **JTBD-201** — personas whose "governance-without-slowing-down" + "audit trail complete" expectations this ticket serves.
