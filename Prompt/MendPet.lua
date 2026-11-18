-- Manners -- a hunter's Mend Pet in a fight: a small secure button of its own,
-- to the right of the prompt (or of the break-free button, where a Forsaken
-- hunter has both), with a key of its own, shown for the length of every fight
-- and lit while the pet is below half its health, in reach, alive, and Mend Pet
-- is not still at work. Modelled on Prompt/BreakFree.lua, whose header says why
-- a fight needs a button of its own: the prompt is locked by the lockdown and
-- its key keeps to buffs.
--
-- WHAT IT KNOWS
--
-- Whether it applies: a hunter who knows Mend Pet, has had a pet out and does
-- not have Lone Wolf (HunterPet.lua's Beast), with the switch on (`beast.fightMend`
-- and the master `beast.all`). Whether it is lit: the pet's health where the
-- client says it in a fight, and our own record of Mend Pet at work (a cast of
-- yours, the bar's included, starts a wait as long as the spell channels or
-- heals on that client). Where the pet's health is secret in a fight (Forever,
-- retail) the button stays half lit with its two lines shown, and still casts.
-- Lua paints only its own regions and alpha in a fight; the shown state, the
-- macro and the place are written out of combat only.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local R = Prompt.regions
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local plain = ns.plain
local Beast = ns.Beast

local MendPet = {}
ns.MendPet = MendPet

-- What Bindings.xml declares.
MendPet.COMMAND = "CLICK MannersMendPet:LeftButton"
_G["BINDING_NAME_CLICK MannersMendPet:LeftButton"] = L["Mend Pet in a fight"]

local STATE = "mannersmendpet"
local DRIVER = "[combat] fight; peace"
-- Between the prompt's (or the break-free button's) right edge and this button.
local GAP = 10
-- How long after a press of this button its spell going out is waited for.
local SUCCEED_SECONDS = 1
-- A repaint after a health event waits this long; the last one is not lost.
local REPAINT = 0.1
local FALLBACK_ICON = "Interface\\Icons\\Ability_Hunter_MendPet"
local GLOW = "Interface\\AddOns\\Manners\\Textures\\RingSq"
-- How long Mend Pet works after a cast, by client: a channel of five seconds on
-- Forever and Classic Era, a heal over time of fifteen on Burning Crusade and ten
-- on Mists, a ten-second cooldown on retail.
local BUSY = { camelot = 5, vanilla = 5, tbc = 15, mists = 10, mainline = 10 }
local FLAVOUR = ns.Flavour and ns.Flavour.flavour

local button, header, icon, glow, pulse, nameText, keyText
local armedMacro, placedKey, paintedKey, keyLabel
local placedBeside = false
local waitUntil, readyAt
local paintDue = false
local dirty, settledOn, placedIcon, placedScale = true, nil, nil, nil

local function Profile()
	return ns.db and ns.db.profile
end

-- Whether this character has a hunter's Mend Pet to offer and the switch is on.
function MendPet.Applies(db)
	db = db or Profile()
	if not (db ~= nil and db.enabled == true and type(db.beast) == "table") then return false end
	if db.beast.all == false or db.beast.fightMend == false then return false end
	return Beast.IsHunter() and Beast.KnowsMend() and Beast.HadPet()
end

-- Whether it is lit, and whether the pet's health was readable.
local function Lit(now)
	if readyAt and now < readyAt then return false, true end
	if plain(_G.UnitExists("pet")) ~= true or plain(_G.UnitIsDead("pet")) == true then return false, true end
	local health, most = plain(_G.UnitHealth("pet")), plain(_G.UnitHealthMax("pet"))
	if type(health) ~= "number" or type(most) ~= "number" or most <= 0 then return false, false end
	if health / most >= Beast.K.MEND_BELOW then return false, true end
	local range = _G.C_Spell and _G.C_Spell.IsSpellInRange
	local id = Beast.MendId()
	if type(range) == "function" and id and plain(range(id, "pet")) == false then return false, true end
	return true, true
end

-- Its own regions and its alpha, which the client lets an addon change in a fight.
local function Paint()
	if not button then return false end
	local lit, known = Lit(GetTime())
	local key = tostring(lit) .. ":" .. tostring(known) .. ":" .. tostring(keyLabel)
	if key == paintedKey then return lit end
	paintedKey = key
	button:SetAlpha(lit and 1 or (known and 0.35 or 0.6))
	if lit then
		glow:Show()
		if pulse and not pulse:IsPlaying() then pulse:Play() end
	else
		if pulse then pulse:Stop() end
		glow:Hide()
	end
	if lit or not known then
		nameText:SetText("|cffffd100" .. tostring(Beast.MendName()) .. "|r")
		keyText:SetText(keyLabel and L["press %s to mend your pet"]:format(keyLabel) or L["click to mend your pet"])
	else
		nameText:SetText("")
		keyText:SetText("")
	end
	return lit
