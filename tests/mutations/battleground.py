# Mutations for battlegrounds and arenas as a situation of their own
# (Battle.lua; its hooks in Queue.lua's SelfEntry, OwnPick, SavingMana and
# BuildQueue, Speech.lua's ChannelOpen, Favours.lua's Held, Core.lua's
# OwnVerdict, defaults and ClampSettings, Commands.lua, Options/Who.lua,
# Options/When.lua's section, its layout slot and the page's reset). Each is
# caught by the scenario in tests/scenarios/battleground.lua that it names.

S = "runscenarios.py"
B = "Battle.lua"

# --- where you are, and which state ---

mutate(B,
       "\twhere.battle = (inside == true or inside == 1) and (kind == \"pvp\" or kind == \"arena\")\n",
       "\twhere.battle = (inside == true or inside == 1) and (kind == \"pvp\")\n",
       "battleground: an arena is no battleground",
       expect="in a arena instance with nothing on you the state is", script=S)

mutate(B,
       "\twhere.battle = (inside == true or inside == 1) and (kind == \"pvp\" or kind == \"arena\")\n",
       "\twhere.battle = (inside == true or inside == 1)\n",
       "battleground: a dungeon read as a battleground",
       expect="a party instance reads as a battleground", script=S)

mutate(B,
       "\twhere.battle = (inside == true or inside == 1) and (kind == \"pvp\" or kind == \"arena\")\n",
       "\twhere.battle = (inside == true) and (kind == \"pvp\" or kind == \"arena\")\n",
       "battleground: the game's 1 for inside not read",
       expect="the game's 1 for inside is not read as inside", script=S)

mutate(B,
       "\tlocal inside, kind = safecall(_G.IsInInstance)\n\twhere.at = now\n",
       "\tlocal inside, kind = _G.IsInInstance()\n\twhere.at = now\n",
       "battleground: a client that will not say throws in the scan",
       expect="a client that will not say where you are", script=S)

mutate(B,
       "\tif Preparing(now) then return \"prep\" end\n",
       "",
       "battleground: the Preparation aura is never read",
       expect="under Preparation the state is", script=S)

mutate(B,
       "\tif Fighting() then return \"fight\" end\n",
       "",
       "battleground: a fight is never read",
       expect="in combat the state is", script=S)

mutate(B,
       "\treturn type(affecting) == \"function\" and plain(affecting(\"player\")) == true\n",
       "\treturn false\n",
       "battleground: the combat flag before the lockdown is not read",
       expect="the combat flag up before the lockdown is not read as a fight", script=S)

mutate(B,
       "\tif Preparing(now) then return \"prep\" end\n\tif Fighting() then return \"fight\" end\n",
       "\tif Fighting() then return \"fight\" end\n\tif Preparing(now) then return \"prep\" end\n",
       "battleground: a combat flag holds the team back before the gates open",
       expect="battleground: before the gates open a fight holds nobody back", script=S)

# --- the aura, per client ---

mutate(B,
       "\tcamelot = { 422621 },\n",
       "\tcamelot = { 44521 },\n",
       "battleground: Forever asked about another client's Preparation",
       expect="battleground: the Preparation aura is read by this client's own id (camelot)", script=S)

mutate(B,
       "\tvanilla = { 422621 },\n",
       "\tvanilla = { 44521 },\n",
       "battleground: Classic Era asked about another client's Preparation",
       expect="battleground: the Preparation aura is read by this client's own id (vanilla)", script=S)

mutate(B,
       "\ttbc = { 44521, 32727, 32728 },\n",
       "\ttbc = { 44521 },\n",
       "battleground: Burning Crusade's arena preparation is not read",
       expect="battleground: the Preparation aura is read by this client's own id (tbc)", script=S)

mutate(B,
       "\tmists = { 44521, 32727, 32728 },\n",
       "\tmists = { 422621 },\n",
       "battleground: Mists asked about Classic Era's Preparation",
       expect="battleground: the Preparation aura is read by this client's own id (mists)", script=S)

mutate(B,
       "\tmainline = { 44521, 32727, 32728 },\n",
       "\tmainline = { 32727, 32728 },\n",
       "battleground: retail's battleground preparation is not read",
       expect="battleground: the Preparation aura is read by this client's own id (mainline)", script=S)

