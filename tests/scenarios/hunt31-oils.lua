-- A player's report from WoW Forever, a shaman: "oils share a buff slot with
-- personal buffs like Rockbiter Weapon for the addon while you can actually use
-- both buffs at the same time". Forever's client lists every enchant on a hand
-- with its kind (Enum.ItemEnchantType: Imbue, Temporary) and keeps one of each
-- on a hand at once: Rockbiter Weapon, a poison and a mage's scroll make an
-- Imbue (SpellEffect 360), a stone, an oil and a lure a Temporary enchant
-- (SpellEffect 54). Manners counted any enchant of either kind as "the hand is
-- seen to", so a shaman wearing Rockbiter was never offered an oil, and the
-- imbueStacks rule that learned the two stack could not learn it: it only
-- learned from seeing both, which never happened because the oil was never
-- offered. Now Buffs.lua says each family's kind (`enchantKind`, audited
-- against the spell data by tools/audit_ids.py) and Core.lua's ReadImbue counts
-- an enchant of the family's own kind. The Classic clients list one temporary
-- enchant to a hand, with no kind to sort by: unchanged.
--
-- The mock's item API is the weapon's enchant list alone, so each scenario
-- stands the rest in as hunt26-weapons.lua does: what the bags hold, the weapon
-- in each hand (a made-up item id and its class and subclass), the enchants on
-- each hand and your level.
--
-- Every scenario name starts with "hunt31-oils:" so the mutations in
-- tests/mutations/hunt31-oils.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- Items, as Buffs.lua has them.
local WIZARD_OIL, BRILLIANT_OIL, DENSE_STONE = 20750, 20749, 12404
local INSTANT_VI, OCCULT_II = 8928, 234444
local LESSER_FLAME_SCROLL = 274947
-- Their enchants (the enchant on the weapon says which item made it).
local WIZARD_OIL_ENCHANT, DENSE_STONE_ENCHANT = 2627, 1643
local INSTANT_VI_ENCHANT, OCCULT_II_ENCHANT = 625, 7651
local LESSER_FLAME_ENCHANT = 8700
-- A shaman's imbues (SpellEffect 360 on Forever: Rockbiter Weapon's first rank
-- makes enchant 29, Flametongue Weapon's 5), which no item makes.
local ROCKBITER, FLAMETONGUE = 29, 5
-- What each item's use casts (ItemEffect), which settles the press.
local WIZARD_OIL_USE = 25121
-- Enum.ItemEnchantType.
local PERMANENT, TEMPORARY, IMBUE = 1, 2, 3

-- Weapons by made-up item id, with the class and subclass GetItemInfoInstant
-- would give: a sword (7), a dagger (15), a mace (4), a staff (10).
local SWORD, DAGGER, MACE, STAFF = 900007, 900015, 900004, 900010
local INFO = { [SWORD] = { 2, 7 }, [DAGGER] = { 2, 15 }, [MACE] = { 2, 4 }, [STAFF] = { 2, 10 } }

local ITEM_NAMES = {
	[WIZARD_OIL] = "Wizard Oil", [BRILLIANT_OIL] = "Brilliant Wizard Oil", [DENSE_STONE] = "Dense Sharpening Stone",
	[INSTANT_VI] = "Instant Poison VI", [LESSER_FLAME_SCROLL] = "Scroll of Imbue Lesser Flame",
}

local function icon(item) return 7100000 + item end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end
local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- Your own entry in the queue as it stands, or nil.
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

-- One enchant as the client lists it: time left in milliseconds, from seconds.
local function entry(id, kind, seconds)
	return { hasEnchant = true, enchantType = kind, timeLeft = seconds * 1000, charges = 0, enchantID = id,
		enchantIconID = 0 }
end

