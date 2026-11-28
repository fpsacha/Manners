-- Manners -- the consumables button: your food, flasks, elixirs, scrolls and a
-- weapon's oils, stones and poisons on a small button of their own, with
-- "Put consumables on a button of their own" on (ownBuffs.apart). Asked for on
-- CurseForge: the prompt in plain sight, the consumables somewhere out of the
-- way. The prompt then never offers them (Queue.lua, OwnPick); this button
-- offers the first one due (ns.SupplyEntry), by the same rules as "Myself".
--
-- A secure button of its own (MannersSupplies), with its own key
-- (Bindings.xml) and its own place (db.supplies, dragged while the prompt is
-- unlocked). Its macro is the prompt's own for the item (Prompt/Macro.lua,
-- ns.ItemMacro), armed out of combat only. Nothing of yours is used in a
-- fight, so the fight always takes it away: a secure state driver, as Hide the
-- prompt in combat uses (Prompt/Fight.lua, which says why a driver alone is
-- not enough), takes the macro off and only then hides it, in the restricted
-- environment, at the pull. The next repaint after the fight arms it afresh.
-- The button wears the socket of the prompt's look (Painted.Socket, Looks/
-- Painted.lua): the painting's frame round the icon's hole, the icon in it, and
-- round where the socket is round. Plain under Earlier art for a look that has
-- earlier art. One texture and a cached check (Wear), out of combat, no setting:
-- it follows the look.
-- A press writes what a press on the prompt writes for one of your own: the
-- retry block, the hand an oil goes on busy, the scroll last used (Core.lua,
-- NoteScrollPress). A right-click skips the item for the skip time.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("mybuffs"), "Manners module API is missing")
local L = ns.L
local Prompt = ns.Prompt
local lib = Prompt.lib
local InCombatLockdown = _G.InCombatLockdown

local Supplies = {}
ns.Supplies = Supplies

-- The key binding that presses the button (Bindings.xml), which the options
-- window sets from My own buffs.
Supplies.COMMAND = "CLICK MannersSupplies:LeftButton"

local STATE = "mannerssupplies"
local DRIVER = "[combat] fight; peace"
-- Shown while the prompt is unlocked, for dragging: a bag.
local PLACEHOLDER = "Interface\\Icons\\INV_Misc_Bag_08"
-- The icon's round mask, the one the painted looks use.
local ROUND_MASK = "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask"

local button, icon, header, socket, mask
-- The item's name under the button, and the plate over it while it is moved.
local caption, plate
-- Moving from My own buffs: shown, holding nothing, dragged by any press.
local moving = false
local DEFAULT_SPOT = { point = "BOTTOM", relPoint = "BOTTOM", x = -170, y = 300 }
-- The entry the macro is armed for, and the macro itself, written only when
-- it changes.
local current, armedMacro
-- Where it was last put, so it is placed again only when that changes.
local placedKey
-- What it wears: the look, Earlier art and the size it was last dressed for, so
-- the socket is cut again only when one of them changes.
local woreStyle, woreEarlier, woreSize, masked

