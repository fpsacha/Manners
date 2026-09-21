**One click to buff back whoever just buffed you — and nearby players missing
yours.**

A priest buffs you in passing. By the time you have picked them out of a dozen
nameplates, they are gone.

Manners watches for it. It reads who buffed you, works out what you owe them,
and puts a single button on screen. Click it, they get their buff, and your
previous target is handed straight back.

It also offers nearby players who are missing yours — not to optimise a raid,
just so buffing a stranger costs one click instead of a minute of squinting at
names.

### What it does

- **Somebody you targeted yourself** → outranks everyone, including a favour
  owed — but only when the game will confirm they are actually missing it. A
  guess does not get to jump the queue.
- **Someone buffs you** → they go to the top and the prompt pulses until you
  have returned it. Works on strangers who are not in your group, and the debt
  survives a reload or a disconnect.
- **Your party or raid** → anyone missing your buff.
- **Passers-by** → nearby players missing it, seen through nameplates, your
  target and your mouseover.

It skips the dead, the out of range, anyone you just tried, and anyone the buff
does nothing for — Arcane Intellect is wasted on a rogue. Right-click the
prompt to skip somebody without marking their favour repaid.

**If they already have it**, you choose: leave them alone, offer a top-up once
their timer runs low, or always offer.

### Say something

Optional, and off until you turn it on. Four sets of lines, loaded with one
click and editable afterwards:

> May the Light watch over you, Ardith.
> The arcane favours you, Ardith.
> A boon for the road, Ardith.
> Winds at your back, Ardith.

Roleplay, Polite, Cheeky, or just their name.

### Classes

| Class | Buffs |
|---|---|
| Mage | Arcane Intellect |
| Priest | Power Word: Fortitude, Divine Spirit, Shadow Protection |
| Druid | Mark of the Wild, Thorns |
| Paladin | Wisdom, Might, Kings, Salvation, Light, Sanctuary |
| Warlock | Unending Breath |
| Warrior | Battle Shout (party only) |

Where a class has several, the prompt offers whichever one they are actually
missing — a priest walks Fortitude, then Divine Spirit, then Shadow Protection,
and somebody who already has the first is still offered the second rather than
disappearing off the list. You can switch individual buffs off, or pin one and
only ever cast that.

Paladins are the exception, because blessings overwrite one another: holding
any one of yours counts as covered, and the automatic pick is Wisdom for
anyone with a mana bar and Might for everyone else.

### How much of this has been tested

**Mage has been used in game, repeatedly, against real players.**

The other five classes are implemented, their spell data is corroborated
against other addons running on this client, and every cast path is exercised
by an automated test suite — but nobody has cast with them yet. Treat them as
unproven and please report anything that misbehaves.

Saying so because getting a single spell to cast on this client took ten
attempts. The same path is used everywhere, but "the tests pass" is not the
same as "somebody used it".

### Why a button, and not automatic

Blizzard does not let an addon cast a spell on its own. That has been true
since patch 2.0 and no addon gets around it.

So Manners does everything except the keypress: it decides who deserves the
buff, and the game casts when you click. Bind a key under **Game Menu → Key
Bindings → Manners**, or use the **Create the macro** button in the options to
put it on your bars.

### Usage

```
/manners           options
/manners unlock    drag the prompt — it re-locks when you let go
/manners test      preview, for styling
/manners debug     what your class and this build allow
/manners errors    anything the addon caught and carried on from
```

Three looks, full colour and font control, LibSharedMedia support, profiles,
and a minimap button.

### On WoW Forever

Built for Interface 16001. This client withholds a great deal from addons:
there is no combat log, unit power and identity can come back as secret values,
and conditional targeting — `[@unit]`, `[@mouseover]`, `[@focus]` — does not
resolve at all.

Manners works around each of those. Buffing somebody means targeting them for
an instant, because that is the only route this client allows; your previous
target is restored immediately, and that can be switched off.

The README documents each restriction, since none of them appear to be written
down anywhere else.

Free, MIT licensed, [source on GitHub](https://github.com/fpsacha/Manners).
