-- Asking for a buff is on What I say, under the lines (every class can ask, a
-- rogue included), and Who to buff's fine print about other people's buffs
-- (a paladin's blessed, the Fish Bowl, a campsite) is one fold, Other people's
-- buffs, whose dot lights when one of its switches is changed.
--
-- Every scenario name starts with "menupass-say:".
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- opts.class (default PRIEST); every spell known unless opts.known is false.
local function with(scenario, opts, body)
	opts = opts or {}
	Mock.reset()
	Mock.class = opts.class or "PRIEST"
	if opts.known ~= false then
		Mock.knownSpells = setmetatable({}, { __index = function() return true end })
	end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		ns.CloseOptions()
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
	end)
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function sectionOf(ns, pageId, key)
	for _, sec in ipairs(ns.WindowLayout.pages[pageId].sections) do
		if sec.key == key then return sec end
	end
end

local function indexOf(ns, pageId, key)
	for i, sec in ipairs(ns.WindowLayout.pages[pageId].sections) do
		if sec.key == key then return i end
	end
end

-- ----------------------------------------------------------- the placement
do
	local scenario = "menupass-say: asking for a buff is on What I say, under the lines"
	with(scenario, nil, function(ns, UI)
		local asking = sectionOf(ns, "click", "click.asking")
		if not asking then
			fail(scenario, "What I say has no click.asking section")
			return
		end
		if asking.title ~= ns.L["Asking for a buff"] or asking.home ~= true then
			fail(scenario, "click.asking is not the titled home for asking")
		end
		local lines, at = indexOf(ns, "click", "click.lines"), indexOf(ns, "click", "click.asking")
		if not (lines and at and at > lines) then fail(scenario, "Asking for a buff is not under the lines") end
		if sectionOf(ns, "who", "who.asking") then fail(scenario, "Who to buff still has its own asking section") end
		for _, key in ipairs({ "ask", "askChannel", "askLine", "askOwn", "askInTowns" }) do
			local page, sec = H.placedOn(ns, "who." .. key)
			if page ~= "click" or not (sec and sec.key == "click.asking") then
				fail(scenario, "who." .. key .. " is on " .. tostring(page) .. ", not on What I say under Asking for a buff")
			end
		end
		local beyond = sectionOf(ns, "who", "who.beyond")
		if not (beyond and beyond.title == ns.L["Resurrection and cures"]) then
			fail(scenario, "who.beyond is not titled Resurrection and cures")
		end
		ns.OpenOptions("click")
		if not UI.RowShown("who.ask") then fail(scenario, "the asking switch is not drawn on What I say") end
	end)
end

-- --------------------------------------------------- reply and custom
do
	local scenario = "menupass-say: reply and custom find My own words and Your lines"
	with(scenario, nil, function(ns, UI)
		ns.OpenOptions("click")
		for _, query in ipairs({ "reply", "custom" }) do
			local found = ns.WindowSearch.Find(query, UI.SearchEntries(), 8)
			local want = { ["who.askOwn"] = false, ["click.phrases"] = false }
			for _, e in ipairs(found) do
				local ref = e.ref or {}
				if ref.via and want[ref.via] == false then
					want[ref.via] = true
					if ref.page ~= "click" then fail(scenario, ("%q finds %s on %s, not What I say"):format(query, ref.via, tostring(ref.page))) end
					if not ref.path then fail(scenario, ("%q finds %s with no switch to open"):format(query, ref.via)) end
				end
			end
			for path, ok in pairs(want) do
				if not ok then fail(scenario, ("%q does not find %s behind its switch"):format(query, path)) end
			end
		end
		for _, path in ipairs({ "who.askOwn", "click.phrases", "click.mixedLines" }) do
			if UI.OffShortList(path) then fail(scenario, path .. " is off the simple list") end
		end
	end)
end

