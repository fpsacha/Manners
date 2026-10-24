# Mutations for how long each buff lasts and the top-up that comes by it (round 32):
# the table of lengths (Buffs.lua), the lead worked out from it and by who it is for
# (Core.lua), the aura's own word, the entries and the tooltip, /manners debug and
# Diagnostics, and the raid setting's repair, reset and place. Each undoes one piece
# and is caught by the scenario in tests/scenarios/hunt32-durations.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
NAMES = "hunt32-durations: "

# ------------------------------------------------------------ the formula
# A share of the length that is not a tenth: a ten-minute buff is no longer topped up a minute before.
mutate("Core.lua",
       "\tlocal SHARE, FLOOR, CAP, CAP_PER_HOUR, CAP_MAX = 0.10, 15, 300, 120, 600\n",
       "\tlocal SHARE, FLOOR, CAP, CAP_PER_HOUR, CAP_MAX = 0.50, 15, 300, 120, 600\n",
       "hunt32-durations: the share of the length",
       expect=NAMES + "camelot: the lead of a 10-minute, 30-minute, 1-hour and 2-hour buff",
       script=S)

# No floor: a two-minute shout is due with a few seconds left.
mutate("Core.lua",
       "\tlocal SHARE, FLOOR, CAP, CAP_PER_HOUR, CAP_MAX = 0.10, 15, 300, 120, 600\n",
       "\tlocal SHARE, FLOOR, CAP, CAP_PER_HOUR, CAP_MAX = 0.10, 1, 300, 120, 600\n",
       "hunt32-durations: no floor",
       expect=NAMES + "camelot: the lead of a 10-minute, 30-minute, 1-hour and 2-hour buff",
       script=S)

# A cap that does not grow with the length: two hours is no more than one.
mutate("Core.lua",
       "\tlocal SHARE, FLOOR, CAP, CAP_PER_HOUR, CAP_MAX = 0.10, 15, 300, 120, 600\n",
       "\tlocal SHARE, FLOOR, CAP, CAP_PER_HOUR, CAP_MAX = 0.10, 15, 300, 0, 600\n",
       "hunt32-durations: a cap that does not grow",
       expect=NAMES + "camelot: the lead of a 10-minute, 30-minute, 1-hour and 2-hour buff",
       script=S)

# The slider no longer a ceiling: a profile that said three minutes gets five.
mutate("Core.lua",
       "\t\t\tif lead > ceiling then lead = ceiling end\n",
       "",
       "hunt32-durations: the slider not a ceiling",
       expect=NAMES + "camelot: the old slider is the ceiling and the raid setting a multiplier",
       script=S)

# A buff topped up the moment it lands (a twenty-second buff, a five-minute blessing in a raid).
mutate("Core.lua",
       "\t\tif seconds and lead > seconds / 2 then lead = seconds / 2 end\n",
       "",
       "hunt32-durations: a lead beyond half the buff",
       expect=NAMES + "camelot: the lead of a 10-minute, 30-minute, 1-hour and 2-hour buff",
       script=S)

# Strangers get the group's lead.
mutate("Core.lua",
       "\t\t\tif lead > STRANGER then lead = STRANGER end\n",
       "",
       "hunt32-durations: a stranger given the group's lead",
       expect=NAMES + "camelot: the lead of a 10-minute, 30-minute, 1-hour and 2-hour buff",
       script=S)

# Your own buffs given nobody else's lead.
mutate("Core.lua",
       "\t\t\tif kind == OWN_KIND or kind == OWN_RAID_KIND then lead = lead * OWN_SHARE end\n",
       "",
       "hunt32-durations: your own no earlier",
       expect=NAMES + "camelot: the lead of a 10-minute, 30-minute, 1-hour and 2-hour buff",
       script=S)

# A raid with no multiplier.
mutate("Core.lua",
       "\t\t\tif kind == RAID_KIND or kind == OWN_RAID_KIND then lead = lead * raid end\n",
       "",
       "hunt32-durations: a raid no earlier",
       expect=NAMES + "camelot: the lead of a 10-minute, 30-minute, 1-hour and 2-hour buff",
       script=S)

# An unknown length that is no longer the slider alone.
mutate("Core.lua",
       "\t\tlocal lead = ceiling\n\t\tif seconds then\n",
       "\t\tlocal lead = 0\n\t\tif seconds then\n",
       "hunt32-durations: an unknown length not the slider",
       expect=NAMES + "camelot: a length nobody knows is the slider alone",
       script=S)

