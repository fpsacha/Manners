-- Buffs you put on yourself, added in 1.11.11 (Buffs.lua, the own families):
-- Shadowform on every client, Moonkin Form on the four Classic-shaped ones,
-- Season of Discovery's Molten Armor, Aspects of the Viper and the Falcon and
-- Heart of the Lion, Grimoire of Sacrifice on Mists and retail, a shaman's weapon
-- imbues on Mists and retail (retail's a hand at a time, Thunderstrike Ward on a
-- shield), and a Lightsmith paladin's rites on retail. Each is offered as "You"
-- when none of its family is up, read as up off an aura, the shapeshift bar or
-- the weapon in that hand, and never offered over a choice the player made: a
-- druid in another form, a hunter in the Viper, another hunter's Heart of the
-- Lion.
--
-- Every scenario name starts with "self-buffs:" so the mutations in
-- tests/mutations/self-buffs.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local SHADOWFORM, RETAIL_SHADOWFORM, MOONKIN, CAT = 15473, 232698, 24858, 768
local INNER_FIRE, FROST_ARMOR, MOLTEN = 588, 168, 428741
local HAWK, FALCON, VIPER = 13165, 469145, 415423
local LION, LION_PARTY = 409580, 409583
local SACRIFICE, SACRIFICED = 108503, 196099
local MISTS_WINDFURY, MISTS_FLAMETONGUE, MISTS_EARTHLIVING = 8232, 8024, 51730
local WINDFURY, FLAMETONGUE, EARTHLIVING, WARD = 33757, 318038, 382021, 462757
local SANCTIFICATION, ADJURATION = 433568, 433583

-- The names the clients give them, for the reads by name; everything else is
-- the mock's.
local NAMES = {
	[SHADOWFORM] = "Shadowform", [RETAIL_SHADOWFORM] = "Shadowform", [MOONKIN] = "Moonkin Form",
	[CAT] = "Cat Form", [INNER_FIRE] = "Inner Fire", [FROST_ARMOR] = "Frost Armor", [MOLTEN] = "Molten Armor",
	[HAWK] = "Aspect of the Hawk", [FALCON] = "Aspect of the Falcon", [VIPER] = "Aspect of the Viper",
	[LION] = "Heart of the Lion", [LION_PARTY] = "Heart of the Lion",
	[SACRIFICE] = "Grimoire of Sacrifice", [SACRIFICED] = "Grimoire of Sacrifice",
	[MISTS_WINDFURY] = "Windfury Weapon", [MISTS_FLAMETONGUE] = "Flametongue Weapon",
	[MISTS_EARTHLIVING] = "Earthliving Weapon", [WINDFURY] = "Windfury Weapon",
	[FLAMETONGUE] = "Flametongue Weapon", [EARTHLIVING] = "Earthliving Weapon", [WARD] = "Thunderstrike Ward",
	[SANCTIFICATION] = "Rite of Sanctification", [ADJURATION] = "Rite of Adjuration",
}

-- The items in each hand: a sword, another sword, a shield (item class 4,
-- subclass 6).
local SWORD, OFF_SWORD, SHIELD = 1001, 1002, 1003
local ITEM_CLASS = { [SWORD] = { 2, 7 }, [OFF_SWORD] = { 2, 7 }, [SHIELD] = { 4, 6 } }

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1")) end

-- Your own entry in the queue (of `want`, when given), or nil.
local function mine(ns, want)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and (not want or key(entry) == want) then return entry end
	end
	return nil
end

local function said(ns) return table.concat(ns.MyselfLines(GetTime()), "\n") end

local world
local TOUCHED = { "C_UnitAuras", "C_Spell", "C_Item", "IsSpellKnown", "IsPlayerSpell", "IsUsableSpell",
	"IsResting", "GetNumShapeshiftForms", "GetShapeshiftFormInfo", "GetInventoryItemID" }

