-- Hunt 39, the press: the hand-back when the player had no target.
--
-- "Hand my target back" ends the macro with /targetlasttarget, which brings
-- back the target before the one the macro took. A player with nothing
-- targeted when the button is armed has nothing to get back, and the client's
-- last target may be one cleared minutes ago (a mob that died): the press then
-- left them holding it. With no target the macro clears instead
-- (/cleartarget), so they end as they began. The macro armed for a fight is
-- frozen for every press in it, whatever is targeted by then, so it keeps
-- /targetlasttarget, which hands back whatever the player had picked.
--
-- Every scenario name starts with "hunt39-press:" so the mutations in
-- tests/mutations/hunt39-press.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end
local function lastLine(text)
	return tostring(text or ""):match("([^\n]*)$")
end

-- Whether the player has a target, as UnitGUID("target") tells it.
local realGuid = UnitGUID
local hasTarget = true
local function targeting(on)
	hasTarget = on
	UnitGUID = function(unit)
		if unit == "target" and not hasTarget then return nil end
		return realGuid(unit)
	end
end

local function session(scenario, body, opts)
	Mock.reset()
	opts = opts or {}
	if opts.class then Mock.class = opts.class end
	local people = opts.people or { nameplate1 = { "Anna", "Aim" } }
	local restore = strangers(people)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		targeting(opts.target ~= false)
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	UnitGUID = realGuid
	hasTarget = true
	Mock.inCombat = false
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function aim(ns)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
end

-- ------------------------------------------------------------------ the line
do
	local scenario = "hunt39-press: no target when armed, the hand-back clears the target"
	session(scenario, function(ns)
		aim(ns)
		local text = macro(ns)
		if lastLine(text) ~= "/cleartarget" then
			fail(scenario, "with nothing targeted the macro ends " .. flat(text))
		end
		if text and text:find("/targetlasttarget", 1, true) then
			fail(scenario, "with nothing targeted the macro still hands back a stale target: " .. flat(text))
		end
		if not (text and text:find("/target Anna Aim\n/cast ", 1, true)) then
			fail(scenario, "the cast is not aimed at Anna: " .. flat(text))
		end
	end, { target = false })

	scenario = "hunt39-press: a target when armed is handed back as before"
	session(scenario, function(ns)
		aim(ns)
		local text = macro(ns)
		if lastLine(text) ~= "/targetlasttarget" then
			fail(scenario, "with a target the macro ends " .. flat(text))
		end
	end)

	scenario = "hunt39-press: with the switch off nothing is handed back or cleared"
	session(scenario, function(ns)
		ns.db.profile.filters.restoreTarget = false
		ns.Prompt:InvalidateMacro()
		aim(ns)
		local text = macro(ns)
		if text and (text:find("/targetlasttarget", 1, true) or text:find("/cleartarget", 1, true)) then
			fail(scenario, "the switch is off and the macro hands back anyway: " .. flat(text))
		end
	end, { target = false })

	scenario = "hunt39-press: your own buff with no target clears it afterwards"
	session(scenario, function(ns)
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(0.5)
		ns.addon:Tick()
		local text = macro(ns)
		if not (text and text:find("/target ", 1, true) and text:find("/cast ", 1, true)) then
			fail(scenario, "SKIPPED -- nothing armed on yourself: " .. flat(text))
		elseif lastLine(text) ~= "/cleartarget" then
			fail(scenario, "a press on yourself with nothing targeted ends " .. flat(text))
		end
	end, { target = false, people = {} })
end

