#!/usr/bin/env bash
# packages/itil/scripts/plugin-maturity-render.sh
#
# Phase 3b (P087 / P238) plugin-maturity README renderer.
#
# Reads each `packages/<plugin>/.claude-plugin/plugin.json` `maturity:`
# field (populated by Phase 3a `wr-itil-plugin-maturity-populate`) and
# writes:
#
#   1. Prose-woven rollup badge into the README.md value-framing lead
#      prose line (the first **bold** line after the H1). Format:
#        Post-bootstrap: `*Maturity: <Band>.*`
#        Bootstrapping window: `*Maturity: <Band> (suite-bootstrap window;
#                              <N> invocations / 30d).*`
#      Markdown text only — no shields.io URL, no inline SVG (ADR-063
#      §README badge rendering format).
#
#   2. Per-skill `Maturity` column populated in the existing `## Skills`
#      table. Cell value is band name only (no compound — compound stays
#      at the rollup per ADR-063). Adds the column header on first run;
#      replaces cell values on subsequent runs.
#
# Idempotent: re-running with unchanged plugin.json + README produces
# byte-identical README output. Replaces existing `*Maturity: ...*` span
# rather than appending.
#
# Anti-patterns enforced (ADR-063 §Decision Outcome §"README badge
# rendering format" + §"Bootstrapping clause rendering"):
#   - NEVER emit a standalone `## Maturity` section
#   - NEVER emit a header block immediately after H1 before any prose
#   - NEVER emit a shields.io URL or inline SVG
#   - Compound rendering stays at rollup only — per-skill cell carries
#     band name only
#
# ADR-044 silent-framework carve-out: band has already been computed by
# Phase 3a per ADR-053 §promotion criteria; the renderer is mechanical
# and never invokes AskUserQuestion.
#
# Usage:
#   wr-itil-plugin-maturity-render
#     [--project-root=PATH]   # default: $PWD
#     [--dry-run]             # print diff to stdout, do not write
#
# Exit codes:
#   0 = always — ADR-013 Rule 6 fail-safe. Missing packages/ / opt-out
#                marker / missing plugin.json / missing README / missing
#                maturity field all hit no-write stderr-comment paths.
#
# Privacy (ADR-035 clauses adopted verbatim):
#   - Opt-out marker `.claude/.skill-metrics-opt-out` disables writes.
#   - No network egress — script body invokes no exfiltration primitive.
#
# @problem P238 (Phase 3b — README badge renderer + advisory drift detector)
# @problem P087 (parent — no maturity signal on plugin features)
# @adr ADR-063 (Plugin maturity presentation layer — Phase 3b contract)
# @adr ADR-053 (Plugin maturity taxonomy — Bootstrapping clause rendering)
# @adr ADR-051 (JTBD-anchored README — prose-weaving precedent)
# @adr ADR-049 (Shim grammar — `wr-itil-plugin-maturity-render` on $PATH)
# @adr ADR-044 (Decision delegation — silent-framework carve-out)
# @adr ADR-035 (Privacy posture — opt-out marker, no network primitive)
# @adr ADR-052 (Behavioural tests default)
# @adr ADR-013 Rule 6 (non-interactive fail-safe — exit 0 always)
# @jtbd JTBD-302 (Trust That the README Describes the Plugin I Just
#   Installed — README is the contract surface)
# @jtbd JTBD-101 (Extend the Suite — clear patterns include stability)
# @jtbd JTBD-003 (Compose Only the Guardrails I Need — at-a-glance
#   stability for composition decisions)

set -uo pipefail

# ── CLI parse ───────────────────────────────────────────────────────────────

PROJECT_ROOT="$PWD"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --project-root=*) PROJECT_ROOT="${arg#--project-root=}" ;;
    --dry-run)        DRY_RUN=1 ;;
    --help|-h)
      sed -n '4,70p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "# wr-itil-plugin-maturity-render: ignoring unknown argument: $arg" >&2
      ;;
  esac
done

# ── Opt-out marker check (ADR-035) ──────────────────────────────────────────

OPT_OUT_MARKER="${PROJECT_ROOT}/.claude/.skill-metrics-opt-out"
if [ -e "$OPT_OUT_MARKER" ]; then
  echo "# wr-itil-plugin-maturity-render: opt-out marker present at ${OPT_OUT_MARKER}" >&2
  exit 0
fi

# ── packages/ discovery check (ADR-013 Rule 6 fail-safe) ────────────────────

if [ ! -d "${PROJECT_ROOT}/packages" ]; then
  echo "# wr-itil-plugin-maturity-render: no packages/ directory at ${PROJECT_ROOT}" >&2
  exit 0
fi

# ── Python body ─────────────────────────────────────────────────────────────

export PMR_PROJECT_ROOT="$PROJECT_ROOT"
export PMR_DRY_RUN="$DRY_RUN"

python3 - <<'PYEOF'
import json, os, re, sys
from pathlib import Path

