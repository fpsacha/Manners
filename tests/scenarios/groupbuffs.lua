-- Group buffs (1.1.0): one cast for a whole party. Somebody who knows Arcane
-- Brilliance, Prayer of Fortitude, Gift of the Wild or a Greater Blessing and
-- carries its reagent is offered the group version for a party (or, for a
-- paladin, a class) with enough people missing the buff, in place of buffing
-- them one at a time. GroupBuffs.lua decides, PostClick and the settle cover
-- everybody the cast reached, and the ledger counts one cast.
--
-- Every scenario name starts with "groupbuffs:" so the mutations in
-- tests/mutations/groupbuffs.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local ARCANE_POWDER, WILD_BERRIES, WILD_THORNROOT = 17020, 17021, 17026
local SACRED_CANDLE, SYMBOL_OF_KINGS = 17029, 21177
local ITEM_NAMES = {
	[ARCANE_POWDER] = "Arcane Powder", [WILD_BERRIES] = "Wild Berries",
	[WILD_THORNROOT] = "Wild Thornroot", [SACRED_CANDLE] = "Sacred Candle",
	[SYMBOL_OF_KINGS] = "Symbol of Kings",
}

-- A mage's Arcane Intellect in every rank, and Arcane Brilliance.
local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }
local BRILLIANCE = 23028

-- The four others in a party of five.
local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	party4 = { "Dain", "Moor" },
}

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function list(ids)
	local out = {}
	for _, id in ipairs(ids) do out[#out + 1] = id end
	return out
end

local function join(...)
	local out = {}
	for i = 1, select("#", ...) do
		for _, id in ipairs((select(i, ...))) do out[#out + 1] = id end
	end
	return out
end

-- What the client is for one scenario: which spells are known, what is in
-- the bags, each unit's class and mana, and the auras each unit carries,
-- by token. Globals the mock does not own per unit, so every one is put
-- back by the undo this hands back.
local function install(env)
	local saved = {
		IsSpellKnown = IsSpellKnown, IsPlayerSpell = IsPlayerSpell, UnitClass = UnitClass,
		UnitPowerMax = UnitPowerMax, UnitInParty = UnitInParty,
		GetItemCount = rawget(_G, "GetItemCount"), GetItemInfo = rawget(_G, "GetItemInfo"),
		C_UnitAuras = rawget(_G, "C_UnitAuras"),
	}
	local known = {}
	for _, id in ipairs(env.known or {}) do known[id] = true end
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = IsSpellKnown
	env.bags = env.bags or {}
	GetItemCount = function(id) return env.bags[id] or 0 end
	GetItemInfo = function(id) return ITEM_NAMES[id] end
	env.classes = env.classes or {}
	UnitClass = function(unit)
		local class = env.classes[unit]
		if class then return class, class end
		return saved.UnitClass(unit)
	end
	-- A warrior's mana bar reads zero, so a paladin's Automatic gives Might.
	UnitPowerMax = function(unit, power)
		local class = env.classes[unit]
		if class == "WARRIOR" or class == "ROGUE" then return 0 end
		return saved.UnitPowerMax(unit, power)
	end
	-- The mock counts every unit as in a party of more than one; here only the
	-- party tokens are, so a nameplate is a stranger. A raid is the mock's.
	UnitInParty = function(unit)
		if Mock.raid then return saved.UnitInParty(unit) end
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end
	env.held = env.held or {}
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			-- A unit whose auras the client withholds, every one of them.
			if env.unreadable and env.unreadable[unit] then return Mock.SECRET end
			local carrying = env.held[unit]
			local source = carrying and carrying[spellId]
			if not source then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3600,
				sourceUnit = type(source) == "string" and source or "player" }
		end,
	}, { __index = base }))
	-- Once only, and from Mock.reset as well: the runner resets after a file
	-- that threw, and these globals must not leak into the files after it.
	local realReset, undone = Mock.reset, false
	local function undo()
		if undone then return end
		undone = true
		Mock.reset = realReset
		IsSpellKnown, IsPlayerSpell, UnitClass = saved.IsSpellKnown, saved.IsPlayerSpell, saved.UnitClass
		UnitPowerMax, UnitInParty = saved.UnitPowerMax, saved.UnitInParty
		rawset(_G, "GetItemCount", saved.GetItemCount)
		rawset(_G, "GetItemInfo", saved.GetItemInfo)
		rawset(_G, "C_UnitAuras", saved.C_UnitAuras)
	end
	Mock.reset = function(...)
		undo()
		return realReset(...)
	end
	return undo
end

-- Whether an options control can be used: AceConfig reads a missing
-- `disabled` as live.
local function live(option)
	return not (type(option.disabled) == "function" and option.disabled())
end

