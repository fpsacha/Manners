-- Find Treasure beside a gathering tracking on WoW Forever. A dwarf on
-- CurseForge: "As a dwarf I can have both find treasure and a profession
-- tracking up, but it doesn't seem to give the option to keep both up." Forever
-- lets the two be on together, so there Find Treasure is a family of its own
-- (Buffs.lua, FIND_TREASURE) beside Tracking, which keeps the rest; Classic Era
-- and Burning Crusade keep one tracking on at a time, and it stays in Tracking.
-- It is `onceUp`: Automatic asks for it only once it has been seen up, so a
-- dwarf who never turns it on is never nagged to. A memory, a pick or a tick of
-- it on Tracking moves across (Core.lua, ns.SplitFindTreasure).
--
-- Tracking is the minimap's tracking list, not an aura, so these drive a
-- stand-in C_Minimap as tracking.lua does. Every scenario name starts with
-- "forever-tracking:" so tests/mutations/forever-tracking.py can name it.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption = H.findOption

local FIND_HERBS, FIND_TREASURE = 2383, 2481

local function minimap(entries)
	if entries == nil then
		rawset(_G, "C_Minimap", nil)
		return
	end
	rawset(_G, "C_Minimap", {
		GetNumTrackingTypes = function() return #entries end,
		GetTrackingInfo = function(i) return entries[i] end,
	})
end

local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
local function learn(ids)
	local known = { [1459] = true }
	for _, id in ipairs(ids) do known[id] = true end
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
end
local function unlearn()
	rawset(_G, "IsSpellKnown", realKnown)
	rawset(_G, "IsPlayerSpell", realPlayer)
	minimap(nil)
end

local function known(ns, key)
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if family.key == key then return family end
	end
	return nil
end

-- A session with Find Herbs and Find Treasure known and on the minimap's list,
-- both off; body(ns, ctx, set) runs on a driven session, where set(id, on)
-- switches one on the list. Put back after, whatever happens.
local function session(scenario, flavour, body)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	local list = { { spellID = FIND_HERBS, active = false }, { spellID = FIND_TREASURE, active = false } }
	minimap(list)
	learn({ FIND_HERBS, FIND_TREASURE })
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			drive(scenario, ns)
			ns.Prompt:ExitTest()
			ns.ForgetTrackingList()
			local ctx = { name = ns.UnitFullName("player"), now = GetTime(), whenBuffed = "skip" }
			local function set(id, on)
				for _, entry in ipairs(list) do
					if entry.spellID == id then entry.active = on end
				end
				ns.ForgetTrackingList()
			end
			body(ns, ctx, set)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
		if not ok then fail(scenario, "errored: " .. tostring(err)) end
	end
	unlearn()
	Mock.reset()
end

local function offered(ns, family, ctx)
	local spell, up, _, why = ns.OwnVerdict(family, ctx)
	return spell and spell.key or nil, up, why
end

-- ------------------------------------------------------------------ the families

do
	local scenario = "forever-tracking: Find Treasure on still reminds you of Find Herbs"
	session(scenario, nil, function(ns, ctx, set)
		local tracking, treasure = known(ns, "tracking"), known(ns, "findtreasure")
		if not tracking then
			fail(scenario, "with Find Herbs on the minimap list, Tracking is not one of your own buffs")
			return
		end
		if not treasure then
			fail(scenario, "Find Treasure is not a family of its own on Forever")
			return
		end
		for _, spell in ipairs(tracking.spells) do
			if spell.key == "findtreasure" then fail(scenario, "Find Treasure is still one of Tracking on Forever") end
		end
		if ns.OwnFamilyLabel(treasure) ~= "Find Treasure" then
			fail(scenario, "the family is called " .. tostring(ns.OwnFamilyLabel(treasure)) .. ", not by its spell")
		end
		-- Find Treasure on, Find Herbs off: the gathering one is still asked for.
		set(FIND_TREASURE, true)
		local spell, up, why = offered(ns, tracking, ctx)
		if up ~= false or spell ~= "findherbs" then
			fail(scenario, ("with Find Treasure on, Find Herbs off was not offered (up %s, spell %s, why %s)")
				:format(tostring(up), tostring(spell), tostring(why)))
		end
		local _, treasureUp = offered(ns, treasure, ctx)
		if treasureUp ~= true then fail(scenario, "Find Treasure on does not read as up") end
		-- And the other way about, once Find Treasure has been seen up.
		set(FIND_TREASURE, false)
		set(FIND_HERBS, true)
		local again, upNow = offered(ns, treasure, ctx)
		if upNow ~= false or again ~= "findtreasure" then
			fail(scenario, ("with Find Herbs on, Find Treasure off was not offered (up %s, spell %s)")
				:format(tostring(upNow), tostring(again)))
		end
		local herbs, herbsUp = offered(ns, tracking, ctx)
		if herbsUp ~= true or herbs then
			fail(scenario, "Find Herbs on still reminds you of Tracking: " .. tostring(herbs))
		end
	end)
