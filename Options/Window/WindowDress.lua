-- Manners -- what the options window wears: the game's own way with a window.
--
-- Window.lua, WindowChrome.lua and WindowPage.lua draw the window flat (a
-- colour, a hairline, a bar). This file lays art over that and changes none of
-- it: a grain and a vignette on the ground, a gilt moulding round the window
-- with a boss on each corner, a beaded gilt rail under the header and over
-- the footer, a light behind the title, a band of light and a gilt stud on
-- the page that is open, and a stud before each section's title.
--
-- Everything here is decoration: no control, no text, nothing that takes the
-- mouse. Each piece is anchored to what it decorates, so it moves, shows and
-- hides with it. The art is Textures/Window, drawn by
-- tools/make_window_textures.py.

local _, ns = ...
local UI = ns.WindowUI

local ART = "Interface\\AddOns\\Manners\\Textures\\Window\\Window_"

-- ---- must agree with tools/make_window_textures.py ---------------------
-- The frame's corner, a fraction of its file; a tile of the rail, in units.
local FRAME_CORNER, RAIL_TILE = 24 / 64, 16

-- The moulding: its corner pieces' size on screen, and how far its middle
-- line stands outside the window's edge.
local CORNER, FRAME_OUT = 16, 2
-- The rail's height, and the ground's grain: a tile's size on screen.
local RAIL_H, GROUND_TILE = 5, 128
-- The light behind the title, the open page's band and its stud, a section's
-- stud: alphas and sizes.
local TITLE_GLOW, PAGE_BAND, STUD_PAGE, STUD_SECTION = 0.20, 0.20, 13, 12
-- A button's inner rim, a hair of gilt inside its dark edge.
local BUTTON_RIM = { 0.80, 0.62, 0.28, 0.50 }
local GOLD = { 1, 0.82, 0.32 }

local Dress = {}
UI.Dress = Dress

local function Tex(parent, layer, sub, file, wrapH, wrapV)
	local t = parent:CreateTexture(nil, layer, nil, sub)
	if wrapH then t:SetTexture(ART .. file, wrapH, wrapV or "CLAMP") else t:SetTexture(ART .. file) end
	return t
end

-- The ground and the moulding, on the window itself.
function Dress.Window(f)
	local w, h = UI.WIDTH, UI.HEIGHT
	-- The grain, tiled at its own size, and the vignette over it: both under
	-- every pane's own colour... which is opaque, so each pane gets its own
	-- (Dress.Pane); these two show in the seams and through the header.
	Dress.Pane(f, f, w, h, -7)

	-- The moulding: nine pieces of one file, its middle line FRAME_OUT outside
	-- the window's edge, over everything the window draws.
	local frame = CreateFrame("Frame", nil, f)
	frame:SetAllPoints(f)
	frame:SetFrameLevel(f:GetFrameLevel() + 30)
	Dress.frame = frame
	local c, o = CORNER, FRAME_OUT + CORNER / 3
	local k = FRAME_CORNER
	local pieces = {
		{ "TOPLEFT", "TOPLEFT", -o, o, c, c, 0, k, 0, k },
		{ "TOPRIGHT", "TOPRIGHT", o, o, c, c, 1 - k, 1, 0, k },
		{ "BOTTOMLEFT", "BOTTOMLEFT", -o, -o, c, c, 0, k, 1 - k, 1 },
		{ "BOTTOMRIGHT", "BOTTOMRIGHT", o, -o, c, c, 1 - k, 1, 1 - k, 1 },
	}
	Dress.corners = {}
	for i, p in ipairs(pieces) do
		local t = Tex(frame, "OVERLAY", 2, "Frame")
		t:SetSize(p[5], p[6])
		t:SetPoint(p[1], f, p[2], p[3], p[4])
		t:SetTexCoord(p[7], p[8], p[9], p[10])
		Dress.corners[i] = t
	end
	local tl, tr, bl, br = Dress.corners[1], Dress.corners[2], Dress.corners[3], Dress.corners[4]
	local sides = {
		{ tl, "TOPRIGHT", tr, "BOTTOMLEFT", k, 1 - k, 0, k },
		{ bl, "TOPRIGHT", br, "BOTTOMLEFT", k, 1 - k, 1 - k, 1 },
		{ tl, "BOTTOMLEFT", bl, "TOPRIGHT", 0, k, k, 1 - k },
		{ tr, "BOTTOMLEFT", br, "TOPRIGHT", 1 - k, 1, k, 1 - k },
	}
	Dress.sides = {}
	for i, s in ipairs(sides) do
		local t = Tex(frame, "OVERLAY", 1, "Frame")
		t:SetPoint("TOPLEFT", s[1], s[2], 0, 0)
		t:SetPoint("BOTTOMRIGHT", s[3], s[4], 0, 0)
		t:SetTexCoord(s[5], s[6], s[7], s[8])
		Dress.sides[i] = t
	end