project_root = Path(os.environ["PMR_PROJECT_ROOT"]).resolve()
dry_run = os.environ.get("PMR_DRY_RUN", "0") == "1"

packages_dir = project_root / "packages"
plugin_dirs = sorted(
    [d for d in packages_dir.iterdir()
     if d.is_dir() and (d / ".claude-plugin" / "plugin.json").is_file()]
)
if not plugin_dirs:
    print("# wr-itil-plugin-maturity-render: no plugins under packages/", file=sys.stderr)
    sys.exit(0)

# Match an existing prose-woven badge: `*Maturity: <body>.*` where body
# may contain anything except a `*`. Anchored on word `Maturity:` to
# avoid eating arbitrary italic spans.
BADGE_RE = re.compile(r"\s*\*Maturity:\s+[^*]+\*")

# Match a standalone `## Maturity` heading (anti-pattern enforcement —
# never emitted; detector catches drift if introduced by hand).
ANTI_SECTION_RE = re.compile(r"(?m)^##\s+Maturity\s*$")


def format_rollup_badge(maturity_record):
    """Render the prose-woven rollup badge per ADR-063.

    During the suite-bootstrap window the rollup carries the compound
    form per ADR-053 §Bootstrapping clause rendering; post-sunset it
    renders the band name only.
    """
    band = maturity_record.get("band", "Experimental")
    bootstrapping = bool(maturity_record.get("bootstrapping"))
    inv = maturity_record.get("rollup_invocations_30d")
    if bootstrapping and isinstance(inv, int) and inv > 0:
        return f"*Maturity: {band} (suite-bootstrap window; {inv} invocations / 30d).*"
    return f"*Maturity: {band}.*"


def weave_rollup_into_lead_prose(readme_text, badge):
    """Insert / replace the prose-woven rollup badge in the
    value-framing lead-prose line (the first **bold** paragraph after
    the H1). Returns the updated README text.

    Idempotent: if the lead-prose line already ends with a `*Maturity:
    ...*` span, replace it; otherwise append `<space><badge>` to the
    end of that line.
    """
    lines = readme_text.split("\n")
    h1_idx = None
    for i, line in enumerate(lines):
        if line.startswith("# "):
            h1_idx = i
            break
    if h1_idx is None:
        return readme_text  # no H1 — skip (defensive)

    # Find first non-empty line after H1 that looks like value-framing
    # prose. Preferred: starts with `**` (bold-lead pattern). Fallback:
    # first non-empty non-heading line.
    lead_idx = None
    fallback_idx = None
    for j in range(h1_idx + 1, len(lines)):
        s = lines[j].strip()
        if not s:
            continue
        if s.startswith("#"):
            continue
        if fallback_idx is None:
            fallback_idx = j
        if s.startswith("**"):
            lead_idx = j
            break
    if lead_idx is None:
        lead_idx = fallback_idx
    if lead_idx is None:
        return readme_text  # no prose found — skip (defensive)

    line = lines[lead_idx]
    # Strip any existing `*Maturity: ...*` span (idempotency contract).
    stripped = BADGE_RE.sub("", line).rstrip()
    new_line = f"{stripped} {badge}"
    lines[lead_idx] = new_line
    return "\n".join(lines)


SKILLS_HEADER_RE = re.compile(r"(?m)^##\s+Skills\s*$")
TABLE_ROW_RE = re.compile(r"^\|.*\|\s*$")
SEPARATOR_RE = re.compile(r"^\|\s*[-:]+(\s*\|\s*[-:]+)+\s*\|\s*$")


def split_row(row):
    """Split a markdown table row by `|`. Returns the inner cells
    (skips the leading + trailing empty splits from the outer `|`).
    Cells are NOT stripped — preserves padding for round-trip.
    """
    parts = row.split("|")
    # Drop the leading empty (before first `|`) and trailing empty
    # (after last `|`) when present.
    if parts and parts[0].strip() == "":
        parts = parts[1:]
    if parts and parts[-1].strip() == "":
        parts = parts[:-1]
    return parts


def join_row(cells):
    return "| " + " | ".join(c.strip() for c in cells) + " |"


def extract_skill_name(cell):
    """Extract the skill name from a `## Skills` cell. Skill cells
    typically read `/wr-<plugin>:<name>` or `\`/wr-<plugin>:<name>\``.
    Returns the bare skill name (after the colon), or None if the cell
    doesn't carry a skill identifier.
    """
    text = cell.strip()
    # Strip surrounding backticks.
    text = text.strip("`")
    m = re.search(r"/wr-[a-z0-9-]+:([a-z0-9-]+)", text)
    if m:
        return m.group(1)
    return None


