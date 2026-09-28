**One click to buff back whoever just buffed you, and nearby players missing yours.**

![The prompt: a dark panel naming Elowen Thistledown, who buffed you, with a gold glow round the spell icon](https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/manners-prompt.png)

Somebody buffs you in passing; Manners puts them on one button, and a click buffs them back and hands your own target straight back. It also offers your group, people who ask for your buff in chat, and nearby players missing it.

> **Beta.** Only Mage has been played in game. Priest, Druid, Paladin, Warlock and Warrior are implemented and tested against a mock client, but nobody has cast with them yet. If you play one, please [say how it went](https://github.com/fpsacha/Manners/issues/new/choose): "it worked" is the most useful report.

Built for **WoW Forever** (Interface 16001) only.

- **Who comes first:** your target, then people who buffed you, people who asked in chat, your group, and passers-by. Each has its own colour, with a colour-blind friendly set.
- **Never offer:** shift-right-click somebody on the prompt and they are never offered anything again, unless they buff you.
- **Friends and guildmates first** among passers-by and within your group.
- **People who ask me for it** (off by default): "int pls", "fort?" or "can I get motw" in say, yell, group chat or a whisper puts them on the prompt for a minute.
- **How near is near:** limit passers-by to about ten yards, or to cities and inns.
- **Snooze** with `/manners snooze`, and **Not while mounted**.
- **The favour ledger:** who buffed you, whether you returned it, and who you buffed unasked. `/manners ledger`.
- **Three looks**, effects you can calm down, text that stays readable on any panel colour, LibSharedMedia fonts and sounds.
- **Minimap button and addon compartment**, with a right-click menu for snooze, preview, who's next and more.
- **Share settings** as one line of text with `/manners export` and `/manners import`.
- **Say something in character** (off by default): over a thousand funny lines, picked for your race, class and faction and for the moment -- the spell you give, what they gave you, how often you two swap, where you are, the hour -- in every people's own voice, never repeating.
- **Nine languages:** English, German, Spanish (Spain and Mexico), French, Italian, Korean, Brazilian Portuguese, Simplified and Traditional Chinese.

**Getting started:** bind a key under Options > Keybindings > Manners, or `/manners macro` for a macro on your bars. `/manners` opens the options and `/manners help` lists every command.

Blizzard does not let an addon cast on its own, so Manners does everything except the keypress: it decides who deserves the buff, and the game casts when you click.

Free, MIT licensed. Full documentation and bug reports on [GitHub](https://github.com/fpsacha/Manners).
