---
status: "proposed"
date: 2026-05-04
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, plugin-developer persona, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-08-04
---

# `@windyroad/*` plugin maturity measurement mechanism — session-transcript invocation counts plus commit-history composite, read-only NDJSON

## Context and Problem Statement

ADR-053 (Phase 1) pinned the five-band maturity taxonomy (Experimental / Alpha / Beta / Stable / Deprecated), the dual-location signal (canonical `plugin.json` `maturity:` field + rendered README header badge), and the abstract promotion/demotion criteria stated in objective-signal-shaped terms (days-shipped, invocation count, closed problem-ticket count, breaking-change-free window). Phase 1 deferred the concrete sources to Phase 2 — what to measure was named in abstract, but how to measure it was left to be pinned with prototype-confirmation rather than ahead-of-the-data guessing.

P087's "Direction decision (2026-04-21)" already records the user-approved approach: combine `/insights` (existing Claude Code command, orthogonal session-friction signal), a session-transcript parser (new skill that reads `~/.claude/projects/*/sessions/*.jsonl`), and a commit-history heuristic. Phase 2 prototyping (P087 Investigation Tasks 3 and 4) ran on 2026-05-03 against this session's history — 4480 sessions in the thirty-day window, thirteen plugins discovered. The prototype confirmed signal fidelity: `wr-architect:agent` (796 invocations / 30d), `wr-jtbd:agent` (638), `wr-risk-scorer:pipeline` (1147) sit at the top, while the `mitigate-incident`, `restore-incident`, `close-incident`, and `link-incident` skills (split out of `manage-incident` in `@windyroad/itil@0.15.0`) score zero invocations and do not appear in the top forty. The user's framing in P087 ("`mitigate-incident` has never been used in anger") is empirically validated by the transcript count.

Phase 2 takes the prototyped sources and pins them as the canonical measurement mechanism: which scripts ship, where they ship, what they emit, what privacy posture they adopt, what the band-mapping is during the bootstrapping window (per ADR-053 amendment), and what the Phase 4+ escalation gate's numeric criterion is.

This ADR is the second phase of a three-phase declarative-first cluster rollout (ADR-057 §"Necessary conditions" — the "all `@windyroad/*` plugin surfaces" class membership, ≥50 surfaces at codification time, NDJSON-line-per-surface countable drift). Phase 2 is descriptive and exit-0-always per ADR-013 Rule 6 fail-safe + ADR-040 declarative-first. Phase 3 (separate ADR / iter) reads Phase 2's NDJSON and writes the canonical `plugin.json` `maturity:` field + renders README badges. Phase 4+ escalates to a release-blocking gate iff drift accumulates per the (N, M) criterion this ADR pins.

## Decision Drivers

