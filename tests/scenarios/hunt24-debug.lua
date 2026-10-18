-- /manners debug and the Diagnostics tab on yourself while your own name is on
-- the never-offer list. Since 1.7.8 the prompt offers you nothing then
-- (SelfEntry) and SelfBuffFirst stops naming your group buff, but ns.MyselfHeldBack
-- had no such reason, so the line per family of your class's own buffs
-- (Commands.lua, ns.MyselfLines) still read "none up -- Frost Armor is the one
-- to cast" for a spell the prompt would never put up. MyselfHeldBack now says
-- "listed", and the lines say you are on the list instead.
--
-- Every name starts with "hunt24-debug:" and then the case's own words, so a
-- mutation can name exactly one; a control that fails reads "SKIPPED --".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

-- Globals a scenario replaces, put back after it whether it finished or threw.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell" }

-- A mage who knows Arcane Intellect and her armors (the ids tests/scenarios/ownbuffs.lua
-- has): /manners debug speaks of "the one to cast" for each family she has, and
-- of "your own X comes first" for the group buff, with the family behind it.
local KNOWN = {}
for _, id in ipairs({ 1459, 1460, 1461, 10156, 10157, 23028, 168, 7300, 7301, 7302, 6117 }) do
	KNOWN[id] = true
end

local function run(scenario, flavour, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		local is = function(id) return KNOWN[id] == true end
		rawset(_G, "IsSpellKnown", is)
		rawset(_G, "IsPlayerSpell", is)
		restore = strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
end

local function lines(ns)
	return ns.MyselfLines(GetTime())
end

local function joined(ns)
	return table.concat(lines(ns), " / ")
end

-- The lines that name a spell to cast, or put one ahead of the rest.
local function naming(ns)
	local out = {}
	for _, line in ipairs(lines(ns)) do
		if line:find("is the one to", 1, true) or line:find("comes first", 1, true) then
			out[#out + 1] = line
		end
	end
	return out
end

-- The lines that say you are on your own never-offer list.
local function saying(ns)
	local out = {}
	for _, line in ipairs(lines(ns)) do
		if line:find("never-offer list", 1, true) then out[#out + 1] = line end
	end
	return out
end

-- What the Diagnostics tab prints for yourself, or nil without that block.
local function diagnostics(ns)
	local node = findOption(ns.optionsTable, "ownDiag")
	if not node or type(node.name) ~= "function" then return nil end
	if type(node.hidden) == "function" and node.hidden() then return "" end
	return node.name()
end

-- ------------------------------------------------------ yourself, never-offered
-- With your own name listed the prompt offers you nothing, so no line may
-- name a buff to cast, and one says why. Somebody else listed changes nothing;
-- taken off the list the lines are what they were.
for _, flavour in ipairs({ "camelot", "vanilla" }) do
	local scenario = "hunt24-debug: " .. flavour .. ": your own name on the never-offer list is what /manners debug says"
	run(scenario, flavour, function(ns)
		local db = ns.db.profile
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(60)
		local me = ns.UnitFullName("player")
		local before = joined(ns)
		local mine = entryFor(ns, me)
		if not (mine and mine.reason == "self") then
			fail(scenario, "SKIPPED -- you were not offered your own buff to begin with")
			return
		end
		if #naming(ns) == 0 then
			fail(scenario, "SKIPPED -- /manners debug named no buff to cast before the listing: " .. before)
			return
		end
		if #saying(ns) > 0 then
			fail(scenario, "SKIPPED -- /manners debug already said you were on the list: " .. before)
			return
		end

		-- Somebody else on the list: the lines are as before.
		db.never["Somebody Else"] = true
		if joined(ns) ~= before then
			fail(scenario, "somebody else on the never-offer list changed what /manners debug says about you: "
				.. joined(ns))
		end
		db.never["Somebody Else"] = nil

		-- You on it.
		db.never[me] = true
		Mock.advance(20)
		if entryFor(ns, me) then
			fail(scenario, "SKIPPED -- your own name on the never-offer list did not stop the offer")
			db.never[me] = nil
			return
		end
		local named = naming(ns)
		if #named > 0 then
			fail(scenario, "your own name is on the never-offer list and the prompt offers you nothing, yet"
				.. " /manners debug says: " .. table.concat(named, " / "))
		end
		local said = saying(ns)
		if #said ~= 1 then
			fail(scenario, "with your own name on the never-offer list /manners debug says so in " .. #said
				.. " line(s) rather than one: " .. joined(ns))
		elseif not said[1]:find("held back", 1, true) then
			fail(scenario, "the line about your own name on the never-offer list does not say your buffs are"
				.. " held back: " .. said[1])
		end
		if ns.MyselfHeldBack(db, GetTime()) ~= "listed" then
			fail(scenario, "MyselfHeldBack does not hold you back for your own name on the never-offer list: "
				.. tostring(ns.MyselfHeldBack(db, GetTime())))
		end
		-- The Diagnostics tab reads the same lines.
		local page = diagnostics(ns)
		if page and not page:find("never-offer list", 1, true) then
			fail(scenario, "the Diagnostics tab does not say you are on the never-offer list: " .. tostring(page))
		end
		-- Listed in small letters, which is the same person to the list.
		db.never[me] = nil
		db.never[me:lower()] = true
		if #saying(ns) ~= 1 or #naming(ns) > 0 then
			fail(scenario, "your own name in small letters on the never-offer list is not the same person to"
				.. " /manners debug: " .. joined(ns))
		end
		db.never[me:lower()] = nil

		-- Taken off the list: as before, and the prompt offers you again.
		if joined(ns) ~= before then
			fail(scenario, "taken off the never-offer list, /manners debug does not say what it said before: "
				.. joined(ns))
		end
		Mock.advance(20)
		if not entryFor(ns, me) then
			fail(scenario, "taken off the never-offer list, you were not offered your own buff again")
		end
		local back = diagnostics(ns)
		if back and back:find("never-offer list", 1, true) then
			fail(scenario, "taken off the never-offer list, the Diagnostics tab still says you are on it: " .. back)
		end
	end)
end
