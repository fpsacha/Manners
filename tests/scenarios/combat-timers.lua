-- Delayed work in Manners: Combat must stop when the loaded module is
-- suspended. Timers cannot be cancelled, so each callback must check activity
-- again when it finally runs.

local _, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
end

local function suspendAndRun(ns, label, scenario)
	local realC, realGuard = rawget(_G, "C_AddOns"), ns.Guard
	local states = { Manners_Combat = 2 }
	local late = 0
	rawset(_G, "C_AddOns", {
		GetAddOnEnableState = function(folder) return states[folder] or 0 end,
		DisableAddOn = function(folder) states[folder] = 0 end,
		EnableAddOn = function(folder) states[folder] = 2 end,
	})
	ns.Guard = function(where, ...)
		if where == label and MannersAPI:ModuleActive("combat") ~= true then late = late + 1 end
		return realGuard(where, ...)
	end
	MannersAPI:SetModuleEnabled("combat", false)
	Mock.runTimers(20)
	ns.Guard, Mock.inCombat = realGuard, false
	rawset(_G, "C_AddOns", realC)
	if MannersAPI:ModuleActive("combat") ~= false then
		fail(scenario, "Combat did not suspend")
	elseif late ~= 0 then
		fail(scenario, tostring(late) .. " delayed callback(s) ran after suspension")
	end
end

local function cureSession(scenario, withAura)
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "DRUID"
	Mock.knownSpells = { [1126] = true, [8946] = true, [2782] = true }
	Mock.groupSize = 1
	local realAuras = rawget(_G, "C_UnitAuras")
	if withAura then
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if unit == "player" and index == 1 and filter == "HARMFUL" then
					return {
						name = "Poison thing", spellId = 90000, dispelName = "Poison",
						expirationTime = Mock.now + 20, duration = 60,
						canActivePlayerDispel = true, isHarmful = true, auraInstanceID = 9001,
					}
				end
			end,
		}, { __index = realAuras }))
	end
	local ns = load(scenario)
	if not ns then
		rawset(_G, "C_UnitAuras", realAuras)
		return nil
	end
	drive(scenario, ns)
	ns.db.profile.prompt.cureFight = true
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.CureFight:Refresh()
	Mock.timers = {}
	Mock.secureActions = true
	return ns, realAuras
end

do
	local scenario = "combat-timers: the cure's delayed flush stops after suspension"
	local ns, realAuras = cureSession(scenario, false)
	if ns then
		pull(ns)
		if #Mock.timers == 0 then fail(scenario, "the cure did not schedule its flush") end
		release(ns)
		suspendAndRun(ns, "cure in a fight", scenario)
		rawset(_G, "C_UnitAuras", realAuras)
	end
	Mock.reset()
end

do
	local scenario = "combat-timers: the cure's delayed recheck stops after suspension"
	local ns, realAuras = cureSession(scenario, true)
	if ns then
		pull(ns)
		Mock.runTimers(0.11)
		local queued = #Mock.timers
		if queued == 0 then
			fail(scenario, "the readable poison did not schedule a cure recheck")
		else
			release(ns)
			suspendAndRun(ns, "cure in a fight", scenario)
		end
		rawset(_G, "C_UnitAuras", realAuras)
	end
	Mock.reset()
end

do
	local scenario = "combat-timers: Mend Pet callbacks stop after suspension"
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "HUNTER"
	Mock.knownSpells = { [136] = true }
	Mock.sv.char = { beastLast = "Pet" }
	local realDead, realHealth, realMax = rawget(_G, "UnitIsDead"), rawget(_G, "UnitHealth"), rawget(_G, "UnitHealthMax")
	rawset(_G, "UnitIsDead", function() return false end)
	rawset(_G, "UnitHealth", function() return 100 end)
	rawset(_G, "UnitHealthMax", function() return 100 end)
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.db.profile.beast.fightMend = true
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.MendPet:Refresh()
		Mock.timers = {}
		Mock.secureActions = true
		pull(ns)
		Mock.timers = {}
		ns.MendPet:Button():Show()
		ns.MendPet.Changed()
		local repaint = #Mock.timers
		Mock.frameEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 136)
		if repaint ~= 1 or #Mock.timers < 2 then
			fail(scenario, ("Mend Pet queued %d repaint and %d total callbacks (shown %s)")
				:format(repaint, #Mock.timers, tostring(ns.MendPet:Button():IsShown())))
		else
			release(ns)
			suspendAndRun(ns, "mend pet", scenario)
		end
	end
	rawset(_G, "UnitIsDead", realDead)
	rawset(_G, "UnitHealth", realHealth)
	rawset(_G, "UnitHealthMax", realMax)
	Mock.reset()
end

do
	local scenario = "combat-timers: break-free rechecks stop after suspension"
	Mock.reset()
	Mock.playerRace = "Scourge"
	Mock.knownSpells = { [7744] = true }
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.db.profile.prompt.breakFree = true
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.BreakFree:Refresh()
		Mock.timers = {}
		pull(ns)
		Mock.lossOfControl = { { locType = "FEAR", spellID = 5782 } }
		Mock.frameEvent("PLAYER_CONTROL_LOST")
		Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
		if #Mock.timers == 0 then
			fail(scenario, "break free did not schedule a recheck")
		else
			release(ns)
			suspendAndRun(ns, "break free", scenario)
		end
	end
	Mock.reset()
end
