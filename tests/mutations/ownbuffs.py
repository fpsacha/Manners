# Mutations for your class's own buffs under "Myself": the families in
# Buffs.lua (VANILLA_OWN), reading them on you and picking one (Core.lua,
# OwnVerdict and OwnAutoPick), the entry and when you are held back
# (Queue.lua, SelfEntry and MyselfHeldBack), the press (Clicks.lua), the
# prompt for a class with nothing for anybody else (Prompt.lua), the options
# (Options.lua), /manners debug (Commands.lua) and the saved settings. Each is
# caught by the scenario in tests/scenarios/ownbuffs.lua that names it.

S = "runscenarios.py"

# --- the offer (Queue.lua) ---

mutate("Queue.lua",
       "\tif not buff then buff, has, remaining = OwnPick(db, full, now) end\n",
       "",
       "own: never offered",
       expect="a mage with no armor up was not offered one", script=S)

# Your own group buff after the class's own rather than before.
mutate("Queue.lua",
       "\tif #mine > 0 then buff, has, remaining = SelfBuff(db, mine, full, now) end\n"
       "\tif not buff then buff, has, remaining = OwnPick(db, full, now) end\n",
       "\tbuff, has, remaining = OwnPick(db, full, now)\n"
       "\tif not buff and #mine > 0 then buff, has, remaining = SelfBuff(db, mine, full, now) end\n",
       "own: your group buff not first",
       expect="before your Intellect", script=S)

# A class with nothing for anybody else offered nothing at all.
mutate("Queue.lua",
       "\t\tlocal own = SelfEntry(db, candidates, now, neverVerdict)\n",
       "\t\tlocal own = nil\n",
       "own: nothing for a hunter",
       expect="rather than Aspect of the Hawk", script=S)

mutate("Queue.lua",
       "\tif InCombatLockdown() or safecall(_G.UnitAffectingCombat, \"player\") == true then return \"fight\" end\n",
       "",
       "own: offered in a fight",
       expect="in a fight you were offered", script=S)

# The pull's own repaint, before the lockdown, not asked about.
mutate("Queue.lua",
       "\tif InCombatLockdown() or safecall(_G.UnitAffectingCombat, \"player\") == true then return \"fight\" end\n",
       "\tif InCombatLockdown() then return \"fight\" end\n",
       "own: offered on the pull",
       expect="on the pull you were offered", script=S)

mutate("Queue.lua",
       "\tif not (db.ownBuffs and db.ownBuffs.inCities == true) and Resting() == true then return \"resting\" end\n",
       "",
       "own: offered in a city",
       expect="in a city you were offered", script=S)

mutate("Queue.lua",
       "\tif not (db.ownBuffs and db.ownBuffs.inCities == true) and Resting() == true then return \"resting\" end\n",
       "\tif Resting() == true then return \"resting\" end\n",
       "own: Also in cities and inns ignored",
       expect="with Also in cities and inns ticked, in a city you were offered", script=S)

# The skip said nowhere: the queue still honours it through the per-buff
# block, and /manners debug is what goes wrong.
mutate("Queue.lua",
       "\tif ns.IsBlocked(full, nil, now or GetTime()) then return \"skipped\" end\n",
       "",
       "own: a skip unsaid",
       expect="/manners debug does not say you are skipped", script=S)

# --- which spell, and whether it is up (Core.lua) ---

mutate("Core.lua",
       "\treturn caps.anyKnown == true or caps.anyOwnKnown == true\n",
       "\treturn caps.anyKnown == true\n",
       "own: a hunter has nothing to cast",
       expect="a hunter with his aspects learned has nothing to cast", script=S)

mutate("Core.lua",
       "\t\tchar.ownLast[family.key] = spell.key\n",
       "",
       "own: the one up never remembered",
       expect="wearing Mage Armor was not remembered", script=S)

mutate("Core.lua",
       "\t\tif last then return last, \"last\" end\n",
       "",
       "own: the one up last ignored",
       expect="rather than the one you had up last", script=S)

mutate("Core.lua",
       "\t\tif spell.neverAuto then return end\n",
       "",
       "own: the Cheetah remembered",
       expect="Aspect of the Cheetah was remembered", script=S)

mutate("Core.lua",
       "\t\t\tif InDungeon() then\n",
       "\t\t\tif false then\n",
       "own: a dungeon not noticed",
       expect="in a dungeon Automatic offered", script=S)

mutate("Core.lua",
       "(kind == \"party\" or kind == \"raid\")",
       "kind ~= nil",
       "own: a battleground taken for a dungeon",
       expect="in a battleground Automatic offered", script=S)

mutate("Core.lua",
       "\t\t\tif not Tanking() then return nil, \"notank\" end\n",
       "",
       "own: Righteous Fury for everybody",
       expect="a paladin alone was offered", script=S)