# The memo outliving a change of the slider or the multiplier.
mutate("Core.lua",
       "\t\tif memoCeiling ~= minutes or memoRaid ~= raid then\n",
       "\t\tif false then\n",
       "hunt32-durations: a memo kept past a setting",
       expect=NAMES + "camelot: the old slider is the ceiling and the raid setting a multiplier",
       script=S)

# ------------------------------------------------------------ who it is for
# Nobody a stranger: the group's lead for a passer-by.
mutate("Core.lua",
       "\t\telseif not opts.inGroup then\n\t\t\tkind = STRANGER_KIND\n",
       "\t\telseif false then\n\t\t\tkind = STRANGER_KIND\n",
       "hunt32-durations: a passer-by given the group's lead in the walk",
       expect=NAMES + "camelot: a passer-by is topped up in the last half minute",
       script=S)

# A dungeon or a raid instance not read as one.
mutate("Core.lua",
       "\t\t\tyes = (inside == true or inside == 1) and (kind == \"party\" or kind == \"raid\")\n",
       "\t\t\tyes = false\n",
       "hunt32-durations: an instance not read as a raid",
       expect=NAMES + "camelot: in a raid or a dungeon the top-up comes earlier",
       script=S)

# Your own buff on yourself walked as anybody's.
mutate("Queue.lua",
       "\t\t-- Yours: a top-up comes earlier than for anybody else's (Core.lua, ns.LeadFor).\n\t\town = true,\n",
       "",
       "hunt32-durations: your own group buff not yours",
       expect=NAMES + "camelot: your own group buff on yourself is topped up as your own",
       script=S)

# One of your own buffs given the group's lead.
mutate("Core.lua",
       "\t\t\t\tlead, kind = ns.OwnLead(ctx, seconds)\n",
       "\t\t\t\tlead, kind = ns.TopUpLead(seconds, ns.LEAD_KIND.group, ctx.refreshUnder)\n",
       "hunt32-durations: your own buff given the group's lead",
       expect=NAMES + "camelot: your own buff is topped up earlier than somebody else's",
       script=S)

# ------------------------------------------------------------ the aura's own word
# The aura's length ignored in the walk: the table's, whatever the aura says.
mutate("Core.lua",
       "\t\tif type(seconds) == \"number\" and seconds > 0 then return seconds end\n",
       "",
       "hunt32-durations: the walk ignoring the aura's length",
       expect=NAMES + "camelot: the aura's real duration beats the table",
       script=S)

# ...and the reader never taking it off the aura.
mutate("Core.lua",
       "\t\t\t\tif type(length) == \"number\" and length > 0 then duration = length end\n",
       "",
       "hunt32-durations: the aura's length never read",
       expect=NAMES + "camelot: the aura's real duration beats the table",
       script=S)

# An aura that says nothing is no longer the table's.
mutate("Core.lua",
       "\t\tif listed and listed > 0 then duration = listed end\n",
       "",
       "hunt32-durations: no fall back on the table",
       expect=NAMES + "vanilla: the aura's real duration beats the table",
       script=S)

# ------------------------------------------------------------ no timer, no reading
# An aura with no expiry (0) read as one that is already out.
mutate("Core.lua",
       "\t\t\t\tif type(expiration) == \"number\" and expiration > 0 then expires = expiration end\n",
       "\t\t\t\texpires = expiration\n",
       "hunt32-durations: no timer read as run out",
       expect=NAMES + "camelot: no timer, or none that can be read, is never topped up",
       script=S)

# An aspect or an aura with a length.
mutate("Buffs.lua",
       "\tif family and (family.toggle or family.tracking) then return 0 end\n",
       "",
       "hunt32-durations: an aspect with a length",
       expect=NAMES + "camelot: an aura or an aspect has no timer and is never topped up",
       script=S)

# ------------------------------------------------------------ the table
# A wrong length for a buff of the vanilla set.
mutate("Buffs.lua",
       "\t\t{ 1800, 10938, 10937, 2791, 1245, 1244, 1243 }, -- Power Word: Fortitude (30 min)\n",
       "\t\t{ 3600, 10938, 10937, 2791, 1245, 1244, 1243 }, -- Power Word: Fortitude (30 min)\n",
       "hunt32-durations: a wrong length for Fortitude",
       expect=NAMES + "vanilla: every id the set holds has a length, or none by design: Power Word: Fortitude lasts",
       script=S)

# An id the set holds with no length.
mutate("Buffs.lua",
       "\t\t{ 600, 5697 }, -- Unending Breath (10 min)\n",
       "",
       "hunt32-durations: an id with no length",
       expect=NAMES + "vanilla: every id the set holds has a length",
       script=S)

