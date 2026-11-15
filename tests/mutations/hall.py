# Mutations for the hall of fame (Hall.lua: the code, who has one, the list;
# Milestones.lua's LastEarned and the line when the last milestone lands;
# Options/Start.lua's section and Options/Window/Layout.lua's fold for it;
# tools/hall.py's vectors). Each is caught by the scenario in
# tests/scenarios/hall.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "hall: "
ROUND = P + "a code round-trips, a two-word and an accented name too, and tools/hall.py agrees"
BENT = P + "a changed character fails the checksum"
BEFORE = P + "before every milestone is earned the section says how many, and there is no code"
DONE = P + "every milestone earned, the code is this character's"
REALM = P + "a client with realms puts the realm in the code, Forever does not"
OFF = P + "hidden with milestones switched off"
LIST = P + "the list is newest first in class colours, marks your own name"
WINDOW = P + "the window draws it in a fold on Start here"

# The code.
mutate("Hall.lua",
       "\t\th = (h * 33 + text:byte(i)) % 4294967296\n",
       "\t\th = (h * 31 + text:byte(i)) % 4294967296\n",
       "hall: the checksum is not the one tools/hall.py makes",
       expect=ROUND, script=S)
mutate("Hall.lua",
       "local SALT = \"Manners\"\n",
       "local SALT = \"\"\n",
       "hall: the checksum loses its salt",
       expect=ROUND, script=S)
mutate("tools/hall.py",
       "MANNERS1-CAMELOT-MAGE-20261114-4D6F7274204465667265747465-0-DA8EF87D",
       "MANNERS1-CAMELOT-MAGE-20261114-4D6F7274204465667265747465-0-DA8EF87E",
       "hall: tools/hall.py holds a code the addon does not make",
       expect=ROUND, script=S)
mutate("Hall.lua",
       "\treturn (text:gsub(\".\", function(c) return (\"%02X\"):format(c:byte()) end))\n",
       "\treturn (text:gsub(\"%w\", function(c) return (\"%02X\"):format(c:byte()) end))\n",
       "hall: a space or an accent goes into the code as it is",
       expect=ROUND, script=S)
mutate("Hall.lua",
       "\tif type(name) ~= \"string\" or name == \"\" or #name > MAX_BYTES then return nil end\n",
       "\tif type(name) ~= \"string\" then return nil end\n",
       "hall: a code for no name or an endless one",
       expect=ROUND, script=S)
mutate("Hall.lua",
       "\tif Checksum(body) ~= check then return nil, \"checksum\" end\n",
       "",
       "hall: the checksum is never asked",
       expect=BENT, script=S)
mutate("Hall.lua",
       "\tcode = code:gsub(\"%s\", \"\"):upper()\n",
       "",
       "hall: a pasted code must be exact to the letter's case",
       expect=BENT, script=S)

# Who has one.
mutate("Hall.lua",
       "\treturn earned, of, of > 0 and earned >= of\n",
       "\treturn earned, of, of > 0 and earned >= of - 1\n",
       "hall: the hall opens one milestone early",
       expect=BEFORE, script=S)
mutate("Hall.lua",
       "\tif not done then return nil end\n\tlocal who = Me()\n",
       "\tlocal who = Me()\n",
       "hall: a code before the last milestone",
       expect=BEFORE, script=S)
mutate("Hall.lua",
       "\treturn TEXT.PROGRESS:format(earned, of)\n",
       "\treturn TEXT.INVITE\n",
       "hall: invited before the hall opens",
       expect=BEFORE, script=S)
mutate("Options/Start.lua",
       "\t\t\t\thidden = function() return not (ns.Hall and ns.Hall.Shown() and ns.Hall.Code() ~= nil) end,\n",
       "\t\t\t\thidden = function() return not (ns.Hall and ns.Hall.Shown()) end,\n",
       "hall: an empty code box before the hall opens",
       expect=BEFORE, script=S)
mutate("Milestones.lua",
       "\t\tif not last or when > last then last = when end\n",
       "\t\tif not last or when < last then last = when end\n",
       "hall: the code is dated the first milestone",
       expect=DONE, script=S)
