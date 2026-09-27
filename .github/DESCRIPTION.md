# Listing copy: what goes where

Nothing in this file is pasted anywhere as a whole. It says which file holds
the paste-ready text for each site, and holds the gallery captions both sites
share.

| Site | Field | Paste from |
|---|---|---|
| CurseForge | Summary (the one line under the name in search results and in the app) | [curseforge-description.md](curseforge-description.md), *Summary field* |
| CurseForge | Description (the project page body, Markdown) | [curseforge-description.md](curseforge-description.md), between the BEGIN and END markers |
| Wago | Description (Markdown, shorter) | [wago-description.md](wago-description.md), between the BEGIN and END markers |
| CurseForge and Wago | Image gallery | the five files below, uploaded by hand |

The GitHub page is the [README](../README.md), written for somebody who has
found the source; the listings are written for somebody deciding whether to
install.

Keep all three agreeing with `Manners.toc`: Mage is tested in game and the
other classes are not, and no listing should quietly claim more.

## Summary alternates

The summary in use is in `curseforge-description.md`, and matches the toc's
`## Notes`. A reader scanning twenty addons gives it about two seconds, so it
leads with what the addon does. If the tone should change:

| | |
|---|---|
| plainest | Buff people back. One click, no hunting through nameplates for the name. |
| function first | Shows you who buffed you and who nearby is missing your buff. One click to sort it. |
| shortest | Never forget to buff somebody back. |
| a little warmer | For people who like buffing strangers, and keep losing them in the crowd. |

## Screenshots (the gallery)

CurseForge and Wago each keep an image gallery beside the page body, uploaded
by hand, with a title and a description for every image. These five, in this
order: the first is the one the listing leads with. They are made by
`tools/make-screenshots.py` into `.github/media/`; upload them again whenever
they are regenerated, or the gallery shows a prompt the addon no longer draws.

The descriptions also embed them, from
`https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/`, so
the page shows them inline once `master` is pushed. The gallery copies are
still needed: they are what the sites show as the listing's images.

| File | Title | Description |
|---|---|---|
| `manners-prompt.png` | Buff them back in one click | Somebody buffed you. Manners puts them on one button, glowing until the favour is returned. |
| `manners-reasons.png` | Why somebody is on the prompt | Your target, somebody who buffed you, somebody who asked in chat, your group, and passers-by missing your buff -- each in its own colour, offered in that order. |
| `manners-ledger.png` | The favour ledger | Who buffed you, whether you returned it, and who you buffed without being asked. Open it with /manners ledger. |
| `manners-languages.png` | In your language | English and eight translations, chosen by your game client. Shown here in German, French and Simplified Chinese. |
| `manners-palette.png` | A palette for colour blindness | Target, favour, group and passer-by colours redrawn for red-green colour blindness, one setting away under Prompt > Style. |
