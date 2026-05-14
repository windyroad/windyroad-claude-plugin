---
name: wr-voice-tone:assess-external-comms
description: On-demand external-comms voice & tone review. Reviews a draft of an outbound prose tool call (gh issue/pr body, security advisory, npm publish content, or .changeset/*.md body) against docs/VOICE-AND-TONE.md. Delegates to wr-voice-tone:external-comms and pre-satisfies the external-comms-gate marker for the current session.
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion, Skill
---

# External-Comms Voice & Tone Assessment Skill

Run a voice & tone review on demand against any drafted outbound prose — outside a hook gate trigger. Pre-satisfies the `external-comms-gate.sh` marker for the current session so the gated tool call (gh issue/pr/api/npm publish/changeset write) proceeds without re-prompting.

This skill is **read-only**. It does not commit, push, or modify files. The marker is written automatically by the `PostToolUse:Agent` hook (`external-comms-mark-reviewed.sh`) after the subagent completes — the skill never writes to `${TMPDIR:-/tmp}/claude-risk-*` directly.

This is the voice-tone half of the external-comms gate. The risk/leak half is handled by `/wr-risk-scorer:assess-external-comms`. When both plugins are installed, both evaluators must PASS independently before the gate permits the tool call.

## When to use

- Before drafting a `gh issue create` / `gh pr create` / `gh issue comment` / `gh pr comment` to a third-party repo.
- Before drafting a `gh api .../security-advisories` body for a vendor private channel.
- Before authoring a `.changeset/*.md` body that will land in CHANGELOG.md and every published npm tarball (P073).
- Before `npm publish` when the README diff is non-trivial.
- After hitting the external-comms gate's deny-and-delegate prompt: this skill is the structured walkthrough that closes the voice-tone loop.

## Steps

### 1. Parse arguments

Read `$ARGUMENTS` for either:

- A draft body verbatim (e.g. the user pastes the prose they're about to post).
- A surface hint (`gh-issue-create`, `gh-pr-comment`, `gh-api-security-advisories`, `gh-issue-edit`, `gh-pr-edit`, `gh-issue-comment`, `gh-pr-create`, `gh-api-comments`, `npm-publish`, `changeset-author`).
- A destination hint (`anthropics/claude-code#52831`, `vendor private channel`, `npm public registry`).

If both draft and surface are present, proceed to step 3. If either is missing, step 2.

### 2. Resolve missing context

If the draft is missing, use `AskUserQuestion`:

> "What draft do you want me to review? Paste the body verbatim — I will pass it to the external-comms voice-tone reviewer."

If the surface is missing AND cannot be inferred from context (e.g. user just said "before I post this comment"), use `AskUserQuestion`:

- header: "Target surface"
- options:
  1. `gh issue create` (public third-party repo)
  2. `gh issue comment` (public third-party repo)
  3. `gh pr create` / `gh pr comment` (public third-party repo)
  4. `gh api .../security-advisories` (vendor private channel)
  5. `npm publish` (permanently published artefact)
  6. `.changeset/*.md` (lands in CHANGELOG + Release PR + every npm tarball)

Do not ask if the surface is obvious from the conversation context.

### 3. Construct the review prompt

Build a self-contained prompt for the `wr-voice-tone:external-comms` subagent that includes:

- The **draft body** verbatim (between explicit `<draft>...</draft>` markers so the agent's substring extraction is unambiguous).
- The **target surface** (one of the canonical strings above).
- The **destination** when known.
- A reminder to compute `EXTERNAL_COMMS_VOICE_TONE_KEY = sha256(draft + '\n' + surface)`.

### 4. Delegate to wr-voice-tone:external-comms

Invoke the subagent via the `Skill` tool:

```
subagent_type: wr-voice-tone:external-comms
prompt: <constructed review prompt from step 3>
```

Wait for the subagent to complete. The subagent will output a structured verdict block (`EXTERNAL_COMMS_VOICE_TONE_VERDICT: PASS|FAIL` + `EXTERNAL_COMMS_VOICE_TONE_KEY: <sha>` + optional `EXTERNAL_COMMS_VOICE_TONE_REASON: ...`). The `PostToolUse:Agent` hook (`external-comms-mark-reviewed.sh`) reads that output and writes the per-evaluator marker automatically.

**Do not write to `${TMPDIR:-/tmp}/claude-risk-*` yourself.** The hook is the only correct mechanism.

### 5. Present results

Present the full review report to the user. Highlight:

- The verdict (PASS / FAIL).
- Each `docs/VOICE-AND-TONE.md` section / principle / banned-pattern entry the draft violated (FAIL only).
- The exact substrings that triggered each finding (FAIL only).
- Whether the voice-tone gate is now pre-satisfied for the current session for this exact draft+surface key (PASS only): "The next attempt to <surface> with this draft body will proceed past the voice-tone evaluator without re-prompting."

When both evaluators are required (voice-tone + risk-scorer both installed), remind the user that the risk-scorer evaluator may still need its own delegation (run `/wr-risk-scorer:assess-external-comms`) before the gate fully permits.

### 6. Above-appetite handling (ADR-013 Rule 6)

If the verdict is FAIL, do NOT auto-rewrite the draft. Use `AskUserQuestion`:

- header: "Voice/tone violation — next step"
- options:
  1. `Rewrite the draft and re-review` — return to step 1 with the rewritten body.
  2. `Override anyway` — set `BYPASS_RISK_GATE=1` for the next gated tool call. Reserved for cases where the user has confirmed the content is acceptable as-drafted (e.g. an explicitly informal context the guide doesn't cover).
  3. `Cancel` — abandon the post.

Do not make the decision unilaterally — per ADR-013 Rule 1, all voice-tone judgement calls outside hard rules belong to the user.

$ARGUMENTS
