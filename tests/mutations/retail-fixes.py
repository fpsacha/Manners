# Mutations for round 30's retail fixes: UNIT_AURA's secret payload on retail
# 12.1 (Favours.lua). Each undoes a fix and is caught by the scenario in
# tests/scenarios/retail-fixes.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ UNIT_AURA's secret unit token
# The report: the handler compared the token (`if unit == "player"`) and handed
# it to UnitGUID with nothing asking whether it was secret, a Lua error on
# every UNIT_AURA in a retail fight.
mutate("Favours.lua",
       "\tunit = plain(unit)\n\tif unit == nil then\n"
       "\t\tif not ns.ownScanDue then ns.auraScan.events = ns.auraScan.events + 1 end\n"
       "\t\tns.ownScanDue = true\n\t\tns.ownAurasChanged = true\n\t\treturn\n\tend\n\n",
       "",
       "retail-fix: UNIT_AURA's secret token compared",
       expect="retail-fix: UNIT_AURA with a secret unit token (a fight on retail 12.1) is never compared",
       script=S)

# The secret token kept away from every comparison, and from the walk too: a
# favour landing in a retail fight waits for an aura change after it.
mutate("Favours.lua",
       "\tif unit == nil then\n"
       "\t\tif not ns.ownScanDue then ns.auraScan.events = ns.auraScan.events + 1 end\n"
       "\t\tns.ownScanDue = true\n",
       "\tif unit == nil then\n"
       "\t\tif not ns.ownScanDue then ns.auraScan.events = ns.auraScan.events + 1 end\n",
       "retail-fix: a secret UNIT_AURA marks no walk due",
       expect="retail-fix: a favour landing in a retail fight, every UNIT_AURA secret, is walked on the tick and filed",
       script=S)