end

do
	local scenario = "forever-tracking: never had Find Treasure up, never asked for it"
	session(scenario, nil, function(ns, ctx, set)
		local treasure = known(ns, "findtreasure")
		if not treasure then
			fail(scenario, "SKIPPED -- Find Treasure is not a family of its own here")
			return
		end
		set(FIND_HERBS, true)
		local spell, up, why = offered(ns, treasure, ctx)
		if spell then
			fail(scenario, "Find Treasure was offered to a dwarf who has never had it up")
		elseif up ~= false or why ~= "none" then
			fail(scenario, ("nothing offered, but up %s and why %s"):format(tostring(up), tostring(why)))
		end
		local memory = ns.db.char.ownLast
		if type(memory) == "table" and memory.findtreasure ~= nil then
			fail(scenario, "a Find Treasure never up was remembered as " .. tostring(memory.findtreasure))
		end
		-- Put up by hand: remembered, and asked for once it drops.
		set(FIND_TREASURE, true)
		offered(ns, treasure, ctx)
		if not (type(ns.db.char.ownLast) == "table" and ns.db.char.ownLast.findtreasure == "findtreasure") then
			fail(scenario, "Find Treasure up was not remembered")
		end
		set(FIND_TREASURE, false)
		if offered(ns, treasure, ctx) ~= "findtreasure" then
			fail(scenario, "Find Treasure had up and then off was not offered")
		end
		-- A pick of it reminds you without the memory.
		ns.db.char.ownLast.findtreasure = nil
		ns.db.profile.ownBuffs.pick.findtreasure = "findtreasure"
		if offered(ns, treasure, ctx) ~= "findtreasure" then
			fail(scenario, "Find Treasure picked and off was not offered")
		end
	end)
end

do
	local scenario = "forever-tracking: Classic Era and Burning Crusade keep it in Tracking"
	for _, flavour in ipairs({ "vanilla", "tbc" }) do
		session(scenario, flavour, function(ns, ctx, set)
			if ns.FindOwnFamily("findtreasure") then
				fail(scenario, flavour .. ": Find Treasure is a family of its own")
			end
			local spell = ns.FindOwnSpell("findtreasure")
			if not (spell and spell.family and spell.family.key == "tracking") then
				fail(scenario, flavour .. ": Find Treasure is not one of Tracking")
				return
			end
			-- One tracking on at a time there: Find Treasure on is Tracking up.
			set(FIND_TREASURE, true)
			local offer, up = offered(ns, spell.family, ctx)
			if up ~= true or offer then
				fail(scenario, ("%s: with Find Treasure on, Tracking read %s and offered %s")
					:format(flavour, tostring(up), tostring(offer)))
			end
			-- And the saved settings are left as they were.
			ns.db.char.ownLast = ns.db.char.ownLast or {}
			ns.db.char.ownLast.tracking = "findtreasure"
			ns.db.profile.ownBuffs.pick.tracking = "findtreasure"
			ns.ClampSettings()
			if ns.db.char.ownLast.tracking ~= "findtreasure" or ns.db.profile.ownBuffs.pick.tracking ~= "findtreasure" then
				fail(scenario, flavour .. ": the repair moved Find Treasure out of Tracking")
			end
		end)
	end
end

-- ------------------------------------------------------------------ the saved settings

