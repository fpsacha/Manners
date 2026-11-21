-- The second review of the day's fixes (Hints.lua, the line said once at an
-- inn; Core.lua, tracking held back in a battleground or an arena).
--
--   * the tick the resting line names, Also in cities and inns, is on the
--     simple view's short list, where a new profile reads My own buffs;
--   * the line is not said, and its once not spent, while Manners is switched
--     off or snoozed: nothing would come up on leaving;
--   * the buff you give everybody, missing on yourself, is something of yours
--     resting holds back, as a family of your class's own is;
--   * a battleground holds back a gathering tracking, never one to fight with
--     that the player picked or had on last.
--
-- Every scenario name starts with "day-fixes-review2:" so the mutations in
-- tests/mutations/day-fixes-review2.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

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
local realResting, realInstance = rawget(_G, "IsResting"), rawget(_G, "IsInInstance")
-- Arcane Intellect, Find Herbs and Find Minerals, and whatever else is named.
local function learn(more)
	local known = { [1459] = true, [2383] = true, [2580] = true }
	for _, id in ipairs(more or {}) do known[id] = true end
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
end
local function putBack()
	rawset(_G, "IsSpellKnown", realKnown)
	rawset(_G, "IsPlayerSpell", realPlayer)
	rawset(_G, "IsResting", realResting)
	rawset(_G, "IsInInstance", realInstance)
	minimap(nil)
end
local function resting(yes) rawset(_G, "IsResting", function() return yes end) end

local function said()
	for _, line in ipairs(Mock.printed) do
		if type(line) == "string" and line:find("Also in cities and inns", 1, true) then return line end
	end
	return nil
end

local function spent(ns)
	local hints = ns.db.char.hints
	return type(hints) == "table" and hints.resting == true
end

---------------------------------------------------------------------------
-- the tick the line names can be found
---------------------------------------------------------------------------

do
	local scenario = "day-fixes-review2: the tick the resting line names is on the simple view's My own buffs"
	Mock.reset()
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.self = true
		ns.SetMenuView("simple")
		ns.OpenOptions("self")
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		if not UI.Where("who.ownCities") then
			fail(scenario, "SKIPPED -- Also in cities and inns is not on My own buffs at all")
			return
		end
		if UI.OffShortList("who.self") then
			fail(scenario, "SKIPPED -- Myself is not on the short list")
			return
		end
		if UI.OffShortList("who.ownCities") then
			fail(scenario, "the line says to tick Also in cities and inns, and the simple view leaves it out")
		elseif not UI.RowShown("who.ownCities") then
			fail(scenario, "Also in cities and inns is on the short list and not drawn with Myself on")
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

---------------------------------------------------------------------------
-- not while Manners is off or snoozed
---------------------------------------------------------------------------

do
	local scenario = "day-fixes-review2: the resting line waits while Manners is switched off or snoozed"
	Mock.reset()
	-- Find Herbs learned and off: something of yours is missing.
	minimap({ { spellID = 2383, active = false }, { spellID = 2580, active = false } })
	learn()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.ForgetTrackingList()
		local profile = ns.db.profile
		profile.sources.self = true
		profile.ownBuffs.inCities = false
		resting(true)
		local function fresh()
			ns.db.char.hints = nil
			Mock.printed = {}
		end
		-- Switched off: nothing will come up on leaving, so nothing says it will.
		profile.enabled = false
		fresh()
		if ns.RestingHint(GetTime()) or said() then fail(scenario, "said with Manners switched off") end
		if spent(ns) then fail(scenario, "the once was spent while Manners was switched off") end
		profile.enabled = true
		-- Snoozed: the same, until the snooze is over.
		ns.addon:HandleSlash("snooze 5")
		if not ns.SnoozeLeft(GetTime()) then
			fail(scenario, "SKIPPED -- /manners snooze 5 did not snooze")
		else
			fresh()
			if ns.RestingHint(GetTime()) or said() then fail(scenario, "said while snoozed") end
			if spent(ns) then fail(scenario, "the once was spent while snoozed") end
		end
		ns.addon:HandleSlash("snooze off")
		-- Back on: said, as it would have been.
		fresh()
		if not (ns.RestingHint(GetTime()) and said()) then
			fail(scenario, "back on and resting with tracking off, the line was not said")
		end
	end
	putBack()
	Mock.reset()
end

---------------------------------------------------------------------------
-- the buff you give everybody is yours too
---------------------------------------------------------------------------

