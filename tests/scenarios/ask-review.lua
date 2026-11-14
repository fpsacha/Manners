-- The review of asking (Ask.lua and its hooks in Prompt/Press.lua and
-- Commands.lua): what you wear is read afresh for a press, an ask the press's
-- own scan dropped is never said off the prompt's fuse, the arming refuses a
-- buff now worn, another class's buff of the same kind is no blessing, a paste
-- leaves how and where you ask alone while asking is on, and no cooldown holds
-- back a press that casts nothing. The session is ask.lua's.
--
-- Every scenario name starts with "ask-review:" so the mutations in
-- tests/mutations/ask-review.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton = H.strangers, H.freshPrompt, H.pressButton

local TOUCHED = { "IsResting", "UnitAffectingCombat", "IsInInstance", "UnitIsAFK", "UnitIsDND", "UnitLevel" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local QUIET = {
	IsResting = function() return false end,
	UnitAffectingCombat = function() return false end,
}

-- One scenario in a quiet world (out in the open, nobody fighting), with
-- `globals` over it; every global is put back whether it finished or threw.
local function with(scenario, globals, body)
	for name, value in pairs(QUIET) do rawset(_G, name, value) end
	for name, value in pairs(globals or {}) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The ask in the queue, or nil.
local function asking(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.ask then return entry end
	end
	return nil
end

local function anyAsked(ns)
	return next(ns.Ask.asked) ~= nil
end

-- A warrior who wears nothing, a priest (Anna Aim) on a nameplate, asking on.
local function ready(scenario, setup)
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.unitClass = "PRIEST"
	Mock.playerHeld = {}
	if setup then setup() end
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if not ns then
		restoreUnits()
		return nil
	end
	freshPrompt(ns, scenario)
	ns.db.profile.sources.ask = true
	return ns, restoreUnits
end

-- The prompt up on the ask for Fortitude, or nil with a SKIPPED line.
local function onAsk(scenario, ns)
	ns.Prompt:Refresh()
	local current = ns.Prompt.state.current
	if not (current and current.ask and ns.Prompt:GetButton():GetAttribute("macrotext1")) then
		fail(scenario, "SKIPPED -- the prompt is not armed with an ask to begin with")
		return nil
	end
	return current
end

-- ---------------------------------------------------------------------- 1
-- The priest gives it unasked; a press in the same second says nothing.
do
	local scenario = "ask-review: a buff that landed since the last scan is not asked for at the press"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		if onAsk(scenario, ns) then
			local buff = ns.FindBuff("PRIEST", "fortitude")
			-- It lands, and nothing tells Ask.lua: its reading is a moment old.
			Mock.playerHeld = { [buff.ranks[1]] = true }
			local ran = pressButton(ns)
			if ran then fail(scenario, "the press said |" .. tostring(ran) .. "| for a buff worn since a moment ago") end
			if anyAsked(ns) then fail(scenario, "an ask was filed for a buff already worn") end
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 2
-- Somebody the press's own scan dropped is not whispered off the fuse.
do
	local scenario = "ask-review: somebody the press's scan dropped is not whispered off the fuse"
	local away = false
	with(scenario, { UnitIsAFK = function(unit) return away and unit ~= "player" end }, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		if onAsk(scenario, ns) then
			away = true
			if asking(ns) then
				fail(scenario, "SKIPPED -- somebody away is still asked by the scan")
			else
				local ran = pressButton(ns)
				if ran then fail(scenario, "the press whispered somebody who had gone away: |" .. tostring(ran) .. "|") end
				if anyAsked(ns) then fail(scenario, "an ask was filed for somebody the scan had dropped") end
			end
		end
		away = false
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 3
-- The arming itself: an entry whose buff is now worn gets no line.
do
	local scenario = "ask-review: the arming refuses an ask for a buff now worn"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		local entry = onAsk(scenario, ns)
		if entry then
			local buff = ns.FindBuff("PRIEST", "fortitude")
			local button = ns.Prompt:GetButton()
			Mock.playerHeld = { [buff.ranks[1]] = true }
			ns.Ask.ForgetWorn()
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			local left = button:GetAttribute("macrotext1")
			if left ~= nil then fail(scenario, "armed |" .. tostring(left) .. "| for a buff now worn") end
			-- And unworn again, the same entry is armed again.
			Mock.playerHeld = {}
			ns.Ask.ForgetWorn()
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			if button:GetAttribute("macrotext1") == nil then
				fail(scenario, "not armed again once the buff is no longer worn")
			end
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 4
-- Mists: Mark of the Wild is the same kind as Kings, and no blessing. The
-- paladin beside you still has Might to give.
do
	local scenario = "ask-review: mists: under a druid's Mark the paladin is asked for Might"
	with(scenario, { UnitLevel = function() return 90 end }, function()
		Mock.reset()
		Mock.setFlavour("mists")
		Mock.class = "WARRIOR"
		Mock.unitClass = "PALADIN"
		Mock.playerHeld = {}
		local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then
			restoreUnits()
			return
		end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.ask = true
		local kings, might = ns.FindBuff("PALADIN", "kings"), ns.FindBuff("PALADIN", "might")
		if not (ns.EXCLUSIVE_BUFFS.PALADIN and kings and might and kings.alikeIds and kings.alikeIds[1126]) then
			fail(scenario, "SKIPPED -- blessings do not replace one another here, or Kings has no Mark for its like")
		elseif not asking(ns) then
			fail(scenario, "SKIPPED -- a warrior wearing nothing is not asking the paladin for anything")
		else
			-- Mark of the Wild on you: Kings would add nothing, Might would.
			Mock.playerHeld = { [1126] = true }
			ns.Ask.ForgetWorn()
			local entry = asking(ns)
			if not entry then
				fail(scenario, "wearing Mark of the Wild and no blessing, the paladin is not asked for Might")
			elseif entry.buff.wanted.key ~= "might" then
				fail(scenario, "under Mark of the Wild the paladin is asked for " .. tostring(entry.buff.wanted.key))
			end
			-- The monk's the same.
			Mock.playerHeld = { [117666] = true }
			ns.Ask.ForgetWorn()
			entry = asking(ns)
			if not (entry and entry.buff.wanted.key == "might") then
				fail(scenario, "under Legacy of the Emperor the paladin is asked for "
					.. tostring(entry and entry.buff.wanted.key))
			end
			-- A blessing of his own on you is all one paladin gives.
			Mock.playerHeld = { [kings.ranks[1]] = true }
			ns.Ask.ForgetWorn()
			if asking(ns) then fail(scenario, "a second blessing is asked for over Kings itself") end
			Mock.playerHeld = { [might.ranks[1]] = true, [1126] = true }
			ns.Ask.ForgetWorn()
			if asking(ns) then fail(scenario, "asked for a blessing with Might and a Mark both worn") end
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 5
-- A paste never changes how or where an ask already switched on is said.
do
	local scenario = "ask-review: a paste leaves how and where you ask alone while asking is on"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		local db = ns.db.profile
		local KEPT = ns.L["How you ask for a buff, and where, is kept as you had it, because you have asking switched on."]
		-- Somebody else's string: /say, in cities too, another line.
		db.sources.ask = false
		db.ask.channel, db.ask.inTowns, db.ask.line = "SAY", true, "mind"
		local theirs = ns.ExportSettings()
		db.ask.channel, db.ask.inTowns, db.ask.line = "WHISPER", false, "moment"
		local plain = ns.ExportSettings()

		-- Asking on, a whisper outside towns: all three stay, and it is said.
		db.sources.ask = true
		local ok, message = ns.ImportSettings(theirs)
		message = tostring(message)
		if not ok then
			fail(scenario, "SKIPPED -- the string was refused: " .. message)
		else
			if db.ask.channel ~= "WHISPER" then
				fail(scenario, "a pasted string turned the whisper into " .. tostring(db.ask.channel))
			end
			if db.ask.inTowns ~= false then fail(scenario, "a pasted string switched on asking in cities and inns") end
			if db.ask.line ~= "moment" then fail(scenario, "a pasted string changed the line to " .. tostring(db.ask.line)) end
			if db.sources.ask ~= true then fail(scenario, "the import switched asking off") end
			if not message:find(KEPT, 1, true) then
				fail(scenario, "the import kept how you ask without saying so: " .. message)
			end
		end

		-- A string that names none of them (one made before asking existed)
		-- does not put the player's choices back to the defaults either.
		db.ask.channel, db.ask.inTowns, db.ask.line = "SAY", true, "may"
		ok, message = ns.ImportSettings(plain)
		if ok then
			if db.ask.channel ~= "SAY" or db.ask.inTowns ~= true or db.ask.line ~= "may" then
				fail(scenario, ("a string naming none of them reset how you ask: %s, %s, %s")
					:format(tostring(db.ask.channel), tostring(db.ask.inTowns), tostring(db.ask.line)))
			end
		end
		-- The same as the player has: nothing was kept back, so nothing is said.
		db.ask.channel, db.ask.inTowns, db.ask.line = "WHISPER", false, "moment"
		ok, message = ns.ImportSettings(plain)
		if ok and tostring(message):find(KEPT, 1, true) then
			fail(scenario, "the import says it kept how you ask when the string held the same")
		end

		-- With asking off they travel, changing nothing anybody hears.
		db.sources.ask = false
		ok, message = ns.ImportSettings(theirs)
		if ok then
			if db.ask.channel ~= "SAY" or db.ask.inTowns ~= true or db.ask.line ~= "mind" then
				fail(scenario, "with asking off, how to ask did not travel with the string")
			end
			if tostring(message):find(KEPT, 1, true) then
				fail(scenario, "with asking off the import says it kept how you ask")
			end
			if db.sources.ask ~= false then fail(scenario, "the string switched asking on") end
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 6
-- A whisper needs no cooldown: the global one, or a cast of your own.
do
	local scenario = "ask-review: a press on an ask is not held back by the cooldown or a cast of your own"
	with(scenario, {}, function()
		for _, case in ipairs({ "the global cooldown", "a cast of your own" }) do
			local ns, restoreUnits = ready(scenario)
			if not ns then return end
			if onAsk(scenario, ns) then
				local want = ns.Prompt:GetButton():GetAttribute("macrotext1")
				if case == "the global cooldown" then
					Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5 } }
				else
					Mock.casting = { spellId = 8690, startsAt = GetTime(), endsAt = GetTime() + 10 }
				end
				if ns.CastReady() then
					fail(scenario, "SKIPPED -- " .. case .. " does not hold a cast back")
				else
					local ran = pressButton(ns)
					if ran ~= want then
						fail(scenario, ("in %s the press ran |%s|, not |%s|"):format(case, tostring(ran), tostring(want)))
					end
					if not anyAsked(ns) then fail(scenario, "in " .. case .. " the ask was not filed") end
				end
			end
			Mock.spellCooldowns, Mock.casting = nil, nil
			noErrors(scenario, ns)
			restoreUnits()
		end
	end)
end

-- ---------------------------------------------------------------------- 7
-- The same for the ask's name in the list. A mage who wears nothing: his own
-- buff is on the prompt and the ask under it; everybody else wears Intellect,
-- so nobody is offered one. `body` gets the addon and the ask's row button.
local function listed(scenario, body)
	with(scenario, {}, function()
		Mock.reset()
		Mock.class = "MAGE"
		Mock.unitClass = "PRIEST"
		Mock.playerHeld = {}
		Mock.held = { [1459] = true, [10157] = true }
		local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then
			restoreUnits()
			return
		end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		local db = ns.db.profile
		db.sources.ask = true
		db.prompt.showQueue, db.prompt.queueRows, db.prompt.clickRows = true, 3, true
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		local found
		for _, button in ipairs(ns.Prompt:Regions().rowButtons or {}) do
			local row = button.mannersRow
			if row and row.entry and row.entry.ask then found = button end
		end
		if not found then
			fail(scenario, "SKIPPED -- no name in the list is an ask")
		else
			body(ns, found)
		end
		Mock.spellCooldowns = nil
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- One left click on a row: PreClick, what the secure handler would run, PostClick.
local function clickRow(button)
	local pre, post = button.scripts.PreClick, button.scripts.PostClick
	if pre then pre(button, "LeftButton", true) end
	local ran = button:GetAttribute("macrotext1")
	if post then post(button, "LeftButton", true) end
	return ran
end

do
	local scenario = "ask-review: an ask's name in the list is said during the cooldown"
	listed(scenario, function(ns, button)
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5 } }
		if ns.CastReady() then fail(scenario, "SKIPPED -- the global cooldown is not running") end
		local ran = clickRow(button)
		if type(ran) ~= "string" or not ran:find("^/w Anna Aim ") then
			fail(scenario, "a click on the ask's name in the cooldown ran |" .. tostring(ran) .. "|")
		end
		if not anyAsked(ns) then fail(scenario, "the ask from the list was not filed") end
	end)
end

-- ---------------------------------------------------------------------- 8
-- And a click on that name reads what you wear afresh, as the prompt's does.
do
	local scenario = "ask-review: an ask's name in the list is not said for a buff that has just landed"
	listed(scenario, function(ns, button)
		local buff = ns.FindBuff("PRIEST", "fortitude")
		Mock.playerHeld = { [buff.ranks[1]] = true }
		local ran = clickRow(button)
		if ran then fail(scenario, "a click on the name said |" .. tostring(ran) .. "| for a buff worn since a moment ago") end
		if anyAsked(ns) then fail(scenario, "an ask was filed for a buff already worn") end
	end)
end
