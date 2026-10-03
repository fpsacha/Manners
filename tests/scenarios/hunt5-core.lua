-- Core.lua fixes from the fifth bug hunt: a Camelot name and surname in a
-- script of two bytes a letter, a remembered favour stamped by a clock that was
-- later set back, the order /manners never prints the list in, and the cost of
-- putting one name on a long list while many favours are owed.
--
-- Every scenario name starts with "core:" so the mutations in
-- tests/mutations/hunt5-core.py can name the one that has to catch them.
-- Globals a scenario replaces are put back by `with`, whether it finished or
-- threw.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, inQueue = H.strangers, H.freshPrompt, H.inQueue

local TOUCHED = { "strcmputf8i" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local function with(scenario, globals, body)
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

-- A stand-in for the client's strcmputf8i that folds the Russian capitals
-- (U+0410..U+042F, two bytes each) onto their small letters and A-Z onto a-z,
-- then compares bytes, which puts the Russian alphabet in order apart from Ё.
local function foldCyrillic(s)
	s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
	s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end)
	return s:lower()
end
local function strcmpCyrillic(a, b)
	a, b = foldCyrillic(a), foldCyrillic(b)
	if a == b then return 0 end
	return a < b and -1 or 1
end

-- Failure lines go through a console that may not print UTF-8, so bytes past
-- ASCII are written as decimal escapes.
local function ascii(list)
	local out = {}
	for i = 1, #list do
		out[i] = (tostring(list[i]):gsub("[\128-\255]", function(c) return "\\" .. c:byte() end))
	end
	return table.concat(out, ", ")
end

local function same(list, want)
	if #list ~= #want then return false end
	for i = 1, #want do
		if list[i] ~= want[i] then return false end
	end
	return true
end

