# Hunt 34, fixes A (tests/scenarios/hunt33-clickui.lua, hunt33-decision.lua,
# hunt33-rows.lua, hunt33-weapons.lua and hunt34-fixesA.lua): the release of a
# held key (Prompt/Press.lua), a reload in a fight (Favours.lua), a /manners try
# macro from a name (Prompt/Macro.lua, Commands.lua), a hand let go when the cast
# succeeds (Core.lua, Clicks.lua), the singular group tooltip
# (Prompt/Button.lua), the name's room (Prompt/Text.lua and the looks) and the
# lines a language gives a man's voice (Phrases.lua). Each fault put back has to be
# caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the release of a held key
mutate("Prompt/Press.lua",
       "\tif down == false then return end\n\tif mouseButton and mouseButton ~= \"LeftButton\" then return end\n\tlocal now = GetTime()\n",
       "\tif mouseButton and mouseButton ~= \"LeftButton\" then return end\n\tlocal now = GetTime()\n",
       "hunt34-press: PreClick takes the release of a key for a press",
       expect="hunt33-press: the release of a", script=S)

mutate("Prompt/Press.lua",
       "\tif down == false then return end\n\t-- Whose press this is",
       "\t-- Whose press this is",
       "hunt34-press: PostClick files the release of a key as a press",
       expect="hunt33-press: the release of a", script=S)

# A click with no phase at all (a script's) is a press: only a false is an up.
mutate("Prompt/Press.lua",
       "\tif down == false then return end\n\tif mouseButton and mouseButton ~= \"LeftButton\" then return end\n\tlocal now = GetTime()\n",
       "\tif not down then return end\n\tif mouseButton and mouseButton ~= \"LeftButton\" then return end\n\tlocal now = GetTime()\n",
       "hunt34-press: a click with no phase taken for a release (PreClick)",
       expect="hunt34-press: a click with no down or up is a press", script=S)

mutate("Prompt/Press.lua",
       "\tif down == false then return end\n\t-- Whose press this is",
       "\tif not down then return end\n\t-- Whose press this is",
       "hunt34-press: a click with no phase taken for a release (PostClick)",
       expect="hunt34-press: a click with no down or up is a press", script=S)

