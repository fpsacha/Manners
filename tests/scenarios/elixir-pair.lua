-- Keeping two elixirs up (after 1.11.26). Burning Crusade and Mists have a battle and
-- a guardian slot, which only each elixir spell's own text names
-- (Consumables.lua's fourth value): two families there, Battle Elixir (the key
-- `elixir`, kept) and Guardian Elixir, each with its own switch; a flask fills
-- both, and on Mists a scroll takes its own slot alone. Classic Era and Forever
-- name no slot anywhere in their data: one family, and the elixirs ticked under
-- *Elixirs to keep up* (ownBuffs.elixirKeep) reminded of one at a time, with
-- two that turn out not to stack remembered as one (db.char.elixirClash). The
-- one switch's pick and memory carry over into the two once a profile
-- (Core.lua, ns.SplitElixirs).
--
-- Every scenario name starts with "elixir-pair:" so the mutations in
-- tests/mutations/elixir-pair.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function verdict(ns, family)
	return ns.OwnVerdict(family, { name = ns.UnitFullName("player"), now = GetTime(), whenBuffed = "skip",
		refreshUnder = 300 })
end

-- What a family offers now: its spell's key, or "none".
local function offers(ns, familyKey)
	local family = ns.FindOwnFamily(familyKey)
	if not family then return "no family " .. familyKey end
	local spell = verdict(ns, family)
	return spell and spell.key or "none"
end

-- The world a scenario stands in: bags (item -> count), the player's auras by
-- id (id -> expiry) and his level.
local world
local TOUCHED = { "C_Item", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell", "IsResting",
	"IsInInstance", "SPELL_FAILED_AURA_BOUNCED" }
local BOUNCED = "A more powerful spell is already active"

local function install()
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 2 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "IsSpellKnown", function() return false end)
	rawset(_G, "IsPlayerSpell", function() return false end)
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "SPELL_FAILED_AURA_BOUNCED", BOUNCED)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			local expires = world.auras[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 3600,
				sourceUnit = "player" }
		end,
		GetAuraDataBySpellName = function() return nil end,
	}, { __index = base }))
end

local LEVEL = { camelot = 60, vanilla = 60, tbc = 70, mists = 90 }
local function with(scenario, opts, body)
	local flavour = opts.flavour or "camelot"
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, level = LEVEL[flavour], auras = {} }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		install()
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		ns.db.profile.sources.self = true
		ns.db.profile.ownBuffs.inCities = true
		for _, k in ipairs(opts.on or {}) do ns.db.profile.ownBuffs.pick[k] = "auto" end
		ns.ForgetScrolls()
		body(ns, ns.CONSUMABLES and ns.CONSUMABLES[flavour])
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function stock(ns, bags)
	world.bags = bags
	ns.addon:BAG_UPDATE_DELAYED()
end

-- The auras on you now, every other one off: id -> seconds left.
local function wearing(ns, auras)
	world.auras = {}
	for id, left in pairs(auras) do world.auras[id] = GetTime() + left end
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
	Mock.advance(1)
end

-- The first elixir row of a slot (nil: any), best first.
local function firstOf(data, slot)
	for _, row in ipairs(data.elixir) do
		if slot == nil or row[4] == slot then return row end
	end
	return nil
end

local function said(text)
	local n = 0
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(text, 1, true) then n = n + 1 end
	end
	return n
end

-- ------------------------------------------------------------------ two slots

