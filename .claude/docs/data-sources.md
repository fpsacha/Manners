# Manners -- data sources

Where spell, item, race and UI facts come from. `tools/clients_watch.py` and
`tools/audit_groups.py` read each client's build from the first bullet below,
the sentence on the builds the code cites (and through clients_watch,
`tools/audit_ids.py` and every generator that reads wago.tools): keep its
wording and its shape, `<client word> <build>`. Moved out of `CLAUDE.md`, word
for word; `CLAUDE.md` is the index, read first.

## Data sources

- **Spell, item and race data**: wago.tools DB2 tables for the exact build
  (`https://wago.tools/db2/<Table>/csv?build=<build>`): SpellName, Spell,
  SpellEffect, SpellLevels, SpellReagents, SpellMisc, SkillLineAbility,
  ItemSparse, ChrRaces, ... The builds cited in the code: Forever
  1.60.1.70790 (read at 1.60.1.70178 until hunt 34, and checked again against
  70450, 70532 and 70790), Classic Era 1.15.9.70003, TBC 2.5.6.69795, Mists
  5.5.4.70032, retail 12.1.0.69933. Forever's 1.60.1.70450 added three weapon
  items (`since` in `Buffs.lua`'s `ENHANCEMENTS`), changed Battle Shout's target
  from the caster's party (20) to the caster's raid (56, the radius unchanged),
  so Forever's set has no `partyIsSubgroup`, and renamed Salvation to
  "Salvation" and "Mass Salvation" (the audit takes either name). Build 1.60.1.70790 then deleted Salvation
  and Blessing of Light outright (ids 1038, 25895, 19977-19979, 25890), so
  Forever's paladin has Wisdom, Might and Kings only (`GONE` in `Buffs.lua`);
  Classic Era and Burning Crusade keep both, and the audit reads Forever at 70790. The audits
  read the build per client from this line.
- **Wowhead** per client (Classic, TBC Classic, MoP Classic, retail, and a
  Forever database) for tooltips, levels and "Requires" lines.
- **Blizzard's own UI code**: `Gethe/wow-ui-source`, one branch per client
  (`live`, `forever`, `classic` for Mists, `classic_anniversary` for TBC,
  `classic_era`, `ptr2`). Read how Blizzard's UI reads a thing before writing a
  reader for it.
- **API and globals per client**: `Ketho/BlizzardInterfaceResources` (API
  dumps, GlobalStrings, CVars) per branch.
- **Addons known to work on Forever**: the installed ones under
  `D:\wow\World of Warcraft\_classic_beta_\Interface\AddOns` (EnhanceQoL,
  QuestieDB with its Camelot data, ...). Grep them when the API misbehaves.
- Never guess a client string (race file, CVar, class token): the Haranir's
  race file is `Harronir` (ChrRaces 86 and 91), and friendly nameplates are
  `nameplateShowFriendlyPlayers` on Forever and retail but
  `nameplateShowFriends` on Classic (`ns.FRIENDLY_PLATES_CVARS`).
