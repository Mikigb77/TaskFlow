export const meta = {
  name: 'ux-fix',
  description: 'TaskFlow UX loop, part 2: ux-implementer fixes the plan one package at a time, ux-tester locks each fix with tests and runs the suite, frontend-ux-reviewer verifies only what changed, failures are re-planned (at most 2 extra rounds), then the ledger, report and reviewer memory are updated',
  whenToUse: 'Started by the /ux skill after ux-review, with the run folder whose plan.json should be carried out.',
  phases: [
    { title: 'Load', detail: 'read the package list from plan.json' },
    { title: 'Implement', detail: 'one ux-implementer per package, one at a time' },
    { title: 'Test', detail: 'ux-tester writes tests from the acceptance checks, then runs the analyzer, the full suite and the previews' },
    { title: 'Verify', detail: 'one frontend-ux-reviewer per area touched, on the fixed findings and changed files only' },
    { title: 'Re-plan', detail: 'ux-organizer turns what failed into a short new plan' },
    { title: 'Record', detail: 'ledger, run report and reviewer memory' },
  ],
}

// args, from the /ux skill:
//   runId, runDir, date
//   skip:           [packageId] — packages the owner struck (optional)
//   only:           [packageId] — run just these (optional)
//   maxExtraRounds: number      — re-plan rounds after the first; default 2
//   notes:          string      — owner context from the conversation (optional)
const a = args || {}
if (!a.runId || !a.runDir) throw new Error('ux-fix needs runId and runDir. Start it with /ux.')
const EXTRA_ROUNDS = Number.isInteger(a.maxExtraRounds) ? a.maxExtraRounds : 2
const skip = new Set(Array.isArray(a.skip) ? a.skip : [])
const only = Array.isArray(a.only) && a.only.length ? new Set(a.only) : null

