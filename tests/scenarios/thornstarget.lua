-- Thorns, also offered to my target (1.12.1). A druid asked for a switch to put
-- Thorns on whoever she picks out without giving up Tanks only, which still
-- reminds her when the tank's runs out. A switch under Offer to (buff.toTarget;
-- Who to buff, "who.toTarget_<key>") offers a buff of the tankChoice kind to
-- your current target whatever Offer to says; everybody else is offered it as
-- Offer to says.
--
-- Every scenario name starts with "thornstarget:" so the mutations in
-- tests/mutations/thornstarget.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

-- Gwen is in the party, no tank, and your target; Bram tanks; Cora is neither.
local NAMES = {
	target = { "Gwen", "Hale" },
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
}

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "UnitInRaid", "C_Spell" }

local function filed(pair)
	return Mock.surnames and (pair[1] .. " " .. pair[2]) or pair[1]
end

-- One session as a druid knowing Mark of the Wild and Thorns, everybody
-- wearing Mark of the Wild (so Thorns is what is missing), Thorns held to the
-- tanks, `toTarget` the switch, then body(ns).
local function session(scenario, toTarget, body)
	Mock.reset()
	Mock.class = "DRUID"
	Mock.groupSize = 4
	local restore = H.strangers(NAMES)
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
			return type(unit) == "string" and (unit:find("^party%d") ~= nil or unit == "target")
		end)
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.strangers = true
		db.sources.group = true
		db.sources.self = false
		db.buff.tanksOnly = { thorns = true }
		db.buff.toTarget = toTarget and { thorns = true } or {}
		Mock.held = {}
		for _, id in ipairs(ns.FindBuff("DRUID", "motw").ranks) do Mock.held[id] = true end
		Mock.roles = { party2 = "TANK" }
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

do
	local scenario = "thornstarget: Tanks only and the switch offer Thorns to a target who does not tank"
	session(scenario, true, function(ns)
		local got = offers(ns)
		if got[filed(NAMES.target)] ~= "thorns" then
			fail(scenario, "the target was offered " .. tostring(got[filed(NAMES.target)]) .. ", not Thorns")
		end
		if got[filed(NAMES.party2)] ~= "thorns" then
			fail(scenario, "the tank was offered " .. tostring(got[filed(NAMES.party2)]) .. ", not Thorns")
		end
		if got[filed(NAMES.party3)] == "thorns" then
			fail(scenario, "a member who is neither tank nor target was offered Thorns")
		end
	end)
end

do
	local scenario = "thornstarget: switch off, Tanks only keeps Thorns off the target"
	session(scenario, false, function(ns)
		local got = offers(ns)
		if got[filed(NAMES.target)] == "thorns" then
			fail(scenario, "the target who does not tank was offered Thorns with the switch off")
		end
		if got[filed(NAMES.party2)] ~= "thorns" then
			fail(scenario, "the tank was offered " .. tostring(got[filed(NAMES.party2)]) .. ", not Thorns")
		end
	end)
end

do
	local scenario = "thornstarget: the switch is in Who to buff, placed under Offer to, and sets only its own set"
	session(scenario, false, function(ns)
		local control = H.findOption(ns.optionsTable, "toTarget_thorns")
		if not control then return fail(scenario, "no toTarget_thorns control in Who to buff") end
		local B = ns.db.profile.buff
		local info = { "who", "toTarget_thorns" }
		control.set(info, true)
		if B.toTarget.thorns ~= true or control.get(info) ~= true then fail(scenario, "on did not tick buff.toTarget.thorns") end
		if B.tanksOnly.thorns ~= true or B.meOnly.thorns ~= nil then fail(scenario, "the switch touched Offer to's sets") end
		control.set(info, false)
		if B.toTarget.thorns ~= nil then fail(scenario, "off left " .. tostring(B.toTarget.thorns) .. " behind, not nil") end
		local page = ns.WindowLayout and ns.WindowLayout.pages and ns.WindowLayout.pages.who
		local found
		for _, section in ipairs(page and page.sections or {}) do
			for _, item in ipairs(section.items or {}) do
				if type(item) == "table" and item[1] == "who.toTarget_thorns" and item.indent == true then found = true end
			end
		end
		if not found then fail(scenario, "the options window does not place who.toTarget_thorns, indented") end
		ns.db.profile.buff.toTarget = "yes"
		ns.ClampSettings()
		if type(ns.db.profile.buff.toTarget) ~= "table" then
			fail(scenario, "a damaged set was left as " .. tostring(ns.db.profile.buff.toTarget))
		end
		ns.db.profile.buff.toTarget = { thorns = true }
		local text = ns.ExportSettings and ns.ExportSettings() or nil
		if text and not text:find("buff.toTarget=thorns", 1, true) then
			fail(scenario, "the export does not carry the choice")
		end
	end)
end
