-- Manners -- the names in the list as buttons: a left click on a name buffs
-- that person exactly as if they had been on the prompt and the prompt had
-- been pressed.
--
-- WHY EACH NAME IS A BUTTON OF ITS OWN, AND NOT A DELEGATE OF THE PROMPT
--
-- The tempting design is a row of type "click" whose clickbutton is the
-- prompt: the row's PreClick says who, and the prompt's own PreClick and
-- PostClick do the rest, so nothing about the macro is written twice. Blizzard's
-- secure code (Gethe/wow-ui-source, branch forever, Blizzard_FrameXML/
-- SecureTemplates.lua) rules it out for this button:
--
--   * SECURE_ACTIONS.click (line 557) runs `delegate:Click(button)` and hands
--     on the mouse button only. Button:Click(button, isDown) takes the phase
--     as its second argument and defaults it to false (the Click entry of
--     Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua), so
--     the delegate always receives an up click, whatever phase the row was
--     pressed in.
--   * The prompt is registered for "AnyDown" with pressAndHoldAction set, the
--     one configuration known to cast on this client (Panel.lua; CHANGELOG
--     1.2.0 and 1.3.0: an up delivery casts nothing here). SecureActionButton_
--     OnClick (line 802) takes useOnKeyDown as true under pressAndHoldAction
--     for any click that is not a secure mouse press, a scripted Click()
--     among them (its own comment says so), so an up click is not the action
--     but the release, and the release looks up `typerelease`, which the
--     prompt does not carry (it would run the macro a second time on every
--     real press).
--
-- So a delegate would be handed a click that casts nothing. Instead each row
-- is registered and silenced exactly as the prompt is (the same trio, the same
-- wildcards) and armed by the same routine, Macro.lua's Arm, from the same
-- STRATEGIES: the macro of a press on a name is the macro of a press on the
-- prompt, because it is built by the same code, and a click on a row is
-- handled by the client exactly as a click on the prompt is. Its press is
-- filed by the same OnPostClick (Press.lua), with the row's slot standing in
-- for the prompt's state.
--
-- A row holds no macro at rest. PreClick arms it, for the length of one press,
-- from a fresh queue; PostClick files the press and lets it go. So there is
-- nothing to keep in step with the repaints, nothing a fight can freeze (the
-- secure attributes cannot change in combat, and a row with none does
-- nothing), and nothing that can be left aimed at somebody: DisarmRows lets go
-- of anything a cut-short press left, at the start of a fight, and a row armed
-- for longer than a press can take is let go on the next repaint.
--
-- The rows are children of the prompt's button, so they go when it goes, and
-- their click areas hang off the list's own font strings: whichever way a look
-- lays the list out (built-in, above or below, or a look's own PaintQueue), the
-- area follows the text it covers. A row with nobody on it is hidden.

local _, ns = ...
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local WHITE, ROW_SCRIPTS, SilenceOtherButtons = lib.WHITE, lib.ROW_SCRIPTS, lib.SilenceOtherButtons

-- How long a row may stay armed. A press is over within the frame; this only
-- catches one that was cut short.
local ARMED_SECONDS = 3

-- How far left of a row's text its marker starts, for a look that does not
-- say (its `rowReach`).
local ROW_REACH = 18

-- The slot of each row: the button, what the row names (entry, name, buffKey,
-- painted by PaintRows) and, for the length of a press, what Arm keeps of the
-- armed macro (current, appliedKey, armed, the spoken line) -- the same fields
-- the prompt keeps on S.
local function Slot(i)
	local button = CreateFrame("Button", "MannersPromptRow" .. i, R.button, "SecureActionButtonTemplate")
	-- The prompt's own registration: "AnyDown" with pressAndHoldAction (Panel.lua).
	button:RegisterForClicks("AnyDown")
	button:SetAttribute("pressAndHoldAction", true)
	local row = { button = button, index = i, isRow = true }
	button.mannersRow = row
	-- Every button but the left is silenced from the start: the client
	-- looks an attribute up modifier-prefixed, then wildcarded, then bare, so
	-- anything left unsilenced falls through to the macro.
	SilenceOtherButtons(row)
	for _, script in ipairs(ROW_SCRIPTS) do
		button:SetScript(script[1], script[2])
	end
	-- Lit while the cursor is on the name.
	row.wash = button:CreateTexture(nil, "BACKGROUND")
	row.wash:SetAllPoints(button)
	row.wash:SetTexture(WHITE)
	row.wash:SetVertexColor(1, 1, 1, 0.07)
	row.wash:Hide()
	button:Hide()
	return row
end

-- Once, out of combat, from Create.
function Prompt:CreateRows()
	R.rowSlots, R.rowButtons = {}, {}
	for i = 1, #R.queueRows do
		local row = Slot(i)
		R.rowSlots[i], R.rowButtons[i] = row, row.button
	end
end

-- Each name's click area, hung off its own text: from `reach` left of it (so
-- the marker and the icon are part of the name) to just past its end, as tall
-- as the rows are apart, so neighbours meet. Out of combat (ApplyStyle's rule).
function Prompt:PlaceRows(p, look, reach)
	if not R.rowButtons then return end
	local pitch = look and look.pitch or (p.fontSize + 4)
	reach = reach or (look and look.rowReach) or ROW_REACH
	for i, fs in ipairs(R.queueRows) do
		local button = R.rowButtons[i]
		button:ClearAllPoints()
		button:SetPoint("LEFT", fs, "LEFT", -reach, 0)
		button:SetPoint("RIGHT", fs, "RIGHT", 4, 0)
		button:SetHeight(pitch)
	end
end

-- Lets go of whatever a press left on the rows. Out of combat only: that is
-- the one time the attributes can be written, and the one time a row could be
-- left aimed at somebody for a fight to freeze.
function Prompt:DisarmRows()
	if not R.rowSlots or InCombatLockdown() then return end
	for _, row in ipairs(R.rowSlots) do
		row.pressing = nil
		self:ArmRow(row, nil)
	end
end

-- Whether any row holds somebody, is shown, is armed or has the cursor on it.
-- While none does, a repaint with nobody listed has nothing to undo and asks
-- the client nothing: it runs on every scan, listed or not.
local busy = false

-- The rows as the list was just painted: each name the list holds is pressable
-- until the next repaint says otherwise. `rows` is the list's own (List.lua),
-- nil to clear it. A row with nobody, with the option off, or in a preview (a
-- mock row names nobody) is hidden, and so cannot be clicked; in a fight
-- nothing is shown or hidden (the client refuses it), and what the rows say
-- is cleared, so a click finds nobody. No attribute is written here at all.
function Prompt:PaintRows(rows)
	local slots = R.rowSlots
	if not slots then return end
	if not busy and not (rows and rows[1]) then return end
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	local clickable = p and p.clickRows ~= false and not S.testMode
	local combat = InCombatLockdown()
	local now = GetTime()
	local any = false
	for i, row in ipairs(slots) do
		local data = rows and rows[i]
		local entry = clickable and data and data.entry or nil
		if entry and entry.buff and entry.name then
			local key = entry.buff.key
			local changed = row.name ~= entry.name or row.buffKey ~= key
			row.entry, row.name, row.buffKey = entry, entry.name, key
			if not combat then
				if not row.shown then
					row.button:Show()
					row.shown = true
				end
				-- The tooltip under the cursor says who the row names now.
				if changed and row.hovered then
					local onEnter = row.button:GetScript("OnEnter")
					if onEnter then onEnter(row.button) end
				end
			end
		else
			row.entry, row.name, row.buffKey = nil, nil, nil
			if row.hovered then
				row.hovered = nil
				row.wash:Hide()
				if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row.button) then
					GameTooltip:Hide()
				end
			end
			if not combat and row.shown then
				row.button:Hide()
				row.shown = false
			end
		end
		-- Armed for longer than a press takes: a press that was cut short.
		if row.appliedKey and not combat and now - (row.armedAt or 0) > ARMED_SECONDS then
			row.pressing = nil
			self:ArmRow(row, nil)
		end
		if row.entry or row.shown or row.appliedKey or row.hovered then any = true end
	end
	busy = any
end
