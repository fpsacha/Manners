-- Moving the prompt (hunt 30). The switch for it was a small checkbox, second
-- on the Look page, and people did not find it. Now Move the prompt is a button
-- in the options window's header, one press from every page (general.moveToggle,
-- Options/Shared.lua's MoveControl, Options/Window/WindowChrome.lua), and the
-- first thing on Look, big, with the ready-made places beside it
-- (appearance.move); Lock position is no longer drawn, the button reads the
-- same lock. Pressed while locked it unlocks exactly as /manners unlock does,
-- ends a preview that would hide "Drag to move", and takes the window out of
-- the way of the prompt; while unlocked it reads Lock it and locks. /manners
-- move is another word for unlock. The unlocked prompt's second line says what
-- happens next instead of warning in red, and its tooltip keeps the warning.
--
-- Every scenario name starts with "hunt30-move:" so the mutations in
-- tests/mutations/hunt30-move.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local function said()
	return table.concat(Mock.printed, "\n")
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function press(button)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, "LeftButton", false) end
end

local function label(button)
	return button and button.label and button.label:GetText() or nil
end

-- One session as `class` (a mage), the lifecycle driven and the slate clean,
-- with body(ns, UI) run and the fight and the snooze put away however it
-- ends.
local function with(scenario, class, body)
	Mock.reset()
	Mock.class = class or "MAGE"
	local ns = load(scenario)
	if not ns then return end
	local ok, err = pcall(function()
		H.freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.printed = {}
		body(ns, ns.WindowUI)
		noErrors(scenario, ns)
	end)
	Mock.inCombat = false
	ns.StopSnooze(true)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ the header
-- Beside Show me the prompt, from every page: Move the prompt unlocks the
-- prompt, and the same button reads Lock it and locks it while it is unlocked.
-- The window steps out of the prompt's way when there is a prompt to drag.
do
	local scenario = "hunt30-move: the header's Move the prompt button unlocks, and reads Lock it while unlocked"
	with(scenario, "MAGE", function(ns, UI)
		local p = ns.db.profile.prompt
		if (ns.WindowLayout.header or {}).move ~= "general.moveToggle" then
			fail(scenario, "the window's header does not place general.moveToggle")
		end
		for _, page in ipairs({ "general", "who", "when", "appearance" }) do
			ns.OpenOptions(page, true)
			if not (UI.header.move and UI.header.move:IsShown()) then
				fail(scenario, "there is no Move the prompt button in the header on " .. page)
			end
		end
		ns.OpenOptions("who", true)
		local move = UI.header.move
		if not move then return end
		if label(move) ~= "Move the prompt" then
			fail(scenario, "locked, the header's button reads " .. tostring(label(move)))
		end
		if not (move:IsEnabled()) then fail(scenario, "Move the prompt is greyed out while no fight is on") end

		press(move)
		if p.locked ~= false then fail(scenario, "pressing Move the prompt left the prompt locked") end
		if not said():find("unlocked -- drag the prompt", 1, true) then
			fail(scenario, "Move the prompt said nothing about dragging in chat: " .. said())
		end
		if ns.OptionsOpen() then
			fail(scenario, "the options window stayed up over the prompt it was asked to move")
		end

		-- Reopened while it is still unlocked: the same button, now Lock it.
		ns.OpenOptions("who", true)
		if label(UI.header.move) ~= "Lock it" then
			fail(scenario, "unlocked, the header's button reads " .. tostring(label(UI.header.move)))
		end
		Mock.printed = {}
		press(UI.header.move)
		if p.locked ~= true then fail(scenario, "pressing Lock it left the prompt unlocked") end
		if not said():find("locked.", 1, true) or said():find("unlocked", 1, true) then
			fail(scenario, "Lock it said " .. said())
		end
		if not ns.OptionsOpen() then fail(scenario, "locking took the window away") end
		if label(UI.header.move) ~= "Move the prompt" then
			fail(scenario, "locked again, the header's button reads " .. tostring(label(UI.header.move)))
		end

		-- And the setting every other place reads is the one it wrote.
		local locked = ns.optionsTable.args.appearance.args.locked
		if not (locked and locked.get({ "locked" }) == true) then
			fail(scenario, "profile.prompt.locked, the saved setting, is not what Lock position reads")
		end
	end)
