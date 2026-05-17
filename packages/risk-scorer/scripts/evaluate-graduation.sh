#!/usr/bin/env bash
# packages/risk-scorer/scripts/evaluate-graduation.sh
#
# Evaluates held-changeset graduation candidates per ADR-061
# (Dogfood graduation criteria for held changesets — symmetric risk balance).
#
# Phase 2a — orthogonal-gate class (Class 3a per ADR-061 Rule 3): deterministic
# Rule 1a join + Rule 2 VP carve-out detection per changeset, independently.
#
# Phase 2b — atomic-cohort class (Class 3b per ADR-061 Rule 3b): parses
# docs/changesets-holding/README.md "Currently held" section, groups entries
# by shared reinstate-trigger prose (parenthetical elaborations stripped
# before grouping), and emits cohort-aware candidates. Cohort priority is
# max(Priority) across all member tickets; any VP-blocked or halt-no-resolution
# member propagates atomically to the entire cohort ("entire cohort ships or
# none does" — symmetric to Rule 2's per-changeset carve-out at cohort grain).
# Single-member "cohorts" fall back to class=3a (no Phase 2a regression).
#
# This script implements deterministic Rule 1a join + Rule 2 VP carve-out
# detection + Rule 3b cohort grouping. It does NOT compute release-risk and
# does NOT apply Rule 4 evidence-floor judgement — those are LLM-judgement
# surfaces owned by the wr-risk-scorer:pipeline agent (per ADR-015 pure-scorer
# contract).
#
# Cohort-id-from-prose is the Phase 2b shape per architect approval 2026-05-17.
# Reassessment Triggers in ADR-061 ("Manual graduations diverge from criterion
# verdicts") cover the upgrade to a structured cohort-declaration field if
# prose-shape brittleness appears in dogfood.
#
# Usage:
#   evaluate-graduation.sh [<project-root>]
#
# Default <project-root> is $(pwd).
#
# Behaviour:
#   - Globs docs/changesets-holding/*.md (excludes README.md).
#   - For each held changeset, applies Rule 1a join:
#       1. Filename convention (primary): <package>-p<NNN>-<slug>.md → P<NNN>
#       2. Body grep fallback (secondary): grep '\bP[0-9]+\b' in changeset body
#       3. Multi-ticket: max(Priority) across the referenced set
#   - Resolves the ticket file via dual-tolerant glob (ADR-031 + RFC-002):
#       docs/problems/<NNN>-*.md (flat) AND docs/problems/*/<NNN>-*.md (per-state)
#   - Extracts the Priority value from the ticket's `**Priority**: N (...)` line.
#   - Detects Rule 2 VP carve-out (ticket file ends in .verifying.md).
#   - Parses docs/changesets-holding/README.md "Currently held" section and
#     groups entries by normalised reinstate-trigger prose (Phase 2b).
#   - Multi-member groups emit class=3b + cohort=<id> with cohort-level
#     priority/status. Single-member groups emit class=3a unchanged.
#   - Emits one structured candidate line per held changeset to stdout.
#
# Stdout format — Class 3a (one candidate per held changeset, agent-parseable):
#   GRADUATION_CANDIDATE: changeset=<filename> | ticket=P<NNN> | priority=<N> | class=3a | status=<resolved|vp-blocked|halt-no-resolution>
#
# Stdout format — Class 3b (cohort member; cohort= column added between class and status):
#   GRADUATION_CANDIDATE: changeset=<filename> | ticket=P<NNN> | priority=<cohort-max-N> | class=3b | cohort=<id> | status=<resolved|vp-blocked|halt-no-resolution>
#
# Stdout summary line at end (member-level counts; cohorts count individually):
#   GRADUATION_SUMMARY: total=<N> resolved=<N> vp_blocked=<N> halts=<N>
#
# Exit codes:
#   0 — script ran to completion (any number of halts is still exit 0;
#       halts surface via per-candidate status=halt-no-resolution lines so
#       the agent can present them as Rule 1a halt-and-prompt candidates)
#   1 — no holding-area or empty holding-area (no-op caller signal)
#   2 — invalid project root (missing docs/)
#
# @adr ADR-061 (graduation criteria — Phase 2a Rule 1a join + Rule 2 VP carve-out;
#               Phase 2b Rule 3b atomic-cohort grouping + cohort-level propagation)
# @adr ADR-049 (resolved via bin/wr-risk-scorer-evaluate-graduation shim)
# @adr ADR-052 (behavioural-fixture coverage at scripts/test/evaluate-graduation.bats)
# @adr ADR-015 (pure-scorer contract — script does deterministic join + grouping;
#               agent owns release-risk re-computation + evidence-floor judgement)
# @adr ADR-031 (dual-tolerant problem-ticket layout per RFC-002 migration window)
# @problem P162 (Phase 2a + Phase 2b)

