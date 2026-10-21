export const meta = {
  name: 'ux-web-review',
  description: 'TaskFlow UX web loop, part 1: web-ux-reviewer reviews each area of the marketing website in scope, then web-ux-organizer turns the findings into a fix plan',
  whenToUse: 'Started by the /ux-web skill, which works out the scope, renders the pages and passes the scope as args. Not useful on its own.',
  phases: [
    { title: 'Review', detail: 'one web-ux-reviewer per area, in parallel; each writes its report to the run folder' },
    { title: 'Organize', detail: 'web-ux-organizer merges duplicates, separates owner decisions, writes plan.json, plan.md and the ledger' },
  ],
}

// args, from the /ux-web skill:
//   runId, runDir, date, mode ('changes' | 'pages' | 'site')
//   webDir:      the website repo, Windows path with forward slashes (optional; default below)
//   slices:      [{ key: 'H' | 'F' | 'L' | 'G', name, scope, idStart }] — one reviewer each
//   reportPaths: [path] — optional; reviews already written, so the Review phase is skipped
//   appChanged:  [path] — app-repo files the site's claims rest on, changed since the last web review
//   notes:       string — owner context from the conversation
const a = args || {}
const slices = Array.isArray(a.slices) ? a.slices : []
const given = Array.isArray(a.reportPaths) ? a.reportPaths : []
if (!a.runId || !a.runDir || !a.mode || !(slices.length || given.length)) {
  throw new Error('ux-web-review needs runId, runDir, mode and slices (or reportPaths). Start it with /ux-web.')
}
const WEB = (a.webDir || 'C:/Users/mikig/Desktop/Custom/MikiHacks/TaskFlow/TaskFlowWeb').replace(/\\/g, '/').replace(/\/$/, '')
const SCOPE = {
  changes: 'what changed on the website, and in the app features it describes, since the last web review',
  pages: 'the pages the owner named',
  site: 'the whole website',
}

const COUNTS = {
  type: 'object',
  properties: {
    s4: { type: 'integer' },
    s3: { type: 'integer' },
    s2: { type: 'integer' },
    s1: { type: 'integer' },
  },
  required: ['s4', 's3', 's2', 's1'],
}

const REVIEWED = {
  type: 'object',
  properties: {
    reportPath: { type: 'string', description: 'The report you wrote, relative to the app repo root' },
    verdict: { type: 'string', description: 'Your verdict line' },
    counts: COUNTS,
    reportText: { type: 'string', description: 'Only if writing the report file was refused: the full report' },
  },
  required: ['reportPath', 'verdict', 'counts'],
}

const PLANNED = {
  type: 'object',
  properties: {
    planPath: { type: 'string', description: 'plan.md, relative to the app repo root' },
    summary: { type: 'string', description: 'Two or three sentences for the owner' },
    counts: {
      type: 'object',
      properties: {
        fix: { type: 'integer' },
        decide: { type: 'integer' },
        skip: { type: 'integer' },
      },
      required: ['fix', 'decide', 'skip'],
    },
    packages: {
      type: 'array',
      description: 'Package headers only; the briefs live in plan.json',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          area: { type: 'string' },
          size: { type: 'string' },
          findings: { type: 'array', items: { type: 'string' } },
        },
        required: ['id', 'title', 'area', 'size', 'findings'],
      },
    },
    decisions: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          question: { type: 'string' },
          findings: { type: 'array', items: { type: 'string' } },
          recommendation: { type: 'string' },
        },
        required: ['question', 'findings', 'recommendation'],
      },
    },
  },
  required: ['planPath', 'summary', 'counts', 'packages', 'decisions'],
}

