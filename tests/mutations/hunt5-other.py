# The fifth bug hunt's buff-data fixes, each put back and required to be
# caught by its scenario in tests/scenarios/hunt5-other.lua.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ own-class-talent-buffs
mutate("Buffs.lua",
       "\t\t\tgroup = { 25898 },\n\t\t\ttalent = true,\n",
       "\t\t\tgroup = { 25898 },\n",
       "hunt5-other: Kings not marked as a talent",
       expect="hunt5-other: talent-only buffs are marked on Classic Era", script=S)

mutate("Buffs.lua",
       "\t\t\tgroup = { 25899 },\n\t\t\ttalent = true,\n",
       "\t\t\tgroup = { 25899 },\n",
       "hunt5-other: Sanctuary not marked as a talent",
       expect="hunt5-other: talent-only buffs are marked on Classic Era", script=S)

mutate("Buffs.lua",
       "\t\t\tgroup = { 27681 },\n\t\t\tmanaOnly = true,\n\t\t\ttalent = true,\n",
       "\t\t\tgroup = { 27681 },\n\t\t\tmanaOnly = true,\n",
       "hunt5-other: Divine Spirit not marked as a talent",
       expect="hunt5-other: talent-only buffs are marked on Classic Era", script=S)

mutate("Buffs.lua",
       "\t\t\tranks = { 369459 },\n\t\t\tmanaOnly = true,\n\t\t\ttalent = true,\n",
       "\t\t\tranks = { 369459 },\n\t\t\tmanaOnly = true,\n",
       "hunt5-other: Source of Magic not marked as a talent",
       expect="hunt5-other: Source of Magic is a talent on retail", script=S)
