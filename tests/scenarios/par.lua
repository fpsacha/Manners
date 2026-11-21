-- The game's friendly nameplates off, as a fresh install has them. On WoW
-- Forever, with no combat log, a stranger's buff is named only through a
-- token (Favours.lua, Sight), and with the nameplates off a passer-by has
-- none: the buff lands, nothing comes up and nothing is said. Before this,
-- the greeting promised strangers anyway, the launcher said "Watching for
-- people to buff." in green, and Start here's red note was hidden exactly
-- while a new profile's Quick setup was asking.
--
-- So it is said where every player looks:
--   * the greeting, in red, with the button that fixes it (Commands.lua);
--   * Start here's note and button while Quick setup asks too, for a pick
--     that offers to passers-by (Options/Start.lua);
--   * the launcher's state, amber, and the options window's strip with the
--     same button beside it (Options/Launcher.lua, WindowChrome.lua);
--   * a line when a stranger's class buff lands with nobody to name, once a
--     session and on three sessions at most (Favours.lua, Hints.lua).
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- scenario name starts with "par:" so the mutations in tests/mutations/par.py
-- can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local CVAR = "nameplateShowFriendlyPlayers"

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The client's settings as GetCVar and SetCVar see them, every SetCVar
-- written down.
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

-- One session with the nameplates as `plates`; `driven` false for a first
-- login the body makes itself.
local function session(scenario, plates, body, driven)
	local box, restore = cvars({ [CVAR] = plates })
	Mock.reset()
	Mock.class = "MAGE"
	local ns
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		if driven ~= false then
			drive(scenario, ns)
			ns.db.profile.firstRun = "answered"
			ns.db.profile.sources.strangers = true
		end
		body(ns, box)
	end)
	if ns then pcall(ns.CloseOptions) end
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	if ns then noErrors(scenario, ns) end
end

local function said(pattern)
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(pattern, 1, true) then return tostring(line) end
	end
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

-- ---------------------------------------------------------------- greeting
local function firstLogin(ns)
	Mock.printed = {}
	ns.addon:OnInitialize()
	ns.addon:OnEnable()
	ns.addon:PLAYER_ENTERING_WORLD()
	for _ = 1, 4 do Mock.runTimers(1) end
end

do
	local scenario = "par: the greeting says the nameplates are off"
	session(scenario, "0", function(ns)
		firstLogin(ns)
		if not said("puts anybody who buffs you") then
			fail(scenario, "no greeting at the first login")
			return
		end
		local line = said("Friendly nameplates are off")
		if not line then
			fail(scenario, "the greeting promises strangers and says nothing of the nameplates")
		elseif not (line:find("|cffff8080", 1, true) and line:find("Show friendly nameplates", 1, true)
			and line:find("Start here", 1, true)) then
			fail(scenario, "the line is not red or does not name the button and its page: " .. line)
		end
	end, false)
end

do
	local scenario = "par: the greeting says nothing of nameplates that are on"
	session(scenario, "1", function(ns)
		firstLogin(ns)
		if said("Friendly nameplates are off") then fail(scenario, "the nameplates are on and the greeting says off") end
	end, false)
end

-- ------------------------------------------------------- Start here, Quick setup
do
	local scenario = "par: Start here asks for the nameplates while Quick setup asks"
	session(scenario, "0", function(ns, box)
		ns.db.profile.firstRun = "pending"
		local Quick = ns.QuickSetup
		if not (Quick and Quick.Asking()) then
			fail(scenario, "Quick setup is not asking")
			return
		end
		local note, button = control(ns, "general", "startPlatesNote"), control(ns, "general", "startShowPlates")
		Quick.SetFirstPick(Quick.WHO, "nearby")
		if shown(note) ~= true or shown(button) ~= true then
			fail(scenario, ("Everyone near me picked: the note is %s and the button %s")
				:format(tostring(shown(note)), tostring(shown(button))))
		end
		-- Under a title of their own, not a second "1." under Quick setup's.
		local head = control(ns, "general", "whoHeader")
		local title = head and head.name
		if type(title) == "function" then title = title({}) end
		if title ~= "Seeing passers-by" then fail(scenario, "the call is titled " .. tostring(title) .. " while Quick setup asks") end
		-- Drawn in the window, not only unhidden in the model.
		ns.OpenOptions("general")
		local UI = ns.WindowUI
		if not (UI.RowShown("general.startPlatesNote") and UI.RowShown("general.startShowPlates")) then
			fail(scenario, "the note and the button are not drawn on Start here while Quick setup asks")
		end
		-- A pick that offers to nobody outside the group has no use for them.
		Quick.SetFirstPick(Quick.WHO, "group")
		if shown(note) ~= false or shown(button) ~= false then
			fail(scenario, "My group picked, and Start here still asks for the nameplates")
		end
		Quick.SetFirstPick(Quick.WHO, "nearby")
		button.func({})
		if #box.sets ~= 1 or box.sets[1][1] ~= CVAR then fail(scenario, "the button did not turn them on") end
		if shown(note) ~= false then fail(scenario, "still asking with the nameplates on") end
	end)
end

