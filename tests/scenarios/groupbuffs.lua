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
		C_UnitAuras = rawget(_G, "C_UnitAuras"), C_Spell = rawget(_G, "C_Spell"),
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
			-- The player wears their own, as in the shared mock, unless the
			-- scenario says what they carry: tests/scenarios/self.lua counts
			-- them into a group cast.
			if unit == "player" and env.held.player == nil then
				return base.GetUnitAuraBySpellID(unit, spellId)
			end
			local carrying = env.held[unit]
			local source = carrying and carrying[spellId]
			if not source then return nil end
			-- env.expires[unit]: seconds left on what they carry, for a top-up.
			local left = env.expires and env.expires[unit] or 3600
			return { spellId = spellId, expirationTime = Mock.now + left, duration = 3600,
				sourceUnit = type(source) == "string" and source or "player" }
		end,
	}, { __index = base }))
	-- The group spell's own icon, told apart from every other spell's.
	-- Read through _G, which builds the mock's C_Spell if nothing has yet.
	local spells = env.groupIcon and C_Spell
	if type(spells) == "table" then
		local realTexture = spells.GetSpellTexture
		rawset(_G, "C_Spell", setmetatable({
			GetSpellTexture = function(id)
				if id == BRILLIANCE then return env.groupIcon end
				return realTexture and realTexture(id)
			end,
		}, { __index = spells }))
	end
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
		rawset(_G, "C_Spell", saved.C_Spell)
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
			if line ~= "Your party" or not sub:find("Arcane Brilliance -- 4 missing", 1, true) then
				fail(scenario, "the panel does not name the party and the count: " .. line .. " / " .. sub)
			end
			local summary = table.concat(ns.Prompt:ClickSummary(group), " / ")
			if not summary:find("casts |cffffffffArcane Brilliance|r on everybody in your party.", 1, true) then
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
		elseif not said:find("4 in your party are missing Arcane Intellect.", 1, true) then
			fail(scenario, "the tooltip does not say how many are missing it: " .. said)
		elseif not (said:find("Right-click to skip this group buff for now.", 1, true)
			and said:find("Shift-right-click to put Bram Oake on your never-offer list.", 1, true)) then
			fail(scenario, "the tooltip does not say what a right-click does to a group cast: " .. said)
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
	{ label = "mana enough only for the single spell", env = mage(), noMana = true },
}) do
	local scenario = "groupbuffs: " .. case.label .. ", they are buffed one by one"
	local realUsable = rawget(_G, "IsUsableSpell")
	if case.unusable then
		IsUsableSpell = function(id) if id == BRILLIANCE then return false, false end return true, false end
	elseif case.noMana then
		-- The client's "not for want of mana": the group spell costs more.
		IsUsableSpell = function(id) if id == BRILLIANCE then return false, true end return true, false end
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
			if ns.Prompt:RenderPrimary(group, 0) ~= "Every Warrior" then
				fail(scenario, "the panel does not name the class: " .. ns.Prompt:RenderPrimary(group, 0))
			end
			-- A paladin reads about classes, not parties.
			local _, slider = ns.GroupBuffDescriptions()
			if not tostring(slider):find("of one class", 1, true) then
				fail(scenario, "a paladin's threshold does not say it counts one class: " .. tostring(slider))
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
-- holds nonsense, and on the Who to buff tab under "My group and raid",
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
		local toggle = who and H.findOption(ns.optionsTable, "groupBuffsUse")
		local slider = who and H.findOption(ns.optionsTable, "groupBuffsAtLeast")
		if not (toggle and slider) then
			fail(scenario, "the Who to buff tab has no group buff controls")
		else
			local header = H.findOption(ns.optionsTable, "groupHeader")
			local raidGroups = H.findOption(ns.optionsTable, "skipRaidGroups")
			if not (header and raidGroups and toggle.order > header.order and slider.order > toggle.order
				and slider.order < raidGroups.order) then
				fail(scenario, "the group buff controls are not right under My group and raid")
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
			local function said(option)
				local desc = option.desc
				if type(desc) == "function" then desc = desc() end
				return tostring(desc or "")
			end
			if #said(toggle) < 40 or #said(slider) < 40 then
				fail(scenario, "a control has no description")
			end
			-- Worded for a mage: the spell learned, and parties, not classes.
			if not said(toggle):find("Arcane Brilliance", 1, true) or said(toggle):find("Greater Blessing", 1, true) then
				fail(scenario, "the toggle does not name the mage's own group spell: " .. said(toggle))
			end
			if not said(slider):find("one party", 1, true) then
				fail(scenario, "the threshold does not say it counts one party or raid group: " .. said(slider))
			end
			if slider.name ~= "When this many need it" then
				fail(scenario, "the threshold's name does not say what happens at the number: " .. tostring(slider.name))
			end
		end
		guarded(scenario, ns)
		restore()
	end

	local scenario2 = "groupbuffs: the settings are hidden from a class without a group version"
	local ns2, restore2 = session(scenario2, { class = "WARLOCK", known = { 5697 } })
	if ns2 then
		local who = ns2.optionsTable and ns2.optionsTable.args.who
		local toggle = who and H.findOption(ns2.optionsTable, "groupBuffsUse")
		if not toggle then
			fail(scenario2, "SKIPPED -- no group buff toggle to hide")
		elseif not toggle.hidden() then
			fail(scenario2, "a warlock is shown a setting for group buffs he does not have")
		end
		guarded(scenario2, ns2)
		restore2()
	end
