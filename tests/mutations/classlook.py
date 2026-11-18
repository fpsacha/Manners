# Mutations for Use my class's look on each character: tests/scenarios/classlook.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# switch, the repair that makes prompt.style follow the class, the picks kept
# per class, the picker's line, the Look page's reset or a settings string
# could plausibly make, and names the scenario that objects.

LOOKS = "Looks/Looks.lua"
T = "Options/Window/WidgetsTheme.lua"
LOOK = "Options/Look.lua"
ADV = "Options/Advanced.lua"
LAYOUT = "Options/Window/Layout.lua"
S = "runscenarios.py"

# --- the switch, the repair and the picks -----------------------------------

mutate("Core.lua", "\t\t\tclassLook = false,\n",
       "\t\t\tclassLook = true,\n",
       "classlook: the switch on by default",
       expect="classlook: off by default", script=S)

mutate("Core.lua", "\tns.Looks.RepairClassLook(p)\n",
       "",
       "classlook: the login never follows the class",
       expect="classlook: on, each character wears", script=S)

mutate(LOOKS, "\tlocal class = ns.plain((select(2, UnitClass(\"player\"))))\n",
       "\tlocal class = ns.plain((select(1, UnitClass(\"player\"))))\n",
       "classlook: the class read as its display name",
       expect="classlook: every client", script=S)

mutate(LOOKS, "\treturn mine[1], \"first\"\n",
       "\treturn mine[#mine], \"first\"\n",
       "classlook: a mage's last look worn first",
       expect="classlook: a mage keeps", script=S)

mutate(LOOKS, "\tif type(picked) == \"string\" and Looks.FOR_CLASS[picked] == class",
       "\tif false and type(picked) == \"string\" and Looks.FOR_CLASS[picked] == class",
       "classlook: a class's pick never read",
       expect="classlook: a mage keeps", script=S)

mutate(LOOKS, "\tif #mine == 1 then return mine[1], \"only\" end\n",
       "",
       "classlook: one look said to be the first of several",
       expect="classlook: the picker says", script=S)

mutate(LOOKS, " or Looks.FOR_CLASS[key] ~= class or not Looks.list[key] then\n",
       " or not Looks.list[key] then\n",
       "classlook: another class's look kept as a pick",
       expect="classlook: a damaged profile", script=S)

mutate(LOOKS, "\t\tif own then p.style = own end\n",
       "",
       "classlook: off keeps the class's look",
       expect="classlook: another look clicked", script=S)

mutate(LOOKS, "\t\t\tp.classStyles[class] = p.style\n",
       "",
       "classlook: on swaps a mage's look for the first",
       expect="classlook: turning it on keeps", script=S)

mutate(LOOKS, "\t\tp.classStyles[class] = key\n",
       "",
       "classlook: a click on a class look not remembered",
       expect="classlook: a mage keeps", script=S)

mutate(LOOKS, "\t\tif not Looks.ClassPick(p, class) then p.style = key end\n",
       "\t\tp.style = key\n",
       "classlook: another look worn over the class's",
       expect="classlook: another look clicked", script=S)

mutate(LOOKS, "\t\tif not Looks.ClassPick(p, class) then p.style = key end\n",
       "",
       "classlook: a class with no look never wears a click",
       expect="classlook: a class with no look", script=S)

# --- the Look page ----------------------------------------------------------

mutate(LOOK, "\t\t\t\t\tns.Looks.Pick(P(), value)\n",
       "\t\t\t\t\tP().style = value\n",
       "classlook: the card's click sets the style whatever the switch",
       expect="classlook: another look clicked", script=S)

mutate(LOOK, "\t\t\t\t\tns.Looks.SetClassLook(P(), value == true)\n",
       "\t\t\t\t\tP().classLook = value == true\n",
       "classlook: the switch changes no look",
       expect="classlook: on, each character wears", script=S)

mutate(LOOK, "\t\t\t\torder = 20.5,\n",
       "\t\t\t\torder = 21.1,\n",
       "classlook: the switch after the dropdown",
       expect="the Look tab reads in setup order", script=S)

mutate(ADV, "\t\t\"prompt.classLook\", \"prompt.classStyles\",\n",
       "",
       "classlook: Look's reset leaves the switch",
       expect="classlook: the Look page's reset", script=S)

mutate(ADV, "\t\t\tns.db.profile.prompt.profileStyle = nil\n",
       "",
       "classlook: the reset gives the old own look back",
       expect="classlook: the Look page's reset", script=S)

# --- a settings string ------------------------------------------------------

mutate("Commands.lua", "\t\t\t\t\t\telseif name == \"prompt.classStyles\" then\n",
       "\t\t\t\t\t\telseif name == \"prompt.classStyles.\" then\n",
       "classlook: the picks do not travel",
       expect="classlook: a settings string", script=S)

mutate("Commands.lua", "\t\tfields[#fields + 1] = { name = \"prompt.profileStyle\", kind = \"string\",\n\t\t\tpath = { \"prompt\" }, key = \"profileStyle\" }\n",
       "",
       "classlook: the profile's own look does not travel",
       expect="classlook: a settings string", script=S)

mutate("Commands.lua", "\t\t\tif field.name == \"prompt.style\" and holder and holder.classLook == true and type(holder.profileStyle) == \"string\" then value = holder.profileStyle end\n",
       "",
       "classlook: the string carries the class's look as the style",
       expect="classlook: a settings string", script=S)

# --- the picker's line ------------------------------------------------------

mutate(T, "\tif p and p.classLook == true then\n",
       "\tif false then\n",
       "classlook: the hint still says a click keeps it",
       expect="classlook: the picker says", script=S)

mutate(T, "L[\"In use: %s, the one you picked of the looks made for your class.\"]",
       "L[\"In use: %s, the first of the looks made for your class.\"]",
       "classlook: a pick said to be the first",
       expect="classlook: the picker says", script=S)

mutate(T, "\tif row.whyShown then\n",
       "\tif false then\n",
       "classlook: the line not laid out",
       expect="classlook: the picker says", script=S)

mutate(T, "and type(own) == \"string\" and own ~= key and",
       "and type(own) == \"string\" and",
       "classlook: the own look named when it is the one worn",
       expect="classlook: the picker says", script=S)

mutate(T, "\tif not p or why == \"off\" or not key then\n",
       "\tif not p or not key then\n",
       "classlook: the line shows with the switch off",
       expect="classlook: the picker says", script=S)

# --- its place in the window ------------------------------------------------

mutate(LAYOUT, "\t\t\t\t\t\"appearance.classLook\",\n",
       "",
       "classlook: the switch not placed",
       expect="classlook: the switch is over the cards", script=S)

mutate(LAYOUT, "\t\t\t[\"appearance.classLook\"] = true,\n",
       "",
       "classlook: the simple view leaves it out",
       expect="classlook: the switch is over the cards", script=S)

mutate(LAYOUT, "\t\t[\"appearance.classLook\"] = L[\"class character alt alts each per own\"],\n",
       "",
       "classlook: no search words",
       expect="classlook: the switch is over the cards", script=S)
