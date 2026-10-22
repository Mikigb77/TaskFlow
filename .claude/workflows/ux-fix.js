export const meta = {
  name: 'ux-fix',
  description: 'TaskFlow UX loop, part 2: packages that share no file are implemented and tested side by side, each in its own worktree, then merged; one round check runs the suite; frontend-ux-reviewer verifies only what changed; failures are re-planned (at most 2 extra rounds); then the ledger, report and reviewer memory are updated',
  whenToUse: 'Started by the /ux skill after ux-review, with the run folder whose plan.json should be carried out.',
  phases: [
    { title: 'Load', detail: 'read the package list, with each package\'s files, from plan.json' },
    { title: 'Implement', detail: 'waves of packages that share no file: each ux-implementer, then its own ux-tester, in their own worktree, side by side; then the merge, and an integrator for any conflict' },
    { title: 'Test', detail: 'the round check: ux-tester writes tests for packages done in the main checkout, then runs the analyzer, the full suite and the previews' },
    { title: 'Verify', detail: 'frontend-ux-reviewers on the fixed findings and changed files only, a few packages each, side by side' },
    { title: 'Re-plan', detail: 'ux-organizer turns what failed into a short new plan' },
    { title: 'Record', detail: 'ledger, run report and reviewer memory' },
  ],
}

// args, from the /ux skill:
//   runId, runDir, date
//   repoRoot:       absolute path of the main checkout, with forward slashes. Without it,
//                   every package runs in the main checkout, one at a time.
//   maxParallel:    packages side by side in one wave; default 12 (owner, 2026-10-21)
//   heavySlots:     heavy commands (Flutter, builds) at once on this machine; default 3
//   skip:           [packageId] — packages the owner struck (optional)
//   only:           [packageId] — run just these (optional)
//   maxExtraRounds: number      — re-plan rounds after the first; default 2
//   batch:          string      — names this batch's files when a plan runs in several batches (optional)
//   notes:          string      — owner context from the conversation (optional)
const a = args || {}
if (!a.runId || !a.runDir) throw new Error('ux-fix needs runId and runDir. Start it with /ux.')
const EXTRA_ROUNDS = Number.isInteger(a.maxExtraRounds) ? a.maxExtraRounds : 2
const skip = new Set(Array.isArray(a.skip) ? a.skip : [])
const only = Array.isArray(a.only) && a.only.length ? new Set(a.only) : null
const batch = typeof a.batch === 'string' && a.batch ? a.batch : ''
const tag = batch ? `${batch}-` : ''
const reportName = batch ? `report-${batch}.md` : 'report.md'
const recordMemory = a.recordMemory !== false
const ROOT = typeof a.repoRoot === 'string' && a.repoRoot ? a.repoRoot.replace(/\\/g, '/').replace(/\/$/, '') : ''
const WIDTH = ROOT ? (Number.isInteger(a.maxParallel) && a.maxParallel > 0 ? a.maxParallel : 12) : 1
const SLOTS = Number.isInteger(a.heavySlots) && a.heavySlots > 0 ? a.heavySlots : 3
const WAVES = ROOT ? `python -I -X utf8 "${ROOT}/.claude/ux-review/waves.py"` : ''
const GATE = ROOT ? `${WAVES} gate --slots ${SLOTS} --` : ''
// A verifier checks at most this many packages, so a wide wave still gets focused checks.
const VERIFY_CHUNK = 4

// Reading discipline for the checking steps. Whole files are what made the trial expensive:
// every big read is written to cache once, then re-read on every later turn.
const PKG = `python -I -X utf8 .claude/ux-review/pkg.py ${a.runDir}`
const LEAN = [
  `Read packages with: ${PKG} <ids> --conventions. Never open plan.json or plan-*.json directly; they are large.`,
  `Read a finding with: grep -n -A 30 "<ID>" ${a.runDir}/review-*.md. Never read a whole review report.`,
  'Read source files in the parts you need (search first, then read with offset and limit), and only the previews of screens that changed.',
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
    files: { type: 'array', items: { type: 'string' }, description: 'The repo-relative files the package expects to change, as its "files" lists them' },
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
        },
        required: ['id', 'applied', 'conflicts'],
      },
    },
    arbChanged: { type: 'boolean' },
    genL10n: { type: 'string' },
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

