-- A class's courtesies on request (Courtesy.lua): a mage's water, food and
-- portals, a warlock's healthstone and summon. Which messages ask for one,
-- what the prompt offers and what a press runs, what holds one back, and the
-- switches.
--
-- Called by scenarios.lua with the addon directory and its helpers. Chat is
-- driven through the addon's own handlers, as tests/scenarios/asked.lua does;
-- the bags, the spell book, the cursor and the trade window are stood in here
-- (`world`), since the mock has none. Every global a scenario replaces is put
-- back after it.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, pressButton = H.strangers, H.freshPrompt, H.owe, H.pressButton

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_Spell", "GetItemCount", "C_Container",
	"ClickTradeButton", "GetTradePlayerItemLink", "GetCursorInfo", "CursorHasItem", "ClearCursor",
	"AcceptTrade", "UnitGUID", "UnitLevel", "UnitInParty", "IsUsableSpell", "MAX_TRADABLE_ITEMS", "IsResting" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local function with(scenario, globals, body)
	for name, value in pairs(globals or {}) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

-- The names the client gives the spells these scenarios use.
local SPELLS = {
	[1459] = "Arcane Intellect",
	[5504] = "Conjure Water", [5505] = "Conjure Water", [5506] = "Conjure Water", [6127] = "Conjure Water",
	[10138] = "Conjure Water", [10139] = "Conjure Water", [10140] = "Conjure Water",
	[587] = "Conjure Food", [28612] = "Conjure Food",
	[11417] = "Portal: Orgrimmar", [11418] = "Portal: Undercity", [11420] = "Portal: Thunder Bluff",
	[6201] = "Create Healthstone (Minor)", [11730] = "Create Healthstone (Major)",
	[698] = "Ritual of Summoning", [42955] = "Conjure Refreshment", [29893] = "Create Soulwell",
	[5697] = "Unending Breath", [687] = "Demon Skin",
}
local RANKS = { [5504] = "Rank 1", [5505] = "Rank 2", [5506] = "Rank 3", [6127] = "Rank 4",
	[10138] = "Rank 5", [10139] = "Rank 6", [10140] = "Rank 7" }

