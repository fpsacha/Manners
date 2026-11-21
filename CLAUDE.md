# Manners -- guide for agents

Read this whole file first: it is the index, short on purpose. The detail is in
the topic files under `.claude/docs/` (TOPICS, at the end); open the ones your
task touches. Not shipped (`.pkgmeta` ignores this file, the packager skips dot
folders). State and open items: `STATUS.md`. Release checklist: `RELEASING.md`.
What changed: `CHANGELOG.md` (written for players). Test internals:
`tests/README.md`. Tool details: `tools/README.md`.

## What it is

A World of Warcraft addon (MIT, github.com/fpsacha/Manners, branch `master`,
CurseForge 1705364, Wago `rNkgzlNa`) that returns buffs. It notices who buffed
you, works out what you owe, and puts one secure button (the prompt) on screen;
a press targets them by name, casts, and hands your target back. It also offers
your group, people who ask in chat, and passers-by missing your buff, reminds
you of your own self-buffs, keeps a favour ledger, and can say a line when it
casts (fixed sets or the "In character" set). Since 1.11.25 the same button
also offers a resurrection, a cure, a courtesy somebody asked for and a polite
ask for a buff you lack ("Entry kinds" in `.claude/docs/clients.md`). Addons
cannot cast on their own: everything except the keypress is decided in Lua and
parked on the button.

## The five clients

| flavour key | client | interface | toc | family | combat log | secret values | UnitName 2nd return |
|---|---|---|---|---|---|---|---|
| `camelot` | WoW Forever 1.60.1 (a Midnight fork, vanilla content) | 16001 | `Manners_Camelot.toc` | modern | no | yes | surname |
| `vanilla` | Classic Era 1.15.9 | 11509 | `Manners_Vanilla.toc` | classic | yes | no | realm |
| `tbc` | Burning Crusade Classic Anniversary 2.5.6 | 20506 | `Manners_TBC.toc` | classic | yes | no | realm |
| `mists` | Mists of Pandaria Classic 5.5.4 | 50504 | `Manners_Mists.toc` | classic | yes | no | realm |
| `mainline` | retail Midnight 12.1.5 | 120105 | `Manners_Mainline.toc` | modern | no | yes | realm |

All five ship: WoW Forever from the first release, Classic Era since 1.6.7,
TBC, Mists and retail since 1.7.0. Forever is the
default everywhere in the tests and the only client anybody here plays.
Branch on `Buffs.lua`'s fields and per-buff flags, never on flavour names
(`.claude/docs/clients.md`).

## Hard rules

Short form; `.claude/docs/hard-rules.md` is the long form, with every
function, switch and test named. Change both together.

- **Lua 5.1.** 60 upvalues per function, 200 active locals. `tests/validate.py`
  fails a function over 55 upvalues or 190 active locals, or a file whose main
  chunk keeps fewer than 10 locals free. Fix with a `do ... end` block or by
  lifting closures to file level. Tests run on `lupa.lua51`; test Lua stays
  5.1-clean too.
- **Secret values.** Anything branched on passes through `ns.plain()` (secret ->
  nil); a value the client withholds is never compared or boolean-tested. No
  `pcall`/`ns.safecall` on busy paths (per unit, per event, per repaint): call
  directly after a `type()` check. `pcall` only for restricted aura reads,
  library code, calls handed a possibly secret value, API drift and setup;
  `ns.Guard` at event, timer and module boundaries. The policy is at the top of
  `Core.lua`'s secret-safe section; `tests/scenarios/perf-budget.lua` caps
  pcalls, client calls and KB per scan on each client. No file keeps its own
  copy of `pcall`.
