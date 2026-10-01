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
       "\t\t\tif InDungeon() then return preferred",
       "\t\t\tif false then return preferred",
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

mutate("Prompt/Refresh.lua",
       "\tif not ns.CanCastAnything() and not S.testMode then\n",
       "\tif not ns.caps.anyKnown and not S.testMode then\n",
       "own: no prompt for a hunter",
       expect="the hunter's prompt is not up on his aspect", script=S)

# --- the options (Options.lua) ---

mutate("Options/Who.lua",
       "\t\t\t\t\t\tif known == family then return false end\n",
       "\t\t\t\t\t\tdo return false end\n",
       "own: every class's families shown",
       expect="is shown to a mage", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t\tif ns.OwnSpellKnown(spell) then\n\t\t\t\t\t\t\tvalues[spell.key]",
       "\t\t\t\t\t\tif true then\n\t\t\t\t\t\t\tvalues[spell.key]",
       "own: spells not learned offered",
       expect="Mage Armor is a choice for a mage who has not learned it", script=S)

mutate("Options/Who.lua",
       "\tif why == \"last\" then return L[\"Automatic (%s, the one you had up last)\"]:format(name) end\n",
       "",
       "own: Automatic does not say it is the last one",
       expect="Automatic reads", script=S)

mutate("Options/Who.lua",
       "\tif why == \"world\" then return L[\"Automatic (%s, outside dungeons and raids)\"]:format(name) end\n",
       "",
       "own: Automatic does not say outside dungeons",
       expect="Automatic reads", script=S)

mutate("Options/Who.lua",
       "\t\t\tif #family.spells > 1 or family.tank then\n",
       "\t\t\tif true then\n",
       "own: a spell alone as a dropdown",
       expect="a priest's Inner Fire is not a checkbox", script=S)

mutate("Options/Who.lua",
       "\t\t\tif #family.spells > 1 or family.tank then\n",
       "\t\t\tif #family.spells > 1 then\n",
       "own: Righteous Fury as a checkbox",
       expect="Righteous Fury's choices read", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tdisabled = function() return not S().self end,\n\t\t\t}\n",
       "\t\t\t\tdisabled = function() return false end,\n\t\t\t}\n",
       "own: live with Myself off",
       expect="the armor dropdown stays live with Myself off", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tif not HasClassBuffs() then return true end\n\t\t\t\tif type(was) == \"function\" then",
       "\t\t\t\tif type(was) == \"function\" then",
       "own: a hunter shown everybody else's settings",
       expect="is shown to a hunter", script=S)

mutate("Options/Who.lua",
       "(ForOthersOnly).\n\t\thidden = function() return not HasPrompt() end,\n",
       "(ForOthersOnly).\n\t\thidden = function() return not HasClassBuffs() end,\n",
       "own: Who to buff hidden from a hunter",
       expect="Who to buff is hidden from a hunter", script=S)

mutate("Options/Start.lua",
       "\tlocal function noPrompt() return not HasPrompt() end\n",
       "\tlocal function noPrompt() return not HasClassBuffs() end\n",
       "own: Start here hides a hunter's prompt",
       expect="Start here hides a hunter's prompt steps", script=S)

mutate("Options/Start.lua",
       "\t\t\t\t\tif not HasClassBuffs() then return grey(Quick.OwnOnlySummary()) end\n",
       "",
       "own: Start here tells a hunter about other people",
       expect="Start here tells a hunter", script=S)

mutate("Options/Launcher.lua",
       "\tlocal ownOnly = ns.OwnBuffsOnly()\n",
       "\tlocal ownOnly = false\n",
       "own: the launcher tells a hunter there is nothing",
       expect="the launcher tells a hunter", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.inCities = value\n",
       "",
       "own: Also in cities and inns not written",
       expect="with Also in cities and inns ticked, in a city you were offered", script=S)

mutate("Options/Diagnostics.lua",
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

# --- review round: the findings on the class's own buffs ---

# A shaman's Water Shield outside the shield family: wearing it reads as no
# shield up, and Lightning Shield is put over it.
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"watershield\", ranks = { 408510 }, talent = true },\n",
       "",
       "own: Water Shield not a shield",
       expect="wearing Water Shield, you were offered", script=S)

# Unending Breath offered to the warlock himself, ahead of his armor.
mutate("Buffs.lua",
       "\t\t\t-- of your Demon Skin or Armor.\n\t\t\tneverSelf = true,\n",
       "\t\t\t-- of your Demon Skin or Armor.\n",
       "own: Unending Breath on yourself",
       expect="rather than Demon Skin", script=S)