-- A session in a party of five (or the raid `env.raid` names), the client as
-- `env` says, the lifecycle driven and the slate cleared. `env.setup` runs on
-- the profile before the first repaint.
local function session(scenario, env)
	Mock.reset()
	Mock.class = env.class or "MAGE"
	if env.raid then
		Mock.raid = env.raid
	else
		Mock.groupSize = 5
	end
	local restoreUnits = H.strangers(env.names or PARTY)
	local restoreEnv = install(env)
	local function restore()
		restoreEnv()
		restoreUnits()
	end
	local ns = load(scenario)
	if not ns then
		restore()
		return nil
	end
	H.freshPrompt(ns, scenario)
	if env.setup then env.setup(ns) end
	-- Whoever the lifecycle left on the panel is let go, so the panel shows
	-- the top of the queue rather than keeping its pick.
	ns.Prompt:ApplyTarget(nil)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	return ns, restore
end

-- The queue's entries for one buff, by the name each is filed under.
local function offers(ns, key)
	local out, count = {}, 0
	for _, entry in ipairs(ns.BuildQueue()) do
		if not key or (entry.buff and entry.buff.key == key) then
			out[entry.name] = entry
			count = count + 1
		end
	end
	return out, count
end

-- The one group cast in the queue, or nil, and how many there are.
local function groupCast(ns)
	local found, count = nil, 0
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.groupCast then
			found = found or entry
			count = count + 1
		end
	end
	return found, count
end

local function covered(entry)
	local out = { entry.name }
	for _, name in ipairs(entry.groupCast.members) do out[#out + 1] = name end
	table.sort(out)
	return table.concat(out, ", ")
end

-- A mage with Arcane Brilliance and twenty Arcane Powder, everybody missing it.
local function mage(extra)
	local env = { known = join(MAGE_SINGLE, { BRILLIANCE }), bags = { [ARCANE_POWDER] = 20 } }
	for k, v in pairs(extra or {}) do env[k] = v end
	return env
end

-- The press, and the game reporting the cast going out.
local function pressAndCast(ns, spellId, guid)
	local ran = H.pressButton(ns)
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, spellId)
	return ran
end

-- ------------------------------------------------------------ groupbuffs-1
-- Four of a party missing Arcane Intellect, and a mage who can give them
-- Arcane Brilliance: one offer, aimed at one of them, casting the group spell,
-- and the panel saying whose party and how many.
do
	local scenario = "groupbuffs: four of a party missing it get one group cast"
	local ns, restore = session(scenario, mage())
	if ns then
		local group, count = groupCast(ns)
		local _, singles = offers(ns, "intellect")
		if not group then
			fail(scenario, "no group cast was offered for four people missing the buff")
		else
			if count ~= 1 or singles ~= 1 then
				fail(scenario, ("expected one group cast and nothing else, got %d group casts in %d offers")
					:format(count, singles))
			end
			if covered(group) ~= "Bram Oake, Cora Vell, Dain Moor, Gwen Hale" then
				fail(scenario, "the group cast does not cover the party: " .. covered(group))
			end
			if group.groupCast.missing ~= 4 then
				fail(scenario, "it says " .. tostring(group.groupCast.missing) .. " missing, not 4")
			end
			local text = macro(ns)
			if not (text and text:find("/target Bram Oake\n/cast Arcane Brilliance", 1, true)) then
				fail(scenario, "the macro does not target one of them and cast Arcane Brilliance: " .. flat(text))
			end
			local line = ns.Prompt:RenderPrimary(group, 0)
			local sub = ns.Prompt:ReasonText(group)
			if not line:find("party", 1, true) or not sub:find("Arcane Brilliance -- 4 missing", 1, true) then
				fail(scenario, "the panel does not name the party and the count: " .. line .. " / " .. sub)
			end
			local summary = table.concat(ns.Prompt:ClickSummary(group), " / ")
			if not summary:find("on their whole party", 1, true) then
				fail(scenario, "the click summary does not say it covers the party: " .. summary)
			end
			-- {buff} in a spoken line is the spell that goes out.
			local speech = ns.db.profile.speech
			speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
			speech.phrases = "Here is {buff}, {name}."
			ns.Prompt:InvalidateMacro()
			ns.addon:Tick()
			local said = macro(ns)
			if not (said and said:find("/say Here is Arcane Brilliance, Bram Oake.", 1, true)) then
				fail(scenario, "the spoken line does not name the group spell: " .. flat(said))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-2
