-- Will of the Forsaken's need (Prompt/BreakFree.lua, GitHub issue 33): under
-- Show the fight buttons at Only when needed the button is out of sight until
-- the client says you are feared, charmed or asleep. Where the game withholds
-- the answer (a secret type, record or count) or has no loss-of-control API,
-- losing control of your character in the fight is the need itself:
-- PLAYER_CONTROL_LOST, or a LOSS_OF_CONTROL_ADDED whose type is secret. The
-- guess ends on PLAYER_CONTROL_GAINED, HasFullControl plainly true, the
-- fight's release, or ten seconds after the last such event when
-- HasFullControl cannot be read. A plain read stays the authority, and a fear
-- reported by mechanic (FEAR_MECHANIC) is a fear.
--
-- These hold Manners to the mock's model of the client (C_LossOfControl in its
-- shapes, UnitIsCharmed and HasFullControl in tests/mockapi.lua), not to the
-- client: which loss of control Forever reports, and whether it is plain
-- there, only a real fear can say (STATUS.md).
--
-- Every name starts with "wotfneed:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local COMMAND = "CLICK MannersBreakFree:LeftButton"
local SPELL = "Will of the Forsaken"
local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bob", "Bright" }, nameplate3 = { "Cara", "Cole" } }
local NAMES = { "Anna Aim", "Bob Bright", "Cara Cole" }