end

-- ------------------------------------------------------------ groupbuffs-20
-- The spoken line follows the spell: when the party drops under the threshold
-- the same person goes from the group cast to a single one, and back, and the
-- line must name what the macro casts each time.
do
	local scenario = "groupbuffs: the spoken line follows the spell between group and single"
	local env = mage()
	local ns, restore = session(scenario, env)
	if ns then
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		speech.phrases = "Here is {buff}, {name}."
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local before = macro(ns)
		if not (before and before:find("/cast Arcane Brilliance\n/say Here is Arcane Brilliance", 1, true)) then
			fail(scenario, "SKIPPED -- the group cast is not armed with its line: " .. flat(before))
		else
			-- Somebody else buffs two of them: two left is under three.
			env.held.party3 = { [10157] = "raid9" }
			env.held.party4 = { [10157] = "raid9" }
			Mock.advance(5)
			ns.addon:Tick()
			local single = macro(ns)
			if not (single and single:find("/cast Arcane Intellect", 1, true)) then
				fail(scenario, "SKIPPED -- the prompt did not go back to a single cast: " .. flat(single))
			elseif not single:find("/say Here is Arcane Intellect", 1, true) then
				fail(scenario, "the spoken line kept the group spell for a single cast: " .. flat(single))
			end
			env.held.party3, env.held.party4 = nil, nil
			Mock.advance(5)
			ns.addon:Tick()
			local again = macro(ns)
			if again and again:find("/cast Arcane Brilliance", 1, true)
				and not again:find("/say Here is Arcane Brilliance", 1, true) then
				fail(scenario, "the spoken line kept the single spell for a group cast: " .. flat(again))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-21
