-- A mage's scrolls on WoW Forever as two of your own buffs: a familiar, and
-- a weapon imbue. A player asked on CurseForge for "one for making sure a
-- familiar is summoned and one for making sure a weapon imbue is on".
-- Buffs.lua holds the scrolls (the camelot set's own), Core.lua reads the
-- bags, your level, the weapon in your main hand and its temporary enchant
-- (ScrollReady, ReadImbue), Prompt/Macro.lua uses the scroll by its item id,
-- and Options/Who.lua and the window show the two families under Myself.
--
-- The mock has no item API, so each scenario stands one in: what the bags
-- hold, the weapon in the main hand, the enchant on it and your level. Your
-- own auras are Mock.playerHeld: Arcane Intellect, and a familiar where a
-- scenario says so. Nothing else is learned, so the scrolls are all there is
-- of your own to offer.
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

-- What /manners debug says about yourself, one line per family.
local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- The world a scenario stands in: bags (item -> count), weapon (the item in
-- the main hand), enchant ({ id, left } on it), level, and `reads`, how many
-- times the bags were asked for a count.
local world

local TOUCHED = { "C_Item", "GetInventoryItemID", "GetWeaponEnchantInfo", "UnitLevel", "IsResting",
	"IsSpellKnown", "IsPlayerSpell" }

local function install()
	rawset(_G, "C_Item", {
		GetItemCount = function(id)
			world.reads = world.reads + 1
			return world.bags[id] or 0
		end,
		GetItemNameByID = function(id) return ITEM_NAMES[id] end,
		GetItemIconByID = function(id) return icon(id) end,
		GetItemInfoInstant = function(id)
			if SUBCLASS[id] then return id, "Weapon", "", "INVTYPE_WEAPON", icon(id), 2, SUBCLASS[id] end
			return id, "Miscellaneous", "", "", icon(id), 15, 0
		end,
	})
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" and slot == 16 then return world.weapon end
		return nil
	end)
	rawset(_G, "GetWeaponEnchantInfo", function()
		local e = world.enchant
		if not e then return false, nil, nil, nil, false, nil, nil, nil end
		return true, e.left * 1000, 0, e.id, false, nil, nil, nil
	end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
end

-- One session as opts.class (a mage by default), with opts.bags, opts.weapon
-- (a staff by default), opts.enchant, opts.level (12) and opts.held (your own
-- auras besides Arcane Intellect), nobody else about; opts.known are the
-- spells learned (the mock's Arcane Intellect alone otherwise). opts.tree
-- records the frames (the prompt's icon). body(ns) runs and everything is put
-- back, whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	if opts.class then Mock.class = opts.class end
	world = { bags = opts.bags or {}, weapon = opts.weapon or STAFF, enchant = opts.enchant,
		level = opts.level or 12, reads = 0 }
	local held = { [INTELLECT] = true }
	for _, id in ipairs(opts.held or {}) do held[id] = true end
	world.held = held
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	install()
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
		if macro(ns) ~= "/use item:" .. LESSER_FLAME then
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

		-- A Frog familiar with you and only Rat scrolls in the bags.
		world.held[RAT_AURA], world.held[FROG_AURA] = nil, true
		if mine(ns) then
			fail(scenario, "with a Frog familiar up, the Rat scroll was offered: " .. key(mine(ns)))
		end

		-- A wizard oil on the staff.
		world.enchant = { id = OIL, left = 1800 }
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
-- dagger. The weapon is read again when the equipment changes.
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
		if pressed ~= "/use item:" .. SPELLBREAK then
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
