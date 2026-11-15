# Pictures to upload at release

Neither CurseForge nor Wago takes pictures through its API, so the galleries
are filled by hand. This is the checklist: every file, in the order the gallery
shows them, with the title and the description to paste beside it. The order,
titles, descriptions and each picture's alt text live in one place,
`GALLERY` in `tools/make-screenshots.py`; this table and `.github/gallery.md`
follow it, and `tests/validate.py` fails when either does not. This file is not
shipped (`.pkgmeta` ignores `.github`).

The order tells the story a browsing player needs, first picture first: the
moment the addon is for (somebody buffed you, one press, your buff lands) and
the press itself on a key, a bar or a controller; who is offered; the looks;
the favour ledger and its milestones; the options window; then languages and
the colour-blind palette.

Redraw them first if anything in the addon's look changed since the last
commit of this folder:

```
python tools/make-screenshots.py --strict
git status .github/media      # clean: the files here are what the addon draws
```

## Where

- **CurseForge**: project 1705364, the images of its gallery. Each picture
  takes the title and the description below.
- **Wago**: addon `rNkgzlNa`, its screenshots. Where a picture takes one line
  only, use the title.

The same order on both, so the first picture a visitor sees is the moment the
addon is for. Replace the copies that are there rather than adding beside
them, and put them in this order even where a file name was there before: the
order changed with the new first picture.

The two animated pictures are GIFs, 800 pixels wide, 1.7 MB and 0.9 MB. If a
gallery refuses a GIF or shows it still, leave it out there: both play in the
CurseForge description, which embeds them from GitHub once `master` holds them.

## The files, in order

| # | File | Title | Description |
|---|---|---|---|
| 1 | `manners-prompt.png` | Somebody buffed you. One press. | Somebody buffed you in passing, and Manners puts them on the prompt. Click it or press your key: they get your buff back, your own target comes straight back, and the game confirms it. |
| 2 | `manners-actionbar.png` | On a key, a bar or a controller | Bind Buff the prompted player to a key, or drop the Manners macro on any action bar slot: the slot shows the spell a press would cast, with its cooldown. A controller button bound the same way works too, and the prompt shows the button's picture. |
| 3 | `manners-reasons.png` | Why somebody is on the prompt | Your target, somebody who buffed you, somebody who asked in chat, your group, and passers-by missing your buff -- each in its own colour, offered in that order. |
| 4 | `manners-more.png` | More than buffs | A resurrection for a dead member of your group, a cure for a poison, disease, curse or harmful spell, water, food or a portal for whoever asks a mage or a warlock in chat, and one polite whisper asking for a buff you are missing. Each has its own switch. |
| 5 | `manners-yourself.png` | Your own buffs too | When your own armor, poison or buff is missing, you come up on the prompt as "You": a mage's armor, a rogue's poison for the main hand, your own Arcane Intellect. |
| 6 | `manners-list.png` | Click any name | Switch on List the next few below (Look) and every name under the prompt is a button, with the icon of the buff they would get. Left-click buffs that person, right-click skips them for now, shift-right-click never offers them again. |
| 7 | `manners-tooltip.png` | A tooltip that stays out of the way | Hover the prompt for the Short tooltip: the name, the spell and why they are offered. Hold Shift for the Full one, which says what the press and each click do. Short, Full, Shift only or Off, and where it shows, under Look. |
| 8 | `manners-looks.png` | Looks to choose from | Glass, the default, then Luxe, Toast, Arcane, Ribbon, Letter, Leather, Forge, Archmage, Lightbringer, Fel, Wild, Frost, Stormcaller, Ebon, Gearworks, Warchief, Framed and Minimal, the same favour drawn in each; click a card under Look to switch. |
| 9 | `manners-look-stormcaller.gif` | Stormcaller, as a buff lands | Animated: somebody buffed you, you press, and chain lightning arcs from the totem to the standing stone. |
| 10 | `manners-look-lightbringer.gif` | Lightbringer, as a buff lands | Animated: somebody buffed you, you press, and the sun of the Light flares round your spell. |
| 11 | `manners-moment.png` | Three moments | Film strips of one favour, four frames each: somebody buffs you, your buff lands, the game refuses it. Frames at 0.05, 0.15, 0.30 and 0.60 seconds. |
| 12 | `manners-ledger.png` | The favour ledger | Who buffed you, whether you returned it, and who you buffed without being asked. Open it with /manners ledger. |
| 13 | `manners-milestones.png` | Milestones | Small things worth doing, kept on a tab of the favour ledger: earned ones with their date and a link to show in chat, the rest with how far along you are. A toast comes up when you earn one, and earning them all puts you among the Gentlefolk of Good Manners, the hall of fame. |
| 14 | `manners-options.png` | Set it up in one window | Open it with /manners or the minimap button. Shown on Start here in the Simple view, the short list of every page: two questions, one key, the favour ledger. Untick Simple view for everything; Move the prompt is one click away in the header. |
| 15 | `manners-options-wide.png` | Drag it wide | Drag the corner and a page flows into two columns, three on an ultrawide screen. Shown on Who to buff for a paladin: who is offered, what to cast, the group, More than buffs and Myself on one screen. |
| 16 | `manners-languages.png` | In your language | English and eight translations, chosen by your game client. Shown here in German, French and Simplified Chinese. |
| 17 | `manners-palette.png` | A palette for colour blindness | The five reason colours redrawn for red-green colour blindness, one setting away under Look > Style. |

## After

- Open each gallery signed out and look: seventeen pictures (fifteen where the
  GIFs were left out), in this order, none cut.
- The project's icon is `icon-512.png` (`icon-64.png` is the small one). It
  has not changed; upload it only if a site shows none.
- The description's own pictures come from
  `https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/`:
  they show once `master` holds this folder, with nothing to upload.