do
	local scenario = "elixir-pair: tbc: a battle and a guardian elixir are each reminded of, a flask fills both"
	with(scenario, { flavour = "tbc", on = { "elixir", "guardianelixir" } }, function(ns, data)
		local battle, guardian = firstOf(data, "battle"), firstOf(data, "guardian")
		if not (battle and guardian) then
			fail(scenario, "SKIPPED -- no battle or guardian elixir row on Burning Crusade")
			return
		end
		if not ns.FindOwnFamily("guardianelixir") then
			fail(scenario, "Burning Crusade has no Guardian Elixir family")
			return
		end
		stock(ns, { [battle[1]] = 1, [guardian[1]] = 1 })
		if offers(ns, "elixir") ~= "elixir" .. battle[1] or offers(ns, "guardianelixir") ~= "elixir" .. guardian[1] then
			fail(scenario, ("nothing on: battle offers %s, guardian %s"):format(offers(ns, "elixir"), offers(ns, "guardianelixir")))
			return
		end
		wearing(ns, { [battle[3]] = 1500 })
		if offers(ns, "elixir") ~= "none" then fail(scenario, "a battle elixir on, and Battle Elixir still offers " .. offers(ns, "elixir")) end
		if offers(ns, "guardianelixir") ~= "elixir" .. guardian[1] then
			fail(scenario, "a battle elixir on, and the guardian slot is not offered: " .. offers(ns, "guardianelixir"))
		end
		wearing(ns, { [guardian[3]] = 1500 })
		if offers(ns, "guardianelixir") ~= "none" then
			fail(scenario, "a guardian elixir on, and Guardian Elixir still offers " .. offers(ns, "guardianelixir"))
		end
		if offers(ns, "elixir") ~= "elixir" .. battle[1] then
			fail(scenario, "a guardian elixir on, and the battle slot is not offered: " .. offers(ns, "elixir"))
		end
		wearing(ns, { [data.flask[1][3]] = 1500 })
		if offers(ns, "elixir") ~= "none" or offers(ns, "guardianelixir") ~= "none" then
			fail(scenario, ("a flask on: battle offers %s, guardian %s"):format(offers(ns, "elixir"), offers(ns, "guardianelixir")))
		end
		-- The page says which slot each switch keeps.
		local control = findOption(ns.optionsTable, "own_guardianelixir")
		local desc = control and (type(control.desc) == "function" and control.desc() or control.desc)
		if type(desc) ~= "string" or not desc:find("guardian elixir", 1, true) then
			fail(scenario, "the Guardian Elixir switch says " .. tostring(desc))
		end
		local keep = findOption(ns.optionsTable, "own_elixirkeep")
		if keep and not (keep.hidden and keep.hidden()) then
			fail(scenario, "Elixirs to keep up is shown on Burning Crusade, where each slot has its switch")
		end
	end)
end

do
	local scenario = "elixir-pair: mists: a scroll takes its own slot alone"
	with(scenario, { flavour = "mists", on = { "elixir", "guardianelixir" } }, function(ns, data)
		local battle, guardian = firstOf(data, "battle"), firstOf(data, "guardian")
		local slots = data.scrollSlots or {}
		if not (battle and guardian and slots.stamina == "guardian" and slots.agility == "battle") then
			fail(scenario, "SKIPPED -- Mists' rows or scroll slots are not what this reads")
			return
		end
		stock(ns, { [battle[1]] = 1, [guardian[1]] = 1 })
		wearing(ns, { [data.scroll.stamina[1][3]] = 1500 })
		if offers(ns, "guardianelixir") ~= "none" then
			fail(scenario, "a Scroll of Stamina (guardian) on, and Guardian Elixir offers " .. offers(ns, "guardianelixir"))
		end
		if offers(ns, "elixir") ~= "elixir" .. battle[1] then
			fail(scenario, "a Scroll of Stamina (guardian) on, and the battle slot is not offered: " .. offers(ns, "elixir"))
		end
		wearing(ns, { [data.scroll.agility[1][3]] = 1500 })
		if offers(ns, "elixir") ~= "none" then
			fail(scenario, "a Scroll of Agility (battle) on, and Battle Elixir offers " .. offers(ns, "elixir"))
		end
		if offers(ns, "guardianelixir") ~= "elixir" .. guardian[1] then
			fail(scenario, "a Scroll of Agility (battle) on, and the guardian slot is not offered: " .. offers(ns, "guardianelixir"))
		end
		-- The scroll itself: held back under a battle elixir, not a guardian one.
		local scroll = data.scroll.agility[1]
		ns.db.profile.ownBuffs.pick.scrollagility = "auto"
		stock(ns, { [scroll[1]] = 1 })
		wearing(ns, { [battle[3]] = 1500 })
		if offers(ns, "scrollagility") ~= "none" then
			fail(scenario, "a battle elixir on, and a Scroll of Agility offered: " .. offers(ns, "scrollagility"))
		end
		wearing(ns, { [guardian[3]] = 1500 })
		if offers(ns, "scrollagility") ~= "scroll" .. scroll[1] then
			fail(scenario, "a guardian elixir on, and the Scroll of Agility held back: " .. offers(ns, "scrollagility"))
		end
		local control = findOption(ns.optionsTable, "own_elixir")
		local desc = control and (type(control.desc) == "function" and control.desc() or control.desc)
		if type(desc) ~= "string" or not desc:find("A scroll counts as a battle or a guardian elixir", 1, true) then
			fail(scenario, "the Battle Elixir switch does not say a scroll takes a slot: " .. tostring(desc))
		end
	end)
