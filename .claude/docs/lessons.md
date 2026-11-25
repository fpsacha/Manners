# Lessons, 21 to 24 November 2026

What a long session learned the hard way, for the next one. Read it before
adding a feature, changing a default, releasing, or answering players.

## Scope: what Manners is, and the 1.11.41 lesson

Manners returns buffs, buffs your group and passers-by, and says thanks. In
1.11.41 it grew in-fight "buttons for the moment" (Counterspell, Blink, Ice
Block, a drink button, wards, Purge...), a falling prompt, card art, water for
the target and more, several ON by default. Players revolted within hours
("bloated", "uninstall", "a mess to turn it all off", "make it a separate
addon"). The owner rolled it back:

- **1.11.42** = 1.11.40 plus only the bug fixes (built from the r39 merge plus
  cherry-picked fixes, master's tree reset to it in one commit).
- **1.12.0**: the essentials by default. Off until ticked: Will of the
  Forsaken, the cure button and Mend Pet in a fight, consumables (food, flasks,
  elixirs, scrolls, weapon oils/stones/poisons, the consumables button), the
  fishing lure, Well-Rested, the companion pet, tracking, a mage's scrolls,
  Make a healthstone; courtesies stay off. Removed: the fight key, Hide the
  prompt in a fight, No flashes in a fight, Dim the prompt in combat (the
  fight's rota stays). Back, off by default: Offer water and food to my target
  (with "Put it on an action bar"). Report a bug window, PR 34.
- **1.12.1**: achievements removed (milestones, hall of fame, Gentlefolk, the
  ledger's title and counter; the ledger list stays), a truly simple Simple
  view (on by default, about a tenth of the options), Also offer Thorns to my
  target, Show what Manners is doing in chat OFF by default, Send Manners
  messages to (a chat tab).
- 1.11.41 was archived on CurseForge (still on Wago and GitHub releases). Its
  code is on branch `features-1.11.41`, pushed.

Rules that follow, the owner's:

- **No new feature ON by default.** Anything beyond the core ships off.
- **Before building, ask: does it serve returning and giving buffs?** If not,
  say so and suggest a separate companion addon rather than building it in.
- **A rollback keeps fixes to existing features.** The cure button's
  aura-display workaround was dropped with 1.11.41's extras by mistake: it was
  a fix (the cure button is blind on Forever without it), not a new feature.
  Split a mixed change; never drop a fix with its package.
- Hunter pet interactions stay (players like them).

## What WoW Forever hides (settled by the owner's own check-ups)

- Other players' casts: UNIT_SPELLCAST_SUCCEEDED arrives with the spell id
  and the cast id withheld (10 heard, 10 withheld). The cast watch cannot name
  a buffer from a cast on Forever.
- The player's own health and mana are hidden even out of a fight.
- Aura contents are withheld in a fight; `C_UnitAuras.GetUnitAuraInstanceIDs`
  is refused to addons there ("Auras cannot be accessed when secret while
  tainted"), so the cure button cannot read who needs it. Reading a target's
  buffs by index in a fight throws the same taint error (1.11.41's Purge rows).
- Loss of control arrives as kind "? (secret)".
- Blizzard's `CustomAuraContainerTemplate` (Blizzard_AuraContainer on the
  `forever` branch of Gethe/wow-ui-source) may be created by an addon and draws
  auras under secrets: the route the cure fix used (branch `features-1.11.41`,
  `Prompt/CureNeed.lua`).
- Players who say "it can't find who buffed me" (issue 44, Lor3_404,
  ladysteph): the caster is hidden on the aura too; still waiting on a
  `/manners debug`.

## Releasing

- The whole suite takes about 22 minutes now (`hunt38-picker.lua` alone about
  5.5). When the owner asks for speed, `check.py --quick` plus the touched
  files is acceptable: `release.py` waits for GitHub's CI, which runs the full
  tests, and nothing uploads if CI is red. Read the failure with
  `gh run view <id> --log-failed`, fix, push, rerun `release.py` with the same
  version.
- A changed default breaks every scenario that assumed the old one: tests
  should tick what they test (`H.extrasOn(ns)` in tests/scenarios.lua), never
  rely on a default.
- Test-harness leaks: a scenario file can leave globals replaced for the next
  file in the same worker (97 false failures once). tests/scenarios.lua now
  restores every global function and `C_` table after each file; restore saved
  globals by NAME, not with `pairs` over saved values (nil ones are skipped).
  `Mock.reset` clears UIParent's and GameTooltip's `_kids` (a worker reached
  22 GB before).
- After a release copy the build to
  `D:\wow\World of Warcraft\_forever_\Interface\AddOns\Manners` and remove
  files the release deleted.

## Working with agents and the owner's budget

- Five builders in parallel burned the owner's weekly budget fast. Run one
  builder at a time unless the owner asks for speed, and say what it costs.
- Workflows with several review rounds are thorough but slow (hours); the
  owner found "late evening" unacceptable. For a release, prefer one focused
  builder with targeted tests.
- An agent cut off by a usage limit leaves uncommitted work: commit it to a
  `wip-*` branch before reusing the worktree.

## Answering players

- CurseForge shows a thread's newest reply at the TOP of the thread, under the
  first comment: a reply may look missing when it is there.
- The comment page loads 20 threads and often will not load more; older ones
  may need the owner.
- Ask players questions in a reply, never in release notes (1.12.1's notes
  asked KoriKaiMoon for a debug: she would never see it).
- The owner sometimes answers players himself: ask before posting a round.
- Report a bug files GitHub issues with the full check-up; read them with
  `gh issue view N` (tools/read_report.py summarises one).

## Open after 1.12.1

- Bring back only the cure button's aura-display workaround (from
  `features-1.11.41`), off by default, without the Shift/Ctrl choices: the
  owner was offered it.
- KoriKaiMoon: party members missing her blessings ignored in dungeons, not
  reproduced with defaults (tests/scenarios/dungeon-party.lua); asked for a
  `/manners debug` from a dungeon.
- Issue 44 (buffer not named on Forever), issue 33, issue 21, #46 and #50
  waiting on players.
- Rhysicuss (Reddit): choose which blessing to ask a paladin for (Kings): a
  small dropdown under Ask people for a buff I'm missing, not built.
- Dark_Arcana's personal question is the owner's to answer.

## MageFeast

The owner's own small mage addon, not in git, only in the game folder:
`D:\wow\World of Warcraft\_forever_\Interface\AddOns\MageFeast` (1.10: mana gem
conjure, a gem button on the bar, key boxes on every row; backups beside it).