-- A spell book, bags, a cursor and a trade window: `known` is a list of spell
-- ids, `bags` item -> count (changed by the scenario as it goes), `levels`
-- token -> level, `party` whether every token is in your party, `partner` the
-- token whose GUID the trade's other side answers with.
local function world(opts)
	local w = { bags = opts.bags or {}, trade = {}, picked = {}, levels = opts.levels or {} }
	local known = {}
	for _, id in ipairs(opts.known or {}) do known[id] = true end
	local knows = function(id) return known[id] == true end
	local base = _G.C_Spell
	local spell = setmetatable({
		GetSpellName = function(id) return SPELLS[id] end,
		GetSpellSubtext = function(id) return RANKS[id] end,
		IsSpellUsable = function() return w.usable end,
	}, { __index = base })
	local function slotItems()
		local list = {}
		for item, count in pairs(w.bags) do
			if count > 0 then list[#list + 1] = item end
		end
		table.sort(list)
		return list
	end
	w.partner = opts.partner or "nameplate1"
	w.globals = {
		IsSpellKnown = knows, IsPlayerSpell = knows, C_Spell = spell,
		GetItemCount = function(item) return w.bags[item] or 0 end,
		C_Container = {
			GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
			GetContainerItemID = function(bag, slot) return bag == 0 and slotItems()[slot] or nil end,
			GetContainerItemInfo = function() return { isLocked = false } end,
			PickupContainerItem = function(bag, slot)
				w.cursor = slotItems()[slot]
				w.picked[#w.picked + 1] = w.cursor
			end,
		},
		GetCursorInfo = function() if w.cursor then return "item", w.cursor end end,
		CursorHasItem = function() return w.cursor ~= nil end,
		ClearCursor = function() w.cursor = nil end,
		ClickTradeButton = function(index)
			w.trade[index] = w.cursor
			w.cursor = nil
		end,
		GetTradePlayerItemLink = function(index) return w.trade[index] and "link" or nil end,
		AcceptTrade = function() w.accepted = true end,
		UnitGUID = function(unit)
			if unit == "NPC" then return "Player-1-" .. w.partner end
			return "Player-1-" .. tostring(unit)
		end,
		UnitLevel = function(unit)
			if unit == "player" then return 60 end
			return w.levels[unit] or 60
		end,
		MAX_TRADABLE_ITEMS = 6,
	}
	if opts.party ~= nil then w.globals.UnitInParty = function(unit) return opts.party and unit ~= "nameplate1" end end
	return w
end

-- A loaded addon with the prompt settled, people who ask switched on and
-- nobody offered anything unasked, so whoever is in the queue asked.
local function ready(ns, scenario, switches)
	freshPrompt(ns, scenario)
	local db = ns.db.profile
	db.sources.asked = true
	db.sources.strangers = false
	db.sources.group = false
	db.sources.self = false
	for _, key in ipairs(switches or {}) do db.sources[key] = true end
end

local MAGE = { 1459, 5504, 5505, 5506, 6127, 10138, 10139, 10140, 587, 28612, 11417, 11418 }
local WARLOCK = { 687, 5697, 6201, 11730, 698 }

-- ---------------------------------------------------------------- courtesy 1
-- The whole of it for water: asked for in /say, offered as a conjure while the
-- bags hold none, then as a trade; the press parks nothing for the settle;
-- the window opening puts the water in it and closes the request; and Manners
-- never accepts.
Mock.reset()
do
	local scenario = "courtesy: water asked for is conjured, then traded, and the trade is never accepted"
	local names = { nameplate1 = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	local w = world({ known = MAGE })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "SKIPPED -- Anna is offered before she asks for anything")
			return
		end
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy) then
			fail(scenario, "asking for water did not put Anna on the prompt for it")
			return
		end
		if anna.reason ~= "asked" or anna.priority ~= 1.5 then
			fail(scenario, ("she is on it as %s (%s), not as somebody who asked"):format(tostring(anna.reason),
				tostring(anna.priority)))
		end
		if anna.courtesy.stage ~= "conjure" then
			fail(scenario, "with no water in the bags the offer is " .. tostring(anna.courtesy.stage) .. ", not a conjure")
		end
		if ns.EntrySpellName(anna) ~= "Conjure Water" then
			fail(scenario, "the entry names " .. tostring(ns.EntrySpellName(anna)) .. ", not Conjure Water")
		end
		if ns.Prompt:ReasonText(anna) ~= "asked for water -- conjure it first" then
			fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(anna)))
		end
		ns.Prompt:Refresh()
		ns.pendingClick = nil
		local ran = pressButton(ns)
		if ran ~= "/cast Conjure Water" then
			fail(scenario, "the conjure press ran " .. tostring(ran and ran:gsub("\n", " / ")))
		end
		if ns.pendingClick then
			fail(scenario, "the press parked a click for the settle, as if a buff were on its way to her")
		end
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "the conjure is offered again the moment after it was pressed")
		end

		-- The water lands in the bags: the next offer is the trade.
		w.bags[8079] = 20
		Mock.advance(1)
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade") then
			fail(scenario, "with water in the bags the offer is not the trade")
			return
		end
		if ns.Prompt:ReasonText(anna) ~= "asked for water" then
			fail(scenario, "the trade's reason line reads " .. tostring(ns.Prompt:ReasonText(anna)))
		end
		ns.Prompt:Refresh()
		ran = pressButton(ns)
		if not (ran and ran:find("^/target Anna Aim\n/trade")) or ran:find("/cast", 1, true) then
			fail(scenario, "the trade press ran " .. tostring(ran and ran:gsub("\n", " / ")))
		end
		if ns.Prompt.state.barText ~= nil then
			fail(scenario, "the bar macro was handed the trade: " .. tostring(ns.Prompt.state.barText))
		end
		if ns.pendingClick then fail(scenario, "the trade press parked a click for the settle") end

		-- The window opens with her on the other side.
		names.NPC = { "Anna", "Aim" }
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		if w.trade[1] ~= 8079 then
			fail(scenario, "the water was not put in the trade window's first slot (" .. tostring(w.trade[1]) .. ")")
		end
		if w.cursor then fail(scenario, "the cursor was left holding the water") end
		if w.accepted then fail(scenario, "Manners accepted the trade") end
		if #ns.standingRequests ~= 0 then fail(scenario, "the request still stands after the trade opened") end
		Mock.advance(10)
		if entryFor(ns, "Anna Aim") then fail(scenario, "she is offered water again after the trade") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------------- courtesy 2