-- ------------------------------------------------------------------ core-1
-- A Camelot name and surname of twelve Russian letters each is a person.
--
-- The identity is the two halves joined by a space, 24 + 1 + 24 bytes, and the
-- macro-safety check capped names at 48 bytes, so everything such a player
-- did was dropped: never offered, their favour never filed. The cap now fits
-- two maximal names; anything that could break out of the macro is still out.
Mock.reset()
do
	local scenario = "core: a long Cyrillic name and surname is a person"
	local LONG = "Александрина Великомучени"
	local restoreUnits = strangers({
		nameplate1 = { "Александрина", "Великомучени" },
		-- 48 + 1 + 48 bytes: the largest name the cap lets through.
		nameplate2 = { string.rep("Ж", 24), string.rep("Ж", 24) },
		-- One byte over.
		nameplate3 = { string.rep("Ж", 24), string.rep("Ж", 24) .. "x" },
		nameplate4 = { "Ann;a", "Aim" },
		nameplate5 = { "Bert", "Bes[ide" },
	})
	with(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local full = ns.UnitFullName("nameplate1")
		if full ~= LONG then
			fail(scenario, "a 49-byte name and surname was not a name: " .. ascii({ tostring(full) }))
		elseif not inQueue(ns)[LONG] then
			fail(scenario, "a stranger with a long Cyrillic name and surname is not offered")
		end
		if ns.UnitFullName("nameplate2") == nil then
			fail(scenario, "a 97-byte name and surname, the longest there is, was not a name")
		end
		if ns.UnitFullName("nameplate3") ~= nil then
			fail(scenario, "a 98-byte name was let through")
		end
		if ns.UnitFullName("nameplate4") ~= nil or ns.UnitFullName("nameplate5") ~= nil then
			fail(scenario, "a name that could break out of the macro was let through")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core-2
-- A remembered favour stamped in the future is restored for no longer than the
-- window.
--
-- The clock was ahead when the file was written and set back before the next
-- login, so the favour's stamp is an hour from now. Counted from that stamp it
-- had an hour and two minutes left against a two-minute window, and its age
-- stayed negative so nothing that drops old favours ever reached it.
Mock.reset()
do
	local scenario = "core: a favour stamped by a clock set back lasts no longer than the window"
	local PETRA = "Petra Stonewell"
	with(scenario, nil, function()
		local first = load(scenario)
		if not first then return end
		drive(scenario, first)
		wipe(first.owed)
		first.db.profile.timing.reciprocateWindow = 120
		local wall = time()
		first.db.char.debts = { [PETRA] = { expires = wall + 3700, at = wall + 3580, class = "PRIEST" } }
		Mock.now = 5
		local ns = load(scenario)
		if not ns then return end
		if not pcall(function() ns.addon:OnInitialize() end) then
			fail(scenario, "SKIPPED -- the second session would not initialise")
			return
		end
		local debt = ns.owed[PETRA]
		if not debt then
			fail(scenario, "SKIPPED -- the favour was not restored at all")
			return
		end
		local left = ns.DebtExpiry(debt) - GetTime()
		if left > 120 then
			fail(scenario, ("a favour came back with %d seconds left of a 120-second window")
				:format(math.floor(left)))
		end
		if GetTime() - debt.at < 0 then
			fail(scenario, ("a favour came back %d seconds younger than now")
				:format(math.floor(debt.at - GetTime())))
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ core-3
-- /manners never lists names alphabetically in any script.
--
-- string.lower folds A-Z only, so a Russian name typed in small letters sorted
-- after every capitalised one. The client's strcmputf8i folds them all.
Mock.reset()
do
	local scenario = "core: the never-offer list is in alphabetical order (Russian)"
	Mock.locale = "ruRU"
	with(scenario, { strcmputf8i = strcmpCyrillic }, function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.ClearNeverList()
		for _, name in ipairs({ "Яна", "Борис", "анна" }) do ns.NeverOffer(name) end
		local list = ns.NeverList()
		if not same(list, { "анна", "Борис", "Яна" }) then
			fail(scenario, "the list reads " .. ascii(list))
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

-- The control: with no strcmputf8i the order is the ASCII one it always was.
do
	local scenario = "core: the never-offer list is in alphabetical order (no strcmputf8i)"
	with(scenario, nil, function()
		rawset(_G, "strcmputf8i", nil)
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.ClearNeverList()
		for _, name in ipairs({ "carl", "Bert", "anna", "Anna Aim" }) do ns.NeverOffer(name) end
		local list = ns.NeverList()
		if not same(list, { "anna", "Anna Aim", "Bert", "carl" }) then
			fail(scenario, "the list reads " .. ascii(list))
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ core-4
-- Putting one name on a long list while many favours are owed compares each
-- favour with that one name, not with the whole list.
--
-- The listed names hold an accented letter (its two bytes written out): two
-- names in A to Z are compared by string.lower alone, without the client's
-- compare, so only names in another script are counted here.
Mock.reset()
do
	local scenario = "core: one name put on a long list costs one compare per favour"
	local calls = 0
	local function counted(a, b)
		calls = calls + 1
		a, b = a:lower(), b:lower()
		if a == b then return 0 end
		return a < b and -1 or 1
	end
	with(scenario, { strcmputf8i = counted }, function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		wipe(ns.owed)
		ns.ClearNeverList()
		local never = ns.db.profile.never
		for i = 1, 500 do never["L\195\173sted" .. i .. " Name"] = true end
		for i = 1, 300 do
			ns.owed["Owed" .. i .. " Name"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		end
		ns.owed["Petra Stonewell"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		ns.owed["Anna Aim-Realm"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		calls = 0
		ns.PutOnNeverList("S\195\179mebody Else")
		if calls == 0 then
			fail(scenario, "SKIPPED -- listing a name in another script asked no compare at all")
		end
		if calls >= 2000 then
			fail(scenario, ("one name put on the list took %d compares"):format(calls))
		end
		if not ns.owed["Owed1 Name"] then
			fail(scenario, "listing somebody else let an unrelated favour go")
		end
		ns.PutOnNeverList("petra stonewell")
		if ns.owed["Petra Stonewell"] then
			fail(scenario, "listing an owed person in small letters kept their favour")
		end
		ns.PutOnNeverList("Anna Aim")
		if ns.owed["Anna Aim-Realm"] then
			fail(scenario, "listing an owed person by the name without the realm kept their favour")
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()
