-- Hunt 3, the looks: what the third hunt of the day found in Looks/ and in the
-- outcome's words.
--
--   * Flow: a scroll at rest does not move in its bookkeeping. A speed set on
--     it while it stands (a look's StopAttention at every scan of a fight) and
--     a new window counted the rest as travel, and it jumped when played.
--   * Warchief, Ebon, Gearworks, Stormcaller, Lightbringer, Archmage, Fel: the
--     next person owed, news to the queue while a verdict stands, does not
--     stop the landing's lights and play the arrival over it.
--   * Warchief: the soot under the words, taken down by a verdict, is not
--     raised and dropped again at every scan the verdict stands.
--   * A cure's outcome says cured, not buffed, on the built-in looks and on a
--     look of Looks/.
--
-- Run on the recording CreateFrame in tests/frametree.lua. Every name starts
-- with "hunt3-looks:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local PAIR = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" } }
local FULL = { ["Anna Aim"] = true, ["Brannoc Vale"] = true }

local function withTree(scenario, names, body)
	Mock.reset()
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

local function near(a, b) return math.abs(a - b) < 1e-4 end

-- The prompt's settings for `style` on Full effects, nobody owed yet.
local function dress(ns, scenario, style)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle = style, "full", "pulse"
	p.showIcon, p.showSub, p.width = true, true, 260
	ns.Prompt:ApplyStyle()
	return p
end

-- ------------------------------------------------------------------ 1
-- A scroll at rest stands, whatever is asked of it meanwhile.
do
	local scenario = "hunt3-looks: a scroll at rest does not travel under a speed set on it or a new window"
	Mock.reset()
	FT.install()
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then
		ok, err = pcall(function()
			local parent = CreateFrame("Frame", nil, UIParent)
			local flow = ns.Looks.Flow.New(parent)
			local tex = parent:CreateTexture(nil, "ARTWORK")
			local function left() return (tex._texCoord or {})[1] end
			local drift = flow:Scroll(tex, 0.035, 0, 1, 1)
			drift:Play()
			Mock.advance(2)
			flow:Tick(GetTime())
			drift:Stop()
			local rested = left()
			if not near(rested, 0.07) then
				fail(scenario, "SKIPPED -- two seconds at 0.035 a second did not leave the scroll at 0.07: " .. tostring(rested))
				return
			end
			-- A fight: the look says the speed again at every scan, the scroll
			-- standing all the while.
			for _ = 1, 10 do
				Mock.advance(0.4)
				drift:Speed(0.035, 0)
			end
			-- The region changed size while it stood.
			Mock.advance(3)
			drift:Window(1, 1)
			if not near(left(), rested) then
				fail(scenario, ("a new window on a scroll at rest moved it from %.4f to %.4f"):format(rested, left()))
			end
			drift:Play()
			if not near(left(), rested) then
				fail(scenario, ("played again after speeds set on it at rest, the scroll jumped from %.4f to %.4f"):format(rested, left()))
			end
			-- And it goes on from there at the speed last set.
			Mock.advance(1)
			flow:Tick(GetTime())
			if not near(left(), rested + 0.035) then
				fail(scenario, ("a second after it was played again the scroll is at %.4f, not %.4f"):format(left(), rested + 0.035))
			end
			-- A speed set while it plays still keeps the place.
			drift:Speed(0.5, 0)
			flow:Tick(GetTime())
			if not near(left(), rested + 0.035) then
				fail(scenario, "a new speed on a playing scroll lost its place")
			end
		end)
	end
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 2
-- The arrival is for a new favour on a prompt with nothing else to say: never
-- over a verdict, whose landing it would cut short.

-- Counts, from here on, the look's Attention calls that came with news and the
-- times such a call put the flourishes' lights out (which is how every one of
-- these looks begins its arrival).
local function watch(look)
	local seen = { news = 0, stops = 0 }
	local attention, stopLights = look.Attention, look.StopLights
	local inNews = false
	look.Attention = function(self, isNew, ...)
		local was = inNews
		inNews = isNew and true or false
		if isNew then seen.news = seen.news + 1 end
		attention(self, isNew, ...)
		inNews = was
	end
	look.StopLights = function(self, ...)
		if inNews then seen.stops = seen.stops + 1 end
		return stopLights(self, ...)
	end
	return seen
end

