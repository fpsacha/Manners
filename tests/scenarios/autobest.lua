-- Automatic takes the best item for you now, not the one used last: "it should
-- be best, based on weapon, class, skill, talent etc", a mage on WoW Forever.
-- Core.lua's Best weighs a ranked family's rows (Buffs.lua: `ranked`, a row's
-- school and power, oilKind and tier, bonus): a mage's imbue and a warlock's
-- stone by the school the talents favour (Talents.lua, Forever's trees), an oil
-- by the role it serves (the group role, the class, else the talents or spec),
-- a lure by the Fishing it adds; ties and no lean keep the table's order. A
-- poison keeps the kind last on its hand at its best rank (`byLine`), and
-- making a stone takes the kind the talents favour.
--
-- Each scenario sets its own client, so the file says the same as every one
-- of them. The world is stood in as tests/scenarios/hunt26-weapons.lua does:
-- the bags, the weapon in each hand, the enchants on it, your level, and the
-- spells known (a talent taken is its spell known, as the client reports it).
--
-- Every scenario name starts with "autobest:" so the mutations in
-- tests/mutations/autobest.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

-- Items, as Buffs.lua has them.
local ACCURACY, FLAME, FROST = 277494, 277497, 277485
local GREATER_FLAME, GREATER_FROST, PRECISION = 277500, 277501, 277502
local SPELLBREAK, LESSER_FLAME, CHILLKNIFE = 277503, 274947, 275067
local MAJOR_FIRE, MAJOR_SPELL, SHARD = 13701, 13603, 6265
local BRILLIANT_WIZARD, BRILLIANT_MANA, MINOR_MANA, BLESSED_WIZARD = 20749, 20748, 20745, 23123
local LESSER_MANA, LESSER_WIZARD, SHADOW_OIL = 20747, 20746, 3824
-- Two of Forever's flasks (Consumables.lua): one for level 55, one for 50.
local FLASK_A, FLASK_B = 274273, 13510
local BRIGHT_BAUBLES, AQUADYNAMIC = 6532, 6533
local INSTANT_VI, DEADLY_V = 8928, 20844
-- Enchants: Frost's imbue, Instant Poison VI's.
local FROST_ENCHANT, INSTANT_VI_ENCHANT = 8709, 625
-- Enum.ItemEnchantType's Imbue.
local IMBUE = 3

-- Talents, as the spells Forever reports them by (Talents.lua).
local PYROBLAST, IGNITE = 11366, 11119
local ICE_BARRIER, COLD_SNAP = 11426, 12472
local ARCANE_POWER, ARCANE_SUBTLETY = 12042, 11210
local SPIRIT_OF_REDEMPTION = 20711
local SHADOW_WEAVING, SHADOW_FOCUS = 15257, 15326
local IMPROVED_SHADOW_BOLT, SHADOW_MASTERY = 17793, 18271
local INCINERATE, CONFLAGRATE = 412758, 1293817
local CREATE_FIRE, CREATE_SPELL = 17953, 17728

-- Weapons by made-up item id, with their item class and subclass.
local STAFF, DAGGER, POLE = 900010, 900015, 900020
local INFO = { [STAFF] = { 2, 10 }, [DAGGER] = { 2, 15 }, [POLE] = { 2, 20 } }

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

-- Your own entry in the queue as it stands, or nil.
local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function entry(id, kind, seconds)
	return { hasEnchant = true, enchantType = kind, timeLeft = seconds * 1000, charges = 0, enchantID = id,
		enchantIconID = 0 }
end

-- The world: bags, hands, enchants (slot -> the client's list), level, known
-- (spell id -> true), talentReads (how many times a talent was asked for),
-- throws (a talent read that threw), and `talent`, the talent ids once loaded.
local world

local TOUCHED = { "C_Item", "C_Spell", "C_SpellBook", "C_SpecializationInfo", "GetInventoryItemID", "UnitLevel",
	"IsSpellKnown", "IsPlayerSpell", "IsUsableSpell", "IsResting", "StaticPopup_Hide", "GetProfessions",
	"GetProfessionInfo" }

local function install()
	rawset(_G, "C_Item", nil)
	local list = C_Item and C_Item.GetWeaponEnchantInfo
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7200000 + id end,
		GetItemInfoInstant = function(id)
			local info = INFO[id]
			if info then return id, "Weapon", "", "INVTYPE_WEAPON", 7200000 + id, info[1], info[2] end
			return id, "Miscellaneous", "", "", 7200000 + id, 15, 0
		end,
		GetWeaponEnchantInfo = list,
		ReplaceEnchant = function() end,
	})
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" then return world.hands[slot] end
		return nil
	end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	local function knows(id)
		if world.talent and world.talent[id] then world.talentReads = world.talentReads + 1 end
		return world.known[id] == true
	end
	rawset(_G, "IsSpellKnown", knows)
	rawset(_G, "IsPlayerSpell", knows)
	local function usable() return true, false end
	rawset(_G, "IsUsableSpell", usable)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "StaticPopup_Hide", function() end)
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = usable }, { __index = spells }))
	Mock.weaponEnchants = setmetatable({}, { __index = function(_, slot)
		return world.enchants[slot == 0 and 16 or slot == 1 and 17 or 18]
	end })
