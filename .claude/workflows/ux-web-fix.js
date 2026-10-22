export const meta = {
  name: 'ux-web-fix',
  description: 'TaskFlow UX web loop, part 2: packages that share no file are implemented and tested side by side, each in its own copy of the website with its own build mirror on WSL\'s disk, then merged; one round check runs the whole suite and the renders; web-ux-reviewer verifies only what changed; failures are re-planned (at most 2 extra rounds); then the ledger, report and reviewer memory are updated',
  whenToUse: 'Started by the /ux-web skill after ux-web-review, with the run folder whose plan.json should be carried out.',
  phases: [
    { title: 'Load', detail: 'read the package list, with each package\'s files, from plan.json' },
    { title: 'Implement', detail: 'waves of packages that share no file: each web-ux-implementer, then its own web-ux-tester, in their own copy of the website, side by side; then the merge, and an integrator for any conflict' },
    { title: 'Test', detail: 'the round check: web-ux-tester writes tests for packages done in the main checkout, then runs the type check, legal check, build, whole suite, unit tests and renders' },
    { title: 'Verify', detail: 'web-ux-reviewers on the fixed findings and changed files only, a few packages each, side by side' },
    { title: 'Re-plan', detail: 'web-ux-organizer turns what failed into a short new plan' },
    { title: 'Record', detail: 'ledger, run report and reviewer memory' },
  ],
}

// args, from the /ux-web skill:
//   runId, runDir, date
//   webDir:         the website repo, Windows path with forward slashes (optional; default below)
//   repoRoot:       the app repo (this loop's home), absolute, forward slashes. Without it,
//                   every package runs in the main checkout, one at a time.
//   maxParallel:    packages side by side in one wave; default 12 (owner, 2026-10-21)
//   heavySlots:     builds and Playwright runs at once in WSL; default 2 (WSL has about 7.5 GB)
//   skip:           [packageId] — packages the owner struck (optional)
//   only:           [packageId] — run just these (optional)
//   maxExtraRounds: number      — re-plan rounds after the first; default 2
//   batch:          string      — names this batch's files when a plan runs in several batches (optional)
//   recordMemory:   boolean     — false on every batch but the last (optional; default true)
//   notes:          string      — owner context from the conversation (optional)
const a = args || {}
if (!a.runId || !a.runDir) throw new Error('ux-web-fix needs runId and runDir. Start it with /ux-web.')
const EXTRA_ROUNDS = Number.isInteger(a.maxExtraRounds) ? a.maxExtraRounds : 2
const skip = new Set(Array.isArray(a.skip) ? a.skip : [])
const only = Array.isArray(a.only) && a.only.length ? new Set(a.only) : null
const batch = typeof a.batch === 'string' && a.batch ? a.batch : ''
const tag = batch ? `${batch}-` : ''
const reportName = batch ? `report-${batch}.md` : 'report.md'
const recordMemory = a.recordMemory !== false

const WEB = (a.webDir || 'C:/Users/mikig/Desktop/Custom/MikiHacks/TaskFlow/TaskFlowWeb').replace(/\\/g, '/').replace(/\/$/, '')
const toWsl = p => p.replace(/^([A-Za-z]):/, (m, d) => `/mnt/${d.toLowerCase()}`)
const WSL = toWsl(WEB)
const APP = (typeof a.repoRoot === 'string' && a.repoRoot ? a.repoRoot : WEB.replace(/\/[^/]+$/, '/TaskFlow')).replace(/\\/g, '/').replace(/\/$/, '')
const PARALLEL = typeof a.repoRoot === 'string' && !!a.repoRoot
const WIDTH = PARALLEL ? (Number.isInteger(a.maxParallel) && a.maxParallel > 0 ? a.maxParallel : 12) : 1
const SLOTS = Number.isInteger(a.heavySlots) && a.heavySlots > 0 ? a.heavySlots : 2
const WAVES = `MSYS_NO_PATHCONV=1 python -I -X utf8 "${APP}/.claude/ux-review/waves.py"`
// Every npm, npx and Playwright command runs on WSL's own disk, in a mirror of the checkout or
// copy, on its own port (webrun.py), and through the web pool's gate.
const MAIN_PORT = 3100
function webrun(src, name, port, serve) {
  return `${WAVES} gate --pool web --slots ${SLOTS} -- wsl -e python3 ${toWsl(APP)}/.claude/ux-web/webrun.py --src ${src} --name ${name} --port ${port}${serve ? ' --serve' : ''} --`
}
const MAIN_RUN = webrun(WSL, 'main', MAIN_PORT)
// The build served once, so the whole suite and the renders run side by side against it, each
// Playwright run with its own output folder.
const MAIN_SERVED = webrun(WSL, 'main', MAIN_PORT, true)
const SIDE_BY_SIDE = `${MAIN_SERVED} 'npx playwright test --reporter=dot --workers=6 > /tmp/ux-suite.log 2>&1 & s=$!; (rm -rf artifacts/ux-web && UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts --workers=4 --grep-invert "perf " --reporter=dot --output=test-results-renders > /tmp/ux-renders.log 2>&1) & r=$!; wait $s; se=$?; wait $r; re=$?; tail -n 40 /tmp/ux-suite.log; tail -n 15 /tmp/ux-renders.log; echo "suite exit $se, renders exit $re"'`
const PERF = `${MAIN_RUN} 'UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts --workers=1 --grep "perf " --reporter=dot'`
// A verifier checks at most this many packages, so a wide wave still gets focused checks.
const VERIFY_CHUNK = 4

