# Mutations for curing yourself (sources.curesSelf: Cures.lua, ns.CureSelf;
# Queue.lua's SelfEntry hook and StopOfferingSelf; Clicks.lua's SettleSelf;
# Core.lua's default; the layout). Each is caught by the scenario in
# tests/scenarios/cures-self.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tcuresSelf = false,\n",
       "\t\t\tcuresSelf = true,\n",
       "cures-self: on by default",
       expect="cures-self: off by default", script=S)

mutate("Cures.lua",
       "\tif not (scan.live and scan.self) or not full then return nil end\n",
       "\tif not scan.live or not full then return nil end\n",
       "cures-self: the party's switch alone cures you",
       expect="cures-self: it asks no walk of anybody else", script=S)

mutate("Cures.lua",
       "\tentry.reason = \"self\"\n",
       "",
       "cures-self: the entry is a group member's",
       expect="cures-self: a poison on you is offered the cure", script=S)

mutate("Cures.lua",
       "\tscan.self = sources.curesSelf == true\n",
       "\tscan.self = true\n",
       "cures-self: the scan has it on with the switch off",
       expect="cures-self: it asks no walk of anybody else", script=S)

mutate("Cures.lua",
       "\tif not (sources.cures == true or sources.curesStrangers == true or sources.curesSelf == true) then return nil end\n",
       "\tif not (sources.cures == true or sources.curesStrangers == true) then return nil end\n",
       "cures-self: the scan ignores the switch",
       expect="cures-self: a poison on you is offered the cure", script=S)

mutate("Cures.lua",
       "\tif not (sources and (sources.cures == true or sources.curesStrangers == true or sources.curesSelf == true)) then return false end\n",
       "\tif not (sources and (sources.cures == true or sources.curesStrangers == true)) then return false end\n",
       "cures-self: a class with nothing else has no prompt for it",
       expect="cures-self: a class with a cure and no buff for others", script=S)

mutate("Queue.lua",
       "\t\tif cure and not ListedAs(full, verdict) then return cure end\n",
       "\t\tif cure then return cure end\n",
       "cures-self: the never-offer list does not hold it",
       expect="cures-self: your own name on the never-offer list", script=S)

mutate("Queue.lua",
       "\tif ns.CureSelf then\n\t\tlocal full = ns.UnitFullName(\"player\")\n",
       "\tif false then\n\t\tlocal full = ns.UnitFullName(\"player\")\n",
       "cures-self: SelfEntry never asks",
       expect="cures-self: a poison on you is offered the cure", script=S)

mutate("Queue.lua",
       "\tif entry and entry.cure then\n\t\tdb.sources.curesSelf = false\n",
       "\tif false then\n\t\tdb.sources.curesSelf = false\n",
       "cures-self: Shift-right-click on the cure switches Myself off",
       expect="cures-self: Shift-right-click switches Cure myself too off", script=S)

mutate("Clicks.lua",
       "\tif ns.RotatesBuffs() and pending.buffKey and not pending.cure then ns.lastGave[pending.name] = pending.buffKey end\n",
       "\tif ns.RotatesBuffs() and pending.buffKey then ns.lastGave[pending.name] = pending.buffKey end\n",
       "cures-self: the cure's key goes into the rotation pointer",
       expect="cures-self: a press settles as a cure on yourself", script=S)

mutate("Clicks.lua",
       "\t\tcure = pending.cure }\n\tRememberSettled(record)",
       "\t\t}\n\tRememberSettled(record)",
       "cures-self: a cure on yourself earns no milestone",
       expect="cures-self: a press settles as a cure on yourself", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.curesSelf\",\n",
       "",
       "cures-self: the switch has no place on the window",
       expect="cures-self: the switch is on Who to buff", script=S)

mutate("Options/Who.lua",
       "local function CuresOff() return not (S().cures or S().curesStrangers or S().curesSelf) end",
       "local function CuresOff() return not (S().cures or S().curesStrangers) end",
       "cures-self: the seconds are greyed with only this switch on",
       expect="cures-self: the switch is on Who to buff", script=S)

mutate("Options/Advanced.lua",
       "\"sources.curesStrangers\", \"sources.curesSelf\", \"filters.cureSeconds\",",
       "\"sources.curesStrangers\", \"filters.cureSeconds\",",
       "cures-self: the page's reset leaves it",
       expect="cures-self: the switch is on Who to buff", script=S)
