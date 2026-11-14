-- "Weapon imbues before the shield" (CurseForge: a shaman short of mana for
-- Lightning Shield never saw Windfury, which waited behind it). A shaman's
-- weapon imbue family comes ahead of the shield when ownBuffs.imbueFirst is on.
--
-- Every scenario name starts with "imbuefirst:" so the mutations in
-- tests/mutations/imbuefirst.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local freshPrompt, findOption = H.freshPrompt, H.findOption

local KNOWN = { [324] = true, [8232] = true }

local function with(scenario, class, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = class
	local saved = { IsSpellKnown = rawget(_G, "IsSpellKnown"), IsPlayerSpell = rawget(_G, "IsPlayerSpell") }
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local function knows(id) return KNOWN[id] == true end
		rawset(_G, "IsSpellKnown", knows)
		rawset(_G, "IsPlayerSpell", knows)
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns)
	end)
	for name, fn in pairs(saved) do rawset(_G, name, fn) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function keys(ns)
	local out = {}
	for _, family in ipairs(ns.KnownOwnFamilies()) do out[#out + 1] = family.key end
	return table.concat(out, ",")
end

do
	local scenario = "imbuefirst: a shaman's imbue comes ahead of his shield only when asked"
	with(scenario, "SHAMAN", function(ns)
		if ns.db.profile.ownBuffs.imbueFirst ~= false then
			fail(scenario, "a new profile's switch is " .. tostring(ns.db.profile.ownBuffs.imbueFirst))
		end
		if keys(ns) ~= "shield,shamanimbue" then fail(scenario, "off, the order is " .. keys(ns)) end
		ns.db.profile.ownBuffs.imbueFirst = true
		if keys(ns) ~= "shamanimbue,shield" then fail(scenario, "on, the order is " .. keys(ns)) end
	end)
end

do
	local scenario = "imbuefirst: the switch is on Who to buff for a shaman and writes the setting"
	with(scenario, "SHAMAN", function(ns)
		local control = findOption(ns.optionsTable, "ownImbueFirst")
		if not control then fail(scenario, "Who to buff has no switch") return end
		if control.hidden() then fail(scenario, "hidden from a shaman who knows an imbue") end
		control.set(nil, true)
		if ns.db.profile.ownBuffs.imbueFirst ~= true then fail(scenario, "turning it on wrote nothing") end
		if control.get() ~= true then fail(scenario, "reads off after turning it on") end
		control.set(nil, false)
		if ns.db.profile.ownBuffs.imbueFirst ~= false then fail(scenario, "turning it off wrote nothing") end
	end)
	local other = "imbuefirst: the switch is hidden from a class with no imbue"
	with(other, "MAGE", function(ns)
		local control = findOption(ns.optionsTable, "ownImbueFirst")
		if control and not control.hidden() then fail(other, "shown to a mage") end
	end)
end
