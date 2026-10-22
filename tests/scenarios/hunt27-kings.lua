-- Blessing of Kings first (hunt 27). A paladin who knows Kings offers it to
-- everybody ahead of the other blessings (Buffs.lua, `strongest`; Core.lua,
-- CastableBuffs), for single casts and for the Greater Blessing of a class, and
-- falls back to the blessing the walk always picked -- Might for those without
-- mana, Wisdom for those with it, then Salvation and Light -- for somebody who
-- already carries Kings from another paladin or cannot be given it. A blessing
-- of yours already on somebody covers them, as it always did: they are never
-- walked from it onto Kings, and Kings of yours is never walked onto the class
-- blessing, so nobody flips from one to the other. It is a setting, on by
-- default, with its control on Who to buff for the paladins whose list does not
-- begin with Kings (Classic Era, Burning Crusade and Forever; Mists' does).
--
-- Every scenario name starts with "hunt27-kings:" so the mutations in
-- tests/mutations/hunt27-kings.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local SYMBOL_OF_KINGS = 21177

-- Kings is third in the list on these, so putting it first is a change.
local CLIENTS = { "vanilla", "tbc", "camelot" }

-- The four others in a party of five.
local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	party4 = { "Dain", "Moor" },
}

-- Whose aura a unit carries: ours, another paladin's (a token the player is not),
-- or nobody the client will name.
local OURS, THEIRS, NOBODY = "player", "nameplate2", true

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitPowerMax", "UnitInParty",
	"GetItemCount", "GetItemInfo", "C_UnitAuras" }

-- The name the queue files a party member under on this client.
local function filed(token)
	local name = PARTY[token]
	return Mock.surnames and (name[1] .. " " .. name[2]) or name[1]
end

local function ids(ns, key)
	local buff = ns.FindBuff("PALADIN", key)
	return buff and buff.ranks or {}
end

-- One paladin's session on `env.client`, the others as `env.classes` says
-- (token -> class), carrying `env.wears` (token -> { [spell id] = source }, and
-- "player" for what you wear yourself), `env.left` (token -> seconds left on what
-- they carry). `env.keys` are the blessings known; `env.greater` adds the Greater
-- Blessings of those. body(ns) runs with the lifecycle driven and the slate
-- cleared; `env.setup(ns)` runs on the profile before that.
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.client)
	Mock.class = "PALADIN"
	Mock.groupSize = env.alone and 0 or 5
	env.classes = env.classes or {}
	env.wears = env.wears or {}
	env.left = env.left or {}
	local names = {}
	for token in pairs(env.classes) do names[token] = PARTY[token] end
	local restoreUnits = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "GetItemCount", function(id) return env.bags and env.bags[id] or 0 end)
	rawset(_G, "GetItemInfo", function(id) return id == SYMBOL_OF_KINGS and "Symbol of Kings" or nil end)
	rawset(_G, "UnitClass", function(unit)
		local class = env.classes[unit]
		if class then return class, class end
		return saved.UnitClass(unit)
	end)
	-- A warrior's and a rogue's mana bar reads zero.
	rawset(_G, "UnitPowerMax", function(unit, power)
		local class = env.classes[unit]
		if class == "WARRIOR" or class == "ROGUE" then return 0 end
		return saved.UnitPowerMax(unit, power)
	end)
	-- The mock counts every unit as in a party; here only the party tokens are.
	rawset(_G, "UnitInParty", function(unit)
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end)
	-- Read through _G, which builds the mock's C_UnitAuras when nothing has yet.
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			local carrying = env.wears[unit]
			if unit == "player" and carrying == nil then return base.GetUnitAuraBySpellID(unit, spellId) end
			local source = carrying and carrying[spellId]
			if not source then return nil end
			local left = env.left[unit] or 3600
			return { spellId = spellId, expirationTime = Mock.now + left, duration = 3600,
				sourceUnit = type(source) == "string" and source or nil }
		end,
	}, { __index = base }))

	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		for _, key in ipairs(env.keys or { "wisdom", "might", "kings", "salvation", "light" }) do
			local buff = ns.FindBuff("PALADIN", key)
			for _, id in ipairs(buff and buff.ranks or {}) do known[id] = true end
			if env.greater and buff then
				for _, rank in ipairs(buff.groupCast or {}) do known[rank.id] = true end
			end
		end
		H.freshPrompt(ns, scenario)
		ns.db.profile.sources.self = env.myself == true
		ns.db.profile.sources.strangers = false
		if env.setup then env.setup(ns) end
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What the queue offers each party member, by token: the buff's key, or false
-- for nothing. The aura cache is let go first (a reading is trusted for three
-- seconds), so a scenario that changes what somebody wears sees it at once.
local function offers(ns, env)
	Mock.advance(4)
	local byName = {}
	for _, entry in ipairs(ns.BuildQueue()) do byName[entry.name] = entry end
	local out = {}
	for token in pairs(env.classes) do
		local entry = byName[filed(token)]
		out[token] = entry and entry.buff and entry.buff.key or false
	end
	return out, byName