-- The tooltip counts the reagent as the bags hold it now.
do
	local scenario = "groupbuffs: the tooltip counts the reagent"
	local ns, restore = session(scenario, mage())
	if ns then
		local button = ns.Prompt:GetButton()
		Mock.tooltip = {}
		local enter = button.scripts.OnEnter
		if enter then enter(button) end
		local said = table.concat(Mock.tooltip, " / ")
		if not said:find("Arcane Brilliance", 1, true) then
			fail(scenario, "SKIPPED -- the tooltip is not about the group cast: " .. said)
		elseif not said:find("Uses one Arcane Powder -- you have 20.", 1, true) then
			fail(scenario, "the tooltip does not count the reagent: " .. said)
		elseif not said:find("4 in their party are missing Arcane Intellect", 1, true) then
			fail(scenario, "the tooltip does not say how many are missing it: " .. said)
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-3
-- The threshold: two missing is two single casts at the default of three, and
-- one group cast when the setting says two.
do
	local scenario = "groupbuffs: under the threshold they are buffed one by one"
	local env = mage({ held = { party1 = { [10157] = true }, party2 = { [10157] = true } } })
	local ns, restore = session(scenario, env)
	if ns then
		local all, singles = offers(ns, "intellect")
		if singles ~= 2 or not (all["Cora Vell"] and all["Dain Moor"]) then
			fail(scenario, "SKIPPED -- the two missing it are not both offered: " .. tostring(singles))
		elseif groupCast(ns) then
			fail(scenario, "a group cast was offered for two missing it under a threshold of three")
		else
			ns.db.profile.groupBuffs.atLeast = 2
			local group = groupCast(ns)
			if not group then
				fail(scenario, "no group cast for two missing it with the threshold set to two")
			elseif group.groupCast.missing ~= 2 then
				fail(scenario, "the group cast counts " .. tostring(group.groupCast.missing) .. " missing, not 2")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-4
-- Nothing changes for somebody who has not learned the group version, has no
-- reagent, or has switched it off: four single casts, as before.
for _, case in ipairs({
	{ label = "not learned", env = { known = list(MAGE_SINGLE), bags = { [ARCANE_POWDER] = 20 } } },
	{ label = "no reagent", env = { known = join(MAGE_SINGLE, { BRILLIANCE }), bags = {} } },
	{ label = "switched off", env = mage({ setup = function(ns) ns.db.profile.groupBuffs.use = false end }) },
	{ label = "the client says it cannot be cast", env = mage(), unusable = true },
}) do
	local scenario = "groupbuffs: " .. case.label .. ", they are buffed one by one"
	local realUsable = rawget(_G, "IsUsableSpell")
	if case.unusable then
		IsUsableSpell = function(id) if id == BRILLIANCE then return false, false end return true, false end
	end
	local ns, restore = session(scenario, case.env)
	if ns then
		local _, singles = offers(ns, "intellect")
		if groupCast(ns) then
			fail(scenario, "a group cast was offered")
		elseif singles ~= 4 then
			fail(scenario, "expected the four of them one by one, got " .. tostring(singles))
		end
		local text = macro(ns)
		if text and text:find("Brilliance", 1, true) then
			fail(scenario, "the macro casts the group spell: " .. flat(text))
		end
		guarded(scenario, ns)
		restore()
	end
	rawset(_G, "IsUsableSpell", realUsable)
end

-- ------------------------------------------------------------ groupbuffs-5
-- "My party and raid" off: the party is not offered, and nothing folds it
-- into a group cast behind the player's back.
do
	local scenario = "groupbuffs: with the party switched off there is no group cast"
	local ns, restore = session(scenario, mage({ setup = function(ns) ns.db.profile.sources.group = false end }))
	if ns then
		local _, singles = offers(ns, "intellect")
		if groupCast(ns) or singles ~= 0 then
			fail(scenario, ("the party was offered with the source off: %d offers"):format(singles))
		end
		-- Three of them owed a favour are offered all the same, one by one:
		-- a group cast would buff the rest of the party, whom the player
		-- said not to offer anything.
		H.owe(ns, "Gwen Hale")
		H.owe(ns, "Bram Oake")
		H.owe(ns, "Cora Vell")
		local _, owedOffers = offers(ns, "intellect")
		if groupCast(ns) then
			fail(scenario, "three favours were folded into a group cast with My party and raid off")
		elseif owedOffers ~= 3 then
			fail(scenario, "SKIPPED -- the three favours are not offered: " .. owedOffers)
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-6
-- The rank decides the reagent: Gift of the Wild's first rank takes Wild
-- Berries and its second Wild Thornroot, and the macro casts the best rank
-- known, so the reagent for that one is the one that has to be carried.
do
	local druid = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
	for _, case in ipairs({
		{ label = "first rank, berries", known = { 21849 }, bags = { [WILD_BERRIES] = 5 }, want = true },
		{ label = "first rank, thornroot only", known = { 21849 }, bags = { [WILD_THORNROOT] = 5 }, want = false },
		{ label = "second rank, thornroot", known = { 21849, 21850 }, bags = { [WILD_THORNROOT] = 5 }, want = true },
		{ label = "second rank, berries only", known = { 21849, 21850 }, bags = { [WILD_BERRIES] = 5 }, want = false },
	}) do
		local scenario = "groupbuffs: the rank known decides the reagent (" .. case.label .. ")"
		local ns, restore = session(scenario, { class = "DRUID", known = join(druid, case.known), bags = case.bags })
		if ns then
			local group = groupCast(ns)
			if (group ~= nil) ~= case.want then
				fail(scenario, case.want and "no Gift of the Wild with the right reagent in the bags"
					or "Gift of the Wild was offered without the reagent its rank takes")
			elseif group and not flat(macro(ns)):find("/cast Gift of the Wild", 1, true) then
				fail(scenario, "the macro does not cast Gift of the Wild: " .. flat(macro(ns)))
			end
			guarded(scenario, ns)
			restore()
		end
	end
