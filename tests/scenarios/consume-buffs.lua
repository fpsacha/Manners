-- Flasks, elixirs and stat scrolls (1.11.11): switches like Well Fed's, one
-- per kind, for every class on the four clients with a table of them
-- (Consumables.lua, written by tools/make_consumables.py from each client's own
-- data: Forever's own flasks and elixirs beside the classic ones, Season of
-- Discovery's on Classic Era, Burning Crusade's, Mists'). Off until switched
-- on; offered when none of the family's auras is on you and one is in the bags,
-- the best first; read by the auras' ids. A flask fills both elixir slots on
-- Burning Crusade and Mists; scrolls are a family per stat, used on you by name,
-- under a class buff of the same stat never, and still the blockers they were.
--
-- Every scenario name starts with "consume-buffs:" so the mutations in
-- tests/mutations/consume-buffs.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local CLIENTS = { "camelot", "vanilla", "tbc", "mists" }
local SCROLLS = { "agility", "strength", "protection", "intellect", "stamina", "spirit" }
local BAR_LINE = "/click MannersBar"

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end
local function flat(t) return (tostring(t):gsub("\n", " / ")) end

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

local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- The world a scenario stands in: bags (item -> count), the player's auras by
-- id (id -> expiry), his level, whether he is mounted, where he stands, and
-- which items were counted.
local world
local TOUCHED = { "C_Item", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell", "IsResting",
	"IsInInstance" }

local function install()
	rawset(_G, "C_Item", {
		GetItemCount = function(id)
			world.counted[id] = (world.counted[id] or 0) + 1
			return world.bags[id] or 0
		end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 2 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "IsMounted", function() return world.mounted end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "IsSpellKnown", function() return false end)
	rawset(_G, "IsPlayerSpell", function() return false end)
	rawset(_G, "IsInInstance", function()
		if world.where then return true, world.where end
		return false, "none"
	end)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			if world.refuse then return Mock.SECRET end
			if world.throws == id then error("aura read refused for " .. id) end
			local expires = world.auras[id]
			if expires == nil then return nil end
			-- Whoever's: a scroll somebody else used on you counts the same.
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 3600,
				sourceUnit = world.from or "player" }
		end,
		GetAuraDataBySpellName = function() return nil end,
	}, { __index = base }))
end

-- One session as a warrior on `opts.flavour` (Forever), with opts.bags,
-- opts.level (the level cap of that client's content) and opts.on (the family
-- keys switched on).
local LEVEL = { camelot = 60, vanilla = 60, tbc = 70, mists = 90, mainline = 90 }
local function with(scenario, opts, body)
	local flavour = opts.flavour or "camelot"
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, level = opts.level or LEVEL[flavour], auras = {}, counted = {},
		mounted = false, refuse = false, where = nil, from = nil }
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
	Mock.secretAuraIds = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function stock(ns, bags)
	world.bags = bags
	ns.addon:BAG_UPDATE_DELAYED()
end

local function wear(ns, id)
	world.auras[id] = GetTime() + 1500
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
	Mock.advance(1)
end

local function has(rows, item)
	for _, row in ipairs(rows or {}) do
		if row[1] == item then return true end
	end
	return false
end

-- ------------------------------------------------------------------ the data

