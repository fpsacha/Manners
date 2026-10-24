-- The buff order (hunt 29). A player can put a class's buffs in an order of
-- their own -- for a paladin, which blessing is tried first, second and so on --
-- on Who to buff (Options/Who.lua, Options/Window/WidgetsOrder.lua), saved per
-- class in db.buff.order[CLASS] (Core.lua, ns.WalkBuffs). The order is what a
-- person who wears none of your buffs is offered, and what somebody who wears
-- another player's is walked on through; anybody wearing one of yours from the
-- walk is covered whatever the order, so nobody is ever switched from one to
-- another (PickBuffFor reads the whole list before it offers anything). It
-- wins over Blessing of Kings first, which is hidden while an order stands;
-- Back to Automatic puts the walk and the switch back as they were.
--
-- Every scenario name starts with "hunt29-order:" so the mutations in
-- tests/mutations/hunt29-order.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local SYMBOL_OF_KINGS = 21177

-- Kings is third in the list on these, and Wisdom first.
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

-- What each class here has learned, by key.
local LEARNED = {
	PALADIN = { "wisdom", "might", "kings", "salvation", "light" },
	DRUID = { "motw", "thorns" },
	PRIEST = { "fortitude", "spirit", "shadow" },
	MAGE = { "intellect" },
}

local function filed(token)
	local name = PARTY[token]
	return Mock.surnames and (name[1] .. " " .. name[2]) or name[1]
end

local function ids(ns, class, key)
	local buff = ns.FindBuff(class, key)
	return buff and buff.ranks or {}
end

-- One session on `env.client` as `env.class` (a paladin), the others as
-- `env.classes` says (token -> class), carrying `env.wears` (token -> { [spell
-- id] = source }, "player" for what you wear yourself) and `env.left` (token ->
-- seconds left on what they carry). `env.keys` are the buffs known, `env.greater`
-- adds the Greater Blessings of those. body(ns) runs with the lifecycle driven
-- and the slate cleared; `env.setup(ns)` runs on the profile before that.
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.client)
	env.class = env.class or "PALADIN"
	Mock.class = env.class
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
		for _, key in ipairs(env.keys or LEARNED[env.class] or {}) do
			local buff = ns.FindBuff(env.class, key)
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