end

-- ------------------------------------------------------------ groupbuffs-7
-- In a raid a party-wide spell reaches the target's own subgroup. Two missing
-- it in the player's subgroup and four in the next: one group cast for the
-- second subgroup only, and the first two one by one.
do
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	local held = {}
	-- Subgroup 1 is raid1-5 (raid1 is the player); raid4 and raid5 have it.
	held.raid4 = { [10157] = true }
	held.raid5 = { [10157] = true }
	-- Subgroup 2 is raid6-10; raid10 has it.
	held.raid10 = { [10157] = true }
	local scenario = "groupbuffs: in a raid only one subgroup counts towards a group cast"
	local ns, restore = session(scenario, mage({ raid = { size = 10, player = 1 }, names = names, held = held }))
	if ns then
		local group, count = groupCast(ns)
		local all = offers(ns, "intellect")
		if not group then
			fail(scenario, "no group cast for the subgroup with four missing it")
		else
			if count ~= 1 then fail(scenario, count .. " group casts, where one subgroup qualifies") end
			if covered(group) ~= "Raider6 Stone, Raider7 Stone, Raider8 Stone, Raider9 Stone" then
				fail(scenario, "the group cast covers people outside the target's subgroup: " .. covered(group))
			end
			if not ns.BuildQueue()[1].groupCast then
				fail(scenario, "the group cast does not come before the single casts of its kind")
			end
			if not (all["Raider2 Stone"] and all["Raider3 Stone"]) then
				fail(scenario, "the two missing it in the other subgroup are no longer offered")
			elseif all["Raider2 Stone"].groupCast or all["Raider3 Stone"].groupCast then
				fail(scenario, "the other subgroup was folded into a group cast it does not reach")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-8