mutate("Core.lua",
       "\t\treturn safecall(_G.UnitGroupRolesAssigned, \"player\") == \"TANK\"\n",
       "\t\treturn true\n",
       "own: the role not read",
       expect="a damage-dealing paladin was offered", script=S)

mutate("Core.lua",
       "\t\tif (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) <= 0 then return false end\n"
       "\t\treturn safecall(_G.UnitGroupRolesAssigned",
       "\t\treturn safecall(_G.UnitGroupRolesAssigned",
       "own: a tank alone",
       expect="a paladin alone was offered", script=S)

mutate("Core.lua",
       "\t\tif spell and spell.family == family and Known(spell) then return spell.key, spell end\n",
       "",
       "own: the pick ignored",
       expect="picked Mage Armor, and was offered", script=S)

mutate("Core.lua",
       "\t\tif pick == \"off\" then return \"off\" end\n",
       "",
       "own: Don't remind me ignored",
       expect="Don't remind me still offered", script=S)

# Your auras not read by id.
mutate("Core.lua",
       "\t\t\t\t\telseif type(aura) == \"table\" and FromYou(aura) ~= false then\n"
       "\t\t\t\t\t\tRemember(family, spell)\n",
       "\t\t\t\t\telseif false then\n"
       "\t\t\t\t\t\tRemember(family, spell)\n",
       "own: armor up not read",
       expect="wearing Frost Armor under another name, you were offered", script=S)

mutate("Core.lua",
       "\t\tlocal named, left, nameRefused = ByName(family, now)\n",
       "\t\tlocal named, left, nameRefused = nil, nil, false\n",
       "own: not read by name",
       expect="wearing an Ice Armor rank the table lacks", script=S)

mutate("Core.lua",
       "\t\t\t\t\t\tif plain(aura.name) == name and FromYou(aura) ~= false then\n",
       "\t\t\t\t\t\tif false then\n",
       "own: the aura list not walked by name",
       expect="found by walking your auras", script=S)

mutate("Core.lua",
       "\t\treturn same == true\n\tend\n",
       "\t\treturn true\n\tend\n",
       "own: somebody else's taken for yours",
       expect="an armor cast by somebody else counted as yours", script=S)

mutate("Core.lua",
       "\t\tif type(source) ~= \"string\" then return nil end\n\t\tlocal same = safecall(UnitIsUnit",
       "\t\tif type(source) ~= \"string\" then return false end\n\t\tlocal same = safecall(UnitIsUnit",
       "own: an aura naming nobody nags",
       expect="wearing an armor naming nobody", script=S)

mutate("Core.lua",
       "\t\tif formSpell and formSpell.family == family then\n",
       "\t\tif false then\n",
       "own: the shapeshift bar not read",
       expect="with Retribution Aura's form active", script=S)

mutate("Core.lua",
       "\t\tif refused or nameRefused then return nil end\n",
       "",
       "own: offered on a withheld reading",
       expect="the client will not read your armor", script=S)

mutate("Core.lua",
       "\t\t\tif family.toggle or ctx.whenBuffed ~= \"refresh\" or not left\n",
       "\t\t\tif ctx.whenBuffed ~= \"refresh\" or not left\n",
       "own: an aura topped up",
       expect="a toggle was offered as a top-up", script=S)

mutate("Core.lua",
       "\t\t\tif family.toggle or ctx.whenBuffed ~= \"refresh\" or not left\n",
       "\t\t\tif family.toggle or not left\n",
       "own: a top-up with top-ups off",
       expect="a minute of Mage Armor was topped up with top-ups off", script=S)

mutate("Core.lua",
       "\t\t\tif family.toggle or ctx.whenBuffed ~= \"refresh\" or not left\n",
       "\t\t\tif true\n",
       "own: never a top-up",
       expect="a minute of Mage Armor with top-ups on offered", script=S)

mutate("Core.lua",
       "\t\tif ns.IsBlocked(ctx.name, spell.key, ctx.now) then return nil, up, left, \"tried\", spell end\n",
       "",
       "own: offered again right after a press",
       expect="offered the armor again right after the press", script=S)

mutate("Core.lua",
       "\t\tif not Usable(spell) then return nil, up, left, \"unusable\", spell end\n",
       "",
       "own: offered what cannot be cast",
       expect="though the game says it cannot be cast", script=S)

# Known by an id whose name the client cannot give: a macro with no spell.
mutate("Core.lua",
       "\t\t\t\tinfo.known = info.known == true and info.name ~= nil\n",
       "",
       "own: an unknown id known",
       expect="an armor whose ids the client does not have was offered", script=S)