end

-- Three buttons and the switch share the header with the title: in a row, the
-- new one between the preview and Snooze, each wide enough for both its words.
do
	local scenario = "hunt30-move: the header's buttons sit in a row, Move the prompt between Show me the prompt and Snooze"
	with(scenario, "MAGE", function(ns, UI)
		ns.OpenOptions("who", true)
		local function span(button)
			local p = button and button.points and button.points[#button.points]
			if not p then return nil end
			return p[4] or 0, (p[4] or 0) + button:GetWidth()
		end
		local a0, a1 = span(UI.header.preview)
		local b0, b1 = span(UI.header.move)
		local c0, c1 = span(UI.header.snooze)
		if not (a0 and b0 and c0) then
			fail(scenario, "SKIPPED -- a header button has no place")
		elseif not (a1 <= b0 and b1 <= c0) then
			fail(scenario, ("the header's buttons overlap or are out of order: Show me the prompt %d-%d,"
				.. " Move the prompt %d-%d, Snooze %d-%d"):format(a0, a1, b0, b1, c0, c1))
		elseif a0 < 130 then
			fail(scenario, "the buttons crowd the title: the first starts at " .. a0)
		end
		for _, text in ipairs({ ns.L["Move the prompt"], ns.L["Lock it"] }) do
			if UI.Measure(text) + 12 > UI.header.move:GetWidth() then
				fail(scenario, ("the button is %d wide, too narrow for %q"):format(UI.header.move:GetWidth(), text))
			end
		end
	end)
end

-- ------------------------------------------------------------------ on screen
-- Unlocking has to leave a prompt on screen to drag, not a mock-up of one: a
-- preview running (the window starts one on Look) would stand where "Drag to
-- move" goes, so unlocking ends it, without a line of its own, and opening Look
-- does not start another over an unlocked prompt.
do
	local scenario = "hunt30-move: unlocking leaves the prompt on screen to drag, a preview out of its way"
	with(scenario, "MAGE", function(ns, UI)
		local R = ns.Prompt.regions
		-- Opening onto Look starts a preview; one started by hand does the same.
		ns.OpenOptions("appearance", true)
		if not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- the preview did not start")
			return
		end
		Mock.printed = {}
		press(UI.header.move)
		if ns.Prompt:InTest() then
			fail(scenario, "the preview stayed over the prompt Move the prompt unlocked")
		end
		if said():find("preview off", 1, true) then
			fail(scenario, "ending the preview for a move said so as well: " .. said())
		end
		ns.addon:Tick()
		if not ns.Prompt:GetButton():IsShown() then
			fail(scenario, "the unlocked prompt is not on screen to be dragged")
		end
		if not tostring(R.nameText:GetText()):find("Drag to move", 1, true) then
			fail(scenario, "the unlocked prompt's first line reads " .. tostring(R.nameText:GetText()))
		end
		-- Look opened again, over an unlocked prompt: no preview started on it.
		ns.OpenOptions("appearance", true)
		ns.OpenOptions("who", true)
		ns.OpenOptions("appearance")
		if ns.Prompt:InTest() then
			fail(scenario, "opening Look started a preview over the unlocked prompt")
		end
		-- Show me the prompt still asks for one, which is its job.
		ns.addon:HandleSlash("lock")
		ns.OpenOptions("appearance", true)
		ns.OpenOptions("who", true)
		ns.OpenOptions("appearance")
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- opening Look no longer starts a preview over a locked prompt")
		end
		ns.Prompt:ExitTest()
	end)
end

-- ------------------------------------------------------------------ a fight
-- The client will not move the secure prompt in a fight: the button is greyed
-- out in the minimap menu's words, a press that gets through anyway does
-- nothing, and Lock it is not refused (a locked prompt is the one that casts).
do
	local scenario = "hunt30-move: Move the prompt is refused in a fight, and says why"
	with(scenario, "MAGE", function(ns, UI)
		local B = ns.WindowBind
		local p = ns.db.profile.prompt
		ns.OpenOptions("general", true)
		local move = UI.header.move
		if not move then
			fail(scenario, "SKIPPED -- no Move the prompt button")
			return
		end
		Mock.inCombat = true
		ns.RefreshOptionsDisplay()
		local item = B.Item("general.moveToggle", nil, UI.ctx)
		if not B.Disabled(item) or move:IsEnabled() then
			fail(scenario, "Move the prompt can be pressed in a fight")
		end
		press(move)
		local def = ns.optionsTable.args.general.args.moveToggle
		def.func({ "moveToggle" })
		if p.locked ~= true then fail(scenario, "a press in a fight unlocked the prompt") end
		if said():find("unlocked", 1, true) then
			fail(scenario, "a press in a fight said the prompt was unlocked: " .. said())
		end
		-- The tooltip says why, in the words the minimap menu already uses.
		Mock.tooltip = {}
		local enter = move:GetScript("OnEnter")
		if enter then enter(move) end
		local tip = table.concat(Mock.tooltip or {}, "\n")
		if not tip:find("cannot be moved or changed during a fight", 1, true) then
			fail(scenario, "the button's tooltip does not say why in a fight: " .. tip)
		end
		for _, option in ipairs({ def, ns.optionsTable.args.appearance.args.move }) do
			if not option.disabled({}) then fail(scenario, "the model's button is live in a fight") end
		end

		-- Lock it is a flag the prompt reads, and works in a fight.
		Mock.inCombat = false
		ns.addon:HandleSlash("unlock")
		Mock.inCombat = true
		ns.RefreshOptionsDisplay()
		if not move:IsEnabled() then
			fail(scenario, "Lock it is greyed out in a fight, where a locked prompt is the one that casts")
		end
		press(move)
		if p.locked ~= true then fail(scenario, "Lock it did nothing in a fight") end
		Mock.inCombat = false
		ns.RefreshOptionsDisplay()
		if not move:IsEnabled() then fail(scenario, "Move the prompt stayed greyed out after the fight") end
	end)
end

-- ------------------------------------------------------------------ the words
-- Every way into unlocking says the same thing: the line /manners unlock prints
-- is the line the button prints, with the addon on, off and snoozed. Off, there
-- is no prompt to drag and the window stays, with the switch in its header.
for _, case in ipairs({ "on", "off", "snoozed" }) do
	local scenario = "hunt30-move: Move the prompt says what /manners unlock says (" .. case .. ")"
	with(scenario, "MAGE", function(ns, UI)
		local p = ns.db.profile.prompt
		if case == "off" then
			ns.addon:HandleSlash("off")
		elseif case == "snoozed" then
			ns.addon:HandleSlash("snooze 5")
		end
		Mock.printed = {}
		ns.addon:HandleSlash("unlock")
		local viaSlash = said()
		ns.addon:HandleSlash("lock")
		ns.OpenOptions("general", true)
		Mock.printed = {}
		press(UI.header.move)
		local viaButton = said()
		if p.locked ~= false then fail(scenario, "the button left the prompt locked") end
		if viaSlash == "" then
			fail(scenario, "SKIPPED -- /manners unlock said nothing")
		elseif viaButton ~= viaSlash then
			fail(scenario, ("the button said %q where /manners unlock says %q"):format(viaButton, viaSlash))
		end
		if case == "off" then
			if not viaButton:find("no prompt to drag", 1, true) then
				fail(scenario, "switched off, the button did not say there is nothing to drag: " .. viaButton)
			end
			if not ns.OptionsOpen() then
				fail(scenario, "switched off, the window shut, with its switch in the header")
			end
		elseif ns.OptionsOpen() then
			fail(scenario, "the window stayed up over the prompt it was asked to move (" .. case .. ")")
		end
		ns.addon:HandleSlash("on")
	end)
end

-- ------------------------------------------------------------------ Look
-- The page leads, after the gallery of looks (its own section, above), with the
-- control, big, the places beside it, and does not draw Lock position: the
-- button reads and writes the same lock.
do
	local scenario = "hunt30-move: Look leads with a big Move the prompt button, the places beside it"
	with(scenario, "MAGE", function(ns, UI)
		local list = H.pagePaths(ns, "appearance") or {}
		if list[1] == "appearance.style" then table.remove(list, 1) end
		if list[1] ~= "appearance.move" or list[2] ~= "appearance.posPreset" then
			fail(scenario, ("Look begins %s, %s"):format(tostring(list[1]), tostring(list[2])))
		end
		if H.placedOn(ns, "appearance.locked") then
			fail(scenario, "Lock position is still drawn on a page, beside a button that is the same switch")
		end
		if not (ns.WindowLayout.unplaced or {})["appearance.locked"] then
			fail(scenario, "Lock position is drawn nowhere and is not said to be")
		end
		ns.OpenOptions("appearance", true)
		local move, places = UI.Where("appearance.move"), UI.Where("appearance.posPreset")
		if not (UI.RowShown("appearance.move") and UI.RowShown("appearance.posPreset")) then
			fail(scenario, "the button or the places are not shown on Look")
			return
		end
		-- The gallery of looks is the page's first section; the button and the
		-- places are its second.
		if move.sec ~= UI.Model("appearance").sections[2] or places.sec ~= move.sec then
			fail(scenario, "the button and the places are not the page's first section")
		end
		if not (places.e.x > move.e.x and math.abs(places.e.y - move.e.y) < move.e.h) then
			fail(scenario, "the places are not beside the button")
		end
		local button = move.e.row.button
		if not (button and button:GetHeight() >= 30) then
			fail(scenario, "the button is not big: " .. tostring(button and button:GetHeight()))
		end
		if label(button) ~= "Move the prompt" then fail(scenario, "the button reads " .. tostring(label(button))) end
		for _, path in ipairs(list) do
			local where = UI.Where(path)
			if where and UI.RowShown(path) and where.e.y + (where.e.row.fieldTop or 0) < move.e.y then
				fail(scenario, path .. " is drawn above the button")
			end
		end

		-- It is the same control as the header's: pressed, it unlocks, and the
		-- window steps aside; reopened, it reads Lock it and locks.
		press(button)
		if ns.db.profile.prompt.locked ~= false then fail(scenario, "pressing the button did not unlock") end
		ns.OpenOptions("appearance", true)
		local again = UI.Where("appearance.move").e.row.button
		if label(again) ~= "Lock it" then fail(scenario, "unlocked, the button reads " .. tostring(label(again))) end
		press(again)
		if ns.db.profile.prompt.locked ~= true then fail(scenario, "Lock it did not lock") end
		ns.Prompt:ExitTest()
	end)
end

-- ------------------------------------------------------------------ the model
-- In the fallback dialog the control is an ordinary button, there for a class
-- with a prompt only, and both of them are one definition.
do
	local scenario = "hunt30-move: the model has the control as an ordinary button, for a class with a prompt"
	with(scenario, "MAGE", function(ns)
		local p = ns.db.profile.prompt
		local general, look = ns.optionsTable.args.general.args.moveToggle, ns.optionsTable.args.appearance.args.move
		for _, option in ipairs({ general, look }) do
			if not (option and option.type == "execute") then
				fail(scenario, "the control is not an execute button")
				return
			end
			p.locked = true
			if option.name({}) ~= "Move the prompt" then fail(scenario, "locked, it reads " .. tostring(option.name({}))) end
			option.func({})
			if p.locked ~= false then fail(scenario, "the button did not unlock") end
			if option.name({}) ~= "Lock it" then fail(scenario, "unlocked, it reads " .. tostring(option.name({}))) end
			if not option.desc({}):find("does not buff anyone", 1, true) then
				fail(scenario, "unlocked, its tooltip reads " .. option.desc({}))
			end
			option.func({})
			if p.locked ~= true then fail(scenario, "Lock it did not lock") end
			if not option.desc({}):find("locks itself when you let go", 1, true) then
				fail(scenario, "locked, its tooltip reads " .. option.desc({}))
			end
			if option.hidden({}) then fail(scenario, "the control is hidden for a class with a prompt") end
		end
	end)
	scenario = "hunt30-move: a class with no prompt has no Move the prompt button"
	with(scenario, "ROGUE", function(ns, UI)
		if ns.caps.hasClassBuffs then
			fail(scenario, "SKIPPED -- a rogue has class buffs here")
			return
		end
		local B = ns.WindowBind
		local item = B.Item("general.moveToggle", nil, UI.ctx)
		if not (item and B.Hidden(item)) then fail(scenario, "a rogue is offered Move the prompt") end
		ns.OpenOptions("general", true)
		if UI.header.move and UI.header.move:IsShown() then
			fail(scenario, "the header shows Move the prompt to a class with nothing for the prompt to show")
		end
	end)
end

-- ------------------------------------------------------------------ /manners move
-- Another word for unlock, in the help, with the same lines, and the open
-- window's button follows it.
do
	local scenario = "hunt30-move: /manners move unlocks the prompt as /manners unlock does"
	with(scenario, "MAGE", function(ns, UI)
		local p = ns.db.profile.prompt
		local listed
		for _, command in ipairs(ns.COMMANDS or {}) do
			if command.word == "move" then listed = command end
		end
		if not (listed and listed.group == "setup") then
			fail(scenario, "/manners move is not among the commands in Setting it up")
		end
		Mock.printed = {}
		ns.addon:HandleSlash("help")
		if not said():find("/manners move|r", 1, true) then
			fail(scenario, "the help does not list /manners move")
		end
		Mock.printed = {}
		ns.addon:HandleSlash("unlock")
		local viaUnlock = said()
		ns.addon:HandleSlash("lock")
		ns.OpenOptions("general", true)
		Mock.printed = {}
		ns.addon:HandleSlash("move")
		if p.locked ~= false then fail(scenario, "/manners move left the prompt locked") end
		if said() ~= viaUnlock or viaUnlock == "" then
			fail(scenario, ("/manners move said %q where /manners unlock says %q"):format(said(), viaUnlock))
		end
		if label(UI.header.move) ~= "Lock it" then
			fail(scenario, "the open window's button still reads " .. tostring(label(UI.header.move)))
		end
		-- In a fight too: the same line, the setting written, nothing moved.
		ns.addon:HandleSlash("lock")
		Mock.inCombat = true
		Mock.printed = {}
		ns.addon:HandleSlash("unlock")
		local fightUnlock = said()
		ns.addon:HandleSlash("lock")
		Mock.printed = {}
		ns.addon:HandleSlash("move")
		if said() ~= fightUnlock or not fightUnlock:find("once this fight ends", 1, true) then
			fail(scenario, ("in a fight /manners move said %q where /manners unlock says %q"):format(said(), fightUnlock))
		end
		Mock.inCombat = false
		ns.addon:HandleSlash("lock")
		-- A preview over the prompt is ended for it, as for the button.
		ns.Prompt:ToggleTest()
		Mock.printed = {}
		ns.addon:HandleSlash("move")
		if ns.Prompt:InTest() or said():find("preview off", 1, true) then
			fail(scenario, "/manners move left the preview up or announced ending it: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ the prompt
-- Unlocked, the prompt's second line says what happens next, in the look's own
-- colour rather than a red warning, in the built-in looks and the three that
-- draw their lines themselves; the warning is its tooltip's, which stays up
-- while there is something to drag.
local LOOKS = { "glass", "framed", "minimal", "luxe", "toast", "arcane", "whisper", "heritage", "slate" }

for _, look in ipairs(LOOKS) do
	local scenario = "hunt30-move: the unlocked prompt says what happens next (" .. look .. ")"
	with(scenario, "MAGE", function(ns)
		local p, R = ns.db.profile.prompt, ns.Prompt.regions
		p.style = look
		ns.addon:HandleSlash("unlock")
		ns.addon:Tick()
		local name, sub = tostring(R.nameText:GetText()), tostring(R.subText:GetText())
		-- Slate sets its lines in capitals.
		if look == "slate" then name, sub = name:lower(), sub:lower() end
		if not name:find(look == "slate" and "drag to move" or "Drag to move", 1, true) then fail(scenario, "the first line reads " .. name) end
		if not sub:find(look == "slate" and "let go and it locks itself" or "Let go and it locks itself", 1, true) then
			fail(scenario, "the second line reads " .. sub)
		end
		if sub:find("not buffing", 1, true) or sub:lower():find("|cffff8080", 1, true) then
			fail(scenario, "the second line is still the red warning: " .. sub)
		end
		-- Locked again, the person comes back and the line goes.
		ns.addon:HandleSlash("lock")
		ns.addon:Tick()
		if tostring(R.subText:GetText()):find("Let go", 1, true) then
			fail(scenario, "the second line stayed after locking")
		end
	end)
end

do
	local scenario = "hunt30-move: the unlocked prompt's tooltip keeps the warning while there is something to drag"
	with(scenario, "MAGE", function(ns)
		local button = ns.Prompt:GetButton()
		local owner
		local realSetOwner, realIsOwned, realHide = GameTooltip.SetOwner, GameTooltip.IsOwned, GameTooltip.Hide
		GameTooltip.SetOwner = function(_, frame) owner = frame Mock.tooltip = {} end
		GameTooltip.IsOwned = function(_, frame) return owner ~= nil and owner == frame end
		GameTooltip.Hide = function() owner = nil end
		local ok, err = pcall(function()
			local function tip() return table.concat(Mock.tooltip or {}, "\n") end
			local function tick() button.scripts.OnUpdate(button, 0.3) end
			-- Locked with nobody on it: nothing to say.
			Mock.tooltip = {}
			button.scripts.OnEnter(button)
			if GameTooltip:IsOwned(button) then
				fail(scenario, "a locked prompt with nobody on it has a tooltip: " .. tip())
			end
			ns.addon:HandleSlash("unlock")
			ns.addon:Tick()
			button.scripts.OnEnter(button)
			for _, want in ipairs({ "Drag to move", "Let go and it locks itself", "not buffing while unlocked" }) do
				if not tip():find(want, 1, true) then
					fail(scenario, ("the tooltip does not say %q: %s"):format(want, (tip():gsub("\n", " / "))))
				end
			end
			tick()
			if not GameTooltip:IsOwned(button) then
				fail(scenario, "the tooltip went at the next check, with the prompt still up to be dragged")
			end
			-- Locked, it goes: what the button describes now is whoever it is armed
			-- at (a mage's own buff), not a drag.
			ns.addon:HandleSlash("lock")
			ns.addon:Tick()
			tick()
			if tip():find("Drag to move", 1, true) or tip():find("not buffing while unlocked", 1, true) then
				fail(scenario, "the drag tooltip stayed up over a locked prompt: " .. (tip():gsub("\n", " / ")))
			end
			-- Switched off or in a preview the panel is not up to be dragged.
			ns.addon:HandleSlash("unlock")
			ns.addon:HandleSlash("off")
			button.scripts.OnEnter(button)
			if GameTooltip:IsOwned(button) then
				fail(scenario, "the drag tooltip is up while the addon is off")
			end
		end)
		GameTooltip.SetOwner, GameTooltip.IsOwned, GameTooltip.Hide = realSetOwner, realIsOwned, realHide
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end)
end
