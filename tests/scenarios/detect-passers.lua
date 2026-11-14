-- Detect Invisibility for passers-by too, asked for by a player. A warlock's
-- Detect Invisibility for others (Buffs.lua, detectgroup) is off until ticked
-- and held to the members of the party or raid by Manners' choice
-- (membersOnly). One switch under it on Who to buff (who.passers_detectgroup,
-- db.buff.detectPassers), off by default, shown only once the buff itself is
-- ticked and only where the class and the client have the buff, sends it to
-- passers-by as well, and to a passer-by who asks for it. With the switch off
-- nothing changes: tests/scenarios/detectgroup.lua holds that.
--
-- Every scenario name starts with "detect-passers:" so the mutations in
-- tests/mutations/detect-passers.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local RANKS = { 11743, 2970, 132 }

local PARTY = { party1 = { "Gwen", "Hale" }, party2 = { "Bram", "Oake" } }
local STRANGER = { "Anna", "Aim" }

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "UnitInRaid" }

local function filed(pair)
	return Mock.surnames and (pair[1] .. " " .. pair[2]) or pair[1]
end

-- One session as opts.class (a warlock) on opts.flavour (Forever) knowing every
-- rank of Detect Invisibility, two party members and a passer-by on a
-- nameplate, nobody wearing anything. opts.on ticks the buff, opts.passers the
-- switch under it.
local function session(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "WARLOCK"
	Mock.groupSize = 3
	local names = { nameplate1 = STRANGER }
	for token, pair in pairs(PARTY) do names[token] = pair end
	local restore = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local known = {}
		for _, id in ipairs(opts.known or RANKS) do known[id] = true end
		if (opts.class or "WARLOCK") == "WARLOCK" then
			rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
			rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		end
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		if opts.fresh then opts.fresh(ns, db) end
		db.sources.strangers = true
		db.sources.group = true
		db.sources.asked = true
		db.sources.self = false
		Mock.held = {}
		if opts.on then db.buff.optIn.detectgroup = true end
		if opts.passers then db.buff.detectPassers = true end
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

-- What the queue offers each name, by buff key.
local function offers(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		out[entry.name] = entry.buff and entry.buff.key
	end
	return out
end

local function text(control, field)
	local v = control and control[field]
	if type(v) == "function" then v = v() end
	return tostring(v or "")
end

-- ------------------------------------------------------------------ the default
do
	local scenario = "detect-passers: off on a new profile, and off it changes nothing"
	local default
	session(scenario, { on = true, fresh = function(_, db) default = db.buff.detectPassers end }, function(ns)
		if default ~= false then
			fail(scenario, "a new profile's buff.detectPassers is " .. tostring(default) .. ", not false")
		end
		local out = offers(ns)
		if out[filed(PARTY.party1)] ~= "detectgroup" then
			fail(scenario, "SKIPPED -- a party member is not offered it with the buff ticked")
			return
		end
		if out[filed(STRANGER)] then
			fail(scenario, "with the switch off a passer-by was offered " .. tostring(out[filed(STRANGER)]))
		end
		if not ns.OnlyReachesGroup() then
			fail(scenario, "with the switch off Manners says the warlock reaches passers-by")
		end
		local buff = ns.FindBuff("WARLOCK", "detectgroup")
		if ns.PassersToo(buff) then fail(scenario, "the buff reads as sent to passers-by with the switch off") end
	end)
end

-- ------------------------------------------------------------------ the switch
do
	local scenario = "detect-passers: ticked, a passer-by is offered it, and so is one who asks"
	session(scenario, { on = true }, function(ns)
		local control = H.findOption(ns.optionsTable, "passers_detectgroup")
		if not (control and control.set and control.get) then
			fail(scenario, "no switch for passers-by under Detect Invisibility on Who to buff")
			return
		end
		if control.get() ~= false then fail(scenario, "the switch reads ticked on a new profile") end
		control.set(nil, true)
		if ns.db.profile.buff.detectPassers ~= true or control.get() ~= true then
			fail(scenario, "ticked, the switch kept " .. tostring(ns.db.profile.buff.detectPassers))
		end
		local out = offers(ns)
		if out[filed(STRANGER)] ~= "detectgroup" then
			fail(scenario, "ticked, a passer-by was offered " .. tostring(out[filed(STRANGER)]))
		end
		if out[filed(PARTY.party1)] ~= "detectgroup" then
			fail(scenario, "ticked, a party member was offered " .. tostring(out[filed(PARTY.party1)]))
		end
		if ns.OnlyReachesGroup() then
			fail(scenario, "ticked, Manners still says the warlock reaches only his group")
		end
		local offer = H.findOption(ns.optionsTable, "offer_detectgroup")
		if text(offer, "name"):find("your group only", 1, true) then
			fail(scenario, "ticked, the buff's own switch still says your group only: " .. text(offer, "name"))
		end
		-- Unticked again, the passer-by is left alone, asking or not.
		control.set(nil, false)
		if ns.db.profile.buff.detectPassers ~= false then fail(scenario, "unticked, the switch kept it on") end
		ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "detect invis pls", filed(STRANGER), "Common", "", "", "",
			0, 0, "", 0, 2, "Player-1-nameplate1")
		out = offers(ns)
		if out[filed(STRANGER)] then
			fail(scenario, "unticked, a passer-by who asked was offered " .. tostring(out[filed(STRANGER)]))
		end
		if not text(offer, "name"):find("your group only", 1, true) then
			fail(scenario, "unticked, the buff's switch no longer says your group only")
		end
	end)
end

do
	local scenario = "detect-passers: ticked, a passer-by who asks for it by name is answered though passers-by are off"
	session(scenario, { on = true, passers = true }, function(ns)
		ns.db.profile.sources.strangers = false
		local out = offers(ns)
		if out[filed(STRANGER)] then
			fail(scenario, "SKIPPED -- with passers-by off one was offered " .. tostring(out[filed(STRANGER)]))
			return
		end
		ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "detect invis pls", filed(STRANGER), "Common", "", "", "",
			0, 0, "", 0, 2, "Player-1-nameplate1")
		out = offers(ns)
		if out[filed(STRANGER)] ~= "detectgroup" then
			fail(scenario, "a passer-by who asked for it was offered " .. tostring(out[filed(STRANGER)]))
		end
	end)
