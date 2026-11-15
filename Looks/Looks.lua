-- Manners -- the looks the prompt can wear, each in a file of its own.
--
-- The prompt draws three looks itself (glass, framed, minimal), in
-- Prompt/Panel.lua. Every other look lives in Looks/<Name>.lua, listed in the
-- toc after this file and before Prompt/, and registers itself here. Prompt
-- keeps everything the looks share -- the secure button, the text, the queue,
-- the hysteresis, every trigger -- and calls into the active look only where
-- the looks differ.
--
-- THE INTERFACE
--
--   ns.Looks.Register(key, look)   key is the saved `style` value.
--
-- Fields on `look`:
--   name            the dropdown's label, L["Name -- what it is"]. Required.
--   title           the card's name in the options window's picker, L["Glass"].
--                   Optional: without it the card takes what the label says
--                   before its dash.
--   description     the card's one line under the name, L["smoked glass, a rim
--                   lit by the reason"]. Optional: without it the card takes what the
--                   label says after the dash. Give both when a translation
--                   writes the label with a dash the picker cannot split.
--   order           where it sits within its category, after the looks
--                   CATEGORIES places by name (lower comes first).
--   category        "minimal", "classic", "themed" or "class": the picker's
--                   shelf. Optional: CATEGORIES below files the looks by key.
--   fallback        a key to draw as instead, until this look is written. A
--                   look with a fallback needs nothing else.
--   combatArtAlpha  the alpha Prompt gives `art` while the fight holds the
--                   panel (default 0.55). 1 when the look dims its own parts.
--   classSoften     0..1: how far a class-coloured name is taken towards white
--                   (nil: as it is), so it never competes with the reason.
--   classContrast   a look on a light ground of its own (the letter's parchment):
--                   a class-coloured name is taken darker, by Legible against
--                   the ground the look wrote into kit.ink (light false, lo,
--                   hi), until it reads at this contrast (4.5); `classInk`
--                   ({ r, g, b, amount }) first takes it that part of the way
--                   to the look's own ink. `codeContrast` holds every other
--                   colour code in the text to the same figure (the shared
--                   rule is 3:1, taken to 4.5:1 only for a code that must move).
--   subOnDark       true when the reason line sits on a dark ground of the
--                   look's own (Luxe's tag): its colour codes, picked for a
--                   dark ground, are not taken darker for a light panel.
--   inkOnDark       true when every line sits on a dark ground of the look's own,
--                   whatever the panel colour says (Leather's hide): subOnDark
--                   for the name and the list as well.
--   TwoLineHeight(fontSize)  the height two lines need on this look (nil:
--                   Prompt's own). Options states it; ApplyStyle obeys it.
--   AccentCarriers(p)        ring, stripe: which reason marks are on screen
--                   for these settings, for the options page's notice. Nil:
--                   both, which is right for a look that always carries it.
--
-- A look that cuts its icon round whatever "Round the icon off" says goes in
-- Looks.roundAlways (below), so the options page greys that switch out for it;
-- a look that reads the switch stays out of it. hunt38-picker.lua checks the
-- list against what each look draws.
--
-- Methods, called as look:Method(...). Everything a look draws is its own: it
-- makes it in Build, shows it in Apply and hides it in Hide. Prompt hides the
-- built-in looks' regions itself. Only Apply and Hide are required.
--
--   Build(kit)      Once, the first time the look is applied, out of combat.
--                   Keep `kit` (see below); make every region and animation.
--   Apply(p, above) -> textX, chipRoom
--                   ApplyStyle, out of combat. Lay out and colour for the
--                   profile's prompt settings `p`, show what is used, hide what
--                   is not. `above` is whether the list hangs over the panel.
--                   Place the icon and the cooldown, set each list row's width
--                   (fs:SetWidth and kit.fit.room[fs]). Return where the text
--                   starts and the room the lines keep at the right while the
--                   count chip is up.
--   Styled(p, twoLine)  After Prompt set the text's fonts, colours and shadows
--                   (the shared StyleText); adjust them for this look.
--   Hide()          The player picked another look (out of combat). Hide every
--                   region of yours and undo every change to a shared one:
--                   the icon's mask, alpha and desaturation, the cooldown's
--                   swipe, textLayer's level and alpha, any reparented text,
--                   the lines' alpha, and any kit.fit.room it set for the
--                   name or the reason line (the built-in looks set none).
--   PlaceLines(right)  Anchor kit.name and kit.sub (both just cleared). `right`
--                   is the inset at the right; kit.fit.twoLine says whether
--                   the second line is up.
--   Fitted(fs)      A line was just set or refitted (FitLine): size anything
--                   that hugs its text. kit.fit.drawn[fs] is its width when
--                   FitLine measured it at the size it left; measure only
--                   when that is nil, and leave a line that has not changed.
--   PaintReason(r, g, b, reason, mode)  The reason's colour (already the custom
--                   one with "Colour marker by reason" off) and accentMode.
--                   Colour the marks and kit.sub. Skipped when nothing
--                   changed since the last call.
--   Chip(on) -> on  The count chip up or down, kit.count already holding its
--                   text. Return false to refuse it for this paint.
--   Attention(isNew, arrived, flashStyle)  Somebody owed is on top: isNew,
--                   they just got there; arrived, the favour was just done.
--                   Calm (kit.FullEffects() false) must leave nothing looping.
--   StopAttention() Nobody owed on top: every loop the look runs stops.
--   Flourish(kind)  "cast", "sent" or "failed", once, Full effects only and not
--                   in a quiet fight. Prompt shakes the text on "failed" and
--                   settles the panel (a small swell) on "cast". A look draws
--                   its own rings with kit.FX: a landing's spread outward
--                   (fx:Land), a refusal's snaps in (fx:Refuse).
--   StopFlourishes()  A repaint about somebody else: the one-shots stop.
--   PaintOutcome(kind, lead, sub, who, stamp)  Write the outcome: the lines
--                   Prompt would write (lead on the name line, sub below), the
--                   person's name, and the outcome's stamp (one per click).
--                   Use kit.SetLine. Prompt clears the count and repaints the
--                   reason afterwards.
--   ClearOutcome()  The outcome is over, or never was: its wash goes.
--   Combat(on)      The fight holds the panel, or lets it go. Dim, but keep
--                   the reason readable.
--   Painted(entry)  Optional. After every paint of a person (Prompt:Paint),
--                   which is the scan's tick: the queue entry on top, for
--                   anything that follows the clock (Arcane's key). Not
--                   called while the fight holds the panel. No pcall here.
--   Hover(on)       The cursor came onto the panel or left it.
--   PaintQueue(rows, shown, above)  The list's text is written (kit.rows);
--                   rows[i].reason is each row's reason. Place the rows, their
--                   markers and the background. nil rows, 0 shown: hide it.
--                   Each row is a button too (Prompt/Rows.lua), hung off the
--                   row's own font string, so a look that anchors kit.rows[i]
--                   gets a click area on each name with nothing more. Two
--                   optional fields size it: `pitch`, the distance between two
--                   rows' centres (set in Apply; the area is that tall, so
--                   neighbours meet), and `rowReach`, how far left of a row's
--                   text its marker starts (default 18), which the area
--                   includes. The row's icon is the three built-in looks' only.
--
-- THE KIT (Prompt:LookKit(), handed to Build)
--   button art textLayer icon cooldown name sub count rows
--                   the shared regions: button is secure, so never touch it;
--                   cooldown can be nil on a client without the template.
--   fit ink         Prompt's text layout and ground tables (read; room,
--                   flags -- in Styled -- and rowReason may be written).
--   Gradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
--   Legible(r, g, b, minimum) -> r, g, b   held to that contrast on the panel
--   TextWidth(fs)   the line's unbounded width, or nil
--   SetLine(fs, text)  FitLine(fs)
--   FullEffects()   false on Calm
--   FX(parent, level, noEcho) -> fx   the gestures every look shares, on frames
--                   of `parent` (the art), parked at nothing: two rings that
--                   spread when a buff lands (fx:Land(r, g, b, strength)) and
--                   one that contracts onto the icon for a refusal
--                   (fx:Refuse(r, g, b, strength)), and, unless `noEcho`, the
--                   icon's echo (fx:Arrive(file, r, g, b)). fx:Place(icon, pad,
--                   size) puts the rings `pad` units outside the icon, which is
--                   `size` across (their file fills their frame, so pad says
--                   where the ring sits), fx:Shape(round, roundFile, squareFile,
--                   maskFile) gives them the look's own art, fx:SetShown(on) and
--                   fx:Stop() (call it in Hide) the rest; fx.frames lists them.
--                   A look that keeps its icon clean passes noEcho.
--                   THE ROOM: nothing of the icon's light may cover the text or
--                   pass the panel's top and bottom. After Place and Shape, a
--                   look calls fx:Fit(limitH, limitV, kit.SHAKE_LEFT): the
--                   distances from the icon's middle to the text (less
--                   kit.TEXT_MARGIN, and to the card's left edge less
--                   kit.EDGE_MARGIN) and to the top and bottom (less
--                   kit.EDGE_MARGIN), which holds the rings and the echo
--                   inside. The files it draws its rings in are described once
--                   with kit.RingArt(file, peak, edge): where the ring is
--                   brightest and how far out it is seen, as fractions of the
--                   file's half-width (hunt37-effects reads the files and holds
--                   the numbers to them). A ring the look scales itself (a
--                   lock-on) is held with kit.CapLock(closing, settling, from,
--                   mid, kit.CapScale(limit, half, edge)). textLayer rests at
--                   kit.TEXT_LEVEL frames above art, over every frame of light;
--                   Hide puts it back there.
--   Tint(r, g, b, t) -> r, g, b   a colour taken towards white (t up to 1) or
--                   black (down to -1); WARM_WHITE is the second tone of a rim
--   ReasonColor(reason) -> { r, g, b }  the palette's, whatever the marker
--   OUTCOME_SECONDS how long an outcome stays
--
-- Rules every look keeps: no pcall on a per-frame or per-scan path (PaintReason,
-- Fitted, PaintQueue and Chip run on every repaint); no OnUpdate but the one
-- Looks/Flow.lua runs for a look's moving art (textures that scroll, drawn
-- animations played frame by frame), and that only while something moves;
-- nothing done
-- to the secure button; art only from Textures/<Look>/, white or grey so the
-- vertex colour carries every reason, given through Looks.Colour and never
-- SetVertexColor (ONE ALPHA, below); a ground of the look's own stated in
-- kit.ink.lo and kit.ink.hi, as bright as it is drawn under the words; and everything the built-in looks honour
-- still works -- size, font, colours, both palettes, the second line and the
-- chip off, the list above and below, a round icon, Calm, the fight, the
-- outcomes, the preview and the drag.

