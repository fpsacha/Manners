-- Manners -- options window: the look picker, a gallery of cards. Added to the
-- kinds Widgets.lua started; see there for what a row is.
--
-- The layout places the model's Panel style (a select) with widget = "themes",
-- and this draws it in place of the dropdown: one card per look the registry
-- holds, in the dropdown's order (the dropdown is made from the same list), so
-- a look registered in Looks/ has a card with nothing more done (Looks.Card
-- says what it is called and how it is described). A card is a
-- picture of the look, its name and its line; the chosen one has a gold edge
-- and a tick, the one under the pointer a lighter edge, and a click sets the
-- control as the dropdown's pick does (Bind.Commit: the profile's style, then
-- Prompt:ApplyStyle, which waits for the end of a fight as every change on
-- this page does).
--
-- The pictures are Textures/Previews/Preview_<key>.tga, drawn by
-- tools/make_look_previews.py from the real look code on the mock client. They
-- are not live: a look keeps its regions on the one secure prompt and its text
-- layout in Prompt's own tables, so a second copy of one painting in a card is
-- not something the code can do, and nothing here touches the prompt but the
-- setting itself. So nothing in a card is secure, nothing runs on a timer, and
-- there is no OnUpdate to stop when the window closes. A look the tool has not
-- drawn has a card with the addon's icon where the picture goes.
--
-- Two or three cards to a row, as many as the page is wide enough for, every
-- row as tall as its tallest card.

local _, ns = ...
local W = ns.WindowWidgets
local T, KIND = W.Theme, W.KIND

local function Bind() return ns.WindowBind end

local GAP, PAD, TEXT_GAP = 10, 6, 6
-- The narrowest a card is drawn, and the most to a row.
local MIN_WIDTH, MAX_COLUMNS = 150, 3
-- Textures/Previews are 256 x 64.
local SHOT_RATIO = 4
local BADGE = 18
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local ICON = "Interface\\AddOns\\Manners\\Textures\\Manners64"

local WASH_HOVER = { 1, 1, 1, 0.07 }
local WASH_ON = { T.gold[1], T.gold[2], T.gold[3], 0.08 }
local WASH_ON_HOVER = { T.gold[1], T.gold[2], T.gold[3], 0.14 }
local SHOT_GROUND = { 0.09, 0.10, 0.13 }
local SHOT_EDGE = { 0, 0, 0, 0.6 }
local BADGE_RING = { 0, 0, 0, 0.7 }
local BADGE_TICK = { 0.12, 0.09, 0.02 }

-- Four one-pixel lines round `anchor`, `out` units outside its edge (inside,
-- when negative).
local function Edges(owner, anchor, out, colour, layer, sublevel)
	local lines = {}
	local function line()
		local t = W.Solid(owner, layer, sublevel, colour)
		lines[#lines + 1] = t
		return t
	end
	local top = line()
	top:SetPoint("TOPLEFT", anchor, "TOPLEFT", -out, out)
	top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", out, out)
	top:SetHeight(1)
	local bottom = line()
	bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -out, -out)
	bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", out, -out)
	bottom:SetHeight(1)
	local left = line()
	left:SetPoint("TOPLEFT", anchor, "TOPLEFT", -out, out)
	left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -out, -out)
	left:SetWidth(1)
	local right = line()
	right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", out, out)
	right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", out, -out)
	right:SetWidth(1)
	return lines
end

local function ShowAll(list, on)
	for _, t in ipairs(list) do t:SetShown(on) end
end

