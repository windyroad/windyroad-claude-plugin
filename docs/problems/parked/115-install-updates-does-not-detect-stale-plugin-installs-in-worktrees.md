# Problem 115: `/install-updates` does not detect stale plugin installs pinned to git worktrees under the current project

**Status**: Parked
**Reported**: 2026-04-24
**Priority**: 6 (Med) — Impact: Moderate (3) x Likelihood: Possible (2)
**Effort**: M
**WSJF**: 0 (parked — excluded from ranking per ADR-022 / Parked policy)

## Parked

**Reason**: User direction 2026-04-26: *"we don't use worktrees here"* (twice — strong signal). The 2026-04-24 P113 incident that surfaced this ticket was a one-off stale install in `.claude/worktrees/upbeat-keller`, manually cleaned up at the time. The project's actual workflow does not use git worktrees, so the systemic install-updates worktree-discovery gap does not manifest in steady-state usage here.

**Trigger to un-park**: any of —
- The project's workflow adopts git worktrees as a regular pattern (e.g., feature-branch isolation via `git worktree add`).
- A downstream adopter of `@windyroad/itil` reports the same gap on their installation (cross-adopter signal that the systemic concern is real for users beyond this project).
- The `claude-code worktree create` tool becomes part of this project's AFK orchestrator pattern (would re-introduce the orphaned-worktree class).

**Date parked**: 2026-04-26.

**Workaround captured (per-machine, ad-hoc)**: documented in this ticket's Workaround section below — `(cd .claude/worktrees/<name> && claude plugin uninstall "<plugin>@windyroad" --scope project)` plus restart. Adopters who hit this on their installation can apply the workaround without waiting for the parked fix.

> Surfaced during P113 (report-upstream autocomplete missing) investigation on 2026-04-24. The shipped `Skill, Agent` frontmatter fix failed to resolve the user-facing symptom because the real RCA was a stale `wr-itil@0.1.0` install pinned to `.claude/worktrees/upbeat-keller` — an orphaned git worktree inside the current project that `/install-updates` Step 3 never scanned.

## Description

`/install-updates`'s sibling-discovery loop at Step 3 walks only `../*/` — parent-relative siblings. It does not descend into `.claude/worktrees/*` under the current project, nor does it inspect `git worktree list` output. If the user has abandoned a git worktree that had `wr-*@windyroad` plugins installed (project-scope) at a time when those plugins were older (e.g. `0.1.0`), the stale install persists in `~/.claude/plugins/installed_plugins.json` indefinitely.

Claude Code's TUI autocomplete appears to read the **first matching entry** in `installed_plugins.json` when enumerating skills for a plugin namespace. When a stale older-version entry is present, it takes precedence over the newer project-root install even if the outer install is listed second — silently producing a wrong skill list for TUI autocomplete. The agent-side skill enumerator walks a different code path that takes the union across versions; hence skills appear available from the agent side but invisible in autocomplete.

Result: the "fresh install" contract of `/install-updates` is broken for projects that use git worktrees.

## Symptoms

- `claude plugin list` shows multiple `wr-<name>@windyroad` rows for the same project tree at different versions; the older version is listed first.
- A skill that exists in the newer version but not in the older version is missing from TUI slash-command autocomplete, even though the skill appears in the agent-side available-skills list.
- Running `/install-updates` reports "nothing to update" for the affected plugin because the worktree install path is never discovered as a project to install into.
- Older cache directories under `~/.claude/plugins/cache/windyroad/<plugin>/<old-version>/` persist as "enabled" in `installed_plugins.json` long after the outer project has moved to a new version.

## Workaround

Per-machine manual cleanup:
```bash
(cd <project>/.claude/worktrees/<name> && claude plugin uninstall "<plugin>@windyroad" --scope project)
```
Then restart Claude Code. This removes the stale row from `installed_plugins.json` and drops the enabled flag from the worktree's local `.claude/settings.json`.

For wholesale cleanup on a project with many abandoned worktrees, `git worktree list` lists them; iterate and uninstall each `wr-*@windyroad` plugin with `--scope project` inside the worktree.

## Impact Assessment

