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
-- Two things on a card are live, laid over the picture. The first is the spell icon. The picture holds a tile
-- where the look draws it (the tool has no game art), and a texture over the
-- picture, at the rectangle the tool recorded for that look (Looks.PreviewIcon),
-- shows the icon of the buff this character casts, cropped as the prompt crops
-- it. The client draws it; no spell art is in any file of the addon. A look
-- that cuts its icon round (Toast, Ribbon, Letter) has the same mask file on the
-- overlay; the others are square, as they are in the picture. A client without
-- mask textures (none of the five) draws them square. The texture is set when
-- the page is painted, so an icon the client had not loaded yet is there the
-- next time the page is drawn.
--
-- The second is the text. The pictures carry none (the tool leaves the
-- name and the reason line out of them), because a picture has one language.
-- Two font strings over each picture, at the rectangles the tool recorded for the
-- look's two lines (Looks.PreviewText), write a sample name, "Anna Aim", which is
-- a name and so the same in every language, and the reason a prompt gives for
-- somebody who buffed you in the client's own words (L["buffed you"], the
-- prompt's default for it, so no string is new). Each is written as the look
-- writes that line: its face where the looks use it (a Latin client, the player's
-- font the default one) else the prompt's own font, its size, colour, shadow and
-- outline, the size scaled with the picture. A line wider than its rectangle is
-- drawn up to a fifth smaller, then cut by the client, as the prompt's are. Set
-- when the page is painted and laid out; nothing is per frame.
--
-- A look's own face is a display serif (Morpheus: Ribbon, Letter and Leather
-- write the name in it), thin, with small letters for its size. A card's picture
-- is smaller than the prompt, and the name scaled down with it was the hardest
-- writing in the window to read (10 units of Morpheus on a card of the window's
-- first size). So the looks draw that name larger than any other face's, which a
-- card follows, and a card writes in the serif only what comes to SERIF_MIN units
-- or more: on a picture smaller than that the name is in the prompt's own font,
-- as every other card's is, and the serif is never drawn smaller to fit.
--
-- A look that sets its reason line in a tag of its own (Luxe's pill) has the tag
-- drawn live as well, round the live words: baked into the picture it was the
-- English words' width, and a German or Korean reason ran past it. The tool
-- records the tag with the line (`pill`: its edges, how far it reaches past the
-- words on either side, its caps, and its layers, each the look's own file as a
-- horizontal three-slice in the look's colour), and the card lays those textures
-- over the picture, under the words, as wide as the words it has just measured.
--
-- The pictures follow *Earlier art*: a look that has an earlier art (a painted
-- look's own code, drawn as before) has a second picture of it, and its card
-- wears that one while the switch is on (Looks.PreviewFile and the rest answer
-- for the art the prompt draws now).
--
-- TABS. Over the cards, a row of tabs: For my class (the looks Looks.FOR_CLASS
-- made for the player's class; only for a class that has some), All, and one
-- per shelf (Looks.CATEGORIES: Minimal, Classic, Themed, Class), each with how
-- many it holds. They are boxed, unlike the underlined sub-divisions in the
-- bar over the page, so the two rows never read as one. The first time it opens
-- on For my class where there is one, else All; the tab last chosen is kept
-- for the session (row.tab: the row lives as long as the window). All lays the
-- shelves out in order, each under a small heading. Under the tabs, one line
-- says what pointing and clicking do, and in a fight that looks wait for its
-- end.
--
-- TRYING A LOOK. The pointer on a card puts that look on the real prompt at
-- once (the Look page starts the preview, Window.lua's LookOpened, so it is on
-- screen), by the profile's style and Prompt:ApplyStyle, as a pick does; the
-- pointer leaving, the card hidden (another tab, another page, the window
-- shut), a fight starting or the game logging out puts the chosen look back.
-- A click keeps it. Never in a fight: ApplyStyle cannot run there, so the
-- pointer tries nothing. Each look's Hide is its contract that nothing of it
-- stays behind; the change is the same one a click makes. Nothing of it runs
-- per frame: the card's own OnEnter and OnLeave, and two events on a frame of
-- its own, made the first time a look is tried.
--
-- Two cards to a row in the usual window, three at most, as many as the page
-- is wide enough for, every row as tall as its tallest card; a card is a
-- picture, the look's name with a small New for a look new in this release
-- and the tick on the chosen one, and its line. The dropdown, which the
-- fallback dialog keeps, is the same list flat.

local _, ns = ...
local W = ns.WindowWidgets
local T, KIND = W.Theme, W.KIND
local L = ns.L
local LSM = LibStub("LibSharedMedia-3.0")

local function Bind() return ns.WindowBind end

local GAP, PAD, TEXT_GAP = 10, 8, 7
-- A shelf's heading on All: its height, and the room under it before its cards.
local HEAD_H, HEAD_GAP = 16, 4
-- The narrowest a card is drawn, and the most to a row: two in the usual
-- window, whose page is 612 wide.
local MIN_WIDTH, MAX_COLUMNS = 200, 3
-- The tabs: their height, the room either side of a tab's words and between
-- two tabs, and under the row of them and under the line that follows.
local TAB_H, TAB_PAD, TAB_GAP, TABS_GAP, HINT_GAP = 22, 9, 6, 7, 10
-- In their order: For my class first, then All, then a shelf each.
local TABS = { "mine", "all", "minimal", "classic", "themed", "class" }
-- The small New on a card: its height and the room either side of the word.
local TAG_H, TAG_PAD = 14, 5
-- Textures/Previews are 256 x 64.
local SHOT_RATIO = 4
local BADGE = 18
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local ICON = "Interface\\AddOns\\Manners\\Textures\\Manners64"
-- The client's own question mark, for a character with no spell to show.
local UNKNOWN = 134400
-- How the prompt crops a spell icon (Prompt/Panel.lua).
local CROP = { 0.08, 0.92, 0.08, 0.92 }
-- The name the cards write: a name is not translated.
local SAMPLE_NAME = "Anna Aim"
-- The two lines, in the order the tool records them (Looks.PreviewText).
local LINES = { "name", "reason" }
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

local WASH_HOVER = { 1, 1, 1, 0.07 }
local WASH_ON = { T.gold[1], T.gold[2], T.gold[3], 0.08 }
local WASH_ON_HOVER = { T.gold[1], T.gold[2], T.gold[3], 0.14 }
local SHOT_GROUND = { 0.09, 0.10, 0.13 }
local SHOT_EDGE = { 0, 0, 0, 0.6 }
local BADGE_RING = { 0, 0, 0, 0.7 }
local BADGE_TICK = { 0.12, 0.09, 0.02 }
-- New: pale green words on a dark green tag (8:1).
local NEW_FILL = { 0.10, 0.27, 0.15, 1 }
local NEW_INK = { 0.74, 0.95, 0.72 }
-- A tab: the chosen one gold on a gold wash, one under the pointer lighter.
local TAB_ON = { T.gold[1], T.gold[2], T.gold[3], 0.13 }
local TAB_HOVER = { 1, 1, 1, 0.05 }
-- A shelf's heading on All, and the hairline after it.
local HEAD_INK = T.goldSoft
local HEAD_RULE = { T.gold[1], T.gold[2], T.gold[3], 0.22 }

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

local function Grey(c)
	return 0.3 * c[1] + 0.59 * c[2] + 0.11 * c[3]
end

-- The sample lines in their own colours, or grey and dimmed with the rest of a
-- greyed-out card; the tag round the reason goes grey with them.
local function TintLines(card, off)
	for _, name in ipairs(LINES) do
		local fs, spec = card.lines[name], card.textAt and card.textAt[name]
		if fs and spec then
			local c = spec.color
			if off then
				local grey = Grey(c)
				fs:SetTextColor(grey, grey, grey, c[4])
			else
				fs:SetTextColor(c[1], c[2], c[3], c[4])
			end
			fs:SetAlpha(off and 0.5 or 1)
		end
	end
	local pill = card.pillSpec
	for i, s in ipairs(card.pill) do
		local layer = pill and pill.layers[i]
		for _, t in ipairs(s) do
			if layer then
				local c = layer.color
				if off then
					local grey = Grey(c)
					t:SetVertexColor(grey, grey, grey, c[4])
				else
					t:SetVertexColor(c[1], c[2], c[3], c[4])
				end
			end
			t:SetAlpha(off and 0.5 or 1)
		end
	end
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
	-- New at the name line's right end, left of the tick where it shows.
	card.newTag:ClearAllPoints()
	card.newTag:SetPoint("TOPRIGHT", card.ground, "BOTTOMRIGHT", on and -(BADGE + 6) or 0, -(3 + (BADGE - TAG_H) / 2))
	-- Greyed out, the words go to the window's dim (the one tone that keeps
	-- its contrast) and the picture to grey; the card itself stays whole.
	card.shot:SetDesaturated(off and true or false)
	card.shot:SetAlpha(off and 0.5 or 1)
	-- The live icon over the picture goes grey with it.
	card.icon:SetDesaturated(off and true or false)
	card.icon:SetAlpha(off and 0.5 or 1)
	TintLines(card, off)
	card:SetEnabled(not off)
end

---------------------------------------------------------------------------
-- trying a look: the one under the pointer on the real prompt (see the header)
---------------------------------------------------------------------------

-- The look being tried, the chosen one it stands in for, and its card; nil
-- while none is.
local trial
local events

local function PromptSettings()
	return ns.db and ns.db.profile and ns.db.profile.prompt
end

local function Restyle()
	if ns.Prompt and not InCombatLockdown() then ns.Prompt:ApplyStyle() end
end

-- The chosen look back on the prompt (`redraw`: drawn now; a click about to
-- choose another, or the game logging out, need not).
local function EndTrial(redraw)
	local t = trial
	if not t then return end
	trial = nil
	t.card.trying = false
	local p = PromptSettings()
	if p and p.style == t.key then p.style = t.was end
	if redraw then Restyle() end
end

-- A fight starting (still out of the lockdown, so the chosen look is drawn
-- again before it), or the game logging out (so a look under the pointer is
-- never the one saved).
local function TrialEvent(_, event)
	ns.Guard("options look", EndTrial, event ~= "PLAYER_LOGOUT")
end

local function Try(card)
	local p = PromptSettings()
	if not (p and card.key) or InCombatLockdown() or W.Off(card.row) then return end
	local had = trial ~= nil
	local was = had and trial.was or p.style
	EndTrial(false)
	if card.key == was then
		if had then Restyle() end
		return
	end
	if not events then
		events = CreateFrame("Frame")
		events:RegisterEvent("PLAYER_REGEN_DISABLED")
		events:RegisterEvent("PLAYER_LOGOUT")
		events:SetScript("OnEvent", TrialEvent)
	end
	trial = { key = card.key, was = was, card = card }
	card.trying = true
	p.style = card.key
	Restyle()
end

local function Clicked(card)
	local row = card.row
	-- The look under the pointer is the one clicked: the chosen one goes back
	-- first, so the click is the pick it would be without the trial.
	if card.trying then EndTrial(false) end
	if W.Off(row) or not card.key or card.selected then return end
	W.Apply(row, card.key)
end

local function Entered(card)
	card.hover = true
	Look(card)
	Try(card)
end

local function Left(card)
	card.hover = false
	Look(card)
	if card.trying then EndTrial(true) end
end

-- A card put away under the pointer (another tab, another page, the window
-- shut) has no OnLeave to wait for.
local function CardHidden(card)
	card.hover = false
	if card.trying then EndTrial(true) end
end

-- The icon the cards wear: the spell of the first buff the prompt would offer
-- this character (CastableBuffs, in the order the prompt walks them; the buff's
-- own icon from the capability probe, which is what the prompt's icon shows),
-- else the first of the class's own buffs it has learned (a hunter's aspect, a
-- shaman's shield), else the client's question mark. Never the icon of a spell
-- the character cannot cast: a card promises what the prompt will show.
local function BuffIcon()
	local function file(info)
		local icon = info and info.icon
		if type(icon) == "number" or type(icon) == "string" then return icon end
	end
	for _, buff in ipairs(ns.CastableBuffs()) do
		local icon = file(ns.BuffInfo(buff))
		if icon then return icon end
	end
	local own = ns.caps.own
	for _, family in ipairs(ns.GetOwnFamilies() or {}) do
		for _, spell in ipairs(family.spells or {}) do
			local info = own and own[spell.key]
			local icon = info and info.known and file(info)
			if icon then return icon end
		end
	end
	return UNKNOWN
end

-- The icon laid at its rectangle in the card's picture: the look's fractions of
-- the picture's width and height, from its top left. Placed when the picture's
-- size is known (Layout) and again when the card is given another look.
local function PlaceIcon(card)
	local at, w, h = card.at, card.picW, card.picH
	if not (at and w and h) then return end
	local icon = card.icon
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", card.ground, "TOPLEFT", at.l * w, -at.t * h)
	icon:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", at.r * w, -at.b * h)
end

-- The icon's shape: the look's own round mask on the overlay of a round look,
-- none on the others, as the prompt masks its icon where masks exist.
local function ShapeIcon(card, at)
	local icon = card.icon
	local round = at and at.round and at.mask and card.CreateMaskTexture and icon.AddMaskTexture
	if round then
		if not card.mask then card.mask = card:CreateMaskTexture() end
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
		local t = card:CreateTexture(nil, "ARTWORK", nil, math.min(7, PILL_LEVEL + i - 1))
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
	local right = spec.l * w + math.min(W.Measure(fs), room) + pill.tail * h
	card.pillSpec, card.pillBox = pill, { left, top, right, bottom }
	for i, layer in ipairs(pill.layers) do
		local s = PillSlices(card, i)
		for _, t in ipairs(s) do
			t:SetTexture(layer.file)
			t:ClearAllPoints()
		end
		s[1]:SetPoint("TOPLEFT", card.ground, "TOPLEFT", left, -top)
		s[1]:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", left + cap, -bottom)
		s[3]:SetPoint("TOPLEFT", card.ground, "TOPLEFT", right - cap, -top)
		s[3]:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", right, -bottom)
		s[2]:SetPoint("TOPLEFT", card.ground, "TOPLEFT", left + cap, -top)
		s[2]:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", right - cap, -bottom)
		for _, t in ipairs(s) do t:Show() end
	end
	HidePill(card, #pill.layers + 1)
	-- Slices made here, at layout, after the card was last painted: tinted now,
	-- or they stay the file's own white until the pointer passes over the card.
	TintLines(card, card.row and card.row.off)
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
	fs:SetPoint("TOPLEFT", card.ground, "TOPLEFT", spec.l * w, -spec.t * h)
	fs:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", spec.r * w, -spec.b * h)
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
	while size > least and W.Measure(fs) > room + 0.5 do
		size = size - 1
		SetFace(fs, path, size, flags)
	end
	-- Kept for the tests: the client has no call that reads the size back.
	card.lineSize[name], card.lineFace[name] = size, path
	if name == "reason" then PlacePill(card, spec, fs, room) end
	fs:Show()
end

-- A card's two lines, for the look it is showing: `at` is what the look's
-- picture records for them (nil for a look without any). card.textAt and the
-- rest are kept for the tests. Placed once the picture's size is known (Layout)
-- as well as here, which is when the language and the player's font are read.
local function PlaceText(card)
	local at, w, h = card.textAt, card.picW, card.picH
	for _, name in ipairs(LINES) do
		local spec = at and at[name]
		if spec and w and h then
			PlaceLine(card, name, spec, name == "name" and SAMPLE_NAME or L["buffed you"])
		else
			card.lines[name]:Hide()
			card.lineSize[name], card.lineFace[name] = nil, nil
			if name == "reason" then HidePill(card) end
		end
	end
end

local function DressText(card, at)
	card.textAt = at
	PlaceText(card)
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
	-- The spell icon, over the tile the picture draws there (see the header).
	card.icon = card:CreateTexture(nil, "ARTWORK", nil, 3)
	card.icon:Hide()
	-- The tag round the reason line, for a look that has one: its slices are
	-- made when a look first asks for them (PillSlices).
	card.pill = {}
	-- The sample name and reason over the picture, in a layer above the icon's.
	card.lines, card.lineSize, card.lineFace = {}, {}, {}
	for _, name in ipairs(LINES) do
		local fs = W.Text(card, T.fonts.small, T.ink, "OVERLAY")
		fs:Hide()
		card.lines[name] = fs
	end

	card.title = W.Text(card, T.fonts.label, T.ink)
	card.title:SetWordWrap(false)
	card.desc = W.Wrapping(W.Text(card, T.fonts.small, T.hint))
	-- As many lines as the words take: the row is as tall as its tallest card
	-- (Layout), and a cap of two cut the longest description short in German,
	-- French, Spanish, Portuguese and Italian at the window's smallest.

	-- The tick for the chosen one: a gold disc on a dark ring, under the
	-- picture's right corner on the title's line, clear of the picture (over
	-- its corner it covered the look's own art: Fel's gem, 1.11.25).
	card.badge = CreateFrame("Frame", nil, card)
	card.badge:SetSize(BADGE, BADGE)
	card.badge:SetPoint("TOPRIGHT", card.ground, "BOTTOMRIGHT", 0, -3)
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

	-- New, for a look new in this release (Looks.NEW): a small green tag on the
	-- name's line, left of where the tick goes.
	card.newTag = CreateFrame("Frame", nil, card)
	local fill = W.Solid(card.newTag, "ARTWORK", 0, NEW_FILL)
	fill:SetAllPoints(card.newTag)
	card.newTag.text = W.Text(card.newTag, T.fonts.small, NEW_INK, "OVERLAY")
	card.newTag.text:SetPoint("CENTER", card.newTag, "CENTER", 0, 0)
	card.newTag.text:SetJustifyH("CENTER")
	card.newTag.text:SetWordWrap(false)
	card.newTag.text:SetText(L["New"])
	card.newTag:SetSize(math.ceil(W.Measure(card.newTag.text)) + 2 * TAG_PAD, TAG_H)
	card.newTag:SetPoint("TOPRIGHT", card.ground, "BOTTOMRIGHT", -(BADGE + 6), -(3 + (BADGE - TAG_H) / 2))
	card.newTag:Hide()

	card:SetScript("OnClick", function(self) ns.Guard("options look", Clicked, self) end)
	card:SetScript("OnEnter", function(self) ns.Guard("options look", Entered, self) end)
	card:SetScript("OnLeave", function(self) ns.Guard("options look", Left, self) end)
	card:SetScript("OnHide", function(self) ns.Guard("options look", CardHidden, self) end)
	row.cards[i] = card
	return card
end

---------------------------------------------------------------------------
-- the tabs over the cards (see the header)
---------------------------------------------------------------------------

-- The player's class as UnitClass names it, or nil.
local function PlayerClass()
	if type(UnitClass) ~= "function" then return nil end
	local _, class = UnitClass("player")
	class = ns.plain(class)
	return type(class) == "string" and class or nil
end

local function TabTitle(tab)
	if tab == "mine" then return L["For my class"] end
	if tab == "all" then return L["All"] end
	return ns.Looks.CATEGORY_TITLE[tab] or tab
end

-- Whether a look is under a tab: All holds every one, For my class the class's
-- own (`mine`, a set of keys), a shelf's tab that shelf's.
local function Under(tab, key, mine)
	if tab == "all" then return true end
	if tab == "mine" then return mine[key] == true end
	return ns.Looks.Category(key) == tab
end

-- How many looks each tab holds.
local function Counts(values, mine)
	local counts = { all = #values, mine = 0 }
	for _, c in ipairs(ns.Looks.CATEGORIES) do counts[c] = 0 end
	for _, key in ipairs(values) do
		if mine[key] then counts.mine = counts.mine + 1 end
		local c = ns.Looks.Category(key)
		counts[c] = (counts[c] or 0) + 1
	end
	return counts
end

-- How a tab reads: chosen (gold, on a gold wash), under the pointer (lighter),
-- or at rest.
local function TabLook(b)
	local on = b.row.tab == b.tab
	local hot = b.hover and not on
	W.Colour(b.wash, on and TAB_ON or TAB_HOVER)
	b.wash:SetShown((on or hot) and true or false)
	W.BorderColour(b.edges, on and T.gold or (hot and T.edgeHi or T.fieldEdge))
	W.TextColour(b.label, on and T.gold or (hot and T.ink or T.inkSoft))
end

-- A tab chosen: its cards shown, the others put away (a look being tried on a
-- card put away goes back, CardHidden), and the page laid out again. Kept for
-- the session in row.tab.
local function TabClicked(b)
	local row = b.row
	if row.tab == b.tab then return end
	row.tab = b.tab
	row:Refresh()
	W.Relayout(row)
end

local function TabEntered(b)
	b.hover = true
	TabLook(b)
end

local function TabLeft(b)
	b.hover = false
	TabLook(b)
end

local function BuildTab(row, tab)
	local b = CreateFrame("Button", nil, row.frame)
	b:RegisterForClicks("LeftButtonUp")
	b.row, b.tab = row, tab
	local fill = W.Solid(b, "BACKGROUND", -2, T.field)
	fill:SetAllPoints(b)
	b.wash = W.Solid(b, "BACKGROUND", -1, TAB_ON)
	b.wash:SetAllPoints(b)
	b.edges = W.Border(b, T.fieldEdge)
	b.label = W.Text(b, T.fonts.label, T.inkSoft)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetJustifyH("CENTER")
	b.label:SetWordWrap(false)
	b:SetScript("OnClick", function(self) ns.Guard("options look", TabClicked, self) end)
	b:SetScript("OnEnter", function(self) ns.Guard("options look", TabEntered, self) end)
	b:SetScript("OnLeave", function(self) ns.Guard("options look", TabLeft, self) end)
	row.tabs[tab] = b
	return b
end

-- The line under the tabs: what pointing and clicking do, that the prompt has
-- to be up to see it, and in a fight that looks wait for its end.
local function Hint()
	if InCombatLockdown() then
		return "|cffffd100" .. L["In a fight a look cannot change: the one you click goes on when the fight ends."] .. "|r"
	end
	local text = L["Point at a look to try it on the prompt; click to keep it."]
	local prompt = ns.Prompt
	local button = prompt and prompt.GetButton and prompt:GetButton()
	if prompt and not prompt:InTest() and not (button and button:IsShown()) then
		text = text .. " " .. L["The prompt is not on screen now: Show me the prompt, at the top of this window, puts it up."]
	end
	return text
end

-- Every tab's words and count, shown while it holds a look (For my class only
-- for a class with looks of its own), and the line under them.
local function PaintTabs(row)
	for _, tab in ipairs(TABS) do
		local n = row.counts[tab] or 0
		local b = row.tabs[tab] or BuildTab(row, tab)
		b.shown = n > 0
		b:SetShown(b.shown)
		b.label:SetText(("%s  |cff8e8b84%d|r"):format(TabTitle(tab), n))
		b.hover = b.hover and b:IsMouseOver() or false
		TabLook(b)
	end
	row.hint:SetText(Hint())
end

-- The tabs left to right, onto another line where they run past the width, and
-- the line under them. Answers where the cards start.
local function PlaceTabs(row, width)
	local x, y = 0, 0
	for _, tab in ipairs(TABS) do
		local b = row.tabs[tab]
		if b and b.shown then
			local w = math.min(width, math.ceil(W.Measure(b.label)) + 2 * TAB_PAD)
			if x > 0 and x + w > width then x, y = 0, y + TAB_H + TAB_GAP end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x, -y)
			b:SetSize(w, TAB_H)
			b.x, b.y, b.w = x, y, w
			x = x + w + TAB_GAP
		end
	end
	y = y + TAB_H + TABS_GAP
	row.hint:ClearAllPoints()
	row.hint:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -y)
	row.hint:SetWidth(width)
	row.hint.y = y
	return y + math.ceil(W.TextHeight(row.hint)) + HINT_GAP
end

-- A shelf's heading on All, at `y` from the row's top: its name and how many,
-- and a hairline on to the right edge. Answers where its cards start.
-- row.heads is kept for the tests.
local function PlaceHead(row, cat, y, width)
	local head = row.heads[cat]
	if not head then
		head = CreateFrame("Frame", nil, row.frame)
		head.cat = cat
		head.text = W.Text(head, T.fonts.normalSmall, HEAD_INK)
		head.text:SetJustifyH("LEFT")
		head.text:SetWordWrap(false)
		head.text:SetPoint("LEFT", head, "LEFT", 0, 0)
		head.rule = W.Solid(head, "ARTWORK", 0, HEAD_RULE)
		head.rule:SetHeight(1)
		row.heads[cat] = head
	end
	head.text:SetText(("%s  |cff8e8b84%d|r"):format(ns.Looks.CATEGORY_TITLE[cat] or cat, row.counts[cat] or 0))
	head:ClearAllPoints()
	head:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -y)
	head:SetSize(width, HEAD_H)
	head.rule:ClearAllPoints()
	head.rule:SetPoint("LEFT", head, "LEFT", math.min(width, math.ceil(W.Measure(head.text)) + 8), 0)
	head.rule:SetPoint("RIGHT", head, "RIGHT", 0, 0)
	head:Show()
	head.y = y
	return y + HEAD_H + HEAD_GAP
end

KIND.themes = {
	Build = function(row)
		row.heads, row.tabs = {}, {}
		row.cards = {}
		row.count = 0
		row.cols = 1
		row.counts = {}
		row.hint = W.Wrapping(W.Text(row.frame, T.fonts.small, T.hint))
		-- The gallery put away (another page) or the window shut with a look
		-- being tried: the chosen one goes back, whichever card had the pointer.
		local function away() ns.Guard("options look", EndTrial, true) end
		row.frame:HookScript("OnHide", away)
		local win = row.ctx and row.ctx.Window
		if win and win.HookScript then win:HookScript("OnHide", away) end
	end,

	Refresh = function(row)
		-- The registry's list, as the dropdown is made from it, asked at every
		-- paint: a look registered since has a card the next time the page
		-- is drawn.
		local _, values = ns.Looks.Choices()
		-- The chosen look: while one is tried under the pointer, the one it
		-- stands in for.
		local now = trial and trial.was or Bind().Value(row.item)
		local mine = {}
		for _, key in ipairs(ns.Looks.ForClass(PlayerClass())) do mine[key] = true end
		row.counts = Counts(values, mine)
		-- The first time, For my class where the class has looks of its own,
		-- else All; after that the tab chosen last, while it holds a look.
		if not (row.tab and (row.counts[row.tab] or 0) > 0) then
			row.tab = row.counts.mine > 0 and "mine" or "all"
		end
		PaintTabs(row)
		-- One icon for every card, asked at every paint.
		local spell = BuffIcon()
		for i, key in ipairs(values) do
			local card = row.cards[i] or BuildCard(row, i)
			card.key = key
			card.selected = now ~= nil and now == key
			-- The pointer may have left while the page was away.
			card.hover = card.hover and card:IsMouseOver() or false
			card.category = ns.Looks.Category(key)
			local title, line = ns.Looks.Card(key)
			card.title:SetText(W.Trim(title))
			card.desc:SetText(W.Trim(line))
			card.isNew = ns.Looks.IsNew(key)
			card.newTag:SetShown(card.isNew)
			-- The picture of the art the prompt draws now: the earlier art's
			-- while Earlier art is on.
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
			DressIcon(card, file and ns.Looks.PreviewIcon(key), spell)
			DressText(card, file and ns.Looks.PreviewText(key))
			Look(card)
			card.inTab = Under(row.tab, key, mine)
			card:SetShown(card.inTab)
		end
		for i = #values + 1, #row.cards do
			row.cards[i].inTab = false
			row.cards[i]:Hide()
		end
		local was = row.count
		row.count = #values
		if was ~= nil and was ~= row.count and was > 0 then W.Relayout(row) end
	end,

	Layout = function(row, width)
		local y = PlaceTabs(row, width)
		for _, head in pairs(row.heads) do head:Hide() end
		-- The cards of the tab in view, in the registry's order.
		local list = {}
		for i = 1, row.count do
			local card = row.cards[i]
			if card.inTab then list[#list + 1] = card end
		end
		local count = #list
		if count == 0 then return y end
		local cols = math.max(1, math.min(MAX_COLUMNS, math.floor((width + GAP) / (MIN_WIDTH + GAP))))
		row.cols = cols
		local base = math.floor((width - (cols - 1) * GAP) / cols)
		local extra = (width - (cols - 1) * GAP) - base * cols
		-- One height for every picture, so the names line up across a row.
		local shotH = math.floor((base - 2 * PAD) / SHOT_RATIO + 0.5)
		-- All under a heading a shelf, each shelf's cards starting a row.
		local heads = row.tab == "all"
		local i = 1
		while i <= count do
			local cat = list[i].category
			if heads and (i == 1 or list[i - 1].category ~= cat) then y = PlaceHead(row, cat, y, width) end
			local last = math.min(count, i + cols - 1)
			while heads and last > i and list[last].category ~= cat do last = last - 1 end
			local x, tallest = 0, 0
			-- Every card of the row, the first few a unit wider where the
			-- width does not divide, so the row runs the whole width.
			local sized = {}
			for k = i, last do
				local card = list[k]
				local w = base + ((k - i) < extra and 1 or 0)
				local inner = w - 2 * PAD
				-- The name leaves room for the tick, and for New where it shows.
				local room = inner - (BADGE + 6) - (card.isNew and math.ceil(card.newTag:GetWidth()) + 6 or 0)
				card.title:SetWidth(math.max(20, room))
				card.desc:SetWidth(inner)
				local titleH = math.ceil(W.TextHeight(card.title))
				local descH = math.ceil(W.TextHeight(card.desc))
				local h = PAD + shotH + TEXT_GAP + math.max(titleH, BADGE - 3) + (descH > 0 and 2 + descH or 0) + PAD
				sized[#sized + 1] = { card = card, w = w, h = h, inner = inner, shotH = shotH, titleH = math.max(titleH, BADGE - 3) }
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
				card.picW, card.picH = s.inner, s.shotH
				PlaceIcon(card)
				PlaceText(card)
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
