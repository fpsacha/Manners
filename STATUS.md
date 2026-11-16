# Where this stands

Working notes. Not part of the shipped addon — `.pkgmeta` leaves it out. How to
work on the project: `CLAUDE.md`. How to release: `RELEASING.md`.

## State

**1.11.25 is the last release** (tagged on 2026-11-14); what is on master
since is under *Unreleased* in the changelog. 1.11.25 was built that day in
parallel worktrees and merged to master: each piece was held to
lint, its own scenario file and `anchors_for.py --check-after`, and each new
mutation to `tools/prove.py`. One `tools/check.py --release` ran over an
earlier master that day; what it found red was cleared on the `integrate`
branch, each by its own scenario file (the list is the second item under
*Open*). No whole suite has run over the tree as it now stands, and nothing
was tried in the game. The checklist of what only the game can settle, now
on WoW Forever in the owner's own play sessions, is the first item under
*Open*.

**Two elixirs at once (branch `post26`, after 1.11.26, not released).**
Burning Crusade and Mists name each elixir's slot only in its spell's own
text ("... Battle Elixir."), so `tools/make_consumables.py` writes it as a
fourth value on each elixir row and `Buffs.lua` builds two families there:
`elixir` (Battle Elixir, the key kept) and `guardianelixir`, each with its
own switch, a flask filling both; on Mists a scroll now covers, and is held
back by, its own slot's elixirs and scrolls alone. Goldenmist Special Brew
(23444) names no slot and is left out (`NO_SLOT`). Classic Era and Forever
name no slot anywhere: one family, `keep`, with *Elixirs to keep up*
(`ownBuffs.elixirKeep`, Who to buff, under *Elixir*) reminding of each ticked
elixir in the bags in turn (Core.lua `ns.KeepTicks`, `ScanKept`,
`KeepAnswer`); a ticked one that comes on as another ticked one goes with
more than a minute left makes the pair one (`db.char.elixirClash`, said once),
and one the game turns away ("A more powerful spell is already active") is
passed over for its ten minutes (`ns.heldOff`). The one switch, a pick of a
guardian elixir and the memory of one up last carry over once a profile
(`ns.SplitElixirs`, stamp `ownBuffs.elixirsSplit`, which a settings string
carries). `tests/scenarios/elixir-pair.lua`, `tests/mutations/elixir-pair.py`
(16, each CAUGHT by `prove.py`). What only the game can say:
1. Classic Era and Forever: whether any two elixirs refuse or overwrite each
   other (two of one stat, Forever's 1250xxx with the classic ones, Season of
   Discovery's 12139xx); the data shows none, and which of the two the game
   does is unverified.
2. Burning Crusade: which slot Goldenmist Special Brew (23444) takes.
3. Burning Crusade: whether the Unstable Flasks of Blade's Edge (40567 to
   40576) fill both slots; their 2.5.6 text does not say so, Mists' does.
4. Whether drinking a second elixir of one slot overwrites the first or is
   refused (Burning Crusade, Mists).
5. Whether "A more powerful spell is already active" reaches the pending
   click for a `/use item:` on yourself as it does for a cast on others.

What was built:

- **The group's pets** (`sources.pets`, off; Queue.lua `IterateUnits`,
  `entry.pet` and `entry.owner`; `tests/scenarios/grouppets.lua`).
- **Battlegrounds and arenas** (`Battle.lua`, `db.battle`; When to offer, *In
  battlegrounds and arenas*, four switches; `battleground.lua`), and a
  gathering tracking quiet there (Core.lua `OwnVerdict`: `"battle"`,
  `ns.GATHERING`; `battle-tracking.lua`).
  `filters.quietInInstances` no longer decides inside one: `battle.team`
  does, and a profile that had the old switch ticked has `team` unticked once
  (`Battle.Carry`).
- **Resurrection** (`Resurrect.lua`; `sources.res` on, `sources.resStrangers`
  off; `res.lua`). Not built: memory of a dead passer-by once the cursor
  leaves; a flash on the panel for a resurrection.
- **Cures** (`Cures.lua`; `sources.cures`, `sources.curesStrangers`, both
  off; `filters.cureSeconds` 10; `cures.lua`). Deny list: Unstable
  Affliction, Vampiric Touch, Mutating Injection, Delusions of Jin'do.
  `canActivePlayerDispel` on the Classic clients is assumed from Blizzard's UI
  code. Not built: curing yourself or pets; Mass Dispel; pet dispels.
- **Courtesies on request** (`Courtesy.lua`; four `sources.courtesy*`, all
  off; `courtesy.lua`). Not built: Pick Lock (it needs a /click on the trade
  slot); "port pls" with no city; a trade press from the bar macro.
- **Asking for a buff** (`Ask.lua`; `sources.ask`, off; `db.ask`; `ask.lua`).
  The bar macro does not carry an ask; asks are forgotten at a `/reload`; on
  Forever and retail a group member is held only to "in sight".
- **Sharing a group between Manners users** (`Share.lua`; `sources.share`,
  on; `raidsplit.lua`). Not covered: LFG instance groups (INSTANCE_CHAT is
  not used); a non-casting user's own self-reminder for a raid-wide buff is
  not held back; a non-caster keeps offering singles to their share while
  the caster's group cast is due.
- **The companion pet on Mists and retail** (Companion.lua `journalOnly`,
  `"petbattle"`; `journalpet.lua`).
- **A line said once in town** (`Hints.lua`, `db.char.hints.resting`;
  `resting-hint.lua`).
- **Own lines among the In character ones** (`speech.mixedLines`, Speech.lua
  `MixedIn`; What I say).
- **The options window's footer** (WindowChrome.lua: the author's line
  larger and centred, the build at the right; the picker's tick clear of the
  picture). On Forever the author's name alone takes a click: left opens a
  whisper through the game's chat box, right looks them up with `/who`. No
  scenario presses it yet.
- **The options menu rebuilt** (`Options/Window/Layout.lua`, `WindowPage.lua`;
  `menu.lua`): who before what on Who to buff; each buff on a row of its own
  with its switches indented under it; a row under a switch that is off is
  not drawn (`UnderOff`), and search says which switch to turn on; columns
  when the window is dragged wide (two from 420 a column, three at most,
  `UI.ColumnsFor`); the simple view (`menuView`: `simple`, `full`, `offer`,
  stamped by `ClampSettings`; the layout's `simple` list; never in a string
  of settings; the mock's player has chosen *Show everything*, a scenario
  about a new profile sets `Mock.newMenu`); homes for the day's features
  (*More than buffs* for resurrection and cures, the group's own section for
  *Share the group*, the courtesies under *People who ask me in chat*).
  Look's colours (*Style*) are a fold, which keeps the page inside three
  screens under nineteen cards.
- **The reminder to set a key** (Options/Start.lua `Setup`, `ns.KeyNudge`,
  `ns.KEY_NUDGE_AFTER` 20 s; `keyReminder` on, `db.char.keyReminders`, three
  at most): *No key yet* on Start here's step 2, and one line in chat.
- **Milestones** (`Milestones.lua`, `db.char.milestones`,
  `db.profile.milestones`: `enabled`, `toast`, `sound`; `milestones.lua`):
  thirteen, three hidden; the ledger's fourth tab; a toast; three switches on
  Start here. Resurrect.lua, Clicks.lua (a settled cure) and Courtesy.lua
  tell it with `ns.Milestones.Note`.
- **The read-through review** (`*-review.lua`, eight scenario files with
  their mutation files): some thirty faults in resurrection, courtesies,
  cures, sharing the group, asking, battlegrounds, pets and the seams
  between them, fixed before any of it shipped.
- **Faster test tools**: `tools/prove.py`, `tools/check.py --release`,
  `tools/jobs.py`, `selftest.py --only/--changed` on the fast proof, and
  `RELEASE-CHECK.md` (`tools/README.md`).
- **Four new looks**, nineteen in all: Stormcaller, Warchief, Gearworks and
  Ebon, each with its generator, its `Textures/` folder, its scenario file
  (`look-<key>.lua`) and mutation file, its strings in eight languages and
  its picker card.
- **Four looks redrawn**: Minimal (a dressing, `Looks/MinimalDress.lua`,
  `Textures/Minimal/`; `prompt.minimalLine = false` takes it off but no
  switch sets it), Ribbon, Letter and Leather; then the serif names a fifth
  larger on those three, Letter's reason line in the standard face, and
  Ribbon's cloth kept through a landing.
- **The looks pass** below (one alpha, the words measured), from before the
  day's build.
