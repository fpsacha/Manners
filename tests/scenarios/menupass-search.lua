-- The options window's search finds the words players use: a word at the start
-- of a word beats one inside it, US spellings find the UK words (and a Spanish
-- "color" stays found), filler words are dropped from a phrase, and what
-- players typed in their reports finds the setting they meant.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function labels(list)
	local out = {}
	for i, entry in ipairs(list) do out[i] = tostring(entry.label) end
	return table.concat(out, ", ")
end

local function search(scenario)
	Mock.reset()
	local ns = load(scenario)
	local Search = ns and ns.WindowSearch
	if ns and not Search then fail(scenario, "the toc loaded no ns.WindowSearch") end
	return Search
end

-- ------------------------------------------------------------------ 1
local scenario = "menupass-search: a word at the start beats one inside a word"
local Search = search(scenario)
if Search then
	local got = Search.Find("rest", { { label = "Firestone" }, { label = "Well-Rested" } })
	if not (got[1] and got[1].label == "Well-Rested") then
		fail(scenario, "Well-Rested did not come first: " .. labels(got))
	end
	if #got ~= 2 then fail(scenario, "the mid-word match was dropped: " .. labels(got)) end
end

-- ------------------------------------------------------------------ 2
scenario = "menupass-search: US spellings find the UK words, and a Spanish word is kept"
Search = search(scenario)
if Search then
	local got = Search.Find("color", { { label = "Colour marker" } })
	if #got ~= 1 then fail(scenario, "color did not find Colour marker") end
	got = Search.Find("gray", { { label = "Grey" } })
	if #got ~= 1 then fail(scenario, "gray did not find Grey") end
	got = Search.Find("color", { { label = "Color del marcador" } })
	if #got ~= 1 then fail(scenario, "color did not find the Spanish Color del marcador") end
	got = Search.Find("favor", { { label = "Por favor" } })
	if #got ~= 1 then fail(scenario, "favor did not find the Spanish Por favor") end
	got = Search.Find("favor", { { label = "Favour ledger" } })
	if #got ~= 1 then fail(scenario, "favor did not find Favour ledger") end
end