mutate("Core.lua",
       " and not buff.notSelf and not buff.neverSelf\n",
       " and not buff.notSelf\n",
       "own: neverSelf ignored",
       expect="rather than Demon Skin", script=S)

# /manners debug telling a warlock nothing he casts goes on himself.
mutate("Commands.lua",
       "\t\telseif #ns.KnownOwnFamilies() == 0 then\n",
       "\t\telse\n",
       "own: debug says nothing goes on a warlock",
       expect="/manners debug does not say Demon Skin is the one", script=S)

# The macro's key without the name it casts by: learning Ice Armor at the
# trainer leaves "/cast Frost Armor" armed under the same entry.
mutate("Prompt/Macro.lua",
       "\t\tns.EntrySpellName(entry),\n",
       "",
       "own: the macro keeps the old rank's name",
       expect="a mage who has learned Ice Armor arms", script=S)

# Burning Crusade handed the vanilla families.
mutate("Buffs.lua",
       "\ttbc = TBC_SET,\n",
       "\ttbc = VANILLA_SET,\n",
       "own: Burning Crusade given the vanilla families",
       expect="was given the vanilla families", script=S)

# /manners debug naming the armor as the one to cast while the prompt is on
# your Intellect.
mutate("Commands.lua",
       "\t\tif first then\n\t\t\tout[#out + 1] = L[\"your own %s comes first",
       "\t\tif false then\n\t\t\tout[#out + 1] = L[\"your own %s comes first",
       "own: debug quiet about your group buff first",
       expect="does not say your Intellect comes before the armor", script=S)

mutate("Queue.lua",
       "\treturn (SelfBuff(db, mine, full, now))\n",
       "\treturn nil\n",
       "own: your group buff first never found",
       expect="does not say your Intellect comes before the armor", script=S)

# The launcher, the login line and the greeting saying nothing is offered
# while the prompt is up on your own buff.
mutate("Options/Launcher.lua",
       "\telseif ownOnly or (ns.OwnBuffsLive() and not ns.ResolveBuff(true)) then\n",
       "\telseif ownOnly then\n",
       "own: the launcher says nothing to a warlock with Demon Skin",
       expect="the launcher tells a warlock with only Demon Skin", script=S)

mutate("Options/Launcher.lua",
       "\t\tif ownOnly then return true, L[\"Watching your own buffs.\"], 0.4, 0.9, 0.4 end\n",
       "\t\tif true then return true, L[\"Watching your own buffs.\"], 0.4, 0.9, 0.4 end\n",
       "own: the launcher does not say others get nothing",
       expect="the launcher tells a warlock with only Demon Skin", script=S)

mutate("Core.lua",
       "\treturn db ~= nil and db.sources.self == true and ns.OwnFamiliesOn() > 0\n",
       "\treturn false\n",
       "own: your own buffs never live",
       expect="the launcher tells a warlock with only Demon Skin", script=S)

mutate("Core.lua",
       "\t\telseif ownLive then\n",
       "\t\telseif false then\n",
       "own: the login line says nothing to a warlock with Demon Skin",
       expect="the login line tells a warlock with only Demon Skin", script=S)

mutate("Commands.lua",
       "\tif othersOff and not ownLive then\n",
       "\tif othersOff then\n",
       "own: the greeting says nothing will be offered",
       expect="the greeting tells a mage with her Intellect switched off", script=S)

mutate("Commands.lua",
       "\telseif othersOff then\n",
       "\telseif false then\n",
       "own: the greeting does not say the prompt is yours",
       expect="the greeting tells a mage with her Intellect switched off", script=S)

# "The one you had up last" written only when the queue reads you.
mutate("Favours.lua",
       "\t\t-- many times a second (Core.lua, RememberOwnBuffs).\n\t\tns.ownAurasChanged = true\n",
       "\t\t-- many times a second (Core.lua, RememberOwnBuffs).\n",
       "own: your auras changing not noticed",
       expect="Concentration Aura put up in a fight was not remembered", script=S)

mutate("Core.lua",
       "\tif ns.ownAurasChanged then ns.Guard(\"remember own buffs\", ns.RememberOwnBuffs) end\n",
       "",
       "own: the tick never remembers",
       expect="Concentration Aura put up in a fight was not remembered", script=S)

