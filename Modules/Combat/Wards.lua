-- Manners: Combat -- reactive Fire Ward and Frost Ward buttons.

local ns = assert(MannersAPI:ModuleContext("combat"), "Manners module API is missing")
local L = ns.L
local plain = ns.plain
local Layout = assert(ns.CombatLayout, "Manners Combat layout API is missing")
local InCombatLockdown = _G.InCombatLockdown

local Wards = {}
ns.ReactiveWards = Wards

local FIRE, FROST = 4, 16
local STATE = "mannersreactivewards"
local DRIVER = "[combat] fight; peace"
local FALLBACK = "Interface\\Icons\\Spell_Fire_SealOfFire"
local GLOW = "Interface\\AddOns\\Manners\\Textures\\RingSq"
local FIGHT_EVENTS = { "UNIT_COMBAT", "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED" }
local ROWS = {
	fire = {
		key = "fire", school = FIRE,
		ranks = { 27128, 10225, 10223, 8458, 8457, 543 },
		icon = "Interface\\Icons\\Spell_Fire_SealOfFire",
	},
	frost = {
		key = "frost", school = FROST,
		ranks = { 32796, 28609, 10177, 8462, 8461, 6143 },
		icon = "Interface\\Icons\\Spell_Frost_FrostWard",
	},
}
local ORDER = { ROWS.fire, ROWS.frost }
local RANK = {}
for _, row in ipairs(ORDER) do
	for _, id in ipairs(row.ranks) do RANK[id] = row end
end

local slots, header = {}, nil
local fightOn, active, frame, settledOn = false, nil, nil, nil
local placedIcon, placedScale, placedRight = nil, nil, nil
local dirty = true

local function Profile()
	return ns.db and ns.db.profile
end

local function Enabled(db)
	db = db or Profile()
	return ns.ModuleActive and ns.ModuleActive("combat") == true
		and db ~= nil and db.enabled == true and db.prompt
		and db.prompt.reactiveWards == true
end

local function Supported()
	return ns.caps and ns.caps.secretRestrictions ~= true
end

function Wards.Supported() return Supported() end

function Wards.Learn()
	for _, row in ipairs(ORDER) do
		row.id, row.name = nil, nil
		for _, id in ipairs(row.ranks) do
			if ns.SpellKnown(id) == true then
				row.id = id
				row.name = ns.SpellNameFor(id)
				break
			end
		end
	end
	dirty = true
end

function Wards.Known(row)
	row = type(row) == "string" and ROWS[row] or row
	return row and row.id ~= nil and type(row.name) == "string" and row.name ~= ""
end

function Wards.Knows()
	if ROWS.fire.id == nil and ROWS.frost.id == nil then Wards.Learn() end
	return Wards.Known(ROWS.fire) or Wards.Known(ROWS.frost)
end

function Wards.Applies(db)
	return Enabled(db) and Supported() and Wards.Knows()
end

local function SchoolHas(mask, school)
	return mask >= school and mask % (school * 2) >= school
end

local function DamageSchool(unit, action, amount, school)
	if plain(unit) ~= "player" or plain(action) ~= "DAMAGE" then return nil end
	local hit, mask = plain(amount), plain(school)
	if type(hit) ~= "number" or hit <= 0 or type(mask) ~= "number" or mask <= 0 then return nil end
	local fire, frost = SchoolHas(mask, FIRE), SchoolHas(mask, FROST)
	if fire == frost then return nil end
	return fire and "fire" or "frost"
end

local function WardAura()
	local auras = _G.C_UnitAuras
	local read = type(auras) == "table" and auras.GetAuraDataByIndex or nil
	if type(read) ~= "function" then return false end
	for index = 1, 40 do
		local aura = read("player", index, "HELPFUL")
		if type(aura) ~= "table" then break end
		local id = plain(aura.spellId)
		if type(id) == "number" and RANK[id] then return true end
	end
	return false
end

local function Show(row, on)
	local slot = slots[row.key]
	if not slot or not slot.button then return end
	slot.visible = on == true
	slot.button:SetAlpha(slot.visible and 1 or 0)
	slot.name:SetText(slot.visible and ("|cffffd100" .. row.name .. "|r") or "")
	slot.cover:SetShown(fightOn and not slot.visible)
	if slot.visible then
		slot.glow:Show()
	else
		slot.glow:Hide()
	end
end

local function Hush()
	active = nil
	for _, row in ipairs(ORDER) do Show(row, false) end