# --- your own, after a death ---

mutate(B,
       "\t\tentry.priority = Battle.SELF_FIRST\n",
       "",
       "battleground: your own missing buff stays behind the people raised beside you",
       expect="in a battleground your own missing buff is not first after a death", script=S)

mutate("Queue.lua",
       "\tif battle then ns.Battle.Rank(entry) end\n",
       "",
       "battleground: your own entry is never ranked for a battleground",
       expect="in a battleground your own missing buff is not first after a death", script=S)

mutate(B,
       "Battle.SELF_FIRST = 0.4\n",
       "Battle.SELF_FIRST = 0.6\n",
       "battleground: your own buff behind the death sweep",
       expect="in a battleground your own missing buff is not first after a death", script=S)

mutate("Queue.lua",
       "\tif ns.Battle.State(now) then return ns.Battle.OwnPick(db, full, now) end\n",
       "",
       "battleground: your own buffs in the table's order",
       expect="in a battleground food came ahead of what you fight with", script=S)

mutate(B,
       "\t\t\t\tif spell and (pass == 2 or has == false) then\n",
       "\t\t\t\tif spell then\n",
       "battleground: one running low ahead of one missing",
       expect="one running low came ahead of one missing altogether", script=S)

mutate(B,
       "\t\tif low then return low, lowHas, lowRemaining, lowCharges, lowSeconds, lowLead, lowKind end\n",
       "",
       "battleground: food ahead of a top-up of what you fight with",
       expect="food came ahead of a top-up of what you fight with", script=S)

mutate(B,
       "\t\tentry.priority = Battle.EXTRAS\n",
       "",
       "battleground: food ahead of the team",
       expect="not behind the team", script=S)

mutate(B,
       "\treturn family.bagged == true or family.kind == \"lure\" or ns.OwnItemsHeldToDungeons(family)\n",
       "\treturn family.kind == \"lure\"\n",
       "battleground: food is not one of the long extras",
       expect="food is not one of the long extras", script=S)

mutate("Queue.lua",
       "\tif battle and buff and has == true then\n",
       "\tif false then\n",
       "battleground: your group buff running low ahead of an armor that is gone",
       expect="the top-up of your group buff came ahead of an armor that is gone", script=S)

mutate(B,
       "\t\tif held then return nil end\n",
       "",
       "battleground: one of your own only running low passes your group buff",
       expect="one of your own only running low passed your group buff", script=S)

# --- before the gates open ---

mutate("Queue.lua",
       "\tif ns.Battle.State() == \"prep\" then\n\t\tsweep.saving = nil\n",
       "\tif false then\n\t\tsweep.saving = nil\n",
       "battleground: the mana floor holds under Preparation",
       expect="under Preparation the mana floor still held the team back", script=S)

mutate("Queue.lua",
       "\tif battle == \"prep\" then skipGroups = nil end\n",
       "",
       "battleground: the raid groups switched off wait under Preparation",
       expect="under Preparation a raid group switched off was still left out", script=S)

mutate("Queue.lua",
       "\tif battle == \"prep\" then skipGroups = nil end\n",
       "\tif battle then skipGroups = nil end\n",
       "battleground: the raid groups switched off offered with the gates open",
       expect="with the gates open, a raid group switched off was offered", script=S)

mutate("Queue.lua",
       "\tif battle == \"prep\" then ns.Battle.GroupFirst(queue) end\n",
       "",
       "battleground: the group casts not first under Preparation",
       expect="under Preparation the group cast does not come first", script=S)

mutate("Queue.lua",
       "\tif battle == \"prep\" then ns.Battle.GroupFirst(queue) end\n",
       "\tif battle then ns.Battle.GroupFirst(queue) end\n",
       "battleground: the group casts first with the gates open",
       expect="with the gates open the group cast", script=S)

# --- once they are open ---

mutate("Queue.lua",
       "\tif battle == \"fight\" then\n",
       "\tif false then\n",
       "battleground: the team offered in a fight",
       expect="in a fight in a battleground somebody is still offered", script=S)

