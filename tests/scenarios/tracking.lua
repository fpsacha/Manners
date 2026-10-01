-- Tracking (Find Herbs and the like) as one of your own buffs. A player asked
-- on CurseForge: "when I die I often forget to put it on". On this client it is
-- the minimap's tracking list, not an aura, so these drive a stand-in
-- C_Minimap: off is offered, on is not, a list the client has not filled in
-- yet offers nothing, and with no list at all the family is not known.

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

-- Find Herbs and Find Minerals learned, beside the mock's Arcane Intellect.
-- Put back after each scenario, so nothing after this file is changed.
local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
local function learn()
	local known = { [1459] = true, [2383] = true, [2580] = true }
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
end
local function unlearn()
	rawset(_G, "IsSpellKnown", realKnown)
	rawset(_G, "IsPlayerSpell", realPlayer)
end

local function tracking(ns)
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if family.tracking then return family end
	end
	return nil
end

do
	local scenario = "tracking: Find Herbs off is offered, on is not"
	Mock.reset()
	local list = { { spellID = 2383, active = false }, { spellID = 2580, active = false } }
	minimap(list)
	learn()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.ForgetTrackingList()
		local family = tracking(ns)
		if not family then
			fail(scenario, "with Find Herbs on the minimap list, tracking is not one of your own buffs")
		else
			local ctx = { name = ns.UnitFullName("player"), now = GetTime(), whenBuffed = "skip" }
			local spell, up = ns.OwnVerdict(family, ctx)
			if up ~= false or not spell then
				fail(scenario, ("tracking off is not offered (up %s, spell %s)"):format(tostring(up), tostring(spell and spell.key)))
			end
			list[2].active = true
			ns.ForgetTrackingList()
			local again, upNow, _, why = ns.OwnVerdict(family, ctx)
			if upNow ~= true or again then
				fail(scenario, "Find Minerals on still reminds you of tracking: " .. tostring(why))
			end
		end
	end
	minimap(nil)
	unlearn()
end

do
	local scenario = "tracking: a list not filled in, or none, offers nothing"
	Mock.reset()
	minimap({ { spellID = 2383, active = false }, false })
	learn()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.ForgetTrackingList()
		if tracking(ns) then fail(scenario, "a tracking list the client has not filled in counts as known") end
		minimap(nil)
		ns.ForgetTrackingList()
		if tracking(ns) then fail(scenario, "with no tracking list at all, tracking counts as known") end
	end
	minimap(nil)
	unlearn()
end
