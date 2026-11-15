# The Profiles page as a profile manager (AutoProfile.lua, its paste box in
# Options/Profiles.lua, its rows in Options/Window/Layout.lua and the name
# box's typing in Options/Window/WidgetsEntry.lua). Each fault is caught by
# the scenario in tests/scenarios/profiles-qol.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
A = "AutoProfile.lua"
PR = "Options/Profiles.lua"

OVER = "profiles-qol: the overview names every profile, who is on it and where switching sends this character"
PICK = "profiles-qol: the buttons act on the picked profile, and say why they are greyed"
RENAME = "profiles-qol: renaming a profile not in use carries its characters, rules and settings"
DELETE = "profiles-qol: Delete sends its characters to Default, and Undo puts the profile, its characters and rules back"
RESET = "profiles-qol: Undo puts back what Reset and Copy into replaced"
STEP = "profiles-qol: Undo is one step: the next action takes its place"
PASTE = "profiles-qol: a paste is undone from the same line, into the profile in use or a new one"
START = "profiles-qol: New characters start on is kept for the account, and Default when the profile is gone"
FIRST = "profiles-qol: a character's first login starts on the profile chosen for new characters"
OWN = "profiles-qol: Give this character its own settings is there only while others share the profile"
FIGHT = "profiles-qol: nothing on the page changes a profile in a fight"
WINDOW = "profiles-qol: the window draws the manager, Undo only once there is something to undo"
MAKE = "autoprofile: the page makes a profile from the defaults or from the settings in use"

# --- the overview ---

mutate(A, "\t\tif name == current then head = L[\"%s (in use)\"]:format(head) end\n",
       "",
       "profiles-qol: the profile in use is not marked",
       expect=OVER, script=S)

mutate(A, "\tif current then table.insert(names, 1, current) end\n",
       "\tif current then names[#names + 1] = current end\n",
       "profiles-qol: the profile in use is listed last",
       expect=OVER, script=S)

mutate(A, "\tif count == 1 and mine then return L[\"this character\"] end\n",
       "",
       "profiles-qol: this character alone is counted as one of many",
       expect=OVER, script=S)

mutate(A, "\tif count == 0 then return L[\"nobody\"] end\n",
       "",
       "profiles-qol: a profile nobody is on is not said to be",
       expect=OVER, script=S)

mutate(A, "\tif name and server == realm then return name end\n",
       "",
       "profiles-qol: characters of this realm named with it",
       expect=OVER, script=S)

mutate(A, "\tif #others > NAMED + 1 then\n",
       "\tif false then\n",
       "profiles-qol: every character named however many",
       expect=OVER, script=S)

mutate(A, "\t\tif st.rules[at] == name then out[#out + 1] = PLACES[at] end\n",
       "",
       "profiles-qol: the overview never says where switching sends this character",
       expect=OVER, script=S)

mutate(A, "\tif not (st and st.enabled) then return nil end\n\tlocal out = {}\n",
       "\tlocal out = {}\n",
       "profiles-qol: the overview speaks of switching while it is off",
       expect=OVER, script=S)

# --- pick, then act ---

mutate(A, "local function PickedInUse() return Busy() or P.Picked() == P.Current() end\n",
       "local function PickedInUse() return Busy() end\n",
       "profiles-qol: Delete is offered for the profile in use",
       expect=PICK, script=S)

mutate(A, "\tif P.Picked() == P.Current() then\n\t\tparts[1] =",
       "\tif false then\n\t\tparts[1] =",
       "profiles-qol: no reason given for the greyed buttons",
       expect=PICK, script=S)

mutate(A, "local function NameOff() return Busy() or P.NameFault(page.draft) ~= nil end\n",
       "local function NameOff() return Busy() end\n",
       "profiles-qol: Duplicate and Rename lit for a name that will not do",
       expect=PICK, script=S)

mutate(A, "\tif Trim(page.draft) ~= \"\" then parts[#parts + 1] = P.NameFault(page.draft) end\n",
       "",
       "profiles-qol: a wrong name is not said to be wrong",
       expect=PICK, script=S)

mutate(A, "\t\tfunction() P.Duplicate(page.draft, P.Picked()) end, NameOff)\n",
       "\t\tfunction() P.Duplicate(page.draft) end, NameOff)\n",
       "profiles-qol: Duplicate copies the profile in use, not the one picked",
       expect=PICK, script=S)

mutate(A, "\tpage.pick, page.draft = name, \"\"\n",
       "\tpage.draft = \"\"\n",
       "profiles-qol: the copy is not picked after Duplicate",
       expect=PICK, script=S)

mutate(A, "\t\tfunction() P.Use(P.Picked()) end, PickedInUse)\n",
       "\t\tfunction() P.Use(P.Current()) end, PickedInUse)\n",
       "profiles-qol: Use switches to nothing new",
       expect=PICK, script=S)

mutate(A, "\treturn L[\"Delete %s? These characters go to the Default profile: %s.\"]:format(tostring(name), table.concat(who, \", \"))\n",
       "\treturn L[\"Delete %s? No character is on it.\"]:format(tostring(name))\n",
       "profiles-qol: Delete does not say who goes to Default",
       expect=PICK, script=S)

