local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

do
	local scenario = "modules migration #64: old active own buffs load My Buffs and restore self learning"
	Mock.reset()
	Mock.class = "DRUID"
	Mock.knownSpells = { [782] = true, [5232] = true }
	Mock.sv.profile = {
		sources = { self = true },
		ownBuffs = { inCities = true, holdMoving = false },
	}
	local realDB, realC = rawget(_G, "MannersDB"), rawget(_G, "C_AddOns")
	rawset(_G, "MannersDB", { profiles = { Default = Mock.sv.profile } })
	local states = { Manners_MyBuffs = 0 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	local ns = load(scenario, true)
	if not ns then
		rawset(_G, "MannersDB", realDB)
		rawset(_G, "C_AddOns", realC)
		return
	end
	drive(scenario, ns)
	if states.Manners_MyBuffs ~= 2 or ns.db.profile.optionalModulesMigrated ~= true then
		fail(scenario, "the old active My Buffs profile was not migrated and marked")
	end
	if MannersAPI:ModuleActive("mybuffs") or not MannersAPI:ModuleReloadPending() then
		fail(scenario, "an unloaded migrated module became active without Reload UI")
	end
	if ns.OffersSelf() then
		fail(scenario, "the disabled module did not explain issue 64's missing self buffs")
	end
	if ns.db.profile.ownBuffs.inCities ~= true
		or ns.db.profile.ownBuffs.holdMoving ~= false then
		fail(scenario, ("migration changed saved own-buff choices: inCities=%s holdMoving=%s")
			:format(tostring(ns.db.profile.ownBuffs.inCities),
				tostring(ns.db.profile.ownBuffs.holdMoving)))
	end
	if not H.loadModule(scenario, "Modules/MyBuffs/Manners_MyBuffs.toc") then
		rawset(_G, "MannersDB", realDB)
		rawset(_G, "C_AddOns", realC)
		return
	end
	local found = false
	for _, buff in ipairs(ns.SelfBuffs()) do if buff.key == "thorns" then found = true end end
	if ns.FindOwnFamily("thorns") and (not found or not ns.OffersSelf()) then
		fail(scenario, "loading migrated My Buffs did not restore the learned Thorns self offer")
	end
	rawset(_G, "MannersDB", realDB)
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules migration #63: old active Services requests load Services"
	Mock.reset()
	Mock.class = "MAGE"
	Mock.sv.profile = {
		sources = { asked = true, courtesyRefresh = true, courtesyTarget = false },
	}
	local realDB, realC = rawget(_G, "MannersDB"), rawget(_G, "C_AddOns")
	rawset(_G, "MannersDB", { profiles = { Default = Mock.sv.profile } })
	local states = { Manners_Services = 0 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	local ns = load(scenario, true)
	if not ns then
		rawset(_G, "MannersDB", realDB)
		rawset(_G, "C_AddOns", realC)
		return
	end
	drive(scenario, ns)
	if states.Manners_Services ~= 2 or ns.db.profile.optionalModulesMigrated ~= true then
		fail(scenario, "old active Services settings did not enable the folder")
	elseif ns.db.profile.sources.asked ~= true or ns.db.profile.sources.courtesyRefresh ~= true then
		fail(scenario, "the Services migration changed its old switches")
	end
	rawset(_G, "MannersDB", realDB)
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules migration: old active Combat switches load Combat"
	Mock.reset()
	Mock.sv.profile = {
		optionalModulesMigrated = true,
		prompt = { breakFree = true, cureFight = false, reactiveWards = false },
		beast = { fightMend = false },
	}
	local realDB, realC = rawget(_G, "MannersDB"), rawget(_G, "C_AddOns")
	rawset(_G, "MannersDB", { profiles = { Default = Mock.sv.profile } })
	local states = { Manners_Combat = 0 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	local ns = load(scenario, true)
	if not ns then
		rawset(_G, "MannersDB", realDB)
		rawset(_G, "C_AddOns", realC)
		return
	end
	drive(scenario, ns)
	if states.Manners_Combat ~= 2 or ns.db.profile.optionalCombatMigrated ~= true then
		fail(scenario, "the old active Combat profile was not migrated and marked")
	end
	if ns.db.profile.prompt.breakFree ~= true then
		fail(scenario, "the saved Combat switch changed during migration")
	end
	rawset(_G, "MannersDB", realDB)
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules migration: any active legacy Combat-only switch loads Combat"
	for _, profile in ipairs({
		{ prompt = { cureFight = true }, beast = { fightMend = false } },
		{ prompt = { cureFight = false, reactiveWards = true }, beast = { fightMend = false } },
		{ prompt = { cureFight = false }, beast = { fightMend = true } },
	}) do
		Mock.reset()
		Mock.sv.profile = profile
		local realDB, realC = rawget(_G, "MannersDB"), rawget(_G, "C_AddOns")
		rawset(_G, "MannersDB", { profiles = { Default = Mock.sv.profile } })
		local states = { Manners_Combat = 0 }
		rawset(_G, "C_AddOns", {
			GetAddOnEnableState = function(folder) return states[folder] or 0 end,
			EnableAddOn = function(folder) states[folder] = 2 end,
			DisableAddOn = function(folder) states[folder] = 0 end,
		})
		local ns = load(scenario, true)
		if ns then drive(scenario, ns) end
		if states.Manners_Combat ~= 2 then fail(scenario, "an active Combat switch stayed disabled") end
		rawset(_G, "MannersDB", realDB)
		rawset(_G, "C_AddOns", realC)
	end
end

do
	local scenario = "modules migration #62: old active consumable choices load My Buffs"
	Mock.reset()
	Mock.class = "ROGUE"
	Mock.sv.profile = {
		sources = { self = true },
		ownBuffs = { pick = { poisonmain = "auto", stonemain = "auto" } },
	}
	local realDB, realC = rawget(_G, "MannersDB"), rawget(_G, "C_AddOns")
	rawset(_G, "MannersDB", { profiles = { Default = Mock.sv.profile } })
	local states = { Manners_MyBuffs = 0 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	local ns = load(scenario, true)
	if not ns then
		rawset(_G, "MannersDB", realDB)
		rawset(_G, "C_AddOns", realC)
		return
	end
	drive(scenario, ns)
	local hasRogueItems = ns.FindOwnFamily("poisonmain") and ns.FindOwnFamily("stonemain")
	if states.Manners_MyBuffs ~= 2 or (hasRogueItems
		and (ns.db.profile.ownBuffs.pick.poisonmain ~= "auto"
			or ns.db.profile.ownBuffs.pick.stonemain ~= "auto")) then
		fail(scenario, "the old poison and weapon-stone choices did not migrate intact")
	end
	rawset(_G, "MannersDB", realDB)
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules migration: new and intentionally off profiles stay disabled"
	Mock.reset()
	Mock.sv.profile = {
		sources = {
			self = true, asked = true, courtesyRefresh = false,
			courtesyPortals = false, courtesyHealthstones = false,
			courtesySummons = false, courtesyTarget = false,
		},
	}
	local realDB, realC = rawget(_G, "MannersDB"), rawget(_G, "C_AddOns")
	rawset(_G, "MannersDB", nil)
	local states = {}
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	local ns = load(scenario, true)
	if not ns then
		rawset(_G, "MannersDB", realDB)
		rawset(_G, "C_AddOns", realC)
		return
	end
	drive(scenario, ns)
	if states.Manners_MyBuffs or states.Manners_Services or states.Manners_Combat then
		fail(scenario, "a new profile enabled an optional folder")
	end
	Mock.sv.profile.optionalModulesMigrated = nil
	Mock.sv.profile.sources.self = false
	rawset(_G, "MannersDB", { profiles = { Default = Mock.sv.profile } })
	MannersAPI:MigrateOptionalModules(true)
	if states.Manners_MyBuffs or states.Manners_Services or states.Manners_Combat then
		fail(scenario, "an intentional off profile was enabled")
	end
	if ns.db.profile.optionalModulesMigrated ~= true then
		fail(scenario, "the skipped migration was not explicitly marked")
	end
	rawset(_G, "MannersDB", realDB)
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules: option builders are registered"
	Mock.reset()
	Mock.class = "HUNTER"
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local api = MannersAPI
	local pet, mine = #api:OptionsExtensions("who"), H.findOption(ns.optionsTable, "beastCall")
	if pet ~= 4 or not mine or not H.findOption(ns.optionsTable, "ownSpellAdd")
		or not H.findOption(ns.optionsTable, "cures")
		or not H.findOption(ns.optionsTable, "courtesyTarget") then
		fail(scenario, "module option builders are missing")
	end
end

do
	local scenario = "modules: Combat-only cure choices read safe with Combat absent"
	Mock.reset()
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	for _, key in ipairs({ "cureFightPlain", "cureFightShift", "cureFightCtrl" }) do
		local control = H.findOption(ns.optionsTable, key)
		if control then
			local ok, value = pcall(control.get)
			if not ok then fail(scenario, key .. " threw without Combat: " .. tostring(value)) end
			if value ~= "none" then fail(scenario, key .. " is not none without Combat: " .. tostring(value)) end
		end
	end
end

do
	local scenario = "modules: Manners menu toggles addon folders"
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local states = { Manners_Combat = 0 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	local control = H.findOption(ns.optionsTable, "modulesCombat")
	if not control then fail(scenario, "the Combat module toggle is missing") end
	control.set(nil, true)
	if states.Manners_Combat ~= 2 then fail(scenario, "Combat was not enabled") end
	control.set(nil, false)
	if states.Manners_Combat ~= 0 then fail(scenario, "Combat was not disabled") end
	rawset(_G, "C_AddOns", nil)
end

do
	local scenario = "modules: an unloaded module can be enabled in combat and repaints"
	Mock.reset()
	Mock.inCombat = true
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	local realC, repaints = rawget(_G, "C_AddOns"), 0
	local state, character = 0, nil
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function() return state end,
		EnableAddOn = function(folder, name)
			if folder ~= "Manners_Combat" then fail(scenario, "enabled " .. tostring(folder)) end
			character = name
			state = 2
		end,
		DisableAddOn = function() fail(scenario, "disabled an unloaded module in combat") end,
	})
	local oldRepaint = ns.RepaintOptions
	ns.RepaintOptions = function() repaints = repaints + 1 end
	local control = H.findOption(ns.optionsTable, "modulesCombat")
	if control.disabled() then fail(scenario, "an unloaded Combat module was disabled in combat") end
	control.set(nil, true)
	if state ~= 2 or character ~= UnitGUID("player") then
		fail(scenario, "the current character was not passed to EnableAddOn")
	end
	if repaints == 0 or not MannersAPI:ModuleReloadPending() then
		fail(scenario, "the pending reload did not repaint")
	end
	ns.RepaintOptions = oldRepaint
	rawset(_G, "C_AddOns", realC)
	Mock.inCombat = false
end

do
	local scenario = "modules: a loaded module cannot be disabled in combat"
	Mock.reset()
	Mock.class = "PALADIN"
	Mock.inCombat = true
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local control = H.findOption(ns.optionsTable, "modulesCombat")
	if not control.disabled() then fail(scenario, "loaded Combat could be disabled in combat") end
	if MannersAPI:SetModuleEnabled("combat", false) then
		fail(scenario, "loaded Combat changed state in combat")
	end
	Mock.inCombat = false
end

do
	local scenario = "modules: core options never call a disabled Combat cure chooser"
	Mock.reset()
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	for _, key in ipairs({
		"breakFreeKey", "mendInFightKey", "cureFightKey", "cureFightKey2",
		"cureFightPlain", "cureFightShift", "cureFightCtrl",
	}) do
		local control = H.findOption(ns.optionsTable, key)
		if control then
			local okGet, value = pcall(control.get)
			if not okGet then fail(scenario, key .. " get threw with modules absent: " .. tostring(value)) end
			local want = key:find("cureFight", 1, true) and key ~= "cureFightKey" and key ~= "cureFightKey2" and "none" or ""
			if value ~= want then fail(scenario, key .. " read " .. tostring(value) .. ", not " .. want) end
			if control.set then
				local okSet, setErr = pcall(control.set, {}, "G")
				if not okSet then fail(scenario, key .. " set threw with modules absent: " .. tostring(setErr)) end
			end
		end
	end
end

do
	local scenario = "modules: the Manners menu enables and disables addon folders"
	Mock.reset()
	local realC = rawget(_G, "C_AddOns")
	local ns = load(scenario, true)
	if not ns then
		rawset(_G, "C_AddOns", realC)
		return
	end
	drive(scenario, ns)
	local api = MannersAPI
	local states = { Manners_Combat = 0 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	local control = H.findOption(ns.optionsTable, "modulesCombat")
	if not control then fail(scenario, "the Combat module toggle is missing") end
	control.set(nil, true)
	if states.Manners_Combat ~= 2 then fail(scenario, "the Combat addon was not enabled") end
	if not api:ModuleReloadPending() then fail(scenario, "the inline Reload UI action is not pending") end
	control.set(nil, false)
	if states.Manners_Combat ~= 0 then fail(scenario, "the Combat addon was not disabled") end
	if api:ModuleReloadPending() then fail(scenario, "changing back to the loaded state still asks for Reload UI") end
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules: unknown addon enable states do not read as enabled"
	Mock.reset()
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	local realC = rawget(_G, "C_AddOns")
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function() return nil end,
	})
	local api = MannersAPI
	if api:IsModuleEnabled("combat") then
		fail(scenario, "an unknown saved state made an absent Combat module look enabled")
	end
	local changed = api:SetModuleEnabled("combat", true)
	if changed then fail(scenario, "a client with no enable API reported a module change") end
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules: disabling loaded Services stops its runtime immediately and still asks for Reload UI"
	Mock.reset()
	Mock.class = "MAGE"
	local realC = rawget(_G, "C_AddOns")
	local ns = load(scenario)
	if not ns then
		rawset(_G, "C_AddOns", realC)
		return
	end
	drive(scenario, ns)
	local states = { Manners_Services = 2 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	local control = H.findOption(ns.optionsTable, "servicesModule")
	if not control then fail(scenario, "the Services page has no module switch") end
	Mock.knownSpells = Mock.knownSpells or {}
	Mock.knownSpells[130] = true
	ns.db.profile.sources.asked = true
	ns.Courtesy.SetServiceOn("slowfall", true)
	ns.Courtesy.SetScope("slowfall", "group", true)
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.Courtesy.Forget()
	ns.Courtesy.Sync()
	local serviceFrame = ns.Courtesy.frame
	if not (serviceFrame and serviceFrame.events and next(serviceFrame.events)) then
		fail(scenario, "Services was not live before its switch went off")
	end
	ns.standingRequests[#ns.standingRequests + 1] = {
		keys = { ["courtesy:slowfall"] = true }, name = "Service Only",
	}
	ns.standingRequests[#ns.standingRequests + 1] = {
		keys = { ["courtesy:slowfall"] = true, intellect = "single" }, name = "Mixed Request",
	}
	local inFlight = {
		name = "In Flight", expires = GetTime() + 60,
		keys = { ["courtesy:slowfall"] = true },
	}
	local served = 0
	MannersAPI:RegisterCallback("Service.Given", function() served = served + 1 end)
	ns.Courtesy.Pressed({
		name = "In Flight",
		courtesy = {
			request = inFlight, stage = "cast", key = "courtesy:slowfall",
			spell = 130, buffKey = "courtesy:slowfall",
		},
	}, { isBar = true }, GetTime())
	control.set(nil, false)
	if states.Manners_Services ~= 0 or MannersAPI:ModuleActive("services") ~= false
		or not MannersAPI:ModuleReloadPending() then
		fail(scenario, "disabling Services did not stop it and request Reload UI")
	end
	if serviceFrame.events and next(serviceFrame.events) then
		fail(scenario, "Services kept its request-event frame live")
	end
	local retiredService = { name = "Service Only", buff = { key = "courtesy:slowfall" },
		courtesy = {}, reason = "asked" }
	if not ns.Prompt.lib.Retired(retiredService, GetTime()) then
		fail(scenario, "a suspended Services entry could survive the prompt hold")
	end
	local state = ns.Prompt.state
	local oldHeld, oldAt = state.heldEntry, state.heldAt
	retiredService.priority = 1
	state.heldEntry, state.heldAt = retiredService, GetTime()
	local coreEntry = { name = "Core Entry", buff = { key = "intellect" }, reason = "group", priority = 9 }
	if ns.Prompt:PickTop({ coreEntry }, coreEntry) ~= coreEntry then
		fail(scenario, "the prompt hold kept a suspended Services entry over a live core entry")
	end
	state.heldEntry, state.heldAt = oldHeld, oldAt
	if #ns.standingRequests ~= 1 or ns.standingRequests[1].keys["courtesy:slowfall"] ~= nil
		or ns.standingRequests[1].keys.intellect ~= "single" then
		fail(scenario, "suspending Services did not drop only its own standing request keys")
	end
	control.set(nil, false)
	if MannersAPI:ModuleActive("services") ~= false or not MannersAPI:ModuleReloadPending() then
		fail(scenario, "setting loaded Services off twice cleared the pending disable")
	end
	control.set(nil, true)
	if states.Manners_Services ~= 2 or MannersAPI:ModuleActive("services") ~= true
		or MannersAPI:ModuleReloadPending() then
		fail(scenario, "restoring loaded Services kept an unnecessary reload")
	end
	if ns.Courtesy.frame ~= serviceFrame or not (serviceFrame.events and next(serviceFrame.events)) then
		fail(scenario, "Services did not resume on its existing frame")
	end
	ns.Courtesy.CastWentOut(130)
	if served ~= 0 or inFlight.keys["courtesy:slowfall"] ~= true then
		fail(scenario, "a service cast from before suspension completed after resume")
	end
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules: disabling loaded Combat stops cures and combat events before Reload UI"
	Mock.reset()
	Mock.class = "PALADIN"
	Mock.knownSpells = { [4987] = true, [1152] = true }
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local realC = rawget(_G, "C_AddOns")
	local states = { Manners_Combat = 2 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	ns.db.profile.sources.cures = true
	ns.db.profile.prompt.cureFight = true
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.CureFight:Refresh()
	local button = ns.CureFight:Button()
	local active = ns.CuresWanted() and button and button:GetAttribute("macrotext1")
	if not active then fail(scenario, "Combat was not active before it was disabled") end
	MannersAPI:SetModuleEnabled("combat", false)
	if MannersAPI:ModuleActive("combat") ~= false or ns.CuresWanted() then
		fail(scenario, "out-of-combat cures stayed active after Combat was disabled")
	end
	if button:GetAttribute("macrotext1") or button:IsShown() then
		fail(scenario, "the secure cure button stayed armed after Combat was disabled")
	end
	local frame = ns.CureFight.frame
	if frame and frame.events and next(frame.events) then
		fail(scenario, "the cure event frame kept listening after Combat was disabled")
	end
	local retiredCure = { name = "Cure Only", buff = { key = "cure:poison" }, cure = "Poison" }
	if not ns.Prompt.lib.Retired(retiredCure, GetTime()) then
		fail(scenario, "a suspended Combat cure could survive the prompt hold")
	end
	MannersAPI:SetModuleEnabled("combat", true)
	if not MannersAPI:ModuleActive("combat") or not ns.CuresWanted() then
		fail(scenario, "restoring Combat did not restore its saved cure setting")
	end
	ns.CureFight:Refresh()
	if not button:GetAttribute("macrotext1") then fail(scenario, "the secure cure button did not re-arm") end
	if ns.CureFight:Button() ~= button then fail(scenario, "Combat recreated the secure cure frame before reload") end
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules: loaded Pets and My Buffs stop runtime work before Reload UI"
	Mock.reset()
	Mock.class = "HUNTER"
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local realC = rawget(_G, "C_AddOns")
	local states = { Manners_Pets = 2, Manners_MyBuffs = 2 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	ns.db.profile.sources.self = true
	ns.db.profile.ownBuffs.apart = true
	ns.db.profile.prompt.locked = false
	ns.Supplies:Refresh()
	local supplies = ns.Supplies:Button()
	if not (supplies and supplies:IsShown()) then
		fail(scenario, "the My Buffs supplies frame was not visible before suspension")
	end
	MannersAPI:SetModuleEnabled("pets", false)
	local petFrame = ns.Beast and ns.Beast.frame
	local hintsFrame = ns.Beast and ns.Beast.hintsFrame
	if MannersAPI:ModuleActive("pets") ~= false
		or (petFrame and petFrame.events and next(petFrame.events))
		or (hintsFrame and hintsFrame.events and next(hintsFrame.events)) then
		fail(scenario, "Pets kept runtime work after its module switch went off")
	end
	local retiredPet = { name = "Pet Care", buff = { key = "beast:call" }, care = true }
	if not ns.Prompt.lib.Retired(retiredPet, GetTime()) then
		fail(scenario, "a suspended Pets entry could survive the prompt hold")
	end
	MannersAPI:SetModuleEnabled("mybuffs", false)
	local journalFrame = ns.Pet and ns.Pet.frame
	local selfOn = ns.OffersSelf()
	local events = journalFrame and journalFrame.events and next(journalFrame.events)
	if MannersAPI:ModuleActive("mybuffs") ~= false or selfOn or events then
		fail(scenario, ("My Buffs kept runtime: active %s, self %s, event %s")
			:format(tostring(MannersAPI:ModuleActive("mybuffs")), tostring(selfOn), tostring(events)))
	end
	if supplies:IsShown() or supplies:GetAttribute("macrotext1") then
		fail(scenario, "My Buffs left its secure supplies button visible or armed")
	end
	local retiredOwn = { name = "You", buff = { key = "own:item" }, reason = "self" }
	if not ns.Prompt.lib.Retired(retiredOwn, GetTime()) then
		fail(scenario, "a suspended My Buffs entry could survive the prompt hold")
	end
	local realExists, petReads = UnitExists, 0
	rawset(_G, "UnitExists", function(unit, ...)
		if unit == "pet" then petReads = petReads + 1 end
		return realExists(unit, ...)
	end)
	MannersAPI:SetModuleEnabled("pets", true)
	ns.BuildQueue()
	rawset(_G, "UnitExists", realExists)
	if petReads == 0 then fail(scenario, "Pets resumed without invalidating its pet cache") end
	MannersAPI:SetModuleEnabled("mybuffs", true)
	if not MannersAPI:ModuleActive("pets") or not MannersAPI:ModuleActive("mybuffs") then
		fail(scenario, "re-enabling loaded modules did not restore their runtime")
	end
	if (petFrame and ns.Beast.frame ~= petFrame) or (journalFrame and ns.Pet.frame ~= journalFrame) then
		fail(scenario, "a module rebuilt its event frame before Reload UI")
	end
	if petFrame and not (petFrame.events and next(petFrame.events)) then
		fail(scenario, "Pets did not resume its event registrations")
	end
	if journalFrame and not (journalFrame.events and next(journalFrame.events)) then
		fail(scenario, "My Buffs did not resume its companion event registrations")
	end
	if ns.Supplies:Button() ~= supplies or not supplies:IsShown() then
		fail(scenario, "My Buffs did not resume its existing supplies button")
	end
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules: the Reload UI button is disabled in combat"
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local reload = H.findOption(ns.optionsTable, "modulesReload")
	Mock.inCombat = true
	if not reload or not reload.disabled or reload.disabled() ~= true then
		fail(scenario, "Reload UI remains live during combat")
	end
	Mock.inCombat = false
end

do
	local scenario = "modules: combat locks every loaded module switch and the API"
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local realC = rawget(_G, "C_AddOns")
	local states = { Manners_Combat = 2 }
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	Mock.inCombat = true
	for _, key in ipairs({
		"modulesCombat", "modulesAchievements", "modulesPets",
		"modulesMyBuffs", "modulesServices",
	}) do
		local control = H.findOption(ns.optionsTable, key)
		if not control or not control.disabled or control.disabled() ~= true then
			fail(scenario, key .. " remains live in combat")
		end
	end
	local api = MannersAPI
	local changed = api:SetModuleEnabled("combat", false)
	if changed or states.Manners_Combat ~= 2 then
		fail(scenario, ("the module API changed addon state in combat: changed %s, state %s, toggle %s")
			:format(tostring(changed), tostring(states.Manners_Combat), tostring(api:CanToggleModule("combat"))))
	end
	Mock.inCombat = false
end

do
	local scenario = "modules: core page resets keep settings owned by disabled modules"
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local states = {
		Manners_Combat = 2, Manners_MyBuffs = 2, Manners_Services = 2,
	}
	local realC = rawget(_G, "C_AddOns")
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 2 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
	})
	MannersAPI:SetModuleEnabled("combat", false)
	MannersAPI:SetModuleEnabled("mybuffs", false)
	MannersAPI:SetModuleEnabled("services", false)
	local profile = ns.db.profile
	profile.prompt.breakFree = true
	profile.prompt.cureFight = true
	profile.prompt.cureFightEach = false
	profile.prompt.fightButtons = "always"
	profile.prompt.cureFightMods.PRIEST = { plain = 17, shift = 18, ctrl = 0 }
	profile.sources.cures = true
	profile.sources.curesStrangers = true
	profile.sources.curesSelf = true
	profile.filters.cureSeconds = 55
	profile.beast.fightMend = true
	profile.supplies.size = 73
	profile.buff.optIn.fireshield = true
	ns.OptionsPage.ResetPage("who")
	ns.OptionsPage.ResetPage("appearance")
	ns.OptionsPage.ResetPage("pet")
	ns.OptionsPage.ResetPage("fight")
	local kept = profile.prompt.breakFree == true and profile.prompt.cureFight == true
		and profile.prompt.cureFightEach == false and profile.prompt.fightButtons == "always"
		and profile.prompt.cureFightMods.PRIEST
		and profile.prompt.cureFightMods.PRIEST.plain == 17
		and profile.sources.cures == true and profile.sources.curesStrangers == true
		and profile.sources.curesSelf == true and profile.filters.cureSeconds == 55
		and profile.beast.fightMend == true and profile.supplies.size == 73
		and profile.buff.optIn.fireshield == true
	if not kept then fail(scenario, "a disabled module's saved choice was reset by a core page") end
	rawset(_G, "C_AddOns", realC)
end

do
	local scenario = "modules: 1.12.5 opens one module chooser after login"
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local opened, marker = 0, ns.db.profile.moduleWelcome1125
	local oldOpen = ns.OpenOptions
	ns.OpenOptions = function(page, quiet)
		if page ~= "modules" or quiet ~= true then fail(scenario, "opened " .. tostring(page)) end
		opened = opened + 1
	end
	Mock.frameEvent("PLAYER_ENTERING_WORLD", true, false)
	Mock.runTimers(1)
	Mock.runTimers(2)
	if opened ~= 1 or ns.db.profile.moduleWelcome1125 ~= true or not MannersAPI:ModuleWelcomeOpen() then
		fail(scenario, ("chooser open %s, marker %s, visible %s")
			:format(tostring(opened), tostring(ns.db.profile.moduleWelcome1125), tostring(MannersAPI:ModuleWelcomeOpen())))
	end
	Mock.frameEvent("PLAYER_ENTERING_WORLD", false, true)
	Mock.runTimers(2)
	if opened ~= 1 then fail(scenario, "the chooser opened twice") end
	MannersAPI:DismissModuleWelcome()
	if MannersAPI:ModuleWelcomeOpen() then fail(scenario, "Done did not dismiss the chooser") end
	ns.OpenOptions = oldOpen
	ns.db.profile.moduleWelcome1125 = marker
	Mock.reset()
end

do
	local scenario = "modules: chooser is marked only when actually presented"
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local opened = 0
	local oldOpen = ns.OpenOptions
	ns.OpenOptions = function(page, quiet)
		if page ~= "modules" or quiet ~= true then fail(scenario, "wrong chooser arguments") end
		opened = opened + 1
	end
	Mock.frameEvent("PLAYER_ENTERING_WORLD", true, false)
	if ns.db.profile.moduleWelcome1125 == true or MannersAPI:ModuleWelcomeOpen() then
		fail(scenario, "the one-second delay consumed the notice before presenting it")
	end
	Mock.inCombat = true
	Mock.runTimers(1)
	if ns.db.profile.moduleWelcome1125 == true or MannersAPI:ModuleWelcomeOpen() or opened ~= 0 then
		fail(scenario, "combat consumed the chooser")
	end
	Mock.inCombat = false
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	if opened ~= 1 or ns.db.profile.moduleWelcome1125 ~= true or not MannersAPI:ModuleWelcomeOpen() then
		fail(scenario, "leaving combat did not present the outstanding chooser")
	end
	MannersAPI:DismissModuleWelcome()
	ns.OpenOptions = oldOpen
	Mock.reset()
end

do
	local scenario = "modules: chooser retries when the delayed window cannot present"
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local opened, oldOpen = 0, ns.OpenOptions
	Mock.frameEvent("PLAYER_ENTERING_WORLD", true, false)
	ns.OpenOptions = nil
	Mock.runTimers(1)
	if ns.db.profile.moduleWelcome1125 == true or MannersAPI:ModuleWelcomeOpen() then
		fail(scenario, "an unavailable window consumed the chooser")
	end
	ns.OpenOptions = function() opened = opened + 1 end
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	if opened ~= 1 or ns.db.profile.moduleWelcome1125 ~= true then
		fail(scenario, "the chooser did not retry the unpresented notice")
	end
	MannersAPI:DismissModuleWelcome()
	ns.OpenOptions = oldOpen
	Mock.reset()
end

do
	local scenario = "modules: chooser callback stays bound to its profile"
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local first, opened = ns.db.profile, 0
	local oldOpen = ns.OpenOptions
	ns.OpenOptions = function(page)
		if page ~= "modules" then fail(scenario, "wrong chooser page") end
		opened = opened + 1
	end
	Mock.frameEvent("PLAYER_ENTERING_WORLD", true, false)
	ns.db:SetProfile("Alt")
	local second = ns.db.profile
	Mock.runTimers(2)
	if opened ~= 1 or second.moduleWelcome1125 ~= true or first.moduleWelcome1125 == true then
		fail(scenario, "the delayed chooser presented or marked the wrong profile")
	end
	if not MannersAPI:DismissModuleWelcome() or MannersAPI:ModuleWelcomeOpen() then
		fail(scenario, "the presented profile did not dismiss its chooser")
	end
	ns.OpenOptions = oldOpen
	Mock.reset()
end

do
	local scenario = "modules migration: a shared profile migrates each character once"
	Mock.reset()
	Mock.playerName = { "Alice", "Mockrealm" }
	Mock.playerGUID = "Player-1-Alice"
	Mock.sv.profile = {
		optionalModulesMigrated = true,
		optionalCombatMigrated = true,
		sources = { self = true, asked = true, courtesyRefresh = true },
		prompt = { breakFree = true },
	}
	local realDB, realC = rawget(_G, "MannersDB"), rawget(_G, "C_AddOns")
	rawset(_G, "MannersDB", { profiles = { Default = Mock.sv.profile } })
	local enabled, calls = {}, 0
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder, character)
			return enabled[character .. ":" .. folder] == true and 2 or 0
		end,
		EnableAddOn = function(folder, character)
			calls = calls + 1
			enabled[character .. ":" .. folder] = true
		end,
		DisableAddOn = function(folder, character)
			enabled[character .. ":" .. folder] = nil
		end,
	})
	local ns = load(scenario, true)
	if not ns then
		rawset(_G, "MannersDB", realDB)
		rawset(_G, "C_AddOns", realC)
		return
	end
	drive(scenario, ns)
	local firstCalls = calls
	Mock.playerName = { "Beth", "Mockrealm" }
	Mock.playerGUID = "Player-1-Beth"
	MannersAPI:MigrateOptionalModules(true)
	if calls ~= firstCalls + 3 then
		fail(scenario, "the second character did not migrate every required folder")
	end
	enabled["Player-1-Beth:Manners_MyBuffs"] = nil
	MannersAPI:MigrateOptionalModules(true)
	if calls ~= firstCalls + 3 then
		fail(scenario, "an intentional per-character disable was enabled again")
	end
	rawset(_G, "MannersDB", realDB)
	rawset(_G, "C_AddOns", realC)
	Mock.reset()
end

do
	local scenario = "modules migration: marker-only profile state still counts as unvisited"
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	ns.db.keys = { char = "Alice - Mockrealm" }
	ns.db.sv.profiles = {
		["Alice - Mockrealm"] = {
			optionalModulesMigrated = true,
			optionalCombatMigrated = true,
			optionalModulesMigratedCharacters = { ["Alice - Mockrealm"] = true },
			optionalCombatMigratedCharacters = { ["Alice - Mockrealm"] = true },
		},
	}
	ns.db.sv.profileKeys = {}
	if ns.Setup.OwnProfileExists() then
		fail(scenario, "migration-only profile state made the character profile count as real")
	end
end
