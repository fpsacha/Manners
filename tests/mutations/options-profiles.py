# The Profiles tab (Options.lua, BuildProfilesTab): the line on what a profile
# is for, and the Share as text section under the library's controls. Each
# fault is caught by the scenario in tests/scenarios/options-profiles.lua that
# names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- the tab ---

# Profiles no longer last among the tabs.
mutate("Options/Profiles.lua",
       "\tt.order = 90\n",
       "\tt.order = 5\n",
       "profiles: the tab is not last",
       expect="tab comes after Profiles", script=S)

# The line on what a profile is for, gone.
mutate("Options/Profiles.lua",
       "\t\tprofilesIntro = {\n",
       "\t\tprofilesIntroGone = {\n",
       "profiles: no intro",
       expect="has no line saying what a profile is for", script=S)

# The intro under the library's own paragraph rather than above it.
mutate("Options/Profiles.lua",
       "\t\t\torder = 0.5,\n\t\t\tfontSize = \"medium\",\n"
       "\t\t\tname = L[\"Every character uses the Default profile",
       "\t\t\torder = 1.5,\n\t\t\tfontSize = \"medium\",\n"
       "\t\t\tname = L[\"Every character uses the Default profile",
       "profiles: intro below the library's paragraph",
       expect="sits below the library's own paragraph", script=S)

# --- the section ---

# Share as text among the library's own controls.
mutate("Options/Profiles.lua",
       "\t\tshareHeader = { type = \"header\", name = L[\"Share as text\"], order = 100 },\n",
       "\t\tshareHeader = { type = \"header\", name = L[\"Share as text\"], order = 0 },\n",
       "profiles: share header among the library's",
       expect="among the library's own controls", script=S)

# --- copy ---

# The box of settings always open.
mutate("Options/Profiles.lua",
       "\t\t\thidden = function() return not Page.shareOpen end,\n",
       "\t\t\thidden = function() return false end,\n",
       "profiles: settings box always open",
       expect="open before anybody asked for it", script=S)

# The button only ever opens it.
mutate("Options/Profiles.lua",
       "\t\t\t\tPage.shareOpen = not Page.shareOpen\n",
       "\t\t\t\tPage.shareOpen = true\n",
       "profiles: hide the text does not hide",
       expect="Hide the text left the box open", script=S)

# The button's label never changes to Hide.
mutate("Options/Profiles.lua",
       "\t\t\t\treturn Page.shareOpen and L[\"Hide the text\"] or L[\"Show my settings as text\"]\n",
       "\t\t\t\treturn L[\"Show my settings as text\"]\n",
       "profiles: copy button label never changes",
       expect="while the box is open", script=S)

# The box open but empty.
mutate("Options/Profiles.lua",
       "\t\t\tget = function() return ns.ExportSettings() or \"\" end,\n",
       "\t\t\tget = function() return \"\" end,\n",
       "profiles: settings box empty",
       expect="does not hold this profile's settings", script=S)

# --- paste ---

# The paste box back to a label that never says how to apply it.
mutate("Options/Profiles.lua",
       "\t\t\tname = L[\"Paste settings here, then press Accept\"],\n",
       "\t\t\tname = L[\"Paste settings to use them\"],\n",
       "profiles: paste box does not say Accept",
       expect="does not say to press Accept", script=S)

# Anything let through the paste box.
# The tab opening with the same paragraph twice.
mutate("Options/Profiles.lua",
       "\tif type(t.args.desc) == \"table\" then t.args.desc.hidden = true end\n",
       "",
       "profiles: the library's paragraph repeats the intro",
       expect="the library's own paragraph repeats the profiles intro", script=S)

# The share boxes, under the library's controls, not pointed at.
mutate("Options/Profiles.lua",
       "\t\t\t\t.. \" \" .. L[\"To share settings as text, see Share as text at the bottom.\"] .. \"\\n\",\n",
       "\t\t\t\t.. \"\\n\",\n",
       "profiles: share boxes not pointed at",
       expect="the profiles intro does not say Share as text", script=S)

mutate("Options/Profiles.lua",
       "\t\t\t\tif not parsed then return err end\n",
       "",
       "profiles: paste box accepts anything",
       expect="accepted text that is not settings", script=S)

# A paste that applies nothing.
mutate("Options/Profiles.lua",
       "\t\t\t\tlocal _, message = ns.ImportSettings(value)\n",
       "\t\t\t\tlocal message = \"\"\n",
       "profiles: paste applies nothing",
       expect="pasting settings did not apply them", script=S)
