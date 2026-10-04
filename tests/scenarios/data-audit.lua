-- The buff data held to WoW Forever's own spell tables (build 1.60.1.70178,
-- from wago.tools): the ids, rank levels, reagents and reach Buffs.lua gives
-- the camelot set, each pinned by what a player would see if it were wrong.
--
-- - A priest's, mage's or druid's group version reaches the caster's whole
--   party and raid on Forever (target 56), not the target's subgroup.
-- - Prayer of Fortitude's first rank takes a Holy Candle.
-- - Omen of Clarity is a passive on Forever: nothing to cast.
-- - Kings and Divine Spirit are trained on Forever, not talents.
-- - Blessing of Sanctuary is gone from Forever's client.
-- - Blessing of Salvation reaches only your party or raid (target 57).
-- - A Fear Ward, a Soulstone and the like are favours.
-- - A shaman's Water Breathing counts as Unending Breath.
-- - "ub" asks a warlock for Unending Breath.
--
-- Every scenario name starts with "data-audit:" so the mutations in
-- tests/mutations/data-audit.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local ARCANE_POWDER, HOLY_CANDLE, SACRED_CANDLE = 17020, 17028, 17029
local ITEM_NAMES = { [ARCANE_POWDER] = "Arcane Powder", [HOLY_CANDLE] = "Holy Candle",
	[SACRED_CANDLE] = "Sacred Candle" }
-- What each group spell eats, by Forever's SpellReagents: the client says it
-- cannot be cast without it.
local REAGENT_OF = { [23028] = ARCANE_POWDER, [21562] = HOLY_CANDLE, [21564] = SACRED_CANDLE }

local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }
local BRILLIANCE = 23028
local FORTITUDE = { 10938, 10937, 2791, 1245, 1244, 1243 }
local DIVINE_SPIRIT = { 27841, 14819, 14818, 14752 }
local WISDOM = { 25290, 19854, 19853, 19852, 19850, 19742 }
local MIGHT = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 }
local KINGS, SALVATION = 20217, 1038
local LIGHT = { 19979, 19978, 19977 }
local UNENDING_BREATH, WATER_BREATHING = 5697, 131
local SANCTUARY = { 20914, 20913, 20912, 20911, 25899 }

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitPowerMax", "UnitLevel",
	"UnitInParty", "GetItemCount", "GetItemInfo", "IsUsableSpell", "C_UnitAuras", "C_Spell" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

local function join(...)
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) == "table" then
			for _, id in ipairs(v) do out[#out + 1] = id end
		else
			out[#out + 1] = v
		end
	end
	return out
end

-- The client one scenario stands in: spells known, reagents in the bags (and
-- a group spell unusable without its own), each token's class, level and
-- party membership, the auras each token wears as { [id] = source token, or
-- true for you }, and spell names the mock gets wrong for Forever. You keep
-- the mock's own auras (Mock.playerHeld).
local function client(opts)
	-- Without `known`, the mock's mage and her Arcane Intellect.
	if opts.known then
		local known = {}
		for _, id in ipairs(opts.known) do known[id] = true end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
	end
	local bags = opts.bags or {}
	rawset(_G, "GetItemCount", function(id) return bags[id] or 0 end)
	rawset(_G, "GetItemInfo", function(id) return ITEM_NAMES[id] end)
	rawset(_G, "IsUsableSpell", function(id)
		local need = REAGENT_OF[id]
		if need and (bags[need] or 0) == 0 then return false, false end
		return true, false
	end)
	local classes, levels = opts.classes or {}, opts.levels or {}
	local baseClass = UnitClass
	UnitClass = function(unit)
		local class = classes[unit]
		if class then return class, class end
		return baseClass(unit)
	end
	local basePower = UnitPowerMax
	UnitPowerMax = function(unit, power)
		if classes[unit] == "WARRIOR" then return 0 end
		return basePower(unit, power)
	end
	UnitLevel = function(unit)
		if unit == "player" then return 60 end
		return levels[unit] or 60
	end
	if opts.inParty then
		UnitInParty = function(unit) return opts.inParty[unit] == true end
	end
	opts.held = opts.held or {}
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit == "player" then return base.GetUnitAuraBySpellID(unit, spellId) end
			local carrying = opts.held[unit]
			local source = carrying and carrying[spellId]
			if not source then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3600, duration = 3600,
				sourceUnit = type(source) == "string" and source or "player" }
		end,
	}, { __index = base }))
	if opts.names then
		local spells = C_Spell
		local realName = spells.GetSpellName
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id)
				return opts.names[id] or realName(id)
			end,
		}, { __index = spells }))
	end
