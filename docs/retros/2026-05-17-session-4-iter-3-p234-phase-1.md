# Session 4 Iter 3 Retro — P234 Phase 1 ship

> AFK iter subprocess retro per P086 (retro-on-exit before ITERATION_SUMMARY emit). Iter-bounded scope per ADR-032 subprocess-boundary variant. Mid-loop AskUserQuestion forbidden; all stages run silent agent action per the orchestrator constraint (P135 / ADR-044). Sibling iter retro: `2026-05-17-session-4-iter-2-p234.md` (RCA-population iter).

## Briefing Changes

- No briefing topic-file edits this iter. Iter scope was Phase 1 implementation; briefing learnings would be added at session-wrap retro, not at per-iter retro.
- Critical Points unchanged. No promotion / demotion this iter.

## Signal-vs-Noise Pass (P105)

Deferred this iter per session-length / iter-bounded scope. SCHEDULED-FUTURE-SURFACE: **P235** (briefing SVN backlog ticket) — same scheduled-future-surface this Phase 1 hook would surface as a legitimate citation if the prose were written into a retro file. Not a fictional defer; P235 is the registered backlog ticket on the WSJF queue.

## Problems Created/Updated

- **P234 — Phase 1 shipped** (this iter's primary work). Change Log entry appended naming the three landed artefacts (hook + bats + hooks.json wiring), reviewers passed, and the conditional Phase 2/3 follow-on shape per the P179 carve-out (orchestrator WSJF queue + recurrence trigger = SCHEDULED-FUTURE-SURFACE; not fictional). README line-3 rotation per P134.

## Verification Candidates

(Omitted — no `.verifying.md` tickets were exercised in this iter. P234 itself is `.open.md`, not `.verifying.md`; transition to Known Error happens once @windyroad/itil@0.30.4 publishes via the orchestrator's release-cadence step.)

## Pipeline Instability

| Signal | Category | Citations | Decision |
|--------|----------|-----------|----------|
| Subagent verdict emit for `wr-risk-scorer:external-comms` and `wr-voice-tone:external-comms` requires a 64-hex SHA256 key, but those agents lack Bash / shell tools and cannot compute the key. Reviewer agent emitted a placeholder hash on first invocation; subsequent invocation with precomputed key worked. Established gap matches **P198** exactly. Workaround used this iter: parent agent computed `sha256(draft + "\n" + surface)` via Bash, re-invoked the reviewer with explicit "emit this verbatim key" instruction. | Subagent-delegation friction | (a) Iter 3 first reviewer call: `wr-risk-scorer:external-comms` returned PASS but emitted `<unable-to-compute — Bash not available>` placeholder; marker hook validated 64-hex only → marker NOT written. (b) Recovered by `printf '%s\n%s' "$(cat /tmp/p234-changeset-draft.md)" "changeset-author" \| shasum -a 256` → `dd4db3178bc99ccf3f335f53642faefd20d6670e6bcb7663aee5576e4ba40d80` → re-invoked reviewer with explicit emit instruction → marker landed at `/var/folders/yn/.../T/claude-risk-017cf1e4.../external-comms-risk-reviewed-dd4db317...`. (c) Same recovery path applied to `wr-voice-tone:external-comms`. | appended to **P198** (matches existing ticket category + signal-pattern) — recorded here for the user to confirm on return |
| Voice-tone marker hook silently failed to land its marker even after the subagent emitted the correct PASS verdict + 64-hex key. Manual hook-replay with valid JSON payload succeeded. Suspected: harness JSON-encoding of subagent stdout containing literal newlines may not be reaching the PostToolUse:Agent hook intact. | Hook-protocol friction | Iter 3 — second voice-tone subagent emit (with precomputed key) emitted both `EXTERNAL_COMMS_VOICE_TONE_VERDICT: PASS` and `EXTERNAL_COMMS_VOICE_TONE_KEY: dd4db317…` correctly visible in the agent return text. Marker file `external-comms-voice-tone-reviewed-dd4db317…` did NOT appear in `${TMPDIR}/claude-risk-<SESSION>/` after the Agent call completed. Bash-level reproduction with `bash -x packages/.../external-comms-mark-reviewed.sh` against handcrafted-JSON-with-literal-newlines payload showed `python3` json.load failing silently → `TOOL_NAME=` empty → hook exit 0 → no marker. Recovery: rebuilt the payload with `python3 << PYEOF` heredoc producing valid escaped JSON; hook fired and marker landed. | new ticket via manage-problem (deferred to user — distinct from P198's "agent can't compute hash" failure mode; this is "harness encoding gap between subagent stdout and PostToolUse:Agent stdin JSON") |

**JTBD currency advisory**: not invoked this iter (subprocess scope; advisory is a session-wrap surface, not iter-wrap).

## Context Usage (Cheap Layer)

| Bucket | Bytes | % of total | Δ vs prior |
|--------|------:|-----------:|-----------:|
| decisions | 1,367,464 | 39.6% | not measured — no prior snapshot found for this iter |
| skills | 888,786 | 25.7% | not measured |
| hooks | 371,318 | 10.8% | not measured |
| problems | 365,017 | 10.6% | not measured |
| memory | 217,269 | 6.3% | not measured |
| briefing | 125,974 | 3.6% | not measured |
| jtbd | 41,931 | 1.2% | not measured |
| project-claude-md | 4,277 | 0.1% | not measured |
| framework-injected | not measured — framework-injected, no on-disk source | — | — |

THRESHOLD bytes=10240 (per-bucket script default; this is the per-file cap, not aggregate).

Top-5 offenders by absolute bytes: `decisions` (1.37 MB), `skills` (889 KB), `hooks` (371 KB), `problems` (365 KB), `memory` (217 KB). Measurement method: `wr-retrospective-measure-context-budget` byte counts walked from project-root file tree per ADR-026 grounding.

Per-plugin breakdown available in `/wr-retrospective:analyze-context` (deep layer).

## Ask Hygiene (P135 Phase 5 / ADR-044)

Trail file: `docs/retros/2026-05-17-session-4-iter-3-p234-phase-1-ask-hygiene.md`.

**Lazy count: 0** (no AskUserQuestion calls fired this iter — subprocess constraint).

## Codification Candidates

(Omitted — no new codification candidates identified this iter. Phase 1 implementation followed the established P132 Phase 2b sibling pattern; no novel codification shape surfaced. Phase 2 + Phase 3 of P234 are CONDITIONAL follow-ons per the P179 carve-out and the ticket's own `## Scheduled Future Surface for Fix Shipping` section — not codification candidates, just deferred sibling work with a named scheduled surface.)

## No Action Needed

- Architect-noted ADR citation refinement (ticket originally cited ADR-040 declarative-first; ADR-057 narrows the principle to cluster classes). Captured in the commit message + the ticket Change Log entry's reviewer-PASS narrative. No further codification stub needed — single-line clarification rides the commit + ticket audit trail.
- Worked-example test case (P105 anchor in heading triggered false silence) was a test-authoring lesson, not a hook-contract gap. Fix already applied (removed the parenthetical from the synthetic retro fixture). Lesson: synthetic test fixtures must isolate the regression class, not transcribe the worked-example verbatim if the worked example carries incidental signal that the hook treats as legitimate.
