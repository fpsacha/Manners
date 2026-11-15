-- The fight's three weak points from the review of 2026-11-15 (Prompt/Fight.lua,
-- Prompt/Macro.lua, Prompt/Refresh.lua, Clicks.lua's bar macro):
--
--   1. what the pull arms is somebody worth pressing for, never a passer-by
--      remembered for a few seconds after they walked off;
--   2. the hand-back of a macro armed for a fight runs only when the /target
--      before it found somebody friendly, so a press cannot take a mob away;
--   3. the fight's rota goes round once: nobody it has pressed for in this
--      fight is pressed for again, and the bar macro, which cannot step, says so
--      where it is made.
--
-- These hold Manners to the mock's model of the secure handlers and of the
-- client's macro runner (tests/mockwidgets.lua, tests/mockmacros.lua), not to
-- the client: STATUS.md lists what a real fight must show.
--
-- Every name starts with "par-core2:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local BINDING = "CLICK MannersPrompt:LeftButton"

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- The pull as the client orders it: PLAYER_REGEN_DISABLED just before the
-- lockdown, then the lockdown, then the state driver's next frame.
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

local function castsSince(n)
	local out = {}
	for i = n + 1, #Mock.castLog do
		local e = Mock.castLog[i]
		if e.spell and not e.refused then out[#out + 1] = e end
	end
	return out
end

local function guarded(ns, scenario)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- ------------------------------------------------------------------ 1
-- Passers-by on nameplates, a mage with "Passers-by" on. `names` is the table
-- the mock's units read their names from; `plates` puts exactly these people
-- on nameplates (and takes everybody else off).
local function crowd(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	local names = {}
	local restore = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.db.profile.sources.strangers = true
		local function tick(n)
			for _ = 1, n do
				Mock.advance(0.4)
				Mock.runTimers(0)
				ns.addon:Tick()
			end
		end
		local function plates(list)
			for k in pairs(names) do names[k] = nil end
			for k in pairs(ns.nameplateUnits) do ns.nameplateUnits[k] = nil end
			for i, n in ipairs(list) do
				names["nameplate" .. i] = n
				ns.nameplateUnits["nameplate" .. i] = true
			end
		end
		body(ns, tick, plates)
		guarded(ns, scenario)
	end)
	Mock.inCombat = false
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function armedAt(ns)
	local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
	return type(text) == "string" and text:match("/target ([^\n]+)") or nil, text
end

local GONE = { { "Anna", "Aim" }, { "Bert", "Beside" }, { "Cora", "Cole" } }
local GONE_NAMES = { ["Anna Aim"] = true, ["Bert Beside"] = true, ["Cora Cole"] = true }

crowd("par-core2: a pull three seconds after a crowd walked off arms none of them", function(ns, tick, plates)
	local scenario = "par-core2: a pull three seconds after a crowd walked off arms none of them"
	plates(GONE)
	tick(8)
	local before = armedAt(ns)
	if not (before and GONE_NAMES[before]) then
		fail(scenario, "SKIPPED -- the crowd was never on the prompt: " .. tostring(before))
		return
	end
	-- They walk off; the memory of them still stands three seconds later.
	plates({})
	tick(7)
	local still = armedAt(ns)
	if not (still and GONE_NAMES[still]) then
		fail(scenario, "SKIPPED -- the memory had already let them go before the pull: " .. tostring(still))
		return
	end
	pull(ns)
	local who, text = armedAt(ns)
	if who then fail(scenario, "the pull froze the prompt on " .. who .. ", who left before it: " .. flat(text)) end
	local header = ns.Prompt:FightHeader()
	local n = header and header:GetAttribute("manners-rota-n") or 0
	if n > 0 then
		local held = {}
		for i = 1, n do held[#held + 1] = flat(header:GetAttribute("manners-rota-" .. i)) end
		fail(scenario, "the fight's rota is made of people who left: " .. table.concat(held, " || "))
	end
	if ns.Prompt:GetButton():IsShown() then fail(scenario, "the panel stays up for the fight over nobody") end
	tick(10)
	if ns.Prompt:GetButton():IsShown() then fail(scenario, "the panel came up in the fight over nobody") end
	release(ns)
end)

crowd("par-core2: at a pull with one passer-by still beside you and two gone, the rota is the one beside you", function(ns, tick, plates)
	local scenario = "par-core2: at a pull with one passer-by still beside you and two gone, the rota is the one beside you"
	plates(GONE)
	tick(8)
	-- Anna and Cora walk off; Bert stays on his nameplate.
	plates({ { "Bert", "Beside" } })
	tick(5)
	pull(ns)
	local who, text = armedAt(ns)
	if who ~= "Bert Beside" then fail(scenario, "the pull armed " .. tostring(who) .. ", not the one still beside you: " .. flat(text)) end
	local header = ns.Prompt:FightHeader()
	local n = header and header:GetAttribute("manners-rota-n") or 0
	for i = 1, n do
		local entry = flat(header:GetAttribute("manners-rota-" .. i))
		if entry:find("Anna Aim", 1, true) or entry:find("Cora Cole", 1, true) then
			fail(scenario, "the rota holds somebody who left: " .. entry)
		end
	end
	release(ns)
end)

-- A favour owed is not a memory of where somebody stood: the owed fallback,
-- offered by name with no token, is still armed at the pull as before.
crowd("par-core2: a favour owed with no token is still armed at the pull", function(ns, tick, plates)
	local scenario = "par-core2: a favour owed with no token is still armed at the pull"
	plates({})
	owe(ns, "Dana Dorn")
	tick(3)
	if armedAt(ns) ~= "Dana Dorn" then fail(scenario, "SKIPPED -- the favour is not on the prompt: " .. tostring(armedAt(ns))) return end
	pull(ns)
	if armedAt(ns) ~= "Dana Dorn" then fail(scenario, "the pull let a favour owed go: " .. tostring(armedAt(ns))) end
	release(ns)
end)

-- Out of a fight the memory still keeps a passer-by on the prompt for a few
-- seconds after the cursor or the nameplate left them (the 1.1.0 report): the
-- pull alone leaves them out.
crowd("par-core2: out of a fight a passer-by who walked off is still offered for a few seconds", function(ns, tick, plates)
	local scenario = "par-core2: out of a fight a passer-by who walked off is still offered for a few seconds"
	plates({ { "Anna", "Aim" } })
	tick(4)
	plates({})
	tick(5)
	if armedAt(ns) ~= "Anna Aim" then fail(scenario, "two seconds after she walked off the prompt holds " .. tostring(armedAt(ns))) end
end)

-- Everybody the fight's rota held walked off during it: the fight over, the
-- fuse keeps the panel up a moment as it stands, and its second line must not
-- still say where the fight's rota stood.
crowd("par-core2: the fight over with nobody left, the second line no longer speaks of the fight", function(ns, tick, plates)
	local scenario = "par-core2: the fight over with nobody left, the second line no longer speaks of the fight"
	local B, R = ns.Prompt:GetButton(), ns.Prompt.regions
	plates(GONE)
	tick(8)
	pull(ns)
	tick(2)
	local during = tostring(R.subText:GetText())
	if not during:find("in a fight", 1, true) then fail(scenario, "SKIPPED -- no rota line in the fight: " .. during) return end
	plates({})
	tick(40)
	release(ns)
	tick(1)
	local after = tostring(R.subText:GetText())
	if B:IsShown() and after:find("in a fight", 1, true) then
		fail(scenario, "after the fight the panel still reads " .. after)
	end
end)