local _, ns = ...
local L = ns.L

local Looks = { list = {} }
ns.Looks = Looks

-- Loaded next: Looks/Flow.lua (ns.Looks.Flow), the clock for art that moves by
-- its texture coordinates.

---------------------------------------------------------------------------
-- ONE ALPHA
--
-- The game keeps one alpha for a texture. SetVertexColor(r, g, b, a) writes
-- over what SetAlpha set, an alpha left out is documented as 1, and an Alpha
-- animation plays over the same number. So a light dimmed with SetAlpha and
-- coloured afterwards stands at full strength in the game and nowhere else:
-- 1.11.19's Glass covered its pane with a grey marble that way (GitHub issue
-- 15). Every look colours its art through Looks.Colour, which never lets a
-- colour move a texture's transparency:
--
--   Looks.Colour(t, r, g, b)         the colour, at the alpha the texture rests at
--   Looks.Colour(t, r, g, b, alpha)  the colour and its own alpha, together
--   Looks.Dim(t, by)                 a dim over its own alpha (a fight's): the
--                                    two are multiplied here, since the client
--                                    keeps one number and the last call wins
--   Looks.Hold(t)                    write down what t rests at, from now on
--
-- The resting alpha is the last one the look itself gave (SetAlpha, or
-- Colour's fifth number), kept in t.restAlpha: Hold reads the texture once and
-- from then on hears every SetAlpha. It is never read back from the texture
-- at the moment of colouring, because GetAlpha in the middle of a flash may
-- answer the flash's passing value, and a colour given then would leave the
-- light lit for good. A look holds all its art at the end of Build
-- (Looks.HoldAll), while nothing plays; a texture nobody held is held at its
-- first colour. The shared icon (kit.icon) is every look's and stays on
-- SetVertexColor: it stands at full alpha wherever a look colours it, and a
-- hold left on it would be one look's mark on the next. A light's strength is
-- its animation's alpha, never an alpha given with its colour.
-- tests/scenarios/looks-alpha.lua takes every look through its states on a
-- mock that keeps one alpha as the game does.
---------------------------------------------------------------------------

-- The look's own SetAlpha: the number it gives is the texture's own alpha
-- from now on, with no dim over it.
local function Tracked(self, alpha)
	self.restAlpha, self.ownAlpha, self.dimBy = alpha, nil, nil
	return self:rawSetAlpha(alpha)
end

function Looks.Hold(t)
	if t.restAlpha == nil then
		t.restAlpha = t:GetAlpha() or 1
		t.rawSetAlpha = t.SetAlpha
		t.SetAlpha = Tracked
	end
	return t
end

-- Everything in a look's list that takes a colour.
function Looks.HoldAll(list)
	for _, t in ipairs(list) do
		if type(t.SetVertexColor) == "function" and type(t.GetAlpha) == "function" and type(t.SetAlpha) == "function" then
			Looks.Hold(t)
		end
	end
end

function Looks.Colour(t, r, g, b, alpha)
	if t.restAlpha == nil then Looks.Hold(t) end
	if alpha ~= nil then
		t.ownAlpha = alpha
		t.restAlpha = alpha * (t.dimBy or 1)
	end
	t:SetVertexColor(r, g, b)
	t:rawSetAlpha(t.restAlpha)
end

function Looks.Dim(t, by)
	if t.restAlpha == nil then Looks.Hold(t) end
	if t.ownAlpha == nil then t.ownAlpha = t.restAlpha end
	t.dimBy = by
	t.restAlpha = t.ownAlpha * by
	t:rawSetAlpha(t.restAlpha)
end

-- The three Prompt/Panel.lua draws, named here so the dropdown is one list.
-- They are never handed back by Get.
local NATIVE = {
	glass = { name = L["Glass -- dark glass in gilt rails, the game's own action bar"], order = 10, native = true,
		title = L["Glass"], description = L["dark glass in gilt rails, the game's own action bar"] },
	framed = { name = L["Framed -- dark panel, a tooltip's rim"], order = 11, native = true,
		title = L["Framed"], description = L["dark panel, a tooltip's rim"] },
	minimal = { name = L["Minimal -- text only, no panel"], order = 12, native = true,
		title = L["Minimal"], description = L["text only, no panel"] },
}
-- THE CATEGORIES the picker sorts the looks into, in its order, each with
-- its heading; and, per category, the looks in the order the picker shows them
-- (a look named nowhere goes after these, by its `order`). A look's own
-- `category` wins; one with none takes it from CATEGORY here, so a look of
-- its own Lua needs no line for it. tests/scenarios/painted.lua holds every
-- look to exactly one.
Looks.CATEGORIES = { "minimal", "classic", "themed", "class" }
Looks.CATEGORY_TITLE = { minimal = L["Minimal"], classic = L["Classic"], themed = L["Themed"], class = L["Class"] }
local SHELVES = {
	minimal = { "minimal", "ghost", "hairline", "pill", "slate", "luxe" },
	classic = { "glass", "framed", "toast", "arcane" },
	themed = { "ribbon", "letter", "warchief", "gearworks" },
	class = { "frost", "archmage", "firemage", "fel", "wild", "lightbringer", "stormcaller", "ebon", "leather",
		"forge", "priest", "rogue", "monk", "demonhunter", "evoker" },
}
local CATEGORY, SHELF, RANK = {}, {}, {}
for i, cat in ipairs(Looks.CATEGORIES) do
	RANK[cat] = i
	for at, key in ipairs(SHELVES[cat]) do CATEGORY[key], SHELF[key] = cat, at end
end

for key, look in pairs(NATIVE) do
	look.key = key
	look.category = CATEGORY[key]
	Looks.list[key] = look
end

function Looks.Register(key, look)
	look.key = key
	look.category = look.category or CATEGORY[key]
	Looks.list[key] = look
	return look
end

-- The look to draw for a style, or nil for one Prompt/Panel.lua draws (and for
-- a key nobody registered). A fallback is followed once.
function Looks.Get(key)
	local look = key and Looks.list[key]
	if look and look.fallback then look = Looks.list[look.fallback] end
	if not look or look.native then return nil end
	return look
end

-- The looks that cut their icon round whatever "Round the icon off" says (a
-- medallion, a seal): the switch reads nothing there, so the options page greys
-- it out for them (tests/scenarios/hunt38-picker.lua holds this list to what the
-- looks draw). A look that reads the setting is not here.
Looks.roundAlways = { toast = true, ribbon = true, letter = true, archmage = true, lightbringer = true, fel = true, wild = true, frost = true, warchief = true, gearworks = true, ebon = true }

-- A DRESSING: more art over one of the three looks Prompt/Panel.lua draws
-- (Looks/Glass.lua, over the glass). Panel.lua lays its own look out as ever
-- and then calls the dressing where it would call a look: Build(kit) once,
-- Apply(p, above), Hide(), PaintReason, Attention, StopAttention, Flourish,
-- StopFlourishes, Combat and Painted, each as the interface above describes
-- it. It owns nothing of the panel's own: it adds, and takes away what it added.
Looks.dress = {}
function Looks.RegisterDress(key, dress)
	dress.key = key
	Looks.dress[key] = dress
	return dress
end

function Looks.Dress(key)
	return key and Looks.dress[key] or nil
end

-- Whether the style's look is round whatever the switch says.
function Looks.RoundAlways(key)
	local look = Looks.Get(key)
	return look ~= nil and Looks.roundAlways[look.key] == true
end

-- Show my key on the prompt (prompt.keycap): whether a look shows the key
-- bound to the prompt, on its painted keycap or its own key tag. "show" and
-- "hide" are the player's, on every look; "look" is the look's own default:
-- a painted look's from its data (Looks/PaintedData.lua's keycap.shown: shown
-- on the class and themed looks, not on the calmer ones), and under Earlier
-- art, or for a look with no painting, what the look always did. With no key
-- bound the look shows nothing whatever this says (its KeyLabel).
function Looks.KeyWanted(look)
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	local choice = p and p.keycap
	if choice == "show" then return true end
	if choice == "hide" then return false end
	local art = look and look.paintedArt
	if art and art.on then return art.data.keycap.shown ~= false end
	return true
end

-- The key bound to the prompt, or nil: the client's own name for it.
Looks.COMMAND = "CLICK MannersPrompt:LeftButton"
function Looks.BoundKey()
	if type(GetBindingKey) ~= "function" then return nil end
	local key = GetBindingKey(Looks.COMMAND)
	if type(key) ~= "string" or key == "" then return nil end
	return key
end

-- The words on a look's key chip for a key bound to the prompt, in the
-- client's own short form (what its action bars print: "s-F", a gamepad
-- button as its glyph, an inline atlas the chip measures as it draws it), or
-- nil where the client gives none. A gamepad button held with a modifier
-- reads as the buttons the player presses: the game turns a held left
-- trigger into Shift by default (CVars GamePadEmulateShift, ...Ctrl, ...Alt),
-- so "SHIFT-PAD1" is the trigger glyph, "+" and the face button's, not "s-"
-- and a glyph. Worked out once and kept (the chip asks at every repaint) until
-- the key, the client's own words for it or the CVars change; a CVar that
-- cannot be read leaves the client's own short form.
do
	local EMULATE = { SHIFT = "GamePadEmulateShift", CTRL = "GamePadEmulateCtrl", ALT = "GamePadEmulateAlt" }
	local comboKey, comboMade, comboText

	local function Glyph(key)
		local text = GetBindingText(key, true)
		if type(text) == "string" and text ~= "" then return text end
	end

	-- nil unless every modifier on the key is a pad button the game emulates.
	local function PadCombo(key)
		local rest, held = key, {}
		while true do
			local mod, tail = rest:match("^(%u+)%-(.+)$")
			if not (mod and EMULATE[mod]) then break end
			held[#held + 1], rest = mod, tail
		end
		if #held == 0 or not rest:match("^PAD") then return nil end
		local get = _G.GetCVar or (_G.C_CVar and _G.C_CVar.GetCVar)
		local parts = {}
		for _, mod in ipairs(held) do
			local button = ns.safecall(get, EMULATE[mod])
			if type(button) ~= "string" or not button:match("^PAD") then return nil end
			parts[#parts + 1] = Glyph(button)
		end
		parts[#parts + 1] = Glyph(rest)
		-- A button the client has no glyph for leaves the client's own form.
		for i = 1, #held + 1 do if not parts[i] then return nil end end
		return table.concat(parts, "+")
	end

	-- What the combination was worked out from besides the key: the three
	-- CVars, which a player can change in a session. Read straight (they
	-- exist on every client; a missing one answers nothing), as often as the
	-- chip asks, which is only for a pad button with a modifier.
	local function Settings()
		local get = _G.GetCVar or (_G.C_CVar and _G.C_CVar.GetCVar)
		if type(get) ~= "function" then return "" end
		return tostring(get(EMULATE.SHIFT)) .. "" .. tostring(get(EMULATE.CTRL)) .. "" .. tostring(get(EMULATE.ALT))
	end

	function Looks.ShortKey(key)
		if type(GetBindingText) ~= "function" or type(key) ~= "string" then return nil end
		local own = Glyph(key)
		if key:find("PAD", 1, true) and key:find("-", 1, true) then
			-- Kept for as long as the key, the client's own words for it (its
			-- glyphs change when a controller of another family is told apart)
			-- and the CVars stay what they were.
			local made = tostring(own) .. "" .. Settings()
			if key ~= comboKey or made ~= comboMade then comboKey, comboMade, comboText = key, made, PadCombo(key) or false end
			if comboText then return comboText end
		end
		return own
	end
end

-- Every style key that may be saved, for ClampSettings.
function Looks.Allowed()
	local out = {}
	for key in pairs(Looks.list) do out[key] = true end
	return out
end

-- A look's category: its own, else the one CATEGORIES files it under, else
-- themed (a look nobody filed is still on a shelf).
function Looks.Category(key)
	local look = Looks.list[key]
	local cat = look and look.category or CATEGORY[key]
	if RANK[cat] then return cat end
	return "themed"
end

-- Every look for the dropdown, one flat list, sorted by category and then
-- within it (the picker's shelves, then `order`), each by its label.
function Looks.Choices()
	local values, sorting = {}, {}
	for key, look in pairs(Looks.list) do
		values[key] = look.name
		sorting[#sorting + 1] = key
	end
	table.sort(sorting, function(a, b)
		local ca, cb = RANK[Looks.Category(a)], RANK[Looks.Category(b)]
		if ca ~= cb then return ca < cb end
		local sa, sb = SHELF[a] or 100, SHELF[b] or 100
		if sa ~= sb then return sa < sb end
		local oa, ob = Looks.list[a].order or 50, Looks.list[b].order or 50
		if oa ~= ob then return oa < ob end
		return a < b
	end)
	return values, sorting
end

-- What the label says either side of its dash: English writes " -- ", the
-- translations an en dash, an em dash, a pair of them without spaces (Chinese),
-- or nothing at all (the label is then the name alone).
local DASHES = { " -- ", " \226\128\147 ", " \226\128\148 ", "\226\128\148\226\128\148" }

local function SplitLabel(label)
	label = type(label) == "string" and label or ""
	for _, dash in ipairs(DASHES) do
		local at = label:find(dash, 1, true)
		if at then return label:sub(1, at - 1), label:sub(at + #dash) end
	end
	return label, ""
end

-- The card a look has in the options window's picker: its name and its one
-- line, from the look's own fields or else from its label.
function Looks.Card(key)
	local look = Looks.list[key]
	if not look then return tostring(key), "" end
	local title, line = SplitLabel(look.name)
	return look.title or title, look.description or line
end

-- Pictures of the looks for the picker's cards: Textures/Previews/Preview_<key>.tga,
-- drawn by tools/make_look_previews.py, which also writes Looks/Previews.lua (the
-- toc loads it after this file) to say which looks it drew. A look it has not
-- drawn yet has a card without a picture.
Looks.previews = {}
-- Where a look's picture holds its spell icon (a tile, drawn because the tool has
-- no game art): { l, t, r, b } as fractions of the picture from its top left,
-- `round` with the `mask` file that look cuts its icon with, and the `crop`
-- (SetTexCoord's four numbers). The picker lays the real icon there, drawn live.
Looks.previewIcon = {}
-- Where a look's picture holds its name and its reason line, and how each is
-- written: { name = line, reason = line }, a line being the rectangle as
-- fractions of the picture like the icon's, `h` and `v` its justification,
-- `size` and the shadow's `x` and `y` fractions of the picture's height, `color`,
-- `flags`, and the look's own `font` (`latin`: only on a client whose alphabet it
-- has). A reason line the look sets in a tag of its own (Luxe) carries the tag
-- as `pill`: its edges `t` and `b`, how far it reaches past the words (`lead`,
-- `tail`), its caps' width of its height (`cap`), and its `layers`, each the
-- look's own `file` as a three-slice in the look's `color`. The pictures carry
-- none of this text, nor the tag: the picker writes the words there live, in the
-- player's language, and draws the tag round them as wide as they are.
Looks.previewText = {}

function Looks.PreviewFile(key)
	if not Looks.previews[key] then return nil end
	return "Interface\\AddOns\\Manners\\Textures\\Previews\\Preview_" .. key
end

-- The icon's place in a look's picture, or nil for a look without one.
function Looks.PreviewIcon(key)
	if not Looks.previews[key] then return nil end
	return Looks.previewIcon[key]
end

-- The two lines a look's card writes over its picture, or nil for a look without
-- a picture.
function Looks.PreviewText(key)
	if not Looks.previews[key] then return nil end
	return Looks.previewText[key]
end
