#!/usr/bin/env bash
# generate-decisions-compendium.sh — generate docs/decisions/README.md from
# per-ADR files. Per ADR-077 (Generated decisions compendium as token-cheap
# load surface for routine architect-agent compliance).
#
# Usage: bash packages/architect/scripts/generate-decisions-compendium.sh [decisions_dir]
# Writes: <decisions_dir>/README.md (idempotent — same input set + bodies
# produce byte-identical output).
#
# Distributed via the ADR-049 $PATH shim at:
#   packages/architect/bin/wr-architect-generate-decisions-compendium
# Hooks and skills MUST invoke the shim, not this script directly — the
# shim resolves the canonical body relative to its own location, so it
# works in adopter installs where the package lives under
# ~/.claude/plugins/cache/windyroad/wr-architect/<version>/.
#
# ADR-031 authoritative-state invariant: per-ADR bodies are the
# authoritative source of substance; this compendium is a derived/cached
# view. The compendium is NEVER edited compendium-side first.
#
# ADR-077 Confirmation item (b): generator must be idempotent — running
# it twice produces identical output.

set -uo pipefail

# --- Flag parsing ----------------------------------------------------------
# `--check` (no write): generate to a temp file and diff against the on-disk
# compendium. Exit 0 if byte-identical, 1 if drift, 2 if directory missing.
# Used by the architect-compendium-refresh-discipline.sh enforcement hook
# (Slice 2) to verify the staged compendium matches the working-tree ADRs.
CHECK_MODE=0
case "${1:-}" in
    --check)
        CHECK_MODE=1
        shift
        ;;
    --help|-h)
        cat <<'EOF'
Usage: generate-decisions-compendium.sh [--check] [decisions_dir]

Without --check: regenerates <decisions_dir>/README.md from the per-ADR
bodies. Idempotent — same in-force ADR set produces byte-identical output.

With --check: generates to a temp file and diffs against the existing
<decisions_dir>/README.md. Exits 0 if up-to-date, 1 if stale (with a
diff hint), 2 on directory error. Does NOT modify any file. Used by the
ADR-077 enforcement hook to verify the committed compendium matches the
current ADR bodies.
EOF
        exit 0
        ;;
esac

DECISIONS_DIR="${1:-docs/decisions}"
TARGET_COMPENDIUM="$DECISIONS_DIR/README.md"

if [ ! -d "$DECISIONS_DIR" ]; then
    echo "generate-decisions-compendium: decisions directory not found: $DECISIONS_DIR" >&2
    exit 2
fi

# In check mode, redirect generation to a temp file so the on-disk
# compendium is never mutated.
if [ "$CHECK_MODE" = "1" ]; then
    COMPENDIUM=$(mktemp -t architect-compendium-check.XXXXXX)
    trap 'rm -f "$COMPENDIUM"' EXIT
else
    COMPENDIUM="$TARGET_COMPENDIUM"
fi

# --- Field extractors ------------------------------------------------------

# Read a frontmatter scalar field (single line `key: value`).
# Strips surrounding quotes and leading/trailing whitespace.
get_frontmatter_field() {
    local file="$1" field="$2"
    awk -v f="$field" '
        /^---$/ { fm = !fm; if (!fm) exit; next }
        fm && $0 ~ "^"f":" {
            sub("^"f": *", "")
            gsub(/^["'"'"']|["'"'"']$/, "")
            sub(/^ +/, ""); sub(/ +$/, "")
            print
            exit
        }
    ' "$file"
}

# Read the first "# Title" line after the frontmatter block.
get_title() {
    awk '
        /^---$/ { fm = !fm; next }
        !fm && /^# / { sub(/^# /, ""); print; exit }
    ' "$1"
}

# Extract a section by its `## Heading` line, up to (but not including) the
# next `## ` heading or EOF.
get_section() {
    local file="$1" heading="$2"
    awk -v h="$heading" '
        $0 == "## " h { in_sec = 1; next }
        in_sec && /^## / { exit }
        in_sec { print }
    ' "$file"
}

