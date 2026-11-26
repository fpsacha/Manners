-- Exact, explicit class services: learned spell, reagents, aura, range,
-- target, cooldown, chat scope, instance and combat state are all read before
-- the secure prompt is armed.

local dir, H = ...
local fail, load = H.fail, H.load
local freshPrompt, strangers = H.freshPrompt, H.strangers

local CLIENTS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local CLASSIC = { camelot = true, vanilla = true, tbc = true }
local SPELLS = {
	[130] = "Slow Fall", [1706] = "Levitate", [546] = "Water Walking",
	[698] = "Ritual of Summoning", [20707] = "Soulstone Resurrection",
	[11417] = "Portal: Orgrimmar",
	[20752] = "Create Soulstone", [20755] = "Create Soulstone", [20756] = "Create Soulstone",
	[20757] = "Create Soulstone", [27238] = "Create Soulstone",
	[29886] = "Create Soulwell", [29893] = "Create Soulwell",
}

local TOUCHED = {
	"IsSpellKnown", "IsPlayerSpell", "C_Spell", "C_Item", "C_UnitAuras", "GetItemCount",
	"UnitInParty", "UnitInRaid", "UnitIsVisible", "UnitIsDeadOrGhost", "UnitIsConnected",
	"UnitCanAssist", "UnitIsPlayer", "CheckInteractDistance", "IsInInstance",
}

local function entry(ns, name)
	local fallback
	local first = name:match("^%S+")
	for _, item in ipairs(ns.BuildQueue()) do
		if item.name == name or item.name == first or ns.ShortName(item.name) == first then
			if item.courtesy then return item end
			fallback = fallback or item
		end
	end
	return fallback
end

local function hear(ns, channel, text, sender, token)
	local event = "CHAT_MSG_" .. channel
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, "Player-1-" .. token)
end

local function scene(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class
	Mock.groupSize = 3
	local names = {
		party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		target = { "Tess", "Target" }, focus = { "Fiona", "Focus" },
		nameplate1 = { "Nia", "Near" },
	}
	local restore = strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local world = {
		known = {}, bags = opts.bags or {}, auras = {}, usable = true, range = true, inGroup = true,
		dead = false, assist = true, player = true, connected = true, visible = true, instance = false,
	}
	local baseKnown = { MAGE = 1459, PRIEST = 1243, SHAMAN = 324, WARLOCK = 687 }
	world.known[baseKnown[opts.class]] = true
	for _, id in ipairs(opts.known or {}) do world.known[id] = true end
	local baseSpell, baseItem, baseAura = rawget(_G, "C_Spell"), rawget(_G, "C_Item"), rawget(_G, "C_UnitAuras")
	rawset(_G, "IsSpellKnown", function(id) return world.known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return world.known[id] == true end)
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id) return SPELLS[id] end,
		IsSpellUsable = function() return world.usable end,
		IsSpellInRange = function() return world.range end,
		GetSpellCooldown = function(id)
			local cooldown = world.cooldowns and world.cooldowns[id]
			return cooldown and { startTime = GetTime(), duration = cooldown } or nil
		end,
	}, { __index = baseSpell }))
	rawset(_G, "C_Item", setmetatable({
		GetItemCount = function(id) return world.bags[id] or 0 end,
		IsUsableItem = function() return true, false end,
		IsItemInRange = function() return world.range end,
	}, { __index = baseItem }))
	rawset(_G, "GetItemCount", function(id) return world.bags[id] or 0 end)
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(_, id)
			if world.auras[id] then return { spellId = id, name = SPELLS[id] or "Aura" } end
		end,
	}, { __index = baseAura }))
	rawset(_G, "UnitInParty", function(unit) return world.inGroup and unit:find("^party") ~= nil end)
	rawset(_G, "UnitInRaid", function() return false end)
	rawset(_G, "UnitIsVisible", function() return world.visible end)
	rawset(_G, "UnitIsDeadOrGhost", function(unit) return unit ~= "player" and world.dead end)
	rawset(_G, "UnitIsConnected", function() return world.connected end)
	rawset(_G, "UnitCanAssist", function() return world.assist end)
	rawset(_G, "UnitIsPlayer", function() return world.player end)
	rawset(_G, "CheckInteractDistance", function() return world.range end)
	rawset(_G, "IsInInstance", function() return world.instance, world.instance and "party" or "none" end)
	local ok, caught = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		ns.db.profile.sources.group = false
		ns.db.profile.sources.self = false
		ns.db.profile.sources.asked = true
		body(ns, world, names)
		for _, err in ipairs(ns.errors or {}) do fail(scenario, "guarded: " .. tostring(err.where) .. " -> " .. tostring(err.err)) end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(caught)) end
