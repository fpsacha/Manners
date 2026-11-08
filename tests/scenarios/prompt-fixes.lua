-- Prompt fixes (bug hunt 35, area prompt): the Cozy Sleeping Bag's family
-- (Well-Rested, 1.11.10) against its own cast, a meal, a profile switch and
-- the debug lines.
--
-- Every scenario name starts with "prompt-fix:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local BAG, RESTED, IN_BAG, UNROLL = 211527, 429959, 429960, 429961
local FED_NAME, MEAL_NAME = "Well Fed", "Nutritious Food"

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function said() return table.concat(Mock.printed, "\n") end
local function flat(s) return (tostring(s):gsub("\n", " / ")) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "C_Container", "UnitLevel", "GetMaxPlayerLevel", "IsMounted",
	"IsSpellKnown", "IsPlayerSpell", "IsResting", "UnitCastingInfo" }

local function install()
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id)
			if world.fed and id == world.fed then return FED_NAME end
			if world.meals[id] then return MEAL_NAME end
			return spells.GetSpellName(id)
		end,
	}, { __index = spells }))
	rawset(_G, "C_Item", {
		GetItemCount = function(id)
			world.counted[id] = (world.counted[id] or 0) + 1
			return world.bags[id] or 0
		end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 5 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "GetMaxPlayerLevel", function() return 60 end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	-- The bag's own cast, while it runs: what the client says of it.
	rawset(_G, "UnitCastingInfo", function(unit)
		local c = world.casting
		if unit ~= "player" or not c or GetTime() >= c.ends then return nil end
		return "Unroll Bag", "Unroll Bag", 133662, c.starts * 1000, c.ends * 1000, false, c.guid, false, UNROLL
	end)
	local container = rawget(_G, "C_Container")
	rawset(_G, "C_Container", setmetatable({
		GetItemCooldown = function() return 0, 0, 1 end,
	}, { __index = container or {} }))
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			local expires = world.byId[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 7200, sourceUnit = "player" }
		end,
		GetAuraDataBySpellName = function(unit, name)
			if unit ~= "player" then return nil end
			local expires = world.byName[name]
			if expires == nil then return nil end
			return { name = name, expirationTime = expires, sourceUnit = "player" }
		end,
	}, { __index = base }))
end

-- One session as a warrior on opts.flavour (Forever), level opts.level (30),
-- with opts.bags and the switches in opts.on (family key -> true).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARRIOR"
	world = { bags = opts.bags or {}, level = opts.level or 30, byId = {}, byName = {}, counted = {},
		meals = {}, fed = nil, casting = nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local data = ns.FOODS and ns.FOODS[opts.flavour or "camelot"]
		if data then
			world.fed = data.fed
			for _, row in ipairs(data) do world.meals[row[3]] = true end
		end
		install()
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		for family in pairs(opts.on or {}) do ns.db.profile.ownBuffs.pick[family] = "auto" end
		ns.ForgetScrolls()
		body(ns, data)
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

-- The prompt pressed on the bag, and the SENT that starts its cast of
-- `seconds` (wago.tools: 15 on Forever, 6 on Classic Era).
local function pressBag(ns, scenario, guid, seconds)
	ns.Prompt:Refresh()
	if key(ns.Prompt:Showing()) ~= "rested" .. BAG then
		fail(scenario, "SKIPPED -- the prompt is on " .. key(ns.Prompt:Showing()) .. ", not the bag")
		return false
	end
	local pressed = H.pressButton(ns)
	if pressed ~= "/use item:" .. BAG or not (ns.pendingClick and ns.pendingClick.onSelf) then
		fail(scenario, "SKIPPED -- the press did not go out: " .. flat(pressed))
		return false
	end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, UNROLL)
	world.casting = { starts = GetTime(), ends = GetTime() + seconds, guid = guid }
	if ns.addon.UNIT_SPELLCAST_START then ns.addon:UNIT_SPELLCAST_START(nil, "player", guid, UNROLL) end
	if ns.pendingClick then fail(scenario, "SKIPPED -- the bag's use was never settled") return false end
	return true
end

-- ------------------------------------------------------------------ #0