-- ------------------------------------------------------------------ re-arming
do
	local scenario = "hunt39-press: the macro follows the target coming and going"
	session(scenario, function(ns)
		aim(ns)
		if lastLine(macro(ns)) ~= "/cleartarget" then
			fail(scenario, "no target: " .. flat(macro(ns)))
		end
		targeting(true)
		Mock.advance(0.5)
		ns.addon:Tick()
		if lastLine(macro(ns)) ~= "/targetlasttarget" then
			fail(scenario, "a target appeared and the macro still ends " .. flat(macro(ns)))
		end
		targeting(false)
		Mock.advance(0.5)
		ns.addon:Tick()
		if lastLine(macro(ns)) ~= "/cleartarget" then
			fail(scenario, "the target went and the macro still ends " .. flat(macro(ns)))
		end
	end, { target = false })

	-- A press re-arms at the last moment, whatever the last repaint saw.
	scenario = "hunt39-press: a press takes the target as it is then"
	session(scenario, function(ns)
		aim(ns)
		targeting(true)
		local ran = H.pressButton(ns)
		if not ran or lastLine(ran) ~= "/targetlasttarget" then
			fail(scenario, "a press after a target appeared ran " .. flat(ran))
		end
	end, { target = false })
end

-- ------------------------------------------------------------------ the fight
do
	local scenario = "hunt39-press: the macro armed for a fight keeps handing back"
	session(scenario, function(ns)
		aim(ns)
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		local text = macro(ns)
		if lastLine(text) ~= "/targetlasttarget" then
			fail(scenario, "the macro armed at the pull ends " .. flat(text))
		end
		-- The player picks a target mid-fight and the macro is not touched.
		targeting(true)
		Mock.protectedCalls = {}
		ns.addon:Tick()
		if macro(ns) ~= text then
			fail(scenario, "the frozen macro changed in the fight: " .. flat(macro(ns)))
		end
		if #Mock.protectedCalls > 0 then
			fail(scenario, "the fight's repaint called " .. table.concat(Mock.protectedCalls, ", "))
		end
	end, { target = false })

	scenario = "hunt39-press: a target that goes in the fight leaves the macro as armed"
	session(scenario, function(ns)
		aim(ns)
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		local armed = macro(ns)
		targeting(false)
		Mock.protectedCalls = {}
		ns.addon:Tick()
		if macro(ns) ~= armed or lastLine(armed) ~= "/targetlasttarget" then
			fail(scenario, "armed for the fight it ends " .. flat(armed) .. ", then " .. flat(macro(ns)))
		end
		if #Mock.protectedCalls > 0 then
			fail(scenario, "the fight's repaint called " .. table.concat(Mock.protectedCalls, ", "))
		end
	end)
end

-- ------------------------------------------------------------------ the room
do
	local scenario = "hunt39-press: the spoken line gets the room the shorter hand-back leaves"
	session(scenario, function(ns)
		local speech = ns.db.profile.speech
		speech.enabled = true
		speech.onlyWhenReturning = false
		speech.channel = "SAY"
		aim(ns)
		local entry = H.inQueue(ns)["Anna Aim"]
		if not entry then
			fail(scenario, "SKIPPED -- Anna is not in the queue")
			return
		end
		local clear = ns.PhraseBudget(entry)
		targeting(true)
		local last = ns.PhraseBudget(entry)
		if clear - last ~= #"/targetlasttarget" - #"/cleartarget" then
			fail(scenario, ("the room is %d with no target and %d with one"):format(clear, last))
		end
		for _, state in ipairs({ false, true }) do
			targeting(state)
			local room = ns.PhraseBudget(entry) - #"/say "
			speech.phrases = string.rep("a", room)
			ns.Prompt:InvalidateMacro()
			Mock.advance(0.5)
			ns.addon:Tick()
			local text = macro(ns)
			if not (text and text:find("/say " .. string.rep("a", room), 1, true)) then
				fail(scenario, ("the line that fits exactly (target %s) was left out: %s"):format(
					tostring(state), flat(text)))
			elseif #text ~= ns.MACRO_LIMIT then
				fail(scenario, ("target %s: the macro is %d characters, not %d"):format(
					tostring(state), #text, ns.MACRO_LIMIT))
			end
			speech.phrases = string.rep("a", room + 1)
			ns.Prompt:InvalidateMacro()
			Mock.advance(0.5)
			ns.addon:Tick()
			text = macro(ns)
			if #tostring(text) > ns.MACRO_LIMIT then
				fail(scenario, ("target %s: a line one too long overran the macro: %d"):format(
					tostring(state), #text))
			end
		end
	end, { target = false })
end
