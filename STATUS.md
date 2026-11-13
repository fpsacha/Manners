# Where this stands

Working notes. Not part of the shipped addon — `.pkgmeta` leaves it out. How to
work on the project: `CLAUDE.md`. How to release: `RELEASING.md`.

## State

1.11.16 is released. Unreleased after it, all three asked for on CurseForge:

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

**Launch day (WoW Forever, 2026-11-05): run one command.** Log in on the
character that has the Manners macro (or any character: the test makes a
temporary macro and deletes it), out of combat, with something targeted if you
like, and type `/manners selftest launch` (or, from 1.11.11, press *Check how
Manners draws in this game* on *Diagnostics*). About half a second later the report
opens in the box under Reporting a bug on Diagnostics (a line in chat says the
counts); click in the box, select all, copy, paste it back. The first line after
the header is the summary (`Launch checks: N PASS, N CHECK, N FAIL -- look at:
...`), then one line per item with the game's own answer: the Morpheus font
file, masks, clipping, `REPEAT` tiling, animations, each of the twelve looks put
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
light on Glass, Framed and Minimal lean on (CHECK or FAIL there means they draw
from the wrong end or not at all); Glass over a snowfield for the edge light
(never over 0.40) and the wave from the icon's right edge, which the renderer
understates; Toast's hammered gold and rope ring; Forge's slot, sparks along
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

**The new looks in the game.** Ribbon, Letter and Leather (1.10.0), Forge, the
glass and tooltip-rim rebuild of Glass and Framed, Toast's re-gilding and the
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
`tests/baselines/<X>.txt`.

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
cost about 30 s.

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
- On Mists a scroll family reads as up under any flask or any elixir, even one
  holding only the other elixir slot (a fourth Consumables.lua column would tell
  them apart). It is wrong only by saying nothing.
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
the full check-up shows the switch and the last thank made or skipped and why.
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
