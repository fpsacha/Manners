# CurseForge listing copy

Paste-ready. Keep it matching the toc: it says Mage is tested and the rest are
not, and the listing should not quietly claim more.

---

## Summary (the one-line field, shown in search results)

This appears under the name in search results and in WowUp. Lead with what it
does; a reader scanning twenty addons gives it about two seconds.

**Recommended:**

> One click to buff back whoever just buffed you — and nearby players missing
> yours.

Alternates, depending on the tone you want:

| | |
|---|---|
| plainest | Buff people back. One click, no hunting through nameplates for the name. |
| function first | Shows you who buffed you and who nearby is missing your buff. One click to sort it. |
| shortest | Never forget to buff somebody back. |
| a little warmer | For people who like buffing strangers, and keep losing them in the crowd. |

An earlier draft read *"Someone buffs you in passing — Manners notices, works
out what you owe them, and puts one button on screen. You click it."* It tells
a story instead of saying what the addon does, and puts the function in the
third clause. Not that.

## Description (the project page body)

A priest buffs you in passing. By the time you've found them in a sea of
nameplates they're gone.

**Manners notices.** It reads who buffed you, works out what you should give
back, and puts one button on your screen. You click it, they get their buff.

It also offers **nearby players who are missing yours** — not to optimise a
raid, just so being the person who buffs strangers costs you one click instead
of a minute of squinting at nameplates.

### What it does

- **Someone buffs you** → they go to the top of the queue, tagged as a favour
  owed, and the prompt pulses until you've returned it. Works on strangers who
  aren't in your group.
- **Your party or raid** → anyone missing your buff.
- **Passers-by** → nearby players missing it, seen through nameplates, your
  target and your mouseover.

Skips the dead, the out-of-range, anyone you just tried, and anyone the buff
does nothing for — Arcane Intellect is wasted on a rogue.

**If they already have it**, you choose: leave them alone, offer a top-up once
their timer runs low, or always offer.

### Classes

| Class | Buffs |
|---|---|
| Mage | Arcane Intellect |
| Priest | Power Word: Fortitude, Divine Spirit, Shadow Protection |
| Druid | Mark of the Wild, Thorns |
| Paladin | Wisdom, Might, Kings, Salvation, Light, Sanctuary |
| Warlock | Unending Breath |
| Warrior | Battle Shout (party only) |

Paladins get an automatic pick: Wisdom for anyone with a mana bar, Might for
everyone else. Any class can pin one buff instead.

### How much of this has been tested

**Mage has been used in game, repeatedly, against real players.** The other
five classes are implemented, their spell data is corroborated against other
addons running on this client, and every cast path is exercised by an automated
test suite — but nobody has cast with them yet. Treat them as unproven, and
please report anything that misbehaves.

Being straight about this because getting a single spell to cast on this client
took ten attempts; the same path is used everywhere, but "it compiles and the
tests pass" is not the same as "somebody used it".

### Why it's a button and not automatic

Blizzard doesn't let an addon cast a spell on its own — that's been true since
patch 2.0 and no addon gets around it. So Manners does everything except the
keypress: it decides who deserves the buff, and the game casts when you click.

### Usage

```
/manners           options
/manners unlock    drag the prompt (it re-locks when you let go)
/manners test      preview, for styling
/manners debug     what your class and this build allow
```

Bind a key under **Game Menu → Key Bindings → Manners**, or use the
**Create the macro** button on the options page to make a `/click` macro for
your bars.

### Notes

Built for **WoW Forever** (Interface 16001). This client withholds a lot from
addons — there is no combat log, unit power and identity can be secret values,
and conditional targeting (`[@unit]`) does not resolve at all. Manners works
around each of those; the README documents them, since none appear to be
written down anywhere else.

Buffing somebody means targeting them for an instant, because that is the only
route this client allows. Your previous target is handed straight back, and
that can be turned off.

Free, MIT licensed, source on GitHub.