# The first rank's name, as before, whatever you know.
mutate("Core.lua",
       "\t\tlocal named = info.topRank or buff.ranks[1]\n",
       "\t\tlocal named = buff.ranks[1]\n",
       "own: cast by the first rank's name",
       expect="a mage knowing only Frost Armor rank 1 arms", script=S)

# "Myself" on with only your class's own buffs is nothing to the lines that
# say who is offered.
mutate("Core.lua",
       "\t\tand (#ns.SelfBuffs() > 0 or ns.OwnFamiliesOn() > 0)\n",
       "\t\tand (#ns.SelfBuffs() > 0)\n",
       "own: your own buffs not counted as offered",
       expect="the launcher tells a hunter", script=S)

# --- the saved settings (Core.lua) ---

mutate("Core.lua",
       "\tfor _, family in ipairs(families) do defaults.profile.ownBuffs.pick[family.key] = \"auto\" end\n",
       "",
       "own: no defaults for the picks",
       expect="a family missing its pick was not given Automatic", script=S)

mutate("Core.lua",
       "\tboolean(own, \"inCities\", false)\n",
       "",
       "own: nonsense cities kept",
       expect="a nonsense Also in cities and inns was kept", script=S)

mutate("Core.lua",
       "\t\telseif value ~= \"auto\" and value ~= \"off\" and not (spell and spell.family == family) then\n",
       "\t\telseif false then\n",
       "own: nonsense pick kept",
       expect="nonsense picks were kept", script=S)

mutate("Core.lua",
       "\t\telseif value ~= \"auto\" and value ~= \"off\" and not (spell and spell.family == family) then\n",
       "\t\telseif value ~= \"auto\" and value ~= \"off\" and not spell then\n",
       "own: another family's spell kept",
       expect="nonsense picks were kept", script=S)

mutate("Core.lua",
       "\t\tif not family then\n\t\t\town.pick[key] = nil\n",
       "\t\tif false then\n\t\t\town.pick[key] = nil\n",
       "own: a family nobody has kept",
       expect="a family nobody has was kept", script=S)

mutate("Core.lua",
       "\t\tif own.pick[key] == nil then own.pick[key] = \"auto\" end\n",
       "",
       "own: a missing pick left missing",
       expect="a family missing its pick", script=S)

# --- the data (Buffs.lua) ---

# Ice Armor's first rank off the line: known, but not by this spell.
mutate("Buffs.lua",
       "ranks = { 10220, 10219, 7320, 7302, 7301, 7300, 168 }",
       "ranks = { 10220, 10219, 7320, 7301, 7300, 168 }",
       "own: Ice Armor off the Frost Armor line",
       expect="a mage who has learned Ice Armor arms", script=S)

mutate("Buffs.lua",
       "{ key = \"aspectcheetah\", ranks = { 5118 }, neverAuto = true },",
       "{ key = \"aspectcheetah\", ranks = { 5118 } },",
       "own: the Cheetah Automatic's",
       expect="Aspect of the Cheetah was remembered", script=S)

mutate("Buffs.lua",
       "\t\t\t},\n\t\t\ttoggle = true,\n\t\t},\n\t\t{\n\t\t\tkey = \"righteousfury\",",
       "\t\t\t},\n\t\t},\n\t\t{\n\t\t\tkey = \"righteousfury\",",
       "own: a paladin's aura timed",
       expect="a toggle was offered as a top-up", script=S)

mutate("Buffs.lua",
       "\t\t\ttank = true,\n",
       "",
       "own: Righteous Fury not the tank's",
       expect="a paladin alone was offered", script=S)

mutate("Buffs.lua",
       "\t\t\tdungeon = \"magearmor\",\n",
       "",
       "own: no Mage Armor for dungeons",
       expect="in a dungeon Automatic offered", script=S)

# --- the press (Clicks.lua) ---

mutate("Clicks.lua",
       "\t\treturn ns.OWN_BY_ID[spellId] == own or SpellNameFor(spellId) == ns.BuffName(own)\n",
       "\t\treturn true\n",
       "own: any spell taken for the armor",
       expect="a Frostbolt going out was taken for the armor", script=S)

# Nothing said on yourself, for your class's own too.
mutate("Speech.lua",
       "\t\tif entry.reason == \"self\" then return nil end\n",
       "",
       "own: a line said on your armor",
       expect="the macro reads", script=S)

# --- a prompt for a hunter (Prompt.lua) ---

mutate("Prompt.lua",
       "\tif not ns.CanCastAnything() and not testMode then\n",
       "\tif not ns.caps.anyKnown and not testMode then\n",
       "own: no prompt for a hunter",
       expect="the hunter's prompt is not up on his aspect", script=S)

# --- the options (Options.lua) ---

mutate("Options.lua",
       "\t\t\t\t\t\tif known == family then return false end\n",
       "\t\t\t\t\t\tdo return false end\n",
       "own: every class's families shown",
       expect="is shown to a mage", script=S)