local function said(out)
	local list = {}
	for token, what in pairs(out) do list[#list + 1] = token .. "=" .. tostring(what) end
	table.sort(list)
	return table.concat(list, ", ")
end

local function matches(out, want)
	for token, what in pairs(want) do
		if out[token] ~= what then return false end
	end
	return true
end

-- A list of buffs, or of keys, as "a, b, c".
local function keys(list)
	local out = {}
	for i, item in ipairs(list or {}) do out[i] = type(item) == "table" and item.key or tostring(item) end
	return table.concat(out, ", ")
end

local function castable(ns) return keys(ns.CastableBuffs()) end

-- Classic Era and Burning Crusade have a sixth blessing, Sanctuary, which a
-- paladin here never learns: it has its place in a saved order and on the page,
-- and is not in the walk.
local function listed(client, text)
	if client == "camelot" then return text end
	return text .. ", sanctuary"
end

-- A list of keys without Sanctuary: what the walk makes of a saved order.
local function learned(list)
	local out = {}
	for _, item in ipairs(list or {}) do
		local key = type(item) == "table" and item.key or item
		if key ~= "sanctuary" then out[#out + 1] = key end
	end
	return table.concat(out, ", ")
end

local function control(ns, key) return H.findOption(ns.optionsTable, key) end

-- A warrior, a mage and a rogue: no mana, mana, no mana.
local THREE = { party1 = "WARRIOR", party2 = "MAGE", party3 = "ROGUE" }

local function setOrder(ns, list) ns.db.profile.buff.order.PALADIN = list end

-- A paladin's list as Automatic walks it with Kings first, and without.
local AUTO_FIRST = "kings, wisdom, might, salvation, light"
local AUTO_PLAIN = "wisdom, might, kings, salvation, light"

for _, client in ipairs(CLIENTS) do
	-- ----------------------------------------------------- what a bare person is offered
	do
		local scenario = "hunt29-order: " .. client .. ": a custom order is what a bare warrior, mage and rogue are offered"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			-- Wisdom first, then Kings, then Might: the warrior and the rogue have
			-- no mana for Wisdom, so they go on to Kings; the mage gets Wisdom.
			setOrder(ns, { "wisdom", "kings", "might", "salvation", "light" })
			if castable(ns) ~= "wisdom, kings, might, salvation, light" then
				fail(scenario, "the walk is " .. castable(ns) .. ", not the order set")
			end
			local out = offers(ns, env)
			if not matches(out, { party1 = "kings", party2 = "wisdom", party3 = "kings" }) then
				fail(scenario, "with Wisdom, Kings, Might the warrior, mage and rogue are offered " .. said(out)
					.. ", not Kings, Wisdom, Kings")
			end
			local top = ns.BuildQueue()[1]
			if top then
				ns.Prompt:ApplyTarget(top)
				local macro = ns.Prompt:GetButton():GetAttribute("macrotext1")
				if not tostring(macro):find("/cast Blessing of " .. (top.buff.key == "wisdom" and "Wisdom" or "Kings"), 1, true) then
					fail(scenario, "the macro does not cast what the queue offers: " .. tostring(macro))
				end
			else
				fail(scenario, "SKIPPED -- nobody is offered anything")
			end
		end)
	end

	do
		local scenario = "hunt29-order: " .. client .. ": a buff first in the order goes to everybody it can"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			setOrder(ns, { "might", "wisdom", "kings", "salvation", "light" })
			local out = offers(ns, env)
			if not matches(out, { party1 = "might", party2 = "might", party3 = "might" }) then
				fail(scenario, "with Might first they are offered " .. said(out) .. ", not Might for all")
			end
			-- The last of the order is what the first of it leaves undone: Light
			-- first goes to all three, Salvation (your group) only to the party.
			setOrder(ns, { "light", "kings", "might", "wisdom", "salvation" })
			out = offers(ns, env)
			if not matches(out, { party1 = "light", party2 = "light", party3 = "light" }) then
				fail(scenario, "with Light first they are offered " .. said(out) .. ", not Light for all")
			end
		end)
	end

	-- ---------------------------------------------------- wins over Kings first
	do
		local scenario = "hunt29-order: " .. client .. ": an order wins over Kings first, on or off"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			for _, first in ipairs({ true, false }) do
				ns.db.profile.buff.kingsFirst = first
				setOrder(ns, { "wisdom", "kings", "might", "salvation", "light" })
				if castable(ns) ~= "wisdom, kings, might, salvation, light" then
					fail(scenario, "Kings first " .. tostring(first) .. ": the walk is " .. castable(ns))
				end
				local out = offers(ns, env)
				if out.party2 ~= "wisdom" then
					fail(scenario, "Kings first " .. tostring(first) .. ": the mage is offered " .. tostring(out.party2)
						.. ", not the Wisdom the order puts ahead of Kings")
				end
				-- And an order that puts Might ahead of Kings keeps it there.
				setOrder(ns, { "might", "kings", "wisdom", "salvation", "light" })
				out = offers(ns, env)
				if out.party1 ~= "might" then
					fail(scenario, "Kings first " .. tostring(first) .. ": the warrior is offered " .. tostring(out.party1)
						.. ", not the Might the order puts ahead of Kings")
				end
			end
		end)
	end

	-- ------------------------------------------------- the one worn is never switched
	do
		local scenario = "hunt29-order: " .. client .. ": a blessing of yours already worn is never switched, whatever the order"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			setOrder(ns, { "wisdom", "kings", "might", "salvation", "light" })
			local might, wisdom, kings = ids(ns, "PALADIN", "might")[1], ids(ns, "PALADIN", "wisdom")[1],
				ids(ns, "PALADIN", "kings")[1]
			-- Might, though the order puts Wisdom and Kings ahead of it; Wisdom;
			-- and a Kings that nobody will name.
			env.wears.party1 = { [might] = OURS }
			env.wears.party2 = { [wisdom] = OURS }
			env.wears.party3 = { [kings] = NOBODY }
			for scan = 1, 5 do
				local out = offers(ns, env)
				if not matches(out, { party1 = false, party2 = false, party3 = false }) then
					fail(scenario, "scan " .. scan .. ": people wearing a blessing of yours were offered " .. said(out)
						.. ", which would replace it")
					return
				end
			end
			-- Running out, with top-ups on: the same blessing again, never the first
			-- of the order.
			ns.db.profile.filters.whenBuffed = "refresh"
			env.left.party1, env.left.party2, env.left.party3 = 100, 100, 100
			local out = offers(ns, env)
			if not matches(out, { party1 = "might", party2 = "wisdom", party3 = "kings" }) then
				fail(scenario, "running out, they were offered " .. said(out)
					.. ", not the blessing they wear (Might, Wisdom, Kings)")
			end
		end)
	end

	-- ------------------------------------------ another paladin's choice is walked on
	do
		local scenario = "hunt29-order: " .. client .. ": another paladin's first choice is walked on to the next"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			setOrder(ns, { "wisdom", "kings", "might", "salvation", "light" })
			local wisdom, kings, might = ids(ns, "PALADIN", "wisdom")[1], ids(ns, "PALADIN", "kings")[1],
				ids(ns, "PALADIN", "might")[1]
			-- The mage has Wisdom from another paladin: on to Kings. The warrior has
			-- Kings from one (Wisdom was never his): on to Might. The rogue has
			-- both of those from one: on to Might as well.
			env.wears.party1 = { [kings] = THEIRS }
			env.wears.party2 = { [wisdom] = THEIRS }
			env.wears.party3 = { [kings] = THEIRS, [wisdom] = THEIRS }
			local out = offers(ns, env)
			if not matches(out, { party1 = "might", party2 = "kings", party3 = "might" }) then
				fail(scenario, "walked on from another paladin's first choice, they are offered " .. said(out)
					.. ", not Might, Kings, Might")
			end
			-- Every blessing of the order from another paladin, Salvation and Light
			-- are what is left.
			env.wears.party2 = { [wisdom] = THEIRS, [kings] = THEIRS, [might] = THEIRS }
			out = offers(ns, env)
			if out.party2 ~= "salvation" then
				fail(scenario, "with Wisdom, Kings and Might from another paladin the mage is offered "
					.. tostring(out.party2) .. ", not Salvation")
			end
		end)
	end

	-- --------------------------------------------------------- Greater Blessings
	do
		local scenario = "hunt29-order: " .. client .. ": Greater Blessings follow the order"
		local env = { client = client, greater = true, bags = { [SYMBOL_OF_KINGS] = 10 },
			classes = { party1 = "WARRIOR", party2 = "WARRIOR", party3 = "WARRIOR", party4 = "MAGE" } }
		session(scenario, env, function(ns)
			-- Automatic, Kings first: Greater Blessing of Kings for the warriors.
			local cast = groupCast(ns)
			if not (cast and cast.groupCast.spellName == "Greater Blessing of Kings") then
				fail(scenario, "SKIPPED -- Automatic's group cast is " .. tostring(cast and cast.groupCast.spellName)
					.. ", not Greater Blessing of Kings")
				return
			end
			-- Might first: the warriors get Greater Blessing of Might, the mage a single one.
			setOrder(ns, { "might", "kings", "wisdom", "salvation", "light" })
			cast = groupCast(ns)
			if not (cast and cast.buff.key == "might" and cast.groupCast.spellName == "Greater Blessing of Might"
				and cast.groupCast.class == "WARRIOR") then
				fail(scenario, "with Might first the warriors' group cast is "
					.. tostring(cast and cast.groupCast.spellName) .. ", not Greater Blessing of Might")
			end
			local _, byName = offers(ns, env)
			local mage = byName[filed("party4")]
			if not (mage and mage.buff.key == "might" and not mage.groupCast) then
				fail(scenario, "the one mage is not left a single Blessing of Might")
			end
			-- Wisdom first: the warriors have no mana for it, so theirs is Kings.
			setOrder(ns, { "wisdom", "kings", "might", "salvation", "light" })
			cast = groupCast(ns)
			if not (cast and cast.buff.key == "kings" and cast.groupCast.spellName == "Greater Blessing of Kings") then
				fail(scenario, "with Wisdom first the warriors' group cast is "
					.. tostring(cast and cast.groupCast.spellName) .. ", not Greater Blessing of Kings")
			end
		end)
	end

	-- ------------------------------------------------------- the spell that is named
	do
		local scenario = "hunt29-order: " .. client .. ": the spell named for the prompt is the first of the order"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			setOrder(ns, { "might", "wisdom", "kings", "salvation", "light" })
			local named = ns.ResolveBuff(true)
			if not named or named.key ~= "might" then
				fail(scenario, "with Might first the login line names " .. tostring(named and named.key))
			end
			-- Wisdom first, but only a mana user has any use for it.
			setOrder(ns, { "wisdom", "might", "kings", "salvation", "light" })
			named = ns.ResolveBuff(true)
			if not named or named.key ~= "wisdom" then
				fail(scenario, "with Wisdom first the login line names " .. tostring(named and named.key))
			end
			named = ns.ResolveBuff(false)
			if not named or named.key ~= "might" then
				fail(scenario, "with Wisdom first, for somebody with no mana, the spell named is "
					.. tostring(named and named.key) .. ", not Might")
			end
			-- Switched off or not learned: left out, as in the walk.
			ns.db.profile.buff.skip.wisdom = true
			named = ns.ResolveBuff(true)
			if not named or named.key ~= "might" then
				fail(scenario, "with Wisdom switched off the spell named is " .. tostring(named and named.key))
			end
			ns.db.profile.buff.skip.wisdom = nil
			-- Pinned: the pin, as ever.
			ns.db.profile.buff.choice = "light"
			named = ns.ResolveBuff(true)
			if not named or named.key ~= "light" then
				fail(scenario, "with Light pinned the spell named is " .. tostring(named and named.key))
			end
			ns.db.profile.buff.choice = "auto"
			-- What the page says Automatic walks, in the order it walks.
			local note = control(ns, "autoNote")
			local text = note and type(note.name) == "function" and note.name() or ""
			local w, m = text:find("Blessing of Wisdom", 1, true), text:find("Blessing of Might", 1, true)
			local k = text:find("Blessing of Kings", 1, true)
			if not (w and m and k and w < m and m < k) then
				fail(scenario, "Automatic's note does not list Wisdom, Might, Kings in that order: " .. text)
			end
		end)
	end

	-- ---------------------------------------------------------- Back to Automatic
	for _, first in ipairs({ true, false }) do
		local scenario = "hunt29-order: " .. client .. ": Back to Automatic restores the walk exactly"
			.. (first and "" or " (Kings first off)")
		local env = { client = client, classes = THREE, greater = true, bags = { [SYMBOL_OF_KINGS] = 10 } }
		session(scenario, env, function(ns)
			ns.db.profile.buff.kingsFirst = first
			local before = castable(ns)
			local offersBefore = offers(ns, env)
			if before ~= (first and AUTO_FIRST or AUTO_PLAIN) then
				fail(scenario, "Automatic's walk is " .. before .. ", not " .. (first and AUTO_FIRST or AUTO_PLAIN))
			end
			local up, reset = control(ns, "orderUp"), control(ns, "orderReset")
			local pick = control(ns, "orderPick")
			if not (up and reset and pick) then
				fail(scenario, "no Buff order controls in the model")
				return
			end
			if reset.hidden() ~= true then fail(scenario, "Back to Automatic is shown while nothing has been moved") end
			-- Move Might to the top, then Light.
			pick.set({ "who", "orderPick" }, "might")
			up.func()
			pick.set({ "who", "orderPick" }, "light")
			up.func()
			up.func()
			up.func()
			if not ns.HasBuffOrder() then fail(scenario, "moving buffs left no order") end
			if castable(ns) == before then fail(scenario, "the walk did not change: " .. castable(ns)) end
			if reset.hidden() ~= false then fail(scenario, "Back to Automatic is not shown over an order") end
			reset.func()
			if ns.HasBuffOrder() or ns.db.profile.buff.order.PALADIN ~= nil then
				fail(scenario, "Back to Automatic left an order: " .. keys(ns.db.profile.buff.order.PALADIN))
			end
			if castable(ns) ~= before then
				fail(scenario, "after Back to Automatic the walk is " .. castable(ns) .. ", not " .. before)
			end
			local out = offers(ns, env)
			if said(out) ~= said(offersBefore) then
				fail(scenario, "after Back to Automatic they are offered " .. said(out) .. ", not " .. said(offersBefore))
			end
			if ns.db.profile.buff.kingsFirst ~= first then
				fail(scenario, "Back to Automatic changed Kings first to " .. tostring(ns.db.profile.buff.kingsFirst))
			end
			if reset.hidden() ~= true then fail(scenario, "Back to Automatic is still shown with no order") end
			local named = ns.ResolveBuff(true)
			if not named or named.key ~= (first and "kings" or "wisdom") then
				fail(scenario, "after Back to Automatic the spell named is " .. tostring(named and named.key))
			end
		end)
	end

	-- ------------------------------------------------------- the Kings switch
	do
		local scenario = "hunt29-order: " .. client .. ": the Kings switch is hidden while an order stands and comes back"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			local toggle = control(ns, "kingsFirst")
			if not toggle then
				fail(scenario, "no Kings first control in the model")
				return
			end
			if toggle.hidden() ~= false then fail(scenario, "the paladin is not shown the switch to begin with") end
			ns.db.profile.buff.kingsFirst = false
			control(ns, "orderPick").set({ "who", "orderPick" }, "kings")
			control(ns, "orderUp").func()
			if toggle.hidden() ~= true then fail(scenario, "the Kings switch is shown over an order of the player's own") end
			control(ns, "orderReset").func()
			if toggle.hidden() ~= false then fail(scenario, "Back to Automatic did not bring the Kings switch back") end
			if toggle.get() ~= false then fail(scenario, "the switch came back reading " .. tostring(toggle.get()) .. ", not as it was left (off)") end
			-- A pin hides it as before, with or without an order.
			ns.db.profile.buff.choice = "might"
			if toggle.hidden() ~= true then fail(scenario, "the switch is shown while Might is pinned") end
		end)
	end

	-- ----------------------------------------------------------- the ends
	do
		local scenario = "hunt29-order: " .. client .. ": up at the top and down at the bottom do nothing"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			local order = ns.BuffWalkOrder()
			local top, bottom = order[1].key, order[#order].key
			if ns.MoveBuff(top, -1) ~= false then fail(scenario, "the first buff moved up") end
			if ns.MoveBuff(bottom, 1) ~= false then fail(scenario, "the last buff moved down") end
			if ns.HasBuffOrder() then fail(scenario, "a move that did nothing left an order: " .. keys(ns.BuffOrder())) end
			if ns.MoveBuff("bogus", 1) ~= false then fail(scenario, "a buff nobody has moved") end
			-- With an order set: the same, and the order is left exactly as it was.
			ns.MoveBuff("light", -1)
			local was = keys(ns.BuffOrder())
			local first = ns.BuffOrder()[1]
			if ns.MoveBuff(first, -1) ~= false then fail(scenario, "the first of an order moved up") end
			local last = ns.BuffOrder()[#ns.BuffOrder()]
			if ns.MoveBuff(last, 1) ~= false then fail(scenario, "the last of an order moved down") end
			if keys(ns.BuffOrder()) ~= was then
				fail(scenario, "moves that did nothing changed the order from " .. was .. " to " .. keys(ns.BuffOrder()))
			end
			-- And the buttons of the old dialog, with the first one picked.
			local pick, up, down = control(ns, "orderPick"), control(ns, "orderUp"), control(ns, "orderDown")
			pick.set({ "who", "orderPick" }, ns.BuffOrder()[1])
			if up.disabled() ~= true then fail(scenario, "Move up is not greyed out for the first buff") end
			if down.disabled() ~= false then fail(scenario, "Move down is greyed out for the first buff") end
			up.func()
			if keys(ns.BuffOrder()) ~= was then fail(scenario, "Move up on the first buff changed the order") end
			pick.set({ "who", "orderPick" }, ns.BuffOrder()[#ns.BuffOrder()])
			if down.disabled() ~= true then fail(scenario, "Move down is not greyed out for the last buff") end
			if up.disabled() ~= false then fail(scenario, "Move up is greyed out for the last buff") end
			down.func()
			if keys(ns.BuffOrder()) ~= was then fail(scenario, "Move down on the last buff changed the order") end
		end)
	end

	-- ------------------------------------------------------------ moving one
	for _, first in ipairs({ true, false }) do
		local scenario = "hunt29-order: " .. client .. ": a move swaps two places and an order that is Automatic's is not kept"
			.. (first and "" or " (Kings first off)")
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			ns.db.profile.buff.kingsFirst = first
			local auto = first and AUTO_FIRST or AUTO_PLAIN
			if ns.BuffOrder() ~= nil then fail(scenario, "a new profile has an order") end
			-- Wisdom up one place: over Kings, or (switch off) it is first already.
			local moved = ns.MoveBuff("might", -1)
			if first then
				-- kings, wisdom, might ...  ->  kings, might, wisdom ...
				if not moved or keys(ns.BuffOrder()) ~= listed(client, "kings, might, wisdom, salvation, light") then
					fail(scenario, "Might up from Automatic's third place gave " .. keys(ns.BuffOrder()))
				end
			else
				if not moved or keys(ns.BuffOrder()) ~= listed(client, "might, wisdom, kings, salvation, light") then
					fail(scenario, "Might up from Automatic's second place gave " .. keys(ns.BuffOrder()))
				end
			end
			-- Straight back: that is Automatic's own walk, so nothing is kept.
			if not ns.MoveBuff("might", 1) then fail(scenario, "Might would not move back down") end
			if ns.HasBuffOrder() or ns.db.profile.buff.order.PALADIN ~= nil then
				fail(scenario, "the order that came back to Automatic's (" .. auto .. ") was kept as " .. keys(ns.BuffOrder()))
			end
			-- Down from the top, then to the bottom, one step at a time.
			local count = #ns.BuffWalkOrder()
			local top = ns.BuffWalkOrder()[1].key
			for _ = 1, count - 1 do
				if not ns.MoveBuff(top, 1) then fail(scenario, "the first buff would not move down a place") end
			end
			local want = {}
			for _, buff in ipairs(ns.BuffWalkOrder()) do want[#want + 1] = buff.key end
			if want[#want] ~= top then fail(scenario, top .. " moved down to the bottom is not last: " .. keys(want)) end
			if #want ~= count then fail(scenario, "a move changed how many buffs there are: " .. keys(want)) end
			-- Everything is in the saved order, so that a buff learned later has a place.
			local saved = ns.BuffOrder()
			if not saved or #saved ~= count then fail(scenario, "the saved order is " .. keys(saved) .. ", not all " .. count) end
			-- The walk is the saved order's learned buffs.
			if castable(ns) ~= learned(saved) then fail(scenario, "the walk is " .. castable(ns) .. ", not the saved " .. keys(saved)) end
		end)
	end

	-- ------------------------------------------------- saved, and survives a reload
	do
		local scenario = "hunt29-order: " .. client .. ": the order is saved and survives a reload"
		local env = { client = client, classes = THREE }
		session(scenario, env, function(ns)
			control(ns, "orderPick").set({ "who", "orderPick" }, "light")
			for _ = 1, 3 do control(ns, "orderUp").func() end
			local want = keys(ns.BuffOrder())
			if not ns.BuffOrder() then
				fail(scenario, "no order after three moves")
				return
			end
			-- The saved profile holds it: a list of keys under the class.
			local saved = Mock.sv.profile.buff.order and Mock.sv.profile.buff.order.PALADIN
			if keys(saved) ~= want then
				fail(scenario, "the saved profile holds " .. keys(saved) .. ", not " .. want)
			end
			-- The addon loaded again over the same file, as a reload does.
			local again = load(scenario)
			if not again then return end
			H.freshPrompt(again, scenario)
			if keys(again.db.profile.buff.order.PALADIN) ~= want then
				fail(scenario, "after a reload the order is " .. keys(again.db.profile.buff.order.PALADIN) .. ", not " .. want)
			end
			if not again.HasBuffOrder() then fail(scenario, "after a reload the profile has no order") end
			if keys(again.WalkBuffs()) ~= want then
				fail(scenario, "after a reload the walk is " .. keys(again.WalkBuffs()) .. ", not " .. want)
			end
		end)
	end
end

-- ------------------------------------------------------------------ Mists
-- Kings, then Might, are all a Mists paladin has: an order puts Might first.
do
	local scenario = "hunt29-order: mists: Might first, then Kings"
	local env = { client = "mists", classes = THREE, keys = { "kings", "might" } }
	session(scenario, env, function(ns)
		local out = offers(ns, env)
		if not matches(out, { party1 = "kings", party2 = "kings", party3 = "kings" }) then
			fail(scenario, "Automatic offers " .. said(out) .. ", not Kings")
		end
		setOrder(ns, { "might", "kings" })
		if castable(ns) ~= "might, kings" then fail(scenario, "the walk is " .. castable(ns)) end
		out = offers(ns, env)
		if not matches(out, { party1 = "might", party2 = "might", party3 = "might" }) then
			fail(scenario, "with Might first they are offered " .. said(out) .. ", not Might")
		end
		-- Another paladin's Might: on to Kings. One of yours never switched.
		local might, kings = ids(ns, "PALADIN", "might")[1], ids(ns, "PALADIN", "kings")[1]
		env.wears.party1 = { [might] = THEIRS }
		env.wears.party2 = { [kings] = OURS }
		out = offers(ns, env)
		if not matches(out, { party1 = "kings", party2 = false, party3 = "might" }) then
			fail(scenario, "with another paladin's Might on the warrior and yours on the mage's Kings, they are offered "
				.. said(out) .. ", not Kings, nothing, Might")
		end
		-- The list the page draws: two lines, and no Kings switch (its list begins with Kings).
		local order = ns.BuffWalkOrder()
		if keys(order) ~= "might, kings" then fail(scenario, "the page lists " .. keys(order)) end
		if control(ns, "orderPick").hidden() ~= false then fail(scenario, "Mists' two blessings are not shown the order") end
		if control(ns, "kingsFirst").hidden() ~= true then fail(scenario, "Mists shows a Kings switch") end
	end)
end

-- ------------------------------------------------------- druids and priests
do
	local scenario = "hunt29-order: druid: the order applies to Mark of the Wild and Thorns"
	local env = { client = "camelot", class = "DRUID", classes = THREE }
	session(scenario, env, function(ns)
		local out = offers(ns, env)
		if not matches(out, { party1 = "motw", party2 = "motw", party3 = "motw" }) then
			fail(scenario, "Automatic offers " .. said(out) .. ", not Mark of the Wild")
		end
		if not ns.MoveBuff("thorns", -1) then fail(scenario, "Thorns would not move up") end
		if keys(ns.BuffOrder()) ~= "thorns, motw" then
			fail(scenario, "the druid's order is " .. keys(ns.BuffOrder()))
		end
		out = offers(ns, env)
		if not matches(out, { party1 = "thorns", party2 = "thorns", party3 = "thorns" }) then
			fail(scenario, "with Thorns first they are offered " .. said(out) .. ", not Thorns")
		end
		-- Wearing Thorns of yours the first goes on to what they lack; wearing Mark
		-- of the Wild they are offered Thorns, the first of the order.
		local thorns, motw = ids(ns, "DRUID", "thorns")[1], ids(ns, "DRUID", "motw")[1]
		env.wears.party1 = { [thorns] = OURS }
		env.wears.party2 = { [motw] = OURS }
		env.wears.party3 = { [thorns] = OURS, [motw] = OURS }
		out = offers(ns, env)
		if not matches(out, { party1 = "motw", party2 = "thorns", party3 = false }) then
			fail(scenario, "walked down the druid's order they are offered " .. said(out)
				.. ", not Mark of the Wild, Thorns, nothing")
		end
		local named = ns.ResolveBuff(true)
		if not named or named.key ~= "thorns" then
			fail(scenario, "the druid's login line names " .. tostring(named and named.key) .. ", not Thorns")
		end
	end)
end

do
	local scenario = "hunt29-order: priest: the order applies to Fortitude, Spirit and Shadow Protection"
	local env = { client = "camelot", class = "PRIEST", classes = THREE }
	session(scenario, env, function(ns)
		-- Spirit first: only a mana user has any use for it, so the mage is offered
		-- it and the warrior and the rogue go on to Fortitude.
		if not ns.MoveBuff("spirit", -1) then fail(scenario, "Spirit would not move up") end
		if keys(ns.BuffOrder()) ~= "spirit, fortitude, shadow" then
			fail(scenario, "the priest's order is " .. keys(ns.BuffOrder()))
		end
		local out = offers(ns, env)
		if not matches(out, { party1 = "fortitude", party2 = "spirit", party3 = "fortitude" }) then
			fail(scenario, "with Spirit first they are offered " .. said(out) .. ", not Fortitude, Spirit, Fortitude")
		end
		-- Shadow Protection to the top: all three.
		ns.MoveBuff("shadow", -1)
		ns.MoveBuff("shadow", -1)
		out = offers(ns, env)
		if not matches(out, { party1 = "shadow", party2 = "shadow", party3 = "shadow" }) then
			fail(scenario, "with Shadow Protection first they are offered " .. said(out) .. ", not Shadow Protection")
		end
		-- Fortitude of yours worn: the walk goes on to what they lack.
		env.wears.party1 = { [ids(ns, "PRIEST", "shadow")[1]] = OURS }
		out = offers(ns, env)
		if out.party1 ~= "fortitude" then
			fail(scenario, "the warrior wearing your Shadow Protection is offered " .. tostring(out.party1)
				.. ", not Fortitude, the next of the order")
		end
	end)
end

-- ------------------------------------------------------------------ the repair
do
	local scenario = "hunt29-order: a damaged order is repaired"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		local profile = ns.db.profile
		local function repaired(list, kingsFirst)
			profile.buff.kingsFirst = kingsFirst ~= false
			profile.buff.order = { PALADIN = list }
			ns.ClampSettings()
			return profile.buff.order.PALADIN
		end
		-- A key no client has, a key twice and something that is no key at all go;
		-- the buffs left out follow in Automatic's order, Kings first with the
		-- switch on.
		local got = repaired({ "light", "bogus", "light", 42, "might", false }, true)
		if keys(got) ~= "light, might, kings, wisdom, salvation" then
			fail(scenario, "{light, bogus, light, 42, might, false} was repaired to " .. keys(got)
				.. ", not light, might, kings, wisdom, salvation")
		end
		got = repaired({ "light", "bogus", "light", 42, "might", false }, false)
		if keys(got) ~= "light, might, wisdom, kings, salvation" then
			fail(scenario, "with Kings first off the same order was repaired to " .. keys(got)
				.. ", not light, might, wisdom, kings, salvation")
		end
		-- Sanctuary is a vanilla buff and this is Forever: kept for the client
		-- that has it, and skipped by the walk.
		got = repaired({ "sanctuary", "kings", "might", "wisdom", "salvation", "light" }, true)
		if keys(got) ~= "sanctuary, kings, might, wisdom, salvation, light" then
			fail(scenario, "another client's Sanctuary was repaired to " .. keys(got) .. ", not kept first")
		end
		if castable(ns) ~= "kings, might, wisdom, salvation, light" then
			fail(scenario, "the walk with Sanctuary first is " .. castable(ns) .. ", which should skip it")
		end
		local named = ns.ResolveBuff(true)
		if not named or named.key ~= "kings" then
			fail(scenario, "with Sanctuary first the spell named is " .. tostring(named and named.key))
		end
		-- An order with nothing left in it, or no list at all, is no order.
		for _, damaged in ipairs({ {}, { "bogus", 7 }, "banana", 12, true }) do
			got = repaired(damaged, true)
			if got ~= nil then
				fail(scenario, "a damaged order of " .. type(damaged) .. " (" .. keys(type(damaged) == "table" and damaged or {})
					.. ") was kept as " .. keys(got))
			end
		end
		-- Neither a class nobody has buffs for, nor a class's keys on another class.
		profile.buff.order = { HUNTER = { "might" }, WARLOCK = { "xyz" }, PRIEST = { "spirit", "fortitude" },
			PALADIN = { "might", "kings" } }
		ns.ClampSettings()
		if profile.buff.order.HUNTER ~= nil then fail(scenario, "a hunter's order was kept") end
		if profile.buff.order.WARLOCK ~= nil then fail(scenario, "a warlock's order of nothing known was kept") end
		if keys(profile.buff.order.PRIEST) ~= "spirit, fortitude, shadow" then
			fail(scenario, "the priest's order was repaired to " .. keys(profile.buff.order.PRIEST))
		end
		if keys(profile.buff.order.PALADIN) ~= "might, kings, wisdom, salvation, light" then
			fail(scenario, "the paladin's order was repaired to " .. keys(profile.buff.order.PALADIN))
		end
		-- The order table itself, not a table.
		for _, damaged in ipairs({ "yes", 0, true }) do
			profile.buff.order = damaged
			ns.ClampSettings()
			if type(profile.buff.order) ~= "table" or next(profile.buff.order) ~= nil then
				fail(scenario, "a damaged order table (" .. type(damaged) .. ") was left as " .. tostring(profile.buff.order))
			end
		end
		-- One that is sound is left alone: the same table, not a copy.
		local sound = { "might", "kings", "wisdom", "salvation", "light" }
		profile.buff.order = { PALADIN = sound }
		ns.ClampSettings()
		if profile.buff.order.PALADIN ~= sound then fail(scenario, "a sound order was rewritten") end
	end)
end

do
	local scenario = "hunt29-order: an order saved on another client keeps its keys and skips the ones this client lacks"
	local env = { client = "mists", classes = THREE, keys = { "kings", "might" } }
	session(scenario, env, function(ns)
		local profile = ns.db.profile
		-- Saved on Classic Era: six blessings, Might first.
		profile.buff.order = { PALADIN = { "might", "wisdom", "kings", "salvation", "light", "sanctuary" } }
		ns.ClampSettings()
		if keys(profile.buff.order.PALADIN) ~= "might, wisdom, kings, salvation, light, sanctuary" then
			fail(scenario, "Mists dropped the other client's keys: " .. keys(profile.buff.order.PALADIN))
		end
		if castable(ns) ~= "might, kings" then fail(scenario, "the Mists walk is " .. castable(ns) .. ", not might, kings") end
		-- The page lists what this client has, in the saved order.
		if keys(ns.BuffWalkOrder()) ~= "might, kings" then fail(scenario, "the page lists " .. keys(ns.BuffWalkOrder())) end
		-- A move here goes among the two it has, and leaves the others where they are.
		if not ns.MoveBuff("kings", -1) then fail(scenario, "Kings would not move up on Mists") end
		if keys(profile.buff.order.PALADIN) ~= "kings, wisdom, might, salvation, light, sanctuary" then
			fail(scenario, "moving Kings up changed the saved order to " .. keys(profile.buff.order.PALADIN)
				.. ", not kings, wisdom, might, salvation, light, sanctuary")
		end
		if castable(ns) ~= "kings, might" then fail(scenario, "after the move the walk is " .. castable(ns)) end
	end)
end

-- ------------------------------------------------------------------ the controls
do
	local scenario = "hunt29-order: the controls are for a class with a choice and no spell pinned"
	local five = { "orderHeader", "orderNote", "orderPick", "orderUp", "orderDown", "orderReset" }
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		for _, key in ipairs({ "orderHeader", "orderNote", "orderPick", "orderUp", "orderDown" }) do
			local c = control(ns, key)
			if not c then
				fail(scenario, "no " .. key .. " in the paladin's model")
			elseif c.hidden() ~= false then
				fail(scenario, "the paladin is not shown " .. key)
			end
		end
		local reset = control(ns, "orderReset")
		if not reset or reset.hidden() ~= true then fail(scenario, "Back to Automatic is shown before anything is moved") end
		-- Pinned: all that is considered is the one spell.
		ns.db.profile.buff.choice = "might"
		for _, key in ipairs(five) do
			local c = control(ns, key)
			if c and c.hidden() ~= true then fail(scenario, key .. " is shown while Might is pinned") end
		end
		-- And the name of the section, the buttons' words and the spell names as the client has them.
		ns.db.profile.buff.choice = "auto"
		local pick = control(ns, "orderPick")
		local values = pick.values()
		if values.kings ~= "Blessing of Kings" or not tostring(values.wisdom):find("Blessing of Wisdom", 1, true) then
			fail(scenario, "the list's names are not the client's own spell names: " .. tostring(values.kings))
		end
		if control(ns, "orderUp").name ~= "Move up" or control(ns, "orderDown").name ~= "Move down"
			or reset.name ~= "Back to Automatic" or control(ns, "orderHeader").name ~= "Buff order" then
			fail(scenario, "the controls' words are " .. tostring(control(ns, "orderUp").name) .. ", "
				.. tostring(control(ns, "orderDown").name) .. ", " .. tostring(reset.name))
		end
		-- The caption says whose order it is.
		local note = control(ns, "orderNote")
		local text = note.name()
		if not text:find("Following Automatic's order, with Blessing of Kings first.", 1, true) then
			fail(scenario, "Automatic's caption is " .. text)
		end
		ns.db.profile.buff.kingsFirst = false
		if not note.name():find("Following Automatic's order.", 1, true) then
			fail(scenario, "with Kings first off the caption is " .. note.name())
		end
		ns.MoveBuff("light", -1)
		if not note.name():find("Your own order is in use.", 1, true) then
			fail(scenario, "over an order of the player's own the caption is " .. note.name())
		end
	end)
end

do
	local scenario = "hunt29-order: the controls are not shown to a class with one buff"
	local env = { client = "camelot", class = "MAGE", classes = THREE }
	session(scenario, env, function(ns)
		for _, key in ipairs({ "orderHeader", "orderNote", "orderPick", "orderUp", "orderDown", "orderReset" }) do
			local c = control(ns, key)
			if not c then
				fail(scenario, "no " .. key .. " in a mage's model")
			elseif c.hidden() ~= true then
				fail(scenario, "a mage is shown " .. key)
			end
		end
		-- A walk with one buff is that buff, order or not.
		if castable(ns) ~= "intellect" then fail(scenario, "a mage's walk is " .. castable(ns)) end
		if ns.MoveBuff("intellect", -1) ~= false then fail(scenario, "a mage's only buff moved") end
	end)
end

do
	local scenario = "hunt29-order: the controls are placed once, in the window's Who to buff"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		ns.OpenOptions("who")
		local UI = ns.WindowUI
		local at
		for _, key in ipairs({ "orderHeader", "orderNote", "orderPick", "orderUp", "orderDown", "orderReset" }) do
			local w = UI.Where("who." .. key)
			if key == "orderHeader" then
				-- A section's header is its title, placed as header=, not as an item.
				if not (w == nil or w.page == "who") then fail(scenario, key .. " is on " .. tostring(w.page)) end
			elseif not w then
				fail(scenario, "who." .. key .. " has no place in the window")
			else
				if w.page ~= "who" then fail(scenario, "who." .. key .. " is placed on " .. tostring(w.page)) end
				at = at or w.e
				if w.e ~= at then fail(scenario, "who." .. key .. " is not drawn with the rest of the order list") end
			end
		end
		if not (at and at.kind == "order") then fail(scenario, "the list is a " .. tostring(at and at.kind) .. ", not an order list") end
		if not UI.RowShown("who.orderPick") then fail(scenario, "the order list is not shown on Who to buff") end
	end)
end

do
	local scenario = "hunt29-order: the page's reset takes the order away"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		ns.db.profile.buff.kingsFirst = false
		ns.MoveBuff("light", -1)
		if not ns.HasBuffOrder() then fail(scenario, "no order to reset") end
		if ns.OptionsPage.ResetPage("who") ~= true then fail(scenario, "the reset of Who to buff did not run") end
		if ns.HasBuffOrder() or next(ns.db.profile.buff.order) ~= nil then
			fail(scenario, "the reset of Who to buff left the order " .. keys(ns.db.profile.buff.order.PALADIN))
		end
		if ns.db.profile.buff.kingsFirst ~= true then fail(scenario, "the reset left Kings first off") end
		if castable(ns) ~= AUTO_FIRST then fail(scenario, "after the reset the walk is " .. castable(ns)) end
	end)
