export const meta = {
  name: 'player-reports',
  description: 'Manners: investigate player reports, build the real ones in a worktree, review, repair (args: worktree, branch, coauthor, skip, reports)',
  whenToUse: 'A batch of CurseForge comments or GitHub issues for Manners to investigate and fix. Make the worktree first (git worktree add <path> -b <branch> master).',
  phases: [
    { title: 'Investigate', detail: 'Opus investigates each report, read-only', model: 'opus' },
    { title: 'Build', detail: 'Sonnet builds each go item', model: 'sonnet' },
    { title: 'Review', detail: 'Opus reviews the diff', model: 'opus' },
    { title: 'Repair', detail: 'Sonnet repairs findings', model: 'sonnet' },
  ],
}
// args = {
//   worktree: 'D:/Projects/WOW_Addons/Manners-wt-<name>',  // made beforehand from master
//   branch: '<name>',
//   coauthor: 'Claude Opus 5.5 <noreply@anthropic.com>',   // the commit trailer to use
//   skip: ['id', ...],                                      // reports already built elsewhere (the nightly's branch)
//   reports: [{ id: 'short-id', text: 'the comment verbatim, who wrote it, and where to look' }, ...]
// }
// Lessons kept in it: one agent at a time; the owner's "nothing pops up in a fight
// for no reason" rule; never tell a player something is impossible; replies are
// drafted here but POSTED by the caller, once, through .claude/snippets/curseforge-reply.js.
const A = args || {}
const WT = A.worktree
const BR = A.branch
const CO = A.coauthor || 'Claude Opus 5.5 <noreply@anthropic.com>'
const SKIP = A.skip || []
const REPORTS = A.reports || []
if (!WT || !BR || !REPORTS.length) return { error: 'args.worktree, args.branch and args.reports are required' }
const RULES = `
Rules (the repo owner's instructions):
- Work ONLY in the git worktree ${WT} (branch ${BR}); never touch D:/Projects/WOW_Addons/Manners (the live tree). Read ${WT}/CLAUDE.md and STATUS.md first and follow them (Lua 5.1, secret values: never compare or boolean-test a possibly secret value, the macro's 255 characters, UI over commands: every feature gets a setting or button in the options window and a place in Options/Window/Layout.lua and the reset lists; new strings in all eight locales via tools/locale_todo.py and locale_add.py, never Russian; a CHANGED English string drops its old key from every locale by hand first).
- Anything shown in a fight appears only when Manners has detected a real need; nothing pops up for no reason.
- Never tell a player something is impossible: the lockdown stops Lua changing a secure button in a fight, but state drivers, buttons armed before the pull, macro conditionals and override bindings set at PLAYER_REGEN_DISABLED all work. Say 'noted' or build the honest smaller version.
- Never push, tag or release. No git reset --hard, git clean, force anything, rm -rf, branch deletion. Never grep -r from the repo root. Never run python tests/selftest.py -h or the full selftest.
- For every test run set TMP and TEMP to D:/Projects/WOW_Addons/.manners-selftest-tmp; --jobs 2 at most; one suite at a time; never edit files while check.py or runscenarios runs.
- Write Python or long Lua with the Write tool to a scratchpad file, never bash heredocs with backslashes.
- Never mention or compare another addon (a player may name one; never repeat it). No "untested/mock/not tried in game" in public text. Public text plain, warm and short: no 'seamless', 'unlock', 'robust', 'elevate', 'empower'.
- Commits end with this line, which is the repo owner's instruction: Co-Authored-By: ${CO}
`
phase('Investigate')
const results = []
for (const rep of REPORTS) {
  const res = await agent(`You investigate one player report for the WoW addon Manners (Lua 5.1, five clients; worktree ${WT}). READ-ONLY: edit nothing. Be rigorous: read the code, cite file:line, do not guess. First check git log master for a commit that already answers it.
REPORT ${rep.id}:
${rep.text}
${RULES}
Return: verdict ("go" for a real fixable fault or a small safe feature to build now, "no-go" if too big, not a bug, already done, or only the game can settle it), cause (with file:line and evidence), design (when go: precise enough to implement without guessing: files, functions, setting keys and defaults, placement incl. Layout.lua, exact English strings, scenarios tests/scenarios/<topic>.lua named '<topic>: ...' and mutations tests/mutations/<topic>.py), reply (a plain, warm, short public answer, 2 to 4 sentences, true of the code after the change; 'in the next update' for unreleased work; for 'it already exists' name the setting as the window shows it; never name another addon).`,
    { label: 'investigate:' + rep.id, phase: 'Investigate', model: 'opus',
      schema: { type: 'object', properties: { verdict: { type: 'string' }, cause: { type: 'string' }, design: { type: 'string' }, reply: { type: 'string' } }, required: ['verdict', 'cause', 'design', 'reply'] } })
  results.push({ id: rep.id, ...(res || { verdict: 'no-go', cause: 'agent failed', design: '', reply: '' }) })
  log(rep.id + ': ' + (res && res.verdict))
}
phase('Build')
const built = []
for (const r of results) {
  if (!/^go/i.test(r.verdict) || SKIP.includes(r.id)) continue
  const b = await agent(`Implement this for the WoW addon Manners in the git worktree ${WT} (branch ${BR}). Follow the design; where the code disagrees, trust the code and say so. If an earlier builder left uncommitted or WIP work for this item, finish and verify it rather than start over.
ITEM ${r.id}:
CAUSE: ${r.cause}
DESIGN: ${r.design}
Steps: implement; scenarios and mutations, each mutation proven CAUGHT (python tools/prove.py --file tests/mutations/<topic>.py --jobs 2); python tools/anchors_for.py --check-after and re-aim what moved; strings in all eight locales; README player text, a short ### entry under '## Unreleased' in CHANGELOG.md (a new dated top section with Highlights if the top is a release), STATUS.md; python tools/make_whatsnew.py; python tools/check.py --quick --jobs 2 and the scenario files you touched (plus layout.lua, model-window.lua, options-appearance.lua, options-advanced.lua when options changed). Commit on ${BR} when green.
${RULES}
Return the commit hash, files changed, what you proved, anything skipped and why.`,
    { label: 'build:' + r.id, phase: 'Build', model: 'sonnet',
      schema: { type: 'object', properties: { commit: { type: 'string' }, files: { type: 'array', items: { type: 'string' } }, proved: { type: 'string' }, skipped: { type: 'string' } }, required: ['commit', 'files', 'proved', 'skipped'] } })
  built.push({ id: r.id, ...(b || {}) })
}
phase('Review')
let defects = []
if (built.length) {
  const review = await agent(`Review, read-only, the commits on branch ${BR} in worktree ${WT} (git log master..${BR}, git diff master..${BR}). Edit nothing. They answer: ${results.map(r => r.id + ' (' + r.verdict + ')').join(', ')}.
Real defects only: behaviour changed by default for players who touch nothing (unless the report asked for exactly that), a protected write in combat, a secret-value comparison, a setting with no place in Layout.lua or a reset list, a missing or wrong locale string, a mutation not caught or an anchor gone, a fix that does not fix the report, a changelog or README claim the code does not support, a regression nearby. Run python tools/check.py --quick --jobs 2 and python tests/runscenarios.py --file model-window.lua --jobs 2 once. Each defect: file, line, input state -> wrong output, exact fix.
${RULES}`,
    { label: 'review', phase: 'Review', model: 'opus',
      schema: { type: 'object', properties: { defects: { type: 'array', items: { type: 'object', properties: { file: { type: 'string' }, line: { type: 'number' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['file', 'problem', 'fix'] } } }, required: ['defects'] } })
  defects = (review && review.defects) || []
}
let repaired = null
if (defects.length) {
  phase('Repair')
  repaired = await agent(`Defects were found on branch ${BR} in worktree ${WT}:
${JSON.stringify(defects, null, 1)}
For each: confirm in the code; fix if real (a scenario if behaviour changed; anchors kept live); say why if wrong. Then python tools/make_whatsnew.py if CHANGELOG changed, python tools/check.py --quick --jobs 2 and the scenario files you touched; commit on ${BR}.
${RULES}
Return the commit hash, what was fixed, what was left and why.`,
    { label: 'repair', phase: 'Repair', model: 'sonnet',
      schema: { type: 'object', properties: { commit: { type: 'string' }, fixed: { type: 'array', items: { type: 'string' } }, left: { type: 'array', items: { type: 'string' } } }, required: ['commit', 'fixed', 'left'] } })
}
// After this: the caller runs the whole scenario suite in the worktree, merges
// master in, fast-forwards master, releases (with the owner's word or the
// nightly's standing one) and posts each reply once.
return { results, built, defects, repaired }