- **Combat.** The secure button's attributes cannot change in combat: what is
  on the prompt when a fight starts stays until it ends, and Lua writes nothing
  on the button in a fight. The exceptions are secure code or bindings set at
  the pull (`PLAYER_REGEN_DISABLED`, before the lockdown), never under it:
  *Hide the prompt in a fight* (`Prompt/Fight.lua`: the snippet disarms the
  prompt and its rows, then hides it, only when the bar macro holds no cast);
  the fight's rota (the header steps the button once round the queue the fight
  began with, then casts nothing; never armed from a passer-by offered from
  memory alone); the fight key (`Prompt/FightKey.lua`: override bindings point
  the prompt's key at a button armed with the chosen spell, never shown,
  cleared at the release). The break-free, Mend Pet and cure buttons have
  their own state drivers and sit at alpha 0; in a fight Lua paints only their
  regions and alpha. Nothing Manners chooses may keep break-free from showing
  and being pressed when needed; the cure button is the other way round,
  nothing of it on screen for nothing. Never hide the prompt by any route that
  leaves it, a row or the bar macro able to cast: a hidden secure button still
  fires from its binding and `/click`.
- **Secure frames never anchor to a region.** The client refuses a protected
  frame's `SetPoint` onto a font string or texture ("Cannot anchor protected
  frames to regions"; 1.8.0 threw at every login). Anchor secure buttons to
  frames; `tests/mockwidgets.lua` refuses the region anchor as the client does.
- **Macro.** 255 characters (`ns.MACRO_LIMIT`); the spoken line gets what the
  cast lines leave (`ns.PhraseBudget`). A press is `/target <name>`,
  `/cast <spell>`, and `/targetlasttarget` when your target is handed back
  (`Prompt/Macro.lua`, `STRATEGIES`). No `[@player]` or any `[@unit]`
  conditional on Forever, where they do not resolve (the fight's cure button,
  off Forever, is the one exception). Secure buttons register `"AnyDown"`;
  only the left mouse button casts (`SilenceOtherButtons`). No macro ever /clicks the
  prompt (the client refuses a macro that clicks a button which runs a macro);
  the bar macro is `/click MannersBar` and the prompt's macro, written out of
  combat only, only into the macro named Manners while its body is Manners'
  own (Clicks.lua `Shaped`). `tests/validate.py` fails a `"/click
  MannersPrompt` literal anywhere but Clicks.lua's `LEGACY_BODIES`.
- **Auras.** `C_UnitAuras` on every client; never `UnitBuff`/`UnitAura`.
- **Public text** (README's player sections, CHANGELOG, listings, toc Notes):
  no "untested" / "mock client" / "not tried in game" disclaimers (validate
  checks the toc Notes). Listing files hold only the page text.
- **Listings** are pasted by the user from `.github/curseforge-summary.txt`,
  `curseforge-description.md`, `wago-description.md` and `gallery.md` (no API
  for the page text). The pictures' order, titles and alt text are `GALLERY` in
  `tools/make-screenshots.py`; every page opens on the moment the addon is for
  and names every headline in validate.py's `_HEADLINES` (a new highlight goes
  there and on the three pages); the summary is one line of 150 characters at
  most; passer-by, never "nearby"; counts of looks or lines are read against
  `Looks/` and `Phrases.lua`.
- **Secrets.** Never take, type or store an API key. The user sets them with
  `gh secret set CF_API_KEY` (and `WAGO_API_TOKEN`), which prompts.
- **CPU.** Leave 2 cores free. With several agents running tests, split the
  workers between them (`--jobs`, `MANNERS_SCENARIO_JOBS`).
- **Parallel agents** work in git worktrees, never the live tree, and put new
  scenarios and mutations in files of their own. After merging, look for the
  same fix made twice (a chat line said twice, a mutation gone MISSED).
- **Files.** Write generated files with the Write tool, never bash heredocs
  (they eat backslashes; `scenarios.lua` is full of `\0`). Text is LF
  (`.gitattributes`); in Python write with `newline=''`. Lua is tab-indented,
  Python 4 spaces.
- Never hand-edit a generated toc or a version number: `tools/maketocs.py` and
  `tests/setversion.py` write them.

## The owner's standing rules for agents

- Work in a git worktree, never the live tree (`D:/Projects/WOW_Addons/Manners`).
- Nothing is shown in a fight without a detected need: a button, line or light
  appears only once a read in the fight has found it wanted.
- Never tell a player something is impossible: say what Manners does, or what
  it would take.
- Never post a reply twice: before posting, look for a reply already there (the
  nightly pass answers comments too); a POST's 201 is the proof it went, a page
  that lags after a reload is not. `.claude/snippets/curseforge-reply.js` does both.