end

-- ------------------------------------------------------------------ keep up (Classic Era, Forever)

for _, client in ipairs({ "camelot", "vanilla" }) do
	local scenario = "elixir-pair: " .. client .. ": the elixirs ticked are each kept up"
	with(scenario, { flavour = client, on = { "elixir" } }, function(ns, data)
		local a, b, c = data.elixir[1], data.elixir[2], data.elixir[3]
		local family = ns.FindOwnFamily("elixir")
		if not (a and b and c and family and family.keep) then
			fail(scenario, "SKIPPED -- no three elixirs, or no keep family, on " .. client)
			return
		end
		local A, B = "elixir" .. a[1], "elixir" .. b[1]
		stock(ns, { [a[1]] = 1, [b[1]] = 1, [c[1]] = 1 })
		-- None ticked: any one elixir on you will do, as before.
		if offers(ns, "elixir") ~= A then fail(scenario, "none ticked, nothing on: offered " .. offers(ns, "elixir")) end
		wearing(ns, { [c[3]] = 1500 })
		if offers(ns, "elixir") ~= "none" then fail(scenario, "none ticked, an elixir on, and offered " .. offers(ns, "elixir")) end
		-- A and B ticked.
		ns.db.profile.ownBuffs.elixirKeep[A] = true
		ns.db.profile.ownBuffs.elixirKeep[B] = true
		if offers(ns, "elixir") ~= A then
			fail(scenario, "two ticked, an unticked one on: offered " .. offers(ns, "elixir") .. ", not the first ticked")
		end
		wearing(ns, { [a[3]] = 1500 })
		if offers(ns, "elixir") ~= B then fail(scenario, "two ticked, the first on: offered " .. offers(ns, "elixir")) end
		wearing(ns, { [a[3]] = 1500, [b[3]] = 1500 })
		if offers(ns, "elixir") ~= "none" then fail(scenario, "both ticked ones on, and offered " .. offers(ns, "elixir")) end
		local up = select(2, verdict(ns, family))
		if up ~= true then fail(scenario, "both ticked ones on, and the family reads " .. tostring(up)) end
		-- A ticked one not in the bags is not asked for. (Minutes on: the first
		-- going a moment after the second came would read as the second
		-- knocking it off.)
		Mock.advance(300)
		stock(ns, { [b[1]] = 1 })
		wearing(ns, { [b[3]] = 1500 })
		if offers(ns, "elixir") ~= "none" then
			fail(scenario, "the first ticked one not in the bags, the other on: offered " .. offers(ns, "elixir"))
		end
		if select(2, verdict(ns, family)) ~= true then
			fail(scenario, "the first ticked one not in the bags, the other on, and the family reads "
				.. tostring(select(2, verdict(ns, family))))
		end
		wearing(ns, {})
		if offers(ns, "elixir") ~= B then
			fail(scenario, "nothing on, the first ticked one not in the bags: offered " .. offers(ns, "elixir"))
		end
		-- The prompt offers it too.
		if key(mine(ns)) ~= B then fail(scenario, "the prompt offers " .. key(mine(ns))) end
		if ns.db.char.elixirClash ~= nil and next(ns.db.char.elixirClash) ~= nil then
			fail(scenario, "elixirs that each came and went in their own time were taken for a pair that does not stack")
		end
		-- The page: the box under the switch, its ticks written where they are read.
		local control = findOption(ns.optionsTable, "own_elixirkeep")
		if not control then
			fail(scenario, "Who to buff has no Elixirs to keep up")
			return
		end
		stock(ns, { [a[1]] = 1, [b[1]] = 1, [c[1]] = 1 })
		if control.hidden() then fail(scenario, "Elixirs to keep up is hidden with the switch on and elixirs in the bags") end
		local values = control.values()
		if not (values[A] and values[B] and values["elixir" .. c[1]]) then
			fail(scenario, "Elixirs to keep up does not list the elixirs in the bags")
		end
		control.set(nil, "elixir" .. c[1], true)
		if ns.db.profile.ownBuffs.elixirKeep["elixir" .. c[1]] ~= true or not control.get(nil, "elixir" .. c[1]) then
			fail(scenario, "ticking one wrote nothing")
		end
		control.set(nil, "elixir" .. c[1], false)
		ns.db.profile.ownBuffs.pick.elixir = "off"
		if not control.hidden() then fail(scenario, "Elixirs to keep up is shown with the elixir switch off") end
	end)
