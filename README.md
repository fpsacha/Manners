# Manners

**One click to buff back whoever just buffed you, and nearby players missing
yours.**

[![CI](https://github.com/fpsacha/Manners/actions/workflows/ci.yml/badge.svg)](https://github.com/fpsacha/Manners/actions/workflows/ci.yml)
[![CurseForge](https://img.shields.io/badge/CurseForge-Manners-f16436)](https://wow.curseforge.com/projects/1705364)
[![Wago](https://img.shields.io/badge/Wago-Manners-c1272d)](https://addons.wago.io/addons/rNkgzlNa)
[![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

<img src=".github/media/manners-prompt.png" alt="The prompt: a dark panel naming Elowen Thistledown, who buffed you, with a gold glow round the spell icon" width="640">

A priest buffs you in passing. By the time you have picked them out of a dozen
nameplates, they are gone.

Manners notices, works out what you owe them, and puts one button on screen.
Click it, they get their buff, and your own target is handed straight back. It
also offers your group, people who ask for your buff in chat, and nearby
players who are missing it, so being the person who buffs strangers costs one
click instead of a minute of squinting at names.

Built for **WoW Forever** (Interface 16001), and shipped for that client only.

## How sure is it

This is a **beta**. The code is finished and the test suites are green, but
**one class has actually been played**. Everything else is tested against a
mock client, and a mock agrees with whoever wrote it.

| Class | How far it has been taken |
|---|---|
| **Mage** | cast in game, repeatedly, against real players |
| Priest, Druid, Paladin, Warlock, Warrior | implemented, spell data corroborated against other addons on this client, every cast path exercised by the suite, **never cast in game** |
| Hunter, Rogue, Shaman | nothing to cast on another player, and Manners says so rather than looking broken |

Getting one spell to cast on this client took ten attempts. Every class uses
that same path, but "the tests pass" is not "somebody used it". If you play
anything but a mage, please
[say how it went](https://github.com/fpsacha/Manners/issues/new/choose),
either way: **"it worked"** is the report that moves a class off this list.

Retail, Mists Classic and Classic Era are implemented too, but nobody working
on this can launch those clients, so they are not shipped.

## Installing

- **[Wago](https://addons.wago.io/addons/rNkgzlNa)**, and through it
  **WowUp**: search *Manners* and install. WowUp dropped CurseForge when
  Overwolf cut off third-party clients, so Wago is the one it reads.
- **[CurseForge](https://wow.curseforge.com/projects/1705364)**, and the
  CurseForge app.
- **By hand**: take a zip from
  [Releases](https://github.com/fpsacha/Manners/releases) and unzip it into
  `Interface/AddOns`.

All three carry the same build from the same tag.

> **Do not install from a clone of this repository.** `Libs/` is deliberately
> not committed (the libraries are fetched at build time), so a zip made from
> a checkout has none of them and will not load. Use a release.

## First steps

1. **Put the prompt on a key.** Bind one under
   **Options > Keybindings > Manners** ("Buff the prompted player"), or make a
   macro with `/manners macro` (or *Create the macro* on the General tab) and
   drag it onto a bar. The macro is `/click MannersPrompt LeftButton 1`; the
   trailing `1` matters, because the secure button only casts on the way
   down.
2. **Look at it.** `/manners test` shows a sample prompt. `/manners unlock`
   lets you drag it, and it locks again when you let go. The *Put it* setting
   on the Prompt tab has three ready-made places.
3. **Open the options** with `/manners`, or click the minimap button.

The first login on each character says what the addon does and what it needs
from you, once, and shows the prompt so you can see where it is.
`/manners welcome` says it again.

## What it does

<img src=".github/media/manners-reasons.png" alt="Five prompts, each a different colour: your target, somebody who buffed you, somebody who asked in chat, a group member and a passer-by" width="640">

Everybody who could use your buff is queued, in this order:

1. **Your target**, when the game can confirm they are missing it. A guess
   does not get to jump the queue.
2. **Somebody who buffed you.** Spotted by watching your own buffs appear and
   reading who cast them, which works on strangers too, as long as the game
   can still name them for you. The favour survives a reload or a
   disconnect.
3. **Somebody who asked for it in chat**, if you switch that on (see below).
4. **Your party or raid**, anyone missing your buff.
5. **Passers-by** missing your buff, seen through nameplates, your target,
   your focus and your mouseover.

It skips the dead, the out-of-range, anyone you just tried, and anyone the buff
does nothing for (Arcane Intellect is wasted on a rogue).

**On the prompt:** left-click (or your key) casts. **Right-click** skips that
person for now without marking their favour repaid. **Shift-right-click** puts
them on the never-offer list.

**Never offer.** People on the list are never offered anything, as passers-by
or as group members. Somebody on it who buffs you is still offered the favour
back, because returning a favour is the point; shift-right-click them again to
let that favour go. The list is on the *Who to buff* tab, and `/manners never`
and `/manners allow <name>` work from chat. In a fight the prompt cannot move
off the person it is showing, so a press still casts at them until the fight
ends, and chat says so.

**Friends and guildmates first.** A friend (Battle.net friends included) or
guildmate goes ahead of the other passers-by, or of the rest of your group. It
only changes the order: people who buffed you still come first, and somebody
known to be out of range never leads over somebody in range.

**People who ask me for it.** Off by default, because reading chat is
guesswork. Somebody who asks for your buff in `/say`, `/yell`, group chat or a
whisper ("int pls", "fort?", "can I get motw", or the spell's name in your
language) is offered it for the next minute, after people who buffed you and
before your group. Nothing is ever said back. What counts:

- eight words at most, naming the buff as a whole word, with nothing like
  *no* or *not* in it;
- a please, a question mark, an opener like *can I* or *anyone*, or nothing
  but the buff's name;
- beside a nickname (*int*, *fort*) or *buff*, only small words like *me*,
  *get* or *pls*, so "int the healer" asks for nothing;
- words English uses for other things (*might*, *mark*, *wisdom*, *spirit*,
  *shadow*) need a please or to stand alone, and never count in group chat;
- nobody of your own class counts as asking (another mage saying "anyone need
  int?" is offering it), and nothing said in a fight counts unless it was
  whispered. A request still waiting when a fight starts waits until it ends.

They must still lack the buff and be somebody the game can see.
`/manners debug` lists the requests still standing.

**Snooze and Not while mounted.** `/manners snooze` hides the prompt for 15
minutes; `snooze 5`, `snooze 1h` (up to four hours) or `snooze off` for your
own. The minimap menu and the General tab have it too. Favours are still
noticed while snoozed. A `/reload` ends a snooze, and one started in a fight
takes effect when the fight ends. *Not while mounted* (When tab, off by
default) keeps the prompt away while you ride and brings it back when you get
off. Press the key while either is hiding the prompt and chat says which.

## The favour ledger

<img src=".github/media/manners-ledger.png" alt="The favour ledger: today's count and all-time totals, then rows of favours still owed, returned and let go, and buffs given to the group and to strangers" width="640">

Who buffed you, with what and when, whether you returned it, and who you
buffed without being asked, newest first. Today's count ("Returned 12 of 14
favours today") and the all-time totals sit at the top, then tabs for
everything, favours, and buffs you gave. A favour you did not return says why:
the time ran out, nothing you cast helps them, or you put them on the
never-offer list. Hover a favour still owed and it says whether the prompt will
offer it, and when.

`/manners ledger`, a shift-click on the minimap button, or *Open the ledger* on
the General tab. It keeps the last 200 entries per character; *Clear* empties
the list and today's count but keeps favours still owed and the all-time
totals. It opens in combat and never says anything in chat.

## The prompt's look

Three looks (glass, framed and minimal), your own colours and fonts, and
LibSharedMedia support. When a buff lands, a ring pops out of the icon and
light crosses the panel; a refused one gives the text a small shake. Somebody
who buffs you makes the panel catch the light, and the prompt fades out after
your last buff. The icon shows the global cooldown sweep, like an action bar.

**Text follows the panel.** Leave the text colour at white and it turns dark
by itself on a light panel colour, and class-coloured names that would vanish
on it are darkened too. Any other text colour is used exactly as picked. The
minimal look outlines its text so it reads over snow as well as in the dark.

**A colour-blind palette.** *Reason colours*, under Prompt > Style, swaps the
four reason colours for pale yellow, orange, sky blue and violet, which stay
apart under protanopia and deuteranopia.

<img src=".github/media/manners-palette.png" alt="The same prompt and list in the standard reason colours and in the colour-blind friendly set" width="640">

Set *Effects* to *Calm* for none of that movement. *Stay quiet in combat* keeps
the prompt dimmed and still for a fight.

## The minimap button

A click opens the options, a shift-click the ledger, and a middle click
switches Manners on or off. Right-click for a menu: on or off, snooze (5
minutes to an hour), who is next (skip one, or never offer them anything), the
ledger, a preview, the prompt's lock, position, sound and effects, the chat
lines, and your profiles when you have more than one. In a fight the entries
that would move the prompt wait until it ends.

The icon dims while snoozed and goes darker still while off. A broker display
shows how many people who buffed you are still waiting. The same launcher is in
the **addon compartment** under the minimap, so hiding the button loses
nothing.

## The options

Seven tabs. Most settings explain themselves; this is what their tooltips no
longer have room for.

**General.** On or off, *Create the macro*, snooze buttons (5, 15 and 30
minutes), the minimap button, and *Tell me in chat what the addon is doing*:
a line in your own chat when somebody buffs you, when a favour is repaid, and
when a click fails. Use it to tell "the buff was never noticed" from "it was
noticed but they could not be reached"; nothing from it is ever said to
anybody else. Also *Share settings* (below) and the ledger.

**Who to buff.**

- *Buff to cast*: automatic, or pin one spell. A pinned spell is the only one
  considered, so if you have not learned it there is nothing to fall back to.
  Where a class has several buffs, automatic offers whichever one they are
  missing, in list order: a priest walks Fortitude, then Divine Spirit, then
  Shadow Protection.
- *Automatic for paladins*: blessings overwrite one another, so anybody
  already carrying one of yours is left alone rather than handed a different
  one. The pick is Wisdom for anyone with a mana bar and Might for everyone
  else. Under *Always offer*, or where the game hides which blessing they
  carry, the first blessing that suits them is offered, and it can replace
  yours.
- *Sources*: people who buffed you, your party and raid, nearby players, and
  people who ask.
- *Whoever I have targeted comes first*: with it off, or under *Always
  offer* (nothing is read then), your target is ranked by why they are on the
  list like anybody else. A targeted stranger whose buffs cannot be read
  counts as a passer-by, so a friend goes ahead of them.
- *How near a passer-by has to be*: *anywhere I can cast* (about thirty
  yards), *nearby* (about ten, the default) or *right beside me* (about five).
  Only passers-by are measured: somebody who buffed you was close enough a
  moment ago, and your group and whoever you targeted or focused were picked on
  purpose. The game gives no exact distance, so this lands on the nearest step
  the client can measure (LibRangeCheck, or the client's interact distance);
  where nothing can measure, everybody in casting range is offered.
- *Only offer passers-by in cities and inns*: off by default. Out in the
  world strangers are left alone; everybody else is still offered.
- *Drop people who are probably gone* and *Let them go after* (45 seconds):
  somebody who buffed you is rarely your target or on a nameplate, so all that
  is known is that they were in range when they buffed you. The clock runs
  from their buff, because nothing can see a player walk off.
- *Minimum level*: read off the unit, so somebody known only by name (the
  usual case for a passer-by who buffed you) cannot be checked and is offered
  anyway.

**When.**

- *If they already have the buff*: leave them alone, offer a top-up once
  their timer drops below a number of minutes, or always offer. Somebody who
  buffed you is offered the favour back whichever you pick.
- *Remember a buff for* (120 seconds): somebody the game can still see stays
  on the prompt this long; somebody it cannot see is let go sooner, when *Let
  them go after* is shorter.
- *Remember them across a reload*: for a favour noticed a minute before a
  disconnect. The clock keeps running while you are away.
- *Wait before offering the same spell again*: per spell, so after
  Fortitude the next scan can still offer Divine Spirit. A right-click skip
  blocks the whole person for the same time.
- *Not while mounted*: dead, on a flight path or in a vehicle the prompt
  already stays away, because nothing can be cast there.

**When you click.**

- *Hand my target back afterwards*: the prompt targets everybody it buffs,
  group members too, because a named conditional (`[@name]`) only reaches your
  own party or raid and most people on the prompt are passers-by. With this
  on, the macro ends with `/targetlasttarget`, except outside a fight for
  somebody already your target, who stays targeted. The macro armed when a
  fight starts keeps `/targetlasttarget` for everybody until it ends.
- *Say something*: off by default, and then only when returning a favour
  unless you say otherwise. Four sets of lines (Roleplay, Polite, Cheeky, Just
  their name), editable, and a fifth, *In character: your race and faction*:
  over a thousand lines, picked when you click to fit your people, your class,
  your faction and the moment -- thanks, an answer to a request, an offer, a
  line for your group -- and what is happening: the spell you give, a trade
  for the one they gave you, how often you two have swapped, an inn or a
  dungeon, the hour, somebody of your own class or people. It does not repeat
  itself, and a context the game will not reveal is left out. The line rides in the macro the button runs, because
  the game refuses addon-sent `/say` and `/yell` outside instances, which is
  exactly where somebody buffs you in passing. How long a line may be depends
  on the name and on whether your target is handed back. An empty box goes
  back to the chosen set, so switch *Say something* off to stay quiet.

**Prompt.** Preview, lock and position, look and colours, sound, text and
icon.

- *Effects*: on *Full*, the ring pops out of the spell icon only if the icon
  is shown, and the panel catches the light unless *When someone buffs you* is
  *Nothing*. With the icon hidden, no stripe and no light (Effects on *Calm*,
  or the minimal look), *When someone buffs you* has nothing to do and is
  greyed out. The cooldown sweep has its own switch under *Icon and queue*.
- *Stay quiet in combat*: the icon also shows no cooldown sweep for the fight.
- *Reason colours*: the target colour appears only while *Whoever I have
  targeted comes first* is on and *If they already have the buff* is not
  *Always offer*.

**Diagnostics.** What your class has and whether the game lets addons read
each buff, what has broken this session, and *Copy for a bug report*. "This
client doesn't know spell N" means Manners cannot see that version on anyone,
which only affects telling whether somebody already carries it.

**Profiles.** The usual Ace profiles; the minimap menu switches between them.

## Sharing settings

`/manners export` puts your settings in a box under *Share settings* on the
General tab, as one line of text to keep or hand to somebody. Paste one into
the box beside it, or after `/manners import`, to use it. A chat line holds
only 255 characters, so a longer string has to go in the box. Only what
differs from the defaults is written, a damaged line is refused before
anything changes, and `/manners import undo` puts your own settings back.

A pasted line never carries whether Manners is on, the lock, where the prompt
sits, the click log or the minimap button. It never switches speaking on, and
while you have it on, what you say and where stays yours.

## Commands

```
/manners                    the options (also /manners options)

Everyday
/manners on | off           switch it on or off
/manners snooze [min|off]   hide the prompt for 15 minutes, or as long as you say
/manners test               preview the prompt, for styling
/manners ledger             the favour ledger
/manners never [name]       who is never offered anything, or put somebody on it
/manners allow <name>       take somebody off that list

Setting it up
/manners welcome            what it does, and the one thing it needs from you
/manners macro              make a /click macro for your action bar
/manners unlock             drag the prompt; it locks again when you let go
/manners lock               lock it again (an unlocked prompt never casts)
/manners restore            switch handing your target back on or off
/manners verbose            switch the chat lines about who buffed you on or off

Sharing settings
/manners export             your settings as one line of text
/manners import <text>      use a line somebody exported
/manners import undo        put your own settings back

When something is wrong
/manners debug              what your class and this build allow
/manners errors             the last few things that broke, if any did
/manners dev                tools for testing the addon on this client: the click log, try, look and forms
/manners help               this list, grouped the same way
```

`/mnr` works in place of `/manners` in all of them. A word it does not
recognise suggests the closest command, or lists them all.

`/manners dev` lists four tools for finding out what this client allows. Only
somebody chasing a problem needs them, so they are kept out of the help, but
they work when typed directly and bug reports quote them:

```
/manners clicks             log what the button does when clicked
/manners try <macro>        run any macro text from the prompt
/manners look [unit]        every answer the game gives about a unit
/manners forms              example macros to try
```

## Languages

<img src=".github/media/manners-languages.png" alt="The prompt and its list in German, Russian and Simplified Chinese" width="640">

English, German, Spanish (Spain and Mexico), French, Italian, Korean,
Brazilian Portuguese, Russian, Simplified and Traditional Chinese, whichever
your client runs in. Slash commands are English in all of them.

## Which buffs each class offers

| Class | Buffs offered |
|---|---|
| Mage | Arcane Intellect |
| Priest | Power Word: Fortitude, Divine Spirit, Shadow Protection |
| Druid | Mark of the Wild, Thorns |
| Paladin | Wisdom, Might, Kings, Salvation, Light, Sanctuary |
| Warlock | Unending Breath |
| Warrior | Battle Shout (your own party only) |

Individual buffs can be switched off on the *Who to buff* tab, or one pinned so
it is the only thing ever cast. Battle Shout reaches your own party (in a raid,
your own subgroup) and nobody else, so a warrior outside a group is offered
nobody. That is deliberate rather than a fault.

## Why a button and not automatic

Blizzard does not let an addon cast a spell on its own: casting is protected
and only runs from a hardware event. This has been true since patch 2.0 and no
addon gets around it.

So Manners does everything except the keypress. It decides who deserves the
buff and writes that decision onto a secure button; the *game* casts when you
click. That split is deliberate on Blizzard's part, and it is why the prompt
freezes during combat: whoever it shows when a fight starts stays on it until
the fight ends.

## Notes on WoW Forever

This client differs from other flavours in ways that are not documented
anywhere, and each one took a live test to find.

**Conditional targeting does not work.** `[@unit]`, `[@Name]`, `[@focus]`,
`[@mouseover]` and the secure `unit` attribute all fail, silently or with "You
have no target". A bare `/cast` with no target works fine, so this is
specifically about naming another unit. Two of those would not have worked
anywhere: `[@Name]` resolves only for somebody already in your party or raid on
every flavour, and `[@nameplateN]` resolves on none of them. Which is why the
macro is the same everywhere — targeting the person by name, casting, and
handing your target back is the only shape that reaches a passing stranger on
any client. The macro uses `/target`, which matches a name *prefix*, so
offering Mort could find Mortimer standing next to him. Where the client names
who received the spell, the addon notices the cast landed on somebody else and
says so; this client usually doesn't, and then the favour is counted as repaid
on the strength of the `/target` line alone. `/targetexact` is
detected (`/manners debug` reports it) but not used yet: it finds nobody at all
if the name is one character out, and the surname spelling the addon assembles
has not been checked against it in game.

**Secure buttons must register for mouse down.** Registering up only leaves the
click arriving and the attributes correct while the game casts nothing and
reports nothing. Every secure button that works here registers `"AnyDown"`.

**Unit power is a secret value** for players outside your group, so "does this
person have mana" cannot be read directly. Class is used instead, which is
accurate for every vanilla class.

**`UnitName` returns a surname, not a realm**, in its second value. Joining
them with a hyphen produces names that no targeting call resolves, so here the
two are joined with a space.

**Nameplate unit tokens are secret** when read off the frame via
`C_NamePlate.GetNamePlates()`. The token passed to `NAME_PLATE_UNIT_ADDED` is
not, so that is what to track.

**There is no combat log.** Registering `COMBAT_LOG_EVENT_UNFILTERED` is
refused here, as it is on retail 12.0. So a favour is spotted by watching your
own buffs appear and reading `aura.sourceUnit`, which is a unit token:
somebody with no nameplate who is not your target cannot be identified at all.
Nothing can be done about that from an addon here.

## Reporting a bug

Open an issue from
[the templates](https://github.com/fpsacha/Manners/issues/new/choose):
*Something misbehaved* for a bug, *A class cast, or did not* for how a class
other than Mage went. The Diagnostics tab's *Copy for a bug report* button
gives you the build, what this client allows, the settings that matter and
anything that has broken, ready to paste. `/manners debug` and `/manners
errors` say much of the same in chat.

## Building a release

Full checklist in [RELEASING.md](RELEASING.md).

`Libs/` is deliberately not in the repository: `.pkgmeta` declares all 14
libraries as build-time externals, so the packager fetches current upstream
copies under their own licences.

**A zip built from a clone therefore has no libraries and will not load.**
Write the notes under `## Unreleased` in `CHANGELOG.md`, set the version, push
master, and once CI is green tag it and let the workflow build it:

```
python tests/setversion.py X.Y.Z-beta.N
git commit -am "Manners X.Y.Z-beta.N"
git push origin master
git tag vX.Y.Z-beta.N && git push origin vX.Y.Z-beta.N
```

A tag pushed without notes, or pushed together with master before CI has
passed, fails its build and stays on origin; RELEASING.md says how to take it
off.

`.github/workflows/release.yml` runs the test suites, fails the build if any
check has stopped being able to detect the fault it exists for, then packages
and publishes a GitHub release and uploads to **CurseForge and Wago** from the
one tag. A destination needs both a token in the repository secrets and a
project id in the toc; missing either skips that upload in a way that reads
exactly like success, so the build log names which half is absent.

The listing text is in `.github/`: see [.github/DESCRIPTION.md](.github/DESCRIPTION.md)
for which file is pasted where.

## Tests

```
python tests/validate.py       structure, syntax, Lua 5.1 limits and version consistency
python tests/runharness.py     load the addon against a mock client
python tests/runscenarios.py   adversarial scenarios
python tests/selftest.py       confirm the suites can still go red
```

All four run on every push via `.github/workflows/ci.yml`, and again as a gate
before any release. See `tests/README.md`.

## Listing images

The CurseForge icon and the screenshots are generated, not captured — see
`tools/README.md`. The screenshots are the addon itself, loaded on the mock
client, put into each scene through its own entry points and drawn by
`tools/render_prompt.py` and `tools/render_ledger.py`. CI refuses to draw one
that would show something other than what its caption says, so they cannot
advertise a prompt the addon does not build.

## Licence

MIT, see `LICENSE`. Bundled libraries keep their own terms — see
`THIRD-PARTY-NOTICES.md`. LibSharedMedia-3.0 is LGPL v2.1.
