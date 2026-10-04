# Changelog

## Unreleased

- `/manners selftest` checks Manners against your game and gives you a
  report to paste. `/manners check` does the same.
- **Two questions to start with.** The first time you open the options on a
  new profile, Start here asks *Who do you want to buff?* and *Should your
  character talk?*, with the same choices as its quick settings, and *Done*
  sets them as those do. *Skip* leaves everything as it is. Neither comes
  back on that profile, and a profile you already had is never asked.
- **Friendly nameplates and the thank-you.** A stranger is shown to Manners
  mostly by their nameplate, so with the game's friendly nameplates off their
  line was left out without a word. What I say now says so while you speak
  with them off, with a *Show friendly nameplates* button that turns them on
  (not in a fight; nothing changes unless you click it). The first line left
  out for that reason in a session says so in chat, once.

## 1.6.5

- **The thank-you line is only said when the buff will land.** Out of range,
  on cooldown, short of mana, or when Manners cannot tell -- a passer-by your
  cursor has left for the prompt, somebody no nameplate or target shows, a
  range the game will not give -- the buff press goes out silently, rather
  than thanking somebody over "Out of range.". The tooltip quotes a line only
  for somebody Manners last saw in range.
- **The Fantasy line set is now Azeroth**, with new lines drawn from
  Warcraft lore. A phrase box still holding the Fantasy lines gets the new
  ones.
- **In character's lines were reviewed:** stale jokes, and talk about the
  game rather than the world, were rewritten. A box saved with the old
  examples is still In character. On a client in another language, a
  rewritten line is left out until it is translated.
- **In character sounds like your own people.** A thank-you, the line heard
  most and the only one with "Only when I buff someone back" on, is now in
  your people's voice about two times in three, up from under one in three:
  a Forsaken sounds Forsaken, a dwarf like a dwarf. Asking, offering and
  group lines lean the same way. Humans, dwarves, night elves, gnomes, orcs,
  the Forsaken, tauren and trolls have 184 new lines between them, a few
  lines any people could say were retired, and Magni is the living king of
  Ironforge rather than a diamond. A Soulstone, Fear Ward, Water Walking or
  Detect Invisibility is thanked for what it does. On a client in another
  language, the new people's lines join once they are translated.
- **Group buffs in a raid count the whole raid.** On WoW Forever, Arcane
  Brilliance, the Prayers and Gift of the Wild reach everybody in your party
  and raid. The prompt now offers one cast for the raid ("Your raid") once
  enough of the raid need it, rather than counting each raid group apart and
  walking you through single casts, and holds it back while anybody in the
  raid it would reach is flagged for PvP: not somebody out of sight or dead,
  though a hunter feigning death still counts.
- **Prayer of Fortitude from level 48 to 59** is offered with Holy Candles in
  your bags, the reagent its first rank takes. It used to look for Sacred
  Candles, so it never came up.
- **Reagent Economy works with group buffs.** With this WoW Forever Legacy
  perk, which removes vendor reagents from your class abilities, the
  Prayers, Arcane Brilliance, Gift of the Wild and the Greater Blessings are
  offered even with no candles, powder, berries or Symbols in your bags. The
  tooltip says no reagent is needed. Start here and Who to buff no longer
  say group buffs are off because a reagent is missing.
- **Imbue Spellbreak's placeholder name** in German, Spanish, Brazilian
  Portuguese, Korean and both Chinese now uses the game's own words. You see
  it until the game has loaded the scroll.
- **Blessing of Salvation is offered only to your party or raid**, since the
  game will not let you cast it on anybody else. A passer-by wearing another
  paladin's blessings is offered Light instead.
- **Skip my own class** now skips priests and paladins who can give
  themselves Divine Spirit or Kings: every priest and paladin trains them on
  WoW Forever.
- **Druids are no longer reminded of Omen of Clarity**, a passive on WoW
  Forever with nothing to cast.
- **Blessing of Sanctuary is gone from a paladin's list**, as it is from WoW
  Forever. `/manners debug` and Diagnostics no longer report its spells as
  missing.
- **A Fear Ward, a Soulstone, Water Walking or Detect Invisibility** cast on
  you now counts as a favour, to return or to `/thank`.
- **Somebody breathing water from a shaman's Water Breathing** is no longer
  offered Unending Breath, and a shaman's Water Breathing on you counts as a
  favour.
- **"ub" in chat** asks a warlock for Unending Breath.
- **A warrior's thank-you goes with Battle Shout only within its 20 yards.**
  The shout is still offered to party members a little further off, but the
  line is said only where something can tell they are close enough to hear
  it: close enough to trade, or LibRangeCheck says so.
- **"por favor", "per favore" and "s'il vous plaît"** count as a please when
  somebody asks for a buff in chat, as "porfa" and "svp" already did. So do
  "¿int?", "int pls…" with the one-character ellipsis, and "int？" typed on a
  Chinese keyboard.
- **Luxe with a light panel colour:** the reason tag's words, the count and
  lines such as "held -- in combat" are light again on the tag's own dark
  fill. They were taken dark to suit the panel, dark on dark.
- **Toast shows its key only when a press casts something:** not over a
  panel held in a fight with nothing armed, and still while a fight's macro
  goes on casting after you unlock the prompt.
- **The preview's count** covers every row it lists below the panel. It
  said 2 over three to five rows.
- **A scroll's imbue that runs out under a wizard oil is offered again.**
  Once the game has shown the two on your weapon together, the oil alone no
  longer counts as the weapon seen to. Until then an oil still counts, so
  nobody is asked to put a scroll over one.
- **A scroll picked above your level gives way to Automatic** while you
  carry one of that kind you can use, and takes over again once you reach
  its level: an alt sharing the main's profile, with Cat Familiar picked and
  Rats in the bags, is offered the Rat.
- **Imbue Spellbreak ranks with Lesser Flame**, whose +4 Fire it puts on.
  Automatic chose it over Flame, Frost and the other scrolls that do more.
- **Another paladin's aura on you, or another hunter's Aspect of the Wild or
  Trueshot Aura:** Automatic offers the next one you know that is not on you
  already, or nothing, rather than a second copy that would not stack. Your
  own copy is read as yours even when the game lists theirs first.
- **Lightning Shield, Shadowguard and Inner Fire nearly spent after a
  fight** are offered as a top-up with *Offer a top-up when it runs low*: the
  shields on their last charge, Inner Fire on its last five. The prompt says
  how many charges are left.
- **No "buffed you" line in a battleground, an arena or any raid group**,
  where everybody buffs everybody at once. The favour is still noticed and
  offered.
- **A warrior's shout that lapses between pulls** no longer brings a "buffed
  you" line and a `/thank` every time: once in half an hour for a group
  member. While they wear your own buff with more than the top-up time left,
  their favour is not offered back: refreshing it repays nothing.
- **A lower rank no longer counts as having the buff.** A level 60 wearing
  Fortitude's second rank from a low-level priest is offered yours, and a
  priest wearing it is reminded of her own. A rank that is the best your cast
  could land on a low-level player still counts.
- **Nobody on your `/ignore` list** is thanked, spoken to or offered a favour
  back, and passers-by on it are not offered. Group members on it still are.
- **With *Ignore shields, heals and trinket procs* off**, a paladin's aura,
  a hunter's aspect or Trueshot Aura no longer counts as a favour every time
  you walk back into its range.
- **A group cast that returns a favour thanks the person it repays**, even
  when somebody else in the party is its target. After a ready check it is
  aimed at the one you owe.
- **One line per person a minute.** Fortitude, then Divine Spirit on the
  same person says the line once, not twice. A thank-you for a favour always
  goes out.

## 1.6.4

- **Pressing the prompt for a weapon imbue puts it on your weapon.** The
  scroll waited for you to click a weapon, so the press did nothing and the
  next one said "That item is not a valid target". It now goes straight on
  the weapon in your main hand, as a poison or oil macro does.

## 1.6.3

- **The Weapon imbue reminder no longer asks again while an imbue is on.**
  It could not see a scroll's imbue on your weapon, so it kept asking you to
  put one on. It now sees it, and with top-ups on asks again only as it runs
  low. An oil on your main hand still counts; an enchanter's permanent
  enchant does not.
- **With no weapon in your main hand,** `/manners debug` and Diagnostics now
  say so. They used to say your imbue scroll did not fit the weapon in your
  main hand.

## 1.6.2

- **Changing page while typing in a box** left the old page drawn, and
  clickable, on top of the new one. It now clears away.
- **A slider or arrow beside a box you had typed in** no longer jumps back
  when that box lets go of the keyboard, and a slider whose mouse release
  went missing follows the setting again.
- **Long dropdowns scroll** instead of running off the screen: fonts and
  sounds from a big media pack, or many profiles.
- **Binding a key straight after typing in the search box** binds it, rather
  than typing the key into the box.
- **Other addons' Profiles pages are left alone.** Manners' share-as-text
  boxes and intro were showing up on every Ace3 addon's Profiles page.
- **A rogue or hunter has *Put these back to default* on What I say.**
- **A pasted settings string no longer switches on /thank** without a word;
  it says so and leaves it off.
- `/manners macro` clears Start here's "No key yet" line at once.
- **`/manners import undo` always puts your settings back.** With a stray
  carriage return in your phrase box, the undo was refused and the pasted
  settings stayed, and your own `/manners export` could not be imported.
  Both work now, and so does a string 1.6.1 exported from such a box.
- **The options window opens even if its saved place is damaged.** A place
  the game cannot put a window at, in a damaged or hand-edited saved file,
  left you with the old options dialog at every login. The window now opens
  in the middle of the screen.
- **Party and Raid speak only in a party or a raid.** With *Where to say it*
  on Party or Raid, the line went out while you were in no party (or no
  raid), reached nobody, and the game answered every press with "You aren't
  in a party." Out of one, the buff now goes out with no line, and the line
  comes back as soon as you join.
- **Skip my own class works for paladins.** With it on, another paladin from
  level 26 up was offered nothing at all, not even Kings, which it never
  skips. He is offered Kings now, and a lower-level paladin still gets your
  better Wisdom.
- **Asking for a buff they already wear no longer hides them.** Somebody who
  asked for a buff that somebody else gave them first was left off the prompt
  for the rest of that minute, whatever else they lacked. They are offered
  the rest, as if they had not asked.
- **A mage's imbue is topped up by its twin.** Spellbreak and Lesser Flame put
  the same enchant on your staff: with the one you used last gone from your
  bags, the other now tops it up, where nothing was offered until it wore off.
- **No line in a fight.** Every press in a fight repeats the macro set when
  it began, so the line went out again on each press, even after the favour
  was returned. The buff still goes out, and the line comes back when the
  fight ends.
- **No thank-you to somebody who has just died.** A press in the moment the
  prompt still showed them said the line while the game refused the buff.