end

-- Fishing at `rank`, through the API every client has.
local function fishing(rank)
	rawset(_G, "GetProfessions", function() return nil, nil, nil, 4, nil end)
	rawset(_G, "GetProfessionInfo", function(index)
		if index == 4 then return "Fishing", 136245, rank, 300 end
	end)
end

-- One session on opts.flavour (Forever) as opts.class (a mage), at opts.level
-- (60), with opts.bags, opts.hands (a staff in the main hand), opts.enchants
-- and opts.known (the talents taken and spells learned). opts.before(world)
-- runs before the load (a client stand-in). body(ns) runs and everything is
-- put back, whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	local class = opts.class or "MAGE"
	Mock.class = class
	world = { bags = opts.bags or {}, hands = opts.hands or { [16] = STAFF }, enchants = opts.enchants or {},
		level = opts.level or 60, known = {}, talentReads = 0, throws = 0 }
	for _, id in ipairs(opts.known or {}) do world.known[id] = true end
	-- The mock's Arcane Intellect, which a mage is wearing.
	world.known[1459] = true
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	install()
	local undo = strangers({})
	local ok, err = pcall(function()
		if opts.before then opts.before(world) end
		local held = {}
		if class == "MAGE" then held[1459] = true end
		Mock.playerHeld = held
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		H.extrasOn(ns)
		Mock.playerHeld = held
		-- The talent ids, so their reads can be counted from here on.
		world.talent = {}
		for _, trees in pairs(ns.TALENT_TREES or {}) do
			for _, tree in ipairs(trees) do
				for _, id in ipairs(tree.spells) do world.talent[id] = true end
			end
		end
		for _, marks in pairs(ns.TALENT_MARKS or {}) do
			for _, ids in pairs(marks) do
				for _, id in ipairs(ids) do world.talent[id] = true end
			end
		end
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

local function remember(ns, family, spellKey)
	ns.db.char.ownLast = ns.db.char.ownLast or {}
	ns.db.char.ownLast[family] = spellKey
end

-- ------------------------------------------------------------------ the mage's imbue

do
	local scenario = "autobest: a fire mage is offered a fire imbue"
	with(scenario, { level = 30, known = { PYROBLAST, IGNITE }, bags = { [ACCURACY] = 1, [FLAME] = 1, [FROST] = 1 } },
		function(ns)
			if key(mine(ns)) ~= "imbueflame" then
				fail(scenario, "a fire mage with Accuracy, Flame and Frost was offered " .. key(mine(ns)))
			end
			local control = findOption(ns.optionsTable, "own_imbue")
			local auto = control and control.values().auto
			if not tostring(auto):find("the best you can use now", 1, true) then
				fail(scenario, "Automatic reads " .. tostring(auto))
			end
		end)
end

do
	local scenario = "autobest: a frost mage is offered a frost imbue"
	with(scenario, { level = 30, known = { ICE_BARRIER, COLD_SNAP }, bags = { [ACCURACY] = 1, [FLAME] = 1, [FROST] = 1 } },
		function(ns)
			if key(mine(ns)) ~= "imbuefrost" then
				fail(scenario, "a frost mage with Accuracy, Flame and Frost was offered " .. key(mine(ns)))
			end
		end)
end

do
	local scenario = "autobest: no talents keep the table's order"
	with(scenario, { level = 30, bags = { [ACCURACY] = 1, [FLAME] = 1, [FROST] = 1 } }, function(ns)
		if key(mine(ns)) ~= "imbueaccuracy" then
			fail(scenario, "with no talent taken, Automatic offered " .. key(mine(ns)) .. " rather than the first in order")
		end
	end)
end

do
	local scenario = "autobest: the best, not the imbue used last"
	with(scenario, { level = 30, known = { PYROBLAST, IGNITE }, bags = { [FLAME] = 1, [FROST] = 1 } }, function(ns)
		remember(ns, "imbue", "imbuefrost")
		if key(mine(ns)) ~= "imbueflame" then
			fail(scenario, "a fire mage who last used Frost was offered " .. key(mine(ns)) .. " rather than Flame")
		end
	end)
end

do
	local scenario = "autobest: an imbue picked by name is kept"
	with(scenario, { level = 30, known = { PYROBLAST, IGNITE }, bags = { [FLAME] = 1, [FROST] = 1 } }, function(ns)
		ns.db.profile.ownBuffs.pick.imbue = "imbuefrost"
		if key(mine(ns)) ~= "imbuefrost" then
			fail(scenario, "Frost picked by name, a fire mage was offered " .. key(mine(ns)))
		end
	end)
end

do
	local scenario = "autobest: an arcane mage takes a scroll of no school over a fire one"
	with(scenario, { level = 46, known = { ARCANE_POWER }, bags = { [GREATER_FLAME] = 1, [PRECISION] = 1 } },
		function(ns)
			if key(mine(ns)) ~= "imbueprecision" then
				fail(scenario, "an arcane mage with Greater Flame and Precision was offered " .. key(mine(ns)))
			end
		end)
	local frost = "autobest: deep arcane with frost second reads as frost"
	with(frost, { level = 46, known = { ARCANE_POWER, ARCANE_SUBTLETY, ICE_BARRIER },
		bags = { [GREATER_FROST] = 1, [PRECISION] = 1 } }, function(ns)
		if key(mine(ns)) ~= "imbuegreaterfrost" then
			fail(frost, "an arcane and frost mage with Greater Frost and Precision was offered " .. key(mine(ns)))
		end
	end)
end

do
	local scenario = "autobest: a tie keeps the table's order"
	with(scenario, { level = 46, known = { PYROBLAST, IGNITE }, bags = { [SPELLBREAK] = 1, [LESSER_FLAME] = 1 } },
		function(ns)
			if key(mine(ns)) ~= "imbuespellbreak" then
				fail(scenario, "Spellbreak and Lesser Flame, both +4 Fire: offered " .. key(mine(ns)))
			end
		end)
	local dagger = "autobest: a fire scroll that does not fit the dagger gives way"
	with(dagger, { level = 46, hands = { [16] = DAGGER }, known = { PYROBLAST, IGNITE },
		bags = { [GREATER_FLAME] = 1, [CHILLKNIFE] = 1 } }, function(ns)
		if key(mine(ns)) ~= "imbuechillknife" then
			fail(dagger, "a fire mage with a dagger was offered " .. key(mine(ns)))
		end
	end)
	local topup = "autobest: a top-up is of the imbue worn"
	with(topup, { level = 30, known = { PYROBLAST, IGNITE }, bags = { [FLAME] = 1, [FROST] = 1 },
		enchants = { [16] = { entry(FROST_ENCHANT, IMBUE, 120) } } }, function(ns)
		ns.db.profile.filters.whenBuffed = "refresh"
		-- In a group, where a weapon's top-up is due before it runs out.
		Mock.groupSize = 4
		local got = mine(ns)
		Mock.groupSize = 0
		if key(got) ~= "imbuefrost" then
			fail(topup, "Frost on the staff with two minutes left, in a group: offered " .. key(got))
		end
	end)
end

-- ------------------------------------------------------------------ the warlock

do
	local scenario = "autobest: a warlock's stone by his talents"
	local bags = { [MAJOR_FIRE] = 1, [MAJOR_SPELL] = 1 }
	with(scenario, { class = "WARLOCK", known = { IMPROVED_SHADOW_BOLT, SHADOW_MASTERY }, bags = bags }, function(ns)
		if key(mine(ns)) ~= "w13603m" then fail(scenario, "a shadow warlock was offered " .. key(mine(ns))) end
	end)
	with(scenario, { class = "WARLOCK", known = { INCINERATE, CONFLAGRATE }, bags = bags }, function(ns)
		if key(mine(ns)) ~= "w13701m" then fail(scenario, "a fire warlock was offered " .. key(mine(ns))) end
	end)
	with(scenario, { class = "WARLOCK", bags = bags }, function(ns)
		if key(mine(ns)) ~= "w13701m" then
			fail(scenario, "a warlock with no talent was offered " .. key(mine(ns)) .. " rather than the first in order")
		end
	end)
end

do
	local scenario = "autobest: a shadow warlock makes a Spellstone"
	with(scenario, { class = "WARLOCK", bags = { [SHARD] = 2 },
		known = { CREATE_FIRE, CREATE_SPELL, IMPROVED_SHADOW_BOLT, SHADOW_MASTERY } }, function(ns)
		ns.db.profile.ownBuffs.pick.makestone = "auto"
		-- Switched on: the shard is counted with the bags from here on.
		ns.addon:BAG_UPDATE_DELAYED()
		remember(ns, "makestone", "createfirestone")
		if key(mine(ns)) ~= "createspellstone" then
			fail(scenario, "a shadow warlock who last had a Firestone on was offered " .. key(mine(ns)))
		end
	end)
	local unknown = "autobest: a stone the warlock has not learned is not made"
	with(unknown, { class = "WARLOCK", bags = { [SHARD] = 2 },
		known = { CREATE_FIRE, IMPROVED_SHADOW_BOLT, SHADOW_MASTERY } }, function(ns)
		ns.db.profile.ownBuffs.pick.makestone = "auto"
		ns.addon:BAG_UPDATE_DELAYED()
		if key(mine(ns)) ~= "createfirestone" then
			fail(unknown, "a shadow warlock with Create Firestone alone was offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ the rest still remember

do
	-- A bagged family (a flask) still takes the one used last, but only while
	-- you can use it: in the bags and your level.
	local scenario = "autobest: a flask used last and out of reach gives way"
	with(scenario, { class = "WARRIOR", level = 52, bags = { [FLASK_A] = 1, [FLASK_B] = 1 } }, function(ns)
		ns.db.profile.ownBuffs.pick.flask = "auto"
		ns.addon:BAG_UPDATE_DELAYED()
		remember(ns, "flask", "flask" .. FLASK_A)
		if key(mine(ns)) ~= "flask" .. FLASK_B then
			fail(scenario, "the flask used last is for level 55, one for 50 in the bags: offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ oils

do
	local scenario = "autobest: an oil for the role"
	local bags = { [BRILLIANT_WIZARD] = 1, [BRILLIANT_MANA] = 1 }
	with(scenario, { class = "PRIEST", known = { SPIRIT_OF_REDEMPTION }, bags = bags }, function(ns)
		if key(mine(ns)) ~= "w20748m" then fail(scenario, "a Holy priest was offered " .. key(mine(ns))) end
	end)
	with(scenario, { class = "PRIEST", known = { SHADOW_WEAVING, SHADOW_FOCUS }, bags = bags }, function(ns)
		if key(mine(ns)) ~= "w20749m" then fail(scenario, "a Shadow priest was offered " .. key(mine(ns))) end
		Mock.groupSize = 4
		Mock.roles = { player = "HEALER" }
		if key(mine(ns)) ~= "w20748m" then
			fail(scenario, "a Shadow priest put down to heal was offered " .. key(mine(ns)))
		end
		-- The client withholds the role a moment (an instance hiding who you
		-- are): the one read last stands.
		Mock.roles = { player = Mock.SECRET }
		if key(mine(ns)) ~= "w20748m" then
			fail(scenario, "with the healer's role withheld, offered " .. key(mine(ns)))
		end
		Mock.groupSize, Mock.roles = 0, nil
	end)
	local tier = "autobest: a healer's stronger wizard oil over a weak mana oil"
	with(tier, { class = "PRIEST", level = 45, known = { SPIRIT_OF_REDEMPTION },
		bags = { [BRILLIANT_WIZARD] = 1, [MINOR_MANA] = 1 } }, function(ns)
		if key(mine(ns)) ~= "w20749m" then
			fail(tier, "a Holy priest at 45 with Brilliant Wizard and Minor Mana Oil was offered " .. key(mine(ns)))
		end
	end)
	local blessed = "autobest: Blessed Wizard Oil comes last"
	with(blessed, { class = "PRIEST", level = 60, known = { SPIRIT_OF_REDEMPTION },
		bags = { [BLESSED_WIZARD] = 1, [BRILLIANT_WIZARD] = 1 } }, function(ns)
		if key(mine(ns)) ~= "w20749m" then fail(blessed, "a Holy priest was offered " .. key(mine(ns))) end
	end)
	-- The class decides where the tree does not: a warrior's Shadow Oil over a
	-- wizard oil first in order, a mage's wizard oil over a mana oil first.
	local class = "autobest: an oil by the class"
	with(class, { class = "WARRIOR", level = 45, bags = { [BRILLIANT_WIZARD] = 1, [SHADOW_OIL] = 1 } }, function(ns)
		if key(mine(ns)) ~= "w3824m" then fail(class, "a warrior with Brilliant Wizard and Shadow Oil was offered " .. key(mine(ns))) end
	end)
	with(class, { level = 40, bags = { [LESSER_MANA] = 1, [LESSER_WIZARD] = 1 } }, function(ns)
		if key(mine(ns)) ~= "w20746m" then fail(class, "a mage with Lesser Mana and Lesser Wizard was offered " .. key(mine(ns))) end
	end)
	-- The group role: a druid put down to tank fights with the weapon; a
	-- paladin put down to tank has no lean (classic Protection); a Holy priest
	-- put down for damage casts.
	local function grouped(role, body)
		return function(ns)
			Mock.groupSize = 4
			Mock.roles = { player = role }
			local ok, err = pcall(body, ns)
			Mock.groupSize, Mock.roles = 0, nil
			if not ok then error(err, 0) end
		end
	end
	local tank = "autobest: an oil by the group role"
	with(tank, { class = "DRUID", level = 45, bags = { [BRILLIANT_WIZARD] = 1, [SHADOW_OIL] = 1 } }, grouped("TANK", function(ns)
		if key(mine(ns)) ~= "w3824m" then fail(tank, "a druid put down to tank was offered " .. key(mine(ns))) end
	end))
	with(tank, { class = "PALADIN", level = 45, bags = { [BRILLIANT_WIZARD] = 1, [SHADOW_OIL] = 1 } }, grouped("TANK", function(ns)
		if key(mine(ns)) ~= "w20749m" then
			fail(tank, "a paladin put down to tank was offered " .. key(mine(ns)) .. " rather than the first in order")
		end
	end))
	with(tank, { class = "PRIEST", level = 40, known = { SPIRIT_OF_REDEMPTION }, bags = { [LESSER_MANA] = 1, [LESSER_WIZARD] = 1 } },
		grouped("DAMAGER", function(ns)
			if key(mine(ns)) ~= "w20746m" then fail(tank, "a Holy priest put down for damage was offered " .. key(mine(ns))) end
		end))
end

do
	local scenario = "autobest: the strongest lure Fishing allows"
	with(scenario, { class = "WARRIOR", level = 30, hands = { [16] = POLE },
		bags = { [BRIGHT_BAUBLES] = 1, [AQUADYNAMIC] = 1 }, before = function() fishing(150) end }, function(ns)
		if key(mine(ns)) ~= "w6533m" then fail(scenario, "Fishing 150 with two lures: offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "autobest: vanilla: a priest's tree by the points in it"
	with(scenario, { flavour = "vanilla", class = "PRIEST", bags = { [BRILLIANT_WIZARD] = 1, [BRILLIANT_MANA] = 1 },
		before = function()
			rawset(_G, "C_SpecializationInfo", {
				GetSpecializationInfo = function(index)
					return 200 + index, "Tree", "", 0, nil, nil, index == 2 and 20 or 0
				end,
			})
		end }, function(ns)
		if key(mine(ns)) ~= "w20748m" then
			fail(scenario, "20 points in Holy: offered " .. key(mine(ns)) .. " rather than a mana oil")
		end
	end)
	-- Classic Era has a GetSpecialization too (Blizzard's GetPrimaryTalentTree),
	-- and a role for each tree: the points spent decide, not the role of the
	-- index it gives.
	local function classic(points, index, roles)
		return function()
			rawset(_G, "C_SpecializationInfo", {
				GetSpecialization = function() return index end,
				GetSpecializationInfo = function(i)
					return 200 + i, "Tree", "", 0, roles[i], nil, points[i] or 0
				end,
			})
		end
	end
	local shadow = "autobest: vanilla: a Shadow priest by his points, not the spec's role"
	with(shadow, { flavour = "vanilla", class = "PRIEST", bags = { [BRILLIANT_WIZARD] = 1, [BRILLIANT_MANA] = 1 },
		before = classic({ 0, 0, 31 }, 1, { "HEALER", "HEALER", "DAMAGER" }) }, function(ns)
		if key(mine(ns)) ~= "w20749m" then
			fail(shadow, "31 points in Shadow, the client's spec index on Discipline: offered " .. key(mine(ns)))
		end
	end)
	with(shadow, { flavour = "vanilla", class = "PALADIN", bags = { [BRILLIANT_WIZARD] = 1, [SHADOW_OIL] = 1 },
		before = classic({ 0, 31, 0 }, 2, { "HEALER", "TANK", "DAMAGER" }) }, function(ns)
		if key(mine(ns)) ~= "w20749m" then
			fail(shadow, "a Protection paladin, no lean, was offered " .. key(mine(ns)) .. " rather than the first in order")
		end
	end)
end

do
	local scenario = "autobest: mists: a healing spec takes a mana oil"
	local function spec(id, role)
		return function()
			rawset(_G, "C_SpecializationInfo", {
				GetSpecialization = function() return 1 end,
				GetSpecializationInfo = function() return id, "Spec", "", 0, role end,
			})
		end
	end
	with(scenario, { flavour = "mists", class = "PRIEST", bags = { [BRILLIANT_WIZARD] = 1, [BRILLIANT_MANA] = 1 },
		before = spec(257, "HEALER") }, function(ns)
		if key(mine(ns)) ~= "w20748m" then fail(scenario, "a Holy priest on Mists was offered " .. key(mine(ns))) end
	end)
	with(scenario, { flavour = "mists", class = "MONK", bags = { [BRILLIANT_WIZARD] = 1, [BRILLIANT_MANA] = 1 },
		before = spec(270, "HEALER") }, function(ns)
		if key(mine(ns)) ~= "w20748m" then fail(scenario, "a Mistweaver was offered " .. key(mine(ns))) end
	end)
	local damage = "autobest: mists: a Shadow spec takes a wizard oil"
	with(damage, { flavour = "mists", class = "PRIEST", level = 40, bags = { [LESSER_MANA] = 1, [LESSER_WIZARD] = 1 },
		before = spec(258, "DAMAGER") }, function(ns)
		if key(mine(ns)) ~= "w20746m" then fail(damage, "a Shadow priest on Mists was offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ reading the talents

do
	local scenario = "autobest: a talent changed is read again"
	with(scenario, { level = 30, known = { PYROBLAST, IGNITE }, bags = { [FLAME] = 1, [FROST] = 1 } }, function(ns)
		if not Mock.registeredEvents.TRAIT_CONFIG_UPDATED then
			fail(scenario, "TRAIT_CONFIG_UPDATED is not registered")
		end
		if key(mine(ns)) ~= "imbueflame" then fail(scenario, "a fire mage was offered " .. key(mine(ns))) end
		world.known[PYROBLAST], world.known[IGNITE] = nil, nil
		world.known[ICE_BARRIER], world.known[COLD_SNAP] = true, true
		ns.addon:TRAIT_CONFIG_UPDATED()
		if key(mine(ns)) ~= "imbuefrost" then
			fail(scenario, "the talents changed to frost, and Automatic still offered " .. key(mine(ns)))
		end
	end)
end

-- Every way a talent change reaches Best: the three other talent events and
-- the probe (SPELLS_CHANGED), each registered and each read again.
do
	local scenario = "autobest: every talent event reads again"
	local ways = { "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "probe" }
	for _, way in ipairs(ways) do
		with(scenario, { level = 30, known = { PYROBLAST, IGNITE }, bags = { [FLAME] = 1, [FROST] = 1 } }, function(ns)
			if way ~= "probe" and not Mock.registeredEvents[way] then fail(scenario, way .. " is not registered") end
			if key(mine(ns)) ~= "imbueflame" then fail(scenario, "a fire mage was offered " .. key(mine(ns))) end
			world.known[PYROBLAST], world.known[IGNITE] = nil, nil
			world.known[ICE_BARRIER], world.known[COLD_SNAP] = true, true
			if way == "probe" then ns.ProbeCapabilities() else ns.addon[way](ns.addon) end
			if key(mine(ns)) ~= "imbuefrost" then
				fail(scenario, ("the talents changed to frost and %s came, and Automatic still offered %s"):format(way,
					key(mine(ns))))
			end
		end)
	end
end

do
	local scenario = "autobest: the talents are read once"
	with(scenario, { level = 30, known = { PYROBLAST, IGNITE }, bags = { [FLAME] = 1, [FROST] = 1 } }, function(ns)
		world.talentReads = 0
		mine(ns)
		if world.talentReads == 0 then fail(scenario, "two scrolls to weigh and no talent read") end
		world.talentReads = 0
		mine(ns)
		if world.talentReads ~= 0 then
			fail(scenario, ("the second scan read %d talents again"):format(world.talentReads))
		end
	end)
	with(scenario, { level = 30, known = { PYROBLAST, IGNITE }, bags = { [FLAME] = 1 } }, function(ns)
		world.talentReads = 0
		if key(mine(ns)) ~= "imbueflame" then fail(scenario, "one scroll in the bags: offered " .. key(mine(ns))) end
		if world.talentReads ~= 0 then
			fail(scenario, ("one scroll in the bags, and %d talents read"):format(world.talentReads))
		end
	end)
end

do
	local scenario = "autobest: a talent read that throws leaves the table's order"
	with(scenario, { level = 30, known = { ICE_BARRIER, COLD_SNAP }, bags = { [FLAME] = 1, [FROST] = 1 },
		before = function(w)
			rawset(_G, "C_SpellBook", {
				IsSpellKnown = function(id)
					if w.talent and w.talent[id] then
						w.throws = w.throws + 1
						error("no such talent read")
					end
					return w.known[id] == true
				end,
			})
		end }, function(ns)
		if key(mine(ns)) ~= "imbueflame" then fail(scenario, "with the read throwing, offered " .. key(mine(ns))) end
		mine(ns)
		if world.throws ~= 1 then fail(scenario, ("%d throws across two scans"):format(world.throws)) end
		local report = ns.FullReport()
		if not report:find("own lean school=nil", 1, true) then
			fail(scenario, "the report says " .. tostring(report:match("own lean[^\n]*")))
		end
	end)
end

-- ------------------------------------------------------------------ poisons

do
	local scenario = "autobest: a poison keeps its kind at its best rank"
	with(scenario, { class = "ROGUE", hands = { [16] = DAGGER, [17] = DAGGER }, bags = { [DEADLY_V] = 1, [INSTANT_VI] = 1 },
		enchants = { [16] = { entry(INSTANT_VI_ENCHANT, IMBUE, 1800) } } }, function(ns)
		remember(ns, "poisonoff", "w8985o")
		if key(mine(ns)) ~= "w20844o" then
			fail(scenario, "Deadly Poison IV last on the off hand, V in the bags: offered " .. key(mine(ns)))
		end
		world.enchants[16] = nil
		ns.addon:WEAPON_ENCHANT_CHANGED()
		if key(mine(ns)) ~= "w8928m" then
			fail(scenario, "the main hand, with nothing on it before, was offered " .. key(mine(ns)))
		end
	end)
end