end

local function groupCast(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.groupCast then return entry end
	end
	return nil
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- "token=what, ..." for a failure line.
local function said(out)
	local list = {}
	for token, what in pairs(out) do list[#list + 1] = token .. "=" .. tostring(what) end
	table.sort(list)
	return table.concat(list, ", ")
end

-- Whether every token in `want` is offered what it says.
local function matches(out, want)
	for token, what in pairs(want) do
		if out[token] ~= what then return false end
	end
	return true
end

-- The three kinds of person: no mana, mana, no mana.
local THREE = { party1 = "WARRIOR", party2 = "MAGE", party3 = "ROGUE" }

for _, client in ipairs(CLIENTS) do
	-- ------------------------------------------------------------ everybody
	do
		local scenario = "hunt27-kings: " .. client .. ": a warrior, a mage and a rogue are all offered Kings"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			local out, byName = offers(ns, env)
			if not matches(out, { party1 = "kings", party2 = "kings", party3 = "kings" }) then
				fail(scenario, "the warrior, the mage and the rogue are offered " .. said(out) .. ", not Kings")
			end
			local top = ns.BuildQueue()[1]
			if top then
				ns.Prompt:ApplyTarget(top)
				if not flat(macro(ns)):find("/cast Blessing of Kings", 1, true) then
					fail(scenario, "the macro does not cast Blessing of Kings: " .. flat(macro(ns)))
				end
			else
				fail(scenario, "SKIPPED -- nobody is offered anything")
			end
			if not byName then fail(scenario, "SKIPPED -- no queue") end
		end)
	end

	-- ------------------------------------------------- Kings already worn
	do
		local scenario = "hunt27-kings: " .. client .. ": Kings from another paladin is walked on to the class blessing"
		local kings
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			kings = ids(ns, "kings")[1]
			for token in pairs(THREE) do env.wears[token] = { [kings] = THEIRS } end
			local out = offers(ns, env)
			if not matches(out, { party1 = "might", party2 = "wisdom", party3 = "might" }) then
				fail(scenario, "somebody wearing another paladin's Kings is offered " .. said(out)
					.. ", not the blessing for their class (Might, Wisdom, Might)")
			end
		end)
	end

	-- ------------------------------------------- Salvation and Light follow
	for _, first in ipairs({ true, false }) do
		local scenario = "hunt27-kings: " .. client .. ": Salvation and Light follow as they did"
			.. (first and "" or " (switch off)")
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			ns.db.profile.buff.kingsFirst = first
			local kings, might, wisdom, salvation = ids(ns, "kings")[1], ids(ns, "might")[1],
				ids(ns, "wisdom")[1], ids(ns, "salvation")[1]
			-- Kings and Might from another paladin on the warrior, those and Wisdom
			-- on the mage, and Salvation too on the rogue.
			env.wears.party1 = { [kings] = THEIRS, [might] = THEIRS }
			env.wears.party2 = { [kings] = THEIRS, [might] = THEIRS, [wisdom] = THEIRS }
			env.wears.party3 = { [kings] = THEIRS, [might] = THEIRS, [salvation] = THEIRS }
			local out = offers(ns, env)
			if not matches(out, { party1 = "salvation", party2 = "salvation", party3 = "light" }) then
				fail(scenario, "with the others' Kings and Might on them, Salvation (your group) and Light"
					.. " are offered " .. said(out) .. ", not salvation, salvation, light")
			end
		end)
	end

	-- ------------------------------------------------- already one of yours
	do
		local scenario = "hunt27-kings: " .. client .. ": a blessing of yours already worn is not flipped to Kings"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			local might, wisdom = ids(ns, "might")[1], ids(ns, "wisdom")[1]
			env.wears.party1 = { [might] = OURS }
			env.wears.party2 = { [wisdom] = OURS }
			env.wears.party3 = { [might] = NOBODY }
			-- Scan after scan: never Kings over what they wear.
			for scan = 1, 5 do
				local out = offers(ns, env)
				if not matches(out, { party1 = false, party2 = false, party3 = false }) then
					fail(scenario, "scan " .. scan .. ": people wearing your Might or Wisdom were offered "
						.. said(out) .. ", which would replace it")
					return
				end
			end
			-- Running out, with top-ups on: the same blessing again, never Kings.
			ns.db.profile.filters.whenBuffed = "refresh"
			env.left.party1, env.left.party2, env.left.party3 = 100, 100, 100
			local out = offers(ns, env)
			if not matches(out, { party1 = "might", party2 = "wisdom", party3 = "might" }) then
				fail(scenario, "running out, they were offered " .. said(out)
					.. ", not the blessing they wear (Might, Wisdom, Might)")
			end
		end)
	end

	-- --------------------------------------------- Kings of yours stays Kings
	do
		local scenario = "hunt27-kings: " .. client .. ": Kings of yours is not flipped to the class blessing"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			local kings = ids(ns, "kings")[1]
			for token in pairs(THREE) do env.wears[token] = { [kings] = OURS } end
			for scan = 1, 5 do
				local out = offers(ns, env)
				if not matches(out, { party1 = false, party2 = false, party3 = false }) then
					fail(scenario, "scan " .. scan .. ": people wearing your Kings were offered " .. said(out))
					return
				end
			end
			ns.db.profile.filters.whenBuffed = "refresh"
			env.left.party1, env.left.party2, env.left.party3 = 100, 100, 100
			local out = offers(ns, env)
			if not matches(out, { party1 = "kings", party2 = "kings", party3 = "kings" }) then
				fail(scenario, "running out, people wearing your Kings were offered " .. said(out)
					.. ", not Kings again")
			end
		end)
	end

	-- --------------------------------------------- the Greater Blessing
	do
		local scenario = "hunt27-kings: " .. client .. ": Greater Blessing of Kings for a class group"
		local env = { client = client, greater = true, bags = { [SYMBOL_OF_KINGS] = 10 },
			classes = { party1 = "WARRIOR", party2 = "WARRIOR", party3 = "WARRIOR", party4 = "MAGE" } }
		session(scenario, env, function(ns)
			local group = groupCast(ns)
			if not group then
				fail(scenario, "no Greater Blessing for three warriors missing Kings")
				return
			end
			if group.buff.key ~= "kings" or group.groupCast.class ~= "WARRIOR" then
				fail(scenario, "the Greater Blessing is " .. tostring(group.buff.key) .. " for "
					.. tostring(group.groupCast.class) .. ", not Kings for the warriors")
			end
			if group.groupCast.spellName ~= "Greater Blessing of Kings" then
				fail(scenario, "the group cast is " .. tostring(group.groupCast.spellName))
			end
			if #group.groupCast.members ~= 2 then
				fail(scenario, "the Greater Blessing covers " .. (#group.groupCast.members + 1) .. " warriors, not three")
			end
			ns.Prompt:ApplyTarget(group)
			if not flat(macro(ns)):find("/cast Greater Blessing of Kings", 1, true) then
				fail(scenario, "the macro does not cast Greater Blessing of Kings: " .. flat(macro(ns)))
			end
			local _, byName = offers(ns, env)
			local mage = byName[filed("party4")]
			if not (mage and mage.buff.key == "kings" and not mage.groupCast) then
				fail(scenario, "the one mage is not left a single Blessing of Kings")
			end
		end)
	end

	do
		local scenario = "hunt27-kings: " .. client .. ": a Greater Blessing of Kings never replaces a Might of yours"
		local env = { client = client, greater = true, bags = { [SYMBOL_OF_KINGS] = 10 },
			classes = { party1 = "WARRIOR", party2 = "WARRIOR", party3 = "WARRIOR", party4 = "WARRIOR" } }
		session(scenario, env, function(ns)
			env.wears.party4 = { [ids(ns, "might")[1]] = OURS }
			-- Past the three seconds a reading is trusted.
			Mock.advance(4)
			if groupCast(ns) then
				fail(scenario, "a Greater Blessing of Kings was offered over a warrior wearing your Might")
			end
			local out = offers(ns, env)
			if not matches(out, { party1 = "kings", party2 = "kings", party3 = "kings", party4 = false }) then
				fail(scenario, "the three are offered single Kings and the fourth nothing, but " .. said(out))
			end
		end)
	end

	-- ---------------------------------------------------------- switch off
	do
		local scenario = "hunt27-kings: " .. client .. ": with the switch off the walk is as it was"
		local env = { client = client, greater = true, bags = { [SYMBOL_OF_KINGS] = 10 }, classes = THREE }
		session(scenario, env, function(ns)
			ns.db.profile.buff.kingsFirst = false
			local out = offers(ns, env)
			if not matches(out, { party1 = "might", party2 = "wisdom", party3 = "might" }) then
				fail(scenario, "with Kings first off, the warrior, mage and rogue are offered " .. said(out)
					.. ", not Might, Wisdom, Might")
			end
			local named = ns.ResolveBuff(true)
			if not named or named.key ~= "wisdom" then
				fail(scenario, "with Kings first off, the spell named is " .. tostring(named and named.key)
					.. ", not Wisdom")
			end
		end)
		local group = "hunt27-kings: " .. client .. ": with the switch off the Greater Blessing is Might"
		local env2 = { client = client, greater = true, bags = { [SYMBOL_OF_KINGS] = 10 },
			classes = { party1 = "WARRIOR", party2 = "WARRIOR", party3 = "WARRIOR", party4 = "MAGE" } }
		session(group, env2, function(ns)
			ns.db.profile.buff.kingsFirst = false
			local cast = groupCast(ns)
			if not (cast and cast.buff.key == "might" and cast.groupCast.spellName == "Greater Blessing of Might") then
				fail(group, "with Kings first off, the warriors' group cast is "
					.. tostring(cast and cast.groupCast.spellName) .. ", not Greater Blessing of Might")
			end
		end)
	end

	-- ---------------------------------------------- a paladin without Kings
	do
		local scenario = "hunt27-kings: " .. client .. ": a paladin who does not know Kings is unchanged"
		local env = { client = client, keys = { "wisdom", "might", "salvation", "light" }, classes = THREE }
		session(scenario, env, function(ns)
			local out = offers(ns, env)
			if not matches(out, { party1 = "might", party2 = "wisdom", party3 = "might" }) then
				fail(scenario, "with Kings not learned, the walk offers " .. said(out) .. ", not Might, Wisdom, Might")
			end
			local named = ns.ResolveBuff(true)
			if not named or named.key ~= "wisdom" then
				fail(scenario, "with Kings not learned, the spell named is " .. tostring(named and named.key))
			end
		end)
	end

	-- --------------------------------------- switched off, pinned elsewhere
	do
		local scenario = "hunt27-kings: " .. client .. ": Kings switched off or another spell pinned"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			ns.db.profile.buff.skip.kings = true
			local out = offers(ns, env)
			if not matches(out, { party1 = "might", party2 = "wisdom", party3 = "might" }) then
				fail(scenario, "with Kings switched off, they are offered " .. said(out) .. ", not Might, Wisdom, Might")
			end
			local named = ns.ResolveBuff(true)
			if not named or named.key ~= "wisdom" then
				fail(scenario, "with Kings switched off, the spell named is " .. tostring(named and named.key))
			end
			ns.db.profile.buff.skip.kings = nil
			ns.db.profile.buff.choice = "might"
			out = offers(ns, env)
			if not matches(out, { party1 = "might", party2 = "might", party3 = "might" }) then
				fail(scenario, "with Might pinned, they are offered " .. said(out) .. ", not Might for all")
			end
			named = ns.ResolveBuff(true)
			if not named or named.key ~= "might" then
				fail(scenario, "with Might pinned, the spell named is " .. tostring(named and named.key))
			end
		end)
	end

	-- ------------------------------------------------------------ Myself
	do
		local scenario = "hunt27-kings: " .. client .. ": Myself is offered Kings first"
		local env = { client = client, alone = true, myself = true, wears = { player = {} } }
		session(scenario, env, function(ns)
			local function mine()
				Mock.advance(4)
				for _, entry in ipairs(ns.BuildQueue()) do
					if entry.reason == "self" then return entry.buff and entry.buff.key or false end
				end
				return false
			end
			if mine() ~= "kings" then
				fail(scenario, "the paladin wearing nothing is offered " .. tostring(mine()) .. " on himself, not Kings")
			end
			ns.db.profile.buff.kingsFirst = false
			if mine() ~= "wisdom" then
				fail(scenario, "with Kings first off he is offered " .. tostring(mine()) .. ", not Wisdom")
			end
		end)
	end

	-- --------------------------------------------- the spell that is named
	do
		local scenario = "hunt27-kings: " .. client .. ": the spell named for the prompt is Kings"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			local named = ns.ResolveBuff(true)
			if not named or named.key ~= "kings" then
				fail(scenario, "the login line and the preview name " .. tostring(named and named.key)
					.. ", not Kings")
			end
			-- What the page says Automatic walks, in the order it walks.
			local note = H.findOption(ns.optionsTable, "autoNote")
			local text = note and type(note.name) == "function" and note.name() or ""
			local k, m = text:find("Blessing of Kings", 1, true), text:find("Blessing of Might", 1, true)
			if not (k and m and k < m) then
				fail(scenario, "Automatic's note does not list Kings ahead of Might: " .. flat(text))
			end
		end)
	end