- **Who is affected**: any adopter who uses git worktrees within a project that enables `@windyroad/*` plugins and then orphans the worktree (common when using AI-assisted tool that creates worktrees for isolation — e.g., `claude-code worktree create`).
- **Frequency**: once per abandoned worktree. Rises with AI-tool usage that scaffolds worktrees automatically.
- **Severity**: Moderate. The symptom presents as a missing slash-command — not a crash, but confusing and hard to diagnose (the user saw only "my autocomplete is broken"; it took a two-layer investigation to trace to the worktree install). Adopters are likely to misattribute to their own plugin or to Claude Code and file the wrong bug report.
- **Analytics**: N/A — per-machine registry state.

## Root Cause Analysis

### Confirmed root cause (from P113 investigation)

1. `/install-updates` Step 3 discovery uses `for d in ../*/; do ... done` — parent-siblings only. It does not:
   - Read `git worktree list` output to enumerate worktrees under the current project
   - Descend into `.claude/worktrees/*/` nor any other worktree location
2. Claude Code's `installed_plugins.json` treats each worktree's `.claude/settings.json` as an independent project scope. A worktree install captured at plugin version N persists indefinitely if the worktree is not explicitly cleaned up.
3. TUI slash-command autocomplete appears to select the first matching project-scope install from `installed_plugins.json` when enumerating skills, producing the stale version's skill list. Agent-side skill enumeration uses a different code path (union across versions) — hence the agent sees the full list while the TUI does not.

### Investigation Tasks

- [x] Confirm the stale-worktree-install mechanism on this machine (P113 investigation — done).
- [ ] Decide the install-updates contract for worktrees: (a) auto-scan all worktrees discovered via `git worktree list` in the current project — symmetric with sibling scanning; (b) scan but ask per-worktree (consent granularity); (c) leave worktrees out of scope and document the workaround in REFERENCE.md only; (d) add a diagnostic sub-command (e.g. `/install-updates --diagnose`) that surfaces stale installs without touching them.
- [ ] Architect decision needed on the consent-gate contract under ADR-030: should worktree installs follow the same `AskUserQuestion` consent pattern as siblings, or does the "same project" relation grant implicit authorisation to touch them?
- [ ] Prototype the `git worktree list` discovery and integrate into Step 3 if option (a) / (b) is chosen.
- [ ] Add a bats test that simulates a stale worktree install and verifies `/install-updates` detects + cleans it (RED first).
- [ ] Update REFERENCE.md with the rationale and any new scope boundary.

### Fix Strategy

**Shape**: investigate-then-decide — three distinct contract shapes are plausible (broad auto-scan, consent-gated scan, diagnostic-only). Scope and UX differ significantly between them. ADR is likely warranted if we land anything beyond the diagnostic-only option.

**Target files (likely)**: `.claude/skills/install-updates/SKILL.md` (Step 3 discovery + Step 6 consent gate + Step 7 install loop), `.claude/skills/install-updates/REFERENCE.md` (rationale), a new bats test, possibly a new ADR under `docs/decisions/`.

**Deferred question**: the symmetric gap for multi-root workspaces (a single VS Code window with multiple folder roots). If those also accumulate stale installs, the discovery surface broadens further. Capture once the worktree variant is landed.

## Dependencies

- **Blocks**: per-adopter recurrence of the P113-class "fresh install didn't land" symptom. P113 itself was un-blocked by a per-machine workaround.
- **Blocked by**: architect decision on the worktree-install contract.
- **Composes with**: P106 (install-updates Step 7 uninstall-before-install — the related but distinct bug where updates silently no-op without a prior uninstall). P115's scope is one layer up: even perfect uninstall-before-install can't fix installs in paths the discovery step never visits.

## Related

- **P113** (`docs/problems/113-wr-itil-report-upstream-missing-from-slash-command-autocomplete.verifying.md`) — driver; surfaced the worktree-install mechanism.
- **P106** (install-updates Step 7 silent-noop fix, Fix Released) — adjacent install-updates correctness issue; same skill but different layer.
- **P045** — auto plugin install after governance release. Long-term, the worktree gap would also affect any automated install pipeline built on top of `/install-updates`.
- **P059 / ADR-030 amendment** — rename-mapping authority; the auto-migration flow has similar "reach into a project's settings" semantics that might need symmetric treatment for worktrees.
- **ADR-030** — repo-local skills; governs the consent model the install-updates skill must satisfy.
- **ADR-004** — project-scope only. Worktrees inherit project-scope semantics, so the contract applies transitively.