-- How a card reads: chosen, under the pointer, or at rest; and dimmed while
-- the control is greyed out.
local function Look(card)
	local row = card.row
	local off = row.off
	local on, hover = card.selected, card.hover and not off
	local edge = T.fieldEdge
	if off then
		edge = T.fieldOff
	elseif on then
		edge = T.gold
	elseif hover then
		edge = T.edgeHi
	end
	W.BorderColour(card.edges, edge)
	ShowAll(card.inner, on and true or false)
	card.wash:SetShown(on or hover or false)
	if on then
		W.Colour(card.wash, hover and WASH_ON_HOVER or WASH_ON)
	else
		W.Colour(card.wash, WASH_HOVER)
	end
	W.TextColour(card.title, off and T.dim or (on and T.gold or T.ink))
	W.TextColour(card.desc, off and T.dim or T.hint)
	card.badge:SetShown(on and true or false)
	-- Greyed out, the words go to the window's dim (the one tone that keeps
	-- its contrast) and the picture to grey; the card itself stays whole.
	card.shot:SetDesaturated(off and true or false)
	card.shot:SetAlpha(off and 0.5 or 1)
	card:SetEnabled(not off)
end

local function Clicked(card)
	local row = card.row
	if W.Off(row) or not card.key or card.selected then return end
	W.Apply(row, card.key)
end

local function Entered(card)
	card.hover = true
	Look(card)
end

local function Left(card)
	card.hover = false
	Look(card)
end

local function BuildCard(row, i)
	local card = CreateFrame("Button", nil, row.frame)
	card:RegisterForClicks("LeftButtonUp")
	card.row = row
	card.fill = W.Solid(card, "BACKGROUND", -2, T.field)
	card.fill:SetAllPoints(card)
	card.wash = W.Solid(card, "BACKGROUND", -1, WASH_HOVER)
	card.wash:SetAllPoints(card)
	card.wash:Hide()
	card.edges = W.Border(card, T.fieldEdge)
	card.inner = Edges(card, card, -1, T.gold, "BORDER", 2)
	ShowAll(card.inner, false)

	-- The picture, on a ground of its own that shows through where there is
	-- none yet, with the addon's icon on it.
	card.ground = W.Solid(card, "ARTWORK", 0, SHOT_GROUND)
	card.shot = card:CreateTexture(nil, "ARTWORK", nil, 1)
	card.mark = card:CreateTexture(nil, "ARTWORK", nil, 1)
	card.mark:SetTexture(ICON)
	card.mark:SetAlpha(0.35)
	card.mark:SetSize(32, 32)
	card.mark:SetPoint("CENTER", card.ground, "CENTER", 0, 0)
	card.shotEdges = Edges(card, card.ground, 1, SHOT_EDGE, "ARTWORK", 2)

	card.title = W.Text(card, T.fonts.label, T.ink)
	card.title:SetWordWrap(false)
	card.desc = W.Wrapping(W.Text(card, T.fonts.small, T.hint))
	if card.desc.SetMaxLines then card.desc:SetMaxLines(2) end

	-- The tick for the chosen one: a gold disc on a dark ring, over the
	-- picture's corner, in a frame of its own so it draws over it.
	card.badge = CreateFrame("Frame", nil, card)
	card.badge:SetSize(BADGE, BADGE)
	card.badge:SetPoint("TOPRIGHT", card.ground, "TOPRIGHT", -4, -4)
	local ring = card.badge:CreateTexture(nil, "OVERLAY", nil, 1)
	ring:SetTexture(ROUND)
	ring:SetSize(BADGE + 4, BADGE + 4)
	ring:SetPoint("CENTER", card.badge, "CENTER", 0, 0)
	W.Colour(ring, BADGE_RING)
	local disc = card.badge:CreateTexture(nil, "OVERLAY", nil, 2)
	disc:SetTexture(ROUND)
	disc:SetAllPoints(card.badge)
	W.Colour(disc, T.gold)
	local tick = card.badge:CreateTexture(nil, "OVERLAY", nil, 3)
	tick:SetTexture(CHECK)
	tick:SetSize(BADGE + 6, BADGE + 6)
	tick:SetPoint("CENTER", card.badge, "CENTER", 0, 0)
	W.Colour(tick, BADGE_TICK)
	card.badge:Hide()

	card:SetScript("OnClick", function(self) ns.Guard("options look", Clicked, self) end)
	card:SetScript("OnEnter", function(self) ns.Guard("options look", Entered, self) end)
	card:SetScript("OnLeave", function(self) ns.Guard("options look", Left, self) end)
	row.cards[i] = card
	return card
