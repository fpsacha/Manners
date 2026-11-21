# Manners -- translations and the options window's layout

How a player-facing string gets its eight translations, the addon's own words,
and the layout keys of the options window. Moved out of `CLAUDE.md`, word for
word; `CLAUDE.md` is the index, read first.

## Translations

Every player-facing string is `L["English text"]`, a literal (validate fails on
`L[variable]`). The key is the English; changing the English is a new key.
Validate fails on any locale missing a key or holding one the code no longer
asks for, so no new or changed string lands without all eight translations
(deDE esES frFR itIT koKR ptBR zhCN zhTW). No Russian, ever.

1. `python tools/locale_todo.py [--out DIR]`: `<code>.todo.json` per locale,
   each missing key mapped to `""`, and the counts.
2. Translate the values. Keep every `%s`, `{token}` and `|c...|r` as the English
   has them. Game terms -- spell, item, class, race and zone names, and the
   client's own UI words (nameplates, Key Bindings) -- use that client's
   official localized name (Wowhead in that language; GlobalStrings from
   Ketho/BlizzardInterfaceResources), never a free translation. Slash
   commands stay English.
3. `python tools/locale_add.py <code> <file.json> [...]` per locale: merges
   into `Locales/<code>.lua` without losing a line, checks with
   `tools/check_translation.py`, rebuilds with `tools/build_locale.py`.
4. `python tests/validate.py`.

The addon's own words, the same in every string: "passer-by" (never "nearby")
for somebody near you who is not in your group; "buff back" and *Buffing back*
for returning a favour; *Favour ledger* stays the ledger's name. A retired
string is removed from every locale by hand before `locale_add.py`, which
refuses to drop a line.

The options window's layout (`Options/Window/Layout.lua`, documented in its
header) has, since round 37: `buttons` (a run of buttons left to right),
`match` (two fields of one width), `offNotes` (path -> why a greyed row is
greyed, drawn by `W.OffNote`), `units` (path -> `{ kind, zero }`: the unit a slider's box shows and parses; `kind` is `seconds` (12 s, 5 min, 1 min 30 s), `minutes` (45 min, 2 h, 1 h 30 min), `percent` or `times`, `zero` the word for 0; a typed 5m or 1h is converted into the setting's own unit), `keywords` (search words) and `parents` (a
hidden control found by search, with the switch to turn on first: only while
that switch is off, and only where `parentsIf`, path -> function, does not
say the switch would show nothing, as for a courtesy another class has). A
fold marked `plain = true` holds no setting and gets no fine-print caption
over it (the hall of fame). A page of more than three titled sections
names its sub-divisions in `subpages` (lists of its section keys, seven at
most, an optional `title`; `tests/scenarios/subpages.lua` holds the shape):
a section named in none (the line a page opens with) is drawn with each. They live
in the layout, not the AceConfig definition, which rejects unknown keys.

The window's search (`Options/Window/Search.lua`) ranks a label at the start
of a word first, then a label with the query inside a word, a choice or a
keyword at a word start, the tooltip at a word start, then the section or
page. The query is ranked as typed and with US spellings folded to the UK
ones (`SPELLING`), and the better rank wins: Spanish and Portuguese write
"color" and "favor". A query that finds nothing and holds a space is tried
again without its filler words (`FILLER`, one whole translated string split on
spaces, built when first used); every word left must rank.

`python tools/locale_keys.py --missing <code>` lists the gaps of one locale.
