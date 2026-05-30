---
name: wr-architect:review-decisions
description: Drain the set of recorded decisions (ADRs) that lack human oversight. Surfaces each unconfirmed ADR's chosen option and alternatives via AskUserQuestion so a human confirms, amends, or rejects the auto-made call, then writes the human-oversight marker. Use when the session-start nudge reports decisions lack oversight, or any time you want to review recorded decisions.
allowed-tools: Read, Glob, Grep, Bash, Edit, AskUserQuestion
---

# Review Decisions — human-oversight drain

Lift auto-made architecture decisions to human decisions. Many ADRs were recorded autocratically — the architect proposed an option and it stood without a human picking it. This skill drains the **unoversighted set** (ADRs lacking `human-oversight: confirmed` in frontmatter, per ADR-066): it surfaces each decision's chosen option + the alternatives via `AskUserQuestion`, and writes the oversight marker only when a human confirms.

This is the P283 prong-2 drain surface. It is the eat-our-own-dogfood loop: confirming a decision is itself a human decision, so it goes through `AskUserQuestion`.

## When to use

- The session-start nudge reported `N decisions lack human oversight`.
- Pre-handover / pre-release: confirm the recorded decision set reflects human intent.
- After a batch of AFK-recorded ADRs: review what landed without interactive confirmation.
- Any focused sitting — the drain is designed for **batches over multiple sittings**, not one blocking pass.

## How it works

Each run drains as many ADRs as the user has appetite for, in topic-clustered batches. The marker persists (ADR-009 never-re-ask principle), so a partially-drained set resumes cleanly on the next run.

### Step 1: Enumerate the unoversighted set

Run the detector (token-cheap — grep over frontmatter, no body reads):

```bash
wr-architect-detect-unoversighted docs/decisions
```

The `wr-architect-detect-unoversighted` command is a `$PATH`-resolved shim (ADR-049 naming grammar) dispatching `packages/architect/scripts/detect-unoversighted.sh`. It prints one unoversighted ADR path per line (superseded ADRs are excluded — a retired decision needs no confirmation). Empty output → the set is fully drained; report "all recorded decisions carry human oversight" and stop.

### Step 2: Cluster + order

Read **only the frontmatter + title + Decision Outcome** of each unoversighted ADR (not full bodies — keep it cheap). Group by topic cluster (e.g. release-cadence, governance-gates, AFK-orchestration, decision-recording) and order **load-bearing first**: ADRs that other ADRs cite as parents, that are `accepted` (already shipped — highest drift cost if the auto-pick was wrong), or that govern a hook/gate the user interacts with daily. Defer narrow / low-coupling ADRs.

### Step 3: Present each decision via AskUserQuestion (batched)

For each ADR in the ordered queue, surface the decision as an `AskUserQuestion` (cap **4 ADRs per call** per ADR-013 Rule 1; issue further calls sequentially). For each ADR:

- **Question**: the decision the ADR records (its Decision Outcome, in one line).
- **Context**: the chosen option + the alternatives the ADR considered (grounded in the ADR's Considered Options section per ADR-026), and any cited parent ADRs.
- **Options** (per ADR):
  - **Confirm** — the recorded decision is correct; write the marker.
  - **Amend** — the decision is mostly right but needs a change; capture the change, apply it to the ADR body, then write the marker.
  - **Reject / supersede** — the auto-made pick is wrong; capture the supersede ticket (see Step 4) and write the **rejected-pending-supersede** marker so the drain stops re-asking.
  - **Defer** — skip this sitting; leave unoversighted for a later run.

This is a genuine human-decision surface (the whole point of P283) — `AskUserQuestion` is correct here and is NOT over-asking. Do not auto-confirm; do not prose-ask.

### Step 4: Apply the outcome

- **Confirm / Amend**: write `human-oversight: confirmed` + `oversight-date: <today, YYYY-MM-DD>` into the ADR's frontmatter (insert after the `date:` line if absent; never duplicate). For Amend, apply the directed body change first. Both edits go through the standard architect / JTBD edit gate per ADR-014.
- **Reject / supersede** (ADR-066 amendment per P316):
  1. Capture the supersede ticket via a follow-up `AskUserQuestion`: "Which problem ticket tracks the supersede?" — options: existing `P<NNN>` IDs surfaced from `docs/problems/`, **Capture a new ticket** (delegate to `/wr-itil:capture-problem`), or **Defer (leave un-tracked for now)**.
  2. If a ticket ID is captured, write `human-oversight: rejected-pending-supersede` + `supersede-ticket: P<NNN>` into the ADR's frontmatter. The detector excludes ADRs carrying both, so the drain stops re-asking until either the supersede ADR lands (status flips to `superseded`) or the rejection is revisited.
  3. If the user defers ticket capture, leave the marker absent — the ADR re-surfaces next drain (the un-tracked case is intentionally re-asked so it doesn't silently rot).
- **Defer**: no write.

### Step 5: Commit + report

Commit the confirmed/amended ADRs per ADR-014 (one commit for the sitting's drained batch is acceptable — the unit of work is "this drain sitting"). Report: how many confirmed / amended / rejected / deferred, and the remaining unoversighted count (re-run the detector). The session-start nudge count drops by the number confirmed.

## Notes

- **Never re-ask** — a confirmed ADR carries the marker permanently and is excluded from future runs (ADR-009 never-re-ask principle). The same write-once-permanence applies to the `rejected-pending-supersede` value (P316 amendment): once the user rejects with a tracked ticket, the drain stops asking. The marker is write-once **except** when an ADR is materially amended after confirmation (the Decision Outcome is rewritten) — a supersede/amend clears it for re-confirmation per ADR-066 Reassessment. When the supersede ADR eventually lands and the original flips to `*.superseded.md`, the existing superseded-status skip takes over; the `rejected-pending-supersede` lines become historical residue (no active clearance required).
- **AFK** — this skill is interactive by construction (the confirm IS the human decision). It is not dispatched inside AFK iteration subprocesses; the session-start nudge self-suppresses there (`WR_SUPPRESS_OVERSIGHT_NUDGE=1`) so the drain is never half-run by an absent user.
- **Born-confirmed going forward** — `/wr-architect:create-adr` writes the marker at its Step 5 confirm, so new ADRs enter the set already oversighted and the unoversighted count only shrinks.

## Related

- **ADR-066** — the oversight marker + this drain skill + the detector + the nudge.
- **ADR-064** — the architect Needs-Direction verdict; the main agent owns `AskUserQuestion` (this skill is that ownership applied to the existing set).
- **ADR-009** — never-re-ask persistent-marker principle (the marker, not its TTL/drift lifecycle).
- **ADR-013 / ADR-044** — structured user interaction + decision-delegation taxonomy.
- **P283** — driving problem ticket (prong 2).
