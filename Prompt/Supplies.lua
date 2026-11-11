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
-- A press writes what a press on the prompt writes for one of your own: the
-- retry block, the hand an oil goes on busy, the scroll last used (Core.lua,
-- NoteScrollPress). A right-click skips the item for the skip time.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local lib = Prompt.lib
local InCombatLockdown = _G.InCombatLockdown

local Supplies = {}
ns.Supplies = Supplies

local STATE = "mannerssupplies"
local DRIVER = "[combat] fight; peace"
-- Shown while the prompt is unlocked, for dragging: a bag.
local PLACEHOLDER = "Interface\\Icons\\INV_Misc_Bag_08"

local button, icon, header
-- The entry the macro is armed for, and the macro itself, written only when
-- it changes.
local current, armedMacro
-- Where it was last put, so it is placed again only when that changes.
local placedKey

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
	ns.MarkAttempted(current.name, current.buff.key)
	ns.NoteScrollPress(current.buff)
	ns.Trail("press", ("pressed: %s, from the consumables button"):format(tostring(current.buff.key)), current.name)
end

-- A right press: not now, for the skip time; the next due comes up.
local function OnClick(_, mouse)
	if mouse ~= "RightButton" or InCombatLockdown() or not current then return end
	ns.MarkAttempted(current.name, current.buff.key, ns.SkipSeconds())
	Supplies:Refresh()
end

local function OnEnter(self)
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	if current then
		tip:AddLine(ns.BuffName(current.buff) or "", 1, 1, 1)
		tip:AddLine(L["Left-click to use it, right-click for not now."], 0.75, 0.75, 0.75, true)
	else
		tip:AddLine(L["Manners: consumables"], 1, 1, 1)
		tip:AddLine(L["Drag to move it. Lock the prompt to use it."], 0.75, 0.75, 0.75, true)
	end
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
	button:RegisterForDrag("LeftButton")
	icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
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
		if db and not db.prompt.locked and not InCombatLockdown() then self:StartMoving() end
	end)
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
	if not ns.ItemsApart(db) then
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
	-- Unlocked: shown, holding nothing, to be dragged where it goes.
	if not db.prompt.locked then
		Disarm()
		icon:SetTexture(PLACEHOLDER)
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
	button:Show()
end

-- Whether a scan has anything to do here: the switch on, or a button made
-- before it went off, to be taken down.
function Supplies:Wanted()
	return button ~= nil or ns.ItemsApart(Profile())
end

-- For tests and /manners selftest.
function Supplies:Button() return button end
function Supplies:Header() return header end
function Supplies:Current() return current end