-- The words that ask for each, in the reader's own shapes, and the ones that
-- ask for nothing.
Mock.reset()
do
	local scenario = "courtesy: the words that ask for one are heard, and no others"
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE, bags = { [17032] = 5 } })
	Mock.groupSize = 2
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh", "courtesyPortals" })
		local asks = {
			{ "water pls", "courtesy:water" }, { "Water?", "courtesy:water" }, { "can I get some water", "courtesy:water" },
			{ "mage water please", "courtesy:water" }, { "need water", "courtesy:water" }, { "wasser bitte", "courtesy:water" },
			{ "agua por favor", "courtesy:water" }, { "conjure water pls", "courtesy:water" },
			{ "food pls", "courtesy:food" }, { "mage food", "courtesy:food" }, { "any food?", "courtesy:food" },
			{ "port to Orgrimmar pls", "courtesy:portal:11417" }, { "portal uc?", "courtesy:portal:11418" },
			{ "can i get a port to org", "courtesy:portal:11417" }, { "org portal pls", "courtesy:portal:11417" },
			{ "Portal: Undercity please", "courtesy:portal:11418" },
			-- Two at once: both are kept, and the first is offered first.
			{ "water and food pls", "courtesy:water" },
		}
		for _, ask in ipairs(asks) do
			hear(ns, "CHAT_MSG_PARTY", ask[1], "Anna Aim", "Player-1-party1")
			local anna = entryFor(ns, "Anna Aim")
			if not (anna and anna.courtesy and anna.courtesy.key == ask[2]) then
				fail(scenario, ("%q was not heard as %s (%s)"):format(ask[1], ask[2],
					tostring(anna and anna.courtesy and anna.courtesy.key or anna and anna.buff.key)))
			end
			Mock.advance(61)
		end
		for _, text in ipairs({
			"watery pls", "the water is cold", "no water pls", "thanks for the water", "is water any good?",
			"who has water?", "i was wondering whether anybody here might have some water for me please",
			"org pls", "uc?", "port pls", "portal to stormwind pls", "port to thunder bluff pls",
			"hs pls", "summon pls", "the portal to org is over there",
		}) do
			hear(ns, "CHAT_MSG_PARTY", text, "Anna Aim", "Player-1-party1")
			local anna = entryFor(ns, "Anna Aim")
			if anna then
				fail(scenario, ("%q put Anna on the prompt for %s"):format(text, tostring(anna.buff.key)))
			end
			Mock.advance(61)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------------- courtesy 3
-- A courtesy is told from a buff, both ways: "water pls" names no buff and
-- "int pls" no courtesy, and "buff pls" asks for no water.
Mock.reset()
do
	local scenario = "courtesy: water is no buff request, and a buff request no courtesy"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local request = ns.standingRequests[1]
		if not (request and request.keys["courtesy:water"]) then
			fail(scenario, "SKIPPED -- the request was not kept under the courtesy's own key")
			return
		end
		if request.keys.intellect then fail(scenario, "water pls was kept as a request for Arcane Intellect") end
		local pool = ns.AskedFor("nameplate1", "Anna Aim", GetTime(), ns.CastableBuffs(), nil)
		if pool then fail(scenario, "water pls reads to the walk as a request for a buff") end
		Mock.advance(61)

		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.buff.key == "intellect" and not anna.courtesy) then
			fail(scenario, "int pls was not offered as Arcane Intellect (" .. tostring(anna and anna.buff.key) .. ")")
		end
		Mock.advance(61)

		hear(ns, "CHAT_MSG_SAY", "buff pls", "Anna Aim", "Player-1-nameplate1")
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.buff.key == "intellect" and not anna.courtesy) then
			fail(scenario, "buff pls was not offered as a buff (" .. tostring(anna and anna.buff.key) .. ")")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------------- courtesy 4
