-- A mage's scrolls on WoW Forever as two of your own buffs: a familiar, and
-- a weapon imbue. A player asked on CurseForge for "one for making sure a
-- familiar is summoned and one for making sure a weapon imbue is on".
-- Buffs.lua holds the scrolls (the camelot set's own), Core.lua reads the
-- bags, your level, the weapon in your main hand and the enchants on it
-- (ScrollReady, ReadImbue), Prompt/Macro.lua uses the scroll by its item id,
-- and Options/Who.lua and the window show the two families under Myself.
--
-- The mock's item API is the weapon's enchant list alone, so each scenario
-- stands the rest in: what the bags hold, the weapon in the main hand, the
-- enchant on it and your level. Your own auras are Mock.playerHeld: Arcane
-- Intellect, and a familiar where a scenario says so. Nothing else is
-- learned, so the scrolls are all there is of your own to offer.
--
-- Every scenario name starts with "mage-scrolls:" so the mutations in
-- tests/mutations/mage-scrolls.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- Items, auras and enchants, as Buffs.lua has them.
local RAT, FROG, CAT = 275069, 277483, 277493
local LESSER_FLAME, CHILLKNIFE, FROST, SPELLBREAK = 274947, 275067, 277485, 277503
local RAT_AURA, FROG_AURA = 1296202, 1302285
local LESSER_FLAME_ENCHANT = 8700
local INTELLECT = 1459
-- A wizard oil's enchant: no scroll makes it.
local OIL = 2628
-- An enchanter's Crusader on the weapon, which never wears off.
local CRUSADER = 1900
-- Enum.ItemEnchantType: a scroll's imbue is of the Imbue kind, an oil
-- Temporary, an enchanter's Permanent.
local PERMANENT, TEMPORARY, IMBUE = 1, 2, 3

-- Two weapons by item id, and the item subclass each is.
local STAFF, DAGGER = 900010, 900015
local SUBCLASS = { [STAFF] = 10, [DAGGER] = 15 }

local ITEM_NAMES = {
	[RAT] = "Scroll of Rat Familiar", [FROG] = "Scroll of Frog Familiar", [CAT] = "Scroll of Cat Familiar",
	[LESSER_FLAME] = "Scroll of Imbue Lesser Flame", [CHILLKNIFE] = "Scroll of Imbue Chillknife",
	[FROST] = "Scroll of Imbue Frost", [SPELLBREAK] = "Scroll of Imbue Spellbreak",
}

-- Every item its own icon, so the prompt's can be told from a spell's.
local function icon(item) return 7000000 + item end

local function said() return table.concat(Mock.printed, "\n") end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end
local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

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

-- What you had on last for the imbue, nil for nothing.
local function lastImbue(ns)
	local last = ns.db.char.ownLast
	return type(last) == "table" and last.imbue or nil
end

-- What /manners debug says about yourself, one line per family.
local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- The world a scenario stands in: bags (item -> count), weapon (the item in
-- the main hand), enchant ({ id, left, kind } on it: seconds, and the kind
-- an Imbue unless it says otherwise), level, `reads`, how many times the
-- bags were asked for a count, and `unloaded`, items the client has not
-- loaded yet (no name until RequestLoadItemDataByID and a load, `requested`
-- saying which were asked for). `enchants`, where a scenario sets it, is the
-- main hand's list as the client hands it over, in place of `enchant`.
--
-- The enchant is read with the calls `api` names, "+" between them: "list"
-- is C_Item.GetWeaponEnchantInfo (tests/mockapi.lua's), every kind of
-- enchant; "temporary" is 12.1's C_PaperDollInfo.GetTemporaryEnchantmentInfo
-- and "shim" the old GetWeaponEnchantInfo, Blizzard_Deprecated's shim over
-- it, both of which report a Temporary enchant alone, never an Imbue. The
-- default is the client's own two, "list+temporary", the deprecation
-- fallbacks switched off. Each counts its calls: listReads, temporaryReads,
-- shimReads. A namespace without the call stands for "not there": the mock
-- would build its own for a nil.
local world

local TOUCHED = { "C_Item", "GetInventoryItemID", "GetWeaponEnchantInfo", "C_PaperDollInfo", "UnitLevel",
	"IsResting", "IsSpellKnown", "IsPlayerSpell", "Enum" }

-- One enchant as C_Item.GetWeaponEnchantInfo lists it: its time left in
-- milliseconds, from seconds here.
local function entry(id, kind, seconds)
	return { hasEnchant = true, enchantType = kind, timeLeft = seconds * 1000, charges = 0, enchantID = id,
		enchantIconID = 0 }
end

-- The main hand's enchants, as the list hands them over.
local function mainHand()
	if world.enchants then return world.enchants end
	local e = world.enchant
	if not e then return {} end
	return { entry(e.id, e.kind or IMBUE, e.left) }
end

-- The Temporary one of them, the only kind the two old calls report.
local function temporary()
	for _, e in ipairs(mainHand()) do
		if e.hasEnchant == true and e.enchantType == TEMPORARY then return e end
	end
	return nil
end

local function install(api)
	local function has(call) return ("+" .. api .. "+"):find("+" .. call .. "+", 1, true) ~= nil end
	rawset(_G, "C_Item", nil)
	local list = C_Item.GetWeaponEnchantInfo
	rawset(_G, "C_Item", {
		GetItemCount = function(id)
			world.reads = world.reads + 1
			return world.bags[id] or 0
		end,
		GetItemNameByID = function(id)
			if world.unloaded and world.unloaded[id] then return nil end
			return ITEM_NAMES[id]
		end,
		RequestLoadItemDataByID = function(id) world.requested[id] = true end,
		GetItemIconByID = function(id) return icon(id) end,
		GetItemInfoInstant = function(id)
			if SUBCLASS[id] then return id, "Weapon", "", "INVTYPE_WEAPON", icon(id), 2, SUBCLASS[id] end
			return id, "Miscellaneous", "", "", icon(id), 15, 0
		end,
		GetWeaponEnchantInfo = has("list") and function(slot)
			world.listReads = world.listReads + 1
			Mock.weaponEnchants = { [0] = mainHand() }
			return list(slot)
		end or nil,
	})
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" and slot == 16 then return world.weapon end
		return nil
	end)
	-- Nothing at all for no enchant, as the client documents it.
	local function native(slot)
		world.temporaryReads = world.temporaryReads + 1
		local e = temporary()
		if slot ~= 16 or not e then return end
		return { enchantID = e.enchantID, remainingTimeMs = e.timeLeft, chargesRemaining = 0, hasExpirationTime = true }
	end
	-- Blizzard_Deprecated's shim: all three weapon slots, four values each.
	local function shim()
		world.shimReads = world.shimReads + 1
		local e = temporary()
		if not e then return false, nil, nil, nil, false, nil, nil, nil, false, nil, nil, nil end
		return true, e.timeLeft, 0, e.enchantID, false, nil, nil, nil, false, nil, nil, nil
	end
	rawset(_G, "C_PaperDollInfo", { GetTemporaryEnchantmentInfo = has("temporary") and native or nil })
	rawset(_G, "GetWeaponEnchantInfo", has("shim") and shim or nil)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
end

-- One session as opts.class (a mage by default), with opts.bags, opts.weapon
-- (a staff by default), opts.enchant or opts.enchants, opts.level (12),
-- opts.held (your own auras besides Arcane Intellect), opts.api (see
-- install) and opts.unloaded, nobody else about; opts.known are the spells
-- learned (the mock's Arcane Intellect alone otherwise). opts.tree records
-- the frames (the prompt's icon). body(ns) runs and everything is put back,
-- whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	if opts.class then Mock.class = opts.class end
	world = { bags = opts.bags or {}, weapon = opts.weapon or STAFF, enchant = opts.enchant,
		enchants = opts.enchants, level = opts.level or 12, reads = 0, listReads = 0, temporaryReads = 0,
		shimReads = 0, unloaded = opts.unloaded, requested = {} }
	local held = { [INTELLECT] = true }
	for _, id in ipairs(opts.held or {}) do held[id] = true end
	world.held = held
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	install(opts.api or "list+temporary")
	if opts.known then
		local learned = {}
		for _, id in ipairs(opts.known) do learned[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return learned[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return learned[id] == true end)
	end
	if opts.tree then FT.install() end
	local undo = strangers({})
	local ok, err = pcall(function()
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
	if opts.tree then FT.uninstall() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The bags changed, as the client says so.
local function restock(ns, bags)
	world.bags = bags
	ns.addon:BAG_UPDATE_DELAYED()
end

-- ------------------------------------------------------------------ 1
-- A level-12 mage with a staff, carrying Rat Familiar and Imbue Lesser Flame:
-- the familiar first, used from the bags by its item id with the scroll's
-- icon, settled by the spell the use casts; once it is with you, the imbue.
do
	local scenario = "mage-scrolls: Rat Familiar and Lesser Flame are offered and used from the bags"
	with(scenario, { bags = { [RAT] = 2, [LESSER_FLAME] = 1 }, tree = true }, function(ns)
		local me = mine(ns)
		if key(me) ~= "ratfamiliar" then
			fail(scenario, "a level-12 mage with a Rat Familiar scroll and no familiar was offered " .. key(me))
			return
		end
		if ns.Prompt:ReasonText(me) ~= "your own Rat Familiar" then
			fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(me)))
		end
		ns.Prompt:Refresh()
		if key(ns.Prompt:Showing()) ~= "ratfamiliar" then
			fail(scenario, "SKIPPED -- the prompt is not on the familiar: " .. key(ns.Prompt:Showing()))
			return
		end
		if macro(ns) ~= "/use item:" .. RAT then
			fail(scenario, "the familiar's macro reads " .. flat(macro(ns)))
		end
		local texture = ns.Prompt:Regions().icon:GetTexture()
		if texture ~= icon(RAT) then
			fail(scenario, "the prompt shows icon " .. tostring(texture) .. ", not the scroll's")
		end
		local summary = ns.Prompt:ClickSummary(ns.Prompt:Showing())
		if summary[1] ~= "Uses |cffffffffRat Familiar|r from your bags." then
			fail(scenario, "the tooltip says " .. flat(table.concat(summary, "\n")))
		end

		-- The press, and the spell the use casts settling it.
		local pressed = H.pressButton(ns)
		if pressed ~= "/use item:" .. RAT or not (ns.pendingClick and ns.pendingClick.onSelf) then
			fail(scenario, "SKIPPED -- the press did not go out: " .. flat(pressed))
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-scroll-1", RAT_AURA)
		if ns.pendingClick then fail(scenario, "the scroll's use was never settled") end
		if not ns.IsBlocked(ns.UnitFullName("player"), "ratfamiliar") then
			fail(scenario, "the familiar was not given its retry cooldown after the press")
		end

		-- The familiar with you: the imbue is next.
		world.held[RAT_AURA] = true
		Mock.advance(30)
		wipe(ns.tried)
		me = mine(ns)
		if key(me) ~= "imbuelesserflame" then
			fail(scenario, "with the familiar up, a staff and no imbue, you were offered " .. key(me))
			return
		end
		ns.Prompt:Refresh()
		if key(ns.Prompt:Showing()) ~= "imbuelesserflame" then
			fail(scenario, "SKIPPED -- the prompt did not move on to the imbue: " .. key(ns.Prompt:Showing()))
			return
		end
		-- Aimed at the main-hand weapon in the same press (1.6.4): the use
		-- alone left the cursor waiting for a weapon.
		if macro(ns) ~= "/use item:" .. LESSER_FLAME .. "\n/use 16" then
			fail(scenario, "the imbue's macro reads " .. flat(macro(ns)))
		end
		if ns.Prompt:Regions().icon:GetTexture() ~= icon(LESSER_FLAME) then
			fail(scenario, "the imbue shows icon " .. tostring(ns.Prompt:Regions().icon:GetTexture()))
		end
	end)
end

-- ------------------------------------------------------------------ 2
-- A familiar up -- whichever scroll it came from -- and anything on the main
-- hand, a wizard oil included, offer nothing. With top-ups on, an imbue
-- running low is offered again.
do
	local scenario = "mage-scrolls: a familiar up and an imbue on offer nothing"
	with(scenario, { bags = { [RAT] = 1, [LESSER_FLAME] = 1 }, held = { RAT_AURA },
		enchant = { id = LESSER_FLAME_ENCHANT, left = 1800 } }, function(ns)
		if mine(ns) then
			fail(scenario, "with a familiar up and the imbue on, you were offered " .. key(mine(ns)))
		end
		local text = lines(ns)
		if not text:find("Familiar: Rat Familiar is up.", 1, true)
			or not text:find("Weapon imbue: Imbue Lesser Flame is up.", 1, true) then
			fail(scenario, "/manners debug says: " .. text)
		end
		if ns.db.char.ownLast.imbue ~= "imbuelesserflame" then
			fail(scenario, "the imbue on the weapon was not remembered: " .. tostring(ns.db.char.ownLast.imbue))
		end

		-- A Frog familiar with you and only Rat scrolls in the bags, at a
		-- level a Frog scroll can be used at.
		world.level = 20
		world.held[RAT_AURA], world.held[FROG_AURA] = nil, true
		if mine(ns) then
			fail(scenario, "with a Frog familiar up, the Rat scroll was offered: " .. key(mine(ns)))
		end

		-- A wizard oil on the staff.
		world.enchant = { id = OIL, left = 1800, kind = TEMPORARY }
		if mine(ns) then
			fail(scenario, "with a wizard oil on the weapon, you were offered " .. key(mine(ns)))
		end
		if not lines(ns):find("Weapon imbue: your main hand already carries a temporary enchant.", 1, true) then
			fail(scenario, "/manners debug says, of an oil: " .. lines(ns))
		end

		-- The imbue running low, with top-ups on: two minutes, read from the
		-- client's milliseconds.
		ns.db.profile.filters.whenBuffed = "refresh"
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 120 }
		local me = mine(ns)
		if key(me) ~= "imbuelesserflame" or me.remaining == nil or me.remaining > 121 then
			fail(scenario, ("two minutes of Lesser Flame with top-ups on offered %s, %s left")
				:format(key(me), tostring(me and me.remaining)))
		end
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 1800 }
		if mine(ns) then
			fail(scenario, "half an hour of Lesser Flame with top-ups on offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- An imbue is for one kind of weapon: Lesser Flame a staff, Chillknife a
-- dagger. The weapon is read again when the equipment changes. With no
-- weapon in the main hand, nothing is offered and /manners debug says so,
-- not that a scroll does not fit a weapon that is not there -- before the
-- level, which no weapon would make any difference to.
do
	local scenario = "mage-scrolls: a dagger in hand offers Chillknife, not Lesser Flame"
	with(scenario, { bags = { [LESSER_FLAME] = 1, [CHILLKNIFE] = 1 }, weapon = DAGGER, held = { RAT_AURA } },
		function(ns)
			if key(mine(ns)) ~= "imbuechillknife" then
				fail(scenario, "with a dagger in hand you were offered " .. key(mine(ns)))
			end
			restock(ns, { [LESSER_FLAME] = 1 })
			if mine(ns) then
				fail(scenario, "with a dagger in hand, Lesser Flame (a staff's) was offered: " .. key(mine(ns)))
			end
			if not lines(ns):find("Weapon imbue: Imbue Lesser Flame does not fit the weapon in your main hand.", 1, true) then
				fail(scenario, "/manners debug says: " .. lines(ns))
			end
			world.weapon = STAFF
			ns.addon:PLAYER_EQUIPMENT_CHANGED(nil, 16, true)
			if key(mine(ns)) ~= "imbuelesserflame" then
				fail(scenario, "with a staff put in hand, you were offered " .. key(mine(ns)))
			end

			-- The staff taken off.
			world.weapon = nil
			ns.addon:PLAYER_EQUIPMENT_CHANGED(nil, 16, false)
			if mine(ns) then
				fail(scenario, "with no weapon in hand, you were offered " .. key(mine(ns)))
			end
			local text = lines(ns)
			if not text:find("Weapon imbue: there is no weapon in your main hand.", 1, true)
				or text:find("does not fit", 1, true) then
				fail(scenario, "with no weapon in hand, /manners debug says: " .. text)
			end
			-- A Spellbreak too, above a level-12 mage's: still the weapon.
			restock(ns, { [SPELLBREAK] = 1, [LESSER_FLAME] = 1 })
			text = lines(ns)
			if not text:find("Weapon imbue: there is no weapon in your main hand.", 1, true) then
				fail(scenario, "with no weapon in hand and a Spellbreak in the bags, /manners debug says: " .. text)
			end
			world.weapon = STAFF
			ns.addon:PLAYER_EQUIPMENT_CHANGED(nil, 16, true)
			if key(mine(ns)) ~= "imbuelesserflame" then
				fail(scenario, "with the staff back in hand, you were offered " .. key(mine(ns)))
			end
		end)
end

-- ------------------------------------------------------------------ 4
-- Empty bags: nothing offered and no row. The bags are read once, and again
-- only when the client says they changed, never on every scan.
do
	local scenario = "mage-scrolls: empty bags offer nothing and are read only when they change"
	with(scenario, { bags = {} }, function(ns)
		if not (Mock.registeredEvents.BAG_UPDATE_DELAYED and Mock.registeredEvents.PLAYER_EQUIPMENT_CHANGED) then
			fail(scenario, "the bags and the weapon in hand are not watched")
		end
		if mine(ns) then fail(scenario, "with no scroll in the bags you were offered " .. key(mine(ns))) end
		if family(ns, "familiar") or family(ns, "imbue") then
			fail(scenario, "with no scroll in the bags, a scroll family counts as yours")
		end
		local control = findOption(ns.optionsTable, "own_familiar")
		if not control or control.hidden() ~= true then
			fail(scenario, "with no scroll in the bags, the Familiar row is shown")
		end

		local before = world.reads
		for _ = 1, 5 do
			Mock.advance(1)
			ns.addon:Tick()
			mine(ns)
		end
		if world.reads ~= before then
			fail(scenario, ("the bags were read %d more times over five scans"):format(world.reads - before))
		end

		-- A scroll bought: nothing until the client says the bags changed.
		world.bags = { [RAT] = 1 }
		if mine(ns) then fail(scenario, "a scroll was offered before the bags were said to have changed") end
		ns.addon:BAG_UPDATE_DELAYED()
		if key(mine(ns)) ~= "ratfamiliar" then
			fail(scenario, "after the bags changed, a Rat Familiar scroll was not offered: " .. key(mine(ns)))
		end
		if world.reads - before ~= 19 then
			fail(scenario, ("the bags were read %d times for the 19 scrolls"):format(world.reads - before))
		end
		if control and control.hidden() ~= false then
			fail(scenario, "with a scroll in the bags, the Familiar row is hidden")
		end
	end)
end

-- ------------------------------------------------------------------ 5
-- A level-4 mage holding both: nothing, and /manners debug says why. Level 5
-- is enough.
do
	local scenario = "mage-scrolls: a level 4 mage is offered nothing"
	with(scenario, { bags = { [RAT] = 1, [LESSER_FLAME] = 1 }, level = 4 }, function(ns)
		if mine(ns) then fail(scenario, "a level-4 mage was offered " .. key(mine(ns))) end
		local text = lines(ns)
		if not text:find("Familiar: Rat Familiar needs level 5.", 1, true) then
			fail(scenario, "/manners debug says: " .. text)
		end
		world.level = 5
		if key(mine(ns)) ~= "ratfamiliar" then
			fail(scenario, "at level 5 you were offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 6
-- Automatic: the best you can use until you have used one, then the one you
-- used last, while there is still one of it to use.
do
	local scenario = "mage-scrolls: Automatic takes the scroll used last"
	with(scenario, { bags = { [RAT] = 1, [FROG] = 1, [LESSER_FLAME] = 1, [FROST] = 1 }, level = 20 }, function(ns)
		local control = findOption(ns.optionsTable, "own_familiar")
		if key(mine(ns)) ~= "frogfamiliar" then
			fail(scenario, "before any familiar, Automatic offered " .. key(mine(ns)) .. " rather than the best one")
		end
		local auto = control and control.values().auto
		if auto ~= "Automatic (Frog Familiar, the best you can use now)" then
			fail(scenario, "Automatic reads " .. tostring(auto))
		end

		-- A Rat familiar summoned, and gone again.
		world.held[RAT_AURA] = true
		ns.addon:UNIT_AURA(nil, "player")
		ns.addon:Tick()
		if ns.db.char.ownLast.familiar ~= "ratfamiliar" then
			fail(scenario, "the Rat familiar was not remembered: " .. tostring(ns.db.char.ownLast.familiar))
		end
		world.held[RAT_AURA] = nil
		if key(mine(ns)) ~= "ratfamiliar" then
			fail(scenario, "with the Rat familiar gone, Automatic offered " .. key(mine(ns)) .. ", not the one used last")
		end
		auto = control and control.values().auto
		if auto ~= "Automatic (Rat Familiar, the one you had up last)" then
			fail(scenario, "Automatic reads " .. tostring(auto))
		end

		-- The last Rat scroll used up: the best of the rest.
		restock(ns, { [FROG] = 1, [LESSER_FLAME] = 1, [FROST] = 1 })
		if key(mine(ns)) ~= "frogfamiliar" then
			fail(scenario, "with no Rat scroll left, Automatic offered " .. key(mine(ns)))
		end

		-- The imbue the same way: Frost first, then Lesser Flame once it was on.
		world.held[FROG_AURA] = true
		if key(mine(ns)) ~= "imbuefrost" then
			fail(scenario, "before any imbue, Automatic offered " .. key(mine(ns)) .. " rather than Frost")
		end
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 1800 }
		mine(ns)
		world.enchant = nil
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, "once Lesser Flame had been on, Automatic offered " .. key(mine(ns)))
		end

		-- A dagger in hand: the one used last does not fit it, so Automatic
		-- takes one that does.
		restock(ns, { [FROG] = 1, [LESSER_FLAME] = 1, [CHILLKNIFE] = 1 })
		world.weapon = DAGGER
		ns.addon:PLAYER_EQUIPMENT_CHANGED(nil, 16, true)
		if key(mine(ns)) ~= "imbuechillknife" then
			fail(scenario, "with a dagger in hand, Automatic offered " .. key(mine(ns)) .. " rather than a scroll that fits it")
		end
	end)
end

-- ------------------------------------------------------------------ 7
-- A scroll picked is offered whatever Automatic says; one with none in the
-- bags stays the pick and is offered once there is one; Don't remind me
-- offers nothing.
do
	local scenario = "mage-scrolls: a chosen scroll, and Don't remind me"
	with(scenario, { bags = { [RAT] = 1, [FROG] = 1 }, level = 30 }, function(ns)
		local control = findOption(ns.optionsTable, "own_familiar")
		if not (control and control.set) then
			fail(scenario, "there is no Familiar dropdown for a mage with scrolls")
			return
		end
		control.set({ "own_familiar" }, "ratfamiliar")
		if key(mine(ns)) ~= "ratfamiliar" then
			fail(scenario, "picked Rat Familiar, and was offered " .. key(mine(ns)))
		end
		control.set({ "own_familiar" }, "catfamiliar")
		if control.get() ~= "catfamiliar" then
			fail(scenario, "a pick with none in the bags reads " .. tostring(control.get()))
		end
		if mine(ns) then fail(scenario, "picked Cat Familiar with none in the bags, and was offered " .. key(mine(ns))) end
		if not lines(ns):find("Familiar: you have no Cat Familiar in your bags.", 1, true) then
			fail(scenario, "/manners debug says: " .. lines(ns))
		end
		restock(ns, { [RAT] = 1, [FROG] = 1, [CAT] = 1 })
		if key(mine(ns)) ~= "catfamiliar" then
			fail(scenario, "with a Cat scroll bought, the pick offered " .. key(mine(ns)))
		end
		control.set({ "own_familiar" }, "off")
		if mine(ns) then fail(scenario, "Don't remind me still offered " .. key(mine(ns))) end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("Familiar: switched off (Don't remind me).", 1, true) then
			fail(scenario, "/manners debug does not say the familiar is switched off: " .. flat(said()))
		end
	end)
end

-- ------------------------------------------------------------------ 8
-- The usual rules for your own buffs hold: not in a city or an inn unless
-- asked, not in a fight, not with Myself off.
do
	local scenario = "mage-scrolls: a city, a fight and Myself off hold the scrolls back"
	with(scenario, { bags = { [RAT] = 1 } }, function(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered the familiar to begin with")
			return
		end
		rawset(_G, "IsResting", function() return true end)
		if mine(ns) then fail(scenario, "in a city you were offered " .. key(mine(ns))) end
		ns.db.profile.ownBuffs.inCities = true
		if not mine(ns) then fail(scenario, "with Also in cities and inns ticked, the familiar was not offered") end
		rawset(_G, "IsResting", function() return false end)
		Mock.inCombat = true
		if mine(ns) then fail(scenario, "in a fight you were offered " .. key(mine(ns))) end
		Mock.inCombat = false
		ns.db.profile.sources.self = false
		if mine(ns) then fail(scenario, "with Myself off you were offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ 9
-- The scrolls are a mage's: a priest carrying them is never offered one, the
-- bags are never read for him, and no row of theirs shows.
do
	local scenario = "mage-scrolls: another class with the scrolls is never offered them"
	-- Fortitude and Inner Fire learned, so he has buffs of his own to offer.
	with(scenario, { class = "PRIEST", known = { 1243, 588 }, bags = { [RAT] = 1, [LESSER_FLAME] = 1 } }, function(ns)
		local me = mine(ns)
		if not me then fail(scenario, "SKIPPED -- the priest is offered nothing of his own") end
		if me and me.buff and me.buff.item then fail(scenario, "a priest was offered " .. key(me)) end
		if family(ns, "familiar") or family(ns, "imbue") then
			fail(scenario, "a priest has a scroll family of his own")
		end
		for _, name in ipairs({ "own_familiar", "own_imbue" }) do
			local control = findOption(ns.optionsTable, name)
			if control and control.hidden() ~= true then fail(scenario, "a priest is shown " .. name) end
		end
		if world.reads ~= 0 then fail(scenario, ("a priest's bags were read %d times"):format(world.reads)) end
	end)
end

-- ------------------------------------------------------------------ 10
-- The rows under Myself: Automatic, every scroll of the family by its name,
-- Don't remind me; placed by the window's layout and shown there while there
-- is a scroll in the bags. Who to buff's reset puts the picks back to
-- Automatic, and the bug report lists the scrolls you carry.
do
	local scenario = "mage-scrolls: the Myself rows list every scroll"
	with(scenario, { bags = { [RAT] = 1, [CHILLKNIFE] = 1 } }, function(ns)
		local familiar = findOption(ns.optionsTable, "own_familiar")
		local imbue = findOption(ns.optionsTable, "own_imbue")
		if not (familiar and imbue and familiar.values and imbue.values) then
			fail(scenario, "a mage with scrolls has no Familiar or Weapon imbue dropdown")
			return
		end
		if familiar.name() ~= "Familiar" or imbue.name() ~= "Weapon imbue" then
			fail(scenario, ("the rows are called %s and %s"):format(tostring(familiar.name()), tostring(imbue.name())))
		end
		local order = table.concat(familiar.sorting(), " ")
		if order ~= "auto catfamiliar frogfamiliar ratfamiliar off" then
			fail(scenario, "the Familiar choices are " .. order)
		end
		local values = familiar.values()
		if values.catfamiliar ~= "Cat Familiar" or values.ratfamiliar ~= "Rat Familiar"
			or values.off ~= "Don't remind me" then
			fail(scenario, ("the Familiar choices read %s, %s, %s"):format(tostring(values.catfamiliar),
				tostring(values.ratfamiliar), tostring(values.off)))
		end
		local imbues = imbue.sorting()
		if #imbues ~= 18 then fail(scenario, ("the Weapon imbue dropdown has %d choices, not 18"):format(#imbues)) end
		values = imbue.values()
		if values.imbuechillknife ~= "Imbue Chillknife" or values.imbuespellbreak ~= "Scroll of Imbue Spellbreak" then
			fail(scenario, ("the imbues read %s and %s"):format(tostring(values.imbuechillknife),
				tostring(values.imbuespellbreak)))
		end

		-- Placed under Myself, and drawn there.
		for _, path in ipairs({ "who.own_familiar", "who.own_imbue" }) do
			local page, section = H.placedOn(ns, path)
			if page ~= "who" or not (section and section.key == "who.myself") then
				fail(scenario, path .. " is not placed under Myself: " .. tostring(page))
			end
		end
		ns.OpenOptions("who")
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		if not (UI and UI.RowShown("who.own_familiar") and UI.RowShown("who.own_imbue")) then
			fail(scenario, "the window does not show the Familiar and Weapon imbue rows")
		end

		-- Who to buff's reset.
		familiar.set({ "own_familiar" }, "off")
		imbue.set({ "own_imbue" }, "imbuechillknife")
		if ns.OptionsPage.ResetPage("who") ~= true then fail(scenario, "SKIPPED -- the reset did not run") end
		if familiar.get() ~= "auto" or imbue.get() ~= "auto" then
			fail(scenario, ("after Who to buff's reset the picks are %s and %s"):format(tostring(familiar.get()),
				tostring(imbue.get())))
		end

		-- The bug report, and the Myself lines on the page.
		local report = findOption(ns.optionsTable, "report").get({ "diagnostics", "report" })
		if not tostring(report):find("scrolls ratfamiliar=ready imbuechillknife=weapon", 1, true) then
			fail(scenario, "the bug report says nothing of the scrolls: " .. flat(report))
		end
		local diag = findOption(ns.optionsTable, "ownDiag")
		local text = diag and diag.name() or ""
		if not text:find("Familiar: none up -- Rat Familiar is the one to use.", 1, true) then
			fail(scenario, "Diagnostics says: " .. flat(text))
		end
	end)
end

-- ------------------------------------------------------------------ 11
-- Spellbreak's use casts Lesser Flame's spell in the client's own data: a
-- press on it is settled by that spell, not taken for something else that
-- went out, and the enchant it leaves is remembered as Spellbreak's.
do
	local scenario = "mage-scrolls: a Spellbreak press is settled by the spell its use casts"
	with(scenario, { bags = { [SPELLBREAK] = 1 }, level = 46 }, function(ns)
		ns.Prompt:Refresh()
		if key(ns.Prompt:Showing()) ~= "imbuespellbreak" then
			fail(scenario, "SKIPPED -- the prompt is not on Spellbreak: " .. key(ns.Prompt:Showing()))
			return
		end
		local pressed = H.pressButton(ns)
		if pressed ~= "/use item:" .. SPELLBREAK .. "\n/use 16" then
			fail(scenario, "SKIPPED -- the press did not go out: " .. flat(pressed))
			return
		end
		Mock.printed = {}
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-scroll-2", 1295720)
		if ns.pendingClick or said():find("went out instead", 1, true) then
			fail(scenario, "Spellbreak's own cast was taken for another: " .. flat(said()))
		end
		if not ns.IsBlocked(ns.UnitFullName("player"), "imbuespellbreak") then
			fail(scenario, "Spellbreak was not given its retry cooldown after the press")
		end
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 3600 }
		mine(ns)
		if ns.db.char.ownLast.imbue ~= "imbuespellbreak" then
			fail(scenario, "the enchant was remembered as " .. tostring(ns.db.char.ownLast.imbue))
		end
	end)
end

-- One press of the prompt on `want`, and the SENT that settles it, with the
-- cast guid `guid` and the spell the use casts. False, said as SKIPPED, when
-- the prompt is on something else or the press did not go out.
local function press(ns, scenario, want, guid, spellId)
	ns.Prompt:Refresh()
	if key(ns.Prompt:Showing()) ~= want then
		fail(scenario, ("SKIPPED -- the prompt is on %s, not %s"):format(key(ns.Prompt:Showing()), want))
		return false
	end
	local pressed = H.pressButton(ns)
	if not (pressed and pressed:find("/use item:", 1, true) and ns.pendingClick and ns.pendingClick.onSelf) then
		fail(scenario, "SKIPPED -- the press on " .. want .. " did not go out: " .. flat(pressed))
		return false
	end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, spellId)
	return true
end

-- ------------------------------------------------------------------ 12
-- Lesser Flame and Spellbreak make the same enchant (8700), so the enchant
-- alone cannot say which is on the weapon. A level-20 mage carrying both --
-- a Spellbreak from a Bundle of Scrolls, below the level it asks for -- can
-- only have used Lesser Flame; a level-50 mage is told by the press he made.
-- Read, remembered, named and topped up as the one used, never as the first
-- in the table.
do
	local scenario = "mage-scrolls: Lesser Flame is told from Spellbreak, which makes the same enchant"
	with(scenario, { bags = { [LESSER_FLAME] = 2, [SPELLBREAK] = 1 }, held = { RAT_AURA }, level = 20 }, function(ns)
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, "SKIPPED -- a level-20 mage was offered " .. key(mine(ns)) .. ", not Lesser Flame")
			return
		end
		-- Used from the bags by hand.
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 1800 }
		if not lines(ns):find("Weapon imbue: Imbue Lesser Flame is up.", 1, true) then
			fail(scenario, "a level-20 mage's Lesser Flame: /manners debug says " .. lines(ns))
		end
		if ns.db.char.ownLast.imbue ~= "imbuelesserflame" then
			fail(scenario, "a level-20 mage's Lesser Flame was remembered as " .. tostring(ns.db.char.ownLast.imbue))
		end
		ns.db.profile.filters.whenBuffed = "refresh"
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 120 }
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, ("two minutes of a level-20 mage's Lesser Flame offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
		world.enchant = nil
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, "once a level-20 mage's Lesser Flame wore off, Automatic offered " .. key(mine(ns)))
		end
		-- His last Lesser Flame used by hand: the Spellbreak left in the bags
		-- asks for a level he does not have, so it is still Lesser Flame.
		restock(ns, { [SPELLBREAK] = 1 })
		ns.db.char.ownLast.imbue = nil
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 3600 }
		mine(ns)
		if ns.db.char.ownLast.imbue ~= "imbuelesserflame" then
			fail(scenario, "a level-20 mage's last Lesser Flame, with a Spellbreak left, was remembered as "
				.. tostring(ns.db.char.ownLast.imbue))
		end
	end)

	-- Level 50 after a reload, with nothing pressed this session: the one he
	-- had on last, not the first that makes the enchant.
	with(scenario, { bags = { [LESSER_FLAME] = 2, [SPELLBREAK] = 2 }, held = { RAT_AURA }, level = 50 }, function(ns)
		ns.db.char.ownLast = ns.db.char.ownLast or {}
		ns.db.char.ownLast.imbue = "imbuelesserflame"
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 3600 }
		if not lines(ns):find("Weapon imbue: Imbue Lesser Flame is up.", 1, true) then
			fail(scenario, "a level-50 mage's Lesser Flame from before a reload: /manners debug says " .. lines(ns))
		end
	end)

	-- Level 50 with Lesser Flame alone in the bags and nothing to go on: the
	-- one he can use, not Spellbreak, first in the table and not carried.
	with(scenario, { bags = { [LESSER_FLAME] = 2 }, held = { RAT_AURA }, level = 50 }, function(ns)
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 3600 }
		if not lines(ns):find("Weapon imbue: Imbue Lesser Flame is up.", 1, true) then
			fail(scenario, "a level-50 mage with Lesser Flame alone in the bags: /manners debug says " .. lines(ns))
		end
	end)

	-- Level 50, both in the bags: each pressed in turn from the prompt.
	with(scenario, { bags = { [LESSER_FLAME] = 2, [SPELLBREAK] = 2 }, held = { RAT_AURA }, level = 50 }, function(ns)
		local control = findOption(ns.optionsTable, "own_imbue")
		if not (control and control.set) then
			fail(scenario, "SKIPPED -- there is no Weapon imbue dropdown")
			return
		end
		local function used(want, guid)
			if not press(ns, scenario, want, guid, 1295720) then return false end
			ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", guid, 1295720)
			world.enchant = { id = LESSER_FLAME_ENCHANT, left = 3600 }
			mine(ns)
			return true
		end
		control.set({ "own_imbue" }, "imbuespellbreak")
		if not used("imbuespellbreak", "Cast-imbue-1") then return end
		if ns.db.char.ownLast.imbue ~= "imbuespellbreak" then
			fail(scenario, "a Spellbreak used from the prompt was remembered as " .. tostring(ns.db.char.ownLast.imbue))
		end
		world.enchant = nil
		Mock.advance(5)
		wipe(ns.tried)
		control.set({ "own_imbue" }, "imbuelesserflame")
		if not used("imbuelesserflame", "Cast-imbue-2") then return end
		if ns.db.char.ownLast.imbue ~= "imbuelesserflame" then
			fail(scenario, "a Lesser Flame used from the prompt with a Spellbreak in the bags was remembered as "
				.. tostring(ns.db.char.ownLast.imbue))
		end
		-- Automatic tops up the one on, not the other.
		control.set({ "own_imbue" }, "auto")
		ns.db.profile.filters.whenBuffed = "refresh"
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 120 }
		Mock.advance(15)
		wipe(ns.tried)
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, "two minutes of a level-50 mage's Lesser Flame offered " .. key(mine(ns)))
		end

		-- A Spellbreak press whose cast is cut short has put nothing on: the
		-- Lesser Flame used by hand after it is still Lesser Flame.
		world.enchant = nil
		control.set({ "own_imbue" }, "imbuespellbreak")
		if not press(ns, scenario, "imbuespellbreak", "Cast-imbue-3", 1295720) then return end
		Mock.advance(2.5)
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-imbue-3", 1295720)
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 3600 }
		-- Past the short block the interrupt leaves, which holds every own
		-- buff back and with it the reading.
		Mock.advance(2.1)
		mine(ns)
		if not lines(ns):find("Weapon imbue: Imbue Lesser Flame is up.", 1, true)
			or ns.db.char.ownLast.imbue ~= "imbuelesserflame" then
			fail(scenario, "after a Spellbreak press cut short, the Lesser Flame on was remembered as "
				.. tostring(ns.db.char.ownLast.imbue))
		end
	end)