end

do
	local scenario = "hunt29-order: a new profile has no order, and the default is a table for the classes"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		local default = ns.defaults.profile.buff.order
		if type(default) ~= "table" or next(default) ~= nil then
			fail(scenario, "the default order is " .. tostring(default) .. ", not an empty table")
		end
		if type(ns.db.profile.buff.order) ~= "table" or ns.BuffOrder() ~= nil then
			fail(scenario, "a new profile has an order")
		end
		-- Shared as text, as a table of its own kind (hunt34 fixes B: the empty
		-- default gave the walk of the defaults nothing to find, so it never
		-- travelled): an exported string names the player's order, and the
		-- player's own string imported leaves the order where it is.
		ns.MoveBuff("light", -1)
		local want = keys(ns.BuffOrder())
		local text = ns.ExportSettings()
		if not (text and text:find("buff.order=PALADIN=", 1, true)) then
			fail(scenario, "an exported string does not name the order: " .. tostring(text))
		end
		local ok = ns.ImportSettings(text)
		if ok ~= true then fail(scenario, "the player's own string would not import") end
		if keys(ns.BuffOrder()) ~= want then
			fail(scenario, "importing a string changed the order to " .. keys(ns.BuffOrder()) .. ", not " .. want)
		end
	end)
end

-- ------------------------------------------------ an order nobody has repaired
do
	local scenario = "hunt29-order: the walk reads an order nobody has repaired"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		-- A key twice, one no client has, a number, a key only Classic Era has
		-- and three of this client's buffs left out: each of this client's buffs
		-- once, in the order given, and the ones left out after them in the set's
		-- order. Nothing throws, and nothing is rewritten.
		local given = { "light", "bogus", "light", 42, "sanctuary", "might" }
		setOrder(ns, given)
		if keys(ns.WalkBuffs()) ~= "light, might, wisdom, kings, salvation" then
			fail(scenario, "the walk is " .. keys(ns.WalkBuffs()) .. ", not light, might, wisdom, kings, salvation")
		end
		if castable(ns) ~= "light, might, wisdom, kings, salvation" then
			fail(scenario, "what can be cast is " .. castable(ns))
		end
		if ns.db.profile.buff.order.PALADIN ~= given or #given ~= 6 then
			fail(scenario, "reading the order rewrote it")
		end
		local out = offers(ns, env)
		if not matches(out, { party1 = "light", party2 = "light", party3 = "light" }) then
			fail(scenario, "with Light first they are offered " .. said(out))
		end
	end)
