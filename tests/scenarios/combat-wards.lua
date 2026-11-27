-- Reactive Fire Ward / Frost Ward buttons belong to Manners: Combat.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local FIRE, FROST = 4, 16

local function pull()
	Mock.inCombat = false
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.inCombat = true
end

local function shown(ns, key)
	local look = ns.ReactiveWards and ns.ReactiveWards:Look(key)
	return look and look.visible == true and look.alpha == 1
end

do
	local scenario = "combat-wards: classic damage reveals only a known matching ward"
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "MAGE"
	Mock.knownSpells = { [10225] = true, [28609] = true }
	Mock.secureActions = true
	local original = _G.C_UnitAuras
	Mock.spellUsable = {
		[10225] = { usable = true, noMana = false },
		[28609] = { usable = true, noMana = false },
	}
	local rawSpells, originalSpells = rawget(_G, "C_Spell"), _G.C_Spell
	rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = function(id)
		local answer = Mock.spellUsable[id]
		return answer and answer.usable, answer and answer.noMana
	end }, { __index = originalSpells }))
	local aura = nil
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataByIndex = function(unit, index, filter)
			if unit == "player" and filter == "HELPFUL" and index == 1 and aura then
				return { spellId = aura }
			end
			return nil
		end,
	}, { __index = original }))
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local profile = ns.db.profile
		if profile.prompt.reactiveWards ~= false then fail(scenario, "the ward button is on by default") end
		if not H.findOption(ns.optionsTable, "reactiveWards") then
			fail(scenario, "the ward switch is missing from the options")
		end
		profile.prompt.reactiveWards = true
		ns.ReactiveWards:Refresh()
		local fire = ns.ReactiveWards:Button("fire")
		local frost = ns.ReactiveWards:Button("frost")
		local promptMacro = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if not (fire and frost) then fail(scenario, "the known ward buttons were not pre-made") end
		if fire:GetAttribute("macrotext1") ~= "/cast Fire Ward"
			or frost:GetAttribute("macrotext1") ~= "/cast Frost Ward" then
			fail(scenario, "the ward buttons were not pre-armed out of combat")
		end
		pull()
		Mock.frameEvent("UNIT_COMBAT", "player", "HEAL", "", 100, FIRE)
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, 1)
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, FIRE + FROST)
		if shown(ns, "fire") or shown(ns, "frost") then
			fail(scenario, "a non-concrete or ambiguous event revealed a ward")
		end
		profile.prompt.reactiveWards = false
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, FIRE)
		if shown(ns, "fire") or shown(ns, "frost") then
			fail(scenario, "a disabled ward option revealed a button in combat")
		end
		profile.prompt.reactiveWards = true
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "CRITICAL", 100, FIRE)
		if not shown(ns, "fire") or shown(ns, "frost") then
			fail(scenario, "fire damage did not reveal Fire Ward alone")
		end
		Mock.spellUsable[10225] = { usable = Mock.SECRET, noMana = false }
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, FIRE)
		if shown(ns, "fire") then fail(scenario, "a secret usability answer revealed Fire Ward") end
		Mock.spellUsable[10225] = { usable = false, noMana = true }
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, FIRE)
		if shown(ns, "fire") then fail(scenario, "insufficient mana revealed Fire Ward") end
		Mock.spellUsable[10225] = { usable = false, noMana = false }
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, FIRE)
		if shown(ns, "fire") then fail(scenario, "an unusable Fire Ward was revealed") end
		Mock.spellUsable[10225] = { usable = true, noMana = false }
		Mock.spellCooldowns = { [10225] = { startTime = GetTime(), duration = 30 } }
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, FIRE)
		if shown(ns, "fire") then fail(scenario, "Fire Ward's cooldown revealed its button") end
		Mock.spellCooldowns = nil
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, FIRE)
		if not shown(ns, "fire") then fail(scenario, "a ready Fire Ward did not reappear") end
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 75, FROST)
		if shown(ns, "fire") or not shown(ns, "frost") then
			fail(scenario, "frost damage did not replace Fire Ward with Frost Ward")
		end
		if ns.Prompt:GetButton():GetAttribute("macrotext1") ~= promptMacro then
			fail(scenario, "a ward damage event re-armed the main prompt in combat")
		end
		aura = 10225
		Mock.frameEvent("UNIT_AURA", "player", {})
		if shown(ns, "fire") or shown(ns, "frost") then
			fail(scenario, "an active ward stayed visible")
		end
		aura = nil
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 50, FIRE)
		Mock.frameEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 10225)
		if shown(ns, "fire") or shown(ns, "frost") then
			fail(scenario, "a successful ward cast did not clear the button")
		end
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 50, FIRE)
		profile.prompt.reactiveWards = false
		ns.ReactiveWards:Release()
		if shown(ns, "fire") or not ns.ReactiveWards:Look("fire").cover:IsShown() then
			fail(scenario, "turning the option off left an invisible secure ward clickable")
		end
		profile.prompt.reactiveWards = true
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		if shown(ns, "fire") or shown(ns, "frost") then
			fail(scenario, "the fight's end did not clear the ward button")
		end
		Mock.knownSpells[28609] = nil
		ns.ReactiveWards.Learn()
		ns.ReactiveWards:Refresh()
		if frost:GetAttribute("macrotext1") ~= nil then
			fail(scenario, "an unlearned Frost Ward stayed armed")
		end
		pull()
		Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, FROST)
		if shown(ns, "frost") then fail(scenario, "an unlearned Frost Ward was revealed") end
	end
	rawset(_G, "C_UnitAuras", original)
	rawset(_G, "C_Spell", rawSpells)
	Mock.reset()