end

-- ------------------------------------------------------------------ 12b
-- The same enchant, and the scroll named for it used up: the top-up is the
-- other scroll that makes it. A level-50 mage used his last Spellbreak with
-- five Lesser Flames in the bags, and nothing was offered while the enchant
-- ran low -- /manners debug said he had no Spellbreak -- until it wore off.
-- The same after a reload, and the other way round. An enchant no scroll in
-- the bags makes is still nobody's to top up.
do
	local scenario = "mage-scrolls: a top-up uses the other scroll that makes the same enchant"
	local function topUp(ns, label, want)
		ns.db.profile.filters.whenBuffed = "refresh"
		world.enchant = { id = world.enchant and world.enchant.id or LESSER_FLAME_ENCHANT, left = 120 }
		local me = mine(ns)
		if key(me) ~= tostring(want) then
			fail(scenario, ("%s, two minutes left: offered %s, not %s; /manners debug says %s")
				:format(label, key(me), tostring(want), lines(ns)))
		elseif want and not (me.remaining and me.remaining <= 120) then
			fail(scenario, label .. ": offered as no top-up: " .. tostring(me.remaining))
		end
	end

	-- In one session: the Spellbreak pressed was his last.
	with(scenario, { bags = { [LESSER_FLAME] = 5, [SPELLBREAK] = 1 }, held = { RAT_AURA }, level = 50 }, function(ns)
		if not press(ns, scenario, "imbuespellbreak", "Cast-twin-1", 1295720) then return end
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-twin-1", 1295720)
		restock(ns, { [LESSER_FLAME] = 5 })
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 3600 }
		mine(ns)
		if ns.db.char.ownLast.imbue ~= "imbuespellbreak" then
			fail(scenario, "SKIPPED -- the Spellbreak used was remembered as " .. tostring(ns.db.char.ownLast.imbue))
			return
		end
		Mock.advance(3480)
		topUp(ns, "his last Spellbreak used, Lesser Flame in the bags", "imbuelesserflame")
	end)

	-- After a reload, the Spellbreak remembered and none left.
	with(scenario, { bags = { [LESSER_FLAME] = 5 }, held = { RAT_AURA }, level = 50 }, function(ns)
		ns.db.char.ownLast = ns.db.char.ownLast or {}
		ns.db.char.ownLast.imbue = "imbuespellbreak"
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 3600 }
		topUp(ns, "Spellbreak remembered from before a reload, Lesser Flame in the bags", "imbuelesserflame")
	end)

	-- The other way round: Lesser Flame remembered, a Spellbreak left.
	with(scenario, { bags = { [SPELLBREAK] = 1 }, held = { RAT_AURA }, level = 50 }, function(ns)
		ns.db.char.ownLast = ns.db.char.ownLast or {}
		ns.db.char.ownLast.imbue = "imbuelesserflame"
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 3600 }
		topUp(ns, "Lesser Flame remembered, a Spellbreak in the bags", "imbuespellbreak")
	end)

	-- Frost on the staff and only Lesser Flame left: another enchant, so no
	-- top-up -- Lesser Flame would replace it.
	with(scenario, { bags = { [LESSER_FLAME] = 5 }, held = { RAT_AURA }, level = 50 }, function(ns)
		world.enchant = { id = 8709, left = 3600 }
		topUp(ns, "Frost running low, Lesser Flame in the bags", nil)
	end)