mutate("Queue.lua",
       "\tif battle then queue = ns.Battle.Reach(queue, rejected) end\n",
       "",
       "battleground: somebody out of reach offered",
       expect="a team-mate measured out of range was offered in a battleground", script=S)

mutate(B,
       "\t\tlocal far = not entry.foldOnly and (entry.unit == nil or entry.ranged == false)\n",
       "\t\tlocal far = not entry.foldOnly and (entry.ranged == false)\n",
       "battleground: somebody no token names offered",
       expect="somebody no token names was offered in a battleground", script=S)

mutate(B,
       "\t\t\tif entry.name then rejected[entry.name] = true end\n",
       "",
       "battleground: out of reach is no verdict",
       expect="the one out of range is not turned down as a verdict", script=S)

# --- the team's switch and the instance switch ---

mutate("Queue.lua",
       "\tif battle then inTown = not ns.Battle.On(\"team\") end\n",
       "",
       "battleground: the instance switch decides in a battleground",
       expect="the instance switch held the team back with Buff my team there on", script=S)

mutate("Queue.lua",
       "\tif battle then inTown = not ns.Battle.On(\"team\") end\n",
       "\tif battle and not ns.Battle.On(\"team\") then return {}, true end\n",
       "battleground: your target dropped with the team",
       expect="your target was dropped with Buff my team there off", script=S)

mutate("Core.lua",
       "\t\t\tteam = true,\n",
       "\t\t\tteam = false,\n",
       "battleground: the team is not offered by default",
       expect="Buff my team there is not on in a new profile", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tif value == true then ns.db.profile.battle.team = false end\n",
       "",
       "battleground: the instance switch leaves the team's on",
       expect="ticking the instance switch left Buff my team there on", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tif value == true then ns.db.profile.battle.team = false end\n",
       "\t\t\t\t\tns.db.profile.battle.team = not value\n",
       "battleground: unticking the instance switch ticks the team's",
       expect="unticking the instance switch ticked Buff my team there", script=S)

mutate("Core.lua",
       "\tif ns.Battle then ns.Battle.Carry(profile) end\n",
       "",
       "battleground: an old profile is not carried over",
       expect="a profile with the instance switch ticked was not carried over", script=S)

mutate(B,
       "\tif type(battle) ~= \"table\" or battle.carried == true then return end\n",
       "\tif type(battle) ~= \"table\" then return end\n",
       "battleground: carried over at every load",
       expect="the carrying over was made twice, over the player's own tick", script=S)

mutate(B,
       "\tif type(filters) == \"table\" and filters.quietInInstances == true then battle.team = false end\n",
       "\tbattle.team = false\n",
       "battleground: every profile loses the team's switch",
       expect="a profile without the instance switch lost Buff my team there", script=S)

# --- what is said, who is thanked, what comes out of the bags ---

mutate("Speech.lua",
       "\tif ns.Battle.Quiet() then return false end\n",
       "",
       "battleground: a line is said there",
       expect="a line would be said in a pvp instance", script=S)

mutate(B,
       "\treturn Where(GetTime()) and not Battle.On(\"speak\")\n",
       "\treturn Where(GetTime())\n",
       "battleground: Say my line there is never read",
       expect="with Say my line there ticked, no line is said", script=S)

mutate("Core.lua",
       "\t\t\tspeak = false,\n",
       "\t\t\tspeak = true,\n",
       "battleground: a line is said there by default",
       expect="Say my line there is not off in a new profile", script=S)

mutate("Favours.lua",
       "\t\t\tlocal battle = ns.Battle.Thanks(seen)\n",
       "\t\t\tlocal battle = nil\n",
       "battleground: a team-mate is not thanked there",
       expect="battleground: thanks go to your own team (a team-mate is thanked)", script=S)

mutate(B,
       "\tif not (type(seen) == \"table\" and seen.inGroup == true) then\n",
       "\tif false then\n",
       "battleground: somebody outside your team is thanked there",
       expect="battleground: thanks go to your own team (nobody outside your team)", script=S)

mutate(B,
       "\tif not Battle.On(\"thank\") then return L[\"thanks are off in battlegrounds\"] end\n",
       "",
       "battleground: Thank people there is never read",
       expect="battleground: thanks go to your own team (nobody with Thank people there off)", script=S)