mutate("Milestones.lua",
       "\tif new > 0 and not quiet and ns.Hall then ns.Hall.Announce() end\n",
       "",
       "hall: the last milestone says nothing of the hall",
       expect=DONE, script=S)
mutate("Milestones.lua",
       "\tif new > 0 and not quiet and ns.Hall then ns.Hall.Announce() end\n",
       "\tif not quiet and ns.Hall then ns.Hall.Announce() end\n",
       "hall: the hall is announced again and again",
       expect=DONE, script=S)
mutate("Hall.lua",
       "\tif done then return TEXT.INVITE end\n",
       "",
       "hall: no invitation once the hall is open",
       expect=DONE, script=S)
mutate("Options/Window/WidgetsEntry.lua",
       "\t[\"general.hallCode\"] = true }\n",
       "\t}\n",
       "hall: the code in a box that takes typing",
       expect=WINDOW, script=S)
mutate("Hall.lua",
       "\tif not (caps and caps.unitNameIsSurname) and type(_G.GetRealmName) == \"function\" then\n",
       "\tif type(_G.GetRealmName) == \"function\" then\n",
       "hall: Forever's code carries a realm",
       expect=REALM, script=S)
mutate("Hall.lua",
       "\t\tif type(value) == \"string\" then realm = value end\n",
       "",
       "hall: the realm never goes into the code",
       expect=REALM, script=S)

# Off with milestones.
mutate("Hall.lua",
       "\tif M.On() ~= true then return false end\n",
       "",
       "hall: shown with milestones switched off",
       expect=OFF, script=S)

# The list.
mutate("Hall.lua",
       "\t\tif a.date ~= b.date then return a.date > b.date end\n",
       "\t\tif a.date ~= b.date then return a.date < b.date end\n",
       "hall: the list oldest first",
       expect=LIST, script=S)
mutate("Hall.lua",
       "\tif type(code) == \"string\" then return (\"|c%s%s|r\"):format(code, name) end\n",
       "",
       "hall: names in no class colour",
       expect=LIST, script=S)
mutate("Hall.lua",
       "\t\tif IsMe(row, who) then line = TEXT.YOU:format(line) end\n",
       "",
       "hall: your own name is not marked",
       expect=LIST, script=S)
mutate("Hall.lua",
       "\treturn who ~= nil and Same(row.name, who.name) and row.client == who.client\n",
       "\treturn who ~= nil and Same(row.name, who.name)\n",
       "hall: a namesake on another client is marked as you",
       expect=LIST, script=S)
mutate("Hall.lua",
       "\tif #rows == 0 then return TEXT.EMPTY end\n",
       "",
       "hall: an empty hall is a bare heading",
       expect=LIST, script=S)
mutate("Hall.lua",
       "\tif Hall.Listed() then return TEXT.LISTED end\n",
       "",
       "hall: somebody listed is invited again",
       expect=LIST, script=S)
mutate("Hall.lua",
       "\tif not done or Hall.Listed() then return end\n",
       "\tif not done then return end\n",
       "hall: somebody listed is told the hall is open",
       expect=LIST, script=S)
mutate("Hall.lua",
       "\t\tif i > MAX_ROWS then\n",
       "\t\tif false then\n",
       "hall: a long list is drawn whole",
       expect=LIST, script=S)

# The window.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t{ key = \"general.hall\", header = \"general.hallHeader\", fold = true, plain = true, items = {\n",
       "\t\t\t\t{ key = \"general.hall\", header = \"general.hallHeader\", plain = true, items = {\n",
       "hall: the hall is no fold",
       expect=WINDOW, script=S)
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"general.hallNote\", standIn = true },\n\t\t\t\t\t\"general.hallCode\",\n\t\t\t\t\t{ \"general.hallList\", standIn = true },\n",
       "\t\t\t\t\t\"general.hallNote\",\n\t\t\t\t\t\"general.hallCode\",\n\t\t\t\t\t\"general.hallList\",\n",
       "hall: the section is not drawn until there is a code",
       expect=WINDOW, script=S)