// Agents sometimes report absolute paths. Website files become relative to the website root (or
// to a copy's root); app-repo files (the loop's own, such as KNOWN_FAILURES.md) relative to the
// app repo root.
function rel(file) {
  const p = String(file).replace(/\\/g, '/')
  const lower = p.toLowerCase()
  for (const root of [WEB, WSL, '../TaskFlowWeb']) {
    if (lower.startsWith(root.toLowerCase() + '/')) return p.slice(root.length + 1)
  }
  const copy = p.match(/\.taskflow-tools\/wt\/[^/]+\/(.+)$/)
  if (copy) return copy[1]
  if (lower.startsWith(APP.toLowerCase() + '/')) return p.slice(APP.length + 1)
  return p
}
const isAppFile = f => /^(\.claude|App|Backend)\//.test(f)

// Reading discipline for the checking steps. Whole files are what made the app loop's trial
// expensive: every big read is written to cache once, then re-read on every later turn.
const PKG = `python -I -X utf8 .claude/ux-review/pkg.py ${a.runDir}`
const LEAN = [
  `Read packages with: ${PKG} <ids> --conventions (from the app repo). Never open plan.json or plan-*.json directly; they are large.`,
  `Read a finding with: grep -n -A 30 "<ID>" ${a.runDir}/review-*.md. Never read a whole review report.`,
  'Read source files in the parts you need (search first, then read with offset and limit), and only the renders of pages that changed (artifacts/ux-web/INDEX.md maps them).',
].join('\n')

const HEADER = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    title: { type: 'string' },
    area: { type: 'string' },
    size: { type: 'string' },
    findings: { type: 'array', items: { type: 'string' } },
    dependsOn: { type: 'array', items: { type: 'string' } },
    files: { type: 'array', items: { type: 'string' }, description: 'The website files the package expects to change, relative to its root, as its "files" lists them' },
  },
  required: ['id', 'title', 'area', 'size', 'findings'],
}
const LOADED = {
  type: 'object',
  properties: { packages: { type: 'array', items: HEADER } },
  required: ['packages'],
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
    filesChanged: { type: 'array', items: { type: 'string' }, description: 'Website paths, relative to its root' },
    addressed: { type: 'array', items: { type: 'string' } },
    notAddressed: { type: 'array', items: MISSED },
    checks: { type: 'array', items: CHECK },
    deviceChecks: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string', description: 'Include every changed file that holds another session\'s uncommitted work' },
    worktree: { type: 'string', description: 'In a copy: its Windows path, as the add command printed it. Otherwise empty.' },
  },
  required: ['status', 'filesChanged', 'addressed', 'notAddressed', 'checks'],
}
const FINDING_TEST = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    coverage: { type: 'string', enum: ['tested', 'render', 'device', 'none'] },
    tests: { type: 'array', items: { type: 'string' }, description: 'file :: test name' },
    result: { type: 'string', enum: ['pass', 'fail', 'n/a'] },
    note: { type: 'string' },
  },
  required: ['id', 'coverage', 'result'],
}
const TESTED = {
  type: 'object',
  properties: {
    passed: { type: 'boolean', description: 'True when every new test passes and nothing fails outside KNOWN_FAILURES.md' },
    checks: { type: 'array', items: CHECK },
    findings: { type: 'array', items: FINDING_TEST },
    failures: {
      type: 'array',
      description: 'Failures still open after you fixed your own tests: the site falls short, or infrastructure you could not fix',
      items: {
        type: 'object',
        properties: {
          test: { type: 'string' },
          owner: { type: 'string', enum: ['site', 'infrastructure'] },
          finding: { type: 'string', description: 'The finding it proves, if any' },
          evidence: { type: 'string' },
        },
        required: ['test', 'owner', 'evidence'],
      },
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
        },
        required: ['id', 'applied', 'conflicts'],
      },
    },
    removed: { type: 'array', items: { type: 'string' } },
  },
  required: ['packages'],
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
    regressions: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          severity: { type: 'integer' },
          title: { type: 'string' },
          where: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['id', 'severity', 'title', 'where', 'fix'],
      },
    },
    notesText: { type: 'string', description: 'Only if writing the notes file was refused: the full notes' },
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

// ---------------------------------------------------------------- waves