-- ------------------------------------------------------------------ 3
scenario = "menupass-search: filler words are dropped from a phrase"
Search = search(scenario)
if Search then
	local got = Search.Find("how do I turn off will of the forsaken",
		{ { label = "Offer Will of the Forsaken when I am feared" }, { label = "Skip players" } })
	if not (#got == 1 and got[1].label == "Offer Will of the Forsaken when I am feared") then
		fail(scenario, "the phrase found: " .. labels(got))
	end
	got = Search.Find("how do i turn it off", { { label = "Offer Will of the Forsaken" }, { label = "Skip players" } })
	if #got ~= 0 then fail(scenario, "\"it\" is not filler, yet the phrase found: " .. labels(got)) end
	got = Search.Find("the a my", { { label = "The a my list" }, { label = "Skip players" } })
	if #got ~= 1 then
		-- The whole query matches a label as typed; only a query that found nothing is cut down.
		fail(scenario, "the whole query, typed as it is, did not find its label")
	end
	got = Search.Find("the a my", { { label = "Skip players" } })
	if #got ~= 0 then fail(scenario, "a phrase of filler alone found: " .. labels(got)) end
end

-- ------------------------------------------------------------------ 4
scenario = "menupass-search: what players typed finds their setting"
do
	Mock.reset()
	Mock.class, Mock.playerRace = "PRIEST", "Scourge"
	Mock.knownSpells = setmetatable({}, { __index = function() return true end })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		ns.OpenOptions("who")
		local function top(query, wanted, n)
			local found = ns.WindowSearch.Find(query, UI.SearchEntries(), n or 8)
			for i = 1, math.min(3, #found) do
				local ref = found[i].ref or {}
				for _, path in ipairs(wanted) do
					if ref.via == path or ref.path == path or (path:sub(-1) == "*" and ((ref.via or ref.path or ""):sub(1, #path - 1) == path:sub(1, -2))) then return end
				end
			end
			local seen = {}
			for i, e in ipairs(found) do seen[i] = tostring((e.ref or {}).via or (e.ref or {}).path) end
			fail(scenario, ("%q: none of %s in the top 3 (found %s)"):format(query, table.concat(wanted, ", "), table.concat(seen, ", ")))
		end
		top("wotf", { "appearance.breakFree" })
		top("break free", { "appearance.breakFree" })
		top("rez", { "who.res" })
		top("delay", { "click.thankDelay" })
		top("queue", { "appearance.showQueue" })
		top("reply", { "click.phrases", "who.askOwn" })
		top("custom", { "click.phrases", "who.askOwn" })
		top("color", { "appearance.accent*" })
		top("blacklist", { "who.neverAdd" })
		top("turn off will of the forsaken", { "appearance.breakFree" })
		ns.CloseOptions()
		ns.Prompt:ExitTest()
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local function as(class, body, minimap)
		Mock.reset()
		local saved = rawget(_G, "C_Minimap")
		if minimap then _G.C_Minimap = minimap end
		Mock.class = class
		Mock.knownSpells = setmetatable({}, { __index = function() return true end })
		local ok, err = pcall(function()
			local ns = load(scenario)
			if not ns then return end
			drive(scenario, ns)
			ns.Guard("probe", ns.ProbeCapabilities)
			ns.Prompt:ExitTest()
			body(ns, ns.WindowUI)
			ns.CloseOptions()
			ns.Prompt:ExitTest()
		end)
		_G.C_Minimap = saved
		Mock.reset()
		if not ok then fail(scenario, class .. " threw: " .. tostring(err)) end
	end
	as("DRUID", function(ns, UI)
		if not ns.FindBuff("DRUID", "thorns") then
			fail(scenario, "SKIPPED -- no Thorns for others on this client")
			return
		end
		ns.OpenOptions("who")
		local tank = UI.Where("who.tank_thorns")
		if not tank then
			fail(scenario, "a druid has no who.tank_thorns")
			return
		end
		local found = ns.WindowSearch.Find("only me", UI.SearchEntries(), 8)
		for i = 1, math.min(3, #found) do
			local ref = found[i].ref or {}
			if ref.via == "who.tank_thorns" or ref.path == "who.tank_thorns" then return end
		end
		fail(scenario, "\"only me\" did not put who.tank_thorns in the top 3")
	end)
	-- A hunter who has Find Herbs: the minimap's tracking list says so.
	as("HUNTER", function(ns, UI)
		local family = false
		for _, fam in ipairs(ns.OWN_BUFFS.HUNTER or {}) do
			if fam.key == "tracking" then family = true end
		end
		if not family then
			fail(scenario, "SKIPPED -- no tracking family for a hunter on this client")
			return
		end
		ns.OpenOptions("who")
		local entries, has = UI.SearchEntries(), false
		for _, e in ipairs(entries) do
			if (e.ref or {}).path == "who.own_tracking" then has = true end
		end
		if not has then fail(scenario, "the hunter has no tracking entry to search for") return end
		local found = ns.WindowSearch.Find("tracking", UI.SearchEntries(), 8)
		for i = 1, math.min(3, #found) do
			local ref = found[i].ref or {}
			if ref.via == "who.own_tracking" or ref.path == "who.own_tracking" then return end
		end
		local seen = {}
		for i, e in ipairs(found) do seen[i] = tostring((e.ref or {}).via or (e.ref or {}).path) .. "/" .. tostring(e.label) end
		fail(scenario, "\"tracking\" did not put who.own_tracking in the top 3: " .. table.concat(seen, ", "))
	end, {
		GetNumTrackingTypes = function() return 1 end,
		GetTrackingInfo = function() return { spellID = 2383, active = false } end,
	})
end