mutate(B,
       "\tif not ((inside == true or inside == 1) and (kind == \"pvp\" or kind == \"arena\")) then return nil end\n",
       "\tif not (inside == true or inside == 1) then return nil end\n",
       "battleground: a dungeon's party is thanked",
       expect="battleground: thanks go to your own team (a dungeon holds a party member's back as ever)", script=S)

mutate("Core.lua",
       "\t\t\tthank = true,\n",
       "\t\t\tthank = false,\n",
       "battleground: nobody is thanked there by default",
       expect="Thank people there is not on in a new profile", script=S)

mutate("Core.lua",
       "\t\t\tand not ns.Battle.ItemsThere()\n",
       "",
       "battleground: Consumables there too is never read",
       expect="with Consumables there too ticked, food still waits for a dungeon", script=S)

mutate(B,
       "\treturn Battle.On(\"items\") and Where(GetTime())\n",
       "\treturn Battle.On(\"items\")\n",
       "battleground: the tick lets consumables through everywhere",
       expect="the tick let food through out in the world", script=S)

mutate(B,
       "\treturn Battle.On(\"items\") and Where(GetTime())\n",
       "\treturn Where(GetTime())\n",
       "battleground: consumables come up there unticked",
       expect="food is no longer held in a battleground", script=S)

mutate("Core.lua",
       "\t\t\titems = false,\n",
       "\t\t\titems = true,\n",
       "battleground: consumables come up there by default",
       expect="Consumables there too is not off in a new profile", script=S)

# --- the section, the reset, the explanation, a pasted string ---

mutate("Options/Window/Layout.lua",
       "\t\t\t\t{ key = \"when.battle\", header = \"when.battleHeader\", items = { \"when.battleTeam\", \"when.battleSpeak\", \"when.battleThank\", \"when.battleItems\" } },\n",
       "",
       "battleground: the section is not on the page",
       expect="battleground: When to offer has the section, its switches are kept and its reset puts them back", script=S)

mutate("Options/When.lua",
       "\t\t\t\t\tns.db.profile.battle.team = value == true\n",
       "",
       "battleground: Buff my team there writes nothing",
       expect="battleTeam was not kept", script=S)

mutate("Options/When.lua",
       "\t\t\t\tset = function(_, value) ns.db.profile.battle.thank = value == true end,\n",
       "\t\t\t\tset = function() end,\n",
       "battleground: Thank people there writes nothing",
       expect="battleThank was not kept", script=S)

mutate("Options/When.lua",
       "\t\t\t\tdisabled = function() return ns.db.profile.ownBuffs.itemsInDungeons ~= true end,\n",
       "",
       "battleground: Consumables there too is never greyed",
       expect="Consumables there too is not greyed while consumables are held nowhere", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"battle.team\", \"battle.speak\", \"battle.thank\", \"battle.items\",\n",
       "",
       "battleground: the page's reset leaves the section",
       expect="When to offer's reset leaves battle.", script=S)

mutate("Commands.lua",
       "\t\tfor _, line in ipairs(ns.Battle.Lines(now)) do self:Print(line) end\n",
       "",
       "battleground: /manners debug says nothing of a battleground",
       expect="/manners debug does not say the gates are open", script=S)

mutate(B,
       "\tif db.speech and db.speech.enabled == true and not Battle.On(\"speak\") then\n",
       "\tif not Battle.On(\"speak\") then\n",
       "battleground: the silence is said to somebody who says nothing anyway",
       expect="with nothing to hold back", script=S)

mutate("Options/Diagnostics.lua",
       "\tlines[#lines + 1] = (\"battle: team=%s speak=%s thank=%s items=%s state=%s\"):format(tostring(db.battle.team),\n"
       "\t\ttostring(db.battle.speak), tostring(db.battle.thank), tostring(db.battle.items), tostring(ns.Battle.State()))\n",
       "",
       "battleground: the check-up leaves the section out",
       expect="the check-up does not hold the section's switches and its state", script=S)

mutate("Commands.lua",
       "\t\t[\"battle.speak\"] = true,\n",
       "",
       "battleground: a pasted string switches on speaking there",
       expect="a pasted string switched on Say my line there for a player who speaks", script=S)
