-- The states tools/render_prompt.py draws, and the addon loaded to draw them.
--
-- Each state is the addon on the mock client, driven the way a scenario drives
-- it, and then left alone: the renderer reads the frame tree tests/frametree.lua
-- recorded and draws what the client would. A state does not paint anything
-- itself -- if it set a colour directly, the picture would be of the state and
-- not of the addon.
--
-- `at` is how far into its animations the picture is taken, in seconds after
-- the last thing the state did. A pulse is drawn near its brightest and a flash
-- a moment after it starts, because a still of an effect at its first frame is
-- a still of nothing.

-- `dir` holds the mock and the recorder; `addonDir` holds the addon being
-- drawn. They differ when an older build is drawn with today's renderer, which
-- is the only fair way to put a before and an after side by side.
local dir, addonDir = ...
addonDir = addonDir or dir

dofile(dir .. "/tests/mockapi.lua")
dofile(dir .. "/tests/frametree.lua")

local R = {}
-- What the drawn build's own toc loads, so an older checkout is drawn with its
-- own file list and today's picks up the ledger and the locales.
local FILES = dofile(dir .. "/tests/addonfiles.lua")(addonDir)

-- Only the units a state names exist; everybody else is nobody. The mock's
-- default answers yes for every token, which would put the same person on the
-- panel through five of them.
local realUnitExists = UnitExists
local realInParty, realInSubgroup = UnitInParty, UnitInSubgroup
-- The mock answers "in my party" for every unit once there is a group at all;
-- a picture of the list wants the party to be the party tokens and nobody else.
local function partyIsParty()
	UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party") ~= nil end
	UnitInSubgroup = UnitInParty
end
local function people(names)
	Mock.unitNames = names
	UnitExists = function(unit)
		if unit == "player" then return true end
		return names[unit] ~= nil
	end
end

local function load()
	Mock.reset()
	UnitExists = realUnitExists
	UnitInParty, UnitInSubgroup = realInParty, realInSubgroup
	FrameTree.uninstall()
	FrameTree.install()
	local ns = {}
	for _, file in ipairs(FILES) do
		local chunk, err = loadfile(addonDir .. "/" .. file)
		if not chunk then error("load " .. file .. ": " .. tostring(err)) end
		chunk("Manners", ns)
	end
	return ns
end

-- Up and running with nobody about, the clock well past the login and every
-- cooldown, and the nameplates the state names registered with the scan.
local function boot(ns, names)
	people(names or {})
	ns.addon:OnInitialize()
	ns.addon:OnEnable()
	ns.addon:PLAYER_ENTERING_WORLD()
	Mock.runTimers(3)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.pendingClick = nil
	for unit in pairs(names or {}) do
		if unit:find("^nameplate") then ns.nameplateUnits[unit] = true end
	end
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.Prompt:ApplyStyle()
	return ns
end

local function owe(ns, name)
	ns.owed[name] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
end

local function tick(ns)
	ns.addon:Tick()
	FrameTree.settle()
end

local STRANGER = { nameplate1 = { "Brannoc", "Vale" } }
local OWED = { nameplate1 = { "Anna", "Aim" } }

local function withPrompt(edit)
	return function(ns)
		boot(ns, OWED)
		if edit then edit(ns.db.profile.prompt, ns) end
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		tick(ns)
	end
end

