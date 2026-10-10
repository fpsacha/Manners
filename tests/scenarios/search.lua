-- The options window's search (Options/Window/Search.lua).
--
-- What the box compares is a label as the player reads it: colour codes,
-- textures and atlases are drawn rather than read, so they must not stop a
-- match, and case must not either -- in German, French and Spanish too, whose
-- capitals string.lower does not fold. Then the order: a label match first,
-- then a choice in a dropdown, then a tooltip, then the section or page, and
-- never more than the box has room for.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load = H.fail, H.load

-- What the toc's Options/Window/*.lua put in the namespace; nil, and the
-- scenario fails, when the toc no longer loads the file.
local function need(ns, file, field)
	return ns[field]
end

local function show(s)
	return (tostring(s):gsub("[\128-\255]", function(c) return ("\\%d"):format(c:byte()) end))
end

local function labels(list)
	local out = {}
	for i, entry in ipairs(list) do out[i] = tostring(entry.label) end
	return table.concat(out, ", ")
end

-- ------------------------------------------------------------------ 1
Mock.reset()
local scenario = "search reads a label as it is drawn, in any case"
local ns = load(scenario)
local Search = ns and need(ns, "Options/Window/Search.lua", "WindowSearch")
if ns and not Search then
	fail(scenario, "the toc loaded no ns.WindowSearch (Options/Window/Search.lua)")
elseif Search then
	for _, case in ipairs({
		{ "|cffffd100Lock|r it", "lock it", "a colour code" },
		{ "|cFF80C0FFBlue|r", "blue", "a colour code in capitals" },
		{ "|cnNORMAL_FONT_COLOR:Named|r colour", "named colour", "a named colour" },
		{ "|TInterface\\Icons\\Spell_Holy_WordFortitude:16|t Fortitude", "fortitude", "a texture" },
		{ "|A:common-icon-checkmark:16:16|a Ready", "ready", "an atlas" },
		{ "Line one\nline two", "line one line two", "a line break" },
		{ "First|nSecond", "first second", "a |n line break" },
		{ "  Spaced   out  ", "spaced out", "spare spaces" },
		{ "SKIP PLAYERS", "skip players", "ASCII capitals" },
		-- German
		{ "\195\132\195\150\195\156", "\195\164\195\182\195\188", "Ä Ö Ü" },
		{ "WEN \195\156BERSPRINGEN", "wen \195\188berspringen", "a German capital inside a word" },
		{ "Stra\195\159e", "stra\195\159e", "ß, which has no capital to fold" },
		-- French
		{ "\195\137\195\136", "\195\169\195\168", "É È" },
		{ "\197\146UVRE", "\197\147uvre", "Œ" },
		{ "\197\184", "\195\191", "Ÿ" },
		{ "\195\128 \195\135A", "\195\160 \195\167a", "À and Ç" },
		-- Spanish
		{ "A\195\145O", "a\195\177o", "Ñ" },
		-- Russian, which only a ruRU client's spell names bring
		{ "\208\144\208\145\208\146 \208\159\208\160\208\161 \208\175", "\208\176\208\177\208\178 \208\191\209\128\209\129 \209\143", "А Б В, П Р С, Я" },
		{ "\208\129\208\150", "\209\145\208\182", "Ё" },
		{ "\209\145\208\182 \208\176", "\209\145\208\182 \208\176", "small Russian letters, already folded" },
		-- Left alone
		{ "2 \195\151 3", "2 \195\151 3", "the multiplication sign, which is no letter" },
		{ "d\195\169j\195\160 vu", "d\195\169j\195\160 vu", "small letters, already folded" },
		{ "\237\149\156\234\181\173\236\150\180", "\237\149\156\234\181\173\236\150\180", "Korean, which has no case" },
	}) do
		local got = Search.Normalise(case[1])
		if got ~= case[2] then
			fail(scenario, ("%s: %s came back as %s, not %s"):format(show(case[3]), show(case[1]), show(got), show(case[2])))
		end
	end
	for _, value in ipairs({ 12, true, {} }) do
		if Search.Normalise(value) ~= "" then
			fail(scenario, "a " .. type(value) .. " is not text, and came back as " .. show(Search.Normalise(value)))
		end
	end
	if Search.Normalise(nil) ~= "" then fail(scenario, "nothing came back as something") end
	-- What the folding is for: a query in capitals finds a label in small letters.
	local hit = Search.Find("\195\156BERSPRINGEN", { { label = "Wen \195\188berspringen" } })
	if #hit ~= 1 then fail(scenario, "a German query in capitals did not find its label") end
	-- A ruRU spell name, "Чародейский интеллект", found by it in small letters.
	local arcane = "\208\167\208\176\209\128\208\190\208\180\208\181\208\185\209\129\208\186\208\184\208\185 \208\184\208\189\209\130\208\181\208\187\208\187\208\181\208\186\209\130"
	hit = Search.Find("\209\135\208\176\209\128\208\190\208\180\208\181\208\185\209\129\208\186\208\184\208\185", { { label = "Buff to offer", choices = { arcane } } })
	if #hit ~= 1 then fail(scenario, "a Russian spell name in small letters did not find its capitalised choice") end
	hit = Search.Find("|cffffd100whisper|r", { { label = "Where to say it", choices = { "Whisper them" } } })
	if #hit ~= 1 then fail(scenario, "a query is not read the way a label is: a colour code in it stopped the match") end