- **Nobody is owed or buffed as "Unknown".** A player whose name the game
  had not loaded yet was filed under that name: owed for their buff,
  offered ahead of the real person for ten seconds, and a press at them
  targeted nobody.
- **Your own buff is not cast again while the game hides it**, as it can in
  a battleground. A buff Manners was not allowed to see read as missing, so
  every press cast it again.
- **A prompt with nothing left to cast is disarmed.** When the game briefly
  reported no spells known, the prompt hid but its key still cast at the
  last person on it, switched off or snoozed, and through the next fight.
- **Manners works with the game's old-API fallbacks switched off**
  (`/console loadDeprecationFallbacks 0`). It read every class as knowing
  no spells, and did nothing.
- **The ledger's "today"** no longer counts favours written while your
  computer's clock ran ahead, on every day until that date came round.
- **A damaged colour in your saved settings is repaired at login**, where it
  broke the prompt's look at every login and on a switch to that profile.
- Less work in busy places: a chat line in Russian, Korean or Chinese, with
  *People who ask me in chat* on, no longer costs hundreds of comparisons;
  nor do the people who asked while they stand near; nor a raid lying dead.
- Toast and Arcane no longer measure the name and the count again on every
  repaint.

## 1.6.1

- **The options window no longer stays see-through.** After a change on
  *Look* it fades so you can see the prompt, and it could stay faded until
  your next click. It now comes back by itself.
- **/thank people who buff me works on every class**, as somebody asked on
  CurseForge. A rogue or a hunter, with no buffs to give, can now thank
  whoever buffs them: their *What I say* page holds that one switch. On every
  class it now also thanks for a buff you could not have returned, and no
  longer needs *People who buff me* on, so the switch is never greyed out.
  The rest is as before: never in a fight or an instance, once per person
  every five minutes, and only class buffs. A class with buffs of its own can
  untick *Ignore shields, heals and trinket procs* on *When to offer* to have
  heals thanked too, and that box no longer waits for *People who buff me*
  either.
- **No /thank while you are hiding**: not in stealth or Shadowmeld, where it
  would give you away to everybody near, and not while you feign death.
- `/manners debug` shows the /thank on every class, and the bug report on
  *Diagnostics* says whether it is on.
- **A mage's scrolls are reminders too**, as somebody asked on CurseForge.
  Under *Who to buff* > *Myself*, *Familiar* reminds you when no familiar is
  with you and a Rat, Frog or Cat Familiar scroll is in your bags, and
  *Weapon imbue* when nothing is on your main hand and you carry an imbue
  scroll that fits it: Lesser Flame on a staff, Chillknife on a dagger, and so
  on. A wizard oil counts as something on it. One press uses the scroll, with
  its own icon on the prompt; if moving cuts its three-second use short, it is
  offered again a moment later. *Automatic* takes the one you used last, or else
  the best your level and weapon allow. Both show only while you carry such a
  scroll, and as with your other buffs, never in a fight, and not in cities
  and inns unless you tick that.

## 1.6.0

- **A new options window.** Manners has a window of its own in place of the
  old tabs: eight pages down the left (Start here, Who to buff, Who to skip,
  When to offer, What I say, Look, Profiles and Diagnostics), and every
  setting in one place only. `/manners` and the minimap button open it on the
  page you used last, and it remembers where you put it.
- **Start here is two steps:** who to buff, already answered, and putting it
  on a key. *Show me the prompt*, *Snooze* and *Manners is on* sit at the top
  of the window, on every page.
- **A line under the top of the window says when the prompt will not do what
  you expect:** switched off, unlocked (with *Lock it* right there), snoozed,
  nothing it can offer, or kept away while you ride. A red dot beside a page
  points at something to fix there, such as no key yet.
- **Search.** The box above the pages finds a setting by its name, its
  tooltip or one of its choices, capitals or not, in every language Manners
  speaks, and takes you straight to it.
- **Who to skip has a page of its own:** the skip switches and the
  never-offer list, which now has an X beside each name to take it off. Under
  *Skip players flagged for PvP* you can see who it is holding back right now.
- **The Advanced tab is gone.** The favour settings are on *When to offer*,
  and the exact position and the prompt's wording on *Look*. Fine-tuning sits
  in folded sections at the foot of each page; a gold dot on one means
  something in it has been changed.
- **Put these back to default resets the page you are on**, and keeps where
  the prompt sits, the lines you wrote and the never-offer list.
- **Changes on Look show on the real prompt:** the window fades while you drag
  a slider, and for a moment after any other change, so you can see the
  prompt behind it.
- *When I buff someone* now leads *What I say*, above the switches it sets.
  The ledger opens on top of the options instead of closing them, and the
  game's **Options > AddOns > Manners** has a button that opens the window.

## 1.5.4

- **Skip my own class when they can cast it too** (Who to buff, under Who to
  skip; off unless you tick it). A mage can give themselves Arcane Intellect,
  so another mage is left out -- unless they are too low a level for the rank
  you cast, and then they still get yours, which is better. Somebody who
  buffed you, asked, or you targeted is always offered, and talent buffs
  such as Divine Spirit or Kings are never skipped this way.

## 1.5.3

- **Tracking is one of your own buffs now.** Find Herbs, Find Minerals, Find
  Treasure, a hunter's tracks, Sense Undead and Sense Demons drop when you die;
  Manners now reminds you to put yours back on, under Who to buff > Myself >
  *Tracking* -- Automatic picks the one you had on last. As with your other
  buffs, not in a fight, and not in cities and inns unless you tick that.

## 1.5.2

- **Toast, redone.** In the game it had a glaring bright line round the banner
  and a heavy square frame with a blue glow round the icon. It is now a quiet
  warm banner: a thin frame of old, matt gold, a round medallion with a slim
  gold ring and the reason colour as a dark enamel band, and no light left
  glowing once it has arrived.