def populate_skills_column(readme_text, skills_map):
    """Insert / populate a `Maturity` column in the `## Skills` table.

    `skills_map` is a dict[skill-name -> band]. If a cell's skill name
    isn't in the map, the cell value is empty (not omitted). Idempotent:
    if the `Maturity` column header already exists, cells are repopulated.
    """
    if not skills_map:
        return readme_text

    lines = readme_text.split("\n")
    skills_idx = None
    for i, line in enumerate(lines):
        if SKILLS_HEADER_RE.match(line):
            skills_idx = i
            break
    if skills_idx is None:
        return readme_text  # no `## Skills` section — skip

    # Find the first table row after the heading (header row of the
    # markdown table). Skip blank lines.
    header_idx = None
    for j in range(skills_idx + 1, len(lines)):
        s = lines[j].strip()
        if not s:
            continue
        if TABLE_ROW_RE.match(lines[j]):
            header_idx = j
            break
        # Hit a non-table non-blank line before any table — no table.
        break
    if header_idx is None:
        return readme_text
    if header_idx + 1 >= len(lines):
        return readme_text
    sep_line = lines[header_idx + 1]
    if not SEPARATOR_RE.match(sep_line.rstrip()):
        return readme_text  # second row isn't a separator — malformed; skip

    header_cells = split_row(lines[header_idx])
    sep_cells = split_row(sep_line)

    # Check whether `Maturity` column already exists.
    norm_headers = [c.strip().lower() for c in header_cells]
    if "maturity" in norm_headers:
        mat_col = norm_headers.index("maturity")
    else:
        mat_col = len(header_cells)
        header_cells.append("Maturity")
        sep_cells.append("---")

    new_header = join_row(header_cells)
    new_sep = "| " + " | ".join(c.strip() for c in sep_cells) + " |"
    lines[header_idx] = new_header
    lines[header_idx + 1] = new_sep

    # Walk subsequent table rows until a blank line or non-table line.
    body_idx = header_idx + 2
    while body_idx < len(lines):
        row = lines[body_idx]
        if not row.strip():
            break
        if not TABLE_ROW_RE.match(row):
            break
        cells = split_row(row)
        # Pad / truncate to the column count.
        target_cols = len(header_cells)
        while len(cells) < target_cols:
            cells.append("")
        if len(cells) > target_cols:
            cells = cells[:target_cols]
        # Identify the skill in the row's first cell that names a skill.
        skill_name = None
        for c in cells:
            sn = extract_skill_name(c)
            if sn:
                skill_name = sn
                break
        band = skills_map.get(skill_name, "") if skill_name else ""
        cells[mat_col] = band
        lines[body_idx] = join_row(cells)
        body_idx += 1

    return "\n".join(lines)


def render_plugin(pkg_dir):
    """Render a single plugin. Returns (changed_bool, new_readme_text)
    or (False, None) when skipped (no maturity, no README, etc).
    """
    plugin_json_path = pkg_dir / ".claude-plugin" / "plugin.json"
    readme_path = pkg_dir / "README.md"
    if not readme_path.is_file():
        return (False, None)
    try:
        plugin_doc = json.loads(plugin_json_path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"# wr-itil-plugin-maturity-render: skipping unreadable plugin.json at {plugin_json_path}: {exc}", file=sys.stderr)
        return (False, None)
    if not isinstance(plugin_doc, dict):
        return (False, None)

    maturity = plugin_doc.get("maturity")
    if not isinstance(maturity, dict) or "band" not in maturity:
        return (False, None)  # Phase 3a hasn't run for this plugin

    badge = format_rollup_badge(maturity)
    readme_text = readme_path.read_text(encoding="utf-8")
    new_text = weave_rollup_into_lead_prose(readme_text, badge)

    # Build per-skill band map from the plugin.json `maturity.skills.<name>`
    # nested location. Per ADR-063 Amendment 2026-05-18 (P0 hotfix), per-skill
    # maturity records nest UNDER the top-level `maturity:` key as `band` /
    # `schema_version` / `computed_at` / `evidence` (no outer `.maturity`
    # envelope — the nested record IS the maturity record).
    skills_map = {}
    skills_section = maturity.get("skills", {}) if isinstance(maturity, dict) else {}
    if isinstance(skills_section, dict):
        for name, entry in skills_section.items():
            if isinstance(entry, dict) and "band" in entry:
                skills_map[name] = entry["band"]

    new_text = populate_skills_column(new_text, skills_map)

    if new_text == readme_text:
        return (False, new_text)
    return (True, new_text)


plugins_processed = 0
plugins_written = 0
plugins_unchanged = 0

for pkg_dir in plugin_dirs:
    plugins_processed += 1
    changed, new_text = render_plugin(pkg_dir)
    if new_text is None:
        continue
    if not changed:
        plugins_unchanged += 1
        continue
    readme_path = pkg_dir / "README.md"
    if dry_run:
        sys.stdout.write(f"--- {readme_path}\n+++ would-write\n")
        sys.stdout.write(new_text)
        sys.stdout.write("\n")
    else:
        readme_path.write_text(new_text, encoding="utf-8")
    plugins_written += 1

print(
    f"# wr-itil-plugin-maturity-render: "
    f"plugins={plugins_processed} written={plugins_written} "
    f"unchanged={plugins_unchanged}",
    file=sys.stderr,
)
PYEOF

exit 0
