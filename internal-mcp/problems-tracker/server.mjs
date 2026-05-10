#!/usr/bin/env node
// problems-tracker MCP — exposes the open-problems backlog of a repo's
// docs/problems/ directory to Cowork artifacts.
//
// Internal tool for windyroad-claude-plugin. Sits outside packages/ on
// purpose — not shipped with the public plugin suite.

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// ----- repo discovery -----
//
// Walk up from a starting dir looking for a .git directory. If `repoPath`
// is given, use it directly. Otherwise default to the directory of this
// server file so the MCP works whether Cowork launches it with cwd=/ or cwd=$HOME.
function findRepoRoot(startDir) {
  let dir = resolve(startDir);
  for (;;) {
    if (existsSync(join(dir, '.git'))) return dir;
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

// ----- git helpers -----
function git(args, cwd) {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 });
  if (r.status !== 0) {
    throw new Error(`git ${args.join(' ')} failed: ${r.stderr.trim()}`);
  }
  return r.stdout;
}

// Set of states recognised in both the old (.state.md suffix) and new
// (docs/problems/<state>/) layouts. Order matters for stack rendering.
const STATES = ['open', 'verifying', 'known-error', 'closed', 'parked'];

function emptyCounts() {
  const c = {};
  for (const s of STATES) c[s] = 0;
  return c;
}

// Determine state from a path under docs/problems/. Handles both layouts:
//   Old (pre-P069): docs/problems/<id>-<slug>.<state>.md
//   New (post-P069): docs/problems/<state>/<id>-<slug>.md
// Returns null for non-ticket files (README, etc.) and unknown states.
function stateOfPath(p) {
  if (!p.startsWith('docs/problems/')) return null;
  const basename = p.split('/').pop();
  // Tickets are named `NNN-slug…` — filter out README.md, README-history.md, etc.
  if (!/^\d{3}-/.test(basename)) return null;

  // New layout
  const m1 = p.match(/^docs\/problems\/([a-z][a-z-]*)\/[^/]+\.md$/);
  if (m1 && STATES.includes(m1[1])) return m1[1];

  // Old layout
  const m2 = basename.match(/\.([a-z][a-z-]*)\.md$/);
  if (m2 && STATES.includes(m2[1])) return m2[1];

  return null;
}

// Walk what's currently on disk (handles both layouts) and return per-state
// counts. Used as a safety override for the most recent day in the timeseries
// — the git-log walk can be off by one across messy rename windows.
function countByStateOnDisk(repoRoot) {
  const counts = emptyCounts();
  const dir = join(repoRoot, 'docs', 'problems');
  if (!existsSync(dir)) return counts;

  // New layout: per-state subdirectory
  for (const state of STATES) {
    const sd = join(dir, state);
    if (!existsSync(sd)) continue;
    for (const f of readdirSync(sd)) {
      if (f.endsWith('.md') && /^\d{3}-/.test(f)) counts[state] += 1;
    }
  }
  // Old layout: flat directory with .state.md suffix (still possible if the
  // user re-runs against a repo that hasn't migrated)
  for (const f of readdirSync(dir)) {
    if (!/^\d{3}-/.test(f)) continue;
    const m = f.match(/\.([a-z][a-z-]*)\.md$/);
    if (m && STATES.includes(m[1])) counts[m[1]] += 1;
  }
  return counts;
}