- **JTBD-101 (Extend the Suite with New Plugins) — primary driver, Phase 2-active**. JTBD-101's desired-outcome list was extended on 2026-05-04 with a hardening-prioritisation outcome: *"I can see which of my plugin's surfaces (skills, agents, hooks) are most and least exercised in real-world use, so I know where to invest hardening effort versus where the surface is so well-trodden that the marginal-test ROI is low."* Phase 2's NDJSON output is the literal data source for that outcome; the plugin-developer persona is the primary Phase 2 consumer (Phase 3 broadens the audience to the plugin-user persona via README badge rendering).
- **JTBD-201 (Restore Service Fast with an Audit Trail) — secondary driver, Phase 2-active**. Tech-lead persona's audit-trail constraint composes with per-surface invocation visibility: an audit reviewing whether a guardrail fired the correct number of times needs the per-surface count, not just aggregate trust signal.
- **JTBD-007 (Keep Plugins Current Across Projects) — secondary driver, Phase 2-active**. The bootstrapping clause's auto-lapse mechanism (ADR-053 §Bootstrapping clause) is a temporal-currency property — currency-pressure axis composes with measurement-tooling output.
- **JTBD-302 (Trust That the README Describes the Plugin I Just Installed) — terminal driver, Phase 3-active only**. JTBD-302's desired-outcomes are README-narrative-anchored; Phase 2's NDJSON-to-stdout posture is operator-side and adopter-invisible. JTBD-302 reactivates in Phase 3 when the rendered README badge surfaces the band designation. Phase 2 prepares JTBD-302 satisfaction; Phase 2 does not deliver it.
- **JTBD-003 (Compose Only the Guardrails I Need) — composition driver**. Composers reading Phase 3 badges (downstream of Phase 2 NDJSON) get an objective per-surface signal; the bootstrapping clause's compound rendering ("Experimental (suite-bootstrap window; 796 invocations / 30d)") preserves the per-surface composition signal during the bootstrapping window.
- **ADR-053 §Bootstrapping clause (binding contract)**: the band-admission rule during the bootstrapping window is fully specified in ADR-053. Phase 2 implements the contract; it does NOT amend or extend the contract. Implementation owns code; Phase 1 owns semantics.
- **ADR-049 §Naming convention (binding grammar)**: every Phase 2 script ships as a thin shim under `packages/<plugin>/bin/wr-<plugin>-<kebab-script-name>` whose body is `exec "$(dirname "$0")/../scripts/<name>.sh" "$@"`. Canonical script body lives under `packages/<plugin>/scripts/<name>.sh` for ergonomics + bats testability.
- **ADR-013 Rule 6 fail-safe (binding posture)**: Phase 2 scripts emit `exit 0` always. Inaccessible-data conditions (missing `~/.claude/projects/`, missing `git`, opt-out marker present) emit zero NDJSON lines and exit 0; they do NOT exit non-zero or block any caller. Phase 2 cannot block any pipeline — promotion to a release-blocking gate is Phase 4+ scope conditional on the (N, M) criterion pinned below.
- **ADR-035 §"Privacy and consent" (binding privacy contract)**: the transcript parser reads `~/.claude/projects/*/sessions/*.jsonl` — host-local, project-private content. Phase 2 adopts ADR-035's clauses verbatim: opt-out marker convention, no exfiltration, content-sanitisation, path-hashing, no-network-primitive bats assertion. ADR-035 is policy-anchored rather than JTBD-anchored because no JTBD declares zero-ceremony privacy as a primary outcome (acknowledged gap; not papered over).
- **ADR-043 §"memory bucket" (read-only-script precedent)**: ADR-043 establishes the precedent of a read-only diagnostic script reading `~/.claude/projects/*/memory/*.md` with explicit ungrounded-when-inaccessible behaviour. Phase 2's transcript parser is the natural sibling reading from a different sub-tree under the same parent root with the same posture.
- **ADR-057 §"Necessary conditions" (cluster-shape conformance)**: P087's class is "every skill / agent / hook in every `@windyroad/*` plugin", class size at codification time is ≥50 surfaces (per ADR-053 §granularity contract), drift is countable as NDJSON-line-per-surface band mismatch. All three conditions hold; Phase 2 ADR is exactly this cluster-rollout shape.
- **ADR-052 §"Behavioural-tests-default" (binding test contract)**: confirmation tests are NDJSON-output-driven against fixture transcripts and fixture git repos, not source-greps on the script body. Bats tests seed a fixture transcript with three known invocations and assert the NDJSON line emits `invocations_30d=3` for the corresponding surface.
- **ADR-023 §"Performance review scope" (binding performance contract)**: per-invocation cost-delta MUST be quantified for any script that ships under a `wr-<plugin>-*` shim. Phase 2 quantifies per-invocation cost with worst-case-assumption citations per ADR-026 (see Performance section).
- **No JTBD covers zero-ceremony privacy (acknowledged gap)**: the closest JTBD is JTBD-003 (Compose Only the Guardrails I Need), which is adjacent but not on-point. The privacy clauses are policy-anchored via ADR-035 rather than persona-anchored. Future iterations may extend the solo-developer persona with a privacy-defaults outcome on a new or existing job; this ADR does NOT retcon JTBD-003 to cover it.

## Considered Options

1. **Option E1 — One composite script `wr-itil-maturity-report` that emits a single combined NDJSON stream from both transcript and git axes**: cheaper to author, cheaper to invoke (one shim, one process). Rejected — conflates two signal sources whose freshness windows, failure modes, and access patterns differ; transcript axis can be inaccessible (privacy, missing dir, wrong machine), git axis only fails outside a git repo. Phase 3 will likely want the axes separately invokable for debugging ("which axis disagrees with my intuition?"). One-composite forces a re-split later.
2. **Option E2 — Two separate scripts on consistent signal-source frame (chosen)**:
   - `packages/itil/scripts/skill-invocations.sh` (canonical body) + `packages/itil/bin/wr-itil-skill-invocations` (shim) — Option 1 transcript axis. Reads `~/.claude/projects/*/sessions/*.jsonl`.
   - `packages/itil/scripts/plugin-exercise-index.sh` (canonical body) + `packages/itil/bin/wr-itil-plugin-exercise-index` (shim) — Option 2 commit-history axis. Reads `git log --since=60d --name-only` plus problem-ticket aggregation.
   Phase 3's badge-renderer reads both, computes the band per ADR-053's promotion rules + Bootstrapping clause, and writes `plugin.json`. Phase 2 owns the signal sources; Phase 3 owns the band-mapping writer.
