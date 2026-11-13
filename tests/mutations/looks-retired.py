# Mutations for the four retired looks (Framed, Luxe, Arcane, Toast): the keys a
# profile may still hold, the move to each one's heir, the one line that says
# so, and the picker and the dropdown offering only what remains
# (Looks/Looks.lua, Core.lua's ClampSettings, Options/Look.lua,
# Options/Window/WidgetsTheme.lua). Each undoes a part of it and is caught by
# the scenario in tests/scenarios/looks-retired.lua it names.
#
# Run by tests/selftest.py with mutate() in scope.

S = "runscenarios.py"
T = "looks-retired: "
LINE = "The look %s has been retired, so your prompt now wears %s. The other looks are on the Look page."

# --- the move ---------------------------------------------------------------

# No move at all: a retired key is nonsense to the repair below it, which hands
# back the default, so an Arcane or a Toast player wakes up on Glass.
mutate("Core.lua",
       "\t\tlocal heir = ns.Looks.Heir(was)\n",
       "\t\tlocal heir = nil\n",
       "looks-retired: a retired look is reset to the default, not moved to its heir",
       expect=T + "a profile saved with toast logs in wearing ribbon", script=S)

# The heir worked out and never written.
mutate("Core.lua",
       "\t\t\tp.style = heir\n",
       "",
       "looks-retired: the heir is announced and the style left for the default",
       expect=T + "a profile saved with arcane logs in wearing archmage", script=S)

# Arcane's players sent to Glass with Framed's and Luxe's.
mutate("Looks/Looks.lua",
       'arcane = "archmage", toast = "ribbon" }',
       'arcane = "glass", toast = "ribbon" }',
       "looks-retired: Arcane's heir is Glass",
       expect=T + "a profile saved with arcane logs in wearing archmage", script=S)

# An heir that is itself retired: the profile lands on nothing and is reset.
mutate("Looks/Looks.lua",
       'arcane = "archmage", toast = "ribbon" }',
       'arcane = "archmage", toast = "luxe" }',
       "looks-retired: Toast's heir is a look that is retired too",
       expect=T + "Looks.Allowed() refuses the retired keys and keeps the rest", script=S)

# Framed forgotten among the retired: its key is nonsense again, and though the
# default it falls back to is its heir, nobody is told.
mutate("Looks/Looks.lua",
       'Looks.retired = { framed = "glass", luxe = "glass",',
       'Looks.retired = { luxe = "glass",',
       "looks-retired: Framed is not among the retired",
       expect=T + "a player who wore framed is told once, by both names", script=S)

# The oldest name sent straight to Glass, past the retirement: no line.
mutate("Core.lua",
       '\tif p.style == "blizzard" then p.style = "framed" end\n',
       '\tif p.style == "blizzard" then p.style = "glass" end\n',
       "looks-retired: the oldest name is moved to Glass without a word",
       expect=T + "a player who wore blizzard is told once, by both names", script=S)

# --- the line ---------------------------------------------------------------

# Moved and never told.
mutate("Core.lua",
       "\t\t\tif C_Timer and C_Timer.After then\n\t\t\t\tC_Timer.After(6, function()\n",
       "\t\t\tif false then\n\t\t\t\tC_Timer.After(6, function()\n",
       "looks-retired: the move is made without a line",
       expect=T + "a player who wore luxe is told once, by both names", script=S)

# Said during the load, under the login's own lines.
mutate("Core.lua",
       "\t\t\t\tC_Timer.After(6, function()\n\t\t\t\t\tns.Guard(\"retired look\", function()\n",
       "\t\t\t\tC_Timer.After(0, function()\n\t\t\t\t\tns.Guard(\"retired look\", function()\n",
       "looks-retired: the line does not wait for the screen",
       expect=T + "the line waits until the screen is up", script=S)

# The heir named twice: the player is not told which look went.
mutate("Core.lua",
       '"|cffffffff" .. (ns.Looks.Card(was)) .. "|r",',
       '"|cffffffff" .. (ns.Looks.Card(heir)) .. "|r",',
       "looks-retired: the line names the heir twice",
       expect=T + "a player who wore toast is told once, by both names", script=S)