mutate(A, "\t\t\tif current then out[current] = L[\"%s (in use)\"]:format(current) end\n",
       "",
       "profiles-qol: the dropdown does not mark the profile in use",
       expect=PICK, script=S)

# A switch from anywhere leaves the dropdown on a profile picked before it.
mutate(A, "\t\tif event == \"OnProfileChanged\" then page.pick = nil end\n",
       "",
       "profiles-qol: the dropdown stays on an old pick after a switch",
       expect=MAKE, script=S)

# --- rename ---

mutate(A, "\t\tsv.profiles[name] = sv.profiles[old]\n",
       "\t\tsv.profiles[name] = Copy(sv.profiles[old])\n",
       "profiles-qol: a rename makes a copy rather than moving the profile",
       expect=RENAME, script=S)

mutate(A, "\t\tsv.profiles[old] = nil\n",
       "",
       "profiles-qol: a rename of a profile not in use keeps the old one",
       expect=RENAME, script=S)

mutate(A, "\tif global and global.newCharacters == old then global.newCharacters = name end\n",
       "",
       "profiles-qol: New characters start on is left on the old name",
       expect=RENAME, script=S)

mutate(A, "\tif page.pick == old then page.pick = name end\n",
       "",
       "profiles-qol: the renamed profile is no longer picked",
       expect=RENAME, script=S)

mutate(A, "\t\tfunction() P.Rename(page.draft, P.Picked()) end, NameOff)\n",
       "\t\tfunction() P.Rename(page.draft) end, NameOff)\n",
       "profiles-qol: Rename renames the profile in use, not the one picked",
       expect=RENAME, script=S)

mutate(A, "\t\treturn RenameProfile(db, r.new, r.old)\n",
       "\t\treturn true\n",
       "profiles-qol: Undo of a rename does nothing",
       expect=RENAME, script=S)

# --- delete ---

mutate(A, "\t\tfor _, key in ipairs(record.keys) do sv.profileKeys[key] = DEFAULT end\n",
       "",
       "profiles-qol: a delete leaves its characters on no profile",
       expect=DELETE, script=S)

mutate(A, "\trecord.keys = P.Users(name)\n",
       "",
       "profiles-qol: a delete forgets who was on the profile",
       expect=DELETE, script=S)

mutate(A, "\t\tsv.profiles[r.name] = r.saved or {}\n",
       "\t\tsv.profiles[r.name] = {}\n",
       "profiles-qol: Undo of a delete brings back an empty profile",
       expect=DELETE, script=S)

mutate(A, "then sv.profileKeys[key] = r.name end\n",
       "then end\n",
       "profiles-qol: Undo of a delete leaves its characters on Default",
       expect=DELETE, script=S)

mutate(A, "then rule.st.rules[rule.at] = r.name end\n",
       "then end\n",
       "profiles-qol: Undo of a delete leaves the rules on Do not switch",
       expect=DELETE, script=S)

mutate(A, "\tpage.last = { text = ok and L[\"Put back as it was.\"] or why }\n",
       "\tpage.last = r\n",
       "profiles-qol: Undo is offered again after it was taken",
       expect=DELETE, script=S)

# --- reset and copy ---

mutate(A, "\tlocal before = Copy(db.profile)\n\tdb:ResetProfile()\n",
       "\tlocal before = db.profile\n\tdb:ResetProfile()\n",
       "profiles-qol: Reset keeps no copy of what it replaced",
       expect=RESET, script=S)

mutate(A, "\tlocal before = Copy(db.profile)\n\tdb:CopyProfile(name, true)\n",
       "\tlocal before = db.profile\n\tdb:CopyProfile(name, true)\n",
       "profiles-qol: Copy into keeps no copy of what it replaced",
       expect=RESET, script=S)

mutate(A, "\tsv.profiles[TEMP] = snapshot\n",
       "",
       "profiles-qol: Undo of a reset copies from nothing",
       expect=RESET, script=S)

mutate(A, "\tif r.kind == \"reset\" or r.kind == \"copy\" or r.kind == \"pasteNew\" then return P.Current() == r.profile end\n",
       "",
       "profiles-qol: Undo of a reset offered on another profile",
       expect=RESET, script=S)

# --- one step ---

mutate(A, "\t\t\tpage.last = nil\n",
       "",
       "profiles-qol: Undo outlives a switch to another profile",
       expect=STEP, script=S)

mutate(A, "\tif record and ns.ForgetImportUndo then ns.ForgetImportUndo() end\n",
       "",
       "profiles-qol: a paste can still be undone after the next action",
       expect=PASTE, script=S)

# --- paste ---

mutate(A, "\t\t\tif ok and name and not page.pasting then\n",
       "\t\t\tif false then\n",
       "profiles-qol: a paste is not the page's last action",
       expect=PASTE, script=S)