set -uo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
HOLDING_DIR="${PROJECT_ROOT}/docs/changesets-holding"
PROBLEMS_DIR="${PROJECT_ROOT}/docs/problems"

if [ ! -d "${PROJECT_ROOT}/docs" ]; then
  echo "GRADUATION_ERROR: invalid project root (missing docs/): ${PROJECT_ROOT}" >&2
  exit 2
fi

if [ ! -d "$HOLDING_DIR" ]; then
  echo "GRADUATION_SUMMARY: total=0 resolved=0 vp_blocked=0 halts=0"
  exit 1
fi

# Enumerate held changesets (exclude README.md). Use null-delim shape so
# filenames-with-spaces never break iteration (defensive even though our
# convention is kebab-case).
HELD_FILES=()
while IFS= read -r -d '' f; do
  base=$(basename "$f")
  if [ "$base" = "README.md" ]; then
    continue
  fi
  HELD_FILES+=("$f")
done < <(find "$HOLDING_DIR" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)

if [ "${#HELD_FILES[@]}" -eq 0 ]; then
  echo "GRADUATION_SUMMARY: total=0 resolved=0 vp_blocked=0 halts=0"
  exit 1
fi

# Delegate the per-candidate join + VP-check + cohort grouping to python for
# re-readable regex + dual-layout glob handling.
EVAL_RESULT=$(python3 - "$HOLDING_DIR" "$PROBLEMS_DIR" "${HELD_FILES[@]}" <<'PYEOF'
import os
import re
import sys
import glob

holding_dir = sys.argv[1]
problems_dir = sys.argv[2]
held_files = sys.argv[3:]

FILENAME_TICKET_RE = re.compile(r'-p(\d+)-', re.IGNORECASE)
BODY_TICKET_RE = re.compile(r'\bP(\d+)\b')
PRIORITY_LINE_RE = re.compile(r'^\*\*Priority\*\*:\s*(\d+)\b')

# Phase 2b — README "Currently held" bullet parser.
# Matches `- \`<filename>\` ... **Reinstate trigger**: <trigger-text>`.
# Captures the filename (group 1) and the trigger text (group 2; rest of line).
README_BULLET_RE = re.compile(
    r'^-\s+`([^`]+\.md)`\s+.*?\*\*Reinstate trigger\*\*:\s*(.+?)\s*$'
)
# Strip parenthetical elaborations before grouping; nested parens are out of
# scope for Phase 2b (no observed README entry uses them in the trigger).
PAREN_RE = re.compile(r'\([^()]*\)')
# Sanitise cohort-id from normalised trigger prose.
NON_ID_CHAR_RE = re.compile(r'[^a-z0-9]+')


def find_ticket_file(ticket_id_padded: str):
    """Dual-tolerant glob per ADR-031 / RFC-002 migration window.

    Returns (path, status_suffix) where status_suffix is one of
    'open', 'known-error', 'verifying', 'closed', 'parked' or None
    if no file resolves.
    """
    # Per-state subdir layout
    for state in ('open', 'known-error', 'verifying', 'closed', 'parked'):
        candidates = glob.glob(os.path.join(problems_dir, state, f'{ticket_id_padded}-*.md'))
        if candidates:
            return candidates[0], state
    # Flat layout
    for state in ('open', 'known-error', 'verifying', 'closed', 'parked'):
        candidates = glob.glob(os.path.join(problems_dir, f'{ticket_id_padded}-*.{state}.md'))
        if candidates:
            return candidates[0], state
    return None, None


def extract_priority(ticket_path: str):
    """Read the `**Priority**: N (...)` line and return integer N, or None."""
    try:
        with open(ticket_path, 'r', encoding='utf-8') as f:
            for line in f:
                m = PRIORITY_LINE_RE.match(line.strip())
                if m:
                    return int(m.group(1))
    except (OSError, IOError):
        return None
    return None


def resolve_ticket_ids(changeset_path: str):
    """Apply Rule 1a join: filename convention primary, body-grep fallback.

    Returns a list of zero-padded ticket IDs (e.g. ['085']) referenced by
    this changeset. Empty list means halt-no-resolution per Rule 1a terminal.
    """
    basename = os.path.basename(changeset_path)
    # Primary: filename convention
    filename_match = FILENAME_TICKET_RE.search(basename)
    if filename_match:
        return [f'{int(filename_match.group(1)):03d}']

    # Fallback: body grep for P\d+ references
    try:
        with open(changeset_path, 'r', encoding='utf-8') as f:
            body = f.read()
    except (OSError, IOError):
        return []

    body_matches = BODY_TICKET_RE.findall(body)
    if not body_matches:
        return []

    # De-duplicate while preserving order; zero-pad
    seen = set()
    ids = []
    for raw_id in body_matches:
        padded = f'{int(raw_id):03d}'
        if padded not in seen:
            seen.add(padded)
            ids.append(padded)
    return ids


def normalise_trigger(trigger_text: str) -> str:
    """Normalise reinstate-trigger prose for cohort-key comparison.

    Strips parenthetical elaborations (Reassessment criterion citations,
    inline notes), takes the prefix up to the first em-dash separator
    (typical for "trigger description — review at ..." continuations),
    strips trailing punctuation, lowercases, and collapses whitespace
    LAST so paren-strip artefacts (stray spaces before punctuation) do
    not break equality matching.
    """
    # Strip parentheticals; loop in case there are multiple non-nested groups.
    prior = None
    cleaned = trigger_text
    while cleaned != prior:
        prior = cleaned
        cleaned = PAREN_RE.sub('', cleaned)
    # Take prefix up to first em-dash separator (continuations begin here).
    cleaned = cleaned.split('—', 1)[0]  # em-dash U+2014
    # Lowercase, strip surrounding whitespace + trailing punctuation; collapse
    # whitespace LAST so paren-strip leaves no orphaned single spaces before
    # punctuation that would defeat equality comparison.
    cleaned = cleaned.lower().strip().rstrip('.,;:').strip()
    cleaned = ' '.join(cleaned.split())
    # Strip any trailing punctuation that was previously space-separated.
    cleaned = cleaned.rstrip('.,;:').strip()
    return cleaned


def cohort_id_from_trigger(normalised: str) -> str:
    """Compute a filename-safe cohort id from normalised trigger prose.

    Takes the first 8 tokens, replaces non-alphanumeric runs with single
    dashes, trims surrounding dashes, caps at 60 chars.
    """
    tokens = normalised.split()[:8]
    joined = ' '.join(tokens)
    slug = NON_ID_CHAR_RE.sub('-', joined).strip('-')
    return slug[:60] if slug else 'cohort'


def parse_currently_held_cohorts(holding_dir: str):
    """Parse docs/changesets-holding/README.md to build a filename→cohort-id map.

    Reads only entries within the "## Currently held" section (case-insensitive),
    extracts each bullet's filename + trigger text, normalises triggers, and
    groups filenames sharing an identical normalised trigger. Cohorts with ≥ 2
    members are returned as {filename: cohort_id}; single-member groups are
    omitted so they fall back to class=3a per Phase 2a semantics.

    Returns {} when README missing OR "Currently held" section absent OR no
    multi-member groups present.
    """
    readme_path = os.path.join(holding_dir, 'README.md')
    if not os.path.isfile(readme_path):
        return {}
    try:
        with open(readme_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except (OSError, IOError):
        return {}

    # Walk lines; track whether we're inside the "Currently held" section.
    in_section = False
    bullets = []  # list of (filename, normalised_trigger)
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('## '):
            heading = stripped[3:].strip().lower()
            in_section = (heading == 'currently held')
            continue
        if not in_section:
            continue
        match = README_BULLET_RE.match(line.rstrip('\n'))
        if not match:
            continue
        filename = match.group(1)
        trigger = match.group(2)
        normalised = normalise_trigger(trigger)
        if not normalised:
            continue
        bullets.append((filename, normalised))

    # Group bullets by normalised trigger.
    groups = {}
    for filename, normalised in bullets:
        groups.setdefault(normalised, []).append(filename)

    # Keep only multi-member groups; compute cohort id.
    cohort_map = {}
    for normalised, members in groups.items():
        if len(members) < 2:
            continue
        cohort_id = cohort_id_from_trigger(normalised)
        for filename in members:
            cohort_map[filename] = cohort_id
    return cohort_map


# Per-changeset resolution structure:
#   {basename: {ticket: 'P<NNN>'|'-', priority: <int>|None, status: <str>,
#               ticket_ids: [<padded>], chosen_suffix: <str>|None}}
per_changeset = {}

for changeset_path in held_files:
    basename = os.path.basename(changeset_path)
    ticket_ids = resolve_ticket_ids(changeset_path)

    if not ticket_ids:
        per_changeset[basename] = {
            'ticket_label': '-',
            'priority': None,
            'status': 'halt-no-resolution',
        }
        continue

    resolutions = []
    for tid in ticket_ids:
        path, suffix = find_ticket_file(tid)
        if path is None:
            continue
        priority = extract_priority(path)
        if priority is None:
            continue
        resolutions.append((tid, priority, suffix))

    if not resolutions:
        per_changeset[basename] = {
            'ticket_label': ','.join(f'P{i}' for i in ticket_ids),
            'priority': None,
            'status': 'halt-no-resolution',
        }
        continue

    resolutions.sort(key=lambda r: r[1], reverse=True)
    chosen_tid, chosen_priority, chosen_suffix = resolutions[0]
    if chosen_suffix == 'verifying':
        per_changeset[basename] = {
            'ticket_label': f'P{chosen_tid}',
            'priority': chosen_priority,
            'status': 'vp-blocked',
        }
        continue

    per_changeset[basename] = {
        'ticket_label': f'P{chosen_tid}',
        'priority': chosen_priority,
        'status': 'resolved',
    }

# Phase 2b — cohort detection.
cohort_map = parse_currently_held_cohorts(holding_dir)
# Build inverse: cohort_id → [member basenames].
cohort_members = {}
for filename, cohort_id in cohort_map.items():
    cohort_members.setdefault(cohort_id, []).append(filename)

# Compute cohort-level rollups (priority + status).
# Atomic propagation: any halt → cohort halts; else any vp-blocked → cohort
# vp-blocked; else cohort resolved. Cohort priority = max(member priority)
# across resolved/vp-blocked members; '-' when all members halted.
cohort_rollup = {}
for cohort_id, members in cohort_members.items():
    statuses = []
    priorities = []
    for filename in members:
        # Only consider members that are actually in the holding-area glob;
        # README may list entries that no longer exist on disk (stale README).
        info = per_changeset.get(filename)
        if info is None:
            continue
        statuses.append(info['status'])
        if info['priority'] is not None:
            priorities.append(info['priority'])

    if not statuses:
        # No cohort members are real held files; skip cohort treatment.
        continue
    if 'halt-no-resolution' in statuses:
        cohort_status = 'halt-no-resolution'
    elif 'vp-blocked' in statuses:
        cohort_status = 'vp-blocked'
    else:
        cohort_status = 'resolved'
    cohort_priority = max(priorities) if priorities else None
    cohort_rollup[cohort_id] = {
        'status': cohort_status,
        'priority': cohort_priority,
    }

# Emit candidate lines in held_files order.
total = 0
resolved = 0
vp_blocked = 0
halts = 0

for changeset_path in held_files:
    total += 1
    basename = os.path.basename(changeset_path)
    info = per_changeset[basename]
    cohort_id = cohort_map.get(basename)
    is_cohort = cohort_id is not None and cohort_id in cohort_rollup

    if is_cohort:
        rollup = cohort_rollup[cohort_id]
        # Use cohort-level priority + status; ticket_label remains member-local
        # so audit trail still cites the specific resolved ticket.
        priority_str = '-' if rollup['priority'] is None else str(rollup['priority'])
        ticket_label = info['ticket_label']
        status = rollup['status']
        print(
            f'GRADUATION_CANDIDATE: changeset={basename} | ticket={ticket_label} | '
            f'priority={priority_str} | class=3b | cohort={cohort_id} | status={status}'
        )
    else:
        priority_str = '-' if info['priority'] is None else str(info['priority'])
        print(
            f'GRADUATION_CANDIDATE: changeset={basename} | ticket={info["ticket_label"]} | '
            f'priority={priority_str} | class=3a | status={info["status"]}'
        )

    # Tally member-level counts (cohorts count per-member for backward compat).
    effective_status = cohort_rollup[cohort_id]['status'] if is_cohort else info['status']
    if effective_status == 'resolved':
        resolved += 1
    elif effective_status == 'vp-blocked':
        vp_blocked += 1
    elif effective_status == 'halt-no-resolution':
        halts += 1

print(f'GRADUATION_SUMMARY: total={total} resolved={resolved} vp_blocked={vp_blocked} halts={halts}')
PYEOF
)
PY_STATUS=$?

echo "$EVAL_RESULT"

if [ "$PY_STATUS" -ne 0 ]; then
  exit "$PY_STATUS"
fi

exit 0