-- Each courtesy is off until ticked, under the switch for people who ask, and
-- its tick is shown only to the class that has it.
Mock.reset()
do
	local scenario = "courtesy: each is off until ticked, and shown to the class that has it"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		local db = ns.db.profile
		for _, key in ipairs({ "courtesyRefresh", "courtesyPortals", "courtesyHealthstones", "courtesySummons" }) do
			if ns.defaults.profile.sources[key] ~= false then
				fail(scenario, key .. " is not off in a new profile (" .. tostring(ns.defaults.profile.sources[key]) .. ")")
			end
			local listed = false
			for _, field in ipairs(ns.OptionsPage.RESET.who) do
				if field == "sources." .. key then listed = true end
			end
			if not listed then fail(scenario, key .. " is not put back by the page's reset") end
		end
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		if entryFor(ns, "Anna Aim") then fail(scenario, "water is offered with its switch off") end
		if #ns.standingRequests ~= 0 then fail(scenario, "water pls was kept as a request with its switch off") end

		local refresh = H.findOption(ns.optionsTable, "courtesyRefresh")
		local portals = H.findOption(ns.optionsTable, "courtesyPortals")
		local stones = H.findOption(ns.optionsTable, "courtesyHealthstones")
		local summons = H.findOption(ns.optionsTable, "courtesySummons")
		if not (refresh and portals and stones and summons) then
			fail(scenario, "SKIPPED -- the four switches are not all on the Who to buff page")
			return
		end
		if refresh.hidden() or portals.hidden() then
			fail(scenario, "a mage is not shown the switches for water and portals")
		end
		if not stones.hidden() or not summons.hidden() then
			fail(scenario, "a mage is shown the warlock's switches")
		end
		db.sources.asked = false
		if not refresh.hidden() then fail(scenario, "the switch is shown with People who ask me in chat off") end
		db.sources.asked = true
		refresh.set({ "courtesyRefresh" }, true)
		if db.sources.courtesyRefresh ~= true then fail(scenario, "ticking the switch did not turn it on") end
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy) then fail(scenario, "water is not offered once its switch is ticked") end
		-- Switched off again while she waits: the offer goes.
		db.sources.courtesyRefresh = false
		if entryFor(ns, "Anna Aim") then fail(scenario, "water is still offered after its switch was turned off") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------------- courtesy 5
-- A portal: for a member of the group only, with the rune in the bags, cast at
-- nobody, and answered once the cast has gone out.
Mock.reset()
do
	local scenario = "courtesy: a portal is for the group, needs its rune and targets nobody"
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" }, nameplate1 = { "Bert", "Beside" } })
	local w = world({ known = MAGE, bags = { [17032] = 2 }, party = true })
	Mock.groupSize = 2
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyPortals" })
		hear(ns, "CHAT_MSG_PARTY", "port to org pls", "Anna Aim", "Player-1-party1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "cast") then
			fail(scenario, "SKIPPED -- the party member's portal is not offered")
			return
		end
		if ns.Prompt:ReasonText(anna) ~= "asked for a portal to Orgrimmar" then
			fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(anna)))
		end
		ns.Prompt:Refresh()
		local ran = pressButton(ns)
		if ran ~= "/cast Portal: Orgrimmar" then
			fail(scenario, "the portal press ran " .. tostring(ran and ran:gsub("\n", " / ")))
		end
		if ns.pendingClick then fail(scenario, "the portal press parked a click for the settle") end
		-- Another spell going out answers nothing; the portal's does.
		ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 1459)
		if #ns.standingRequests ~= 1 then fail(scenario, "another spell's cast answered the request for a portal") end
		ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 11417)
		if #ns.standingRequests ~= 0 then fail(scenario, "the portal going out did not answer the request") end
		Mock.advance(61)

		-- No rune: nothing offered, and the check-up says why.
		w.bags[17032] = 0
		hear(ns, "CHAT_MSG_PARTY", "port to org pls", "Anna Aim", "Player-1-party1")
		if entryFor(ns, "Anna Aim") then fail(scenario, "the portal is offered with no Rune of Portals in the bags") end
		local said = table.concat(ns.RequestLines(), "\n")
		if not said:find("|r for a portal to Orgrimmar (", 1, true) then
			fail(scenario, "the check-up's line for the request does not say what was asked for: " .. said)
		end
		if not said:find("asked for a portal to Orgrimmar -- no ", 1, true) or not said:find("in your bags", 1, true) then
			fail(scenario, "the check-up does not say the rune is missing: " .. said)
		end
		Mock.advance(61)
		w.bags[17032] = 2

		-- Somebody outside the group asks: not offered.
		hear(ns, "CHAT_MSG_SAY", "port to org pls", "Bert Beside", "Player-1-nameplate1")
		if entryFor(ns, "Bert Beside") then fail(scenario, "a passer-by is offered a portal") end
		said = table.concat(ns.RequestLines(), "\n")
		if not said:find("not in your party or raid", 1, true) then
			fail(scenario, "the check-up does not say he is outside the group: " .. said)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------------- courtesy 6
