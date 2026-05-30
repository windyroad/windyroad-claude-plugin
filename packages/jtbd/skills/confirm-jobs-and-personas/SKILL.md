---
name: wr-jtbd:confirm-jobs-and-personas
description: Drain the set of Jobs To Be Done and personas that lack human oversight. Surfaces each auto-derived job/persona via AskUserQuestion so a human confirms, amends, or rejects it, then writes the human-oversight marker. Use when the session-start nudge reports jobs/personas lack oversight, or any time you want to review the documented JTBD corpus. This is the read-write oversight drain — distinct from /wr-jtbd:review-jobs (the read-only alignment reviewer).
allowed-tools: Read, Glob, Grep, Bash, Edit, AskUserQuestion
---

# Confirm Jobs and Personas — human-oversight drain

Lift auto-derived Jobs To Be Done and personas to human decisions. Documented jobs/personas are load-bearing: the JTBD edit gate reviews every project change against `docs/jtbd/`, so a job or persona that was agent-derived without a human confirming it reflects real need propagates wrong alignment verdicts. This skill drains the **unoversighted set** (jobs/personas lacking `human-oversight: confirmed`, per ADR-068): it surfaces each via `AskUserQuestion`, and writes the oversight marker only when a human confirms.

This is the P288 / ADR-068 drain surface — the JTBD sibling of `/wr-architect:review-decisions`. It is **read-write** (writes the marker on confirm). It is NOT the same as `/wr-jtbd:review-jobs`, which is a read-only alignment review ("do my changes trace to documented jobs?"); this skill confirms the jobs/personas themselves.

## When to use

- The session-start nudge reported `N jobs/personas lack human oversight`.
- Pre-handover / pre-release: confirm the JTBD corpus reflects real user/business need.
- After an `update-guide` run or agent-derived job/persona authoring landed files without confirmation.
- Any focused sitting — designed for **batches over multiple sittings**, not one blocking pass.

## How it works

The marker persists (ADR-009 never-re-ask principle), so a partially-drained set resumes cleanly on the next run.

### Step 1: Enumerate the unoversighted set

```bash
wr-jtbd-detect-unoversighted docs/jtbd
```

The `wr-jtbd-detect-unoversighted` command is a `$PATH`-resolved shim (ADR-049) dispatching `packages/jtbd/scripts/detect-unoversighted.sh`. It prints one unoversighted job/persona path per line (README excluded; token-cheap grep over frontmatter — no body reads). Empty output → the corpus is fully confirmed; report and stop.

### Step 2: Cluster + order

Read **only the frontmatter + title + Job Statement / persona "Who" section** of each unoversighted file (not full bodies — keep it cheap). Group by persona directory and order **load-bearing first**: personas before their jobs (a persona frames its jobs), and jobs that other artifacts (problems, RFCs, READMEs) cite most heavily before narrow ones.

### Step 3: Present each via AskUserQuestion (batched)

For each job/persona in the ordered queue, surface it as an `AskUserQuestion` (cap **4 per call** per ADR-013 Rule 1; issue further calls sequentially):

- **Question**: the job statement (for a JTBD) or the persona definition (who they are + key constraints), in one line.
- **Context**: grounded in what the file actually says (per ADR-026) — the persona served, the desired outcomes, any cited problems/RFCs.
- **Options** per artifact:
  - **Confirm** — the job/persona accurately reflects real need; write the marker.
  - **Amend** — mostly right but needs a change; capture it, apply it to the file, then write the marker.
  - **Reject** — the auto-derived job/persona does not reflect real need; capture the supersede ticket (see Step 4) and write the **rejected-pending-supersede** marker so the drain stops re-asking.
  - **Defer** — skip this sitting; leave unoversighted for later.