end

-- ------------------------------------------------------------------ 13
-- Spellbreak is named by its item, since its spell is Lesser Flame's. A mage
-- who has never carried one has never loaded the item, so the client has no
-- name for it yet: a name of its own stands in, the item is asked for, and
-- the item's name is taken once the client has it. Never two Lesser Flames
-- in the dropdown.
do
	local scenario = "mage-scrolls: Spellbreak before the client has its item is not named as Lesser Flame"
	-- At Spellbreak's own level: below it, a pick gives way to Automatic's
	-- Lesser Flame while there is one to use.
	with(scenario, { bags = { [LESSER_FLAME] = 2 }, held = { RAT_AURA }, level = 46,
		unloaded = { [SPELLBREAK] = true } }, function(ns)
		local control = findOption(ns.optionsTable, "own_imbue")
		if not (control and control.values) then
			fail(scenario, "SKIPPED -- there is no Weapon imbue dropdown")
			return
		end
		local values = control.values()
		if values.imbuespellbreak == values.imbuelesserflame or values.imbuespellbreak ~= "Imbue Spellbreak" then
			fail(scenario, ("before the item loaded, Spellbreak reads %s and Lesser Flame %s")
				:format(tostring(values.imbuespellbreak), tostring(values.imbuelesserflame)))
		end
		if not world.requested[SPELLBREAK] then fail(scenario, "the Spellbreak item was never asked for") end
		control.set({ "own_imbue" }, "imbuespellbreak")
		if not lines(ns):find("Weapon imbue: you have no Imbue Spellbreak in your bags.", 1, true) then
			fail(scenario, "picked Spellbreak with none in the bags: /manners debug says " .. lines(ns))
		end
		world.unloaded = nil
		values = control.values()
		if values.imbuespellbreak ~= "Scroll of Imbue Spellbreak" then
			fail(scenario, "once the item loaded, Spellbreak reads " .. tostring(values.imbuespellbreak))
		end
	end)