end

local function Disarm()
	for _, row in ipairs(ORDER) do
		local slot = slots[row.key]
		local button = slot and slot.button
		if button and not InCombatLockdown() then
			button:SetAttribute("type1", nil)
			button:SetAttribute("macrotext1", nil)
			button:SetAttribute("type", nil)
			button:SetAttribute("macrotext", nil)
		end
	end
end

local function DisarmRow(row)
	local slot = slots[row.key]
	local button = slot and slot.button
	if button and not InCombatLockdown() then
		button:SetAttribute("type1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("type", nil)
		button:SetAttribute("macrotext", nil)
	end
end

local function Arm(row)
	local slot = slots[row.key]
	if not (slot and slot.button) then return end
	if not Wards.Known(row) then
		DisarmRow(row)
		return
	end
	local macro = "/cast " .. row.name
	slot.button:SetAttribute("type1", "macro")
	slot.button:SetAttribute("macrotext1", macro)
	slot.button:SetAttribute("type", "macro")
	slot.button:SetAttribute("macrotext", macro)
end

local function PreClick(row, mouse)
	if mouse ~= "LeftButton" then return end
	local pending = ns.pendingClick
	if pending and ns.ExpirePendingClick then ns.ExpirePendingClick(pending, L["you cast a ward instead"]) end
	Hush()
	ns.Trail("press", "pressed: " .. row.name)
end

local function OnEnter(slot, self)
	if not slot.visible then return end
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	if type(tip.SetSpellByID) == "function" then tip:SetSpellByID(slot.row.id) end
	tip:AddLine(L["Manners: a left click here casts this ward."], 0.75, 0.75, 0.75, true)
	ns.AddSettingsLine(tip, "appearance.reactiveWards")
	tip:Show()
end

local function Place(profile)
	local right = Layout.RightOf(ns.CureFight, ns.MendPet, ns.BreakFree)
	local key = tostring(right)
	if slots.fire and (placedIcon ~= profile.iconSize or placedScale ~= profile.scale or placedRight ~= key) then
		Layout.PlaceRight(slots.fire.button, right, profile)
		Layout.PlaceBelow(slots.frost.button, slots.fire.button, profile)
		placedIcon, placedScale, placedRight = profile.iconSize, profile.scale, key
	end
end

local SNIPPET = [=[
	local fire = self:GetFrameRef("fireward")
	local frost = self:GetFrameRef("frostward")
	local on = newstate == "fight" and self:GetAttribute("manners-on")
	if fire then
		if on then fire:Show(true) else fire:Hide(true) end
	end
	if frost then
		if on then frost:Show(true) else frost:Hide(true) end
	end
]=]

local function CreateSlot(row, relative)
	local old = slots[row.key]
	if old then return old end
	local button = CreateFrame("Button", "Manners" .. row.key:gsub("^%l", string.upper) .. "Ward",
		UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetClampedToScreen(true)
	button:RegisterForClicks("AnyDown")
	button:SetAttribute("pressAndHoldAction", true)
	button:SetAlpha(0)
	button:EnableMouse(true)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexture(row.icon or FALLBACK)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(GLOW)
	glow:SetBlendMode("ADD")
	glow:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 8)
	glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -8)
	glow:SetVertexColor(0.5, 0.85, 1)
	glow:Hide()
	local name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("BOTTOMLEFT", button, "RIGHT", 4, 1)
	name:SetText("")
	local cover = CreateFrame("Frame", nil, button)
	cover:SetAllPoints(button)
	cover:SetFrameLevel(button:GetFrameLevel() + 10)
	cover:EnableMouse(true)
	cover:Hide()
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	for index = 2, 31 do
		if index <= 5 then button:SetAttribute("type" .. index, "none") end
		button:SetAttribute("*type" .. index, "none")
	end
	local slot = { row = row, button = button, icon = icon, glow = glow, name = name,
		cover = cover, visible = false }
	slots[row.key] = slot
	button:SetScript("PreClick", function(_, mouse) PreClick(row, mouse) end)
	button:SetScript("OnEnter", function(self) OnEnter(slot, self) end)
	button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	button:Hide()
	return slot
end