end

-- ------------------------------------------------------------------ Mists
-- Kings is first in Mists' list already, and Wisdom is gone: the switch means
-- nothing there, so it is not shown, and the walk is the same either way.
do
	local scenario = "hunt27-kings: mists: Kings is first either way, and the switch is not shown"
	local env = { client = "mists", classes = THREE, keys = { "kings", "might" } }
	session(scenario, env, function(ns)
		for _, first in ipairs({ true, false }) do
			ns.db.profile.buff.kingsFirst = first
			local out = offers(ns, env)
			if not matches(out, { party1 = "kings", party2 = "kings", party3 = "kings" }) then
				fail(scenario, "Kings first " .. tostring(first) .. ": offered " .. said(out) .. ", not Kings")
			end
		end
		local kings = ids(ns, "kings")[1]
		env.wears.party1 = { [kings] = THEIRS }
		local out = offers(ns, env)
		if out.party1 ~= "might" then
			fail(scenario, "wearing another paladin's Kings, the warrior is offered " .. tostring(out.party1)
				.. ", not Might")
		end
		if ns.StrongestBuff() ~= nil then
			fail(scenario, "Mists' Kings is marked strongest, though its list begins with it")
		end
		local control = H.findOption(ns.optionsTable, "kingsFirst")
		if not (control and type(control.hidden) == "function") then
			fail(scenario, "SKIPPED -- no Kings first control in the model")
		elseif control.hidden() ~= true then
			fail(scenario, "Mists shows a Kings first switch that changes nothing")
		end
	end)