-- A paladin's Greater Blessing covers one class, and follows the blessing
-- the per-class choice gives it: Might for the warriors (no mana), Wisdom for
-- the two mages, who stay single casts under a threshold of three.
local PALADIN_SINGLE = {
	25290, 19854, 19853, 19852, 19850, 19742, -- Wisdom
	25291, 19838, 19837, 19836, 19835, 19834, 19740, -- Might
}
local function paladinRaid(extra)
	local names, classes = {}, {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	for _, i in ipairs({ 2, 3, 6, 7 }) do classes["raid" .. i] = "WARRIOR" end
	for _, i in ipairs({ 4, 8 }) do classes["raid" .. i] = "MAGE" end
	for _, i in ipairs({ 5, 9, 10 }) do classes["raid" .. i] = "PRIEST" end
	local env = {
		class = "PALADIN", raid = { size = 10, player = 1 }, names = names, classes = classes,
		known = join(PALADIN_SINGLE, { 25916, 25782, 25918, 25894 }),
		bags = { [SYMBOL_OF_KINGS] = 10 },
		-- The priests have Wisdom from us, so the only class left is the warriors.
		held = { raid5 = { [25290] = true }, raid9 = { [25290] = true }, raid10 = { [25290] = true } },
	}
	for k, v in pairs(extra or {}) do env[k] = v end
	return env
end
do
	local scenario = "groupbuffs: a Greater Blessing counts one class"
	local ns, restore = session(scenario, paladinRaid())
	if ns then
		local group, count = groupCast(ns)
		local all = offers(ns)
		if not group then
			fail(scenario, "no Greater Blessing for four warriors missing Might")
		else
			if count ~= 1 then fail(scenario, count .. " group casts, where one class qualifies") end
			if group.buff.key ~= "might" then
				fail(scenario, "the warriors' Greater Blessing is " .. tostring(group.buff.key) .. ", not Might")
			end
			if covered(group) ~= "Raider2 Stone, Raider3 Stone, Raider6 Stone, Raider7 Stone" then
				fail(scenario, "the Greater Blessing does not cover the warriors, across subgroups: " .. covered(group))
			end
			if not flat(macro(ns)):find("/cast Greater Blessing of Might", 1, true) then
				fail(scenario, "the macro does not cast Greater Blessing of Might: " .. flat(macro(ns)))
			end
			if not ns.Prompt:RenderPrimary(group, 0):find("every Warrior", 1, true) then
				fail(scenario, "the panel does not name the class: " .. ns.Prompt:RenderPrimary(group, 0))
			end
			local mage4 = all["Raider4 Stone"]
			if not (mage4 and mage4.buff.key == "wisdom" and not mage4.groupCast) then
				fail(scenario, "the mages lost their own single Wisdom")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- A warrior the queue never offered (he carries our Kings) would lose it to a
-- Greater Blessing of Might, since one paladin's blessings replace each other:
-- no group cast. Another paladin's Kings on him is no reason to hold back.
for _, case in ipairs({
	{ label = "ours", source = "player", want = false },
	{ label = "another paladin's", source = "raid9", want = true },
}) do
	local scenario = "groupbuffs: a Greater Blessing never replaces another of ours (" .. case.label .. " Kings)"
	local env = paladinRaid({ known = join(PALADIN_SINGLE, { 20217, 25916, 25782, 25918, 25894 }) })
	env.classes.raid8 = "WARRIOR"
	env.held.raid8 = { [20217] = case.source }
	local ns, restore = session(scenario, env)
	if ns then
		local group = groupCast(ns)
		if (group ~= nil) ~= case.want then
			fail(scenario, case.want and "no Greater Blessing though the Kings on the fifth warrior is not ours"
				or "a Greater Blessing of Might was offered over our own Kings on a warrior")
		end
		guarded(scenario, ns)
		restore()
	end
end

-- A warrior whose auras nobody can read may carry another blessing of ours,
-- which a Greater Blessing would replace: no group cast while one is unread.
do
	local scenario = "groupbuffs: a Greater Blessing waits while a warrior is unread"
	local env = paladinRaid()
	env.unreadable = { raid6 = true }
	local ns, restore = session(scenario, env)
	if ns then
		local all = offers(ns, "might")
		if groupCast(ns) then
			fail(scenario, "a Greater Blessing was offered over a warrior nobody could read")
		elseif not all["Raider6 Stone"] or all["Raider6 Stone"].known ~= nil then
			fail(scenario, "SKIPPED -- the unread warrior is not offered with an unread answer")
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-9
-- After it lands: the press blocks everybody it covered at once (their auras
-- still read the old answer for a moment), the settle files it, and once the
-- buff reads on them nobody it covered is offered again.
do
	local scenario = "groupbuffs: after it lands nobody it covered is offered again"
	local env = mage()
	local ns, restore = session(scenario, env)
	if ns then
		local ran = H.pressButton(ns)
		local _, waiting = offers(ns, "intellect")
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-G1", BRILLIANCE)
		if not (ran and ran:find("Arcane Brilliance", 1, true)) then
			fail(scenario, "SKIPPED -- the press did not cast the group spell: " .. flat(ran))
		else
			if waiting ~= 0 then
				fail(scenario, waiting .. " of the people it covered were offered again while the press waited for the game")
			end
			local _, now = offers(ns, "intellect")
			if now ~= 0 then
				fail(scenario, now .. " of the people it covered were offered again straight after the cast")
			end
			for unit in pairs(PARTY) do env.held[unit] = { [BRILLIANCE] = true } end
			Mock.advance(20)
			local _, later = offers(ns, "intellect")
			if later ~= 0 then
				fail(scenario, later .. " of the people it covered were offered again once it read on them")
			end
			if ns.pendingClick then fail(scenario, "the press was never settled") end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- The same in a raid: the other subgroup is still offered, one by one.
do
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	local scenario = "groupbuffs: after it lands the other subgroup is still offered"
	local env = mage({ raid = { size = 10, player = 1 }, names = names,
		held = { raid4 = { [10157] = true }, raid5 = { [10157] = true }, raid10 = { [10157] = true } } })
	local ns, restore = session(scenario, env)
	if ns then
		local ran = pressAndCast(ns, BRILLIANCE, "Cast-G2")
		if not (ran and ran:find("Arcane Brilliance", 1, true)) then
			fail(scenario, "SKIPPED -- the press did not cast the group spell: " .. flat(ran))
		else
			for i = 6, 9 do env.held["raid" .. i] = { [BRILLIANCE] = true } end
			Mock.advance(20)
			local all, count = offers(ns, "intellect")
			if count ~= 2 or not (all["Raider2 Stone"] and all["Raider3 Stone"]) then
				fail(scenario, "expected the two in the other subgroup and nobody else, got " .. count)
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-10
-- Favours in the party: the group cast takes the favour's place on the prompt
-- (a favour owed lifts it), is aimed at the person owed, and returns every
-- favour it covers. A favour outside the party keeps its own single buff.
do
	local scenario = "groupbuffs: the group cast returns the favours it covers"
	local names = { nameplate1 = { "Ezra", "Pike" } }
	for unit, name in pairs(PARTY) do names[unit] = name end
	local ns, restore = session(scenario, mage({ names = names }))
	if ns then
		H.owe(ns, "Cora Vell")
		H.owe(ns, "Dain Moor")
		H.owe(ns, "Ezra Pike")
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local group = groupCast(ns)
		local all = offers(ns, "intellect")
		if not group then
			fail(scenario, "no group cast for a party with two favours in it")
		else
			if group.priority ~= 1 or group.reason ~= "owed" then
				fail(scenario, "the group cast does not take a favour's place: " .. tostring(group.reason))
			end
			if group.name ~= "Cora Vell" then
				fail(scenario, "the group cast is not aimed at somebody owed: " .. tostring(group.name))
			end
			if not (all["Ezra Pike"] and not all["Ezra Pike"].groupCast) then
				fail(scenario, "the favour outside the party lost its own single buff")
			end
			local button = ns.Prompt:GetButton()
			Mock.tooltip = {}
			if button.scripts.OnEnter then button.scripts.OnEnter(button) end
			local tip = table.concat(Mock.tooltip, " / ")
			if not tip:find("It returns the favour to Cora Vell, Dain Moor as well.", 1, true) then
				fail(scenario, "the tooltip does not name the favours the group cast returns: " .. tip)
			end
			Mock.printed = {}
			local ran = pressAndCast(ns, BRILLIANCE, "Cast-G3")
			if not (ran and ran:find("/target Cora Vell", 1, true) and ran:find("Arcane Brilliance", 1, true)) then
				fail(scenario, "SKIPPED -- the press was not the group cast at Cora: " .. flat(ran))
			else
				if ns.owed["Cora Vell"] or ns.owed["Dain Moor"] then
					fail(scenario, "a favour the group cast covered is still owed")
				end
				if not ns.owed["Ezra Pike"] then
					fail(scenario, "the favour outside the party was counted as returned")
				end
				local said = table.concat(Mock.printed, "\n")
				if not said:find("Dain Moor", 1, true) then
					fail(scenario, "nothing says the group cast returned Dain's favour too: " .. said)
				end
				local returned = {}
				for _, e in ipairs(ns.Ledger.Entries("favours")) do
					if e.state == "returned" then returned[e.name] = e.gave end
				end
				if returned["Cora Vell"] ~= BRILLIANCE or returned["Dain Moor"] ~= BRILLIANCE then
					fail(scenario, "the ledger does not show both favours returned with Arcane Brilliance")
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-11
-- The ledger: one cast is one buff given, however many it reached, and the
-- row says how many.
do
	local scenario = "groupbuffs: the ledger counts one cast"
	local ns, restore = session(scenario, mage())
	if ns then
		local before = ns.Ledger.Summary()
		local ran = pressAndCast(ns, BRILLIANCE, "Cast-G4")
		if not (ran and ran:find("Arcane Brilliance", 1, true)) then
			fail(scenario, "SKIPPED -- the press did not cast the group spell: " .. flat(ran))
		else
			local after = ns.Ledger.Summary()
			if after.given - before.given ~= 1 or after.totals.group - before.totals.group ~= 1 then
				fail(scenario, ("one group cast counted as %d given today, %d to the group")
					:format(after.given - before.given, after.totals.group - before.totals.group))
			end
			local given = ns.Ledger.Entries("given")[1]
			if not (given and given.covered == 4 and given.spell == BRILLIANCE) then
				fail(scenario, "the ledger row does not say one Arcane Brilliance reached four: "
					.. tostring(given and given.covered))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-12
-- A late refusal: the server turns the group cast down after it was sent,
-- and every favour it returned is owed again, the ledger's rows with them.
do
	local scenario = "groupbuffs: a late refusal puts every favour back"
	local ns, restore = session(scenario, mage())
	if ns then
		H.owe(ns, "Cora Vell")
		H.owe(ns, "Dain Moor")
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local ran = pressAndCast(ns, BRILLIANCE, "Cast-G5")
		if not (ran and ran:find("Arcane Brilliance", 1, true)) or ns.owed["Dain Moor"] then
			fail(scenario, "SKIPPED -- the group cast did not settle both favours: " .. flat(ran))
		else
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-G5", BRILLIANCE)
			if not (ns.owed["Cora Vell"] and ns.owed["Dain Moor"]) then
				fail(scenario, "a favour the refused group cast had returned is not owed again")
			end
			for _, e in ipairs(ns.Ledger.Entries("favours")) do
				if (e.name == "Cora Vell" or e.name == "Dain Moor") and e.state ~= "owed" then
					fail(scenario, "the ledger still shows " .. e.name .. "'s favour " .. tostring(e.state))
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-13
-- A press the game refused at once (out of range): nobody got anything, so
-- everybody it covered is back after the two seconds a failed press writes,
-- not the whole retry cooldown.
do
	local scenario = "groupbuffs: a refused press gives everybody it covered back"
	local ns, restore = session(scenario, mage())
	if ns then
		local ran = H.pressButton(ns)
		if not (ran and ran:find("Arcane Brilliance", 1, true)) then
			fail(scenario, "SKIPPED -- the press did not cast the group spell: " .. flat(ran))
		else
			ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
			Mock.advance(3)
			ns.Guard("sweep", ns.SweepPendingClick, GetTime())
			local group = groupCast(ns)
			if not group or covered(group) ~= "Bram Oake, Cora Vell, Dain Moor, Gwen Hale" then
				fail(scenario, "three seconds after a refused press the party is not offered again: "
					.. tostring(group and covered(group)))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-14
-- The same person moving from a single cast to the group one: two of the
-- party missing it (one by one), then two more, and the macro follows.
do
	local scenario = "groupbuffs: the macro follows a party filling up"
	local env = mage({ held = { party1 = { [10157] = true }, party3 = { [10157] = true } } })
	local ns, restore = session(scenario, env)
	if ns then
		local before = macro(ns)
		if not (before and before:find("/target Bram Oake\n/cast Arcane Intellect", 1, true)) then
			fail(scenario, "SKIPPED -- Bram's single cast is not armed: " .. flat(before))
		else
			env.held.party1, env.held.party3 = nil, nil
			Mock.advance(4)
			ns.addon:Tick()
			local after = macro(ns)
			if not (after and after:find("/target Bram Oake\n/cast Arcane Brilliance", 1, true)) then
				fail(scenario, "the macro still casts the single buff at a party that now wants the group one: "
					.. flat(after))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-15
-- A fight freezes the macro: the group cast armed at the pull is what every
-- press in it casts, and a press in it still covers the whole party.
do
	local scenario = "groupbuffs: a fight freezes the group cast"
	local env = mage()
	local ns, restore = session(scenario, env)
	if ns then
		local armed = macro(ns)
		if not (armed and armed:find("Arcane Brilliance", 1, true)) then
			fail(scenario, "SKIPPED -- no group cast armed before the fight: " .. flat(armed))
		else
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
			-- Two of them buffed by somebody else mid-fight: out of combat that
			-- would drop the party under the threshold.
			env.held.party1 = { [10157] = true }
			env.held.party2 = { [10157] = true }
			Mock.advance(4)
			ns.addon:Tick()
			if macro(ns) ~= armed then
				fail(scenario, "the macro changed in a fight: " .. flat(macro(ns)))
			end
			local ran = pressAndCast(ns, BRILLIANCE, "Cast-G6")
			if ran ~= armed then
				fail(scenario, "the press in the fight ran something else: " .. flat(ran))
			end
			if ns.pendingClick then fail(scenario, "the press in the fight was never settled") end
			local blocked = 0
			for _, name in ipairs({ "Gwen Hale", "Bram Oake", "Cora Vell", "Dain Moor" }) do
				if ns.IsBlocked(name, "intellect") then blocked = blocked + 1 end
			end
			if blocked ~= 4 then
				fail(scenario, "the press in the fight covered " .. blocked .. " of the four")
			end
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_ENABLED()
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-16
-- Readings nobody could make do not count towards the threshold: a reagent is
-- not spent on people who may already have the buff.
do
	local scenario = "groupbuffs: unread auras do not count as missing"
	local ns, restore = session(scenario, mage({ setup = function(ns)
		ns.db.profile.filters.whenBuffed = "always"
	end }))
	if ns then
		local _, singles = offers(ns, "intellect")
		if singles == 0 then
			fail(scenario, "SKIPPED -- nobody is offered with Always offer")
		elseif groupCast(ns) then
			fail(scenario, "a group cast was offered for people nobody read as missing it")
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-17
-- The macro aims at somebody in reach: with only one of them measured in
-- range, the group cast is aimed at that one; with none, there is none.
do
	local scenario = "groupbuffs: the group cast is aimed at somebody in range"
	local ns, restore = session(scenario, mage({ setup = function(ns)
		ns.db.profile.filters.requireInRange = false
	end }))
	if ns then
		Mock.rangeByUnit = { party1 = false, party2 = false, party3 = false, party4 = true }
		Mock.advance(4)
		local group = groupCast(ns)
		if not group or group.name ~= "Dain Moor" then
			fail(scenario, "the group cast is not aimed at the one in range: " .. tostring(group and group.name))
		end
		Mock.rangeByUnit = { party1 = false, party2 = false, party3 = false, party4 = false }
		Mock.advance(4)
		if groupCast(ns) then
			fail(scenario, "a group cast was aimed at somebody measured out of range")
		end
		Mock.rangeByUnit = nil
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-18
-- Running out: a note the moment the last reagent goes, once, and the prompt
-- back to single casts.
do
	local scenario = "groupbuffs: a gentle note when the reagent runs out"
	local env = mage({ bags = { [ARCANE_POWDER] = 1 } })
	local ns, restore = session(scenario, env)
	if ns then
		if not groupCast(ns) then
			fail(scenario, "SKIPPED -- no group cast with one Arcane Powder")
		else
			Mock.printed = {}
			env.bags[ARCANE_POWDER] = 0
			ns.addon:Tick()
			ns.addon:Tick()
			local said = table.concat(Mock.printed, "\n")
			local _, notes = said:gsub("you are out of Arcane Powder", "")
			if notes ~= 1 then
				fail(scenario, ("running out was said %d times: %s"):format(notes, said))
			end
			local _, singles = offers(ns, "intellect")
			if groupCast(ns) or singles ~= 4 then
				fail(scenario, "the prompt did not go back to single casts with no reagent left")
			end
			Mock.printed = {}
			env.bags[ARCANE_POWDER] = 5
			ns.addon:Tick()
			env.bags[ARCANE_POWDER] = 0
			ns.addon:Tick()
			if table.concat(Mock.printed, "\n"):find("you are out of", 1, true) then
				fail(scenario, "the note came back a second time in one session")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-19
-- The settings: on by default with a threshold of three, repaired when a file
-- holds nonsense, and on the Who to buff tab beside "My party and raid",
-- shown to a class with a group version and hidden from one without.
do
	local scenario = "groupbuffs: the settings"
	local ns, restore = session(scenario, mage())
	if ns then
		local g = ns.db.profile.groupBuffs
		if g.use ~= true or g.atLeast ~= 3 then
			fail(scenario, ("a new profile has use=%s atLeast=%s, not on and 3"):format(tostring(g.use), tostring(g.atLeast)))
		end
		for _, case in ipairs({
			{ use = "yes", atLeast = 9, want = { true, 5 } },
			{ use = false, atLeast = "x", want = { false, 3 } },
			{ use = true, atLeast = 2.6, want = { true, 2 } },
			{ use = true, atLeast = 1, want = { true, 2 } },
		}) do
			g.use, g.atLeast = case.use, case.atLeast
			ns.ClampSettings()
			if g.use ~= case.want[1] or g.atLeast ~= case.want[2] then
				fail(scenario, ("use=%s atLeast=%s was repaired to %s/%s, not %s/%s"):format(
					tostring(case.use), tostring(case.atLeast), tostring(g.use), tostring(g.atLeast),
					tostring(case.want[1]), tostring(case.want[2])))
			end
		end
		g.use, g.atLeast = true, 3

		local who = ns.optionsTable and ns.optionsTable.args.who
		local toggle = who and who.args.groupBuffsUse
		local slider = who and who.args.groupBuffsAtLeast
		if not (toggle and slider) then
			fail(scenario, "the Who to buff tab has no group buff controls")
		else
			if not (toggle.order > who.args.group.order and slider.order > toggle.order
				and slider.order < who.args.strangers.order) then
				fail(scenario, "the group buff controls are not right under My party and raid")
			end
			if toggle.hidden() or slider.hidden() then
				fail(scenario, "the controls are hidden from a mage")
			end
			toggle.set({ "groupBuffsUse" }, false)
			if g.use ~= false or toggle.get({ "groupBuffsUse" }) ~= false then
				fail(scenario, "the toggle does not switch group buffs off")
			end
			if live(slider) then
				fail(scenario, "the threshold stays live with group buffs off")
			end
			toggle.set({ "groupBuffsUse" }, true)
			slider.set({ "groupBuffsAtLeast" }, 4)
			if g.atLeast ~= 4 or slider.get({ "groupBuffsAtLeast" }) ~= 4 then
				fail(scenario, "the slider does not set the threshold")
			end
			ns.db.profile.sources.group = false
			if live(toggle) then
				fail(scenario, "the toggle stays live with My party and raid off")
			end
			ns.db.profile.sources.group = true
			if #tostring(toggle.desc or "") < 40 or #tostring(slider.desc or "") < 40 then
				fail(scenario, "a control has no description")
			end
		end
		guarded(scenario, ns)
		restore()
	end

	local scenario2 = "groupbuffs: the settings are hidden from a class without a group version"
	local ns2, restore2 = session(scenario2, { class = "WARLOCK", known = { 5697 } })
	if ns2 then
		local who = ns2.optionsTable and ns2.optionsTable.args.who
		local toggle = who and who.args.groupBuffsUse
		if not toggle then
			fail(scenario2, "SKIPPED -- no group buff toggle to hide")
		elseif not toggle.hidden() then
			fail(scenario2, "a warlock is shown a setting for group buffs he does not have")
		end
		guarded(scenario2, ns2)
		restore2()
	end
end