- One agent at a time: queue them rather than fan out several in the background.
- Tests go easy on RAM: `--jobs 4` at most, one suite at a time; ask before a
  full selftest (GitHub runs it, `selftest.yml`). An agent runs a suite in the
  foreground with a timeout, never in the background or on a Monitor.
- Build first, test once: while building, only `tools/lint.py` and the piece's
  own scenario file; no suite and no push until the owner calls the test pass.
- No other addon is ever named, hinted at or compared with: not in listings,
  README, CHANGELOG, strings, comments, test names, commits or STATUS.md.
- Every feature gets a control (the options window, the launcher menu); a slash
  command is only a shortcut, and replies to players name the setting.
- Behaviour before looks: the right buff for the situation, working in a fight.
- Docs move with the code, before every release: README's player sections,
  `STATUS.md`, the listing files, this file and `.claude/docs/`,
  `tools/README.md`, `tests/README.md`. CHANGELOG notes are short: `###`
  sections, a line or two each, the switch named.
- An In character line is said while giving a buff: it must make sense to the
  one who just felt it land (`.claude/docs/phrases.md`).
- Looks start from named Warcraft art and go bold on art and animation, each
  one unique; show animations as GIFs. All art is painted through the Gemini
  image API, never drawn in code.
- Releases are the owner's call (the nightly feedback task's own release
  apart) and go out from this PC, never a cloud session; a feature asked for
  before a release ships goes in that release.
- Do the obvious next step and report after; ask only before a release or a
  deletion.
- No in-game testing by the owner: assume the code works once the suites pass,
  never ask the owner to check something in the game, and let players' reports
  find what the simulator could not (ask the player for `/manners debug`).

## Everyday commands

- `python tools/lint.py`: every Lua (5.1) and Python file compiles and the
  generated tocs are current, under a second (the Edit hook runs `--quick`).
- `python tools/anchors_for.py FILE:LINE` **before** editing a line (the
  mutations whose text sits there); `--check-after` **after** (only the gone
  ones: re-aim them in the same change, never delete them).
- `python tools/prove.py "<label text>"` or `--file tests/mutations/<topic>.py`:
  a new mutation proven in seconds on its own scenario files (CAUGHT proves it).
- `python tools/check.py`: validate, harness, scenarios on Forever. `--quick`
  (no scenarios, a minute or two), `--lint` (lint first, stop on a fault),
  `--flavours` (each client's own files), `--anchors`, `--release` (all of it).
- `python tests/selftest.py --changed [REF]`: the mutations of every file that
  differs from REF (default master). Before handing work back:
  `check.py --lint --flavours --anchors` and `selftest.py --changed`.

## Start of a session

1. Read `STATUS.md`'s *Where I left off*.
2. `gh issue list --label player --state open`: what players are waiting on.
3. `git worktree list`: the worktrees already out, and whose they are.
4. `git branch --list "feedback-*"`: feedback branches not yet merged.

## TOPICS

Under `.claude/docs/`, each standing alone. Open the one your task touches.

- `file-map.md`: what each file holds, adding a setting. Before adding or moving code.
- `clients.md`: `Buffs.lua`'s fields and flags, each client's own ways, entry
  kinds. For anything one client does differently, or a new kind of entry.
- `hard-rules.md`: the hard rules in full. Before touching `Prompt/`, a macro,
  a fight button or the listings.
- `checks.md`: every check and flag, `--jobs`, CI, dev tools, audits. To pick a check.
- `tests.md`: scenarios and mutations, names, anchors, timers. Before writing a test.
- `release.md`: the release steps and versions. Before a release.
- `translations.md`: locales, the addon's own words, the options layout's keys.
  For any player-facing string or a new control.
- `phrases.md`: In character pools, a line's rules, the examples caveat. Before
  adding or changing a line.
- `data-sources.md`: the builds per client (the audits read them here), Wowhead,
  Blizzard's UI source, client strings. Before reading or citing client data.
- `status-history.md`: the long notes on every feature up to 1.11.36 and the
  questions only the game can answer. When a player reports something about
  one of them, or a code comment says "(STATUS.md)" about a game-only question.
