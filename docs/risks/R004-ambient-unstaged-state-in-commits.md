# R004: Ambient / unstaged state included in commits

A commit using `git add -A` / `git add .` (or a too-broad `git add <glob>`) captures session-ambient files that should have stayed local: `.claude/settings.json` modifications, `.afk-run-state/*.jsonl` queues, `/tmp/<session-marker>` artefacts, novel `.claude/.foo-marker` classes that haven't been added to `.gitignore` yet.

## Recogniser

**Path patterns** (any match → consider this entry):

- (state-shape, not path-shape) — applies whenever `git status` shows modified-not-staged or untracked files in:
  - `.claude/settings.json`, `.claude/settings.local.json`
  - `.afk-run-state/*`
  - `/tmp/*-announced-*`, `/tmp/manage-problem-grep-*`, `/tmp/claude-risk-*`
  - `.claude/.intake-scaffold-*`, `.claude/.install-updates-consent`
  - `.claude/projects/*/memory/*.md`

**Diff-content keywords** (any match → consider):

- `git add -A`, `git add .`, `git add docs/` (broad globs)
- (Bash command does NOT name specific paths)

**Anti-patterns** (looks like R004 but isn't):

- Authoring a deliberately-fake credential in a test fixture → score as **R008** with bypass rationale, not R004.
- A commit explicitly intended to update `.gitignore` (covering a new ambient class) — that's a fix, not the risk.

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | **primary** | Risk surfaces when `git add` runs |
| push | yes | If pushed, ambient state reaches public-repo history |
| release | yes | cumulative |
| external-comms | no | not an outbound-prose class |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 2 (Minor) — typically recoverable in-session via `git reset` / `git revert`; bounded post-push for typical class.
- **Likelihood**: 3 (Possible) — ambient state is in `git status` every session; one bulk-stage away.
- **Inherent score**: 6
- **Inherent band**: Medium

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| `.gitignore` filesystem-level exclusion | Ambient class is in the ignore list (known classes only) | 1 | -1 likelihood | Bump +1 (novel class not yet ignored) |
| `git add <specific-paths>` discipline (codified in many SKILL.md flows) | Bash command names specific paths instead of `-A` / `.` | 2 | -1 likelihood | Bump +1 (bulk-stage at risk) |
| CLAUDE.md P131 "never write project-generated artefacts under `.claude/`" | Always (declarative) | n/a (written policy) | 0 paths | Lower author-mindfulness |
| gitStatus visibility per-prompt | Always (system-reminder shows gitStatus snapshot at each turn) | n/a (declarative; advisory) | 0 paths | Lower author-mindfulness |

Lifetime residual likelihood = 1 (Rare; floor).

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| Bash command uses `git add -A` or `git add .` | +1 | Bulk-stage subverts specific-paths discipline |
| Bash command uses `git add <glob>` covering an ambient-class directory (e.g., `git add .claude/`) | +2 | Almost-certainly captures ambient state |
| `git status` (per system-reminder) shows untracked / modified ambient files NOT in `.gitignore` | +1 | Novel class; gitignore not yet covering |
| Commit message naming an ambient-class concern (auto-staging the very file the ticket references) | +1 | False-positive sub-class — meta-trap |
| Bash command is `git add <single-path>` for a non-ambient file | -1 | Specific staging eliminates the bulk-stage failure mode |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 1 (Rare) — gitignore + specific-paths discipline + gitStatus visibility stack to capped reduction.
- **Residual score**: 2
- **Residual band**: Very Low — below appetite.

**Below appetite**. Could push lower with a PreToolUse:Bash hook on `git add -A` / `git add .` requiring explicit acknowledgement, but cost-benefit doesn't currently warrant it (no observed instance reaching adopter exposure).

## Watch-out

- Throughout typical sessions, `.claude/settings.json` is persistently modified-not-staged — discipline alone prevents accidental inclusion.
- New plugin features can introduce new ambient classes (markers, queues, caches) that aren't in `.gitignore` until someone notices. Lag window: days-to-weeks.
- False-positive sub-class: agent annotates a ticket about an ambient class, then auto-stages the very ambient file the ticket references. Always re-check `git status` before bulk staging.
- Pre-existing test failures showing up in `git status` are an "ambient broken state" sub-class — they can leak into commits as if the commit fixed them.

## See also

- **Sibling**: R008 (credentials in committed files) — settings.json with API key fragments escalates to R008 territory.
- **Generalisation**: R009 (functional defects) — when ambient state IS a defect's evidence (e.g., ambient broken bats failing).
- **Drivers / ADRs**: CLAUDE.md P131, ADR-058 (plugin maturity NDJSON pattern), ADR-049 (plugin-bundled scripts via $PATH bin).
