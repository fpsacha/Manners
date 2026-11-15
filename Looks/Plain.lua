-- Manners -- plain painted looks: a look made of its painting alone.
--
-- Most looks have code of their own (Looks/<Name>.lua) and wear a painting over
-- it (Looks/Painted.lua). A PLAIN look has nothing but its painting: it is
-- registered here from one row of PLAIN (key, title, description, order,
-- category), and its behaviour is the modest set below, written once for all of
-- them. Looks/Painted.lua (loaded next) wraps it like any painted look, lays its
-- three pieces and its keycap and puts the icon in the socket; what is here
-- moves the words onto the well, the key's letter onto the keycap, and answers
-- the rest of the look interface (Looks/Looks.lua's header):
--
--   PaintReason   the reason line taken towards the reason's colour, held to
--                 its contrast on the well, and the socket's light in it
--   Chip          the key's letter on the painted keycap (Show my key on the
--                 prompt), the count as plain words left of it
--   Attention     a slow breath of light on the socket's rim for somebody
--                 owed: a few breaths, then still; on Calm, nothing loops
--   Flourish      the shared rings (kit.FX): a landing's spread, a refusal's
--   PaintOutcome  the verdict on the reason line, in the outcome's colour
--   Combat        the painting dimmed and greyed, the text dimmed, the reason
--                 still read
--   Hover         the socket's light a shade up
--   PaintQueue    the list under (or over) the bar on a plain dark sheet in the
--                 well's own colour, a mark in each row's reason colour
--
-- The icon is round in a round socket (Looks.roundAlways) and follows *Round
-- the icon off* in a square one. Plain looks have no earlier art: *Earlier art*
-- leaves them as they are (paintedOnly). Everything colours through
-- Looks.Colour and Looks.Dim; no OnUpdate, no pcall; nothing is laid out in a
-- fight (Apply is ApplyStyle's, out of combat).
--
-- Adding one: its painting in art/looks/<key>/ (INTEGRATION.md), the tool run,
-- a row in PLAIN, its title and line translated, its category in CATEGORY
-- (Looks/Looks.lua).

local _, ns = ...
local Looks = ns.Looks
local Colour, Dim = Looks.Colour, Looks.Dim
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local RING = "Interface\\AddOns\\Manners\\Textures\\Ring"
local RING_SQ = "Interface\\AddOns\\Manners\\Textures\\RingSq"
-- The disc tools/make_painted_look.py writes for a round socket.
local ROUND_MASK = "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask"
local COMMAND = Looks.COMMAND

-- The looks, in the picker's order within their category.
local PLAIN = {
	{ key = "firemage", title = L["Fire Mage"], description = L["bronze and embers, a molten gem at its end"], order = 9.81, category = "class" },
	{ key = "priest", title = L["Priest"], description = L["ivory and gold, a halo round the icon"], order = 9.82, category = "class" },
	{ key = "rogue", title = L["Rogue"], description = L["black leather and brass, a poisoned blade"], order = 9.83, category = "class" },
	{ key = "monk", title = L["Monk"], description = L["red lacquer and jade, an endless knot"], order = 9.84, category = "class" },
	{ key = "demonhunter", title = L["Demon Hunter"], description = L["dark leather and fel steel, a warglaive's ring"], order = 9.85, category = "class" },
	{ key = "evoker", title = L["Evoker"], description = L["scaled bronze, a dragon round the icon"], order = 9.86, category = "class" },
	{ key = "ghost", title = L["Ghost"], description = L["a pane of smoked glass, a thin rim"], order = 1.3, category = "minimal" },
	{ key = "hairline", title = L["Hairline"], description = L["a framed icon and one fine line, no panel"], order = 1.4, category = "minimal" },
	{ key = "pill", title = L["Pill"], description = L["a rounded pane, a pale rim"], order = 1.5, category = "minimal" },
	{ key = "slate", title = L["Slate"], description = L["a dark pane in a steel edge"], order = 1.6, category = "minimal" },
}

-- A fight: the text this dim, the icon greyed and this dim, the painting this
-- grey (kept light enough that a light keycap's dark letter holds 4.5:1).
local TEXT_COMBAT, ICON_COMBAT, PAINT_COMBAT = 0.92, 0.70, 0.80
-- The socket's light: its file is this much wider than the socket; how bright
-- it breathes for somebody owed, how many breaths, how long one is; how
-- bright the cursor leaves it; and how bright a favour's arrival flashes it.
local GLOW_SPAN, GLOW_PEAK, BREATHS, BREATH, GLOW_HOVER, GLOW_ARRIVE = 1.32, 0.38, 3, 1.6, 0.16, 0.5
-- The reason line: this much of the way from its plain colour to the reason's.
local REASON_SHARE, REASON_CONTRAST = 0.6, 4.8
-- The verdicts' colours.
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- The words on a dark well and on a light one, when the data names none.
local LIGHT_NAME, LIGHT_REASON = { 1, 0.98, 0.94 }, { 0.86, 0.80, 0.68 }
-- The list's sheet: how opaque, and how far round the rows it reaches.
local SHEET_ALPHA, SHEET_PAD = 0.94, 4

local function SubSize(fontSize) return math.max(7, fontSize - 3) end
local function Gap(fontSize) return math.max(1.5, fontSize * 0.16) end

local function Box(t, rel, x0, y0, x1, y1)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", rel, "TOPLEFT", x0, -y0)
	t:SetPoint("BOTTOMRIGHT", rel, "TOPLEFT", x1, -y1)
end

-- The player chose a font colour of their own (AceDB keeps only a change).
local function Chosen(p)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local c = p and p.fontColor
	if type(c) ~= "table" or type(d) ~= "table" then return false end
	for i = 1, 3 do
		if math.abs((c[i] or 1) - (d[i] or 1)) > 0.002 then return true end
	end
	return false
end

local Plain = {}

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Plain:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own = {}
	self.own = own
	local function keep(x) own[#own + 1] = x return x end
	-- The socket's light, under the icon (BLEND, so nothing glares).
	self.glow = keep(art:CreateTexture(nil, "BACKGROUND", nil, -3))
	self.glow:SetAlpha(0)
	local breathe = self.glow:CreateAnimationGroup()
	breathe:SetLooping("BOUNCE")
	local a = breathe:CreateAnimation("Alpha")
	a:SetFromAlpha(0)
	a:SetToAlpha(GLOW_PEAK)
	a:SetDuration(BREATH)
	if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
	self.breathe = breathe
	local flash = self.glow:CreateAnimationGroup()
	local up = flash:CreateAnimation("Alpha")
	up:SetFromAlpha(0)
	up:SetToAlpha(GLOW_ARRIVE)
	up:SetDuration(0.15)
	up:SetOrder(1)
	local down = flash:CreateAnimation("Alpha")
	down:SetFromAlpha(GLOW_ARRIVE)
	down:SetToAlpha(0)
	down:SetDuration(0.4)
	down:SetOrder(2)
	self.flash = flash
	-- The shared rings, and no echo: the icon stays clean in its socket.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do keep(f) end
	-- Words on nothing (a bare look: the data's `bare`): a soft dark backing
	-- under them, a band with its top and bottom fading out.
	self.backing = {}
	for i = 1, 4 do
		local t = keep(art:CreateTexture(nil, "BACKGROUND", nil, -6))
		t:SetTexture(WHITE)
		self.backing[i] = t
	end
	-- The list's sheet and its marks.
	self.sheet = keep(art:CreateTexture(nil, "BACKGROUND", nil, -2))
	self.sheet:SetTexture(WHITE)
	self.marks = {}
	for i = 1, #kit.rows do
		local t = keep(art:CreateTexture(nil, "ARTWORK", nil, 1))
		t:SetTexture(WHITE)
		self.marks[i] = t
	end
	-- The key's letter, on a frame of its own over the painting so a fight's
	-- dim of the words does not grey it on a light keycap.
	self.chipFrame = keep(CreateFrame("Frame", nil, art))
	self.chipFrame:SetFrameLevel(art:GetFrameLevel() + 3)
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyText = keep(self.chipFrame:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)
	-- The icon's shape in a round socket; taken off in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	Looks.HoldAll(own)
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

-- Before the painting is laid (Looks/Painted.lua calls PaintedPlace after).
function Plain:Apply(p, above)
	local kit = self.kit
	self.active = true
	self.p, self.W, self.H, self.above = p, p.width, p.height, above
	local fs = p.fontSize
	self.fontSize, self.sub = fs, SubSize(fs)
	self.pitch = self.sub + 6
	for _, x in ipairs(self.own) do x:Show() end
	self.breathe:Stop()
	self.flash:Stop()
	self.glow:SetAlpha(0)
	self.sheet:Hide()
	for _, t in ipairs(self.marks) do t:Hide() end
	self.keyText:Hide()
	kit.count:Hide()
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.listShown, self.listAt, self.keyLabel, self.keyUp, self.countText = nil, nil, nil, false, nil
	self.pulseSpent, self.pulseGen = nil, (self.pulseGen or 0) + 1
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	self.heldCombat = held
	return 0, 0
end

function Plain:PaintedPlace(g, p, above)
	local kit = self.kit
	local art, icon = kit.art, kit.icon
	local W, H = self.W, self.H
	local showIcon = p.showIcon and true or false
	self.g = g
	self.textX = g.textX
	-- The two lines centred on the well.
	local fs, sub = self.fontSize, self.sub
	local block = fs + Gap(fs) + sub
	local dy = H / 2 - g.textY
	self.nameY = block / 2 - fs / 2 + 0.5 + dy
	self.subY = -(block / 2 - sub / 2) + 0.5 + dy
	self.oneY = dy
	-- The icon: round in a round socket, else as the switch says.
	icon:SetShown(showIcon)
	if g.round and showIcon then
		self.mask:ClearAllPoints()
		self.mask:SetAllPoints(icon)
		self.mask:Show()
		if not self.masked then
			icon:AddMaskTexture(self.mask)
			self.masked = true
		end
	elseif self.masked then
		icon:RemoveMaskTexture(self.mask)
		self.masked = nil
		self.mask:Hide()
	else
		self.mask:Hide()
	end
	local size = g.iconSize
	if kit.cooldown then
		kit.cooldown:ClearAllPoints()
		kit.cooldown:SetAllPoints(icon)
		if kit.cooldown.SetSwipeTexture then kit.cooldown:SetSwipeTexture(g.round and ROUND_MASK or WHITE) end
		if kit.cooldown.SetUseCircularEdge then kit.cooldown:SetUseCircularEdge(g.round and true or false) end
	end
	-- The socket's light round it, in the socket's shape.
	self.glow:SetTexture(g.round and RING or RING_SQ)
	local span = 2 * g.socketR * GLOW_SPAN
	self.glow:ClearAllPoints()
	self.glow:SetPoint("CENTER", art, "TOPLEFT", g.socketX, -g.socketY)
	self.glow:SetSize(span, span)
	self.glow:SetShown(showIcon)
	-- The rings from the socket, held off the words and inside the painting.
	self.fx:SetShown(showIcon)
	if showIcon then
		self.fx:Place(icon, (span - size) / 2, size)
		self.fx:Shape(g.round, RING, RING_SQ, g.round and ROUND_MASK or nil)
		local limitH = math.min(g.textX - g.socketX - kit.TEXT_MARGIN, g.socketX - g.left - kit.EDGE_MARGIN)
		local limitV = math.min(g.socketY - g.y0, g.y1 - g.socketY) - kit.EDGE_MARGIN
		self.fx:Fit(math.max(1, limitH), math.max(1, limitV), kit.SHAKE_LEFT)
	end
	-- The key's letter on the keycap; the lines keep left of it.
	local keyL, keyR = g.keyX - g.keyW / 2, g.keyX + g.keyW / 2
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("CENTER", art, "TOPLEFT", g.keyX, -g.keyY)
	self.keyBox:SetSize(g.keyW, g.keyH)
	self.chipInset = math.ceil(W - keyL) + 3
	self.roomBase = self.chipInset + math.ceil(sub * 2.2)
	-- The count as words, left of the keycap.
	local count = kit.count
	count:ClearAllPoints()
	count:SetPoint("RIGHT", art, "TOPLEFT", keyL - 5, -g.textY)
	-- The list from the socket to the keycap's far side, clear of what the
	-- painting hangs under (or over) the bar.
	self.rowX = math.max(g.textX, 24)
	self.listX0 = math.max(2, g.socketX - g.socketR)
	self.listX1 = math.max(self.rowX + 30, keyR)
	self.listGap = math.max(0, (above and -g.y0 or (g.y1 - H)) * 0.85)
	local rowWidth = math.max(20, self.listX1 - self.rowX - 6)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		kit.fit.room[row] = rowWidth
	end
	-- The backing under words on nothing: from the socket's frame to just past
	-- the longer line (PlaceBacking, as the words change), a soft edge over,
	-- under and after them.
	local bare = self.paintedArt.data.bare
	self.bare, self.backW, self.backName, self.backSub = bare, nil, nil, nil
	if bare then
		self.backSoft = math.max(2, fs * 0.45)
		self.backHalf = block / 2 + 1
		self.backX0 = g.socketX + g.socketR
		self.backMost = keyL - 2
		local b = self.backing
		Colour(b[1], 0, 0, 0, bare)
		kit.Gradient(b[2], "VERTICAL", 0, 0, 0, bare, 0, 0, 0, 0)
		kit.Gradient(b[3], "VERTICAL", 0, 0, 0, 0, 0, 0, 0, bare)
		kit.Gradient(b[4], "HORIZONTAL", 0, 0, 0, bare, 0, 0, 0, 0)
		self:PlaceBacking(self.backMost - self.backX0)
	end
	for _, t in ipairs(self.backing) do t:SetShown(bare ~= nil) end
	if self.heldCombat then self:Combat(true) end
	self.heldCombat = nil
	return g.textX, self.roomBase
end

-- The backing `w` units long from the socket's frame (never past the keycap).
function Plain:PlaceBacking(w)
	local g, b = self.g, self.backing
	local art = self.kit.art
	local x0, soft, half = self.backX0, self.backSoft, self.backHalf
	local x1 = math.min(self.backMost, x0 + w)
	if self.backW == x1 then return end
	self.backW = x1
	local y = g.textY
	Box(b[1], art, x0, y - half, x1, y + half)
	Box(b[2], art, x0, y - half - soft, x1, y - half)
	Box(b[3], art, x0, y + half, x1, y + half + soft)
	Box(b[4], art, x1, y - half, x1 + soft * 2, y + half)
end

-- The words as the painting wants them: light on a dark well, the data's own
-- ink on a light one; and a soft dark shadow under words on nothing (a bare
-- look) or over a see-through pane.
function Plain:PaintedStyled(g)
	local kit, d = self.kit, self.paintedArt.data
	local ink = kit.ink
	local p = self.p
	local dark = d.ink.light == false
	local nameInk = d.ink.name or LIGHT_NAME
	local reasonInk = d.ink.reason or LIGHT_REASON
	-- A painting's own ink is set already (Looks/Painted.lua, DarkInk).
	if not (Chosen(p) or d.ink.name) then kit.name:SetTextColor(nameInk[1], nameInk[2], nameInk[3], 1) end
	self.reasonInk = reasonInk
	if dark then
		kit.name:SetShadowOffset(0, 0)
		kit.sub:SetShadowOffset(0, 0)
	else
		local strong = d.bare or d.pane
		kit.name:SetShadowColor(0, 0, 0, strong and 1 or 0.9)
		kit.name:SetShadowOffset(1, -1)
		kit.sub:SetShadowColor(0, 0, 0, 1)
		kit.sub:SetShadowOffset(1, -1)
	end
	-- The count and the list's names on the well and the sheet.
	local cr, cg, cb = kit.Legible(reasonInk[1], reasonInk[2], reasonInk[3], 4.5)
	kit.count:SetTextColor(cr, cg, cb, 1)
	kit.count:SetShadowColor(0, 0, 0, 1)
	kit.count:SetShadowOffset((dark or not d.bare) and 0 or 1, (dark or not d.bare) and 0 or -1)
	local rr, rg, rb = kit.Legible(nameInk[1], nameInk[2], nameInk[3], 4.5)
	for _, fs in ipairs(kit.rows) do
		fs:SetTextColor(rr, rg, rb, 1)
		fs:SetShadowOffset(dark and 0 or 1, dark and 0 or -1)
	end
	ink.rowReason = dark and "|cff5a3a28" or "|cffa8a090"
	-- The key's letter: the painting's own ink for its keycap, no larger than
	-- the keycap holds.
	local path = kit.fit.path or STANDARD_TEXT_FONT
	local size = math.max(6, math.min(self.sub, math.floor(g.keyH * 0.7)))
	-- A mid-toned keycap: the pale letter outlined dark (the data's keyOutline).
	local flags = g.keyOutline and "OUTLINE" or ""
	if not self.keyText:SetFont(path, size, flags) or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
	local k = g.keyInk
	self.keyText:SetTextColor(k[1], k[2], k[3], 1)
	self.keyText:SetShadowOffset(0, 0)
	if self.tint then self:Tint(self.tint[1], self.tint[2], self.tint[3]) end
end

function Plain:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	self.breathe:Stop()
	self.flash:Stop()
	self.fx:Stop()
	self.glow:SetAlpha(0)
	for _, x in ipairs(self.own) do x:Hide() end
	self.pulseGen = (self.pulseGen or 0) + 1
	local icon = kit.icon
	if self.masked then
		icon:RemoveMaskTexture(self.mask)
		self.masked = nil
	end
	self.mask:Hide()
	icon:SetAlpha(1)
	icon:SetVertexColor(1, 1, 1)
	icon:SetDesaturated(false)
	if kit.cooldown then
		kit.cooldown:SetAlpha(1)
		if kit.cooldown.SetSwipeTexture then kit.cooldown:SetSwipeTexture(WHITE) end
		if kit.cooldown.SetUseCircularEdge then kit.cooldown:SetUseCircularEdge(false) end
	end
	kit.count:Show()
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.listShown, self.listAt, self.keyUp = nil, nil, false
end

---------------------------------------------------------------------------
-- the lines and the key
---------------------------------------------------------------------------

function Plain:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	local textX = self.textX or 0
	local inset = math.max(right, self.chipInset or 12)
	inset = math.min(inset, math.max(0, self.W - textX - 20))
	self.inset = inset
	local room = math.max(20, self.W - textX - inset)
	fit.room[name], fit.room[sub] = room, room
	if fit.twoLine then
		name:SetPoint("LEFT", textX, self.nameY or 0)
		name:SetPoint("RIGHT", -inset, self.nameY or 0)
	else
		name:SetPoint("LEFT", textX, self.oneY or 0)
		name:SetPoint("RIGHT", -inset, self.oneY or 0)
	end
	sub:SetPoint("LEFT", textX, self.subY or 0)
	sub:SetPoint("RIGHT", -inset, self.subY or 0)
end

-- Nothing hugs the words: the lines are placed once, by PlaceLines.
function Plain:Fitted() end

-- The key bound to the prompt, as the game spells it short, or nil: only where
-- a press casts something, never over an outcome, and only as Show my key on
-- the prompt asks.
function Plain:KeyLabel()
	if self.outcomeOn or type(GetBindingKey) ~= "function" then return nil end
	if not (self.kit.button:GetAttribute("type1") or (ns.Prompt and ns.Prompt:InTest())) then return nil end
	if not Looks.KeyWanted(self) then return nil end
	local key = GetBindingKey(COMMAND)
	if type(key) ~= "string" or key == "" then return nil end
	local text = Looks.ShortKey(key)
	if type(text) == "string" and text ~= "" then key = text end
	return key
end

-- Every repaint: the key's letter on the keycap, the count as words beside it.
function Plain:Chip(on)
	local kit = self.kit
	-- The backing as long as the longer line: measured only when the words
	-- change (kit.TextWidth is a pcall: none on every paint).
	if self.bare then
		local name, sub = kit.name:GetText(), kit.sub:IsShown() and kit.sub:GetText() or ""
		local secret = issecretvalue and (issecretvalue(name) or issecretvalue(sub))
		if secret or name ~= self.backName or sub ~= self.backSub then
			self.backName, self.backSub = (not secret) and name or nil, (not secret) and sub or nil
			local w = math.max(kit.fit.drawn[kit.name] or kit.TextWidth(kit.name) or 0,
				kit.sub:IsShown() and (kit.fit.drawn[kit.sub] or kit.TextWidth(kit.sub) or 0) or 0)
			self:PlaceBacking((self.textX - self.backX0) + w + self.backSoft)
		end
	end
	local key = self:KeyLabel()
	if key ~= self.keyLabel then
		self.keyLabel = key
		self.keyText:SetText(key or "")
	end
	self.keyText:SetShown(key ~= nil)
	if not on then
		kit.count:Hide()
		return false
	end
	-- Words on nothing: the backing reaches the count too.
	if self.bare then self:PlaceBacking(self.backMost - self.backX0) end
	local count = kit.count
	local text = count:GetText()
	if type(text) == "string" and text:match("^%d+$") then count:SetText("+" .. text) end
	text = count:GetText()
	if text ~= self.countText then
		self.countText = text
		self.countW = kit.TextWidth(count) or (self.sub * 2)
	end
	kit.fit.chipRoom = math.max(self.roomBase or 0, math.ceil(self.countW or 0) + (self.chipInset or 0) + 8)
	count:Show()
	return true
end

---------------------------------------------------------------------------
-- the reason, the fight, the cursor
---------------------------------------------------------------------------

-- The reason line taken towards the reason's colour, held to its contrast on
-- the well; the socket's light in the colour itself.
function Plain:Tint(r, g, b)
	local kit = self.kit
	local base = self.reasonInk or LIGHT_REASON
	local sr = base[1] + (r - base[1]) * REASON_SHARE
	local sg = base[2] + (g - base[2]) * REASON_SHARE
	local sb = base[3] + (b - base[3]) * REASON_SHARE
	-- A little over the 4.5:1 floor, so the letters' own edges keep it.
	sr, sg, sb = kit.Legible(sr, sg, sb, REASON_CONTRAST)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	Colour(self.glow, r, g, b)
end

function Plain:PaintReason(r, g, b, _, mode)
	self.tint = { r, g, b }
	if mode == "off" then
		local base = self.reasonInk or LIGHT_REASON
		self:Tint(base[1], base[2], base[3])
	else
		self:Tint(r, g, b)
	end
	self.refused = nil
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

function Plain:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	kit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)
	kit.icon:SetDesaturated(on or self.refused or false)
	local v = on and ICON_COMBAT or 1
	kit.icon:SetVertexColor(v, v, v)
	if kit.cooldown then kit.cooldown:SetAlpha(on and ICON_COMBAT or 1) end
	local paint = on and PAINT_COMBAT or 1
	Looks.Painted.Tone(self, paint, paint, paint, on)
	Dim(self.sheet, on and TEXT_COMBAT or 1)
	if on then
		self:StopAttention()
		self:StopFlourishes()
	end
end

function Plain:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	if not self.breathe:IsPlaying() and not self.flash:IsPlaying() then
		self.glow:SetAlpha(on and GLOW_HOVER or 0)
	end
end

---------------------------------------------------------------------------
-- attention and flourishes
---------------------------------------------------------------------------

function Plain:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	self.breathe:Stop()
	self.flash:Stop()
	self.glow:SetAlpha(self.hovered and GLOW_HOVER or 0)
end

-- Somebody owed on top: on Full effects the socket's rim breathes a few times
-- and is still; a favour that just arrived flashes it once. Calm: nothing.
function Plain:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat or not full then
		self:StopAttention()
		return
	end
	if isNew then self.pulseSpent = nil end
	if arrived or (isNew and flashStyle == "once") then
		self.breathe:Stop()
		self.flash:Stop()
		self.flash:Play()
	end
	if flashStyle ~= "pulse" or self.pulseSpent then
		self.breathe:Stop()
		return
	end
	if self.breathe:IsPlaying() and not isNew then return end
	if not self.breathe:IsPlaying() then self.breathe:Play() end
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= self.pulseGen or not self.active then return end
			self.pulseSpent = true
			self:StopAttention()
		end)
	end
end

function Plain:Flourish(kind)
	if not self.kit.icon:IsShown() then return end
	if kind == "failed" then
		local o = OUTCOME.failed
		self.fx:Refuse(o[1], o[2], o[3], 0.8)
	elseif kind == "cast" then
		local o = OUTCOME.cast
		self.fx:Land(o[1], o[2], o[3], 0.7)
	end
end

function Plain:StopFlourishes()
	self.fx:Stop()
	self.flash:Stop()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was, the reason line becomes the verdict in the
-- outcome's colour.
function Plain:PaintOutcome(kind, lead, sub, who, stamp)
	local kit = self.kit
	local o = OUTCOME[kind] or OUTCOME.cast
	local word
	if kind == "failed" then
		word = (sub and sub ~= "" and sub) or L["could not buff"]
	elseif kind == "sent" then
		word = L["sent, unconfirmed"]
	else
		word = L["buffed"]
	end
	if who and kit.sub:IsShown() then
		kit.SetLine(kit.name, who)
	else
		kit.SetLine(kit.name, lead)
		word = sub or ""
	end
	self.outcomeOn = true
	self:StopAttention()
	local vr, vg, vb = kit.Legible(o[1], o[2], o[3], 4.5)
	kit.sub:SetTextColor(vr, vg, vb, 1)
	Colour(self.glow, o[1], o[2], o[3])
	self.refused = kind == "failed"
	kit.icon:SetDesaturated(self.refused or self.combat or false)
	if kit.sub:IsShown() then kit.SetLine(kit.sub, word) end
end

function Plain:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- The list on a plain sheet in the well's own colour, under the bar (or over
-- it), clear of what the painting hangs there; a thin mark in each row's
-- reason colour.
function Plain:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.marks do
		if not (list and i <= shown) then self.marks[i]:Hide() end
	end
	if not list then
		if self.listShown then
			self.listShown, self.listAt = nil, nil
			self.sheet:Hide()
		end
		return
	end
	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		Colour(self.marks[i], c[1], c[2], c[3])
		self.marks[i]:Show()
	end
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above
	local pitch = self.pitch
	local gap = self.listGap or 0
	local depth = shown * pitch + 2 * SHEET_PAD
	local y0
	if above then
		y0 = -gap - depth
	else
		y0 = self.H + gap
	end
	local sheet = self.sheet
	local well = self.paintedArt.data.wellColour or { 0.06, 0.06, 0.08 }
	Colour(sheet, well[1], well[2], well[3], SHEET_ALPHA)
	Box(sheet, art, self.listX0, y0, self.listX1, y0 + depth)
	sheet:Show()
	local markW = math.max(2, math.floor(self.sub * 0.25 + 0.5))
	for i = 1, shown do
		local fs = kit.rows[i]
		local y = y0 + SHEET_PAD + (i - 1) * pitch + pitch / 2
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		local m = self.marks[i]
		m:ClearAllPoints()
		m:SetPoint("CENTER", art, "TOPLEFT", self.rowX - 7, -y)
		m:SetSize(markW, math.max(4, pitch - 6))
	end
end

---------------------------------------------------------------------------
-- registering
---------------------------------------------------------------------------

-- One look of PLAIN, with its painting's data `d`.
local function RegisterPlain(row, d)
	local look = {
		title = row.title,
		description = row.description,
		name = row.title .. " -- " .. row.description,
		order = row.order,
		category = row.category,
		-- The painting dims itself in a fight (Combat), the art stays whole.
		combatArtAlpha = 1,
		classSoften = 0.35,
		-- No earlier art to fall back to: Earlier art leaves it as it is.
		paintedOnly = true,
		paintedHides = {},
	}
	-- Words in dark ink on a light ground take their contrast rules from
	-- Looks/Painted.lua's wrapping (classContrast, classInk).
	-- Each look's methods its own, so Looks/Painted.lua's wrapping of one
	-- never reaches another.
	for name, fn in pairs(Plain) do
		if type(fn) == "function" then look[name] = fn end
	end
	Looks.Register(row.key, look)
	if d.socket.shape == "round" then Looks.roundAlways[row.key] = true end
end

-- Only a look whose painting is in the data: without it there is nothing to
-- draw.
for _, row in ipairs(PLAIN) do
	local d = ns.PaintedData and ns.PaintedData[row.key]
	if d then RegisterPlain(row, d) end
end