-- The world a scenario stands in: bags (item -> count), hands (inventory
-- slot -> the weapon in it), enchants (slot -> the client's list) and level.
local world

local TOUCHED = { "C_Item", "C_Spell", "GetInventoryItemID", "UnitLevel", "IsSpellKnown", "IsPlayerSpell",
	"IsResting", "StaticPopup_Hide" }

local function install()
	-- The client's own list where the mock has it (Forever's, or a client the
	-- scenario gives it to), kept as the weapon's enchants.
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
	rawset(_G, "StaticPopup_Hide", function() end)
	-- The enchants are the world's, read when asked.
	Mock.weaponEnchants = setmetatable({}, { __index = function(_, slot)
		return world.enchants[slot == 0 and 16 or slot == 1 and 17 or 18]
	end })
end

-- One session on opts.flavour (WoW Forever by default) as opts.class, with
-- opts.bags, opts.hands (a sword in the main hand by default), opts.enchants
-- ({ [16] = list, [17] = list }), opts.level (40) and opts.list (a client
-- that has Forever's list of enchants, which only Forever has). body(ns) runs
-- and everything is put back, whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "SHAMAN"
	if opts.list then Mock.weaponEnchantList = true end
	world = { bags = opts.bags or {}, hands = opts.hands or { [16] = SWORD }, enchants = opts.enchants or {},
		level = opts.level or 40 }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	install()
	local undo = strangers({})
	local ok, err = pcall(function()
		local held = {}
		if (opts.class or "SHAMAN") == "MAGE" then held[1459] = true end
		Mock.playerHeld = held
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.playerHeld = held
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

-- One press of the prompt on `want`, then the SENT that settles it. Returns
-- what the button ran, or nil when the prompt was not on `want`.
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

-- ------------------------------------------------------------------ 1
-- The report. A shaman with Rockbiter Weapon (an Imbue) on his main hand and
-- a wizard oil in his bags is offered the oil: used by its item id and aimed
-- at the main hand, settled by the spell its use casts. With the oil on beside
-- Rockbiter, nothing is asked for; with the oil on and Rockbiter off, a
-- shaman's own imbue is none of ours to offer. A shaman dual-wielding, each
-- hand under an imbue, is offered the oil for the main hand and then for the
-- off hand, aimed at slot 17.
do
	local scenario = "hunt31-oils: a shaman wearing Rockbiter Weapon is offered an oil, and both stay on"
	with(scenario, { bags = { [WIZARD_OIL] = 3 }, hands = { [16] = MACE },
		enchants = { [16] = { entry(ROCKBITER, IMBUE, 1800) } } }, function(ns)
		local me = mine(ns)
		if key(me) ~= "w20750m" then
			fail(scenario, "a shaman with Rockbiter on the main hand and a Wizard Oil in the bags was offered " .. key(me) .. "; /manners debug says " .. lines(ns))
			return
		end
		if not lines(ns):find("Oil (Main Hand): none up -- Wizard Oil (Main Hand) is the one to use.", 1, true) then
			fail(scenario, "/manners debug says: " .. lines(ns))
		end
		local ran = press(ns, scenario, "w20750m", WIZARD_OIL_USE, "Cast-oil-1")
		if ran ~= "/use item:" .. WIZARD_OIL .. "\n/use 16" then
			fail(scenario, "the oil's macro reads " .. flat(ran))
			return
		end
		-- The cast goes on, three seconds; nothing else is offered for the hand
		-- meanwhile, and the oil lands beside Rockbiter.
		Mock.advance(1)
		if mine(ns) then fail(scenario, "with the oil going on, you were offered " .. key(mine(ns))) end
		Mock.advance(2)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-oil-1", WIZARD_OIL_USE)
		world.enchants[16] = { entry(ROCKBITER, IMBUE, 1790), entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
		ns.addon:WEAPON_ENCHANT_CHANGED()
		Mock.advance(8)
		if mine(ns) then fail(scenario, "with Rockbiter and the oil on, you were offered " .. key(mine(ns))) end
		if not lines(ns):find("Oil (Main Hand): Wizard Oil (Main Hand) is up.", 1, true) then
			fail(scenario, "with the oil on beside Rockbiter, /manners debug says: " .. lines(ns))
		end
		if ns.db.char.ownLast.oilmain ~= "w20750m" then
			fail(scenario, "the oil on the weapon was not remembered: " .. tostring(ns.db.char.ownLast.oilmain))
		end
		-- Rockbiter run out under the oil: nothing to offer, it is no item of ours.
		world.enchants[16] = { entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1700) }
		if mine(ns) then fail(scenario, "with the oil alone on, you were offered " .. key(mine(ns))) end
		-- The oil run out, Rockbiter still on: the oil is offered again, once the
		-- retry block of the press is out (wiped here).
		wipe(ns.tried)
		world.enchants[16] = { entry(ROCKBITER, IMBUE, 1500) }
		if key(mine(ns)) ~= "w20750m" then
			fail(scenario, "with the oil run out under Rockbiter, you were offered " .. key(mine(ns)))
		end
	end)

	-- The press settled, the weapon showing nothing new (the game refused, or
	-- the cast was lost): Rockbiter on the hand is not the oil having landed,
	-- so the oil is offered again once the hand is free and the retry is out.
	local silent = "hunt31-oils: an oil that never landed under Rockbiter is offered again"
	with(silent, { bags = { [WIZARD_OIL] = 3 }, hands = { [16] = MACE },
		enchants = { [16] = { entry(ROCKBITER, IMBUE, 1800) } } }, function(ns)
		if not press(ns, silent, "w20750m", WIZARD_OIL_USE, "Cast-oil-2") then return end
		Mock.advance(3)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-oil-2", WIZARD_OIL_USE)
		Mock.advance(2)
		if mine(ns) then fail(silent, "with the press five seconds old, you were offered " .. key(mine(ns))) end
		Mock.advance(10)
		if key(mine(ns)) ~= "w20750m" then
			fail(silent, "with Rockbiter alone on the mace fifteen seconds after the press, you were offered " .. key(mine(ns)))
		end
	end)

	local dual = "hunt31-oils: a dual-wielding shaman is offered an oil for each hand under its imbue"
	with(dual, { bags = { [WIZARD_OIL] = 3 }, hands = { [16] = MACE, [17] = MACE },
		enchants = { [16] = { entry(ROCKBITER, IMBUE, 1800) }, [17] = { entry(FLAMETONGUE, IMBUE, 1800) } } },
		function(ns)
			if key(mine(ns)) ~= "w20750m" then
				fail(dual, "both hands under an imbue, the main hand was offered " .. key(mine(ns)))
				return
			end
			world.enchants[16] = { entry(ROCKBITER, IMBUE, 1800), entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
			if key(mine(ns)) ~= "w20750o" then
				fail(dual, "with the main hand done, the off hand was offered " .. key(mine(ns)))
				return
			end
			ns.Prompt:Refresh()
			if macro(ns) ~= "/use item:" .. WIZARD_OIL .. "\n/use 17" then
				fail(dual, "the off hand's macro reads " .. flat(macro(ns)))
			end
			world.enchants[17] = { entry(FLAMETONGUE, IMBUE, 1700), entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
			if mine(ns) then fail(dual, "with both hands done, you were offered " .. key(mine(ns))) end
		end)
end

-- ------------------------------------------------------------------ 2
-- A mage: a wizard oil (Temporary) is no scroll's imbue (Imbue), and an
-- imbue is no oil. A mage wearing an oil is reminded of the scroll; one
-- wearing the scroll's imbue is reminded of the oil; wearing both, of
-- neither. (Until now the oil alone counted as the imbue being on, unless
-- the two had been seen on the staff together first.)
do
	local scenario = "hunt31-oils: an oil is no scroll imbue for a mage, and a scroll imbue is no oil"
	with(scenario, { class = "MAGE", level = 45, hands = { [16] = STAFF },
		bags = { [LESSER_FLAME_SCROLL] = 2, [WIZARD_OIL] = 2 } }, function(ns)
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, "a bare staff was offered " .. key(mine(ns)))
			return
		end
		-- An oil on the staff.
		world.enchants[16] = { entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, ("with a wizard oil on the staff, you were offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
		if not lines(ns):find("Oil (Main Hand): Wizard Oil (Main Hand) is up.", 1, true)
			or not lines(ns):find("Weapon imbue: none up -- Imbue Lesser Flame is the one to use.", 1, true) then
			fail(scenario, "with a wizard oil on the staff, /manners debug says " .. lines(ns))
		end
		-- The scroll's imbue on the staff.
		world.enchants[16] = { entry(LESSER_FLAME_ENCHANT, IMBUE, 1800) }
		if key(mine(ns)) ~= "w20750m" then
			fail(scenario, ("with the imbue on the staff, you were offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
		if not lines(ns):find("Weapon imbue: Imbue Lesser Flame is up.", 1, true) then
			fail(scenario, "with the imbue on the staff, /manners debug says " .. lines(ns))
		end
		-- Both, in either order.
		world.enchants[16] = { entry(LESSER_FLAME_ENCHANT, IMBUE, 1800), entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(scenario, "with the imbue and an oil on the staff, you were offered " .. key(mine(ns))) end
		world.enchants[16] = { entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800), entry(LESSER_FLAME_ENCHANT, IMBUE, 1800) }
		if mine(ns) then fail(scenario, "with an oil and the imbue on the staff, you were offered " .. key(mine(ns))) end
		-- The imbue run out under the oil, after the two have been seen together
		-- and the imbue alone: the oil is still no imbue.
		world.enchants[16] = { entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1700) }
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, ("with the imbue run out under the oil, you were offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- What shares a kind still excludes: a stone and an oil are both Temporary
-- enchants, which a hand has one of, so either on keeps the other from being
-- asked for; an Imbue beside them changes nothing about that.
do
	local scenario = "hunt31-oils: a stone and an oil, both temporary, still exclude each other"
	with(scenario, { class = "WARRIOR", bags = { [DENSE_STONE] = 2, [WIZARD_OIL] = 2 } }, function(ns)
		if key(mine(ns)) ~= "w12404m" then
			fail(scenario, "a bare sword with a stone and an oil in the bags was offered " .. key(mine(ns)))
			return
		end
		-- An imbue alone leaves both to be asked for, the stone first (said before
		-- any enchant of theirs is listed, which would teach their kind).
		world.enchants[16] = { entry(ROCKBITER, IMBUE, 1800) }
		if key(mine(ns)) ~= "w12404m" then
			fail(scenario, "with Rockbiter alone on the sword, you were offered " .. key(mine(ns)))
		end
		world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(scenario, "with a stone on the sword, you were offered " .. key(mine(ns))) end
		world.enchants[16] = { entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(scenario, "with an oil on the sword, you were offered " .. key(mine(ns))) end
		-- An imbue beside the stone: still nothing for the oil.
		world.enchants[16] = { entry(ROCKBITER, IMBUE, 1800), entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(scenario, "with Rockbiter and a stone on the sword, you were offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ 4
-- The client's word beats the data: when it lists an enchant one of a
-- family's own items makes as the other kind, that is the family's kind from
-- then on, for the session (a datum misjudged must not keep a reminder wrong).
-- Here the oil's own enchant is listed as an Imbue: it is up, and Rockbiter
-- (an Imbue) now seen to the hand where it had not; a Temporary enchant that
-- is none of the oil's no longer is. The stone's family is untouched.
do
	local scenario = "hunt31-oils: a family's own enchant listed as the other kind teaches the family that kind"
	with(scenario, { class = "WARRIOR", bags = { [WIZARD_OIL] = 2 } }, function(ns)
		world.enchants[16] = { entry(ROCKBITER, IMBUE, 1800) }
		if key(mine(ns)) ~= "w20750m" then
			fail(scenario, "before the client said anything, Rockbiter on the sword left the oil: " .. key(mine(ns)))
			return
		end
		world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(scenario, "before the client said anything, a stone on the sword was offered " .. key(mine(ns))) end

		-- The oil's own enchant, listed as an Imbue.
		world.enchants[16] = { entry(WIZARD_OIL_ENCHANT, IMBUE, 1800) }
		if mine(ns) then fail(scenario, "with the oil's own enchant listed as an Imbue, you were offered " .. key(mine(ns))) end
		if not lines(ns):find("Oil (Main Hand): Wizard Oil (Main Hand) is up.", 1, true) then
			fail(scenario, "with the oil's own enchant listed as an Imbue, /manners debug says " .. lines(ns))
		end
		if ns.db.char.ownLast.oilmain ~= "w20750m" then
			fail(scenario, "the oil listed as an Imbue was not remembered: " .. tostring(ns.db.char.ownLast.oilmain))
		end

		-- Taught: an Imbue of anyone's is what the oil is up for now...
		world.enchants[16] = { entry(ROCKBITER, IMBUE, 1800) }
		if mine(ns) then
			fail(scenario, "after the client listed an oil as an Imbue, Rockbiter on the sword was offered " .. key(mine(ns)))
		end
		-- ...and a Temporary enchant of anyone's is not.
		world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		if key(mine(ns)) ~= "w20750m" then
			fail(scenario, "after the client listed an oil as an Imbue, a stone on the sword left the oil: " .. key(mine(ns)))
		end

		-- Only the family it was said of: a stone's is still Temporary.
		local stone = ns.FindOwnFamily("stonemain")
		world.enchants[16] = { entry(ROCKBITER, IMBUE, 1800) }
		if not stone or ns.ReadOwnFamily(stone) ~= false then
			fail(scenario, "the oil's lesson reached the stone's family: Rockbiter read as " .. tostring(stone and ns.ReadOwnFamily(stone)))
		end
		world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		if not stone or ns.ReadOwnFamily(stone) ~= true then
			fail(scenario, "a stone on the sword is not up for the stone's family")
		end

		-- Said the other way round later, the family follows: listed as a
		-- Temporary enchant again, a Temporary one is up and an Imbue is not.
		world.enchants[16] = { entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(scenario, "with the oil listed as Temporary again, you were offered " .. key(mine(ns))) end
		world.enchants[16] = { entry(ROCKBITER, IMBUE, 1800) }
		if key(mine(ns)) ~= "w20750m" then
			fail(scenario, "with the oil listed as Temporary again, Rockbiter on the sword left the oil: " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 5
-- Forever's poisons are Imbues (SpellEffect 360), five of Season of
-- Discovery's Temporary enchants (54), and a spell says its own kind where
-- its family's differs. A rogue wearing Occult Poison II has seen to the
-- hand; the client listing it as what the data says teaches nothing, so a
-- stone alone on the hand is still no poison. And a poison (Imbue) and a stone
-- (Temporary) stay on a hand together, so a rogue with Instant Poison on is
-- offered the stone.
do
	local scenario = "hunt31-oils: a rogue's poison is an imbue, Season of Discovery's a temporary enchant"
	with(scenario, { class = "ROGUE", level = 60, hands = { [16] = DAGGER },
		bags = { [INSTANT_VI] = 2, [DENSE_STONE] = 1 } }, function(ns)
		-- A stone alone is no poison.
		world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		if key(mine(ns)) ~= "w8928m" then
			fail(scenario, "with a stone on the dagger, the poison was not offered: " .. key(mine(ns)) .. "; /manners debug says " .. lines(ns))
			return
		end
		-- Occult Poison II, as the data says: a Temporary enchant, and up.
		world.enchants[16] = { entry(OCCULT_II_ENCHANT, TEMPORARY, 1800) }
		local poison = family(ns, "poisonmain")
		if not poison or ns.ReadOwnFamily(poison) ~= true then
			fail(scenario, "Occult Poison II on the dagger, listed as Temporary, is not up for the poison family")
		end
		-- Nothing was learned from it: a stone alone is no poison still.
		world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		if key(mine(ns)) ~= "w8928m" then
			fail(scenario, "after Occult Poison II was listed as Temporary, a stone on the dagger was taken for a poison: " .. key(mine(ns)))
		end
		-- Instant Poison VI, an Imbue as the data says: up, and the stone is offered beside it.
		world.enchants[16] = { entry(INSTANT_VI_ENCHANT, IMBUE, 1800) }
		if key(mine(ns)) ~= "w12404m" then
			fail(scenario, ("with Instant Poison on the dagger, the stone was not offered: %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
		-- Both on: nothing.
		world.enchants[16] = { entry(INSTANT_VI_ENCHANT, IMBUE, 1800), entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(scenario, "with a poison and a stone on the dagger, you were offered " .. key(mine(ns))) end
	end)

	-- Each family's kind as the data states it.
	local data = "hunt31-oils: Forever's families name their kind, and every other client's name none"
	with(data, { class = "ROGUE", level = 60, bags = { [INSTANT_VI] = 1, [DENSE_STONE] = 1, [WIZARD_OIL] = 1 } },
		function(ns)
			local want = { poisonmain = "imbue", poisonoff = "imbue", stonemain = "temporary", stoneoff = "temporary",
				oilmain = "temporary", oiloff = "temporary", lure = "temporary" }
			for name, kind in pairs(want) do
				local f = ns.FindOwnFamily(name)
				if not f then
					fail(data, "SKIPPED -- no " .. name .. " family")
				elseif f.enchantKind ~= kind and kind == "imbue" then
					fail(data, "an imbue family (a poison) is not of the Imbue kind: " .. name .. " is " .. tostring(f.enchantKind))
				elseif f.enchantKind ~= kind then
					fail(data, "a temporary family (a stone, an oil, a lure) is not of the Temporary kind: " .. name .. " is " .. tostring(f.enchantKind))
				end
			end
			-- Five poisons are Temporary enchants, which their spells say.
			local temporary = {}
			for _, spell in ipairs(ns.FindOwnFamily("poisonmain").spells) do
				if spell.enchantKind == "temporary" then temporary[spell.item] = true end
			end
			for _, item in ipairs({ 217345, 217346, 217347, 226374, 234444 }) do
				if not temporary[item] then fail(data, "a Season of Discovery poison is not a Temporary enchant: " .. item) end
				temporary[item] = nil
			end
			if next(temporary) then fail(data, "a poison other than Season of Discovery's is a Temporary enchant: " .. next(temporary)) end
		end)
	local mage = "hunt31-oils: the mage's imbue family is of the Imbue kind, her familiar of none"
	with(mage, { class = "MAGE", level = 45, hands = { [16] = STAFF }, bags = { [LESSER_FLAME_SCROLL] = 1 } }, function(ns)
		local imbue = ns.FindOwnFamily("imbue")
		if not imbue or imbue.enchantKind ~= "imbue" then
			fail(mage, "the weapon imbue family is of kind " .. tostring(imbue and imbue.enchantKind))
		end
		local familiar = ns.FindOwnFamily("familiar")
		if not familiar or familiar.enchantKind ~= nil then
			fail(mage, "the familiar family is of kind " .. tostring(familiar and familiar.enchantKind))
		end
	end)
	for _, flavour in ipairs({ "vanilla", "tbc", "mists" }) do
		local scenario = ("hunt31-oils: %s's families name no kind of enchant"):format(flavour)
		with(scenario, { flavour = flavour, class = "SHAMAN", bags = { [WIZARD_OIL] = 1, [DENSE_STONE] = 1 } }, function(ns)
			local seen = 0
			for _, f in ipairs(ns.GetOwnFamilies("SHAMAN") or {}) do
				if f.enhance then
					seen = seen + 1
					if f.enchantKind ~= nil then fail(scenario, f.key .. " is of kind " .. tostring(f.enchantKind)) end
					for _, spell in ipairs(f.spells) do
						if spell.enchantKind ~= nil then
							fail(scenario, spell.key .. " is of kind " .. tostring(spell.enchantKind))
							break
						end
					end
				end
			end
			if seen == 0 then fail(scenario, "SKIPPED -- " .. flavour .. " has no enhancement families") end
		end)
	end
end

-- ------------------------------------------------------------------ 6
-- Classic Era, Burning Crusade and Mists read the global GetWeaponEnchantInfo:
-- one temporary enchant to a hand, whoever made it, and nothing to sort. A
-- shaman there wearing Rockbiter (a temporary enchant on those clients) is
-- not offered an oil, as before.
do
	for _, flavour in ipairs({ "vanilla", "tbc", "mists" }) do
		local scenario = ("hunt31-oils: %s keeps one enchant to a hand"):format(flavour)
		with(scenario, { flavour = flavour, class = "SHAMAN", hands = { [16] = MACE }, bags = { [WIZARD_OIL] = 2 },
			enchants = { [16] = { entry(ROCKBITER, TEMPORARY, 1800) } } }, function(ns)
			if mine(ns) then
				fail(scenario, ("a shaman wearing Rockbiter on %s was offered %s; /manners debug says %s")
					:format(flavour, key(mine(ns)), lines(ns)))
			end
			if not lines(ns):find("Oil (Main Hand): the weapon already carries a temporary enchant.", 1, true) then
				fail(scenario, "/manners debug says " .. lines(ns))
			end
			world.enchants[16] = {}
			if key(mine(ns)) ~= "w20750m" then
				fail(scenario, "with nothing on the mace, you were offered " .. key(mine(ns)))
			end
			-- The oil going on, then on: nothing to ask for.
			world.enchants[16] = { entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
			if mine(ns) then fail(scenario, "with the oil on the mace, you were offered " .. key(mine(ns))) end
		end)
	end

	-- A client that were to hand over Forever's list while its data names no
	-- kind (a data's omission, or a build with the list that this one has none
	-- for): any temporary or imbue enchant is the hand seen to, as it was.
	local list = "hunt31-oils: a family with no kind takes any temporary or imbue enchant from the list"
	with(list, { flavour = "vanilla", class = "SHAMAN", list = true, hands = { [16] = MACE }, bags = { [WIZARD_OIL] = 2 },
		enchants = { [16] = { entry(ROCKBITER, IMBUE, 1800) } } }, function(ns)
		if type(C_Item.GetWeaponEnchantInfo) ~= "function" then
			fail(list, "SKIPPED -- the client has no list of enchants")
			return
		end
		if mine(ns) then
			fail(list, "a family with no kind was offered an oil over an Imbue on the list: " .. key(mine(ns)))
		end
		world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(list, "a family with no kind was offered an oil over a Temporary enchant: " .. key(mine(ns))) end
		world.enchants[16] = { entry(1900, PERMANENT, 0) }
		if key(mine(ns)) ~= "w20750m" then
			fail(list, "with only a permanent enchant on the mace, you were offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 7
-- An enchant of the other kind whose id the client hides might be one of the
-- family's own, listed as the other kind: the client is not saying, which is
-- never a reason to offer, and nothing is remembered. An enchant of the
-- family's own kind with its id hidden is up all the same.
do
	local scenario = "hunt31-oils: an enchant of the other kind with a hidden id is the client not saying"
	local function hidden(kind)
		local e = entry(ROCKBITER, kind, 1800)
		e.enchantID = Mock.SECRET
		return e
	end
	with(scenario, { class = "WARRIOR", bags = { [WIZARD_OIL] = 2 } }, function(ns)
		world.enchants[16] = { hidden(IMBUE) }
		if mine(ns) then fail(scenario, "an Imbue with its id hidden was a reason to offer the oil: " .. key(mine(ns))) end
		if not lines(ns):find("Oil (Main Hand): the game will not say whether it is up, so it is not offered.", 1, true) then
			fail(scenario, "/manners debug says: " .. lines(ns))
		end
		if ns.db.char.ownLast and ns.db.char.ownLast.oilmain ~= nil then
			fail(scenario, "an Imbue with its id hidden was remembered as " .. tostring(ns.db.char.ownLast.oilmain))
		end
		-- Of the oil's own kind, hidden or not, it is up.
		world.enchants[16] = { hidden(TEMPORARY) }
		if mine(ns) then fail(scenario, "a Temporary enchant with its id hidden was a reason to offer the oil: " .. key(mine(ns))) end
		-- A readable one beside the hidden one decides.
		world.enchants[16] = { hidden(IMBUE), entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) }
		if mine(ns) then fail(scenario, "the oil's own enchant beside a hidden one was not enough: " .. key(mine(ns))) end
		world.enchants[16] = {}
		if key(mine(ns)) ~= "w20750m" then fail(scenario, "with nothing on the sword, you were offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ 8
-- /manners selftest compares what the client lists on the main hand with what
-- Manners reads for the mage's imbue. A wizard oil is listed and the imbue is
-- not on: right, since an oil is no imbue, so the report may not call it the
-- bug it was written to find (an imbue listed and read as nothing on).
do
	local scenario = "hunt31-oils: the report does not fault a mage's reading of an oil on the staff"
	local function mainHand(results)
		local worst, text = "PASS", {}
		local rank = { PASS = 1, WARN = 2, FAIL = 3 }
		for _, r in ipairs(results) do
			if r.id == "beliefs.mainHand" then
				text[#text + 1] = r.status .. " " .. tostring(r.value)
				if rank[r.status] > rank[worst] then worst = r.status end
			end
		end
		return worst, table.concat(text, " / ")
	end
	with(scenario, { class = "MAGE", level = 45, hands = { [16] = STAFF }, bags = { [LESSER_FLAME_SCROLL] = 1 },
		enchants = { [16] = { entry(WIZARD_OIL_ENCHANT, TEMPORARY, 1800) } } }, function(ns)
		if not ns.Selftest then
			fail(scenario, "SKIPPED -- Selftest.lua did not load")
			return
		end
		local ok, results = pcall(ns.Selftest.Run)
		if not ok then
			fail(scenario, "Run threw: " .. tostring(results))
			return
		end
		local worst, text = mainHand(results)
		if worst ~= "PASS" or not text:find("temporary enchant, which is no imbue", 1, true) then
			fail(scenario, "with an oil on the staff, the main hand's comparison reads " .. text)
		end
		-- The imbue listed and read as on is a pass; read as nothing on, the bug.
		world.enchants[16] = { entry(LESSER_FLAME_ENCHANT, IMBUE, 1800) }
		ok, results = pcall(ns.Selftest.Run)
		worst, text = mainHand(ok and results or {})
		if worst ~= "PASS" then fail(scenario, "with the imbue on the staff, the main hand's comparison reads " .. text) end
		local read = ns.ReadOwnFamily
		ns.ReadOwnFamily = function() return false end
		ok, results = pcall(ns.Selftest.Run)
		ns.ReadOwnFamily = read
		worst, text = mainHand(ok and results or {})
		if worst ~= "FAIL" then
			fail(scenario, "with the imbue listed and read as nothing on, the comparison reads " .. text)
		end
	end)
end