# The look that went named twice: the player is not told what they wear now.
mutate("Core.lua",
       '"|cffffffff" .. (ns.Looks.Card(heir)) .. "|r"))',
       '"|cffffffff" .. (ns.Looks.Card(was)) .. "|r"))',
       "looks-retired: the line names the retired look twice",
       expect=T + "a player who wore arcane is told once, by both names", script=S)

# A retired look with no name left: the line says its key.
mutate("Looks/Looks.lua",
       "\tif not look and RETIRED_TITLE[key] then return RETIRED_TITLE[key], \"\" end\n",
       "",
       "looks-retired: a retired look has no name for the line",
       expect=T + "a retired look keeps its name for the line, and nothing else", script=S)

# Every profile told, whatever it wears, at every login.
mutate("Core.lua",
       "\t\tlocal heir = ns.Looks.Heir(was)\n",
       "\t\tlocal heir = ns.Looks.Heir(was) or was\n",
       "looks-retired: every profile is told its look was retired",
       expect=T + "a profile on glass keeps it and is told nothing", script=S)

# The same, read from the other end: said again at the login after.
mutate("Core.lua",
       "\t\tif heir then\n\t\t\tp.style = heir\n",
       "\t\tif heir or was == \"archmage\" then\n\t\t\their = heir or was\n\t\t\tp.style = heir\n",
       "looks-retired: an heir's players are told again at every login",
       expect=T + "nothing is said at the login after", script=S)

# The German line gone: a German client reads it in English.
mutate("Locales/deDE.lua",
       'L["' + LINE + '"] = ',
       'L["' + LINE + ' (old)"] = ',
       "looks-retired: the German line for a retired look is missing",
       expect=T + "a German client is told in German", script=S)

# --- the registry, the picker and the dropdown ---------------------------------

# A retired key that something registers may be saved again.
mutate("Looks/Looks.lua",
       "\t\tif not Looks.retired[key] then out[key] = true end\n",
       "\t\tout[key] = true\n",
       "looks-retired: a retired key registered again may be saved",
       expect=T + "Looks.Allowed() refuses the retired keys and keeps the rest", script=S)

# ...and is offered again.
mutate("Looks/Looks.lua",
       "\t\tif not Looks.retired[key] then\n\t\t\tvalues[key] = look.name\n",
       "\t\tif true then\n\t\t\tvalues[key] = look.name\n",
       "looks-retired: a retired key registered again is offered",
       expect=T + "Looks.Allowed() refuses the retired keys and keeps the rest", script=S)

# Framed back among the looks Prompt/Panel.lua is said to draw: in no picker,
# and still a key the registry answers for, with nothing behind it.
mutate("Looks/Looks.lua",
       "\tminimal = { name = L[\"Minimal -- text only, no panel\"], order = 12, native = true,",
       "\tframed = { name = \"Framed\", order = 11, native = true },\n"
       "\tminimal = { name = L[\"Minimal -- text only, no panel\"], order = 12, native = true,",
       "looks-retired: Framed is back in the registry with nothing to draw it",
       expect=T + "a retired look keeps its name for the line, and nothing else", script=S)

# The fallback dialog's dropdown offering a look that is gone.
mutate("Options/Look.lua",
       "\t\t\t\tvalues = (ns.Looks.Choices()),\n",
       "\t\t\t\tvalues = (function() local v = ns.Looks.Choices() v.luxe = \"Luxe\" return v end)(),\n",
       "looks-retired: the dropdown offers Luxe",
       expect=T + "the picker and the dropdown offer exactly the looks that remain", script=S)

# The picker drawing a card for one.
mutate("Options/Window/WidgetsTheme.lua",
       "\t\tlocal _, values = ns.Looks.Choices()\n",
       "\t\tlocal _, values = ns.Looks.Choices()\n\t\tvalues[#values + 1] = \"toast\"\n",
       "looks-retired: the picker shows a card for Toast",
       expect=T + "the picker and the dropdown offer exactly the looks that remain", script=S)

# --- what ships --------------------------------------------------------------

# Framed's rim named by the prompt again, with no file behind the name.
mutate("Prompt/Prompt.lua",
       "local BEZEL_ROUND = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\IconBezelRound\"\n",
       "local BEZEL_ROUND = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\IconBezelRound\"\n"
       "local TOOLTIP_RIM = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\TooltipRim\"\n",
       "looks-retired: the prompt names Framed's rim again",
       expect=T + "nothing of the four still ships", script=S)