end

for _, client in ipairs({ "camelot", "vanilla" }) do
	local scenario = "elixir-pair: " .. client .. ": two that do not stack are kept as one"
	with(scenario, { flavour = client, on = { "elixir" } }, function(ns, data)
		local a, b = data.elixir[1], data.elixir[2]
		if not (a and b) then
			fail(scenario, "SKIPPED -- no two elixirs on " .. client)
			return
		end
		local A, B = "elixir" .. a[1], "elixir" .. b[1]
		ns.db.profile.ownBuffs.elixirKeep[A] = true
		ns.db.profile.ownBuffs.elixirKeep[B] = true
		stock(ns, { [a[1]] = 1, [b[1]] = 1 })
		wearing(ns, { [b[3]] = 1500 })
		if offers(ns, "elixir") ~= A then
			fail(scenario, "SKIPPED -- the second on, the first not offered: " .. offers(ns, "elixir"))
			return
		end
		-- A is drunk and B's aura goes with it, twenty-five minutes early.
		wearing(ns, { [a[3]] = 1500 })
		if offers(ns, "elixir") ~= "none" then
			fail(scenario, "the first knocked the second off, and the second is still asked for: " .. offers(ns, "elixir"))
		end
		local clash = ns.db.char.elixirClash
		if not (type(clash) == "table" and clash[A] == B and clash[B] == A) then
			fail(scenario, "the pair is not remembered as not stacking")
		end
		local line = "do not stack: Manners now keeps whichever of the two is on you."
		if said(line) ~= 1 then fail(scenario, "the line is said " .. said(line) .. " times, not once") end
		wearing(ns, { [b[3]] = 1500 })
		if offers(ns, "elixir") ~= "none" then fail(scenario, "the second on alone, and offered " .. offers(ns, "elixir")) end
		wearing(ns, { [a[3]] = 1500 })
		if said(line) ~= 1 then fail(scenario, "the line is said again: " .. said(line) .. " times") end
		-- One that runs out on its own is no clash.
		ns.db.char.elixirClash = nil
		wearing(ns, {})
		offers(ns, "elixir")
		Mock.advance(10)
		stock(ns, { [a[1]] = 1, [b[1]] = 1 })
		wearing(ns, { [b[3]] = 30 })
		if offers(ns, "elixir") ~= A then
			fail(scenario, "SKIPPED -- the second on with half a minute left, the first not offered: " .. offers(ns, "elixir"))
		end
		wearing(ns, { [a[3]] = 1500 })
		offers(ns, "elixir")
		if type(ns.db.char.elixirClash) == "table" and ns.db.char.elixirClash[A] then
			fail(scenario, "an elixir with half a minute left going as another came on was taken for a clash")
		end
	end)
end

for _, client in ipairs({ "camelot", "vanilla" }) do
	local scenario = "elixir-pair: " .. client .. ": one the game turns away is passed over"
	with(scenario, { flavour = client, on = { "elixir" } }, function(ns, data)
		local a, b = data.elixir[1], data.elixir[2]
		if not (a and b) then
			fail(scenario, "SKIPPED -- no two elixirs on " .. client)
			return
		end
		local A, B = "elixir" .. a[1], "elixir" .. b[1]
		ns.db.profile.ownBuffs.elixirKeep[A] = true
		ns.db.profile.ownBuffs.elixirKeep[B] = true
		stock(ns, { [a[1]] = 1, [b[1]] = 1 })
		wearing(ns, {})
		if offers(ns, "elixir") ~= A then
			fail(scenario, "SKIPPED -- nothing on, the first not offered: " .. offers(ns, "elixir"))
			return
		end
		-- "A more powerful spell is already active", on the press of A on you.
		ns.NoteRefusal(ns.UnitFullName("player"), BOUNCED, nil, nil, A)
		if offers(ns, "elixir") ~= B then
			fail(scenario, "the game turned the first away, and offered " .. offers(ns, "elixir") .. ", not the second")
		end
	end)
end

-- ------------------------------------------------------------------ carried over