mutate("Core.lua",
       "\t\tfor _, family in ipairs(ns.KnownOwnFamilies()) do ns.ReadOwnFamily(family) end\n",
       "",
       "own: the memory read reads nothing",
       expect="Concentration Aura put up in a fight was not remembered", script=S)

# In a fight UNIT_AURA on you only marks the walk of your aura list due, and
# the tick makes it (Favours.lua, FlushOwnScan): one walk a tick, not one an
# event. Each end of that, broken.
mutate("Favours.lua",
       "\t\tif InCombatLockdown() then\n\t\t\t-- A walk is forty slots",
       "\t\tif false then\n\t\t\t-- A walk is forty slots",
       "own: every aura event in a fight walks",
       expect="the aura events in a fight walked your buffs themselves", script=S)

mutate("Core.lua",
       "\t-- UNIT_AURA): one a tick however many came, and a favour filed first.\n"
       "\tns.FlushOwnScan()\n",
       "\t-- UNIT_AURA): one a tick however many came, and a favour filed first.\n",
       "own: the tick never walks what a fight left due",
       expect="four aura events and a tick read", script=S)

mutate("Core.lua",
       "\t-- is filed before the repaint below offers anybody.\n\tns.FlushOwnScan()\n",
       "\t-- is filed before the repaint below offers anybody.\n",
       "own: the fight's last favour filed after the repaint",
       expect="the repaint after the fight ran before the favour", script=S)

# What the walk made as the fight ends finds landed in the fight: never
# thanked, and as quiet as a dungeon fight.
mutate("Favours.lua",
       "\t\t-- A favour from the fight, found by the walk made as it ended.\n"
       "\t\tif walkAfterFight then return L[\"in a fight\"] end\n",
       "",
       "own: the fight's last favour thanked after it",
       expect="the favour from the fight was thanked with an emote after it", script=S)

mutate("Favours.lua",
       "\t\tif walkAfterFight then return true end\n",
       "",
       "own: the fight's last favour said after a dungeon fight",
       expect="the favour from a dungeon fight was said in chat after it", script=S)

mutate("Favours.lua",
       "\twalkAfterFight = not InCombatLockdown()\n",
       "",
       "own: the walk as a fight ends not the fight's",
       expect="the favour from the fight was thanked with an emote after it", script=S)

mutate("Favours.lua",
       "\t\t-- (ns.FlushOwnScan) is answered by it too.\n\t\tns.ownScanDue = false\n",
       "\t\t-- (ns.FlushOwnScan) is answered by it too.\n",
       "own: a walk made leaves the next one due",
       expect="a tick with no aura event since walked your buffs again", script=S)

mutate("Favours.lua",
       "\t\tif asked then scan.walks = scan.walks + 1 end\n",
       "",
       "own: debug counts no walks",
       expect="/manners debug counts", script=S)

# Only the walks a change to your auras asked for are counted, so /manners
# debug never sets more walks than changes beside them.
mutate("Favours.lua",
       "\t\tif asked then scan.walks = scan.walks + 1 end\n",
       "\t\tscan.walks = scan.walks + 1\n",
       "own: debug counts a login's walks",
       expect="a walk no change to your auras asked for was counted", script=S)

mutate("Favours.lua",
       "\t\t\tns.Guard(\"ScanOwnBuffs\", ns.ScanOwnBuffs, true)\n",
       "\t\t\tns.Guard(\"ScanOwnBuffs\", ns.ScanOwnBuffs)\n",
       "own: debug misses the walks out of a fight",
       expect="an aura event out of a fight was not counted as a walk", script=S)

mutate("Favours.lua",
       "\t\tasked = asked or ns.ownScanDue\n",
       "",
       "own: debug misses the walks a fight left due",
       expect="/manners debug counts", script=S)

# A buff that runs out and is recast under its own number between two ticks
# of a fight is never read gone, since the events there only mark a walk due:
# it reaches IsNew looking like a refresh, and the end the last reading saw
# having gone by is what tells the two apart.
mutate("Favours.lua",
       "\t\tif before and expires and expires > before and before > 0 and before <= GetTime()\n"
       "\t\t\tand lastPresent[instanceId] == key then\n"
       "\t\t\treturn true\n"
       "\t\tend\n",
       "",
       "own: a recast between two fight ticks taken for a refresh",
       expect="ran out and was recast under its own number before the tick", script=S)