do
	local scenario = "prompt-fix: the bag is not offered again partway through its own 15 s cast"
	with(scenario, { on = { rested = true }, bags = { [BAG] = 1 } }, function(ns)
		if not pressBag(ns, scenario, "Cast-bag-1", 15) then return end
		for _, at in ipairs({ 5, 10, 12.5, 14.5 }) do
			Mock.advance(at - (GetTime() - world.casting.starts))
			if mine(ns) then
				fail(scenario, ("%.1f s into the bag's 15 s cast it is offered again: %s"):format(at, key(mine(ns))))
				break
			end
		end
	end)
end

-- The bag laid down from the bags by hand, not through the prompt: no press of
-- Manners' holds it back, only the cast the client says is running (BagBusy).
do
	local scenario = "prompt-fix: the bag laid by hand is not offered while its cast runs"
	with(scenario, { on = { rested = true }, bags = { [BAG] = 1 } }, function(ns)
		if not mine(ns) then fail(scenario, "SKIPPED -- the bag is not offered to begin with") return end
		world.casting = { starts = GetTime(), ends = GetTime() + 15, guid = "Cast-bag-hand" }
		Mock.advance(2)
		if mine(ns) then fail(scenario, "2 s into a bag cast started by hand it is offered: " .. key(mine(ns))) end
		Mock.advance(14)
		if not mine(ns) then fail(scenario, "the cast over with no Well-Rested, and nothing offered") end
	end)
end

do
	local scenario = "prompt-fix: Classic Era with a 3 s retry block, the bag is not offered mid-cast"
	with(scenario, { flavour = "vanilla", on = { rested = true }, bags = { [BAG] = 1 } }, function(ns)
		ns.db.profile.timing.retryCooldown = 3
		if not pressBag(ns, scenario, "Cast-bag-2", 6) then return end
		Mock.advance(4.5)
		if mine(ns) then fail(scenario, "4.5 s into the bag's 6 s cast it is offered again: " .. key(mine(ns))) end
	end)
end

do
	local scenario = "prompt-fix: the bag's cast interrupted at second 8 is said and offered again"
	with(scenario, { on = { rested = true }, bags = { [BAG] = 1 } }, function(ns)
		ns.db.profile.verbose = true
		if not pressBag(ns, scenario, "Cast-bag-3", 15) then return end
		Mock.advance(8)
		Mock.printed = {}
		world.casting = nil
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-bag-3", UNROLL)
		if not said():find("the cast was interrupted", 1, true) then
			fail(scenario, "the bag's cast interrupted at 8 s said nothing of it: " .. flat(said()))
		end
		Mock.advance(2.1)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "2 s after the bag's cast was interrupted, offered " .. key(mine(ns)) .. ", not the bag")
		end
	end)
end

-- ------------------------------------------------------------------ #1

do
	local scenario = "prompt-fix: while eating, the sleeping bag is not offered next"
	with(scenario, { on = { rested = true, food = true }, level = 59 }, function(ns, data)
		local meal
		for _, row in ipairs(data or {}) do
			if row[2] <= 59 then meal = row break end
		end
		if not meal then fail(scenario, "SKIPPED -- no food for level 59") return end
		world.bags = { [meal[1]] = 2, [BAG] = 1 }
		ns.addon:BAG_UPDATE_DELAYED()
		if not tostring(key(mine(ns))):find("^food") then
			fail(scenario, "SKIPPED -- food was not offered first: " .. key(mine(ns)))
			return
		end
		world.byName[MEAL_NAME] = GetTime() + 18
		Mock.advance(1)
		local entry = mine(ns)
		if entry then
			fail(scenario, "a meal is on, and offered " .. key(entry) .. ", whose use would stand you up")
		end
	end)
end

-- ------------------------------------------------------------------ #2

