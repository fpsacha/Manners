# Blessing of Freedom on a slowed or rooted friendly target (#71).
S = "runscenarios.py"
OFFER = "combat-freedom: a paladin is offered Blessing of Freedom, off by default"
SENSE = "combat-freedom: a slowed or rooted friendly target lights it, nothing else does"

mutate("Modules/Combat/MomentsData.lua",
       "\tset.PALADIN = set.PALADIN or {}\n\ttable.insert(set.PALADIN, 1, Freedom(cooldown))\n",
       "",
       "combat-freedom: no paladin row",
       expect=OFFER, script=S)
mutate("Modules/Combat/MomentsSense.lua",
       "\t\tif id and list[id] then return \"yes\" end\n",
       "",
       "combat-freedom: a slowing debuff is never seen",
       expect=SENSE, script=S)
mutate("Modules/Combat/MomentsSense.lua",
       "\t\tif Secret(rec) or Secret(rec.spellId) then return \"blind\", \"your target's debuffs\" end\n",
       "",
       "combat-freedom: a withheld debuff counts as none",
       expect=SENSE, script=S)
mutate("Modules/Combat/ImpairData.lua",
       "ns.IMPAIRING = build and build() or {}",
       "ns.IMPAIRING = {}",
       "combat-freedom: the list of slowing spells is empty",
       expect=OFFER, script=S)