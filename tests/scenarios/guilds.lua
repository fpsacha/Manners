-- Leave out these guilds, and Show their guild under the name (1.11.14). A
-- player on CurseForge asked to exclude guilds from the list, or at least to
-- see a guild under the name. The first is a typed list (filters.skipGuilds,
-- one name a line) that holds back the group and passers-by in those guilds,
-- and not a favour owed, a request or a target; the second puts <Guild> after
-- the reason on the second line (prompt.showGuild). Both are off by default.
--
-- Every scenario name starts with "guilds:" so the mutations in
-- tests/mutations/guilds.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local GUILDS = { nameplate1 = "Knights", party1 = "Raiders", target = "Knights" }

-- One session as a mage with a passer-by (Anna, of Knights), a party member
-- (Gwen, of Raiders) and a target (Tess, of Knights). `state.says` is whether
-- the client answers GetGuildInfo at all.
local function with(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local savedInfo, savedParty = rawget(_G, "GetGuildInfo"), rawget(_G, "UnitInParty")
	local state = { says = true }
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, party1 = { "Gwen", "Hale" },
		target = { "Tess", "Target" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "GetGuildInfo", function(unit)
			if state.says == "empty" then return "" end
			if not state.says then return nil end
			return GUILDS[unit]
		end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.group = true
		body(ns, state)
	end)
	restore()
	rawset(_G, "GetGuildInfo", savedInfo)
	rawset(_G, "UnitInParty", savedParty)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function named(first, last)
	return Mock.surnames and (first .. " " .. last) or first
end

local ANNA, GWEN, TESS = named("Anna", "Aim"), named("Gwen", "Hale"), named("Tess", "Target")

local function queue(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[entry.name] = entry end
	return out
end

local function has(list, ...)
	for _, name in ipairs({ ... }) do
		if not list[name] then return false, name end
	end
	return true
end

do
	local scenario = "guilds: off by default, everybody is offered and no guild is read"
	with(scenario, function(ns)
		if ns.db.profile.filters.skipGuilds ~= "" then fail(scenario, "the list is not empty in a new profile") end
		if ns.db.profile.prompt.showGuild ~= false then fail(scenario, "the guild line is not off by default") end
		local list = queue(ns)
		local ok, missing = has(list, ANNA, GWEN, TESS)
		if not ok then fail(scenario, missing .. " was not offered") end
		for name, entry in pairs(list) do
			if entry.guild then fail(scenario, name .. " carries a guild with the switch off") end
		end
	end)
end

do
	local scenario = "guilds: a passer-by of a listed guild is left out, in any case"
	with(scenario, function(ns)
		ns.db.profile.filters.skipGuilds = "knights"
		local list = queue(ns)
		if list[ANNA] then fail(scenario, "a passer-by of a listed guild was offered") end
		if not list[GWEN] then fail(scenario, "somebody of another guild was held back") end
	end)
end

do
	local scenario = "guilds: a member of your group in a listed guild is left out"
	with(scenario, function(ns)
		ns.db.profile.filters.skipGuilds = "Raiders"
		local list = queue(ns)
		if list[GWEN] then fail(scenario, "a group member of a listed guild was offered") end
		if not list[ANNA] then fail(scenario, "a passer-by of another guild was held back") end
	end)
end

do
	local scenario = "guilds: lines, spaces and the game's <Name> all read"
	with(scenario, function(ns)
		ns.db.profile.filters.skipGuilds = "\n  <Raiders>  \r\nSomebody Else\n\n"
		local list = queue(ns)
		if list[GWEN] then fail(scenario, "<Raiders> on a line of its own did not leave Raiders out") end
		if not list[ANNA] then fail(scenario, "Knights was left out by a list that does not name it") end
	end)
end

do
	local scenario = "guilds: your target and focus are still offered"
	with(scenario, function(ns)
		ns.db.profile.filters.skipGuilds = "Knights"
		local list = queue(ns)
		if not list[TESS] then fail(scenario, "the target was held back by its guild") end
	end)
end

do
	local scenario = "guilds: somebody who buffed you is still offered"
	with(scenario, function(ns)
		ns.db.profile.filters.skipGuilds = "Knights"
		H.owe(ns, ANNA)
		local list = queue(ns)
		if not list[ANNA] then fail(scenario, "a favour owed to somebody of a listed guild was dropped") end
	end)
end

do
	local scenario = "guilds: a guild the client will not say leaves nobody out"
	with(scenario, function(ns, state)
		ns.db.profile.filters.skipGuilds = "Knights\nRaiders"
		state.says = false
		local list = queue(ns)
		local ok, missing = has(list, ANNA, GWEN, TESS)
		if not ok then fail(scenario, missing .. " was left out without a guild to go on") end
	end)
end

do
	local scenario = "guilds: a list of only blank lines leaves nobody out"
	with(scenario, function(ns)
		ns.db.profile.filters.skipGuilds = "  \n\n <> \n"
		local ok, missing = has(queue(ns), ANNA, GWEN, TESS)
		if not ok then fail(scenario, missing .. " was left out by an empty list") end
	end)
end

do
	local scenario = "guilds: the second line says the guild when asked"
	with(scenario, function(ns)
		ns.db.profile.prompt.showGuild = true
		local list = queue(ns)
		local anna, gwen = list[ANNA], list[GWEN]
		if not (anna and gwen) then fail(scenario, "the queue lost somebody") return end
		if anna.guild ~= "Knights" or gwen.guild ~= "Raiders" then
			fail(scenario, "the entries read " .. tostring(anna.guild) .. " and " .. tostring(gwen.guild))
		end
		local line = ns.Prompt:ReasonText(anna)
		if not line:find("<Knights>", 1, true) then fail(scenario, "the second line reads " .. line) end
		ns.db.profile.prompt.showGuild = false
		local plain = ns.Prompt:ReasonText(anna)
		if plain:find("<", 1, true) then fail(scenario, "the guild stayed with the switch off: " .. plain) end
	end)
end

do
	local scenario = "guilds: somebody with no guild gets no empty brackets"
	with(scenario, function(ns, state)
		ns.db.profile.prompt.showGuild = true
		state.says = false
		local anna = queue(ns)[ANNA]
		if not anna then fail(scenario, "the queue lost somebody") return end
		local line = ns.Prompt:ReasonText(anna)
		if line:find("<", 1, true) then fail(scenario, "the second line reads " .. line) end
	end)
end

do
	local scenario = "guilds: a guild the client answers with nothing shows no brackets"
	with(scenario, function(ns, state)
		ns.db.profile.prompt.showGuild = true
		state.says = "empty"
		local anna = queue(ns)[ANNA]
		if not anna then fail(scenario, "the queue lost somebody") return end
		local line = ns.Prompt:ReasonText(anna)
		if line:find("<", 1, true) then fail(scenario, "the second line reads " .. line) end
	end)
end

do
	local scenario = "guilds: a blank reason line is followed by no gap"
	with(scenario, function(ns)
		ns.db.profile.prompt.showGuild = true
		ns.db.profile.prompt.reasonNearby = ""
		local anna = queue(ns)[ANNA]
		if not anna then fail(scenario, "the queue lost somebody") return end
		local line = ns.Prompt:ReasonText(anna)
		if line ~= "<Knights>" then fail(scenario, "the second line reads '" .. line .. "'") end
	end)
end

do
	local scenario = "guilds: Who to skip has the box and Look has the switch, both kept"
	with(scenario, function(ns)
		local box = H.findOption(ns.optionsTable, "skipGuilds")
		if not box then fail(scenario, "no box for the guilds to leave out") return end
		if box.type ~= "input" or not box.multiline then fail(scenario, "the guild list is not a multi-line box") end
		box.set({ "who", "skipGuilds" }, "Knights")
		if ns.db.profile.filters.skipGuilds ~= "Knights" or box.get({ "who", "skipGuilds" }) ~= "Knights" then
			fail(scenario, "the guild list was not kept")
		end
		local switch = H.findOption(ns.optionsTable, "showGuild")
		if not switch then fail(scenario, "no switch for the guild line") return end
		if switch.type ~= "toggle" then fail(scenario, "the guild switch is a " .. tostring(switch.type)) end
		switch.set({ "appearance", "showGuild" }, true)
		if ns.db.profile.prompt.showGuild ~= true then fail(scenario, "the guild switch was not kept") end
	end)
end

do
	local scenario = "guilds: a damaged list is repaired to an empty one"
	with(scenario, function(ns)
		ns.db.profile.filters.skipGuilds = { "Knights" }
		ns.ClampSettings()
		if ns.db.profile.filters.skipGuilds ~= "" then
			fail(scenario, "a list that is not text was kept: " .. tostring(ns.db.profile.filters.skipGuilds))
		end
		local list = queue(ns)
		if not has(list, ANNA, GWEN) then fail(scenario, "the scan lost people over a damaged list") end
	end)
end