end

KIND.themes = {
	Build = function(row)
		row.cards = {}
		row.count = 0
		row.cols = 1
	end,

	Refresh = function(row)
		-- The registry's list, as the dropdown is made from it, asked at every
		-- paint: a look registered since has a card the next time the page
		-- is drawn.
		local _, values = ns.Looks.Choices()
		local now = Bind().Value(row.item)
		for i, key in ipairs(values) do
			local card = row.cards[i] or BuildCard(row, i)
			card.key = key
			card.selected = now ~= nil and now == key
			-- The pointer may have left while the page was away.
			card.hover = card.hover and card:IsMouseOver() or false
			local title, line = ns.Looks.Card(key)
			card.title:SetText(W.Trim(title))
			card.desc:SetText(W.Trim(line))
			local file = ns.Looks.PreviewFile(key)
			-- Kept for the tests: the client has no call that reads a texture's
			-- file back.
			card.file = file
			if file then
				card.shot:SetTexture(file)
				card.shot:Show()
				card.mark:Hide()
			else
				card.shot:Hide()
				card.mark:Show()
			end
			Look(card)
			card:Show()
		end
		for i = #values + 1, #row.cards do row.cards[i]:Hide() end
		local was = row.count
		row.count = #values
		if was ~= nil and was ~= row.count and was > 0 then W.Relayout(row) end
	end,

	Layout = function(row, width)
		local count = row.count
		if count == 0 then return 0 end
		local cols = math.max(1, math.min(MAX_COLUMNS, math.floor((width + GAP) / (MIN_WIDTH + GAP))))
		cols = math.min(cols, count)
		row.cols = cols
		local base = math.floor((width - (cols - 1) * GAP) / cols)
		local extra = (width - (cols - 1) * GAP) - base * cols
		-- One height for every picture, so the names line up across a row.
		local shotH = math.floor((base - 2 * PAD) / SHOT_RATIO + 0.5)
		local y, i = 0, 1
		while i <= count do
			local last = math.min(count, i + cols - 1)
			local x, tallest = 0, 0
			-- Every card of the row, the first few a unit wider where the
			-- width does not divide, so the row runs the whole width.
			local sized = {}
			for k = i, last do
				local card = row.cards[k]
				local w = base + ((k - i) < extra and 1 or 0)
				local inner = w - 2 * PAD
				card.title:SetWidth(inner)
				card.desc:SetWidth(inner)
				local titleH = math.ceil(W.TextHeight(card.title))
				local descH = math.ceil(W.TextHeight(card.desc))
				local h = PAD + shotH + TEXT_GAP + titleH + (descH > 0 and 2 + descH or 0) + PAD
				sized[#sized + 1] = { card = card, w = w, h = h, inner = inner, shotH = shotH, titleH = titleH }
				tallest = math.max(tallest, h)
			end
			for _, s in ipairs(sized) do
				local card = s.card
				card:ClearAllPoints()
				card:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x, -y)
				card:SetSize(s.w, tallest)
				card.ground:ClearAllPoints()
				card.ground:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -PAD)
				card.ground:SetSize(s.inner, s.shotH)
				card.shot:ClearAllPoints()
				card.shot:SetAllPoints(card.ground)
				card.title:ClearAllPoints()
				card.title:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(PAD + s.shotH + TEXT_GAP))
				card.desc:ClearAllPoints()
				card.desc:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(PAD + s.shotH + TEXT_GAP + s.titleH + 2))
				card.x, card.y, card.w, card.h = x, y, s.w, tallest
				x = x + s.w + GAP
			end
			y = y + tallest + GAP
			i = last + 1
		end
		return y - GAP
	end,

	Natural = function() return MIN_WIDTH end,
}
