local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

do
	local scenario = "mybuffs-module: core owns no self extras without the module"
	Mock.reset()
	Mock.class = "HUNTER"
	Mock.sv.profile = { sources = { self = true }, ownBuffs = { itemsLast = true } }
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	if ns.OwnSpells or ns.Supplies or ns.Pet then fail(scenario, "an extra crossed the module boundary") end
	local selfBuffs = ns.SelfBuffs
	ns.SelfBuffs = function() return { { key = "aspect" } } end
	if ns.OffersSelf() or ns.OwnBuffsLive() then fail(scenario, "core still offers its own buffs") end
	ns.SelfBuffs = selfBuffs
end

do
	local scenario = "mybuffs-module: saved own-buff settings survive attachment"
	Mock.reset()
	Mock.class = "HUNTER"
	Mock.sv.profile = { ownBuffs = { apart = true, petChoice = "favourite", itemsLast = true } }
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local own = ns.db.profile.ownBuffs
	if not ns.OwnSpells or not ns.Supplies or not ns.Pet then fail(scenario, "module features are missing") end
	if own.apart ~= true or own.petChoice ~= "favourite" or own.itemsLast ~= true then
		fail(scenario, "a saved own-buff setting moved")
	end
end

do
	local scenario = "mybuffs-module: split own families use a scoped accessor"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARLOCK"
	Mock.knownSpells = { [425464] = true, [19028] = true }
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local control = H.findOption(ns.optionsTable, "own_demonicsacrifice")
	if not control or type(control.desc) ~= "function" then
		fail(scenario, "the split family control is missing")
		return
	end
	local ok, line = pcall(control.desc)
	if not ok then fail(scenario, "the split family touched a private lookup: " .. tostring(line)) end
end