**Presentation rule — lead with the job statement / persona definition, never with the meta (P302).** The AskUserQuestion `question` field MUST open with the one-line job statement (for a JTBD) or persona definition (for a persona) — *what the job/persona asserts about real user/business need* — phrased as `"This job statement: <statement>"` / `"This persona: <who they are + key constraint>"`. Persona-cluster relationships, source-citations (which problem/RFC triggered the auto-derivation), and any internal-housekeeping recording-shape are **meta** about *how the artifact was authored*, not what it asserts — relegate them to a trailing clause or omit. Mirrors the `/wr-architect:review-decisions` presentation rule (P302) — ADR-074's *name the substance, not the grain* principle applied to the JTBD-confirm surface, and ADR-026 grounding extended from the file body to the AskUserQuestion `question` text. Burying the substance behind meta forces a clarifying re-ask: the user cannot tell what they are confirming reflects real need.

The trailing clause exists for cross-reference value — it is optional, NOT a re-entry point for meta-leading. When the meta does not add load-bearing context for the confirm decision, omit it entirely.

This is a genuine human-decision surface (the point of P288/ADR-068) — `AskUserQuestion` is correct here, not over-asking. Do not auto-confirm; do not prose-ask.

### Step 4: Apply the outcome

- **Confirm / Amend**: write `human-oversight: confirmed` + `oversight-date: <today, YYYY-MM-DD>` into the file's frontmatter (insert after the `status:`/`date-created:` line if absent; never duplicate). For Amend, apply the directed change first. Edits go through the standard JTBD / architect edit gate per ADR-014.
- **Reject** (ADR-068 amendment per P316, mirroring ADR-066):
  1. Capture the supersede ticket via a follow-up `AskUserQuestion`: "Which problem ticket tracks the rework?" — options: existing `P<NNN>` IDs surfaced from `docs/problems/`, **Capture a new ticket** (delegate to `/wr-itil:capture-problem`), or **Defer (leave un-tracked for now)**.
  2. If a ticket ID is captured, write `human-oversight: rejected-pending-supersede` + `supersede-ticket: P<NNN>` into the file's frontmatter. The detector excludes artifacts carrying both, so the drain stops re-asking until either the rework lands (file renamed to `*.superseded.md`) or the rejection is revisited.
  3. If the user defers ticket capture, leave the marker absent — the artifact re-surfaces next drain (the un-tracked case is intentionally re-asked so it doesn't silently rot).
- **Defer**: no write.

**Unoversighted ≠ unusable** (ADR-068): an unconfirmed job/persona stays fully readable and review-anchorable. The marker records provenance; it never quarantines the doc or blocks reviews from reading it.

### Step 5: Commit + report

Commit the confirmed/amended files per ADR-014 (one commit per drain sitting is acceptable). Report: confirmed / amended / rejected / deferred counts, and the remaining unoversighted count (re-run the detector). The session-start nudge count drops by the number confirmed.

## Notes

- **Never re-ask** — a confirmed job/persona carries the marker permanently and is excluded from future runs (ADR-009). The same write-once-permanence applies to the `rejected-pending-supersede` value (P316 amendment): once the user rejects with a tracked ticket, the drain stops asking. Write-once **except** when the job statement / persona definition is materially rewritten — a material amend clears the marker for re-confirmation (ADR-068 Reassessment). When the rework lands and the file is renamed to `*.superseded.md`, the existing superseded-name skip takes over; the `rejected-pending-supersede` lines become historical residue.
- **AFK** — interactive by construction (the confirm IS the human decision); not dispatched in AFK iteration subprocesses. The session-start nudge self-suppresses there (`WR_SUPPRESS_OVERSIGHT_NUDGE=1`).
- **Born-confirmed going forward** — `/wr-jtbd:update-guide` writes the marker when the user confirms a new/edited job or persona, so new artifacts enter the set already oversighted and the unoversighted count only shrinks.

## Related

- **ADR-068** — this drain + the marker + detector + nudge. **ADR-066 / P283** — the architect precedent this mirrors.
- **ADR-008** — JTBD directory structure (the marker is additive to its frontmatter contract).
- **ADR-009** — never-re-ask persistent-marker principle. **ADR-013 / ADR-044** — structured user interaction + decision-delegation taxonomy.
- `packages/jtbd/skills/review-jobs/SKILL.md` — the read-only alignment reviewer (distinct from this drain).
- `packages/jtbd/skills/update-guide/SKILL.md` — born-confirmed write site.
