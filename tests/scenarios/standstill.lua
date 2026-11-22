-- Nothing of your own on the run (1.11.30). A player on CurseForge: Manners
-- tries to eat buff food and use a sharpening stone or a wizard oil while he
-- moves, and the food is simply thrown away, a stone or an oil cut short. A
-- family flagged `still` (Buffs.lua: food, the sleeping bag, a weapon's stone,
-- oil, poison or lure, Forever's mage scrolls, making a warlock's stone), and
-- any other whose use the client gives a cast time (a companion pet from the
-- bags, Mists' armors, a rogue's poison spells), is not offered while you move,
-- jump or fall, nor for a second after (Core.lua, Moving and NeedsStill,
-- OwnVerdict's "moving"). The client's own speed rules when it says it plainly;
-- a speed it keeps secret is read from PLAYER_STARTED_MOVING and
-- PLAYER_STOPPED_MOVING. A flask, an elixir or a stat scroll is instant and is
-- never held. The prompt's hold and fuse (Prompt/Hold.lua), the consumables
-- button's press (Prompt/Supplies.lua) and the moving event let go of the item
-- at once, not at the next scan.
--
-- Moving() answers once for each GetTime(), so a scenario that changes the
-- speed and then looks at once lets the clock tick first (Mock.advance).
--
-- Every scenario name starts with "standstill:" so the mutations in
-- tests/mutations/standstill.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local FED_NAME, MEAL_NAME = "Well Fed", "Nutritious Food"

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end
local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- Every key of your own the queue offers, by kind of family.
local function offered(ns)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and entry.buff and entry.buff.family then
			local family = entry.buff.family
			out[#out + 1] = family.enhance and "enhance" or family.consumable and "consumable" or family.key
		end
	end
	return table.concat(out, ",")
end

-- The world a scenario stands in: bags (item -> count), the player's auras by
-- name, his level, his speed (a number, or Mock.SECRET), whether he falls,
-- and the cast time the client gives every spell (nil: the mock's own).
local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell",
	"IsResting", "GetUnitSpeed", "IsFalling", "GetInventoryItemID", "StaticPopup_Hide" }

-- Weapons by made-up item id, as hunt33-weapons.lua has them.
local DAGGER = 900015
local ROUGH_STONE = 2862

local function install(ns)
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id)
			if id == world.fed then return FED_NAME end
			if world.meals[id] then return MEAL_NAME end
			return spells.GetSpellName(id)
		end,
		GetSpellInfo = function(id)
			if world.castTime ~= nil then return { name = "x", castTime = world.castTime } end
			return spells.GetSpellInfo(id)
		end,
	}, { __index = spells }))
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Food " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id)
			if id == DAGGER then return id, "Weapon", "", "INVTYPE_WEAPON", 7100000 + id, 2, 15 end
			return id, "Consumable", "", "", 7100000 + id, 0, 5
		end,
	})
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" and slot == 16 then return DAGGER end
		return nil
	end)
	rawset(_G, "StaticPopup_Hide", function() end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "GetUnitSpeed", function() return world.speed end)
	rawset(_G, "IsFalling", function() return world.falling end)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataBySpellName = function(unit, name)
			if unit ~= "player" then return nil end
			local expires = world.auras[name]
			if expires == nil then return nil end
			return { name = name, expirationTime = expires, sourceUnit = "player" }
		end,
		GetUnitAuraBySpellID = function() return nil end,
	}, { __index = base }))
end

-- One session as `opts.class` (a warrior) on `opts.flavour` (Forever), standing
-- still, with opts.bags and opts.on (food switched on). The moving state of
-- another scenario is let go of, and so is every cast time this one caches.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, level = 60, auras = {}, meals = {}, fed = nil, speed = 0, falling = false,
		castTime = nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ns
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		local data = ns.FOODS[opts.flavour or "camelot"]
		if data then
			world.fed = data.fed
			for _, row in ipairs(data) do world.meals[row[3]] = true end
		end
		install(ns)
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		ns.NoteMoving(GetTime(), false)
		Mock.advance(2)
		if opts.on ~= false then
			ns.db.profile.ownBuffs.pick.food = "auto"
			ns.ForgetScrolls()
		end
		body(ns, data)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	-- A cast time cached from a stub must not leak into another file.
	if ns and ns.ForgetCastTimes then ns.ForgetCastTimes() end
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

-- Food in the bags, standing, painted on the prompt.
local function fed(scenario, body)
	with(scenario, {}, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		ns.addon:Tick()
		local shown = ns.Prompt:Showing()
		if key(shown) ~= "food" .. data[1][1] then
			fail(scenario, "SKIPPED -- the food was not on the prompt to begin with: " .. key(shown))
			return
		end
		body(ns, data)
	end)
end

-- ------------------------------------------------------------------ food