-- ---------------------------------------------------- launcher and strip
do
	local scenario = "par: the launcher says passers-by go unseen"
	session(scenario, "0", function(ns, box)
		local watching, line, r, g, b, _, _, kind = ns.LauncherState()
		if kind ~= "plates" then
			fail(scenario, "nameplates off reads as " .. tostring(kind) .. ": " .. tostring(line))
			return
		end
		if watching ~= true then fail(scenario, "the group is still watched, and the launcher says not") end
		if not (r == 1 and g > 0.7 and b == 0) then fail(scenario, "the line is not amber") end
		if not tostring(line):find("friendly nameplates are off", 1, true) then fail(scenario, "the line says " .. tostring(line)) end
		box.values[CVAR] = "1"
		if select(8, ns.LauncherState()) ~= "watching" then fail(scenario, "the nameplates on and still warned") end
		box.values[CVAR] = "0"
		ns.db.profile.sources.strangers = false
		if select(8, ns.LauncherState()) ~= "watching" then fail(scenario, "passers-by off and still warned") end
	end)
end

do
	local scenario = "par: the options window's strip has the button"
	session(scenario, "0", function(ns, box)
		ns.OpenOptions("when")
		local UI = ns.WindowUI
		local strip = UI.strip
		if not (strip.line and strip.line:find("friendly nameplates are off", 1, true)) then
			fail(scenario, "When to offer's strip says " .. tostring(strip.line))
			return
		end
		local button = strip.plates
		if not (button and button:IsShown()) then
			fail(scenario, "no Show friendly nameplates button on the strip")
			return
		end
		-- Start here and Who to buff carry the note and the button themselves.
		ns.OpenOptions("general")
		if strip.kind == "plates" or button:IsShown() then fail(scenario, "Start here says it twice") end
		ns.OpenOptions("when")
		local click = button:GetScript("OnClick")
		click(button, "LeftButton")
		if #box.sets ~= 1 or box.sets[1][1] ~= CVAR then
			fail(scenario, ("the strip's button made %d changes"):format(#box.sets))
		end
		if button:IsShown() or strip.kind == "plates" then fail(scenario, "the strip still asks with the nameplates on") end
	end)
end

-- ------------------------------------------------- a buff with nobody to name
-- A class buff lands from a caster the game gives no token for (Mock's extra
-- aura with no source): Power Word: Fortitude, rank 1.
local function land(ns, instance, source)
	Mock.extraAura = instance
	Mock.extraAuraSpell = 1243
	Mock.extraAuraSource = source
	ns.addon:UNIT_AURA(nil, "player")
	Mock.advance(1)
	ns.addon:UNIT_AURA(nil, "player")
	ns.addon:Tick()
end

local function primed(ns)
	ns.Prompt:ExitTest()
	Mock.auraCount = 8
	for _ = 1, 30 do Mock.runTimers(0.2) end
	Mock.printed = {}
end

local UNNAMED = "the game would not say who"

do
	local scenario = "par: a stranger's buff with nobody to name says why, once"
	session(scenario, "0", function(ns)
		primed(ns)
		land(ns, 3501, nil)
		-- The line waits for the landing's window to close (the cast watch), so that
		-- it is said only when nobody was named.
		Mock.runTimers(2)
		local line = said(UNNAMED)
		if not line then
			fail(scenario, "a Fortitude from nobody the game would name, and nothing said")
			return
		end
		if not line:find("Show friendly nameplates", 1, true) then fail(scenario, "the line names no way out: " .. line) end
		Mock.printed = {}
		Mock.extraAura = false
		ns.addon:UNIT_AURA(nil, "player")
		Mock.advance(1)
		land(ns, 3502, nil)
		Mock.runTimers(2)
		if said(UNNAMED) then fail(scenario, "said twice in a session") end
		local hints = ns.db.char.hints
		if not (type(hints) == "table" and hints.unnamed == 1) then fail(scenario, "the session is not counted") end
	end)
end

do
	local scenario = "par: a buff with nobody to name is quiet with the nameplates on"
	session(scenario, "1", function(ns)
		primed(ns)
		land(ns, 3501, nil)
		Mock.runTimers(2)
		if said(UNNAMED) then fail(scenario, "the nameplates are on, and the line blames them") end
	end)
end

do
	local scenario = "par: a buff with nobody to name is quiet in a fight"
	session(scenario, "0", function(ns)
		primed(ns)
		Mock.inCombat = true
		land(ns, 3501, nil)
		Mock.runTimers(2)
		Mock.inCombat = false
		if said(UNNAMED) then fail(scenario, "said in a fight, where a withheld caster looks the same") end
	end)
end

do
	local scenario = "par: a named buff says nothing of the nameplates"
	session(scenario, "0", function(ns)
		primed(ns)
		land(ns, 3501, "nameplate1")
		-- Counted as told even where an earlier reading used the session's line up.
		local hints = ns.db.char.hints
		if said(UNNAMED) or (type(hints) == "table" and hints.unnamed) then
			fail(scenario, "a buff from somebody named, and the line says nobody")
		end
		if not said("buffed you") then fail(scenario, "the named favour was not announced") end
	end)
end

do
	local scenario = "par: a buff with nobody to name stops after three sessions"
	session(scenario, "0", function(ns)
		ns.db.char.hints = { unnamed = 3 }
		primed(ns)
		land(ns, 3501, nil)
		Mock.runTimers(2)
		if said(UNNAMED) then fail(scenario, "said on a fourth session") end
	end)
end