const HEADER = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    title: { type: 'string' },
    area: { type: 'string' },
    size: { type: 'string' },
    findings: { type: 'array', items: { type: 'string' } },
    dependsOn: { type: 'array', items: { type: 'string' } },
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
  },
  required: ['status', 'filesChanged', 'addressed', 'notAddressed', 'checks'],
}
const TESTED = {
  type: 'object',
  properties: {
    passed: { type: 'boolean', description: 'True when every new test passes and nothing fails outside KNOWN_FAILURES.md' },
    checks: { type: 'array', items: CHECK },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          coverage: { type: 'string', enum: ['tested', 'preview', 'device', 'none'] },
          tests: { type: 'array', items: { type: 'string' }, description: 'file :: test name' },
          result: { type: 'string', enum: ['pass', 'fail', 'n/a'] },
          note: { type: 'string' },
        },
        required: ['id', 'coverage', 'result'],
      },
    },
    failures: {
      type: 'array',
      description: 'Failures still open after you fixed your own tests: the app falls short, or infrastructure you could not fix',
      items: {
        type: 'object',
        properties: {
          test: { type: 'string' },
          owner: { type: 'string', enum: ['app', 'infrastructure'] },
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
    reportPath: { type: 'string' },
    verdict: { type: 'string' },
    verified: { type: 'array', items: { type: 'string' } },
    open: { type: 'array', items: MISSED },
    deviceChecks: { type: 'array', items: { type: 'string' } },
  },
  required: ['reportPath', 'verdict', 'verified', 'open', 'deviceChecks'],
}

function packageLine(r) {
  const missed = r.notAddressed.length
    ? `; not addressed: ${r.notAddressed.map(n => `${n.id} (${n.reason})`).join('; ')}`
    : ''
  return `- ${r.id} in ${r.planFile}: ${r.findings.join(', ')}. Implementer: ${r.status}${missed}`
}

function implementPrompt(p, round, planFile) {
  const lines = [
    `UX loop run ${a.runId}, round ${round}. Implement work package ${p.id}: ${p.title}.`,
    `Area ${p.area}, size ${p.size}, findings ${p.findings.join(', ')}.`,
  ]
  if (Array.isArray(p.dependsOn) && p.dependsOn.length) lines.push(`It builds on ${p.dependsOn.join(', ')}, done earlier in this run.`)
  lines.push(
    `Your instructions are package ${p.id} in ${planFile} (brief, files, acceptance checks, device checks), plus the top-level "conventions" in ${a.runDir}/plan.json, which apply to every package.`,
    `The findings themselves are in the review reports in ${a.runDir}/ (search for their IDs).`,
    'Earlier packages in this run may already have changed the code; build on their work.',
  )
  if (a.notes) lines.push(`From the owner, this session: ${a.notes}`)
  lines.push('Return the structured result.')
  return lines.join('\n')
}

function testPrompt(round, impl, files) {
  return [
    `UX loop run ${a.runId}, round ${round}. Lock this round's fixes with tests, then run the round's check.`,
    'Packages implemented this round:',
    ...impl.map(packageLine),
    `Files changed this round: ${files.length ? files.join(', ') : 'none reported'}.`,
    `Acceptance checks are in each package's plan file; the findings are in the review reports in ${a.runDir}/; the top-level "conventions" in ${a.runDir}/plan.json apply too.`,
    'Parts of a package marked "waits on D#" were left out on purpose; do not test them.',
    'Return the structured result.',
  ].join('\n')
}

function verifyPrompt(round, area, items, tested) {
  const files = [...new Set(items.flatMap(r => r.filesChanged))]
  const ids = new Set(items.flatMap(r => r.findings))
  const testLines = tested.findings
    .filter(f => ids.has(f.id))
    .map(f => `- ${f.id}: ${f.coverage}, ${f.result}${f.tests && f.tests.length ? ` (${f.tests.join('; ')})` : ''}${f.note ? `. ${f.note}` : ''}`)
  return [
    `Mode: verify. UX loop run ${a.runId}, round ${round}, area ${area}. Today is ${a.date}.`,
    'Check only these work packages and their findings:',
    ...items.map(packageLine),
    `Each package's acceptance checks are in its plan file; the findings are in the review reports in ${a.runDir}/.`,
    'Parts of a package marked "waits on D#" were left out on purpose (an owner decision is pending); do not count them as not fixed.',
    `Files changed in this run: ${files.length ? files.join(', ') : 'none reported'}. See them with: git diff HEAD -- <file>.`,
    'What ux-tester proved for these findings (a failing test means the acceptance check is not met):',
    ...(testLines.length ? testLines : ['- nothing reported']),
    'Judge every listed finding as fixed, partly or not_fixed, with evidence. Then look for regressions, only in these files and the flows they touch.',
    `Number regressions R${round}${area}-1, R${round}${area}-2 and so on; the organizer gives them final IDs.`,
    'The tester re-rendered the previews just now. Read them; do not run Flutter. Another step records memory.',
    `Write your notes to ${a.runDir}/verify-r${round}-${area}.md, then return the structured result.`,
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
  lines.push(`Write the new packages to ${a.runDir}/plan-r${round + 1}.json (same structure as plan.json), append them to plan.md under "Round ${round + 1}", add regressions to ISSUES.md with final IDs, then return the structured result.`)
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
    'Update .claude/ux-review/ISSUES.md, write report.md in the run folder, then return the structured result.',
  ].join('\n')
}

phase('Load')
const loaded = await agent(
  `Read ${a.runDir}/plan.json and return the header of every package in its "packages" array, in order: id, title, area, size, findings, dependsOn. Copy the values exactly.`,
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

for (let round = 1; ; round++) {
  phase('Implement')
  const impl = []
  // One at a time on purpose: fixes that change copy all edit the same three ARB files.
  for (const p of packages) {
    const result = await agent(implementPrompt(p, round, planFile), {
      agentType: 'ux-implementer',
      label: `implement ${p.id}${round > 1 ? ` · round ${round}` : ''}`,
      phase: 'Implement',
      schema: IMPLEMENTED,
    })
    const r = result || {
      status: 'failed',
      filesChanged: [],
      addressed: [],
      notAddressed: p.findings.map(id => ({ id, reason: 'The implementer did not return a result.' })),
      checks: [],
    }
    r.filesChanged.forEach(f => changedAll.add(f))
    impl.push({ ...r, id: p.id, area: p.area, findings: p.findings, planFile })
    log(`${p.id} ${r.status}: ${r.addressed.length} of ${p.findings.length} finding(s) addressed.`)
  }

  phase('Test')
  const roundFiles = [...new Set(impl.flatMap(r => r.filesChanged))]
  tested = (await agent(testPrompt(round, impl, roundFiles), {
    agentType: 'ux-tester',
    label: `test · round ${round}`,
    phase: 'Test',
    schema: TESTED,
  })) || { passed: false, checks: [], findings: [], failures: [], filesChanged: [], notes: 'The tester did not return a result.' }
  tested.filesChanged.forEach(f => changedAll.add(f))
  const proven = tested.findings.filter(f => f.coverage === 'tested' && f.result === 'pass').map(f => f.id)
  const device = tested.findings.filter(f => f.coverage === 'device').map(f => f.id)
  log(`Tests, round ${round}: ${tested.passed ? 'passed' : 'failed'}; ${proven.length} finding(s) proven by a test, ${tested.failures.length} failure(s) open.`)

  phase('Verify')
  const areas = [...new Set(impl.map(r => r.area))]
  const checked = (await parallel(areas.map(area => () =>
    agent(verifyPrompt(round, area, impl.filter(r => r.area === area), tested), {
      agentType: 'frontend-ux-reviewer',
      label: `verify ${area} · round ${round}`,
      phase: 'Verify',
      schema: VERIFIED,
    })
  ))).filter(Boolean)
  const results = checked.flatMap(v => v.results)
  const regressions = checked.flatMap(v => v.regressions)
  const seen = new Set(results.map(x => x.id))
  const unchecked = impl.flatMap(r => r.findings).filter(id => !seen.has(id))
  // A failing acceptance test overrides a "fixed" verdict.
  const testFailed = {}
  tested.failures.filter(f => f.owner === 'app' && f.finding).forEach(f => { testFailed[f.finding] = f })
  const failing = results
    .filter(x => x.result !== 'fixed' || testFailed[x.id])
    .map(x => (x.result === 'fixed'
      ? { ...x, result: 'partly', evidence: `${x.evidence} But a test fails: ${testFailed[x.id].test}: ${testFailed[x.id].evidence}` }
      : x))
  failing.forEach(f => { failures[f.id] = (failures[f.id] || 0) + 1 })
  const strayTestFailures = tested.failures.filter(f => f.owner === 'app' && !f.finding)
  rounds.push({
    round,
    planFile,
    packages: impl.map(r => ({ id: r.id, status: r.status })),
    tests: { passed: tested.passed, proven, device },
    verifyReports: checked.map(v => v.reportPath),
    results,
    failing,
    regressions,
    unchecked,
  })
  log(`Round ${round}: ${results.length - failing.length} fixed, ${failing.length} not yet, ${regressions.length + strayTestFailures.length} regression(s), ${unchecked.length} unchecked.`)

  if (!failing.length && !regressions.length && !strayTestFailures.length && !unchecked.length && tested.passed) break
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
  })
  if (!next) break
  escalated.push(...next.escalated)
  packages = next.packages
  planFile = `${a.runDir}/plan-r${round + 1}.json`
  if (!packages.length) break
}

phase('Record')
const close = await agent(closePrompt(rounds, escalated, [...changedAll]), {
  agentType: 'ux-organizer',
  label: 'record ledger and report',
  phase: 'Record',
  schema: CLOSED,
})
await agent(
  [
    `Mode: memory. UX loop run ${a.runId} just finished.`,
    `Read ${a.runDir}/report.md and the verify-*.md files in ${a.runDir}, and update your memory with what is worth keeping: patterns the app now follows, changes to the screen map, recurring problem types.`,
    'Issue statuses and owner decisions already live in .claude/ux-review/; do not copy them.',
  ].join('\n'),
  { agentType: 'frontend-ux-reviewer', label: 'record reviewer memory', phase: 'Record', effort: 'medium' },
)

return {
  runId: a.runId,
  runDir: a.runDir,
  rounds: rounds.length,
  testsPassed: tested ? tested.passed : false,
  filesChanged: [...changedAll].sort(),
  escalated,
  close,
}