end

do
	local scenario = "hunt29-order: a pinned spell wins over an order"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		setOrder(ns, { "wisdom", "kings", "might", "salvation", "light" })
		ns.db.profile.buff.choice = "might"
		local out = offers(ns, env)
		if not matches(out, { party1 = "might", party2 = "might", party3 = "might" }) then
			fail(scenario, "with Might pinned over an order that starts with Wisdom they are offered " .. said(out))
		end
		-- And the order is still there for when the pin goes.
		ns.db.profile.buff.choice = "auto"
		out = offers(ns, env)
		if out.party2 ~= "wisdom" then
			fail(scenario, "after the pin the mage is offered " .. tostring(out.party2) .. ", not Wisdom")
		end
	end)
end

-- ----------------------------------------------------- read, not rebuilt, per scan
do
	local scenario = "hunt29-order: the ordered list is read on every scan and rebuilt only when the order changes"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		local base = ns.WalkBuffs()
		if base ~= ns.GetClassBuffs("PALADIN") then fail(scenario, "with no order the walk is not the class's own list") end
		ns.MoveBuff("light", -1)
		local first = ns.WalkBuffs()
		if keys(first) ~= "kings, wisdom, might, light, salvation" then
			fail(scenario, "the ordered list is " .. keys(first))
		end
		-- Scan after scan: the same table, not one built each time.
		for _ = 1, 20 do ns.CastableBuffs() end
		if ns.WalkBuffs() ~= first then fail(scenario, "the ordered list was rebuilt although the order did not change") end
		-- Changed in place -- a hand edit, a pasted profile, the page's reset
		-- wiping the table -- it is read again at the next scan.
		local saved = ns.BuffOrder()
		saved[1], saved[2] = saved[2], saved[1]
		if keys(ns.WalkBuffs()) ~= "wisdom, kings, might, light, salvation" then
			fail(scenario, "an order edited in place is still read as " .. keys(ns.WalkBuffs()))
		end
		saved[#saved] = nil
		if keys(ns.WalkBuffs()) ~= "wisdom, kings, might, light, salvation" then
			fail(scenario, "an order cut short is read as " .. keys(ns.WalkBuffs()) .. ", with its missing buff after it")
		end
		wipe(saved)
		if ns.WalkBuffs() ~= base then fail(scenario, "an emptied order is not read as Automatic") end
		-- What a scan costs: the same with an order as without. CastableBuffs makes
		-- its answer (one table) either way; the ordered list adds nothing to it.
		local function cost()
			collectgarbage("collect")
			collectgarbage("stop")
			local before = collectgarbage("count")
			for _ = 1, 400 do ns.CastableBuffs() end
			local used = collectgarbage("count") - before
			collectgarbage("restart")
			return used
		end
		local without = cost()
		ns.MoveBuff("light", -1)
		local with = cost()
		if with > without * 1.05 + 1 then
			fail(scenario, ("400 scans allocate %.1f KB with an order and %.1f KB without"):format(with, without))
		end
	end)