-- ------------------------------------------------------- the fine print fold
do
	local scenario = "menupass-say: Who to buff's fine print is folded and its dot lights when changed"
	with(scenario, { class = "PALADIN" }, function(ns, UI)
		ns.OpenOptions("who")
		local fine
		for _, sec in ipairs(UI.Model("who").sections) do
			if sec.key == "who.castFine" then fine = sec end
		end
		if not fine then
			fail(scenario, "a paladin's Who to buff has no Other people's buffs fold")
			return
		end
		if not fine.fold then fail(scenario, "Other people's buffs is not a fold") end
		-- Nothing of it left among What to cast.
		local cast = sectionOf(ns, "who", "who.cast")
		for _, raw in ipairs(cast and cast.items or {}) do
			local path = type(raw) == "table" and raw[1] or raw
			if path == "who.leaveBlessed" or path == "who.spareFishBowl" or path == "who.neverFishBowl" or path == "who.spareCamp" then
				fail(scenario, path .. " is still among What to cast")
			end
		end
		if UI.FoldChanged(fine) then fail(scenario, "the fold's dot is lit on a profile nobody changed") end
		-- The Fish Bowl switch is drawn on Forever only (Boosted Stats); off it
		-- the fold's other switch stands in for it.
		local key, what = "spareFishBowl", "the Fish Bowl switch"
		if not (ns.Flavour and ns.Flavour.flavour == "camelot") then
			if not (ns.EXCLUSIVE_BUFFS and ns.EXCLUSIVE_BUFFS[ns.caps.class]) then
				fail(scenario, "SKIPPED -- no switch of the fine print is shown on this client")
				return
			end
			key, what = "leaveBlessed", "Skip players another paladin has blessed"
		end
		ns.db.profile.buff[key] = true
		ns.RefreshOptionsDisplay()
		if not UI.FoldChanged(fine) then fail(scenario, "the fold's dot stays dark with " .. what .. " on") end
		ns.db.profile.buff[key] = ns.defaults.profile.buff[key]
	end)
end

-- ------------------------------------------------------------ the bars
do
	local scenario = "menupass-say: Who to buff and What I say list their sub-divisions"
	local function check(ns, UI, id)
		ns.OpenOptions(id)
		local want = {}
		local m = UI.Model(id)
		for _, def in ipairs(ns.WindowLayout.pages[id].subpages or {}) do
			for _, key in ipairs(def) do
				for _, sec in ipairs(m.sections) do
					if sec.key == key and sec.visible then want[#want + 1] = def[1]; break end
				end
				if want[#want] == def[1] then break end
			end
		end
		if #want < 2 then
			fail(scenario, id .. " lists " .. #want .. " sub-divisions")
			return
		end
		local got = {}
		if UI.subbar.frame:IsShown() then
			for _, b in ipairs(UI.subbar.chips) do
				if b:IsShown() and b.key then got[#got + 1] = b.key end
			end
		end
		if table.concat(got, ",") ~= table.concat(want, ",") then
			fail(scenario, ("%s's bar shows %s, not %s"):format(id, table.concat(got, ","), table.concat(want, ",")))
		end
	end
	for _, class in ipairs({ "PRIEST", "PALADIN" }) do
		with(scenario, { class = class }, function(ns, UI)
			check(ns, UI, "who")
			check(ns, UI, "click")
			-- Asking for a buff is its own chip on What I say.
			local saw = false
			for _, def in ipairs(ns.WindowLayout.pages.click.subpages) do
				if def[1] == "click.asking" then saw = true end
			end
			if not saw then fail(scenario, "What I say has no Asking for a buff sub-division") end
			for _, def in ipairs(ns.WindowLayout.pages.who.subpages) do
				if def[1] == "who.asking" then fail(scenario, "Who to buff still lists who.asking") end
			end
		end)
	end
end

-- -------------------------------------------------------------- the reset
do
	local scenario = "menupass-say: What I say's reset puts asking back, even for a rogue"
	with(scenario, { class = "ROGUE", known = false }, function(ns)
		local db = ns.db.profile
		local d = ns.defaults.profile
		db.sources.ask = true
		db.ask.channel = db.ask.channel == "SAY" and "WHISPER" or "SAY"
		db.ask.line = "own"
		db.ask.own = "hello there {name}"
		db.ask.inTowns = not db.ask.inTowns
		local ok, answer = pcall(ns.OptionsPage.ResetPage, "click")
		if not ok or answer ~= true then
			fail(scenario, "the reset did not run: " .. tostring(answer))
			return
		end
		if db.sources.ask ~= d.sources.ask then fail(scenario, "asking is still on after the reset") end
		if db.ask.channel ~= d.ask.channel then fail(scenario, "ask.channel was not put back") end
		if db.ask.line ~= d.ask.line then fail(scenario, "ask.line was not put back") end
		if (db.ask.own or "") ~= (d.ask.own or "") then fail(scenario, "ask.own was not put back") end
		if db.ask.inTowns ~= d.ask.inTowns then fail(scenario, "ask.inTowns was not put back") end
	end)
end
