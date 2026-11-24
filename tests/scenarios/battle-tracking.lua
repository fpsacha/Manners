-- No tracking reminder in a battleground or an arena (1.11.25). A player wrote
-- on CurseForge: "in Battlegrounds after I died it shows me detect mining but
-- not my normal class buff, outside of BGs it works fine". Every death drops
-- tracking, the prompt keeps one entry for you at a time, and the reminder for
-- Find Minerals stood ahead of the class's own buff after each one. In a
-- battleground or an arena nothing is said about tracking, on or off
-- (Core.lua, OwnVerdict: "battle"); a dungeon, a raid and the open world keep
-- the reminder.
--
-- Every scenario name starts with "battle-tracking:" so the mutations in
-- tests/mutations/battle-tracking.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

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

-- Find Herbs and Find Minerals learned, beside the mock's Arcane Intellect,
-- and Frost Armor: a family that is not tracking, for the hold to leave alone.
local realKnown, realPlayer, realInstance = IsSpellKnown, IsPlayerSpell, rawget(_G, "IsInInstance")
local function learn()
	local known = { [1459] = true, [2383] = true, [2580] = true, [168] = true }
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
end
local function putBack()
	rawset(_G, "IsSpellKnown", realKnown)
	rawset(_G, "IsPlayerSpell", realPlayer)
	rawset(_G, "IsInInstance", realInstance)
	minimap(nil)
end

local function tracking(ns)
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if family.tracking then return family end
	end
	return nil
end

do
	local scenario = "battle-tracking: no tracking reminder in a battleground or an arena, and one everywhere else"
	Mock.reset()
	minimap({ { spellID = 2383, active = false }, { spellID = 2580, active = false } })
	learn()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		-- Ticked, as a player who wants it has (off by default since 1.12).
		for _, k in ipairs({ "tracking" }) do ns.db.profile.ownBuffs.pick[k] = "auto" end
		ns.ForgetTrackingList()
		local family = tracking(ns)
		if not family then
			fail(scenario, "SKIPPED -- tracking is not one of your own buffs")
		else
			local ctx = { name = ns.UnitFullName("player"), now = GetTime(), whenBuffed = "skip" }
			local function inside(yes, kind)
				rawset(_G, "IsInInstance", function() return yes, kind end)
			end
			-- Out in the world, in a dungeon and in a raid: reminded, as before.
			for _, place in ipairs({ { false, "none" }, { true, "party" }, { true, "raid" } }) do
				inside(place[1], place[2])
				local spell, up, _, why = ns.OwnVerdict(family, ctx)
				if not spell or up ~= false then
					fail(scenario, ("in %s tracking off is not offered: %s"):format(place[2], tostring(why)))
				end
				if ns.InBattleground() then fail(scenario, place[2] .. " is read as a battleground") end
			end
			-- A battleground and an arena: nothing, and it says why.
			for _, kind in ipairs({ "pvp", "arena" }) do
				inside(true, kind)
				local spell, up, _, why = ns.OwnVerdict(family, ctx)
				if spell or why ~= "battle" then
					fail(scenario, ("in a %s instance tracking is still offered: %s, %s"):format(kind, tostring(spell and spell.key), tostring(why)))
				end
				if up ~= nil then fail(scenario, "in a " .. kind .. " instance tracking was read: " .. tostring(up)) end
			end
			-- The game's 1 for true counts, and a kind it will not say is no battleground.
			inside(1, "pvp")
			if not ns.InBattleground() then fail(scenario, "the game's 1 for inside is not read as inside") end
			inside(true, nil)
			if ns.InBattleground() then fail(scenario, "an instance of no kind is read as a battleground") end
			-- A client without the question is in none.
			rawset(_G, "IsInInstance", nil)
			if ns.InBattleground() then fail(scenario, "with no IsInInstance, a battleground is assumed") end
			-- Another family is not held back there: only tracking is.
			inside(true, "pvp")
			for _, other in ipairs(ns.KnownOwnFamilies()) do
				if not other.tracking then
					local _, _, _, why = ns.OwnVerdict(other, ctx)
					if why == "battle" then fail(scenario, other.key .. " is held back in a battleground as tracking is") end
				end
			end
			-- And /manners debug says why, in words.
			inside(true, "pvp")
			local said = false
			local ok, lines = pcall(ns.MyselfLines, GetTime())
			if not (ok and type(lines) == "table") then
				fail(scenario, "the explanation could not be read: " .. tostring(lines))
			else
				for _, line in ipairs(lines) do
					if type(line) == "string" and line:find("battleground", 1, true) then said = true end
				end
				if not said then fail(scenario, "the explanation does not say tracking waits in a battleground") end
			end
		end
	end
	putBack()
	Mock.reset()
end