function reviewPrompt(s) {
  const others = slices.filter(o => o.key !== s.key).map(o => o.key + ' — ' + o.name)
  const lines = [
    `UX web loop run ${a.runId}: review ${SCOPE[a.mode]}. Your area: ${s.key} — ${s.name}. Today is ${a.date}.`,
    `The website repo is ${WEB}; paths in your report are relative to its root.`,
    'Scope:',
    s.scope,
  ]
  if (a.mode === 'changes') {
    lines.push('See each website file\'s change since the last web review with: bash .claude/ux-web/ux-web.sh since -- <file> (run from the app repo).')
  }
  if (Array.isArray(a.appChanged) && a.appChanged.length) {
    lines.push(
      `App-repo files the site's claims rest on, changed since the last web review: ${a.appChanged.join(', ')}.`,
      'See each change with: bash .claude/ux-web/ux-web.sh since --app -- <file>. Check every claim in your area that they touch: the site must say what the app does today, in the app\'s words.',
    )
  }
  if (a.notes) lines.push(`From the owner, this session: ${a.notes}`)
  lines.push(
    others.length
      ? `Other areas are reviewed in parallel (${others.join('; ')}). Stay in yours; put anything else in one line under "Cross-slice notes".`
      : 'You are the only reviewer in this run.',
    `The pages were rendered and measured from the current working tree just before this run. Start with ${WEB}/artifacts/ux-web/INDEX.md and AUDIT.md, then read the renders you need, including the demo states; crop tall ones with crop.mjs. Do not run npm, Playwright or the build, and never call the live voice demo: its state renders stub the API.`,
    `Number new findings from WEB-${s.idStart} upward. Anything already in .claude/ux-web/ISSUES.md keeps its ID and is not reported as new.`,
    'Another step records memory: skip the memory update and end your report with a "Memory notes" section.',
    `Write your full report to ${a.runDir}/review-${s.key}.md, then return the structured result. If writing the file is refused, put the full report in "reportText" instead.`,
  )
  return lines.join('\n')
}

let reports = given.map(p => ({ reportPath: p, verdict: 'reviewed earlier', counts: null }))

if (!given.length) {
  phase('Review')
  const results = await parallel(slices.map(s => () =>
    agent(reviewPrompt(s), {
      agentType: 'web-ux-reviewer',
      label: `review ${s.key} · ${s.name}`,
      phase: 'Review',
      schema: REVIEWED,
    }).then(r => r && { ...r, key: s.key })
  ))
  reports = results.filter(Boolean)
  const missing = slices.filter((s, i) => !results[i]).map(s => s.key)
  if (missing.length) log(`No report from area ${missing.join(', ')}; the plan covers the others only.`)
  if (!reports.length) throw new Error('No reviewer returned a report.')
  const total = reports.reduce((n, r) => n + r.counts.s4 + r.counts.s3 + r.counts.s2 + r.counts.s1, 0)
  log(`Reviews done: ${total} finding(s) in ${reports.length} report(s).`)
  if (total === 0) {
    return { runId: a.runId, runDir: a.runDir, mode: a.mode, reports, inlineReports: [], plan: null }
  }
}

phase('Organize')
const organize = [
  `Mode: plan. UX web loop run ${a.runId}: ${SCOPE[a.mode]} (${a.mode}). Today is ${a.date}. Run folder: ${a.runDir}. Website repo: ${WEB}.`,
  'Reviewer reports:',
  ...reports.map(r => (r.reportText
    ? `- area ${r.key}: not saved as a file; its full text is at the end of this message (${r.verdict})`
    : `- ${r.reportPath} (${r.verdict})`)),
  a.mode === 'site'
    ? 'Whole-site run: the owner approves your plan before anything is fixed, so make plan.md easy to approve or strike from, decisions first.'
    : 'Scoped run: your plan goes straight to the implementers. Keep packages tight.',
]
if (Array.isArray(a.appChanged) && a.appChanged.length) organize.push(`App-repo files that changed what the site should say: ${a.appChanged.join(', ')}.`)
if (a.notes) organize.push(`From the owner, this session: ${a.notes}`)
if (reports.some(r => /\d$/.test(r.key))) {
  organize.push('Some areas were split between two reviewers (H1 and H2, and so on). Each is still one area: give packages its letter, and merge findings the two halves share.')
}
organize.push(
  'Give every package its "files", the paths relative to the website root it will change: packages that share no file are implemented side by side.',
  `Write ${a.runDir}/plan.json and ${a.runDir}/plan.md, update .claude/ux-web/ISSUES.md, then return the structured result.`,
)
for (const r of reports.filter(x => x.reportText)) {
  organize.push('', `===== Report for area ${r.key} =====`, r.reportText)
}

const plan = await agent(organize.join('\n'), {
  agentType: 'web-ux-organizer',
  label: 'organize',
  phase: 'Organize',
  schema: PLANNED,
})
if (!plan) throw new Error('The organizer did not return a plan.')
log(`Plan: ${plan.counts.fix} to fix in ${plan.packages.length} package(s), ${plan.counts.decide} for the owner, ${plan.counts.skip} skipped.`)

// Reports a reviewer couldn't save: the main session writes them to the run folder.
const inlineReports = reports
  .filter(r => r.reportText)
  .map(r => ({ path: `${a.runDir}/review-${r.key}.md`, text: r.reportText }))
return {
  runId: a.runId,
  runDir: a.runDir,
  mode: a.mode,
  reports: reports.map(r => ({ key: r.key, reportPath: r.reportPath, verdict: r.verdict, counts: r.counts })),
  inlineReports,
  plan,
}