-- A warlock's healthstone: created with a shard, traded once it is in the
-- bags, and put in the window only for whoever asked.
Mock.reset()
do
	local scenario = "courtesy: a healthstone is created with a shard, then traded to whoever asked"
	local names = { nameplate1 = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	local w = world({ known = WARLOCK, bags = { [6265] = 1 } })
	Mock.class = "WARLOCK"
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyHealthstones" })
		hear(ns, "CHAT_MSG_SAY", "hs pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "conjure") then
			fail(scenario, "SKIPPED -- the healthstone is not offered as a create")
			return
		end
		if ns.Prompt:ReasonText(anna) ~= "asked for a healthstone -- create it first" then
			fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(anna)))
		end
		ns.Prompt:Refresh()
		local ran = pressButton(ns)
		-- A name that ends in a bracket of its own needs the empty one after
		-- it, or the macro reads "(Major)" as a rank.
		if ran ~= "/cast Create Healthstone (Major)()" then
			fail(scenario, "the create press ran " .. tostring(ran and ran:gsub("\n", " / ")))
		end
		-- The stone the talent improves is one of three ids: any of them is it.
		w.bags[6265], w.bags[19013] = 0, 1
		Mock.advance(1)
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade" and anna.courtesy.item == 19013) then
			fail(scenario, "the improved stone in the bags is not offered as the trade")
			return
		end
		ns.Prompt:Refresh()
		pressButton(ns)
		-- The window opens with somebody else: nothing goes in, and she still
		-- waits for hers.
		names.NPC = { "Bert", "Beside" }
		w.partner = "nameplate2"
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		if w.trade[1] or #w.picked > 0 then fail(scenario, "the stone was put in a trade with somebody else") end
		if #ns.standingRequests ~= 1 then fail(scenario, "a trade with somebody else answered her request") end
		Mock.advance(9)
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade") then
			fail(scenario, "she is not offered the trade again after it opened with somebody else")
			return
		end
		ns.Prompt:Refresh()
		pressButton(ns)
		names.NPC = { "Anna", "Aim" }
		w.partner = "nameplate1"
		-- Something on the cursor already: it is not dropped for the stone.
		w.cursor = 4306
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		if w.trade[1] or w.cursor ~= 4306 then fail(scenario, "what the cursor held was put in the trade, or dropped") end
		if w.accepted then fail(scenario, "Manners accepted the trade") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------------- courtesy 7