end

-- ------------------------------------------------------------ the setting
do
	local scenario = "hunt27-kings: the switch is on by default and repaired to on"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		if ns.defaults.profile.buff.kingsFirst ~= true then
			fail(scenario, "Kings first is " .. tostring(ns.defaults.profile.buff.kingsFirst) .. " by default, not on")
		end
		if ns.db.profile.buff.kingsFirst ~= true then
			fail(scenario, "a new profile has Kings first " .. tostring(ns.db.profile.buff.kingsFirst))
		end
		for _, damaged in ipairs({ "yes", 0, {} }) do
			ns.db.profile.buff.kingsFirst = damaged
			ns.ClampSettings()
			if ns.db.profile.buff.kingsFirst ~= true then
				fail(scenario, "a damaged value (" .. type(damaged) .. ") was left as "
					.. tostring(ns.db.profile.buff.kingsFirst) .. ", not put back on")
			end
		end
		ns.db.profile.buff.kingsFirst = false
		ns.ClampSettings()
		if ns.db.profile.buff.kingsFirst ~= false then
			fail(scenario, "a plain off was turned back on by the repair")
		end
	end)
end

for _, client in ipairs(CLIENTS) do
	local scenario = "hunt27-kings: " .. client .. ": the switch is on Who to buff for a paladin"
	local env = { client = client, classes = THREE }
	session(scenario, env, function(ns)
		local control = H.findOption(ns.optionsTable, "kingsFirst")
		if not control then
			fail(scenario, "no Kings first control in the model")
			return
		end
		if control.hidden() ~= false then fail(scenario, "the paladin is not shown the switch") end
		local label = control.name()
		if label ~= "Blessing of Kings first" then
			fail(scenario, "the switch is called " .. tostring(label) .. ", not the client's own spell name and \"first\"")
		end
		if not tostring(control.desc()):find("Blessing of Kings", 1, true) then
			fail(scenario, "the description does not name the spell: " .. tostring(control.desc()))
		end
		if control.get() ~= true then fail(scenario, "the switch does not read on") end
		control.set({ "who", "kingsFirst" }, false)
		if ns.db.profile.buff.kingsFirst ~= false or control.get() ~= false then
			fail(scenario, "the switch does not turn Kings first off")
		end
		-- Off, the walk is as it was, at once.
		local out = offers(ns, env)
		if not matches(out, { party1 = "might", party2 = "wisdom", party3 = "might" }) then
			fail(scenario, "with the switch turned off the walk offers " .. said(out))
		end
		-- And the page's reset puts it back.
		if ns.OptionsPage.ResetPage("who") ~= true or ns.db.profile.buff.kingsFirst ~= true then
			fail(scenario, "the reset of Who to buff left Kings first " .. tostring(ns.db.profile.buff.kingsFirst))
		end
		-- A pin is all that is considered then, so the switch goes while one stands.
		ns.db.profile.buff.choice = "might"
		if control.hidden() ~= true then fail(scenario, "the switch is shown while Might is pinned") end
	end)
end

do
	local scenario = "hunt27-kings: the switch is not shown to another class"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "MAGE"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local control = H.findOption(ns.optionsTable, "kingsFirst")
		if not control then
			fail(scenario, "no Kings first control in a mage's model")
		elseif control.hidden() ~= true then
			fail(scenario, "a mage is shown Blessing of Kings first")
		end
		-- A walk with no strongest buff is the list as it stands, switch on or off.
		for _, first in ipairs({ true, false }) do
			ns.db.profile.buff.kingsFirst = first
			local castable = ns.CastableBuffs()
			if castable[1] and castable[1].key ~= "intellect" then
				fail(scenario, "a mage's list begins with " .. castable[1].key)
			end
		end
	end
	Mock.reset()
end
