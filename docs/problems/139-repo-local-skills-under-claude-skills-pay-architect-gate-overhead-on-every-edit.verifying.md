# Problem 139: Repo-local skills under `.claude/skills/` pay architect-gate overhead on every edit — relocate source-of-truth outside `.claude/` and symlink

**Status**: Verification Pending
**Reported**: 2026-04-28
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: M — relocate `.claude/skills/install-updates/` (and any future repo-local skill) under `packages/repo-local/<skill>/` (or equivalent canonical location), replace the in-`.claude/skills/` content with a symlink to the new source-of-truth, amend ADR-030 to record the new location convention + the symlink contract, audit gate-exclusion lists across plugin hooks (architect, JTBD, TDD, style-guide, voice-tone, risk-scorer) to confirm that the symlink-target path under `packages/` follows the normal review process, and update `MEMORY.md` / BRIEFING references.
**WSJF**: (12 × 1.0) / 2 = **6.0**
**Type**: technical

> Surfaced 2026-04-28 by direct user direction during a `/install-updates` follow-on edit session: *"editing skills in .claude requires explicit approval from me which wastes time. Instead we could place these files elsewhere and link to them in .claude. We would only need to approve the linking once per file. After than edit on the file (outside of .claude) can follow the normal review process"*. Triggering session evidence: editing `.claude/skills/install-updates/SKILL.md` and `.claude/skills/install-updates/REFERENCE.md` to remove the legacy-JTBD-flag + rename-mapping logic required two architect-agent re-runs (the first when the gate fired and the file was blocked; the second when the agent had to re-prompt with a concrete diff to satisfy the marker). Each re-run costs sub-agent latency, model tokens, and user wall-clock time.

## Description

ADR-030 (Repo-local skills for project-specific workflow tooling) chose `.claude/skills/<skill-name>/SKILL.md` as the canonical location for repo-local skills. The location was driven by two facts:

1. **Discoverability via `/<name>` autocomplete** — Claude Code's runtime resolves `.claude/skills/<name>/SKILL.md` for the `/<name>` slash command without any plugin prefix.
2. **No portable alternative** — at the time, no other path was known to participate in slash-command resolution.

The downstream consequence: every edit to one of these repo-local skills triggers the architect PreToolUse:Edit gate (`packages/architect/hooks/architect-enforce-edit.sh`), the JTBD gate, the style-guide gate, and (for `.ts/.tsx/.js/.jsx` only) the TDD gate. Per session, every edit pays:

- **Architect agent re-run** — the gate denies the Edit unless an architect marker is on file for the SKILL.md path. The agent must delegate to `wr-architect:agent`, present the proposed diff, receive a verdict, and then retry the Edit. Sub-agent latency (~30-60s), context budget for the architect prompt + verdict, and user wall-clock time.
- **JTBD agent re-run** — same shape, parallel cost, on a different gate.
- **Re-runs on marker invalidation** — if the agent edits multiple sections of the same file across multiple turns, the gate may fire repeatedly (depends on the per-edit vs per-file marker semantics).