-- The in-character set names the spell that goes out as well, and leaves out
-- a line that names the single spell outright ("Mark of the Wild, {name}.")
-- when the cast is Gift of the Wild.
for _, case in ipairs({
	{ label = "Arcane Brilliance", env = mage(), wrong = "Arcane Intellect", right = "Arcane Brilliance" },
	{ label = "Gift of the Wild", env = { class = "DRUID",
		known = { 9885, 9884, 8907, 5234, 6756, 5232, 1126, 21849 }, bags = { [WILD_BERRIES] = 5 } },
		wrong = "Mark of the Wild", right = "Gift of the Wild" },
}) do
	local scenario = "groupbuffs: an in-character line names the group spell (" .. case.label .. ")"
	local ns, restore = session(scenario, case.env)
	if ns then
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		local preset = H.findOption(ns.optionsTable, "preset")
		local group = groupCast(ns)
		if not (preset and preset.set and group) then
			fail(scenario, "SKIPPED -- no preset control or no group cast")
		else
			preset.set({ "preset" }, "incharacter")
			local wrong, right = 0, 0
			local sample
			for _ = 1, 2000 do
				local line = ns.PickPhrase(group, 255) or ""
				if line:find(case.wrong, 1, true) then
					wrong = wrong + 1
					sample = sample or line
				end
				if line:find(case.right, 1, true) then right = right + 1 end
			end
			if wrong > 0 then
				fail(scenario, wrong .. " in-character lines named the single spell over a group cast: " .. sample)
			elseif right == 0 then
				fail(scenario, "no in-character line in 2000 named " .. case.right)
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-22
-- A favour owed at the head of the party: the cast returns it, and the cast
-- itself is still one buff given, reaching four -- whoever it was aimed at.
-- A late refusal takes that row back with the favour.
do
	local scenario = "groupbuffs: a group cast aimed at a favour still counts as one buff given"
	local ns, restore = session(scenario, mage())
	if ns then
		H.owe(ns, "Cora Vell")
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local before = ns.Ledger.Summary()
		local rows = #ns.Ledger.Entries("given")
		local ran = pressAndCast(ns, BRILLIANCE, "Cast-G7")
		if not (ran and ran:find("/target Cora Vell", 1, true) and ran:find("Arcane Brilliance", 1, true)) then
			fail(scenario, "SKIPPED -- the press was not the group cast at Cora: " .. flat(ran))
		else
			local after = ns.Ledger.Summary()
			if after.given - before.given ~= 1 or after.totals.group - before.totals.group ~= 1 then
				fail(scenario, ("a group cast aimed at a favour counted as %d given today, %d to the group")
					:format(after.given - before.given, after.totals.group - before.totals.group))
			end
			local given = ns.Ledger.Entries("given")[1]
			if #ns.Ledger.Entries("given") ~= rows + 1 or not (given and given.covered == 4
				and given.spell == BRILLIANCE and given.name ~= "Cora Vell") then
				fail(scenario, "no row says one Arcane Brilliance reached four: " .. tostring(given and given.name))
			end
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-G7", BRILLIANCE)
			local undone = ns.Ledger.Summary()
			if #ns.Ledger.Entries("given") ~= rows or undone.given ~= before.given then
				fail(scenario, "a late refusal left the group cast counted as given")
			end
			if not ns.owed["Cora Vell"] then
				fail(scenario, "a late refusal did not put Cora's favour back")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-23