# Forever's shout as Classic Era's.
mutate("Buffs.lua",
       "\t\t{ 180, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }, -- Battle Shout (3 min)\n",
       "\t\t{ 120, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }, -- Battle Shout (3 min)\n",
       "hunt32-durations: Forever's shout as Classic Era's",
       expect=NAMES + "camelot: battleshout lasts 180 seconds",
       script=S)

# Mists' Blessing of Might as five minutes.
mutate("Buffs.lua",
       "\t\t{ 3600, 19740 }, -- Blessing of Might (1 h)\n",
       "\t\t{ 300, 19740 }, -- Blessing of Might (1 h)\n",
       "hunt32-durations: Mists' Might as five minutes",
       expect=NAMES + "mists: might lasts 3600 seconds",
       script=S)

# The group version's length said even where it is the single's.
mutate("Buffs.lua",
       "\tif group == single then group = nil end\n",
       "",
       "hunt32-durations: a group length equal to the single's said",
       expect=NAMES + "camelot: every id the set holds has a length, or none by design",
       script=S)

# ------------------------------------------------------------ the entry, the tooltip, the words
# A top-up entry that says nothing of its length and lead.
mutate("Queue.lua",
       "\t\t\tmade.duration, made.lead, made.leadKind = seconds, lead, leadKind\n",
       "",
       "hunt32-durations: an entry without its lead",
       expect=NAMES + "camelot: a group member is topped up at the lead, not before",
       script=S)

# A tooltip that does not say how long it lasts.
mutate("Prompt/Button.lua",
       "\t\tif entry.duration and entry.lead then\n",
       "\t\tif false then\n",
       "hunt32-durations: a tooltip without the length",
       expect=NAMES + "camelot: the tooltip says how long it lasts and why now",
       script=S)

# ...or why a raid's comes early.
mutate("Prompt/Button.lua",
       "\t\t\tlocal why = kind == \"raid\" and L[\"In a raid or dungeon, so earlier than usual.\"]\n",
       "\t\t\tlocal why = kind == \"raid\" and nil\n",
       "hunt32-durations: a tooltip without the raid's reason",
       expect=NAMES + "camelot: the tooltip says how long it lasts and why now",
       script=S)

# /manners debug without the group version's length.
mutate("Commands.lua",
       "\t\t\tif single and group then lasts = lasts .. \" \" .. L[\"(%s as a group cast)\"]:format(Text(group)) end\n",
       "",
       "hunt32-durations: debug without the group cast's length",
       expect=NAMES + "vanilla: /manners debug and Diagnostics say when a top-up is due",
       script=S)

# The Diagnostics page not drawing them.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"diagnostics.leadDiag\",\n",
       "",
       "hunt32-durations: Diagnostics not drawing the leads",
       expect=NAMES + "camelot: /manners debug and Diagnostics say when a top-up is due",
       script=S)

# ------------------------------------------------------------ the setting
# The raid setting not repaired.
mutate("Core.lua",
       "\t{ \"filters\", \"refreshRaid\", 1, 4 },\n",
       "",
       "hunt32-durations: the raid setting not repaired",
       expect=NAMES + "the raid setting is repaired, reset and on the page",
       script=S)

# ...with another default.
mutate("Core.lua",
       "\t\t\trefreshRaid = 2,\n",
       "\t\t\trefreshRaid = 3,\n",
       "hunt32-durations: the raid setting with another default",
       expect=NAMES + "the raid setting is repaired, reset and on the page",
       script=S)

# ...and not reset with its page.
mutate("Options/Advanced.lua",
       "\"filters.refreshUnder\", \"filters.refreshRaid\", ",
       "\"filters.refreshUnder\", ",
       "hunt32-durations: the raid setting not reset",
       expect=NAMES + "the raid setting is repaired, reset and on the page",
       script=S)

# ...nor beside the slider it works on.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"when.refreshRaid\", indent = true },\n",
       "",
       "hunt32-durations: the raid setting not placed",
       expect=NAMES + "the raid setting is repaired, reset and on the page",
       script=S)

# ...with the wrong end.
mutate("Options/When.lua",
       "\t\t\t\tmax = 4,\n\t\t\t\tstep = 0.5,\n",
       "\t\t\t\tmax = 8,\n\t\t\t\tstep = 0.5,\n",
       "hunt32-durations: the raid slider with the wrong end",
       expect=NAMES + "the raid setting is repaired, reset and on the page",
       script=S)