-- The enchants on each hand, as every client's reader takes them: the list
-- (Forever) and the global GetWeaponEnchantInfo (the Classic clients) from
-- Mock.weaponEnchants, retail's C_PaperDollInfo from Mock.tempEnchants.
local function enchant(ns, main, off)
	world.enchanted = { [16] = main, [17] = off }
	local function list(on)
		if not on then return {} end
		return { { hasEnchant = true, enchantType = 3, timeLeft = 3000 * 1000, charges = 0, enchantID = 5401,
			enchantIconID = 0 } }
	end
	Mock.weaponEnchants = { [0] = list(main), [1] = list(off) }
	Mock.tempEnchants = { [16] = main and { id = 5401, left = 3000 } or nil, [17] = off and { id = 5400, left = 3000 } or nil }
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

-- What you wear of your own: { [id] = source }, "player" for yours.
local function wear(ns, auras)
	world.auras = auras or {}
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

-- The shapeshift form active, by its spell id (nil for none).
local function shift(ns, form)
	world.form = form
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

-- The item in the off hand (OFF_SWORD, SHIELD or nil).
local function hold(ns, item)
	world.items[17] = item
	ns.ForgetHands()
end

-- A `opts.class` on `opts.flavour` who knows opts.known (spell ids), wearing
-- nothing of their own, nothing on either hand, a sword in the main hand and
-- opts.offhand in the other.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "PRIEST"
	world = { auras = {}, known = {}, usable = {}, items = { [16] = SWORD, [17] = opts.offhand } }
	for _, id in ipairs(opts.known or {}) do world.known[id] = true end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local function known(id) return world.known[id] == true end
		rawset(_G, "IsSpellKnown", known)
		rawset(_G, "IsPlayerSpell", known)
		rawset(_G, "IsResting", function() return false end)
		local function usable(id) return world.usable[id] ~= false, false end
		rawset(_G, "IsUsableSpell", usable)
		rawset(_G, "GetNumShapeshiftForms", function() return world.form and 1 or 0 end)
		rawset(_G, "GetShapeshiftFormInfo", function(i)
			if i == 1 and world.form then return 136116, true, true, world.form end
			return nil
		end)
		rawset(_G, "GetInventoryItemID", function(unit, slot)
			if unit == "player" then return world.items[slot] end
			return nil
		end)
		rawset(_G, "C_Spell", nil)
		local spells = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or spells.GetSpellName(id) end,
			IsSpellUsable = usable,
		}, { __index = spells }))
		rawset(_G, "C_Item", nil)
		local items = C_Item
		rawset(_G, "C_Item", setmetatable({
			GetItemInfoInstant = function(id)
				local class = ITEM_CLASS[id]
				if not class then return nil end
				return id, "Weapon", "Weapon", "INVTYPE_WEAPON", 135274, class[1], class[2]
			end,
		}, { __index = items }))
		rawset(_G, "C_UnitAuras", nil)
		local auras = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, id)
				if unit ~= "player" then return auras.GetUnitAuraBySpellID(unit, id) end
				local source = world.auras[id]
				if source == nil then return nil end
				return { spellId = id, name = NAMES[id], expirationTime = 0, duration = 0, sourceUnit = source }
			end,
			GetAuraDataBySpellName = function(unit, name)
				if unit ~= "player" then return nil end
				for id, source in pairs(world.auras) do
					if NAMES[id] == name then
						return { spellId = id, name = name, expirationTime = 0, duration = 0, sourceUnit = source }
					end
				end
				return nil
			end,
		}, { __index = auras }))
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		ns.Guard("probe", ns.ProbeCapabilities)
		enchant(ns, false, false)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.weaponEnchants, Mock.tempEnchants = nil, nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ the data

local function family(ns, class, key)
	for _, each in ipairs(ns.OWN_BUFFS[class] or {}) do
		if each.key == key then return each end
	end
	return nil
end