end

local function enable(ns, service)
	ns.Courtesy.SetServiceOn(service, true)
	ns.Courtesy.SetScope(service, "group", true)
	ns.Courtesy.SetScope(service, "whisper", true)
	ns.Courtesy.SetScope(service, "target", true)
	ns.Courtesy.Forget()
end

-- Every named class service exists on every exact client that ships it. The
-- spell is still not queued until the learned-spell and live context checks pass.
do
	local scenario = "services-utilities: exact client support is class-gated"
	for _, client in ipairs(CLIENTS) do
		for _, case in ipairs({
			{ "MAGE", "courtesySlowFall", "slowfall" },
			{ "PRIEST", "courtesyLevitate", "levitate" },
			{ "SHAMAN", "courtesyWaterWalking", "waterwalking" },
			{ "WARLOCK", "courtesySoulstone", "soulstone" },
		}) do
			scene(scenario, { flavour = client, class = case[1] }, function(ns)
				if not ns.Courtesy.Has(case[2]) then
					fail(scenario, client .. " has no " .. case[3] .. " definition for " .. case[1])
				end
			end)
		end
	end
end

do
	local scenario = "services-utilities: explicit utility requests prove target, aura, range, reagent and cooldown"
	for _, case in ipairs({
		{ service = "slowfall", class = "MAGE", spell = 130, words = "slow fall pls", reagent = 17056 },
		{ service = "levitate", class = "PRIEST", spell = 1706, words = "levitate pls", reagent = 17056 },
		{ service = "waterwalking", class = "SHAMAN", spell = 546, words = "water walking pls", reagent = 17058 },
	}) do
		for _, client in ipairs(CLIENTS) do
			local bags = {}
			if CLASSIC[client] then bags[case.reagent] = 1 end
			scene(scenario, { flavour = client, class = case.class, known = { case.spell }, bags = bags }, function(ns, world)
				enable(ns, case.service)
				hear(ns, "PARTY", case.words, "Anna Aim", "party1")
				local offer = entry(ns, "Anna Aim")
				if not (offer and offer.courtesy and offer.courtesy.stage == "targetcast"
					and offer.courtesy.spell == case.spell) then
					fail(scenario, client .. " " .. case.service .. " is not a targeted secure offer: "
						.. table.concat(ns.RequestLines(), " / "))
					return
				end
				ns.Prompt:Refresh()
				local macro = ns.Prompt:GetButton():GetAttribute("macrotext1")
				local target = offer.targetName or offer.name
				if not (macro and macro:find("/target " .. target .. "\n/cast " .. (SPELLS[case.spell] or ""), 1, true)) then
					fail(scenario, client .. " " .. case.service .. " macro is " .. tostring(macro))
				end
				world.auras[case.spell] = true
				Mock.advance(1)
				if entry(ns, "Anna Aim") then fail(scenario, client .. " offered " .. case.service .. " over its aura") end
				world.auras[case.spell] = nil
				world.range = false
				Mock.advance(1)
				if entry(ns, "Anna Aim") then fail(scenario, client .. " offered " .. case.service .. " out of range") end
				world.range = true
				world.cooldowns = { [case.spell] = 30 }
				Mock.advance(1)
				if entry(ns, "Anna Aim") then fail(scenario, client .. " offered " .. case.service .. " on cooldown") end
				world.cooldowns = nil
				world.usable = Mock.SECRET
				Mock.advance(1)
				if entry(ns, "Anna Aim") then fail(scenario, client .. " offered " .. case.service .. " with secret usability") end
				world.usable = true
				if CLASSIC[client] then
					world.bags[case.reagent] = 0
					world.usable = false
					Mock.advance(1)
					if entry(ns, "Anna Aim") then fail(scenario, client .. " offered " .. case.service .. " without its reagent") end
					world.bags[case.reagent] = 1
				end
				world.usable = true
				world.dead = true
				Mock.advance(1)
				if entry(ns, "Anna Aim") then fail(scenario, client .. " offered " .. case.service .. " to a dead player") end
				if client == "camelot" and not table.concat(ns.RequestLines(), "\n"):find("dead or a ghost", 1, true) then
					fail(scenario, "the check-up does not explain the dead target")
				end
				world.dead = false
				world.known[case.spell] = nil
				ns.Courtesy.Forget()
				Mock.advance(1)
				if entry(ns, "Anna Aim") then fail(scenario, client .. " offered an unlearned " .. case.service) end
			end)
		end
	end
