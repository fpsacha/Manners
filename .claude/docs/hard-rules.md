# Manners -- the hard rules, long form

`CLAUDE.md` keeps the hard rules short; this is the full text they were cut
from, with every mechanism, switch and test named. Change both together. Moved
out of `CLAUDE.md`, word for word; `CLAUDE.md` is the index, read first.

## Hard rules

- **Lua 5.1.** 60 upvalues per function, 200 active locals. `tests/validate.py`
  fails a function over 55 upvalues or 190 active locals, or a file whose main
  chunk keeps fewer than 10 locals free. Fix by putting helpers in a
  `do ... end` block or lifting closures to file level. Tests run on
  `lupa.lua51`; test Lua stays 5.1-clean too.
- **Secret values.** Anything branched on passes through `ns.plain()` (secret ->
  nil). No `pcall`/`ns.safecall` on busy paths (per unit, per event, per
  repaint): call directly after a `type()` check. `pcall` only for restricted
  aura reads, library code, calls handed a possibly secret value, API drift
  and setup; `ns.Guard` at event, timer and module boundaries. The policy is at
  the top of `Core.lua`'s secret-safe section; `tests/scenarios/perf-budget.lua`
  caps pcalls, client calls and KB per scan for each of the five clients in six
  places (idle, city, dungeon, raid, city with a never-offer list, raid with
  group casts), at about measured + 25%; `MANNERS_PERF_REPORT=1 python
  tests/runscenarios.py --file perf-budget.lua` prints what each measures
  (Forever: idle 10, city 13, raid 18 pcalls). No file keeps its own copy of
  `pcall`.
