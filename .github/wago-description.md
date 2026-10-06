**One click to buff back whoever just buffed you, and nearby players missing yours.**

![The prompt: a dark panel naming Elowen Thistledown, who buffed you, with a gold glow round the spell icon](https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/manners-prompt.png)

Somebody buffs you in passing; Manners puts them on one button, and a click buffs them back and hands your own target straight back. It also offers your group, people who ask for your buff in chat, and nearby players missing it -- and you, when you are missing your own buff or one your class casts only on itself. In dungeons and raids it keeps your group topped up, with one group cast for a whole party when you carry the reagent.

Built for **WoW Forever** (Interface 16001) and **Classic Era** (Interface 11509).

- **Who comes first:** your target, then your group at a ready check or just back from the dead, then people who buffed you, people who asked in chat, you, the rest of your group, and passers-by. They are colour-coded, with a colour-blind friendly set.
- **Buff myself:** missing your own buff, or one your class casts only on itself -- a mage's armor, a priest's Inner Fire, a warlock's Demon Armor, a paladin's aura or Righteous Fury, a hunter's aspect, a shaman's shield -- and "You" comes up on the prompt; one press puts it on you. Pick your armor, aura or aspect, or let *Automatic* follow the one you had up last. Only when none of a kind is up, never in a fight, and not in cities and inns unless you want it. Hunters and shamans now get a prompt of their own. On WoW Forever, a mage is reminded of familiar and weapon imbue scrolls too.
- **Group buffs:** with Arcane Brilliance, a Prayer, Gift of the Wild or a Greater Blessing learned and its reagent in your bags, 3 or more of a party who need your buff get one cast instead of one each. The prompt says who it is for ("Your party", "Group 2", "Every Warrior") and counts your reagents.
- **Dungeons and raids:** tick only the **raid groups you buff**, **save mana** below a level you set, and no "buffed you" chat line inside a raid.
- **Never offer:** shift-right-click somebody on the prompt and they are never offered anything again, unless they buff you.
- **Friends and guildmates first** among passers-by and within your group.
- **Never flags you for PvP:** while you are not flagged, players flagged for PvP are not offered, since buffing them would flag you too.
- **People who ask me in chat** (off by default): "int pls", "fort?" or "can I get motw" in say, yell, group chat or a whisper puts them on the prompt for a minute.
- **How near is near:** limit passers-by to about ten yards, or to cities and inns.
- **Snooze** with `/manners snooze`, and **hide the prompt while you're mounted**.
- **The favour ledger:** who buffed you, whether you returned it, and who you buffed unasked. `/manners ledger`.
- **Titles for your manners**, from *Well Brought Up* at 10 favours returned to *The Very Soul of Courtesy* at 1,000, shown in the ledger with your progress and in the minimap tooltip.
- **Six looks** -- Luxe, Toast, Arcane, Glass, Framed and Minimal -- effects you can calm down, text that stays readable on any panel colour, LibSharedMedia fonts and sounds.
- **Minimap button and addon compartment**, with a right-click menu for snooze, preview, who's next and more.
- **Share settings** as one line of text with `/manners export` and `/manners import`.
- **Say something in character** (off by default): over two thousand funny lines, picked for your race, class and faction and for the moment -- the spell you give, what they gave you, how often you two swap, where you are, the hour -- in every people's own voice, never repeating.
- **Whisper them** as the channel for your line, so only the person you buff hears it, and an optional `/thank` emote when somebody buffs you (off by default).
- **A self-test:** `/manners selftest` checks Manners against your game and gives you a report to paste into a bug report.
- **Nine languages:** English, German, Spanish (Spain and Mexico), French, Italian, Korean, Brazilian Portuguese, Simplified and Traditional Chinese.

**Getting started:** `/manners` opens the options on **Start here**. The first time, two questions set you up -- who to buff, and whether your character talks. After that, four numbered steps: who to buff (one quick choice), a key or a macro for your bars, where the prompt sits, and whether to say thanks. `/manners help` lists every command.

Blizzard does not let an addon cast on its own, so Manners does everything except the keypress: it decides who deserves the buff, and the game casts when you click.

Free, MIT licensed. Full documentation and bug reports on [GitHub](https://github.com/fpsacha/Manners).