for _, client in ipairs({ "tbc", "mists" }) do
	local scenario = "elixir-pair: " .. client .. ": the one switch carries over into the two"
	with(scenario, { flavour = client }, function(ns, data)
		local own = ns.db.profile.ownBuffs
		local guardian = firstOf(data, "guardian")
		local G = "elixir" .. guardian[1]
		-- On, before the split: Guardian Elixir on too, once.
		own.elixirsSplit = nil
		own.pick.elixir = "auto"
		own.pick.guardianelixir = "off"
		ns.ClampSettings()
		if own.pick.guardianelixir ~= "auto" or own.elixirsSplit ~= true then
			fail(scenario, ("Elixir on: Guardian Elixir is %s, stamp %s"):format(tostring(own.pick.guardianelixir), tostring(own.elixirsSplit)))
		end
		-- After it, each switch is its own.
		own.pick.guardianelixir = "off"
		ns.ClampSettings()
		if own.pick.guardianelixir ~= "off" or own.pick.elixir ~= "auto" then
			fail(scenario, "a second repair carried it over again: " .. tostring(own.pick.guardianelixir))
		end
		-- Off stays off.
		own.elixirsSplit = nil
		own.pick.elixir = "off"
		own.pick.guardianelixir = "auto"
		ns.ClampSettings()
		if own.pick.guardianelixir ~= "off" then fail(scenario, "Elixir off: Guardian Elixir is " .. tostring(own.pick.guardianelixir)) end
		-- A guardian elixir picked moves to its family.
		own.elixirsSplit = nil
		own.pick.elixir = G
		ns.ClampSettings()
		if own.pick.guardianelixir ~= G or own.pick.elixir ~= "auto" then
			fail(scenario, ("a guardian elixir picked: Battle %s, Guardian %s"):format(tostring(own.pick.elixir), tostring(own.pick.guardianelixir)))
		end
		-- The memory of one up last moves too.
		ns.db.char.ownLast = { elixir = G }
		ns.ClampSettings()
		local last = ns.db.char.ownLast
		if last.elixir ~= nil or last.guardianelixir ~= G then
			fail(scenario, ("the memory: elixir %s, guardianelixir %s"):format(tostring(last.elixir), tostring(last.guardianelixir)))
		end
		-- A string pasted from before the split carries it over; one from after keeps both.
		own.pick.elixir = "auto"
		own.pick.guardianelixir = "off"
		own.elixirsSplit = true
		local after = ns.ExportSettings()
		own.elixirsSplit = nil
		local before = ns.ExportSettings()
		own.elixirsSplit = true
		ns.ImportSettings(after)
		if own.pick.guardianelixir ~= "off" then
			fail(scenario, "a string made after the split turned Guardian Elixir on: " .. tostring(own.pick.guardianelixir))
		end
		ns.ImportSettings(before)
		if own.pick.guardianelixir ~= "auto" then
			fail(scenario, "a string made before the split left Guardian Elixir " .. tostring(own.pick.guardianelixir))
		end
		-- Nothing to keep up there: each slot has its switch.
		own.elixirKeep[G] = true
		ns.ClampSettings()
		if next(own.elixirKeep) ~= nil then fail(scenario, "a tick under Elixirs to keep up kept on " .. client) end
	end)
end

do
	local scenario = "elixir-pair: vanilla: one family, nothing carried, the ticks repaired and shared"
	with(scenario, { flavour = "vanilla" }, function(ns, data)
		local own = ns.db.profile.ownBuffs
		own.elixirsSplit = nil
		own.pick.elixir = "auto"
		ns.ClampSettings()
		if own.elixirsSplit ~= nil or own.pick.guardianelixir ~= nil then
			fail(scenario, ("Classic Era: stamp %s, Guardian Elixir %s"):format(tostring(own.elixirsSplit), tostring(own.pick.guardianelixir)))
		end
		local A = "elixir" .. data.elixir[1][1]
		own.elixirKeep[A] = true
		own.elixirKeep.elixir1 = true
		own.elixirKeep.flask13510 = true
		own.elixirKeep["elixir" .. data.elixir[2][1]] = "yes"
		ns.ClampSettings()
		local n = 0
		for _ in pairs(own.elixirKeep) do n = n + 1 end
		if own.elixirKeep[A] ~= true or n ~= 1 then fail(scenario, "the ticks were not repaired: " .. n .. " left") end
		local text = ns.ExportSettings()
		if not text:find("ownBuffs.elixirKeep=" .. A, 1, true) then
			fail(scenario, "the export does not carry the tick: " .. text)
			return
		end
		own.elixirKeep[A] = nil
		ns.ImportSettings(text)
		if own.elixirKeep[A] ~= true then fail(scenario, "importing the string did not bring the tick back") end
	end)
end
