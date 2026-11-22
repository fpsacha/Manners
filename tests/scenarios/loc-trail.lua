-- The trail's line for a loss of control (Prompt/BreakFree.lua): one line for
-- one loss however many times the client tells it, written after the button has
-- been painted so it can say whether break free lit, and only for the player's
-- own unit (the client may send LOSS_OF_CONTROL_ADDED for others too).
--
-- Every name starts with "loc-trail:".

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


-- The trail's lines holding `needle`.
local function trailLines(ns, needle)
	local out = {}
	for _, t in ipairs(ns.db.char.trail or {}) do
		if t.text:find(needle, 1, true) then out[#out + 1] = t.text end
	end
	return out
end

local function told(unit)
	Mock.lossOfControl = { { locType = "FEAR", spellID = 5782 } }
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", unit or "player", 1)
end

with("loc-trail: one loss of control told twice is one trail line", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = { { locType = "FEAR", spellID = 5782 } }
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", "player", 1)
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", "player", 1)
	local lines = trailLines(ns, "loss of control: ")
	if #lines ~= 1 then fail(scenario, #lines .. " trail lines, not 1: " .. table.concat(lines, " | ")) end
	release(ns)
end, { nobody = true, people = {} })

with("loc-trail: two losses a second apart are two lines", function(ns, scenario)
	pull(ns)
	told()
	Mock.advance(1)
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", "player", 2)
	local lines = trailLines(ns, "loss of control: ")
	if #lines ~= 2 then fail(scenario, #lines .. " trail lines, not 2: " .. table.concat(lines, " | ")) end
	release(ns)
end, { nobody = true, people = {} })

with("loc-trail: the line says break free was lit", function(ns, scenario)
	pull(ns)
	told()
	local lines = trailLines(ns, "loss of control: ")
	if #lines ~= 1 then fail(scenario, "SKIPPED -- " .. #lines .. " trail lines") return end
	if not lit(ns) then fail(scenario, "SKIPPED -- the button did not light") return end
	if not lines[1]:find("break free lit", 1, true) then fail(scenario, "the line does not say it lit: " .. lines[1]) end
	release(ns)
end, { nobody = true, people = {} })

with("loc-trail: a loss you keep control through says not lit", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = { { locType = Mock.SECRET } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", "player", 1)
	local lines = trailLines(ns, "loss of control: ")
	if #lines ~= 1 then fail(scenario, "SKIPPED -- " .. #lines .. " trail lines") return end
	if not lines[1]:find("break free not lit", 1, true) then fail(scenario, "the line does not say it stayed dark: " .. lines[1]) end
	release(ns)
end, { nobody = true, people = {}, control = true })

with("loc-trail: a loss of control on another unit writes nothing and lights nothing", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = { { locType = "FEAR", spellID = 5782 } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", "pet", 1)
	if #trailLines(ns, "loss of control: ") ~= 0 then fail(scenario, "a pet's loss of control was written") end
	if not away(ns) then fail(scenario, "lit for another unit's loss of control") end
	release(ns)
end, { nobody = true, people = {} })

with("loc-trail: with the switch off the line says not shown", function(ns, scenario)
	-- The button was made while the switch was on; then the switch goes off.
	ns.db.profile.prompt.breakFree = false
	ns.addon:Tick()
	Mock.runTimers(0)
	pull(ns)
	told()
	Mock.lossOfControl = { { locType = "STUN", spellID = 5782 } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", "player", 1)
	local lines = trailLines(ns, "loss of control: STUN")
	if #lines ~= 1 then fail(scenario, "SKIPPED -- " .. #lines .. " trail lines: " .. table.concat(lines, " | ")) return end
	if not lines[1]:find("not shown", 1, true) then fail(scenario, "the line does not say not shown: " .. lines[1]) end
	if lines[1]:find("break free lit", 1, true) then fail(scenario, "the line says it lit with the switch off: " .. lines[1]) end
	release(ns)
end, { nobody = true, people = {} })
