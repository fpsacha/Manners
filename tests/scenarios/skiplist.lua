-- Who to skip: paste a list of names (the never-offer list), and commas between
-- guilds (GitHub issue 30). The never-offer box took one name; a pasted
-- "Anna, Bert" went on as one entry. Now a second box takes names one a line or
-- with commas between, and the guild box reads commas too and keeps its text
-- tidy (one a line, no < >, no blanks or repeats).
--
-- Every scenario name starts with "skiplist:" so the mutations in
-- tests/mutations/skiplist.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local GUILDS = { nameplate1 = "Knights", party1 = "Raiders", target = "Knights" }

-- One session as a mage with a passer-by (Anna, of Knights), a party member
-- (Gwen, of Raiders) and a target (Tess, of Knights).
local function with(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local savedInfo, savedParty = rawget(_G, "GetGuildInfo"), rawget(_G, "UnitInParty")
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, party1 = { "Gwen", "Hale" },
		target = { "Tess", "Target" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "GetGuildInfo", function(unit) return GUILDS[unit] end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.group = true
		body(ns)
	end)
	restore()
	rawset(_G, "GetGuildInfo", savedInfo)
	rawset(_G, "UnitInParty", savedParty)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function named(first, last)
	return Mock.surnames and (first .. " " .. last) or first
end

local ANNA, GWEN, TESS = named("Anna", "Aim"), named("Gwen", "Hale"), named("Tess", "Target")

local function queue(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[entry.name] = entry end
	return out
end

local function listed(ns)
	local out = {}
	for _, name in ipairs(ns.NeverList()) do out[#out + 1] = name end
	table.sort(out)
	return out
end

local function same(got, ...)
	local want = { ... }
	table.sort(want)
	if #got ~= #want then return false end
	for i = 1, #got do
		if got[i] ~= want[i] then return false end
	end
	return true
end

local function show(list)
	return "{" .. table.concat(list, "; ") .. "}"
end

do
	local scenario = "skiplist: a pasted list puts every name on the never-offer list"
	with(scenario, function(ns)
		local box = H.findOption(ns.optionsTable, "neverPaste")
		if not box then fail(scenario, "no paste box") return end
		ns.ClearNeverList()
		box.set({ "who", "neverPaste" }, ANNA .. "\nBert, Cara\n\n  ,Dana  ")
		local got = listed(ns)
		if not same(got, ANNA, "Bert", "Cara", "Dana") then
			fail(scenario, "the list reads " .. show(got))
		end
	end)
end

do
	local scenario = "skiplist: duplicates and names already listed are passed over"
	with(scenario, function(ns)
		ns.ClearNeverList()
		ns.NeverOffer("Anna", true)
		local added, already = ns.NeverOfferList("anna\nBert\nbert")
		local got = listed(ns)
		if #got ~= 2 then fail(scenario, "the list reads " .. show(got)) end
		if added ~= 1 or already ~= 2 then
			fail(scenario, "it counted " .. tostring(added) .. " added, " .. tostring(already) .. " already")
		end
	end)
end

do
	local scenario = "skiplist: a list of only blanks adds nobody"
	with(scenario, function(ns)
		ns.ClearNeverList()
		local added, already = ns.NeverOfferList(" \n , ,\n")
		if #ns.NeverList() ~= 0 then fail(scenario, "somebody went on the list: " .. show(listed(ns))) end
		if added ~= 0 or already ~= 0 then
			fail(scenario, "it counted " .. tostring(added) .. ", " .. tostring(already))
		end
		local a2, b2 = ns.NeverOfferList(nil)
		if a2 ~= 0 or b2 ~= 0 then fail(scenario, "a paste that is not text counted something") end
	end)
end

do
	local scenario = "skiplist: a pasted name who buffed you is still offered the favour back"
	with(scenario, function(ns)
		ns.ClearNeverList()
		H.owe(ns, ANNA)
		ns.NeverOfferList(ANNA)
		if not ns.IsNeverOffered(ANNA) then fail(scenario, "she did not go on the list") end
		local anna = queue(ns)[ANNA]
		if not anna then fail(scenario, "a favour owed was dropped by the paste") end
		if not ns.owed[ANNA] then fail(scenario, "her debt was let go by the paste") end
	end)
end

do
	local scenario = "skiplist: the paste box sits under Never offer and is empty after"
	with(scenario, function(ns)
		local box = H.findOption(ns.optionsTable, "neverPaste")
		if not box then fail(scenario, "no paste box") return end
		if box.type ~= "input" or not box.multiline then fail(scenario, "the paste box is not a multi-line input") end
		if box.get({ "who", "neverPaste" }) ~= "" then fail(scenario, "the paste box shows something") end
		box.set({ "who", "neverPaste" }, "Bert")
		if box.get({ "who", "neverPaste" }) ~= "" then fail(scenario, "the paste box keeps what was put in it") end
		-- Its place: after the never-offer header, before the next header.
		local parent
		local function walk(node)
			if type(node) ~= "table" or type(node.args) ~= "table" then return end
			if node.args.neverPaste then parent = node return end
			for _, child in pairs(node.args) do
				walk(child)
				if parent then return end
			end
		end
		walk(ns.optionsTable)
		local head = parent and parent.args.neverHeader
		if not head then fail(scenario, "no Never offer header beside the paste box") return end
		if not (head.order < box.order) then fail(scenario, "the paste box is above the Never offer header") end
		for key, other in pairs(parent.args) do
			if other.type == "header" and other.order > head.order and other.order < box.order then
				fail(scenario, "the header " .. tostring(key) .. " sits between the box and Never offer")
			end
		end
		local found
		for _, page in pairs(ns.WindowLayout.pages or {}) do
			for _, section in ipairs(page.sections or {}) do
				if section.key == "skip.never" then
					for _, item in ipairs(section.items or {}) do
						if item == "who.neverPaste" then found = true end
					end
				end
			end
		end
		if not found then fail(scenario, "Layout's skip.never section does not hold who.neverPaste") end
	end)
end

do
	local scenario = "skiplist: guilds with commas between are each left out"
	with(scenario, function(ns)
		ns.db.profile.filters.skipGuilds = "Raiders, Knights"
		local list = queue(ns)
		if list[ANNA] then fail(scenario, "a passer-by of the second guild was offered") end
		if list[GWEN] then fail(scenario, "a member of the first guild was offered") end
		if not list[TESS] then fail(scenario, "the target was left out") end
	end)
end

do
	local scenario = "skiplist: the guild box keeps one guild a line, blanks and repeats dropped"
	with(scenario, function(ns)
		local box = H.findOption(ns.optionsTable, "skipGuilds")
		if not box then fail(scenario, "no guild box") return end
		box.set({ "who", "skipGuilds" }, "Knights, <Raiders>\n\nknights\n")
		local kept = ns.db.profile.filters.skipGuilds
		if kept ~= "Knights\nRaiders" then
			fail(scenario, "the box keeps '" .. tostring(kept):gsub("\n", "|") .. "'")
		end
	end)
end