do
	local scenario = "forever-tracking: a memory or a pick of it on Tracking moves across"
	session(scenario, nil, function(ns, ctx, set)
		if not ns.FindOwnFamily("findtreasure") then
			fail(scenario, "SKIPPED -- Find Treasure is not a family of its own here")
			return
		end
		local own, char = ns.db.profile.ownBuffs, ns.db.char
		char.ownLast = char.ownLast or {}
		char.ownLast.tracking = "findtreasure"
		own.pick.tracking = "findtreasure"
		ns.ClampSettings()
		if char.ownLast.findtreasure ~= "findtreasure" then
			fail(scenario, "the memory of Find Treasure on Tracking did not move: " .. tostring(char.ownLast.findtreasure))
		end
		if char.ownLast.tracking ~= nil then
			fail(scenario, "Tracking still remembers Find Treasure: " .. tostring(char.ownLast.tracking))
		end
		if own.pick.findtreasure ~= "findtreasure" then
			fail(scenario, "the pick of Find Treasure on Tracking did not move: " .. tostring(own.pick.findtreasure))
		end
		if own.pick.tracking ~= "auto" then
			fail(scenario, "Tracking's pick after the move is " .. tostring(own.pick.tracking) .. ", not Automatic")
		end
		-- The moved memory is what reminds you of it.
		own.pick.findtreasure = "auto"
		set(FIND_HERBS, true)
		if offered(ns, ns.FindOwnFamily("findtreasure"), ctx) ~= "findtreasure" then
			fail(scenario, "the moved memory does not remind you of Find Treasure")
		end
		-- Once: the next repair leaves your own choice alone.
		own.pick.findtreasure = "off"
		ns.ClampSettings()
		if own.pick.findtreasure ~= "off" then
			fail(scenario, "a second repair changed Find Treasure's switch to " .. tostring(own.pick.findtreasure))
		end
	end)
end

do
	local scenario = "forever-tracking: a tick or Tracking off keeps it off"
	session(scenario, nil, function(ns, ctx, set)
		if not ns.FindOwnFamily("findtreasure") then
			fail(scenario, "SKIPPED -- Find Treasure is not a family of its own here")
			return
		end
		local own, char = ns.db.profile.ownBuffs, ns.db.char
		-- Ticked under Never remind me about, which a family of one has no list for.
		own.leave.findtreasure = true
		ns.ClampSettings()
		if own.pick.findtreasure ~= "off" then
			fail(scenario, "Find Treasure ticked on Tracking is switched " .. tostring(own.pick.findtreasure))
		end
		if own.leave.findtreasure == true then
			fail(scenario, "the tick was left where no list shows it")
		end
		own.pick.findtreasure = "auto"
		ns.ClampSettings()
		if own.pick.findtreasure ~= "auto" then
			fail(scenario, "switched back on, a second repair made it " .. tostring(own.pick.findtreasure))
		end
		-- Tracking switched off, with Find Treasure the one up last.
		own.pick.tracking = "off"
		char.ownLast = char.ownLast or {}
		char.ownLast.tracking = "findtreasure"
		ns.ClampSettings()
		if own.pick.findtreasure ~= "off" then
			fail(scenario, "with Tracking off, Find Treasure came out switched " .. tostring(own.pick.findtreasure))
		end
		if char.ownLast.findtreasure ~= nil then
			fail(scenario, "with Tracking off, the memory still moved across")
		end
		set(FIND_TREASURE, false)
		set(FIND_HERBS, true)
		if offered(ns, ns.FindOwnFamily("findtreasure"), ctx) then
			fail(scenario, "with Tracking off before, Find Treasure was offered after the move")
		end
	end)
end

-- ------------------------------------------------------------------ the options page

do
	local scenario = "forever-tracking: the page has a switch for it"
	session(scenario, nil, function(ns)
		local control = findOption(ns.optionsTable, "own_findtreasure")
		if not control then
			fail(scenario, "Who to buff has no Find Treasure control")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the control is a " .. tostring(control.type)) end
		if control.hidden() then fail(scenario, "the control is hidden with Find Treasure known") end
		local desc = type(control.desc) == "function" and control.desc() or control.desc
		if not tostring(desc):find("once you have had it up", 1, true) then
			fail(scenario, "the switch does not say it waits until it has been up: " .. tostring(desc))
		end
		if control.get() ~= true then fail(scenario, "the switch is off on a new profile") end
		control.set({}, false)
		if ns.db.profile.ownBuffs.pick.findtreasure ~= "off" then
			fail(scenario, "switching it off did not write the profile")
		end
		control.set({}, true)
		if ns.db.profile.ownBuffs.pick.findtreasure ~= "auto" then
			fail(scenario, "switching it on did not write the profile")
		end
	end)
end