do
	local scenario = "consume-buffs: every client's table is whole and in order"
	with(scenario, {}, function(ns)
		local floor = {
			camelot = { flask = 8, elixir = 50, scroll = 4 },
			vanilla = { flask = 10, elixir = 25, scroll = 4 },
			tbc = { flask = 20, elixir = 40, scroll = 5 },
			mists = { flask = 40, elixir = 75, scroll = 9 },
		}
		-- Shattrath's flasks (Tempest Keep to the Sunwell only) and Season of
		-- Discovery's nightmare flasks work in their areas only: after the rest.
		local AREA = { [32898] = true, [32899] = true, [32900] = true, [32901] = true, [35716] = true,
			[35717] = true, [221024] = true, [222952] = true }
		local function inOrder(where, rows, minimum)
			if type(rows) ~= "table" or #rows < minimum then
				fail(scenario, ("%s has %s rows, fewer than the %d its data gives"):format(where, tostring(rows and #rows), minimum))
				return
			end
			local seen, last, area = {}, nil, false
			for i, row in ipairs(rows) do
				local item, level, use = row[1], row[2], row[3]
				if type(item) ~= "number" or type(level) ~= "number" or type(use) ~= "number" then
					fail(scenario, ("%s row %d is not { item, level, spell }"):format(where, i))
					return
				end
				if seen[item] then fail(scenario, ("%s lists item %d twice"):format(where, item)) end
				seen[item] = true
				if AREA[item] then
					area = true
				elseif area then
					fail(scenario, ("%s row %d (%d) is a flask for every place, after one for an area"):format(where, i, item))
					return
				end
				if not AREA[item] and last and level > last[2] then
					fail(scenario, ("%s row %d (%d, level %d) is above %d, level %d"):format(where, i, item, level, last[1], last[2]))
					return
				end
				if not AREA[item] then last = row end
			end
		end
		for client, minimum in pairs(floor) do
			local data = ns.CONSUMABLES[client]
			if type(data) ~= "table" then
				fail(scenario, client .. " has no table")
			else
				inOrder(client .. ".flask", data.flask, minimum.flask)
				inOrder(client .. ".elixir", data.elixir, minimum.elixir)
				for _, stat in ipairs(SCROLLS) do
					inOrder(client .. ".scroll." .. stat, data.scroll and data.scroll[stat], minimum.scroll)
				end
				local fills = client == "tbc" or client == "mists"
				if (data.flaskFills == true) ~= fills then
					fail(scenario, client .. ": flaskFills is " .. tostring(data.flaskFills))
				end
			end
		end
		-- Retail's flasks alone since the missing-buffs round (missing-buffs.lua).
		local retail = ns.CONSUMABLES.mainline
		if not (retail and retail.flask and retail.flask[1]) or retail.elixir or retail.scroll then
			fail(scenario, "retail's table is not its flasks alone")
		end
		local data = ns.CONSUMABLES
		-- Forever's four of its own and the four classic flasks; Season of
		-- Discovery's on Classic Era; Forever's own elixirs from level 1.
		for _, item in ipairs({ 274273, 274274, 274275, 274276, 13510, 13511, 13512, 13513 }) do
			if not has(data.camelot.flask, item) then fail(scenario, "Forever's flasks lack " .. item) end
		end
		for _, item in ipairs({ 233962, 233964, 233965, 233966, 13510 }) do
			if not has(data.vanilla.flask, item) then fail(scenario, "Classic Era's flasks lack " .. item) end
		end
		for _, item in ipairs({ 247754, 247755, 250328, 13452 }) do
			if not has(data.camelot.elixir, item) then fail(scenario, "Forever's elixirs lack " .. item) end
		end
		-- No water breathing, nor a flask among the elixirs.
		if has(data.vanilla.elixir, 5996) or has(data.vanilla.elixir, 13510) then
			fail(scenario, "Classic Era's elixirs hold Water Breathing or a flask")
		end
		-- Mists' IX before its VIII, both level 80: the stronger first.
		if data.mists.scroll.agility[1][1] ~= 63303 then
			fail(scenario, "Mists' best Scroll of Agility is " .. tostring(data.mists.scroll.agility[1][1]) .. ", not IX (63303)")
		end
	end)
end

do
	local scenario = "consume-buffs: every class has the families, retail none"
	for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local total, whole = 0, 0
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				total = total + 1
				local keys = {}
				for _, family in ipairs(families) do
					if family.consumable then
						keys[family.key] = family
						if not (family.bagged and family.toggle) then
							fail(scenario, client .. " " .. class .. ": " .. family.key .. " is not a bagged toggle")
						end
					end
				end
				local want = { "flask", "elixir" }
				for _, stat in ipairs(SCROLLS) do want[#want + 1] = "scroll" .. stat end
				local all = true
				for _, k in ipairs(want) do all = all and keys[k] ~= nil end
				if all then whole = whole + 1 end
				-- A scroll is cast at a friendly target and its aura is a favour
				-- from anybody else; a flask or an elixir is neither.
				for k, family in pairs(keys) do
					local scroll = k:sub(1, 6) == "scroll"
					for _, spell in ipairs(family.spells) do
						if (spell.onAlly == true) ~= scroll or (spell.castOnOthers == true) ~= scroll then
							fail(scenario, client .. " " .. k .. ": " .. spell.key .. " is aimed wrong")
							break
						end
					end
				end
				local elixir = keys.elixir
				local fills = client == "tbc" or client == "mists"
				if elixir and (elixir.covers ~= nil) ~= fills then
					fail(scenario, client .. ": the elixir family's covers are " .. tostring(elixir.covers))
				end
			end
			if client == "mainline" then
				if whole ~= 0 then fail(scenario, "retail's classes have the consumable families") end
			elseif whole ~= total or total == 0 then
				fail(scenario, ("%s: %d of %d classes have every consumable family"):format(client, whole, total))
			end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ the switch

do
	local scenario = "consume-buffs: off by default, the bags unread, and a switch shown with one"
	with(scenario, {}, function(ns, data)
		local flask = data.flask[1][1]
		for _, k in ipairs({ "flask", "elixir", "scrollagility", "scrollspirit" }) do
			if ns.db.profile.ownBuffs.pick[k] ~= "off" then
				fail(scenario, k .. " is " .. tostring(ns.db.profile.ownBuffs.pick[k]) .. " on a new profile, not off")
			end
		end
		stock(ns, { [flask] = 1 })
		if mine(ns) then fail(scenario, "a flask in the bags with the switch off: offered " .. key(mine(ns))) end
		if world.counted[flask] then fail(scenario, "the bags were counted for a flask with the switch off") end
		local control = findOption(ns.optionsTable, "own_flask")
		if not control then
			fail(scenario, "Who to buff has no flask switch for a warrior")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.hidden and control.hidden() then fail(scenario, "the switch is hidden with a flask in the bags") end
		world.bags = {}
		if not (control.hidden and control.hidden()) then fail(scenario, "the switch is shown with no flask and it off") end
		local desc = type(control.desc) == "function" and control.desc() or control.desc
		if type(desc) ~= "string" or not desc:find("flask", 1, true) then
			fail(scenario, "the switch says " .. tostring(desc))
		end
		world.bags = { [flask] = 1 }
		control.set({ "own_flask" }, true)
		if ns.db.profile.ownBuffs.pick.flask ~= "auto" or control.get() ~= true then
			fail(scenario, "switching it on wrote " .. tostring(ns.db.profile.ownBuffs.pick.flask))
		end
		world.bags = {}
		if control.hidden and control.hidden() then fail(scenario, "switched on, the switch hides when the flasks are gone") end
		world.bags = { [flask] = 1 }
		if key(mine(ns)) ~= "flask" .. flask then fail(scenario, "switched on, with a flask in the bags: offered " .. key(mine(ns))) end
		control.set({ "own_flask" }, false)
		if ns.db.profile.ownBuffs.pick.flask ~= "off" then
			fail(scenario, "switching it off wrote " .. tostring(ns.db.profile.ownBuffs.pick.flask))
		end
		-- Each scroll's switch is its own.
		local scroll = data.scroll.agility[1][1]
		world.bags = { [scroll] = 1 }
		local agility, spirit = findOption(ns.optionsTable, "own_scrollagility"), findOption(ns.optionsTable, "own_scrollspirit")
		if not (agility and spirit) or agility.hidden() or not spirit.hidden() then
			fail(scenario, "with a Scroll of Agility in the bags, its switch and Spirit's are not shown and hidden")
		end
	end)
end

do
	-- Retail's flasks have theirs since the missing-buffs round (missing-buffs.lua):
	-- no elixir or scroll.
	local scenario = "consume-buffs: no switch on retail"
	with(scenario, { flavour = "mainline" }, function(ns)
		for _, k in ipairs({ "own_elixir", "own_scrollagility" }) do
			if ns.optionsTable.args.who.args[k] then fail(scenario, "retail has " .. k) end
		end
	end)
end

-- ------------------------------------------------------------------ the offer

do
	local scenario = "consume-buffs: a flask in the bags and none on is offered, used by its item"
	with(scenario, { on = { "flask" } }, function(ns, data)
		local best = data.flask[1]
		stock(ns, { [best[1]] = 2 })
		local entry = mine(ns)
		if key(entry) ~= "flask" .. best[1] then
			fail(scenario, "a flask in the bags, none on, the switch on: offered " .. key(entry))
			return
		end
		ns.Prompt:Refresh()
		if macro(ns) ~= "/use item:" .. best[1] then
			fail(scenario, "the macro is " .. flat(macro(ns)) .. ", not /use item:" .. best[1])
		end
		if ns.BuffName(entry.buff) ~= "Item " .. best[1] then
			fail(scenario, "the flask is named " .. tostring(ns.BuffName(entry.buff)))
		end
	end)
end

do
	local scenario = "consume-buffs: a flask up, or a refused read, is not offered"
	with(scenario, { on = { "flask" } }, function(ns, data)
		local best, other = data.flask[1], data.flask[#data.flask]
		stock(ns, { [best[1]] = 1 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- the flask was not offered to begin with")
			return
		end
		-- Any flask of the family on you, not only the one in the bags.
		wear(ns, other[3])
		if mine(ns) then fail(scenario, "another flask on you, and still offered " .. key(mine(ns))) end
		world.auras[other[3]] = nil
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "the flask gone, and nothing is offered again") end
		world.refuse = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "the aura read refused, and offered " .. key(mine(ns))) end
		if not lines(ns):find("will not say whether it is up", 1, true) then
			fail(scenario, "a refused aura read is not said to be unread: " .. lines(ns))
		end
		-- An empty read the client says may be hiding one: no answer either.
		world.refuse = false
		Mock.secretAuraIds = { [best[3]] = true }
		Mock.advance(1)
		if mine(ns) then fail(scenario, "an aura the client keeps secret read as missing: offered " .. key(mine(ns))) end
		Mock.secretAuraIds = nil
		-- A read the client throws on: no answer, and nothing breaks.
		world.throws = other[3]
		Mock.advance(1)
		if mine(ns) then fail(scenario, "an aura read that throws taken for none: offered " .. key(mine(ns))) end
		local up = select(2, verdict(ns, ns.FindOwnFamily("flask")))
		if up ~= nil then fail(scenario, "an aura read that throws read as " .. tostring(up)) end
		world.throws = nil
	end)
end

do
	local scenario = "consume-buffs: the best elixir you can use is the one offered"
	with(scenario, { on = { "elixir" } }, function(ns, data)
		local best, worst = data.elixir[1], data.elixir[#data.elixir]
		stock(ns, { [best[1]] = 1, [worst[1]] = 1 })
		if key(mine(ns)) ~= "elixir" .. best[1] then
			fail(scenario, "with both in the bags, offered " .. key(mine(ns)) .. ", not the best, elixir" .. best[1])
		end
		world.level = best[2] - 1
		Mock.advance(1)
		if key(mine(ns)) ~= "elixir" .. worst[1] then
			fail(scenario, ("at level %d, below the best's %d, offered %s"):format(world.level, best[2], key(mine(ns))))
		end
		-- Any elixir of the family on you: none is asked for over it.
		wear(ns, worst[3])
		if mine(ns) then fail(scenario, "an elixir on you, and another offered: " .. key(mine(ns))) end
	end)
end

for _, client in ipairs(CLIENTS) do
	local fills = client == "tbc" or client == "mists"
	local scenario = fills and "consume-buffs: a flask fills both elixir slots on Burning Crusade and Mists"
		or "consume-buffs: a flask beside an elixir on Classic Era and Forever"
	with(scenario, { flavour = client, on = { "elixir" } }, function(ns, data)
		local elixir, flask = data.elixir[1], data.flask[1]
		stock(ns, { [elixir[1]] = 1 })
		if key(mine(ns)) ~= "elixir" .. elixir[1] then
			fail(scenario, client .. ": an elixir in the bags, none on: offered " .. key(mine(ns)))
			return
		end
		wear(ns, flask[3])
		local entry = mine(ns)
		if fills and entry then
			fail(scenario, client .. ": a flask on you, and an elixir offered: " .. key(entry))
		elseif not fills and key(entry) ~= "elixir" .. elixir[1] then
			-- No slots there: a flask and an elixir stack.
			fail(scenario, client .. ": a flask on you, and the elixir not offered: " .. key(entry))
		end
	end)
end

-- ------------------------------------------------------------------ the scrolls

do
	local scenario = "consume-buffs: a scroll is used on you by name, your target handed back"
	with(scenario, { on = { "scrollagility" } }, function(ns, data)
		local best = data.scroll.agility[1]
		stock(ns, { [best[1]] = 1 })
		local entry = mine(ns)
		if key(entry) ~= "scroll" .. best[1] then
			fail(scenario, "a Scroll of Agility in the bags: offered " .. key(entry))
			return
		end
		ns.Prompt:Refresh()
		local text = macro(ns) or ""
		local want = "/target " .. ns.TargetName(ns.UnitFullName("player")) .. "\n/use item:" .. best[1] .. "\n"
		if text:sub(1, #want) ~= want then
			fail(scenario, "the macro is " .. flat(text) .. ", not " .. flat(want) .. " and a hand-back")
		end
		local last = text:match("([^\n]+)$")
		if last ~= "/targetlasttarget" and last ~= "/cleartarget" then
			fail(scenario, "the macro hands nothing back: " .. flat(text))
		end
	end)
end

do
	local scenario = "consume-buffs: scrolls of two stats stack, one stat does not"
	with(scenario, { on = { "scrollagility", "scrollstrength" } }, function(ns, data)
		local agility, strength = data.scroll.agility, data.scroll.strength
		stock(ns, { [agility[1][1]] = 1, [strength[1][1]] = 1 })
		-- A lesser Agility on you, from somebody else: the family is up.
		world.from = "party1"
		wear(ns, agility[#agility][3])
		local fa, fs = ns.FindOwnFamily("scrollagility"), ns.FindOwnFamily("scrollstrength")
		local spellA, upA = verdict(ns, fa)
		local spellS = verdict(ns, fs)
		if spellA or upA ~= true then
			fail(scenario, "a Scroll of Agility on you, and the family reads " .. tostring(upA) .. ", offering " .. tostring(spellA and spellA.key))
		end
		if not (spellS and spellS.key == "scroll" .. strength[1][1]) then
			fail(scenario, "Agility on you, and Strength not offered: " .. tostring(spellS and spellS.key))
		end
	end)
end

for _, client in ipairs({ "vanilla", "camelot", "tbc" }) do
	local scenario = "consume-buffs: a Scroll of Intellect waits under Arcane Intellect"
	with(scenario, { flavour = client, on = { "scrollintellect", "scrollagility" } }, function(ns, data)
		local intellect = data.scroll.intellect[1]
		stock(ns, { [intellect[1]] = 1 })
		local family = ns.FindOwnFamily("scrollintellect")
		if not (verdict(ns, family)) then
			fail(scenario, client .. ": a Scroll of Intellect in the bags, nothing on, and nothing offered")
			return
		end
		-- The mage's buff of the same stat at its best rank, worth more than a
		-- scroll: the game would turn the scroll away, so none is asked for. (A
		-- rank worth less than the weakest scroll holds none back:
		-- newbuffs-fixes.lua.)
		local ai = ns.FindBuff("MAGE", "intellect")
		world.from = "party1"
		wear(ns, ai.ranks[1])
		local spell, up = verdict(ns, family)
		if spell or up ~= true then
			fail(scenario, client .. ": Arcane Intellect on you, and a Scroll of Intellect offered: " .. tostring(spell and spell.key))
		end
		-- No buff of a stat covers another's scroll.
		if #ns.ConsumableAuras(ns.FindOwnFamily("scrollagility")) ~= #data.scroll.agility then
			fail(scenario, client .. ": a Scroll of Agility is covered by something else")
		end
	end)
end

for _, client in ipairs({ "vanilla", "camelot", "tbc" }) do
	local scenario = "consume-buffs: a scroll stays a blocker and another's is their favour"
	with(scenario, { flavour = client }, function(ns)
		local ai = ns.FindBuff("MAGE", "intellect")
		local top = ns.CONSUMABLES[client].scroll.intellect[1][3]
		local listed = false
		for _, id in ipairs(ai.blockerIds or {}) do listed = listed or id == top end
		if not listed then fail(scenario, client .. ": the best Scroll of Intellect is no longer Arcane Intellect's blocker") end
		if ns.IsOwnAura(top) then
			fail(scenario, client .. ": a Scroll of Intellect somebody used on you is read as your own aura, nobody's favour")
		end
		-- A flask or an elixir only you can put on yourself.
		if not ns.IsOwnAura(ns.CONSUMABLES[client].flask[1][3]) then
			fail(scenario, client .. ": a flask on you is taken for somebody's favour")
		end
	end)
end

-- ------------------------------------------------------------------ held back

do
	local scenario = "consume-buffs: mounted, nothing is offered, and debug says why"
	with(scenario, { on = { "flask", "elixir", "scrollstamina" } }, function(ns, data)
		stock(ns, { [data.flask[1][1]] = 1 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- the flask was not offered to begin with")
			return
		end
		world.mounted = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "mounted, and offered " .. key(mine(ns))) end
		if not lines(ns):find("waits until you dismount", 1, true) then
			fail(scenario, "mounted, /manners debug does not say the flask waits: " .. lines(ns))
		end
		world.mounted = false
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "dismounted, and nothing offered") end
	end)
end

do
	local scenario = "consume-buffs: held to dungeons and raids with the switch"
	with(scenario, { on = { "flask", "scrollagility" } }, function(ns, data)
		stock(ns, { [data.flask[1][1]] = 1, [data.scroll.agility[1][1]] = 1 })
		ns.db.profile.ownBuffs.itemsInDungeons = true
		for _, k in ipairs({ "flask", "elixir", "scrollagility" }) do
			local family = ns.FindOwnFamily(k)
			if not ns.OwnItemsHeldToDungeons(family) then fail(scenario, k .. " is not held to dungeons") end
		end
		if ns.OwnItemsHeldToDungeons(ns.FindOwnFamily("rested")) then
			fail(scenario, "the sleeping bag is held to dungeons")
		end
		local _, _, _, why = verdict(ns, ns.FindOwnFamily("flask"))
		if why ~= "dungeon" then fail(scenario, "a flask out in the world with the switch on: " .. tostring(why)) end
		if not lines(ns):find("only offered in a dungeon or a raid", 1, true) then
			fail(scenario, "the debug lines do not say it: " .. lines(ns))
		end
		world.where = "raid"
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "in a raid with the switch on, nothing offered") end
		local control = findOption(ns.optionsTable, "ownDungeons")
		local said = control and (control.name .. " " .. control.desc) or ""
		if not (said:find("flask", 1, true) and said:find("scroll", 1, true)) then
			fail(scenario, "the switch does not say it holds flasks and scrolls: " .. said)
		end
	end)
end

-- ------------------------------------------------------------------ the bar macro

do
	-- The bar's copy of a scroll used on you is Manners' own shape: at the next
	-- login it is put back to the bar line, never kept as the player's.
	local scenario = "consume-buffs: the bar macro keeps a scroll used on you as its own"
	Mock.reset()
	Mock.setFlavour("camelot")
	local restore = strangers({})
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			local me = ns.TargetName(ns.UnitFullName("player"))
			local body = BAR_LINE .. "\n/target " .. me .. "\n/use item:3012\n/targetlasttarget"
			Mock.macroList[1] = { name = "Manners", icon = "INV_MISC_NOTE_03", body = body }
			ns.addon:OnInitialize()
			ns.addon:OnEnable()
			Mock.runTimers(3)
			local now = Mock.macroList[1] and Mock.macroList[1].body
			if ns.BarMacroState() ~= "ours" or now ~= BAR_LINE then
				fail(scenario, ("%s is %s and holds %s, not Manners' own"):format(flat(body), tostring(ns.BarMacroState()), flat(now)))
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	restore()
	Mock.reset()
end