end

-- ------------------------------------------------------------------ 14
-- A wizard oil running low with top-ups on: no scroll tops it up, so nothing
-- is offered and /manners debug says the weapon carries an enchant, not that
-- Automatic has nothing to pick with a Lesser Flame in the bags.
do
	local scenario = "mage-scrolls: an oil running low is an enchant on the weapon, not nothing to pick"
	with(scenario, { bags = { [RAT] = 1, [LESSER_FLAME] = 1 }, held = { RAT_AURA },
		enchant = { id = OIL, left = 60, kind = TEMPORARY } }, function(ns)
		ns.db.profile.filters.whenBuffed = "refresh"
		if mine(ns) then fail(scenario, "a wizard oil with a minute left offered " .. key(mine(ns))) end
		local text = lines(ns)
		if not text:find("Weapon imbue: your main hand already carries a temporary enchant.", 1, true)
			or text:find("Automatic has nothing it would pick", 1, true) then
			fail(scenario, "a wizard oil with a minute left: /manners debug says " .. text)
		end
		local diag = findOption(ns.optionsTable, "ownDiag")
		local shown = diag and diag.name() or ""
		if not shown:find("Weapon imbue: your main hand already carries a temporary enchant.", 1, true) then
			fail(scenario, "a wizard oil with a minute left: Diagnostics says " .. flat(shown))
		end
	end)