-- Forever unless a scenario names the client: a Forsaken who knows Will of
-- the Forsaken, its key on F, three people on nameplates all owed and the
-- prompt up on one of them. opts.shape (the loss-of-control API's),
-- opts.flavour, opts.nobody (nobody owed), opts.control (what HasFullControl
-- answers for the whole run: true, false or "secret"; unset leaves the
-- mock's own, which says control is gone while a loss of control is listed).
local function with(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.playerRace = "Scourge"
	Mock.knownSpells = { [7744] = true }
	Mock.lossOfControlShape = opts.shape
	local restore = strangers(opts.people or PEOPLE)
	local realControl = _G.HasFullControl
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			-- Switched on, as a player who ticked it has (off by default since 1.12).
			ns.defaults.profile.prompt.breakFree = true
			freshPrompt(ns, scenario)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			ns.db.profile.verbose = true
			ns.Prompt:ApplyStyle()
			Mock.bindings = Mock.bindings or {}
			Mock.bindings.F = COMMAND
			if not opts.nobody then
				for _, name in ipairs(NAMES) do owe(ns, name) end
			end
			ns.addon:Tick()
			Mock.runTimers(0)
			if opts.control ~= nil then
				local answer = opts.control
				if answer == "secret" then answer = Mock.SECRET end
				rawset(_G, "HasFullControl", function() return answer end)
			end
			body(ns, scenario)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	rawset(_G, "HasFullControl", realControl)
	Mock.inCombat = false
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

-- A loss of control of `kind` beginning, and every one ending.
local function lose(kind)
	Mock.lossOfControl = { { locType = kind or "FEAR", spellID = 5782 } }
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
end
local function regain()
	Mock.lossOfControl = {}
	Mock.charmed = nil
	Mock.frameEvent("LOSS_OF_CONTROL_UPDATE")
	Mock.frameEvent("PLAYER_CONTROL_GAINED")
end

-- Lit (the alpha the fade walks to is 1)...
local function lit(ns)
	local look = ns.BreakFree:Look()
	return look ~= nil and look.alpha == 1
end
-- ...and out of sight (alpha 0).
local function away(ns)
	local look = ns.BreakFree:Look()
	return look ~= nil and look.alpha == 0
end

local function promptName(ns)
	return tostring(ns.Prompt:Regions().name:GetText() or "")
end

local function option(ns, key)
	local look = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
	return look and look.args and look.args[key]
end

-- ------------------------------------------------------------------ 1
with("wotfneed: a fear by mechanic lights it", function(ns, scenario)
	pull(ns)
	if not away(ns) then fail(scenario, "not out of sight before any fear") end
	lose("FEAR_MECHANIC")
	if not lit(ns) then fail(scenario, "not lit for a fear by mechanic") end
	regain()
	if not away(ns) then fail(scenario, "still in sight once it ended") end
	release(ns)
end, { nobody = true, people = {} })

-- ------------------------------------------------------------------ 2
-- The game would not name what took your control: a secret type, and only the
-- loss-of-control event to say anything happened.
with("wotfneed: a secret loss of control lights it while you have lost control", function(ns, scenario)
	pull(ns)
	if not ns.Prompt:GetButton():IsShown() then fail(scenario, "SKIPPED -- the prompt was not up") return end
	Mock.lossOfControl = { { locType = Mock.SECRET } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
	if not lit(ns) then fail(scenario, "not lit for a secret loss of control") end
	local name = promptName(ns)
	if not name:find("Break free", 1, true) then fail(scenario, "the prompt reads " .. name) end
	regain()
	if not away(ns) then fail(scenario, "still in sight once control was back") end
	release(ns)
end)

-- ------------------------------------------------------------------ 3
-- Nothing is readable: the count, the charm and HasFullControl are all
-- secret. Control lost is the need; control gained alone ends it.
with("wotfneed: a secret count and a secret charm with control lost light it", function(ns, scenario)
	pull(ns)
	Mock.lossOfControlCount = Mock.SECRET
	Mock.charmed = Mock.SECRET
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	if not lit(ns) then fail(scenario, "not lit with control lost and nothing readable") end
	Mock.frameEvent("PLAYER_CONTROL_GAINED")
	if not away(ns) then fail(scenario, "still in sight after control was gained") end
	release(ns)
end, { nobody = true, people = {}, control = "secret" })

-- ------------------------------------------------------------------ 4
for _, flavour in ipairs({ "camelot", "vanilla" }) do
	with("wotfneed: no loss-of-control API, a fear lights it (" .. flavour .. ")", function(ns, scenario)
		if not ns.BreakFree:Button() then fail(scenario, "no button on " .. flavour) return end
		pull(ns)
		lose("FEAR")
		if not lit(ns) then fail(scenario, "not lit for a fear with no API to report one") end
		regain()
		if not away(ns) then fail(scenario, "still in sight once control was back") end
		release(ns)
	end, { flavour = flavour, shape = "none", nobody = true, people = {} })
end

-- ------------------------------------------------------------------ 5
with("wotfneed: a secret report while you plainly have control is no reason", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = { { locType = Mock.SECRET } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
	if not away(ns) then fail(scenario, "lit while HasFullControl plainly says you have control") end
	release(ns)
end, { nobody = true, people = {}, control = true })

-- ------------------------------------------------------------------ 6
-- Nothing says it ended and nothing can be read: the guess lasts ten seconds.
with("wotfneed: a withheld read with nothing to say it ended gives up after ten seconds", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = { { locType = Mock.SECRET } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
	if not lit(ns) then fail(scenario, "SKIPPED -- not lit") return end
	Mock.advance(5)
	Mock.runTimers(1)
	if not lit(ns) then fail(scenario, "given up after six seconds") end
	Mock.advance(11)
	Mock.runTimers(1)
	if not away(ns) then fail(scenario, "still lit eleven seconds after the last word of it") end
	release(ns)
end, { nobody = true, people = {}, control = "secret" })

-- ------------------------------------------------------------------ 7
with("wotfneed: a plain stun with control lost is no reason", function(ns, scenario)
	pull(ns)
	lose("STUN")
	if not away(ns) then fail(scenario, "lit for a plain stun") end
	if promptName(ns):find("Break free", 1, true) then fail(scenario, "the prompt names it for a plain stun") end
	release(ns)
end)

-- ------------------------------------------------------------------ 8
with("wotfneed: a plain empty report and a secret charm are no reason", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = {}
	Mock.charmed = Mock.SECRET
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	if not away(ns) then fail(scenario, "lit for a plain empty report") end
	release(ns)
end, { nobody = true, people = {}, control = false })

-- ------------------------------------------------------------------ 9
with("wotfneed: the guess ends with the fight", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = { { locType = Mock.SECRET } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
	if not lit(ns) then fail(scenario, "SKIPPED -- not lit") return end
	release(ns)
	pull(ns)
	if not away(ns) then fail(scenario, "the next fight began with it lit") end
	release(ns)
end, { nobody = true, people = {}, control = "secret" })

-- ------------------------------------------------------------------ 10
with("wotfneed: the switch's tooltip says when it shows", function(ns, scenario)
	local switch = option(ns, "breakFree")
	if not switch then fail(scenario, "no switch") return end
	local desc = type(switch.desc) == "function" and switch.desc() or switch.desc
	if type(desc) ~= "string" or not desc:find("whenever you lose control of your character", 1, true) then
		fail(scenario, "the switch's tooltip reads " .. tostring(desc))
	end
end)

-- ------------------------------------------------------------------ 11
with("wotfneed: debug says it came up on a loss of control the game would not name", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = { { locType = Mock.SECRET } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
	if not lit(ns) then fail(scenario, "SKIPPED -- not lit") return end
	local lines = table.concat(ns.BreakFreeLines(), " / ")
	if not lines:find("a loss of control the game would not name", 1, true) then
		fail(scenario, "/manners debug does not say it was a guess: " .. lines)
	end
	release(ns)
end, { nobody = true, people = {} })

-- ------------------------------------------------------------------ 12
-- The API is read in whichever shape the client has: a plain stun with control
-- lost is told apart from a fear only by reading it, so an API left unread
-- would be taken for "no API" and guessed at.
for _, row in ipairs({ { "data", "wotfneed: a plain stun is read as one in the data shape" },
	{ "events", "wotfneed: a plain stun is read as one in the events shape" } }) do
	local shape = row[1]
	with(row[2], function(ns, scenario)
		pull(ns)
		lose("STUN")
		if not away(ns) then fail(scenario, "lit for a plain stun") end
		lose("FEAR")
		if not lit(ns) then fail(scenario, "not lit for a plain fear") end
		release(ns)
	end, { shape = shape, nobody = true, people = {} })
end
