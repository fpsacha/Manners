-- Manners -- painted looks: a look's frame drawn from one painting instead of
-- the art its own code laid out.
--
-- THE IDEA. A painting of the whole bar (art/looks/<key>/, not shipped) is cut by
-- tools/make_painted_look.py into three pieces -- the LEFT end with the icon's
-- socket, the MIDDLE run the game stretches, the RIGHT end with the keycap and the
-- end ornament -- written to Textures/Painted/<Key>/, with every number the game
-- needs in Looks/PaintedData.lua (ns.PaintedData), all of it as fractions of the
-- bar's core height, so any prompt size works. This file lays the three pieces
-- behind the words of a look that has such data, and leaves everything else to
-- the look: its Attention, Flourish, outcome, reason colouring, chips, list,
-- fight, hover and its moving layers.
--
-- HOW A LOOK TAKES IT UP. Nothing is called from the look's own Build, Apply,
-- Styled or Hide: at load this file wraps those four methods of every look
-- ns.PaintedData names (so the look's own code reads as it did, and the diff to
-- wire a look is a few fields and two small methods). On the look:
--
--   paintedHides       the names of the look's fields (a region, or a list of
--                      them) its painted frame replaces: kept hidden while the
--                      painting is up, whatever the look's own code shows.
--   paintedIconFill    how much of the socket's width the icon fills (0.98).
--   PaintedPlace(g, p, above) -> textX, chipRoom   optional. After the look's own
--                      Apply and after this file has laid the pieces and put the
--                      icon in the socket: move what the look keeps (its lights,
--                      its tags, the moving layers) onto the painting, by `g`
--                      (Painted.Layout, below). Returns where the text starts
--                      and the room the lines keep at the right with the chip
--                      up (nil: g.textX, and the look's own chipRoom).
--   PaintedStyled(g)   optional. After the look's own Styled and after the ink
--                      was set to the painted well's: colours read against it.
--   Painted.Tone(look, r, g, b, grey)   from the look's own dressing (a fight's
--                      dim, a refusal's grey): the pieces in that colour.
--
-- THE SWITCH. *Earlier art* (prompt.classicArt, on the Look page) draws every look
-- exactly as before: with it on, the wrapped methods are the look's own and nothing
-- of this file is on the screen (its pieces hidden, every muffled region given
-- back its own Show).
--
-- Painted.Socket cuts a painting's icon socket out alone, for the small consumables
-- button (Prompt/Supplies.lua) to wear.
--
-- The rules every look keeps hold here: the pieces are textures of `art` (never
-- anchored to by a secure frame), coloured through Looks.Colour, laid out only in
-- Apply (ApplyStyle, out of combat), with no pcall and no OnUpdate.

local _, ns = ...
local Looks = ns.Looks
local Colour = Looks.Colour

local Painted = {}
Looks.Painted = Painted

local PARTS = { "left", "middle", "right" }
-- A painting in dark ink: the contrast a class colour and a colour code are
-- held to on it, and how far a class colour is first taken to the ink (the
-- figures the letter's parchment wears).
local DARK_CONTRAST, DARK_INK_SHARE = 5, 0.55
-- The keycap is a fourth piece (art.keycap), over the right end.
local ICON_FILL = 0.98

-- Whether the player wants the painted frames: Earlier art is off.
local function Wanted()
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	return not (p and p.classicArt)
end

-- Whether the look draws from its painting now.
function Painted.On(look)
	local art = look and look.paintedArt
	return art ~= nil and art.on == true
end

---------------------------------------------------------------------------
-- muffling: a region the painting replaces stays hidden whatever the look's
-- own code shows, and gets its own Show back when the painting goes
---------------------------------------------------------------------------

local function Noop() end
local function StayHidden(self) self:Hide() end

local function Muffle(t)
	if t.paintedMuffled then return end
	-- What the region held under these names itself (nil for a method it takes
	-- from its kind), put back as it was.
	t.paintedMuffled = { rawget(t, "Show") or false, rawget(t, "SetShown") or false }
	t:Hide()
	t.Show = Noop
	t.SetShown = StayHidden
end

local function Unmuffle(t)
	local saved = t.paintedMuffled
	if not saved then return end
	t.Show = saved[1] or nil
	t.SetShown = saved[2] or nil
	t.paintedMuffled = nil
end

-- Every region a look names: a field holding a region, or a list of them.
local function Each(look, fn)
	for _, field in ipairs(look.paintedHides or {}) do
		local v = look[field]
		if type(v) == "table" then
			if type(v.Hide) == "function" then
				fn(v)
			else
				for _, t in ipairs(v) do
					if type(t) == "table" and type(t.Hide) == "function" then fn(t) end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- layout
---------------------------------------------------------------------------

-- Where everything goes for a prompt W x H, in units from art's top left, y
-- running down. The core fills the prompt's height; the middle takes what the
-- two ends leave. On a prompt too short for the whole painting the ends are cut
-- back, the left first (from its inner side: the well, never the socket nor
-- where the text starts), then the right (never the keycap nor the ornament);
-- shorter still, the whole bar is drawn smaller, centred in the height.
--
-- The words want ROOM_EMS of the font's size between the well's start and the
-- keycap. Where the prompt is too short for that, the painting's two ends hang
-- past its edges, as far as is wanted and no further than the data allows (the
-- left one never past the socket's hole, the right one never past the
-- keycap), the left first; the prompt itself (the secure button) is the size the
-- player set. On a painting with slim ends nothing hangs.
local ROOM_EMS = 9.5

function Painted.Layout(d, W, H, fontSize)
	local unit = math.max(1, H)
	local keyRight = d.keycap.x + d.keycap.w / 2
	local short = ROOM_EMS * (fontSize or 0) - (W - (d.textX + keyRight) * unit)
	local hl, hr = 0, 0
	if short > 0 then
		hl = math.min(short, (d.hangLeft or 0) * unit)
		hr = math.min(short - hl, (d.hangRight or 0) * unit)
	end
	local left, right = -hl, W + hr
	local L, R = d.left.w, d.right.w
	local lw, rw = L, R
	local over = L + R - (right - left) / unit
	if over > 0 then
		local cut = math.min(over, math.max(0, L - d.leftMin))
		lw, over = L - cut, over - cut
		cut = math.min(over, math.max(0, R - d.rightMin))
		rw, over = R - cut, over - cut
		if over > 0 then
			-- Drawn smaller: the hangs keep their share of the smaller core.
			local hlu, hru = hl / unit, hr / unit
			unit = W / (lw + rw - hlu - hru)
			hl, hr = hlu * unit, hru * unit
			left, right = -hl, W + hr
		end
	end
	local top = (H - unit) / 2
	local g = {
		unit = unit, top = top, W = W, H = H, left = left, right = right, hangL = hl, hangR = hr,
		y0 = top - d.above * unit, y1 = top + (1 + d.below) * unit,
		x1 = left + lw * unit, x2 = right - rw * unit,
		-- The texcoords of the two ends where they were cut back.
		leftR = d.left.r * lw / L, rightL = d.right.r * (1 - rw / R),
		socketX = left + d.socket.x * unit, socketY = top + d.socket.y * unit, socketR = d.socket.r * unit,
		square = d.socket.shape ~= "round",
		textX = left + d.textX * unit, textY = top + d.textY * unit,
		keyX = right - d.keycap.x * unit, keyY = top + d.keycap.y * unit,
		keyW = d.keycap.w * unit, keyH = d.keycap.h * unit,
		endX = right - d.ornament.x * unit, endY = top + d.ornament.y * unit,
		wellTop = top + d.well.top * unit, wellBottom = top + d.well.bottom * unit,
		keyInk = d.keyInk, keyOutline = d.keyOutline,
	}
	if g.x2 < g.x1 then g.x2 = g.x1 end
	return g
end

local function Box(t, rel, x0, y0, x1, y1)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", rel, "TOPLEFT", x0, -y0)
	t:SetPoint("BOTTOMRIGHT", rel, "TOPLEFT", x1, -y1)
end

-- How far the middle reaches under each end: the pieces butted edge to edge
-- meet at a fraction of a pixel, and the game can leave a hairline of the
-- world between them there.
local SEAM = 1

-- The three pieces over the layout (and Prompt/Panel.lua's framed painting's).
local function Place(art, rel, g)
	local d, s = art.data, art.pieces
	Box(s[1], rel, g.left, g.y0, g.x1, g.y1)
	s[1]:SetTexCoord(0, g.leftR, 0, d.left.b)
	Box(s[2], rel, g.x1 - SEAM, g.y0, g.x2 + SEAM, g.y1)
	s[2]:SetTexCoord(0, d.middle.r, 0, d.middle.b)
	Box(s[3], rel, g.x2, g.y0, g.right, g.y1)
	s[3]:SetTexCoord(g.rightL, d.right.r, 0, d.right.b)
	s[1]:Show()
	s[2]:SetShown(g.x2 - g.x1 > 0.5)
	s[3]:Show()
	-- The keycap, a piece of its own over the right end (the frame under it is
	-- whole): where the keycap is painted, at the painting's own scale.
	local c, k = d.keycap, art.keycap
	local kx, ky = g.keyX + c.dx * g.unit, g.keyY + c.dy * g.unit
	Box(k, rel, kx - c.pw * g.unit / 2, ky - c.ph * g.unit / 2, kx + c.pw * g.unit / 2, ky + c.ph * g.unit / 2)
	k:SetTexCoord(0, c.r, 0, c.b)
end
Painted.Place = Place

-- A painting's socket cut out on its own, for a small button in the look's own art (Prompt/Supplies.lua): the left piece's texcoords of a square round the icon's hole, as far as the rim reaches (SOCKET_RIM times the hole's radius) and never past the piece, the share of that square the icon fills, and whether the socket is round.
local SOCKET_RIM = 1.45
function Painted.Socket(d)
	local s, l = d.socket, d.left
	local tall = d.above + 1 + d.below
	local h = math.min(s.r * SOCKET_RIM, s.x, l.w - s.x, s.y + d.above, 1 + d.below - s.y)
	return (s.x - h) / l.w * l.r, (s.x + h) / l.w * l.r, (d.above + s.y - h) / tall * l.b, (d.above + s.y + h) / tall * l.b, s.r * ICON_FILL / h, s.shape == "round"
end

-- The least room, in ems of the font's size, the words keep between where they
-- start and the keycap: on a prompt too narrow for the painting (the bar drawn
-- smaller) the keycap and its letter step aside, as the earlier art's key tag
-- did, rather than stand where the name must go.
local KEY_ROOM_EMS = 4

-- Whether the painted keycap is up: the painting up, a key bound to the prompt,
-- and Show my key on the prompt (Looks.KeyWanted) asking for it; and not over
-- an outcome, which the look's own letter leaves too.
function Painted.KeyShown(look)
	local art = look and look.paintedArt
	return art ~= nil and art.on == true and art.keyFits ~= false and Looks.KeyWanted(look)
		and Looks.BoundKey() ~= nil and not look.outcomeOn
end

-- Whether the words keep KEY_ROOM_EMS beside the keycap where they start at
-- textX (art.keyFits, read by KeyShown; the framed painting asks it itself).
local function KeyFits(g, textX, fontSize)
	return g.keyX - g.keyW / 2 - textX >= KEY_ROOM_EMS * (fontSize or 0)
end
Painted.KeyFits = KeyFits

local function ShowKeycap(look)
	local art = look.paintedArt
	if not art then return end
	local up = Painted.KeyShown(look)
	art.keycap:SetShown(up)
	-- The look's own letter goes with the keycap it is written on.
	if not up and art.on and look.keyText then look.keyText:Hide() end
end

-- The live spell icon in the socket; its shape (a mask) is the look's own, by
-- its own rule about "Round the icon off".
local function PlaceIcon(look, kit, g)
	local size = 2 * g.socketR * (look.paintedIconFill or ICON_FILL)
	g.iconSize = size
	local icon = kit.icon
	icon:ClearAllPoints()
	icon:SetSize(size, size)
	icon:SetPoint("CENTER", kit.art, "TOPLEFT", g.socketX, -g.socketY)
end

-- The painting taken down: its pieces hidden, every muffled region given back.
local function Release(look)
	local art = look.paintedArt
	if not art then return end
	art.on, art.g, art.keyFits = false, nil, nil
	for _, t in ipairs(art.pieces) do t:Hide() end
	art.keycap:Hide()
	Each(look, Unmuffle)
end

function Painted.Tone(look, r, g, b, grey)
	local art = look.paintedArt
	if not (art and art.on) then return end
	for _, t in ipairs(art.pieces) do
		t:SetDesaturated(grey and true or false)
		Colour(t, r, g, b)
	end
	art.keycap:SetDesaturated(grey and true or false)
	Colour(art.keycap, r, g, b)
end

-- The player chose a font colour of their own (AceDB keeps only a change).
local function ChosenColour(p)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local c = p and p.fontColor
	if type(c) ~= "table" or type(d) ~= "table" then return false end
	for i = 1, 3 do
		if math.abs((c[i] or 1) - (d[i] or 1)) > 0.002 then return true end
	end
	return false
end

-- A painting with words in ink of its own (dark on a light ground: the data's
-- ink.name and ink.reason): the name and the reason line in it, held to the
-- ground's contrast, and no shadow (a dark shadow under dark ink smudges it).
-- The reason's tint and a class colour take it from there (the look's
-- PaintReason over ink.sub; classContrast and classInk on the look).
local function DarkInk(kit, words, p)
	if not ChosenColour(p) then
		local n = words.name
		local r, g, b = kit.Legible(n[1], n[2], n[3], 4.5)
		kit.name:SetTextColor(r, g, b, 1)
	end
	local c = words.reason
	local r, g, b = kit.Legible(c[1], c[2], c[3], 4.5)
	kit.ink.sub = { r, g, b }
	kit.sub:SetTextColor(r, g, b, 1)
	kit.name:SetShadowOffset(0, 0)
	kit.sub:SetShadowOffset(0, 0)
end

---------------------------------------------------------------------------
-- the wrapping
---------------------------------------------------------------------------

function Painted.Wrap(look, d)
	local build, apply, styled, hide, chip = look.Build, look.Apply, look.Styled, look.Hide, look.Chip
	-- Words in the painting's own dark ink on a light ground: a class-coloured
	-- name and every colour code taken dark enough to read on it, the name
	-- first part of the way to the ink (Looks/Looks.lua: classContrast,
	-- classInk), unless the look says so itself (Letter's own figures).
	if d.ink.light == false and d.ink.name and look.classContrast == nil then
		local n = d.ink.name
		look.classContrast, look.codeContrast = DARK_CONTRAST, DARK_CONTRAST
		look.classInk = { n[1], n[2], n[3], DARK_INK_SHARE }
	end

	function look:Build(kit)
		build(self, kit)
		local pieces = {}
		for i, part in ipairs(PARTS) do
			local t = kit.art:CreateTexture(nil, "BACKGROUND", nil, -5)
			t:SetTexture(d[part].file)
			t:Hide()
			Looks.Hold(t)
			pieces[i] = t
		end
		local keycap = kit.art:CreateTexture(nil, "BACKGROUND", nil, -4)
		keycap:SetTexture(d.keycap.file)
		keycap:Hide()
		Looks.Hold(keycap)
		self.paintedArt = { data = d, pieces = pieces, keycap = keycap, on = false }
	end

	function look:Apply(p, above)
		local art = self.paintedArt
		-- A plain look (Looks/Plain.lua) has no earlier art: Earlier art leaves
		-- it painted.
		if not (art and (Wanted() or self.paintedOnly)) then
			Release(self)
			return apply(self, p, above)
		end
		Each(self, Muffle)
		art.on = true
		local textX, chipRoom = apply(self, p, above)
		local g = Painted.Layout(d, p.width, p.height, p.fontSize)
		g.round = Looks.roundAlways[self.key] == true or p.roundIcon == true
		art.g = g
		Place(art, self.kit.art, g)
		-- The keycap only where the words keep their room beside it, known
		-- before the look places what it keeps (it may ask KeyShown).
		art.keyFits = KeyFits(g, g.textX, p.fontSize)
		ShowKeycap(self)
		PlaceIcon(self, self.kit, g)
		if self.PaintedPlace then
			local x, room = self:PaintedPlace(g, p, above)
			return x or g.textX, room or chipRoom
		end
		return g.textX, chipRoom
	end

	function look:Styled(p, twoLine)
		if styled then styled(self, p, twoLine) end
		local art = self.paintedArt
		if not (art and art.on) then return end
		-- The words stand on the painted well: Legible holds them to its own
		-- luminance at its darkest and its brightest.
		local ink = self.kit.ink
		ink.light, ink.lo, ink.hi = d.ink.light, d.ink.lo, d.ink.hi
		if d.ink.name then DarkInk(self.kit, d.ink, p) end
		if self.PaintedStyled then self:PaintedStyled(art.g) end
	end

	function look:Hide()
		hide(self)
		Release(self)
	end

	-- At every repaint: the keycap follows a key bound or unbound since.
	if chip then
		function look:Chip(on)
			local up = chip(self, on)
			ShowKeycap(self)
			return up
		end
	end
end

-- Every look the data names, wrapped once, at load (this file is loaded after
-- every look and before Prompt/).
for key, d in pairs(ns.PaintedData or {}) do
	local look = Looks.list[key]
	if look and not look.native and not look.fallback and type(look.Apply) == "function" then
		Painted.Wrap(look, d)
	end
end
