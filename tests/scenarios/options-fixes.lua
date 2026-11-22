-- Options and diagnostics findings from the r35 bug hunt (area: options). Each
-- scenario is red on the tree before its fix and says why.
--
-- Every scenario name starts with "options-fix:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- ------------------------------------------------------------------ Well-Rested world
-- As tests/scenarios/wellrested.lua sets it up: bags, auras by id, level,
-- mounted, the bag's cooldown.
local BAG, RESTED = 211527, 429959
local world
local REST_TOUCHED = { "C_Item", "C_UnitAuras", "C_Container", "UnitLevel", "GetMaxPlayerLevel", "IsMounted",
	"IsSpellKnown", "IsPlayerSpell", "IsResting" }

local function installRest()
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Miscellaneous", "", "", 7100000 + id, 15, 0 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "GetMaxPlayerLevel", function() return 60 end)
	rawset(_G, "IsMounted", function() return world.mounted end)
	rawset(_G, "IsResting", function() return false end)
	local container = rawget(_G, "C_Container")
	rawset(_G, "C_Container", setmetatable({
		GetItemCooldown = function() return 0, 0, 1 end,
	}, { __index = container or {} }))
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			local expires = world.auras[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 7200, sourceUnit = "player" }
		end,
	}, { __index = base }))
end

local function rested(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARRIOR"
	world = { bags = opts.bags or {}, level = 30, auras = {}, mounted = false }
	local saved = {}
	for _, name in ipairs(REST_TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		installRest()
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		if opts.on then
			ns.db.profile.ownBuffs.pick.rested = "auto"
			ns.ForgetScrolls()
		end
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(REST_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function myself(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- #0
do
	local scenario = "options-fix: an import that switches Well-Rested on offers the bag already in the bags"
	rested(scenario, { bags = { [BAG] = 1 } }, function(ns)
		local pick = ns.db.profile.ownBuffs.pick
		if pick.rested ~= "off" then
			fail(scenario, "SKIPPED -- Well-Rested is " .. tostring(pick.rested) .. " to begin with")
			return
		end
		-- A scan with the switch off reads the bags without the bag.
		if mine(ns) then fail(scenario, "SKIPPED -- offered with the switch off") return end
		-- The string to paste: the same settings with the switch on.
		pick.rested = "auto"
		local text = ns.ExportSettings()
		pick.rested = "off"
		if not text:find("rested", 1, true) then
			fail(scenario, "SKIPPED -- the export does not carry the Well-Rested switch")
			return
		end
		local ok, message = ns.ImportSettings(text)
		if not ok then
			fail(scenario, "SKIPPED -- the import refused: " .. tostring(message))
			return
		end
		if pick.rested ~= "auto" then
			fail(scenario, "SKIPPED -- the import left Well-Rested " .. tostring(pick.rested))
			return
		end
		-- Nothing in the bags moved: no BAG_UPDATE_DELAYED.
		if key(mine(ns)) ~= "rested" .. BAG then
			local before, said = key(mine(ns)), myself(ns)
			-- The bags read again: what a bag change does.
			ns.addon:BAG_UPDATE_DELAYED()
			fail(scenario, "Well-Rested switched on by an import, the bag in the bags: offered "
				.. before .. ", Myself says '" .. said .. "'; after BAG_UPDATE_DELAYED offered "
				.. key(mine(ns)) .. ", Myself says '" .. myself(ns) .. "'")
		end
	end)
end

-- #2
do
	local scenario = "options-fix: Well-Rested up is named in the Myself line, not ?"
	rested(scenario, { on = true, bags = { [BAG] = 1 } }, function(ns)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "SKIPPED -- the bag was not offered to begin with")
			return
		end
		world.auras[RESTED] = GetTime() + 7000
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(1)
		if mine(ns) then fail(scenario, "SKIPPED -- Well-Rested up and still offered") return end
		local text = myself(ns)
		if text:find("? is up", 1, true) then
			fail(scenario, "the Myself line for Well-Rested up reads: " .. text)
		end
	end)
end

-- #3
do
	local scenario = "options-fix: Well-Rested is not said to have no timer"
	rested(scenario, { on = true, bags = { [BAG] = 1 } }, function(ns)
		local text = table.concat(ns.LeadLines(), " / ")
		if text:find("Well-Rested: no timer -- never topped up.", 1, true) then
			fail(scenario, "When a top-up is due says a two-hour aura never runs out: " .. text)
		end
	end)
end

-- ------------------------------------------------------------------ #1 Emote to use
do
	local scenario = "options-fix: Emote to use is shown beside the /thank switch for a class with nothing to give"
	Mock.reset()
	Mock.class = "ROGUE"
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		if ns.caps.hasClassBuffs then
			fail(scenario, "SKIPPED -- a rogue reads as having buffs to give")
			return
		end
		local thank = findOption(ns.optionsTable, "thankEmote")
		local token = findOption(ns.optionsTable, "thankEmoteToken")
		if not (thank and token) then
			fail(scenario, "SKIPPED -- What I say has no /thank or no Emote to use")
			return
		end
		local function hidden(c)
			local rule = c.hidden
			if type(rule) == "function" then return rule({}) and true or false end
			return rule and true or false
		end
		if hidden(thank) then fail(scenario, "SKIPPED -- the /thank switch is hidden for a rogue") return end
		if hidden(token) then
			fail(scenario, "a rogue sees /thank people who buff me but not Emote to use: always /thank")
		end
		noErrors(scenario, ns)
	end)
	undo()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ own armor (#4 #5 #6)
local DEMON_SKIN = 687
local OWN_TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_UnitAuras", "IsResting", "IsInInstance" }

local function wear(ns, auras)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	local byId, byName = {}, {}
	for _, a in ipairs(auras or {}) do
		local aura = { spellId = a.id, name = ns.SpellNameFor(a.id),
			expirationTime = a.left and (Mock.now + a.left) or 0, sourceUnit = "player" }
		byId[a.id] = aura
		if aura.name then byName[aura.name] = aura end
	end
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit == "player" and (ns.OWN_BY_ID[id] or byId[id]) then return byId[id] end
			return base.GetUnitAuraBySpellID(unit, id)
		end,
		GetAuraDataBySpellName = function(unit, name)
			if unit == "player" then return byName[name] end
			return nil
		end,
	}, { __index = base }))
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