end

-- ------------------------------------------------------------------ 15
-- The order the enchant is read in. C_Item.GetWeaponEnchantInfo, the list
-- the client's own buff bar reads, wherever it is there: neither old call is
-- asked beside it. Without it, C_PaperDollInfo.GetTemporaryEnchantmentInfo;
-- GetWeaponEnchantInfo -- Blizzard_Deprecated's shim over that, there while
-- loadDeprecationFallbacks is on and reading all three weapon slots per
-- call -- only without both. With none of them the weapon is not read and
-- nothing is offered. The old calls report a Temporary enchant alone, so
-- here the scroll's enchant is one.
do
	local scenario = "mage-scrolls: the enchant is read with the list first, the old calls only without it"
	-- All three: the list alone.
	with(scenario, { bags = { [LESSER_FLAME] = 1 }, held = { RAT_AURA }, api = "list+temporary+shim",
		enchant = { id = LESSER_FLAME_ENCHANT, left = 1800 } }, function(ns)
		for _ = 1, 3 do
			Mock.advance(1)
			ns.addon:Tick()
		end
		if mine(ns) then fail(scenario, "with all three calls and Lesser Flame on, you were offered " .. key(mine(ns))) end
		if world.listReads == 0 then fail(scenario, "with all three calls, the list was never asked") end
		if world.temporaryReads ~= 0 or world.shimReads ~= 0 then
			fail(scenario, ("with the list there, GetTemporaryEnchantmentInfo was asked %d times and the shim %d")
				:format(world.temporaryReads, world.shimReads))
		end
	end)
	-- No list, and both old calls: the shim never asked.
	with(scenario, { bags = { [LESSER_FLAME] = 1 }, held = { RAT_AURA }, api = "temporary+shim" }, function(ns)
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, "with GetTemporaryEnchantmentInfo first and a bare staff, you were offered " .. key(mine(ns)))
		end
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 1800, kind = TEMPORARY }
		for _ = 1, 3 do
			Mock.advance(1)
			ns.addon:Tick()
		end
		if mine(ns) then
			fail(scenario, "with GetTemporaryEnchantmentInfo first and Lesser Flame on, you were offered " .. key(mine(ns)))
		end
		if lastImbue(ns) ~= "imbuelesserflame" then
			fail(scenario, "with GetTemporaryEnchantmentInfo first, Lesser Flame was remembered as "
				.. tostring(lastImbue(ns)))
		end
		if world.shimReads ~= 0 then
			fail(scenario, ("GetWeaponEnchantInfo was asked %d times with GetTemporaryEnchantmentInfo there"):format(
				world.shimReads))
		end
	end)
	-- The shim alone, the deprecation fallbacks on a client without the
	-- other two: it still serves.
	with(scenario, { bags = { [LESSER_FLAME] = 1 }, held = { RAT_AURA }, api = "shim" }, function(ns)
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, "with GetWeaponEnchantInfo alone and a bare staff, you were offered " .. key(mine(ns)))
		end
		world.enchant = { id = LESSER_FLAME_ENCHANT, left = 1800, kind = TEMPORARY }
		if mine(ns) then
			fail(scenario, "with GetWeaponEnchantInfo alone and Lesser Flame on, you were offered " .. key(mine(ns)))
		end
		if lastImbue(ns) ~= "imbuelesserflame" then
			fail(scenario, "with GetWeaponEnchantInfo alone, Lesser Flame was remembered as "
				.. tostring(lastImbue(ns)))
		end
	end)
	-- None: nothing is known of the weapon, so nothing is offered for it.
	with(scenario, { bags = { [LESSER_FLAME] = 1 }, held = { RAT_AURA }, api = "" }, function(ns)
		if mine(ns) then fail(scenario, "with no call to read the weapon, you were offered " .. key(mine(ns))) end
		if not lines(ns):find("Weapon imbue: the game will not say whether it is up, so it is not offered.", 1, true) then
			fail(scenario, "with no call to read the weapon, /manners debug says " .. lines(ns))
		end
	end)