- **Combat.** The secure button's attributes cannot change in combat: what is
  on the prompt when a fight starts stays until it ends. The one exception is
  secure code, the fight's rota (`Prompt/Fight.lua`, `prompt.fightRota`, on):
  at the pull the header is handed the macro of everybody in the queue, and a
  `SecureHandlerWrapScript` round the prompt's OnClick writes the next one on
  the button at every left press, so a fight's presses go once round the
  people it began with rather than at one of them, and past the last it
  writes none (the button casts nothing until the fight ends; secure code
  can read no cooldown and no aura, so "pressed for" is all it knows);
  `SyncFightRota`, from the prompt's PostClick, then points `S.current` at
  whoever the button now casts at, or at nobody once the round is done
  (`Prompt:FightRotaDone`). The pull arms none of it from a passer-by
  offered from memory alone (`ForFight`, Queue.lua's `remembered`). Lua
  still writes nothing on the button in a fight.
  The break-free button (`Prompt/BreakFree.lua`, MannersBreakFree) casts
  only Will of the Forsaken, from its own key or a left click: armed out of
  combat whenever it applies, shown and hidden by its own state driver for
  every fight, whatever a snooze or the prompt's place at the pull say, but at alpha 0 (no tooltip, its highlight a region so
  it takes the alpha) and faded in by Lua (a plain OnUpdate, as the cure's)
  only while you are afflicted; in a fight Lua paints only its regions and
  alpha. Afflicted is a plain read of the loss of control (FEAR, FEAR_MECHANIC,
  CHARM, SLEEP) or of UnitIsCharmed; an added event's numeric eventIndex is
  read first because a record can be present before the active count catches
  up. An empty first read is rechecked for ten seconds but is not guessed from
  by itself. Where the game withholds the read (secret) or has no API, losing
  control of your character in the fight (PLAYER_CONTROL_LOST, or a
  LOSS_OF_CONTROL_ADDED with a secret type) is the need, ended by
  PLAYER_CONTROL_GAINED, HasFullControl plainly true, the release, or ten
  seconds with HasFullControl unreadable; a plain read always wins, so a plain
  stun is no reason (`tests/scenarios/wotfneed.lua`). `prompt.fightButtons` = `always` keeps it dim (0.35) for the whole
  fight instead, and covers Mend Pet's button the same way; the cure button
  never reads it. Nothing Manners itself chooses may keep it from showing when
  it is needed and from being pressed, and the prompt's own key keeps to
  buffs. Off by default since 1.12 (`prompt.breakFree`), as are the Mend Pet
  button (`beast.fightMend`) and the cure button (`prompt.cureFight`).
  The cure button (`Prompt/CureFight.lua`, MannersCureFight) is the other
  way round: nothing of it may be on the screen for nothing. It is armed out
  of combat and shown by its own state driver for every fight, but at alpha 0
  (no tooltip, its highlight a region so it takes the alpha); Lua paints only
  its alpha and its own text and textures in a fight, fading it in once a read
  in the fight has found somebody in reach it can cure, and out again when
  nobody needs it. A class with two cures gets two buttons while
  `prompt.cureFightEach` is on (the default): MannersCureFight casts the first
  cure (its macro still holds the second behind Shift, so a key bound for the
  one cure keeps casting the second on Shift) and MannersCureFight2 the second, below it, with
  `CLICK MannersCureFight2:LeftButton` for a key. They are two slots of one
  file and one header drives both (`SetFrameRef("cure2", ...)` and the
  attribute `manners-two`, written out of combat in Refresh; the snippet shows
  or hides the second by the same newstate test); each shows only for the
  kinds its own cure removes, and Lua shows, hides, moves or arms neither in a
  fight. With the switch off, or one cure, there is one button and the second
  cure is on Shift. Where the client withholds auras (Forever, retail) the
  contents of every aura are passed over, but the game's own list of the
  harmful auras you can remove (`C_UnitAuras.GetUnitAuraInstanceIDs(unit,
  "HARMFUL|RAID")`, plain: `AuraUtil.AuraFilters.Raid`) says somebody carries
  one: the group and focus are then read as on a plain client, and somebody on
  the list whose auras are all withheld is shown with the kind unnamed ("a
  debuff you can remove"), on both buttons. An empty list ends the read at
  once. A plain read that found nothing (deny list, under two seconds, the
  client's no) still wins. Naming the kind under secrecy through
  `GetAuraDispelTypeColor` and a color curve is noted, not built (the
  dispel-type ids are not documented). Its events (UNIT_AURA and the rest) are registered at the
  pull and dropped at the release, UNIT_AURA filtered by a table lookup
  outside the Guard, and a scan with the switch off and no button made pays
  one profile field and no question to the client. A value the client
  withholds is never compared or boolean-tested: a withheld debuff is passed
  over, and where the client withholds them (Forever, retail) with no list of
  what you can remove, only you and your target are read.
  Reactive ward buttons (`Modules/Combat/Wards.lua`, Manners: Combat) pre-arm
  a known Fire Ward and Frost Ward out of combat. They reveal one macro only
  after `UNIT_COMBAT` supplies a plain player `DAMAGE` amount and an
  unambiguous numeric fire or frost school mask, and the ward is still known,
  usable with enough mana and ready off cooldown. They never infer a school
  from secrets, names or the combat log. On clients with secret combat values
  the feature makes no runtime frame and no options control.
  The detected combat prompt (`Modules/Combat/Moments*.lua`, Manners: Combat)
  covers every class through the client's action catalog. Every action has an
  independent switch (off by default) and learned-spell gate, but the player
  sees one prompt: the most urgent detected spell replaces its icon, name and
  reason. The player may choose any look, size, quiet/pulse/strong-pulse alert
  and optional sound in *In a fight*; the whole panel is the click target. Its
  secure slots all share that place and no per-action binding is exposed.
  Macros, points, size and mouse state are armed before combat; during lockdown
  only the selected slot's visual z-order and the unprotected art change. A
  target-cast event is the safe positive for an interrupt, so a secret
  interruptible flag never inserts a reveal click; an explicit uninterruptible
  cast is still dark. Other withheld reads are never treated as a need without
  a safe positive signal.
  Gone in 1.12, when Manners went back to its essentials: the fight key (*In a
  fight, my key casts*, `Prompt/FightKey.lua`), *Hide the prompt in a fight*
  (the hide snippet in `Prompt/Fight.lua`), *No flashes in a fight* and *Dim
  the prompt in combat*; ClampSettings lets their saved fields go. Never hide
  the prompt by any route that leaves it, a row or the bar macro able to
  cast: a hidden secure button still fires from its binding and `/click`. The
  repaint after the fight arms the prompt afresh.
- **Secure frames never anchor to a region.** The client refuses a protected
  frame's `SetPoint` onto a font string or texture ("Cannot anchor protected
  frames to regions"); 1.8.0 did it for the list's names and threw in
  ApplyStyle at every login. Anchor secure buttons to frames (the prompt's
  art, its button); `tests/mockwidgets.lua` refuses the region anchor as the
  client does.
- **Macro.** 255 characters (`ns.MACRO_LIMIT`); the spoken line gets what the
  cast lines leave (`ns.PhraseBudget`). A press on anybody, yourself included,
  is `/target <name>`, `/cast <spell>`, and `/targetlasttarget` when your
  target is handed back (`Prompt/Macro.lua`, `STRATEGIES`); a self-cast shout
  is a bare `/cast`, a scroll `/use item:<id>`, and a scroll that needs a
  friendly target (Classic's stat scrolls, `STRATEGIES.allyscroll`) `/target
  <your name>`, `/use item:<id>` and the hand-back. No `[@player]` or any
  `[@unit]` conditional on Forever, where they do not resolve. The one
  exception is the fight's cure button (`Prompt/CureFight.lua`), whose macro
  is `/cast [@mouseover,help,nodead][help,nodead][@player] <cure>` where
  `caps.conditionalTargeting` is true (every client but Forever) and a bare
  `/cast` on Forever; no `/target`, no spoken line, no hand-back. The
  prompt's conditional is bare: the macro armed for a fight hands back with `/targetlasttarget
  [help]` (`HandBack`), so a `/target` that found nobody leaves your mob
  targeted; `/manners selftest launch` (`launch.handback`) says whether the
  client's `[help]` reads the target as `UnitCanAssist` does. Secure buttons
  register `"AnyDown"`. Only the left mouse button casts: every other button
  (type2..type5 and the wildcards `*type2`..`*type31`) is set to `none` in
  `Prompt/Macro.lua` `SilenceOtherButtons`, because the client looks an
  attribute up modifier-prefixed first and shift-right-click would otherwise
  run the macro. No macro ever /clicks the prompt: the client refuses a macro
  that clicks a button which runs a macro (Blizzard, WoWUIBugs #552; Classic
  Era 1.15.9 cast nothing from `/click MannersPrompt LeftButton 1`). The bar
  macro carries the cast under `/click MannersBar` (Clicks.lua, click macro):
  the prompt's macro, spoken line included when one is armed and fits beside
  the bar line (the arming's own judgement: a bar press has no PreClick to
  hold it at the last moment, so one said over a cast that then fails cannot be
  taken back; a line too long for the bar's copy leaves it the cast alone),
  written out of combat only, never during a bar press or with the macro
  window open, only into the macro named Manners while its body is Manners'
  own (the bar line first, then a shape Manners writes: at most one `/target
  <name>`, one `/cast <spell>` with at most one spoken line after it, in a
  channel of `ns.CHANNEL_COMMANDS` and with no `[`, or `/use item:<id>` with at
  most one `/use 16|17` (after a `/target` of your own name for a scroll), and
  after a `/target` at most one hand-back, bare or the fight's `[help]`, in
  that order; `#` lines kept on
  top; Clicks.lua `Shaped`).
  The press is filed by Press.lua's OnBarClick against `Prompt.bar`, and only
  when the macro running (`GetRunningMacro`) is the Manners one; a body a
  session before left, found in a fight, is read (`Look` runs in combat,
  writing nothing) and its presses said and never filed (`StaleBarPress`).
  `tests/validate.py` fails a `"/click MannersPrompt` literal anywhere but
  Clicks.lua's `LEGACY_BODIES`.
- **Auras.** `C_UnitAuras` on every client; never `UnitBuff`/`UnitAura`.
- **Public text** (README's player sections, CHANGELOG, listings, toc Notes):
  no "untested" / "mock client" / "not tried in game" disclaimers.
  `tests/validate.py` checks the toc Notes. Listing files hold only the page
  text.
- **Listings** are pasted by the user from `.github/curseforge-summary.txt`,
  `curseforge-description.md`, `wago-description.md` and `gallery.md`:
  neither CurseForge nor Wago has an API for the page text (uploads only).
  The pictures' order, titles, descriptions and alt text are one list,
  `GALLERY` in `tools/make-screenshots.py`: `gallery.md`, `media/UPLOAD.md`
  and every page's alt text follow it, and every page opens on its first
  picture, the moment the addon is for (`tests/validate.py`, "the listings
  tell the moment first"; mutations in `tests/mutations/storefront.py`).
  The CurseForge opening (down to *What you see*), the README's (down to
  *Installing*) and Wago's page each name every headline feature in
  validate.py's `_HEADLINES` ("the listings name what ships"): a release
  whose highlight is new adds it there and to the three pages. The summary
  is one line of 150 characters at most. Every picture's alt text is
  GALLERY's, the listings say passer-by (never "nearby"), and a count of
  looks or of In character lines ("Nineteen looks", "over three thousand
  lines") is read against `Looks/` and `Phrases.lua` ("the listings' small
  facts are the addon's"): a new look or a thousandth line turns it red
  until the pages say so.
- **Secrets.** Never take, type or store an API key. The user sets them with
  `gh secret set CF_API_KEY` (and `WAGO_API_TOKEN`), which prompts.
- **CPU.** Leave 2 cores free across the machine. Run as many read-only agents as
  fit the available tool/session limit. Before parallel test work, set
  `MANNERS_JOBS` to a machine-wide budget and split that budget between agents;
  an agent running tests uses `--jobs` from its share. Stop adding agents if the
  owner is slowed, memory is short, or commands begin competing for workers.
- **Parallel agents** work in git worktrees, never the live tree. Read-only
  reviewers may share a revision and split by subsystem; builders each own a
  worktree and a disjoint set of files, scenarios and mutations. One integrator
  merges them in order. After merging, look for the same fix made twice (a chat
  line said twice, a mutation gone MISSED).
- **Files.** Write generated files with the Write tool, never bash heredocs
  (they eat backslashes; `scenarios.lua` is full of `\0`). Text is LF
  (`.gitattributes`); in Python write with `newline=''`. Lua is tab-indented,
  Python 4 spaces.
- Never hand-edit a generated toc or a version number: `tools/maketocs.py` and
  `tests/setversion.py` write them.