-- The ledger row keeps its count through a reload, when every saved row goes
-- through the ledger's repair.
do
	local scenario = "groupbuffs: the ledger row keeps its count through a reload"
	local ns, restore = session(scenario, mage())
	if ns then
		local ran = pressAndCast(ns, BRILLIANCE, "Cast-G8")
		if not (ran and ran:find("Arcane Brilliance", 1, true)) then
			fail(scenario, "SKIPPED -- the press did not cast the group spell: " .. flat(ran))
		else
			-- A fresh table is what a reload hands the ledger: it is repaired
			-- row by row before anything reads it.
			local saved = ns.db.char.ledger
			local copy = {}
			for k, v in pairs(saved) do copy[k] = v end
			ns.db.char.ledger = copy
			ns.Ledger.Load()
			local given = ns.Ledger.Entries("given")[1]
			if not (given and given.covered == 4) then
				fail(scenario, "after a reload the row no longer says how many it reached: "
					.. tostring(given and given.covered))
			end
		end
		-- A client that withholds the id of what went out: the row still
		-- names the group spell, which is what the macro cast.
		Mock.advance(20)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local again = pressAndCast(ns, Mock.SECRET, "Cast-G11")
		if again and again:find("Arcane Brilliance", 1, true) then
			local given = ns.Ledger.Entries("given")[1]
			if not (given and given.spell == BRILLIANCE) then
				fail(scenario, "with the id withheld the row names " .. tostring(given and given.spell)
					.. ", not the group spell")
			end
		else
			fail(scenario, "SKIPPED -- no second group cast to press: " .. flat(again))
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-24
-- Not now, on a group cast: the whole party is skipped, not the one it was
-- aimed at, and chat says so. It all comes back after the retry cooldown.
do
	local scenario = "groupbuffs: not now on a group cast skips the whole party"
	local ns, restore = session(scenario, mage())
	if ns then
		if not groupCast(ns) then
			fail(scenario, "SKIPPED -- no group cast to skip")
		else
			Mock.printed = {}
			H.pressButton(ns, "RightButton")
			ns.addon:Tick()
			local _, left = offers(ns, "intellect")
			if left ~= 0 then
				fail(scenario, left .. " offers of Arcane Intellect came straight back after skipping the party")
			end
			local said = table.concat(Mock.printed, "\n")
			if not said:find("skipping |cffffffffyour party|r for now.", 1, true) then
				fail(scenario, "chat does not say the party was skipped: " .. said)
			end
			Mock.advance(13)
			local back = groupCast(ns)
			if not back or covered(back) ~= "Bram Oake, Cora Vell, Dain Moor, Gwen Hale" then
				fail(scenario, "the party did not come back after the cooldown")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- Never, on a group cast: only the one it was aimed at goes on the list, the
-- rest are skipped for now, and chat says both.
do
	local scenario = "groupbuffs: never on a group cast lists one and skips the rest"
	local ns, restore = session(scenario, mage())
	if ns then
		local group = groupCast(ns)
		if not group then
			fail(scenario, "SKIPPED -- no group cast")
		else
			local realShift = rawget(_G, "IsShiftKeyDown")
			IsShiftKeyDown = function() return true end
			Mock.printed = {}
			H.pressButton(ns, "RightButton")
			rawset(_G, "IsShiftKeyDown", realShift)
			ns.addon:Tick()
			if not ns.IsNeverOffered(group.name) then
				fail(scenario, "the one the cast was aimed at is not on the never-offer list")
			end
			for _, name in ipairs(group.groupCast.members) do
				if ns.IsNeverOffered(name) then fail(scenario, name .. " was listed with the one aimed at") end
			end
			local _, left = offers(ns, "intellect")
			if left ~= 0 then
				fail(scenario, left .. " of the rest came straight back after never")
			end
			if not table.concat(Mock.printed, "\n"):find("The rest of your party is skipped for now.", 1, true) then
				fail(scenario, "chat does not say the rest were skipped: " .. table.concat(Mock.printed, "\n"))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- The launcher says what the prompt says: the party and the group spell, in
