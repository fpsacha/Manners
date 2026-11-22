-- Fixes found in the fight's buttons (Prompt/BreakFree.lua and its neighbours).
-- Forever unless a scenario names the client.
--
-- Every name starts with "fight-fix:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local COMMAND = "CLICK MannersBreakFree:LeftButton"

-- A Forsaken who knows Will of the Forsaken, its key on F, nobody owed.
-- opts.control: what HasFullControl answers for the whole run (true, false or
-- "secret"); unset leaves the mock's own.
local function withForsaken(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.playerRace = "Scourge"
	Mock.knownSpells = { [7744] = true }
	Mock.lossOfControlShape = opts.shape
	local restore = strangers({})
	local realControl = _G.HasFullControl
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			ns.db.profile.verbose = true
			ns.Prompt:ApplyStyle()
			Mock.bindings = Mock.bindings or {}
			Mock.bindings.F = COMMAND
			ns.addon:Tick()
			Mock.runTimers(0)
			if opts.control ~= nil then
				local answer = opts.control
				if answer == "secret" then answer = Mock.SECRET end
				rawset(_G, "HasFullControl", function() return answer end)
			end
			body(ns, scenario)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	rawset(_G, "HasFullControl", realControl)
	Mock.inCombat = false
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

local function lit(ns)
	local look = ns.BreakFree:Look()
	return look ~= nil and look.alpha == 1
end

-- ------------------------------------------------------------------ 1
-- Forever: the loss of control's type is secret and HasFullControl cannot be
-- read. A fear at t=0 (control lost, a secret report) runs eight seconds; a
-- second fear lands at t=8 with only a secret report and runs to t=16, no
-- control gained between them. The guess lasts ten seconds after the LAST
-- word of a loss of control, so break free stays lit to t=16.
withForsaken("fight-fix: a second secret fear inside the guess keeps break free lit ten seconds from it", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = { { locType = Mock.SECRET } }
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
	if not lit(ns) then fail(scenario, "SKIPPED -- not lit for the first fear") release(ns) return end
	for t = 1, 8 do
		Mock.runTimers(1)
		if not lit(ns) then fail(scenario, ("gone at t=%d, inside the first fear"):format(t)) release(ns) return end
	end
	-- The second fear: a fresh secret report, no control gained in between.
	Mock.lossOfControl = { { locType = Mock.SECRET } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
	for t = 9, 16 do
		Mock.runTimers(1)
		if not lit(ns) then
			fail(scenario, ("break free went out at t=%d while the second fear (from t=8) still holds"):format(t))
			break
		end
	end
	release(ns)
end, { control = "secret" })

-- ------------------------------------------------------------------ 2
-- Forever, a mage: every harmful aura comes back secret in a fight, but the
-- game's list of the debuffs you can remove ("HARMFUL|RAID") names party1, who
-- carries a 30 s curse. The cure button shows "a debuff you can remove" and
-- stays lit for as long as the list still names them: no UNIT_AURA came, so
-- nothing changed. It must not blink out and back in while the curse holds,
-- and one person counts once in /manners debug's "needing a cure".
do
	local scenario = "fight-fix: a curse seen only from the game's list keeps the cure button lit without a blink"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "MAGE"
	Mock.groupSize = 3
	local names = { party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } }
	local restore = strangers(names)
	local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "C_Spell" }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local debuffs = { party1 = { { kind = "Curse", ends = 0 } } }
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return id == 475 end)
		rawset(_G, "IsPlayerSpell", function(id) return id == 475 end)
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end)
		local baseAuras, baseSpell = C_UnitAuras, C_Spell
		rawset(_G, "C_UnitAuras", setmetatable({
			-- Every harmful slot withheld, as Forever does in a fight.
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return baseAuras.GetAuraDataByIndex(unit, index, filter) end
				return Mock.SECRET
			end,
			-- The game's own list stays plain while the curse is on.
			GetUnitAuraInstanceIDs = function(unit)
				local out = {}
				for i, d in ipairs(debuffs[unit] or {}) do
					if d.ends > Mock.now then out[#out + 1] = 9000 + i end
				end
				return out
			end,
		}, { __index = baseAuras }))
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) if id == 475 then return "Remove Lesser Curse" end return baseSpell.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = baseSpell }))
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		ns.db.profile.verbose = true
		ns.db.profile.prompt.cureFight = true
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.bindings = Mock.bindings or {}
		Mock.bindings.F = "CLICK MannersCureFight:LeftButton"
		ns.addon:Tick()
		Mock.runTimers(0)
		debuffs.party1[1].ends = Mock.now + 30
		pull(ns)
		for _ = 1, 3 do Mock.runTimers(0.11) end
		local look = ns.CureFight:Look()
		if not look or look.alpha ~= 1 or not tostring(look.name:GetText() or ""):find("Gwen", 1, true) then
			fail(scenario, "SKIPPED -- not lit for Gwen's curse after the pull: " .. tostring(look and look.alpha))
			release(ns)
			return
		end
		-- Ten seconds of the fight in 0.05 s steps, no UNIT_AURA: the list still
		-- names Gwen the whole time.
		local blinks, firstAt = 0, nil
		local wasLit = true
		for step = 1, 200 do
			Mock.runTimers(0.05)
			local lit = look.alpha == 1 and tostring(look.name:GetText() or "") ~= ""
			if wasLit and not lit then
				blinks = blinks + 1
				firstAt = firstAt or step * 0.05
			end
			wasLit = lit
		end
		if blinks > 0 then
			fail(scenario, ("the button went dark %d times in 10 s while the curse held (first at %.2f s in)"):format(blinks, firstAt))
		end
		local line = ns.CureFightLines()[2] or ""
		local seen = tonumber(line:match("(%d+) needing a cure"))
		if seen ~= 1 then fail(scenario, "one person with one curse counted as " .. tostring(seen) .. " needing a cure: " .. line) end
		release(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.inCombat = false
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 3
-- Classic Era, a druid with "A button for each cure" off: one button, the
-- second cure on Shift. The game's Key Bindings give the command two keys, F
-- and SHIFT-G. SHIFT-G holds Shift on every press, so a [mod:shift] clause
-- would make it always cast Cure Poison: the button must be armed with the
-- first cure alone, as it is when the only key is bound with Shift.
do
	local scenario = "fight-fix: a second key bound with Shift arms the first cure alone"
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "DRUID"
	Mock.groupSize = 3
	Mock.held = { [1126] = true }
	local names = { party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } }
	local restore = strangers(names)
	local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_Spell" }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = { [1126] = true, [8946] = true, [2782] = true }
	local spellNames = { [1126] = "Mark of the Wild", [8946] = "Cure Poison", [2782] = "Remove Curse" }
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end)
		local baseSpell = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return spellNames[id] or baseSpell.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = baseSpell }))
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		ns.db.profile.verbose = true
		ns.db.profile.prompt.cureFight = true
		ns.db.profile.prompt.cureFightEach = false
		ns.Guard("probe", ns.ProbeCapabilities)
		local command = "CLICK MannersCureFight:LeftButton"
		Mock.bindings = { F = command }
		ns.addon:Tick()
		Mock.runTimers(0)
		local before = ns.CureFight:Button():GetAttribute("macrotext1")
		if not tostring(before):find("mod:shift", 1, true) then
			fail(scenario, "SKIPPED -- with F alone the macro has no Shift clause: " .. tostring(before))
			return
		end
		-- The second key, with Shift in it.
		Mock.bindings = { F = command, ["SHIFT-G"] = command }
		Mock.frameEvent("UPDATE_BINDINGS")
		ns.addon:Tick()
		Mock.runTimers(0)
		local macro = ns.CureFight:Button():GetAttribute("macrotext1")
		if macro ~= "/cast [@mouseover,help,nodead][help,nodead][@player] Remove Curse" then
			fail(scenario, "with F and SHIFT-G bound the macro reads " .. tostring(macro)
				.. ": SHIFT-G would always cast the second cure")
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.inCombat = false
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 4
-- Forever, a mage: party1 carries a curse the game's list of the debuffs you
-- can remove ("HARMFUL|RAID") names, every harmful aura withheld in the fight,
-- and the client withholds party1's name as well (UnitName comes back secret;
-- UnitExists, UnitIsPlayer and UnitCanAssist stay plain). The cure button may
-- show, but it must never call them "nil": not on the name line and not on the
-- key line ("target nil and press F").
do
	local scenario = "fight-fix: a withheld name on the cure button never reads as nil"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "MAGE"
	Mock.groupSize = 3
	local names = { party1 = { Mock.SECRET }, party2 = { "Hugo", "Holt" } }
	local restore = strangers(names)
	local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "C_Spell" }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local debuffs = { party1 = { { kind = "Curse", ends = 0 } } }
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return id == 475 end)
		rawset(_G, "IsPlayerSpell", function(id) return id == 475 end)
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end)
		local baseAuras, baseSpell = C_UnitAuras, C_Spell
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return baseAuras.GetAuraDataByIndex(unit, index, filter) end
				return Mock.SECRET
			end,
			GetUnitAuraInstanceIDs = function(unit)
				local out = {}
				for i, d in ipairs(debuffs[unit] or {}) do
					if d.ends > Mock.now then out[#out + 1] = 9000 + i end
				end
				return out
			end,
		}, { __index = baseAuras }))
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) if id == 475 then return "Remove Lesser Curse" end return baseSpell.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = baseSpell }))
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		ns.db.profile.verbose = true
		ns.db.profile.prompt.cureFight = true
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.bindings = Mock.bindings or {}
		Mock.bindings.F = "CLICK MannersCureFight:LeftButton"
		ns.addon:Tick()
		Mock.runTimers(0)
		debuffs.party1[1].ends = Mock.now + 30
		pull(ns)
		for _ = 1, 3 do Mock.runTimers(0.11) end
		local look = ns.CureFight:Look()
		local nameLine = look and tostring(look.name:GetText() or "") or ""
		local keyLine = look and look.key and tostring(look.key:GetText() or "") or ""
		if look and look.alpha == 1 then
			if nameLine:find("nil", 1, true) then
				fail(scenario, "the cure button names the person \"nil\": " .. nameLine)
			end
			if keyLine:find("nil", 1, true) then
				fail(scenario, "the key line tells the player to aim at \"nil\": " .. keyLine)
			end
		end
		release(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.inCombat = false
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
