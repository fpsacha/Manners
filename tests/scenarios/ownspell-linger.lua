-- A spell of my own the verdict took off (Blink left no aura): the prompt's
-- hold and the empty-queue fuse must not keep it on the panel, armed, for the
-- seconds after the verdict.
--
-- Every scenario name starts with "ownspell-linger: " so the mutations in
-- tests/mutations/ownspell-linger.py can name the one that has to catch them.

local dir, H = ...
local fail, load, strangers, freshPrompt, findOption = H.fail, H.load, H.strangers, H.freshPrompt, H.findOption

local BLINK = 1953
local TOUCHED = { "C_UnitAuras", "C_Spell", "IsSpellKnown", "IsPlayerSpell", "IsResting" }

local function gone(ns, scenario, label)
	local S = ns.Prompt.state
	local text = tostring(ns.Prompt:GetButton():GetAttribute("macrotext1") or "")
	if S.current and S.current.buff and S.current.buff.key == "ownspell" .. BLINK then
		fail(scenario, label .. ": the removed spell is still the panel's current entry")
	end
	if S.heldEntry and S.heldEntry.buff and S.heldEntry.buff.key == "ownspell" .. BLINK then
		fail(scenario, label .. ": the removed spell is still held")
	end
	if text:find("ownspell" .. BLINK, 1, true) then
		fail(scenario, label .. ": the button is still armed with the removed spell")
	end
end

local function run(scenario, hover, pressIt, alone, memory)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "MAGE"
	local names = { [BLINK] = "Blink" }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers(alone and {} or { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bob", "Bee" }, nameplate3 = { "Cid", "Cee" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local baseKnows = IsSpellKnown
		local function knows(id) return id == BLINK or baseKnows(id) end
		rawset(_G, "IsSpellKnown", knows)
		rawset(_G, "IsPlayerSpell", knows)
		rawset(_G, "IsResting", function() return false end)
		local baseSpell = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return names[id] or baseSpell.GetSpellName(id) end,
			GetSpellIDForSpellIdentifier = function(t) if t == "Blink" then return BLINK end return tonumber(t) or baseSpell.GetSpellIDForSpellIdentifier and baseSpell.GetSpellIDForSpellIdentifier(t) end,
			GetSpellInfo = function(t)
				local id = tonumber(t) or (t == "Blink" and BLINK) or nil
				if not id then return baseSpell.GetSpellInfo and baseSpell.GetSpellInfo(t) end
				return { name = names[id] or baseSpell.GetSpellName(id), spellID = id, iconID = 135736 }
			end,
			GetSpellTexture = function(id) if id == BLINK then return 135736 end return baseSpell.GetSpellTexture and baseSpell.GetSpellTexture(id) end,
			IsSpellHarmful = function() return false end,
			IsSpellPassive = function() return false end,
			IsSpellHelpful = function(id) return id == BLINK end,
		}, { __index = baseSpell }))
		local baseAuras = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, id) if id == BLINK then return nil end return baseAuras.GetUnitAuraBySpellID(unit, id) end,
			GetAuraDataBySpellName = function(unit, name, filter) if name == "Blink" then return nil end return baseAuras.GetAuraDataBySpellName(unit, name, filter) end,
		}, { __index = baseAuras }))
		freshPrompt(ns, scenario)
		CreateMacro("Manners", "INV_MISC_NOTE_03", "/click MannersBar", false)
		ns.addon:UPDATE_MACROS()
		ns.db.profile.sources.self = true
		ns.db.profile.ownBuffs.inCities = true
		ns.Guard("probe", ns.ProbeCapabilities)
		findOption(ns.optionsTable, "ownSpellAdd").set({ "ownSpellAdd" }, "Blink")
		if pressIt == "window" then
			ns.OpenOptions("who")
			ns.WindowUI.Reveal("who.ownSpell1")
			pressIt = false
		end
		Mock.advance(1)
		ns.addon:Tick()
		if hover then
			local fn = ns.Prompt:GetButton().scripts.OnEnter
			if fn then fn(ns.Prompt:GetButton()) end
		end
		if pressIt == true then
			H.pressButton(ns)
			ns.addon:Tick()
		end
		if memory then
			ns.db.char.ownLast = ns.db.char.ownLast or {}
			ns.db.char.ownLast["ownspell" .. BLINK] = BLINK
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "", "Cast-own-" .. BLINK, BLINK)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-own-" .. BLINK, BLINK)
		if pressIt == "tickfirst" then
			for _ = 1, 4 do
				Mock.advance(0.4)
				ns.addon:Tick()
			end
			Mock.advance(0.35)
			ns.addon:Tick()
			Mock.runTimers(0.05)
		else
			Mock.runTimers(2)
		end
		gone(ns, scenario, "right after the verdict")
		if memory and type(ns.db.char.ownLast) == "table" and ns.db.char.ownLast["ownspell" .. BLINK] ~= nil then
			fail(scenario, "the last pick of the removed spell is still remembered")
		end
		Mock.advance(0.4)
		ns.addon:Tick()
		gone(ns, scenario, "half a second after the verdict")
		for i = 1, 3 do
			Mock.advance(0.4)
			ns.addon:Tick()
		end
		for i = 1, 30 do
			Mock.advance(0.4)
			ns.addon:Tick()
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

run("ownspell-linger: the hold lets go of a spell the verdict took off", false, "tickfirst")
run("ownspell-linger: the fuse does not re-arm a spell the verdict took off", false, "tickfirst", true)
run("ownspell-linger: the verdict forgets the last pick of the spell", false, "tickfirst", true, true)