end

-- ------------------------------------------------------------------ 16
-- A familiar up costs one aura read: a level-12 mage reads the Rat's alone
-- (a Frog or a Cat scroll asks for a level he does not have), and a mage of
-- any level reads the one he had up last first. Reading all three best first
-- was three reads and three pcalls on every scan, fights included.
do
	local scenario = "mage-scrolls: a familiar up costs one aura read"
	with(scenario, { bags = { [RAT] = 1, [LESSER_FLAME] = 1 }, held = { RAT_AURA },
		enchant = { id = LESSER_FLAME_ENCHANT, left = 1800 } }, function(ns)
		local familiar = family(ns, "familiar")
		if not familiar then
			fail(scenario, "SKIPPED -- no Familiar family for a mage with a Rat scroll")
			return
		end
		-- Nothing remembered, so the level alone keeps the Cat and the Frog
		-- unread.
		ns.db.char.ownLast.familiar = nil
		local before = Mock.counts.auraRead
		local up, spell = ns.ReadOwnFamily(familiar)
		if not (up and spell and spell.key == "ratfamiliar") then
			fail(scenario, "SKIPPED -- the Rat familiar is not read as up: " .. tostring(spell and spell.key))
		elseif Mock.counts.auraRead - before ~= 1 then
			fail(scenario, ("a level-12 mage's Rat familiar took %d aura reads, not 1"):format(
				Mock.counts.auraRead - before))
		end
	end)
	with(scenario, { bags = { [RAT] = 1, [CAT] = 1 }, held = { RAT_AURA }, level = 30,
		enchant = { id = LESSER_FLAME_ENCHANT, left = 1800 } }, function(ns)
		local familiar = family(ns, "familiar")
		if not familiar then
			fail(scenario, "SKIPPED -- no Familiar family for a mage with Rat and Cat scrolls")
			return
		end
		ns.ReadOwnFamily(familiar)
		if ns.db.char.ownLast.familiar ~= "ratfamiliar" then
			fail(scenario, "SKIPPED -- the Rat familiar was not remembered: " .. tostring(ns.db.char.ownLast.familiar))
			return
		end
		local before = Mock.counts.auraRead
		local up = ns.ReadOwnFamily(familiar)
		if not up then
			fail(scenario, "a level-30 mage's Rat familiar, read again, is not up")
		elseif Mock.counts.auraRead - before ~= 1 then
			fail(scenario, ("a level-30 mage's Rat familiar, the one he had up last, took %d aura reads, not 1")
				:format(Mock.counts.auraRead - before))
		end
	end)
end

