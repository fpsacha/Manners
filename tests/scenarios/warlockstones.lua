-- A warlock's Firestone or Spellstone on WoW Forever, asked for on CurseForge by a
-- player there: "any chance of getting spellstone/firestone added like how wizard
-- oils apply". On Forever 1.60.1.70790 they are on-use items whose use puts an
-- Imbue on the main-hand weapon (SpellEffect 360, as a poison or a mage's scroll),
-- two hours. One family for both, a warlock's alone, the main hand alone
-- (Buffs.lua, warlockstone), offered while one is in the bags, used with /use
-- item:<id> and /use 16 as an oil is. Being an Imbue, it sits beside an oil or a
-- stone (a Temporary enchant) on the same hand, and neither stands in for the
-- other. On Classic Era and Burning Crusade the stones are held in the off hand
-- and put nothing on a weapon: no family there.
--
-- The mock's item API is the weapon's enchant list alone, so each scenario stands
-- the rest in as hunt31-oils.lua does.
--
-- Every scenario name starts with "warlockstones:" so the mutations in
-- tests/mutations/warlockstones.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- Items, best first, as Buffs.lua has them, with their enchants and use spells.
local MAJOR_FIRE, MAJOR_SPELL, GREATER_FIRE, GREATER_SPELL = 13701, 13603, 13700, 13602
local FIRESTONE, SPELLSTONE, LESSER_FIRE = 13699, 5522, 1254
local ORDER = { MAJOR_FIRE, MAJOR_SPELL, GREATER_FIRE, GREATER_SPELL, FIRESTONE, SPELLSTONE, LESSER_FIRE }
local ENCHANT = { [MAJOR_FIRE] = 1825, [MAJOR_SPELL] = 8061, [GREATER_FIRE] = 1824, [GREATER_SPELL] = 8060,
	[FIRESTONE] = 1823, [SPELLSTONE] = 8059, [LESSER_FIRE] = 1803 }
local USE = { [MAJOR_FIRE] = 17949, [MAJOR_SPELL] = 1237159, [GREATER_FIRE] = 17947, [GREATER_SPELL] = 1237156,
	[FIRESTONE] = 17945, [SPELLSTONE] = 1237152, [LESSER_FIRE] = 758 }
local WIZARD_OIL, WIZARD_OIL_ENCHANT = 20750, 2627
-- Enum.ItemEnchantType.
local TEMPORARY, IMBUE = 2, 3

-- Weapons by made-up item id: a staff (10), a dagger (15), a sword (7).
local STAFF, DAGGER, SWORD = 900010, 900015, 900007
local INFO = { [STAFF] = { 2, 10 }, [DAGGER] = { 2, 15 }, [SWORD] = { 2, 7 } }

local ITEM_NAMES = {
	[MAJOR_FIRE] = "Major Firestone", [MAJOR_SPELL] = "Major Spellstone", [GREATER_FIRE] = "Greater Firestone",
	[GREATER_SPELL] = "Greater Spellstone", [FIRESTONE] = "Firestone", [SPELLSTONE] = "Spellstone",
	[LESSER_FIRE] = "Lesser Firestone", [WIZARD_OIL] = "Wizard Oil",
}

local function icon(item) return 7100000 + item end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end
local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function family(ns, name)
	for _, known in ipairs(ns.KnownOwnFamilies()) do
		if known.key == name then return known end
	end
	return nil
end

local function entry(id, kind, seconds)
	return { hasEnchant = true, enchantType = kind, timeLeft = seconds * 1000, charges = 0, enchantID = id,
		enchantIconID = 0 }
end

local world

local TOUCHED = { "C_Item", "GetInventoryItemID", "UnitLevel", "IsSpellKnown", "IsPlayerSpell", "StaticPopup_Hide" }

local function install()
	rawset(_G, "C_Item", nil)
	local list = C_Item and C_Item.GetWeaponEnchantInfo
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return ITEM_NAMES[id] end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return icon(id) end,
		GetItemInfoInstant = function(id)
			local info = INFO[id]
			if info then return id, "Weapon", "", "INVTYPE_WEAPON", icon(id), info[1], info[2] end
			return id, "Miscellaneous", "", "", icon(id), 15, 0
		end,
		GetWeaponEnchantInfo = list,
	})
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" then return world.hands[slot] end
		return nil
	end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	-- A warlock who knows none of his spells: only the bags are asked about.
	rawset(_G, "IsSpellKnown", function() return false end)
	rawset(_G, "IsPlayerSpell", function() return false end)
	rawset(_G, "StaticPopup_Hide", function() end)
	Mock.weaponEnchants = setmetatable({}, { __index = function(_, slot)
		return world.enchants[slot == 0 and 16 or slot == 1 and 17 or 18]
	end })