end

-- One scenario: the client `opts` describes, nobody about but `opts.people`,
-- the lifecycle driven and the slate cleared, then body(ns). `opts.setup(ns)`
-- runs on the profile before the first scan. Everything is put back and the
-- mock reset, whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.class then Mock.class = opts.class end
	if opts.groupSize then Mock.groupSize = opts.groupSize end
	if opts.raid then Mock.raid = opts.raid end
	if opts.unknown then Mock.unknownSpells = opts.unknown end
	if opts.playerHeld then Mock.playerHeld = opts.playerHeld end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = H.strangers(opts.people or {})
	local ok, err = pcall(function()
		client(opts)
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		if opts.setup then opts.setup(ns) end
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The queue as it stands: the group casts in it, and every entry by name.
local function queue(ns)
	local groups, byName = {}, {}
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.groupCast then groups[#groups + 1] = entry end
		byName[entry.name] = entry
	end
	return groups, byName
end

local function covered(entry)
	local out = { entry.name }
	for _, name in ipairs(entry.groupCast.members) do out[#out + 1] = name end
	table.sort(out)
	return table.concat(out, ", ")
end

local function key(entry) return entry and entry.buff and entry.buff.key end

-- A ten-player raid, raid1 being you: subgroup 1 is raid1-5, 2 raid6-10.
local function raidNames()
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	return names
end
local function wearing(tokens, ids)
	local held = {}
	for _, token in ipairs(tokens) do
		held[token] = {}
		for _, id in ipairs(ids) do held[token][id] = true end
	end
	return held
end

-- ------------------------------------------------------------------ 1
-- Forever's Arcane Brilliance, Prayers and Gift of the Wild reach the
-- caster's whole party and raid within 100 yards (SpellEffect target 56;
-- Classic Era's 37, the target's party). Two missing it in each of two raid
-- groups is four for one cast: one group cast, for the raid, named so.
do
	local scenario = "data-audit: on Forever one group spell covers everybody in the raid"
	with(scenario, {
		raid = { size = 10, player = 1 }, people = raidNames(),
		known = join(MAGE_SINGLE, BRILLIANCE), bags = { [ARCANE_POWDER] = 20 },
		held = wearing({ "raid4", "raid5", "raid8", "raid9", "raid10" }, { 10157 }),
	}, function(ns)
		local groups, byName = queue(ns)
		local singles = 0
		for _, entry in pairs(byName) do
			if not entry.groupCast and key(entry) == "intellect" then singles = singles + 1 end
		end
		if #groups ~= 1 then
			fail(scenario, ("two missing it in each of two raid groups were offered %d group casts and %d single ones, "
				.. "where one Arcane Brilliance covers all four on Forever"):format(#groups, singles))
			return
		end
		local group = groups[1]
		if covered(group) ~= "Raider2 Stone, Raider3 Stone, Raider6 Stone, Raider7 Stone" then
			fail(scenario, "the group cast does not cover everybody in the raid missing it: " .. covered(group))
		end
		if group.groupCast.missing ~= 4 or singles ~= 0 then
			fail(scenario, ("the raid's group cast counts %s missing, with %d single casts beside it")
				:format(tostring(group.groupCast.missing), singles))
		end
		local title = ns.Prompt:RenderPrimary(group, 0)
		if title ~= "Your raid" or group.groupCast.label ~= "your raid" then
			fail(scenario, ("the panel calls a cast that covers the raid %q (%s)"):format(tostring(title),
				tostring(group.groupCast.label)))
		end
	end)
end

-- ------------------------------------------------------------------ 2
-- And so a raider flagged for PvP anywhere in the raid keeps it back: it
-- lands on them, wherever their raid group, and would flag you. Raider4 is
-- in your raid group and wears the buff, so is never queued at all; the
-- other group has four missing it. The press asks again.
do
	local scenario = "data-audit: on Forever a raider flagged in any raid group holds the group cast back"
	local opts = {
		raid = { size = 10, player = 1 }, people = raidNames(),
		known = join(MAGE_SINGLE, BRILLIANCE), bags = { [ARCANE_POWDER] = 20 },
		held = wearing({ "raid4", "raid5", "raid10" }, { 10157 }),
	}
	with(scenario, opts, function(ns)
		local groups = queue(ns)
		local group = groups[1]
		if not group then
			fail(scenario, "SKIPPED -- no group cast for the raid with nobody flagged")
			return
		end
		Mock.pvp = { raid4 = true }
		if not ns.GroupCastFlagged(group) then
			fail(scenario, "a press would cast the group spell over Raider4, flagged for PvP in another raid group, "
				.. "and flag you: on Forever it lands on them too")
		end
		groups = queue(ns)
		if #groups > 0 then
			fail(scenario, "a raider flagged for PvP in another raid group did not hold back the group cast, "
				.. "which lands on them on Forever and would flag you")
		end
		local lines = table.concat(ns.PvPLines(true), "\n")
		if not lines:find("no Arcane Brilliance for your raid", 1, true) then
			fail(scenario, "/manners debug does not say why the raid gets no group cast: " .. flat(lines))
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- The settings say what is counted: the party or raid on Forever, one party
-- (a raid group) on Classic Era, which keeps its own reach.
for _, case in ipairs({
	{ label = "Forever", raid = true, words = "your party or raid" },
	{ label = "Classic Era", flavour = "vanilla", raid = false, words = "one party" },
}) do
	local scenario = "data-audit: the group buff settings say what one cast counts (" .. case.label .. ")"
	with(scenario, { flavour = case.flavour, known = join(MAGE_SINGLE, BRILLIANCE),
		bags = { [ARCANE_POWDER] = 20 } }, function(ns)
		if (ns.GROUP_IS_RAID == true) ~= case.raid then
			fail(scenario, case.raid and "Forever's Arcane Brilliance is taken to reach only one raid group"
				or "Classic Era's Arcane Brilliance is taken to reach the whole raid")
		end
		local toggle, slider = ns.GroupBuffDescriptions()
		if not (toggle:find(case.words, 1, true) and slider:find(case.words, 1, true)) then
			fail(scenario, ("the group buff settings do not say they count %s: %s / %s"):format(case.words,
				toggle, slider))
		end
	end)
end

-- ------------------------------------------------------------------ 4
-- Prayer of Fortitude's first rank (learned at 48) takes a Holy Candle, its
-- second (60) a Sacred Candle. A priest from 48 to 59 carrying the Holy
-- Candles the spell needs was never offered it.
for _, case in ipairs({
	{ label = "first rank, Holy Candles", known = { 21562 }, bags = { [HOLY_CANDLE] = 5 }, want = true },
	{ label = "first rank, Sacred Candles only", known = { 21562 }, bags = { [SACRED_CANDLE] = 5 }, want = false },
	{ label = "second rank, Sacred Candles", known = { 21562, 21564 }, bags = { [SACRED_CANDLE] = 5 }, want = true },
}) do
	local scenario = "data-audit: Prayer of Fortitude's first rank takes a Holy Candle (" .. case.label .. ")"
	with(scenario, {
		class = "PRIEST", groupSize = 5,
		people = { party1 = { "Gwen", "Hale" }, party2 = { "Bram", "Oake" }, party3 = { "Cora", "Vell" },
			party4 = { "Dain", "Moor" } },
		known = join(FORTITUDE, case.known), bags = case.bags,
		-- Forever's own name for it; the mock gives 21562 retail's.
		names = { [21562] = "Prayer of Fortitude" },
	}, function(ns)
		local groups = queue(ns)
		local group = groups[1]
		if (group ~= nil) ~= case.want then
			fail(scenario, case.want
				and "a priest who knows Prayer of Fortitude and carries the candle its rank takes was never offered it"
				or "Prayer of Fortitude was offered without the candle its rank takes")
		elseif group then
			local text = flat(ns.Prompt:GetButton():GetAttribute("macrotext1"))
			if not text:find("/cast Prayer of Fortitude", 1, true) then
				fail(scenario, "the macro does not cast Prayer of Fortitude: " .. text)
			end
			local want = case.bags[HOLY_CANDLE] and HOLY_CANDLE or SACRED_CANDLE
			if group.groupCast.reagent ~= want then
				fail(scenario, ("the low-stock and out-of-stock notes count item %s, not the %s this rank takes")
					:format(tostring(group.groupCast.reagent), ITEM_NAMES[want]))
			end
		end
	end)
end

-- ------------------------------------------------------------------ 5
-- Omen of Clarity is a passive every druid has from 20 on Forever (16864:
-- Attributes_0 0x40, no duration): no family, never offered. On Classic Era
-- it is a ten-minute buff, and still one.
for _, case in ipairs({
	{ label = "Forever", want = false },
	{ label = "Classic Era", flavour = "vanilla", want = true },
}) do
	local scenario = "data-audit: Omen of Clarity is a druid's own buff only on Classic Era (" .. case.label .. ")"
	with(scenario, { flavour = case.flavour, class = "DRUID", known = { 1126, 16864 },
		-- Wearing their Mark of the Wild, so it is the druid's own that comes up.
		playerHeld = { [1126] = true } }, function(ns)
		local family = false
		for _, known in ipairs(ns.KnownOwnFamilies()) do
			if known.key == "omen" then family = true end
		end
		local offered = false
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason == "self" and key(entry) == "omen" then offered = true end
		end
		if case.want then
			if not (family and offered) then
				fail(scenario, ("a Classic Era druid without Omen of Clarity up was not offered it (family %s, offered %s)")
					:format(tostring(family), tostring(offered)))
			end
		elseif family or offered then
			fail(scenario, "a Forever druid was offered Omen of Clarity, a passive there with nothing to cast: "
				.. "the press casts nothing, on every quiet scan")
		end
	end)
end

-- ------------------------------------------------------------------ 6
-- "Skip my own class": Kings (trained at 20) and Divine Spirit (30 to 60) are
-- no talents on Forever, so somebody of your class past the level of your
-- rank gives himself the same, and one below it still gets yours.
local function sameClass(scenario, class, known, level, on)
	local result
	with(scenario, {
		class = class, groupSize = 2, inParty = { party1 = true },
		people = { party1 = { "Anna", "Aim" } }, classes = { party1 = class }, levels = { party1 = level },
		known = known,
		setup = function(ns)
			ns.db.profile.sources.strangers = false
			ns.db.profile.filters.skipSameClass = on
		end,
	}, function(ns)
		local _, byName = queue(ns)
		result = key(byName["Anna Aim"]) or false
	end)
	return result
end
for _, case in ipairs({
	{ class = "PRIEST", key = "spirit", known = DIVINE_SPIRIT, spell = "Divine Spirit", high = 60, low = 35,
		at = "30 to 60" },
	{ class = "PALADIN", key = "kings", known = { KINGS }, spell = "Kings", high = 60, low = 15, at = "20" },
}) do
	local scenario = "data-audit: Skip my own class skips a " .. case.class:lower() .. " who trains "
		.. case.spell .. " on Forever"
	local off = sameClass(scenario, case.class, case.known, case.high, false)
	local high = sameClass(scenario, case.class, case.known, case.high, true)
	local low = sameClass(scenario, case.class, case.known, case.low, true)
	if off ~= case.key then
		fail(scenario, ("SKIPPED -- a level %d %s is offered %s with the option off"):format(case.high,
			case.class:lower(), tostring(off)))
	else
		if high ~= false then
			fail(scenario, ("a level 60 %s with Skip my own class on was offered %s for a level %d %s, who trains "
				.. "it at %s on Forever"):format(case.class:lower(), tostring(high), case.high, case.class:lower(), case.at))
		end
		if low ~= case.key then
			fail(scenario, ("a level %d %s, too low for your best %s, was offered %s"):format(case.low,
				case.class:lower(), case.spell, tostring(low)))
		end
	end
end

-- ------------------------------------------------------------------ 7
-- Blessing of Sanctuary is gone from Forever's client (no SpellName for
-- 20911-20914 or 25899). Listed, it was a red "Manners has the wrong spell
-- ids" on /manners debug and Diagnostics for every paladin.
do
	local unknown = {}
	for _, id in ipairs(SANCTUARY) do unknown[id] = true end
	local scenario = "data-audit: a Forever paladin has no Blessing of Sanctuary to call unknown"
	with(scenario, { class = "PALADIN", unknown = unknown }, function(ns)
		local bad = {}
		for _, buff in ipairs(ns.GetClassBuffs("PALADIN") or {}) do
			local info = ns.BuffInfo(buff)
			for _, id in ipairs(info and info.unresolved or {}) do bad[#bad + 1] = buff.key .. " " .. id end
		end
		if #bad > 0 then
			fail(scenario, "every Forever paladin is told in red that Manners has the wrong spell ids: "
				.. table.concat(bad, ", "))
		end
		if ns.FindBuff("PALADIN", "sanctuary") or H.findOption(ns.optionsTable, "offer_sanctuary") then
			fail(scenario, "a Forever paladin is shown Blessing of Sanctuary, which no paladin there can learn")
		end
	end)
end

-- ------------------------------------------------------------------ 8
-- Blessing of Salvation can be cast only on somebody in your party or raid
-- (target 57). Pinned, it is offered to Bert in your party and never to Anna
-- passing by, whom the game refuses it on.
do
	local scenario = "data-audit: Salvation is offered only to your party or raid"
	with(scenario, {
		class = "PALADIN", groupSize = 2, inParty = { party1 = true },
		people = { nameplate1 = { "Anna", "Aim" }, party1 = { "Bert", "Beside" } },
		known = join(WISDOM, MIGHT, SALVATION),
		setup = function(ns) ns.db.profile.buff.choice = "salvation" end,
	}, function(ns)
		local _, byName = queue(ns)
		if key(byName["Bert Beside"]) ~= "salvation" then
			fail(scenario, "SKIPPED -- Bert in your party is not offered Salvation: " .. tostring(key(byName["Bert Beside"])))
		end
		if byName["Anna Aim"] then
			fail(scenario, "a passer-by outside your group was offered Blessing of Salvation, which the game refuses on "
				.. "anybody outside your party or raid: a press that fails, and backs off from her")
		end
		local switch = H.findOption(ns.optionsTable, "offer_salvation")
		local label = switch and type(switch.name) == "function" and switch.name() or ""
		if not label:find("your group only", 1, true) then
			fail(scenario, "Who to buff does not say Salvation reaches your group only: " .. tostring(label))
		end
		-- And what the owed switch says with Wisdom and Might switched off,
		-- Salvation all there is to cast: your group, not your subgroup,
		-- which only a shout is limited to.
		ns.db.profile.buff.skip.wisdom, ns.db.profile.buff.skip.might = true, true
		local owed = H.findOption(ns.optionsTable, "owed")
		local desc = owed and type(owed.desc) == "function" and owed.desc() or ""
		if not desc:find("Yours reaches only your group,", 1, true) then
			fail(scenario, "with Salvation pinned, People who buff me does not say it reaches your group: " .. desc)
		end
	end)
end

-- The whole raid is "your group" to Salvation: a raider in another raid
-- group gets it, where a shout would not reach him.
do
	local scenario = "data-audit: Salvation reaches a raider in another raid group"
	with(scenario, {
		class = "PALADIN", raid = { size = 10, player = 1 }, people = raidNames(),
		known = join(WISDOM, MIGHT, SALVATION),
		setup = function(ns) ns.db.profile.buff.choice = "salvation" end,
	}, function(ns)
		local _, byName = queue(ns)
		if key(byName["Raider7 Stone"]) ~= "salvation" then
			fail(scenario, "Raider7, in your raid but another raid group, was offered "
				.. tostring(key(byName["Raider7 Stone"])) .. ", not the Salvation that reaches him")
		end
	end)
end

-- A passer-by, a warrior, wearing another paladin's Might and Kings: Wisdom
-- does nothing for him, so the walk goes past what he wears to Light, not to
-- Salvation, which the game would refuse.
do
	local scenario = "data-audit: a passer-by wearing another paladin's Might and Kings is offered Light"
	local theirs = {}
	for _, id in ipairs({ MIGHT[1], KINGS }) do theirs[id] = "nameplate2" end
	with(scenario, {
		class = "PALADIN",
		people = { nameplate1 = { "Anna", "Aim" } }, classes = { nameplate1 = "WARRIOR" },
		known = join(WISDOM, MIGHT, KINGS, SALVATION, LIGHT),
		held = { nameplate1 = theirs },
	}, function(ns)
		local _, byName = queue(ns)
		local got = key(byName["Anna Aim"])
		if got ~= "light" then
			fail(scenario, "a passer-by wearing another paladin's Might and Kings was offered " .. tostring(got)
				.. ", not Light: Salvation is refused outside your group, and he never gets the Light you could give")
		end
	end)
end

-- ------------------------------------------------------------------ 9
-- Class buffs Manners never offers are favours all the same: a priest's Fear
-- Ward, a warlock's Soulstone. They were dropped as stray procs.
do
	local scenario = "data-audit: a Fear Ward or a Soulstone from somebody is a favour"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } } }, function(ns)
		if not (ns.ALL_BUFF_IDS[6346] and ns.ALL_BUFF_IDS[20707] and ns.ALL_BUFF_IDS[546]
			and ns.ALL_BUFF_IDS[132]) then
			fail(scenario, "Fear Ward, Soulstone, Water Walking or Detect Invisibility is not a class buff")
		end
		if ns.BUFF_BY_ID[6346] or ns.BUFF_BY_ID[20707] then
			fail(scenario, "Fear Ward or a Soulstone is filed under a buff Manners offers")
		end
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 6346, 4101)
		H.favourFrom(ns, "nameplate2", 20707, 4102)
		if not ns.owed["Anna Aim"] then
			fail(scenario, "Anna's Fear Ward was taken for a stray proc: no 'buffed you' line, no debt, no /thank")
		end
		if not ns.owed["Bert Beside"] then
			fail(scenario, "Bert's Soulstone was taken for a stray proc: no 'buffed you' line, no debt, no /thank")
		end
	end)
