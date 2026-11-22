-- A controller button in the options window's key boxes (Options/Window/
-- WidgetsChoice.lua, keybinding): the box takes it only while it waits for a
-- key, binds the same CLICK command a keyboard key does, and a trigger set to
-- act as Shift starts a chord instead of being the key.
--
-- Every name starts with "gamepad-key: " so a mutation in tests/mutations/
-- gamepad-key.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, clearClicks = H.strangers, H.freshPrompt, H.owe, H.clearClicks

local ANNA = { "Anna", "Aim" }
local PROMPT = "CLICK MannersPrompt:LeftButton"

-- A session on Forever with the prompt built and the window's side of the
-- contract, and the key box of one control of the model.
local function with(scenario, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	local savedGUID, savedCVar = rawget(_G, "UnitGUID"), rawget(_G, "GetCVar")
	local restore = strangers({ nameplate1 = { ANNA[1], ANNA[2] } })
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			body(ns)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	restore()
	rawset(_G, "UnitGUID", savedGUID)
	rawset(_G, "GetCVar", savedCVar)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function keyRow(ns, path)
	local ctx = { changes = {}, holds = {}, pages = {}, relayouts = 0 }
	ctx.Window = CreateFrame("Frame", nil, UIParent)
	ctx.Window:SetSize(820, 600)
	ctx.OnChange = function(item) ctx.changes[#ctx.changes + 1] = item.path end
	ctx.OnHold = function() end
	ctx.ScrollPage = function() end
	ctx.Relayout = function(row) row:Layout(row.width) end
	local item = ns.WindowBind.Item(path, {}, ctx)
	if not item then return nil end
	local row = ns.WindowWidgets.Build("keybinding", ctx.Window, item)
	row:Layout(560)
	return row
end

local function bound(command)
	return (GetBindingKey(command))
end

with("gamepad-key: a controller button pressed in The prompt's key binds the prompt to it", function(ns)
	local scenario = "gamepad-key: a controller button pressed in The prompt's key binds the prompt to it"
	local row = keyRow(ns, "general.bindKey")
	if not row then fail(scenario, "SKIPPED -- no general.bindKey") return end
	local W = ns.WindowWidgets
	row.button:Click("LeftButton")
	if W.Capturing() ~= row then fail(scenario, "a click did not start listening") end
	if not Mock.padDown(row.button, "PAD1") then fail(scenario, "the box did not take the controller while waiting") return end
	if bound(PROMPT) ~= "PAD1" then fail(scenario, "the prompt is bound to " .. tostring(bound(PROMPT))) end
	if W.Capturing() ~= nil then fail(scenario, "the capture went on after the button") end
	local want = type(GetBindingText) == "function" and GetBindingText("PAD1") or "PAD1"
	if row.button.text:GetText() ~= want then
		fail(scenario, "the box reads " .. tostring(row.button.text:GetText()))
	end
end)

with("gamepad-key: a trigger set to act as Shift starts a chord, and the button after it binds SHIFT-", function(ns)
	local scenario = "gamepad-key: a trigger set to act as Shift starts a chord, and the button after it binds SHIFT-"
	rawset(_G, "GetCVar", function(name) if name == "GamePadEmulateShift" then return "PADLTRIGGER" end return "none" end)
	local row = keyRow(ns, "general.bindKey")
	if not row then fail(scenario, "SKIPPED -- no general.bindKey") return end
	local W = ns.WindowWidgets
	row.button:Click("LeftButton")
	Mock.padDown(row.button, "PADLTRIGGER")
	if W.Capturing() ~= row then fail(scenario, "the trigger on its own ended the capture") end
	if bound(PROMPT) ~= nil then fail(scenario, "the trigger on its own was bound: " .. tostring(bound(PROMPT))) end
	Mock.modifiers.shift = true
	Mock.padDown(row.button, "PAD2")
	Mock.modifiers.shift = false
	if bound(PROMPT) ~= "SHIFT-PAD2" then fail(scenario, "the chord came out as " .. tostring(bound(PROMPT))) end
end)

with("gamepad-key: the box takes no controller button unless it is waiting for one", function(ns)
	local scenario = "gamepad-key: the box takes no controller button unless it is waiting for one"
	local row = keyRow(ns, "general.bindKey")
	if not row then fail(scenario, "SKIPPED -- no general.bindKey") return end
	if Mock.padDown(row.button, "PAD1") then fail(scenario, "an idle box took a controller button") end
	if bound(PROMPT) ~= nil then fail(scenario, "an idle box bound " .. tostring(bound(PROMPT))) end
	row.button:Click("LeftButton")
	if row.button._gamepad ~= true then fail(scenario, "a waiting box does not take the controller") end
	Mock.keyDown(row.button, "ESCAPE")
	if row.button._gamepad ~= false then fail(scenario, "Escape left the box holding the controller") end
	row.button:Click("LeftButton")
	Mock.padDown(row.button, "PAD1")
	if row.button._gamepad ~= false then fail(scenario, "a taken button left the box holding the controller") end
end)

with("gamepad-key: a bound controller button casts once on the first press", function(ns)
	local scenario = "gamepad-key: a bound controller button casts once on the first press"
	local row = keyRow(ns, "general.bindKey")
	if not row then fail(scenario, "SKIPPED -- no general.bindKey") return end
	row.button:Click("LeftButton")
	Mock.padDown(row.button, "PAD1")
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local before = #Mock.castLog
	Mock.pressKey("PAD1", { release = true })
	if #Mock.castLog - before ~= 1 then fail(scenario, ("the first press cast %d time(s)"):format(#Mock.castLog - before)) end
	clearClicks(ns)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	before = #Mock.castLog
	Mock.pressKey("PAD1", { release = true })
	if #Mock.castLog - before ~= 1 then fail(scenario, ("the second press cast %d time(s)"):format(#Mock.castLog - before)) end
end)

with("gamepad-key: the break-free key takes a controller button too", function(ns)
	local scenario = "gamepad-key: the break-free key takes a controller button too"
	local row = keyRow(ns, "appearance.breakFreeKey")
	if not row then fail(scenario, "SKIPPED -- no appearance.breakFreeKey") return end
	row.button:Click("LeftButton")
	if not Mock.padDown(row.button, "PAD3") then fail(scenario, "the box did not take the controller") return end
	if bound("CLICK MannersBreakFree:LeftButton") ~= "PAD3" then
		fail(scenario, "break free is bound to " .. tostring(bound("CLICK MannersBreakFree:LeftButton")))
	end
end)