end

-- One session on opts.flavour (Forever) as opts.class (a warlock), with opts.bags,
-- opts.hands (a staff in the main hand), opts.enchants and opts.level (60).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "WARLOCK"
	world = { bags = opts.bags or {}, hands = opts.hands or { [16] = STAFF }, enchants = opts.enchants or {},
		level = opts.level or 60 }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	install()
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.weaponEnchants = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function press(ns, scenario, want, spellId, guid)
	ns.Prompt:Refresh()
	if key(ns.Prompt:Showing()) ~= want then
		fail(scenario, ("SKIPPED -- the prompt is on %s, not %s"):format(key(ns.Prompt:Showing()), want))
		return nil
	end
	local button = ns.Prompt:GetButton()
	button.scripts.PreClick(button, "LeftButton", true)
	local ran = button:GetAttribute("macrotext1")
	button.scripts.PostClick(button, "LeftButton", true)
	if spellId then ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, spellId) end
	return ran
end

-- The family of `class` with this key in this client's own lists, or nil.
local function listed(ns, class, name)
	for _, f in ipairs(ns.GetOwnFamilies(class) or {}) do
		if f.key == name then return f end
	end
	return nil
end

-- ------------------------------------------------------------------ the data
do
	local scenario = "warlockstones: one family on Forever, a warlock's alone, for the main hand, best first"
	with(scenario, {}, function(ns)
		local f = listed(ns, "WARLOCK", "warlockstone")
		if not f then
			fail(scenario, "a warlock on Forever has no Firestone or Spellstone family")
			return
		end
		if not f.enhance or f.slot ~= 16 or f.kind ~= "warlockstone" or f.enchantKind ~= "imbue" then
			fail(scenario, ("the family is enhance=%s slot=%s kind=%s enchantKind=%s, not a main-hand Imbue")
				:format(tostring(f.enhance), tostring(f.slot), tostring(f.kind), tostring(f.enchantKind)))
		end
		if f.label ~= "Firestone or Spellstone" then fail(scenario, "the family is called " .. tostring(f.label)) end
		local items = {}
		for i, spell in ipairs(f.spells) do
			items[i] = spell.item
			if spell.enchant ~= ENCHANT[spell.item] or spell.ranks[1] ~= USE[spell.item] then
				fail(scenario, ("item %s makes %s with %s; the data says %s with %s"):format(tostring(spell.item),
					tostring(spell.enchant), tostring(spell.ranks[1]), tostring(ENCHANT[spell.item]), tostring(USE[spell.item])))
			end
			if spell.level ~= 0 then fail(scenario, "item " .. spell.item .. " asks level " .. tostring(spell.level)) end
			if ns.OwnSeconds(spell) ~= 7200 then
				fail(scenario, "item " .. spell.item .. " lasts " .. tostring(ns.OwnSeconds(spell)) .. " s, not two hours")
			end
		end
		if table.concat(items, ",") ~= table.concat(ORDER, ",") then
			fail(scenario, "the stones are listed " .. table.concat(items, ",") .. ", not best first: " .. table.concat(ORDER, ","))
		end
		for _, other in ipairs(ns.GetOwnFamilies("WARLOCK") or {}) do
			if other.kind == "warlockstone" and other ~= f then fail(scenario, "a second stone family, " .. other.key) end
		end
		for _, class in ipairs({ "MAGE", "ROGUE", "PRIEST", "WARRIOR", "SHAMAN" }) do
			for _, other in ipairs(ns.GetOwnFamilies(class) or {}) do
				if other.kind == "warlockstone" then fail(scenario, "a " .. class .. " has a stone family, " .. other.key) end
			end
		end
	end)
	for _, client in ipairs({ "vanilla", "tbc", "mists", "mainline" }) do
		with(scenario, { flavour = client }, function(ns)
			for _, other in ipairs(ns.GetOwnFamilies("WARLOCK") or {}) do
				if other.kind == "warlockstone" then fail(scenario, client .. "'s warlock has " .. other.key) end
			end
		end)
	end
end

