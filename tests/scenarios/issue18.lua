-- GitHub issue 18, from a warlock on WoW Forever: "Until i got the lvl 40 demo
-- capstone: demonic pact, which allows me to have soul link and demonic
-- sacrifice at the same time. the addon acts like these two are mutually
-- exclusive". Forever's Demonic Pact (425464, 1.60.1.70790 and 70938): "Your
-- Demonic Sacrifice effect is no longer cancelled by summoning a different Demon
-- pet." With it known, Soul Link is a family of its own beside Demonic Sacrifice
-- (Buffs.lua, needsSpell, notWithSpell); without it, and on Classic Era and
-- Burning Crusade, the one family is as it was. And "a check if you don't have
-- firestone or spellstone on your weapon if you have the spell learned": the
-- create spell offered (Buffs.lua, makestone, off until turned on) when no stone
-- is in the bags or on the weapon and a Soul Shard is in the bags.
--
-- Every scenario name starts with "issue18:" so the mutations in
-- tests/mutations/issue18.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local SACRIFICE, SOUL_LINK, LINKED, PACT = 18788, 19028, 25228, 425464
local TOUCH = 18791
local CREATE_FIRE, CREATE_SPELL = 17953, 17728
local SHARD = 6265
local MAJOR_FIRE, MAJOR_SPELL = 13701, 13603
local ENCHANT = { [MAJOR_FIRE] = 1825, [MAJOR_SPELL] = 8061 }
local IMBUE = 3
local STAFF = 900010

local NAMES = {
	[SACRIFICE] = "Demonic Sacrifice", [SOUL_LINK] = "Soul Link", [LINKED] = "Soul Link",
	[18789] = "Burning Wish", [18790] = "Fel Stamina", [TOUCH] = "Touch of Shadow", [18792] = "Fel Energy",
	[PACT] = "Demonic Pact", [CREATE_FIRE] = "Create Firestone", [17952] = "Create Firestone",
	[17951] = "Create Firestone", [6366] = "Create Firestone", [CREATE_SPELL] = "Create Spellstone",
	[17727] = "Create Spellstone", [2362] = "Create Spellstone",
}
local ITEM_NAMES = { [MAJOR_FIRE] = "Major Firestone", [MAJOR_SPELL] = "Major Spellstone", [SHARD] = "Soul Shard" }

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1")) end
local function said(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function known(ns, name)
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if family.key == name then return family end
	end
	return nil
end

local function listed(ns, class, name)
	for _, family in ipairs(ns.GetOwnFamilies(class) or {}) do
		if family.key == name then return family end
	end
	return nil
end

local world
local TOUCHED = { "C_UnitAuras", "C_Spell", "C_Item", "IsSpellKnown", "IsPlayerSpell", "IsUsableSpell", "IsResting",
	"GetInventoryItemID", "UnitLevel", "StaticPopup_Hide" }

local function wear(ns, auras)
	world.auras = auras or {}
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

-- A warlock on opts.flavour (Forever) who knows opts.known, wearing nothing of
-- his own, with opts.bags, a staff in the main hand (opts.hands) and
-- opts.enchants on it.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARLOCK"
	world = { auras = {}, known = {}, bags = opts.bags or {}, hands = opts.hands or { [16] = STAFF },
		enchants = opts.enchants or {} }
	for _, id in ipairs(opts.known or {}) do world.known[id] = true end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local function knows(id) return world.known[id] == true end
		rawset(_G, "IsSpellKnown", knows)
		rawset(_G, "IsPlayerSpell", knows)
		rawset(_G, "IsResting", function() return false end)
		local function usable() return true, false end
		rawset(_G, "IsUsableSpell", usable)
		rawset(_G, "C_Spell", nil)
		local spells = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or spells.GetSpellName(id) end,
			IsSpellUsable = usable,
		}, { __index = spells }))
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
		rawset(_G, "C_Item", nil)
		local list = C_Item and C_Item.GetWeaponEnchantInfo
		rawset(_G, "C_Item", {
			GetItemCount = function(id) return world.bags[id] or 0 end,
			GetItemNameByID = function(id) return ITEM_NAMES[id] end,
			RequestLoadItemDataByID = function() end,
			GetItemIconByID = function(id) return 7100000 + id end,
			GetItemInfoInstant = function(id)
				if id == STAFF then return id, "Weapon", "", "INVTYPE_2HWEAPON", 7100000, 2, 10 end
				return id, "Miscellaneous", "", "", 7100000 + id, 15, 0
			end,
			GetWeaponEnchantInfo = list,
		})
		rawset(_G, "GetInventoryItemID", function(unit, slot)
			if unit == "player" then return world.hands[slot] end
			return nil
		end)
		rawset(_G, "UnitLevel", function() return 60 end)
		rawset(_G, "StaticPopup_Hide", function() end)
		Mock.weaponEnchants = setmetatable({}, { __index = function(_, slot)
			return world.enchants[slot == 0 and 16 or slot == 1 and 17 or 18]
		end })
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		ns.Guard("probe", ns.ProbeCapabilities)
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