do
	local scenario = "standstill: food waits while you move and comes back once you stand still"
	with(scenario, {}, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- food in the bags, standing still, and nothing offered")
			return
		end
		world.speed = 7
		Mock.advance(0.5)
		if mine(ns) then fail(scenario, "moving, and offered " .. key(mine(ns))) end
		local said = lines(ns)
		if not said:find("waits until you stand still", 1, true) then
			fail(scenario, "the Myself lines do not say why: " .. said)
		end
		-- Stopped: the second past the last step still holds it.
		world.speed = 0
		Mock.advance(0.5)
		if mine(ns) then fail(scenario, "stopped half a second ago, and offered " .. key(mine(ns))) end
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "standing still for a second and a half, and the food is not back") end
	end)
end

do
	local scenario = "standstill: a speed the client keeps secret is read from the moving events"
	with(scenario, {}, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- food in the bags, standing still, and nothing offered")
			return
		end
		world.speed = Mock.SECRET
		-- Secret and no word of moving: standing, as the game has told us.
		Mock.advance(1.5)
		if not mine(ns) then fail(scenario, "a secret speed and no moving event hid the food") end
		ns.addon:PLAYER_STARTED_MOVING()
		-- Past the hold, so only the events keep it back.
		Mock.advance(1.5)
		if mine(ns) then fail(scenario, "a secret speed and a start of moving, and offered " .. key(mine(ns))) end
		ns.addon:PLAYER_STOPPED_MOVING()
		Mock.advance(1.5)
		if not mine(ns) then fail(scenario, "stopped, and the food is not back") end
	end)
	-- The game raises on a boolean test of a secret and the mock's secret is a
	-- plain truthy table, so nothing above can see one: the source is read
	-- instead. Whatever GetUnitSpeed answers is never the operand of `and` or
	-- `or` in Moving; issecretvalue and type() look at it first.
	local source = assert(io.open(dir .. "/Core.lua", "r")):read("*a")
	local body = source:match("\n\tlocal function Moving%(now%)(.-)\n\tend\n")
	if not body then
		fail(scenario, "SKIPPED -- Moving could not be found in Core.lua")
	elseif body:find('speedOf%("player"%)%s+or') or body:find('and%s+speedOf%("player"%)') then
		fail(scenario, "Moving tests the speed for truth before asking issecretvalue: the game raises on a secret")
	end
end

do
	local scenario = "standstill: a jump counts as moving"
	with(scenario, {}, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- food in the bags, standing still, and nothing offered")
			return
		end
		world.falling = true
		Mock.advance(0.5)
		if mine(ns) then fail(scenario, "falling, and offered " .. key(mine(ns))) end
		world.falling = false
		Mock.advance(2)
		if not mine(ns) then fail(scenario, "landed two seconds ago, and the food is not back") end
	end)
end

do
	local scenario = "standstill: a plain standing speed beats a stale moving event"
	with(scenario, {}, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		-- A start the client never followed with a stop.
		ns.addon:PLAYER_STARTED_MOVING()
		world.speed = 0
		Mock.advance(1.5)
		if not mine(ns) then
			fail(scenario, "a plain speed of nothing, and a start of moving never stopped, holds the food")
		end
	end)
end

-- ------------------------------------------------------------------ the press

do
	local scenario = "standstill: a press made on the move eats nothing"
	fed(scenario, function(ns, data)
		world.speed = 7
		Mock.advance(0.05)
		local ran = H.pressButton(ns)
		if ran and tostring(ran):find("/use item:", 1, true) then
			fail(scenario, "pressed on the move, and the button ran " .. tostring(ran))
		end
	end)
end

do
	local scenario = "standstill: the hold lets go of food on the move"
	fed(scenario, function(ns, data)
		local held = ns.Prompt.state.heldEntry
		if key(held) ~= "food" .. data[1][1] then
			fail(scenario, "SKIPPED -- the prompt holds " .. key(held) .. ", not the food")
			return
		end
		world.speed = 7
		Mock.advance(0.05)
		local other = { name = "Anna", priority = 5, buff = ns.FindBuff and ns.FindBuff("WARRIOR", "battleshout")
			or { key = "other" }, ranged = true }
		local pick = ns.Prompt:PickTop({ other }, other)
		if pick ~= other then
			fail(scenario, "the food kept the prompt while its owner moved: " .. tostring(pick and pick.name))
		end
	end)
end

do
	local scenario = "standstill: starting to move takes the food off the prompt at once"
	fed(scenario, function(ns, data)
		world.speed = 7
		ns.addon:PLAYER_STARTED_MOVING()
		local text = macro(ns)
		if text and tostring(text):find("/use item:", 1, true) then
			fail(scenario, "the prompt still carries " .. tostring(text) .. " after the move began")
		end
		if ns.Prompt:Showing() and key(ns.Prompt:Showing()) == "food" .. data[1][1] then
			fail(scenario, "the prompt still shows the food after the move began")
		end
	end)