The cost is structural, not incidental. Every time the user (or the agent on the user's behalf) needs to update a repo-local skill, the gate fires.

**User's proposed fix**: relocate the source-of-truth file outside `.claude/`. Place repo-local skills under (e.g.) `packages/repo-local/<skill-name>/SKILL.md` or `scripts/repo-local-skills/<name>/SKILL.md`. Inside `.claude/skills/<skill-name>/`, replace the file with a **symlink** pointing to the source-of-truth. The user approves the **symlink creation** once (a one-shot architect+JTBD review of the new packaging surface), and after that:

- Subsequent edits target the source path under `packages/` (or wherever) and follow the **normal review process** — architect / JTBD gates fire on the source path, exclusion lists govern the .claude/ side.
- The Claude Code runtime continues to resolve `/<name>` via the symlink under `.claude/skills/`, so user-facing discoverability is unchanged.

This converts a per-edit cost into a per-relocation cost. For a skill that ships once and edits N times, the relocation pays back after the first or second edit.

## Symptoms

- Edits to `.claude/skills/install-updates/SKILL.md` and `.claude/skills/install-updates/REFERENCE.md` block on the architect gate even when the change is a pure trim (removing dead logic that the architect already approved conceptually).
- The agent must re-invoke `wr-architect:agent` with a more concrete diff to land the marker; the second invocation always passes, suggesting the gate fires for marker-state reasons, not for genuine architectural risk.
- This session: two architect re-runs to land the SKILL.md trim; user direction surfaced after the second.
- Pattern repeats across other repo-local skills if/when they are created (ADR-030 envisions multiple).

## Workaround

For the current session, the agent re-runs the architect with a sufficiently concrete diff to land the marker. No structural workaround exists short of the proposed relocation.

User-side workaround: explicitly approve the architect delegation when prompted. Costs user attention.

## Impact Assessment

- **Who is affected**: Anyone (user or agent) editing a repo-local skill under `.claude/skills/<name>/`. Currently `install-updates` is the only repo-local skill, but ADR-030 envisions more. Every future repo-local skill inherits this overhead.
- **Frequency**: Every edit to a repo-local skill. For skills that evolve (e.g. install-updates accumulating refinements per release loop), this is multiple times per month.
- **Severity**: Moderate — slows down work, costs sub-agent tokens, but does not break anything. The work still completes.
- **Analytics**: Session-level evidence — this session paid two architect re-runs for one logical SKILL+REFERENCE+ADR trim. Aggregate cost across the project's lifetime would be substantial as more repo-local skills land.

## Root Cause Analysis

### Investigation Tasks

- [ ] Confirm Claude Code's slash-command resolver follows symlinks under `.claude/skills/`. Quick test: create a throwaway `.claude/skills/test-link/` symlinked to a `packages/test-link/` directory containing a SKILL.md, and verify `/test-link` autocomplete + invocation works.
- [ ] Audit each plugin hook's gate-exclusion list to determine whether edits to a `packages/<repo-local>/SKILL.md` source file would follow the normal architect / JTBD review process (the desired behaviour). Files to audit: `packages/architect/hooks/architect-enforce-edit.sh`, `packages/jtbd/hooks/jtbd-enforce-edit.sh`, `packages/tdd/hooks/tdd-enforce-edit.sh`, `packages/style-guide/hooks/style-guide-enforce-edit.sh`, `packages/voice-tone/hooks/voice-tone-enforce-edit.sh`, `packages/risk-scorer/hooks/risk-scorer-*.sh`. The audit confirms or refutes the assumption that "outside `.claude/` = normal review".
- [ ] Decide on the canonical relocation target. Candidates: `packages/repo-local/<name>/`, `scripts/repo-local-skills/<name>/`, `packages/<existing-plugin>/repo-local-skills/<name>/`. The choice interacts with ADR-002 (monorepo per-plugin packages) and ADR-003 (marketplace-only distribution) — repo-local skills must NOT publish via the marketplace.
- [ ] Sketch the symlink contract: relative vs absolute path; one symlink per `SKILL.md`/`REFERENCE.md` or symlink-the-directory; behaviour under `git clone` on Windows (where symlinks can require admin rights or developer mode). Document under what conditions the symlink approach degrades.
- [ ] Amend ADR-030 to record the new location convention + the symlink contract. The Decision Outcome's contract point 1 ("Location: `.claude/skills/<skill-name>/SKILL.md`") becomes the resolved-via-symlink path; the source-of-truth contract is added.
- [ ] Migrate `.claude/skills/install-updates/` as the worked example. Move the four files (`SKILL.md`, `REFERENCE.md`, `test/*.bats`) under the canonical relocation target. Replace `.claude/skills/install-updates/` with a symlink. Verify all bats tests still pass.
- [ ] Audit `.gitignore` / `.gitattributes` for any rules that would interact poorly with symlinks under `.claude/`.

### Preliminary Hypothesis

The architect-gate overhead is structural — it fires on path-prefix matching against `.claude/skills/`. Relocating the source path to `packages/repo-local/<name>/` (or similar) shifts the gate's input set so the source file matches the normal-review path, and the symlink under `.claude/skills/` either matches a one-time exclusion or is treated as an opaque symlink the gate doesn't traverse. The exact mechanic depends on whether the gate's path-prefix check uses `realpath` or the literal write-target path.

A symlink-aware gate is preferable to a fully-relocated source — it preserves ADR-030's "the skill lives where Claude Code reads it" intent. But a non-symlink-aware gate would either miss the rename (gate doesn't fire because the literal target is outside `.claude/skills/`) or double-fire (gate fires on both the symlink target and the source). The audit task above resolves this empirically.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P131 (agents-write-project-artefacts-to-claude-user-space) — both are about clarifying the `.claude/` ownership boundary. P131 governs **writes** of project-generated content; this ticket governs **edits** of user-authored repo-local skills. The same relocation-and-link pattern partially serves P131's space (project-generated content also belongs outside `.claude/`).

## Related