- The minimap button now has a place of its own on the rim. It used to sit
  on the spot every addon gets by default, right on top of other buttons
  (Questie's, for one), so you saw theirs and got Manners' tooltip. A button
  you have dragged stays where you put it.

## 1.5.1

- **The new looks read properly in the game.** Luxe's reason tag could be
  white on white (a passer-by's "needs Arcane Intellect"), Toast put gold text
  on a gold banner, and Arcane laid light over the spell icon. Now the spell
  icon is drawn clean in all three -- only a ring around it -- the text always
  sits on a dark ground, and Luxe's tag and count are dark with the reason
  colour round the edge. The count no longer sits on the icon.
- **Glass is the default look again** while the new looks settle in. If you
  picked Luxe, Toast or Arcane yourself, you keep it.
- **"Say a line when I buff someone" now speaks every time you buff somebody.**
  "Only when I buff someone back" was on underneath it by default, so buffing
  a passer-by said nothing. It is off by default now; the two thank-you
  choices on Start here still switch it on.
- **In character shows far more of your lines.** The box on What I say now
  holds about 24 of your own character's lines instead of 8, and the note
  above it says how many the set really has -- over 2,400. Your saved set is
  updated when you log in; lines you wrote yourself are never touched.

## 1.5.0

The prompt gets three new looks, the options open again, and a big pass of
fixes and trimming makes Manners lighter on your game.

### Three new looks

- Pick one under Look > Style > *Panel style*, beside Glass, Framed and
  Minimal:
  - **Luxe:** a slim dark card with a stripe in the reason colour, a rounded
    icon in a ring, and the reason written as a small tag.
  - **Toast:** a warm banner with a gilded medallion round the icon; the time
    left to return a favour burns along its bottom edge as an ember.
  - **Arcane:** smoked glass with a rim lit in the reason colour, the icon in a
    slowly turning circle of runes, and a keycap showing the key you bound.
- **Luxe is the new default.** If you never picked a look, you now see Luxe;
  pick Glass again under Look > Style to go back. A look you chose yourself is
  kept.
- In the new looks the result of a click replaces the second line -- "buffed",
  "could not buff" -- and the name stays where it is.
- They keep the reason colour in a fight while the icon greys, and honour
  Calm, the colour-blind palette, your colours, fonts and size, the count, the
  list above or below, the second line and icon rounding.

### Fixed

- **The options would not open** ("AceConfigRegistry-3.0: ... width:
  expected a string or number"), from 1.1.2 on. The buttons and drop-downs
  are still sized to their words, now in a way the options library accepts,
  and slider and key binding labels are no longer cut off either ("Top up when
  less than this is l...").
- The prompt now moves on as soon as something better comes up. Before, it
  could stay on the person you had just targeted away from, on your old target
  after you cleared it (even with somebody who buffed you waiting), or on
  somebody whose favour had run out.
- You are no longer offered a buff you do not have the mana to cast: a mage low
  on mana kept getting an Intellect prompt that failed with "Not enough mana".
  Buffs you can still afford, like your armor, are still offered.
- A party or raid member the game cannot see (still in town while you are
  inside) is no longer offered, even if they buffed you or asked. They are
  offered again once they are back in sight.
- Buffs you were already wearing no longer show up as new "buffed you" favours
  when a fight ends.
- One Battle Shout now returns the favour to everybody owed in your party who
  was close enough to hear it, not only the person it was aimed at.
- Buffing yourself now always hands your target back, even with "Hand my
  target back" off -- unless you had yourself targeted.
- "Give this character its own settings" no longer wipes the settings a
  character already has. Back on a shared profile, the button reads "Go back
  to this character's own settings" and returns you to them as you left them.
  When another character uses this character's settings, Start here says so.
- Hunters and shamans now get the Advanced tab for their own prompt, "Play a
  sound" works for them, and options about favours from others are hidden for
  classes nobody can owe one.
- Pasting settings no longer switches "Tell me in chat" back on.
- {class} in the prompt wording shows the class in your game's language
  ("Priester") instead of "PRIEST".
- Right-clicking the prompt in a fight now says the next press still casts at
  that person until the fight ends; after a failed press the message names the
  group spell when the prompt has moved on to one.
- "Nothing you cast is any use to them" is now quiet in raids and dungeon
  fights, like every other "buffed you" line, and in character a party member
  you have targeted hears group lines rather than a stranger's "for the road".

### Lighter on your game

- The scan of who is around does far less work: in a 40-player raid, 22
  protected calls per pass instead of 161; in a busy city, 9 instead of 89; a
  ready check, 6 instead of 143. About a third less memory churn in raids.
- In a fight, your own buffs are read once per scan (about 2.5 times a second)
  however often they change, instead of on every change -- this takes most of
  the work off the busiest moments. A "buffed you" line for a buff that lands
  mid-fight can come up to one scan later; the favour is kept all the same, and
  a buff that runs out and is put straight back is still noticed.
- A long "never offer" list no longer slows the scan in a crowd, group buffs in
  a raid read each member once per pass, and other players' spell casts are no
  longer delivered to Manners at all.
- `/manners debug` shows how many times your auras changed this session and
  how many reads that took.

## 1.4.0

Buffing somebody flagged for PvP flags you too. Manners now keeps them off the
prompt while you are not flagged yourself, as a player asked.

- **Skip players flagged for PvP**, on by default under *Who to skip* on the
  *Who to buff* tab. While you are not flagged, nobody flagged is offered
  anything: not a favour back, a request from chat, your group, a passer-by
  or your target.
- While you are flagged yourself, as in a battleground, they are offered as
  before. The one exception is while your own flag is running out: buffing
  somebody flagged would start the five minutes again, so they stay off the
  prompt until it has run out.
- A group spell or a shout lands on everybody it reaches -- your party, your
  raid group, or for a Greater Blessing the whole class -- so one flagged
  person there holds it back, and everybody else is offered one at a time.
- If somebody gets flagged while they are on the prompt, it moves on at once,
  even with your cursor on it, and a click outside a fight never casts at
  them.
- A favour from somebody flagged stays owed, and is offered back if their
  flag drops before the favour runs out. The chat line and the ledger say so.
- `/manners debug` and the *Diagnostics* tab name who is being held back for
  PvP, and `/manners look` shows a player's PvP flags.

## 1.3.0

*In character* more than doubles: from about a thousand lines to over two
thousand, in every people's own voice, and in all nine languages.

- **Forsaken first.** Nearly four times as many lines, from new angles --
  the Dark Lady, the apothecaries, Undercity's sewers, bits falling off,
  bats, eternity's boredom -- and a handful heard only in Undercity itself.
  *"Repaid at once. We Forsaken never carry debts. They rot."*
- **Every other people** roughly doubles: thanks, answers, offers, lines for
  your own kind and for your group, and more for the hours each people keeps.
- **More for the moment:** your class, the spell you are giving, what they
  gave you, the third swap today, a city, the wild, a dungeon, a battleground,
  the small hours, and the class of the person you are helping.
- **Your own people speak up more.** A character now sounds like their people
  more often, and a thank-you sounds like a thank-you rather than a remark
  about the spell.
- A translation that has not arrived yet is never said: on a client in
  another language, a line without a translation is left out rather than
  spoken in English.

## 1.2.0

Manners 1.2 looks after you too, as somebody asked on CurseForge. When you
are missing your own buff, or one your class casts only on itself -- a mage's
armor, a priest's Inner Fire, a paladin's aura, a hunter's aspect -- "You"
comes up on the same prompt, and one press puts it on you. Where your class
has a choice, such as a mage's armors, pick the one you want, or leave it on
Automatic and it follows the one you had up last. And hunters and shamans,
who have nothing to give anybody else, now get a prompt of their own.

### Your own buff, on yourself

- **"You" on the prompt.** When you are missing the buff you give others --
  Arcane Intellect, Fortitude, Mark of the Wild, a blessing -- the prompt
  offers it to you, with "your own Arcane Intellect" under it. With *Offer a
  top-up when it runs low*, also when yours is running out.
- A press casts it on you and hands your target straight back, as it does for
  anybody else. Nothing is said, and nothing goes in the favour ledger.
- **Where you come in the queue:** behind your target, your group at a ready
  check or just back from the dead, people who buffed you and people who
  asked; ahead of the rest of your group and passers-by.
- On by default: *Myself, when I'm missing my own buff*, under the new
  **Myself** heading on Who to buff. Right-click "You" to skip it for now;
  shift-right-click switches it off, and chat says where to switch it back on.
- On Start here, *Only people who buff me* now switches Myself off, and the
  other three choices switch it on. If you picked *Only people who buff me*
  before 1.2, pick it again (or untick Myself) to keep yourself off the
  prompt.
- *Save mana* never holds back your own buffs: below the floor you are still
  offered, along with people who buffed you or asked, and the tooltip,
  `/manners debug` and the setting itself say so.
- In a party you count towards a group buff, and the group cast covers you.
- A paladin already wearing one of their own blessings is not offered another
  on top of it.
- A warrior's Battle Shout already covers the warrior, and nobody needs
  Unending Breath on dry land, so neither is offered to you.
- The line under "You" can be reworded on Advanced: *Reason text: my own
  buff*.

### Your class's own buffs

The buffs your class casts only on itself, shown under Myself once you have
learned them:

- **Mage:** Frost Armor (Ice Armor from level 30) or Mage Armor.
- **Priest:** Inner Fire, and Touch of Weakness and Shadowguard if you have
  learned them.
- **Warlock:** Demon Skin (Demon Armor from level 20).
- **Paladin:** an aura (Devotion, Retribution, Concentration, or Shadow, Frost
  or Fire Resistance) and Righteous Fury.
- **Hunter:** an aspect (Hawk, Monkey, Wild or Beast; Cheetah and Pack count
  as up) and Trueshot Aura.
- **Shaman:** Lightning Shield or Water Shield.
- **Druid:** Omen of Clarity.

You are offered one at a time, your buff for others first: a mage missing
both gets Arcane Intellect, then the armor. Learn Ice Armor or Demon Armor at
the trainer and the prompt casts the new one straight away.

### Automatic, or pick your own

- Where your class has several of one kind -- a mage's armors, a paladin's
  auras, a hunter's aspects, a shaman's shields -- Who to buff has a
  drop-down: **Automatic**, each one you know, or **Don't remind me**. A buff
  on its own is a simple checkbox.
- **Automatic** reminds you of the one you had up last, even if you changed
  it in a fight or in town, and the drop-down says which: "Automatic (Mage
  Armor, the one you had up last)".
- Until you have had one up, a mage is offered Mage Armor in a dungeon or raid
  and Frost or Ice Armor everywhere else (the same armor everywhere until Mage
  Armor is learned), a paladin Devotion Aura, and a hunter Aspect of the Hawk
  (the Monkey before that).
- Automatic never picks Aspect of the Cheetah or of the Pack, but with either
  up you are not reminded.
- **Righteous Fury:** *Automatic (only while I'm the tank)* reminds you only
  while your group role is tank, *Always* whenever it is not up, and *Don't
  remind me* never.

### When you are reminded

- Only when **none** of a kind is up. Any armor, aura or aspect of yours
  counts, so the one you chose is never swapped for another. Only yours
  count: another paladin's aura on you does not stop the reminder.
- Never in a fight.
- Not in cities and inns, unless you tick **Also in cities and inns** (off by
  default: nobody needs Inner Fire at the auction house). This goes for your
  own buff for others too.
- Not while the game says the spell cannot be cast: a druid in cat form, a
  priest in Shadowform, a mage out of mana.
- With *Offer a top-up when it runs low*, a buff with a timer, such as Inner
  Fire or an armor, is also offered when it is running out. An aura or an
  aspect never is.
- `/manners debug` and the Diagnostics tab say which of your own buffs is up,
  which is due, and why one is not being offered.

### Hunters and shamans

- Manners used to have nothing for a hunter or a shaman, who have no buff to
  give anybody else. Now the prompt is theirs, for their own aspect, Trueshot
  Aura or shield.
- Who to buff shows them just the Myself settings. Start here has the key,
  the preview and snooze, and When to offer has the top-up choice and *Hide
  the prompt while I'm mounted*.
- Their greeting (`/manners welcome`) says what the prompt does for them.

### Fixed

- **The favour ledger** filed a buff you gave somebody who asked in chat as a
  gift given unprompted, and counted it in "You gave ... buffs unprompted
  today". It is now marked as asked for, and left out of that count. A group
  cast counts as asked for only when everybody it reached had asked.
- A paladin's Greater Blessing for their own class is no longer offered when
  it would replace a different blessing of theirs that they are wearing.

## 1.1.2

- **Fixed: picking "In character" on Start here made your character speak
  only when returning a favour**, so buffing a passer-by, somebody who asked
  or your group said nothing -- and the lines written for those moments were
  never heard. In character now speaks whenever you buff somebody. The two
  thank-you choices still speak only when you buff someone back, and the
  *Only when I buff someone back* switch now sits right under the choice on
  Start here.
- Buttons and drop-downs on the options page are now as wide as their words,
  so "Put these back to default" and "Above the action bars (default)" are no
  longer cut off with "...", in English or in the longer translations.

## 1.1.1

- **Fixed: the prompt for somebody nearby vanished before you could click
  it.** Somebody found under your cursor or on a nameplate now stays on offer
  for about ten seconds after you stop pointing at them, and a click still
  reaches them by name. The same goes for people who asked you in chat and
  people who buffed you a while ago.
- **Fixed:** with friendly nameplates on, somebody standing right at the edge
  of *Passers-by within* no longer blinks on and off the prompt.
- While your mouse is over the prompt, it holds still on the person it shows.
  It still moves on at once if they turn out to be dead, already buffed, out
  of range or out of sight, if somebody who buffed you comes along, or if you
  mount (with *Hide the prompt while I'm mounted* on), die or take a taxi.
  Right-click and shift-right-click work as before, and after ten seconds it
  lets go of somebody who has simply gone.
- Somebody remembered this way is let go at once if you switch off, or pin
  away from, the buff they were offered.
- A long row in the list under the prompt, such as a long name that needs
  Arcane Intellect, is now drawn a little smaller so it fits, instead of
  being cut off with "...".

## 1.1.0

Manners 1.1 is about dungeons and raids, and about getting started. With the
reagent in your bags, one press can now buff a whole party. Your group goes to
the front at a ready check and after a wipe, and a raid buffer can stick to
the groups they were given. The options page has been rebuilt around a new
**Start here** tab: four numbered steps, a couple of quick choices, and plain
words everywhere else.

### Group buffs

- **One cast for the whole party.** If you know Arcane Brilliance, Prayer of
  Fortitude, Prayer of Spirit, Prayer of Shadow Protection or Gift of the
  Wild and carry its reagent, then when at least 3 people in your party need
  your buff, the prompt offers one group cast instead of buffing them one at
  a time. In a raid it counts each raid group on its own, because that is what
  the spell reaches.
- **Greater Blessings** work the same way, by class. A Greater Blessing is
  held back while anybody of that class carries another of your blessings,
  because it would replace it.
- The prompt names who it is for the way you would say it: "Your party",
  "Your group", "Group 2" or "Every Warrior". The second line says why:
  "Arcane Brilliance -- 4 missing" after a wipe, "4 running out" before a pull.
  The tooltip counts your reagents.
- Right-click skips the group buff for the whole group. Shift-right-click puts
  only the person it is aimed at on your never-offer list and skips the rest
  for now.
- Without the mana for the group spell, you are offered the single buff
  instead. With the chat lines on (they are by default), you get a warning
  when a cast leaves you with 5 reagents or fewer, and another when you run
  out. The prompt then goes back to one person at a time.
- Spoken lines name the spell you are actually casting. The ledger counts a
  group cast as one buff given, and every favour it returned is marked
  returned.
- On by default, under Who to buff > My group and raid: *Use group buffs*,
  and *When this many need it* (2 to 5). Nothing changes until you have
  learned a group buff and carry its reagent.

### Dungeons and raids

- **Ready checks.** From a ready check until the pull, everybody in your party
  or raid who is missing your buff goes to the front, behind only your own
  target. The prompt says "ready check".
- **Back from the dead.** For two minutes after somebody in your group is
  brought back, they go to the front if they are missing your buff, and the
  prompt says "just revived". A hunter getting up from Feign Death doesn't
  count.
- Both are on by default, under Who to buff > Who comes first, and only change
  the order: nobody is added.
- **Raid groups I buff.** Untick the groups you were not assigned. In a raid,
  their members are offered only if they buffed you, asked, or you target
  them. `/manners debug` lists the groups you still buff, even before the raid.
- **Save mana.** *Save mana: stop below (% mana)*, on When to offer, is off by
  default. Below that level, only people who buffed you or asked are offered.
  Your group, your target and passers-by come back once your mana is 5 points
  above it, so the prompt doesn't flicker between casts.
- **Quieter raids.** Inside a raid the "buffed you" chat line is no longer
  printed. In a dungeon it keeps quiet during a fight. Either way the favour
  is still remembered and offered.
- **Out of sight, out of the queue.** With *Skip players out of range* on, the
  prompt no longer offers group members the game cannot see at all, such as
  those still in town or far off in the instance.

### Easier setup: Start here

- The options now open on **Start here**, in four numbered steps: 1. Who to
  buff, 2. Put it on a key, 3. See it, 4. Say thanks (optional).
- **Offer my buff to** is one quick choice: *Only people who buff me*,
  *People who buff me, and my group*, *Everyone near me*, or *My group, kept
  topped up (dungeons and raids)*. A grey line under it says in plain words
  what you picked. Fine-tune it on Who to buff.
- Set your key right there, or press **Make a macro**, which also opens the
  macro window so you can drag it onto a bar. The line underneath says
  whether you are ready.
- **Show me the prompt**, **Where it sits** and **Lock position** are there
  to place the prompt without leaving the page.
- **When I buff someone** is the quick choice for what you say: *Stay
  silent*, *Just /thank them*, *A polite line*, *In character* or *Whisper
  them a thank-you*.
- Snooze, the favour ledger, the minimap button and the chat lines are there
  too. When your other characters share these settings, Start here says so.
  **Give this character its own settings** copies them into a profile of its
  own.

### A clearer options page

- The tabs are now Start here, Who to buff, When to offer, What I say, Look,
  Advanced, Diagnostics and Profiles. Things moved to where you would look for
  them:
  - */thank people who buff me* is on What I say;
  - *Keep the prompt dim and still in combat* is on Look;
  - favour timings, targeting, exact position and prompt wording are on
    Advanced;
  - *Share as text* is on Profiles.
- Plain labels throughout, such as *Buff to offer*, *Passers-by within*,
  *Skip players below level*, *Hide the prompt while I'm mounted*,
  *Animations* and *Flash when someone buffs me*.
- A class with a single buff simply reads "You offer Arcane Intellect."
  instead of a dropdown with one choice.
- The phrase sets are now called Fantasy (general), In character (fits your
  race and class), Polite, Cheeky and Just their name. The lines stay out of
  the way until you tick *Say a line when I buff someone*.
- Your settings carry over, and nothing was reset.

## 1.0.0

Manners 1.0, the first stable release. When somebody buffs you in passing,
Manners notices, works out what you owe them, and puts one button on screen:
click it, they get their buff back, and your own target is handed straight
back. It also offers your group, people who ask in chat, and nearby players
missing your buff.

### New since the last beta

- **Titles for your manners.** Favours you return now earn you a title:
  Well Brought Up at 10, then Well Mannered (25), Courteous (50), Gracious
  (100), Magnanimous (250), Paragon of Etiquette (500) and, at 1,000, The Very
  Soul of Courtesy.
- Your title sits at the top of the favour ledger, with how far you are from
  the next ("37 of 50 to Courteous") and a small progress bar. Hover it for its
  line of flavour. The minimap tooltip shows it too.
- A new title gets one line in chat, once, even with chat lines off. It comes
  a few seconds after the favour that earned it, once the game has taken the
  cast; if the cast is refused, nothing is said until you really earn it.
- Favours you returned before this update count: you simply have the title
  you earned, with no burst of announcements. Clear keeps your title, as it
  keeps the all-time totals.
- **Whisper them**, a new choice under When you click > Speech > Channel,
  says your line to the person you buff and nobody else. It only goes when the
  whisper can't reach somebody else by mistake. When the name is not certain
  (on Camelot, a one-word name or a surname with accents; somebody from your
  own realm who is out of sight after a /reload), they get the buff with no
  line.
- **Thank them with an emote**, under Prompt > Getting your attention, off by
  default: when somebody buffs you and the prompt can return it, you /thank
  them. Never in a fight or in a dungeon, raid, battleground or arena, at most
  once per person every five minutes, and once every ten seconds in all, so a
  raid buffing you on the pull is one thank. `/manners debug` shows the last
  thank, or why the last one was skipped.

### Highlights

What eleven betas built, for anyone meeting Manners for the first time:

- **The prompt, and why somebody is on it.** Your target, somebody who
  buffed you, somebody who asked in chat, your group, and passers-by, in that
  order, each in its own colour, with a colour-blind friendly set. Right-click
  skips somebody for now. The favour survives a reload.
- **The favour ledger.** `/manners ledger` or a shift-click on the minimap
  button: who buffed you and with what, whether you returned it (and if not,
  why), who you buffed unasked, and today's count ("Returned 12 of 14 favours
  today").
- **A never-offer list, and friends first.** Shift-right-click somebody on
  the prompt and they are never offered anything again, unless they buff you.
  Friends, Battle.net friends and guildmates go ahead of other passers-by and
  the rest of your group.
- **Snooze.** `/manners snooze` hides the prompt for 15 minutes, or as long as
  you say, and Not while mounted keeps it away while you ride.
- **The minimap menu.** Right-click the button to snooze, preview, skip or
  never offer whoever is next, lock and place the prompt, and switch
  profiles. It is in the addon compartment too.
- **In character.** An optional phrase set of over a thousand lines, picked
  when you click to fit your people, your class and the moment: the spell you
  give, a trade for the one they gave you, an inn, a dungeon, the small
  hours. It doesn't repeat itself.
- **Nine languages:** English, German, Spanish, French, Italian, Korean,
  Brazilian Portuguese, and Simplified and Traditional Chinese.

## 1.0.0-beta.11

- French: the ledger's Clear button asks "Vraiment effacer ?" before it
  empties the list. The longer wording did not fit the button.

## 1.0.0-beta.10

The "In character" phrase set, grown into the addon's party piece: over a
thousand lines, funnier, and aware of the moment.

### In character

- **Seven times the lines.** Every people has around thirty of its own now,
  plus lines for your class, your faction, and anyone at all -- in all ten
  languages.
- **It reads the moment.** The line can be about the spell you are giving
  ("Mark of the Wild, {name}. The wolves will still bite, but they'll feel
  bad."), a trade for the one they gave you, the third time you two have
  swapped today, an inn, the wild or a dungeon, the small hours or the
  morning, or somebody of your own class or people. When the game will not
  say, that part is simply left out.
- **Your class speaks too**: mages, priests, druids, paladins, warlocks and
  warriors each have their own lines.
- **No repeats.** The last dozen lines you said are left out while anything
  else fits.
- Still only if you pick "In character" under When you click > Load a set.
  Nobody else hears a thing.

## 1.0.0-beta.9

A phrase set that speaks in your character's own voice, a colour of their own
for people who ask in the colour-blind palette, shorter texts on the options
page, and a long list of fixes, many of them for players whose names or chat
are not in English.

### New: In character

- **"In character: your race and faction"**, a new set under When you click >
  Speech > Load a set. The line isn't taken from a fixed list. It is picked
  when you click, to fit your people, your faction and why the buff is going
  out: thanks when you return a favour, an answer when somebody asked, an
  offer to a stranger, and friendlier lines for your group.
- Every playable race has a voice, and allied races share their people's: a
  Dark Iron dwarf talks like a dwarf, a Mag'har like an orc. Each people has
  two answers to a request, so somebody who asks often doesn't hear the same
  line every time. The Haranir use their faction's lines and the general ones
  for now.
- Somebody of your own people can get a word as kin, when the game lets the
  addon read their race.
- No line says "buff" out loud. Where a line names the spell, it uses the
  spell's own name, as in "Have some Arcane Intellect in return". With a long
  name, a shorter line is picked instead of saying nothing.
- The box shows a few of your character's lines. On a profile shared by
  several characters, each one sees and speaks its own. Edit them and they
  become your own fixed lines, as with any other set.
- "Only when returning a favour" applies to this set too, and Roll a few
  prints one sample line for each reason, so you can hear how it sounds.
- Nothing changes unless you pick the set.

### Colours and texts

- **In the colour-blind palette, people who asked for your buff have a deep
  pink of their own** instead of sharing the passers-by violet.
- The Colour it by reason tooltip names all five reasons and their colours,
  in both palettes.
- **Shorter texts on the options page.** Every tooltip and note is one or two
  short sentences; the longer explanations are on the addon page. No setting
  was renamed or reset.
- The Targeting note says plainly that the prompt targets whoever it buffs,
  group members too, and when your previous target comes back.
- Share settings lists everything a pasted line leaves alone: your on switch,
  lock, prompt position, click log and minimap button. It never switches
  speaking on.
- **`/manners dev`** lists the tools for testing the addon on this client
  (clicks, try, look, forms). `/manners help` no longer lists them, but they
  still work, and a typo of one points you at `/manners dev`.
- The first-login greeting, the error for a cut-short settings line, the
  message for never-offering somebody you owe in a fight, and the ledger
  tooltip for a favour only your party can return are all shorter.

### Asking in chat

- If somebody asks for several buffs, or asks while you owe them, you are
  offered the rest of what they asked for after the first one lands. When
  their buffs can't be read, "buffs pls" no longer offers again the one that
  just landed.
- Questions about a buff in German, French, Spanish, Portuguese, Italian,
  Russian and Chinese are no longer taken as asking you for it.
- "No" and "don't" in other languages now stop a message counting as a
  request, the way "no" and "not" already did in English.
- Long Chinese sentences that only mention a buff no longer count as asking,
  while "法师求奥术智慧" (a 求 after a word, not only at the start) still
  does.
- On Korean clients, everyday words that happen to contain a buff's name, such
  as 가시나요, no longer count as asking for Thorns.

### The prompt and fights

- Clicking the prompt right after switching targets hands your new target
  back.
- Starting a fight just as the prompt changes no longer leaves it stuck on the
  wrong person, taking your target.
- Switching Manners off and on, or unlocking and locking it, during a fight no
  longer loses track of the buff you just gave.
- A warrior's shout no longer counts as repaying somebody who had just walked
  out of earshot.
- A buff you receive in a fight says it will be offered once the fight ends,
  instead of saying it is already on the prompt.
- Unlocking the prompt in a fight no longer says a press will cast when
  nothing is armed.
- A font from a media pack that fails to load no longer makes the prompt or
  the favour ledger disappear. They fall back to the game's font.
- **Your character no longer speaks to somebody out of range.** The spoken
  line is left out for anybody the game says is too far away, checked again
  the moment you press. After the game refuses a cast on somebody, nothing is
  said to them for half a minute, or until a buff on them lands. Where the
  game can't tell the range, the line is said as before.
- **Somebody the game won't let you buff stops coming back.** Each refusal in
  a row keeps them off the prompt for longer: a moment, then half a minute,
  then five minutes, with one line in chat saying so. Somebody who buffed you
  is kept off for a minute at most, and you still owe them. Target them to try
  again at once; `/manners debug` lists who is waiting and for how long.

### Favours and names

- **Players with long names and surnames in Cyrillic and other non-Latin
  letters** are recognised, offered and recorded in the ledger.
- Being buffed again after you die, or after the buff has run out, is noticed
  and offered back.
- Somebody you shift-right-click onto the never-offer list stays there if the
  server then refuses your last cast on them.
- After a loading screen, people who buffed you before it are no longer
  offered as if they were still in range, while Drop people who are probably
  gone is on (the default).
- A damaged settings file no longer turns Manners off or wipes the favours you
  still owed.
- After your PC clock is set back, remembered favours no longer outlast the
  window you set.
- The snooze end time follows the minimap clock when it shows realm time.
- `/manners never` and the profile list in the minimap menu are in
  alphabetical order in every language.

### The favour ledger and options

- Today's summary is right on the days the clocks change, and on a busy day
  it keeps counting after the oldest rows have been trimmed from the list.
- The minimap button's tooltip no longer points you at the addon compartment
  when another addon has hidden it.
- The Font dropdown shows your chosen font, marked "not loaded", when its
  media pack isn't loaded, instead of going blank.

### Lighter

- More room under the game's limits for addon code, the limit that stopped
  1.0.0-beta.6 from loading.
- Putting somebody on the never-offer list stays quick with a long list and
  many favours owed, and the memory of who got which buff no longer grows
  through a very long session.
- New screenshots on the addon page, drawn from what the addon actually
  builds: the prompt, the five reasons and their colours, the favour ledger,
  the prompt in German, Russian and Chinese, and the colour-blind palette.

## 1.0.0-beta.8

A redesigned favour ledger, a prompt that stays readable on any panel colour,
a colour-blind palette, an option to buff people who ask for it in chat, and a
lighter scan in crowds.

### The favour ledger

- **Redesigned.** Today's summary is the first and largest thing on the
  window, and the tabs, buttons and labels fit in German and Russian too.
- Each row shows who (in their class colour), when, a coloured badge for what
  happened (Still owed, Returned, Let go or Gave), then the details.
- An empty ledger shows the Manners mark and says how entries get there, or,
  in amber, why nothing is being recorded right now.
- Clear turns red while it waits for the second click, and only shows when
  there is something for it to clear.

### Easier to read

- **The text follows the panel.** Pick a light panel colour and leave Text
  colour at white, and the text turns dark by itself. Class-coloured names that
  would vanish on it, such as a priest's white, are darkened too. On the
  default dark panel nothing changes.
- A text colour you pick yourself is used exactly as you chose it, except on
  names while "Colour names by class" is on. Set it back to white to let the
  prompt choose again.
- **The Minimal look is outlined and brighter**, so it stays readable over snow
  as well as in dark places, including every row of the list of who is next.
- **Colour-blind friendly reason colours**, under Prompt > Style > Reason
  colours. The four reasons become pale yellow (your target), orange (buffed
  you), sky blue (your group) and violet (passers-by). Off by default.
- Long lines in German, Russian and other longer languages, and a few English
  ones, are drawn slightly smaller before they get cut off, and use the space
  beside the name whenever the count badge is hidden.

### New: people who ask for your buff

- **People who ask me for it**, under Who to buff, off by default. When
  somebody asks for your buff in /say, /yell, your group's chat (party, raid or
  instance) or a whisper, they go on the prompt for a minute, reading "asked
  for it" in a pink of its own. "int pls", "fort?", "can I get motw", "buffs
  please" and the spell's name in your language all count.
- They come after people who buffed you and before your group. They are
  offered it only while they don't have it: if somebody else buffs them first,
  or you cast it by hand, they leave the prompt.
- Only short messages that actually ask count, with the buff named as a whole
  word and nothing saying no or not. "int pls" and "can I get int" ask; "int
  the healer pls", "need int ring" and "rogues need a buff" don't. Words
  English uses for other things (might, mark, wisdom, spirit, shadow, shout)
  need a please or to stand alone, and never count in group chat.
- Players of your own class never count as asking: another mage saying
  "anyone need int?" is offering it.
- What is said during a fight is taken as tactics ("int" there means
  interrupt) and ignored, except a whisper. A request still waiting when a
  fight starts waits until it ends, once.
- You're only offered buffs you can cast, a pinned spell stays the only one
  offered, and the never-offer list still applies. Somebody who asks from out
  of sight is offered only if they turn up before the minute is out. Nothing is
  ever said back to them.
- The minimap tooltip and its Who's next menu say "asked for it" too, and
  `/manners debug` shows who has asked, where, and how long each request has
  left.

### Lighter in crowds

- Each scan leaves less than half the garbage it used to.
- A long never-offer list no longer slows the scan down. Every name on it used
  to be compared with everybody in sight on every scan; the answers are now
  remembered until the list changes.
- None of this changes who is offered what, or in which order.

## 1.0.0-beta.7

A fix for 1.0.0-beta.6, which did not load.

- Manners loads again. In 1.0.0-beta.6 part of the addon failed to load with
  the error "function at line 604 has more than 60 upvalues", so the prompt
  never appeared and a second error followed. Thank you to jackflagg84 and
  Xangandu for reporting it, and to Xangandu for tracking down the cause.

## 1.0.0-beta.6

A feature release: a favour ledger, a never-offer list, a snooze, a menu on
the minimap button, a new look for the prompt, and nine more languages.

### New

- **The favour ledger.** `/manners ledger`, or shift-click the minimap
  button, shows who buffed you and with what, whether you returned it, and
  who you buffed without being asked. Newest first.
- Today's count sits at the top of the ledger ("Returned 3 of 4 favours
  today"), with your all-time totals under it. The minimap tooltip and the
  General tab show the same summary.
- A favour you didn't return says why: the time ran out, nothing you cast
  helps them, or you put them on your never-offer list.
- The ledger keeps your last 200 entries per character, never says anything
  in chat, and opens in combat. Clear keeps favours you still owe and your
  all-time totals.
- **Never offer.** Shift-right-click the prompt and that person is never
  offered anything again. Chat says how to undo it (`/manners allow Name`).
  A plain right-click still just skips.
- The never-offer list is on the Who to buff tab, where you can add a name,
  take one off or clear it. `/manners never` shows it in chat.
- Someone on the list who buffs you is still offered the favour back.
  Shift-right-click them on the prompt to let that favour go.
- **Friends and guildmates first.** Your friends (Battle.net friends
  included) and guildmates go ahead of other passers-by, and ahead of the
  rest of your group. People who buffed you still come first. Switch it off
  under Who comes first.
- **Snooze.** `/manners snooze` hides the prompt for 15 minutes, or as long
  as you say (`/manners snooze 5`, `snooze 1h`, up to 4 hours).
  `/manners snooze off` ends it. The minimap menu and the General tab can
  snooze too, and the minimap button shows when it ends.
- **Not while mounted**, on the When tab, keeps the prompt away while you
  ride. Off by default.
- **Passers-by only in cities and inns**, under Who to skip, off by default.
  Your group, anyone who buffed you and your target are still offered
  everywhere.
- **Share your settings.** `/manners export` turns them into one line of
  text to back up or share, and `/manners import` (or the Share settings box
  on the General tab) uses one. `/manners import undo` puts yours back.
- A pasted line never switches on speaking to other players, and never
  changes your on switch, the prompt's lock or position, or your minimap
  button.
- `/manners help` lists every command in groups, one line each. A mistyped
  command, such as `/manners snoze`, suggests the one you probably meant.
- Pressing the key while the prompt is hidden says why: snoozed, or mounted.
- The prompt's tooltip says when someone is on your friends list or in your
  guild.

### The look

- The prompt has a new look: a softer shadow with a crisp edge, light on the
  glass, and a proper frame around the spell icon.
- When somebody buffs you, the icon gets a soft glow around it instead of
  being washed out.
- The spell icon shows the global cooldown sweep after you cast, like your
  action bars. Turn it off under Prompt > Icon and queue.
- When a buff lands, a ring pops out of the icon and light crosses the panel.
  A refused buff gives a small shake and a red ring instead of flooding the
  panel red.
- After your last buff the prompt fades out instead of blinking off.
- New Prompt setting **Effects**: Full, or Calm for less movement. "Stay
  quiet in combat" also stops the new effects during a fight.

### The minimap button

- **Right-click now opens a menu** instead of switching Manners off.
  Middle-click switches it on or off in one press.
- The menu has on or off, snooze, who's next (skip them or never offer them),
  the ledger, preview, the prompt's lock and position, sound and effects, the
  chat lines, and your profiles.
- In a fight, the entries that would move the prompt are greyed out until it
  ends.
- The icon dims while Manners is snoozed and goes darker still while it is
  off. A broker display shows how many people who buffed you are waiting for
  one back.
- Manners is also in the addon compartment under the minimap, so hiding the
  button loses nothing.

### Languages

- Manners now speaks German, Spanish (Spain and Mexico), French, Italian,
  Korean, Brazilian Portuguese, Russian, Simplified Chinese and Traditional
  Chinese: the options, the prompt, the ledger and the chat lines.
- The prompt's wordings and the buff phrases start out in your client's
  language. Phrases you never edited switch over too, even though earlier
  versions saved them in English.
- Slash commands stay in English in every language.

### Fixed

- Someone already on the prompt who then buffs you now gets "Flash once" and
  the stripe sweep. Before, only a new face did.
- The prompt no longer hops down a few pixels at the end of its entrance.
- While the prompt is unlocked, the chat line when someone buffs you says the
  favour waits until you lock it, instead of saying it is on the prompt.
- A buff the game refused late no longer cuts short a newer favour the same
  person gave you in the meantime.

## 1.0.0-beta.5

A second full bug-fix pass: 73 fixes, most with a test that fails without them.

### The big ones

- **The distance filter never worked in a released build.** The range-check
  library that ships with Manners was never loaded, so "Nearby" fell back to
  the 8-yard duel check and "Right beside me" offered the same people as
  "Nearby". It now loads and is used.
- **The key binding has its own "Manners" section** under Options >
  Keybindings. The addon used to send you to "Game Menu > Key Bindings", which
  this client doesn't have. A key you already bound stays bound.
- **Manners has its own icon** in the addon list and on the minimap button.

### Pressing the prompt

- A potion, healthstone, trinket or any spell off the global cooldown no
  longer holds the prompt for a second and a half.
- A second press the game refuses, or an action-bar cast of the same buff,
  no longer marks a buff that already landed as refused.
- After a refused buff, pressing again while the red line is up no longer
  buffs the next person without saying so. The prompt says who it moved on
  to, and the red line comes off on time.
- Right-click skip on a refused buff skips the person the red line names.
- Buffing the player you already have targeted keeps them targeted. (In a
  fight the prompt is frozen, so there it always hands your target back.)
- A press just after someone steps out of range goes to them instead of
  being silently ignored.
- If full bags or another unrelated error pops up just before your buff goes
  out, chat now says the buff went out after all.
- Pressing twice quickly no longer says the first person "was not buffed"
  when the game simply hadn't answered yet.
- The prompt dims the moment a fight starts, not up to a scan later.
- A slight drag on a locked prompt no longer prints "moved and locked", and
  holding a drag as a fight starts no longer causes a blocked-action error.
- Pressing the key while Manners is switched off says so.

### Warriors and paladins

- Battle Shout is offered only to your own party subgroup in a raid, and not
  to group members too far away to hear it. A shout no longer counts as
  repaying people it didn't reach.
- Warriors are no longer told strangers are measured or offered buffs, and
  the "counted as repaid" line names Battle Shout.
- Paladins: another paladin's blessing no longer stops you offering one of
  yours that stacks with it, and a paladin you owe gets a blessing they don't
  already have.

### Who gets offered

- When nothing you can cast is any use to someone who buffed you, Manners
  says why instead of saying the favour is on the prompt.
- When the game won't say whether someone has your buff, the prompt says it
  couldn't check, instead of putting them ahead of someone who buffed you.
- Lowering "Remember a buff for", or switching to a profile with a shorter
  time, applies at once to people who already buffed you.
- A pinned spell is offered even if its own switch under Automatic is off.
- The login line, preview and minimap tooltip no longer name a spell you
  switched off or haven't learned, and say so when everything is off.

### The prompt and the preview

- Changing Scale no longer moves the prompt, and the position presets put it
  in the same place at any scale. The "who's next" list stays on screen at
  large and small scales.
- The tooltip updates while open when the buff or reason changes, and the
  line it says you'll speak is the one you actually say.
- The preview can't be started in a fight, and one started from Options >
  AddOns ends when you close that window.
- A damaged colour setting no longer turns the prompt white after a profile
  switch.
- Emptying the phrase box shows the set it falls back to straight away.
- If an update moves your prompt, chat tells you how to put it back.

### Chat, commands and option text

- The login line and `/manners debug` say when Manners is switched off, or
  "People who buffed me" is unticked, instead of "nobody has buffed you".
- `/manners look` says when the game withheld the buff check, instead of
  reporting "false".
- Changing `/manners try`, `/manners restore` or "When you click" in a fight
  says the change applies once the fight ends. `/manners unlock` in a fight
  says the same.
- `/manners try`: `{first}` works for one-word names, and `{unit}` no longer
  turns into your current target.
- About twenty option descriptions and tooltips that said something untrue
  now match what the addon does, among them "Stay quiet in combat", "Tell me
  in chat what the addon is doing", "If they already have the buff", the
  Targeting note, the Diagnostics tab and the minimap tooltip.

## 1.0.0-beta.4

A bug-fix release. Every part of the addon that had never been through a
review has now had one, and each fix below comes with a test that fails
without it.

### Pressing the prompt

- A press always goes to the person the prompt is showing. If the prompt has
  just moved on (after a refused press, say), the press does nothing and chat
  tells you who it moved on to.
- Pressing twice quickly after the game refused a buff no longer buffs the
  next person and counts the first one as repaid.
- Right-click to skip moves the prompt on at once, so a left-click just after
  cannot buff the person you skipped.
- In combat, a press during the global cooldown no longer blames the person on
  the prompt. A press in the last moment of the cooldown counts: the game
  queues it and the buff lands. That moment follows your own Spell Queue
  Window setting.
- A press held back by the cooldown no longer swallows the one you make a
  moment later, and one made just before a fight no longer leaves the prompt
  empty for the whole fight.
- The prompt waits out spells with a cast time (Conjure Water, Hearthstone)
  instead of trying to buff mid-cast.
- A spell you cast by hand a second after a refused press no longer counts as
  that press landing.
- An out-of-range press is reported once, in the game's words. No second red
  flash, and the person comes back after two seconds instead of four.

### Who gets offered

- **Changed since 1.0.0-beta.1, not announced at the time:** passers-by are
  only offered when they are close, "Nearby" (about ten yards) by default.
  The setting is under *Who to buff* → *How near a passer-by has to be*.
  Pick *Anywhere I can cast* for the old behaviour.
- On a client that will not measure distance to strangers, "Nearby" no longer
  quietly drops everyone. It says plainly that it has no signal.
- If one way of measuring cannot tell about someone, the next is asked
  instead of offering them from thirty yards away. "Right beside me" can no
  longer offer more people than "Nearby".
- Warriors, and any class whose buffs reach only their group, are no longer
  told the prompt offers buffs to strangers.
- A class with nothing to cast (a rogue, say) no longer records favours.
- A buff learned in a burst at a trainer is picked up within seconds, not at
  the next loading screen.

### Settings

- A sound from a sound pack (SharedMedia, WeakAuras) is no longer reset to
  "Manners alert" at every login.
- A pinned buff is no longer wiped when another class logs in on the same
  profile.
- Switching, copying or resetting a profile updates the minimap text at once.
- A prompt moved under 0.9 no longer comes back stuck over your action bars,
  and the old `/click MannersPrompt` macro is updated for you. Macros you
  edited are left alone.
- A reason line you empty on purpose stays empty after a reload.
- The Font list shows names, not file paths.
- Narrowing the prompt keeps the icon inside it. The icon slider no longer
  fights you while you drag it, and a mouse wheel past the limit shows the
  size actually kept.
- "Load a set" can reload a set you have edited. The Locked box updates after
  you drag the prompt. The Diagnostics tab shows the real error count.
- Several settings descriptions were wrong (your target is pale blue, not
  green; the height a second line needs) and now match what they do.

### Messages

- Chat no longer says someone "is still owed" when they never buffed you.
- "Could not cast" names the spell instead of printing its number.
- "Ready in …" no longer leaves the reason line the wrong colour, and never
  says "ready in 0.0s".
- `/manners test` no longer says "preview on" when someone real is on the
  prompt. The first-run greeting no longer promises a prompt when the addon is
  switched off on that profile.

## 1.0.0-beta.3

Documentation only. The README said it could be installed "through any client
that reads CurseForge — WowUp", which is not true: WowUp dropped CurseForge
when Overwolf cut off third-party clients. Wago is the one it reads, and that
is now what both the README and the listing say.

## 1.0.0-beta.2

Also published to Wago from this release on. WowUp dropped CurseForge when
Overwolf cut off third-party clients, so an addon on CurseForge alone never
appears there — and Wago already has a game type for WoW Forever.

Otherwise identical to beta.1.

## 1.0.0-beta.1

It runs on **WoW Forever** and nothing else. Retail, Mists Classic and Classic
Era are implemented, but nobody has launched those games -- and a toc is a
promise.

### Since 0.9.6

Six rounds of review, a port to five clients that ships as one, and two bugs
found in ten minutes of actually playing it that no test here could reach.

### Added

- **The prompt offers the buff they are actually missing.** A priest walks
  Fortitude, then Divine Spirit, then Shadow Protection; a druid offers Thorns
  as well as Mark of the Wild. Before this one buff per class was resolved and
  only that one checked, so the rest were never offered at all -- and worse,
  the default "leave them alone if they have it" then dropped the person from
  the queue the moment they held the first one, so being *partly* buffed made
  you invisible. Individual buffs can be switched off, or one pinned. Paladins
  are excluded on purpose: blessings overwrite one another, so walking would
  replace what the last click gave.
- **Somebody you targeted yourself outranks everyone**, including a favour
  owed -- but only when the game will confirm they are missing it. A guess does
  not jump the queue.
- **Debts survive a reload.** Stored per character on the wall clock and
  rebased on the way back in, because everything held in memory is relative to
  a clock that counts from when the computer booted. Clamped to the window as it currently stands,
  so shortening the slider cannot be out-waited by a file written under a
  longer one.
- **Right-click the prompt to skip somebody** without marking their favour
  repaid.
- **`/manners errors`**, and the panel no longer goes silent after the first
  thing it catches -- failures are kept per label, so a broken scanner after a
  broken style pass is visible instead of swallowed.
- Issue templates that require `/manners debug` and `/manners errors`, and a
  second one for reporting whether a class cast.

### Fixed

- **Every loading screen could invent favours.** This was the worst of them.
  The aura baseline was wiped and re-scanned in the same breath, so there was
  nothing to disagree with; the scan primed off a list the client had not
  actually shown it; and when the list read back, every buff you were carrying
  was announced as a fresh favour -- printed, pulsed at a bystander, and
  written to your saved variables. The scan no longer tries to recognise a
  refusal, which it cannot do because the shape one arrives in is unknown.
  Nothing primes, prunes or announces on the strength of a single reading.
- **A favour could name the wrong person.** The caster was resolved when the
  aura was *noticed*, not when it landed, and nameplate tokens are recycled in
  between -- so the debt, the chat line, the amber prompt and the spoken line
  could all be aimed at somebody who had done nothing. The caster is now read
  during the slot walk and carried forward, and a sighting nobody could name is
  never announced rather than announced to whoever is standing there later.
- **A warrior could never repay a favour.** Battle Shout is self-cast, so its
  macro has no `/target` by construction, and the settle path judged every
  click by "did it land on the person we offered?" -- which it never can.
- **A refused cast walked the person down their whole buff list.** Out of range
  or out of sight left standing the per-buff cooldown the click had written
  optimistically, so the prompt offered them the next buff, which failed the
  same way, until they were dropped entirely.
- **Every disarm was a no-op in combat.** Switching the addon off, unlocking
  the prompt or entering preview left it armed and still naming somebody, and
  the click handler had no guard at all -- so a switched-off addon still cast
  through the keybinding and still marked the favour repaid.
- **A cast that landed on the wrong player still counted**, and a late refusal
  arriving after the game had confirmed a send was dropped entirely, leaving a
  tick standing over a cast the server threw away.
- **The grace-window path ignored every filter the main path applies**, so a
  warrior who Battle Shouted you came back holding Arcane Intellect at the top
  of the queue, and a level-5 priest came back after being rejected for it.
- **The keybinding was an up-click on a button that only casts on the way
  down** -- and it is the first route the options panel recommends. It is now
  the native `CLICK` binding form.
- **Speech died silently on any new, copied or reset profile**, and stayed
  broken until a reload while the dropdown still claimed a set was loaded.
- **"Play a sound" played nothing** (the default was "None"), and the sound
  list was showing file paths as names.
- **The minimap button stayed attached to whichever profile loaded first**, so
  after a switch the checkbox and the button disagreed and a drag saved the
  position to neither.
- The prompt stayed on screen unlocked after being switched off, kept pulsing
  in combat after the debt was settled, and announced favours from a source
  that was switched off -- a line about something that could never reach it.

### Changed

- **The prompt stops churning.** It holds a candidate for a moment before
  swapping to an equal one, fades instead of vanishing, keeps a floor between
  sounds, says when it is held in combat rather than showing a stale name while
  looking live, and confirms a click landed instead of throwing every
  ingredient away unless a debug flag was on. It no longer starts life in the
  middle of the play area.
- **The options page stops describing things the addon does not do**: a Look
  mode that applied no border, an accent explanation a colour short, a re-offer
  delay that promised a per-player wait while writing a per-spell one, sliders
  with no units that silently mixed seconds with minutes, and a filter whose
  own description contradicted its label.
- **The first-name fallback is gone.** 1.3.0 added it so the game could pick
  whichever spelling resolved; the full name does resolve on this client, so
  the failure it guarded against was never observed, and offering two spellings
  could aim a cast -- and a spoken line -- at whoever else shared a first name.
  See the note above `ExpirePendingClick`. Do not restore it.

### Testing and tooling

- Tests run on every push, not only on a release tag.
- `validate.py` now catches a function given where AceConfig wants a number,
  which rejects the *entire* options table and stops the page drawing at all;
  and it compares `.pkgmeta` against `embeds.xml`, which fail in opposite
  directions and both package cleanly.
- `selftest.py` requires each mutation to be caught by the check that exists
  for it. It used to infer "caught" from the whole run going red, which a
  mutation guarantees -- so a bug reintroduced in one place and noticed
  somewhere else read as a pass.
- 120 scenarios, 96 mutations. The listing images are generated by scripts in
  `tools/` that read the prompt's real defaults out of the addon, so they
  cannot advertise a layout it does not draw.

## 0.9.6

Two live bugs found by the audit, both cases of the addon doing the wrong
thing rather than nothing.

### Fixed

- **The right mouse button still cast.** 0.9.5 stopped a right-press running
  the bookkeeping but not the cast: the unsuffixed `type`/`macrotext` are the
  fallback for every button, and `AnyDown` delivers all of them. So turning the
  camera with the cursor over the panel fired the buff, skipping PreClick's
  re-resolve entirely -- no retry cooldown, no debt settled, the same person
  offered again immediately. Buttons 2-5 are now given a type the secure
  handler does not recognise. The unsuffixed pair stays, because it is the form
  copied from the buttons that provably work on this client.
- **A cast that landed on the wrong player counted as the favour returned.**
  `/target <name>` for a name the game cannot resolve is a no-op -- it leaves
  your existing target in place -- so the cast went to whoever that was, and
  the debt was cleared for somebody who never got anything. The spell-sent
  event carries the name it actually reached, and it now has to match.

### Added

- `.github/AUDIT.md`, the full output of a 37-agent audit: 103 findings, 20
  bugs confirmed after adversarial verification, and a ranked feature plan.
  Kept because it is a work queue, not a report.

## 0.9.5

*Never released on its own: the `v0.9.5` tag points at the same commit as
`v0.9.4`, and these fixes first shipped in 1.0.0-beta.1.*

From a 103-finding audit across UX, code, performance and bugs.

### Fixed

- **Warriors were offered nobody, ever.** A guard meant as hardening bailed out
  of the whole queue when the player's current mana was zero -- which for a
  warrior is a readable, permanent zero. A whole class was silently dead. The
  check now only applies to classes that have a mana bar at all.
- **A pinned buff was reset to Automatic on every login.** `ClampSettings` ran
  before `ProbeCapabilities`, so it validated the choice against a class it did
  not yet know. Order swapped, and an unknown class now leaves the setting
  alone instead of rewriting it.
- **The "Only count real class buffs" toggle did nothing.** It had a default
  and a full-width control with a paragraph of explanation, and nothing read
  it; the filter was hardcoded. It works now.
- **`/manners restore` was in the help text but not implemented.**
- **The aura scan stopped at the first slot the client withheld**, hiding every
  favour behind it -- which then re-fired as new on the next scan, forever. It
  tolerates gaps now.
- **Any mouse button burned the candidate.** `RegisterForClicks("AnyDown")` is
  what makes casting work here, but it routes every button through the click
  handlers -- so a right-press to turn the camera set the retry cooldown and
  cleared the favour without casting anything. Only the left button acts.
- **A cast that never happened counted as a favour returned.** Clicking cleared
  the debt outright; if the cast was blocked by range or line of sight, they
  were marked repaid. The debt is now held until the game says what happened,
  and a failure re-offers them in two seconds.
- **The phrase preview promised 200 characters and the cast path allowed 120**,
  so anything in between rolled happily in the options and was silently never
  spoken. One shared constant, and the help says the real number.

### Tests

- The mock gave warriors mana, which is exactly why that bug got through. It
  reports honestly now.
- Three regression scenarios, each mutation-tested: reintroducing the bug makes
  its scenario fail.

## 0.9.3

### Fixed

- **LibDataBroker was fetched from a URL that does not exist.** The packager
  pulled the other twelve libraries and then failed on this one:
  `repos.curseforge.com/wow/libdatabroker-1-1/trunk` returns 404. It is sourced
  from `github.com/tekkub/libdatabroker-1-1` now, which is where it actually
  lives.

## 0.9.2

### Fixed

- **The test suites could only run on one machine.** `validate.py` and
  `runharness.py` carried absolute Windows paths from where they were first
  written, and the Lua harnesses joined paths with a backslash. Everything is
  resolved relative to the test file now, and CI runs them for real.
- `validate.py` treated an absent `Libs/` as a failure. A checkout legitimately
  has none -- they are build-time externals -- so it now says so and carries on,
  while still checking them when present.
- It also checks that the toc, `ns.BUILD` and the changelog agree on the
  version, because a log naming the wrong build has already cost an hour once.

## 0.9.1

### Added

- **Phrase sets.** Four of them, loadable from the Speech tab in one click:
  Roleplay (now the default), Polite, Cheeky, and Just their name. They are a
  starting point, not a cage -- the list stays editable afterwards.

### Changed

- The listing copy leads with what the addon does rather than telling a story
  about it. The toc, README and CurseForge summary all match.
- New project icon, built to sit beside real spell icons: bevelled gold frame,
  arcane interior, two streams of light winding into a core.

## 0.9.0

Renumbered down from 1.6.0 before any release. One class has cast in game;
calling that 1.x claims a confidence the testing does not support. The version
goes to 1.0.0 when the other five have been used by somebody.

### Release engineering

- **`.github/workflows/release.yml`** -- tag a version and it runs all three
  suites, fails the build if any check has stopped being able to detect the
  fault it exists for, then packages and publishes through the BigWigsMods
  packager. `Libs/` is not in the repository, so **a zip built from a clone
  has no libraries and will not load**; this is the supported way to build one,
  and both the README and the gitignore now say so.
- The toc, the README and the addon's own description state which classes have
  been verified in game and which have not.

### Tests

- **Every class, every buff.** All thirteen now have their cast path driven and
  the resulting macro checked: every line a real command, within the 255-byte
  limit, casting something, and targeting where targeting is right.
- **Warrior is structurally different** and is checked for it: Battle Shout is
  selfCast, so its macro must be a single line with no `/target` at all.
  Targeting somebody would be wrong, not merely unnecessary.
- **Paladin's automatic choice** -- Wisdom for a mana bar, Might otherwise --
  is pinned down.
- Writing these found that **a solo warrior is offered nobody**, because Battle
  Shout reaches the party and no further. That is correct, and is now a test
  and a line in the README rather than a surprise.
- Both new checks were mutation-tested: breaking the selfCast branch or
  swapping the Paladin mapping makes them fail.

## 1.6.0 (early numbering, before 0.9)

Casting works, so the scaffolding built to find out why it did not has been
taken out. 371 lines removed.

### Removed

- **Probe mode** -- the eight-form cycler that identified `/target` + `/cast`
  as the only working path. It did its job.
- **Self-test mode** -- the bare cast that proved the spell and the button
  independently of targeting.
- **The roster cast path** -- never verified, and a guess does not belong in
  the hot path next to something proven.
- **The diagnostics ring buffer and the whole SavedVariables dump** -- the scan
  rejection tallies, name sampling, nameplate counts, aura scan counters,
  combat-log counters and the restriction report. All of it answered its
  question.
- **The combat log handler**, which cannot fire on this client at all.

### Fixed

- **UI errors were spamming chat.** Hooking `UI_ERROR_MESSAGE` reports
  everything the game raises -- "that item is not a valid target", "another
  action is in progress", "you are no longer rested" -- none of it ours. Now
  scoped to the second after our own click, and behind `/manners clicks`.
- Cast reporting is opt-in for the same reason.

### Kept, deliberately

- **`ns.Guard`** -- not debug scaffolding but the thing that makes a failure
  visible. A repeating timer whose function throws stops silently, and that is
  exactly what "the prompt never appeared" looked like from the outside.
- **The build stamp**, because a log that does not say which build produced it
  can be read for an hour before anyone notices the game never loaded the file.
- **`/manners try` and `/manners look`** -- a test console, not leftovers.

### Tests

- `tests/selftest.py` now covers five fault classes rather than three, and
  reports loudly when a refactor has moved the code a check depended on. All
  five still go red on demand.

## 1.5.0 (early numbering, before 0.9)

It casts. Confirmed in game against four different players in ten seconds,
with the build stamp and form label proving which code ran:

    CLICK build=1.4.1 form=live  macro=/target Elara Brightmoor /cast Arcane Intellect /targetlasttarget
    CAST SENT 1459 -> Elara Brightmoor    CAST OK 1459
    CAST SENT 1459 -> Corvin Ashgrove  CAST OK 1459

`target=` on each line showed the original target already restored, so
/targetlasttarget works too.

### Added -- a test console

Iterating on this client otherwise costs one guess per /reload. These make it
one guess per click.

- **`/manners try <macro text>`** -- arms any macro text on the prompt.
  Tokens `{unit}` `{name}` `{first}` `{spell}` `{id}` expand against whoever is
  currently offered; `\n` gives a new line. Bare `/manners try` clears it.
  The command word is matched case-insensitively but the macro text is kept
  verbatim, because it is case- and punctuation-sensitive.
- **`/manners look [unit]`** -- every API answer for a unit, and crucially
  whether each one came back as a **secret value** rather than a real one.
  "false" and "withheld" are indistinguishable after the fact, and telling them
  apart is most of the work on this client.
- **`/manners forms`** -- ready-made macros to paste into `try`.

Everything the console prints also lands in SavedVariables, so a session can be
read off disk without transcribing chat.

### Changed

- Click logging is off by default now that casting is proven. `/manners clicks`
  turns it back on.

## 1.4.1 (early numbering, before 0.9)

Findings from a 109-agent investigation across the client corpus.

### Fixed

- **An emptied queue left the previous person's macro armed, and clicking cast
  at them.** `ApplyTarget`'s clear was guarded by `appliedKey ~= nil` as an
  optimisation, but `PreClick` sets `appliedKey` to nil immediately before
  calling it -- so on a click the guard was always false and the clear never
  ran. Now unconditional.

### Added

- **A build stamp and an armed-form label in every click line.** A log that
  does not say which build produced it, or which of live/probe/selftest/roster
  armed the button, can be diagnosed for an hour before anyone notices the game
  never loaded the file being read. That is not hypothetical: it happened here.
- `probeOn`, `selfTestOn` and `rosterOn` in the diagnostics dump, and a red
  DIAGNOSTIC MODE ACTIVE line in `/manners debug`. A mode with no visible state
  is a trap.
- The click line now reports what `/target` actually acquired.
- `/manners roster` -- an opt-in path that casts on group members through a
  party/raid token in `unit1` rather than targeting them. That is the one unit
  form with a working precedent in the corpus (ClassBuffReminder uses it, and
  only ever with roster tokens or "player"); Manners had only ever fed that
  form a nameplate token, which is exactly what does not resolve. Off by
  default: `/target` works, and a proven path should not be replaced by a
  guess.

### Tests

- A regression scenario for the stale-macro bug, mutation-tested: reintroducing
  the guard makes it fail with the stale macro quoted.
- **The mock clock can advance.** It was frozen, so once a scenario clicked,
  the retry cooldown never expired and every later `BuildQueue` came back
  empty -- several assertions were skipping while reporting green. Scenarios
  that cannot run now fail loudly instead of passing vacuously.

## 1.4.0 (early numbering, before 0.9)

### It casts

Conditional targeting does not work on this client. Every form was probed one
per click against a real player, and every one failed the same way -- the
conditional resolves to nothing, and the cast has nowhere to go:

    [@nameplate4]            UI ERROR: You have no target
    [@nameplate4,help]       UI ERROR: You have no target
    [@Corvin Ashgrove]            UI ERROR: You have no target
    [@Papa]                  UI ERROR: You have no target
    [@focus] after /focus    UI ERROR: You have no target
    [@mouseover]             UI ERROR: You have no target
    type=spell + unit=       nothing at all

What works is hard targeting:

    /target Elara Brightmoor
    /cast Arcane Intellect
    -> CAST SENT 1459 -> Elara Brightmoor   [target then cast]
    -> CAST OK 1459

So that is what it does now, including the space in the name. Your previous
target is handed straight back with /targetlasttarget, which can be turned off
under Who to buff.

This also closes out nine earlier attempts that were all aimed at the wrong
layer. A bare `/cast` with no target casts on you perfectly well, and a `/say`
on the next line of the same macro went out fine while the `/cast` above it did
nothing -- the button, the click, the macro and the spell were never broken.
Only naming somebody else was.

### Added

- `/manners probe` cycles every targeting form, one per click, and names the
  one that lands. This is what found the answer.
- `/manners selftest` arms a bare cast with no target, which proves the spell
  and the button independently of any targeting question.
- `/manners restore` toggles handing your target back.

## 1.3.0 (early numbering, before 0.9)

### The cast, again

Matched the secure button configuration to the ones that provably work on this
client, exactly rather than partially. All three of them -- MountActions,
GroupTools, CombatDungeon -- use the same trio, and the two settings go
together:

    RegisterForClicks("AnyDown")
    type = "macro"
    pressAndHoldAction = true

Registering down while leaving `pressAndHoldAction` false, which is where this
was, leaves the click arriving and the attributes reading back correctly with
nothing cast. The spell/unit attribute form is documented and did nothing here,
so it is gone; every working button on this client casts through macro text,
including the one that summons a mount.

There is no `C_ClickBindings` on this client, so Blizzard's own click-casting
route does not exist as an alternative.

### Fixed

- **The macro never tried the bare first name.** `ShortName` splits on `-`, so
  with a surname it returned the whole thing. Whether the game wants `Petra` or
  `Petra Stonewell` depends on whether the second word is a surname or part of the
  character name, which an addon cannot find out -- so both are offered now and
  the game picks whichever resolves.

  **Since retired.** That mechanism was removed: the full name does resolve
  on this client, so the failure it guarded against was never once observed,
  and offering two spellings aimed casts -- and spoken lines -- at whoever
  else shared a first name. See the note in `Core.lua` above
  `ExpirePendingClick`. Do not restore it from this entry.

- **"Buff state unreadable on this build" was shown when nothing had been
  read.** Setting *always offer* skips the aura check entirely, which left the
  state nil -- and nil rendered as the client refusing us. Choosing not to look
  and looking and being refused are now different things.
- **The favour baseline was taken too late.** The first aura scan decides what
  counts as pre-existing, and it only ran when `UNIT_AURA` next fired. Anyone
  who buffed you before that was recorded as something you already had. The
  baseline is now taken on login.
- **Range was checked by spell name**, which has to be resolved against the
  spellbook first; by id where one is known.

### Hardened

- Every fixed-value setting is validated against its set: the three-way buffed
  choice, prompt style, accent placement, flash style, both anchors, and the
  pinned buff -- which is dropped if it belongs to a class you are not. An
  unrecognised value otherwise falls through every branch that handles it into
  whatever the last `else` happens to be.
- Colours are checked for being three numbers before being read as such.

### Tests

- **`tests/scenarios.lua`** -- twelve adversarial scenarios rather than the
  happy path: a class with nothing to give, a dead player, combat lockdown, a
  client where every value is secret, a client where every API is missing, a
  profile full of values no slider could produce, the modes that must never
  cast, speech that could break the macro, and names the client might plausibly
  return. Each one drives the full lifecycle and fails on anything thrown.
- The garbage-profile scenario was mutation-tested: removing a validation makes
  it fail, which is the only evidence that a passing test means anything.

## 1.2.0 (early numbering, before 0.9)

### The cast

Clicking the prompt did nothing, silently, for a long stretch of testing. The
click arrived, the button held correct attributes, and the game cast nothing and
reported nothing.

The cause: the button registered for **mouse up only**. Every secure button that
works on this client registers for **down** — `MountActions` and `GroupTools`
both use `"AnyDown"`, and one carries the comment *"force the action to trigger
on key down regardless of ActionButtonUseKeyDown"*. With up only, `PostClick`
still fires and the attributes still read back correctly, so from the outside it
is indistinguishable from a broken button.

Now registers `"AnyUp", "AnyDown"` with `pressAndHoldAction = false`.

### Fixed

- **A stale unit token could buff the wrong player.** The key that decides
  whether to rebuild the cast ignored the unit token, so a nameplate index
  handed to somebody else while the name stayed the same left the button aimed
  at whoever held it now.
- **The target is re-resolved in `PreClick`**, the last moment before the secure
  handler reads the attributes, so nothing stale can be cast at.
- **The target no longer churns.** Re-sorting every tick swapped who was offered
  while the cursor was over the prompt: the tooltip described one person and the
  button was aimed at another.
- **Names were invented.** `UnitName`'s second return is documented as the realm
  but carries a **surname** here — six players standing together came back with
  six different values. Joining them with a hyphen produced names like
  `Petra-Stonewell` that no targeting call could resolve.
- Speech rolled its phrase twice, so the line that chose the code path was not
  the line that got used.
- An unlocked or disabled prompt could still arm itself through `PreClick`.
- Macro creation assumed slot limits that differ between flavours.

### Hardened

- Nothing is offered while dead, charmed, in a vehicle, on a taxi, or out of
  mana — all of them buttons that could only fail.
- The aura cache is swept; a city put hundreds of players through it and nothing
  removed them.
- The tooltip refresher runs a few times a second rather than every frame.
- Click logging moved behind its own toggle, so ordinary use is quiet.

### Added

- **A test harness** (`tests/`) that loads the addon against a mock WoW API and
  drives its main paths. It catches calls to names that do not exist, handlers
  registered for events this client lacks, and misspelled APIs — the three
  faults that cost the most time here, none of which a syntax check can see.
  `tests/selftest.py` reintroduces each one to prove the harness still detects
  it.

## 1.1.0 (early numbering, before 0.9)

Everything below came out of testing against a live client; several were faults
that could not be found by reading the code.

### Fixed

- **The scanner never started.** `OnEnable` registered `LEARNED_SPELL_IN_TAB`,
  which this client does not have. Registering an unknown event throws, and that
  line sat directly above the call that starts the scan timer — so the prompt
  could never appear for anyone.
- **Nobody was ever eligible.** Unit power comes back as a secret value for
  players outside your group, so the "has a mana bar" test failed for everyone
  and mana-only buffs were filtered out universally. Class is readable when
  power is not.
- **Favours were never noticed.** WoW Forever does not deliver
  `COMBAT_LOG_EVENT_UNFILTERED` to addons at all.
- **Everyone showed as "unverified".** `skipIfBuffed and UnitHasBuff(...) or nil`
  collapsed a definite "they do not have it" into "cannot tell".
- **Nameplate units were invisible.** `namePlateUnitToken` read off the frame is
  secret here; the token from `NAME_PLATE_UNIT_ADDED` is not.
- Preview mode and the unlocked state both looked identical to a working prompt
  while quietly disabling it.

### Added

- **If they already have the buff**: leave them alone, offer a top-up once the
  timer runs low, or always offer.
- A **Create the macro** button, and `/manners macro`.
- Attention pulse that continues until the favour is returned.
- Self-recording diagnostics written to SavedVariables.

## 1.0.0 (early numbering, before 0.9)

First release.
