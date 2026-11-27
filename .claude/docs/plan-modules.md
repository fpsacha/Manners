# Hand-off: splitting Manners into optional modules

A brief for the next AI working on Manners. Written 25 November 2026, after
1.12.1. Read `CLAUDE.md`, `.claude/docs/lessons.md` and `STATUS.md` first; this
file is the plan the owner approved, with the decisions still open.

## Why

Manners (a World of Warcraft addon: it returns buffs, buffs your group and
passers-by, and says thanks) grew far past that goal. In 1.11.41 players
revolted ("bloated", "make it a separate addon", "a mess to turn it all off").
1.11.42 rolled 1.11.41 back; 1.12.0 and 1.12.1 switched the extras off by
default and removed the achievements (details in `lessons.md`).

The owner now wants the extras back, but OUT of the core: in the same download
as separate, optional addon folders that ship disabled. A player who wants
one enables it once in the game's AddOns list. Manners itself stays small.

## The approach (approved: "A. Same download, two folders")

- One CurseForge/Wago/GitHub release, one zip, several top-level folders:
  `Manners` (the core) plus one folder per module. No second listing.
- Each module is its own addon: its own `.toc` with
  `## Dependencies: Manners` and `## DefaultState: disabled` (the game honours
  it: shown unticked in the AddOns list until the player ticks it), its own
  `## Title` such as "Manners: Combat", its own SavedVariables if it needs any,
  the same five interface numbers.
- The core must behave identically with every module present or absent. A
  module only plugs in through hooks the core publishes; the core never
  requires a module.
- In Manners' options, a short line on *Start here* lists the modules and how
  to enable them; each module's options appear in the options window only
  while that module is loaded.

## The modules (owner's decisions so far)