// Files every package may touch: the ARB catalogs merge key by key, generated l10n is rebuilt
// after the merge, and test files merge line by line. They never keep packages apart.
const MERGEABLE = /^App\/(lib\/l10n\/(app_\w+\.arb|generated\/)|test\/)/
function footprint(p) {
  const files = (Array.isArray(p.files) ? p.files : [])
    .map(f => String(f).replace(/\\/g, '/').replace(/^\.\//, '').split(/[\s:#(]/)[0])
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

function packageLine(r) {
  const missed = r.notAddressed.length
    ? `; not addressed: ${r.notAddressed.map(n => `${n.id} (${n.reason})`).join('; ')}`
    : ''
  return `- ${r.id} in ${r.planFile}: ${r.findings.join(', ')}. Implementer: ${r.status}${missed}`
}

function implementPrompt(p, round, planFile, mode, extra) {
  const lines = [
    `UX loop run ${a.runId}, round ${round}. Implement work package ${p.id}: ${p.title}.`,
    `Area ${p.area}, size ${p.size}, findings ${p.findings.join(', ')}.`,
  ]
  if (mode === 'worktree') {
    lines.push(
      `You work in your own git worktree, a copy of the repo made for you. Other implementers work at the same time in theirs, on packages that share no file with yours, so never touch the main checkout at ${ROOT}.`,
      `Before anything else, from your worktree's root (your starting directory), run: ${WAVES} seed --run ${a.runDir}`,
      'It brings this run\'s changes so far, the plan and the decisions into your worktree, and runs flutter pub get. Then work only inside your worktree, with paths relative to it.',
      `Run every heavy command through the gate, which lets only ${SLOTS} run at once on this machine: ${GATE} <command>. That covers flutter analyze, flutter test, the previews, flutter gen-l10n and flutter build. Everything else (reading, searching, editing) runs freely.`,
      'Return your worktree\'s absolute path (git rev-parse --show-toplevel) in "worktree".',
    )
  }
  if (Array.isArray(p.dependsOn) && p.dependsOn.length) lines.push(`It builds on ${p.dependsOn.join(', ')}, done earlier in this run.`)
  lines.push(
    `Your instructions are package ${p.id}: its brief, files, acceptance checks and device checks, plus the plan's shared conventions. Print exactly those with: ${PKG} ${p.id} --conventions`,
    LEAN,
    'Earlier packages in this run may already have changed the code; build on their work.',
    'Test files listed in the package are for ux-tester, who writes the acceptance tests after you. Only update existing tests your change breaks.',
    'Run only the tests that cover your change, in one flutter test call. Never run the whole suite: the round check runs it after every package.',
    'If you change Kotlin, Gradle, the manifest or Android resources, compile with: flutter build apk --debug --no-pub --target-platform android-x64 (from App/; build only, never install). The analyzer and tests do not compile native code.',
  )
  if (extra) lines.push(extra)
  if (a.notes) lines.push(`From the owner, this session: ${a.notes}`)
  lines.push('Return the structured result.')
  return lines.join('\n')
}

function integratePrompt(p, round, planFile, wt, conflicts) {
  return [
    `UX loop run ${a.runId}, round ${round}. Mode: integrate. Work package ${p.id}: ${p.title}.`,
    `Area ${p.area}, findings ${p.findings.join(', ')}.`,
    `${p.id} was implemented and tested side by side with other packages, in its own worktree at ${wt}. Merging it into the main checkout conflicted with packages merged just before it:`,
    ...conflicts.map(c => `- ${c.path}: ${c.why}`),
    `Bring all of ${p.id}'s changes into the main checkout at ${ROOT}, by hand, on top of what is there now. Its whole patch, code and tests: ${WAVES} diff --worktree ${wt}`,
    'Keep both packages\' intent where they meet. If they truly contradict, keep what is already in the main checkout, and say so in your notes.',
    'Then, from App/ in the main checkout: flutter gen-l10n if an ARB file changed, flutter analyze --no-pub, and the tests that cover the files you touched, in one flutter test call. Never run the whole suite.',
    `When it is in, remove the worktree: ${WAVES} drop --worktree ${wt}`,
    `Your instructions are package ${p.id}, as before: ${PKG} ${p.id} --conventions`,
    LEAN,
    a.notes ? `From the owner, this session: ${a.notes}` : '',
    'Return the structured result: filesChanged is every file you changed in the main checkout; worktree is empty.',
  ].filter(Boolean).join('\n')
}

function packageTestPrompt(p, round, r, wt) {
  return [
    `UX loop run ${a.runId}, round ${round}. Mode: package. Lock work package ${p.id} with tests: ${p.title}.`,
    `Area ${p.area}, findings ${p.findings.join(', ')}. Its implementer reported: ${r.status}${r.notAddressed.length ? `; not addressed: ${r.notAddressed.map(n => `${n.id} (${n.reason})`).join('; ')}` : ''}.`,
    `It was implemented in its own worktree at ${wt}, and other packages are being implemented and tested side by side in theirs. Work only there: read and write files under ${wt}, and run commands from ${wt}/App. Never touch the main checkout at ${ROOT}.`,
    `Files the implementer changed: ${r.filesChanged.length ? r.filesChanged.join(', ') : 'none reported'}.`,
    `Write the tests for ${p.id}'s acceptance checks only, as your instructions say, and run them with the existing tests of the files it changed, in one call through the gate: ${GATE} flutter test --no-pub <files>.`,
    'Skip the round\'s check: no whole suite, no whole-app analyzer, no previews, no native build. The round check runs those once every package is merged.',
    'Parts of a package marked "waits on D#" were left out on purpose; do not test them.',
    LEAN,
    'Return the structured result for this package only. filesChanged lists your test files, relative to the repo root.',
  ].join('\n')
}

function mergePrompt(items) {
  const pairs = items.map(x => `--worktree ${x.p.id}=${x.r.worktree}`).join(' ')
  return [
    'Run exactly this one command, from anywhere, and wait for it:',
    `${WAVES} merge ${pairs}`,
    'It merges each package\'s worktree into the main checkout, in this order, and prints one JSON object. Return that JSON as the structured result, unchanged. Do nothing else: no other command, no edits.',
  ].join('\n')
}

// The slow checks side by side: the whole suite in one gate slot, the previews in another.
function sideBySide(previews) {
  const gate = GATE ? `${GATE} ` : ''
  return [
    'Run the slow checks side by side, in one shell command from App/, and wait for both:',
    `mkdir -p build/round-check && ( ${gate}flutter test --no-pub --reporter failures-only > build/round-check/suite.log 2>&1; echo "suite exit $?" ) & ( ${previews} > build/round-check/previews.log 2>&1; echo "previews exit $?" ) & wait`,
    'It can take longer than one tool call may run (the suite alone took 8 minutes on 2026-10-22): start it with the Bash tool\'s run_in_background, and wait for it to finish.',
    'Then read the tails of build/round-check/suite.log and previews.log. Run the previews one after another inside their group, each through the gate.',
  ].join('\n')
}

function roundTestPrompt(round, impl, files, locked, unlocked, targeted) {
  const lines = [
    `UX loop run ${a.runId}, round ${round}. Lock this round's fixes with tests, then run the round's check, in the main checkout.`,
    'Packages implemented this round:',
    ...impl.map(packageLine),
    `Files changed this round: ${files.length ? files.join(', ') : 'none reported'}.`,
  ]
  if (locked.length) {
    lines.push(
      'Already locked by their own testers, in their worktrees, and merged in: don\'t write tests for these again; your check runs their tests with the rest.',
      ...locked.map(t => `- ${t.id}: ${t.findings.map(f => `${f.id} ${f.coverage}/${f.result}${f.tests && f.tests.length ? ` (${f.tests.join('; ')})` : ''}`).join(', ') || 'no findings reported'}${t.failures.length ? `. Failing there: ${t.failures.map(f => `${f.test} (${f.owner}${f.finding ? `, ${f.finding}` : ''})`).join('; ')}` : ''}`),
    )
  }
  lines.push(
    unlocked.length
      ? `Write tests for these packages only: ${unlocked.map(r => r.id).join(', ')}.`
      : 'No package needs new tests from you: run the round\'s check.',
    LEAN,
    targeted
      ? 'This is a redo round, so the check covers what changed: flutter gen-l10n if an ARB file changed; flutter analyze --no-pub; one flutter test call with the new tests, the tests of every file this round changed and the tests that cover its findings; and the previews of the screens this round changed. Don\'t run the whole suite or the three older preview commands: the final check runs them once, when the redo rounds are done.'
      : sideBySide('the UX preview suite for the screens this round changed, then the three older preview commands'),
    'Report every failing test against its finding, including tests the package testers wrote.',
    'Parts of a package marked "waits on D#" were left out on purpose; do not test them.',
    files.some(f => /[\\/]android[\\/]/.test(f))
      ? 'Android files changed this round: include the compile check, flutter build apk --debug --no-pub --target-platform android-x64 (build only, never install). A broken native build fails the round.'
      : 'No Android files changed this round, so no native build is needed.',
    'Return the structured result. In "findings", cover every package of the round: copy what the package testers proved, unless your run shows otherwise.',
  )
  return lines.join('\n')
}

function finalPrompt(round, files, findings) {
  return [
    `UX loop run ${a.runId}. Mode: final check, after round ${round}. The redo rounds are done, and their checks passed on what they changed. Now run the whole check once, in the main checkout. Write no new tests.`,
    `Files changed in this run: ${files.length ? files.join(', ') : 'none reported'}.`,
    'From App/: flutter gen-l10n if an ARB file changed, then flutter analyze --no-pub.',
    sideBySide('the UX preview suite for every screen this run changed, then the three older preview commands'),
    files.some(f => /[\\/]android[\\/]/.test(f))
      ? 'Android files changed in this run: include the compile check, flutter build apk --debug --no-pub --target-platform android-x64 (build only, never install).'
      : 'No Android files changed in this run, so no native build is needed.',
    `Report every failing test against its finding (the run's findings: ${findings.join(', ')}), or with no finding if it proves none; fix only your own test infrastructure, as your instructions say.`,
    'Return the structured result.',
  ].join('\n')
}

function verifyPrompt(round, area, part, items, tested) {
  const files = [...new Set(items.flatMap(r => r.filesChanged))]
  const ids = new Set(items.flatMap(r => r.findings))
  const testLines = tested.findings
    .filter(f => ids.has(f.id))
    .map(f => `- ${f.id}: ${f.coverage}, ${f.result}${f.tests && f.tests.length ? ` (${f.tests.join('; ')})` : ''}${f.note ? `. ${f.note}` : ''}`)
  const key = `${area}${part}`
  return [
    `Mode: verify. UX loop run ${a.runId}, round ${round}, area ${area}. Today is ${a.date}.`,
    'Check only these work packages and their findings:',
    ...items.map(packageLine),
    LEAN,
    'Parts of a package marked "waits on D#" were left out on purpose (an owner decision is pending); do not count them as not fixed.',
    `Files changed in this run: ${files.length ? files.join(', ') : 'none reported'}. See only what changed with: git diff HEAD -- <file>.`,
    'What the testers proved for these findings (a failing test means the acceptance check is not met):',
    ...(testLines.length ? testLines : ['- nothing reported']),
    'Judge every listed finding as fixed, partly or not_fixed, with evidence. Then look for regressions, only in these files and the flows they touch.',
    `Number regressions R${round}${key}-1, R${round}${key}-2 and so on; the organizer gives them final IDs.`,
    'The tester re-rendered the previews just now. Read them; do not run Flutter. Another step records memory.',
    `Write your notes to ${a.runDir}/verify-${tag}r${round}-${key}.md, then return the structured result.`,
  ].join('\n')
}

function replanPrompt(round, failing, regressions, unchecked, tested, impl, failures) {
  const twice = failing.filter(f => failures[f.id] >= 2).map(f => f.id)
  const failedChecks = tested.checks.filter(c => !c.passed).map(c => c.command + (c.note ? ` (${c.note})` : ''))
  const lines = [
    `Mode: replan. UX loop run ${a.runId}, after round ${round}. Today is ${a.date}. Run folder: ${a.runDir}.`,
    'Not fixed yet:',
    ...(failing.length ? failing.map(f => `- ${f.id}: ${f.result}, failed ${failures[f.id]} time(s). ${f.evidence}`) : ['- none']),
    'Regressions:',
    ...(regressions.length ? regressions.map(r => `- ${r.id}, severity ${r.severity}: ${r.title}. ${r.where}. Fix: ${r.fix}`) : ['- none']),
    'Failing tests (from ux-tester):',
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
    `Read only this round's verify notes (${a.runDir}/verify-${tag}r${round}-*.md) and the packages involved. In ISSUES.md, edit only the lines you change.`,
    'Give every new package its "files" (repo-relative paths), as plan.json does: packages that share no file are implemented side by side.',
  )
  lines.push(`Write the new packages to ${a.runDir}/plan-${tag}r${round + 1}.json (same structure as plan.json), append them to plan.md under "Round ${round + 1}${batch ? ` (${batch})` : ''}", add regressions to ISSUES.md with final IDs, then return the structured result.`)
  return lines.join('\n')
}

function closePrompt(rounds, escalated, files) {
  const ids = list => (list.length ? list.join(', ') : 'none')
  return [
    `Mode: close. UX loop run ${a.runId}. Today is ${a.date}. Run folder: ${a.runDir}.`,
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
    `Files changed: ${ids(files)}.`,
    'A finding counts as verified only if the last round that checked it said "fixed" and no test for it failed. Note which verified findings are locked by a test. Phone checks stay listed for the owner.',
    `Work from the round summaries above and this batch's verify notes (${a.runDir}/verify-${tag}*.md); don't re-read the plan or the review reports. In ISSUES.md, find each finding's line with grep and edit only those lines.`,
    `Update .claude/ux-review/ISSUES.md, then return the structured result with the full report in "report". Don't write a report file yourself; the main session saves it as ${a.runDir}/${reportName}${batch ? ` (this batch: ${batch})` : ''}.`,
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
  return { runId: a.runId, runDir: a.runDir, rounds: 0, testsPassed: true, filesChanged: [], escalated: [], close: null }
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
    const changed = [...new Set([...(files || r.filesChanged), ...(t ? t.filesChanged : [])])]
    changed.forEach(f => changedAll.add(f))
    impl.push({ ...r, filesChanged: changed, id: p.id, area: p.area, findings: p.findings, planFile })
    if (t) locked.push({ ...t, id: p.id })
    log(`${p.id} ${r.status}: ${r.addressed.length} of ${p.findings.length} finding(s) addressed${t ? `; locked by ${t.findings.filter(f => f.coverage === 'tested').length} test(s)` : ''}.`)
  }
  const inMain = async (p, extra) => {
    const r = await agent(implementPrompt(p, round, planFile, 'main', extra), {
      agentType: 'ux-implementer',
      label: `implement ${p.id}${round > 1 ? ` · round ${round}` : ''}`,
      phase: 'Implement',
      schema: IMPLEMENTED,
    })
    record(p, r || noResult(p), null, null)
  }

  const waves = planWaves(packages)
  const shape = waves.map(w => w.length).join(', ')
  log(`Round ${round}: ${packages.length} package(s) in ${waves.length} wave(s) (${shape}), up to ${WIDTH} side by side, ${SLOTS} heavy commands at once.`)

  for (const [n, wave] of waves.entries()) {
    if (wave.length === 1) {
      await inMain(wave[0])
      continue
    }
    // Side by side: each package's implementer, then its tester, in the package's own worktree.
    const done = await parallel(wave.map(p => async () => {
      const r = await agent(implementPrompt(p, round, planFile, 'worktree'), {
        agentType: 'ux-implementer',
        isolation: 'worktree',
        label: `implement ${p.id}${round > 1 ? ` · round ${round}` : ''}`,
        phase: 'Implement',
        schema: IMPLEMENTED,
      })
      if (!r || !r.worktree || r.status === 'failed') return { p, r, t: null }
      const t = await agent(packageTestPrompt(p, round, r, r.worktree), {
        agentType: 'ux-tester',
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
    if (merged && merged.genL10n && merged.genL10n.startsWith('failed')) log(`gen-l10n after wave ${n + 1}: ${merged.genL10n}`)
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
        const r = await agent(integratePrompt(x.p, round, planFile, x.r.worktree, x.m.conflicts), {
          agentType: 'ux-implementer',
          label: `integrate ${x.p.id}${round > 1 ? ` · round ${round}` : ''}`,
          phase: 'Implement',
          schema: IMPLEMENTED,
        })
        record(x.p, r || noResult(x.p), null, r ? x.t : null)
      } else {
        const why = !x.r ? 'its implementer returned nothing' : !x.r.worktree ? 'it reported no worktree' : x.r.status === 'failed' ? `it failed: ${x.r.notes || 'no notes'}` : 'the merge returned nothing'
        log(`${x.p.id} could not run side by side (${why}); redoing it in the main checkout.`)
        await inMain(x.p, `It was first tried in a worktree, side by side with other packages, and ${why}. Work in the main checkout this time.`)
      }
    }
  }

  phase('Test')
  const roundFiles = [...new Set(impl.flatMap(r => r.filesChanged))]
  const lockedIds = new Set(locked.map(t => t.id))
  const unlocked = impl.filter(r => !lockedIds.has(r.id))
  // Round 1 runs the whole check; redo rounds check what they changed, and the final check
  // runs the whole suite once at the end.
  tested = (await agent(roundTestPrompt(round, impl, roundFiles, locked, unlocked, round > 1), {
    agentType: 'ux-tester',
    label: `test · round ${round}`,
    phase: 'Test',
    schema: TESTED,
  })) || { passed: false, checks: [], findings: [], failures: [], filesChanged: [], notes: 'The tester did not return a result.' }
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
      agentType: 'frontend-ux-reviewer',
      label: `verify ${g.area}${g.part} · round ${round}`,
      phase: 'Verify',
      schema: VERIFIED,
      effort: 'high',
    })
  ))).filter(Boolean)
  const results = checked.flatMap(v => v.results)
  const regressions = checked.flatMap(v => v.regressions)
  const seen = new Set(results.map(x => x.id))
  const unchecked = impl.flatMap(r => r.findings).filter(id => !seen.has(id))
  // A failing acceptance test overrides a "fixed" verdict, here or from an earlier round.
  const judge = () => {
    const testFailed = {}
    tested.failures.filter(f => f.owner === 'app' && f.finding).forEach(f => { testFailed[f.finding] = f })
    const list = results
      .filter(x => x.result !== 'fixed' || testFailed[x.id])
      .map(x => (x.result === 'fixed'
        ? { ...x, result: 'partly', evidence: `${x.evidence} But a test fails: ${testFailed[x.id].test}: ${testFailed[x.id].evidence}` }
        : x))
    const here = new Set(results.map(x => x.id))
    Object.values(testFailed).filter(f => !here.has(f.finding)).forEach(f => {
      list.push({ id: f.finding, result: 'partly', evidence: `Fixed in an earlier round, but a test fails now: ${f.test}: ${f.evidence}` })
    })
    return { list, stray: tested.failures.filter(f => f.owner === 'app' && !f.finding) }
  }
  let { list: failing, stray: strayTestFailures } = judge()
  let clean = !failing.length && !regressions.length && !strayTestFailures.length && !unchecked.length && tested.passed
  if (clean && round > 1) {
    phase('Test')
    const findings = [...new Set([...rounds.flatMap(r => r.results.map(x => x.id)), ...results.map(x => x.id)])]
    const fin = (await agent(finalPrompt(round, [...changedAll], findings), {
      agentType: 'ux-tester',
      label: `final check · round ${round}`,
      phase: 'Test',
      schema: TESTED,
    })) || { passed: false, checks: [], findings: [], failures: [], filesChanged: [], notes: 'The final check did not return a result.' }
    fin.filesChanged.forEach(f => changedAll.add(f))
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
    verifyReports: checked.map(v => v.reportPath),
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
    agentType: 'ux-organizer',
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
  agentType: 'ux-organizer',
  label: 'record ledger and report',
  phase: 'Record',
  schema: CLOSED,
  effort: 'high',
})
// For a plan run in batches, the skill sets recordMemory false on every batch but the last.
if (recordMemory) {
  await agent(
    [
      `Mode: memory. UX loop run ${a.runId} just finished.`,
      `Read the verify-*.md files in ${a.runDir} (search them; read only what you need) and the run summary below, and update your memory with what is worth keeping: patterns the app now follows, changes to the screen map, recurring problem types.`,
      `Run summary: ${close ? close.verdict : 'not available'}`,
      'Issue statuses and owner decisions already live in .claude/ux-review/; do not copy them.',
    ].join('\n'),
    { agentType: 'frontend-ux-reviewer', label: 'record reviewer memory', phase: 'Record', effort: 'medium' },
  )
}

return {
  runId: a.runId,
  runDir: a.runDir,
  reportName,
  rounds: rounds.length,
  testsPassed: tested ? tested.passed : false,
  filesChanged: [...changedAll].sort(),
  escalated,
  close,
}
