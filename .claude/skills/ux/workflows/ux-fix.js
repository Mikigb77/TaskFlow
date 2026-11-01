export const meta = {
  name: 'ux-fix',
  description: 'TaskFlow UX loop, part 2: every package flows through on its own, in its own worktree (ux-implementer, ux-tester, frontend-ux-reviewer, one fix and a second check if it falls short, then the merge), as many at once as the machine allows, each step running only the tests its change touches; one final check runs the analyzer, the whole suite and the previews, once; a repair fixes what it finds and reruns only that; what still fails is re-planned once; then the ledger, report and reviewer memory',
  whenToUse: 'Started by the /ux skill after ux-review, with the run folder whose plan.json should be carried out.',
  phases: [
    { title: 'Load', detail: 'check that worktrees work from this session, and read the package headers' },
    { title: 'Packages', detail: 'each package in its own worktree: implement, test, verify, fix once and verify again if it falls short, then merge. Every step runs check.py: only the analysis, tests and previews its change touches. A package starts as soon as its dependencies are merged and a slot is free; it never waits for unrelated packages.' },
    { title: 'Check', detail: 'the final check in the main checkout, the only whole-suite run: analyzer, whole suite and UX previews, side by side; then a repair of what it finds, re-checked by check.py' },
    { title: 'Re-plan', detail: 'ux-organizer plans what the final check or the reviewers left failing (one extra round by default)' },
    { title: 'Record', detail: 'ledger, run report and reviewer memory' },
  ],
}

// args, from the /ux skill:
//   runId, runDir, date
//   repoRoot:       absolute path of the main checkout, with forward slashes (required).
//   heavySlots:     heavy commands (Flutter, builds) at once on this machine, across every
//                   workflow and lane of this repo; default 3. The package checks are short,
//                   so 3 fit a 4-CPU machine too.
//   agents:         agents at once in this workflow; default the runtime's own cap,
//                   min(16, CPUs - 2), from the CPU count the load step reads.
//   maxParallel:    packages in flight at once (admitted, holding their files); default agents + 2.
//   fileLimit:      packages changing the same file at once; default 2. ARB and test files
//                   don't count: they merge key by key and line by line.
//   fixAttempts:    fixes per package after its check finds it short, in its worktree; default 1.
//   maxExtraRounds: re-plan rounds after the final check; default 1.
//   planFile:       the plan to load, when not the run's plan.json (optional).
//   skip, only:     [packageId] — packages the owner struck, or the only ones to run (optional).
//   batch:          names this run's report and records when a plan runs in parts (optional).
//   recordMemory:   false skips the reviewer's memory step (optional; default true).
//   notes:          owner context from the conversation (optional).
//   part:           'all' (default); 'packages' runs only the packages and returns their
//                   records, for one lane of several (pkg.py --lanes auto splits the plan);
//                   'finish' runs the final check, the repair, the re-plan and the record for
//                   lanes that ran, given laneResults.
//   lane:           this lane's name, for its labels and logs (with part 'packages').
//   laneResults:    [the result of each lane] (with part 'finish').
//   worktrees:      false runs every package in the main checkout, one at a time (a fallback
//                   for a machine where worktrees don't work).
const a = args || {}
if (!a.runId || !a.runDir) throw new Error('ux-fix needs runId and runDir. Start it with /ux.')
const norm = p => String(p || '').trim().replace(/\\/g, '/').replace(/^\/([a-zA-Z])\//, '$1:/').replace(/\/+$/, '')
const same = (x, y) => {
  const p = norm(x)
  const q = norm(y)
  return !!p && (p === q || (/^[a-zA-Z]:\//.test(p) && p.toLowerCase() === q.toLowerCase()))
}
const ROOT = norm(a.repoRoot)
if (!ROOT) throw new Error('ux-fix needs repoRoot: the main checkout\'s absolute path (git rev-parse --show-toplevel), with forward slashes.')
const PART = a.part === 'packages' || a.part === 'finish' ? a.part : 'all'
const LANE = a.lane ? String(a.lane) : ''
const ISOLATE = a.worktrees !== false
const int = (v, d, min = 1) => (Number.isInteger(v) && v >= min ? v : d)
const SLOTS = int(a.heavySlots, 3)
const FILE_LIMIT = int(a.fileLimit, 2)
const FIXES = int(a.fixAttempts, 1, 0)
const EXTRA_ROUNDS = int(a.maxExtraRounds, 1, 0)
const skip = new Set(Array.isArray(a.skip) ? a.skip : [])
const only = Array.isArray(a.only) && a.only.length ? new Set(a.only) : null
const batch = typeof a.batch === 'string' && a.batch ? a.batch : ''
const tag = batch ? `${batch}-` : ''
const reportName = batch ? `report-${batch}.md` : 'report.md'
const recordMemory = a.recordMemory !== false
const RUN = `${ROOT}/${norm(a.runDir)}`
const PLAN = typeof a.planFile === 'string' && a.planFile ? a.planFile : `${a.runDir}/plan.json`
const PLAN_ABS = /^([a-zA-Z]:)?\//.test(norm(PLAN)) ? norm(PLAN) : `${ROOT}/${norm(PLAN)}`
const PY = 'python -I -X utf8'
const WAVES = `${PY} "${ROOT}/.claude/skills/ux/scripts/waves.py"`
const GATE = `${WAVES} gate --slots ${SLOTS} --`
const PKG = `${PY} "${ROOT}/.claude/skills/ux/scripts/pkg.py" "${RUN}"`
// The package check: only the tests, analysis and previews a change touches, through the gate.
// The final check is the only whole-suite run.
const CHECK_CMD = `${PY} "${ROOT}/.claude/skills/ux/scripts/check.py" --slots ${SLOTS}`
const PREVIEWS = 'flutter test --no-pub --dart-define=WRITE_UX_PREVIEWS=true test/ux_previews/ux_previews_test.dart'
const MERGE_LOG = `${RUN}/merges${batch ? `-${batch}` : ''}${LANE ? `-${LANE}` : ''}.jsonl`

// Reading discipline for every step. Whole files are what made the first runs expensive:
// every big read is written to cache once, then re-read on every later turn.
const LEAN = [
  `Read packages with: ${PKG} <ids> --conventions. Never open plan.json or plan-*.json directly; they are large.`,
  `Read a finding with: grep -n -A 30 "<ID>" "${RUN}"/review-*.md. Never read a whole review report.`,
  'Read source files in the parts you need (search first, then read with offset and limit), and only the previews of screens that changed.',
].join('\n')

// ---------------------------------------------------------------- schemas

const HEADER = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    title: { type: 'string' },
    area: { type: 'string' },
    size: { type: 'string' },
    findings: { type: 'array', items: { type: 'string' } },
    dependsOn: { type: 'array', items: { type: 'string' } },
    files: { type: 'array', items: { type: 'string' }, description: 'The repo-relative files the package expects to change, as its "files" lists them' },
  },
  required: ['id', 'title', 'area', 'size', 'findings'],
}
const LOADED = {
  type: 'object',
  properties: {
    planFile: { type: 'string' },
    cpus: { type: 'integer' },
    toplevel: { type: 'string' },
    commonDir: { type: 'string' },
    packages: { type: 'array', items: HEADER },
  },
  required: ['cpus', 'toplevel', 'commonDir', 'packages'],
}
const CHECK = {
  type: 'object',
  properties: {
    command: { type: 'string' },
    passed: { type: 'boolean' },
    note: { type: 'string' },
  },
  required: ['command', 'passed'],
}
const MISSED = {
  type: 'object',
  properties: { id: { type: 'string' }, reason: { type: 'string' } },
  required: ['id', 'reason'],
}
const IMPLEMENTED = {
  type: 'object',
  properties: {
    status: { type: 'string', enum: ['done', 'partial', 'blocked', 'failed'] },
    filesChanged: { type: 'array', items: { type: 'string' } },
    addressed: { type: 'array', items: { type: 'string' } },
    notAddressed: { type: 'array', items: MISSED },
    checks: { type: 'array', items: CHECK },
    deviceChecks: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
    worktree: { type: 'string', description: 'In a worktree: its absolute path (git rev-parse --show-toplevel). Otherwise empty.' },
  },
  required: ['status', 'filesChanged', 'addressed', 'notAddressed', 'checks'],
}
const FINDING_TEST = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    coverage: { type: 'string', enum: ['tested', 'preview', 'device', 'none'] },
    tests: { type: 'array', items: { type: 'string' }, description: 'file :: test name' },
    result: { type: 'string', enum: ['pass', 'fail', 'n/a'] },
    note: { type: 'string' },
  },
  required: ['id', 'coverage', 'result'],
}
const FAILURE = {
  type: 'object',
  properties: {
    test: { type: 'string' },
    owner: { type: 'string', enum: ['app', 'infrastructure'] },
    finding: { type: 'string', description: 'The finding it proves, if any' },
    evidence: { type: 'string' },
  },
  required: ['test', 'owner', 'evidence'],
}
const TESTED = {
  type: 'object',
  properties: {
    passed: { type: 'boolean', description: 'True when every new test passes and nothing fails outside KNOWN_FAILURES.md' },
    checks: { type: 'array', items: CHECK },
    findings: { type: 'array', items: FINDING_TEST },
    failures: {
      type: 'array',
      description: 'Failures still open after you fixed your own tests: the app falls short, or infrastructure you could not fix',
      items: FAILURE,
    },
    filesChanged: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
  required: ['passed', 'checks', 'findings', 'failures', 'filesChanged'],
}
const MERGED = {
  type: 'object',
  properties: {
    packages: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          worktree: { type: 'string' },
          applied: { type: 'array', items: { type: 'string' } },
          conflicts: {
            type: 'array',
            items: { type: 'object', properties: { path: { type: 'string' }, why: { type: 'string' } }, required: ['path', 'why'] },
          },
          ignored: { type: 'array', items: { type: 'string' } },
          gone: { type: 'boolean' },
          alreadyMerged: { type: 'boolean' },
          error: { type: 'string' },
        },
        required: ['id', 'applied', 'conflicts'],
      },
    },
    shelved: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          worktree: { type: 'string' },
          patch: { type: 'string' },
          removed: { type: 'boolean' },
          note: { type: 'string' },
          error: { type: 'string' },
        },
        required: ['id'],
      },
    },
    arbChanged: { type: 'boolean' },
    genL10n: { type: 'string' },
    removed: { type: 'array', items: { type: 'string' } },
  },
  required: ['packages'],
}
const REGRESSION = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    severity: { type: 'integer' },
    title: { type: 'string' },
    where: { type: 'string' },
    fix: { type: 'string' },
  },
  required: ['id', 'severity', 'title', 'where', 'fix'],
}
const VERIFIED = {
  type: 'object',
  properties: {
    reportPath: { type: 'string' },
    results: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          result: { type: 'string', enum: ['fixed', 'partly', 'not_fixed'] },
          evidence: { type: 'string' },
          needsDevice: { type: 'boolean' },
        },
        required: ['id', 'result', 'evidence'],
      },
    },
    regressions: { type: 'array', items: REGRESSION },
  },
  required: ['reportPath', 'results', 'regressions'],
}
const REPLANNED = {
  type: 'object',
  properties: {
    packages: { type: 'array', items: HEADER },
    escalated: { type: 'array', items: MISSED },
  },
  required: ['packages', 'escalated'],
}
const CLOSED = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'One or two sentences' },
    report: { type: 'string', description: 'The full run report in Markdown. Return it here; the main session saves it, because subagents may not write report files.' },
    verified: { type: 'array', items: { type: 'string' } },
    open: { type: 'array', items: MISSED },
    deviceChecks: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'report', 'verified', 'open', 'deviceChecks'],
}