-- No shard, no stone and no summon; and a summon targets the member who asked
-- and leaves them targeted.
Mock.reset()
do
	local scenario = "courtesy: a summon targets the member who asked, hands nothing back, and needs a shard"
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" }, nameplate1 = { "Bert", "Beside" } })
	local w = world({ known = WARLOCK, bags = {}, party = true })
	Mock.class = "WARLOCK"
	Mock.groupSize = 2
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesySummons", "courtesyHealthstones" })
		hear(ns, "CHAT_MSG_PARTY", "summon pls", "Anna Aim", "Player-1-party1")
		if entryFor(ns, "Anna Aim") then fail(scenario, "a summon is offered with no Soul Shard in the bags") end
		local said = table.concat(ns.RequestLines(), "\n")
		if not said:find("a summon", 1, true) or not said:find("in your bags", 1, true) then
			fail(scenario, "the check-up does not say the shard is missing: " .. said)
		end
		w.bags[6265] = 3
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "summon") then
			fail(scenario, "SKIPPED -- the summon is not offered with a shard in the bags")
			return
		end
		if ns.Prompt:ReasonText(anna) ~= "asked for a summon" then
			fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(anna)))
		end
		ns.Prompt:Refresh()
		local ran = pressButton(ns)
		if ran ~= "/target Anna Aim\n/cast Ritual of Summoning" then
			fail(scenario, "the summon press ran " .. tostring(ran and ran:gsub("\n", " / ")))
		end
		ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 698)
		if #ns.standingRequests ~= 0 then fail(scenario, "the ritual going out did not answer the request") end
		Mock.advance(61)

		-- A stone with no shard: nothing to create it with.
		w.bags[6265] = 0
		hear(ns, "CHAT_MSG_PARTY", "hs pls", "Anna Aim", "Player-1-party1")
		if entryFor(ns, "Anna Aim") then fail(scenario, "a healthstone is offered with no shard to make it") end
		Mock.advance(61)
		w.bags[6265] = 3

		-- Somebody outside the group cannot be summoned.
		hear(ns, "CHAT_MSG_SAY", "summon pls", "Bert Beside", "Player-1-nameplate1")
		if entryFor(ns, "Bert Beside") then fail(scenario, "a passer-by is offered a summon") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------------- courtesy 8
-- Never in a fight: nothing is offered in one, and the pull takes a courtesy
-- off the button before the fight freezes it.
Mock.reset()
do
	local scenario = "courtesy: nothing is offered or left armed in a fight"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE, bags = { [8079] = 20 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_WHISPER", "water pls", "Anna Aim", "Player-1-nameplate1")
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		local armed = button:GetAttribute("macrotext1")
		if not (armed and armed:find("/trade", 1, true)) then
			fail(scenario, "SKIPPED -- the trade was not on the button before the pull")
			return
		end
		-- The pull, as the client delivers it: the event first, the lockdown
		-- after.
		ns.addon:PLAYER_REGEN_DISABLED()
		armed = button:GetAttribute("macrotext1")
		if armed and (armed:find("/trade", 1, true) or armed:find("Conjure", 1, true)) then
			fail(scenario, "the pull left the courtesy on the button: " .. armed:gsub("\n", " / "))
		end
		for _, entry in ipairs(ns.Prompt.state.fightQueue or {}) do
			if entry.courtesy then fail(scenario, "the fight's rota was handed a courtesy") end
		end
		Mock.inCombat = true
		if entryFor(ns, "Anna Aim") then fail(scenario, "a courtesy is offered in a fight") end
		local said = table.concat(ns.RequestLines(), "\n")
		if not said:find("never in a fight", 1, true) then
			fail(scenario, "the check-up does not say the fight holds it: " .. said)
		end
		-- The fight over, the request held through it is offered again.
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy) then fail(scenario, "the request held through the fight is not offered after it") end
		-- A fight the pull's event never announced (a /reload in the middle of
		-- one): the lockdown alone holds it.
		Mock.inCombat = true
		if entryFor(ns, "Anna Aim") then fail(scenario, "a courtesy is offered in a fight nothing announced") end
		Mock.inCombat = false
		noErrors(scenario, ns)
	end)
	Mock.inCombat = false
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------------- courtesy 9
-- The rank suits whoever asked: somebody of level 20 is not handed water they
-- cannot drink, and the conjure names the rank they can.
Mock.reset()
do
	local scenario = "courtesy: the water suits the level of whoever asked"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE, bags = { [8079] = 20 }, levels = { nameplate1 = 20 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy) then
			fail(scenario, "SKIPPED -- water is not offered")
			return
		end
		if anna.courtesy.stage ~= "conjure" then
			fail(scenario, "somebody of level 20 is offered the level 55 water in the bags")
			return
		end
		ns.Prompt:Refresh()
		local ran = pressButton(ns)
		if ran ~= "/cast Conjure Water(Rank 3)" then
			fail(scenario, "the conjure for level 20 ran " .. tostring(ran and ran:gsub("\n", " / ")))
		end
		-- Rank 3's water in the bags is what goes to them.
		w.bags[2136] = 10
		Mock.advance(1)
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy.stage == "trade" and anna.courtesy.item == 2136) then
			fail(scenario, "the water that suits them is not what the trade holds ("
				.. tostring(anna and anna.courtesy.item) .. ")")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- --------------------------------------------------------------- courtesy 10