end

do
	local scenario = "services-utilities: portal destinations are explicit and TBC uses its learned Soulwell"
	scene(scenario, { flavour = "tbc", class = "MAGE", known = { 11417 }, bags = { [17032] = 1 } }, function(ns)
		enable(ns, "portal")
		ns.Courtesy.SetDestination(11417, false)
		hear(ns, "PARTY", "portal to Orgrimmar pls", "Anna Aim", "party1")
		if entry(ns, "Anna Aim") then fail(scenario, "a destination switched off was offered") end
		if #ns.standingRequests ~= 0 then fail(scenario, "a switched-off destination was still kept as a request") end
		-- Turning it off while a request already stands is rechecked in Plan.
		ns.Courtesy.SetDestination(11417, true)
		hear(ns, "PARTY", "portal to Orgrimmar pls", "Anna Aim", "party1")
		ns.Courtesy.SetDestination(11417, false)
		if entry(ns, "Anna Aim") then fail(scenario, "a standing request survived its destination being switched off") end
		ns.Courtesy.SetDestination(11417, true)
		hear(ns, "PARTY", "portal to Orgrimmar pls", "Anna Aim", "party1")
		local portal = entry(ns, "Anna Aim")
		if not (portal and portal.courtesy and portal.courtesy.stage == "cast"
			and portal.courtesy.spell == 11417) then
			fail(scenario, "the explicitly named learned destination was not offered: "
				.. table.concat(ns.RequestLines(), " / "))
		end
	end)
	scene(scenario, { flavour = "tbc", class = "WARLOCK", known = { 29886 } }, function(ns)
		enable(ns, "healthstone")
		hear(ns, "PARTY", "healthstone pls", "Anna Aim", "party1")
		local well = entry(ns, "Anna Aim")
		if not (well and well.courtesy and well.courtesy.stage == "cast" and well.courtesy.spell == 29886) then
			fail(scenario, "the learned TBC Soulwell was not preferred for a group request: "
				.. table.concat(ns.RequestLines(), " / "))
		end
	end)
end

