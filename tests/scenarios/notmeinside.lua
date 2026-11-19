-- Thorns, not on me in a dungeon or a raid (1.11.30). A druid who heals asked
-- how to stop being offered Thorns on herself inside a dungeon: Only me kept
-- reminding her, and Tanks only left her alone only while she was no tank. A
-- switch under Offer to (buff.notMeInside; Who to buff, "who.notMeInside_<key>")
-- holds a buff of the tankChoice kind off yourself while you are in a dungeon
-- or a raid, whatever Offer to says. Out in the world, and in a battleground or
-- an arena, you are reminded as ever; the rest of the group is offered as Offer
-- to says.
--
-- Every scenario name starts with "notmeinside:" so the mutations in
-- tests/mutations/notmeinside.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
}
local STRANGER = { "Anna", "Aim" }

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "UnitInRaid", "C_Spell", "IsInInstance" }

local function filed(pair)
	return Mock.surnames and (pair[1] .. " " .. pair[2]) or pair[1]
end

-- One session as a druid knowing Mark of the Wild and Thorns, everybody
-- wearing Mark of the Wild (so Thorns is what is missing), `opts.setup(ns)`
-- run on the profile, then body(ns). The party tokens are in the group, the
-- nameplate is a stranger.
local function session(scenario, opts, body)
	Mock.reset()
	Mock.class = "DRUID"
	Mock.groupSize = 4
	local names = { nameplate1 = STRANGER }
	for token, pair in pairs(PARTY) do names[token] = pair end
	local restore = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		-- Mists and retail have no Thorns to hold to anybody.
		if not (ns.FindBuff("DRUID", "motw") and ns.FindBuff("DRUID", "thorns")) then return end
		local known = {}
		for _, key in ipairs({ "motw", "thorns" }) do
			for _, id in ipairs(ns.FindBuff("DRUID", key).ranks) do known[id] = true end
		end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.strangers = true
		db.sources.group = true
		db.sources.asked = true
		db.sources.self = false
		-- Mark of the Wild on everybody, so Thorns is what the walk comes to.
		Mock.held = {}
		for _, id in ipairs(ns.FindBuff("DRUID", "motw").ranks) do Mock.held[id] = true end
		if opts.setup then opts.setup(ns) end
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What the queue offers each name, by buff key; absent for nobody.
local function offers(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		out[entry.name] = entry.buff and entry.buff.key
	end
	return out
end

local function selfEntry(ns)
	Mock.advance(4)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- Your own Thorns, as the queue says it now: the key of the self entry, or nil.
local function mineWith(ns, role)
	ns.db.profile.sources.self = true
	Mock.playerHeld = {}
	for _, id in ipairs(ns.FindBuff("DRUID", "motw").ranks) do Mock.playerHeld[id] = true end
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
	Mock.roles = { party2 = "TANK", player = role }
	local mine = selfEntry(ns)
	return mine and mine.buff and mine.buff.key
end

-- Where the game says you are: `inside`, and the kind of instance.
local function placeAt(inside, kind)
	rawset(_G, "IsInInstance", function() return inside, kind end)
end

local function setMeOnly(ns) ns.db.profile.buff.meOnly = { thorns = true } end
local function setNotInside(ns) ns.db.profile.buff.notMeInside = { thorns = true } end
local function setBoth(ns)
	setMeOnly(ns)
	setNotInside(ns)
end
local function setTanksMeInside(ns)
	ns.db.profile.buff.tanksOnly = { thorns = true }
	ns.db.profile.buff.tanksMe = { thorns = true }
	setNotInside(ns)
end

do
	local scenario = "notmeinside: Only me and the switch keep Thorns off a healer inside a dungeon, not outside"
	session(scenario, { setup = setBoth }, function(ns)
		placeAt(true, "party")
		local key = mineWith(ns, "HEALER")
		if key == "thorns" then fail(scenario, "a healer inside a party instance was reminded of Thorns on herself") end
		placeAt(false, "none")
		key = mineWith(ns, "HEALER")
		if key ~= "thorns" then
			fail(scenario, "out in the world she was reminded of " .. tostring(key) .. ", not Thorns")
		end
	end)
end

do
	local scenario = "notmeinside: nothing chosen is the way it was, Only me reminds inside a dungeon"
	session(scenario, { setup = setMeOnly }, function(ns)
		placeAt(true, "party")
		local key = mineWith(ns, "HEALER")
		if key ~= "thorns" then fail(scenario, "inside a party instance with the switch off she was reminded of " .. tostring(key)) end
		if next(ns.defaults.profile.buff.notMeInside) ~= nil then
			fail(scenario, "the switch is on by default")
		end
	end)
end

do
	local scenario = "notmeinside: Tanks and me inside a dungeon offers the tank Thorns and not you"
	session(scenario, { setup = setTanksMeInside }, function(ns)
		placeAt(true, "party")
		local key = mineWith(ns, "HEALER")
		if key == "thorns" then fail(scenario, "a healer was reminded of Thorns on herself inside a party instance") end
		local out = offers(ns)
		if out[filed(PARTY.party2)] ~= "thorns" then
			fail(scenario, "the tank was offered " .. tostring(out[filed(PARTY.party2)]) .. ", not Thorns")
		end
		for _, token in ipairs({ "party1", "party3" }) do
			if out[filed(PARTY[token])] then
				fail(scenario, token .. ", who is no tank, was offered " .. tostring(out[filed(PARTY[token])]))
			end
		end
	end)
end

do
	local scenario = "notmeinside: a raid holds it too, a battleground does not"
	session(scenario, { setup = setBoth }, function(ns)
		placeAt(true, "raid")
		local key = mineWith(ns, "HEALER")
		if key == "thorns" then fail(scenario, "reminded of Thorns on herself inside a raid") end
		placeAt(true, "pvp")
		key = mineWith(ns, "HEALER")
		if key ~= "thorns" then
			fail(scenario, "in a battleground she was reminded of " .. tostring(key) .. ", not Thorns")
		end
	end)
end

do
	local scenario = "notmeinside: the switch is in Who to buff and sets only its own set"
	session(scenario, {}, function(ns)
		local control = H.findOption(ns.optionsTable, "notMeInside_thorns")
		if not control then
			fail(scenario, "Who to buff has no Not on me in a dungeon or raid switch for Thorns")
			return
		end
		local B = ns.db.profile.buff
		B.tanksOnly = { thorns = true }
		B.meOnly = { thorns = true }
		local info = { "who", "notMeInside_thorns" }
		control.set(info, true)
		if control.get(info) ~= true or B.notMeInside.thorns ~= true then
			fail(scenario, "ticking it left " .. tostring(B.notMeInside.thorns))
		end
		if B.tanksOnly.thorns ~= true or B.meOnly.thorns ~= true then
			fail(scenario, "ticking it changed Offer to")
		end
		control.set(info, false)
		if control.get(info) ~= false or B.notMeInside.thorns ~= nil then
			fail(scenario, "unticking it left " .. tostring(B.notMeInside.thorns))
		end
		if B.tanksOnly.thorns ~= true or B.meOnly.thorns ~= true then
			fail(scenario, "unticking it changed Offer to")
		end
	end)
end

do
	local scenario = "notmeinside: the options window places it right under Offer to"
	session(scenario, {}, function(ns)
		local layout = ns.WindowLayout
		local page = layout and layout.pages and layout.pages.who
		if not page then
			fail(scenario, "no who page in the layout")
			return
		end
		for _, section in ipairs(page.sections or {}) do
			local items = section.items or {}
			for i, item in ipairs(items) do
				if type(item) == "table" and item[1] == "who.tank_thorns" then
					local nxt = items[i + 1]
					if not (type(nxt) == "table" and nxt[1] == "who.notMeInside_thorns" and nxt.indent == true) then
						fail(scenario, "the item after Offer to is not the indented switch")
					end
				end
			end
		end
		-- Offer to itself missing from the page is tankonly.lua's to say.
	end)
end

do
	local scenario = "notmeinside: the set is repaired and travels with a profile"
	session(scenario, {}, function(ns)
		ns.db.profile.buff.notMeInside = "yes"
		ns.ClampSettings()
		if type(ns.db.profile.buff.notMeInside) ~= "table" then
			fail(scenario, "a damaged set was left as " .. tostring(ns.db.profile.buff.notMeInside))
		end
		setNotInside(ns)
		local text = ns.ExportSettings and ns.ExportSettings() or nil
		if text and not text:find("buff.notMeInside=thorns", 1, true) then
			fail(scenario, "the export does not carry the choice: " .. tostring(text))
		end
	end)
end