end

-- ------------------------------------------------------------------ in a fight
do
	local scenario = "hunt29-order: a change made in a fight is taken, and the next scan walks the new order"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		ns.OpenOptions("who")
		local UI = ns.WindowUI
		Mock.inCombat = true
		local row = UI.RowFor("who.orderPick")
		if not (row and row.lines and row.lines[3]) then
			Mock.inCombat = false
			fail(scenario, "SKIPPED -- no order list on Who to buff")
			return
		end
		local ok, err = pcall(function() row.lines[3].up:GetScript("OnClick")(row.lines[3].up, "LeftButton", false) end)
		Mock.inCombat = false
		if not ok then fail(scenario, "an arrow pressed in a fight threw: " .. tostring(err)) end
		if keys(ns.BuffOrder()) ~= "kings, might, wisdom, salvation, light" then
			fail(scenario, "the order after a press in a fight is " .. keys(ns.BuffOrder()))
		end
		ns.addon:Tick()
		if castable(ns) ~= "kings, might, wisdom, salvation, light" then
			fail(scenario, "the walk after it is " .. castable(ns))
		end
	end)
end

-- ------------------------------------------------------------------ the window
-- The list is one row drawn from five definitions (WidgetsOrder.lua): a line
-- for each buff in the order they are tried, each with the spell's icon, its
-- place and its name, an arrow up and one down (greyed at the ends), the first
-- the walk can use set apart, and the way back to Automatic under it.
local function press(button)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, "LeftButton", false) end
end