do
	local scenario = "services-utilities: request scope, combat, instance and matching are independent per service"
	scene(scenario, { flavour = "camelot", class = "MAGE", known = { 130 }, bags = { [17056] = 1 } }, function(ns, world)
		enable(ns, "slowfall")
		ns.Courtesy.SetScope("slowfall", "group", false)
		ns.Courtesy.SetScope("slowfall", "whisper", false)
		ns.Courtesy.SetScope("slowfall", "target", false)
		hear(ns, "PARTY", "slow fall pls", "Anna Aim", "party1")
		if entry(ns, "Anna Aim") then fail(scenario, "party chat was accepted with group scope off") end
		-- A different source keeps the service active while this chat source
		-- remains forbidden, so the Plan-level gate is exercised too.
		ns.Courtesy.SetScope("slowfall", "target", true)
		hear(ns, "PARTY", "slow fall pls", "Anna Aim", "party1")
		if entry(ns, "Anna Aim") then fail(scenario, "party chat was accepted as a current-target request") end
		hear(ns, "WHISPER", "slow fall pls", "Fiona Focus", "focus")
		if entry(ns, "Fiona Focus") then fail(scenario, "focus was accepted as the current target") end
		wipe(ns.standingRequests)
		ns.Courtesy.SetScope("slowfall", "group", true)
		Mock.inCombat = true
		ns.Courtesy.SetServiceSetting("slowfall", "combat", "hold")
		hear(ns, "PARTY", "slow fall pls", "Anna Aim", "party1")
		Mock.inCombat = false
		Mock.advance(1)
		if not entry(ns, "Anna Aim") then fail(scenario, "a combat request set to Hold was lost") end
		Mock.inCombat = true
		ns.Courtesy.SetServiceSetting("slowfall", "combat", "ignore")
		hear(ns, "PARTY", "slow fall pls", "Bert Beside", "party2")
		Mock.inCombat = false
		Mock.advance(1)
		if entry(ns, "Bert Beside") then fail(scenario, "a combat request set to Ignore was kept") end
		Mock.inCombat = true
		hear(ns, "WHISPER", "slow fall pls", "Bert Beside", "party2")
		Mock.inCombat = false
		Mock.advance(1)
		if entry(ns, "Bert Beside") then fail(scenario, "an ignored combat whisper fell through to the core request hold") end
		ns.Courtesy.SetServiceSetting("slowfall", "where", "outside")
		world.instance = true
		Mock.advance(1)
		if entry(ns, "Anna Aim") then fail(scenario, "the service was offered inside an excluded instance") end
		world.instance = false
		ns.Courtesy.SetServiceSetting("slowfall", "matching", "strict")
		hear(ns, "PARTY", "slowfall pls", "Bert Beside", "party2")
		if #ns.standingRequests > 1 then fail(scenario, "a short alias matched with explicit names only") end
	end)
end

do
	local scenario = "services-utilities: a learned service alone gives a class a castable prompt"
	scene(scenario, { flavour = "mainline", class = "WARLOCK", known = { 698 } }, function(ns)
		enable(ns, "summon")
		if not (ns.Courtesy and ns.Courtesy.Active and ns.Courtesy.Active()) then
			fail(scenario, "the learned group service was not active")
		end
		if not ns.CanCastAnything() then fail(scenario, "Services did not give the class something to cast") end
		if not ns.OptionsPage.HasPrompt() then fail(scenario, "the options said a Services-only class has no prompt") end
	end)
end

do
	local scenario = "services-utilities: Classic Soulstones are created then used; modern ones cast directly"
	for _, client in ipairs(CLIENTS) do
		local id = CLASSIC[client] and (client == "tbc" and 27238 or 20757) or 20707
		scene(scenario, { flavour = client, class = "WARLOCK", known = { id }, bags = CLASSIC[client] and { [6265] = 1 } or {} },
			function(ns, world)
				enable(ns, "soulstone")
				hear(ns, "PARTY", "soulstone pls", "Anna Aim", "party1")
				local offer = entry(ns, "Anna Aim")
				if not offer then fail(scenario, client .. " has no Soulstone offer") return end
				local wanted = CLASSIC[client] and "conjure" or "targetcast"
				if offer.courtesy.stage ~= wanted then
					fail(scenario, client .. " Soulstone is " .. tostring(offer.courtesy.stage) .. ", not " .. wanted)
					return
				end
				if CLASSIC[client] then
					local item = client == "tbc" and 22116 or 16896
					ns.Courtesy.Pressed(offer, { isBar = false }, GetTime())
					ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-soul", id)
					world.bags[item] = 1
					Mock.advance(5)
					offer = entry(ns, "Anna Aim")
					if not (offer and offer.courtesy.stage == "item" and offer.courtesy.item == item) then
						fail(scenario, client .. " did not move from Create Soulstone to the bag item")
					end
				end
			end)
	end
end
