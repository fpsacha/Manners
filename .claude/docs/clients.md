# Manners -- the five clients in detail

The table of the five clients is in `CLAUDE.md`. Here: how the client is told,
`Buffs.lua`'s per-client fields and flags, what each client does differently,
and the entry kinds on the prompt. Moved out of `CLAUDE.md`, word for word;
`CLAUDE.md` is the index, read first.

## The five clients, in detail

- **Flavour.lua** matches the interface number against bands tried in order
  (camelot first: 16001 and 11509 are both five digits). `WOW_PROJECT_ID` is a
  cross-check only (MAINLINE on retail and on Forever's early builds), except
  Forever's own `WOW_PROJECT_CAMELOT` (18 in its 1.60.1.70532 source), which
  names one client and wins where the interface number has no band or
  another client's (`tests/scenarios/flavour-project.lua`). An unknown
  interface falls back to the project id's family, else `modern`.
- **MomentsData.lua** (the buttons for the moment, `Prompt/Moments.lua`) has one
  set per data set as `Cures.lua` does (`SETS`: Forever and Classic Era share
  one, Burning Crusade, Mists and retail each have their own): rows per class,
  and a flavour with no entry gets none. A mage's rows differ by data only:
  Counterspell's cooldown, Ice Block and Cold Snap's spell ids (talents on
  Forever and Classic Era, Hypothermia from Burning Crusade), a mana gem on the
  clients that have one, Spellsteal from Burning Crusade, the wards on Forever,
  Classic Era and Burning Crusade, Slow Fall's feather where the client asks for
  one. Nothing branches on a client's name; a signal the client cannot give
  answers "blind" and the row's `blind` field decides.
- **Buffs.lua** has one set per flavour (`SETS`); an unrecognised flavour gets
  its family's (classic -> vanilla, modern -> mainline). The chosen set fills
  `ns.BUFFS`, `ns.OWN_BUFFS`, `ns.EXCLUSIVE_BUFFS`, `ns.CLASS_AUTO`,
  `ns.CLASSES_WITHOUT_BUFFS`, `ns.PARTY_IS_SUBGROUP`, `ns.GROUP_IS_RAID`,
  `ns.SHOUT_YARDS`, `ns.WIDE_CASTS`, `ns.GROUP_BY_CLASS`, `ns.FAVOUR_ONLY_IDS`,
  `ns.NOT_FAVOUR_IDS`, `ns.RANK_LEVEL`, `ns.STAT_VALUE`, `ns.STAT_TIERS`,
  `ns.LEVEL_GATED`. Branch on those fields
  and the per-buff flags (`partyOnly`, `groupOnly`, `selfCast`, `alone`, `alike`,
  `blockers`, `neverAuto`, `optIn`, `returnOnly`, `pet`, `forTank`, ... documented at the top of
  the file) rather than on
  flavour names. `blockers` and `ns.STAT_VALUE` are the flat-stat scrolls that
  hold a weaker rank of Arcane Intellect, Fortitude or Divine Spirit off
  (Classic Era, TBC, Forever; Mists and retail give percentages and have none),
  weighed numerically in `UnitHasBuff`; `tools/audit_ids.py` holds them to
  SpellEffect. On Forever the blockers also hold the camping buffs Boosted
  Stamina, Intellect and Spirit, whose worth goes by the wearer's level
  (`ns.STAT_TIERS`, `ns.CampWorth`: the aura's own points, else the tier the
  feature's text gives; the audit holds both), and Forever's Arcane Intellect
  also the three other auras its data calls Arcane Intellect, outside the
  rank chain (`ALIKE_BLOCKERS`: 364161, 13326, 16876; the audit takes the
  buff's own name for them). A refusal the game explains only after
  `UNIT_SPELLCAST_FAILED` (Forever) is acted on when the reason comes
  (Queue.lua `NoteGameError`, `LateReason`; the message type's string id from
  `GetGameMessageInfo`, Clicks.lua), and the same buff refused on the same
  person twice running with no reason and no aura added to or taken off them
  between is held off them as THIS_BUFF holds it, target or not
  (`RefusedAgain`; lifted by such an aura, `ns.AuraChangedOn` from Favours.lua's
  UNIT_AURA while `ns.refusalWatch`, or by Who to buff's `heldRetry`,
  `ns.OfferHeldAgain`). `ns.LEVEL_GATED` (the vanilla
  set's `levelGated`, read by Forever's and Burning Crusade's) says a cast
  lands only within ten levels of its rank: a buff's `lowLevel`, worked out in
  the lookups, keeps it off anybody too low for every rank (`Castable`), and
  `ns.RANK_LEVEL` holds the group versions' levels too, for the fold
  (GroupBuffs.lua, `TooLow`) and for a group version worn (`UnitHasBuff`). The
  camelot set is vanilla's (`__index`) with its own buffs, and is still called
  "vanilla" in `ns.BUFFS_SOURCE`; tbc builds on vanilla the same way.
- **How long each buff lasts** is a table of ids per client in `Buffs.lua`
  ("how long each lasts", `ns.SPELL_SECONDS`: seconds, 0 no timer, absent
  unknown), from each client's SpellDuration; `tools/audit_ids.py` holds every
  row to it, so a new id in a set needs its row. A top-up's lead is worked out
  from it in `Core.lua` (`ns.TopUpLead`, `ns.LeadFor`: a tenth of the length,
  the slider `refreshUnder` its ceiling, `refreshRaid` times in a raid or
  dungeon, your own buffs half as much again, passers-by the last half
  minute); the aura's own `duration` beats the table.
- **Who is offered first** (Queue.lua, `PRIORITY` and `OfferRank`): by tier
  (target, a ready check or a death, owed, asked, yourself, group, passers-by),
  then range, then inside a tier what is missing before what nobody could read
  before a top-up, then the buff's place in the walk (everybody's first
  missing buff before anybody's second; no place for a class whose buffs
  replace one another), then group cast, friends, name. `Prompt:PickTop` keeps
  the current person on a tie only while no worse by that order, range
  included (`Reach` in `Prompt/Hold.lua`: a passer-by only remembered gives
  way to one in reach, except under the cursor), and the fight's rota steps
  through the queue as built. A refusal for line of sight or range is a run
  of its own (Queue.lua `WHERE`, 5/15/30 s), never the person's five minutes.
- **A blessing for each class** (`buff.forClass`, CLASS -> buff key; Who to
  buff, under the buff order: `who.classNote`, `classPick`, `classBlessing`,
  `classReset`, for a class whose buffs replace one another): the blessing
  chosen for somebody's class goes to the head of the walk in `PickBuffFor`'s
  exclusive branch (`opts.theirClass`, read by the queue only while a class
  has one) and nothing else changes; never over a pin.
- **Unasked, by default**: `optIn` buffs are off until ticked (Detect
  Invisibility for the group; Shadow Protection on Classic Era, Forever and
  TBC), and Detect Invisibility stays the group's alone (`membersOnly`) until
  *Offer Detect Invisibility to passers-by too* under it is ticked
  (`buff.detectPassers`, off; `ns.PassersToo`, asked by `Castable`,
  `ns.OnlyReachesGroup` and the buff's label); a `returnOnly` buff (Unending Breath there) goes only to a favour's
  giver (`opts.owed`) and to a request by name (`opts.asked`, which a plain
  "buff pls" is not); `buff.skipCasters` is on. A warlock's *Fire Shield from my
  imp on the tank* (`fireshield`: `pet`, `forTank`, `partyOnly`, `optIn`) is off
  too; ticked, it goes only to the party's tank, and only while a pet out knows
  it (`ns.PetCasts`).
- **A refused reading in a battleground match** (Forever and retail keep auras
  secret there, even out of a fight; GitHub issue 29): a refusal says nothing,
  so the walk offers nothing on it. Two things stand in for the reading, both
  only on a refusal and never over a reading the client gives. After your
  death a refusal of your own buff is read as missing until you cast one of
  that family again, or somebody's cast of it lands on you (`ns.GoneWithDeath`;
  `throughDeath` buffs, those that outlast death, are exempt). A cast of yours
  that landed on a team-mate covers a refusal of theirs for the buff's single
  length (`ns.CoveredByCast`, its own clock, no top-up), until they are seen
  dead or the game takes the cast back.
- **Client-specific behaviour** (grep `ns.Flavour.flavour` / `.family`):
  - Forever only: surnames joined with a space (`caps.unitNameIsSurname`);
    the mage's scrolls (Familiar, Weapon imbue: `CAMELOT_OWN`, used with
    `/use item:<id>`); the Reagent Economy perk (`ns.ReagentWaived`);
    group casts reaching the whole party and raid (`groupIsRaid`); the mage's,
    priest's and druid's group casts have no unit target (SpellEffect target
    56), so `UNIT_SPELLCAST_SENT` names nobody (an empty string) and
    `SettlePendingClick` reads that as "would not say"; regional unique names
    in `/w` (Speech.lua asks the client, assumes them on Forever when it will
    not say, and walks the name as Forever's `ExtractTellTarget` does:
    accents and apostrophes are fine); no Blessing of Sanctuary, Omen of Clarity
    passive, Kings and Divine Spirit trained; once a session, for whoever buffs the
    author's character through the prompt, a line in gold, across the screen
    and in the raid warning's lettering under a seal (`Textures/AuthorSeal.tga`,
    `tools/make_author_seal.py`), the level-up sound and a bow, and an addon
    message (prefix `Manners`) that the author's own Manners prints as "X
    buffed you with Manners" (`ns.NoteBuffedAuthor`, `ns.HeardAddonMessage`,
    Clicks.lua; deliberately not in the listings or the changelog).
  - classic family (vanilla, tbc, mists): the combat log is read in addition
    to the aura scan (`ns.combatLogArmed`); never registered on modern clients
    (registration is refused there).
  - modern family, and a classic client whose log was refused: the cast watch
    (`ns.castWatch.armed`, Favours.lua) listens to every unit's
    `UNIT_SPELLCAST_SUCCEEDED`, filtered by a table lookup, to name a favour's
    caster when the aura names nobody (GitHub issue 26). Questions only the game
    can settle: (1) whether Forever 1.60.1 fires it for other players' nameplateN,
    target, mouseover, focus and party tokens at all, with spellID and castGUID
    plain (if not, nothing is named, as before; `/manners debug`'s "casts by other
    players: N seen" tells); (2) whether `nameplateNtarget` resolves (if not,
    every cast has an unknown aim: named only after the window, only with the
    friendly nameplates on, and only when the caster plainly does not freshly wear
    the buff; a client that withholds the answer names nobody, and every landing
    waits for its window, your own casts of the buff counting as another player); (3) the order and gap between the
    caster's cast and UNIT_AURA on you (the 1 s window either side is an
    estimate); (4) whether `expirationTime - duration` is the landing time on
    GetTime's clock; (5) whether one cast's castGUID is the same under every
    token; (6) why Forever's `sourceUnit` is nil with a nameplate up at all (the
    trail lines and the last-favour line show which case); (7) retail 12.x:
    whether a stranger's spellID or GUID is secret in the open world.
  - mists and mainline: a single buff on a group member lands party-wide
    (`wideCasts`), shouts reach 100 yards, their own `rankLevel`; mists' raid
    buff kinds do not stack (`alike`); mainline's own buffs are a rogue's
    poisons (families `lethal` and `nonlethal`, spells), Shadowform, Grimoire of
    Sacrifice, a shaman's imbues per hand (`shamanimbue`, `shamanimbueoff` with
    `shield`) and a paladin's rites (`rite`), and six classes have nothing for
    others. Mists has its own families too (`MISTS_OWN`).
  - one target at a time (`oneTarget`; Earth Shield, Spirit of the Alpha,
    Beacon of Light, Beacon of Faith, Oath of Light, Symbiosis with
    `notOwnClass`, Symbiotic Relationship, Blistering Scales): `Core.lua`
    `Castable` keeps it to your group and to a tank (`ns.IsTankUnit`) while
    none of yours is on anybody (`Queue.lua` `OneTargetHolders`, read once per
    scan), then to a top-up of the one wearing it; a request by name always
    reaches it, "buff pls" never. A paladin's Beacon or Oath is picked apart
    from his `exclusive` blessings (`PickBuffFor`). `ns.OnlyTalentBuffs` tells
    a class whose every buff for others is a talent (the Welcome's "no buff
    learned"; `ns.OnlyOneTarget` gives the greeting its one-target line).
    `apartFrom` keeps a buff off the member who wears that other one of yours
    (Beacon of Faith and of Light), read even while that other buff is
    switched off. A favour from a tank is owed to such a
    class (`ns.CouldOffer` takes the giver's tank role and class, from Sight's
    `seen.tank` and `seen.class`, the combat log's record asking
    `ns.IsTankUnit` instead; given the giver's `name`, it also reads who wears
    yours through `ns.OneTargetHolders`, with its own table, and the favour
    line says when the return waits for it to come free). Retail's Symbiotic
    Relationship is `notSelf`: the druid is never read as its holder. `ns.NoteGave` and `GaveSince` keep one time
    per buff key per name, so on Forever a blessing on your Oath's wearer does
    not hide the Oath. A buff's `group` may hold one partner aura a class
    (Symbiosis), as retail's Blessing of the Bronze does.
  - own-buff flags from round 36: `form` (never offered in another form),
    `needs`/`notWith`, `shield` (waits for a shield in the off hand); from
    round 37, `needsWeapon` (a weapon in that hand: retail's off-hand
    Flametongue) and `shiftsOut` (Mark of the Wild on vanilla and tbc: Moonkin
    Form waits while one is queued, `Queue.lua` `FormWaits`). Round 37's own
    families: `demonicsacrifice` (vanilla, camelot, tbc), `treeoflife` (tbc,
    vanilla), `spiritofthealpha` (vanilla, `tank`). Round 38's family flags:
    `shiftedOut` (the form that waits for a queued `shiftsOut` buff: Moonkin
    Form on Classic Era and TBC, TBC's Tree of Life; Season of Discovery's
    tree has none) and `timed` (a toggle with a timer: Demonic Sacrifice, so
    Diagnostics makes no "no timer" claim); the spell flag `byPet` (an own
    buff whose caster is your pet: TBC's Soul Link). The family flag
    `onceUp` (Automatic reminds only of the one remembered up, nothing before;
    a pick still reminds): Forever's `findtreasure`, a family of its own beside
    `tracking` there because Forever keeps Find Treasure on with a gathering
    tracking (Classic Era and TBC keep it in `tracking`); `ns.SplitFindTreasure`
    in `Core.lua` moves a pick, tick or memory of it off `tracking` once.
    `shoutYards` is read only by `tools/audit_ids.py`. GitHub issue 18's
    spell flags `needsSpell`/`notWithSpell` (a spell id the client must say
    you know, or must not, for the spell to count as known; asked only in the
    probe, so a talent learned counts at the next SPELLS_CHANGED): Forever's
    Demonic Pact (425464) moves Soul Link out of `demonicsacrifice` into a
    family of its own, `soullink` (`pact`; the old family's `splitTo` names
    it for the page), after the sacrifice; Classic Era and TBC are untouched.
    Its family flags `makes` (the key of a family whose items this one's
    spells create: up while one is in the bags or on the hand, Core.lua
    `ReadMakes`; each spell's `items` say which, for Automatic) and `reagent`
    (an item the cast uses up, counted with the bags, `ns.OwnReagentCount`;
    OwnVerdict answers `"reagent"` without one): Forever's `makestone`,
    Create Firestone or Spellstone, `optIn`, under `warlockstone`; each spell's
    `school` (`fire`, `shadow`) is the kind Automatic makes when the talents
    favour one (`Best.Makes`), else the kind last on the weapon. `holds`
    (GitHub issue 32): up while any item of its spells' `items` is in the bags
    (`ReadOwnFamily` through `ns.OwnHeldFirst`; never `anyHeld`, a stone is no
    buff to use), with `reagent` for a Soul Shard: `makehealthstone`, Create
    Healthstone on every client (a shard on Classic Era, Forever and TBC only),
    on by default (no `optIn`), `still`.
  - weapon enhancements (poisons, sharpening stones and weightstones, wizard
    and mana oils, fishing lures), vanilla, tbc, camelot and mists: items from
    the bags, one family per kind and hand (`slot` 16 or 17), the rows in
    `Buffs.lua`'s `ENHANCEMENTS`, each client's own item data (a rogue's
    poisons are items there but spells on mists and retail). Used with
    `/use item:<id>` and `/use 16|17`, settled by the timed self-use
    (`Clicks.lua`, `ENHANCE_SECONDS`), read per hand in `Core.lua`
    (`ReadImbue`). The game's question about replacing an enchant
    (`REPLACE_ENCHANT`) is left to the player: Manners never answers it, never
    calls `C_Item.ReplaceEnchant` and never hides the popup (the test holds it
    to that). A class with nothing learned and one in the bags has a prompt
    (`ns.OwnItemsHeld`). Automatic takes the best item, never the one used
    last (`AutoAnswer` reads `Remembered` only for a family without
    `scroll`): a `ranked` family (oil, lure, warlock's stone, Forever's
    `imbue`) by `Core.lua`'s `Best.Pick`, worth from each row's `oilKind` and
    `tier` (by the role: group role, kept while it reads secret, then class,
    then the tree: Forever's talents, the points spent on Classic Era and TBC
    ahead of their spec index, else the spec on Mists and retail), `bonus` (a lure's
    Fishing) or `school` and `power` (the talents, `Talents.lua`), ties in
    table order, the lean read once under one pcall and kept until the probe
    or a talent event (`ns.ForgetLean`); `Best.Pick` asks for it only when two
    rows are in the bags, `Best.Makes` and the debug line whenever they run; a `byLine`
    family (poison) the kind last on that hand (`line`) at its first ready
    row (`Best.Line`); the rest (stones, the familiar) table order. The side
    tables are in `ENHANCEMENTS` (`OIL`, `LURE`, `STONE_SCHOOL`,
    `POISON_LINE`) and `CAMELOT_OWN` (`IMBUE_SCHOOL`); `/manners debug`'s
    `own lean` line says what was read (`tests/scenarios/autobest.lua`).
  - Well Fed (vanilla, tbc, camelot, mists) and Well-Rested (vanilla and
    camelot, the Cozy Sleeping Bag): `bagged` families in `Buffs.lua` (`food`,
    `rest`), an item from the bags with one switch, off until it is turned on;
    `family.food` alone where only food is meant (the meal in progress).
    Well-Rested is a toggle, never topped up; *Remind me before Well-Rested
    runs out* (`ownBuffs.restedEarly`, off) has `OwnVerdict` read its last
    five minutes as gone.
    A companion pet (`pet`, `Pets.lua`, `Companion.lua`) is a bagged family
    too, on all five clients, with no aura: whether one is out is the pet
    journal or Manners' own count of a bag pet, and where there is a journal
    it is summoned with no press (`OwnVerdict` answers `"journal"`, and
    `Pet:Tick` in the scan does the summon). On Mists and retail the family
    has no bag rows and the journal is all there is (`Pet.journalOnly`):
    never in a pet battle (`ns.PetHold`: `"petbattle"`).
    Flasks, elixirs and scrolls (`Consumables.lua`) are bagged families too,
    flagged `consumable`: `covers` names the class buffs of the same stat that
    hold a scroll back (a rank worth less than the weakest scroll is skipped,
    by `ns.STAT_VALUE`), `flaskFills` (TBC, Mists) lets a flask count for
    both elixir families, `elixir` (Battle Elixir, `slot = "battle"`) and
    `guardianelixir` (`slot = "guardian"`), split by each row's fourth value;
    `scrollSlots` (Mists) makes each scroll take its own slot, covered by and
    covering only that slot's elixirs and scrolls (`slotScrolls` on the
    family). On Classic Era and Forever, whose data names no slot, the one
    `elixir` family is `keep`: *Elixirs to keep up* (`ownBuffs.elixirKeep`,
    `who.own_elixirkeep`) reminds of each ticked elixir in the bags in turn
    (`ns.KeepTicks`, `ReadConsumable`'s `ScanKept`, `AutoAnswer`'s
    `KeepAnswer`), two found not to stack kept as one (`db.char.elixirClash`,
    `ns.NoteElixirClash`); `ns.SplitElixirs` carries the one switch, a
    guardian pick and the memory into the two once a profile (stamp
    `ownBuffs.elixirsSplit`, carried by a settings string). A row's `auras`
    names what a dummy use becomes (Mists' Alchemist's Flask) and `lapses` a
    flask lost on death (the Crystal of Insanity). Retail has the flask family alone, for every class.
    `Core.lua` reads each with `ReadConsumable` (one pcall per family). *Consumables only in dungeons and raids*
    (`ownBuffs.itemsInDungeons`, the key kept from its old name) holds back
    oils, stones, food and these (`ns.OwnItemsWaitForDungeon`; `ownBuffs.foodOutside` lets
    food out, GitHub issue 37). A spell family off
    until it is turned on is `optIn` (a warlock's Detect Invisibility: vanilla,
    camelot and tbc; Mists and retail have no such spell). `isScroll` marks
    every scroll (the stat scrolls, Forever's Familiar and Weapon imbue): the
    *Scrolls* switch under Myself (`ownBuffs.scrolls`, `ns.ScrollsOff`) turns
    them all off and hides their rows, each pick kept. A family reminded
    only while you swim is `swimming` (a warlock's Unending Breath on yourself,
    `selfbreath`, on all five clients, first of a warlock's own, on by default): Core.lua
    `Swimming` reads `IsSwimming()` and holds it two seconds past the last
    stroke (`SWIM_HOLD`), and OwnVerdict answers `"dry"` before any aura read.
    The buff for others is `swimGate` (Unending Breath on every client): with
    `buff.swimOnly[key]` set (*Offer Unending Breath to others only while I am
    swimming*, off by default) `Castable` offers it only while `ns.Swimming`, a
    favour returned (`opts.owed`) and a request by name (`opts.asked`) still going.
    A family cut short by moving is `still` (food, the sleeping bag, a weapon's
    stone, oil, poison or lure, Forever's scrolls, making a warlock's stone; any
    other family when the client gives its use spell a cast time, so a bag pet
    and Mists' armors go by that and a flask never does): Core.lua `Moving`
    reads `GetUnitSpeed` (plain, it rules; secret or missing, the
    PLAYER_STARTED/STOPPED_MOVING word kept by `ns.NoteMoving`) and `IsFalling`,
    holds it `STILL_HOLD` (one second) past the last step, and OwnVerdict
    answers `"moving"` after the mounted, sleeping-bag, pet-hold and journal
    rules; `ns.StillCut(entry, now)` is what the prompt's hold (Hold.lua), the
    consumables button's press (Supplies.lua) and the moving event ask. Off (`ownBuffs.holdMoving`, My own buffs), CutByMoving answers false and nothing is held.
    An own spell's `group` (a shaman's Water Breathing 131 for it, where the
    client has it) is matched through `auraIds` only, never cast, never in
    `OWN_BY_ID`; `tools/audit_ids.py` holds it to `OWN_GROUP_NAMES`.
  - level cap for "Skip players below level": 60, tbc 70, mists and mainline 90
    (Core.lua).
- **Entry kinds on the prompt** (1.11.25). A queue entry was a buff for
  somebody; five flags now mark what else it can be, and every file that
  handles a press asks them before treating it as a buff: `entry.res`
  (Resurrect.lua: a dead member of the group, priority -1, ahead of your
  target), `entry.cure` (Cures.lua: the kind removed, in the person's one
  place in the queue at 1.25), `entry.courtesy` (Courtesy.lua: a plan with its
  `stage`, conjure or trade, under the reason "asked", or "target" for the water
  and food offered to your target unasked, `sources.courtesyTarget`), `entry.ask` (Ask.lua:
  last of everything at 9, a spoken line and no cast) and `entry.pet` with
  `entry.owner` (Queue.lua: a group member's pet, with `sources.pets`,
  targeted by its own name). A sixth, `entry.thank` (ThankPress.lua: a
  thank-you waiting for a press at 2.5, the id of the thank parked, nothing
  armed, filed by `ns.ThankPress.Pressed` at PostClick), came after, and then
  `entry.care` and `entry.bond` (HunterPet.lua: a hunter's pet, under the
  pseudo-names `?pet:<kind>`, armed by `ns.BeastArm`, filed by
  `ns.Beast.Pressed`; a right-click or *Let it go* is `ns.Beast.Dismiss`, which
  never blocks a person, lists anybody or turns *Myself* off).
  Each brings its own answers to `ns.BuffInfo`
  (`buff.res`, `buff.courtesy`, `buff.askInfo`, a cure's own), its own reason
  line (Prompt/Paint.lua `ReasonText`) and tooltip (Prompt/Button.lua), and
  its own filing at PostClick (Prompt/Press.lua): none settles a favour, goes
  in the ledger or is counted as a buff given. Nothing is said with a
  resurrection, a cure or a pet's buff (Speech.lua), and a pet counts for no
  group cast (GroupBuffs.lua). None but a pet's buff is offered or armed in a
  fight, the pull's own repaint included (`Prompt.armedForFight`), so none is
  frozen on the button or handed to the fight's rota. `ns.CanCastAnything` is
  true for a class with a resurrection (`caps.res`), a cure switched on
  (`ns.CuresWanted`) or asking switched on (`ns.AskLive`), so a class with no
  buff for others can still have a prompt. A gathering tracking
  (`ns.GATHERING`) is never reminded of in a battleground or an arena
  (`OwnVerdict` answers `"battle"`, `ns.InBattleground`); one to fight with,
  picked or Automatic's last, still is.