local function windowOrder(ns)
	ns.OpenOptions("who")
	ns.Prompt:ExitTest()
	local UI = ns.WindowUI
	local row = UI.RowFor("who.orderPick")
	if not (row and row.lines and UI.RowShown("who.orderPick")) then return nil, UI end
	return row, UI
end

for _, client in ipairs(CLIENTS) do
	local scenario = "hunt29-order: " .. client .. ": the window draws a line for each buff, in order"
	local env = { client = client, classes = THREE }
	session(scenario, env, function(ns)
		local row = windowOrder(ns)
		if not row then
			fail(scenario, "SKIPPED -- no order list on Who to buff")
			return
		end
		local order = ns.BuffWalkOrder()
		local shown = 0
		-- The spell's own icon on each line, as the client has it for the spell.
		local drawn = {}
		for i, line in ipairs(row.lines) do
			local real = line.icon.SetTexture
			line.icon.SetTexture = function(self, file, ...)
				drawn[i] = file
				return real(self, file, ...)
			end
		end
		ns.RefreshOptionsDisplay()
		for i, line in ipairs(row.lines) do
			if line:IsShown() then shown = shown + 1 end
			local buff = order[i]
			if buff then
				if not tostring(line.text:GetText()):find(ns.BuffName(buff), 1, true) then
					fail(scenario, "line " .. i .. " reads " .. tostring(line.text:GetText()) .. ", not " .. ns.BuffName(buff))
				end
				if line.num:GetText() ~= tostring(i) then
					fail(scenario, "line " .. i .. " is numbered " .. tostring(line.num:GetText()))
				end
			end
		end
		if shown ~= #order then fail(scenario, "the list shows " .. shown .. " lines for " .. #order .. " buffs") end
		for i, buff in ipairs(order) do
			local info = ns.BuffInfo(buff)
			local icon = info and ns.plain(info.icon)
			if icon == nil or drawn[i] ~= icon then
				fail(scenario, "line " .. i .. " draws " .. tostring(drawn[i]) .. ", not " .. ns.BuffName(buff) .. "'s own icon "
					.. tostring(icon))
			end
		end
		-- The mana and group notes are on the lines, as on the switches above.
		local text = {}
		for _, line in ipairs(row.lines) do text[#text + 1] = tostring(line.text:GetText()) end
		local all = table.concat(text, "\n")
		if not (all:find("mana users only", 1, true) and all:find("your group only", 1, true)) then
			fail(scenario, "the lines do not say which blessing is for mana users and which for your group: " .. all)
		end
		-- Nothing about it is hidden over the list.
		if not row.note then fail(scenario, "the list has no caption") end
		-- The window's own placement: the list sits in Who to buff's own section.
		local where = ns.WindowUI.Where("who.orderPick")
		if not (where and where.sec and where.sec.key == "who.order") then
			fail(scenario, "the list is in section " .. tostring(where and where.sec and where.sec.key))
		end
	end)
end

do
	local scenario = "hunt29-order: window: the first line the walk can use is set apart, the others are not"
	-- Light is not learned: the first line, Kings, is what a bare person is offered.
	local env = { client = "camelot", classes = THREE, keys = { "wisdom", "might", "kings", "salvation" } }
	session(scenario, env, function(ns)
		local row = windowOrder(ns)
		if not row then
			fail(scenario, "SKIPPED -- no order list on Who to buff")
			return
		end
		for i, line in ipairs(row.lines) do
			if line:IsShown() then
				local first = i == 1
				if line.wash:IsShown() ~= first or line.bar:IsShown() ~= first then
					fail(scenario, "line " .. i .. (first and " is not" or " is") .. " set apart")
				end
			end
		end
		-- Light, which is not learned, is dimmed and says so.
		local last = row.lines[5]
		if not (last and tostring(last.text:GetText()):find("not learned", 1, true)) then
			fail(scenario, "the buff that is not learned does not say so: " .. tostring(last and last.text:GetText()))
		end
		if last and not last.icon:IsDesaturated() then fail(scenario, "the buff that is not learned is drawn in full colour") end
		if row.lines[1].icon:IsDesaturated() then fail(scenario, "the first buff is drawn dim") end
		-- Kings put below the others: the emphasis goes with the place, so it is
		-- Wisdom's now.
		ns.MoveBuff("kings", 1)
		ns.MoveBuff("kings", 1)
		ns.MoveBuff("kings", 1)
		ns.RefreshOptionsDisplay()
		if not (row.lines[1].wash:IsShown() and not row.lines[2].wash:IsShown()) then
			fail(scenario, "after Kings went down the first line is not the one set apart")
		end
		-- Not learned first in the order: the emphasis passes it by.
		ns.db.profile.buff.order.PALADIN = { "light", "kings", "might", "wisdom", "salvation" }
		ns.RefreshOptionsDisplay()
		if not (not row.lines[1].wash:IsShown() and row.lines[2].wash:IsShown()) then
			fail(scenario, "Light is not learned and is set apart as what a bare person is offered, or Kings is not")
		end
	end)
end

do
	local scenario = "hunt29-order: window: no arrow up on the first line and none down on the last"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		local row = windowOrder(ns)
		if not row then
			fail(scenario, "SKIPPED -- no order list on Who to buff")
			return
		end
		local n = #ns.BuffWalkOrder()
		for i = 1, n do
			local line = row.lines[i]
			if line.up:IsEnabled() ~= (i > 1) then fail(scenario, "line " .. i .. "'s arrow up is " .. (line.up:IsEnabled() and "live" or "greyed")) end
			if line.down:IsEnabled() ~= (i < n) then fail(scenario, "line " .. i .. "'s arrow down is " .. (line.down:IsEnabled() and "live" or "greyed")) end
		end
		-- A press on a greyed arrow does nothing, and moves no buff.
		press(row.lines[1].up)
		press(row.lines[n].down)
		row.lines[1].up:Click()
		if ns.HasBuffOrder() then fail(scenario, "a greyed arrow moved a buff: " .. keys(ns.BuffOrder())) end
		-- The arrows follow the buffs: the buff now first has none up.
		press(row.lines[2].up)
		row = windowOrder(ns)
		if not (row.lines[1].up:IsEnabled() == false and row.lines[2].up:IsEnabled() == true) then
			fail(scenario, "after a move the first line still has an arrow up, or the second has none")
		end
	end)