| Folder | Contents | Default |
|---|---|---|
| `Manners` (core) | Returning favours; group and passer-by buffs; top-ups; the prompt and its key; the fight's rota; thanks and the In character lines; the favour ledger list; never-offer list, quiet times, Who to skip; resurrection and out-of-fight cures; asking for a buff; battlegrounds; profiles; Report a bug; **all the looks (owner: looks stay core)** | on |
| `Manners_Combat` | The cure button in a fight, WITH the aura-display workaround that makes it work on WoW Forever (branch `features-1.11.41`, `Prompt/CureNeed.lua`, plus Shift/Ctrl per cure); Will of the Forsaken button; Mend Pet in a fight. Later, if the owner wants: 1.11.41's "buttons for the moment" (Counterspell, Blink, Ice Block, wards, drink...) and the removed fight key / hide / dim options | disabled |
| `Manners_Achievements` | The overhauled achievements (plan below) | disabled |
| `Manners_Pets` | The hunter pet module (and, the owner wants it for warlocks too: a warlock's demon would need its own features designed; today the module is hunter-only): Call, Revive, Feed, Mend Pet out of a fight, Bond with my pet, the pet's own lines and moments (`HunterPet.lua`, `HunterPetHints.lua`, `BeastFoods.lua`, the My pet page) | enabled by default for hunters and warlocks (owner). `DefaultState` is per account, not per class: ship it enabled and have it do nothing (no frames, no events, no options page) for any other class |
| `Manners_MyBuffs`, titled **Manners: My Buffs** (owner's name) | Your own class buffs (armor, aura, aspect, forms, shields; "your own buffs come up as You"), consumables (food, flasks, elixirs, scrolls, weapon oils/stones/poisons, the consumables button), fishing lure, Well-Rested, companion pet, tracking, a mage's scrolls, Make a healthstone | disabled |
| `Manners_Services`, titled **Manners: Services** (owner: its own module) | Exact, explicit-request class services with independent controls: mage water/food, named portals and Slow Fall; priest Levitate; shaman Water Walking; warlock healthstones/Soulwell, summons and Soulstones; target refreshments; Fire Shield on the supported clients. Every service is off until enabled, and disabled services create no runtime frames, events or queue entries | disabled |

Order of work (owner: "good with me", Services in question): plumbing first,
then Combat (it brings the cure fix back), then Achievements, then Pets, the
own-buffs module, Services. The migration is now implemented as one coherent
branch for focused verification; any release remains the owner's call.

## Achievements plan (implemented)

Goals: off by default (the module ships disabled), zero cost and zero risk
when off, rewards good manners rather than grinding, never noisy.

- Read-only: built from the favour ledger's records and a few events the core
  publishes ("you buffed X", "X buffed you", "you thanked X"). It never
  touches the prompt, the queue or casting. Its own saved data and its own
  error guard.
- Themes: Gratitude (favours returned, thanks), Generosity (strangers buffed,
  first buffs of the day), Fellowship (groups kept buffed, resurrections),
  Courtesy (asking politely, water given), one set per class. Bronze, silver
  and gold tiers per achievement (10 / 100 / 1000) instead of 13 one-offs; a
  few hidden playful ones (buffing back within 10 seconds, the same stranger
  on three days).
- No grind: only real exchanges with other players count; daily caps per
  person; nothing rewards spamming buffs at nameplates.
- Quiet: one tab of the ledger with progress bars
  and the next goal per theme; toasts OFF by default (choice: none, a small
  toast, or one chat line; no sound unless picked); titles only inside that
  window; nothing on the minimap or in the ledger itself.
- Decided 25 November: (1) reuse the old 13 milestones' names and ideas
  where they fit, but the owner wants MORE and BETTER ones; (2) NO share card and no hall
  of fame (owner: no reason to have one); (3) credit the ledger's last
  200 entries on first enable; (4) a tab in the ledger, not a window of its own.
- The old code (Milestones.lua, Hall.lua, HallProof.lua, HallOfFame.lua, the
  ledger's title band) was removed in 1.12.1 (commit cce1be2e); `git show
  cce1be2e^:Milestones.lua` recovers it for reference. Do not restore it as
  is: the owner asked for a BIG overhaul.

## Technical notes for the plumbing (read the code; these are pointers)

- The core's namespace is private (`local _, ns = ...`). A module cannot see
  it. Publish a small public API from the core, e.g. a global table
  `MannersAPI` (or `LibStub`-registered), with: the AceDB object or a getter
  for the module's own profile section, event callbacks (CallbackHandler is
  already in Libs/), a way to register an options page and Layout entries,
  and the few functions a module needs (ns.plain, ns.Guard, ns.Trail, the
  prompt's refresh). Keep it small and documented in `.claude/docs/`.
- Settings: keep each moved feature's saved keys where they are (in Manners'
  AceDB profile) so players keep their choices when they enable the module, or
  give each module an AceDB namespace and migrate once. Decide in the plumbing
  step; a player who had a feature on before must find it on after enabling
  the module.
- Secure frames: a module that creates secure buttons (Combat) creates them
  at its own load, out of combat, exactly as the code does today; the combat
  rules in `CLAUDE.md` and `hard-rules.md` still apply.
- Packaging: `.pkgmeta` packages one folder today (`package-as: Manners`).
  The packager supports `move-folders` to ship several top-level folders from
  one repo (each module in its own source folder, e.g. `Modules/Combat/`
  moved to `Manners_Combat`). `tools/maketocs.py` generates the five tocs per
  client for the core; extend it for each module's tocs. `tools/release.py`,
  CI (`.github/workflows/`) and `tests/validate.py` (toc and file checks)
  need to know about the module folders.
- Tests: `tests/scenarios.lua` loads the core from its toc; it must load a
  module's files after the core when a scenario asks for that module, and the
  whole suite must also pass with no module loaded (proving the core does not
  depend on one). Each module's scenarios and mutations live in its own files.
- Copying to the owner's game folder: each module folder goes to
  `D:\wow\World of Warcraft\_forever_\Interface\AddOns\<folder>`.

## Where the code is

- Live tree: `D:/Projects/WOW_Addons/Manners`, branch `master` (= 1.12.1 plus
  docs). GitHub `fpsacha/Manners`.
- Branch `features-1.11.41` (pushed): everything removed in the 1.11.41
  rollback: the moment buttons (`Prompt/Moments*.lua`), the cure aura display
  (`Prompt/CureNeed.lua`), Fire Shield, water for the target, the cards.
- Removed in 1.12.0: the fight key (`Prompt/FightKey.lua`), hide/no
  flashes/dim; see `git log` for the commit "1.12 step 1".

## Rules that matter most here (from the owner)

- Manners stays small: nothing new ON by default; modules ship disabled.
- Work in a git worktree, never the live tree. Fan out read-only reviews and
  independent builders as the machine and session allow, under `CLAUDE.md`'s
  machine-wide worker budget. Builders own disjoint files and worktrees; one
  integrator merges and checks for duplicate fixes.
- Releases: `python tools/release.py X.Y.Z --coauthor "..."`; it waits for
  GitHub CI (the full tests) and uploads nothing if CI is red. Released
  without asking once green (see `CLAUDE.md`).
- No other addon is named anywhere. Every feature has a control in the
  options window. Players are answered with the setting's name.
- Ask players questions in replies, never in release notes.

## Player requests to fold in

- **Which blessing to ask a paladin for (core, the Ask feature, implemented).** Two players
  asked: Rhysicuss (Reddit: "change which buff is asked for ... Blessing of
  Kings instead of Wisdom") and broodwave (CurseForge, a Feral druid: "it
  defaults to ask Paladins for Blessing of Wisdom always, and stops after
  getting it ... as a Feral, Wisdom is the least one I need, and I'd like to
  ask for more than just that one"). Today `Ask.lua` `Want` uses
  `ns.CLASS_AUTO` (Buffs.lua: PALADIN mana = wisdom, other = might): anyone
  with mana is asked for Wisdom, and a class whose buffs replace one another
  stops after one. Build: a choice under *Ask people for a buff I'm missing*,
  "Blessing to ask a paladin for" (Automatic / Kings / Might / Wisdom /
  Salvation... as the client has them), Automatic reading the spec or talents
  (a Feral or a tank wants Might or Kings, not Wisdom, as `Core.lua`'s
  talent reading already does for other choices); and, with several paladins
  in reach, asking a second paladin for a second blessing (in Classic each
  paladin's blessing on you is separate). Automatic can move to a different
  missing blessing for the next reachable paladin after the first request.
  Off-by-default rules do not apply:
  Automatic must keep today's behaviour for everyone who does not choose.
- **The cure in a fight never shows on Forever** (user_8qf1t3rx4pgp80ez:
  "it shows cure poison out of a fight, but when I enter, nothing pops up";
  earlier user_fer3yhwuvuz52jwg, LuckyDan, the owner). This is the cure
  button being blind on Forever without the aura-display workaround: the
  Combat module's first job.

## Open bugs (GitHub issues, 25 November)

- **#44, the most reported bug: "the game did not say who" buffed you** (core).
  Many players on WoW Forever (#44, #53, #54 closed as a duplicate, Lor3_404,
  ladysteph, thetruekritze on CurseForge), standing next to the buffer with
  friendly nameplates on. Their check-ups show: the aura's caster is withheld,
  and the cast watch hears no buff casts (Forever hides other players' spell
  and cast ids completely: the owner's check-up had 10 casts heard, all
  withheld). So `Favours.lua` has nothing plain to name them by, files the
  favour as unnamed and prints the "Somebody just put a buff on you, but the
  game did not say who" hint (`Hints.lua`, `ns.UnmatchedBuffHint`). Ideas to
  examine, keeping the one-person rule (naming nobody is fine, naming the wrong
  player never): (a) when exactly one player who CAN cast that buff (its class,
  and level for the rank) is in sight at the landing (nameplates, group,
  target), name them; with two or more, name nobody; (b) whether any plain
  signal remains on Forever (the aura's `sourceUnit` through a path that is not
  withheld, the combat text, `UNIT_AURA` update info's `isFromPlayerOrPlayerPet`,
  the nameplate's aura reads); (c) at the very least make the chat hint
  quieter: it reads like an error to players ("I'm getting an error"), and
  1.12.1 already turned the chat commentary off by default. Write scenarios
  for each with the shapes the check-ups show (`tools/read_report.py` on #53).
- **#33, Will of the Forsaken never offered:** the module and focused scenarios
  cover learned-spell, race, control and lost-of-control reads. The report still
  lacks the player's client and `/manners debug`, so no player-specific root
  cause can be claimed.
  Now part of Manners: Combat (off by default since 1.12.0).
- **#21, No buff popup:** waiting on the player's client and log since 21
  November; likely stale, close if nothing comes.
- Closed 25 November: #46 (1.11.41's drink icon, gone), #50 (moving the prompt
  failed in 1.11.41's layout; closed, reopen if it recurs on 1.12.1), #54
  (duplicate of #44).
- KoriKaiMoon (CurseForge): party members missing her blessings ignored in
  dungeons; not reproduced with defaults (`tests/scenarios/dungeon-party.lua`);
  asked for a `/manners debug` from a dungeon.

## Progress

- **Issue #44 is built:** the caster's Manners sends one spell-id whisper on
  success; the receiver uses it first, else one capable player in sight and no
  ambiguous class; the chat hint is calm, verbose-only and once a session.
- **Plumbing is built:** `MannersAPI`, profile callbacks, dynamic options
  extensions and pages, bounded ledger copies, typed service-buff
  registration, a module-aware toc generator and core-without-module tests.
- **Manners: Combat is built:** disabled, with five generated tocs and the
  secure fight buttons.
- **Manners: Achievements is built:** disabled, with its own saved data, four
  themes, 10/100/1000 tiers, hidden moments, daily per-person caps and a
  first-enable seed from the ledger's last 200 rows.
- **Manners: Pets is built:** enabled by default; another class gets no pet
  frame, event or page, and a warlock is deliberately inert.
- **Manners: My Buffs is built:** disabled; own-buff behaviour, custom spells,
  companion pets and the supplies button live in the module while saved keys
  stay where they were.
- **Manners: Services is built:** disabled, with its own page and per-service
  controls. Exact client data supports mage refreshments, portals and Slow
  Fall, priest Levitate and shaman Water Walking on all five clients; warlock
  healthstones, summons and Soulstones on all five, with Soulwell on TBC,
  Mists and retail; Fire Shield only on Forever, Classic Era and TBC. The
  service registry, lazy event frames, item-usability gates and the exact-build
  `tools/audit_services.py` check hold these boundaries.

## Next

Run the focused scenarios, quick/anchor checks and review the complete
worktree. No release, push or commit is part of this migration.