for _, style in ipairs({ "warchief", "ebon", "gearworks", "stormcaller", "lightbringer", "archmage", "fel" }) do
	local scenario = "hunt3-looks: " .. style .. " plays no arrival over a verdict"
	withTree(scenario, PAIR, function(ns)
		dress(ns, scenario, style)
		local look = ns.Prompt:Regions().look
		if not (look and look.StopLights and look.Attention) then
			fail(scenario, "SKIPPED -- the look is not in use, or has no lights to stop")
			return
		end
		local seen = watch(look)
		owe(ns, "Anna Aim")
		tick(ns)
		if seen.news < 1 or seen.stops < 1 then
			fail(scenario, ("SKIPPED -- a new favour on a quiet prompt did not begin the arrival (news %d, lights stopped %d)")
				:format(seen.news, seen.stops))
			return
		end
		owe(ns, "Brannoc Vale")
		tick(ns)
		Mock.advance(3)
		FT.settle()
		tick(ns)
		local top = ns.Prompt:PanelName()
		if not FULL[top or ""] then
			fail(scenario, "SKIPPED -- neither of the two owed is on the prompt: " .. tostring(top))
			return
		end
		local nextUp = top == "Anna Aim" and "Brannoc Vale" or "Anna Aim"

		-- The verdict first, the debt still standing; then the scan that
		-- settles it and brings the other up, the verdict still on the panel.
		ns.Prompt:ShowOutcome("cast", top)
		seen.news, seen.stops = 0, 0
		Mock.advance(0.3)
		ns.owed[top] = nil
		tick(ns)
		if seen.news < 1 then
			fail(scenario, "SKIPPED -- the scan did not bring the next person owed to the top as news")
			return
		end
		if not ns.Prompt:OutcomeLive() then fail(scenario, "SKIPPED -- the outcome ended before the scan") return end
		if seen.stops > 0 then
			fail(scenario, "at the scan that brought the next person up, the landing's lights were put out for an arrival")
		end

		-- The verdict over, and a new favour is an arrival again.
		Mock.advance(3)
		tick(ns)
		FT.settle()
		ns.owed[nextUp] = nil
		tick(ns)
		seen.news, seen.stops = 0, 0
		owe(ns, top)
		tick(ns)
		if seen.stops < 1 then
			fail(scenario, "with no verdict on the panel a new favour no longer begins the arrival")
		end

		-- And in the outcome's own repaint, which comes to the look before the
		-- verdict's words are written.
		owe(ns, nextUp)
		tick(ns)
		Mock.advance(3)
		FT.settle()
		tick(ns)
		local now = ns.Prompt:PanelName()
		if not FULL[now or ""] then
			fail(scenario, "SKIPPED -- neither of the two owed is on the prompt the second time: " .. tostring(now))
			return
		end
		ns.owed[now] = nil
		seen.news, seen.stops = 0, 0
		ns.Prompt:ShowOutcome("cast", now)
		if seen.news < 1 then
			fail(scenario, "SKIPPED -- the outcome's repaint did not bring the next person owed to the top as news")
			return
		end
		if seen.stops > 0 then
			fail(scenario, "in the outcome's own repaint, the landing's lights were put out for an arrival")
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- Warchief's soot goes down once with the verdict and stays down under it.
withTree("hunt3-looks: Warchief's soot fades once under a verdict", ANNA, function(ns, scenario)
	dress(ns, scenario, "warchief")
	owe(ns, "Anna Aim")
	tick(ns)
	local look = ns.Prompt:Regions().look
	if not (look and look.sootOut and look.sootIn and look.SootUp) then
		fail(scenario, "SKIPPED -- Warchief is not the look in use")
		return
	end
	Mock.advance(3)
	FT.settle()
	tick(ns)
	if not look.sootOn then
		fail(scenario, "SKIPPED -- with somebody owed on top the soot is not up")
		return
	end
	-- The game refused the cast: the person stays owed.
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range")
	if look.sootOn then
		fail(scenario, "SKIPPED -- the verdict did not take the soot down")
		return
	end
	local outs, ins = look.sootOut._plays, look.sootIn._plays
	Mock.advance(0.3)
	tick(ns)
	if not ns.Prompt:OutcomeLive() then fail(scenario, "SKIPPED -- the outcome ended before the scan") return end
	if look.sootOn then fail(scenario, "the scan under the verdict left the soot up") end
	if look.sootOut._plays ~= outs or look.sootIn._plays ~= ins then
		fail(scenario, ("the scan under the verdict played the soot's fades again (in %d, out %d)")
			:format(look.sootIn._plays - ins, look.sootOut._plays - outs))
	end
	-- The verdict over, the person still owed: the soot comes back up.
	Mock.advance(1)
	tick(ns)
	if ns.Prompt:OutcomeLive() then fail(scenario, "SKIPPED -- the outcome is still live a second on") return end
	if not look.sootOn then fail(scenario, "after the verdict, with somebody still owed, the soot stayed down") end
end)

-- ------------------------------------------------------------------ 4
-- A cure's outcome is told as a cure.
local function plainText(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

for _, style in ipairs({ "glass", "warchief" }) do
	local scenario = "hunt3-looks: a cure's outcome says cured, not buffed, on " .. style
	withTree(scenario, ANNA, function(ns)
		dress(ns, scenario, style)
		owe(ns, "Anna Aim")
		tick(ns)
		Mock.advance(3)
		FT.settle()
		tick(ns)
		local r = ns.Prompt:Regions()
		local function words()
			return plainText(r.name:GetText()), plainText(r.sub:GetText())
		end
		ns.Prompt:ShowOutcome("cast", "Anna Aim", nil, "cure:poison")
		local name, sub = words()
		if name:find("buffed", 1, true) or sub:find("buffed", 1, true) then
			fail(scenario, ("a cure that landed reads as a buff: %q / %q"):format(name, sub))
		end
		if not (name:find("cured", 1, true) and name:find("Anna", 1, true)) then
			fail(scenario, ("a cure that landed does not say who was cured: %q / %q"):format(name, sub))
		end
		Mock.advance(3)
		tick(ns)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range", "cure:poison")
		name, sub = words()
		if name:find("could not buff", 1, true) or sub:find("could not buff", 1, true) then
			fail(scenario, ("a cure the game refused reads as a buff: %q / %q"):format(name, sub))
		end
		if not (name:find("could not cure", 1, true) and name:find("Anna", 1, true)) then
			fail(scenario, ("a cure the game refused does not say so: %q / %q"):format(name, sub))
		end
		if not sub:find("Out of range", 1, true) then
			fail(scenario, ("a cure the game refused lost the game's own reason: %q"):format(sub))
		end
		-- A buff is still told as a buff.
		Mock.advance(3)
		tick(ns)
		ns.Prompt:ShowOutcome("cast", "Anna Aim", nil, "fortitude")
		name, sub = words()
		if not (name .. " " .. sub):find("buffed", 1, true) then
			fail(scenario, ("a buff that landed no longer says buffed: %q / %q"):format(name, sub))
		end
		if name:find("cured", 1, true) then
			fail(scenario, ("a buff that landed reads as a cure: %q"):format(name))
		end
	end)
end