do
	local scenario = "day-fixes-review2: resting holding back your own Intellect is something to say"
	Mock.reset()
	-- Find Herbs on: no family of your class's own is missing anything.
	minimap({ { spellID = 2383, active = true }, { spellID = 2580, active = false } })
	learn()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.ForgetTrackingList()
		local profile = ns.db.profile
		profile.sources.self = true
		profile.ownBuffs.inCities = false
		local me = ns.UnitFullName("player")
		local function fresh(held)
			Mock.playerHeld = held
			ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
			Mock.advance(60)
			ns.db.char.hints = nil
			Mock.printed = {}
		end
		-- Out in the world with nothing on: the prompt would be on your Intellect.
		resting(false)
		fresh({})
		if not ns.SelfBuffFirst(profile, GetTime()) then
			fail(scenario, "SKIPPED -- out in the world your own Intellect is not what the prompt is on")
		else
			-- Wearing it at the inn: nothing of yours is missing.
			resting(true)
			fresh(nil)
			if ns.RestingHint(GetTime()) or said() then fail(scenario, "said with your own Intellect on and nothing missing") end
			if spent(ns) then fail(scenario, "the once was spent with nothing missing") end
			-- Your own name on the never-offer list: nothing would come up on leaving.
			fresh({})
			profile.never[me] = true
			if ns.RestingHint(GetTime()) or said() then fail(scenario, "said with your own name on the never-offer list") end
			profile.never[me] = nil
			-- Without it at the inn: the prompt is empty, and the line says why.
			fresh({})
			if ns.SelfBuffFirst(profile, GetTime()) then
				fail(scenario, "resting, the prompt is said to be on your own buff")
			end
			if not (ns.RestingHint(GetTime()) and said()) then
				fail(scenario, "resting with your own Intellect missing, the line was not said")
			end
		end
	end
	putBack()
	Mock.reset()
end

---------------------------------------------------------------------------
-- a tracking to fight with, in a battleground
---------------------------------------------------------------------------

do
	local scenario = "day-fixes-review2: a battleground holds back a gathering tracking, not one to fight with"
	Mock.reset()
	-- Find Herbs, Find Minerals and Track Humanoids learned, none on: a death.
	minimap({ { spellID = 2383, active = false }, { spellID = 2580, active = false }, { spellID = 19883, active = false } })
	learn({ 19883 })
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.ForgetTrackingList()
		local family
		for _, each in ipairs(ns.KnownOwnFamilies()) do
			if each.key == "tracking" then family = each end
		end
		local humanoids = ns.FindOwnSpell("trackhumanoids")
		if not (family and humanoids and humanoids.family == family) then
			fail(scenario, "SKIPPED -- Track Humanoids is not one of your trackings")
		else
			local ctx = { name = ns.UnitFullName("player"), now = GetTime(), whenBuffed = "skip" }
			local picks = ns.db.profile.ownBuffs.pick
			local function verdict(pick, last, kind)
				picks.tracking = pick
				ns.db.char.ownLast = { tracking = last }
				rawset(_G, "IsInInstance", function() return kind ~= nil, kind or "none" end)
				local spell, _, _, why = ns.OwnVerdict(family, ctx)
				return spell and spell.key, why
			end
			-- Out in the world the pick is what is reminded of: the ground to stand on.
			local key = verdict("trackhumanoids", nil, nil)
			if key ~= "trackhumanoids" then
				fail(scenario, "SKIPPED -- Track Humanoids picked is not reminded of out in the world: " .. tostring(key))
			else
				for _, kind in ipairs({ "pvp", "arena" }) do
					-- Picked by the player.
					local got, why = verdict("trackhumanoids", nil, kind)
					if got ~= "trackhumanoids" then
						fail(scenario, ("in a %s instance the Track Humanoids you picked is held back: %s"):format(kind, tostring(why)))
					end
					-- Automatic, and the one you had on last.
					got, why = verdict(nil, "trackhumanoids", kind)
					if got ~= "trackhumanoids" then
						fail(scenario, ("in a %s instance the Track Humanoids you had on last is held back: %s"):format(kind, tostring(why)))
					end
					-- Herbs and ore wait there, picked or Automatic's.
					got, why = verdict("findminerals", nil, kind)
					if got or why ~= "battle" then
						fail(scenario, ("in a %s instance Find Minerals picked is still offered: %s"):format(kind, tostring(why)))
					end
					got, why = verdict(nil, "findherbs", kind)
					if got or why ~= "battle" then
						fail(scenario, ("in a %s instance the Find Herbs you had on last is still offered: %s"):format(kind, tostring(why)))
					end
					got, why = verdict(nil, nil, kind)
					if got or why ~= "battle" then
						fail(scenario, ("in a %s instance Automatic's first gathering tracking is still offered: %s"):format(kind, tostring(why)))
					end
				end
				-- Don't remind me stays what it is.
				local got, why = verdict("off", "trackhumanoids", "pvp")
				if got or why ~= "off" then fail(scenario, "Don't remind me is not off in a battleground: " .. tostring(why)) end
			end
			picks.tracking = nil
		end
	end
	putBack()
	Mock.reset()
end