end

do
	for _, flavour in ipairs({ "camelot", "mainline" }) do
		local scenario = "combat-wards: " .. flavour .. " does not fake secret school damage"
		Mock.reset()
		Mock.setFlavour(flavour)
		Mock.class = "MAGE"
		Mock.knownSpells = { [10225] = true, [28609] = true }
		local ns = load(scenario)
		if ns then
			drive(scenario, ns)
			ns.db.profile.prompt.reactiveWards = true
			ns.ReactiveWards:Refresh()
			if ns.ReactiveWards:Button("fire") or ns.ReactiveWards:Button("frost") then
				fail(scenario, "a secret-restricted client made ward buttons")
			end
			local control = H.findOption(ns.optionsTable, "reactiveWards")
			if not control or control.hidden() ~= true then
				fail(scenario, "the unsupported client's options offered reactive wards")
			end
		end
		Mock.reset()
	end
end

do
	local scenario = "combat-wards: disabled Combat and reload leave no armed ward button"
	Mock.reset()
	Mock.setFlavour("tbc")
	Mock.class = "MAGE"
	Mock.knownSpells = { [27128] = true, [32796] = true }
	Mock.spellUsable = {
		[27128] = { usable = true, noMana = false },
		[32796] = { usable = true, noMana = false },
	}
	local rawSpells, originalSpells = rawget(_G, "C_Spell"), _G.C_Spell
	rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = function(id)
		local answer = Mock.spellUsable[id]
		return answer and answer.usable, answer and answer.noMana
	end }, { __index = originalSpells }))
	local ns = load(scenario, true)
	if ns then
		drive(scenario, ns)
		if ns.ReactiveWards then fail(scenario, "the core made reactive wards without Combat") end
		local module = H.loadModule(scenario, "Modules/Combat/Manners_Combat.toc")
		if module then
			ns.db.profile.prompt.reactiveWards = true
			ns.ReactiveWards:Refresh()
			pull()
			Mock.frameEvent("UNIT_COMBAT", "player", "DAMAGE", "", 100, FIRE)
			if not shown(ns, "fire") then fail(scenario, "TBC did not reveal Fire Ward") end
			Mock.inCombat = false
			local realAddOns = rawget(_G, "C_AddOns")
			local states = { Manners_Combat = 2 }
			rawset(_G, "C_AddOns", {
				GetAddOnEnableState = function(folder) return states[folder] or 0 end,
				DisableAddOn = function(folder) states[folder] = 0 end,
				EnableAddOn = function(folder) states[folder] = 2 end,
			})
			MannersAPI:SetModuleEnabled("combat", false)
			if shown(ns, "fire") or ns.ReactiveWards:Button("fire"):GetAttribute("macrotext1") then
				fail(scenario, "suspending Combat left a ward visible or armed")
			end
			local events = ns.ReactiveWards.frame
				and (ns.ReactiveWards.frame._events or ns.ReactiveWards.frame.events)
			if events and next(events) then
				fail(scenario, "suspending Combat left ward events registered")
			end
			rawset(_G, "C_AddOns", realAddOns)
		end
	end
	rawset(_G, "C_Spell", rawSpells)
	Mock.reset()
end