-- ------------------------------------------------------------------ 17
-- A scroll's use takes three seconds, and SENT settles the press as the cast
-- starts. Moving cuts it short (INTERRUPTED, naming the cast) and nothing is
-- used up: the press is taken back as a refused one is, and the familiar is
-- offered again once that short block is out, not the imbue in its place for
-- the whole retry cooldown. The same for the cast failing after the settle's
-- window, by its guid; a cast the client says succeeded stays settled.
do
	local scenario = "mage-scrolls: a scroll's cast cut short is offered again"
	with(scenario, { bags = { [RAT] = 2, [LESSER_FLAME] = 1 } }, function(ns)
		ns.db.profile.verbose = true
		if not press(ns, scenario, "ratfamiliar", "Cast-rat-1", RAT_AURA) then return end
		if not ns.IsBlocked(ns.UnitFullName("player"), "ratfamiliar") then
			fail(scenario, "SKIPPED -- the familiar was not given its retry cooldown by the press")
			return
		end
		Mock.advance(2.5)
		Mock.printed = {}
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-rat-1", RAT_AURA)
		if not said():find("you were not buffed|r -- the cast was interrupted.", 1, true) then
			fail(scenario, "an interrupted scroll said: " .. flat(said()))
		end
		Mock.advance(2.1)
		if key(mine(ns)) ~= "ratfamiliar" then
			fail(scenario, "2 s after the Rat Familiar's cast was interrupted, you were offered " .. key(mine(ns)))
		end

		-- Failed after the window, by its guid.
		Mock.advance(5)
		wipe(ns.tried)
		if not press(ns, scenario, "ratfamiliar", "Cast-rat-2", RAT_AURA) then return end
		Mock.advance(2.5)
		ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-rat-2", RAT_AURA)
		Mock.advance(2.1)
		if key(mine(ns)) ~= "ratfamiliar" then
			fail(scenario, "2 s after the Rat Familiar's cast failed, you were offered " .. key(mine(ns)))
		end

		-- Succeeded: nothing takes it back, not even the same scroll used
		-- again from the bags and cut short.
		Mock.advance(5)
		wipe(ns.tried)
		if not press(ns, scenario, "ratfamiliar", "Cast-rat-3", RAT_AURA) then return end
		Mock.advance(3)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-rat-3", RAT_AURA)
		Mock.advance(1)
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-rat-4", RAT_AURA)
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", nil, RAT_AURA)
		Mock.advance(2.1)
		if not ns.IsBlocked(ns.UnitFullName("player"), "ratfamiliar") then
			fail(scenario, "a Rat Familiar cast that succeeded was taken back by a later interrupt")
		end

		-- A failure naming no cast is no word on this one: the same scroll
		-- pressed again from a bar mid-cast fails with its spell id too.
		Mock.advance(15)
		wipe(ns.tried)
		if not press(ns, scenario, "ratfamiliar", "Cast-rat-5", RAT_AURA) then return end
		Mock.advance(0.5)
		ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, RAT_AURA)
		Mock.advance(2.1)
		if not ns.IsBlocked(ns.UnitFullName("player"), "ratfamiliar") then
			fail(scenario, "a failure naming no cast took back the Rat Familiar being cast")
		end

		-- A client that names no cast at all: the interrupt is the scroll's by
		-- its spell while the cast can still be running, and not after.
		Mock.advance(15)
		wipe(ns.tried)
		if not press(ns, scenario, "ratfamiliar", nil, RAT_AURA) then return end
		Mock.advance(2.5)
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", nil, RAT_AURA)
		Mock.advance(2.1)
		if key(mine(ns)) ~= "ratfamiliar" then
			fail(scenario, "with no cast guids, 2 s after the Rat Familiar's cast was interrupted, you were offered "
				.. key(mine(ns)))
		end
		Mock.advance(5)
		wipe(ns.tried)
		if not press(ns, scenario, "ratfamiliar", nil, RAT_AURA) then return end
		Mock.advance(7)
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", nil, RAT_AURA)
		Mock.advance(2.1)
		if not ns.IsBlocked(ns.UnitFullName("player"), "ratfamiliar") then
			fail(scenario, "an interrupt 7 s after the Rat Familiar's three-second cast took the press back")
		end
	end)
end