local function spellKeys(fam)
	local out = {}
	for _, spell in ipairs(fam and fam.spells or {}) do out[#out + 1] = spell.key end
	return table.concat(out, ", ")
end

-- Which client has which, and every one of them on in a new profile.
do
	local scenario = "self-buffs: the families each client has, every one on by default"
	local WANT = {
		camelot = { PRIEST = { "shadowform" }, DRUID = { "moonkinform" } },
		vanilla = { PRIEST = { "shadowform" }, DRUID = { "moonkinform" }, HUNTER = { "heartofthelion" } },
		tbc = { PRIEST = { "shadowform" }, DRUID = { "moonkinform" } },
		mists = { PRIEST = { "shadowform" }, DRUID = { "moonkinform" }, WARLOCK = { "grimoireofsacrifice" },
			SHAMAN = { "shamanimbue" } },
		mainline = { PRIEST = { "shadowform" }, WARLOCK = { "grimoireofsacrifice" },
			SHAMAN = { "shamanimbue", "shamanimbueoff" }, PALADIN = { "rite" } },
	}
	local NOT = { camelot = { HUNTER = "heartofthelion" }, tbc = { HUNTER = "heartofthelion" },
		mainline = { DRUID = "moonkinform" } }
	for client, classes in pairs(WANT) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			for class, keys in pairs(classes) do
				for _, k in ipairs(keys) do
					local fam = family(ns, class, k)
					if not fam then
						fail(scenario, ("%s: a %s has no %s"):format(client, class:lower(), k))
					elseif ns.defaults.profile.ownBuffs.pick[k] ~= "auto" then
						fail(scenario, ("%s: %s is %s on a new profile, not on"):format(client, k,
							tostring(ns.defaults.profile.ownBuffs.pick[k])))
					end
				end
			end
			for class, k in pairs(NOT[client] or {}) do
				if family(ns, class, k) then fail(scenario, ("%s: a %s has %s, which it cannot learn there"):format(client, class:lower(), k)) end
			end
		end
		Mock.reset()
	end
end

-- Season of Discovery's runes: Molten Armor, the Falcon and the Viper on Classic
-- Era; the two aspects on Forever too, Molten Armor not.
do
	local scenario = "self-buffs: the runes in the mage's armor and the hunter's aspects"
	for _, client in ipairs({ "vanilla", "camelot" }) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local armor = spellKeys(family(ns, "MAGE", "armor"))
			local aspect = spellKeys(family(ns, "HUNTER", "aspect"))
			local wantArmor = client == "vanilla" and "moltenarmor, frostarmor, magearmor" or "frostarmor, magearmor"
			if armor ~= wantArmor then fail(scenario, client .. ": the armors are " .. armor .. ", not " .. wantArmor) end
			if not aspect:find("^aspectfalcon, aspecthawk") or not aspect:find("aspectviper", 1, true) then
				fail(scenario, client .. ": the aspects are " .. aspect)
			end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ Shadowform

for _, case in ipairs({ { "vanilla", SHADOWFORM }, { "camelot", SHADOWFORM }, { "tbc", SHADOWFORM },
	{ "mists", SHADOWFORM }, { "mainline", RETAIL_SHADOWFORM } }) do
	local client, id = case[1], case[2]
	local scenario = "self-buffs: " .. client .. ": a shadow priest out of Shadowform is reminded of it"
	with(scenario, { flavour = client, known = { id } }, function(ns)
		local entry = mine(ns)
		if key(entry) ~= "shadowform" then
			fail(scenario, "out of the form, offered " .. key(entry) .. ", not Shadowform")
			return
		end
		ns.Prompt:ApplyTarget(entry)
		if not macro(ns):find("/cast Shadowform", 1, true) then fail(scenario, "the press is " .. macro(ns)) end
		wear(ns, { [id] = "player" })
		if mine(ns) then fail(scenario, "in Shadowform (its aura), offered " .. key(mine(ns))) end
		wear(ns, {})
		shift(ns, id)
		if mine(ns) then fail(scenario, "in Shadowform (the shapeshift bar), offered " .. key(mine(ns))) end
	end)
end

-- Inner Fire first while both are down, and in the form nothing the client
-- calls unusable there.
do
	local scenario = "self-buffs: Inner Fire before Shadowform, and nothing unusable in the form"
	with(scenario, { flavour = "vanilla", known = { INNER_FIRE, SHADOWFORM } }, function(ns)
		if key(mine(ns)) ~= "innerfire" then
			fail(scenario, "with both down, offered " .. key(mine(ns)) .. " first, not Inner Fire")
		end
		wear(ns, { [SHADOWFORM] = "player" })
		world.usable[INNER_FIRE] = false
		if mine(ns) then fail(scenario, "in Shadowform, offered " .. key(mine(ns)) .. " though the game says it cannot be cast") end
		world.usable[INNER_FIRE] = nil
		if key(mine(ns)) ~= "innerfire" then
			fail(scenario, "in Shadowform, Inner Fire (castable in it) was not offered: " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ Moonkin Form

for _, client in ipairs({ "vanilla", "camelot", "tbc", "mists" }) do
	local scenario = "self-buffs: " .. client .. ": Moonkin Form in caster form, never in another form"
	with(scenario, { flavour = client, class = "DRUID", known = { MOONKIN } }, function(ns)
		if key(mine(ns)) ~= "moonkinform" then
			fail(scenario, "in caster form, offered " .. key(mine(ns)) .. ", not Moonkin Form")
			return
		end
		shift(ns, CAT)
		if mine(ns) then fail(scenario, "in Cat Form, offered " .. key(mine(ns))) end
		if not said(ns):find("you are in another form", 1, true) then
			fail(scenario, "/manners debug does not say why: " .. said(ns))
		end
		shift(ns, MOONKIN)
		if mine(ns) then fail(scenario, "in Moonkin Form, offered " .. key(mine(ns))) end
		shift(ns, nil)
		if key(mine(ns)) ~= "moonkinform" then fail(scenario, "back in caster form, nothing offered") end
	end)
end

-- ------------------------------------------------------------------ the runes

do
	local scenario = "self-buffs: vanilla: Molten Armor is the armor up, and Automatic's first"
	with(scenario, { flavour = "vanilla", class = "MAGE", known = { FROST_ARMOR, MOLTEN } }, function(ns)
		if key(mine(ns)) ~= "moltenarmor" then
			fail(scenario, "with no armor, offered " .. key(mine(ns)) .. ", not Molten Armor")
		end
		wear(ns, { [MOLTEN] = "player" })
		if mine(ns) then fail(scenario, "in Molten Armor, offered " .. key(mine(ns))) end
	end)
end

for _, client in ipairs({ "vanilla", "camelot" }) do
	local scenario = "self-buffs: " .. client .. ": the Viper up is the hunter's choice, and never Automatic's"
	with(scenario, { flavour = client, class = "HUNTER", known = { HAWK, VIPER } }, function(ns)
		if key(mine(ns)) ~= "aspecthawk" then
			fail(scenario, "with no aspect, Automatic offered " .. key(mine(ns)) .. ", not the Hawk")
		end
		wear(ns, { [VIPER] = "player" })
		if mine(ns) then fail(scenario, "in the Viper, offered " .. key(mine(ns))) end
		-- The Viper alone known: Automatic has nothing it would pick.
		wear(ns, {})
		world.known = { [VIPER] = true }
		ns.Guard("probe", ns.ProbeCapabilities)
		if mine(ns) then fail(scenario, "knowing the Viper alone, Automatic offered " .. key(mine(ns))) end
	end)
end

for _, client in ipairs({ "vanilla", "camelot" }) do
	local scenario = "self-buffs: " .. client .. ": the Falcon is Automatic's first, and up is up"
	with(scenario, { flavour = client, class = "HUNTER", known = { HAWK, FALCON } }, function(ns)
		if key(mine(ns)) ~= "aspectfalcon" then
			fail(scenario, "with no aspect, Automatic offered " .. key(mine(ns)) .. ", not the Falcon")
		end
		wear(ns, { [FALCON] = "player" })
		if mine(ns) then fail(scenario, "in the Falcon, offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "self-buffs: vanilla: Heart of the Lion, and another hunter's covers you"
	with(scenario, { flavour = "vanilla", class = "HUNTER", known = { LION } }, function(ns)
		if key(mine(ns)) ~= "heartofthelion" then
			fail(scenario, "with none up, offered " .. key(mine(ns)) .. ", not Heart of the Lion")
			return
		end
		wear(ns, { [LION] = "player" })
		if mine(ns) then fail(scenario, "with yours up, offered " .. key(mine(ns))) end
		wear(ns, { [LION_PARTY] = "party1" })
		if mine(ns) then fail(scenario, "with another hunter's on you, offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ Grimoire of Sacrifice

for _, case in ipairs({ { "mists", SACRIFICE }, { "mainline", SACRIFICED } }) do
	local client, aura = case[1], case[2]
	local scenario = "self-buffs: " .. client .. ": Grimoire of Sacrifice with a demon out, never without"
	with(scenario, { flavour = client, class = "WARLOCK", known = { SACRIFICE } }, function(ns)
		if key(mine(ns)) ~= "grimoireofsacrifice" then
			fail(scenario, "with a demon out and none up, offered " .. key(mine(ns)))
			return
		end
		wear(ns, { [aura] = "player" })
		if mine(ns) then fail(scenario, "sacrificed, offered " .. key(mine(ns))) end
		wear(ns, {})
		world.usable[SACRIFICE] = false
		if mine(ns) then fail(scenario, "with no demon to sacrifice, offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ a shaman's imbues

do
	local scenario = "self-buffs: mists: a shaman's imbue on the main hand, the spec's own first"
	with(scenario, { flavour = "mists", class = "SHAMAN", known = { MISTS_FLAMETONGUE, MISTS_WINDFURY } }, function(ns)
		if key(mine(ns)) ~= "windfuryweapon" then
			fail(scenario, "Enhancement, nothing on the weapon: offered " .. key(mine(ns)) .. ", not Windfury")
		end
		enchant(ns, true, false)
		if mine(ns) then fail(scenario, "an imbue on the main hand, offered " .. key(mine(ns))) end
		enchant(ns, false, false)
		world.known = { [MISTS_FLAMETONGUE] = true, [MISTS_EARTHLIVING] = true }
		ns.Guard("probe", ns.ProbeCapabilities)
		if key(mine(ns)) ~= "earthlivingweapon" then
			fail(scenario, "Restoration, nothing on the weapon: offered " .. key(mine(ns)) .. ", not Earthliving")
		end
	end)
end

local function control(ns, k)
	local c = findOption(ns.optionsTable, "own_" .. k)
	if c and c.hidden and c.hidden() then return nil end
	return c
end

do
	local scenario = "self-buffs: mainline: Windfury on the main hand, Flametongue on the off hand"
	with(scenario, { flavour = "mainline", class = "SHAMAN", known = { WINDFURY, FLAMETONGUE },
		offhand = OFF_SWORD }, function(ns)
		if key(mine(ns)) ~= "windfuryweapon" then
			fail(scenario, "nothing on either hand: offered " .. key(mine(ns)) .. ", not Windfury")
		end
		local main = control(ns, "shamanimbue")
		local values = main and main.values and main.values() or {}
		if values.flametongueweapon then
			fail(scenario, "the main hand's choices list Flametongue, which goes on the off hand beside Windfury")
		end
		enchant(ns, true, false)
		if key(mine(ns)) ~= "flametongueoffhand" then
			fail(scenario, "Windfury on, the off hand bare: offered " .. key(mine(ns)) .. ", not Flametongue")
		end
		enchant(ns, true, true)
		if mine(ns) then fail(scenario, "both hands imbued, offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "self-buffs: mainline: an Elemental shaman's Flametongue is the main hand's"
	with(scenario, { flavour = "mainline", class = "SHAMAN", known = { FLAMETONGUE } }, function(ns)
		if key(mine(ns)) ~= "flametongueweapon" then
			fail(scenario, "no Windfury, nothing on the weapon: offered " .. key(mine(ns)) .. ", not Flametongue")
		end
		if control(ns, "shamanimbueoff") then
			fail(scenario, "the off hand's imbue is shown to a shaman with nothing for it")
		end
		enchant(ns, true, false)
		if mine(ns) then fail(scenario, "Flametongue on the main hand, offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "self-buffs: mainline: Thunderstrike Ward waits for a shield"
	with(scenario, { flavour = "mainline", class = "SHAMAN", known = { FLAMETONGUE, WARD } }, function(ns)
		enchant(ns, true, false)
		if mine(ns) then fail(scenario, "no shield in the off hand, offered " .. key(mine(ns))) end
		if not said(ns):find("goes on a shield, and there is none in your off hand", 1, true) then
			fail(scenario, "/manners debug does not say why: " .. said(ns))
		end
		hold(ns, SHIELD)
		if key(mine(ns)) ~= "thunderstrikeward" then
			fail(scenario, "a shield, nothing on it: offered " .. key(mine(ns)) .. ", not Thunderstrike Ward")
		end
		enchant(ns, true, true)
		if mine(ns) then fail(scenario, "the ward on the shield, offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ the rites

do
	local scenario = "self-buffs: mainline: a Lightsmith's rite on the main hand"
	with(scenario, { flavour = "mainline", class = "PALADIN", known = { SANCTIFICATION } }, function(ns)
		if key(mine(ns)) ~= "ritesanctification" then
			fail(scenario, "nothing on the weapon: offered " .. key(mine(ns)) .. ", not Rite of Sanctification")
			return
		end
		enchant(ns, true, false)
		if mine(ns) then fail(scenario, "the rite on the weapon, offered " .. key(mine(ns))) end
		-- Still nothing for anybody else, and a prompt for its own.
		if ns.CLASSES_WITHOUT_BUFFS.PALADIN ~= true or not ns.OwnBuffsOnly() then
			fail(scenario, "a retail paladin with a rite is not read as having its own buffs alone")
		end
	end)
end

-- ------------------------------------------------------------------ the page

do
	local scenario = "self-buffs: mainline: the page names each hand and says what it reminds"
	with(scenario, { flavour = "mainline", class = "SHAMAN", known = { WINDFURY, FLAMETONGUE, WARD },
		offhand = SHIELD }, function(ns)
		local off = control(ns, "shamanimbueoff")
		if not off then
			fail(scenario, "no off-hand imbue on Who to buff for a shaman who knows two")
			return
		end
		local label = H.optionText(off.name)
		if label ~= "Weapon imbue (Off Hand)" then fail(scenario, "the off hand's row reads " .. label) end
		local text = H.optionText(off.desc)
		if not text:find("off hand", 1, true) or text:find("main hand", 1, true) then
			fail(scenario, "the off hand's row says " .. text)
		end
		for _, path in ipairs({ "who.own_shamanimbue", "who.own_shamanimbueoff" }) do
			if not H.placedOn(ns, path) then fail(scenario, path .. " is not placed under Myself") end
		end
	end)
	with(scenario, { flavour = "mainline", class = "PALADIN", known = { SANCTIFICATION, ADJURATION } }, function(ns)
		local rite = control(ns, "rite")
		if not rite then
			fail(scenario, "no rite on Who to buff for a paladin who knows both")
			return
		end
		if H.optionText(rite.desc):find("Windfury", 1, true) then
			fail(scenario, "the paladin's row speaks of Windfury: " .. H.optionText(rite.desc))
		end
		if not H.placedOn(ns, "who.own_rite") then fail(scenario, "who.own_rite is not placed under Myself") end
	end)
	with(scenario, { flavour = "mists", class = "DRUID", known = { MOONKIN } }, function(ns)
		local moonkin = control(ns, "moonkinform")
		if not moonkin or moonkin.type ~= "toggle" then
			fail(scenario, "no Moonkin Form switch for a druid who knows it")
			return
		end
		if not H.optionText(moonkin.desc):find("another form", 1, true) then
			fail(scenario, "the switch does not say it waits out another form: " .. H.optionText(moonkin.desc))
		end
	end)
end
