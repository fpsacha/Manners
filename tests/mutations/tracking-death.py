# Mutations for tracking after a death (GitHub issue 55): Core.lua's
# ReadOwnFamily reads a tracking the minimap list shows on as off after a
# death, until the list changes while you are alive; Burning Crusade's
# tracking outlasts a death. Each is caught by tests/scenarios/tracking-death.lua.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tif ns.GoneWithDeath(\"own:\" .. family.key, family.throughDeath) then return false end\n\t\t\tfor _, spell in ipairs(family.spells) do",
       "\t\t\tfor _, spell in ipairs(family.spells) do",
       "tracking-death: the stale list is believed after a death",
       expect="tracking-death: Find Minerals is reminded after a death though the list still says on", script=S)

mutate("Core.lua",
       "\t\t\tif family.tracking then ns.NoteCastSinceDeath(\"own:\" .. family.key) end\n",
       "",
       "tracking-death: a list change after the death is never believed",
       expect="tracking-death: the list changing once you are back up is believed", script=S)

mutate("Core.lua",
       "\tif plain(UnitIsDeadOrGhost(\"player\")) ~= true then\n\t\tfor _, family in ipairs(ns.GetOwnFamilies(playerClass) or {}) do",
       "\tif true then\n\t\tfor _, family in ipairs(ns.GetOwnFamilies(playerClass) or {}) do",
       "tracking-death: a list change while dead is believed",
       expect="tracking-death: a change of the list while dead is not believed", script=S)

mutate("Buffs.lua",
       "tracking = true, toggle = true, throughDeath = true, spells = spells }",
       "tracking = true, toggle = true, spells = spells }",
       "tracking-death: Burning Crusade's tracking taken as gone with a death",
       expect="tracking-death: Burning Crusade reads the list as it is after a death", script=S)
