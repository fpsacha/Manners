-- The third hunt of the day, where two of the day's features meet:
--
--   * the companion pet is not brought out of the journal while Manners is
--     switched off or snoozed (Companion.lua, Pet:Tick);
--   * a trade the asker opens gets nothing while Manners is switched off,
--     snoozed or its prompt unlocked: the last scan's offer is not gone by
--     once scans offer nothing (Courtesy.lua, TradeOpened);
--   * /manners debug says the queue's count and the cure lines to a class
--     with a cure and no buff for anybody else (Commands.lua);
--   * the line said once at an inn is not spent while Hide all Manners
--     messages is on (Hints.lua, ns.RestingHint);
--   * a resurrection or a courtesy whose token went is not said to have lost
--     a line to the nameplates: neither carries one (Speech.lua,
--     ns.NoteTokenlessHold);
--   * a resurrection's tooltip says nothing about a reading set by the
--     options (Prompt/Button.lua);
--   * a press of the bar macro while the prompt is on a courtesy's trade says
--     to press the prompt, and the macro's slot shows no spell
--     (Prompt/Press.lua, BarWaiting; Prompt/Macro.lua).
--
-- Every scenario name starts with "hunt3-seams:" so the mutations in
-- tests/mutations/hunt3-seams.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt = H.strangers, H.freshPrompt

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session with `globals` in place of the client's own, each put back
-- whatever happens.
local function with(scenario, globals, body)
	local saved = {}
	for name in pairs(globals) do saved[name] = rawget(_G, name) end
	for name, value in pairs(globals) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for name in pairs(globals) do rawset(_G, name, saved[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

---------------------------------------------------------------------------
-- the companion pet, with Manners off or snoozed
---------------------------------------------------------------------------

Mock.reset()
do
	local scenario = "hunt3-seams: no pet is brought out of the journal while Manners is switched off or snoozed"
	Mock.setFlavour("mists")
	Mock.class = "WARRIOR"
	-- The journal: two pets owned, none out, and the summons made of it.
	local journal = { calls = {} }
	local restoreUnits = strangers({})
	with(scenario, {
		IsMounted = function() return false end,
		IsInInstance = function() return false, "none" end,
		IsStealthed = function() return false end,
		IsFlying = function() return false end,
		IsResting = function() return false end,
		UnitInVehicle = function() return false end,
		UnitOnTaxi = function() return false end,
		IsSpellKnown = function() return false end,
		IsPlayerSpell = function() return false end,
		C_PetBattles = { IsInBattle = function() return false end },
		hooksecurefunc = function(owner, name, hook)
			local real = owner[name]
			owner[name] = function(...)
				real(...)
				hook(...)
			end
		end,
		C_PetJournal = {
			GetSummonedPetGUID = function() return journal.out end,
			GetNumPets = function() return 2, 2 end,
			HasFavoritePets = function() return false end,
			PetIsSummonable = function() return true end,
			SummonPetByGUID = function(guid)
				journal.calls[#journal.calls + 1] = "guid"
				journal.out = guid
			end,
			SummonRandomPet = function()
				journal.calls[#journal.calls + 1] = "random"
				journal.out = "BattlePet-0-00000000BBBB"
			end,
			DismissSummonedPet = function() journal.out = nil end,
		},
	}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local profile = ns.db.profile
		profile.sources.self = true
		profile.ownBuffs.pick.pet = "auto"
		ns.ForgetScrolls()
		local function tick(seconds)
			Mock.advance(seconds)
			if ns.Pet:Wanted() then ns.Pet:Tick(GetTime()) end
		end
		if not ns.Pet:Wanted() then
			fail(scenario, "SKIPPED -- the scan does not ask for the pet with the switch on")
			return
		end
		-- Switched off: the scan still runs, and brings nothing out.
		profile.enabled = false
		tick(1)
		tick(ns.Pet.TRY_EVERY + 1)
		if #journal.calls > 0 then
			fail(scenario, "a pet was brought out of the journal with Manners switched off (" .. table.concat(journal.calls, ", ") .. ")")
		end
		profile.enabled = true
		journal.calls, journal.out = {}, nil
		-- Snoozed: the same, until the snooze is over.
		ns.addon:HandleSlash("snooze 5")
		if not ns.SnoozeLeft(GetTime()) then
			fail(scenario, "SKIPPED -- /manners snooze 5 did not snooze")
		else
			tick(1)
			tick(ns.Pet.TRY_EVERY + 1)
			if #journal.calls > 0 then
				fail(scenario, "a pet was brought out of the journal while snoozed (" .. table.concat(journal.calls, ", ") .. ")")
			end
		end
		ns.addon:HandleSlash("snooze off")
		journal.calls, journal.out = {}, nil
		-- Back on: one comes out, as it would have.
		tick(ns.Pet.TRY_EVERY + 1)
		if #journal.calls ~= 1 then
			fail(scenario, "back on with none out, " .. #journal.calls .. " summons from the journal, not 1")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

---------------------------------------------------------------------------
-- a courtesy: bags, a spell book, a cursor and a trade window
---------------------------------------------------------------------------

local SPELLS = {
	[1459] = "Arcane Intellect",
	[5504] = "Conjure Water", [5505] = "Conjure Water", [5506] = "Conjure Water", [6127] = "Conjure Water",
	[10138] = "Conjure Water", [10139] = "Conjure Water", [10140] = "Conjure Water",
	[587] = "Conjure Food", [28612] = "Conjure Food",
}
local MAGE = { 1459, 5504, 5505, 5506, 6127, 10138, 10139, 10140, 587, 28612 }

-- As tests/scenarios/courtesy-review.lua stands them in: `bags` item -> count,
-- `partner` the token the trade's other side answers with, `open` whether the
-- trade window is up; `trade` and `picked` are what went where.
local function world(bags)
	local w = { bags = bags, trade = {}, picked = {}, open = false, partner = "nameplate1" }
	local known = {}
	for _, id in ipairs(MAGE) do known[id] = true end
	local knows = function(id) return known[id] == true end
	local function slotItems()
		local list = {}
		for item, count in pairs(w.bags) do
			if count > 0 then list[#list + 1] = item end
		end
		table.sort(list)
		return list
	end
	w.globals = {
		IsSpellKnown = knows, IsPlayerSpell = knows,
		C_Spell = setmetatable({ GetSpellName = function(id) return SPELLS[id] end }, { __index = _G.C_Spell }),
		GetItemCount = function(item) return w.bags[item] or 0 end,
		C_Container = {
			GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
			GetContainerItemID = function(bag, slot) return bag == 0 and slotItems()[slot] or nil end,
			GetContainerItemInfo = function() return { isLocked = false } end,
			PickupContainerItem = function(bag, slot)
				w.cursor = slotItems()[slot]
				w.picked[#w.picked + 1] = w.cursor
			end,
		},
		GetCursorInfo = function() if w.cursor then return "item", w.cursor end end,
		CursorHasItem = function() return w.cursor ~= nil end,
		ClearCursor = function() w.cursor = nil end,
		ClickTradeButton = function(index)
			w.trade[index] = w.cursor
			w.cursor = nil
		end,
		GetTradePlayerItemLink = function(index) return w.trade[index] and "link" or nil end,
		AcceptTrade = function() w.accepted = true end,
		UnitGUID = function(unit)
			if unit == "NPC" then return "Player-1-" .. w.partner end
			return "Player-1-" .. tostring(unit)
		end,
		UnitLevel = function() return 60 end,
		MAX_TRADABLE_ITEMS = 6,
		TradeFrame = { IsShown = function() return w.open end },
	}
	return w
end

local function hear(ns, text, sender, guid)
	ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

-- Only people who ask, and the water switch.
local function asking(ns, scenario)
	freshPrompt(ns, scenario)
	local db = ns.db.profile
	db.sources.asked, db.sources.courtesyRefresh = true, true
	db.sources.strangers, db.sources.group, db.sources.self = false, false, false
end

Mock.reset()
do
	local scenario = "hunt3-seams: a trade the asker opens gets nothing while Manners is off, snoozed or unlocked"
	local names = { nameplate1 = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	local w = world({ [8079] = 20 })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		asking(ns, scenario)
		hear(ns, "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade") then
			fail(scenario, "SKIPPED -- the water in the bags is not offered as a trade")
			return
		end
		local profile = ns.db.profile
		names.NPC = { "Anna", "Aim" }
		w.open = true
		-- She opens the trade, and no press came before it.
		local function opens(state)
			ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
			if w.trade[1] or #w.picked > 0 then
				fail(scenario, "the water went into the trade she opened while Manners was " .. state)
			end
			if #ns.standingRequests ~= 1 then
				fail(scenario, "her request was answered while Manners was " .. state)
			end
			w.trade, w.picked, w.cursor = {}, {}, nil
		end
		profile.enabled = false
		opens("switched off")
		profile.enabled = true
		ns.addon:HandleSlash("snooze 5")
		if not ns.SnoozeLeft(GetTime()) then
			fail(scenario, "SKIPPED -- /manners snooze 5 did not snooze")
		else
			opens("snoozed")
		end
		ns.addon:HandleSlash("snooze off")
		profile.prompt.locked = false
		opens("unlocked")
		profile.prompt.locked = true
		-- Back on, and still within her minute: the water goes in.
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade") then
			fail(scenario, "SKIPPED -- back on, the water is no longer offered")
			return
		end
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		if w.trade[1] ~= 8079 then
			fail(scenario, "back on, the water was not put in the trade she opened (" .. tostring(w.trade[1]) .. ")")
		end
		if w.accepted then fail(scenario, "Manners accepted the trade") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

---------------------------------------------------------------------------
-- the bar macro, with the prompt on a courtesy's trade
---------------------------------------------------------------------------

Mock.reset()
do
	local scenario = "hunt3-seams: a bar press on a courtesy's trade says to press the prompt, and the slot shows no spell"
	local names = { nameplate1 = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	local w = world({ [8079] = 20 })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		asking(ns, scenario)
		ns.db.profile.verbose = true
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.CreateClickMacro()
		if not Mock.dropOnBar(2) then
			fail(scenario, "SKIPPED -- no macro on the bar")
			return
		end
		hear(ns, "water pls", "Anna Aim", "Player-1-nameplate1")
		ns.addon:Tick()
		Mock.runTimers(0)
		local current = ns.Prompt.state.current
		if not (current and current.courtesy and current.courtesy.stage == "trade") then
			fail(scenario, "SKIPPED -- the prompt is not on the trade")
			return
		end
		local kind, what = Mock.slotShows(2)
		if kind == "spell" then
			fail(scenario, "the bar slot shows " .. tostring(what) .. " while the macro holds no cast for the trade")
		end
		Mock.printed = {}
		local casts = Mock.pressBar(2) or {}
		local text = table.concat(Mock.printed, "\n")
		if #casts ~= 0 then fail(scenario, "SKIPPED -- the bar press cast something") end
		local _, times = text:gsub("a trade somebody asked for %-%- press the prompt itself", "")
		if times ~= 1 then
			fail(scenario, "a bar press on the trade said: " .. flat(text))
		end
		-- The prompt itself still runs the trade.
		local ran = H.pressButton(ns)
		if not (ran and ran:find("/trade", 1, true)) then
			fail(scenario, "SKIPPED -- the prompt's own press ran " .. flat(ran))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

---------------------------------------------------------------------------
-- /manners debug, for a class with a cure and no buff for anybody else
---------------------------------------------------------------------------

Mock.reset()
do
	local scenario = "hunt3-seams: /manners debug says the cure lines and the count to a class with no buff for others"
	Mock.class = "SHAMAN"
	Mock.groupSize = 3
	local restoreUnits = strangers({ party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } })
	local base = C_UnitAuras
	-- A poison on the first member with five seconds left: under the ten a
	-- cure waits for, so nothing is offered and only the report can say why.
	local auras = setmetatable({
		GetAuraDataByIndex = function(unit, index, filter)
			if filter ~= "HARMFUL" then return base.GetAuraDataByIndex(unit, index, filter) end
			if unit ~= "party1" or index ~= 1 then return nil end
			return { name = "Nasty Poison", spellId = 90000, dispelName = "Poison",
				expirationTime = Mock.now + 5, duration = 60, isHarmful = true, auraInstanceID = 9001 }
		end,
	}, { __index = base })
	with(scenario, {
		IsSpellKnown = function(id) return id == 526 end,
		IsPlayerSpell = function(id) return id == 526 end,
		UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end,
		C_UnitAuras = auras,
	}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers, sources.self, sources.cures = true, false, false, true
		ns.Guard("probe", ns.ProbeCapabilities)
		if ns.caps.hasClassBuffs then
			fail(scenario, "SKIPPED -- the shaman has a buff for somebody else")
			return
		end
		Mock.advance(4)
		ns.BuildQueue()
		Mock.advance(4)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		if not said:find("cures: ", 1, true) then
			fail(scenario, "/manners debug has no cure line for a shaman with Cure Poison: " .. flat(said))
		end
		if not said:find("left alone", 1, true) then
			fail(scenario, "/manners debug does not say why the poisoned member is left alone: " .. flat(said))
		end
		if not said:find("queue now: 0", 1, true) then
			fail(scenario, "/manners debug does not give the queue's count: " .. flat(said))
		end
		-- Each said once.
		local _, cures = said:gsub("cures: ", "")
		local _, counts = said:gsub("queue now:", "")
		if cures > 1 or counts > 1 then fail(scenario, "said twice: " .. flat(said)) end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

---------------------------------------------------------------------------
-- the resting line, with every message hidden
---------------------------------------------------------------------------

Mock.reset()
do
	local scenario = "hunt3-seams: the resting line is not spent while Hide all Manners messages is on"
	with(scenario, {
		-- Find Herbs learned and off: something of yours is missing.
		C_Minimap = {
			GetNumTrackingTypes = function() return 2 end,
			GetTrackingInfo = function(i)
				return ({ { spellID = 2383, active = false }, { spellID = 2580, active = false } })[i]
			end,
		},
		IsSpellKnown = function(id) return id == 1459 or id == 2383 or id == 2580 end,
		IsPlayerSpell = function(id) return id == 1459 or id == 2383 or id == 2580 end,
		IsResting = function() return true end,
	}, function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.ForgetTrackingList()
		local profile = ns.db.profile
		profile.sources.self = true
		profile.ownBuffs.inCities = false
		local function said()
			for _, line in ipairs(Mock.printed) do
				if type(line) == "string" and line:find("Also in cities and inns", 1, true) then return true end
			end
			return false
		end
		local function spent()
			local hints = ns.db.char.hints
			return type(hints) == "table" and hints.resting == true
		end
		ns.db.char.hints = nil
		Mock.printed = {}
		profile.silentChat = true
		if ns.RestingHint(GetTime()) then fail(scenario, "counted as said with every message hidden") end
		if said() then fail(scenario, "SKIPPED -- the line was printed with every message hidden") end
		if spent() then fail(scenario, "the once was spent on a line that was never shown") end
		-- With the chat back on: said, as it would have been.
		profile.silentChat = false
		Mock.printed = {}
		if not (ns.RestingHint(GetTime()) and said()) then
			fail(scenario, "with the chat back on, the line was not said")
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

---------------------------------------------------------------------------
-- the nameplate line, for a kind that carries no line
---------------------------------------------------------------------------

Mock.reset()
do
	local scenario = "hunt3-seams: a resurrection or a courtesy is not said to have lost a line to the nameplates"
	local restoreUnits = strangers({})
	with(scenario, {
		-- Friendly nameplates off, as GetCVar answers.
		GetCVar = function(name)
			if name == "nameplateShowFriendlyPlayers" then return "0" end
			return nil
		end,
		SetCVar = function() end,
	}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		ns.db.profile.verbose = true
		local function lines()
			local n = 0
			for _, line in ipairs(Mock.printed or {}) do
				if type(line) == "string" and line:find("friendly nameplates off", 1, true) then n = n + 1 end
			end
			return n
		end
		if not ns.FriendlyPlatesOff() then
			fail(scenario, "SKIPPED -- friendly nameplates do not read as off")
			return
		end
		Mock.printed = {}
		ns.NoteTokenlessHold({ name = "Dora Dusk", reason = "nearby", res = true, buff = { key = "res" } })
		if lines() > 0 then fail(scenario, "a resurrection is said to have left a line out") end
		ns.NoteTokenlessHold({ name = "Anna Aim", reason = "asked", courtesy = { stage = "trade" }, buff = { key = "courtesy:water" } })
		if lines() > 0 then fail(scenario, "a courtesy is said to have left a line out") end
		-- A buff for a stranger still says it, and the once was not used up.
		ns.NoteTokenlessHold({ name = "Bert Beside", reason = "nearby", buff = { key = "intellect" } })
		if lines() ~= 1 then
			fail(scenario, "a buff's line held back for want of a token said it " .. lines() .. " times, not once")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

---------------------------------------------------------------------------
-- a resurrection's tooltip
---------------------------------------------------------------------------

Mock.reset()
do
	local scenario = "hunt3-seams: a resurrection's tooltip says nothing about a reading set by the options"
	Mock.class = "PRIEST"
	Mock.groupSize = 4
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } })
	local realDead, realSpell = UnitIsDeadOrGhost, C_Spell
	local known = { [2006] = true, [2010] = true }
	with(scenario, {
		UnitIsDeadOrGhost = function(unit)
			if unit == "player" then return realDead(unit) end
			return unit == "party1"
		end,
		UnitIsGhost = function() return false end,
		UnitHasIncomingResurrection = function() return false end,
		UnitIsFeignDeath = function() return false end,
		UnitAffectingCombat = function() return false end,
		UnitIsVisible = function() return true end,
		UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end,
		C_Spell = setmetatable({
			GetSpellName = function(id) return known[id] and "Resurrection" or realSpell.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = realSpell }),
		IsSpellKnown = function(id) return known[id] == true end,
		IsPlayerSpell = function(id) return known[id] == true end,
	}, function()
		local ns = load(scenario)
		if not ns then return end
		for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do known[id] = true end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.strangers, sources.self = false, false
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.advance(4)
		local entry
		for _, e in ipairs(ns.BuildQueue()) do
			if e.res and not e.resNames then entry = e end
		end
		if not entry then
			fail(scenario, "SKIPPED -- the dead member is offered no resurrection")
			return
		end
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		ns.db.profile.prompt.tooltip = "full"
		local button = ns.Prompt:GetButton()
		Mock.tooltip = {}
		if button.scripts.OnEnter then button.scripts.OnEnter(button) end
		local tip = table.concat(Mock.tooltip or {}, " / ")
		if not tip:find("In your group.", 1, true) then
			fail(scenario, "SKIPPED -- the full tooltip is not up for the resurrection: " .. tip)
			return
		end
		if tip:find("Not checking whether they have it", 1, true) then
			fail(scenario, "the resurrection's tooltip speaks of a reading the options turned off: " .. tip)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