mutate(A, "\tdb:SetProfile(name)\n\tif P.Current() ~= name then return false end\n",
       "",
       "profiles-qol: a paste into a new profile goes over the one in use",
       expect=PASTE, script=S)

mutate(A, "\tif at then message = Trim(message:sub(1, at - 1) .. message:sub(at + #offer)) end\n",
       "",
       "profiles-qol: a paste into a new profile offers the import's undo",
       expect=PASTE, script=S)

mutate(A, "\t\tif type(db.DeleteProfile) == \"function\" then db:DeleteProfile(r.profile, true) end\n",
       "",
       "profiles-qol: Undo of a paste into a new profile keeps the profile",
       expect=PASTE, script=S)

mutate(A, "\tpage.pasteName = \"\"\n",
       "",
       "profiles-qol: the new profile's name stays in the box",
       expect=PASTE, script=S)

mutate(A, "\t\thidden = function() return page.into ~= \"new\" end,\n",
       "\t\thidden = function() return true end,\n",
       "profiles-qol: no box for the new profile's name",
       expect=PASTE, script=S)

mutate(PR, "\t\t\t\tif into then\n\t\t\t\t\tlocal _, said = ns.Profiles.PasteAsNew(into, value)\n",
       "\t\t\t\tif false then\n\t\t\t\t\tlocal _, said = ns.Profiles.PasteAsNew(into, value)\n",
       "profiles-qol: the paste box never pastes into a new profile",
       expect=PASTE, script=S)

mutate(PR, "\t\t\t\t\treturn ns.Profiles.NameFault(into) or true\n",
       "\t\t\t\t\treturn true\n",
       "profiles-qol: a paste into a new profile takes any name",
       expect=PASTE, script=S)

# --- new characters ---

mutate(A, "\t\t\tglobal.newCharacters = (type(value) == \"string\" and value ~= DEFAULT and P.Names()[value]) and value or nil\n",
       "\t\t\tglobal.newCharacters = value\n",
       "profiles-qol: Default saved as a name for new characters",
       expect=START, script=S)

mutate(A, "\tif type(name) == \"string\" and P.Names()[name] then return name end\n\treturn DEFAULT\n",
       "\tif type(name) == \"string\" then return name end\n\treturn DEFAULT\n",
       "profiles-qol: new characters start on a profile that is gone",
       expect=START, script=S)

mutate(A, "\t\tif name == start and start ~= DEFAULT then text = text .. \" \" .. L[\"New characters start here.\"] end\n",
       "",
       "profiles-qol: the overview never says where new characters start",
       expect=START, script=S)

mutate(A, "\tif not key or (type(sv.profileKeys) == \"table\" and sv.profileKeys[key] ~= nil) then return end\n",
       "\tif not key then return end\n",
       "profiles-qol: a character that logged in before is moved",
       expect=FIRST, script=S)

mutate(A, "\tif not (type(sv.profiles) == \"table\" and type(sv.profiles[name]) == \"table\") then return end\n",
       "",
       "profiles-qol: a new character starts on a profile that is gone",
       expect=FIRST, script=S)

mutate(A, "\tsv.profileKeys[key] = name\n",
       "",
       "profiles-qol: a new character starts on Default whatever was chosen",
       expect=FIRST, script=S)

mutate(A, "\t\tns.Guard(\"new character's profile\", StartOn)\n",
       "",
       "profiles-qol: nothing runs at a first login",
       expect=FIRST, script=S)

# --- a profile of this character's own ---

mutate("Options/Start.lua", "\treturn Setup.SharedWith() > 0 and db:GetCurrentProfile() ~= db.keys.char\n",
       "\treturn db:GetCurrentProfile() ~= db.keys.char\n",
       "profiles-qol: its own settings offered to a character alone on its profile",
       expect=OWN, script=S)

# --- a fight ---

mutate(PR, "\t\t\t\t\tif InCombatLockdown() then return L[\"A profile cannot be made in a fight.\"] end\n",
       "",
       "profiles-qol: a paste into a new profile let through in a fight",
       expect=FIGHT, script=S)

mutate(A, "\t\tfunction() P.Undo() end, Busy)\n",
       "\t\tfunction() P.Undo() end, nil)\n",
       "profiles-qol: Undo not greyed in a fight",
       expect=FIGHT, script=S)

# --- the window ---

mutate("Options/Window/Layout.lua", "\t\t\t\t\t{ \"profiles.current\", standIn = true },\n",
       "\t\t\t\t\t\"profiles.current\",\n",
       "profiles-qol: the overview's section goes with Undo",
       expect=WINDOW, script=S)

mutate(A, "\targs.undo.hidden = function() return not P.CanUndo() end\n",
       "",
       "profiles-qol: Undo drawn with nothing to undo",
       expect=WINDOW, script=S)

mutate("Options/Window/WidgetsEntry.lua", "local LIVE = { [\"profiles.name\"] = true, [\"profiles.pasteName\"] = true }\n",
       "local LIVE = {}\n",
       "profiles-qol: a name typed without Enter never reaches the buttons",
       expect=WINDOW, script=S)