mutate("Favours.lua",
       "\t\tfor instanceId, expires in pairs(presentUntil) do lastUntil[instanceId] = expires end\n",
       "",
       "own: the ends each reading saw not kept",
       expect="ran out and was recast under its own number before the tick", script=S)

# And each half of the test: any later end, the end the baseline filed
# rather than the one last read (which a refresh moves), the same end, and an
# end of 0, which is none.
mutate("Favours.lua",
       "expires > before and before > 0 and before <= GetTime()\n",
       "expires > before and before > 0\n",
       "own: every later end taken for a recast",
       expect="a refresh read before the end it replaced was taken for a favour", script=S)

mutate("Favours.lua",
       "\t\tlocal before = lastUntil[instanceId]\n",
       "\t\tlocal before = knownUntil[instanceId]\n",
       "own: a recast measured against the filed end",
       expect="a refresh read again after the end it replaced had gone by", script=S)

mutate("Favours.lua",
       "\t\tif before and expires and expires > before and",
       "\t\tif before and expires and expires >= before and",
       "own: the same end taken for a recast",
       expect="the same aura read after its end with the end it had", script=S)

mutate("Favours.lua",
       "expires > before and before > 0 and before <= GetTime()\n",
       "expires > before and before <= GetTime()\n",
       "own: no end taken for one that ran out",
       expect="a buff with no end, read later with one, was taken for a recast", script=S)

# The dungeon pick taken before it is learned.
mutate("Core.lua",
       "\t\tif preferred and Known(preferred) then\n",
       "\t\tif preferred then\n",
       "own: Automatic promises Mage Armor before it is learned",
       expect="outside Automatic reads", script=S)

# Myself's heading and Also in cities and inns shown to a warrior, and the
# latter live with Myself off.
mutate("Options/Who.lua",
       "order = 15, hidden = NothingForSelf },",
       "order = 15 },",
       "own: Myself's heading shown to a warrior",
       expect="myselfHeader is shown to a warrior", script=S)

mutate("Options/Who.lua",
       "\t\t\t\torder = 15.9,\n\t\t\t\twidth = \"full\",\n\t\t\t\thidden = NothingForSelf,\n",
       "\t\t\t\torder = 15.9,\n\t\t\t\twidth = \"full\",\n",
       "own: Also in cities and inns shown to a warrior",
       expect="ownCities is shown to a warrior", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tdisabled = function() return not S().self end,\n"
       "\t\t\t\tget = function() return ns.db.profile.ownBuffs.inCities == true end,\n",
       "\t\t\t\tget = function() return ns.db.profile.ownBuffs.inCities == true end,\n",
       "own: Also in cities and inns live with Myself off",
       expect="Also in cities and inns stays live with Myself off", script=S)

# When to offer for a hunter: there, and only what is about him.
mutate("Options/When.lua",
       "topped up from here.\n\t\thidden = function() return not HasPrompt() end,\n",
       "topped up from here.\n\t\thidden = function() return not HasClassBuffs() end,\n",
       "own: When to offer hidden from a hunter",
       expect="When to offer is hidden from a hunter", script=S)

mutate("Options/When.lua",
       "\t\treturn (class ~= nil and ns.MANA_CLASSES[class] ~= true) or not HasClassBuffs()\n",
       "\t\treturn (class ~= nil and ns.MANA_CLASSES[class] ~= true)\n",
       "own: a hunter shown the mana floor",
       expect="manaFloor is shown to a hunter", script=S)

mutate("Options/When.lua",
       "order = 20,\n\t\t\t\thidden = function() return not S().owed or not HasClassBuffs() end,\n",
       "order = 20,\n\t\t\t\thidden = function() return not S().owed end,\n",
       "own: a hunter shown the favours",
       expect="favoursHeader is shown to a hunter", script=S)

mutate("Options/When.lua",
       "F().whenBuffed ~= \"always\" or not HasClassBuffs() end,\n",
       "F().whenBuffed ~= \"always\" end,\n",
       "own: a hunter shown the always note",
       expect="alwaysNote is shown to a hunter", script=S)

mutate("Options/When.lua",
       "\t\t\t\t\tif not HasClassBuffs() then\n\t\t\t\t\t\treturn L[\"Your own buffs are offered when none",
       "\t\t\t\t\tif false then\n\t\t\t\t\t\treturn L[\"Your own buffs are offered when none",
       "own: a hunter told about favours on When to offer",
       expect="If they already have it tells a hunter", script=S)