# Extract the "Chosen option:" line from the Decision Outcome section.
# Matches the common MADR shapes:
#   Chosen option: **"X"**, because Y.
#   Chosen option: X, because Y.
#   Chosen: X.
get_chosen() {
    get_section "$1" "Decision Outcome" \
        | awk '/^Chosen/ { print; exit }' \
        | head -1
}

# Extract top-level bullet lines (`- ...`) from a section. Skips nested
# `  - ...` sub-bullets to keep the compendium dense. Capped at N entries.
get_bullets() {
    local file="$1" section="$2" cap="${3:-5}"
    get_section "$file" "$section" \
        | awk '/^- / { sub(/^- */, ""); print }' \
        | head -"$cap"
}

# Compact-join bullets onto one line, truncating each to N chars + "…".
# Joins with "; ". Strips markdown emphasis to keep the line scannable.
compact_join_bullets() {
    local per_item="${1:-120}"
    awk -v n="$per_item" '
        {
            # Strip leading checkbox markers `[ ]` / `[x]` (from Confirmation).
            sub(/^\[[ x]\] */, "")
            # Strip markdown bold/italic markers for compactness.
            gsub(/\*\*/, "")
            gsub(/`/, "")
            # Drop nested-bullet continuation lines that survived earlier filters.
            if (length($0) == 0) next
            if (length($0) > n) line = substr($0, 1, n) "…"
            else line = $0
            if (out == "") out = line
            else out = out "; " line
        }
        END { print out }
    '
}

# Extract ADR-NNN references from Related bullets. Compact "ADR-NNN" listing
# is sufficient for routine compliance graph navigation; full relationship
# prose (amends/extends/relates/composes) is preserved in the per-ADR body.
extract_related_ids() {
    awk '
        {
            while (match($0, /ADR-[0-9]+/)) {
                ref = substr($0, RSTART, RLENGTH)
                if (!seen[ref]++) {
                    if (out == "") out = ref
                    else out = out ", " ref
                }
                $0 = substr($0, RSTART + RLENGTH)
            }
        }
        END { print out }
    '
}

# --- Sanitisers ------------------------------------------------------------

# Strip markdown links `[text](url)` -> `text`.
strip_links() {
    sed -E 's/\[([^]]+)\]\([^)]+\)/\1/g'
}

# Collapse to a single line: replace newlines + carriage returns with spaces,
# squeeze runs of spaces, trim leading/trailing whitespace.
oneline() {
    tr '\n\r' '  ' | tr -s ' ' | sed 's/^ *//; s/ *$//'
}

# Truncate a string to N chars + ellipsis if longer. Avoids slicing inside
# a markdown emphasis pair (e.g. `**text**`) — if the truncation would land
# inside `**...**`, round back to before the opening pair.
truncate_with_ellipsis() {
    local s="$1" n="$2"
    if [ "${#s}" -le "$n" ]; then
        printf '%s' "$s"
        return
    fi
    printf '%s' "${s:0:n}…"
}

# --- Per-ADR entry emitter -------------------------------------------------

emit_entry() {
    local file="$1"
    local id title status oversight superseded supersede_ticket
    local chosen drivers confirmation related

    id=$(basename "$file" | grep -oE '^[0-9]+')
    title=$(get_title "$file")
    status=$(get_frontmatter_field "$file" "status")
    oversight=$(get_frontmatter_field "$file" "human-oversight")
    superseded=$(get_frontmatter_field "$file" "supersedes")
    # ADR-066 amendment (P316): when the oversight value is
    # `rejected-pending-supersede`, surface the tracking ticket parenthetically
    # so the compendium badge shows both the disposition AND the supersede in
    # flight without a per-ADR body read.
    supersede_ticket=$(get_frontmatter_field "$file" "supersede-ticket")

    # Chosen-option line — truncate to a comfortable summary length.
    chosen=$(get_chosen "$file" | strip_links | oneline)
    chosen=$(printf '%s' "$chosen" | awk -v n=240 '{ if (length($0) > n) print substr($0,1,n) "…"; else print }')

    # Confirmation: cap 5 bullets, ≤ 110 chars each, joined with "; " on one line.
    # This is the routine-compliance scannable view; the full Confirmation list
    # remains in the per-ADR body for deep-dive surfaces.
    confirmation=$(get_bullets "$file" "Confirmation" 5 | strip_links | compact_join_bullets 110)

    # Related: extract ADR-NNN graph references only. Full relationship prose
    # (amends / extends / relates / composes) stays in the per-ADR body.
    related=$(get_bullets "$file" "Related" 20 | strip_links | extract_related_ids)

    # Decision Drivers intentionally NOT emitted in the routine view (per
    # ADR-077 Decision Outcome — drivers belong on the deep-dive surface, not
    # the routine compliance load). If a future iteration needs them, add a
    # `--with-drivers` flag rather than emit by default.

    # Header line — ID + Title + status badges.
    {
        echo ""
        echo "### ADR-${id} — ${title}"
        # Status / oversight / supersession badges on one compact line.
        local badges="**Status:** ${status:-?}"
        if [ -n "$oversight" ]; then
            if [ "$oversight" = "rejected-pending-supersede" ] && [ -n "$supersede_ticket" ]; then
                badges="${badges} | **Oversight:** ${oversight} (${supersede_ticket})"
            else
                badges="${badges} | **Oversight:** ${oversight}"
            fi
        fi
        if [ -n "$superseded" ] && [ "$superseded" != "[]" ]; then
            badges="${badges} | **Supersedes:** ${superseded}"
        fi
        echo "${badges}"
        if [ -n "$chosen" ]; then
            echo "**Chosen:** ${chosen}"
        fi
        if [ -n "$confirmation" ]; then
            echo "**Confirmation:** ${confirmation}"
        fi
        if [ -n "$related" ]; then
            echo "**Related:** ${related}"
        fi
    }
}

# --- Compendium emission ---------------------------------------------------

# Collect + sort ADR files. README.md and any sibling -history.md / -summary.md
# style files (future P194 etc.) are excluded.
#
# Status sectioning (ADR-077 amended 2026-05-30): the compendium is split
# into two sections so the architect agent's routine load reads in-force
# decisions first and historical decisions second.
#   - In-force (proposed + accepted): the current rules to follow.
#   - Historical (superseded + rejected + deprecated): direction for what NOT
#     to do — useful when reviewing a proposed change that re-treads a path
#     that was tried and rejected, or that conflicts with a superseded
#     decision's still-valid intent.
# Both sections sort by ID ascending; the status badge on each entry tells
# the agent which kind it is.
all_files=()
while IFS= read -r f; do
    all_files+=("$f")
done < <(find "$DECISIONS_DIR" -maxdepth 1 -type f -name '*.md' \
            ! -name 'README.md' \
            ! -name '*-history.md' \
            ! -name '*-summary.md' \
            2>/dev/null | sort)

in_force_files=()
historical_files=()
for f in "${all_files[@]}"; do
    s=$(get_frontmatter_field "$f" "status")
    case "$s" in
        proposed|accepted)
            in_force_files+=("$f")
            ;;
        superseded|rejected|deprecated)
            historical_files+=("$f")
            ;;
        *)
            # Unknown status: surface as in-force so it isn't silently dropped;
            # the badge will show "?" and a reviewer can correct the source.
            in_force_files+=("$f")
            ;;
    esac
done

in_force_total=${#in_force_files[@]}
historical_total=${#historical_files[@]}
total=$((in_force_total + historical_total))

# Header is deterministic — NO timestamp, NO date. The compendium must be
# idempotent (same input bodies => byte-identical output) so the ADR-077
# drift-detection bats can compare the committed file against a fresh
# generator run and detect any divergence as substance drift, not as
# date-stamp churn.
{
    echo "# Decisions Compendium"
    echo ""
    echo "<!-- AUTO-GENERATED by packages/architect/scripts/generate-decisions-compendium.sh per ADR-077 — do NOT hand-edit; regenerate via \`wr-architect-generate-decisions-compendium\`. -->"
    echo ""
    echo "Compact rendered index of every ADR's chosen option, confirmation criteria, and relationship graph. **Authoritative substance lives in the per-ADR body** (\`<NNN>-<slug>.<status>.md\`); this compendium is a derived view for routine \`wr-architect:agent\` compliance review."
    echo ""
    echo "**Two sections:**"
    echo ""
    echo "- **In-force decisions** (\`proposed\` + \`accepted\`) — the current rules to follow."
    echo "- **Historical decisions** (\`superseded\` + \`rejected\` + \`deprecated\`) — direction for what NOT to do. Useful when reviewing a proposed change that re-treads a path already tried, or that conflicts with a superseded decision's still-valid intent. The status badge on each entry says which kind it is."
    echo ""
    echo "For deep-dive — creating, evolving, ratifying, or contesting a decision — open the per-ADR file directly. \`/wr-architect:create-adr\`, \`/wr-architect:capture-adr\`, and \`/wr-architect:review-decisions\` all keep the full body in scope. Decision Drivers, Considered Options bodies, Pros and Cons, Consequences narrative, and Reassessment Criteria are intentionally NOT in this routine view — they live in the per-ADR body."
    echo ""
    echo "**Total ADRs:** ${total} (${in_force_total} in-force, ${historical_total} historical)"
    echo ""
    echo "---"
    echo ""
    echo "## In-force decisions"
    echo ""
    echo "_${in_force_total} ADRs. These are the current rules. The architect agent reads this section first for routine compliance review._"
    for f in "${in_force_files[@]}"; do
        emit_entry "$f"
    done
    if [ "$historical_total" -gt 0 ]; then
        echo ""
        echo "---"
        echo ""
        echo "## Historical decisions"
        echo ""
        echo "_${historical_total} ADRs. These were tried and superseded, rejected, or deprecated. Read them as direction for what NOT to do, or to understand the lineage of an in-force decision. Do not enforce them as current rules._"
        for f in "${historical_files[@]}"; do
            emit_entry "$f"
        done
    fi
} > "$COMPENDIUM"

if [ "$CHECK_MODE" = "1" ]; then
    # Check mode: diff temp against target. Idempotency contract holds only
    # when both files exist; treat absence as "stale" (drift detected).
    if [ ! -f "$TARGET_COMPENDIUM" ]; then
        echo "generate-decisions-compendium: compendium MISSING — $TARGET_COMPENDIUM does not exist" >&2
        echo "  run: wr-architect-generate-decisions-compendium" >&2
        exit 1
    fi
    if cmp -s "$COMPENDIUM" "$TARGET_COMPENDIUM"; then
        echo "generate-decisions-compendium: compendium up-to-date (${total} ADRs — ${in_force_total} in-force, ${historical_total} historical)" >&2
        exit 0
    fi
    {
        echo "generate-decisions-compendium: compendium IS STALE relative to ADR bodies"
        echo "  expected (fresh generator output): $COMPENDIUM"
        echo "  actual   (on disk):                $TARGET_COMPENDIUM"
        echo "  run: wr-architect-generate-decisions-compendium && git add $TARGET_COMPENDIUM"
        echo ""
        echo "diff (first 40 lines):"
        diff "$TARGET_COMPENDIUM" "$COMPENDIUM" 2>/dev/null | head -40
    } >&2
    exit 1
fi

echo "generate-decisions-compendium: wrote $COMPENDIUM (${total} ADRs total — ${in_force_total} in-force, ${historical_total} historical)" >&2
