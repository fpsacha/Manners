-- Trust (the weakest-point review of 2026-11-15).
--
-- A scan that keeps failing, with "Say nothing at all in chat" on. ns.Guard
-- announced a failure only through addon:Print, which silentChat swallows, and
-- the game's own error display, which is off by default: the prompt froze or
-- never came, the launcher said "Watching for people to buff." in green, and
-- only the Diagnostics tab knew. Now a fault that repeats (three times inside
-- ten seconds) is the launcher's first state, in red, with the way to the full
-- check-up -- in its tooltip, its broker text and the options window's strip --
-- and, once a session for a silent player, one line on screen (UIErrorsFrame,
-- not chat). A single failure does not cry wolf, and a scan that recovers
-- takes the mark down.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- scenario name starts with "par-trust:" so the mutations in
-- tests/mutations/par-trust.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local function said() return table.concat(Mock.printed or {}, "\n") end

local function tooltip()
	local broker = Mock.broker
	if not (broker and broker.OnTooltipShow) then return nil end
	local lines = {}
	local tt = { AddLine = function(_, text) lines[#lines + 1] = tostring(text) end }
	local ok = pcall(broker.OnTooltipShow, tt)
	if not ok then return nil end
	return table.concat(lines, "\n")
end

-- One session with a scan whose repaint throws (`breakIt` true), the screen's
-- error line captured.
local function session(scenario, body)
	Mock.reset()
	local savedScreen = rawget(_G, "UIErrorsFrame")
	local screen = {}
	rawset(_G, "UIErrorsFrame", { AddMessage = function(_, text, r, g, b)
		screen[#screen + 1] = { text = tostring(text), r = r, g = g, b = b }
	end })
	local ns
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		Mock.printed = {}
		local P = ns.Prompt
		local real = P.Refresh
		local kit = {
			screen = screen,
			breakIt = function() P.Refresh = function() error("par-trust: the repaint broke") end end,
			mend = function() P.Refresh = real end,
			tick = function(n)
				for _ = 1, n or 1 do
					Mock.advance(0.4)
					ns.addon:Tick()
				end
			end,
		}
		body(ns, kit)
		P.Refresh = real
	end)
	if ns then pcall(ns.CloseOptions) end
	rawset(_G, "UIErrorsFrame", savedScreen)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------ a scan that keeps failing
do
	local scenario = "par-trust: silent chat, a scan that keeps failing is shown off chat"
	session(scenario, function(ns, kit)
		ns.db.profile.silentChat = true
		kit.breakIt()
		kit.tick(5)
		if #ns.errors < 5 then
			fail(scenario, ("SKIPPED -- the broken repaint failed %d times, not 5"):format(#ns.errors))
			return
		end
		local watching, line, r, g, b, _, _, kind = ns.LauncherState()
		if kind ~= "broken" then
			fail(scenario, "the launcher reads " .. tostring(kind) .. ": " .. tostring(line))
		else
			if watching ~= false then fail(scenario, "a broken scan still reads as watching") end
			if not (r == 1 and g < 0.5 and b < 0.5) then fail(scenario, "the line is not red") end
			if not tostring(line):find("Run a full check-up", 1, true) then
				fail(scenario, "the line does not name the full check-up: " .. tostring(line))
			end
			if not tostring(line):find("Tick", 1, true) then
				fail(scenario, "the line does not say what fails: " .. tostring(line))
			end
		end
		local tip = tooltip()
		if not (tip and tip:find("Run a full check-up", 1, true)) then
			fail(scenario, "the launcher's tooltip says nothing of it: " .. tostring(tip))
		end
		local text = Mock.broker and Mock.broker.text
		if not (text and text:find("something broke", 1, true)) then
			fail(scenario, "the broker text is " .. tostring(text))
		end
		-- Once on screen, however long it keeps failing.
		kit.tick(10)
		if #kit.screen ~= 1 then
			fail(scenario, ("%d lines on screen, not one"):format(#kit.screen))
		elseif not kit.screen[1].text:find("Run a full check-up", 1, true) then
			fail(scenario, "the screen says " .. kit.screen[1].text)
		end
		-- And still nothing in chat: the promise holds.
		if said():find("broke", 1, true) then fail(scenario, "chat was told: " .. said()) end
	end)
end

do
	local scenario = "par-trust: the options window's strip says the scan is broken"
	session(scenario, function(ns, kit)
		ns.db.profile.silentChat = true
		kit.breakIt()
		kit.tick(4)
		ns.OpenOptions("when")
		local strip = ns.WindowUI and ns.WindowUI.strip
		if not (strip and strip.kind == "broken" and strip.line and strip.line:find("Run a full check-up", 1, true)) then
			fail(scenario, "When to offer's strip says " .. tostring(strip and strip.line))
		end
	end)
end

do
	local scenario = "par-trust: one failure does not mark the scan broken"
	session(scenario, function(ns, kit)
		ns.db.profile.silentChat = true
		kit.breakIt()
		kit.tick(1)
		kit.mend()
		kit.tick(3)
		if #ns.errors ~= 1 then fail(scenario, ("SKIPPED -- %d failures, not 1"):format(#ns.errors)) return end
		local kind = select(8, ns.LauncherState())
		if kind == "broken" then fail(scenario, "a single failure reads as a broken scan") end
		if #kit.screen ~= 0 then fail(scenario, "a single failure was put on screen: " .. kit.screen[1].text) end
		-- Failures far apart do not add up to one that keeps failing.
		for i = 1, 3 do
			Mock.advance(30)
			kit.tick(1)
			kit.breakIt()
			kit.tick(1)
			kit.mend()
		end
		if select(8, ns.LauncherState()) == "broken" then fail(scenario, "three failures a minute apart read as broken") end
	end)
end

do
	local scenario = "par-trust: a scan that recovers takes the mark down"
	session(scenario, function(ns, kit)
		ns.db.profile.silentChat = true
		kit.breakIt()
		kit.tick(4)
		if select(8, ns.LauncherState()) ~= "broken" then fail(scenario, "SKIPPED -- never marked broken") return end
		kit.mend()
		Mock.advance(15)
		kit.tick(2)
		local kind = select(8, ns.LauncherState())
		if kind == "broken" then fail(scenario, "still marked broken after the scan mended") end
		local text = Mock.broker and Mock.broker.text
		if text and text:find("something broke", 1, true) then fail(scenario, "the broker text still says " .. text) end
		-- The errors themselves stay for Diagnostics.
		if #ns.errors < 4 then fail(scenario, "the errors were lost") end
		-- Broken again later in the session: marked again, and not said on
		-- screen a second time.
		kit.breakIt()
		kit.tick(4)
		if select(8, ns.LauncherState()) ~= "broken" then fail(scenario, "broken again and not marked") end
		if #kit.screen ~= 1 then fail(scenario, ("%d lines on screen in one session, not one"):format(#kit.screen)) end
	end)
end

do
	local scenario = "par-trust: with chat on, the chat line says it and the screen does not"
	session(scenario, function(ns, kit)
		ns.db.profile.silentChat = false
		kit.breakIt()
		kit.tick(5)
		if not said():find("something broke in", 1, true) then fail(scenario, "chat was not told: " .. said()) end
		if #kit.screen ~= 0 then fail(scenario, "the screen said it over the chat line: " .. kit.screen[1].text) end
		if select(8, ns.LauncherState()) ~= "broken" then fail(scenario, "the launcher does not say it") end
	end)
end