3. **Option E3 — Host the scripts under a new `@windyroad/maturity` plugin or a yet-to-be-created `@windyroad/observe` plugin**: one-of-a-kind concern violates YAGNI; no second cluster of related observability skills exists yet. Rejected on YAGNI plus ADR-002 (each plugin independently installable — adopters who already install itil get the maturity tooling without a second install). Reassessment criterion documented below: if a second cluster of cross-cutting plugin-suite-observability tooling emerges (licence audit, vulnerability scan, dependency-currency rollup), promote `wr-itil-skill-invocations` and `wr-itil-plugin-exercise-index` into a new `@windyroad/observe` plugin via the standard skill-split / plugin-split pattern (ADR-010 deprecation-window precedent).
4. **Option E4 — Phase 2 scripts also write a cache file `~/.claude/maturity-cache/<project>/maturity.ndjson` for offline lookup**: rejected — directly contradicts ADR-053 §Confirmation #1 ("emit per-surface band designations as machine-readable output (JSON or NDJSON to stdout) without writing to disk. Phase 2 is exercise-the-signal, not commit-the-signal"). Reintroduces the dual-truth-with-drift surface ADR-053 §"Decision-anchored pressure stack alignment" rejects. If offline lookup is needed for `claude plugin list`-time band display, that legitimately belongs in Phase 3 where `plugin.json`'s `maturity:` field IS the canonical persistent record. Phase 3 reads from Phase 2's stdout once and writes the field; subsequent reads consume the field. No Phase 2 cache file.
5. **Option E5 — Three signal sources (add `/insights` parsing as a third axis)**: rejected for Phase 2. `/insights` is referenced as orthogonal session-friction signal (Phase 1 Direction decision §1); plugin authors can cite `/insights` output in their READMEs in Phase 3, but Phase 2's mechanical band-computation does not consume `/insights` output programmatically — `/insights` is interactive and session-scoped, not machine-readable across sessions. Phase 2's two-axis composite (transcript + git) is sufficient for the bootstrapping window's band computation.
6. **Option E6 — Continuous numeric exercise index instead of band-discrete output**: rejected — defeats ADR-053 §Decision Outcome §"Option D2 chosen" (five bands provide on-the-tin readability that a continuous score does not). Phase 2 may emit the continuous index alongside the band as a supplementary signal in the NDJSON; the band remains the load-bearing field for Phase 3 consumers.

## Decision Outcome

**Chosen option: Option E2 — two separate scripts (`wr-itil-skill-invocations` + `wr-itil-plugin-exercise-index`) under `packages/itil/`, NDJSON to stdout, exit-0-always, ADR-035-anchored privacy posture, ADR-052-behavioural confirmation, ADR-023-quantified performance.**

Rationale: Option E2 maintains separation of concerns (transcript-axis failure modes are independent from git-axis failure modes), preserves Phase 3 debugger-affordance (axes can be invoked and inspected independently), composes with ADR-049's shim grammar without modification, and avoids the YAGNI violation a new `@windyroad/observe` plugin would introduce. The plugin-home selection (itil) is justified by ADR-053's framing — maturity is downstream of ITIL service-management vocabulary (incident → problem → known-error → exercise level → maturity); no need for a fourteenth plugin until a second cluster of related observability skills emerges.

### Script contracts

**`wr-itil-skill-invocations`** — transcript axis, Option 1 prototype made canonical:

- Reads `~/.claude/projects/*/sessions/*.jsonl` (recursive glob) on the local host.
- Filters to messages with `type == "assistant"` whose `message.content` array contains a `tool_use` entry.
- Tallies invocations by:
  - `Skill` tool: input.skill (`wr-<plugin>:<skill-name>` form). Filtered to known plugin namespaces; unknown short-form skill names (e.g. user-typed shorthand `commit`, `loop`) are excluded from per-plugin attribution.
  - `Agent` tool: input.subagent_type (`wr-<plugin>:agent` form). Same namespace filter.
  - `Bash` tool: input.command pattern-matched against `bin/wr-<plugin>-*` shim grammar (ADR-049) and `packages/<plugin>/` script paths.
- Window: configurable, default thirty days. Time filter applied to the message-level `timestamp` field (ISO 8601) when present, file mtime otherwise.
- Output: NDJSON one record per surface. Schema:

  ```json
  {
    "schema_version": "1.0",
    "axis": "skill-invocations",
    "surface": "wr-itil:manage-problem",
    "kind": "skill",
    "plugin": "itil",
    "window_days": 30,
    "invocations": 96,
    "first_invocation_iso": "2026-04-08T03:14:21Z",
    "last_invocation_iso": "2026-05-03T22:48:11Z"
  }
  ```

  One additional record per surface kind (`skill`, `agent`, `bash-attributed`) is acceptable; downstream consumers aggregate.
- Exit code: 0 always. Conditions that produce zero output records (missing directory, opt-out marker, no transcripts in window): print one comment line `# wr-itil-skill-invocations: <reason>` to stderr, exit 0.

**`wr-itil-plugin-exercise-index`** — commit-history axis, Option 2 prototype made canonical:

- Runs `git log --since=<window>d --name-only --pretty=format:%H|%aI|%s` once on the project root.
- Per plugin (auto-discovered by listing `packages/*/`):
  - `commits_window`: count of commits in the last sixty days (default; configurable) touching at least one file under `packages/<plugin>/`.
  - `days_shipped`: days since the OLDEST git commit touching `packages/<plugin>/` (computed via a second log without `--since`).
  - `closed_tickets_window`: count of `docs/problems/*.closed.md` and `*.verifying.md` whose body cites `packages/<plugin>/`, modified in the last ninety days (default; configurable).
  - `breaking_change_age_days`: days since the most recent commit subject containing `BREAKING`, `feat!`, or `fix!` markers (sentinel value `null` when no match found in window).
- Output: NDJSON one record per plugin. Schema:

  ```json
  {
    "schema_version": "1.0",
    "axis": "plugin-exercise-index",
    "plugin": "itil",
    "commits_window": 157,
    "window_days": 60,
    "days_shipped": 27,
    "closed_tickets_window": 81,
    "tickets_window_days": 90,
    "breaking_change_age_days": null,
    "composite_index": 4.11
  }
  ```

  `composite_index = log10(commits_window + 1) + log10(closed_tickets_window + 1) + (days_shipped >= 60 ? 1.0 : 0.0)` — supplementary signal per Considered Option E6's "MAY emit alongside band" carve-out. The band field is NOT computed by this script; band-mapping is Phase 3's responsibility consuming both axes' NDJSON.
- Exit code: 0 always. Outside-git-repo and missing-`packages/` conditions emit zero records and exit 0.

**Per-category override hook**: both scripts accept a `--category-overrides=<file>` flag (path to a JSON file mapping plugin or surface globs to alternative thresholds). Future iterations of ADR-053 may pin per-category overrides (AFK orchestrator vs ADR-creation skill vs runtime-gate hook); the flag is a forward-extension point that ships unused in Phase 2 and is wired in by future ADR amendments without breaking the script's NDJSON shape.

### Privacy posture (ADR-035 clauses adopted verbatim)

- **Project-scoped read, explicit-invocation only**: the transcript script runs only when a developer explicitly invokes the shim (no PreToolUse / PostToolUse hook auto-invokes it). The git script likewise runs only on explicit invocation. No agent in project A passively reads project B's transcripts.
- **Opt-out marker**: `.claude/.skill-metrics-opt-out` (empty file marker) in a project root disables transcript-script reads for that project. The script checks the marker before reading the transcript directory; on marker present, emits zero records, prints `# wr-itil-skill-invocations: opt-out marker present at <path>` to stderr, exits 0.
- **First-run notice (interactive mode only)**: the first time the transcript script fires in a given session AND the opt-out marker is absent AND no opt-in marker `.claude/.skill-metrics-opt-in` is present, the script prints a one-line stderr notice describing what is read and how to opt out. AFK fail-safe per ADR-013 Rule 6: in non-interactive mode (orchestrator-launched session detected via envvar per ADR-019 convention), first-run notice fires once with no interactive-prompt; the script proceeds with reads but emits the notice line for transcript record.
- **Confidentiality clauses**: outputs only counts and surface names. Never user prose; never tool-input content beyond surface-name extraction (`Skill.input.skill`, `Agent.input.subagent_type`, `Bash.input.command` parsed for plugin-attribution pattern only); never attachment content. Project paths that surface in any output field are sha256-prefix-hashed (first twelve characters) per ADR-035's path-hashing convention. Bats fixture seeds a mock-secret pattern into a synthetic transcript and asserts the secret does NOT appear in the NDJSON output.
- **No network primitive**: the scripts invoke no `curl`, `wget`, `nc`, `fetch`, `http.client`, or equivalent. Bats fixture greps the canonical script body for these tokens and asserts absence (negative grep, declarative — exit 1 on positive match).

### Performance contract (ADR-023 §Decision Outcome template)