end

-- ------------------------------------------------------------------ 2
Mock.reset()
scenario = "search puts labels first, then choices, tooltips and places, at most eight"
ns = load(scenario)
Search = ns and need(ns, "Options/Window/Search.lua", "WindowSearch")
if ns and not Search then
	fail(scenario, "the toc loaded no ns.WindowSearch (Options/Window/Search.lua)")
elseif Search then
	-- Given worst first, so the order out is the ranking's and not the input's.
	local entries = {
		{ label = "Nothing here", desc = "nothing", section = "Elsewhere", page = "Look" },
		{ label = "On the page", page = "Sound and fury" },
		{ label = "In the section", section = "Sound" },
		{ label = "Play it", desc = "Plays a |cffffd100sound|r when someone buffs you." },
		{ label = "Channel", choices = { "Say", "Sound off" } },
		{ label = "Play a sound" },
		{ label = "SOUND", desc = "sound", choices = { "sound" }, section = "Sound" },
	}
	local want = { "Play a sound", "SOUND", "Channel", "Play it", "On the page", "In the section" }
	local got = Search.Find("Sound", entries)
	if labels(got) ~= table.concat(want, ", ") then
		fail(scenario, "the order was " .. labels(got) .. "; it should be " .. table.concat(want, ", "))
	end
	for i, entry in ipairs(got) do
		if entry ~= entries[({ 6, 7, 5, 4, 2, 3 })[i]] then
			fail(scenario, "result " .. i .. " is not the entry it was given as, so its ref is lost")
			break
		end
	end

	local many = {}
	for i = 1, 12 do many[i] = { label = "Skip " .. i, ref = i } end
	got = Search.Find("skip", many)
	if #got ~= 8 then
		fail(scenario, "with no limit given, " .. #got .. " results came back, not 8")
	elseif got[1].ref ~= 1 or got[8].ref ~= 8 then
		fail(scenario, "equal matches came back out of the order they were given: " .. labels(got))
	end
	if #Search.Find("skip", many, 3) ~= 3 then fail(scenario, "a limit of 3 gave " .. #Search.Find("skip", many, 3)) end
	if #Search.Find("skip", many, 20) ~= 12 then fail(scenario, "a limit past the matches did not give them all") end

	for _, query in ipairs({ "", "   ", "|cffffd100|r", false }) do
		if query == false then query = nil end
		if #Search.Find(query, many) ~= 0 then
			fail(scenario, "an empty query (" .. show(query) .. ") found " .. #Search.Find(query, many) .. " things")
		end
	end
	if #Search.Find("zebra", many) ~= 0 then fail(scenario, "a query nothing holds found something") end
	if #Search.Find("skip", nil) ~= 0 then fail(scenario, "no entries at all still found something") end
end

-- ------------------------------------------------------------------ 3
-- The fold on the addon's own words: the German client's page names, typed in
-- capitals, find the pages.
Mock.reset()
Mock.locale = "deDE"
scenario = "search finds a German page typed in capitals"
ns = load(scenario)
Search = ns and need(ns, "Options/Window/Search.lua", "WindowSearch")
local layout = ns and need(ns, "Options/Window/Layout.lua", "WindowLayout")
if ns and not (Search and layout) then
	fail(scenario, "the toc loaded no ns.WindowSearch or ns.WindowLayout")
elseif Search then
	local entries = {}
	for _, group in ipairs(layout.groups) do
		for _, pageId in ipairs(group) do
			entries[#entries + 1] = { label = layout.pages[pageId].title, ref = pageId }
		end
	end
	if layout.pages.skip.title == "Who to skip" then
		fail(scenario, "SKIPPED -- the page names came back in English on a German client")
	else
		for query, pageId in pairs({ ["WEN \195\156BERSPRINGEN"] = "skip", ["ST\195\132RKEN"] = "who" }) do
			local got = Search.Find(query, entries)
			if not (got[1] and got[1].ref == pageId) then
				fail(scenario, show(query) .. " did not find " .. pageId .. " (" .. show(layout.pages[pageId].title)
					.. "); found " .. show(labels(got)))
			end
		end
	end
end
Mock.reset()
