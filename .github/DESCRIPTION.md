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

The body lives in [curseforge-description.md](curseforge-description.md) and
nowhere else. It used to be repeated here in full, which meant every edit to
the listing had to be made twice or the two copies drifted apart -- and the one
that drifts is always the one nobody pastes from.

Paste that file whole into CurseForge's editor. Its rich-text editor takes
markdown formatting directly: headings, bold and tables all survive.

Before pasting, check it still agrees with `Manners.toc`. The listing says Mage
is tested in game and the other five classes are not, and it should never
quietly claim more than that.

## Screenshots (the gallery)

CurseForge and Wago each keep an image gallery beside the page body, uploaded
by hand, with a title and a description for every image. These five, in this
order -- the first is the one the listing leads with. They are made by
`tools/make-screenshots.py` into `.github/media/`; upload them again whenever
they are regenerated, or the gallery shows a prompt the addon no longer draws.

The body in `curseforge-description.md` does not embed them. The gallery sits
on the same page, and a copy in the body would be a second set to keep in step
-- the drift this file was split to stop.

| File | Title | Description |
|---|---|---|
| `manners-prompt.png` | Buff them back in one click | Somebody buffed you. Manners puts them on one button, glowing until the favour is returned. |
| `manners-reasons.png` | Why somebody is on the prompt | Your target, somebody who buffed you, somebody who asked in chat, your group, and passers-by missing your buff -- each in its own colour, offered in that order. |
| `manners-ledger.png` | The favour ledger | Who buffed you, whether you returned it, and who you buffed without being asked. Open it with /manners ledger. |
| `manners-languages.png` | In your language | English and nine translations, chosen by your game client. Shown here in German, Russian and Simplified Chinese. |
| `manners-palette.png` | A palette for colour blindness | Target, favour, group and passer-by colours redrawn for red-green colour blindness, one setting away under Prompt > Style. |