-- The order is the contact sheet's.
R.states = {
	{ key = "idle", title = "Idle -- nobody to buff", setup = function(ns)
		boot(ns, {})
		tick(ns)
	end },
	{ key = "owed", title = "Somebody buffed you (pulse)", at = 0.85, setup = function(ns)
		boot(ns, OWED)
		owe(ns, "Anna Aim")
		tick(ns)
	end },
	{ key = "owed-arrival", title = "The moment they buffed you", at = 0.32, setup = function(ns)
		boot(ns, OWED)
		owe(ns, "Anna Aim")
		tick(ns)
	end },
	{ key = "group", title = "A group member", setup = function(ns)
		Mock.groupSize = 2
		boot(ns, { party1 = { "Gwen", "Hollow" } })
		tick(ns)
	end },
	{ key = "stranger", title = "A stranger nearby", setup = function(ns)
		boot(ns, STRANGER)
		tick(ns)
	end },
	{ key = "target", title = "Your target", setup = function(ns)
		boot(ns, { target = { "Tamsin", "Reed" } })
		tick(ns)
	end },
	{ key = "refused", title = "A refused buff", at = 0.15, setup = function(ns)
		boot(ns, OWED)
		owe(ns, "Anna Aim")
		tick(ns)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		FrameTree.settle()
	end },
	{ key = "success", title = "A buff that landed", at = 0.28, setup = function(ns)
		boot(ns, OWED)
		owe(ns, "Anna Aim")
		tick(ns)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		FrameTree.settle()
	end },
	{ key = "leaving", title = "After the last buff", at = 0.48, setup = function(ns)
		boot(ns, OWED)
		owe(ns, "Anna Aim")
		tick(ns)
		-- What a press does to the only person on the prompt: they are
		-- retired for the retry cooldown, so the queue behind the flash is
		-- empty and the panel is on its way down.
		ns.BlockPerson("Anna Aim")
		wipe(ns.owed)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		FrameTree.settle()
	end },
	{ key = "calm", title = "A buff that landed, Effects: Calm", at = 0.28, setup = function(ns)
		boot(ns, OWED)
		ns.db.profile.prompt.effects = "calm"
		owe(ns, "Anna Aim")
		tick(ns)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		FrameTree.settle()
	end },
	{ key = "sent", title = "Sent, unconfirmed", at = 0.15, setup = function(ns)
		boot(ns, OWED)
		owe(ns, "Anna Aim")
		tick(ns)
		ns.Prompt:ShowOutcome("sent", "Anna Aim")
		FrameTree.settle()
	end },
	{ key = "gcd", title = "Global cooldown running", at = 0.5, setup = function(ns)
		boot(ns, OWED)
		owe(ns, "Anna Aim")
		tick(ns)
		-- A cast that went out half a second ago, as the client reports it.
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
		if ns.addon.UNIT_SPELLCAST_SENT then
			ns.Guard("sent", ns.addon.UNIT_SPELLCAST_SENT, ns.addon, nil, "player", nil, nil, 1459)
		end
		tick(ns)
	end },
	{ key = "combat", title = "Held in combat", at = 0.85, setup = function(ns)
		boot(ns, OWED)
		owe(ns, "Anna Aim")
		tick(ns)
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		tick(ns)
	end },
	{ key = "queue", title = "Queue list shown", at = 0.85, setup = function(ns)
		Mock.groupSize = 2
		partyIsParty()
		boot(ns, { party1 = { "Gwen", "Hollow" }, nameplate1 = { "Anna", "Aim" },
			nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" } })
		ns.db.profile.prompt.showQueue = true
		ns.db.profile.prompt.queueRows = 3
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		tick(ns)
	end },
	{ key = "preview", title = "Preview", at = 0.85, setup = function(ns)
		boot(ns, {})
		Mock.optionsOpen = true
		ns.Prompt:ToggleTest()
		FrameTree.settle()
	end },
	{ key = "unlocked", title = "Unlocked to drag", setup = function(ns)
		boot(ns, OWED)
		ns.db.profile.prompt.locked = false
		ns.Prompt:ApplyStyle()
		tick(ns)
	end },
	{ key = "framed", title = "Look: framed", at = 0.85, setup = withPrompt(function(p)
		p.style = "framed"
	end) },
	{ key = "minimal", title = "Look: minimal", at = 0.85, setup = withPrompt(function(p)
		p.style = "minimal"
	end) },
	{ key = "stripe", title = "Reason colour: stripe", at = 0.85, setup = withPrompt(function(p)
		p.accentMode = "stripe"
	end) },
	{ key = "both", title = "Reason colour: both", at = 0.85, setup = withPrompt(function(p)
		p.accentMode = "both"
	end) },
	{ key = "noaccent", title = "Reason colour: neither", at = 0.85, setup = withPrompt(function(p)
		p.accentMode = "off"
	end) },
	{ key = "accent", title = "One accent colour", at = 0.85, setup = withPrompt(function(p)
		p.accentByReason = false
		p.accentColor = { 0.85, 0.35, 0.75, 1 }
	end) },
	{ key = "lightpanel", title = "A light panel colour", at = 0.85, setup = withPrompt(function(p)
		p.bgColor = { 0.86, 0.84, 0.78, 0.92 }
		p.fontColor = { 0.10, 0.10, 0.12, 1 }
	end) },
	{ key = "round", title = "Round icon", at = 0.85, setup = withPrompt(function(p)
		p.roundIcon = true
	end) },
	{ key = "small", title = "Scale 0.7", at = 0.85, setup = withPrompt(function(p)
		p.scale = 0.7
	end) },
	{ key = "large", title = "Scale 1.6", at = 0.85, setup = withPrompt(function(p)
		p.scale = 1.6
	end) },
}

-- Any extra states a newer addon adds, by key, so an old and a new tree can be
-- asked for the same list and the one that lacks a state simply leaves a gap.
function R.find(key)
	for _, s in ipairs(R.states) do
		if s.key == key then return s end
	end
end

function R.keys()
	local out = {}
	for i, s in ipairs(R.states) do out[i] = s.key end
	return out
end

-- One state, drawn: the tree under UIParent, the button's id so the picture
-- can be framed on it, and the clock the animations are to be read at.
function R.run(key)
	local state = R.find(key)
	if not state then return nil end
	local ns = load()
	local ok, err = pcall(state.setup, ns)
	UnitExists = realUnitExists
	UnitInParty, UnitInSubgroup = realInParty, realInSubgroup
	if not ok then error("state " .. key .. ": " .. tostring(err)) end
	local button = ns.Prompt:GetButton()
	return {
		tree = FrameTree.snapshot(UIParent),
		button = button and button._serial,
		now = Mock.now + (state.at or 0),
		title = state.title,
		screen = { width = 1600, height = Mock.screenHeight or 1000 },
		errors = ns.errors and #ns.errors or 0,
		firstError = ns.errors and ns.errors[1] and (tostring(ns.errors[1].where) .. " -> "
			.. tostring(ns.errors[1].err)) or nil,
	}
end

return R