local function EventFrame()
	if frame then return frame end
	frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(_, event, unit, action, flag, amount, school)
		if event == "UNIT_COMBAT" and plain(unit) ~= "player" then return end
		if event == "UNIT_AURA" and plain(unit) ~= "player" then return end
		if event == "UNIT_SPELLCAST_SUCCEEDED" and plain(unit) ~= "player" then return end
		ns.Guard("reactive wards", function()
			if event == "PLAYER_REGEN_DISABLED" then
				fightOn = true
				Hush()
				for _, watched in ipairs(FIGHT_EVENTS) do frame:RegisterEvent(watched) end
				if WardAura() then Hush() end
			elseif event == "UNIT_COMBAT" then
				local key = DamageSchool(unit, action, amount, school)
				local row = key and ROWS[key] or nil
				if row and fightOn and Wards.Applies() and Wards.Known(row) and not WardAura() then
					Hush()
					active = key
					Show(row, true)
				end
			elseif event == "UNIT_AURA" then
				if WardAura() then Hush() end
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
				local id = plain(flag)
				if active and type(id) == "number" and RANK[id] then Hush() end
			elseif event == "SPELLS_CHANGED" then
				if not InCombatLockdown() then
					Wards.Learn()
					Wards:Refresh()
				else
					dirty = true
				end
			end
		end)
	end)
	Wards.frame = frame
	return frame
end

function Wards:Create()
	if slots.fire or InCombatLockdown() then return end
	local fire = CreateSlot(ROWS.fire)
	local frost = CreateSlot(ROWS.frost)
	if type(_G.RegisterStateDriver) == "function" then
		local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
		if ok and type(made) == "table" and type(made.SetFrameRef) == "function" then
			made:SetFrameRef("fireward", fire.button)
			made:SetFrameRef("frostward", frost.button)
			made:SetAttribute("manners-on", false)
			made:SetAttribute("_onstate-" .. STATE, SNIPPET)
			_G.RegisterStateDriver(made, STATE, DRIVER)
			header = made
		end
	end
end

function Wards:Refresh()
	if InCombatLockdown() then return end
	local db = Profile()
	if not db then return end
	local wanted = Enabled(db)
	local eventFrame = wanted and Supported() and EventFrame() or frame
	if eventFrame then
		eventFrame:RegisterEvent("SPELLS_CHANGED")
		eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		if not wanted or not Supported() then
			eventFrame:UnregisterAllEvents()
		end
	end
	if not Wards.Applies(db) then
		Disarm()
		Hush()
		fightOn, settledOn = false, false
		if header then header:SetAttribute("manners-on", false) end
		for _, row in ipairs(ORDER) do
			local slot = slots[row.key]
			if slot and slot.button:IsShown() then slot.button:Hide() end
		end
		dirty = false
		return
	end
	Wards:Create()
	for _, row in ipairs(ORDER) do
		Arm(row)
		Show(row, false)
	end
	Place(db.prompt)
	Hush()
	if header then
		header:SetAttribute("manners-on", true)
		header:SetAttribute("state-" .. STATE, "peace")
	end
	for _, row in ipairs(ORDER) do
		local slot = slots[row.key]
		if slot and slot.button:IsShown() then slot.button:Hide() end
	end
	placedIcon, placedScale = db.prompt.iconSize, db.prompt.scale
	settledOn, dirty, fightOn = true, false, false
end

function Wards:Wanted()
	local db = Profile()
	if not db or InCombatLockdown() then return false end
	local on = Wards.Applies(db) and true or false
	if dirty or on ~= settledOn then return true end
	if not on then return false end
	local p = db.prompt
	local right = tostring(Layout.RightOf(ns.CureFight, ns.MendPet, ns.BreakFree))
	return p.iconSize ~= placedIcon or p.scale ~= placedScale or right ~= placedRight
end

function Wards:Release()
	fightOn = false
	if frame then
		for _, event in ipairs(FIGHT_EVENTS) do frame:UnregisterEvent(event) end
	end
	Hush()
	if not Wards.Applies(Profile()) then
		if frame then
			frame:UnregisterEvent("SPELLS_CHANGED")
			frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
		end
		Disarm()
		for _, row in ipairs(ORDER) do
			local slot = slots[row.key]
			if slot then slot.cover:SetShown(InCombatLockdown()) end
		end
		settledOn, dirty = false, true
		return
	end
	dirty = true
	self:Refresh()
end

function Wards:Button(key) local slot = slots[key or "fire"] return slot and slot.button end
function Wards:Look(key)
	local slot = slots[key or "fire"]
	return slot and { alpha = slot.button:GetAlpha(), name = slot.name:GetText(),
		cover = slot.cover, visible = slot.visible }
end
