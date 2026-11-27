-- Pass 2, the fight lens: what the review of 1.11.34's fight buttons found.
-- Each scenario is red on the tree it was written against and goes green with
-- its fix. Every name starts with "pass2-fight: " so a mutation can name one.

local dir, H = ...
local fail, load, freshPrompt = H.fail, H.load, H.freshPrompt

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The client's own decision, copied from SecureActionButton_OnClick and
-- SecureActionButton_ShouldUseOnKeyDown (Blizzard_FrameXML/SecureTemplates.lua,
-- the same lines on the forever, live and classic_era branches): whether a
-- key press's down click is the button's action. A binding's press is a key
-- press (isKeyPress), so isSecureMousePress is false.
local function DownIsAction(button, keyDownCVar)
	local pressAndHold = button:GetAttribute("pressAndHoldAction")
	local useOnKeyDown = button:GetAttribute("useOnKeyDown")
	if useOnKeyDown == nil then useOnKeyDown = keyDownCVar end
	local onDown = (useOnKeyDown or pressAndHold) and true or false
	return onDown
end

-- ------------------------------------------------------------------ 1, 2
-- Each fight button is registered for "AnyDown" alone, so the down click is
-- the only one it is handed. With ActionButtonUseKeyDown off and no
-- pressAndHoldAction the client takes that down click as neither the action
-- nor a release: nothing is cast. The prompt sets pressAndHoldAction for this
-- (Prompt/Panel.lua); the fight buttons must too.
do
	local rows = {
		{ "the cure button", "MannersCureFight", function(ns) ns.CureFight:Create() return ns.CureFight:Button() end },
		{ "the break-free button", "MannersBreakFree", function(ns) ns.BreakFree:Create() return ns.BreakFree:Button() end },
		{ "the mend-pet button", "MannersMendPet", function(ns) ns.MendPet:Create() return ns.MendPet:Button() end },
	}
	for _, row in ipairs(rows) do
		local scenario = "pass2-fight: " .. row[1] .. " casts on its key with ActionButtonUseKeyDown off"
		Mock.reset()
		local ns = load(scenario)
		if ns then
			local ok, err = pcall(function()
				freshPrompt(ns, scenario)
				local button = row[3](ns)
				if not button then fail(scenario, "SKIPPED -- no " .. row[2] .. " made") return end
				local clicks = button._clicks or {}
				if #clicks ~= 1 or clicks[1] ~= "AnyDown" then
					fail(scenario, "SKIPPED -- registered for " .. table.concat(clicks, ", "))
					return
				end
				if not DownIsAction(button, false) then
					fail(scenario, row[2] .. " is registered for AnyDown with pressAndHoldAction="
						.. tostring(button:GetAttribute("pressAndHoldAction"))
						.. ": with ActionButtonUseKeyDown off its key casts nothing")
				end
				noErrors(scenario, ns)
			end)
			if not ok then fail(scenario, "threw: " .. tostring(err)) end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ 3
-- The cure button is shown by its state driver for every fight at alpha 0.
-- With its key bound, out of sight it must take no click (as the break-free
-- and mend-pet buttons take none: Prompt/BreakFree.lua, SetMouse), or a click
-- beside the prompt casts the cure with nobody needing it.
do
	local scenario = "pass2-fight: out of sight with its key bound the cure button takes no click"
	local COMMAND = "CLICK MannersCureFight:LeftButton"
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "DRUID"
	Mock.groupSize = 3
	Mock.knownSpells = { [1126] = true, [8946] = true, [2782] = true }
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			ns.KeyNudge = nil
			ns.db.profile.prompt.cureFight = true
			ns.Guard("probe", ns.ProbeCapabilities)
			Mock.bindings = Mock.bindings or {}
			Mock.bindings.F = COMMAND
			ns.addon:Tick()
			Mock.runTimers(0)
			local button = ns.CureFight:Button()
			if not button then fail(scenario, "SKIPPED -- no cure button for a druid with the switch on") return end
			ns.CureFight:Refresh()
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
			Mock.frameEvent("PLAYER_REGEN_DISABLED")
			Mock.runTimers(0)
			Mock.runTimers(2)
			if not button:IsShown() then fail(scenario, "SKIPPED -- its driver did not show it at the pull") end
			local look = ns.CureFight:Look()
			if look and look.alpha ~= 0 then fail(scenario, "SKIPPED -- lit with nobody to cure") end
			if button._mouse ~= false then
				fail(scenario, "shown at alpha 0 with its key bound and nobody to cure, it takes a click (mouse "
					.. tostring(button._mouse) .. ")")
			end
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_ENABLED()
			Mock.frameEvent("PLAYER_REGEN_ENABLED")
			Mock.runTimers(0)
			noErrors(scenario, ns)
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.inCombat = false
	Mock.reset()
end

-- ------------------------------------------------------------------ 5
-- ReadLoss hands a secret loss-of-control record (or locType) back as it came,
-- then asked `raw ~= nil` of it: a comparison of a possibly secret value, which
-- the client raises on. The mock's secret is a table, so it cannot raise; the
-- scenario reads the source instead (as tests/scenarios/standstill.lua does).
do
	local scenario = "pass2-fight: ReadLoss never compares a possibly secret record"
	local f = io.open(dir .. "/Modules/Combat/BreakFree.lua", "r")
	if not f then
		fail(scenario, "SKIPPED -- Modules/Combat/BreakFree.lua not readable")
	else
		local src = f:read("*a")
		f:close()
		local body = src:match("local function ReadLoss%(row, eventIndex%)(.-)\nend\n")
		if not body then
			fail(scenario, "SKIPPED -- ReadLoss not found")
		else
			for line in body:gmatch("[^\n]+") do
				if line:find("raw%s*[~=]=") or line:find("[~=]=%s*raw[^%w_]") then
					fail(scenario, "compares the raw read: " .. line:gsub("^%s+", ""))
				end
			end
		end
	end
end