-- ------------------------------------------------------------------ Demonic Pact

-- Without the talent, Forever's warlock is as he was: one family, Soul Link
-- first, and either aura up is the family up.
do
	local scenario = "issue18: forever: without Demonic Pact, Soul Link and Demonic Sacrifice stay one choice"
	with(scenario, { known = { SACRIFICE, SOUL_LINK } }, function(ns)
		if known(ns, "soullink") then fail(scenario, "Soul Link has a family of its own without Demonic Pact") end
		if key(mine(ns)) ~= "soullink" then
			fail(scenario, "knowing both, nothing up: offered " .. key(mine(ns)) .. ", not Soul Link")
			return
		end
		wear(ns, { [LINKED] = "pet" })
		if mine(ns) then fail(scenario, "Soul Link up, offered " .. key(mine(ns))) end
		wear(ns, { [TOUCH] = "player" })
		if mine(ns) then fail(scenario, "the sacrifice up, offered " .. key(mine(ns))) end
	end)
end

-- With it, both are reminded of, the sacrifice first, and neither up hides the other.
do
	local scenario = "issue18: forever: with Demonic Pact, Soul Link and Demonic Sacrifice are each reminded of"
	with(scenario, { known = { SACRIFICE, SOUL_LINK, PACT } }, function(ns)
		if not known(ns, "soullink") then
			fail(scenario, "with Demonic Pact Soul Link has no family of its own; /manners debug says " .. said(ns))
			return
		end
		if key(mine(ns)) ~= "demonicsacrifice" then
			fail(scenario, "nothing up: offered " .. key(mine(ns)) .. ", not Demonic Sacrifice first")
			return
		end
		ns.Prompt:ApplyTarget(mine(ns))
		if not macro(ns):find("/cast Demonic Sacrifice", 1, true) then fail(scenario, "the press is " .. macro(ns)) end
		wear(ns, { [TOUCH] = "player" })
		if key(mine(ns)) ~= "soullinkpact" then
			fail(scenario, "the sacrifice up and no Soul Link: offered " .. key(mine(ns)) .. ", not Soul Link")
		end
		wear(ns, { [LINKED] = "pet" })
		if key(mine(ns)) ~= "demonicsacrifice" then
			fail(scenario, "Soul Link up and no sacrifice: offered " .. key(mine(ns)) .. ", not Demonic Sacrifice")
		end
		wear(ns, { [LINKED] = "pet", [TOUCH] = "player" })
		if mine(ns) then fail(scenario, "both up, offered " .. key(mine(ns))) end
		-- Each has its own choice under Myself.
		local own = findOption(ns.optionsTable, "own_soullink")
		if not own or own.hidden() then fail(scenario, "Who to buff shows no Soul Link switch of its own") end
		if not H.placedOn(ns, "who.own_soullink") then fail(scenario, "who.own_soullink is not placed under Myself") end
		local sacrifice = findOption(ns.optionsTable, "own_demonicsacrifice")
		local values = sacrifice and sacrifice.values() or {}
		if values.soullink then fail(scenario, "the Demonic Sacrifice dropdown still offers Soul Link as its choice") end
		-- Off, one leaves the other reminded.
		ns.db.profile.ownBuffs.pick.soullink = "off"
		wear(ns, { [TOUCH] = "player" })
		if mine(ns) then fail(scenario, "Soul Link switched off, offered " .. key(mine(ns))) end
	end)
end

-- Learning the talent mid-session: the next SPELLS_CHANGED probes again.
do
	local scenario = "issue18: forever: Demonic Pact learned mid-session takes effect without a reload"
	with(scenario, { known = { SACRIFICE, SOUL_LINK } }, function(ns)
		wear(ns, { [TOUCH] = "player" })
		if mine(ns) then
			fail(scenario, "SKIPPED -- before the talent, the sacrifice up, offered " .. key(mine(ns)))
			return
		end
		world.known[PACT] = true
		Mock.advance(6)
		ns.addon:SPELLS_CHANGED()
		Mock.advance(6)
		if key(mine(ns)) ~= "soullinkpact" then
			fail(scenario, "Demonic Pact learned, the sacrifice up: offered " .. key(mine(ns)) .. ", not Soul Link")
		end
		world.known[PACT] = nil
		Mock.advance(6)
		ns.addon:SPELLS_CHANGED()
		Mock.advance(6)
		if mine(ns) then fail(scenario, "Demonic Pact unlearned, the sacrifice up: offered " .. key(mine(ns))) end
	end)
end