-- the tooltip and in Who's next, and Skip for now there skips the party.
do
	local scenario = "groupbuffs: the launcher names the group cast and skips it whole"
	local ns, restore = session(scenario, mage())
	if ns then
		local broker = Mock.broker
		if not (groupCast(ns) and broker and broker.OnTooltipShow and broker.OnClick) then
			fail(scenario, "SKIPPED -- no group cast or no launcher")
		else
			local lines = {}
			broker.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = tostring(text) end })
			local tip = table.concat(lines, "\n")
			if not tip:find("On the prompt: |cffffffffYour party|r -- Arcane Brilliance", 1, true) then
				fail(scenario, "the launcher's tooltip does not name the group cast: " .. tip)
			end
			local function newMenu(text, fn)
				local d = { text = text, fn = fn, items = {} }
				local function add(item) d.items[#d.items + 1] = item return item end
				function d:CreateTitle(t) return add({ text = t, items = {} }) end
				function d:CreateDivider() return add({ items = {} }) end
				function d:CreateButton(t, f) return add(newMenu(t, f)) end
				function d:CreateCheckbox(t) return add(newMenu(t)) end
				function d:CreateRadio(t) return add(newMenu(t)) end
				function d:SetEnabled() end
				function d:SetTooltip() end
				return d
			end
			local function child(root, pattern)
				for _, item in ipairs(root and root.items or {}) do
					if item.text and tostring(item.text):find(pattern) then return item end
				end
			end
			local realMenu, opened = rawget(_G, "MenuUtil"), nil
			MenuUtil = { CreateContextMenu = function(owner, generator)
				opened = newMenu()
				generator(owner, opened)
				return opened
			end }
			local ok, err = pcall(broker.OnClick, {}, "RightButton")
			rawset(_G, "MenuUtil", realMenu)
			local person = ok and child(child(opened, "^Who's next$"), "^Your party %-%- Arcane Brilliance")
			local skip = person and child(person, "^Skip for now$")
			if not skip then
				fail(scenario, "Who's next does not list the group cast as the prompt names it: " .. tostring(err))
			else
				Mock.printed = {}
				skip.fn()
				ns.addon:Tick()
				local _, left = offers(ns, "intellect")
				if left ~= 0 then
					fail(scenario, left .. " offers came straight back after Skip for now on the party")
				end
				if not table.concat(Mock.printed, "\n"):find("skipping |cffffffffyour party|r", 1, true) then
					fail(scenario, "Skip for now does not say the party was skipped")
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-25
-- A party member who asked in chat is answered by the group cast aimed at
-- somebody else: their request is closed, not offered again once the
-- cooldown is out.
do
	local scenario = "groupbuffs: a group cast answers a member who asked in chat"
	local ns, restore = session(scenario, mage({ setup = function(ns)
		ns.db.profile.sources.asked = true
	end }))
	if ns then
		local function hear(text, sender, guid)
			ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
		end
		-- Two ask, so the cast is aimed at one of them (Cora, by name) and
		-- Dain's request can only be answered as somebody it covered.
		hear("int pls", "Cora Vell", "Player-1-party3")
		hear("int pls", "Dain Moor", "Player-1-party4")
		local function reasonOfDain()
			local use = ns.db.profile.groupBuffs.use
			ns.db.profile.groupBuffs.use = false
			local all = offers(ns, "intellect")
			ns.db.profile.groupBuffs.use = use
			return all["Dain Moor"] and all["Dain Moor"].reason
		end
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local group = groupCast(ns)
		if reasonOfDain() ~= "asked" or not group or group.name == "Dain Moor" then
			fail(scenario, "SKIPPED -- Dain's request is not standing behind a group cast at somebody else: "
				.. tostring(reasonOfDain()) .. " / " .. tostring(group and group.name))
		else
			local ran = pressAndCast(ns, BRILLIANCE, "Cast-G9")
			if not (ran and ran:find("Arcane Brilliance", 1, true)) then
				fail(scenario, "SKIPPED -- the press did not cast the group spell: " .. flat(ran))
			else
				Mock.advance(13)
				if reasonOfDain() == "asked" then
					fail(scenario, "Dain's request still stands after the group cast covered him")
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-26
-- A late refusal after somebody it covered was put on the never-offer list
-- since the settle: their favour is let go, not owed again, as the anchor's is.
do
	local scenario = "groupbuffs: a late refusal lets go a favour listed since the settle"
	local ns, restore = session(scenario, mage())
	if ns then
		H.owe(ns, "Cora Vell")
		H.owe(ns, "Dain Moor")
		-- Dain's favour in the ledger as a buff landing files it, so there is
		-- a row for the refusal to put back and the listing to let go.
		ns.Ledger.Received({ name = "Dain Moor", key = 10157, class = "MAGE" })
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local ran = pressAndCast(ns, BRILLIANCE, "Cast-G10")
		if not (ran and ran:find("/target Cora Vell", 1, true)) or ns.owed["Dain Moor"] then
			fail(scenario, "SKIPPED -- the group cast at Cora did not settle Dain's favour: " .. flat(ran))
		else
			ns.PutOnNeverList("Dain Moor")
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-G10", BRILLIANCE)
			if ns.owed["Dain Moor"] then
				fail(scenario, "a favour listed since the settle is owed again after the refusal")
			end
			local state = "no row"
			for _, e in ipairs(ns.Ledger.Entries("favours")) do
				if e.name == "Dain Moor" then state = tostring(e.state) end
			end
			if state ~= "letgo" then
				fail(scenario, "the ledger shows Dain's favour " .. state .. ", not let go")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-27
-- The panel's icon is the group spell's own.
do
	local scenario = "groupbuffs: the panel shows the group spell's icon"
	local ns, restore = session(scenario, mage({ groupIcon = 777001 }))
	if ns then
		local group = groupCast(ns)
		local icon = ns.Prompt:Regions().icon
		if not (group and icon) then
			fail(scenario, "SKIPPED -- no group cast or no icon")
		else
			local shown
			local realSet = icon.SetTexture
			icon.SetTexture = function(self, file, ...)
				shown = file
				return realSet(self, file, ...)
			end
			ns.Prompt:Paint(group, 0)
			icon.SetTexture = realSet
			if shown ~= 777001 then
				fail(scenario, "the panel shows icon " .. tostring(shown) .. ", not the group spell's")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-28
-- Who it is for, as players say it: in a raid, your own subgroup is "Your
-- group" and another is "Group 2"; the tooltip says the same.
do
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	local scenario = "groupbuffs: in a raid the panel names the raid group"
	-- Everybody in both subgroups missing it: two group casts.
	local ns, restore = session(scenario, mage({ raid = { size = 10, player = 1 }, names = names }))
	if ns then
		local seen = {}
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then seen[#seen + 1] = ns.Prompt:RenderPrimary(entry, 0) end
		end
		table.sort(seen)
		if table.concat(seen, ", ") ~= "Group 2, Your group" then
			fail(scenario, "the raid's group casts are not named by raid group: " .. table.concat(seen, ", "))
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-29
-- Missing and running out, told apart: a top-up before a pull says "running
-- out", not "missing", and a mix says how many need it.
do
	local scenario = "groupbuffs: running out is not called missing"
	local env = mage({
		held = { party1 = { [10157] = true }, party2 = { [10157] = true },
			party3 = { [10157] = true }, party4 = { [10157] = true } },
		expires = { party1 = 120, party2 = 120, party3 = 120, party4 = 120 },
		setup = function(ns) ns.db.profile.filters.whenBuffed = "refresh" end,
	})
	local ns, restore = session(scenario, env)
	if ns then
		local group = groupCast(ns)
		if not group then
			fail(scenario, "SKIPPED -- no group cast for four running out")
		else
			local sub = ns.Prompt:ReasonText(group)
			if sub ~= "Arcane Brilliance -- 4 running out" then
				fail(scenario, "four running out reads: " .. sub)
			end
			env.held.party3, env.held.party4 = nil, nil
			Mock.advance(4)
			local mixed = groupCast(ns)
			local text = mixed and ns.Prompt:ReasonText(mixed) or "nothing"
			if text ~= "Arcane Brilliance -- 4 need it" then
				fail(scenario, "two missing and two running out reads: " .. text)
			end
			if mixed then
				ns.Prompt:ApplyTarget(nil)
				ns.Prompt:InvalidateMacro()
				ns.addon:Tick()
				local button = ns.Prompt:GetButton()
				Mock.tooltip = {}
				if button.scripts.OnEnter then button.scripts.OnEnter(button) end
				local tip = table.concat(Mock.tooltip, " / ")
				if not (tip:find("2 in your party are missing Arcane Intellect.", 1, true)
					and tip:find("2 more are running out.", 1, true)) then
					fail(scenario, "the tooltip does not tell missing from running out: " .. tip)
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-30
-- A heads-up while there is time to buy more: once, when a cast takes the
-- count down to five or fewer. Not for a count that went up (a few bought, or
-- the bags at login), which is nothing spent.
do
	local scenario = "groupbuffs: a heads-up when the reagent runs low"
	-- Empty through the load, whose chat the session clears, so the three
	-- bought below are heard.
	local env = mage({ bags = { [ARCANE_POWDER] = 0 } })
	local ns, restore = session(scenario, env)
	if ns then
		Mock.printed = {}
		env.bags[ARCANE_POWDER] = 3
		ns.addon:Tick()
		local said = table.concat(Mock.printed, "\n")
		if said:find("Arcane Powder left", 1, true) then
			fail(scenario, "the heads-up came at login, before anything was spent")
		end
		env.bags[ARCANE_POWDER] = 7
		ns.addon:Tick()
		Mock.printed = {}
		env.bags[ARCANE_POWDER] = 5
		ns.addon:Tick()
		env.bags[ARCANE_POWDER] = 4
		ns.addon:Tick()
		said = table.concat(Mock.printed, "\n")
		local _, notes = said:gsub("Arcane Powder left", "")
		if notes ~= 1 or not said:find("5 Arcane Powder left", 1, true) then
			fail(scenario, ("the heads-up was said %d times: %s"):format(notes, said))
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ groupbuffs-31
-- A group cast aimed at somebody who asked for it in chat. An asker outranks
-- the party, so the cast is aimed at them whenever one of the party asked --
-- and filed under their reason alone, it was listed as asked for and left out
-- of the day's gifts, though it reached the rest of the party unprompted. It
-- is asked for only when everybody it covered asked.
do
	local scenario = "groupbuffs: a group cast aimed at somebody who asked is still a gift"
	local function ask(ns, token)
		local names = PARTY[token]
		ns.addon:CHAT_MSG_PARTY("CHAT_MSG_PARTY", "int pls", names[1] .. " " .. names[2], "Common", "",
			"", "", 0, 0, "", 0, 1, "Player-1-" .. token)
	end
	for _, case in ipairs({
		{ askers = { "party3" }, asked = false, label = "one of four asked" },
		{ askers = { "party1", "party2", "party3", "party4" }, asked = true, label = "all four asked" },
	}) do
		local ns, restore = session(scenario, mage({
			setup = function(ns) ns.db.profile.sources.asked = true end,
		}))
		if ns then
			ns.db.char.ledger = nil
			ns.Ledger.Load()
			for _, token in ipairs(case.askers) do ask(ns, token) end
			ns.Prompt:InvalidateMacro()
			ns.addon:Tick()
			local group = groupCast(ns)
			local showing = ns.Prompt:Showing()
			if not (group and showing and showing.groupCast and showing.reason == "asked") then
				fail(scenario, "SKIPPED -- " .. case.label .. ", and the group cast is not aimed at an asker: "
					.. tostring(showing and showing.name) .. " " .. tostring(showing and showing.reason))
			else
				local ran = pressAndCast(ns, BRILLIANCE, "Cast-G31-" .. #case.askers)
				local row = ns.Ledger.Entries("given")[1]
				if not (ran and ran:find("Arcane Brilliance", 1, true) and row and row.covered == 4) then
					fail(scenario, "SKIPPED -- " .. case.label .. ", and the group cast filed no row: " .. flat(ran))
				elseif case.asked and row.asked ~= true then
					fail(scenario, "everybody it covered asked, and the group cast was filed as given unprompted")
				elseif not case.asked and row.asked then
					fail(scenario, "a group cast aimed at the one who asked was filed as asked for")
				else
					local given = ns.Ledger.Summary().given
					if given ~= (case.asked and 0 or 1) then
						fail(scenario, ("%s, and the group cast counts as %d of today's gifts")
							:format(case.label, given))
					end
				end
			end
			guarded(scenario, ns)
			restore()
		end
	end
end