end

do
	local scenario = "standstill: the consumables button uses nothing on the move"
	with(scenario, {}, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		ns.db.profile.ownBuffs.apart = true
		Mock.advance(1)
		ns.addon:Tick()
		local b = ns.Supplies:Button()
		if not (b and b:GetAttribute("macrotext1")) then
			fail(scenario, "SKIPPED -- the consumables button was not armed to begin with")
			return
		end
		world.speed = 7
		Mock.advance(0.05)
		b.scripts.PreClick(b, "LeftButton", true)
		local text = b:GetAttribute("macrotext1")
		if text ~= nil then fail(scenario, "pressed on the move, and the button carries " .. tostring(text)) end
	end)
end

-- ------------------------------------------------------------------ a stone

do
	local scenario = "standstill: a weapon stone waits on the move, a flask does not"
	with(scenario, {}, function(ns)
		-- The lowest flask of the warrior's family, switched on.
		local flask
		for _, family in ipairs(ns.OWN_BUFFS.WARRIOR or {}) do
			if family.key == "flask" then flask = family end
		end
		if not flask then
			fail(scenario, "SKIPPED -- a warrior has no flask family on this client")
			return
		end
		local low = flask.spells[1]
		for _, spell in ipairs(flask.spells) do
			if spell.level < low.level then low = spell end
		end
		ns.db.profile.ownBuffs.pick.flask = "auto"
		ns.db.profile.sources.self = true
		ns.db.profile.ownBuffs.inCities = true
		-- One of your own is offered at a time, so each is tried alone.
		stock(ns, { [ROUGH_STONE] = 2 })
		Mock.advance(1)
		local standing = offered(ns)
		if standing ~= "enhance" then
			fail(scenario, "SKIPPED -- standing still, the stone is not offered: " .. standing .. " // " .. lines(ns))
			return
		end
		world.speed = 7
		Mock.advance(0.5)
		local moving = offered(ns)
		if moving ~= "" then fail(scenario, "moving, and a stone is offered: " .. moving) end
		world.speed = 0
		Mock.advance(2)
		stock(ns, { [low.item] = 2 })
		Mock.advance(1)
		standing = offered(ns)
		if standing ~= "consumable" then
			fail(scenario, "SKIPPED -- standing still, the flask is not offered: " .. standing .. " // " .. lines(ns))
			return
		end
		world.speed = 7
		Mock.advance(0.5)
		moving = offered(ns)
		if moving ~= "consumable" then fail(scenario, "moving, and a flask is held back: " .. moving) end
	end)
end

-- ------------------------------------------------------------------ the families

do
	local scenario = "standstill: which families wait for you to stand still, on every client"
	for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		with(scenario, { flavour = client, on = false }, function(ns)
			world.speed = 7
			Mock.advance(0.5)
			local needs = 0
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				for _, family in ipairs(families) do
					local must = family.food or family.rest or family.enhance or family.key == "familiar"
						or family.key == "makestone" or family.key == "makehealthstone" or (family.key == "imbue" and family.scroll)
					if must then
						needs = needs + 1
						if family.still ~= true then
							fail(scenario, ("%s %s: %s is not flagged still"):format(client, class, family.key))
						end
					end
					if family.consumable then
						if family.still then fail(scenario, ("%s %s: %s is flagged still"):format(client, class, family.key)) end
						world.castTime = 0
						ns.ForgetCastTimes()
						if family.spells[1] and ns.StillCut({ buff = family.spells[1] }, GetTime()) then
							fail(scenario, ("%s %s: an instant %s is held on the move"):format(client, class, family.key))
						end
					end
					if family.pet and family.spells[1] and client ~= "mists" and client ~= "mainline" then
						world.castTime = 1000
						ns.ForgetCastTimes()
						if not ns.StillCut({ buff = family.spells[1] }, GetTime()) then
							fail(scenario, ("%s %s: a pet with a cast of a second is not held on the move"):format(client, class))
						end
						world.castTime = 0
						ns.ForgetCastTimes()
						if ns.StillCut({ buff = family.spells[1] }, GetTime()) then
							fail(scenario, ("%s %s: an instant pet is held on the move"):format(client, class))
						end
					end
				end
			end
			if needs == 0 and client ~= "mainline" then fail(scenario, client .. ": no family was found to check") end
			-- Standing, nothing is held whatever the family.
			world.speed = 0
			world.castTime = 1000
			ns.ForgetCastTimes()
			Mock.advance(2)
			for _, families in pairs(ns.OWN_BUFFS or {}) do
				for _, family in ipairs(families) do
					if family.spells[1] and ns.StillCut({ buff = family.spells[1] }, GetTime()) then
						fail(scenario, client .. ": " .. family.key .. " is held with nobody moving")
						return
					end
				end
			end
		end)
	end
end