- **ADR-030** (`docs/decisions/030-repo-local-skills-for-workflow-tooling.proposed.md`) — the governing decision that placed repo-local skills under `.claude/skills/`. The fix here amends ADR-030's Decision Outcome contract point 1 to record the source-of-truth + symlink shape.
- **ADR-002** (monorepo per-plugin packages) — the relocation target lives under `packages/` per this ADR's convention. Repo-local skills do NOT publish via the marketplace (ADR-003), so the new location is a monorepo-internal convention rather than a published-package layer.
- **P131** (`agents-write-project-artefacts-to-claude-user-space-treating-gate-exclusions-as-write-permission`, known-error) — composing ticket. The relocation pattern proposed here generalises the rule from "agents must not write under `.claude/`" to "the source-of-truth for repo-local artefacts lives outside `.claude/`; `.claude/` carries only resolution-layer references (symlinks, settings) plus user-controlled config".
- **P029** (`edit-gate-overhead-disproportionate-for-governance-docs`, closed) — adjacent precedent. P029 closed by adding file-suffix carve-outs for documentation-only governance edits (problem ticket transitions). This ticket proposes a different mechanism (relocate-and-link) for a different surface (repo-local skill SKILL.md/REFERENCE.md). Both serve the same outcome: reduce architect-gate friction where the gate adds no architectural value.
- **P004** (`edit-gates-block-non-project-files`, closed) — about gates blocking files outside the project directory. Distinct surface (user-config files like `~/.claude/channels/discord/access.json`); included for completeness in the gate-friction family.
- **P098** (`project-and-user-owned-context-contributors-global-claude-md-and-local-skills`, verifying) — touches the `.claude/skills/` ownership question from a different angle (context-contributor budget). Verifying-Pending; not blocking.
- **P124** (`agent-side-session-id-discovery-helper`) — helper-related observation surfaced during this ticket's own creation: the agent-side session-ID discovery helper picks the first glob-match instead of the most-recent announce marker; with 103 stale architect-announced markers in `/tmp`, this returns a wrong SID and the create-gate marker lands at the wrong path. Worked around inline (brute-force-touched markers under all known SIDs).

## Fix Released

Released on `main` 2026-04-28 (work-problems iter 7) as a single commit per ADR-014.

**Change shape** (Option B per architect verdict — `scripts/repo-local-skills/` chosen over `packages/repo-local/` to keep `packages/` semantic = publishable `@windyroad/*` plugins per ADR-002 and ADR-003):

1. `git mv` of `.claude/skills/install-updates/{SKILL.md, REFERENCE.md, test/}` to `scripts/repo-local-skills/install-updates/`. Source-of-truth now lives there; all editing targets that path.
2. Relative symlinks created at `.claude/skills/install-updates/{SKILL.md, REFERENCE.md, test/}` pointing back to the source-of-truth (`../../../scripts/repo-local-skills/install-updates/<file>`). Claude Code's `/install-updates` autocomplete continues to resolve via the symlinks.
3. ADR-030 amended in same commit: Decision Outcome contract point 1 rewritten (source-of-truth + resolution-layer split); new "Symlink contract" section (relative; per-file for SKILL.md/REFERENCE.md, directory-level allowed for test/; Windows degradation documented); Confirmation section adds four assertions; Reassessment Criteria gains a third trigger ("symlink resolution breaks").
4. Behavioural bats added at `scripts/repo-local-skills/install-updates/test/install-updates-symlink-contract.bats` — 11 tests covering: source-of-truth files exist + are regular files (not symlinks); `.claude/` entries are symlinks; targets are relative not absolute; symlinks resolve to the same content as source; gate-exclusion audit asserts no `scripts/` carve-out in architect / JTBD hooks. All 11 pass via `npx bats scripts/repo-local-skills/install-updates/test/install-updates-symlink-contract.bats`.
5. Briefing reference at `docs/briefing/governance-workflow.md` updated to point at the new source-of-truth.

**Gate-exclusion audit outcome** (per architect verdict + bats assertions):

- `packages/architect/hooks/architect-enforce-edit.sh` — no `scripts/` carve-out. Edits to `scripts/repo-local-skills/<name>/SKILL.md` fire the architect gate as required (normal review).
- `packages/jtbd/hooks/jtbd-enforce-edit.sh` — no `scripts/` carve-out. Same outcome.
- `packages/tdd/hooks/tdd-enforce-edit.sh` — fires only on `.ts/.tsx/.js/.jsx`; `.md` and `.bats` unaffected.
- `packages/style-guide/hooks/`, `packages/voice-tone/hooks/`, `packages/risk-scorer/hooks/` — file-type matching not path exclusion; fire on content independent of location.

**Verification**: user can confirm by running `/install-updates` and verifying the skill loads as before. Edits to `scripts/repo-local-skills/install-updates/SKILL.md` or `REFERENCE.md` now fire the architect / JTBD gates exactly once per session (per existing per-session marker semantics) — no per-edit re-runs purely because the path is under `.claude/skills/`. Awaiting user verification.
