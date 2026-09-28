**One click to buff back whoever just buffed you, and nearby players missing yours.**

![The prompt: a dark panel naming Elowen Thistledown, who buffed you, with a gold glow round the spell icon](https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/manners-prompt.png)

A priest buffs you in passing. By the time you have picked them out of a dozen nameplates, they are gone.

Manners notices, works out what you owe them, and puts one button on screen. Click it, they get their buff, and your own target is handed straight back. It also offers your group, people who ask for your buff in chat, and nearby players missing it, so buffing a stranger costs one click instead of a minute of squinting at names.

> **Only Mage has been played in game.** Priest, Druid, Paladin, Warlock and Warrior are implemented and tested against a mock client, but nobody has cast with them yet. If you play one, please [say how it went](https://github.com/fpsacha/Manners/issues/new/choose): **"it worked"** is the report that moves a class off the untested list.

Built for **WoW Forever** (Interface 16001), and shipped for that client only.

### Who it offers, in this order

![Five prompts, each a different colour: your target, somebody who buffed you, somebody who asked in chat, a group member and a passer-by](https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/manners-reasons.png)

1. **Your target**, when the game can confirm they are missing it.
2. **Somebody who buffed you.** Works on strangers, and the favour survives a reload or a disconnect.
3. **Somebody who asked for it in chat**, if you switch that on.
4. **Your party or raid**, anyone missing your buff.
5. **Passers-by** missing your buff: nameplates, your target, focus and mouseover.

It skips the dead, the out of range, anyone you just tried, and anyone the buff does nothing for (Arcane Intellect is wasted on a rogue). Right-click the prompt to skip somebody for now; shift-right-click to never offer them anything.

- **Never offer.** A list of people who are never offered anything, unless they buff you, because returning a favour is the point.
- **Friends and guildmates first.** Battle.net friends included, they go ahead of other passers-by and the rest of your group.
- **People who ask me for it.** Off by default. Somebody who says "int pls", "fort?" or "can I get motw" in /say, /yell, group chat or a whisper is offered it for a minute. Only short messages that plainly ask count, and nothing said in a fight unless it was whispered. Nothing is ever said back.
- **How near is near.** Arcane Intellect reaches thirty yards, which in a city is everybody on screen, so passers-by can be limited to *nearby* (about ten yards, the default) or *right beside me*, or offered only in cities and inns.
- **If they already have it**: leave them alone, offer a top-up when it runs low, or always offer.
- **Out of the way when you want it.** `/manners snooze` hides the prompt for 15 minutes (or `snooze 5`, `snooze 1h`, `snooze off`), and *Not while mounted* keeps it away while you ride.
- **Thank them with an emote.** Off by default. When somebody buffs you and you have something to give back, you `/thank` them -- never in a fight or an instance, and at most once per person every five minutes. New, and not yet tried in game.

### The favour ledger

![The favour ledger: the title your manners have earned, today's count and all-time totals, then rows of favours still owed, returned and let go, and buffs given to the group and to strangers](https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/manners-ledger.png)

Who buffed you and with what, whether you returned it (and if not, why), and who you buffed without being asked, with today's count ("Returned 12 of 14 favours today") and your all-time totals. `/manners ledger` or shift-click the minimap button.

Favours you return also earn you a title, from *Well Brought Up* at 10 to *The Very Soul of Courtesy* at 1,000. It sits at the top of the ledger with how far you are from the next ("37 of 50 to Courteous"), and in the minimap tooltip. The only thing the ledger ever says in chat is a new title, once.

### The prompt

Three looks (glass, framed, minimal), your own colours and fonts, and LibSharedMedia support. When a buff lands a ring pops out of the icon and light crosses the panel; a refused one gives a small shake. The icon shows the global cooldown sweep like an action bar. Set *Effects* to *Calm* if you would rather it kept still.

Leave the text colour at white and it turns dark by itself on a light panel. *Reason colours* under Prompt > Style has a colour-blind friendly set: pale yellow, orange, sky blue and violet.

![The same prompt and list in the standard reason colours and in the colour-blind friendly set](https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/manners-palette.png)

### Say something

Optional, and off until you turn it on: a line when you buff somebody, from four sets (Roleplay, Polite, Cheeky, or just their name) that you can edit. It goes out through the button's macro, so it counts as you talking. Say it, yell it, tell your group, or *whisper them* so nobody else hears; a whisper goes only when there is no doubt who it reaches.

Or pick **In character: your race and faction**: over a thousand lines, and the one you say is chosen when you click, to fit your people, your class and the moment. Thanks when you return a favour, an answer when somebody asked, an offer to a stranger, something warmer for your group -- and lines that only work right now: about the spell you are giving, a trade for the one they gave you, the third swap today, an inn, a dungeon, the small hours, somebody of your own class. Every race has its own voice (a dwarf's brogue, an orc's *Lok'tar ogar*, a Forsaken's gallows humour), and it does not repeat itself. In all nine languages.

> *"Most kind, Elowen. You've lifted me from 'deceased' to 'mildly deceased'."* -- a Forsaken, returning a favour

### The minimap button

Click for options, shift-click for the ledger, middle-click to switch Manners on or off. Right-click for a menu: snooze, preview, who's next (skip them or never offer them), lock and position, sound and effects, chat lines and profiles. It is in the addon compartment too, so hiding the button loses nothing.

### Getting started

Bind a key under **Options > Keybindings > Manners**, or type `/manners macro` to make a macro for your bars. The first login on each character says what it does and shows you the prompt once; `/manners welcome` says it again.

```
/manners            options
/manners test       preview the prompt
/manners unlock     drag the prompt; it locks again when you let go
/manners snooze     hide the prompt for 15 minutes, or as long as you say
/manners ledger     the favour ledger
/manners never      who is never offered anything; add a name to put them on it
/manners export     your settings as one line of text, to keep or share
/manners import     use a line somebody exported (import undo puts yours back)
/manners debug      what your class and this build allow
/manners help       every command, grouped
```

`/mnr` works as well. Profiles are supported, and a pasted settings line never switches on speaking to other players or moves your prompt.

### Classes

| Class | Buffs |
|---|---|
| Mage | Arcane Intellect |
| Priest | Power Word: Fortitude, Divine Spirit, Shadow Protection |
| Druid | Mark of the Wild, Thorns |
| Paladin | Wisdom, Might, Kings, Salvation, Light, Sanctuary |
| Warlock | Unending Breath |
| Warrior | Battle Shout (your own party only) |

Where a class has several, the prompt offers whichever one they are missing: a priest walks Fortitude, then Divine Spirit, then Shadow Protection. Paladin blessings overwrite one another, so anybody holding one of yours is left alone, and the automatic pick is Wisdom for mana users and Might for everyone else. You can switch buffs off, or pin one and only ever cast that. Hunters, rogues and shamans have nothing to cast on another player, and Manners says so.

### Languages

![The prompt and its list in German, French and Simplified Chinese](https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/manners-languages.png)

English, German, Spanish (Spain and Mexico), French, Italian, Korean, Brazilian Portuguese, Simplified and Traditional Chinese, whichever your client runs in.

### Why a button, and not automatic

Blizzard does not let an addon cast a spell on its own, and has not since patch 2.0. So Manners does everything except the keypress: it decides who deserves the buff, and the game casts when you click.

On WoW Forever conditional targeting (`[@unit]`, `[@mouseover]`, `[@focus]`) does not resolve, so buffing somebody means targeting them for an instant. Your previous target is handed straight back, and that can be switched off.

### Bugs and reports

Use [the issue templates on GitHub](https://github.com/fpsacha/Manners/issues/new/choose). The Diagnostics tab has a *Copy for a bug report* button that gathers the build, what your client allows and anything that has broken.

Also on [Wago](https://addons.wago.io/addons/rNkgzlNa), which is the one WowUp reads. Free, MIT licensed, [source on GitHub](https://github.com/fpsacha/Manners).