- **Kings and a Fish Bowl, GitHub issue 17** (the daily feedback pass,
  2026-11-14). With `buff.spareFishBowl` on, GroupBuffs.lua `ClassSafe` asks
  `ns.SparesFishBowl` of everybody of the class the queue did not offer
  Kings, you included, and one wearer keeps the Greater Blessing of Kings
  back (the others keep their single Kings). *Never put Kings over Boosted
  Stats* (`buff.neverFishBowl`, off, indented under the first switch and
  greyed without it): `PickBuffFor` drops the Kings it kept for last and
  answers "covered", except for a request by name.
  `tests/scenarios/fishbowl.lua`, fifteen mutations seen CAUGHT by
  `tools/prove.py`; no whole suite ran. Only the game can say whether
  Boosted Stats reads on a group member out of a fight on Forever (one
  guarded read by spell id, as the single walk's). A debt to somebody held
  this way waits out its time as Still owed.
- **Friendly nameplates off, said where the player looks** (branch `par`,
  2026-11-15; the weakest point six reviewers found: with the game's
  friendly nameplates off, as a fresh install has them, a stranger's buff on
  Forever lands with no `sourceUnit`, nothing comes up and nothing is said,
  while the greeting promised strangers and the launcher said "Watching" in
  green). Now: a red line under the greeting (Commands.lua `ns.Welcome`);
  Start here's note and button while Quick setup asks too, for a pick that
  offers to passers-by (`Quick.FirstPassersBy`; the section titled *Seeing
  passers-by* then); the launcher's `plates` state, amber, and the options
  window's strip with *Show friendly nameplates* beside it, except on Start
  here and Who to buff, which carry their own (WindowChrome.lua
  `PLATES_BUTTON`); a class buff from nobody named goes on the trail and,
  with the nameplates plainly off and out of a fight, is said once a session
  on three sessions a character (Favours.lua `Unnamed`, Hints.lua
  `ns.UnnamedBuffHint`, `db.char.hints.unnamed`). `tests/scenarios/par.lua`
  (red before), nineteen mutations in `tests/mutations/par.py` seen CAUGHT;
  `plates-cta.lua` turned round (it held the old rule, hidden while asking)
  and its two mutations re-aimed. `tools/render_options.py` has `platesoff`
  and `firstrun` states. Only the game can say whether a stranger's buff on
  Forever really reads `sourceUnit` as a plain nil out of a fight (the line
  depends on it), and whether `SetCVar` from the strip's button is accepted
  as the page's own is.
- **The first hour, said plainly** (branch `par-clarity`, 2026-11-15; five
  of the reviewers' runners-up, `tests/scenarios/par-clarity.lua`, red
  before, 27 mutations in `tests/mutations/par-clarity.py` seen CAUGHT).
  Closed: (1) a player with no key had no way to learn why the prompt stayed
  empty, and (2) a place rule holding everybody back still read "Watching"
  in green: Queue.lua's `ns.PlaceHold` names the rule as BuildQueue reads it
  (a scenario walks 864 combinations of place and switch and holds the two together), and the
  launcher's `placeheld`, `mana` and `passersheld` states (Launcher.lua
  `PlaceHeldLine`, `SavingManaLine`) put it in the tooltip, the options
  window's strip (the first two), *Diagnostics*' new first line
  (`Page.HoldLines`, `diagnostics.holdDiag`), a press on the empty prompt and
  `/manners debug`; (3) a brand-new character's greeting waits for the first
  buff (`db.char.welcomeWaits`, one line naming it, the greeting from the
  probe after SPELLS_CHANGED: Commands.lua's wrap of `ns.ProbeCapabilities`);
  (4) Forever's, Mists' and retail's warrior is told the shout reaches the
  raid around them, and *Raid groups I buff* gets a note for a shout
  (`who.skipRaidGroupsNote`); (5) the dungeon switch reads *Offer nothing in
  dungeons and raids* while *Buff my team there* is ticked beside it
  (`Page.InstancesLabel`). Only the game can say whether SPELLS_CHANGED
  follows a trainer's lesson closely enough on Forever for the greeting to
  read as the reply to it (the probe is throttled to one in five seconds).
  Left alone: the preview's "Click it to put it away" line (Prompt, not this
  branch's), the key reminder on the first login, and the raid-groups-all-
  unticked hold, which `/manners debug` says and the strip does not.

- **The review's core job, first share** (branch `par-core1`, 2026-11-15).
  (1) A passer-by who walked off, kept by name for `LINGER_SECONDS` with
  `ranged` unset, held the prompt on the tie of the tier for up to ten
  seconds while somebody in reach, sorted ahead, waited: `Prompt/Hold.lua`
  `WorseOffer` now reads the queue's range key first (`Reach`), and the hold
  gives way on it too for the queue's own entry, never under the cursor
  (`CursorHolds`, 1.1.1). `linger.lua`'s right-click skip case now puts the
  cursor on the prompt before Bert arrives (it relied on the old rule).
  (2) Line of sight and range refusals are a run of their own (Queue.lua
  `WHERE`, `WHERE_STEPS` 5/15/30 s, `StoodAway`, `r.away`), with the range's
  ten-second floor, no step of the person's run and no chat line; an error
  line arriving just after a reasonless refusal takes that step back
  (`r.undo`, `NoteGameError`). (3) A list line under the cursor keeps the
  person it named (`Prompt/Rows.lua` `HoldRows`, from List.lua's
  `PaintQueue`), blank and shown, naming nobody, once they leave the list.
  `tests/scenarios/par-core1.lua` (red before), fifteen mutations in
  `tests/mutations/par-core1.py` seen CAUGHT; `hunt13-fix2.py` and
  `range-follow.py` each had one re-aimed. Only the game can say: that the
  client's line-of-sight and range errors match `SPELL_FAILED_LINE_OF_SIGHT`,
  `ERR_OUT_OF_RANGE` and `SPELL_FAILED_OUT_OF_RANGE` as Forever words them,
  and in which order they come against UNIT_SPELLCAST_FAILED; and that a
  secure row shown and kept under a still cursor keeps its OnEnter (the
  blank line relies on the cursor not falling off it).


Before that, still unreleased after 1.11.24: a pass over the fifteen looks
there were then (branch
`looks-polish`), in three parts.

- **One alpha.** The game keeps one alpha for a texture, and a colour given
  with an alpha (documented as 1 when left out) writes over what `SetAlpha`
  set. Nine looks coloured lights they had parked or dimmed (Archmage,
  Lightbringer, Fel, Forge, Leather, Letter, Ribbon, Toast, Arcane), and
  Panel.lua the bezel's hover twin on glass, framed and minimal. Every look
  now colours through `ns.Looks.Colour` (`Looks/Looks.lua`, ONE ALPHA: the
  resting alpha kept in a field, never read back mid-flash), a fight's dim is
  `Looks.Dim` over a light's own alpha (Toast's clock, Arcane's runes, well
  and drain, Luxe's shadow: the last call used to win), and the lights whose
  colour carried their strength flash to it (Toast's hover, warm ring,
  arrival and glints, Letter's seal light, Ribbon's shine, Arcane's wash).
  `tests/scenarios/looks-alpha.lua` runs every look three times (the mock,
  the game's one alpha, an alpha left out read as 1) and compares every
  texture at every checkpoint.
- **The words measured.** `tools/audit_look_contrast.py` (4.5:1 for the name,
  the reason line, the tags and the list's rows, on the pictures, three
  sizes). Coloured words are held to the body-text line, 5 against the flat
  panel colour (`CODE_CONTRAST`, was 3: the shaman's blue and the death
  knight's red on a name); the list's grey after a name is `8c8e9c`;
  Ribbon, Leather and Forge state the ground they draw (`kit.ink`); Fel's
  reason line and verdict are held to 7 and its smoke is thinner; Ribbon's
  key letter is on the tags' frame and near black in a fight, its shine 0.5;
  Letter's inks are held to 5 (a byte's rounding took 4.5 under); on Fel,
  Lightbringer, Wild and Frost a tag gives way before the name is drawn
  smaller (`NameFits` at the size set). `tests/scenarios/looks-read.lua`.
- **Looked at.** Film strips of every look with a long name, a key bound and
  a count, and a check that no tag's text overlaps a line at five sizes:
  nothing overlapping, cut off or left lit was found in the pictures.

Only the live game can say: whether an alpha left out of `SetVertexColor`
is read as 1 or left alone (the helper is right either way); how bright the
flashes that now go to their own strength are in ADD (Toast's arrival at
0.55, its glints at 0.8, Ribbon's shine at 0.5: the renderer understates
ADD); how the lifted class colours look beside the game's own on a name; how
the reason line reads at 10 pt in the game's face on Forge's iron, which
passes at 4.6 and is the nearest to the floor with Glass's and Arcane's
colour-blind "asked"; and whether Letter's seal, whose light at the top of
its pulse covers the icon in the renderer, does so in the game.

Unreleased after 1.11.23, asked for on CurseForge: *Weapon imbues before the
shield* (`ownBuffs.imbueFirst`, off; Who to buff, Weapons; Core.lua
`KnownOwnFamilies` puts a shaman's imbue families ahead of the rest;
`tests/scenarios/imbuefirst.lua`).

1.11.17 is released. Unreleased after it, both asked for on CurseForge:

- A favour is not returned with a buff its giver already wears
  (`filters.repayCovered`, off: *Refresh a buff they already have, to return a
  favour*, When to offer, Buffing back). Queue.lua writes `opts.spareCovered`
  for somebody owed and read, Core.lua's `Fresh` then spares what they wear
  with more than the top-up lead left whoever cast it (a rank above yours
  included), and `PickBuffFor` hands back a third value, true, when that is
  all there is (`Covered`: every castable buff read on them, none on its
  cooldown). The walk marks the debt (`covered`) and `LetGoCovered` lets it go
  once the walk is over: ledger `why = "covered"` (*Let go: they already have
  your buff*, counted with the favours nothing could return, not against
  you), the debts saved, and a line only after a "buffed you" line that
  promised the prompt (`said` on the debt). Favours.lua `CoveredAlready` asks
  the same as the favour arrives, of the token that names them, so the common
  case is one line and no debt. Not on a reading withheld or "kept" from a
  fight, not under Always offer, and a buff about to run out still returns the
  favour. With the switch on everything is as it was (`paidUp`, own casts
  only). `tests/scenarios/covered.lua`. Left as they were: a favour whose
  giver is covered only by *Leave alone anybody another paladin has blessed*,
  by a blessing of yours that is switched off or unpaid for, or by a scroll
  that blocks your buff (no timer read) still waits out its time as Still
  owed; and the whispered thank-you (`prompt.thankWhisper`) goes when the
  favour is let go as it arrives, not when a later scan lets it go.
- Thorns' *Tanks only* holds everybody outside the group too (Core.lua
  `Castable`: `opts.tanksOnly` with no `opts.tanksOutside`), a favour's giver
  included, by a token, by the tokenless fallback and from the passer-by
  memory (`StillCastable`); a request by name is still answered. What it did
  before is the fourth choice, *Tanks, and anyone outside my group*
  (`buff.tanksOutside` beside `buff.tanksOnly`, so a saved Tanks only is the
  strict one). `tests/scenarios/tankonly.lua`. A druid whose only buff
  switched on is Thorns, under Tanks only, keeps a passer-by's favour as
  Still owed until its time runs out, as a favour from a member who is no
  tank always did.

**Four looks retired in 1.11.19, back in 1.11.20.** Framed, Luxe, Toast and
Arcane were taken out in 1.11.19 (their players moved to Glass, Archmage and
Ribbon) at the author's word that the looks should all be unique, and
players asked for them straight back (GitHub issue 15, CurseForge): 1.11.20
restored them whole, files, art, generators, tests, the panel's rim and the
strings, from the commits that removed them, and removed `Looks.retired`,
`Looks.Heir` and the move of a saved style to an heir. A profile that 1.11.19
moved to Glass stays on Glass; the player picks the old look again. There
were fifteen looks with Wild (a druid's) and Frost (a frost mage's) added in
1.11.22, and there are nineteen since 1.11.25. **Only the game can say:** whether the four read as they did.

**The right-buff audit (Unreleased).** A player called the addon "a buggy
mess": "very frequently it retargets the same person when they are buffed and
does not notice party members that are unbuffed". Fifteen findings, each a
scenario in `tests/scenarios/audit-right-buff.lua` and a mutation in
`tests/mutations/audit-right-buff.py`:

- *The order inside a tier* (Queue.lua `OfferRank`, the sort at the end of
  `BuildQueue`; Prompt/Hold.lua `PickTop`): after the tier and the range,
  somebody read as missing the buff, then somebody unread, then a top-up or
  refresh; then the buff's place in the walk (`walkPlace`, written per scan
  from the castable list; none for a class whose buffs replace one another),
  then group cast, friends and name as before. PickTop keeps the current
  person on a tie of the tier only while they are no worse by that order. A
  top-up of your own buff has the group's priority (`SelfEntry`); missing, it
  keeps `PRIORITY.self`. The fight's rota takes the queue as built, so it
  steps in this order too.
- *Shadow Protection* is `optIn` on Classic Era, Forever and Burning Crusade,
  as Detect Invisibility is. A profile that never touched it now has it off;
  the changelog says to tick it.
- *Unending Breath* is `returnOnly` (new flag, Buffs.lua) on the same three:
  `Castable` offers it only for `opts.owed` (the walk, the tokenless fallback,
  Favours.lua's two questions) or a request by name. **Open:** the summaries
  on Who to buff and the Welcome still speak of passers-by for a warlock whose
  only buff it is (they ask `ns.OnlyReachesGroup`, which is about reach); the
  switch's own description says the rule.
- *Might and casters*: `buff.skipCasters` is on by default.
- *"Buff pls"*: `ns.AskedFor` hands back whether the request named a buff, and
  `opts.asked` is now "asked for by name": a plain "buff pls" keeps *Only
  buffs they can use*, *Don't offer Might to...*, *Tanks only* and *Only me*.
- *Too low a level* (`levelGated` on the vanilla set, read by Forever's and
  Burning Crusade's; `buff.lowLevel` from the lookups; `opts.targetLevel`):
  `Castable` turns down a buff none of whose ranks lands within ten levels.
  The walk reads `UnitLevel` only while a castable buff has a `lowLevel`, or
  for somebody owed.
- *A favour by name keeps its rank*: the giver's level goes on the debt
  (Favours.lua `seen.level`, the walk, saved with the debts) and on the
  tokenless entry (`entry.level`), and `ns.CastName` names the rank by it. A
  remembered passer-by (the ten-second memory) still casts the plain name.
- *The ten-minute hold* ("A more powerful spell is already active", "Target
  is too low level") is told to the walk through `ns.heldOff` (Core.lua,
  read by `Castable`) beside the block in `ns.tried`, so a paladin's walk
  moves on to the next blessing. For a refused group cast the hold is on the
  group version for the one it was aimed at (`ns.GROUP_HOLD`;
  GroupBuffs.lua `Aimable`), and nobody's single buff: this reverses 1.11.14's
  "a group cast holds the buff off everyone it covered".
- *Forever's camping buffs*: Boosted Stamina 1230124, Boosted Intellect
  1229513 and Boosted Spirit 1229718 are `blockers` of Fortitude, Intellect
  and Divine Spirit (`CAMP_BLOCKER`), weighed by `ns.CampWorth`: the aura's
  `points[1]` where the client gives it, else the tier for the wearer's level
  (`ns.STAT_TIERS`, from each feature's own text), else nothing.
  `tools/audit_ids.py` holds the top to SpellEffect and the tiers to the text.
- *Group casts*: the group ranks' levels are in `ns.RANK_LEVEL` (held to
  SpellLevels by the audit). A member more than ten levels under the group
  rank is not counted and never the target (GroupBuffs.lua `TooLow`; never
  you). On Forever (`ns.GROUP_IS_RAID`) a member out of the single buff's
  range, read as missing it or running low, is kept for the fold alone
  (`foldOnly`, Queue.lua `visit`; `ns.GroupReady`), counted and covered, never
  the target, and taken out again if no group cast forms. A group version
  worn is weighed as the rank it is (Core.lua `UnitHasBuff`), for a buff with
  more than one rank, and never below the group version you cast yourself.
- *A warrior's shout*: `ns.shoutUnreached`, written by `BuildQueue` around
  its `SelfEntry`, makes `CastsOnSelf` allow the shout in a group whose walk
  queued it for nobody.
- The mock's other units are level 60 now (`tests/mockapi.lua`, `UnitLevel`);
  the player stays 12.

Left for the author to decide: **Thorns' default is still Everyone**, so a
druid is offered it for cloth casters and for herself every ten minutes; the
audit left it, since Thorns does something for anybody who gets hit, and
*Offer Thorns to* already narrows it. (Three refusals in a row for line of
sight or range no longer take a party member off for five minutes: they are
a run of their own since `par-core1`, half a minute at most.)

Only the live game can say, about the audit:

1. Whether Forever refuses a Fortitude, Intellect or Divine Spirit worth no
   more than the camping buff somebody wears, as it does over a scroll (the
   data says the same aura; "mutually exclusive" is the feature's own text),
   and whether equal counts as refused. What the aura's `points` read on a
   wearer below 60 (`/manners look target`): if the client gives them, the
   tiers are never used.
2. The four camping buffs not weighed: the Enchanted Lute's Boosted Stats
   against Mark of the Wild, the Lodestone's Boosted Attack Power against
   Blessing of Might, the Mana Well's Boosted Mana Regeneration against
   Blessing of Wisdom, and the Fish Bowl against Kings. Whether the weaker of
   the two is refused or replaces is not in the data; today yours is offered
   and, if refused, held off for ten minutes.
3. What Forever's untargeted group casts (Arcane Brilliance, the Prayers, Gift
   of the Wild) give a member more than ten levels under the rank. Manners no
   longer counts such a member and offers them the single buff; if the game
   does give them the group version, that single offer goes when it lands.
4. Whether such a cast goes out with a friendly target more than forty yards
   off: the fold still wants somebody within the single buff's reach to aim
   at, though the spell needs no target.
5. Whether `C_Spell.GetSpellSubtext` answers at once for a rank below your
   top one; an empty first answer casts the plain name until the next scan.

Only the live game can say: that the buffs of somebody who has just buffed you
read at that moment on WoW Forever (the token is the one the aura named as its
caster; a reading the client withholds leaves them owed, as before), and how
often a passer-by who buffs you holds a token at all on the next scans (with
none, the favour is offered unverified for *Let them go after*, as before).

In 1.11.17, all three asked for on CurseForge:

- *Below it, still offer* under *Save mana* (`filters.manaFloorKeeps`:
  `asked`, the default and the old behaviour, `self` or `none`; Queue.lua
  `ns.ManaFloorKeeps` and `ns.ManaFloorKept`, which every line about the
  floor asks). BuildQueue's `manaHoldsAsked` turns favours and requests away
  as a verdict in the walk, skips the tokenless owed fallback and lets go of
  remembered askers (OfferPassersBy's `dropAsked`); SelfEntry offers nothing
  with `none`, read off the scan's `sweep.saving`. Debts are never cleared by
  it. The consumables button is not held back (items cost no mana).
  `tests/scenarios/manakeeps.lua`.
- A buff back is not a favour owed (Favours.lua `BuffedBack`, in
  `OweFavour` before the debt is written): the giver wears a buff the client
  names you as the caster of with more than the top-up lead left, or Manners
  noted a gift to them (`ns.NoteGave`'s third argument, `not wasOwed`, kept in
  `giftAt`; `ns.GaveLately`) whose time less the lead has not run out. A cast
  that returned their favour is no gift, so their next buff is a new favour
  (hunt3-ledger's refusal fixture relies on it). The ledger files it as state
  `back`, *Buffed back*, counted in neither the received nor the owed totals;
  the /thank and a whisper still go (nothing is owed, so the whisper's rule
  lets it). `tests/scenarios/buffback.lua`.
- A right-click on your own buff skips that buff (`ns.MarkAttempted` with the
  skip time), ctrl-right-click all of yours (`ns.BlockPerson`), shift is still
  StopOfferingSelf (Prompt/Press.lua `ShownBuffKey`: a row's own buff, under
  an outcome the buff the outcome is about, `S.outcomeBuff` written by
  `Prompt:ShowOutcome` from Clicks.lua's records, else the painted entry's).
  The launcher's *Skip for now* on your own buff skips that one too.
  `tests/scenarios/ownskip.lua`.

Only the live game can say: that ctrl-right-click reaches the prompt's
PostClick with `IsControlKeyDown()` true and casts nothing (the `*type2`
wildcard covers it, as it does shift); and on WoW Forever a buff you cast by
hand, outside the prompt, still cannot be told for yours on somebody else (no
caster named, no note), so its giver is owed as before.

In 1.11.16, asked for on CurseForge: the prompt
moved in the game's Edit Mode (`prompt.moveInEditMode`, on; Prompt/Button.lua,
"Edit Mode": `EventRegistry`'s "EditMode.Enter" unlocks a locked prompt and
"EditMode.Exit" locks one it unlocked, a drag meanwhile saves the place and
leaves it unlocked, and `db.char.editUnlocked` locks it at the next login after
a `/reload` inside Edit Mode; `tests/scenarios/editmode.lua`). The two callback
names are read from Blizzard's EditModeManager.lua on all five branches. Only
the live game can say: that the callbacks reach an addon on each client, that
the unlocked prompt can be dragged over Edit Mode's own overlay, and that a
callback registered by an addon leaves Edit Mode's saving untainted.

Also in 1.11.16, asked for by the author: a companion pet kept out (`pet`
family, off by default; `Pets.lua` from `tools/make_pets.py`, `Companion.lua`,
`tests/scenarios/pets.lua`). Forever's pet journal is summoned with no press
from the scan (`C_PetJournal.SummonPetByGUID` or `SummonRandomPet`, by *Which
pet*, `ownBuffs.petChoice`); a pet used from the bags (every pet on Classic Era
and TBC, 17 on Forever) is a press on the prompt, out or not by Manners' own
count. Only the live game can say: that `SummonPetByGUID` from addon code with
no key press works on Forever (a Forever addon does it from a timer; if not,
three empty summons or ADDON_ACTION_FORBIDDEN leave it to the player for the
session, but the game may show its "blocked" popup once); what takes a bag pet
away on Classic Era and TBC (death, a loading screen and a flight are assumed,
mounting is not); and whether a bag pet's item used while one is out puts it
away (assumed, as a toggle). Mists and retail are left out until the first of
these is known there.

Also in 1.11.16, both asked for on CurseForge: *Wait a moment before thanking*
(`prompt.thankDelay`, off; Favours.lua `ThankFavour`: the /thank and the
whisper go out after a random one to three seconds on `C_Timer.After`, every
rule asked again then by `Blocked`, one thank waiting at a time, a skip
written to `ns.thankLog.skipped`; `tests/scenarios/thankdelay.lua`), and
*Where* under *Offer nothing in cities and inns* (`filters.quietInTownsWhere`:
both, cities, inns; Queue.lua `inTown`, Range.lua `ns.InCity`: the player's map
and its parents against each client's capital uiMap ids, read from wago.tools'
UiMap at the builds in `CLAUDE.md`; `tests/scenarios/townhold.lua`). Only the
live game can say: that `C_Map.GetBestMapForUnit("player")` answers in a city
on every client (Forever's UiMap has only 60 rows; nil there holds back both,
as before), that resting at an inn inside a capital reads as the city, and
that the emote and whisper from a timer, with no key press, go out as the
immediate ones do.

Unreleased after 1.11.16, asked for on CurseForge: a warlock's Firestone and
Spellstone on Forever (`warlockstone`, an Imbue kind in Buffs.lua's
CAMELOT_ROWS, main hand only; held in the off hand on Classic Era and TBC, so
not there; `tests/scenarios/warlockstones.lua`), and Detect Invisibility for
the group (`detectgroup`, `membersOnly` and `optIn`, new flags in Buffs.lua;
`db.buff.optIn`; `tests/scenarios/detectgroup.lua`). Only the live game can
say that `/use` of a Forever stone with the main hand named lands on it the way
an oil does.

In 1.11.15, all asked for on CurseForge: classes left out as
passers-by (`filters.skipNearbyClasses`, a sparse set of class tokens;
`SkippedClasses` in Queue.lua, a verdict in the walk and a let-go in
`OfferPassersBy`), *Remind me this many minutes early* made exact
(`SelfEarlier` returns the asked moment, later as well as earlier, the same in a
dungeon, in half minutes), food offered again at once after a meal cut short
(`mealOn` in `OwnVerdict` lets the press's block go), and a whispered thank-you
to whoever you will not buff back (`prompt.thankWhisper`, `ns.ThankWhisper` in
Speech.lua: an In character thanks line sent with `SendChatMessage`, under the
/thank's rules; a whisper needs no key press, which /say does outside an
instance). Whether Forever and the Classic clients accept that whisper from
addon code with no key press is open until somebody turns it on there. Also:
a lone warrior's shout kept in a fight (`FightShouts`, `SelfEntry`'s `fight`;
GitHub issue 13: "Myself" held everything back in a fight, so the prompt
emptied on the pull), Kings kept last over Forever's Fish Bowl
(`buff.spareFishBowl`, `SparesFishBowl` in Core.lua reading Boosted Stats,
spell 1230098, which Spell 1307245 calls mutually exclusive with Kings; GitHub
issue 12), and 24 thank emotes (`ns.THANK_EMOTES`, each checked against every
client's ChatEmoteConstants.lua; CurseForge). And the consumables button
(`ownBuffs.apart`, `db.supplies`, Prompt/Supplies.lua: a second secure button,
MannersSupplies, with its own binding; `ns.SupplyEntry` and `ns.ItemFamily` in
Queue.lua keep the item families off the prompt; `ns.ItemMacro` in Macro.lua
arms it with the prompt's own macro for the item; a state driver's snippet
disarms and hides it at every pull; CurseForge). Not tried in the live game
yet: the button's drag and its key binding on each client.

1.11.14 added: a lower rank named in the macro for a low-level
target (`ns.CastName`, GitHub issue 9; the rank text is the client's own
`GetSpellSubtext`, so a client without it keeps the plain name), a buff left
off a person for ten minutes after "A more powerful spell is already active" or
"Target is too low level" (`NoteRefusal`'s `buffKey`), *Hold back my target and
focus too* (`filters.quietTargets`, issue 8), *A right-click skips for*
(`timing.skipSeconds`), a mage's scrolls held to dungeons and raids, lines typed
into the phrase box kept when the box is left (`MultiLeft`), Might left off a mage, warlock
or priest (`buff.skipCasters`, `meleeOnly`, `ns.CASTER_CLASSES`; CurseForge), a
food that can be ticked under *Never remind me about* (`OwnLeaveable`, GitHub
issue 11), guilds left out
(`filters.skipGuilds`, `SkippedGuilds` and `GuildOf` in Queue.lua; asked for on
CurseForge) with a guild line under the name (`prompt.showGuild`, `entry.guild`,
`ReasonText`), and *Remind me of my
shout when I'm alone* (`ownBuffs.shoutAlone`, `CastsOnSelf`; a warrior alone is
offered his own Battle Shout through the self entry, whose macro targets himself
and casts it, which has never run in the live game). Whether
Forever's client takes `/cast Name(Rank N)` and answers `GetSpellSubtext` is
open until somebody casts one there.

1.11.14 is released, for all five live clients: WoW Forever, Classic Era, Burning
Crusade Classic Anniversary, Mists of Pandaria Classic and retail (a toc per
client from `tools/maketocs.py`, a buff set per client in `Buffs.lua`, each
checked against that client's DB2 on wago.tools, and a scenario file and
mutations per client). Every buff on every client has In character lines of
its own, and every people has lines (the Haranir since 1.7.2, speaking since
1.7.3).

What 1.11.1 to 1.11.9 added, in `CHANGELOG.md` for players: per-spell self-buff
exceptions, a Well Fed reminder, a shaman's weapon imbues, the emote chosen for
`/thank`, the bar macro's spoken line, no Manners menus with a gamepad on,
Thorns held to tanks or to you alone, oils, stones and food only in dungeons and
raids, nothing offered in cities and inns, a switch to say nothing in chat,
weapon items renewed only once gone while alone, a switch for Unending
Breath, the full check-up for bug reports (1.11.9) and a Well-Rested reminder
for the Cozy Sleeping Bag (1.11.10). 1.11.13 adds the friendly nameplates
note, Soul Link read right on Forever and Classic Era, Find Treasure beside a
gathering tracking on Forever, the Scrolls switch, Unending Breath while you
swim, Hide the prompt in combat, the options window's own drop-down list with a
gamepad on or no client menu, the follow prompt as a second opinion on range
where the spell's check is silent, and ten seconds off the prompt after the
game answers Out of range. Whether the follow prompt answers for a stranger on
Forever is open (nil there leaves them offered). 1.11.11 and 1.11.12: nothing offered inside an
instance, paladins skipping players another paladin has blessed, a warlock's
own Detect Invisibility, funnier Forsaken thanks, bug hunt 35's
fixes (Well-Rested above all), and the buffs its finder listed (round 36: more
own buffs, flasks, elixirs and scrolls, and Earth Shield, Beacon of Light and the
other one-target buffs for the tank), and bug hunt 37's 47 fixes with the
buffs still missing (Demonic Sacrifice, Tree of Life, Spirit of the Alpha,
Beacon of Faith, Symbiotic Relationship, retail flasks). Forever's build 1.60.1.70790 deleted Blessing of Salvation and Light
(1.11.4); the audit reads Forever at that build (`CLAUDE.md`, "Data sources").

Working here is quicker and safer for an agent since round 33 (`CLAUDE.md`,
"Dev tools"). `tools/lint.py` says in under a second whether every Lua and
Python file compiles and the generated tocs are current (`check.py --lint` runs
it first and stops there on a problem). `tools/anchors_for.py` lists the
mutations on a line before it is edited and, after, the anchors that are gone.
`tools/clients_watch.py` compares each client's interface number and build with
Blizzard's UI source and lists the PTR numbers. A `.claude/` folder holds a
permissions list, a hook that lints each edited file, and the commands
`/check`, `/release`, `/bughunt`, `/translate` and `/phrases`.

## Open

**The other clients' lists, 2026-11-15.** `tests/baselines/*.txt` took in the
reds of today's new scenario files off Forever (par-core1, par-core2,
par-clarity, refused, speech-range's hand-back): read as Forever fixtures
(two-part names, a mage's Arcane Intellect), not read line by line. Worth a
pass: give those files the `hasBuffs` skip, and see that the refusal hold
(`RefusedAgain`) is exercised on Classic Era with a fixture of its own.

**In the game: the checklist** (rewritten 2026-11-15 from the 74 open boxes
of 1.11.25's list, `RELEASE-CHECK.md` and the "only the live game can say"
notes below; WoW Forever has been playable since 5 November). One list, in
the order to do it in your own play sessions on Forever, the things that
would cost a player's trust first. Each step says what to do and what to look
for. Paste what does not match, and the report of step 1 every time.

*Refusals (the owner's report on Forever 1.60.1.70938, branch `refused`)*

*The first hour, said plainly*
- [ ] A new character with its buff still at the trainer: the first login
      says Manners starts once you learn it; at the trainer, the greeting
      and its preview come within a few seconds of the lesson.
- [ ] *Offer nothing in cities and inns* on, in Stormwind: the minimap
      tooltip and the options window's strip name the switch in amber, and
      *Diagnostics* opens with the same line.


- [ ] Arcane Intellect refused with "A more powerful spell is already active":
      the full check-up's trail shows, after the `refused` line, an `event`
      line `UI_ERROR_MESSAGE +0.0Xs type N (number, message string), id
      SPELL_FAILED_AURA_BOUNCED` and a `refused` line "the game's reason came
      after the refusal". Which of `UNIT_SPELLCAST_FAILED` and
      `UI_ERROR_MESSAGE` comes first is read from the order of those `event`
      lines; the code now handles either. Paste them if the reason is still
      "no reason given".
- [ ] One press refused that way leaves the person off the prompt for that
      buff (ten minutes); *Offer held-back buffs again* (Who to buff, under
      *Never offer*) brings it back; `/manners debug` lists
      "intellect held off for ...".
- [ ] What the person wore: the buff's name and icon on them (their buff
      bar, or `/dump C_UnitAuras.GetAuraDataByIndex("target", i)` for each
      `i`), and its spell id. The data of 70938 has no new aura that gives
      Intellect but a self-only elixir (Elixir of Endless Intellect, 1327736);
      Manners now knows three more "Arcane Intellect" auras (364161 +7, 13326
      +10, 16876 +31) and the Incense Candle's Boosted Intellect (1229513), by
      the wearer's level unless the aura gives its points. If it was the
      candle, its points as the client gives them (`points` in that dump) say
      whether its worth goes by the camper's level, not the wearer's.

*First, the report that checks itself*

1. **The launch report, before playing and after.** Log in, out of combat,
   `/manners selftest launch`. Look for: `0 failed` on both chat lines and
   in the box. It now also lists *actions the game refused* (every
   ADDON_ACTION_BLOCKED or FORBIDDEN naming Manners since login, so it
   answers for steps 3 to 6 below once you have done them) and *where you
   are* (the map Manners reads, and whether it calls it a capital), and *a
   debuff's timer* (whether a harmful aura's `expirationTime` is given). Run
   it again at the end of the session and paste both.

*What would put "blocked" or an error on a player's screen*

2. **A real favour, start to end.** Have somebody buff you (an alt in a
   group will do). Look for: the prompt names them; one press buffs them
   back and your target comes back; the ledger (`/manners ledger`) has the
   line; the spoken line, if on, is said once; with *Thank* on, the `/thank`
   emote goes out (`C_ChatInfo.PerformEmote` from addon code has never run).
3. **Edit Mode.** Open the game's Edit Mode, drag the prompt over its
   overlay, close it, then `/reload` and open and close it once more. Look
   for: the prompt unlocks and locks with it, keeps its new place, and no
   "blocked" popup or Lua error, then or at the next Edit Mode save. Step 1's
   *actions the game refused* says the same.
4. **The companion pet from the journal.** *Keep a companion pet out* on,
   *Which pet* on a favourite. Look for: a pet comes out with no press within
   a few seconds, comes back once after a flight or a death, and no
   "blocked" popup (step 1 says the same).
5. **A fight.** With a person on the prompt, pull a mob. Look for: no
   "action blocked" message, no error; the key casts at the people the fight
   began with, one after another (the fight's rota); with *Hide the prompt
   in combat* on it hides and comes back after; the action bar's Manners
   macro still casts out of combat.
6. **A refused cast.** Press the prompt at somebody out of range or behind
   a wall. Look for: the game's own error, the person still owed (not marked
   repaid), and in `/manners clicks` on, a `CAST SENT` and a `CAST FAILED`
   carrying the same cast id. If the ids are missing, a late refusal goes
   unnoticed.
7. **A warrior's Battle Shout.** On a warrior, repay a favour with the shout
   (it is cast with no `/target`). Look for: the favour settled and the
   ledger line; only Mage has ever cast in the live client.
8. **Resurrection.** A healer in a party, somebody dies and does not
   release. Look for: they are first on the prompt; the press casts and
   hands your target back; they leave the prompt during the cast, are back
   about two seconds after you move mid-cast, and are dropped when another
   healer casts first. A member who released, and a hunter in Feign Death,
   are never offered.
9. **A courtesy on Forever.** A mage asked for water by a party member.
   Look for: `/target` then `/trade` from the press opens the trade with the
   water in slot 1 and no "action blocked"; a low asker gets the lower rank
   conjured. A warlock: Ritual of Summoning ends the request when the
   channel starts, and asks for a shard; a portal only for a group member
   who names the city, and nothing with no rune.
10. **Asking for a buff.** A rogue, *Ask for buffs I lack* ticked, beside a
    priest outside town with no Fortitude. Look for: the ask comes last; the
    press whispers "Name Surname" and leaves your target untouched;
    `/manners debug` has an "asking for buffs:" line; `/say` as the channel,
    and an In character line with that set chosen.
11. **A cure.** A druid or a priest, *Cure my party and raid* ticked, a party
    member poisoned out of combat. Look for: the cure offered, the press
    removes it, `/manners debug` has a "cures:" line; a debuff with under ten
    seconds left, and one with no timer, are left alone.
12. **Sharing a group.** Two characters of one class grouped, both with
    Manners. Look for: a full check-up on each shows "Sharing the group"
    users=1 and each prompt offers only its own part; if it says "refused
    ... (a sender written ...)", send that line; when one leaves or goes
    offline the other is offered everybody at the next scan.

*Where you are*

13. **Battlegrounds.** Before the gates open, `/manners debug` says "the
    gates are shut". Look for: what is on the prompt as the gates open;
    after a graveyard's resurrection "You" first, armour before food; in a
    fight the key casts nothing at anybody new, out of combat the team again;
    with *Thank people there* a `/thank` to a team-mate who buffs you and none
    in a fight; *Say my line there* off says nothing; no Find Minerals or Find
    Herbs reminder after a death there.
14. **Switching profile by place.** *Switch profile automatically* on, one
    profile for *In a raid*, one for *In a dungeon*, one for *In
    battlegrounds*, one for *In the open world*. Look for: a moment after the
    loading screen, one line in chat ("profile X (in a raid)"), the prompt in
    that profile's look and place, the page's first line "Chosen
    automatically", and back on the way out; no toast, key reminder or
    greeting with it. Zoning in during a fight waits for its end; a profile
    picked by hand inside holds through a `/reload` and the instance's own
    zone changes until the next door; typing in a box of the options window
    as the loading screen ends waits until the box is left and keeps the
    text; *Say so in chat* off, or *Hide all Manners messages* on the profile
    arrived at, says nothing.
15. **Towns and inns.** Log in at an inn with one of your own buffs
    missing. Look for: one line in chat about twelve seconds in, never again
    on that character; step 1's *where you are* reads a capital in one and
    "resting, not a capital" at an inn outside one.

*Your settings and your profiles*

16. **Profiles.** *New profile* (a name, Enter) makes one at the defaults
    and the first line names it; *Duplicate* copies (change a setting first
    and see it carried); *Rename* keeps the settings and the old name is
    gone; *Delete* never lists the one in use and asks first, as *Copy from*
    and *Reset* do; Undo puts each back. A second character on the renamed
    profile logs in on it under the new name.
17. **The group's pets.** In a party with a hunter or a warlock, *My group's
    pets too* ticked. Look for: the pet with its owner named on the second
    line; the press reaches it by name and hands your target back; two pets
    with the family's default name ("Cat") are told apart.
18. **Own lines.** With lines in *My own lines, mixed in*, about one press
    in three says one of them, and the bar macro carries it too.
19. **Milestones.** A character with a long ledger, its first login on
    1.11.25: one line saying how many it had already earned, no toast.
    Return a first favour on a new character: the toast (*Much Obliged*) a
    few seconds after the cast, drawn like the game's own, clear of the
    prompt (also with the prompt dragged to the top centre), gone at a
    click, with its sound and none with *Play the sound* off; earned in a
    fight it waits for the end, two together one a minute. A resurrection,
    a cure and a courtesy each earn theirs once landed, a refused one
    nothing. `/reload` within three seconds of buffing a stranger: the
    Milestones tab's count of strangers is one more, as the ledger's is.
    The tab: thirteen rows, three *Hidden* until earned, each with how far
    along; *Link in chat* fills the chat box and sends nothing. *Milestones*
    off: no tab, toast or line, the two switches under it greyed; on again,
    what passed meanwhile is marked with no toast.
20. **The hall of fame.** *Start here*, *Gentlefolk of Good Manners*: "N of
    M milestones earned" with this character's M, nobody listed yet, the
    fold gone with *Milestones* off. With every milestone (or `/run` them
    earned on a test character): the code box, a click selects it all,
    Ctrl+C copies it, and `python tools/hall.py check <code>` reads both
    words of the name with accents, the class, client and day; *Show my
    certificate* opens the ledger on *Milestones* with it beside (on the
    left at the right edge of the screen), and a screenshot of it is legible
    at the usual UI scale, the code's lines put together are the code in
    the box, and nothing is cut with an ellipsis.
21. **A warlock's Detect Invisibility.** Ticked, *Offer Detect Invisibility
    to passers-by too* shows under it; ticked, a passer-by without it comes
    up and the press lands.

*The options window*

22. **Every page.** Open each tab: no empty page, no control on another,
    search finds "emote"; change one setting, `/reload`, it stuck. Who to
    buff: who first, then what, each buff on its own row with its switches a
    step in; a priest finds Divine Spirit's tick at once. A row under a
    switch that is off is gone and comes back with it, and search for it
    says which switch to turn on first and opens it. Start here with
    *Milestones* on: no grey line about the defaults between *Favour ledger*
    and *Gentlefolk*.
23. **Its shapes.** Drag the grip wide: two columns, then three, nothing
    cut, no row over another, the usual size back at a right-click on the
    grip. *Simple view*: the short list of each page, how many settings it
    leaves out, *Show everything*; a search landing on one left out opens
    the full view; a new character starts in it; an old profile is offered
    it once (*Try the simple view*, *Not now*) and never again.
24. **Its small parts.** The footer: the author's line larger and centred,
    the version at the right, nothing cut at the smallest size; on Forever
    the pointer over the author's name shows *Click to whisper.* and
    *Right-click to look them up.*, a click opens a whisper to "Name Surname"
    and sends nothing, a right click runs the `/who`. A greyed switch (the
    chat lines' with *Hide all Manners messages* on) and, in a fight, *Move
    the prompt* in the header: the tooltip opens under the mouse (and say
    whether the greyed button lights its highlight). Start here, step 2: *No
    key yet* in gold with no key, the key once set. The reminder: a character
    with no key gets one line about twenty seconds into its second login,
    none in a fight until it ends, none after three logins, with a key, with
    the Manners macro made or with the reminder switch off; `/manners debug`
    says why it keeps quiet.

*The looks* (`/manners test` for a preview; other work is changing them, so
do these last, on the build you are about to release)

25. **The prompt and the picker.** `/manners test`: where you left it, the
    icon, name and reason readable, nothing overlapping or poking out; press
    it, the cast goes off and your target comes back. *Look*: every card has
    its picture whole with your own buff icon on it and the tick clear of the
    picture; pick three, the newest first: no green or white squares, no
    stretched strip, the words on the art, the animation once, then still.
    *Style* (the colours) folded under the hairline, its gold dot lit once a
    colour is changed, the page about three screens with its folds shut.
26. **The four new looks.** Stormcaller: the totem above and left of the
    panel, the icon square and round with *Round the icon off*, lava and
    water running, the lightning sheets at their frame rate, the list's
    tablet hanging from the slab, Calm stills it. Warchief: the icon cut to
    the chamfered square, the crest's glow while owed, the banner stirring,
    the drum beat and sparks on a landing, the reason on the iron.
    Gearworks: the icon round under the glass, the needle finding its mark
    for each reason, the three cogs turning in mesh, steam on a landing and
    the spark on a refusal. Ebon: the icon cut to the eight-sided socket,
    soulfire and vapour seen and not too strong, the three runes kindling in
    turn, the refusal playing out. All four: the words at the smallest and
    largest sizes.
27. **The four redrawn looks.** Minimal: the two additive flashes' strength,
    the cast's slide ending where it began, the fill cut at the left tick,
    the tick and cross sheets' frame rate, the hairline crisp. Ribbon: the
    seam between the tiled middle and the fork, the flutter and the wave in
    step, the rays' and glints' brightness, the laurel's gleam turning, the
    medallion pinned on, the cloth never absent through a landing. Letter:
    the cover's seam, the text held while the quill writes, the quill turning
    about its point, the reason line in the standard face. Leather: the
    feathers turning about their top, the glints, the strike's flash, the
    embers at rest, the smoke's frames. The serif names on Ribbon, Letter and
    Leather a fifth larger, with a long name and a key on the chip.

*Not on Forever: for a player of that client* (asked for in the listings'
comments when one turns up)

- Classic Era: `/manners selftest launch`'s *a debuff's timer* on a party
  member with a timed debuff you did not cast (an `expirationTime` of 0
  there means no cure is ever offered on that client, Cures.lua `ReadInto`),
  and whether `canActivePlayerDispel` is given; each cure spell per class.
- Mists or retail: a scenario counts as a dungeon for automatic profiles; a
  healthstone request casts Create Soulwell; the companion pet out of the
  journal with no press, once after a flight or a pet battle, not several.
- A client with realms: `GetRealmName()` is in the hall of fame's code.

**The baselines' new reds (2026-11-15).** The four baselines were written
again whole, in sections by piece, once `scenarios.lua` ran to its end on
every client. Against the old flat lists: Classic Era 908 reds (193 not in
the old list, 8 gone), TBC 921 (202, 9), Mists 1188 (386, 19), retail 1246
(411, 33). None is from this change: on Classic Era and TBC the old lists
were simply stale (they predate 1.11.25, and its asking, courtesies,
battlegrounds, hall of fame, Forever's Find Treasure and downranking are
written on Forever's two-part names, "Anna Aim", which those clients read as
a realm); on Mists and retail most are the 299 scenario loads of
`scenarios.lua` that had never run there. They are accepted as known so the
gate can see the next one; they are not all read. Worth reading first, on
retail and Mists, as they may be faults and not fixtures (each a section of
`tests/baselines/mainline.txt`): "who the proximity setting does not apply
to" (a party member, your target and your focus dropped for distance), "one
landing seen twice" (one favour filed as two debts, aura scan first and log
first), "a right-click skip holds against the next left press", "a press
goes to whoever the panel names", "the fallback does not undo a rejection"
(the level and range filters), "nobody is measured in a fight", "a refusal
read through the library is still a refusal", "the mark is consumed rather
than timed out", "an unknown class is not told it has nothing", "a spell
learned in a burst is not missed", and "Battle Shout reaches only who can
hear it". And 2, 2, 14 and 19 lines are scenarios that threw (`threw:`), each
a fixture asking for a buff or a family the client has not got: Wisdom and
Might (`whatif.lua`, `ask.lua`), Righteous Fury and the paladin auras
(`ownbuffs.lua`, `mage-scrolls.lua`'s `db.char.ownLast`, never made where no
such family is remembered), `linger.lua`, `hunt13-fix1.lua`, `self.lua`,
`perf.lua`. Each wants the `hasBuffs` skip `scenarios.lua` now has, or a
fixture of its client; a crash is a poor known red.

**1.11.25: the test pass.** One `tools/check.py --release` ran on master
before the menu and milestones were merged (10 min 39 s at `--jobs 6`). What
it found, and what became of each on `integrate`, where every one was run
again by its own scenario file and no whole suite:

- `validate`: `ns.Cures` written and never read. The addon's: the table was
  there for the tests alone. Gone; `cures-review.lua` sees the memory of a
  passer-by by what is offered.
- The previews stale: `Previews.lua`'s fingerprint, brought current with the
  look lists (`make_look_previews.py --check` and `--check-bare` pass).
- `perf-budget.lua`, 18.2 pcalls a raid scan against 18 (and 20.2 against 20
  with group casts) on four clients. The addon's: Battle.lua asked
  `IsInInstance` through `safecall` every two seconds, anywhere. It is now
  protected only until it has answered once (`answered`, Battle.lua `Where`);
  no budget was raised. Charged line by line, that was the only protected
  call the day's features added to the raid scan with their switches as a
  new profile has them: Share.lua, Resurrect, Cures, Milestones and Ask add
  none there.
- `hunt24-favours.lua` (4): the test's. The reminder to set a key parks a
  twenty-second timer at login, on the clock those scenarios read for the
  favours' settle timers; the file takes it off for its runs.
- `settings-fixes.lua` (2, on all five clients): the addon's. Battle.lua
  stamps `battle.carried` into every profile it meets, so an own profile only
  visited read as one set up and *Give this character its own settings* went
  back to defaults instead of copying. `OnlyVisited` (Options/Start.lua)
  knows the stamp.
- `menu.lua`: Look was 3.2 screens against 3.1 once the picker had nineteen
  cards. The layout's: *Style* is a fold now.
- `hunt38-picker` (28), `look-gearworks` (3), `theme-picker` (2),
  `hunt40-layout` (2), `selftest-launch`, `looks-alpha`, `hunt40-cards`, the
  fuzz canary and the fuzzer's `SetDegrees` on five clients: the tests' and
  the mock's, all settled by the look lists (the four new looks in every
  shared list, the mock's Rotation). Green.
- `fuzz-fixes.lua` as the four other clients: green.

Found beside them by `tools/prove.py`, three mutations that had gone MISSED
with their scenarios green, all the tests' own:

- `model-fixes.lua`'s canary picks *Never inside an instance* by its place
  among the window's controls, which Start here's three switches for
  milestones moved: 0.5190, the 164th of 315, now.
- Two of `fuzz-fixes.lua`'s canaries had gone blind. "A group member left off
  the queue" replayed seed 6, a warlock whose one buff for others (Unending
  Breath) goes only to a favour or a request by name since the right-buff
  audit, so nobody was plainly worth it: seed 75, a priest in a party. "The
  raised member behind a plain one" no longer fired on seed 22: seed 35.
  Both seeds were picked by playing the same steps on eighty, with the fault
  and without. All fifteen of `fuzz-fixes.py` are CAUGHT.

Still owed, for the full pass the author runs (`tools/check.py --release`,
then the selftest on GitHub):

- `tests/mockapi.lua`'s `KNOWN_EVENTS` lacks `UNIT_SPELLCAST_FAILED_QUIET`
  and `INCOMING_RESURRECT_CHANGED`; `fuzz_check.lua` needs an `e.res`
  exception to "is dead and was offered" and does not know the reason "ask";
  `fuzz_check.lua` and `fuzz_steps.lua` were edited for battlegrounds. The
  fuzzer has not run since any of it.
- `tools/audit_ids.py` does not cover Resurrect.lua's ids, and was not run
  for Courtesy.lua's or Cures.lua's.
- `perf-budget.lua` measures no world with a cure switch on, a dead member
  or a hello under way: a harmful-aura read a person, and the looks that run
  a `Painted` at every scan (Letter, Ribbon, Minimal's `Rest`), are inside
  the budgets as measured and have no line of their own.
- `pets.lua` and `mainline.lua` were edited for the journal pet and run only
  on their own; other scenarios listing Mists' or retail's families may need
  `and not family.pet`.
- No scenario presses the footer's author name.
- The full selftest has judged none of the day's mutations: each was seen
  CAUGHT by `tools/prove.py` on its own scenario files, which is not the
  whole suite.
- The contrast audit ran at the default size only for seven of the eight
  new or redrawn looks.
- **The listing pictures are to be redrawn and uploaded once the painted
  looks land** (the prompt's art is being repainted; drawing them before
  would draw them twice). `tools/make-screenshots.py` already holds the new
  story (2026-11-15 review): the first picture is the moment the addon is for,
  somebody buffed you, a pointer and your key, the same prompt as your buff
  lands (`picture_prompt`, `HERO_STEPS`), and the gallery runs the moment,
  who is offered, the looks, the ledger and milestones, the options window
  (`GALLERY`, which `.github/gallery.md`, `.github/media/UPLOAD.md` and every
  page's alt text follow; `tests/validate.py` holds them to it). It passes
  `--strict` on the current art. The files in `.github/media` are still the
  old drawing, old order: the pages already ask for the new first picture by
  its old file name, so until the redraw is on `master` they show the old
  one. At the redraw: `python tools/make-screenshots.py --strict`, look at
  each, commit `.github/media`, then upload in UPLOAD.md's order (none of the
  seventeen is in either gallery yet; whether each takes a GIF is to be seen
  there). What the redraw changes besides the first picture:
  `manners-options.png` (its footer reads 1.11.24; the menu's painted page
  icons and the bar of a page's parts are newer than it),
  `manners-options-wide.png` (the same icons and parts bar), every picture
  of a look (`manners-looks.png`, the two GIFs, `manners-moment.png`, and
  the prompts in the rest) for the painted art.
- **The listing text is up to date (2026-11-15) and not pasted yet**: the
  summary, both descriptions and the README's opening name the profiles
  that switch by themselves, the profile manager with *Undo*, a blessing for
  each class, the hall of fame, pages in parts with painted icons and the
  Forsaken's lines; the CurseForge looks paragraph is one line; every alt
  text is GALLERY's. Paste `curseforge-summary.txt` and
  `curseforge-description.md` into CurseForge and `wago-description.md` into
  Wago once the release that ships *Unreleased* is out (they describe it),
  and after the redraw above is on `master` (the descriptions show the new
  first picture by its file name).

**Launch day (WoW Forever, 2026-11-05): run one command.** Log in on the
character that has the Manners macro (or any character: the test makes a
temporary macro and deletes it), out of combat, with something targeted if you
like, and type `/manners selftest launch` (or, from 1.11.11, press *Check how
Manners draws in this game* on *Diagnostics*). About half a second later the report
opens in the box under Reporting a bug on Diagnostics (a line in chat says the
counts); click in the box, select all, copy, paste it back. The first line after
the header is the summary (`Launch checks: N PASS, N CHECK, N FAIL -- look at:
...`), then one line per item with the game's own answer: the Morpheus font
file, masks, clipping, `REPEAT` tiling, animations, each of the looks put
on the real prompt (regions, font, masks) and the style put back, the picker's
card icon and text, the bar slot (`SetMacroSpell`/`GetMacroSpell`, what an
empty string leaves, `SetMacroItem`, `PickupMacro`, `UPDATE_MACROS`, and
`EditMacro` writing the bar macro's two lines and reading them back), the
controller glyphs (`GetBindingText` for `PAD1` and `SHIFT-PAD1`, the three
`GamePadEmulate*` CVars), the tooltip's anchors, `/cleartarget` and the display
restyle. Do it twice if you can: once with nothing targeted and once with a
friendly player targeted (the hand-back line reads the difference). It casts
nothing, and the checks that touch things put them back (the report says what
it made). What it cannot say, because only eyes can, and what to look at after
it: Ribbon, Letter and Leather on the prompt (`/manners test` for a preview)
and the Leather's strips really tiled; the Letter's unroll cut to the paper;
the `launch.anim` line's `Scale(x, y) about LEFT` probe, which the two rules of
light on Glass and Minimal lean on (CHECK or FAIL there means they draw
from the wrong end or not at all); Glass over a snowfield for the edge light
(never over 0.40) and the wave from the icon's right edge, which the renderer
understates; Forge's slot, sparks along
the band and the steam puff, which the renderer shows faintly;
the bar slot drawing the spell's icon, cooldown and range, and the note icon
back with nobody to buff; the Manners macro on a bar: put it on a bar (Start
here > Put Manners on an action bar), `/manners clicks` on, and press the slot
with the mouse, then with its key with the game's cast-on-key-down setting on
and off (Esc > Options > Combat): each press casts once at the person the
prompt shows, and the log reads `CLICK build=... via=bar macro=...` then
`CAST SENT <spell> -> <name>`; open the macro window while the prompt changes
and the macro holds `/click MannersBar` alone until it shuts, then the lines
under it follow the prompt again; press it in the last moments of a global
cooldown: no cast, `ready in`; the picker's cards with the live icon on each; a
controller button's glyph on the chip; pressing with nothing targeted leaving
you with no target; and the prompt re-laying itself out after a change of UI
scale (Esc, Options, Video). Any CHECK or FAIL line is the lead: paste it with
`/manners errors` and `/manners debug`.

**The bar macro on Classic Era (1.11.0).** A Night Elf druid on Classic Era
1.15.9 (1.10.3, alone, Thorns on herself) found the Manners macro on a bar
casting nothing while a click on the prompt cast: the client will not run a
macro from inside one (Blizzard, WoWUIBugs #552), and the macro was
`/click MannersPrompt LeftButton 1`. It now carries the cast under
`/click MannersBar` (Clicks.lua, click macro), which rests on one thing no test
here can show: that a macro whose first line /clicks a plain button running
addon Lua still runs its `/target` and `/cast` lines on that client. First, a
macro made by hand with two lines, `/click MannersBar` and `/cast Thorns`
(any spell), pressed from a bar with 1.11.0 loaded, says whether it does. Give
it a name of its own, not Manners: a macro named Manners whose lines are a
shape Manners writes (that one is) is Manners', and is rewritten before the
press. Then
ask the reporter to update, press the bar macro once with the mouse and once
by key with `/manners clicks` on, and paste the lines (`BAR wrote=...`,
`CLICK build=... via=bar macro=...`, `CAST SENT ...`). A press is filed only
when `GetRunningMacro()` names the Manners macro (a client that names none
leaves it to the body): `CLICK via=bar body=other` on a press of the Manners
macro itself would say the client names something else there, and every bar
press would go unfiled. The scenarios in `tests/scenarios/barclick.lua` and
`barpress.lua` hold Manners' wiring to a model of the client
(`tests/mockmacros.lua`, "running macros"), not the client. Whether an
`EditMacro` lets go of what `SetMacroSpell` put on the slot is not known either:
every write hands it over again (`ReassertMacroSlot`).

**The action bar slot in the game (1.10.1).** SetMacroSpell/SetMacroItem on
the "Manners" macro, cleared with an empty string, and PickupMacro from the
options button are untested in a real client: check the slot shows the spell's
icon, cooldown and range, goes back to the note icon with nobody to buff, and
that a controller button bound to the prompt shows its glyph on the chip.

**Group pets (Unreleased), asked for on CurseForge by a hunter and a
warlock: needs a look in the real game.** *My group's pets too*
(`sources.pets`, off, under *My party and raid*): the walk goes on to
`partypetN` / `raidpetN` after everybody else (`Queue.lua`, `IterateUnits`),
`IsBuffableUnit` lets a pet through, and its entry carries `pet` and `owner`
(`tests/scenarios/grouppets.lua`). Only the live game can say: that `/target
<pet name>` reaches the pet (a pet with a common name, "Wolf" or "Cat", may
share it with another pet or a creature near by, and the name search may take
either); that `UnitIsUnit(unit, "pet")` names your own among a raid's pets;
what `UnitPowerMax` says of a pet's mana on each client (a withheld answer
falls back on the client's class for the pet); and whether a group cast
already covers the pets on each client (a pet is never counted for one, so
where it does, a pet missing the buff is offered a single cast the group cast
would have made unnecessary). Left out on purpose: a pet named as somebody of
the group, by the whole name or its first word, and one named as somebody
you owe a favour while it stands. A passer-by who shares a pet's name keeps
theirs: people are walked first, and one verdict is reached per name a scan.
A request in chat from somebody of a pet's name is still ticked off by a buff
that lands on the pet (`ns.ServeRequest` goes by name).

**The fight's rota (Unreleased), after a player wrote that Manners "retargets
the same person when they are buffed and does not notice party members that
are unbuffed".** `Prompt/Fight.lua`: at the pull the header is handed the
macro of everybody in the queue (`manners-rota-1..n`, twelve at most), and a
`SecureHandlerWrapScript` round the prompt's OnClick steps `macrotext1` to the
next on every left press; `SyncFightRota` (from the prompt's PostClick) points
`S.current` there. `prompt.fightRota`, on. Read against Blizzard's own
`SecureHandlers.lua` on the forever branch (Wrapped_Click, line 272) and held
by `tests/scenarios/fight-rota.lua` to the mock's model of it on all five
clients. Only the live game can say: that the wrap takes on the prompt on
Forever, that the post-body's write lands in a fight, that PostClick runs
after it (the panel would otherwise name the person just buffed), and how it
feels with the cooldown (a press it turns away still steps).

**The fight, after the review of 2026-11-15** (`tests/scenarios/par-core2.lua`).
Closed: a pull a few seconds after a crowd passed froze a passer-by who had
walked off on the prompt for the whole fight and made the rota of people who
had left. The pull's own repaint now arms from the queue less every passer-by
offered from memory alone (`Prompt/Fight.lua` `ForFight`, Queue.lua's
`remembered` on an `OfferPassersBy` entry); an asker and a favour owed stay.
The fuse after a fight repaints a second line that still spoke of the rota.
Closed: a press in a fight whose `/target` found nobody (the person gone from
view since the pull) handed your target back anyway, taking you off the mob
for that press and every one after. The macro armed for a fight now ends
`/targetlasttarget [help]` (`Prompt/Macro.lua` `HandBack`; Clicks.lua's
`Shaped` takes it as Manners' own); out of a fight the hand-back is as before.
The mock's runner now asks `SecureCmdOptionParse` for the hand-back as the
client's handler does, and reads `[help]`, `[harm]` and `[exists]` off its
target. Only the live game can say: that a questing pull just after somebody
ran past leaves the prompt down (or on whoever is still beside you); that
Forever's parser reads a bare `[help]` as the target's friendliness (run
`/manners selftest launch` with a friend targeted and again with a mob: the
hand-back's line says `[help] answers "yes"`, then `"no"`); and, in a real
fight, a press at somebody who has run off leaving your mob targeted, then
the next press at somebody there giving the mob back.

Closed: in a fight the rota went round and round, casting a half-hour buff
again at people it had just buffed. It goes round once now (`ROTA_POST`
writes nothing on the button past its last, and never reads a macro above
`manners-rota-n`, which a longer rota of an earlier fight may have left);
`SyncFightRota` empties `current` and the panel says *in a fight --
everybody it began with has had a press*. Secure code can know no more than
that: the restricted environment has no cooldown or aura read, and a handle
to a frame Lua could write in a fight is refused (`RestrictedFrames.lua`
`GetHandleFrame` on the forever branch), so a press the cooldown turned away
still uses its turn. A rota of one is no rota, as before: its press keeps to
the one person. The bar macro cannot step (no macro may /click a button that
runs a macro, and none may be rewritten in a fight): it keeps to the one
person the pull wrote, and *Put Manners on an action bar* says so in its
tooltip. Only the live game can say: in a dungeon pull, that presses one a
cooldown apart reach each person once and the fourth of three casts nothing
with the panel saying so; that a press inside the cooldown passes its person
by; and that the bar macro's tooltip reads right with *Hide the prompt in
combat* on and off.

**The credit line.** `diagnostics.aboutNote` names the author's
character (`ns.AUTHOR`, Clicks.lua), in the options window's footer under the
build since 1.11.18 (`Layout.lua`'s `footer.about`). It asks for nothing and must stay that
way: Blizzard's add-on policy forbids an add-on to ask for donations in the
game, gold included. `tests/scenarios/about.lua` reads the line in all nine
languages for the words a request would need.

**Archmage (Unreleased), asked for by the author.** `Looks/Archmage.lua`,
`Textures/Archmage/` (`tools/make_archmage_textures.py`), key `archmage`,
order 8, in `Looks.roundAlways` (the icon is a hexagon whatever the switch
says). Its lightning is four drawn frames, each a region of its own lit in
turn by Alpha animations that hold: frame-by-frame with no OnUpdate and no
FlipBook. It is the one look that loops with nobody owed (`look.idle`: an
ember, two lights drifting along the ridges, two glints; the author asked for
it), and `hunt35-effects` lets those groups through by name. Only the live
game can say: that a hexagonal mask cuts the icon and the cooldown's sweep on
all five clients, that a Rotation of a quarter turn leaves the four-pointed
star as it found it, that a Translation's offset starts again at each turn of
a REPEAT group (the drifting lights), and how bright the additive flashes are
(the renderer understates them).

**Glass redrawn (Unreleased): the game's own action bar.** `Looks/Glass.lua`
is a DRESSING over the glass `Prompt/Panel.lua` still draws (`Looks.RegisterDress`,
`S.dress`; Panel, Effects and Paint call it where they would call a look), so
every test of the built-in glass still holds: gryphons at the ends
(`tools/figures.py`, outlines raised or cut into relief; the generator needs
scipy for the cut, which no test runs), gilt rails, two sheets of
caustics scrolled under the words and the ready border run round the icon by
`Looks/Flow.lua`, the one OnUpdate a look may run (thirty writes a second,
only while something moves; `tests/scenarios/flow.lua`). Its eyes glint at rest
(`dress.idle`, let through by name in `look.lua` and `hunt35-effects.lua`) and
its gryphons stand outside the panel (`dress.outside`). *Gryphons at the ends*
(`prompt.gryphons`, off by default: the author's call, some players do not want
them) brings them. Only the live game can say: how the scrolled
textures look at the game's filtering, whether SetTexCoord's eight-number form
turns the border's strips as the mock does, and how bright the additive flash
of the gilt is. The picker's card for Glass shows only the gryphons' wings at
its edges: the card's view is the panel's own width.

**Lightbringer (Unreleased), asked for by the author as a paladin's look to
test.** `Looks/Lightbringer.lua`, `Textures/Lightbringer/`
(`tools/make_lightbringer_textures.py`), key `lightbringer`, order 9, in
`Looks.roundAlways`. Two of its lights leave the panel on purpose (the pillar
and the wings come from above; `look.skyward`, which `hunt37-effects` lets
through by name), and its rays are taller than the panel as drawn. Its sun
turns at rest (`look.idle`, let through by `hunt35-effects` as Archmage's is).
Only the live game can say: that three Rotation groups started in one frame
stay in step for minutes (the rays, their warm tone and their flash), that a
turn of 45 degrees on a REPEAT group restarts without a visible step, that a
Scale about TOP or a corner grows a texture from that side, how the wings and
the pillar look over the world behind the panel, and whether art drawn past
the button's bounds is clipped by anything the player has it parented near.

**Fel (Unreleased), asked for by the author as a warlock's look.**
`Looks/Fel.lua`, `Textures/Fel/` (`tools/make_fel_textures.py`, twenty-eight
files, its horns through `tools/figures.py`), key `fel`, order 9.5 (after
Lightbringer, before Glass), in `Looks.roundAlways`. Three things move by
their texture coordinates (`Looks/Flow.lua`): the fire along the foot and its
leap (one sheet of sixteen drawn frames, a tile of it laid several times
along the slab, every tile started in one call), the fire behind the cracks
(a scrolled REPEAT texture under a slab whose cracks are holes in its alpha)
and the gout (a sheet played once). The circle's eight runes are eight crops
of one file, each with a Rotation whose origin is the circle's middle. Its
gout leaves the panel on purpose (`look.skyward`); its embers and the
shard's glint loop at rest (`look.idle`); its horns and the circle stand
past the button's bounds as drawn. `tools/render_prompt.py` now draws
Rotation (the picker's cards are drawn with it off). Only the live game can
say: that a Rotation with an origin offset from the region's middle carries
a texture round that point as the renderer draws it, and that eight of them
started in one frame stay in step; that eight sheet handles started in one
call show the same frame (the tiles' seams) at thirty writes a second; how
a sheet's neighbouring frames bleed at a frame's edge under the game's
filtering (each frame fades to nothing at its top and its foot, and tiles
along its length); how bright the gout, the leap and the bolt are in ADD
(the renderer understates them); whether a 256 x 256 sheet at one texel a
unit is too soft for the gout at a large UI scale; how the alpha holes of
the slab's cracks look over the scrolled fire at the game's filtering; and
whether the picker's card, which cuts the horns' points off at its upper
edge, wants a taller view.

**Wild (Unreleased), asked for by the author as a druid's look.**
`Looks/Wild.lua`, `Textures/Wild/` (`tools/make_wild_textures.py`, thirty-four
files; the antlers, the crozier and every leaf through `tools/figures.py`),
key `wild`, order 9.7 (after Fel, before Glass), in `Looks.roundAlways`. Four
things move by their texture coordinates (`Looks/Flow.lua`): the moonwell
water round the icon (two layers of one REPEAT texture scrolled against one
another, both cut to the bed's ring by one mask texture), the vine (two
sheets of sixteen frames, its first half and then its second, the second
started from the first's `done` and timed from the moment the first ended,
played once when a favour arrives) and its three blossoms (a sheet of
sixteen, each at its own speed). Everything else that moves is an animation
group: five sprigs that sway (a Rotation that bounces, about the sprig's
root), three leaves that drift, three fireflies and a wisp, two glints on
the water, a landing's ten leaves and six petals (two Translations and a
Rotation each), a refusal's husks. Its sprigs, drifting leaves, fireflies,
wisp and glints loop at rest (`look.idle`); nothing of it is scaled, so it names nothing in
`look.skyward`; its antlers stand some 27 units over a default panel and its
sprigs and vine past the button's bounds as drawn. A refusal browns the
wreath, the sprigs and the bough by `SetDesaturated(true)` with a brown
vertex colour, and `tools/render_prompt.py` now tints a greyed texture as
the game does (it used to grey the tinted product, which lost the colour).
With a key bound and the default width the words have 82 units between the
wreath and the crozier, so a long reason line is drawn smaller sooner than
on the other looks. Its colours keep each texture's alpha as Frost's do
(`Colour`, since the merge with 1.11.21: before it a reason's colour with an
alpha of 1 would, in the game, have lit the halo, the flash, the star, the
moon's light and the inlay's core that `SetAlpha` had parked dark or faint;
`look-wild: a colour leaves every light as faint as it was`). Only the live game can say: that a mask texture on a
REPEAT texture whose coordinates run past 1 cuts it as the renderer draws
it (the launch check's masks are the icons'); that a desaturated texture
takes its vertex colour (if not, a refusal's leaves are grey, not brown);
that a Rotation on BOUNCE swings a sprig back the way it came; that two
Translations in one group add up to the arc drawn here; how the two water
layers read at the game's filtering and at thirty writes a second; how
bright the paw and the bloom are in ADD over the icon (the renderer
understates them); whether the vine's two halves meet without a seam and
its second half takes up from the first without a held frame; whether the
vine's sheets, two texels to a unit at the default width and stretched on a
wide panel, are too soft at a large UI scale; and whether the picker's card, which cuts the antlers off at its
upper edge, wants a taller view.

**Frost (Unreleased), asked for by the author as a frost mage's look.**
`Looks/Frost.lua`, `Textures/Frost/` (`tools/make_frost_textures.py`,
thirty-six files), key `frost`, order 9.8 (after Wild, before Glass), in
`Looks.roundAlways`. By `Looks/Flow.lua`: the mist in the ring round the icon
(two layers of one REPEAT texture scrolled against one another, cut to the
ring by a mask), the rime (two sheets of sixteen frames creeping from both
ends at once, played once when a favour arrives) and three snowflakes (a
sheet of sixteen each, at its own pace). The rest are animation groups: the
Ice Block shut over the icon and shattered, its fractures and Frost Nova's
ring (ADD, under 0.6 s), eight shards flung, the snowflakes' splinters, a
refusal's cracks (they stay), melting rime and falling icicles; at rest
(`look.idle`) four glints, five flakes of snow and a drop from an icicle.
Two things were done for the two complaints players made of other looks.
The words: the name and the reason line stand on the deep ice over a full
dark shadow, the reason line and the verdict held to a contrast of 7
(`SUB_CONTRAST`), and where the button is too low for its two lines the
slab stands up to 1.12 of the button's height (`SLAB_OVER`) so the name
keeps clear of the frosted rim. The alpha: every colour given to a texture
goes through `ns.Looks.Colour` (the shared helper since the pass after
1.11.24: the colour, then the alpha the texture rests at, kept in a field
and never read back from `GetAlpha` mid-flash), because the game keeps one
alpha for a texture and a colour with an alpha of 1 would light what
`SetAlpha` dimmed (`look-frost: a colour leaves every light as faint as it
was` makes the mock's textures behave so). Only the live game can say: how
the mist's two layers read at the game's filtering under the
mask; how bright the fractures and the nova are in ADD over the icon (the
renderer understates them); whether the rime's two halves meet in the
middle without a seam on a wide panel; that a desaturated texture takes its
vertex colour, as the fight's dulling and a refusal's greying assume; how
the reason line reads at 10 pt in the game's own face on the ice (the
renderer's stand-in is bolder); and whether the picker's card, which cuts
the rime's spikes and the icicles' points at its edges, wants a taller view.

**The new looks in the game.** Ribbon, Letter and Leather (1.10.0), Forge, the
glass rebuild of Glass and the
picker's cards (the player's own buff icon laid over each picture) have only
been seen in the renderer: the real Morpheus face, masks, the scroll's unroll
clip, the tiled leather and the tiled iron want a look in the client. So do the
built-in looks' new motion (the entrance rules, the favour's glint, the landing's
edge light and wave, the refusal's crack and grey icon) and the bezel's hover
lift.

**Forever's group casts and the cast event.** The mage's, priest's and druid's
group casts have no unit target in the client's spell data, so
`UNIT_SPELLCAST_SENT` is taken to name nobody and the cast is settled as "would
not say" (1.7.6). That is an inference from the data and Blizzard's
documentation, not an observation: `/manners clicks` after one such cast shows
the sent line (`CAST SENT 23028 -> ` with nothing after the arrow if it is
right).

**Only Mage has ever cast in the live client, and only on WoW Forever.** No
review substitutes for it. Warrior first: Battle Shout is `selfCast`, its macro
has no `/target` line, and `pending.selfCast` in `SettlePendingClick` is the
branch deciding whether a warrior can ever repay anybody. It has never run
against the real game. The other four clients have run only on the mock.

**Weapon enhancements were written against the data and the mock, and the
first word from the live game is a shaman on Forever saying the oil macro
"doesn't apply oils properly".** Nothing in the data says why: an
oil's use spell is the same shape as a scroll's (SpellTargetRestrictions target
16, a three-second cast, SpellEquippedItems asking a weapon class), the ids and
enchants audit clean at both Forever builds, and the macro is the scroll's
(`/use item:<id>`, `/use 16`). What the game does with it is not known. Ask the
player which oil, what the press did (nothing, an error line, the replace popup,
the wrong hand), and for `/manners debug` and the lines `/manners dev clicks`
prints on one press (`CLICK build=... macro=...`, `CAST SENT <spell> -> ...`,
`CAST OK`, `after our cast: ...`). A macro of the player's own with those two
lines (`/use item:20750`, `/use 16` for a Wizard Oil), clicked from a bar with
the oil in the bags, says whether the game takes the form at all. Forever
lists an Imbue (Rockbiter Weapon, a poison, a scroll) and a Temporary enchant (a
stone, an oil, a lure) on a hand together; `enchantKind` in `Buffs.lua` and
`ReadImbue` in `Core.lua` sort by it.

**One assumption is untested.** A late refusal is matched to the press it
answers using the cast guid the client sends with both cast events, and only
the guid: a refusal undoes nothing unless both events carry the same one,
because without it a new attempt being turned away cannot be told from the
answer to a press that landed. If the client does not fill the guid in, a real
late refusal goes unnoticed and the favour stays marked repaid, which is safe
but quieter. Confirm with `/manners clicks` in game.

**`runscenarios.py --flavour X` is red off Forever by design**: most of its
failures are fixtures written for Forever (two-part names, Forever's scrolls
and raid-wide group casts, a raid pcall ceiling set for Forever's data). Run it
with `--baseline` to see only failures that are not already in
`tests/baselines/<X>.txt`. Since 2026-11-15 that is a gate:
`tools/check.py --baselines`, part of `--release`, runs the whole suite as
each of the four other clients in eight pieces and fails on a red that is not
written down in its piece's section. Before, `scenarios.lua` stopped at its
block 16 on Mists and retail (`FindBuff("PALADIN", "wisdom")` is nil there),
so 299 of its scenario loads, and in a one-process run every topic file, never
ran on those two clients, and the baselines accepted the abort as a known red.
The four baselines were written again whole that day; what that run found
that the old lists did not hold is under *Open* (the baselines' new reds).
What it costs: about 95 minutes of two cores, some 32 at `--jobs 6`, so it is
a release step and not an every-change one. CI still runs Forever alone.

**Client builds move.** `python tools/clients_watch.py` says when one has (its
row reads DRIFT); the toc then needs the number (`tools/maketocs.py`'s
`FLAVOURS` and `Manners.toc`'s Interface line). Retail moved to 12.1.5
(interface 120105) in 1.7.7.

**What 1.8.0 needs the live game for.** The clickable names in the list
(`Prompt/Rows.lua`): a left click on a name targets, casts and hands back with
the spoken line, and the favour is filed; the row's attributes written in its
PreClick are read on that same press (the prompt relies on the same); in a
fight a name does nothing and no "action blocked" error appears; the click
areas line up with the text in all six looks, above and below the prompt;
right-click skips, shift-right-click lists. The weapon enhancements
(`ENHANCEMENTS` in `Buffs.lua`): `/use 16` and `/use 17` aim the right hand on
each client; the off hand's values in `GetWeaponEnchantInfo()` on Era, TBC and
Mists; `WEAPON_ENCHANT_CHANGED` fires; over an enhancement already on, the
game's own replace question appears and the player's click completes it
(Manners never answers it); retail and Mists poison spells and talents read
right. The friendly-nameplate note and button under Passers-by, and the
empty-key line, as laid out in the real window.

**Group spells are cast by bare name**, trusting the game to pick the best
rank (Buffs.lua header). A priest or druid with two ranks of Prayer of
Fortitude or Gift of the Wild has never pressed one in the live game. On a
level-60 priest, `/run local i=C_Spell.GetSpellInfo("Prayer of Fortitude")
print(i and i.spellID)` printing 21564 says the bare name means the top rank.

**Bug hunt 23 rests on three client facts nobody here can observe.** The nine
old candidates were triaged after 1.7.7: two were already fixed, seven were
fixed in 1.7.8 (`tests/scenarios/hunt23-*.lua`). What they assume:
- Classic Era and TBC answer nothing for spell 61304 (no DB2 row there), so
  `GlobalCooldownReading` (Clicks.lua) reads one of the class's buffs. If those
  clients answer zeros instead, the fallback never runs. `/run
  print(C_Spell.GetSpellCooldown(61304))` on either client settles it.
- The cast spell's `isOnGCD` reads true by `SPELL_UPDATE_COOLDOWN` for a cast
  on the global cooldown (`DropGuessOffGcd`); Blizzard documents the field as
  trustworthy only there.
- Selecting the unit already selected sends no `PLAYER_TARGET_CHANGED`
  (Queue.lua `pointedAt`, `NoteRefusal`).

**What bug hunt 23 left.** A refusal of your aura list longer than both settle
stages (about 34 s: a keystone, a long fight) still loses the first favour
after it (Favours.lua). A target chosen before the addon heard any target event
(login, `/reload`) is not known to be a choice and is backed off as before.

**The retail runs of the fight scenarios are local only.** `check.py
--flavours` runs `unverified.lua`, `hunt23-queue.lua` and `hunt23-favours.lua`
as mainline (`ALSO` in `tools/check.py`), since retail hides auras in a fight
as Forever does. Neither `ci.yml` nor `tools/release.py` runs `--flavours`
(release.py runs `check.py --anchors`); adding it to release.py's check would
cost about 30 s. `check.py --release` runs it, and the whole-suite baselines
of the four other clients beside it.

**A client bump stales `tests/baselines/mainline.txt`.** Nine of its lines
carry the client line ("12.1.5 (...), interface 120105"); they were rewritten
for 12.1.5 after 1.7.8. `normalise()` in `tests/runscenarios.py` could strip
the build and interface so the next bump does not.

**Unused local functions are found by hand.** `tests/validate.py` reports a
write-only `ns.X`, but nothing finds a local function nobody calls; extending
that check is the one step of the 1.0.0-beta.9 cleanup plan never built.

**Well Fed was written against the data and the mock (1.11.2).** Three things
only the live game can say, each from one press of food on a character with
the switch on (*Who to buff* > *Myself* > *Well Fed*) and a Well Fed food in the
bags: (1) that the aura is found by the client's own name for it
(`C_UnitAuras.GetAuraDataBySpellName` with the name of `ns.FOODS[client].fed`):
`/manners debug` says "Well Fed: ... is up" with one on you and offers a food
with none; (2) that a meal in progress is seen, so a second food is not offered
over it: the use spells are named "Food", "Nutritious Food" or "Nutritious
Drink" (`Eating` in `Core.lua` reads the aura of that name); and (3) that a
press eats the food the prompt names (`/use item:<id>`, the icon of the item).
On Forever the foods and their use spells are from build 1.60.1.70532; if a
build adds foods, `python tools/make_foods.py` rewrites `Foods.lua` from the
cached tables (`--check` says whether it is current) and the next release
carries it.

**Bug hunt 35's buff ideas, built in round 36 (Unreleased).** The owner asked
for all of them. Three builders added them, each id checked on that client's
wago.tools tables:
- Own buffs: Shadowform, Moonkin Form (`form`), the Season of Discovery runes
  (Molten Armor, Aspects of the Falcon and Viper, Heart of the Lion), Grimoire
  of Sacrifice, the shaman's imbues on Mists and retail (retail per hand,
  `shield` for Thunderstrike Ward) and the Lightsmith rites.
- Flasks, elixirs and scrolls (`Consumables.lua`, from `tools/make_consumables.py`).
- Buffs for one target at a time (`oneTarget`): Earth Shield, Beacon of Light,
  Oath of Light on Forever, Symbiosis (`notOwnClass`) and Blistering Scales, and
  Season of Discovery's Commanding Shout.

Earth Shield and Commanding Shout are not on Forever: their ids are leftover
Season of Discovery runes there with no TraitDefinition row, so neither can be
learned. Beacon of Light 407613 has no SpellName row on Forever.

What only the live game can say about them:
1. Whether `UnitGroupRolesAssigned` gives a tank a role in a Classic Era or
   Burning Crusade group made without the group finder. If it answers `NONE`,
   the tank buffs are offered unasked only in a raid with a main tank mark, as
   for Thorns' *Tanks only*.
2. Whether a Beacon, Oath or Earth Shield you put on somebody names you as its
   caster on retail and Forever. If it names nobody, an untimed Beacon on a
   non-tank is not read as yours, and the tank is offered one.
3. Whether retail's `GetTemporaryEnchantmentInfo` reports the dummy imbues,
   Thunderstrike Ward and the rites.
4. Whether `GetShapeshiftFormInfo` answers for Moonkin Form as Manners reads it.
5. Whether Forever's Aspects of the Falcon and Viper can be learned.
6. Whether a `/target <you>` and `/use item:<id>` press uses a scroll on Forever,
   and whether using one while mounted dismounts you.
7. Whether Season of Discovery's Commanding Shout shares a rule with Battle
   Shout: the data shows none, so the two are offered side by side.

**Bug hunt 37 (Unreleased): 47 findings, all fixed, and the buffs still
missing.** Five areas, each in its own worktree: the new buffs (12), the engine
(7), the prompt (5), the test model (7) and a builder for buffs still missing
(16 ideas, 11 built). Built: Demonic Sacrifice and Soul Link (`demonicsacrifice`,
Classic Era, Forever, TBC), Tree of Life (TBC, Season of Discovery), Spirit of
the Alpha (Season of Discovery, `oneTarget` for others and `tank` on yourself),
retail's Beacon of Faith (`apartFrom` keeps it off your Beacon of Light's
wearer) and Symbiotic Relationship, more Classic Era elixirs, Mists'
Alchemist's Flask and Crystal of Insanity, and retail flasks. Not built, each
with its reason in the round's notes: Valor of Azeroth (raid-wide reach on a
set whose shouts are subgroup-only), Horn of Lordaeron (exclusive with Might),
Juju Power and Guile (a server-side exclusion no table holds), retail weapon
oils and stones (no retail SpellItemEnchantment in the audit), retail Moonkin
Form (a class-tree trait: no spec gate), Mists Enhancement's off-hand imbue
(which hand `/cast` lands on).

Left for later:
- The Oath of Light cast record (`ns.NoteGave`) is memory only, so a `/reload`
  on Forever forgets which Oath was yours. Keeping it in `db.char` would fix it.
- A one-target-only class lets a favour from a non-tank go, and the chat line
  blames *Skip players it does nothing for* even when that is off. A new string.
- ptBR and itIT word nine RP.GIFT thanks in a man's voice; they sit in
  `RP.MASCULINE` until retranslated in a form that fits both.
- The *Right now* line keeps up with the prompt in Manners' own window only;
  the fallback AceConfig dialog repaints it on its usual triggers.
- `Options/Who.lua` PlatesHidden and `Options/Launcher.lua` still give a
  talent-only class with nothing learned the nameplate note.
- An alt's scroll body in the bar macro is recognised through AceDB's
  `profileKeys`, so a character that never logged in with Manners is not.
- vanilla's `window-classes.lua` "a warrior with one buff" fixture is stale
  since Commanding Shout (baselined), and mainline's `who.own_moonkinform`
  layout red is baselined, not explained.

What only the live game can say about them:
1. Whether a Mists scroll really knocks a Battle or Guardian elixir off.
2. Whether Symbiosis puts the class aura (110478 to 110491) on the member with
   the druid as its source, and what aura 136519 is.
3. Whether retail's off-hand Flametongue refuses an empty off hand.
4. Which aura Season of Discovery's Felguard gives for Demonic Sacrifice, and
   whether Demonic Sacrifice and Soul Link read as unusable with no demon out.
5. Whether another shaman's Spirit of the Alpha on a tanking shaman fills his.
6. Which of 79638 to 79640 the Alchemist's Flask puts on you; the Crystal of
   Insanity is offered during its cooldown after a death.
7. Which of 474750 and 474754 the ally wears for Symbiotic Relationship (both
   are read on members, never on the druid).
8. Whether Burning Crusade names your pet (`pet`) as the source of Soul Link
   (25228), as its data says; Manners reads it as yours on that.

**A blessing naming no caster (Unreleased), reported on CurseForge.** A paladin
was never offered Might or Wisdom beside a third party's Kings where the aura
names nobody as its caster, as Forever is noted to do (see "Written against the
mock" below), since nobody named counted as yours. Once the client has named you
on somebody else (`ns.namesYourCasts`, Core.lua's aura read, per session), an
aura naming nobody, and not hidden, is another paladin's. Read on Forever
1.60.1.70862: your own cast on another player says `caster=player` (`/manners
look target`). What a third party's says with nobody near them to name has not
been read; if it names them, this changes nothing.

**The Scrolls switch (Unreleased), asked for on CurseForge.** `ownBuffs.scrolls`
(on by default, so nothing changes until it is flipped) turns off every family
flagged `isScroll` (the stat scrolls, Forever's Familiar and Weapon imbue) and
hides their rows, through `ns.ScrollsOff`; each scroll's own switch and pick are
kept. Nothing here depends on the live game beyond what the scrolls already did.

**Find Treasure beside a gathering tracking on Forever (Unreleased).** A dwarf
on CurseForge keeps Find Treasure (2481) on with Find Herbs or Find Minerals;
on Forever 1.60.1.70790 all three are SpellEffect aura 45, so it is the server
that lets them share. On Forever alone Find Treasure is now a family of its own
(`findtreasure`, `onceUp`: reminded only once Manners has seen it on), and
`ns.SplitFindTreasure` moves a pick, a tick or the memory of it off Tracking
once (`tests/scenarios/forever-tracking.lua`). What only the live game can say:
(1) that the minimap's list (`C_Minimap.GetTrackingInfo`) shows Find Treasure
and Find Herbs `active` together; (2) that `/cast Find Treasure` with Find Herbs
on leaves Find Herbs on, and the other way about (if one press turns the other
off, the two families would take turns). Open: whether Forever lets Find Herbs
and Find Minerals be on together too. Nothing says so yet; if a player reports
it, they would split the same way (and Tracking's Automatic would need a rule
for which of several to ask for). A dwarf with a gathering profession who had
Find Treasure as Tracking's memory is now asked for the gathering one too (the
first known) when it is off.

**Well-Rested was written against the data and the mock (1.11.10).** The
Cozy Sleeping Bag (item 211527) casts Unroll Bag (429961, an hour's cooldown);
resting in the bag a minute gives Well-Rested (429959), and the bag's area
puts a tracking aura (429960) on you (wago.tools, Classic Era 1.15.9.70003 and
Forever 1.60.1.70790; Burning Crusade, Mists and retail have none of them).
Only the live game can say: that 429960 is on you while you lie in the bag
(`BagBusy` in `Core.lua` reads it, and the item's cooldown, to hold the
reminder back), that the bag is obtainable on Forever at all (its data is
there), and that `/use item:211527` lays it down. `/manners debug` says
"Well-Rested: ..." with the reason in each case.

**Unending Breath while swimming (Unreleased).** A warlock's own family
(`selfbreath`, every client), reminded only while `IsSwimming()` says yes, held
two seconds past the last stroke. Only the live game can say: that
`IsSwimming()` stays true at the surface and under it alike, and how long a jump
out at the surface or wading at the swimming depth reads false (two seconds is
a guess, longer than the prompt's empty fuse); and that a shaman's Water
Breathing (131) is the aura it says on the warlock wearing it.

**Waiting on players (1.11.9).** Two `/thank` reports need a log: one player
sees a /thank with *Thank people who buff me* off, another never gets one. One
code path makes the emote (`Favours.lua`, `ThankFavour`) and it obeys the switch;
the full check-up shows the switch and the last thank made or skipped and why,
and (Unreleased) the whispered thank-you's switch and who it last went to.
Offering buffs to group pets (a hunter's, a warlock's) was asked for and is its
own piece of work: pets have no unique name, are not players and are not in
`UnitInParty`, so the walk, the macro (`/target` by token, not by name) and the
settle all need it.

**Hide the prompt in combat (Unreleased), asked for on CurseForge.** Look's new
switch (`prompt.hideInFight`, off) takes the prompt and its list off the screen
for a fight through a `SecureHandlerStateTemplate` header with a `[combat]
fight; peace` state driver (`Prompt/Fight.lua`): its snippet clears type1,
macrotext1, type and macrotext on the prompt and every row, then hides the
prompt; the pull first writes the bar macro to its first line alone, and the
prompt is hidden only when the macro reads back that way. Built on
Blizzard's SecureStateDriver.lua, SecureHandlers.lua and RestrictedFrames.lua
(the same on all five branches) and the mock's model of them. Only the live
game can say: that the snippet runs in a fight on each client and the key
binding, `/click MannersPrompt` and the bar macro then cast nothing (`/manners
selftest launch` has a `launch.fighthide` line: the header, the driver
reading peace, and the snippet tried on a scratch secure button out of combat);
that `PLAYER_REGEN_DISABLED` still lets the bar macro be written on every
client, as the pull already relies on; and that the prompt comes back with its
entrance after the fight.

**The fuzzer's request model (1.11.9).** Two 500-seed findings ("asked for motw
and is offered as group/target") were the fuzzer's, not the addon's: a second
line ("thorns pls") replaces a person's request (Requests.lua, NoteRequest, one
per person), and `sayAsk` in `tests/fuzz_steps.lua` did not drop the old one. It
does now, keyed on the addon's own `askScan.noted`. The 1.11.x settings in the
fuzzer are read off a number made from the seed, not drawn, so every older seed
and canary plays as before; 2,500 runs of 150 steps were clean after it.

**Since 1.11.9, untried in game:** a sound is stopped by the handle
`PlaySoundFile` returns (`StopSound`, kept in `db.char.soundHandle` so the next
session stops one a `/reload` left playing); whether a handle outlives a
`/reload` is not known.

**1.11.3 to 1.11.8 were released on the quick gate alone.** The full selftest was
not run for them (about an hour: `python tests/selftest.py`); `check.py --lint
--flavours --anchors`, every client's baseline, the fuzzer and the perf budget
were, and each change's mutations were proved red by hand. Run the full suite
before the next release.

**Written against the mock, not the game (1.11.3 to 1.11.8).** Only a live
character can say: (1) a shaman's imbue is read from the main hand's enchant of
the Imbue kind and the first spell known is offered (Windfury first); the off
hand is read on retail only (1.11.11), and Mists' own imbues are offered since
1.11.11; (2) the
bar macro carries the armed spoken line, so a press says it even over a cast
that then fails, and whether the game takes the longer body is untried; (3) with
a gamepad on, no `MenuUtil` menu is opened (issue #6's trace is Blizzard's, with
Manners the only addon, so the cause is a guess from the trace); (4) a role for
Thorns' Tanks only is `UnitGroupRolesAssigned` or the raid's main tank mark:
`UnitGroupRolesAssigned("player")` answered `NONE` alone on Forever, and what a
group gives is not known; (5) on Forever the game names you as the caster of your
own buff on another player (`sourceUnit` is `player`) and nobody for a third
party's, which is what `ns.NoteGave` backstops.

**The audit lists 18 findings for Forever.** `python tools/audit_ids.py --client
camelot --offline` reports length rows for the lower ranks of a shaman's imbues
as "held nowhere" (the family holds the top rank of each; the rows are for the
ranks the client may name). They are the same findings it had at 1.11.3 and
nothing reads them.

**The `visuals` branch's merge 2f6f5e2 ("Merge forge-look into visuals") has no
Co-Authored-By trailer.** Every other commit there carries it; the merge is
merged history and is left as it is (no amend, no rebase).

## Decisions

Code comments point here (`STATUS.md`) for these. They are decisions rather
than code; do not undo them.

- **`verbose` stays on by default** (decided 2026-10-17). Every player gets
  "X buffed you" and the line saying why a cast failed: a new player sees the
  addon notice favours. AceDB stores no value equal to its default, so changing
  the default would flip everybody who never touched the setting.
- **The real player names in git history stay** (decided 2026-10-17): nine
  names in two commits from before the v0.9.5 scrub, plus the pre-scrub
  screenshots as blobs. All of it was public long before, a rewrite would
  change every hash and tag and still leave copies in clones and GitHub's
  caches.

- **The bar macro carries the cast** (decided 2026-11-02): the client refuses a
  macro that /clicks a button which runs a macro (Blizzard, WoWUIBugs #552;
  retail 11.0.2, the Classic clients since), so no macro may /click
  MannersPrompt. Do not go back to a /click body. The bar's copy says no line:
  only a press of the prompt judges the line at the last moment (HoldLine).

- **The first-name fallback was removed deliberately.** The macro sends one
  `/target`, carrying the full name. Both `CHANGELOG.md` 1.3.0 and
  `.github/AUDIT.md` argue for offering the bare first name as well; both are
  marked superseded, and there is a note above `ExpirePendingClick` in
  `Clicks.lua` saying why. Do not restore it.
- **The aura scan corroborates rather than recognises.** It does not try to
  tell a refusal from an empty list — it cannot, because the shape a refusal
  arrives in is unknown. Nothing primes, prunes or announces on one reading.
  A refusal that repeats identically across two readings is indistinguishable
  from holding nothing, and that residue is documented in the code.
- **A favour names who was there when the aura landed**, not who holds that
  nameplate token when it is noticed. A sighting nobody could name is never
  announced.
- **The never-offer list does not apply to a favour owed.** Somebody on it
  who buffs you is still offered the return, because returning a favour is
  the point of the addon; the options page says so. Shift-right-clicking an
  owed person lets that one favour go too, or they would come straight back
  when the skip ran out -- including somebody who was already on the list.
  Friends-first orders people *within* a kind of offer (group, passers-by)
  and never across one, and below the range key: a friend known to be out of
  range never leads over somebody in range.
- **The combat log is an addition, never a replacement.** It is registered only
  on Classic Era, Burning Crusade and Mists — Forever and retail refuse it — and
  it exists for the one thing the aura scan cannot do anywhere: name a stranger
  with no unit token, from `SPELL_AURA_APPLIED`'s GUID via
  `GetPlayerInfoByGUID`. It goes through the same `NoteFavour`, not a queue of
  its own, and none of the aura scan's corroboration applies to it: a log line
  is an event, not a reading that might be wrong. Where both sources run they
  agree through one claimed-and-consumed mark, so a landing both of them see is
  announced once and a genuine recast still counts.