end

do
	local scenario = "hunt29-order: window: Back to Automatic is there only while the order differs"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		local row, UI = windowOrder(ns)
		if not row then
			fail(scenario, "SKIPPED -- no order list on Who to buff")
			return
		end
		if not row.reset then
			fail(scenario, "the list has no Back to Automatic button")
			return
		end
		if row.reset.frame:IsShown() then fail(scenario, "Back to Automatic is shown over Automatic's own order") end
		local height = UI.Where("who.orderPick").e.h
		press(row.lines[3].up)
		if not row.reset.frame:IsShown() then fail(scenario, "Back to Automatic is not shown over an order of the player's own") end
		if not (UI.Where("who.orderPick").e.h > height) then
			fail(scenario, "the button appeared and the page gave it no room")
		end
		-- Moved back to where it was: the order is Automatic's again, and the button goes.
		press(row.lines[2].down)
		if ns.HasBuffOrder() then fail(scenario, "an order that is Automatic's was kept: " .. keys(ns.BuffOrder())) end
		if row.reset.frame:IsShown() then fail(scenario, "Back to Automatic is shown over Automatic's own order again") end
		if not (UI.Where("who.orderPick").e.h == height) then fail(scenario, "the page kept the room of a button that is gone") end
		-- And the button itself puts everything back.
		press(row.lines[4].up)
		press(row.lines[3].up)
		if not row.reset.frame:IsShown() then fail(scenario, "no button over two moves") end
		press(row.reset.button)
		if ns.HasBuffOrder() then fail(scenario, "the button left an order: " .. keys(ns.BuffOrder())) end
		if row.reset.frame:IsShown() then fail(scenario, "Back to Automatic is still shown after it was pressed") end
		if castable(ns) ~= AUTO_FIRST then fail(scenario, "after the button the walk is " .. castable(ns)) end
	end)