// Files every package may touch: the site's copy (src/content), the stylesheets and the tests merge
// line by line, and two insertions at one place keep both; a real conflict goes to an integrator,
// and the round check's renders catch styles that clash. They never keep packages apart. With
// styles counted, the first whole-site plan's 23 packages take 7 waves instead of 12.
const MERGEABLE = /^(src\/content\/|src\/styles\/|tests\/)/
function footprint(p) {
  const files = (Array.isArray(p.files) ? p.files : [])
    .map(f => rel(String(f)).replace(/^\.\//, '').replace(/^TaskFlowWeb\//, '').split(/[\s:#(]/)[0])
    .filter(Boolean)
  // A package with no file list could touch anything: it runs alone.
  return { solo: !files.length, files: new Set(files.filter(f => !MERGEABLE.test(f))) }
}

// Each package goes in the earliest wave after its dependencies whose packages share none of
// its files. Plan order decides ties.
function planWaves(list) {
  if (WIDTH <= 1) return list.map(p => [p])
  const waves = []
  const at = {}
  for (const p of list) {
    const fp = footprint(p)
    const deps = (p.dependsOn || []).filter(d => d in at).map(d => at[d] + 1)
    let i = deps.length ? Math.max(...deps) : 0
    const fits = w => !fp.solo && w.length < WIDTH && !w.some(o => o.fp.solo || [...fp.files].some(f => o.fp.files.has(f)))
    while (i < waves.length && !fits(waves[i])) i++
    if (i === waves.length) waves.push([])
    waves[i].push({ p, fp })
    at[p.id] = i
  }
  return waves.map(w => w.map(x => x.p))
}

// ---------------------------------------------------------------- prompts

// Verify notes a reviewer couldn't save: passed on inline, and saved by the main session.
const inlineNotes = []
function notesAppendix(round) {
  const notes = inlineNotes.filter(n => round === undefined || n.round === round)
  return notes.length
    ? ['', 'Verify notes that could not be saved as files:', ...notes.flatMap(n => ['', `===== ${n.path} =====`, n.text])]
    : []
}

function packageLine(r) {
  const missed = r.notAddressed.length
    ? `; not addressed: ${r.notAddressed.map(n => `${n.id} (${n.reason})`).join('; ')}`
    : ''
  return `- ${r.id} in ${r.planFile}: ${r.findings.join(', ')}. Implementer: ${r.status}${missed}`
}

const copyName = (p, round) => `${a.runId}-${tag}r${round}-${p.id}`.replace(/[^A-Za-z0-9._-]/g, '')

function implementPrompt(p, round, planFile, copy) {
  const lines = [
    `UX web loop run ${a.runId}, round ${round}. Implement work package ${p.id}: ${p.title}.`,
    `Area ${p.area}, size ${p.size}, findings ${p.findings.join(', ')}.`,
  ]
  if (copy) {
    lines.push(
      `You work in your own copy of the website, made for you; other implementers work at the same time in theirs, on packages that share no file with yours. Never edit the main checkout at ${WEB}.`,
      `Before anything else, run: ${WAVES} add --repo ${WEB} --name ${copy.name}`,
      'It prints your copy\'s Windows path ("worktree"), seeded with the website\'s uncommitted state. Edit only files under that path, with absolute Windows paths. Package paths are relative to its root.',
      `Run every npm, npx and Playwright command as: ${webrun(`<your copy's Windows path>`, copy.name, copy.port)} '<command>'`,
      `That runs it on WSL's own disk, in a mirror of your copy, on port ${copy.port}, and copies artifacts/ and test-results/ back into your copy. Your renders land in <your copy>/artifacts/ux-web/.`,
      'Return your copy\'s Windows path in "worktree".',
    )
  } else {
    lines.push(
      `Website repo: ${WEB}.`,
      `Run every npm, npx and Playwright command as: ${MAIN_RUN} '<command>'`,
      `That runs it on WSL's own disk, in a mirror of the checkout, on port ${MAIN_PORT}, and copies artifacts/ and test-results/ back into ${WEB}.`,
    )
  }
  if (Array.isArray(p.dependsOn) && p.dependsOn.length) lines.push(`It builds on ${p.dependsOn.join(', ')}, done earlier in this run.`)
  lines.push(
    `Your instructions are package ${p.id} in ${planFile}: its brief, files, acceptance checks and device checks, plus the plan's shared conventions. Print exactly those with: ${PKG} ${p.id} --conventions`,
    LEAN,
    'Earlier packages in this run may already have changed the code; build on their work.',
    'Test files listed in the package are for web-ux-tester, who writes the acceptance tests after you. Only update existing tests your change breaks.',
    'Run npm run build before any Playwright run: the config serves the last build. Run only the specs that cover your change, never the whole suite: the round check runs it.',
    `Another session may have uncommitted work in the website (git -C ${WEB} status). Change those files only where your brief says, never reformat them, and name them in your notes.`,
  )
  if (a.notes) lines.push(`From the owner, this session: ${a.notes}`)
  lines.push('Return the structured result.')
  return lines.join('\n')
}

function integratePrompt(p, round, wt, conflicts) {
  return [
    `UX web loop run ${a.runId}, round ${round}. Mode: integrate. Work package ${p.id}: ${p.title}.`,
    `Area ${p.area}, findings ${p.findings.join(', ')}.`,
    `${p.id} was implemented and tested side by side with other packages, in its own copy at ${wt}. Merging it into the website's main checkout conflicted with packages merged just before it:`,
    ...conflicts.map(c => `- ${c.path}: ${c.why}`),
    `Bring all of ${p.id}'s changes into ${WEB}, by hand, on top of what is there now. Its whole patch, code and tests: ${WAVES} diff --worktree ${wt}`,
    'Keep both packages\' intent where they meet. If they truly contradict, keep what is already in the main checkout, and say so in your notes.',
    `Then check it: ${MAIN_RUN} 'npm run check', then 'npm run build', then the specs that cover the files you touched.`,
    `When it is in, remove the copy: ${WAVES} drop --worktree ${wt}`,
    `Your instructions are package ${p.id}, as before: ${PKG} ${p.id} --conventions`,
    LEAN,
    a.notes ? `From the owner, this session: ${a.notes}` : '',
    'Return the structured result: filesChanged is every website file you changed in the main checkout; worktree is empty.',
  ].filter(Boolean).join('\n')
}

function packageTestPrompt(p, round, r, copy) {
  return [
    `UX web loop run ${a.runId}, round ${round}. Mode: package. Lock work package ${p.id} with Playwright tests: ${p.title}.`,
    `Area ${p.area}, findings ${p.findings.join(', ')}. Its implementer reported: ${r.status}${r.notAddressed.length ? `; not addressed: ${r.notAddressed.map(n => `${n.id} (${n.reason})`).join('; ')}` : ''}.`,
    `It was implemented in its own copy of the website at ${r.worktree}, and other packages are being implemented and tested side by side in theirs. Work only there: write tests under ${r.worktree}/tests, with absolute Windows paths. Never touch the main checkout at ${WEB}.`,
    `Files the implementer changed: ${r.filesChanged.length ? r.filesChanged.join(', ') : 'none reported'}.`,
    `Run every npm, npx and Playwright command as: ${webrun(r.worktree, copy.name, copy.port)} '<command>'`,
    `Write the tests for ${p.id}'s acceptance checks only, as your instructions say. Then: npm run build, and your new tests with the existing specs of the pages it changed.`,
    'Skip the round\'s check: no whole suite, no unit tests, no full renders. The round check runs those once every package is merged.',
    'Parts of a package marked "waits on WD#" were left out on purpose; do not test them.',
    LEAN,
    'Return the structured result for this package only. filesChanged lists your test files, relative to the website root.',
  ].join('\n')
}

function mergePrompt(items) {
  const pairs = items.map(x => `--worktree ${x.p.id}=${x.r.worktree}`).join(' ')
  return [
    'Run exactly this one command, from anywhere, and wait for it:',
    `${WAVES} merge ${pairs} --no-gen`,
    'It merges each package\'s copy into the website\'s main checkout, in this order, removes the merged copies and their build mirrors, and prints one JSON object. Return that JSON as the structured result, unchanged. Do nothing else: no other command, no edits.',
  ].join('\n')
}

// The whole check: the type and legal checks, a production build, then the whole suite and the
// renders side by side against that one build, the unit tests, and lab performance on its own.
const FULL_CHECK = [
  `The check, in order: ${MAIN_RUN} 'npm run check'; then 'npm run legal:check'; then 'SITE_URL=https://taskflow.garbar.tech npm run build'.`,
  `Then the whole suite and the renders side by side, against that build, as exactly this one command: ${SIDE_BY_SIDE}`,
  'It takes about 11 minutes (on 2026-10-22 the suite alone was 1392 tests in 10.8 minutes), longer than one tool call may run: start it with the Bash tool\'s run_in_background, then wait for it to finish before reading its output.',
  `Then ${MAIN_RUN} 'npm run test:unit', and lab performance on its own: ${PERF}`,
  'Then check the acceptance checks that artifacts/ux-web/AUDIT.md measures against its rows.',
].join('\n')

function finalPrompt(round, files, findings) {
  return [
    `UX web loop run ${a.runId}. Mode: final check, after round ${round}. The redo rounds are done, and their checks passed on what they changed. Now run the whole check once. Write no new tests. Website repo: ${WEB}.`,
    `Files changed in this run: ${files.length ? files.join(', ') : 'none reported'}.`,
    FULL_CHECK,
    `Report every failing test against its finding (the run's findings: ${findings.join(', ')}), or with no finding if it proves none, and class each as the site's or the infrastructure's. Return the structured result.`,
  ].join('\n')
}

function roundTestPrompt(round, impl, files, locked, unlocked, targeted) {
  const lines = [
    `UX web loop run ${a.runId}, round ${round}. Lock this round's fixes with Playwright tests, then run the round's check. Website repo: ${WEB}.`,
    'Packages implemented this round:',
    ...impl.map(packageLine),
    `Files changed this round: ${files.length ? files.join(', ') : 'none reported'}.`,
  ]
  if (locked.length) {
    lines.push(
      'Already locked by their own testers, in their copies, and merged in: don\'t write tests for these again; your check runs their tests with the rest.',
      ...locked.map(t => `- ${t.id}: ${t.findings.map(f => `${f.id} ${f.coverage}/${f.result}${f.tests && f.tests.length ? ` (${f.tests.join('; ')})` : ''}`).join(', ') || 'no findings reported'}${t.failures.length ? `. Failing there: ${t.failures.map(f => `${f.test} (${f.owner}${f.finding ? `, ${f.finding}` : ''})`).join('; ')}` : ''}`),
    )
  }
  lines.push(
    unlocked.length
      ? `Write tests for these packages only: ${unlocked.map(r => r.id).join(', ')}.`
      : 'No package needs new tests from you: run the round\'s check.',
    LEAN,
    `Run every npm, npx and Playwright command as: ${MAIN_RUN} '<command>'`,
    targeted
      ? 'This is a redo round, so the check covers what changed: npm run check; npm run legal:check if legal content changed; SITE_URL=https://taskflow.garbar.tech npm run build; your new tests and the specs of the pages this round changed; and the renders of those pages only (UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts --workers=6 --reporter=dot -g "<page> "). No whole suite, unit tests, full renders or lab performance: the final check runs them once, when the redo rounds are done.'
      : FULL_CHECK,
    'Parts of a package marked "waits on WD#" were left out on purpose; do not test them.',
    'Class every failure as the site\'s or the infrastructure\'s, including tests the package testers wrote. Return the structured result. In "findings", cover every package of the round: copy what the package testers proved, unless your run shows otherwise.',
  )
  return lines.join('\n')
}

function verifyPrompt(round, area, part, items, tested) {
  const files = [...new Set(items.flatMap(r => r.filesChanged))]
  const ids = new Set(items.flatMap(r => r.findings))
  const testLines = tested.findings
    .filter(f => ids.has(f.id))
    .map(f => `- ${f.id}: ${f.coverage}, ${f.result}${f.tests && f.tests.length ? ` (${f.tests.join('; ')})` : ''}${f.note ? `. ${f.note}` : ''}`)
  const key = `${area}${part}`
  return [
    `Mode: verify. UX web loop run ${a.runId}, round ${round}, area ${area}. Today is ${a.date}. Website repo: ${WEB}.`,
    'Check only these work packages and their findings:',
    ...items.map(packageLine),
    LEAN,
    'Parts of a package marked "waits on WD#" were left out on purpose (an owner decision is pending); do not count them as not fixed.',
    `Files changed in this run: ${files.length ? files.join(', ') : 'none reported'}. See only what this run changed with: bash .claude/ux-web/ux-web.sh diff -- <file> (from the app repo; it leaves out another session's uncommitted work).`,
    'What the testers proved for these findings (a failing test means the acceptance check is not met):',
    ...(testLines.length ? testLines : ['- nothing reported']),
    'Judge every listed finding as fixed, partly or not_fixed, with evidence. Then look for regressions, only in these files and the pages they touch.',
    `Number regressions R${round}${key}-1, R${round}${key}-2 and so on; the organizer gives them final IDs.`,
    `The tester re-rendered every page just now: start with ${WEB}/artifacts/ux-web/INDEX.md and read only the renders of pages that changed. Do not run npm or Playwright. Another step records memory.`,
    `Write your notes to ${a.runDir}/verify-${tag}r${round}-${key}.md, then return the structured result. If writing the file is refused, put the notes in "notesText" instead.`,
  ].join('\n')
}

function replanPrompt(round, failing, regressions, unchecked, tested, impl, failures) {
  const twice = failing.filter(f => failures[f.id] >= 2).map(f => f.id)
  const failedChecks = tested.checks.filter(c => !c.passed).map(c => c.command + (c.note ? ` (${c.note})` : ''))
  const lines = [
    `Mode: replan. UX web loop run ${a.runId}, after round ${round}. Today is ${a.date}. Run folder: ${a.runDir}. Website repo: ${WEB}.`,
    'Not fixed yet:',
    ...(failing.length ? failing.map(f => `- ${f.id}: ${f.result}, failed ${failures[f.id]} time(s). ${f.evidence}`) : ['- none']),
    'Regressions:',
    ...(regressions.length ? regressions.map(r => `- ${r.id}, severity ${r.severity}: ${r.title}. ${r.where}. Fix: ${r.fix}`) : ['- none']),
    'Failing tests (from web-ux-tester):',
    ...(tested.failures.length ? tested.failures.map(f => `- ${f.test} (${f.owner}${f.finding ? `, ${f.finding}` : ''}): ${f.evidence}`) : ['- none']),
  ]
  if (unchecked.length) lines.push(`Not checked by the reviewer, so plan them again: ${unchecked.join(', ')}`)
  lines.push(
    tested.passed ? 'Round check: passed.' : `Round check: failed. ${failedChecks.join('; ') || tested.notes || ''}`,
    'Implementer notes:',
    ...impl.map(r => `- ${r.id}: ${r.status}${r.notes ? `. ${r.notes}` : ''}`),
  )
  if (twice.length) lines.push(`Failed twice, so escalate instead of re-planning: ${twice.join(', ')}`)
  lines.push(
    LEAN,
    `Read only this round's verify notes (${a.runDir}/verify-${tag}r${round}-*.md) and the packages involved. In .claude/ux-web/ISSUES.md, edit only the lines you change.`,
    'Give every new package its "files" (paths relative to the website root), as plan.json does: packages that share no file are implemented side by side.',
    `Write the new packages to ${a.runDir}/plan-${tag}r${round + 1}.json (same structure as plan.json), append them to plan.md under "Round ${round + 1}${batch ? ` (${batch})` : ''}", add regressions to .claude/ux-web/ISSUES.md with final IDs, then return the structured result.`,
    ...notesAppendix(round),
  )
  return lines.join('\n')
}

function closePrompt(rounds, escalated, files) {
  const ids = list => (list.length ? list.join(', ') : 'none')
  return [
    `Mode: close. UX web loop run ${a.runId}. Today is ${a.date}. Run folder: ${a.runDir}. Website repo: ${WEB}.`,
    `Rounds: ${rounds.length}.`,
    ...rounds.map(r => [
      `- Round ${r.round} (${r.planFile}):`,
      `packages ${r.packages.map(p => `${p.id} ${p.status}`).join(', ')};`,
      `waves ${r.waves};`,
      `tests ${r.tests.passed ? 'passed' : 'failed'}, proven by test ${ids(r.tests.proven)}, device-only ${ids(r.tests.device)};`,
      `verification ${ids(r.verifyReports)};`,
      `fixed ${ids(r.results.filter(x => x.result === 'fixed').map(x => x.id))};`,
      `not yet ${ids(r.failing.map(x => x.id))};`,
      `regressions ${ids(r.regressions.map(x => x.id))};`,
      `unchecked ${ids(r.unchecked)}.`,
    ].join(' ')),
    `Escalated: ${escalated.length ? escalated.map(e => `${e.id} (${e.reason})`).join('; ') : 'none'}.`,
    `Files changed: ${ids(files)}. Mark those that hold another session's uncommitted work (git -C ${WEB} status --porcelain): the main session can commit only the run's own lines there.`,
    'A finding counts as verified only if the last round that checked it said "fixed" and no test for it failed. Note which verified findings are locked by a test. Device checks stay listed for the owner.',
    `Work from the round summaries above and this batch's verify notes (${a.runDir}/verify-${tag}*.md); don't re-read the plan or the review reports. In .claude/ux-web/ISSUES.md, find each finding's line with grep and edit only those lines.`,
    `Update .claude/ux-web/ISSUES.md, then return the structured result with the full report in "report". Don't write a report file yourself; the main session saves it as ${a.runDir}/${reportName}${batch ? ` (this batch: ${batch})` : ''}.`,
    ...notesAppendix(),
  ].join('\n')
}

// ---------------------------------------------------------------- run

phase('Load')
const loaded = await agent(
  `Read ${a.runDir}/plan.json and return the header of every package in its "packages" array, in order: id, title, area, size, findings, dependsOn, files. Copy the values exactly.`,
  { label: 'load plan', phase: 'Load', schema: LOADED, effort: 'low' },
)
if (!loaded || !loaded.packages.length) throw new Error(`No packages found in ${a.runDir}/plan.json.`)
let packages = loaded.packages.filter(p => !skip.has(p.id) && (!only || only.has(p.id)))
if (packages.length < loaded.packages.length) {
  log(`Running ${packages.length} of ${loaded.packages.length} packages; the rest were skipped or limited.`)
}
if (!packages.length) {
  return { runId: a.runId, runDir: a.runDir, reportName, rounds: 0, testsPassed: true, filesChanged: [], webFiles: [], appFiles: [], escalated: [], close: null, inlineNotes }
}

const rounds = []
const failures = {}
const escalated = []
const changedAll = new Set()
let planFile = `${a.runDir}/plan.json`
let tested = null

const noResult = p => ({
  status: 'failed',
  filesChanged: [],
  addressed: [],
  notAddressed: p.findings.map(id => ({ id, reason: 'The implementer did not return a result.' })),
  checks: [],
})

for (let round = 1; ; round++) {
  phase('Implement')
  const impl = []
  const locked = []
  const record = (p, r, files, t) => {
    const changed = [...new Set([...(files || r.filesChanged), ...(t ? t.filesChanged : [])].map(rel))]
    changed.forEach(f => changedAll.add(f))
    impl.push({ ...r, filesChanged: changed, id: p.id, area: p.area, findings: p.findings, planFile })
    if (t) locked.push({ ...t, id: p.id })
    log(`${p.id} ${r.status}: ${r.addressed.length} of ${p.findings.length} finding(s) addressed${t ? `; locked by ${t.findings.filter(f => f.coverage === 'tested').length} test(s)` : ''}.`)
  }
  const inMain = async (p, extra) => {
    const r = await agent(implementPrompt(p, round, planFile, null) + (extra ? `\n${extra}` : ''), {
      agentType: 'web-ux-implementer',
      label: `implement ${p.id}${round > 1 ? ` · round ${round}` : ''}`,
      phase: 'Implement',
      schema: IMPLEMENTED,
    })
    record(p, r || noResult(p), null, null)
  }

  const waves = planWaves(packages)
  const shape = waves.map(w => w.length).join(', ')
  log(`Round ${round}: ${packages.length} package(s) in ${waves.length} wave(s) (${shape}), up to ${WIDTH} side by side, ${SLOTS} builds at once in WSL.`)

  for (const [n, wave] of waves.entries()) {
    if (wave.length === 1) {
      await inMain(wave[0])
      continue
    }
    // Side by side: each package's implementer, then its tester, in the package's own copy.
    const done = await parallel(wave.map((p, i) => async () => {
      const copy = { name: copyName(p, round), port: MAIN_PORT + 1 + i }
      const r = await agent(implementPrompt(p, round, planFile, copy), {
        agentType: 'web-ux-implementer',
        label: `implement ${p.id}${round > 1 ? ` · round ${round}` : ''}`,
        phase: 'Implement',
        schema: IMPLEMENTED,
      })
      if (!r || !r.worktree || r.status === 'failed') return { p, r, t: null }
      const t = await agent(packageTestPrompt(p, round, r, copy), {
        agentType: 'web-ux-tester',
        label: `test ${p.id}${round > 1 ? ` · round ${round}` : ''}`,
        phase: 'Implement',
        schema: TESTED,
      })
      return { p, r, t }
    }))
    const items = wave.map((p, i) => done[i] || { p, r: null, t: null })
    const ready = items.filter(x => x.r && x.r.worktree && x.r.status !== 'failed')
    const merged = ready.length
      ? await agent(mergePrompt(ready), {
        label: `merge wave ${n + 1}${round > 1 ? ` · round ${round}` : ''}`,
        phase: 'Implement',
        schema: MERGED,
        effort: 'low',
      })
      : null
    const byId = new Map((merged ? merged.packages : []).map(m => [m.id, m]))
    // Merged ones first, then conflicts and failures one at a time in the main checkout.
    const later = []
    for (const x of items) {
      const m = byId.get(x.p.id)
      if (x.r && m && !m.conflicts.length) record(x.p, x.r, m.applied, x.t)
      else later.push({ ...x, m })
    }
    for (const x of later) {
      if (x.r && x.m && x.m.conflicts.length) {
        log(`${x.p.id} conflicted at merge (${x.m.conflicts.map(c => c.path).join(', ')}); integrating by hand.`)
        const r = await agent(integratePrompt(x.p, round, x.r.worktree, x.m.conflicts), {
          agentType: 'web-ux-implementer',
          label: `integrate ${x.p.id}${round > 1 ? ` · round ${round}` : ''}`,
          phase: 'Implement',
          schema: IMPLEMENTED,
        })
        record(x.p, r || noResult(x.p), null, r ? x.t : null)
      } else {
        const why = !x.r ? 'its implementer returned nothing' : !x.r.worktree ? 'it reported no copy' : x.r.status === 'failed' ? `it failed: ${x.r.notes || 'no notes'}` : 'the merge returned nothing'
        log(`${x.p.id} could not run side by side (${why}); redoing it in the main checkout.`)
        await inMain(x.p, `It was first tried in its own copy, side by side with other packages, and ${why}. Work in the main checkout this time.`)
      }
    }
  }

  phase('Test')
  const roundFiles = [...new Set(impl.flatMap(r => r.filesChanged))]
  const lockedIds = new Set(locked.map(t => t.id))
  const unlocked = impl.filter(r => !lockedIds.has(r.id))
  // Round 1 runs the whole check; redo rounds check what they changed, and the final check
  // runs the whole check once at the end.
  tested = (await agent(roundTestPrompt(round, impl, roundFiles, locked, unlocked, round > 1), {
    agentType: 'web-ux-tester',
    label: `test · round ${round}`,
    phase: 'Test',
    schema: TESTED,
  })) || { passed: false, checks: [], findings: [], failures: [], filesChanged: [], notes: 'The tester did not return a result.' }
  tested.filesChanged = tested.filesChanged.map(rel)
  tested.filesChanged.forEach(f => changedAll.add(f))
  // What the package testers proved, unless the round check says otherwise.
  const byFinding = new Map()
  locked.forEach(t => t.findings.forEach(f => byFinding.set(f.id, f)))
  tested.findings.forEach(f => byFinding.set(f.id, f))
  tested.findings = [...byFinding.values()]
  const proven = tested.findings.filter(f => f.coverage === 'tested' && f.result === 'pass').map(f => f.id)
  const device = tested.findings.filter(f => f.coverage === 'device').map(f => f.id)
  log(`Tests, round ${round}: ${tested.passed ? 'passed' : 'failed'}; ${proven.length} finding(s) proven by a test, ${tested.failures.length} failure(s) open.`)

  phase('Verify')
  const groups = []
  for (const area of [...new Set(impl.map(r => r.area))]) {
    const inArea = impl.filter(r => r.area === area)
    const parts = Math.ceil(inArea.length / VERIFY_CHUNK)
    for (let k = 0; k < parts; k++) {
      groups.push({ area, part: parts > 1 ? String(k + 1) : '', items: inArea.slice(k * VERIFY_CHUNK, (k + 1) * VERIFY_CHUNK) })
    }
  }
  const checked = (await parallel(groups.map(g => () =>
    agent(verifyPrompt(round, g.area, g.part, g.items, tested), {
      agentType: 'web-ux-reviewer',
      label: `verify ${g.area}${g.part} · round ${round}`,
      phase: 'Verify',
      schema: VERIFIED,
      effort: 'high',
    }).then(v => v && { ...v, key: `${g.area}${g.part}` })
  ))).filter(Boolean)
  checked
    .filter(v => v.notesText)
    .forEach(v => inlineNotes.push({ round, path: `${a.runDir}/verify-${tag}r${round}-${v.key}.md`, text: v.notesText }))
  const results = checked.flatMap(v => v.results)
  const regressions = checked.flatMap(v => v.regressions)
  const seen = new Set(results.map(x => x.id))
  const unchecked = impl.flatMap(r => r.findings).filter(id => !seen.has(id))
  // A failing acceptance test overrides a "fixed" verdict, here or from an earlier round.
  const judge = () => {
    const testFailed = {}
    tested.failures.filter(f => f.owner === 'site' && f.finding).forEach(f => { testFailed[f.finding] = f })
    const list = results
      .filter(x => x.result !== 'fixed' || testFailed[x.id])
      .map(x => (x.result === 'fixed'
        ? { ...x, result: 'partly', evidence: `${x.evidence} But a test fails: ${testFailed[x.id].test}: ${testFailed[x.id].evidence}` }
        : x))
    const here = new Set(results.map(x => x.id))
    Object.values(testFailed).filter(f => !here.has(f.finding)).forEach(f => {
      list.push({ id: f.finding, result: 'partly', evidence: `Fixed in an earlier round, but a test fails now: ${f.test}: ${f.evidence}` })
    })
    return { list, stray: tested.failures.filter(f => f.owner === 'site' && !f.finding) }
  }
  let { list: failing, stray: strayTestFailures } = judge()
  let clean = !failing.length && !regressions.length && !strayTestFailures.length && !unchecked.length && tested.passed
  // Redo rounds checked only what they changed: the whole check runs once, now.
  if (clean && round > 1) {
    phase('Test')
    const findings = [...new Set([...rounds.flatMap(r => r.results.map(x => x.id)), ...results.map(x => x.id)])]
    const fin = (await agent(finalPrompt(round, [...changedAll], findings), {
      agentType: 'web-ux-tester',
      label: `final check · round ${round}`,
      phase: 'Test',
      schema: TESTED,
    })) || { passed: false, checks: [], findings: [], failures: [], filesChanged: [], notes: 'The final check did not return a result.' }
    fin.filesChanged.map(rel).forEach(f => changedAll.add(f))
    tested = {
      ...tested,
      passed: fin.passed,
      checks: [...tested.checks, ...fin.checks],
      failures: [...tested.failures, ...fin.failures],
      notes: [tested.notes, fin.notes].filter(Boolean).join(' '),
    }
    ;({ list: failing, stray: strayTestFailures } = judge())
    clean = !failing.length && !strayTestFailures.length && tested.passed
    log(`Final check after round ${round}: ${fin.passed ? 'passed' : 'failed'}; ${fin.failures.length} failure(s).`)
  }
  failing.forEach(f => { failures[f.id] = (failures[f.id] || 0) + 1 })
  rounds.push({
    round,
    planFile,
    waves: shape,
    packages: impl.map(r => ({ id: r.id, status: r.status })),
    tests: { passed: tested.passed, proven, device },
    verifyReports: checked.map(v => (v.notesText ? `${a.runDir}/verify-${tag}r${round}-${v.key}.md (inline)` : v.reportPath)),
    results,
    failing,
    regressions,
    unchecked,
  })
  log(`Round ${round}: ${results.length - failing.length} fixed, ${failing.length} not yet, ${regressions.length + strayTestFailures.length} regression(s), ${unchecked.length} unchecked.`)

  if (clean) break
  if (round > EXTRA_ROUNDS) {
    log(`Stopping after ${round} rounds; what's left goes to the owner.`)
    break
  }

  phase('Re-plan')
  const next = await agent(replanPrompt(round, failing, regressions, unchecked, tested, impl, failures), {
    agentType: 'web-ux-organizer',
    label: `re-plan after round ${round}`,
    phase: 'Re-plan',
    schema: REPLANNED,
    effort: 'high',
  })
  if (!next) break
  escalated.push(...next.escalated)
  packages = next.packages
  planFile = `${a.runDir}/plan-${tag}r${round + 1}.json`
  if (!packages.length) break
}

phase('Record')
const close = await agent(closePrompt(rounds, escalated, [...changedAll]), {
  agentType: 'web-ux-organizer',
  label: 'record ledger and report',
  phase: 'Record',
  schema: CLOSED,
  effort: 'high',
})
// For a plan run in batches, the skill sets recordMemory false on every batch but the last.
if (recordMemory) {
  await agent(
    [
      `Mode: memory. UX web loop run ${a.runId} just finished.`,
      `Read the verify-*.md files in ${a.runDir} (search them; read only what you need) and the run summary below, and update your memory with what is worth keeping: patterns the site now follows, changes to the site map and the claims map, recurring problem types.`,
      `Run summary: ${close ? close.verdict : 'not available'}`,
      'Issue statuses and owner decisions already live in .claude/ux-web/; do not copy them.',
      ...notesAppendix(),
    ].join('\n'),
    { agentType: 'web-ux-reviewer', label: 'record reviewer memory', phase: 'Record', effort: 'medium' },
  )
}

const filesChanged = [...changedAll].sort()
return {
  runId: a.runId,
  runDir: a.runDir,
  reportName,
  rounds: rounds.length,
  testsPassed: tested ? tested.passed : false,
  filesChanged,
  webFiles: filesChanged.filter(f => !isAppFile(f)),
  appFiles: filesChanged.filter(isAppFile),
  escalated,
  close,
  inlineNotes: inlineNotes.map(n => ({ path: n.path, text: n.text })),
}