-- Classic Era and Burning Crusade have no such talent; 425464 on Classic Era is
-- Season of Discovery's rune of the name, and changes nothing.
for _, client in ipairs({ "vanilla", "tbc" }) do
	local scenario = "issue18: " .. client .. ": the warlock's family is as it was, Demonic Pact or not"
	with(scenario, { flavour = client, known = { SACRIFICE, SOUL_LINK, PACT } }, function(ns)
		if listed(ns, "WARLOCK", "soullink") or listed(ns, "WARLOCK", "makestone") then
			fail(scenario, "a family of Forever's own is on " .. client)
		end
		if key(mine(ns)) ~= "soullink" then fail(scenario, "nothing up: offered " .. key(mine(ns)) .. ", not Soul Link") end
		wear(ns, { [TOUCH] = "player" })
		if mine(ns) then fail(scenario, "the sacrifice up, offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ the stone to make

do
	local scenario = "issue18: forever: a stone is offered to be made only when the spell is known and none is to hand"
	with(scenario, { known = { CREATE_FIRE, CREATE_SPELL }, bags = { [SHARD] = 2 } }, function(ns)
		local family = known(ns, "makestone")
		if not family then
			fail(scenario, "knowing Create Firestone, the family is not known; /manners debug says " .. said(ns))
			return
		end
		if ns.db.profile.ownBuffs.pick.makestone ~= "off" then
			fail(scenario, "a new profile reminds you to make a stone: " .. tostring(ns.db.profile.ownBuffs.pick.makestone))
		end
		if mine(ns) then fail(scenario, "switched off, offered " .. key(mine(ns))) end
		if not H.placedOn(ns, "who.own_makestone") then fail(scenario, "who.own_makestone is not placed under the stone") end
		local own = findOption(ns.optionsTable, "own_makestone")
		if not own or own.hidden() then fail(scenario, "Who to buff shows no switch for it") end
		own.set(nil, "auto")
		if key(mine(ns)) ~= "createfirestone" then
			fail(scenario, "on, a shard and nothing to hand: offered " .. key(mine(ns)) .. "; /manners debug says " .. said(ns))
			return
		end
		ns.Prompt:ApplyTarget(mine(ns))
		if not macro(ns):find("/cast Create Firestone", 1, true) then fail(scenario, "the press is " .. macro(ns)) end
		-- Picked: the Spellstone.
		ns.db.profile.ownBuffs.pick.makestone = "createspellstone"
		if key(mine(ns)) ~= "createspellstone" then fail(scenario, "Create Spellstone picked, offered " .. key(mine(ns))) end
		ns.db.profile.ownBuffs.pick.makestone = "auto"
		-- No shard: nothing, and /manners debug says why.
		world.bags[SHARD] = nil
		ns.addon:BAG_UPDATE_DELAYED()
		if mine(ns) then fail(scenario, "no Soul Shard, offered " .. key(mine(ns))) end
		if not said(ns):find("Soul Shard", 1, true) then fail(scenario, "no shard and /manners debug says " .. said(ns)) end
		world.bags[SHARD] = 1
		ns.addon:BAG_UPDATE_DELAYED()
		-- Made: the stone in the bags is offered to be used, never made again.
		world.bags[MAJOR_FIRE] = 1
		ns.addon:BAG_UPDATE_DELAYED()
		if key(mine(ns)) ~= "w13701m" then fail(scenario, "a stone in the bags: offered " .. key(mine(ns)) .. ", not to use it") end
		-- On the weapon, none in the bags: nothing, and the kind remembered.
		world.bags[MAJOR_FIRE] = nil
		ns.addon:BAG_UPDATE_DELAYED()
		world.enchants[16] = { { hasEnchant = true, enchantType = IMBUE, timeLeft = 7000000, charges = 0,
			enchantID = ENCHANT[MAJOR_SPELL], enchantIconID = 0 } }
		ns.addon:WEAPON_ENCHANT_CHANGED()
		if mine(ns) then fail(scenario, "a Spellstone on the staff, offered " .. key(mine(ns))) end
		world.enchants[16] = nil
		ns.addon:WEAPON_ENCHANT_CHANGED()
		if key(mine(ns)) ~= "createspellstone" then
			fail(scenario, "the Spellstone worn off: Automatic offered " .. key(mine(ns)) .. ", not the kind used last")
		end
		-- No weapon in the main hand: nothing to put one on.
		world.hands[16] = nil
		ns.ForgetHands()
		if mine(ns) then fail(scenario, "no weapon, offered " .. key(mine(ns))) end
	end)
	local none = "issue18: forever: no create spell known, no stone to make"
	with(none, { bags = { [SHARD] = 2 } }, function(ns)
		ns.db.profile.ownBuffs.pick.makestone = "auto"
		if known(ns, "makestone") then fail(none, "knowing no create spell, the family is known") end
		if mine(ns) then fail(none, "knowing no create spell, offered " .. key(mine(ns))) end
	end)
end