-- Runs in the restricted environment: disarmed first, then hidden, so a
-- snippet stopped half way leaves a button that uses nothing.
local SNIPPET = [=[
	if newstate ~= "fight" then return end
	local button = self:GetFrameRef("supplies")
	if button then
		button:SetAttribute("type1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("type", nil)
		button:SetAttribute("macrotext", nil)
		button:Hide(true)
	end
]=]

local function Profile()
	return ns.db and ns.db.profile
end

local function Disarm()
	current = nil
	if armedMacro ~= nil then
		button:SetAttribute("type1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("type", nil)
		button:SetAttribute("macrotext", nil)
		armedMacro = nil
	end
end

local function Arm(entry)
	current = entry
	local macro = ns.ItemMacro(entry)
	-- Asked of the button too: a fight's snippet empties it behind our back.
	if macro == armedMacro and button:GetAttribute("macrotext1") == macro then return end
	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)
	armedMacro = macro
end

local function Place(db)
	local s = db.supplies
	local key = table.concat({ tostring(s.point), tostring(s.relPoint), tostring(s.x), tostring(s.y), tostring(s.size) }, ":")
	if key == placedKey then return end
	placedKey = key
	button:ClearAllPoints()
	button:SetPoint(s.point or "BOTTOM", UIParent, s.relPoint or "BOTTOM", tonumber(s.x) or 0, tonumber(s.y) or 0)
	button:SetSize(s.size, s.size)
end

-- The socket of the prompt's look round the icon (Painted.Socket), the icon in
-- its hole and rounded where the socket is. The whole button stays the size the
-- player set; a look with no socket, or Earlier art, leaves the icon on all of it.
local function Wear(db)
	local p = db.prompt
	local style, earlier, size = p.style, p.classicArt == true, db.supplies.size
	if style == woreStyle and earlier == woreEarlier and size == woreSize then return end
	woreStyle, woreEarlier, woreSize = style, earlier, size
	local Looks = ns.Looks
	local look = Looks and style and Looks.list[style]
	local key = (look and look.fallback) or style
	if look and look.fallback then look = Looks.list[key] end
	local d = ns.PaintedData and key and ns.PaintedData[key]
	local Painted = Looks and Looks.Painted
	local round, fill = false, nil
	if d and Painted and Painted.Socket and (not earlier or (look and look.paintedOnly)) then
		local u0, u1, v0, v1, share, isRound = Painted.Socket(d)
		socket:SetTexture(d.left.file)
		socket:SetTexCoord(u0, u1, v0, v1)
		Looks.Colour(socket, 1, 1, 1)
		socket:Show()
		fill, round = share, isRound
	else
		socket:Hide()
	end
	icon:ClearAllPoints()
	if fill then
		local inset = size * (1 - fill) / 2
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
	else
		icon:SetAllPoints(button)
	end
	if round and mask then
		if not masked then icon:AddMaskTexture(mask); masked = true end
		mask:Show()
	elseif masked then
		icon:RemoveMaskTexture(mask); masked = nil; mask:Hide()
	end
end

-- Where a drag left it, in whole pixels.
local function SavePosition()
	local db = Profile()
	if not db then return end
	local point, _, relPoint, x, y = button:GetPoint(1)
	local s = db.supplies
	s.point, s.relPoint = point or "BOTTOM", relPoint or "BOTTOM"
	s.x, s.y = math.floor((tonumber(x) or 0) + 0.5), math.floor((tonumber(y) or 0) + 0.5)
	placedKey = nil
end

-- A left press: what a press on the prompt writes for one of your own.
local function PreClick(_, mouse)
	if InCombatLockdown() or mouse ~= "LeftButton" or not current then return end
	-- Moving since the scan armed it (Core.lua, ns.StillCut): nothing is used.
	if ns.StillCut(current, _G.GetTime()) then
		Disarm()
		return
	end
	ns.MarkAttempted(current.name, current.buff.key)
	ns.NoteScrollPress(current.buff)
	ns.Trail("press", ("pressed: %s, from the consumables button"):format(tostring(current.buff.key)), current.name)
end

-- A right press: not now, for the skip time; the next due comes up.
local function OnClick(_, mouse)
	if mouse ~= "RightButton" or InCombatLockdown() or not current then return end
	ns.SkipOwn(current.name, current.buff.key, ns.OwnSkipSeconds())
	Supplies:Refresh()
end

local function OnEnter(self)
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	if current and not moving then
		tip:AddLine(L["Manners: consumables"], 1, 0.82, 0)
		tip:AddLine(ns.BuffName(current.buff) or "", 1, 1, 1)
		tip:AddLine(L["Left-click to use it, right-click to skip it for now."], 0.75, 0.75, 0.75, true)
	elseif moving then
		tip:AddLine(L["Manners: consumables"], 1, 1, 1)
		tip:AddLine(L["Drag it to move it."], 0.75, 0.75, 0.75, true)
	else
		tip:AddLine(L["Manners: consumables"], 1, 1, 1)
		tip:AddLine(L["Drag to move it. Lock the prompt to use it."], 0.75, 0.75, 0.75, true)
	end
	ns.AddSettingsLine(tip, "who.ownApart")
	tip:Show()
end

local function OnLeave()
	local tip = _G.GameTooltip
	if tip then tip:Hide() end
end

-- Made the first time it is wanted, out of combat.
function Supplies:Create()
	if button or InCombatLockdown() then return end
	button = CreateFrame("Button", "MannersSupplies", UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetClampedToScreen(true)
	button:SetMovable(true)
	button:RegisterForClicks("AnyDown")
	-- A key press is a down click: without this the client takes it as neither
	-- the action nor a release while ActionButtonUseKeyDown is off (Panel.lua).
	button:SetAttribute("pressAndHoldAction", true)
	button:RegisterForDrag("LeftButton")
	socket = button:CreateTexture(nil, "BACKGROUND")
	socket:SetAllPoints(button)
	socket:Hide()
	icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	if button.CreateMaskTexture and icon.AddMaskTexture then
		mask = button:CreateMaskTexture()
		mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(icon)
		mask:Hide()
	end
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	local hl = button:GetHighlightTexture()
	if hl then hl:SetAllPoints(icon) end
	-- On the frame, for the scenarios to read.
	button.socket, button.socketMask = socket, mask
	-- Only the left button uses the item: every other one is told to do
	-- nothing, the modifier-prefixed lookups too (Prompt/Macro.lua says why).
	for index = 2, 31 do
		if index <= 5 then button:SetAttribute("type" .. index, "none") end
		button:SetAttribute("*type" .. index, "none")
	end
	button:SetScript("PreClick", PreClick)
	button:HookScript("OnClick", OnClick)
	button:SetScript("OnDragStart", function(self)
		local db = Profile()
		if db and (moving or not db.prompt.locked) and not InCombatLockdown() then self:StartMoving() end
	end)
	-- What it is, under it, so a lone square on the screen reads as Manners'.
	caption = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	caption:SetPoint("TOP", button, "BOTTOM", 0, -2)
	caption:SetWidth(140)
	caption:SetWordWrap(false)
	button.caption = caption
	-- The plate over it while it is moved from My own buffs: what it is, how to
	-- move it, and the two ways out, as the combat prompt's mover has.
	plate = CreateFrame("Frame", "MannersSuppliesMover", button)
	plate:SetPoint("BOTTOM", button, "TOP", 0, 6)
	plate:SetSize(260, 50)
	plate:SetFrameStrata("DIALOG")
	local back = plate:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	back:SetColorTexture(0.05, 0.04, 0.03, 0.92)
	local rim = plate:CreateTexture(nil, "BORDER")
	rim:SetPoint("TOPLEFT", plate, "TOPLEFT", 0, 0)
	rim:SetPoint("TOPRIGHT", plate, "TOPRIGHT", 0, 0)
	rim:SetHeight(2)
	rim:SetColorTexture(1, 0.82, 0, 0.9)
	local title = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", plate, "TOPLEFT", 10, -8)
	title:SetText(L["Manners: consumables"])
	local how = plate:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	how:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	how:SetText(L["Drag it to move it."])
	local done = CreateFrame("Button", nil, plate, "UIPanelButtonTemplate")
	done:SetSize(60, 22)
	done:SetPoint("RIGHT", plate, "RIGHT", -8, 0)
	done:SetText(L["Done"])
	done:SetScript("OnClick", function() ns.Guard("consumables button", Supplies.Move, Supplies, false) end)
	local reset = CreateFrame("Button", nil, plate, "UIPanelButtonTemplate")
	reset:SetSize(60, 22)
	reset:SetPoint("RIGHT", done, "LEFT", -6, 0)
	reset:SetText(L["Reset"])
	reset:SetScript("OnClick", function() ns.Guard("consumables button", Supplies.ResetSpot, Supplies) end)
	plate.done, plate.reset = done, reset
	plate:Hide()
	button.plate = plate
	-- The pull ends a move (the driver hides the button itself).
	local watch = CreateFrame("Frame")
	watch:RegisterEvent("PLAYER_REGEN_DISABLED")
	watch:SetScript("OnEvent", function() Supplies:Pull() end)
	button:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnLeave", OnLeave)
	button:Hide()
	if type(_G.RegisterStateDriver) == "function" then
		local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
		if ok and type(made) == "table" and type(made.SetFrameRef) == "function" then
			made:SetFrameRef("supplies", button)
			made:SetAttribute("_onstate-" .. STATE, SNIPPET)
			_G.RegisterStateDriver(made, STATE, DRIVER)
			header = made
		end
	end
end

-- On every scan (Core.lua, TickBody), and at both ends of a fight. Out of
-- combat only: in one, the snippet has it, and nothing of yours is offered.
function Supplies:Refresh(now)
	local db = Profile()
	if not db or InCombatLockdown() then return end
	if not ns.ModuleActive("mybuffs") or not ns.ItemsApart(db) then
		if button then
			Disarm()
			button:Hide()
		end
		return
	end
	if not button then self:Create() end
	if not button then return end
	-- The next pull is a change whatever the driver last read.
	if header and header:GetAttribute("state-" .. STATE) ~= "peace" then
		header:SetAttribute("state-" .. STATE, "peace")
	end
	Place(db)
	-- Before the unlocked branch: the drag placeholder wears the look too.
	Wear(db)
	plate:SetShown(moving)
	-- Unlocked, or moved from My own buffs: shown, holding nothing, to be dragged
	-- where it goes.
	if moving or not db.prompt.locked then
		Disarm()
		icon:SetTexture(PLACEHOLDER)
		caption:SetText(L["Manners: consumables"])
		button:Show()
		return
	end
	now = now or GetTime()
	local entry = db.enabled and not ns.SnoozeLeft(now) and ns.SupplyEntry(db, now) or nil
	if not entry then
		Disarm()
		button:Hide()
		return
	end
	Arm(entry)
	icon:SetTexture(lib.EntryIcon(entry))
	caption:SetText(ns.BuffName(entry.buff) or "")
	button:Show()
end

-- Whether a scan has anything to do here: the switch on, or a button made
-- before it went off, to be taken down.
function Supplies:Wanted()
	return ns.ModuleActive("mybuffs") and (button ~= nil or ns.ItemsApart(Profile()))
end

function Supplies:Suspend()
	moving = false
	if not button then return end
	if plate then plate:Hide() end
	Disarm()
	button:Hide()
end

-- Shown and dragged from My own buffs (Show and move the consumables button),
-- or put back. Out of a fight only; the pull ends it.
function Supplies:Move(on)
	if InCombatLockdown() then return end
	moving = on == true
	if moving and not button then self:Create() end
	self:Refresh()
	if ns.RefreshOptionsDisplay then ns.Guard("options repaint", ns.RefreshOptionsDisplay) end
end

function Supplies:Moving() return moving end

-- Back where it starts, under the prompt's left.
function Supplies:ResetSpot()
	local db = Profile()
	if not db or InCombatLockdown() then return end
	for k, v in pairs(DEFAULT_SPOT) do db.supplies[k] = v end
	placedKey = nil
	self:Refresh()
end

-- A fight ends the move: the driver hides the button, and nothing is armed.
function Supplies:Pull()
	moving = false
	if plate then plate:Hide() end
end

-- For tests and /manners selftest.
function Supplies:Button() return button end
function Supplies:Header() return header end
function Supplies:Current() return current end