// ---------------------------------------------------------------- scheduling

// Files every package may touch: the ARB catalogs merge key by key, generated l10n is rebuilt
// after the merge, and test files merge line by line. They never hold packages back.
// Keep in step with pkg.py.
const MERGEABLE = /^App\/(lib\/l10n\/(app_\w+\.arb|generated\/)|test\/)/
function footprint(p) {
  const files = (Array.isArray(p.files) ? p.files : [])
    .map(f => String(f).replace(/\\/g, '/').replace(/^\.\//, '').split(/[\s:#(]/)[0])
    .filter(Boolean)
  return files.filter(f => !MERGEABLE.test(f))
}

// Agents at once. The runtime caps a workflow at min(16, CPUs - 2) and queues the rest first
// come, first served; this queue goes first by priority instead, so an earlier package's
// next step (test, verify, merge) runs before a later package starts. Packages finish one
// after another, their worktrees go, and later packages are seeded with more of the run.
let AGENTS = int(a.agents, 2)
let active = 0
let order = 0
const waiting = []
function pump() {
  while (active < AGENTS && waiting.length) {
    active++
    waiting.shift().go()
  }
}
function slot(prio) {
  return new Promise(go => {
    waiting.push({ prio, n: order++, go })
    waiting.sort((x, y) => x.prio - y.prio || x.n - y.n)
    pump()
  })
}
async function call(prio, prompt, opts) {
  await slot(prio)
  try {
    return await agent(prompt, opts)
  } catch (e) {
    log(`${opts.label}: ${(e && e.message) || e}`)
    return null
  } finally {
    active--
    pump()
  }
}

// Packages in flight: admitted ones hold their files until they are merged, so at most
// FILE_LIMIT packages change one file at once. A package that can't start yet never holds
// back a later one that can.
let FLIGHT = 1
const flight = { running: 0, holders: new Map(), waiting: [] }
function admit(p, prio) {
  const files = footprint(p)
  return new Promise(go => {
    flight.waiting.push({ files, prio, n: order++, go })
    flight.waiting.sort((x, y) => x.prio - y.prio || x.n - y.n)
    letIn()
  })
}
function letIn() {
  for (let i = 0; i < flight.waiting.length;) {
    const w = flight.waiting[i]
    const fits = flight.running < FLIGHT && w.files.every(f => (flight.holders.get(f) || 0) < FILE_LIMIT)
    if (!fits) {
      i++
      continue
    }
    flight.waiting.splice(i, 1)
    flight.running++
    w.files.forEach(f => flight.holders.set(f, (flight.holders.get(f) || 0) + 1))
    let left = false
    w.go(() => {
      if (left) return
      left = true
      flight.running--
      w.files.forEach(f => flight.holders.set(f, flight.holders.get(f) - 1))
      letIn()
    })
  }
}

// Merges and shelves, one at a time in the main checkout. Whatever is waiting when the last
// merge ends goes in the next one, so packages that finish together merge together.
const toMerge = []
let merging = false
let mergeRound = 1
function enqueue(item) {
  return new Promise(resolve => {
    toMerge.push({ ...item, resolve })
    if (!merging) drain()
  })
}
async function drain() {
  merging = true
  try {
    while (toMerge.length) {
      const items = toMerge.splice(0)
      const m = await call(0, mergePrompt(items), {
        label: `merge ${items.map(x => (x.kind === 'shelve' ? `(set aside ${x.id})` : x.id)).join(' ')}${mergeRound > 1 ? ` · round ${mergeRound}` : ''}`,
        phase: 'Packages',
        schema: MERGED,
        model: 'haiku',
      })
      if (m && m.genL10n && String(m.genL10n).startsWith('failed')) log(`gen-l10n after a merge: ${m.genL10n}`)
      const merged = new Map(((m && m.packages) || []).map(e => [e.id, e]))
      const shelved = new Map(((m && m.shelved) || []).map(e => [e.id, e]))
      for (const x of items) x.resolve((x.kind === 'shelve' ? shelved : merged).get(x.id) || null)
    }
  } finally {
    merging = false
  }
}

// ---------------------------------------------------------------- prompts

const ids = list => (list.length ? list.join(', ') : 'none')
const missed = r => (r && r.notAddressed && r.notAddressed.length ? `; not addressed: ${r.notAddressed.map(n => `${n.id} (${n.reason})`).join('; ')}` : '')
const why = r => (!r ? 'its agent returned nothing' : r.status === 'failed' ? `it failed: ${r.notes || 'no notes'}` : !r.worktree ? 'it reported no worktree' : `it worked in ${r.worktree}, not in a worktree of its own`)
// A test run: the package check (its result counts its analyzer and tests, not its previews),
// or flutter test without the previews.
const isTest = c => /check\.py/.test(c.command) || (/flutter test/.test(c.command) && !/WRITE_\w*PREVIEWS/.test(c.command))
const CHECK_LINE = [
  `The check: ${CHECK_CMD}, from anywhere in the worktree. It runs, through the gate, flutter gen-l10n if an ARB file changed, the analyzer on the files changed and the files that use them, and only the tests that cover the change: the tests of the files changed and of the screens that show a changed ARB key, the tests that name a changed key, the catalog test, and the tests that failed last time. It compiles the APK when a native file changed. The first run counts everything since the worktree's seed; each later run counts only what changed since the run before, plus what failed in it.`,
  'Never run flutter test, flutter analyze or the whole suite yourself: the run\'s final check runs the whole suite once, after every package is merged. To debug one failing test alone, the check takes --tests <file>.',
  'Report the check as one entry in checks: its command, passed (its last run passed), and in note what it ran and what failed.',
].join('\n')

function where(wt) {
  if (!ISOLATE) return `Work in the main checkout at ${ROOT}; packages run one at a time there.`
  return [
    `Work only in the package's worktree at ${wt}: read and write files under it, and run every command as cd "${wt}/App" && <command> (each command may start in another folder). Never touch the main checkout at ${ROOT}: other packages are being worked on at the same time, in their own worktrees.`,
    `Heavy commands run through the gate, which lets only ${SLOTS} run at once on this machine. The check (${CHECK_CMD}) takes its own place there; anything else heavy goes through it too: ${GATE} <command>. Reading, searching and editing run freely.`,
  ].join('\n')
}

function packageLine(p, r) {
  return `- ${p.id} (${p.title}): findings ${p.findings.join(', ')}. Implementer: ${r ? r.status : 'no result'}${missed(r)}`
}

function implementPrompt(p, ctx, depNote, extra) {
  const lines = [
    `UX loop run ${a.runId}, round ${ctx.round}. Implement work package ${p.id}: ${p.title}.`,
    `Area ${p.area}, size ${p.size}, findings ${p.findings.join(', ')}.`,
  ]
  if (ISOLATE) {
    lines.push(
      `You work in your own git worktree, a copy of the repo made for you. Other packages are implemented, tested and checked at the same time in theirs, so never touch the main checkout at ${ROOT}.`,
      `Before anything else, from your worktree's root (your starting directory), run: ${WAVES} seed --run ${a.runDir}`,
      'It brings the run so far (every package merged before yours), the plan and the decisions into your worktree, and runs flutter pub get. Then work only inside your worktree, with paths relative to it. If seed refuses (you are in the main checkout) or fails, stop and report failed with its message.',
      `Heavy commands run through the gate, which lets only ${SLOTS} run at once on this machine; the check below takes its own place there. Reading, searching and editing run freely.`,
      'Return your worktree\'s absolute path (git rev-parse --show-toplevel) in "worktree".',
    )
  } else {
    lines.push(`You work in the main checkout at ${ROOT}; packages run one at a time there.`)
  }
  if (depNote) lines.push(depNote)
  lines.push(
    `Your instructions are package ${p.id}: its brief, files, acceptance checks and device checks, plus the plan's shared conventions. Print exactly those with: ${PKG} ${p.id} --conventions`,
    LEAN,
    'Earlier packages in this run may already have changed the code; build on their work.',
    'Test files listed in the package are for ux-tester, who writes the acceptance tests after you. Only update existing tests your change breaks.',
    ISOLATE
      ? CHECK_LINE
      : `Checks, from ${ROOT}: ${CHECK_CMD} --main --files <every file you changed>. It runs only the analysis and tests your change touches; never the whole suite, which the run's final check runs once. Report it as one entry in checks.`,
    'Run the check when your change is complete, fix what it reports, and run it again until it passes. Don\'t render previews: ux-tester renders the screens you changed, after you, for the reviewer.',
  )
  if (extra) lines.push(extra)
  if (a.notes) lines.push(`From the owner, this session: ${a.notes}`)
  lines.push('Return the structured result.')
  return lines.join('\n')
}

function testPrompt(p, ctx, r, wt) {
  const ran = r.checks.filter(c => c.passed && isTest(c)).map(c => `${c.command}${c.note ? ` (${c.note})` : ''}`)
  return [
    `UX loop run ${a.runId}, round ${ctx.round}. Mode: package. Lock work package ${p.id} with tests: ${p.title}.`,
    `Area ${p.area}, findings ${p.findings.join(', ')}. Its implementer reported: ${r.status}${missed(r)}.`,
    where(wt),
    `Files the implementer changed: ${ids(r.filesChanged)}.`,
    ran.length
      ? `The implementer's check passed: ${ran.join(' ; ')}. Those tests don't run again.`
      : 'The implementer reported no passing check.',
    `1. Write the tests for ${p.id}'s acceptance checks only, as your instructions say.`,
    ISOLATE
      ? `2. Run the check with the previews, from the worktree: ${CHECK_CMD} --previews auto. It analyzes and runs only your new and changed test files (and anything that failed in the implementer's last run), then renders, for the reviewer, the previews of every screen whose sources ${p.id} changed (by the Sources in ${ROOT}/App/build/ux/INDEX.md). Fix your own tests and run it again until your tests are right; a test that fails because the app falls short stays failing.`
      : `2. Run, from ${ROOT}: ${CHECK_CMD} --main --files <your test files and the files ${p.id} changed> --previews auto. It runs only those tests and renders the previews of the screens ${p.id} changed.`,
    `3. Read which previews it rendered. If a screen ${p.id} changed has a preview it missed, render it too with --previews "<area>/<screen>\\." (names in INDEX.md). If a preview's flow breaks because the screen changed on purpose, update the flow in App/test/ux_previews/ and run the check again. If no preview shows what changed, say so in your notes.`,
    'Skip the run\'s check: no whole suite, no whole-app analyzer, no older preview commands. The final check runs those once, after every package is merged.',
    'Report the check as one entry in checks: its command, passed, and in note what it ran.',
    'Parts of a package marked "waits on D#" were left out on purpose; do not test them.',
    LEAN,
    'Return the structured result for this package only. filesChanged lists the test and preview files you changed, relative to the repo root.',
  ].join('\n')
}

function verifyPrompt(p, ctx, r, t, wt, check, fixNote) {
  const name = `verify-${tag}r${ctx.round}-${p.id}${check > 1 ? `-${check}` : ''}.md`
  const proved = (t ? t.findings : [])
    .filter(f => p.findings.includes(f.id))
    .map(f => `- ${f.id}: ${f.coverage}, ${f.result}${f.tests && f.tests.length ? ` (${f.tests.join('; ')})` : ''}${f.note ? `. ${f.note}` : ''}`)
  const failing = (t ? t.failures : []).map(f => `- ${f.test} (${f.owner}${f.finding ? `, ${f.finding}` : ''}): ${f.evidence}`)
  return [
    `Mode: verify. UX loop run ${a.runId}, round ${ctx.round}, work package ${p.id}, area ${p.area}. Today is ${a.date}.${check > 1 ? ` This is check ${check}, after a fix.` : ''}`,
    'Check only this package and its findings:',
    packageLine(p, r),
    fixNote || '',
    LEAN,
    'Parts of a package marked "waits on D#" were left out on purpose (an owner decision is pending); do not count them as not fixed.',
    ISOLATE
      ? `The package is in its own worktree at ${wt}, on top of the run's earlier work; it is merged into the main checkout only after you. Read there: files under ${wt}, and exactly what the package changed with: ${WAVES} diff --worktree "${wt}". Never touch the main checkout at ${ROOT}, apart from writing your notes.`
      : `It is in the main checkout. See what changed with: git diff HEAD -- <file>, for the files it changed: ${ids(r.filesChanged)}.`,
    'What its tester proved (a failing test means the acceptance check is not met):',
    ...(proved.length ? proved : ['- nothing reported']),
    ...(failing.length ? ['Failing tests:', ...failing] : []),
    `Its tester rendered the previews of the screens it changed, into ${ISOLATE ? wt : ROOT}/App/build/ux/ (INDEX.md there lists them)${t && t.notes ? `; the tester's notes: ${t.notes}` : ''}. Read them; do not run Flutter.`,
    'Judge every listed finding as fixed, partly or not_fixed, with evidence. Then look for regressions, only in the files it changed and the flows they touch.',
    `Number regressions R${ctx.round}-${p.id}-1, R${ctx.round}-${p.id}-2 and so on; the organizer gives them final IDs. Another step records memory.`,
    `Write your notes to ${RUN}/${name}, then return the structured result.`,
  ].filter(Boolean).join('\n')
}

function fixPrompt(p, ctx, state, t, wt) {
  const testFiles = t ? t.filesChanged.filter(f => /_test\.dart$/.test(f)) : []
  const failingTests = [...new Set([...state.failing.filter(f => f.testFailed), ...state.stray]
    .map(f => (String(f.evidence || f.test).match(/(?:App\/)?(test\/[\w/.-]+?_test\.dart)/) || [])[1])
    .filter(Boolean)
    .map(f => `App/${f}`))]
  return [
    `UX loop run ${a.runId}, round ${ctx.round}. Mode: fix. Work package ${p.id}: ${p.title}. Area ${p.area}, findings ${p.findings.join(', ')}.`,
    'It was implemented, locked with tests and checked by the reviewer, who found it short:',
    ...state.failing.map(f => `- ${f.id}: ${f.result}. ${f.evidence}`),
    ...(state.regressions.length ? ['Regressions it caused:', ...state.regressions.map(g => `- ${g.id}, severity ${g.severity}: ${g.title}. ${g.where}. Fix: ${g.fix}`)] : []),
    ...(state.stray.length ? ['Existing tests it broke:', ...state.stray.map(f => `- ${f.test}: ${f.evidence}`)] : []),
    `Fix exactly these, and keep what already works. Your instructions are still package ${p.id}: ${PKG} ${p.id} --conventions`,
    ISOLATE ? `${where(wt)}\nThe worktree is seeded already: don't run seed.` : where(wt),
    LEAN,
    'If a test is wrong rather than the app, say so in your notes and leave the test alone: ux-tester owns the acceptance tests.',
    ISOLATE
      ? `Then run the check with the previews, from the worktree, until it passes: ${CHECK_CMD} --previews auto. It reruns what failed in the last check and the tests of what you change now, and renders again the previews of the screens your fix changed, for the reviewer's second look; nothing else.${failingTests.length ? ` If one of these failing tests isn't rerun, add it with --also: ${failingTests.join(' ')}.` : ''}`
      : `Then run, from ${ROOT}, until it passes: ${CHECK_CMD} --main --files <every file you changed> --previews auto${testFiles.length ? ` --also ${testFiles.join(' ')}` : ''}.`,
    CHECK_LINE.split('\n').slice(1).join('\n'),
    a.notes ? `From the owner, this session: ${a.notes}` : '',
    `Return the structured result: filesChanged is every file you changed in this fix; worktree is ${ISOLATE ? wt : 'empty'}.`,
  ].filter(Boolean).join('\n')
}

function integratePrompt(p, ctx, oldWt, conflicts) {
  return [
    `UX loop run ${a.runId}, round ${ctx.round}. Mode: integrate. Work package ${p.id}: ${p.title}. Area ${p.area}, findings ${p.findings.join(', ')}.`,
    `${p.id} is done, tested and checked in its old worktree at ${oldWt}, but merging it into the main checkout conflicted with packages merged since it started:`,
    ...conflicts.map(c => `- ${c.path}: ${c.why}`),
    `You carry it over in your own fresh worktree, a copy of the repo made for you. Never touch the main checkout at ${ROOT}.`,
    `1. From your worktree's root (your starting directory): ${WAVES} seed --run ${a.runDir}`,
    `2. Then: ${WAVES} carry --from "${oldWt}"`,
    '   It brings the package\'s changes over with three-way merges and prints JSON. Each file under "conflicts" holds conflict markers (main checkout now / the package\'s seed / the package): resolve each by hand, keeping both packages\' intent. If they truly contradict, keep what the main checkout has now and say so in your notes.',
    `3. Resolve the conflicts, then run the check until it passes: ${CHECK_CMD}. In this fresh worktree it counts the whole package since the seed: the analysis and tests the package touches, nothing more.`,
    CHECK_LINE.split('\n').slice(1).join('\n'),
    `4. When they pass, remove the old worktree: ${WAVES} drop --worktree "${oldWt}"`,
    `Your instructions are package ${p.id}, as before: ${PKG} ${p.id} --conventions`,
    LEAN,
    a.notes ? `From the owner, this session: ${a.notes}` : '',
    'Return the structured result: filesChanged is every file the package changes; worktree is your worktree\'s absolute path (git rev-parse --show-toplevel).',
  ].filter(Boolean).join('\n')
}

function mergePrompt(items) {
  const parts = items.map(x => `--${x.kind === 'shelve' ? 'shelve' : 'worktree'} ${x.id}="${x.wt}"`)
  return [
    'Run exactly this one command, from anywhere, and wait for it:',
    `${WAVES} merge ${parts.join(' ')} --patches "${RUN}" --log "${MERGE_LOG}"`,
    'It prints one JSON object. Return that JSON as the structured result, unchanged. Do nothing else: no other command, no edits.',
  ].join('\n')
}

function sideBySide() {
  return [
    'Run the slow checks side by side, in one shell command from App/, and wait for both:',
    `mkdir -p build/final-check && ( ${GATE} flutter test --no-pub --reporter failures-only > build/final-check/suite.log 2>&1; echo "suite exit $?" ) & ( ${GATE} ${PREVIEWS} > build/final-check/previews.log 2>&1; echo "previews exit $?" ) & wait`,
    'It takes longer than one tool call may run (on 2026-11-01 the suite alone took 13 minutes on a 4-CPU machine, the previews 4): start it with the Bash tool\'s run_in_background, and wait for it to finish.',
    'Then read the tails of build/final-check/suite.log and previews.log. A preview flow that fails is an app failure if the app broke, or yours to fix in App/test/ux_previews/ if a screen changed on purpose.',
  ].join('\n')
}

function finalPrompt(round, recs, files) {
  const findings = [...new Set(recs.flatMap(r => r.findings))]
  const locked = recs.filter(r => r.merged && r.tests && r.tests.files.length).map(r => `- ${r.id}: ${r.tests.files.join(', ')}`)
  return [
    `UX loop run ${a.runId}. Mode: final check${round > 1 ? `, after redo round ${round}` : ''}. Every package of this run is merged into the main checkout at ${ROOT}: run the whole check there, once. Write no new tests.`,
    `Packages merged: ${ids(recs.filter(r => r.merged).map(r => r.id))}.`,
    `Files changed in this run: ${ids(files)}.`,
    'Their own tests, written by their testers:',
    ...(locked.length ? locked : ['- none reported']),
    'From App/: flutter gen-l10n if an ARB file changed (the merges ran it; check lib/l10n/generated is current), then flutter analyze --no-pub.',
    sideBySide(),
    files.some(f => /(^|\/)android\//.test(f))
      ? 'Android files changed in this run: include the compile check, flutter build apk --debug --no-pub --target-platform android-x64 (build only, never install). A broken native build fails the check.'
      : 'No Android files changed in this run, so no native build is needed.',
    `Report every failing test against its finding (this run's findings: ${ids(findings)}), or with no finding if it proves none; fix only your own test infrastructure, as your instructions say. Failures listed in ${ROOT}/.claude/ux-review/KNOWN_FAILURES.md don't count.`,
    'Return the structured result.',
  ].join('\n')
}

// The tests a failure names, as repo-relative files.
const testFilesOf = failures => [...new Set(failures
  .map(f => (String(f.test).replace(/\\/g, '/').match(/(?:App\/)?(test\/[\w/.-]+?_test\.dart)/) || [])[1])
  .filter(Boolean)
  .map(f => `App/${f}`))]

function repairPrompt(round, recs, failures, failedChecks) {
  const files = testFilesOf(failures)
  return [
    `UX loop run ${a.runId}. Mode: repair. Every package of this run is merged into the main checkout at ${ROOT}, and the run's final check (the whole suite, once) found it short:`,
    ...failures.map(f => `- ${f.test}${f.finding ? ` (${f.finding})` : ''}: ${f.evidence}`),
    ...failedChecks.map(c => `- ${c.command}: failed${c.note ? `. ${c.note}` : ''}`),
    'Each passed in its own package, so the cause is usually two packages meeting in the main checkout, or a package that broke something its check did not cover. Find each cause and fix it there, in the main checkout: nothing else runs there now.',
    `Keep every package's intent. If two truly contradict, keep the later one's and say so. The packages: ${ids(recs.filter(r => r.merged).map(r => r.id))}; read one with ${PKG} <id> --conventions, and what the run changed in a file with git diff HEAD -- <file>.`,
    'If a test is wrong rather than the app (a package changed that copy or behaviour on purpose), say so in your notes and leave it: ux-tester owns the tests.',
    LEAN,
    `Then run, from ${ROOT}, until it passes: ${CHECK_CMD} --main --files <every file you changed>${files.length ? ` --also ${files.join(' ')}` : ''}`,
    'It reruns the tests that failed and the analysis and tests of what you changed, nothing else: the whole suite has run once already. Report it as one entry in checks.',
    a.notes ? `From the owner, this session: ${a.notes}` : '',
    'Return the structured result: filesChanged is every file you changed, repo-relative; worktree is empty.',
  ].filter(Boolean).join('\n')
}

function recheckPrompt(round, recs, files, also) {
  const findings = [...new Set(recs.filter(r => r.round === round).flatMap(r => r.findings))]
  return [
    `UX loop run ${a.runId}. Mode: re-check, after redo round ${round}. The run's final check has run the whole suite once already; don't run it again. Round ${round}'s packages are merged into the main checkout at ${ROOT}; check only what they changed. Write no new tests.`,
    `Run, from ${ROOT}: ${CHECK_CMD} --main --files ${files.join(' ')}${also.length ? ` --also ${also.join(' ')}` : ''}`,
    'It runs gen-l10n if an ARB file changed, the analyzer on those files and the files that use them, the tests that cover them and the tests that failed before. It can take several minutes: run it in the background if one tool call can\'t wait that long.',
    `Report every failing test against its finding (this round's findings: ${ids(findings)}), or with no finding if it proves none, as in a final check. Failures listed in ${ROOT}/.claude/ux-review/KNOWN_FAILURES.md don't count.`,
    'Return the structured result: checks holds the check.',
  ].join('\n')
}

function replanPrompt(round, failures, regressions, failedChecks) {
  return [
    `Mode: replan. UX loop run ${a.runId}, after round ${round}. Today is ${a.date}. Run folder: ${a.runDir}.`,
    'Every package was implemented, locked by tests and checked on its own, and fixed once where it fell short. Findings still short after that fix are escalated to the owner, not re-planned. What is left for you:',
    'Failing tests in the final check that its repair in the main checkout could not clear (from ux-tester):',
    ...(failures.length ? failures.map(f => `- ${f.test} (${f.owner}${f.finding ? `, ${f.finding}` : ''}): ${f.evidence}`) : ['- none']),
    'Regressions the reviewers found that the package\'s own fix did not clear:',
    ...(regressions.length ? regressions.map(g => `- ${g.id} (from ${g.pkg}), severity ${g.severity}: ${g.title}. ${g.where}. Fix: ${g.fix}`) : ['- none']),
    failedChecks.length ? `Final check: failed. ${failedChecks.map(c => c.command + (c.note ? ` (${c.note})` : '')).join('; ')}` : '',
    LEAN,
    `Read only the verify notes of the packages involved (${RUN}/verify-${tag}r${round}-<package>*.md). In ISSUES.md, edit only the lines you change.`,
    'Plan packages only for these. Give every new package its "files" (repo-relative paths): packages run side by side, and their files decide how many touch one file at once.',
    `Write the new packages to ${a.runDir}/plan-${tag}r${round + 1}.json (same structure as plan.json), append them to plan.md under "Round ${round + 1}${batch ? ` (${batch})` : ''}", add the regressions to ISSUES.md with final IDs, then return the structured result.`,
  ].filter(Boolean).join('\n')
}

function closePrompt(recs, finals, files) {
  return [
    `Mode: close. UX loop run ${a.runId}${batch ? ` (${batch})` : ''}. Today is ${a.date}. Run folder: ${a.runDir}.`,
    'Every package ran on its own, in its own worktree: implemented, locked by tests, checked by the reviewer, fixed once and checked again where it fell short, then merged. A package whose own tests still failed after its fix was set aside unmerged, with its patch in the run folder.',
    'Packages:',
    ...recs.map(r => [
      `- ${r.id} (round ${r.round}, ${String(r.planFile).split('/').pop()}): ${r.outcome}; implementer ${r.status}${r.attempts ? `, ${r.attempts} fix(es)` : ''};`,
      `fixed ${ids(r.fixed)};`,
      `not fixed ${ids(r.notFixed.map(x => `${x.id} (${x.result}: ${String(x.evidence).slice(0, 240)})`))};`,
      `unchecked ${ids(r.unchecked)};`,
      `proven by test ${ids(r.tests ? r.tests.proven : [])}; device-only ${ids(r.tests ? r.tests.device : [])};`,
      `regressions open ${ids(r.regressions.map(g => `${g.id} S${g.severity} ${g.title} at ${g.where}`))}${r.replanned && r.replanned.length ? `; regressions re-planned ${ids(r.replanned.map(g => g.id))}` : ''};`,
      `verify notes ${ids(r.verifyReports)}.`,
    ].join(' ')),
    'Final checks:',
    ...(finals.length ? finals.map(f => `- after round ${f.round}: ${f.passed ? 'passed' : 'failed'}${f.note ? ` (${f.note})` : ''}${f.failures.length ? `; failing: ${f.failures.map(x => `${x.test} (${x.owner}${x.finding ? `, ${x.finding}` : ''})`).join('; ')}` : ''}`) : ['- none ran: nothing was merged']),
    `Escalated to the owner: ${escalated.length ? escalated.map(e => `${e.id} (${e.reason})`).join('; ') : 'none'}.`,
    `Files changed: ${ids(files)}.`,
    'A finding counts as verified only if the last check of it said "fixed" and no test for it failed. Note which verified findings are locked by a test. Phone checks stay listed for the owner.',
    'Regressions still open get final IDs (the next free numbers after the highest in ISSUES.md) and their own lines in ISSUES.md, as open.',
    `Work from the summaries above and this run's verify notes (${RUN}/verify-${tag}*.md); don't re-read the plan or the review reports. In ISSUES.md, find each finding's line with grep and edit only those lines.`,
    `Update .claude/ux-review/ISSUES.md, then return the structured result with the full report in "report". Don't write a report file yourself; the main session saves it as ${a.runDir}/${reportName}.`,
  ].join('\n')
}

// ---------------------------------------------------------------- one package

const changedAll = new Set()
const organizerEscalated = []
let escalated = []

// What needs the owner, from the latest package that had each finding: blocked, failed or
// set aside unmerged, or still short after its fix (or failing in the final check).
function escalations(recs) {
  const latest = new Map()
  recs.forEach(r => r.findings.forEach(id => latest.set(id, r)))
  const out = []
  for (const [id, r] of latest) {
    if (r.status === 'blocked') {
      const n = r.notAddressed.find(x => x.id === id)
      out.push({ id, reason: `${r.id} is blocked: ${n ? n.reason : r.notes || 'it needs a decision'}` })
    } else if (!r.merged) {
      out.push({ id, reason: `${r.id} ${r.outcome}` })
    } else {
      const x = r.notFixed.find(y => y.id === id)
      if (x) out.push({ id, reason: `${x.result} after ${r.attempts} fix(es): ${String(x.evidence).slice(0, 300)}` })
    }
  }
  const seen = new Set(out.map(e => e.id))
  return [...out, ...organizerEscalated.filter(e => !seen.has(e.id))]
}

function judge(p, v, t) {
  const testFailed = new Map()
  for (const f of (t ? t.failures : [])) if (f.owner === 'app' && f.finding) testFailed.set(f.finding, f)
  const results = v ? v.results : []
  const failing = []
  for (const x of results) {
    const tf = testFailed.get(x.id)
    if (x.result !== 'fixed') failing.push({ ...x, testFailed: !!tf })
    else if (tf) failing.push({ ...x, result: 'partly', evidence: `${x.evidence} But a test fails: ${tf.test}: ${tf.evidence}`, testFailed: true })
  }
  const seen = new Set(results.map(x => x.id))
  for (const [id, f] of testFailed) if (!seen.has(id)) failing.push({ id, result: 'partly', evidence: `A test fails: ${f.test}: ${f.evidence}`, testFailed: true })
  const stray = (t ? t.failures : []).filter(f => f.owner === 'app' && !f.finding)
  const regressions = v ? v.regressions : []
  return {
    failing,
    fixed: results.filter(x => x.result === 'fixed' && !testFailed.has(x.id)).map(x => x.id),
    unchecked: p.findings.filter(id => !seen.has(id) && !testFailed.has(id)),
    stray,
    regressions,
    needsFix: !!(failing.length || regressions.length || stray.length),
  }
}

function testSummary(t) {
  if (!t) return { passed: null, files: [], proven: [], device: [], failures: [], note: 'The tester did not return a result.' }
  return {
    passed: t.passed,
    files: t.filesChanged,
    proven: t.findings.filter(f => f.coverage === 'tested' && f.result === 'pass').map(f => f.id),
    device: t.findings.filter(f => f.coverage === 'device').map(f => f.id),
    failures: t.failures,
    note: t.notes || '',
  }
}

const union = (...lists) => [...new Set(lists.flat().filter(Boolean))]

async function verify(p, ctx, r, t, wt, check, fixNote) {
  for (let i = 0; i < 2; i++) {
    const v = await call(ctx.prio, verifyPrompt(p, ctx, r, t, wt, check, fixNote), {
      agentType: 'frontend-ux-reviewer',
      label: `verify ${p.id}${check > 1 ? ` · check ${check}` : ''}${i ? ' (again)' : ''}${ctx.sfx}`,
      phase: 'Packages',
      schema: VERIFIED,
      effort: 'high',
    })
    if (v) return v
  }
  return null
}

// Sets a package's worktree aside without merging it: its patch goes to the run folder.
async function setAside(id, wt) {
  if (!ISOLATE || !wt || same(wt, ROOT)) return ''
  const s = await enqueue({ kind: 'shelve', id, wt })
  return s && s.patch ? s.patch : ''
}

async function mergePackage(p, ctx, rec, wt) {
  let cur = wt
  for (let attempt = 1; attempt <= 3; attempt++) {
    const m = await enqueue({ kind: 'merge', id: p.id, wt: cur })
    if (!m) {
      if (attempt < 3) continue
      rec.patch = await setAside(p.id, cur)
      rec.outcome = 'not merged: the merge step returned nothing'
      return
    }
    if (m.error) {
      rec.patch = await setAside(p.id, cur)
      rec.outcome = `not merged: ${m.error}`
      return
    }
    if (!m.conflicts.length) {
      if (m.gone && !m.alreadyMerged && rec.filesChanged.length) {
        rec.outcome = 'lost: its worktree was gone before the merge'
        log(`${p.id}: its worktree ${cur} was gone before the merge, with ${rec.filesChanged.length} changed file(s) reported.`)
        return
      }
      rec.merged = true
      rec.applied = m.applied || []
      rec.applied.forEach(f => changedAll.add(f))
      rec.outcome = m.gone && !m.alreadyMerged ? 'nothing to merge' : attempt > 1 ? 'merged, after carrying it over' : 'merged'
      return
    }
    if (attempt === 3) {
      rec.patch = await setAside(p.id, cur)
      rec.outcome = `not merged: it still conflicts (${m.conflicts.map(c => c.path).join(', ')})`
      return
    }
    log(`${p.id} conflicted at merge (${m.conflicts.map(c => c.path).join(', ')}); carrying it over in a fresh worktree.`)
    const g = await call(ctx.prio, integratePrompt(p, ctx, cur, m.conflicts), {
      agentType: 'ux-implementer',
      isolation: 'worktree',
      label: `integrate ${p.id}${attempt > 1 ? ` (${attempt})` : ''}${ctx.sfx}`,
      phase: 'Packages',
      schema: IMPLEMENTED,
    })
    if (!g || g.status === 'failed' || !g.worktree || same(g.worktree, ROOT)) {
      rec.patch = await setAside(p.id, cur)
      if (g && g.worktree && !same(g.worktree, ROOT)) await setAside(`${p.id}-carry`, norm(g.worktree))
      rec.outcome = `not merged: carrying it over failed (${why(g)})`
      return
    }
    rec.filesChanged = union(rec.filesChanged, g.filesChanged)
    cur = norm(g.worktree)
  }
}

function newRecord(p, ctx) {
  return {
    id: p.id,
    title: p.title,
    area: p.area,
    findings: p.findings,
    planFile: ctx.planFile,
    round: ctx.round,
    status: 'failed',
    outcome: 'not started',
    merged: false,
    filesChanged: [],
    applied: [],
    notAddressed: [],
    deviceChecks: [],
    tests: null,
    attempts: 0,
    fixed: [],
    notFixed: [],
    unchecked: [],
    regressions: [],
    verifyReports: [],
    patch: '',
    notes: '',
  }
}

async function work(p, ctx, rec, depNote) {
  // 1. Implement, in a fresh worktree; once more if the first attempt fails.
  let r = null
  let wt = ''
  for (let attempt = 1; attempt <= 2; attempt++) {
    const extra = attempt > 1 ? `A first attempt failed: ${why(r)}. Start over in this new worktree.` : ''
    r = await call(ctx.prio, implementPrompt(p, ctx, depNote, extra), {
      agentType: 'ux-implementer',
      label: `implement ${p.id}${attempt > 1 ? ' (again)' : ''}${ctx.sfx}`,
      phase: 'Packages',
      schema: IMPLEMENTED,
      ...(ISOLATE ? { isolation: 'worktree' } : {}),
    })
    wt = ISOLATE && r && r.worktree ? norm(r.worktree) : ''
    if (r && ISOLATE && wt && same(wt, ROOT)) log(`${p.id}: the implementer reported the main checkout as its worktree; check the main checkout for stray edits.`)
    const bad = !r || r.status === 'failed' || (ISOLATE && (!wt || same(wt, ROOT)))
    if (!bad) break
    if (wt && !same(wt, ROOT)) await setAside(`${p.id}-attempt${attempt}`, wt)
    if (attempt === 2) {
      rec.status = r ? r.status : 'failed'
      rec.outcome = `failed: ${why(r)}`
      rec.notes = r && r.notes ? r.notes : ''
      return
    }
  }
  rec.status = r.status
  rec.filesChanged = [...r.filesChanged]
  rec.notAddressed = r.notAddressed
  rec.deviceChecks = r.deviceChecks || []
  rec.notes = r.notes || ''
  if (r.status === 'blocked') {
    rec.patch = await setAside(p.id, wt)
    rec.outcome = 'blocked: it needs a decision'
    return
  }

  // 2. Lock it with tests, and render its screens for the reviewer.
  let t = await call(ctx.prio, testPrompt(p, ctx, r, wt), {
    agentType: 'ux-tester',
    label: `test ${p.id}${ctx.sfx}`,
    phase: 'Packages',
    schema: TESTED,
  })
  rec.tests = testSummary(t)
  rec.filesChanged = union(rec.filesChanged, t ? t.filesChanged : [])
  let testsOk = !(t && t.failures.some(f => f.owner === 'app'))

  // 3. Check it; fix what falls short, and check again.
  let v = await verify(p, ctx, r, t, wt, 1, '')
  if (v) rec.verifyReports.push(v.reportPath)
  let state = judge(p, v, t)
  for (let k = 1; k <= FIXES && state.needsFix; k++) {
    const f = await call(ctx.prio, fixPrompt(p, ctx, state, t, wt), {
      agentType: 'ux-implementer',
      label: `fix ${p.id}${k > 1 ? ` (${k})` : ''}${ctx.sfx}`,
      phase: 'Packages',
      schema: IMPLEMENTED,
    })
    if (!f) break
    rec.attempts = k
    rec.filesChanged = union(rec.filesChanged, f.filesChanged)
    rec.deviceChecks = union(rec.deviceChecks, f.deviceChecks || [])
    const ran = f.checks.filter(isTest)
    if (ran.length) testsOk = ran.every(c => c.passed)
    if (testsOk && t) t = { ...t, failures: t.failures.filter(x => x.owner !== 'app') }
    const fixNote = [
      `A fix ran after check ${k}: ${f.status}.${f.notes ? ` ${f.notes}` : ''}`,
      `Its test run: ${ran.map(c => `${c.command}: ${c.passed ? 'passed' : 'failed'}${c.note ? ` (${c.note})` : ''}`).join('; ') || 'none reported'}.`,
      state.regressions.length ? `Regressions from check ${k}: ${state.regressions.map(g => `${g.id} (${g.title})`).join('; ')}. Say which still hold, keeping their IDs; number new ones after them.` : '',
    ].filter(Boolean).join(' ')
    const v2 = await verify(p, ctx, { ...r, status: f.status, filesChanged: rec.filesChanged }, t, wt, k + 1, fixNote)
    if (v2) {
      v = v2
      rec.verifyReports.push(v2.reportPath)
    }
    state = judge(p, v, t)
  }
  rec.fixed = state.fixed
  rec.notFixed = state.failing.map(({ id, result, evidence }) => ({ id, result, evidence }))
  rec.unchecked = state.unchecked
  rec.regressions = state.regressions
  if (state.stray.length) rec.notes = [rec.notes, `Existing tests still failing: ${state.stray.map(f => f.test).join('; ')}.`].filter(Boolean).join(' ')

  // 4. Merge it, unless its own tests still fail: then it waits, unmerged, for the owner.
  if (!ISOLATE) {
    rec.merged = true
    rec.outcome = 'done in the main checkout'
    rec.applied = rec.filesChanged
    rec.filesChanged.forEach(f => changedAll.add(f))
    return
  }
  if (!testsOk || state.stray.length) {
    rec.patch = await setAside(p.id, wt)
    rec.outcome = `not merged: its own tests still fail after ${rec.attempts} fix(es)${rec.patch ? `; patch ${rec.patch}` : ''}`
    return
  }
  await mergePackage(p, ctx, rec, wt)
}

async function runPackage(p, ctx, before) {
  const rec = newRecord(p, ctx)
  const notMerged = []
  for (const dep of before) {
    const d = await dep
    if (d && !d.merged) notMerged.push(`${d.id} (${d.outcome})`)
  }
  const deps = (p.dependsOn || []).filter(Boolean)
  const depNote = deps.length
    ? `It builds on ${deps.join(', ')}, from earlier in this run.${notMerged.length ? ` These were not merged, so check what is really there before building on them: ${notMerged.join('; ')}.` : ' What of it this run merged is in your worktree.'}`
    : ''
  const leave = await admit(p, ctx.prio)
  try {
    await work(p, ctx, rec, depNote)
  } catch (e) {
    rec.outcome = `failed: ${(e && e.message) || e}`
  } finally {
    leave()
  }
  log(`${p.id}: ${rec.outcome}; ${rec.fixed.length} of ${p.findings.length} finding(s) fixed${rec.tests ? `, ${rec.tests.proven.length} locked by a test` : ''}${rec.attempts ? `, after ${rec.attempts} fix(es)` : ''}${rec.regressions.length ? `, ${rec.regressions.length} regression(s) open` : ''}.`)
  return rec
}

// Runs a round's packages, each as soon as its dependencies are done and it is admitted.
async function runAll(list, round, planFile) {
  mergeRound = round
  const sfx = round > 1 ? ` · round ${round}` : ''
  const byId = new Map(list.map(p => [p.id, p]))
  // A dependency cycle would wait forever: drop the edges that close one.
  const state = new Map()
  const keep = new Map(list.map(p => [p.id, []]))
  const visit = id => {
    state.set(id, 1)
    for (const d of byId.get(id).dependsOn || []) {
      if (!byId.has(d)) continue
      if (state.get(d) === 1) {
        log(`${id} and ${d} depend on each other; ${id} won't wait for ${d}.`)
        continue
      }
      keep.get(id).push(d)
      if (!state.has(d)) visit(d)
    }
    state.set(id, 2)
  }
  list.forEach(p => { if (!state.has(p.id)) visit(p.id) })
  const done = new Map()
  const resolvers = new Map()
  list.forEach(p => done.set(p.id, new Promise(res => resolvers.set(p.id, res))))
  const all = list.map((p, i) => {
    const ctx = { round, planFile, prio: round * 1000 + i + 1, sfx }
    return runPackage(p, ctx, keep.get(p.id).map(d => done.get(d))).then(rec => {
      resolvers.get(p.id)(rec)
      return rec
    })
  })
  return Promise.all(all)
}

// ---------------------------------------------------------------- finish

async function finalCheck(round, recs, targeted) {
  const files = [...changedAll].sort()
  const fin = await call(0, targeted ? recheckPrompt(round, recs, targeted.files, targeted.also) : finalPrompt(round, recs, files), {
    agentType: 'ux-tester',
    label: targeted ? `re-check · round ${round}` : `final check${round > 1 ? ` · round ${round}` : ''}`,
    phase: 'Check',
    schema: TESTED,
  })
  return fin || { passed: false, checks: [], findings: [], failures: [], filesChanged: [], notes: `The ${targeted ? 're-check' : 'final check'} did not return a result.` }
}

// A test that fails in the final check overrides "fixed" for its finding. Returns the findings
// it took from "fixed", so a repair that makes the test pass can give them back.
function applyFinal(recs, fin) {
  const demoted = []
  for (const f of fin.failures.filter(x => x.owner === 'app')) {
    const owner = f.finding ? [...recs].reverse().find(r => r.merged && r.findings.includes(f.finding)) : null
    if (!owner) continue
    if (owner.fixed.includes(f.finding)) demoted.push({ rec: owner, id: f.finding })
    owner.fixed = owner.fixed.filter(x => x !== f.finding)
    if (!owner.notFixed.some(x => x.id === f.finding)) {
      owner.notFixed.push({ id: f.finding, result: 'partly', evidence: `A test fails in the final check: ${f.test}: ${f.evidence}` })
    }
  }
  return demoted
}

// What the final check finds short goes to one repair in the main checkout. Its check reruns
// the failing tests and covers what the repair changed: the whole suite never runs twice.
async function repair(round, recs, fin, demoted) {
  const failures = fin.failures.filter(f => f.owner === 'app')
  const failedChecks = fin.checks.filter(c => !c.passed && !isTest(c) && !/WRITE_\w*PREVIEWS/.test(c.command))
  if (!failures.length && !failedChecks.length) return null
  const r = await call(0, repairPrompt(round, recs, failures, failedChecks), {
    agentType: 'ux-implementer',
    label: `repair after the final check${round > 1 ? ` · round ${round}` : ''}`,
    phase: 'Check',
    schema: IMPLEMENTED,
  })
  if (!r) return null
  const files = (r.filesChanged || []).map(f => norm(f)).map(f => (f.startsWith(`${ROOT}/`) ? f.slice(ROOT.length + 1) : f))
  files.forEach(f => changedAll.add(f))
  const ran = r.checks.filter(isTest)
  const ok = r.status === 'done' && ran.length > 0 && ran.every(c => c.passed)
  log(`Repair after the final check: ${r.status}; its check ${ran.length ? (ok ? 'passed' : 'failed') : 'did not run'}; ${files.length} file(s) changed.`)
  if (ok) {
    for (const d of demoted) {
      d.rec.notFixed = d.rec.notFixed.filter(x => !(x.id === d.id && /^A test fails in the final check/.test(x.evidence)))
      if (!d.rec.fixed.includes(d.id) && !d.rec.notFixed.some(x => x.id === d.id)) d.rec.fixed.push(d.id)
    }
  }
  return { ok, files, notes: r.notes || '' }
}

async function finish(recs) {
  let round = Math.max(1, ...recs.map(r => r.round))
  const finals = []
  let fin = null
  let passed = true
  let open = [] // app failures of the final check that no repair cleared: the re-plan gets them
  let openSteps = [] // failed steps (the analyzer, gen-l10n, the APK build) that no repair cleared
  const infra = () => (fin ? fin.failures.filter(f => f.owner !== 'app') : [])
  if (recs.some(r => r.merged)) {
    fin = await finalCheck(round, recs)
    fin.filesChanged.forEach(f => changedAll.add(f))
    const demoted = applyFinal(recs, fin)
    finals.push({ round, passed: fin.passed, failures: fin.failures })
    log(`Final check after round ${round}: ${fin.passed ? 'passed' : 'failed'}; ${fin.failures.length} failure(s).`)
    passed = fin.passed
    open = fin.failures.filter(f => f.owner === 'app')
    openSteps = fin.checks.filter(c => !c.passed && !isTest(c))
    if (!fin.passed) {
      const fixed = await repair(round, recs, fin, demoted)
      if (fixed && fixed.ok) {
        open = []
        openSteps = []
        passed = !infra().length
        finals.push({ round, passed, failures: infra(), note: `repaired in the main checkout (${ids(fixed.files)}); its check reran the failing tests and the tests of what it changed, not the whole suite` })
      }
    }
  }
  for (let extra = 0; extra < EXTRA_ROUNDS; extra++) {
    const regressions = recs.flatMap(r => r.regressions.map(g => ({ ...g, pkg: r.id })))
    if (!open.length && !openSteps.length && !regressions.length) break
    const next = await call(0, replanPrompt(round, open, regressions, openSteps), {
      agentType: 'ux-organizer',
      label: `re-plan after round ${round}`,
      phase: 'Re-plan',
      schema: REPLANNED,
      effort: 'high',
    })
    if (!next) break
    organizerEscalated.push(...next.escalated)
    recs.forEach(r => {
      r.replanned = [...(r.replanned || []), ...r.regressions]
      r.regressions = []
    })
    if (!next.packages.length) break
    round++
    log(`Round ${round}: ${next.packages.length} package(s) re-planned.`)
    const more = await runAll(next.packages, round, `${a.runDir}/plan-${tag}r${round}.json`)
    recs.push(...more)
    if (more.some(r => r.merged)) {
      // The whole suite ran once already: re-check only this round's changes, and the tests that failed.
      const files = [...new Set(more.filter(r => r.merged).flatMap(r => r.applied))].sort()
      const re = await finalCheck(round, recs, { files, also: testFilesOf(open) })
      re.filesChanged.forEach(f => changedAll.add(f))
      applyFinal(recs, re)
      finals.push({ round, passed: re.passed, failures: re.failures, note: 're-check of the round\'s changes and the tests that failed before, not the whole suite' })
      log(`Re-check after round ${round}: ${re.passed ? 'passed' : 'failed'}; ${re.failures.length} failure(s).`)
      open = re.failures.filter(f => f.owner === 'app')
      openSteps = re.checks.filter(c => !c.passed && !isTest(c))
      passed = re.passed && !infra().length
    } else if (open.length || openSteps.length) {
      passed = false
    }
  }
  if ([...changedAll].some(f => /\.arb$/.test(f))) changedAll.add('App/lib/l10n/generated')
  const files = [...changedAll].sort()
  escalated = escalations(recs)

  const close = await call(0, closePrompt(recs, finals, files), {
    agentType: 'ux-organizer',
    label: 'record ledger and report',
    phase: 'Record',
    schema: CLOSED,
    effort: 'medium',
  })
  if (recordMemory) {
    await call(0, [
      `Mode: memory. UX loop run ${a.runId} just finished.`,
      `Read the verify-*.md files in ${RUN} (search them; read only what you need) and the run summary below, and update your memory with what is worth keeping: patterns the app now follows, changes to the screen map, recurring problem types.`,
      `Run summary: ${close ? close.verdict : 'not available'}`,
      'Issue statuses and owner decisions already live in .claude/ux-review/; do not copy them.',
    ].join('\n'), { agentType: 'frontend-ux-reviewer', label: 'record reviewer memory', phase: 'Record', effort: 'medium' })
  }
  return {
    runId: a.runId,
    runDir: a.runDir,
    reportName,
    rounds: round,
    testsPassed: passed,
    filesChanged: files,
    escalated,
    packages: recs.map(r => ({ id: r.id, round: r.round, outcome: r.outcome, fixed: r.fixed, notFixed: r.notFixed.map(x => x.id), patch: r.patch })),
    close,
  }
}

// ---------------------------------------------------------------- run

if (PART === 'finish') {
  const lanes = Array.isArray(a.laneResults) ? a.laneResults.filter(Boolean) : []
  if (!lanes.length) throw new Error('part "finish" needs laneResults: the result of every lane run.')
  const recs = lanes.flatMap(l => l.records || [])
  lanes.forEach(l => (l.filesChanged || []).forEach(f => changedAll.add(f)))
  const cpus = Math.max(...lanes.map(l => l.cpus || 0), 3)
  AGENTS = int(a.agents, Math.max(1, Math.min(16, cpus - 2)))
  FLIGHT = ISOLATE ? int(a.maxParallel, AGENTS + 2) : 1
  log(`Finishing ${lanes.length} lane(s): ${recs.length} package(s), ${recs.filter(r => r.merged).length} merged.`)
  return await finish(recs)
}

phase('Load')
const loaded = await agent([
  'Run exactly this one command and wait for it:',
  `${PY} "${ROOT}/.claude/skills/ux/scripts/pkg.py" "${RUN}" --headers --plan "${PLAN_ABS}"`,
  'It prints one JSON object. Return it as the structured result, unchanged: every package, every field, in order. Do nothing else.',
].join('\n'), {
  label: 'load plan',
  phase: 'Load',
  schema: LOADED,
  model: 'haiku',
  ...(ISOLATE ? { isolation: 'worktree' } : {}),
})
if (!loaded) {
  throw new Error(`The load step returned nothing. Check that ${PLAN_ABS} exists${ISOLATE ? `, and that this session's folder is ${ROOT}: worktrees are made from it` : ''}.`)
}
if (ISOLATE && (!loaded.toplevel || same(loaded.toplevel, ROOT) || !same(loaded.commonDir, `${ROOT}/.git`))) {
  // On 2026-10-31 a batch's worktrees failed this way, and all its packages ran one at a time.
  throw new Error(`Worktrees don't work from this session: the load step ran in ${loaded.toplevel || 'no worktree'} (git folder ${loaded.commonDir || 'unknown'}), not in a worktree of ${ROOT}. Move the session to ${ROOT} (cd there, or change_directory), check git worktree list, and start again; or pass worktrees: false to run every package in the main checkout, one at a time.`)
}
AGENTS = int(a.agents, Math.max(1, Math.min(16, (loaded.cpus || 4) - 2)))
FLIGHT = ISOLATE ? int(a.maxParallel, AGENTS + 2) : 1
const packages = loaded.packages.filter(p => !skip.has(p.id) && (!only || only.has(p.id)))
if (packages.length < loaded.packages.length) log(`Running ${packages.length} of ${loaded.packages.length} packages; the rest were skipped or limited.`)
if (!packages.length) {
  return { runId: a.runId, runDir: a.runDir, part: PART, lane: LANE, cpus: loaded.cpus, records: [], rounds: 0, testsPassed: true, filesChanged: [], escalated: [], close: null }
}
log(`${packages.length} package(s)${LANE ? ` in lane ${LANE}` : ''}: up to ${AGENTS} agents at once (${loaded.cpus} CPUs), ${FLIGHT} packages in flight, ${FILE_LIMIT} per file, ${SLOTS} heavy commands at once.`)
if (AGENTS <= 4 && packages.length > 2 * AGENTS && PART === 'all') {
  log(`This machine allows only ${AGENTS} agents per workflow. A plan this size runs faster in lanes, several runs at once: pkg.py --lanes auto (SKILL.md, "Lanes").`)
}

phase('Packages')
const records = await runAll(packages, 1, PLAN)

if (PART === 'packages') {
  return {
    runId: a.runId,
    runDir: a.runDir,
    part: 'packages',
    lane: LANE,
    cpus: loaded.cpus,
    records,
    filesChanged: [...changedAll].sort(),
    escalated: escalations(records),
  }
}
return await finish(records)