-- One entry a person: a favour owed stays ahead of the courtesy, and a buff
-- nobody asked for gives way to it.
Mock.reset()
do
	local scenario = "courtesy: a favour comes first, and an unasked buff gives way"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE, bags = { [8079] = 20 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		ns.db.profile.sources.strangers = true
		local before = entryFor(ns, "Anna Aim")
		if not (before and before.reason == "nearby") then
			fail(scenario, "SKIPPED -- Anna is not offered Intellect as a passer-by")
			return
		end
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local count, anna = 0, nil
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Anna Aim" then count, anna = count + 1, entry end
		end
		if count ~= 1 then fail(scenario, "Anna is in the queue " .. count .. " times") end
		if not (anna and anna.courtesy) then fail(scenario, "the water she asked for did not take the passer-by's place") end

		owe(ns, "Anna Aim")
		count, anna = 0, nil
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Anna Aim" then count, anna = count + 1, entry end
		end
		if count ~= 1 then fail(scenario, "owed a favour, Anna is in the queue " .. count .. " times") end
		if not (anna and anna.reason == "owed" and not anna.courtesy) then
			fail(scenario, "the favour she is owed did not stay ahead of the water")
		end
		local said = table.concat(ns.RequestLines(), "\n")
		if not said:find("after the buff you have for them", 1, true) then
			fail(scenario, "the check-up does not say the water waits behind the buff: " .. said)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- --------------------------------------------------------------- courtesy 11
-- With no buff to give anybody the queue leaves early: a courtesy is still
-- offered.
Mock.reset()
do
	local scenario = "courtesy: water is offered with every buff switched off"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE, bags = { [8079] = 20 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		ns.db.profile.buff.skip = { intellect = true }
		if #ns.CastableBuffs() ~= 0 then
			fail(scenario, "SKIPPED -- the mage still has a buff to give")
			return
		end
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local queue, verdicts = ns.BuildQueue()
		if not (queue[1] and queue[1].courtesy and queue[1].name == "Anna Aim") then
			fail(scenario, "with no buff to give, the water she asked for is not offered")
		end
		if verdicts == true then fail(scenario, "the queue was handed back as refused for your own state") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- --------------------------------------------------------------- courtesy 12
-- Mists: one spell makes water and food alike, and a warlock's healthstone for
-- the group is a Soulwell, cast at nobody.
Mock.reset()
do
	local scenario = "courtesy: mists: one refreshment for water and food"
	Mock.setFlavour("mists")
	local restoreUnits = strangers({ nameplate1 = { "Anna" } })
	-- Level 90, as the Conjured Mana Pudding (80610) asks of whoever eats it.
	local w = world({ known = { 1459, 42955 }, levels = { nameplate1 = 90 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		for _, text in ipairs({ "water pls", "food pls" }) do
			w.bags[80610] = 0
			hear(ns, "CHAT_MSG_SAY", text, "Anna", "Player-1-nameplate1")
			local anna = entryFor(ns, "Anna")
			if not (anna and anna.courtesy and anna.courtesy.stage == "conjure" and anna.courtesy.spell == 42955) then
				fail(scenario, text .. ": not offered as Conjure Refreshment")
			end
			w.bags[80610] = 20
			anna = entryFor(ns, "Anna")
			if not (anna and anna.courtesy and anna.courtesy.stage == "trade" and anna.courtesy.item == 80610) then
				fail(scenario, text .. ": the refreshment in the bags is not offered as the trade")
			end
			Mock.advance(61)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

Mock.reset()
do
	local scenario = "courtesy: mists: a healthstone asked for is a Soulwell for the group"
	Mock.setFlavour("mists")
	local restoreUnits = strangers({ party1 = { "Anna" }, nameplate1 = { "Bert" } })
	local w = world({ known = { 5697, 29893, 698 }, party = true })
	Mock.class = "WARLOCK"
	Mock.groupSize = 2
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyHealthstones", "courtesySummons" })
		hear(ns, "CHAT_MSG_PARTY", "hs pls", "Anna", "Player-1-party1")
		local anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy and anna.courtesy.stage == "cast" and anna.courtesy.spell == 29893) then
			fail(scenario, "SKIPPED -- the Soulwell is not offered")
			return
		end
		ns.Prompt:Refresh()
		local ran = pressButton(ns)
		if ran ~= "/cast Create Soulwell" then
			fail(scenario, "the press ran " .. tostring(ran and ran:gsub("\n", " / ")))
		end
		Mock.advance(61)
		-- No shard on this client: the summon is offered with empty bags.
		hear(ns, "CHAT_MSG_PARTY", "summon pls", "Anna", "Player-1-party1")
		anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy and anna.courtesy.stage == "summon") then
			fail(scenario, "the summon is not offered where the client asks for no shard")
		end
		Mock.advance(61)
		hear(ns, "CHAT_MSG_SAY", "hs pls", "Bert", "Player-1-nameplate1")
		if entryFor(ns, "Bert") then fail(scenario, "a passer-by is offered a Soulwell") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- --------------------------------------------------------------- courtesy 13
-- The tooltip's account of each press, and a skip of whoever asked.
Mock.reset()
do
	local scenario = "courtesy: the tooltip says what the press does, and a skip lets them go"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE, bags = {} })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy) then
			fail(scenario, "SKIPPED -- water is not offered")
			return
		end
		local lines = table.concat(ns.Prompt:ClickSummary(anna, ns.Prompt.state), "\n")
		if not lines:find("nobody is targeted", 1, true) or not lines:find("Conjure Water", 1, true) then
			fail(scenario, "the conjure's tooltip reads: " .. lines)
		end
		w.bags[8079] = 20
		anna = entryFor(ns, "Anna Aim")
		lines = table.concat(ns.Prompt:ClickSummary(anna, ns.Prompt.state), "\n")
		if not lines:find("opens a trade", 1, true) or not lines:find("accepting the trade is yours", 1, true) then
			fail(scenario, "the trade's tooltip reads: " .. lines)
		end
		ns.Prompt:Refresh()
		pressButton(ns, "RightButton")
		if entryFor(ns, "Anna Aim") then fail(scenario, "a right-click did not skip whoever asked") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- --------------------------------------------------------------- courtesy 14
-- "Offer nothing in cities and inns" holds a courtesy as it holds a request for a
-- buff, but for somebody you targeted on purpose.
Mock.reset()
do
	local scenario = "courtesy: Offer nothing in cities and inns holds a courtesy too"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, target = { "Bert", "Beside" } })
	local w = world({ known = MAGE, bags = { [8079] = 20 } })
	w.globals.IsResting = function() return true end
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		hear(ns, "CHAT_MSG_SAY", "water pls", "Bert Beside", "Player-1-target")
		if not (entryFor(ns, "Anna Aim") and entryFor(ns, "Bert Beside")) then
			fail(scenario, "SKIPPED -- resting with the rule off, the two who asked are not both offered")
			return
		end
		ns.db.profile.filters.quietInTowns = true
		if entryFor(ns, "Anna Aim") then fail(scenario, "a courtesy is offered in a city with the rule on") end
		if not entryFor(ns, "Bert Beside") then fail(scenario, "your own target is held back by the city rule") end
		local said = table.concat(ns.RequestLines(), "\n")
		if not said:find("held back in a city or an inn", 1, true) then
			fail(scenario, "the check-up does not say the city rule holds it: " .. said)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