-- ------------------------------------------------------------------ 18
-- A player's report: a scroll's imbue on the weapon, and the reminder asking
-- for one all the same. The imbue is an enchant of the Imbue kind, which
-- C_PaperDollInfo.GetTemporaryEnchantmentInfo never reports; the client's
-- own buff bar reads it from C_Item.GetWeaponEnchantInfo. Read from there:
-- not offered, and the scroll named and remembered.
do
	local scenario = "mage-scrolls: an imbue on is read from the client's list, which the temporary-enchant call leaves out"
	with(scenario, { bags = { [RAT] = 1, [LESSER_FLAME] = 1 }, held = { RAT_AURA },
		enchants = { entry(LESSER_FLAME_ENCHANT, IMBUE, 1800) } }, function(ns)
		if C_PaperDollInfo.GetTemporaryEnchantmentInfo(16) ~= nil then
			fail(scenario, "SKIPPED -- the temporary-enchant call reports the imbue")
			return
		end
		if mine(ns) then
			fail(scenario, "with Lesser Flame's imbue on the staff, you were offered " .. key(mine(ns)))
		end
		if not lines(ns):find("Weapon imbue: Imbue Lesser Flame is up.", 1, true) then
			fail(scenario, "with Lesser Flame's imbue on the staff, /manners debug says " .. lines(ns))
		end
		if lastImbue(ns) ~= "imbuelesserflame" then
			fail(scenario, "Lesser Flame's imbue on the staff was remembered as " .. tostring(lastImbue(ns)))
		end
		-- Worn off: nothing on the list, and Lesser Flame offered again.
		world.enchants = {}
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, "with the imbue worn off, you were offered " .. key(mine(ns)))
		end
	end)
	-- A client without Enum.WeaponSlot and Enum.ItemEnchantType: the numbers
	-- they stand for, the main hand 0 and an Imbue 3.
	with(scenario, { bags = { [RAT] = 1, [LESSER_FLAME] = 1 }, held = { RAT_AURA },
		enchants = { entry(LESSER_FLAME_ENCHANT, IMBUE, 1800) } }, function(ns)
		local enum = {}
		for name, values in pairs(Enum) do enum[name] = values end
		enum.WeaponSlot, enum.ItemEnchantType = nil, nil
		rawset(_G, "Enum", enum)
		if mine(ns) then
			fail(scenario, "without the weapon enums and Lesser Flame on the staff, you were offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 19
-- On the list, an oil (Temporary) has seen to the weapon as a scroll's imbue
-- has; an enchanter's enchant (Permanent) never has, alone or beside one.
do
	local scenario = "mage-scrolls: an oil on the list counts, a permanent enchant never does"
	with(scenario, { bags = { [LESSER_FLAME] = 1 }, held = { RAT_AURA },
		enchants = { entry(OIL, TEMPORARY, 1800) } }, function(ns)
		if mine(ns) then fail(scenario, "with a wizard oil on the list, you were offered " .. key(mine(ns))) end
		if not lines(ns):find("Weapon imbue: your main hand already carries a temporary enchant.", 1, true) then
			fail(scenario, "with a wizard oil on the list, /manners debug says " .. lines(ns))
		end
		if lastImbue(ns) ~= nil then
			fail(scenario, "a wizard oil on the list was remembered as " .. tostring(lastImbue(ns)))
		end
	end)
	with(scenario, { bags = { [LESSER_FLAME] = 1 }, held = { RAT_AURA },
		enchants = { entry(CRUSADER, PERMANENT, 0) } }, function(ns)
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, ("with only Crusader on the staff, you were offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
		world.enchants = { entry(CRUSADER, PERMANENT, 0), entry(LESSER_FLAME_ENCHANT, IMBUE, 1800) }
		if mine(ns) then
			fail(scenario, "with Crusader and Lesser Flame on the staff, you were offered " .. key(mine(ns)))
		end
		if not lines(ns):find("Weapon imbue: Imbue Lesser Flame is up.", 1, true) then
			fail(scenario, "with Crusader and Lesser Flame on the staff, /manners debug says " .. lines(ns))
		end
	end)
end

-- ------------------------------------------------------------------ 20
-- A secret on the list, or a field missing, is the client not saying: never
-- a reason to offer, and nothing remembered. Whether one is on, its kind (it
-- could be an enchanter's), the entry or the whole list; a missing
-- hasEnchant the same. An entry that does say is enough, whatever the rest
-- hide; one that hides only its enchant is on, and nobody's scroll.
do
	local scenario = "mage-scrolls: a secret on the list is the client not saying"
	-- Withheld: not offered, nothing remembered, and /manners debug says so.
	local function withheld(ns)
		return mine(ns) == nil and lastImbue(ns) == nil
			and lines(ns):find("Weapon imbue: the game will not say whether it is up, so it is not offered.", 1, true) ~= nil
	end
	local function told(ns)
		return ("offered %s, remembered as %s; /manners debug says %s"):format(key(mine(ns)),
			tostring(lastImbue(ns)), lines(ns))
	end
	local function hiding(field, value)
		local e = entry(LESSER_FLAME_ENCHANT, IMBUE, 1800)
		e[field] = value
		return e
	end
	with(scenario, { bags = { [LESSER_FLAME] = 1 }, held = { RAT_AURA },
		enchants = { hiding("hasEnchant", Mock.SECRET) } }, function(ns)
		if not withheld(ns) then fail(scenario, "with hasEnchant secret, the weapon was read: " .. told(ns)) end
		world.enchants = { hiding("enchantType", Mock.SECRET) }
		if not withheld(ns) then fail(scenario, "with the enchant's kind secret, the weapon was read: " .. told(ns)) end
		world.enchants = { Mock.SECRET }
		if not withheld(ns) then fail(scenario, "with the entry secret, the weapon was read: " .. told(ns)) end
		world.enchants = Mock.SECRET
		if not withheld(ns) then fail(scenario, "with the whole list secret, the weapon was read: " .. told(ns)) end
		world.enchants = { hiding("hasEnchant", nil) }
		if not withheld(ns) then fail(scenario, "with hasEnchant missing, the weapon was read: " .. told(ns)) end
		-- One that says, behind one that does not.
		world.enchants = { hiding("hasEnchant", Mock.SECRET), entry(LESSER_FLAME_ENCHANT, IMBUE, 1800) }
		if mine(ns) or lastImbue(ns) ~= "imbuelesserflame" then
			fail(scenario, "Lesser Flame behind a secret entry: " .. told(ns))
		end
	end)
	with(scenario, { bags = { [LESSER_FLAME] = 1 }, held = { RAT_AURA },
		enchants = { hiding("enchantID", Mock.SECRET) } }, function(ns)
		if mine(ns) or lastImbue(ns) ~= nil then
			fail(scenario, "an imbue whose enchant is secret: " .. told(ns))
		end
	end)
end

-- ------------------------------------------------------------------ 21
-- The list's time left is in milliseconds: two minutes of Lesser Flame with
-- top-ups on is offered again, half an hour is not. With an oil on beside
-- it, listed before or after, the scroll's imbue is the one read, named and
-- topped up.
do
	local scenario = "mage-scrolls: the list's milliseconds drive a top-up, of the scroll's imbue beside an oil"
	with(scenario, { bags = { [LESSER_FLAME] = 2 }, held = { RAT_AURA },
		enchants = { entry(LESSER_FLAME_ENCHANT, IMBUE, 120) } }, function(ns)
		ns.db.profile.filters.whenBuffed = "refresh"
		local me = mine(ns)
		if key(me) ~= "imbuelesserflame" or not (me.remaining and me.remaining > 110 and me.remaining <= 120) then
			fail(scenario, ("two minutes of Lesser Flame on the list, top-ups on: offered %s, %s left")
				:format(key(me), tostring(me and me.remaining)))
		end
		world.enchants = { entry(LESSER_FLAME_ENCHANT, IMBUE, 1800) }
		if mine(ns) then
			fail(scenario, "half an hour of Lesser Flame on the list, top-ups on: offered " .. key(mine(ns)))
		end
		world.enchants = { entry(OIL, TEMPORARY, 1800), entry(LESSER_FLAME_ENCHANT, IMBUE, 120) }
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, ("an oil listed before two minutes of Lesser Flame: offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
		world.enchants = { entry(LESSER_FLAME_ENCHANT, IMBUE, 120), entry(OIL, TEMPORARY, 1800) }
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, ("an oil listed after two minutes of Lesser Flame: offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 22
-- What if a Brilliant Wizard Oil and a scroll's imbue sit on one staff, and
-- the imbue runs out with the oil still on? The client lists each enchant
-- apart (scenario 21), so once it has listed the two together they stack,
-- and an oil alone means the scroll's imbue is gone: it is offered again.
-- Never seen together, an oil alone still counts (scenario 19), so nobody
-- is asked to put a scroll over an oil that would not take it.
do
	local scenario = "mage-scrolls: an oil alone, once seen beside a scroll's imbue, no longer counts"
	with(scenario, { bags = { [LESSER_FLAME] = 2 }, held = { RAT_AURA },
		enchants = { entry(OIL, TEMPORARY, 1700), entry(LESSER_FLAME_ENCHANT, IMBUE, 1800) } }, function(ns)
		if mine(ns) then
			fail(scenario, "SKIPPED -- an oil and Lesser Flame on the staff offered " .. key(mine(ns)))
			return
		end
		world.enchants = { entry(OIL, TEMPORARY, 1600) }
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, ("the imbue ran out under an oil seen beside it, and you were offered %s; "
				.. "/manners debug says %s"):format(key(mine(ns)), lines(ns)))
		end
		if not lines(ns):find("Weapon imbue: none up -- Imbue Lesser Flame is the one to use.", 1, true) then
			fail(scenario, "with the imbue gone from under the oil, /manners debug says " .. lines(ns))
		end
	end)
end

-- ------------------------------------------------------------------ 23
-- What if two mages share the Default profile, the main picks Cat Familiar
-- or Imbue Greater Frost, and the level-14 alt carries Rats and Lesser
-- Flames? A pick above your level steps aside for Automatic while it has a
-- scroll to use, and takes over again at its level; the dropdown keeps it.
do
	local GREATER_FROST = 277501
	local scenario = "mage-scrolls: a scroll picked above your level gives way to Automatic until you reach it"
	with(scenario, { bags = { [RAT] = 4 }, level = 14 }, function(ns)
		local familiar = findOption(ns.optionsTable, "own_familiar")
		local imbue = findOption(ns.optionsTable, "own_imbue")
		if not (familiar and familiar.set) then
			fail(scenario, "SKIPPED -- there is no Familiar dropdown")
			return
		end
		familiar.set({ "own_familiar" }, "catfamiliar")
		if key(mine(ns)) ~= "ratfamiliar" then
			fail(scenario, ("Cat Familiar picked at level 14 with four Rats: offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
		if familiar.get() ~= "catfamiliar" then
			fail(scenario, "the dropdown no longer shows the pick: " .. tostring(familiar.get()))
		end
		-- Nothing Automatic could use (a Frog wants 16): the pick stands, and
		-- says why it waits in its own words.
		restock(ns, { [FROG] = 1 })
		if mine(ns) or not lines(ns):find("Familiar: you have no Cat Familiar in your bags.", 1, true) then
			fail(scenario, ("Cat picked at level 14 with only a Frog scroll: offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
		world.level = 25
		restock(ns, { [RAT] = 4, [CAT] = 1 })
		if key(mine(ns)) ~= "catfamiliar" then
			fail(scenario, "at level 25 with a Cat scroll, the pick offered " .. key(mine(ns)))
		end
		-- Out of Cats at its level: the pick holds, as scenario 7 has it.
		restock(ns, { [RAT] = 4 })
		if mine(ns) then fail(scenario, "Cat picked at 25 with none in the bags offered " .. key(mine(ns))) end

		-- The imbue the same way.
		world.level = 14
		world.held[RAT_AURA] = true
		restock(ns, { [LESSER_FLAME] = 3 })
		if not (imbue and imbue.set) then
			fail(scenario, "SKIPPED -- there is no Weapon imbue dropdown")
			return
		end
		imbue.set({ "own_imbue" }, "imbuegreaterfrost")
		if key(mine(ns)) ~= "imbuelesserflame" then
			fail(scenario, ("Greater Frost picked at level 14 with Lesser Flames: offered %s; /manners debug says %s")
				:format(key(mine(ns)), lines(ns)))
		end
		world.level = 50
		restock(ns, { [GREATER_FROST] = 1, [LESSER_FLAME] = 3 })
		if key(mine(ns)) ~= "imbuegreaterfrost" then
			fail(scenario, "at level 50 with Greater Frost in the bags, the pick offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 24
-- What if a mage of 46 or more carries Imbue Spellbreak beside level-25 or
-- level-16 scrolls, with none remembered? Spellbreak puts on Lesser Flame's
-- +4 Fire (its spell and enchant are Lesser Flame's), so Automatic ranks it
-- with the level-5 scrolls, not ahead of Flame's +12 or Frost's +8.
do
	local ACCURACY, FLAME = 277494, 277497
	local scenario = "mage-scrolls: Automatic ranks Spellbreak with Lesser Flame, below the scrolls that do more"
	with(scenario, { bags = { [SPELLBREAK] = 2, [FLAME] = 1, [ACCURACY] = 1 }, held = { RAT_AURA }, level = 50 },
		function(ns)
			if key(mine(ns)) ~= "imbueaccuracy" then
				fail(scenario, ("Spellbreak, Flame and Accuracy at level 50: offered %s; /manners debug says %s")
					:format(key(mine(ns)), lines(ns)))
			end
			restock(ns, { [SPELLBREAK] = 2, [FROST] = 1 })
			if key(mine(ns)) ~= "imbuefrost" then
				fail(scenario, "Spellbreak and Frost at level 50: offered " .. key(mine(ns)))
			end
			restock(ns, { [SPELLBREAK] = 2, [LESSER_FLAME] = 1 })
			if key(mine(ns)) ~= "imbuespellbreak" then
				fail(scenario, "SKIPPED -- Spellbreak and Lesser Flame at level 50: offered " .. key(mine(ns)))
			end
		end)
end
