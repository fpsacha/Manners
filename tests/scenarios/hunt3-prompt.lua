-- The prompt letting go of somebody put on the never-offer list by any route
-- other than its own shift-right-click: /manners never, the options box, the
-- menu -- and of somebody listed whose favour has just run out.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton = H.strangers, H.freshPrompt, H.pressButton
local owe = H.owe

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Runs one scenario body, and names a throw as that scenario's failure.
local function run(scenario, body)
	local ok, err = pcall(body)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------ hunt3 prompt 1
-- Listed from outside the prompt while on the panel, with somebody else just
-- as deserving waiting: the hold used to keep them named, and armed, for up to
-- a second and a half.
Mock.reset()
do
	local scenario = "a person put on the never list leaves the panel at once"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "SKIPPED -- the panel named " .. tostring(ns.Prompt:PanelName()) .. " to start with")
			return
		end
		Mock.advance(0.1)
		ns.PutOnNeverList("Anna Aim")
		ns.Prompt:Refresh()
		if ns.Prompt:PanelName() ~= "Bert Beside" then
			fail(scenario, "after /manners never the panel named " .. tostring(ns.Prompt:PanelName()))
		end
		Mock.advance(0.3)
		local ran = tostring(pressButton(ns) or "")
		if ran:find("Anna Aim", 1, true) then
			fail(scenario, "a press cast at Anna just after she was put on the never list: " .. ran)
		end
		if ns.pendingClick and ns.pendingClick.name == "Anna Aim" then
			fail(scenario, "a press filed a cast at Anna just after she was put on the never list")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------ hunt3 prompt 2
-- The same, alone on the panel: the empty-queue fuse used to keep her up and
-- armed for three quarters of a second.
Mock.reset()
do
	local scenario = "a person put on the never list gets no fuse"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "SKIPPED -- the panel named " .. tostring(ns.Prompt:PanelName()) .. " to start with")
			return
		end
		Mock.advance(0.1)
		ns.PutOnNeverList("Anna Aim")
		ns.Prompt:Refresh()
		if ns.Prompt:GetButton():IsShown() then
			fail(scenario, "the panel stayed up naming " .. tostring(ns.Prompt:PanelName())
				.. " after she was put on the never list")
		end
		local ran = pressButton(ns)
		if ran ~= nil and tostring(ran):find("Anna Aim", 1, true) then
			fail(scenario, "a press cast at Anna just after she was put on the never list: " .. tostring(ran))
		end
		if ns.pendingClick and ns.pendingClick.name == "Anna Aim" then
			fail(scenario, "a press filed a cast at Anna just after she was put on the never list")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------ hunt3 prompt 3
-- Somebody listed but owed is the exception the list makes, and stays exactly
-- as offered as before; once that favour runs out, though, they are listed
-- with nothing to return, and go at once rather than after the hold.
Mock.reset()
do
	local scenario = "a listed person is held while owed and let go when the favour runs out"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		ns.owed["Anna Aim"].expires = GetTime() + 60
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "SKIPPED -- the panel named " .. tostring(ns.Prompt:PanelName()) .. " to start with")
			return
		end
		Mock.advance(0.1)
		ns.NeverOffer("Anna Aim")
		ns.Prompt:Refresh()
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "an owed person on the never list was taken off the panel: "
				.. tostring(ns.Prompt:PanelName()))
		end
		local ran = tostring(pressButton(ns) or "")
		if not ran:find("Anna Aim", 1, true) then
			fail(scenario, "a press did not cast at an owed person on the never list: " .. ran)
		end

		-- Her favour runs out with her still on the panel, well inside the
		-- hold the last paint started.
		ns.pendingClick = nil
		wipe(ns.tried)
		ns.owed["Anna Aim"].expires = GetTime() + 0.3
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "SKIPPED -- Anna was not back on the panel before her favour ran out: "
				.. tostring(ns.Prompt:PanelName()))
			return
		end
		Mock.advance(0.4)
		ns.Prompt:Refresh()
		if ns.Prompt:PanelName() == "Anna Aim" then
			fail(scenario, "Anna, listed and owed nothing any more, was still held on the panel")
		end
		Mock.advance(0.2)
		ran = tostring(pressButton(ns) or "")
		if ran:find("Anna Aim", 1, true) then
			fail(scenario, "a press cast at Anna, listed, after her favour ran out: " .. ran)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------ hunt3 prompt 4
-- And the fuse still covers somebody listed but owed who drops out of one scan:
-- they are the list's exception, not somebody it has retired.
Mock.reset()
do
	local scenario = "a listed person who is owed still gets the fuse"
	local seen = { nameplate1 = { "Anna", "Aim" } }
	local restoreUnits = strangers(seen)
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		-- Past the grace window, with only people in reach offered, so that out
		-- of sight she leaves the queue rather than staying on by name.
		ns.db.profile.filters.reachableOnly = true
		ns.owed["Anna Aim"].at = GetTime() - (ns.db.profile.timing.graceSeconds or 45) - 5
		ns.NeverOffer("Anna Aim")
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "SKIPPED -- the panel named " .. tostring(ns.Prompt:PanelName()) .. " to start with")
			return
		end
		-- She steps out of sight for a scan.
		Mock.advance(0.1)
		seen.nameplate1 = nil
		ns.nameplateUnits.nameplate1 = nil
		local empty = #ns.BuildQueue() == 0
		if not empty then
			fail(scenario, "SKIPPED -- the queue still had somebody in it with nobody in sight")
			return
		end
		ns.Prompt:Refresh()
		if not ns.Prompt:GetButton():IsShown() or ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "an owed person on the never list lost the fuse and the panel came down")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