- **Per-invocation cost — `wr-itil-skill-invocations`**: bounded by transcript count × per-line JSON parse cost. Worst-case empirical observation 2026-05-03 (4480 sessions in thirty-day window, average ~140 lines/session): 1.4 seconds wall-clock on a warm-cache developer laptop (M-series Mac, NVMe disk, Python 3.13 stdlib `json`). Cite "no telemetry — worst-case empirical observation 2026-05-03 in this session" per ADR-026 grounding rule. Cold-cache estimate 2-3 seconds; not measured.

  **Decision Outcome — Phase 2c reassessment 2026-05-16 (iter-5)**: corpus grew to 5155 jsonl / 1.13 GB / 380,898 lines on the same workstation; warm-cache median measured 7.12 seconds (7.46 / 7.12 / 7.06 across three runs). Profile: file I/O 5.91s, JSON parse adds ~3s, mtime-filter savings 1.68s. The 5s reassessment threshold on §Reassessment Triggers line below fired with a 42% margin; Phase 2d performance-tuning iter was queued as a discrete P087 Investigation Task.

  **Decision Outcome — Phase 2d optimization 2026-05-17 (iter-6)**: substring pre-filter on `"tool_use"` token added before `json.loads()` in the canonical script body. Discriminating-token approach: 39.6% of in-window transcript lines retained for full parse against the live corpus (260,943 → 103,459); ~60% of lines short-circuit without paying the JSON parse cost. Re-quantified warm-cache median 5.34 seconds (5.32 / 5.34 / 5.44 across three runs) against the same 5155 jsonl / 1.13 GB / 380,898 lines corpus — 1.78s reduction (25%) from the Phase 2c 7.12s baseline. Cold-cache estimate not re-measured. The 5s reassessment threshold remained marginally exceeded (~0.34s / 6.8% over) — `breaking_change_age_days=null` not applicable; this is wall-clock cost, not git-axis composite. Phase 2e binary-search-to-first-in-window queued as the next obvious slice per the architect-endorsed staged shipping plan; the substring filter discharges the majority of the optimization headroom while leaving the appendable-JSONL-aware byte-seek optimization for a sibling slice. The substring-filter line is whitespace-tolerant (`"tool_use"` is a value token, not a key:value pair) so it works against both compact and pretty-printed JSONL; correctness fall-through invariant pinned by the "Phase 2d: false-positive substring fall-through" bats fixture.

  **Decision Outcome — Phase 2e optimization 2026-05-17 (iter-7)**: binary-search-to-first-in-window byte-seek added alongside the Phase 2d substring filter. For files ≥ 256 KB the script bisects byte offsets to locate the earliest line whose `timestamp` parses to a value at or after the cutoff, then linear-scans from that offset; files below threshold continue to scan from byte 0 (linear scan is cheaper than bisect overhead on small files). Re-quantified warm-cache median **4.04 seconds** (3.87 / 4.04 / 4.98 across three warm runs) against the same 5164 jsonl / ~1.08 GB corpus on the same workstation — 1.30s reduction (24%) from the Phase 2d 5.34s baseline and **3.08s reduction (43%)** from the Phase 2c 7.12s baseline. Cold-cache observed 7.81s (single run; first-pass disk read dominates). The 5s ADR-058 §Reassessment Triggers threshold is now silenced — warm-cache wall-clock is 0.96s / 19% under the budget. NDJSON output shape and record count are unchanged (235 records on the live corpus, identical surface attribution and ordering to Phase 2d). The bisect probes timestamps via a cheap whitespace-tolerant byte regex (`"timestamp"\s*:\s*"..."`); per-probe `readline()` alignment guarantees byte-boundary safety; loop termination guaranteed by `hi = mid` on the in-window branch (line-aligned probes would stall under `hi = pos`).

  **Input invariant — append-only monotonic timestamps within session jsonl**: the bisect assumes timestamps within a single session jsonl file are non-decreasing by byte order (each Claude Code session is an append-only stream from one process; the wall-clock advances monotonically across writes). Real session transcripts satisfy this by construction. Synthetic input that violates the invariant (clock skew, replay, hand-authored jumbled fixtures) under-counts gracefully — the bisect locates by byte position and may skip earlier in-window lines that happen to follow later out-of-window lines — without crashing or emitting malformed NDJSON. Pinned by the "Phase 2e: non-monotonic timestamps — graceful degradation" bats fixture; correctness invariants on monotonic input pinned by the "byte-seek straddle / all-in-window / small-file linear / empty-large-file" fixtures (19 tests now, all green).
- **Per-invocation cost — `wr-itil-plugin-exercise-index`**: bounded by `git log --since=60d --name-only` traversal. Worst-case empirical observation 2026-05-03 on the windyroad-claude-plugin monorepo: 0.8 seconds wall-clock on a warm-cache developer laptop. Plus problem-ticket scan: 90-day window × ~150 ticket files × ~5 KB average body = 0.1 seconds. Total: ≤ 1.0 second warm; ≤ 2.0 seconds cold.
- **Frequency estimate**: invoked from the eventual Phase 3 wiring (yet to be authored) at minimum once per `/wr-itil:assess-release` and possibly once per developer-initiated `claude plugin list`-extended-output invocation. Phase 2 frequency = "user-initiated only", aggregate = "≤ daily per developer". No hook auto-invokes either script.
- **Performance budget**: no `performance-budget-itil-scripts` ADR currently exists in scope. Phase 2 explicitly accepts ungoverned performance risk per ADR-023's Decision Outcome template — risk owned at the Phase 2 implementation level rather than gated at an upstream policy. If Phase 3 wires either script into a frequently-invoked surface (e.g. `claude plugin list` on every `/install-updates` run), a follow-on ADR pinning a `performance-budget-itil-scripts` performance contract is recommended at that time. Reassessment trigger documented below.
- **Cache-control discipline**: Phase 2 has no on-disk cache (Considered Option E4 rejected). The transcript-axis script CAN cache its in-process per-jsonl-file last-modified-time map within a single invocation but MUST NOT persist any cache to disk between invocations — same prohibition as ADR-053 §Confirmation #1 ("without writing to disk").