end

-- ------------------------------------------------------------------ 10
-- A shaman's Water Breathing is the same aura as Unending Breath (82, ten
-- minutes): somebody wearing it is not offered a cast that does nothing.
do
	local scenario = "data-audit: somebody breathing water from a shaman is not offered Unending Breath"
	with(scenario, {
		class = "WARLOCK",
		people = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } },
		known = { UNENDING_BREATH },
		held = { nameplate1 = { [WATER_BREATHING] = "nameplate2" } },
	}, function(ns)
		local _, byName = queue(ns)
		if key(byName["Bert Beside"]) ~= "breath" then
			fail(scenario, "SKIPPED -- Bert, breathing no water, is not offered Unending Breath")
		end
		if byName["Anna Aim"] then
			fail(scenario, "Anna, already breathing water from a shaman's Water Breathing, was offered Unending Breath: "
				.. "a wasted cast that does nothing for her")
		end
		local buff = ns.BUFF_BY_ID[WATER_BREATHING]
		if not (buff and buff.key == "breath" and ns.ALL_BUFF_IDS[WATER_BREATHING]) then
			fail(scenario, "a shaman's Water Breathing on you is not a favour")
		end
	end)
end

-- ------------------------------------------------------------------ 11
-- "ub" is how players ask for Unending Breath, in a group's chat too.
do
	local scenario = "data-audit: ub asks a warlock for Unending Breath"
	with(scenario, {
		class = "WARLOCK", people = { nameplate1 = { "Anna", "Aim" } }, known = { UNENDING_BREATH },
		setup = function(ns)
			local db = ns.db.profile
			db.sources.asked, db.sources.strangers, db.sources.group = true, false, false
		end,
	}, function(ns)
		for _, case in ipairs({
			{ event = "CHAT_MSG_PARTY", text = "ub pls" },
			{ event = "CHAT_MSG_SAY", text = "ub?" },
			{ event = "CHAT_MSG_WHISPER", text = "can i get ub" },
		}) do
			ns.addon[case.event](ns.addon, case.event, case.text, "Anna Aim", "Common", "", "", "", 0, 0, "", 0, 1,
				"Player-1-nameplate1")
			local _, byName = queue(ns)
			local anna = byName["Anna Aim"]
			if not (anna and anna.reason == "asked" and key(anna) == "breath") then
				fail(scenario, ("%q in %s did not put Anna on the prompt for Unending Breath"):format(case.text,
					case.event))
			end
			Mock.advance(61)
		end
	end)
end