do
	local scenario = "prompt-fix: a profile switch that turns Well-Rested on offers the bag"
	with(scenario, { bags = { [BAG] = 1 } }, function(ns)
		if not ns.db.SetProfile then fail(scenario, "SKIPPED -- the mock database has no profiles") return end
		if mine(ns) then fail(scenario, "SKIPPED -- offered with the switch off: " .. key(mine(ns))) return end
		Mock.sv.profiles = Mock.sv.profiles or {}
		Mock.sv.profiles["Alt"] = { ownBuffs = { pick = { rested = "auto" } } }
		ns.db:SetProfile("Alt")
		if not Mock.dbCallbacks["OnProfileChanged"] then ns.addon:RefreshConfig("OnProfileChanged") end
		if ns.db.profile.ownBuffs.pick.rested ~= "auto" then
			fail(scenario, "SKIPPED -- the Alt profile has Well-Rested " .. tostring(ns.db.profile.ownBuffs.pick.rested))
			return
		end
		Mock.advance(1)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "switched to a profile with Well-Rested on, the bag in the bags: offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ #3

do
	local scenario = "prompt-fix: the debug lines name Well-Rested and Well Fed when up"
	with(scenario, { on = { rested = true, food = true }, level = 59 }, function(ns, data)
		local meal
		for _, row in ipairs(data or {}) do
			if row[2] <= 59 then meal = row break end
		end
		world.bags = { [BAG] = 1, [meal and meal[1] or 0] = 1 }
		ns.addon:BAG_UPDATE_DELAYED()
		world.byId[RESTED] = GetTime() + 7000
		world.byName[FED_NAME] = GetTime() + 1700
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(1)
		local text = table.concat(ns.MyselfLines(GetTime()), " / ")
		if not text:find("Well-Rested:", 1, true) then
			fail(scenario, "SKIPPED -- no Well-Rested line: " .. flat(text))
			return
		end
		if text:find("? is up", 1, true) then
			fail(scenario, "a buff up is named '?': " .. flat(text))
		end
	end)
end

-- ------------------------------------------------------------------ hunt 37
-- Bug hunt 37, area prompt: Moonkin Form against the group's Mark of the Wild,
-- an alt's scroll body in the account-wide bar macro, and a class whose only
-- buff for others is a talent it has not learned (the empty press's lines, the
-- prompt's sound).
do
	local MOONKIN, MOTW, LS = 24858, 1126, 324
	local NAMES = { [MOONKIN] = "Moonkin Form", [MOTW] = "Mark of the Wild", [LS] = "Lightning Shield" }
	local PARTY = { party1 = { "Gwen", "Hale" }, party2 = { "Bram", "Oake" } }
	local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "C_Spell", "IsResting",
		"GetNumShapeshiftForms", "GetShapeshiftFormInfo", "GetCVar", "SetCVar" }

	-- env: client, class, known (ids), party (bool), form (spell id), wears
	-- (unit -> { [id] = source }), plates ("0"/"1"). body(ns, env).
	local function run(scenario, env, body)
		Mock.reset()
		Mock.setFlavour(env.client)
		Mock.class = env.class
		if env.party then Mock.groupSize = 3 end
		env.wears = env.wears or {}
		local restoreUnits = H.strangers(env.party and PARTY or {})
		local saved = {}
		for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
		local ok, err = pcall(function()
			local known = {}
			for _, id in ipairs(env.known or {}) do known[id] = true end
			local function isKnown(id) return known[id] == true end
			rawset(_G, "IsSpellKnown", isKnown)
			rawset(_G, "IsPlayerSpell", isKnown)
			rawset(_G, "IsResting", function() return false end)
			rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end)
			rawset(_G, "GetNumShapeshiftForms", function() return env.form and 1 or 0 end)
			rawset(_G, "GetShapeshiftFormInfo", function(i)
				if i == 1 and env.form then return 136116, true, true, env.form end
				return nil
			end)
			local cvar = env.plates or "1"
			rawset(_G, "GetCVar", function(name)
				if name == "nameplateShowFriends" or name == "nameplateShowFriendlyPlayers" then return cvar end
				return nil
			end)
			rawset(_G, "SetCVar", function() end)
			local spells = C_Spell
			rawset(_G, "C_Spell", setmetatable({
				GetSpellName = function(id) return NAMES[id] or spells.GetSpellName(id) end,
			}, { __index = spells }))
			local base = C_UnitAuras
			rawset(_G, "C_UnitAuras", setmetatable({
				GetUnitAuraBySpellID = function(unit, id)
					local source = env.wears[unit] and env.wears[unit][id]
					if source == nil then return nil end
					return { spellId = id, name = NAMES[id], expirationTime = 0, duration = 0, sourceUnit = source }
				end,
				GetAuraDataBySpellName = function(unit, name)
					for id, source in pairs(env.wears[unit] or {}) do
						if NAMES[id] == name then
							return { spellId = id, name = name, expirationTime = 0, duration = 0, sourceUnit = source }
						end
					end
					return nil
				end,
			}, { __index = base }))
			local ns = load(scenario)
			if not ns then return end
			if ns.Flavour.flavour ~= env.client then
				fail(scenario, "SKIPPED -- the mock is " .. tostring(ns.Flavour.flavour) .. ", not " .. env.client)
				return
			end
			freshPrompt(ns, scenario)
			ns.db.profile.sources.self = true
			ns.db.profile.sources.strangers = true
			ns.db.profile.sources.group = true
			ns.Guard("probe", ns.ProbeCapabilities)
			ns.addon:Tick()
			body(ns, env)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
		for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
		restoreUnits()
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end

	local function forget(ns)
		for _, unit in ipairs({ "player", "party1", "party2" }) do
			local guid = UnitGUID(unit)
			if guid then ns.ForgetUnitAuras(ns.plain(guid)) end
		end
	end

	local function top(ns)
		Mock.advance(4)
		local q = ns.BuildQueue()
		return q[1]
	end
	local function describe(entry)
		if not entry then return "nothing" end
		return tostring(entry.name) .. "/" .. tostring(entry.reason) .. "/" .. key(entry)
	end

	-- #0: the press of Mark of the Wild drops the druid out of Moonkin Form
	-- (it is not castable in it on these two clients); the next member still
	-- lacks it, and Moonkin Form must not come in ahead of them.
	for _, client in ipairs({ "vanilla", "tbc" }) do
		local scenario = "prompt-fix: " .. client .. ": Moonkin Form is not offered ahead of the group's Mark of the Wild"
		run(scenario, { client = client, class = "DRUID", known = { MOONKIN, MOTW }, party = true, form = MOONKIN,
			wears = { player = { [MOTW] = "player" } } }, function(ns, env)
			local first = top(ns)
			if not (first and first.reason ~= "self" and key(first) == "motw") then
				fail(scenario, "SKIPPED -- in Moonkin Form the prompt did not offer a member MotW: " .. describe(first))
				return
			end
			-- The press: out of the form, and that member's MotW landed.
			env.form = nil
			if first.name == "Gwen" then env.wears.party1 = { [MOTW] = "player" } else env.wears.party2 = { [MOTW] = "player" } end
			forget(ns)
			local after = top(ns)
			if key(after) == "moonkinform" then
				fail(scenario, "with a member still lacking Mark of the Wild, the prompt offers " .. describe(after)
					.. " -- the next press shifts back into the form the next MotW knocks you out of")
			elseif not (after and key(after) == "motw") then
				fail(scenario, "SKIPPED -- the second member was not offered MotW: " .. describe(after))
			end
		end)
	end

	-- Forever casts Mark of the Wild in Moonkin Form: the form stays offered.
	do
		local scenario = "prompt-fix: camelot: Moonkin Form is still offered ahead of the group's Mark of the Wild"
		run(scenario, { client = "camelot", class = "DRUID", known = { MOONKIN, MOTW }, party = true, form = MOONKIN,
			wears = { player = { [MOTW] = "player" } } }, function(ns, env)
			local first = top(ns)
			if not (first and first.reason ~= "self" and key(first) == "motw") then
				fail(scenario, "SKIPPED -- in Moonkin Form the prompt did not offer a member MotW: " .. describe(first))
				return
			end
			env.form = nil
			if first.name == "Gwen" then env.wears.party1 = { [MOTW] = "player" } else env.wears.party2 = { [MOTW] = "player" } end
			forget(ns)
			local after = top(ns)
			if key(after) ~= "moonkinform" then
				fail(scenario, "Mark of the Wild can be cast in the form here, yet the prompt offers " .. describe(after))
			end
		end)
	end

	-- #2: an empty prompt's press with nothing castable on anybody else does
	-- not blame the friendly nameplates.
	for _, client in ipairs({ "vanilla", "tbc", "mists" }) do
		local scenario = "prompt-fix: " .. client .. ": a shaman with no Earth Shield is not told the nameplates hide passers-by"
		run(scenario, { client = client, class = "SHAMAN", known = { LS }, plates = "0",
			wears = { player = { [LS] = "player" } } }, function(ns)
			if ns.Prompt:GetButton():IsShown() then
				fail(scenario, "SKIPPED -- the prompt is up with Lightning Shield on: " .. describe(top(ns)))
				return
			end
			if #ns.CastableBuffs() ~= 0 then fail(scenario, "SKIPPED -- something is castable on others") return end
			Mock.printed = {}
			H.pressButton(ns)
			local text = said()
			if text:find("nameplate", 1, true) then
				fail(scenario, "nothing is castable on a passer-by, yet the press says: " .. flat(text))
			elseif not text:find("nobody to buff right now.", 1, true) then
				fail(scenario, "SKIPPED -- the press said: " .. flat(text))
			end
		end)
	end

	-- #3: "Only for people who buff me" (on by default) lets the sound through
	-- for a class nobody can owe: Lightning Shield dropping sounds.
	for _, client in ipairs({ "vanilla", "tbc", "mists" }) do
		local scenario = "prompt-fix: " .. client .. ": a shaman with no Earth Shield hears his own reminder"
		run(scenario, { client = client, class = "SHAMAN", known = { LS },
			wears = { player = { [LS] = "player" } } }, function(ns, env)
			ns.db.profile.sound.enabled = true
			if ns.db.profile.sound.owedOnly ~= true then
				fail(scenario, "SKIPPED -- Only for people who buff me is not on by default")
			end
			Mock.advance(10)
			ns.addon:Tick()
			if ns.Prompt:GetButton():IsShown() then
				fail(scenario, "SKIPPED -- the prompt is up with Lightning Shield on")
				return
			end
			Mock.sounds = {}
			env.wears.player = {}
			forget(ns)
			Mock.advance(10)
			ns.addon:Tick()
			local first = ns.BuildQueue()[1]
			if not (ns.Prompt:GetButton():IsShown() and first and first.reason == "self") then
				fail(scenario, "SKIPPED -- Lightning Shield dropping put nothing of yours up: " .. describe(first))
			elseif #Mock.sounds ~= 1 then
				fail(scenario, "his own reminder came up and the sound played " .. #Mock.sounds .. " times")
			end
		end)
	end

	-- #4: a retail paladin with no Beacon and no rite presses the empty
	-- prompt: not promised something to learn.
	do
		local scenario = "prompt-fix: mainline: a paladin with no Beacon is not told nothing is learned yet"
		run(scenario, { client = "mainline", class = "PALADIN", known = {} }, function(ns)
			if ns.Prompt:GetButton():IsShown() then fail(scenario, "SKIPPED -- the prompt is up") return end
			if ns.CanCastAnything() then fail(scenario, "SKIPPED -- something is castable") return end
			Mock.printed = {}
			H.pressButton(ns)
			local text = said()
			if text:find("nothing learned to cast yet", 1, true) then
				fail(scenario, "a paladin who may never learn Beacon is told: " .. flat(text))
			end
		end)
	end
end

-- #1: an alt's scroll body (/target <other>, /use item, hand-back) left in the
-- account-wide macro is Manners' own, rewritten at login like a /cast one.
do
	local BAR_LINE = "/click MannersBar"
	for _, case in ipairs({
		{ "a scroll used on another character", BAR_LINE .. "\n/target Alice Aster\n/use item:3012\n/targetlasttarget" },
		{ "a cast at another character (control)", BAR_LINE .. "\n/target Alice Aster\n/cast Arcane Intellect\n/targetlasttarget" },
	}) do
		local scenario = "prompt-fix: an alt's bar macro body is rewritten at login (" .. case[1] .. ")"
		Mock.reset()
		Mock.setFlavour("camelot")
		local restore = strangers({})
		Mock.macroList[1] = { name = "Manners", icon = "INV_MISC_NOTE_03", body = case[2] }
		local ns = load(scenario)
		if ns then
			local ok, err = pcall(function()
				Mock.printed = {}
				ns.addon:OnInitialize()
				-- Alice has played on this account (AceDB's record of who has).
				ns.addon.db.sv.profileKeys["Alice - Mockrealm"] = "Default"
				ns.addon:OnEnable()
				Mock.runTimers(3)
				local now = Mock.macroList[1] and Mock.macroList[1].body
				if now ~= BAR_LINE then
					fail(scenario, "the body left by another character stayed: " .. flat(now))
				end
				if said():find("still targets", 1, true) then
					fail(scenario, "said the macro is not Manners': " .. flat(said()))
				end
			end)
			if not ok then fail(scenario, "threw: " .. tostring(err)) end
		end
		restore()
		Mock.reset()
	end
end
