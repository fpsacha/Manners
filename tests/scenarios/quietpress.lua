-- A press on an empty prompt and the chat lines (1.11.7). A key held, or a macro
-- spammed, with nobody to buff said "nobody to buff right now." at every press,
-- all day, for a player who had unticked "Tell me in chat what Manners is
-- doing". The press is still taken as empty; the line is said only with that
-- switch on (Prompt/Press.lua, ExplainEmptyPress).
--
-- Every scenario name starts with "quietpress:" so the mutations in
-- tests/mutations/quietpress.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local function said() return table.concat(Mock.printed, "\n") end

local function with(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	local restore = H.strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		ns.addon:Tick()
		if ns.Prompt:GetButton():IsShown() then
			fail(scenario, "SKIPPED -- the prompt is up with nobody to offer")
			return
		end
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "quietpress: with the chat lines on, a press on an empty prompt says why"
	with(scenario, function(ns)
		Mock.printed = {}
		H.pressButton(ns)
		if not said():find("nobody to buff right now.", 1, true) then
			fail(scenario, "the press said nothing: " .. said())
		end
	end)
end

do
	local scenario = "quietpress: with the chat lines off, the prompt's key says nothing"
	with(scenario, function(ns)
		ns.db.profile.verbose = false
		Mock.printed = {}
		for _ = 1, 3 do H.pressButton(ns) end
		if said() ~= "" then fail(scenario, "the press spoke: " .. said()) end
	end)
end

do
	local scenario = "quietpress: with the chat lines off, the action bar macro says nothing"
	with(scenario, function(ns)
		ns.db.profile.verbose = false
		ns.CreateClickMacro()
		if not Mock.dropOnBar(2) then
			fail(scenario, "SKIPPED -- no macro on the bar")
			return
		end
		Mock.printed = {}
		Mock.pressBar(2, { via = "key", keyDown = true })
		if said() ~= "" then fail(scenario, "the bar press spoke: " .. said()) end
	end)
end