end

-- ------------------------------------------------------------------ where it shows
do
	local scenario = "detect-passers: the switch shows only once the buff is ticked"
	session(scenario, {}, function(ns)
		local control = H.findOption(ns.optionsTable, "passers_detectgroup")
		if not control then
			fail(scenario, "no switch for passers-by on Who to buff")
			return
		end
		if control.hidden() ~= true then fail(scenario, "the switch shows while Detect Invisibility is unticked") end
		-- Left ticked from before, with the buff unticked: still the group's alone.
		ns.db.profile.buff.detectPassers = true
		if offers(ns)[filed(STRANGER)] then
			fail(scenario, "with the buff unticked a passer-by was offered it")
		end
		ns.db.profile.buff.detectPassers = false
		local offer = H.findOption(ns.optionsTable, "offer_detectgroup")
		offer.set({ "who", "offer_detectgroup" }, true)
		if control.hidden() ~= false then fail(scenario, "the switch stays hidden with Detect Invisibility ticked") end
		if not text(control, "name"):find("passers-by too", 1, true) then
			fail(scenario, "the switch does not say passers-by too: " .. text(control, "name"))
		end
		-- In the window: on Who to buff, one step in from the buff's own switch,
		-- and found by search through it.
		local layout = ns.WindowLayout
		local at, offerAt, indent
		for _, section in ipairs(layout.pages.who.sections) do
			for i, item in ipairs(section.items) do
				local path = type(item) == "table" and item[1] or item
				if path == "who.offer_detectgroup" then offerAt = i end
				if path == "who.passers_detectgroup" then
					at, indent = i, type(item) == "table" and item.indent
				end
			end
		end
		if not (at and offerAt and at > offerAt and indent == true) then
			fail(scenario, "the switch is not placed one step in under Detect Invisibility's own")
		end
		if layout.parents["who.passers_detectgroup"] ~= "who.offer_detectgroup" then
			fail(scenario, "search is not told which switch to tick first")
		end
	end)
end

do
	local scenario = "detect-passers: only where the class and the client have the buff"
	for _, case in ipairs({ { "camelot", "WARLOCK", true }, { "vanilla", "WARLOCK", true }, { "tbc", "WARLOCK", true },
		{ "mists", "WARLOCK", false }, { "mainline", "WARLOCK", false }, { "camelot", "PRIEST", false },
		{ "camelot", "MAGE", false } }) do
		session(scenario, { flavour = case[1], class = case[2], known = case[1] == "tbc" and { 132 } or nil }, function(ns)
			local found
			for key in pairs(ns.optionsTable.args.who.args) do
				if tostring(key):find("^passers_") then
					if found then fail(scenario, ("%s %s: a second switch, %s"):format(case[1], case[2], key)) end
					found = key
				end
			end
			if (found == "passers_detectgroup") ~= case[3] or (found ~= nil) ~= case[3] then
				fail(scenario, ("%s %s: the switch is %s"):format(case[1], case[2], tostring(found)))
			end
		end)
	end
end

do
	local scenario = "detect-passers: tbc: ticked, a passer-by is offered the one rank"
	session(scenario, { flavour = "tbc", known = { 132 }, on = true, passers = true }, function(ns)
		local out = offers(ns)
		if out[filed(STRANGER)] ~= "detectgroup" then
			fail(scenario, "on Burning Crusade a passer-by was offered " .. tostring(out[filed(STRANGER)]))
		end
	end)
end

-- ------------------------------------------------------------------ the profile
do
	local scenario = "detect-passers: the switch travels with a profile, is repaired, and the page's reset turns it off"
	session(scenario, { on = true, passers = true }, function(ns)
		local line = ns.ExportSettings()
		ns.db.profile.buff.detectPassers = false
		local ok = ns.ImportSettings(line)
		if not ok or ns.db.profile.buff.detectPassers ~= true then
			fail(scenario, "restoring an export lost the switch")
		end
		ns.db.profile.buff.detectPassers = "yes"
		ns.ClampSettings(ns.db.profile)
		if ns.db.profile.buff.detectPassers ~= false then
			fail(scenario, "a damaged switch was kept as " .. tostring(ns.db.profile.buff.detectPassers))
		end
		ns.db.profile.buff.detectPassers = true
		if ns.OptionsPage.ResetPage("who") ~= true then fail(scenario, "SKIPPED -- the reset did not run") end
		if ns.db.profile.buff.detectPassers ~= false then
			fail(scenario, "the reset of Who to buff left passers-by on")
		end
	end)
end