end

local function Disarm()
	if armedMacro ~= nil then
		button:SetAttribute("type1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("type", nil)
		button:SetAttribute("macrotext", nil)
		armedMacro = nil
	end
end

-- The one spell, and nothing else: no target, no line, no other press.
local function Arm(name)
	local macro = "/cast " .. name
	if macro == armedMacro and button:GetAttribute("macrotext1") == macro then return end
	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)
	armedMacro = macro
end

-- Beside the break-free button where there is one, else the prompt's right edge:
-- anchored to a frame (never a region: CLAUDE.md), the size of the prompt's icon.
local function Place(p)
	placedIcon, placedScale = p.iconSize, p.scale
	local size = math.floor(math.max(24, math.min(48, tonumber(p.iconSize) or 30)) * (tonumber(p.scale) or 1) + 0.5)
	local bf = ns.BreakFree
	local beside = bf and bf.Applies() and bf:Button() or nil
	placedBeside = beside ~= nil
	local key = size .. ":" .. tostring(placedBeside)
	if key == placedKey then return end
	placedKey = key
	button:ClearAllPoints()
	button:SetPoint("LEFT", beside or R.button, "RIGHT", GAP, 0)
	button:SetSize(size, size)
end

-- A press, by its key or a left click: in a fight too. The press the prompt
-- filed is not this one's, so it is let go with its own reason.
local function PreClick(_, mouse)
	if mouse ~= "LeftButton" then return end
	waitUntil = GetTime() + SUCCEED_SECONDS
	local pending = ns.pendingClick
	if pending and ns.ExpirePendingClick then ns.ExpirePendingClick(pending, L["you mended your pet instead"]) end
	ns.Trail("press", "pressed: mend pet")
end

local function OnEnter(self)
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	local id = Beast.MendId()
	if id and type(tip.SetSpellByID) == "function" then
		tip:SetSpellByID(id)
	else
		tip:AddLine(tostring(Beast.MendName()), 1, 1, 1)
	end
	tip:AddLine(L["Manners: a left click here casts it, as its key does. The prompt's own key keeps to buffs."], 0.75, 0.75, 0.75, true)
	tip:Show()
end

local function OnLeave()
	local tip = _G.GameTooltip
	if tip then tip:Hide() end
end

-- Runs in the restricted environment: shown for the fight, hidden after.
local SNIPPET = [=[
	local mend = self:GetFrameRef("mend")
	if not mend then return end
	if newstate == "fight" and self:GetAttribute("manners-on") then
		mend:Show(true)
	else
		mend:Hide(true)
	end
]=]

-- Made the first time it is wanted, out of combat.
function MendPet:Create()
	if button or InCombatLockdown() then return end
	button = CreateFrame("Button", "MannersMendPet", UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetClampedToScreen(true)
	button:RegisterForClicks("AnyDown")
	icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:SetTexture(ns.safecall(_G.C_Spell and _G.C_Spell.GetSpellTexture, Beast.MendId() or 136) or FALLBACK_ICON)
	glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(GLOW)
	glow:SetBlendMode("ADD")
	glow:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 8)
	glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -8)
	glow:SetVertexColor(1, 0.82, 0.2)
	glow:Hide()
	pulse = glow:CreateAnimationGroup()
	if type(pulse.SetLooping) == "function" then pulse:SetLooping("BOUNCE") end
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.25)
	fade:SetDuration(0.45)
	-- Its two lines go to its right, clear of a break-free button's lines.
	nameText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("BOTTOMLEFT", button, "RIGHT", 4, 1)
	nameText:SetText("")
	keyText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keyText:SetPoint("TOPLEFT", button, "RIGHT", 4, -1)
	keyText:SetText("")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	for index = 2, 31 do
		if index <= 5 then button:SetAttribute("type" .. index, "none") end
		button:SetAttribute("*type" .. index, "none")
	end
	button:SetScript("PreClick", PreClick)
	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnLeave", OnLeave)
	button:Hide()
	if type(_G.RegisterStateDriver) == "function" then
		local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
		if ok and type(made) == "table" and type(made.SetFrameRef) == "function" then
			made:SetFrameRef("mend", button)
			made:SetAttribute("manners-on", false)
			made:SetAttribute("_onstate-" .. STATE, SNIPPET)
			_G.RegisterStateDriver(made, STATE, DRIVER)
			header = made
		end
	end
	local frame = MendPet.frame
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	frame:RegisterEvent("UNIT_PET")
end

-- The key it is bound to; read out of a fight and at every pull, before the lockdown.
local function ReadKey()
	local key = type(GetBindingKey) == "function" and GetBindingKey(MendPet.COMMAND) or nil
	keyLabel = type(key) == "string" and key ~= "" and key or nil