### Confirmation (behavioural per ADR-052)

1. **NDJSON-shape fixture**: `packages/itil/scripts/test/skill-invocations.bats` seeds a synthetic transcript file under a temp `~/.claude/projects/<temp>/sessions/` with three `Skill` invocations of `wr-itil:manage-problem` in 30-day window. The bats asserts `wr-itil-skill-invocations --window-days=30 --root=<temp>` emits exactly one NDJSON record where `axis="skill-invocations"`, `surface="wr-itil:manage-problem"`, `kind="skill"`, `plugin="itil"`, `invocations=3`. NDJSON is validated structurally (each line is valid JSON with the expected keys), not by string-match.
2. **Opt-out marker fixture**: bats seeds the temp project with `.claude/.skill-metrics-opt-out`, runs the script, asserts zero NDJSON output records on stdout AND stderr line `# wr-itil-skill-invocations: opt-out marker present at <path>`. Exit code 0.
3. **No-network-primitive fixture**: bats greps the canonical script body (`packages/itil/scripts/skill-invocations.sh`, `packages/itil/scripts/plugin-exercise-index.sh`) for tokens `curl|wget|nc |fetch|http\.client|urllib`. Asserts zero matches. (Negative-presence grep is acceptable here under ADR-052's "behavioural unless declarative-only" exception — no executable behaviour can express "this script is incapable of exfiltration"; the negative grep is the closest behavioural approximation.)
4. **Path-hashing fixture**: bats seeds a transcript whose tool-call inputs reference an absolute path containing a synthetic secret-shaped string `password-XXXX-secret`. Asserts the NDJSON output does NOT contain the literal `password-XXXX-secret` token (path-sanitisation applied) AND any path that surfaces is sha256-prefix-hashed (twelve hex characters).
5. **Inaccessible-directory fixture**: bats sets `--root=/nonexistent/path` (overriding the default `~/.claude/projects`), runs the script, asserts zero NDJSON output records on stdout, stderr line documenting the inaccessible-root condition, exit code 0. ADR-013 Rule 6 fail-safe verified.
6. **Git-axis composite fixture**: `packages/itil/scripts/test/plugin-exercise-index.bats` initialises a temp git repo with a `packages/dummy/` subdirectory and three commits touching it (one in window, two out of window). Asserts the NDJSON record for `plugin="dummy"` shows `commits_window=1` (default 60-day window).
7. **Outside-git-repo fixture**: bats runs `wr-itil-plugin-exercise-index` from a non-git temp directory, asserts zero NDJSON output records, stderr documenting the missing-git condition, exit code 0.
8. **Schema-version contract**: bats parses the NDJSON output and asserts every record's `schema_version` field equals `"1.0"`. Future schema bumps follow ADR-035's "additive-only within a major version" precedent.
9. **Bootstrapping-clause band-mapping is NOT tested in Phase 2** — band-mapping is Phase 3's responsibility consuming both axes' NDJSON. Phase 2 emits the underlying signals; band-mapping fixtures live with the Phase 3 ADR's bats.

### Phase 4+ escalation gate (numeric criterion ADR-053 left open)

ADR-053 §Confirmation #5 says escalation from advisory to CI assertion follows the ADR-013 Rule 6 criterion: "if accumulated drift across N consecutive releases (initial proposal: three) goes unfixed, the advisory script is promoted to a release-blocking gate". Phase 2 pins the (N, M) numeric criterion explicitly:

- **N = 3 consecutive releases** — drift count must NOT decrease across three release boundaries to trigger escalation. Aligns with ADR-051's escalation contract for JTBD anchoring (consistency across cluster ADRs per ADR-057 §Phase 4 contract).
- **M = 5 surfaces** — drift count threshold below which the advisory remains advisory regardless of trend. Below five out-of-band surfaces in any single release-time scan, the advisory's signal-to-noise is too low to justify a release gate. Above five, the drift represents a maintenance gap meaningful for adopters.
- **Drift definition**: a surface is "drifted" when its computed band (per Phase 3 band-mapping consuming Phase 2 NDJSON) does NOT match its persisted `plugin.json` `maturity:` field. Drift is countable per ADR-057 §"Necessary conditions" condition 3.
- **Advisory output line for the gate**: each release-time scan emits `RELEASE <version> SURFACE <name> drift_band_computed=<X> drift_band_persisted=<Y>` for any drifted surface, plus a summary line `RELEASE <version> total_drift_count=<K>`. The release-pipeline integration (Phase 4+ scope) reads the summary line and triggers the gate iff `K >= 5` AND the previous two release scans also reported `K >= 5` AND `K` is non-decreasing across the three.

The (N, M) values are tunable in a future amendment; the initial pinning is conservative (N=3 is the minimum that establishes a trend; M=5 is below the suite's likely steady-state drift count of ≤2 surfaces under normal maintenance, so the gate fires only on systemic maintenance gaps not routine band recomputation).

## Consequences

- **Positive**: Phase 2 NDJSON output is the data source for the JTBD-101 hardening-prioritisation outcome (extended 2026-05-04). Plugin developers can answer "which of my surfaces are exercised, which are not" with `wr-itil-skill-invocations | jq 'select(.plugin == "<my-plugin>")'`. The cumulative observation-and-codification-and-tooling cycle from P087's first reporting on 2026-04-21 to Phase 2 landing on 2026-05-04 is fourteen days — within the "second-occurrence-triggers-helper-extraction" precedent's tolerance.
- **Positive**: read-only, exit-0-always, host-local posture composes cleanly with ADR-013 Rule 6, ADR-040, ADR-035, ADR-043. Phase 2 introduces zero new policy surface; reuses existing privacy and grounding contracts.
- **Positive**: the (N, M) escalation criterion ADR-053 left open is now pinned. Phase 4+ escalation has a deterministic trigger; future contributors authoring escalation tooling have a contract to ship against rather than a deferred decision.
- **Positive**: composability with ADR-057 cluster-rollout shape is explicit — class membership condition met (≥50 surfaces), countable drift met (NDJSON line per surface), three-phase shape preserved.
- **Neutral**: two scripts vs one composite is a deliberate trade-off. Future contributors invoking BOTH axes pay two process startups; the architectural-clarity benefit is judged worth the cost. Reassessment trigger: if the two-script invocation pattern becomes a measurable performance burden at Phase 3 (e.g. `claude plugin list` invocation latency exceeds 200ms), a future amendment may re-evaluate consolidation.
- **Negative**: ADR-002 boundary tension. The maturity tooling lives under `@windyroad/itil`, meaning adopters who install only `@windyroad/architect` cannot run a maturity report on architect itself without also installing itil. Acknowledged trade-off — maturity is part of the ITIL service-management vocabulary, adopters who want maturity install itil. Reassessment criterion: if a second cluster of cross-cutting plugin-suite-observability tooling emerges (licence audit, vulnerability scan, dependency-currency rollup), promote `wr-itil-skill-invocations` and `wr-itil-plugin-exercise-index` into a new `@windyroad/observe` plugin via the standard skill-split / plugin-split pattern. ADR-010 deprecation-window precedent applies.
- **Negative**: privacy-JTBD gap. No JTBD declares zero-ceremony privacy as a primary outcome; the privacy clauses are policy-anchored via ADR-035 rather than persona-anchored. Risk: future contributors reviewing the privacy surface have ADR-035 to read but no JTBD-level user-perspective framing. Recommendation: a future iteration may extend the solo-developer or plugin-user persona with a privacy-defaults outcome on a new or existing job. This ADR does NOT retcon any existing JTBD to cover it.
- **Negative**: Phase 2's "no on-disk cache" posture (ADR-053 §Confirmation #1 verbatim) means every `claude plugin list`-time band display recomputes from session transcripts and git log. Phase 3's `plugin.json` `maturity:` field IS the canonical persistent record (per ADR-053 §Decision Outcome §"Chosen signal location"); Phase 3 reads from Phase 2's stdout once and writes the field; subsequent reads consume the field. Until Phase 3 ships, every `wr-itil-skill-invocations` invocation pays the full transcript-parse cost. Mitigation: Phase 2's < 1.5s warm-cache cost is acceptable for user-initiated invocations.
- **Negative**: Phase 4+ escalation gate's (N, M) values are strawmen. If steady-state drift count proves to routinely sit at six or seven surfaces (above the M=5 threshold) without representing genuine maintenance gap, the gate would fire spuriously. Phase 3 retroactive-assessment data is the first calibration point; if M=5 is wrong, the (N, M) values can be tuned in a future amendment without re-authoring this ADR.

## More Information

- **P087** — `docs/problems/087-no-maturity-signal-for-plugin-features.known-error.md` — driver ticket; "Direction decision (2026-04-21)" + "Phase 2" subsection record the user-approved approach; Phase 2 prototype outputs preserved under `docs/audits/p087-phase2-prototypes/` for audit-trail.
- **ADR-053** — `docs/decisions/053-plugin-maturity-taxonomy.proposed.md` — Phase 1 contract; §Bootstrapping clause (amendment 2026-05-04) is the band-admission contract Phase 2 implements without modification.
- **ADR-049** — `docs/decisions/049-plugin-script-resolution-via-bin-on-path.proposed.md` — `wr-<plugin>-<kebab-script-name>` shim grammar binding both Phase 2 scripts.
- **ADR-035** — `docs/decisions/035-centralised-review-reports.proposed.md` — privacy and consent clauses adopted verbatim (opt-out marker, project-scoped read, content-sanitisation, path-hashing).
- **ADR-043** — `docs/decisions/043-progressive-context-usage-measurement.proposed.md` — read-only-script-on-`~/.claude/projects/` precedent for the ungrounded-when-inaccessible behaviour.
- **ADR-004** — `docs/decisions/004-project-scoped-install-by-default.proposed.md` — establishes the per-project read/write boundary that ADR-035 specialises.
- **ADR-013** — `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` — Rule 6 fail-safe binding posture.
- **ADR-040** — declarative-first-then-enforce precedent; Phase 2 is the descriptive measurement layer.
- **ADR-052** — `docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md` — confirmation tests are NDJSON-output-driven against fixtures.
- **ADR-057** — `docs/decisions/057-three-phase-declarative-first-cluster-rollout.proposed.md` — meta-shape; Phase 2 ADR is exactly this rollout's Phase 2.
- **ADR-023** — `docs/decisions/023-wr-architect-performance-review-scope.proposed.md` — Decision Outcome template for performance-quantification.
- **ADR-026** — agent output grounding; per-invocation cost-delta estimates cite "no telemetry — worst-case empirical observation" per ADR-026 grounding rule.
- **ADR-019** — envvar convention for AFK-mode detection.
- **ADR-002** — monorepo per-plugin packages boundary.
- **ADR-010** — skill-split / plugin-split deprecation-window precedent for the future `@windyroad/observe` migration scenario.
- **JTBD-101** — `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md` — extended 2026-05-04 with the hardening-prioritisation outcome that Phase 2's NDJSON serves.
- **JTBD-302** — `docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md` — terminal driver, Phase-3-active.
- **JTBD-201** — `docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md` — secondary driver, Phase-2-active.
- **JTBD-007** — `docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md` — currency-pressure composition.
- **JTBD-003** — `docs/jtbd/solo-developer/JTBD-003-compose-guardrails.proposed.md` — composition driver.

### Reassessment Triggers

This ADR is reassessed when ANY of the following occur:

- **Phase 3 retroactive-assessment data invalidates the (N, M) escalation values**: if steady-state drift count routinely sits at six or seven surfaces without representing genuine maintenance gap, tune (N, M).
- **A second cluster of cross-cutting plugin-suite-observability tooling emerges**: promote scripts into a new `@windyroad/observe` plugin via ADR-010 skill-split precedent.
- **Phase 3 wires either script into a frequently-invoked surface (e.g. `claude plugin list` on every `/install-updates` run)**: author a `performance-budget-itil-scripts` ADR pinning per-invocation cost ceiling.
- **The Bootstrapping clause's sunset criterion fires (anticipated 2026-06-06, sixty days after 2026-04-07 first commit)**: re-validate Phase 2 NDJSON output under steady-state band-mapping; verify no script changes are needed (steady-state thresholds are already wired through the per-category override hook).
- **Upstream Claude Code ships per-skill invocation analytics either inside `/insights` output or as a machine-readable export from session JSONL**: `wr-itil-skill-invocations`'s custom parser becomes redundant; consolidate or deprecate per the ADR-010 superseded-by pattern.
- **The privacy-JTBD gap is closed by extending solo-developer or plugin-user persona with a privacy-defaults outcome on a new or existing job**: re-anchor ADR-058's privacy posture from policy-only (ADR-035) to JTBD-anchored.
- **Either script's worst-case cost grows above 5 seconds wall-clock on a warm-cache developer laptop**: open a performance-tuning iter and re-quantify under ADR-023's Decision Outcome template. *2026-05-17 update (Phase 2e iter-7)*: trigger fired Phase 2c iter-5 (7.12s observed); Phase 2d iter-6 substring-prefilter optimization shipped at 5.34s warm-cache median (still marginally exceeding by 0.34s / 6.8%); Phase 2e iter-7 binary-search-to-first-in-window byte-seek shipped at **4.04s warm-cache median** (3.87 / 4.04 / 4.98 across three warm runs) — 1.30s reduction (24%) from Phase 2d, 3.08s reduction (43%) from Phase 2c baseline. **Trigger is now silenced** — warm-cache wall-clock sits 0.96s / 19% under the 5s threshold with measurement headroom for corpus growth. Reassessment fires again if subsequent corpus growth or feature additions push the median above 5s; the next remediation slice (a "Phase 2f" if needed) would target either an in-memory file-handle cache across invocations (out of scope under ADR-053 §Confirmation #1 disk-cache prohibition; in-process only) or skipping the first-line timestamp probe per file when mtime tightly bounds the cutoff.
- **Reassessment date 2026-08-04** — quarterly review per the standard ADR cadence; verify the Phase 2 contract is still load-bearing after Phase 3 has had ~3 months of operation.