end

do
	local scenario = "hunt29-order: window: a press repaints the list and the page at once"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		local row, UI = windowOrder(ns)
		if not row then
			fail(scenario, "SKIPPED -- no order list on Who to buff")
			return
		end
		local before = ns.BuffWalkOrder()
		if not UI.RowShown("who.kingsFirst") then fail(scenario, "SKIPPED -- no Kings switch to watch") return end
		-- Might (third) up one place: the list is Kings, Might, Wisdom, at once.
		press(row.lines[3].up)
		local after = ns.BuffWalkOrder()
		for i = 1, #after do
			if not tostring(row.lines[i].text:GetText()):find(ns.BuffName(after[i]), 1, true) then
				fail(scenario, "line " .. i .. " reads " .. tostring(row.lines[i].text:GetText()) .. " after the press, not "
					.. ns.BuffName(after[i]))
			end
		end
		if after[2].key ~= before[3].key then fail(scenario, "the buff pressed did not move up a place") end
		-- The page is repainted too: the Kings switch is gone, Automatic's note (a row
		-- of its own) lists the new order, and the caption says whose order it is.
		if UI.RowShown("who.kingsFirst") then fail(scenario, "the Kings switch is still shown over an order") end
		local autoRow = UI.RowFor("who.autoNote")
		local autoText = autoRow and autoRow.text and tostring(autoRow.text:GetText()) or ""
		local m, w = autoText:find("Blessing of Might", 1, true), autoText:find("Blessing of Wisdom", 1, true)
		if not (m and w and m < w) then
			fail(scenario, "Automatic's note still reads the old order after the press: " .. autoText)
		end
		local note = row.note and row.note.text and row.note.text:GetText() or ""
		if not tostring(note):find("Your own order is in use.", 1, true) then
			fail(scenario, "the caption still reads: " .. tostring(note))
		end
		-- The buff that moved lights up for a moment, and the light fades.
		if not row.lines[2].flash:IsShown() then fail(scenario, "the buff that moved is not lit") end
		if row.lines[1].flash:IsShown() or row.lines[3].flash:IsShown() then
			fail(scenario, "a buff that did not move is lit")
		end
		local update = row.lines[2]:GetScript("OnUpdate")
		if not update then
			fail(scenario, "the light has nothing to fade it")
		else
			for _ = 1, 10 do update(row.lines[2], 0.1) end
			if row.lines[2].flash:IsShown() then fail(scenario, "the light on the moved buff does not fade") end
		end
		-- Pressed again: the list is read again, not once.
		press(row.lines[2].up)
		if not tostring(row.lines[1].text:GetText()):find(ns.BuffName(ns.BuffWalkOrder()[1]), 1, true) then
			fail(scenario, "a second press did not repaint the list")
		end
		if ns.BuffOrder()[1] ~= "might" then fail(scenario, "Might is not first: " .. keys(ns.BuffOrder())) end
	end)
end

do
	local scenario = "hunt29-order: window: the list is hidden for a mage and while a spell is pinned"
	local env = { client = "camelot", class = "MAGE", classes = THREE }
	session(scenario, env, function(ns)
		ns.OpenOptions("who")
		local UI = ns.WindowUI
		if UI.RowShown("who.orderPick") then fail(scenario, "a mage is shown the buff order") end
	end)
	local env2 = { client = "camelot", classes = THREE }
	session(scenario, env2, function(ns)
		ns.db.profile.buff.choice = "might"
		ns.OpenOptions("who")
		local UI = ns.WindowUI
		if UI.RowShown("who.orderPick") then fail(scenario, "the buff order is shown while Might is pinned") end
		ns.db.profile.buff.choice = "auto"
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("who.orderPick") then fail(scenario, "the buff order does not come back with Automatic") end
	end)
end

-- ----------------------------------------- the old dialog: a dropdown and buttons
do
	local scenario = "hunt29-order: the old dialog's dropdown and buttons move the picked buff"
	local env = { client = "camelot", classes = THREE }
	session(scenario, env, function(ns)
		local pick, up, down = control(ns, "orderPick"), control(ns, "orderUp"), control(ns, "orderDown")
		local values = pick.values()
		local sorting = pick.sorting()
		if keys(sorting) ~= AUTO_FIRST then fail(scenario, "the dropdown lists " .. keys(sorting) .. ", not Automatic's order") end
		for _, key in ipairs(sorting) do
			if not values[key] then fail(scenario, "the dropdown has no name for " .. key) end
		end
		if pick.get() ~= "kings" then fail(scenario, "nothing picked reads " .. tostring(pick.get()) .. ", not the first") end
		pick.set({ "who", "orderPick" }, "light")
		if pick.get() ~= "light" then fail(scenario, "the pick is not kept: " .. tostring(pick.get())) end
		up.func()
		up.func()
		-- The one picked stays picked, so it goes on up.
		if pick.get() ~= "light" then fail(scenario, "the pick moved off Light with it: " .. tostring(pick.get())) end
		if keys(ns.BuffOrder()) ~= "kings, wisdom, light, might, salvation" then
			fail(scenario, "two steps up gave " .. keys(ns.BuffOrder()))
		end
		down.func()
		if keys(ns.BuffOrder()) ~= "kings, wisdom, might, light, salvation" then
			fail(scenario, "one step down gave " .. keys(ns.BuffOrder()))
		end
		-- A pick that is not on the list reads as the first.
		pick.set({ "who", "orderPick" }, "bogus")
		if pick.get() ~= "kings" then fail(scenario, "a pick that is gone reads " .. tostring(pick.get())) end
		-- What the old dialog repaints, and the prompt: told at each move.
		local calls = { macro = 0, redraw = 0 }
		local realMacro, realRedraw = ns.Prompt.InvalidateMacro, ns.RefreshOptionsDisplay
		ns.Prompt.InvalidateMacro = function(...) calls.macro = calls.macro + 1 return realMacro(...) end
		ns.RefreshOptionsDisplay = function(...) calls.redraw = calls.redraw + 1 return realRedraw(...) end
		pick.set({ "who", "orderPick" }, "wisdom")
		up.func()
		control(ns, "orderReset").func()
		ns.Prompt.InvalidateMacro, ns.RefreshOptionsDisplay = realMacro, realRedraw
		if calls.macro < 2 or calls.redraw < 2 then
			fail(scenario, "a move and the way back told the prompt " .. calls.macro .. " times and the dialog " .. calls.redraw)
		end
	end)
end
