local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

do
	local scenario = "services-module: courtesy target is off and absent from core"
	Mock.reset()
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	if ns.Courtesy then fail(scenario, "services crossed into the core") end
	if ns.defaults.profile.sources.courtesyTarget ~= false then fail(scenario, "target water is on by default") end
end

do
	local scenario = "services-module: its page owns independent service and policy switches"
	Mock.reset()
	Mock.class = "MAGE"
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local water = H.findOption(ns.optionsTable, "courtesyWater")
	local food = H.findOption(ns.optionsTable, "courtesyFood")
	local scope = H.findOption(ns.optionsTable, "courtesyWaterScope")
	local combat = H.findOption(ns.optionsTable, "courtesyWaterCombat")
	local refresh = H.findOption(ns.optionsTable, "courtesyRefresh")
	if not (water and food and scope and combat and refresh) then
		fail(scenario, "a mage's independent service controls are missing")
	end
	if water.order == refresh.order then
		fail(scenario, "separate service controls share a sort order")
	end
	if water.hidden() or food.hidden() or not H.findOption(ns.optionsTable, "courtesyLevitate").hidden() then
		fail(scenario, "the Services page is not class-gated")
	end
	water.set(nil, true)
	if not ns.Courtesy.ServiceOn("water") or ns.Courtesy.ServiceOn("food") then
		fail(scenario, "water and food do not keep independent values")
	end
	scope.set(nil, "whisper", false)
	if ns.Courtesy.Scope("water", "whisper") then fail(scenario, "the per-service whisper scope did not save") end
	combat.set(nil, "ignore")
	if ns.Courtesy.ServiceSetting("water", "combat", "hold") ~= "ignore" then
		fail(scenario, "the per-service combat behaviour did not save")
	end
	ns.OptionsPage.RESET.services.after()
	if next(ns.db.profile.services or {}) then fail(scenario, "the Services reset kept module-only policy values") end
	if ns.Courtesy.ServiceOn("water") then fail(scenario, "the Services reset left water enabled") end
end

do
	local scenario = "services-module: target refreshments and Fire Shield attach"
	Mock.reset()
	Mock.class = "WARLOCK"
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	if not ns.Courtesy then fail(scenario, "courtesy service did not attach") end
	local target = H.findOption(ns.optionsTable, "courtesyTarget")
	if not target or ns.defaults.profile.sources.courtesyTarget ~= false then fail(scenario, "target refreshments are missing or on") end
	if not (ns.WindowLayout.pages and ns.WindowLayout.pages.services) then fail(scenario, "Services has no options page") end
	local inModules = false
	for _, page in ipairs(ns.WindowLayout.groups[5] or {}) do
		if page == "services" then inModules = true end
	end
	if not inModules then fail(scenario, "Services is outside the Optional modules group") end
	if ns.Courtesy.frame then fail(scenario, "an off Services module created its request-event frame") end
	local fire = H.findOption(ns.optionsTable, "courtesyFireShield")
	if ns.FindBuff("WARLOCK", "fireshield") then fail(scenario, "Fire Shield does queue work while off") end
	local available = ({ camelot = true, vanilla = true, tbc = true })[Mock.flavour] == true
	if not available then
		if fire then fail(scenario, "Fire Shield has a Services control on an unsupported client") end
		return
	end
	if not fire then fail(scenario, "Fire Shield has no Services control") end
	fire.set(nil, true)
	local buff = ns.FindBuff("WARLOCK", "fireshield")
	if not buff or not buff.pet or not buff.forTank or not buff.optIn then fail(scenario, "Fire Shield does not attach when enabled") end
	if not ns.petCastEvents then fail(scenario, "enabled Fire Shield has no pet event frame") end
	fire.set(nil, false)
	if ns.FindBuff("WARLOCK", "fireshield") then fail(scenario, "Fire Shield stays in the queue after it is switched off") end
end

do
	local scenario = "services-module: saved Fire Shield attaches after the profile is ready"
	Mock.reset()
	Mock.class = "WARLOCK"
	local first = load(scenario)
	if not first then return end
	drive(scenario, first)
	if not first.Courtesy.SetFireShield(true) then fail(scenario, "Fire Shield could not be saved") end
	local second = load(scenario)
	if not second then return end
	drive(scenario, second)
	local buff = second.FindBuff("WARLOCK", "fireshield")
	if not buff or not second.petCastEvents then
		fail(scenario, "saved Fire Shield did not attach after the profile loaded")
	end
end