mutate("Options.lua",
       "\t\t\t\t\t\tif ns.OwnSpellKnown(spell) then\n\t\t\t\t\t\t\tvalues[spell.key]",
       "\t\t\t\t\t\tif true then\n\t\t\t\t\t\t\tvalues[spell.key]",
       "own: spells not learned offered",
       expect="Mage Armor is a choice for a mage who has not learned it", script=S)

mutate("Options.lua",
       "\tif why == \"last\" then return L[\"Automatic (%s, the one you had up last)\"]:format(name) end\n",
       "",
       "own: Automatic does not say it is the last one",
       expect="Automatic reads", script=S)

mutate("Options.lua",
       "\tif why == \"world\" then return L[\"Automatic (%s, outside dungeons and raids)\"]:format(name) end\n",
       "",
       "own: Automatic does not say outside dungeons",
       expect="Automatic reads", script=S)

mutate("Options.lua",
       "\t\t\tif #family.spells > 1 or family.tank then\n",
       "\t\t\tif true then\n",
       "own: a spell alone as a dropdown",
       expect="a priest's Inner Fire is not a checkbox", script=S)

mutate("Options.lua",
       "\t\t\tif #family.spells > 1 or family.tank then\n",
       "\t\t\tif #family.spells > 1 then\n",
       "own: Righteous Fury as a checkbox",
       expect="Righteous Fury's choices read", script=S)

mutate("Options.lua",
       "\t\t\t\tdisabled = function() return not S().self end,\n\t\t\t}\n",
       "\t\t\t\tdisabled = function() return false end,\n\t\t\t}\n",
       "own: live with Myself off",
       expect="the armor dropdown stays live with Myself off", script=S)

mutate("Options.lua",
       "\t\t\t\tif not HasClassBuffs() then return true end\n\t\t\t\tif type(was) == \"function\" then",
       "\t\t\t\tif type(was) == \"function\" then",
       "own: a hunter shown everybody else's settings",
       expect="is shown to a hunter", script=S)

mutate("Options.lua",
       "\t\thidden = function() return not HasPrompt() end,\n",
       "\t\thidden = function() return not HasClassBuffs() end,\n",
       "own: Who to buff hidden from a hunter",
       expect="Who to buff is hidden from a hunter", script=S)

mutate("Options.lua",
       "\tlocal function noPrompt() return not HasPrompt() end\n",
       "\tlocal function noPrompt() return not HasClassBuffs() end\n",
       "own: Start here hides a hunter's prompt",
       expect="Start here hides a hunter's prompt steps", script=S)

mutate("Options.lua",
       "\t\t\t\t\tif not HasClassBuffs() then return grey(Quick.OwnOnlySummary()) end\n",
       "",
       "own: Start here tells a hunter about other people",
       expect="Start here tells a hunter", script=S)

mutate("Options.lua",
       "\tlocal ownOnly = ns.OwnBuffsOnly()\n",
       "\tlocal ownOnly = false\n",
       "own: the launcher tells a hunter there is nothing",
       expect="the launcher tells a hunter", script=S)

mutate("Options.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.inCities = value\n",
       "",
       "own: Also in cities and inns not written",
       expect="with Also in cities and inns ticked, in a city you were offered", script=S)

mutate("Options.lua",
       "\t\t\t\thidden = function() return #ns.MyselfLines(GetTime()) == 0 end,\n",
       "\t\t\t\thidden = function() return true end,\n",
       "own: Diagnostics silent",
       expect="Diagnostics does not say which armor is due", script=S)

# --- /manners debug (Commands.lua) ---

mutate("Commands.lua",
       "\t\t-- Where you are held back, and each of your class's own buffs.\n"
       "\t\tfor _, line in ipairs(ns.MyselfLines(now)) do self:Print(\"  \" .. line) end\n",
       "",
       "own: debug silent",
       expect="/manners debug does not say the armor is up", script=S)

mutate("Commands.lua",
       "\t\tif held == \"resting\" then\n",
       "\t\tif false then\n",
       "own: debug quiet about a city",
       expect="/manners debug does not say why nothing is offered in a city", script=S)

mutate("Commands.lua",
       "\t\telseif held then\n\t\t\tout[#out + 1] = HELD[held]\n",
       "\t\telseif false then\n\t\t\tout[#out + 1] = HELD[held]\n",
       "own: debug quiet about a fight",
       expect="/manners debug does not say a fight holds you back", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"off\" then\n",
       "\t\telseif false then\n",
       "own: debug quiet about Don't remind me",
       expect="/manners debug does not say the armor is switched off", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"unusable\" then\n",
       "\t\telseif false then\n",
       "own: debug quiet about what cannot be cast",
       expect="/manners debug does not say the armor cannot be cast", script=S)