end

-- From a scan (Core.lua, TickBody) when Wanted says something changed, and as a
-- fight ends (Release). Out of combat only.
function MendPet:Refresh()
	if InCombatLockdown() then return end
	local db = Profile()
	if not db then return end
	local name = Beast.MendName()
	if not (MendPet.Applies(db) and name) then
		if button then
			Disarm()
			if header and header:GetAttribute("manners-on") then header:SetAttribute("manners-on", false) end
			if button:IsShown() then button:Hide() end
		end
		settledOn, dirty = false, false
		return
	end
	if not button then self:Create() end
	if not button then return end
	Place(db.prompt)
	Arm(name)
	if header then
		if header:GetAttribute("manners-on") ~= true then header:SetAttribute("manners-on", true) end
		if header:GetAttribute("state-" .. STATE) ~= "peace" then header:SetAttribute("state-" .. STATE, "peace") end
	end
	if button:IsShown() then button:Hide() end
	ReadKey()
	paintedKey = nil
	Paint()
	settledOn, dirty = true, false
end

-- Whether a scan has anything to do here: plain field reads, nothing the client
-- is asked beyond the lockdown's.
function MendPet:Wanted()
	if button == nil and not Beast.IsHunter() then return false end
	if InCombatLockdown() then return false end
	if dirty then return true end
	local db = Profile()
	if not db then return false end
	local on = MendPet.Applies(db) and true or false
	if on ~= settledOn then return true end
	if not on then return false end
	local p = db.prompt
	if p.iconSize ~= placedIcon or p.scale ~= placedScale then return true end
	local bf = ns.BreakFree
	return ((bf and bf.Applies() and bf:Button()) ~= nil) ~= placedBeside
end

-- PLAYER_REGEN_ENABLED, out of lockdown: the button taken down and armed again.
function MendPet:Release()
	paintedKey = nil
	dirty = true
	self:Refresh()
end

-- From HunterPet.lua's pet UNIT_HEALTH: one repaint after a short wait, so the
-- last of a burst of events is never dropped.
function MendPet.Changed()
	if not button or not button:IsShown() or paintDue then return end
	local timer = _G.C_Timer
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return end
	paintDue = true
	timer.After(REPAINT, function()
		paintDue = false
		ns.Guard("mend pet", Paint)
	end)
end

local function OnEvent(event, spellId)
	if event == "PLAYER_REGEN_DISABLED" then
		ReadKey()
		paintedKey = nil
		Paint()
	elseif event == "UNIT_PET" then
		paintedKey = nil
		if InCombatLockdown() then Paint() end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local id = plain(spellId)
		local ours = waitUntil and GetTime() <= waitUntil
		if (id ~= nil and Beast.IsMend(id)) or (id == nil and ours) then
			local busy = BUSY[FLAVOUR] or 10
			readyAt = GetTime() + busy
			waitUntil = nil
			paintedKey = nil
			Paint()
			local timer = _G.C_Timer
			if type(timer) == "table" and type(timer.After) == "function" then
				timer.After(busy + 0.05, function()
					paintedKey = nil
					ns.Guard("mend pet", Paint)
				end)
			end
			ns.Trail("fight", "mend pet went out")
		end
	end
end

do
	local frame = CreateFrame("Frame")
	MendPet.frame = frame
	-- Every unit's casts and pet events arrive: only the player's are read.
	frame:SetScript("OnEvent", function(_, event, unit, _, spellId)
		if (event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_PET") and unit ~= "player" then return end
		ns.Guard("mend pet", OnEvent, event, spellId)
	end)
end

-- For /manners debug.
function ns.MendPetLines()
	local out = {}
	if not Beast.IsHunter() then return out end
	local db = Profile()
	local armed = button and button:GetAttribute("macrotext1")
	local left = readyAt and math.max(0, math.floor(readyAt - GetTime())) or 0
	out[1] = ("mend pet button: switch %s; %s; key %s; driver %s; shown %s; busy %s"):format(
		(db and db.beast and db.beast.fightMend ~= false and db.beast.all ~= false) and "on" or "off",
		armed and ("armed (" .. tostring(armed) .. ")") or (button and "made, not armed" or "not made"),
		tostring(keyLabel or (type(GetBindingKey) == "function" and GetBindingKey(MendPet.COMMAND)) or "none"),
		tostring(header and header:GetAttribute("state-" .. STATE) or "none"),
		tostring(button ~= nil and button:IsShown()), tostring(left))
	return out
end

function MendPet:Button() return button end
function MendPet:Header() return header end
-- What it shows: the spell's name and the key beside it, the glow.
function MendPet:Look()
	if not button then return nil end
	return { name = nameText, key = keyText, glow = glow, icon = icon }
end