-- ------------------------------------------------------------------ the press
-- A Major Firestone in the bags and nothing on the staff: offered, used on the
-- main hand, settled by its use spell; on, nothing is asked for and the stone is
-- remembered. Without one in the bags the family is neither known nor offered.
do
	local scenario = "warlockstones: a Firestone in the bags is offered, used on the main hand, and remembered"
	with(scenario, { bags = { [MAJOR_FIRE] = 1 } }, function(ns)
		if not family(ns, "warlockstone") then
			fail(scenario, "with a Major Firestone in the bags the family is not known; /manners debug says " .. lines(ns))
			return
		end
		if key(mine(ns)) ~= "w13701m" then
			fail(scenario, "a warlock with a Major Firestone and a bare staff was offered " .. key(mine(ns)))
			return
		end
		local ran = press(ns, scenario, "w13701m", USE[MAJOR_FIRE], "Cast-stone-1")
		if ran ~= "/use item:" .. MAJOR_FIRE .. "\n/use 16" then
			fail(scenario, "the stone's macro reads " .. flat(ran))
			return
		end
		Mock.advance(3)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-stone-1", USE[MAJOR_FIRE])
		world.enchants[16] = { entry(ENCHANT[MAJOR_FIRE], IMBUE, 7200) }
		ns.addon:WEAPON_ENCHANT_CHANGED()
		Mock.advance(8)
		if mine(ns) then fail(scenario, "with the Firestone on, you were offered " .. key(mine(ns))) end
		if ns.db.char.ownLast.warlockstone ~= "w13701m" then
			fail(scenario, "the stone on the staff was not remembered: " .. tostring(ns.db.char.ownLast.warlockstone))
		end
	end)
	local none = "warlockstones: none in the bags, nothing offered"
	with(none, {}, function(ns)
		if family(ns, "warlockstone") then fail(none, "with no stone in the bags the family is known") end
		if mine(ns) then fail(none, "with nothing in the bags, you were offered " .. key(mine(ns))) end
	end)
end

-- Best first among what the bags hold: a Greater Firestone over a Spellstone.
do
	local scenario = "warlockstones: the best stone in the bags is the one offered"
	with(scenario, { bags = { [SPELLSTONE] = 1, [GREATER_FIRE] = 1 } }, function(ns)
		if key(mine(ns)) ~= "w13700m" then
			fail(scenario, "with a Spellstone and a Greater Firestone in the bags, you were offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ beside an oil
-- The stone's Imbue and an oil's Temporary enchant are on the hand together: the
-- one on is no reason to skip the other, and both on is nothing to ask.
do
	local scenario = "warlockstones: a stone and an oil sit side by side on the main hand"
	with(scenario, { bags = { [MAJOR_SPELL] = 1, [WIZARD_OIL] = 2 } }, function(ns)
		if key(mine(ns)) ~= "w13603m" then
			fail(scenario, "a bare staff with a Spellstone and an oil in the bags was offered " .. key(mine(ns)))
			return
		end
		world.enchants[16] = { entry(ENCHANT[MAJOR_SPELL], IMBUE, 7200) }
		if key(mine(ns)) ~= "w20750m" then
			fail(scenario, "with the Spellstone on the staff, you were offered " .. key(mine(ns)) .. ", not the oil; /manners debug says " .. lines(ns))
		end
		world.enchants[16] = { entry(ENCHANT[MAJOR_SPELL], IMBUE, 7200), entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(scenario, "with the Spellstone and the oil on, you were offered " .. key(mine(ns))) end
		world.enchants[16] = { entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1700) }
		if key(mine(ns)) ~= "w13603m" then
			fail(scenario, "with the oil alone on the staff, you were offered " .. key(mine(ns)) .. ", not the Spellstone; /manners debug says " .. lines(ns))
		end
	end)
end

-- ------------------------------------------------------------------ the options
-- Under Myself on Who to buff, as an oil is, while one is in the bags; and not
-- held back by Consumables only in dungeons and raids, as a rogue's poison is not.
do
	local scenario = "warlockstones: a switch under Myself, and not held to dungeons"
	with(scenario, { bags = { [FIRESTONE] = 1 } }, function(ns)
		local f = family(ns, "warlockstone")
		if not f then
			fail(scenario, "SKIPPED -- the family is not known with a Firestone in the bags")
			return
		end
		if not H.findOption(ns.optionsTable, "own_warlockstone") then
			fail(scenario, "Who to buff has no Firestone or Spellstone switch for a warlock with one in the bags")
		end
		if ns.OwnItemsHeldToDungeons(f) then
			fail(scenario, "a warlock's stone is held to dungeons and raids like an oil")
		end
		ns.db.profile.ownBuffs.itemsInDungeons = true
		if key(mine(ns)) ~= "w13699m" then
			fail(scenario, "with consumables held to dungeons, out in the world you were offered " .. key(mine(ns)))
		end
	end)
end