end

-- A pane's grain and vignette, over its own colour: `w` by `h` units, which
-- the grain is tiled to.
function Dress.Pane(parent, over, w, h, sub)
	local grain = Tex(parent, "BACKGROUND", sub or 2, "Ground", "REPEAT", "REPEAT")
	grain:SetAllPoints(over)
	grain:SetTexCoord(0, w / GROUND_TILE, 0, h / GROUND_TILE)
	local shade = Tex(parent, "BACKGROUND", (sub or 2) + 1, "Shade")
	shade:SetAllPoints(over)
	return grain, shade
end

-- A beaded rail along `edge` ("TOP" or "BOTTOM") of `frame`, `width` long.
function Dress.Rail(frame, edge, width)
	local t = Tex(frame, "ARTWORK", 3, "Rail", "REPEAT", "CLAMP")
	t:SetHeight(RAIL_H)
	if edge == "BOTTOM" then
		t:SetPoint("LEFT", frame, "BOTTOMLEFT", 0, 0)
		t:SetPoint("RIGHT", frame, "BOTTOMRIGHT", 0, 0)
	else
		t:SetPoint("LEFT", frame, "TOPLEFT", 0, 0)
		t:SetPoint("RIGHT", frame, "TOPRIGHT", 0, 0)
	end
	t:SetTexCoord(0, width / RAIL_TILE, 0, 1)
	return t
end

-- The header: a light behind the title and the rail under it.
function Dress.Header(h, title)
	local glow = Tex(h, "BACKGROUND", 3, "Glow")
	glow:SetSize(260, UI.HEADER * 1.6)
	glow:SetPoint("CENTER", title, "LEFT", 30, 0)
	glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], TITLE_GLOW)
	Dress.titleGlow = glow
	Dress.headerRail = Dress.Rail(h, "BOTTOM", UI.WIDTH)
end

function Dress.Footer(foot)
	Dress.footerRail = Dress.Rail(foot, "TOP", UI.WIDTH)
end

-- A page's button in the sidebar: the open page's band of light, fading to
-- the right, and its stud on the gold bar. Both are shown and hidden with
-- `b.selected`, which they hang off.
function Dress.PageButton(b)
	local band = Tex(b, "BACKGROUND", 2, "Fade")
	band:SetAllPoints(b)
	band:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], PAGE_BAND)
	local stud = Tex(b, "OVERLAY", 1, "Stud")
	stud:SetSize(STUD_PAGE, STUD_PAGE)
	stud:SetPoint("CENTER", b, "LEFT", 1, 0)
	b.band, b.stud = band, stud
end

-- The open page's second line (the profile's name) is written lighter: the
-- band behind it would take the grey of the others under what reads.
function Dress.PageSelected(b, selected)
	if b.band then b.band:SetShown(selected) end
	if b.stud then b.stud:SetShown(selected) end
	if b.sub then
		local c = selected and UI.C.nav or UI.C.hint
		b.sub:SetTextColor(c[1], c[2], c[3], 1)
	end
end

-- A button of the window's (Widgets.lua): a gilt line inside its dark edge,
-- as the game's own red buttons are set in gold.
function Dress.Button(b)
	local rim = {}
	for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local t = b:CreateTexture(nil, "BORDER", nil, 3)
		t:SetColorTexture(BUTTON_RIM[1], BUTTON_RIM[2], BUTTON_RIM[3], BUTTON_RIM[4])
		if i <= 2 then
			t:SetPoint(side .. "LEFT", b, side .. "LEFT", 1, i == 1 and -1 or 1)
			t:SetPoint(side .. "RIGHT", b, side .. "RIGHT", -1, i == 1 and -1 or 1)
			t:SetHeight(1)
		else
			t:SetPoint("TOP" .. side, b, "TOP" .. side, i == 3 and 1 or -1, -2)
			t:SetPoint("BOTTOM" .. side, b, "BOTTOM" .. side, i == 3 and 1 or -1, 2)
			t:SetWidth(1)
		end
		rim[i] = t
	end
	b.rim = rim
end

-- A section: a stud at the end of its rule, where the rule fades out of the
-- title.
function Dress.Section(sec, child)
	local stud = Tex(child, "OVERLAY", 1, "Stud")
	stud:SetSize(STUD_SECTION, STUD_SECTION)
	stud:Hide()
	sec.stud = stud
end

function Dress.PlaceSection(sec)
	if not sec.stud then return end
	sec.stud:ClearAllPoints()
	sec.stud:SetPoint("CENTER", sec.rule, "LEFT", 2, 0)
	sec.stud:Show()
end
