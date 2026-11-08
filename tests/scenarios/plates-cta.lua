-- Friendly nameplates off with passers-by on: Manners finds almost nobody
-- outside the group, and a player who never opens Who to buff never learned
-- it (a check-up from WoW Forever, 1.11.12). So the call to it is loud: Who to
-- buff's note is red and the page has a red dot (Options/Shared.lua,
-- Page.Warn), and Start here says the same under step 1 with the same button
-- (Options/Start.lua, startPlatesNote and startShowPlates), all from one
-- answer (Options/Who.lua, Page.PlatesWanted).
--
-- The setting is nameplateShowFriendlyPlayers on WoW Forever and
-- nameplateShowFriends on the Classic clients, so each scenario runs as both.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- scenario name starts with "plates-cta:" so the mutations in
-- tests/mutations/plates-cta.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local CASES = {
	{ label = "Forever", flavour = nil, cvar = "nameplateShowFriendlyPlayers" },
	{ label = "vanilla", flavour = "vanilla", cvar = "nameplateShowFriends" },
}

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The client's settings as GetCVar and SetCVar see them, every SetCVar
-- written down; the client answers only the names in `values`.
local function cvars(values)
	local realGet, realSet = rawget(_G, "GetCVar"), rawget(_G, "SetCVar")
	local box = { values = values or {}, sets = {} }
	rawset(_G, "GetCVar", function(name) return box.values[name] end)
	rawset(_G, "SetCVar", function(name, value)
		box.sets[#box.sets + 1] = { name, value }
		box.values[name] = tostring(value)
	end)
	return box, function()
		rawset(_G, "GetCVar", realGet)
		rawset(_G, "SetCVar", realSet)
	end
end

local function session(scenario, case, plates, body)
	local box, restore = cvars({ [case.cvar] = plates })
	Mock.reset()
	if case.flavour then Mock.setFlavour(case.flavour) end
	local ns
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		-- Set up already: Quick setup's questions are not asking.
		ns.db.profile.firstRun = "answered"
		ns.db.profile.sources.strangers = true
		body(ns, box)
	end)
	if ns then pcall(ns.CloseOptions) end
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	if ns then noErrors(scenario, ns) end
end

local function control(ns, tab, key)
	local t = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args[tab]
	return t and t.args and t.args[key]
end

local function shown(c)
	if not c then return "missing" end
	local hidden = c.hidden
	if type(hidden) == "function" then hidden = hidden({}) end
	return not hidden
end

local function text(c)
	local name = c and c.name
	if type(name) == "function" then name = name({}) end
	return tostring(name)
end

local function warn(ns)
	local fn = ns.OptionsPage.Warn and ns.OptionsPage.Warn.who
	if type(fn) ~= "function" then return "missing" end
	return fn()
end

-- ------------------------------------------------------------- Who to buff
for _, case in ipairs(CASES) do
	local scenario = "plates-cta: " .. case.label .. ": Who to buff has a red dot and a red note while the nameplates are off"
	session(scenario, case, "0", function(ns, box)
		if warn(ns) ~= true then fail(scenario, "passers-by on, nameplates off, and Who to buff has no red dot") end
		local note = control(ns, "who", "strangersPlatesNote")
		if shown(note) ~= true then fail(scenario, "the note under the passers-by switch is hidden") end
		if not text(note):find("|cffff8080", 1, true) then
			fail(scenario, "the note under the red dot is not red: " .. text(note))
		end
		box.values[case.cvar] = "1"
		if warn(ns) ~= false then fail(scenario, "the nameplates are on and Who to buff still has a red dot") end
		box.values[case.cvar] = "0"
		ns.db.profile.sources.strangers = false
		if warn(ns) ~= false then fail(scenario, "passers-by are off and Who to buff has a red dot for the nameplates") end
		if #box.sets > 0 then fail(scenario, "the setting was changed without a click") end
	end)
end

-- ------------------------------------------------------------- Start here
for _, case in ipairs(CASES) do
	local scenario = "plates-cta: " .. case.label .. ": Start here asks for the nameplates under step 1"
	session(scenario, case, "0", function(ns, box)
		local note = control(ns, "general", "startPlatesNote")
		local button = control(ns, "general", "startShowPlates")
		if shown(note) ~= true or shown(button) ~= true then
			fail(scenario, ("the note is %s and the button %s"):format(tostring(shown(note)), tostring(shown(button))))
			return
		end
		if not text(note):find("Turn on friendly nameplates so Manners can see passers-by", 1, true) then
			fail(scenario, "the note says " .. text(note))
		end
		if text(button) ~= "Show friendly nameplates" then fail(scenario, "the button reads " .. text(button)) end
		-- Drawn under step 1, in its section.
		local page, section = H.placedOn(ns, "general.startPlatesNote")
		local _, buttonSection = H.placedOn(ns, "general.startShowPlates")
		if page ~= "general" or not section or section.key ~= "general.who" or buttonSection ~= section then
			fail(scenario, "the note and the button are not drawn under step 1 on Start here")
		end
		-- Not while Quick setup asks, which stands in for step 1.
		ns.db.profile.firstRun = "pending"
		if shown(note) ~= false or shown(button) ~= false then fail(scenario, "shown while Quick setup asks") end
		ns.db.profile.firstRun = "answered"
		-- The click: refused in a fight, the setting turned on out of one.
		Mock.inCombat = true
		button.func({})
		if #box.sets > 0 then fail(scenario, "the setting was changed in a fight") end
		Mock.inCombat = false
		button.func({})
		if #box.sets ~= 1 or box.sets[1][1] ~= case.cvar or tostring(box.sets[1][2]) ~= "1" then
			fail(scenario, ("the click made %d changes"):format(#box.sets))
		end
		if shown(note) ~= false or shown(button) ~= false then fail(scenario, "still asking with the nameplates on") end
		if warn(ns) ~= false then fail(scenario, "the red dot stayed with the nameplates on") end
	end)
end

-- Passers-by off: nothing to ask for.
do
	local scenario = "plates-cta: Start here says nothing with passers-by off"
	session(scenario, CASES[1], "0", function(ns)
		ns.db.profile.sources.strangers = false
		if shown(control(ns, "general", "startPlatesNote")) ~= false
			or shown(control(ns, "general", "startShowPlates")) ~= false then
			fail(scenario, "Start here asks for the nameplates with passers-by off")
		end
	end)
end