// ----- timeseries -----
//
// Walk every commit that touched docs/problems/ in chronological order using
// a SINGLE `git log --name-status` call. At each commit boundary, emit per-
// state counts for the current set of ticket files. Forward-fill gaps to
// today. The single-pass git call (vs N ls-tree calls) avoids paying macOS
// per-spawn overhead on every commit.
function buildTimeseries(repoRoot) {
  const log = git(
    [
      'log',
      '--reverse',
      '--name-status',
      '--pretty=format:COMMIT|%H|%cI',
      '--',
      'docs/problems/',
    ],
    repoRoot,
  );

  // Mirror what `git ls-tree` would return at each commit by tracking a Set
  // of file paths under docs/problems/. Each commit's --name-status lines
  // mutate the set: A/M add, D removes, R deletes the old + adds the new,
  // C adds the new. Tracking by full path (not ticket-id) is important: some
  // commits add `004-foo.closed.md` before deleting `004-foo.open.md`, so a
  // ticket-id-keyed map collapses the transition window incorrectly.
  const filePaths = new Set();

  const byDay = new Map(); // ISO date -> { open, verifying, ..., parked }
  let currentDate = null;

  function snapshotCurrent() {
    if (!currentDate) return;
    const counts = emptyCounts();
    for (const p of filePaths) {
      const s = stateOfPath(p);
      if (s) counts[s] += 1;
    }
    byDay.set(currentDate, counts);
  }

  for (const line of log.split('\n')) {
    if (line.startsWith('COMMIT|')) {
      snapshotCurrent();
      const parts = line.split('|');
      currentDate = parts[2].slice(0, 10);
      continue;
    }
    if (!line.trim()) continue;

    const cols = line.split('\t');
    const status = cols[0];
    if (status === 'A') {
      filePaths.add(cols[1]);
    } else if (status === 'D') {
      filePaths.delete(cols[1]);
    } else if (status === 'M' || status === 'T') {
      // content / type change — path unchanged
    } else if (status.startsWith('R')) {
      filePaths.delete(cols[1]);
      filePaths.add(cols[2]);
    } else if (status.startsWith('C')) {
      filePaths.add(cols[2]);
    }
  }
  snapshotCurrent();

  if (byDay.size === 0) return [];

  const days = [...byDay.keys()].sort();
  const start = days[0];
  const today = new Date().toISOString().slice(0, 10);
  const end = today > days[days.length - 1] ? today : days[days.length - 1];

  const out = [];
  let last = null;
  for (let d = start; d <= end; d = nextDay(d)) {
    if (byDay.has(d)) last = byDay.get(d);
    if (last) out.push({ date: d, ...last });
  }

  // Safety override: the rename-tracking walk can get off by one if a single
  // commit applies multiple renames to the same ticket out of order. Trust
  // the actual on-disk counts for today.
  if (out.length) {
    const diskCounts = countByStateOnDisk(repoRoot);
    out[out.length - 1] = { date: out[out.length - 1].date, ...diskCounts };
  }
  return out;
}

