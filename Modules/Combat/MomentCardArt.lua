-- Manners -- a look's card dressed with live words and a live icon: the part of
-- the look picker's card (Options/Window/WidgetsTheme.lua) that the buttons for
-- the moment (Prompt/MomentsCard.lua) wear too, so a moment button is the same
-- picture of the player's look, with the spell's icon, its name and the reason
-- written over it, and nothing is drawn in code.
--
-- A look keeps its regions on the one secure prompt, so a second live copy of one
-- is not something the code can do; what a look records instead is its picture
-- (Textures/Previews/Preview_<key>.tga, made from the look's own card by
-- tools/make_look_previews.py) and where, on that picture, its icon and its two
-- lines sit and how each is written (Looks.PreviewIcon, Looks.PreviewText). This
-- file lays the spell's icon at the icon's rectangle, with the look's round mask
-- where it cuts its icon round, writes each line in the look's own face, size,
-- colour and shadow (its face only where the looks use it, else the player's
-- prompt font, shrunk up to a fifth to fit, then cut by the client as the
-- prompt's lines are) and, for a look that sets its reason in a tag of its own
-- (Luxe's pill), draws the tag round the words as wide as they are.
--
-- Everything works on a "card" table, the fields of which are those a picker card
-- already had:
--   owner      the frame that makes the textures, the mask and the font strings
--   anchor     what the regions are anchored to (a frame or a texture)
--   shot       the picture
--   icon       the spell's icon
--   lines      font strings by name; lineSize, lineFace what each was written in
--   pill       the tag's slices by layer; pillSpec, pillBox what was laid
--   at, textAt what the look records for the icon and the lines
--   picW, picH the picture's size in units
--   onPill     called after a tag is laid (the picker tints it)
-- A frame may be its own card (the picker's card is).
--
-- Out of a fight only, for a region of a frame the game paints or one that rides
-- a secure button: every call here that changes a texture, a font or a point is
-- the setup's. Nothing here is per frame.

local ns = assert(MannersAPI and MannersAPI:ModuleContext("combat"), "Manners module API is missing")
local LSM = LibStub("LibSharedMedia-3.0")

local CardArt = {}
ns.Looks.CardArt = CardArt

-- How the prompt crops a spell icon (Prompt/Panel.lua).
local CROP = { 0.08, 0.92, 0.08, 0.92 }
-- The smallest letters a card writes, and how far a line is drawn smaller to fit.
local MIN_SIZE, MIN_SHRINK = 5, 0.8
-- The smallest a look's own display face is written on a card: under it the
-- line is in the prompt's own font.
local SERIF_MIN = 12
-- A line with no face of its own, for LineFace.
local PLAIN = {}
-- A tag's three slices, cut from the file's quarters: the caps and the middle.
local CUTS = { { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }
-- The sublevel the tag's first layer is drawn at, over the icon (3) and under
-- the lines (OVERLAY).
local PILL_LEVEL = 4
-- The client languages whose alphabet a look's own face (Morpheus) draws: the
-- rule the looks follow for their own text.
local LATIN = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true,
	itIT = true, ptBR = true }

-- The unbounded width of a string's text, or an estimate where the client
-- will not say.
local function Measure(fs)
	local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
	local w = measure and ns.plain(measure(fs))
	if type(w) == "number" and w == w then return w end
	return #tostring(fs:GetText() or "") * 6
end

-- The icon laid at its rectangle in the card's picture: the look's fractions of
-- the picture's width and height, from its top left. Placed when the picture's
-- size is known (Layout) and again when the card is given another look.
local function PlaceIcon(card)
	local at, w, h = card.at, card.picW, card.picH
	if not (at and w and h) then return end
	local icon = card.icon
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", card.anchor, "TOPLEFT", at.l * w, -at.t * h)
	icon:SetPoint("BOTTOMRIGHT", card.anchor, "TOPLEFT", at.r * w, -at.b * h)
end

-- The icon's shape: the look's own round mask on the overlay of a round look,
-- none on the others, as the prompt masks its icon where masks exist.
local function ShapeIcon(card, at)
	local icon = card.icon
	local round = at and at.round and at.mask and card.owner.CreateMaskTexture and icon.AddMaskTexture
	if round then
		if not card.mask then card.mask = card.owner:CreateMaskTexture() end
		card.mask:SetTexture(at.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		card.mask:ClearAllPoints()
		card.mask:SetAllPoints(icon)
		if not card.masked then
			icon:AddMaskTexture(card.mask)
			card.masked = true
		end
	elseif card.masked then
		icon:RemoveMaskTexture(card.mask)
		card.masked = false
	end
end

-- A card's live icon, for the look it is showing: `at` is where that look's
-- picture holds its icon (nil for a look without one), `file` the spell icon.
-- card.at and card.iconFile are kept for the tests.
local function DressIcon(card, at, file)
	local icon = card.icon
	card.at = at
	if not at then
		ShapeIcon(card, nil)
		card.iconFile = nil
		icon:Hide()
		return
	end
	card.iconFile = file
	icon:SetTexture(file)
	local crop = at.crop or CROP
	icon:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
	ShapeIcon(card, at)
	PlaceIcon(card)
	icon:Show()
end

-- The face a line is written in: the look's own where the looks use it (a client
-- whose alphabet it has, the player's font the default one: AceDB strips a value
-- equal to the default, so only another is a choice), else the prompt's own font.
local function LineFace(spec)
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	if spec.font then
		local own = ns.defaults and ns.defaults.profile.prompt.font
		local chosen = p and type(p.font) == "string" and p.font ~= own
		if not chosen and (not spec.latin or LATIN[ns.LOCALE or "enUS"]) then return spec.font end
	end
	return p and LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT
end

local function SetFace(fs, path, size, flags)
	if not fs:SetFont(path, size, flags) or not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
end

-- A shadow offset in the picture's units, a whole unit at the least: a fraction
-- of one is no shadow.
local function Offset(v)
	local n = math.max(1, math.floor(math.abs(v) + 0.5))
	return v < 0 and -n or n
end

-- The tag's slices for its layer `i`, made the first time a look asks for them.
local function PillSlices(card, i)
	local s = card.pill[i]
	if s then return s end
	s = {}
	for j = 1, 3 do
		local t = card.owner:CreateTexture(nil, "ARTWORK", nil, math.min(7, PILL_LEVEL + i - 1))
		t:SetTexCoord(CUTS[j][1], CUTS[j][2], 0, 1)
		t:Hide()
		s[j] = t
	end
	card.pill[i] = s
	return s
end

local function HidePill(card, from)
	for i = from or 1, #card.pill do
		for _, t in ipairs(card.pill[i]) do t:Hide() end
	end
	if not from then card.pillSpec, card.pillBox = nil, nil end
end

-- The tag a look sets its reason line in, round the line as the card has just
-- fitted it: it reaches `lead` and `tail` past the words (what the line
-- measures, or its rectangle where the client is left to cut it), its edges and
-- its caps scaled with the picture as the letters are, each layer the look's own
-- file in the look's own colour. So a reason in any language wears a tag of its
-- own width, as it does on the prompt. card.pillBox is kept for the tests.
local function PlacePill(card, spec, fs, room)
	local pill = spec.pill
	if not pill then
		HidePill(card)
		return
	end
	local w, h = card.picW, card.picH
	local top, bottom = pill.t * h, pill.b * h
	local height = bottom - top
	local cap = (pill.cap or 0.5) * height
	local left = spec.l * w - pill.lead * h
	local right = spec.l * w + math.min(Measure(fs), room) + pill.tail * h
	card.pillSpec, card.pillBox = pill, { left, top, right, bottom }
	for i, layer in ipairs(pill.layers) do
		local s = PillSlices(card, i)
		for _, t in ipairs(s) do
			t:SetTexture(layer.file)
			t:ClearAllPoints()
		end
		s[1]:SetPoint("TOPLEFT", card.anchor, "TOPLEFT", left, -top)
		s[1]:SetPoint("BOTTOMRIGHT", card.anchor, "TOPLEFT", left + cap, -bottom)
		s[3]:SetPoint("TOPLEFT", card.anchor, "TOPLEFT", right - cap, -top)
		s[3]:SetPoint("BOTTOMRIGHT", card.anchor, "TOPLEFT", right, -bottom)
		s[2]:SetPoint("TOPLEFT", card.anchor, "TOPLEFT", left + cap, -top)
		s[2]:SetPoint("BOTTOMRIGHT", card.anchor, "TOPLEFT", right - cap, -bottom)
		for _, t in ipairs(s) do t:Show() end
	end
	HidePill(card, #pill.layers + 1)
	-- Slices made here, at layout, after the card was last painted: tinted now
	-- by whoever tints them, or they stay the file's own white.
	if card.onPill then card.onPill(card) end
end

-- One line at its rectangle in the picture, in the look's face, at the look's
-- size for this picture (a card's picture is smaller than the 248 x 62 units the
-- tool drew), drawn up to a fifth smaller where the words are wider than the
-- rectangle; what is still too wide the client cuts, as the prompt's lines are.
-- A look's own serif only at SERIF_MIN units or more: where the picture's size
-- for the line is under that it is in the prompt's own font, and a line in the
-- serif is never fitted to less. card.lineFace says which it was.
-- The reason line's tag, where its look has one, is laid round it.
local function PlaceLine(card, name, spec, text)
	local fs, w, h = card.lines[name], card.picW, card.picH
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", card.anchor, "TOPLEFT", spec.l * w, -spec.t * h)
	fs:SetPoint("BOTTOMRIGHT", card.anchor, "TOPLEFT", spec.r * w, -spec.b * h)
	fs:SetJustifyH(spec.h or "LEFT")
	fs:SetJustifyV(spec.v or "MIDDLE")
	fs:SetWordWrap(false)
	local shadow = spec.shadow
	if shadow then
		local c = shadow.color
		fs:SetShadowColor(c[1], c[2], c[3], c[4])
		fs:SetShadowOffset(Offset(shadow.x * h), Offset(shadow.y * h))
	else
		fs:SetShadowColor(0, 0, 0, 0)
		fs:SetShadowOffset(0, 0)
	end
	local path, flags = LineFace(spec), spec.flags or ""
	local base = math.max(MIN_SIZE, math.floor(spec.size * h + 0.5))
	local least = math.max(MIN_SIZE, math.floor(base * MIN_SHRINK + 0.5))
	if spec.font and path == spec.font then
		if base < SERIF_MIN then path = LineFace(PLAIN) else least = math.max(least, SERIF_MIN) end
	end
	local room = (spec.r - spec.l) * w
	local size = base
	SetFace(fs, path, size, flags)
	fs:SetText(text)
	while size > least and Measure(fs) > room + 0.5 do
		size = size - 1
		SetFace(fs, path, size, flags)
	end
	-- Kept for the tests: the client has no call that reads the size back.
	card.lineSize[name], card.lineFace[name] = size, path
	if name == "reason" then PlacePill(card, spec, fs, room) end
	fs:Show()
end

-- A card's lines, for the look it is showing: `at` is what the look's picture
-- records for them (nil for a look without any), `texts` the words by name; a
-- name with no words is hidden. card.textAt and the rest are kept for the tests.
local function PlaceText(card, texts)
	local at, w, h = card.textAt, card.picW, card.picH
	for _, name in ipairs(card.names) do
		local spec = at and at[name]
		local text = texts and texts[name]
		if spec and w and h and text ~= nil then
			PlaceLine(card, name, spec, text)
		else
			card.lines[name]:Hide()
			card.lineSize[name], card.lineFace[name] = nil, nil
			if name == "reason" then HidePill(card) end
		end
	end
end

-- The regions of a moment card on `owner`: the picture (ARTWORK 0), the spell's
-- icon (ARTWORK 3) and a font string a name, laid by Dress. anchor is the owner.
function CardArt.New(owner, names)
	local card = { owner = owner, anchor = owner, names = names, pill = {}, lines = {}, lineSize = {}, lineFace = {} }
	card.shot = owner:CreateTexture(nil, "ARTWORK", nil, 0)
	card.icon = owner:CreateTexture(nil, "ARTWORK", nil, 3)
	card.icon:Hide()
	for _, name in ipairs(names) do
		local fs = owner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:Hide()
		card.lines[name] = fs
	end
	return card
end

-- The picture, the icon and the words for a look at this size (w x h units; the
-- pictures are 4:1): `file` the picture, `at` and `textAt` what the look records,
-- `iconFile` the spell's icon, `texts` the words by name.
function CardArt.Dress(card, file, at, textAt, iconFile, texts, w, h)
	card.file = file
	card.shot:SetTexture(file)
	card.shot:ClearAllPoints()
	card.shot:SetAllPoints(card.anchor)
	card.picW, card.picH = w, h
	DressIcon(card, at, iconFile)
	card.textAt = textAt
	PlaceText(card, texts)
end

CardArt.Measure, CardArt.PlaceIcon, CardArt.ShapeIcon, CardArt.DressIcon = Measure, PlaceIcon, ShapeIcon, DressIcon
CardArt.LineFace, CardArt.SetFace, CardArt.Offset = LineFace, SetFace, Offset
CardArt.PillSlices, CardArt.HidePill, CardArt.PlacePill = PillSlices, HidePill, PlacePill
CardArt.PlaceLine, CardArt.PlaceText = PlaceLine, PlaceText