local function warlock(scenario, body)
	Mock.reset()
	Mock.class = "WARLOCK"
	local saved = {}
	for _, name in ipairs(OWN_TOUCHED) do saved[name] = rawget(_G, name) end
	IsSpellKnown = function(id) return id == DEMON_SKIN end
	IsPlayerSpell = IsSpellKnown
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		-- Demon Skin is the armor of Forever, Classic Era and TBC; Mists and retail
		-- have other ids and the fixture does not fit them.
		local flavour = ns.Flavour and ns.Flavour.flavour
		if flavour == "mists" or flavour == "mainline" then return end
		wear(ns, {})
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		wear(ns, {})
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(OWN_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- #4
do
	local scenario = "options-fix: Myself says your armor's top-up is due when the prompt offers it, on Skip"
	warlock(scenario, function(ns)
		local f = ns.db.profile.filters
		if f.whenBuffed ~= "skip" or f.selfTopUp ~= true then
			fail(scenario, "SKIPPED -- the defaults are " .. tostring(f.whenBuffed) .. "/" .. tostring(f.selfTopUp))
			return
		end
		wear(ns, { { id = DEMON_SKIN, left = 200 } })
		if key(mine(ns)) ~= "demonarmor" then
			fail(scenario, "SKIPPED -- Demon Skin with 200 s left was not topped up: " .. key(mine(ns)))
			return
		end
		local text = myself(ns)
		if not text:find("running low", 1, true) then
			fail(scenario, "the prompt tops Demon Skin up, and Myself says: " .. text)
		end
	end)
end

-- #5
do
	local scenario = "options-fix: When a top-up is due gives your armor the selfLead moment"
	warlock(scenario, function(ns)
		local f = ns.db.profile.filters
		f.selfLead = 10
		wear(ns, { { id = DEMON_SKIN, left = 500 } })
		if key(mine(ns)) ~= "demonarmor" then
			fail(scenario, "SKIPPED -- ten minutes asked for, Demon Skin with 500 s left: offered " .. key(mine(ns)))
			return
		end
		local line
		for _, l in ipairs(ns.LeadLines()) do
			if l:find(ns.BuffName(ns.FindOwnSpell("demonarmor") or {}) or "\1", 1, true) == 1 or l:find("Demon", 1, true) then
				line = l
			end
		end
		if not line then
			fail(scenario, "SKIPPED -- no line for Demon Skin in " .. table.concat(ns.LeadLines(), " / "))
			return
		end
		if not line:find("topped up at 10m left", 1, true) then
			fail(scenario, "offered at 500 s left (selfLead 10), and the line reads: " .. line)
		end
	end)
end

-- #6
do
	local scenario = "options-fix: the top-up heading does not say off while your own are topped up"
	warlock(scenario, function(ns)
		wear(ns, { { id = DEMON_SKIN, left = 200 } })
		if key(mine(ns)) ~= "demonarmor" then
			fail(scenario, "SKIPPED -- Demon Skin with 200 s left was not topped up: " .. key(mine(ns)))
			return
		end
		local heading = ns.LeadHeading()
		if heading:find("top-ups are off", 1, true) then
			fail(scenario, "defaults: the heading reads '" .. heading .. "' while the prompt tops Demon Skin up"
				.. " under it: " .. table.concat(ns.LeadLines(), " / "))
		end
	end)
end

-- ------------------------------------------------------------------ the full check-up (#7 #8)
local PVP_TOUCHED = { "UnitIsPVP", "UnitIsPVPFreeForAll", "IsPVPTimerRunning" }

local function checkup(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	local saved = {}
	for _, name in ipairs(PVP_TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers(opts.people or {})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(PVP_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function scan(ns, seconds)
	for _ = 1, math.floor(seconds / 0.4 + 0.5) do
		Mock.runTimers(0.4)
		ns.addon:Tick()
	end
end

-- #7 (PvP)
do
	local scenario = "options-fix: the full check-up does not name a player held back for PvP"
	checkup(scenario, { people = { nameplate1 = { "Bobby", "Flagbearer" } } }, function(ns)
		Mock.pvp = { nameplate1 = true }
		scan(ns, 2)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local printed = table.concat(Mock.printed, "\n")
		Mock.printed = {}
		if not printed:find("Bobby", 1, true) then
			fail(scenario, "SKIPPED -- /manners debug does not name Bobby: " .. printed:sub(1, 300))
			return
		end
		local text = ns.FullReport()
		-- The /manners debug section's PvP line (the self-test names him too).
		local line = text:match("[^\n]*Bobby[^\n]*flagged for PvP[^\n]*")
		if line then
			fail(scenario, "the check-up, pasted in public, names Bobby in clear: " .. tostring(line))
		end
	end)
end

-- #7 (a request)
do
	local scenario = "options-fix: the full check-up does not name somebody who asked from out of reach"
	checkup(scenario, {}, function(ns)
		ns.db.profile.sources.asked = true
		ns.addon.CHAT_MSG_WHISPER(ns.addon, "CHAT_MSG_WHISPER", "int pls", "Zedd Faraway", "Common", "", "", "",
			0, 0, "", 0, 1, "Player-1-00ZZZZZZ")
		local lines = table.concat(ns.RequestLines(), "\n")
		if not lines:find("Zedd", 1, true) then
			fail(scenario, "SKIPPED -- the request was not noted: " .. lines)
			return
		end
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Zedd Faraway" then
				fail(scenario, "SKIPPED -- Zedd is queued, so the queue aliases him")
				return
			end
		end
		local text = ns.FullReport()
		if text:find("Zedd", 1, true) then
			local line = text:match("[^\n]*Zedd[^\n]*")
			fail(scenario, "the check-up, pasted in public, names Zedd in clear: " .. tostring(line))
		end
	end)
end

-- #8
do
	local scenario = "options-fix: a player named Bug leaves the check-up's own words alone"
	checkup(scenario, { flavour = "vanilla", people = { nameplate1 = { "Bug" } } }, function(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 10938, 9101)
		ns.addon:Tick()
		local text = ns.FullReport()
		if not text:find("Person 1", 1, true) then
			fail(scenario, "SKIPPED -- nobody was aliased: " .. text:sub(1, 200))
			return
		end
		if not text:find("== Bug report ==", 1, true) then
			fail(scenario, "the alias for Bug overwrote the report's heading: "
				.. tostring(text:match("== [^\n]* report ==")))
		end
	end)
end

-- A name is a word of its own: Intel is not the start of Intellect.
do
	local scenario = "options-fix: a player named Intel leaves the word Intellect alone"
	checkup(scenario, { flavour = "vanilla", people = { nameplate1 = { "Intel" } } }, function(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 10938, 9101)
		ns.addon:Tick()
		local text = ns.FullReport()
		if not text:find("Person 1", 1, true) then
			fail(scenario, "SKIPPED -- nobody was aliased: " .. text:sub(1, 200))
			return
		end
		if text:find("Person 1lect", 1, true) then
			fail(scenario, "the alias for Intel overwrote the start of Intellect: "
				.. tostring(text:match("[^\n]*Person 1lect[^\n]*")))
		elseif not text:find("Intellect", 1, true) then
			fail(scenario, "SKIPPED -- the report never says Intellect")
		end
	end)
end

-- A slider box read back in the client's own language: zhCN shows 120 s as
-- 2分钟, koKR 90 s as 1분 30초, deDE 60 min as 1 Std. Clicking into the box
-- and out again, typing nothing, must leave the setting where it was.
do
	local scenario = "options-fix: a slider box left untouched keeps its value in the client's language"
	local CASES = {
		{ "zhCN", "advanced.reciprocateWindow", "timing", "reciprocateWindow", 120 },
		{ "koKR", "advanced.reciprocateWindow", "timing", "reciprocateWindow", 90 },
		{ "deDE", "when.refreshUnder", "filters", "refreshUnder", 60 },
	}
	for _, case in ipairs(CASES) do
		local locale, path, store, field, start = case[1], case[2], case[3], case[4], case[5]
		Mock.reset()
		Mock.class = "MAGE"
		Mock.locale = locale
		Mock.knownSpells = setmetatable({}, { __index = function() return true end })
		local ok, err = pcall(function()
			local ns = load(scenario)
			if not ns then return end
			H.drive(scenario, ns)
			ns.Guard("probe", ns.ProbeCapabilities)
			ns.Prompt:ExitTest()
			ns.db.profile.filters.whenBuffed = "refresh"
			local UI = ns.WindowUI
			ns.OpenOptions(UI.PageOf(path))
			ns.Prompt:ExitTest()
			ns.db.profile[store][field] = start
			UI.Refresh()
			local row = UI.RowFor(path)
			if not (row and row.box) then
				fail(scenario, locale .. ": " .. path .. " has no slider box on its page")
				return
			end
			if row.Refresh then row:Refresh() end
			local shown = row.box:GetText()
			row.box:SetFocus()
			row.box:ClearFocus()
			local now = ns.db.profile[store][field]
			if now ~= start then
				fail(scenario, ("%s: %s at %s showed %q; clicking in and out made it %s"):format(
					locale, path, tostring(start), tostring(shown), tostring(now)))
			end
			noErrors(scenario, ns)
			ns.CloseOptions()
			ns.Prompt:ExitTest()
		end)
		Mock.reset()
		if not ok then fail(scenario, locale .. " threw: " .. tostring(err)) end
	end
end

-- Food still offered outside dungeons and raids has its own getter: without a
-- FIELDS entry no default is found for it, so it never carries a gold mark and
-- What I changed never lists it (who.ownHoldMoving got its entry in 1.11.38).
do
	local scenario = "options-fix: Food still offered outside dungeons and raids, changed, is marked and listed"
	Mock.reset()
	Mock.class = "MAGE"
	Mock.knownSpells = setmetatable({}, { __index = function() return true end })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		ns.db.profile.menuView = "full"
		local UI = ns.WindowUI
		local path = "who.ownFoodOutside"
		ns.OpenOptions(UI.PageOf(path))
		ns.Prompt:ExitTest()
		local own = ns.db.profile.ownBuffs
		if own.foodOutside ~= false or own.itemsInDungeons == true then
			fail(scenario, "SKIPPED -- the defaults are foodOutside " .. tostring(own.foodOutside)
				.. ", itemsInDungeons " .. tostring(own.itemsInDungeons))
			return
		end
		own.itemsInDungeons = true
		own.foodOutside = true
		UI.ShowPage(UI.PageOf(path))
		local at = UI.Where(path)
		if at and at.sec.fold then UI.State().open[at.sec.key] = true end
		ns.RefreshOptionsDisplay()
		if not UI.RowShown(path) then
			fail(scenario, "SKIPPED -- " .. path .. " is not drawn on " .. tostring(UI.PageOf(path)))
			return
		end
		local item = UI.Item(path)
		local row = UI.RowFor(path)
		local marked = row and row.mark and row.mark:IsShown() or false
		if not marked then
			fail(scenario, "Food still offered outside ticked (default off) carries no gold mark; DefaultOf answers "
				.. tostring(UI.DefaultOf(path, item)) .. ", IsChanged " .. tostring(UI.IsChanged(path, item)))
		end
		local listed = false
		for _, hit in ipairs(UI.ShowChanged()) do
			if (hit.ref.via or hit.ref.path) == path then listed = true end
		end
		if not listed then fail(scenario, "What I changed does not list Food still offered outside dungeons and raids") end
		UI.CloseResults()
		noErrors(scenario, ns)
		ns.CloseOptions()
		ns.Prompt:ExitTest()
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A class with no buff for anybody else (a Forever rogue, hunter or shaman):
-- ForOthersOnly hides every control on Who to buff but those under Myself.
-- The consumables button, its key, Which food and own items after everybody
-- else are all Myself settings and must show as their siblings do.
do
	local scenario = "options-fix: a class with nothing for others still sees the consumables button, its key, Which food and own items last"
	for _, class in ipairs({ "ROGUE", "HUNTER", "SHAMAN" }) do
		Mock.reset()
		Mock.setFlavour("camelot")
		Mock.class = class
		local undo = strangers({})
		local savedItem = rawget(_G, "C_Item")
		local ok, err = pcall(function()
			local ns = load(scenario)
			if not ns then return end
			freshPrompt(ns, scenario)
			-- Food in the bags, Well Fed ticked: Which food stands under it.
			local data = ns.FOODS and ns.FOODS.camelot
			local food = data and data[1] and data[1][1]
			if not food then
				fail(scenario, "SKIPPED -- no Forever food in ns.FOODS")
				return
			end
			rawset(_G, "C_Item", setmetatable({
				GetItemCount = function(id) return id == food and 3 or 0 end,
				GetItemNameByID = function(id) return "Food " .. id end,
				RequestLoadItemDataByID = function() end,
				GetItemIconByID = function(id) return 7100000 + id end,
				GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 5 end,
			}, { __index = savedItem or {} }))
			ns.db.profile.ownBuffs.pick.food = "auto"
			ns.ForgetScrolls()
			ns.addon:BAG_UPDATE_DELAYED()
			local function shown(name)
				local option = findOption(ns.optionsTable, name)
				if not option then return nil end
				local hidden = option.hidden
				if type(hidden) == "function" then hidden = hidden({}) end
				return not hidden
			end
			if ns.Page and ns.Page.HasClassBuffs and ns.Page.HasClassBuffs() then
				fail(scenario, "SKIPPED -- a " .. class .. " has a class buff for others here")
				return
			end
			if not shown("ownHoldMoving") then
				fail(scenario, "SKIPPED -- a " .. class .. " does not see Hold my food either (nothing for self?)")
				return
			end
			for _, name in ipairs({ "ownApart", "ownItemsLast", "ownFoodChoice" }) do
				local s = shown(name)
				if s == nil then
					fail(scenario, class .. ": no control " .. name)
				elseif not s then
					fail(scenario, class .. ": " .. name .. " is hidden, though its sibling ownHoldMoving shows")
				end
			end
			ns.db.profile.ownBuffs.apart = true
			if ns.Setup and ns.Setup.CanBind and ns.Setup.CanBind() and not shown("ownApartKey") then
				fail(scenario, class .. ": ownApartKey is hidden with the consumables button on")
			end
			noErrors(scenario, ns)
		end)
		undo()
		rawset(_G, "C_Item", savedItem)
		Mock.reset()
		if not ok then fail(scenario, class .. " threw: " .. tostring(err)) end
	end
end

-- A retail monk whose only cast is Resuscitate (res.lua's "res 15"), with no
-- food in the bags and asking off. Unticking Resurrect my group's dead must
-- not take Who to buff out of the sidebar: that page holds the switch that
-- turns it back on (and the cure switches), as a hunter's My pet stays with
-- its switch off (menupass-self.lua).
do
	local scenario = "options-fix: a class with only its resurrection keeps Who to buff with the res switch off"
	Mock.reset()
	Mock.setFlavour("mainline")
	Mock.class = "MONK"
	local undo = strangers({})
	local savedKnown, savedPlayer = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local known = { [115178] = true }
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		H.drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		if ns.caps.anyKnown or ns.caps.anyOwnKnown then
			fail(scenario, "SKIPPED -- the monk has something else to cast")
			return
		end
		if not (ns.Resurrect and ns.Resurrect.Has()) then
			fail(scenario, "SKIPPED -- the monk is not taken to know Resuscitate")
			return
		end
		if ns.AskLive and ns.AskLive() then
			fail(scenario, "SKIPPED -- asking is live for the monk")
			return
		end
		ns.OpenOptions()
		if not ns.WindowUI.visiblePages.who then
			fail(scenario, "SKIPPED -- Who to buff is not shown even with the res switch on")
			return
		end
		ns.CloseOptions()
		ns.db.profile.sources.res = false
		ns.RefreshOptionsDisplay()
		ns.OpenOptions()
		local UI = ns.WindowUI
		if not UI.visiblePages.who then
			fail(scenario, "with Resurrect my group's dead off Who to buff leaves the sidebar, and the switch with it")
		end
		local res = findOption(ns.optionsTable, "res")
		local hidden = res and res.hidden
		if type(hidden) == "function" then hidden = hidden({}) end
		if res and hidden then fail(scenario, "the res switch itself is hidden once unticked") end
		noErrors(scenario, ns)
		ns.CloseOptions()
		ns.Prompt:ExitTest()
	end)
	undo()
	rawset(_G, "IsSpellKnown", savedKnown)
	rawset(_G, "IsPlayerSpell", savedPlayer)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- My own buffs' Reset this page puts Which pet (who.ownPetChoice, drawn on
-- that page) back to The one I had out last, as every other setting there.
do
	local scenario = "options-fix: My own buffs' reset puts Which pet back to the one I had out last"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.drive(scenario, ns)
		local own = ns.db.profile.ownBuffs
		if own.petChoice ~= "last" then
			fail(scenario, "SKIPPED -- Which pet does not start on the last one: " .. tostring(own.petChoice))
			return
		end
		own.petChoice = "random"
		own.itemsLast = not own.itemsLast
		if ns.OptionsPage.ResetPage("self") ~= true then
			fail(scenario, "SKIPPED -- the reset did not run")
			return
		end
		own = ns.db.profile.ownBuffs
		if own.petChoice ~= "last" then
			fail(scenario, "after My own buffs' reset Which pet is still " .. tostring(own.petChoice))
		end
		noErrors(scenario, ns)
		ns.Prompt:ExitTest()
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What I changed (UI.ShowChanged) asks UI.Differs of each control shown. A
-- Forever rogue's tick under the food's Never remind me about
-- (who.own_leave_food) and under Elixirs to keep up (who.own_elixirkeep) are
-- changes of their own lists; the other Never remind me about (who.own_leave)
-- holds the non-food ticks only, so a food tick alone does not mark it.
do
	local scenario = "options-fix: What I changed names the food and elixir lists a tick is in, not the other list"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "ROGUE"
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.drive(scenario, ns)
		local UI = ns.WindowUI
		if not (UI and UI.Differs) then
			fail(scenario, "SKIPPED -- no UI.Differs")
			return
		end
		local food, keep
		for _, family in ipairs(ns.GetOwnFamilies() or {}) do
			if family.food then food = family end
			if family.keep then keep = family end
		end
		local meal = food and food.spells and food.spells[1]
		local elixir = keep and keep.spells and keep.spells[1]
		if not (meal and elixir) then
			fail(scenario, "SKIPPED -- no Forever food or elixir family to tick")
			return
		end
		local own = ns.db.profile.ownBuffs
		if UI.Differs("who.own_leave_food") or UI.Differs("who.own_elixirkeep") or UI.Differs("who.own_leave") then
			fail(scenario, "SKIPPED -- a list counts as changed on a new profile")
			return
		end
		own.leave[meal.key] = true
		if type(own.elixirKeep) ~= "table" then own.elixirKeep = {} end
		own.elixirKeep[elixir.key] = true
		if not UI.Differs("who.own_leave_food") then
			fail(scenario, "a food ticked under Never remind me about (" .. tostring(meal.key)
				.. ") does not count the food's list as changed")
		end
		if not UI.Differs("who.own_elixirkeep") then
			fail(scenario, "an elixir ticked under Elixirs to keep up (" .. tostring(elixir.key)
				.. ") does not count that list as changed")
		end
		if UI.Differs("who.own_leave") then
			fail(scenario, "a food tick alone counts the other Never remind me about, whose boxes show none, as changed")
		end
		noErrors(scenario, ns)
		ns.Prompt:ExitTest()
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