function nextDay(iso) {
  const d = new Date(iso + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

// ----- WSJF parser -----
//
// Tickets use two formats:
//   **WSJF**: 6.0 — (12 × 1.0) / 2 — ...
//   **WSJF**: (15 × 1.0) / 8 = **1.875**
// Strategy: prefer the value after `=` (computed result, often **bolded**);
// fall back to the first number on the line (direct form).
function parseWsjf(text) {
  const line = text.match(/^\*\*WSJF\*\*:\s*(.*)$/m);
  if (!line) return null;
  const eq = line[1].match(/=\s*\*{0,2}(\d+(?:\.\d+)?)\*{0,2}/);
  if (eq) return parseFloat(eq[1]);
  const first = line[1].match(/(\d+(?:\.\d+)?)/);
  return first ? parseFloat(first[1]) : null;
}

// ----- open tickets -----
function buildOpens(repoRoot) {
  const dir = join(repoRoot, 'docs', 'problems');
  if (!existsSync(dir)) return [];

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Collect candidate open-state files from both layouts so the server keeps
  // working through and after a P069-style migration.
  const candidates = []; // { fullPath, basename, displayPath }

  const newOpenDir = join(dir, 'open');
  if (existsSync(newOpenDir)) {
    for (const f of readdirSync(newOpenDir)) {
      if (f.endsWith('.md') && /^\d{3}-/.test(f)) {
        candidates.push({
          fullPath: join(newOpenDir, f),
          basename: f,
          displayPath: `open/${f}`,
        });
      }
    }
  }
  for (const f of readdirSync(dir)) {
    if (f.endsWith('.open.md') && /^\d{3}-/.test(f)) {
      candidates.push({
        fullPath: join(dir, f),
        basename: f,
        displayPath: f,
      });
    }
  }

  candidates.sort((a, b) => a.basename.localeCompare(b.basename));

  const opens = [];
  for (const { fullPath, basename, displayPath } of candidates) {
    const text = readFileSync(fullPath, 'utf8');

    let title = '';
    for (const ln of text.split('\n')) {
      if (ln.startsWith('# Problem ')) {
        title = ln.replace(/^# Problem \d+:\s*/, '');
        break;
      }
    }

    const reported = (text.match(/^\*\*Reported\*\*:\s*(\d{4}-\d{2}-\d{2})/m) || [])[1] || null;
    const priority = parseInt((text.match(/^\*\*Priority\*\*:\s*(\d+)/m) || [])[1] || '', 10);
    const effort = (text.match(/^\*\*Effort\*\*:\s*([A-Za-z]+)/m) || [])[1] || null;
    const wsjf = parseWsjf(text);

    let age = null;
    if (reported) {
      const r = new Date(reported + 'T00:00:00');
      age = Math.round((today - r) / 86400000);
    }

    opens.push({
      id: basename.slice(0, 3),
      title,
      reported,
      priority: Number.isFinite(priority) ? priority : null,
      wsjf,
      effort,
      age,
      file: displayPath,
    });
  }

  opens.sort((a, b) => (b.wsjf ?? 0) - (a.wsjf ?? 0) || (b.priority ?? 0) - (a.priority ?? 0));
  return opens;
}

// ----- combined status -----
function buildStatus(repoPath) {
  const here = dirname(fileURLToPath(import.meta.url));
  const start = repoPath || here;
  const repoRoot = findRepoRoot(start);
  if (!repoRoot) {
    throw new Error(`No git repo found at or above ${start}`);
  }
  if (!existsSync(join(repoRoot, 'docs', 'problems'))) {
    throw new Error(`No docs/problems directory in ${repoRoot}`);
  }

  // Timing logs go to stderr so they show up in the MCP log panel without
  // polluting the JSON-RPC response on stdout.
  const t0 = Date.now();
  const timeseries = buildTimeseries(repoRoot);
  const t1 = Date.now();
  const opens = buildOpens(repoRoot);
  const t2 = Date.now();
  console.error(
    `[problems-tracker] get_problems_status: timeseries=${t1 - t0}ms ` +
    `opens=${t2 - t1}ms total=${t2 - t0}ms days=${timeseries.length} opens=${opens.length}`,
  );

  return {
    timeseries,
    opens,
    generated: new Date().toISOString(),
    repoRoot,
  };
}

// ----- MCP server wiring -----
const server = new Server(
  { name: 'problems-tracker', version: '0.1.0' },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'get_problems_status',
      description:
        'Returns the current open-problems backlog as { timeseries, opens, generated, repoRoot }. ' +
        'timeseries is one entry per day with shape { date, open, verifying, "known-error", closed, parked } ' +
        '— per-state ticket counts reconstructed from git rename history of docs/problems/. Handles both ' +
        'the flat .state.md layout and the post-P069 docs/problems/<state>/ layout. opens is the current ' +
        'list of open tickets sorted by WSJF desc, with id, title, reported, priority, wsjf, effort, age ' +
        '(days), file.',
      inputSchema: {
        type: 'object',
        properties: {
          repoPath: {
            type: 'string',
            description:
              'Optional absolute path to the repo. If omitted, walks up from the server file to find .git.',
          },
        },
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  if (req.params.name !== 'get_problems_status') {
    throw new Error(`Unknown tool: ${req.params.name}`);
  }
  try {
    const status = buildStatus(req.params.arguments?.repoPath);
    return {
      content: [{ type: 'text', text: JSON.stringify(status) }],
      structuredContent: status,
    };
  } catch (e) {
    return {
      content: [{ type: 'text', text: JSON.stringify({ error: e.message }) }],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
