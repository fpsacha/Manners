-- Manners -- the card a button for the moment is drawn as (Prompt/Moments.lua
-- makes the buttons and says what each waits for). A lit button is a small
-- prompt in the player's own look: the look's picture (the one the Look page's
-- picker shows, Textures/Previews/Preview_<key>.tga, made from the look's own art
-- by tools/make_look_previews.py) with three things written live over it in the
-- look's recorded fonts and colours (Looks/CardArt.lua): the spell's icon, its
-- name and a short reason line ("you are stunned", "your target is casting").
-- Nothing is drawn in code.
--
-- A look keeps its regions on the one secure prompt, so the card cannot be a live
-- second copy of the prompt: it is the look's picture, and the look's own moving
-- art is not on it. Its motion is a pulse of an ADD copy of that same picture.
--
-- THE FRAMES (built by Moments.lua's Create, the regions here), over the secure
-- button, which has no region of its own and whose alpha is never written:
--   face   a plain gate, alpha 0 at rest, Lua's own
--   hint   on face, dim (alpha 0.4), under inner: the dim card Lua shows where the
--          game has painted inner away (the first of two clicks: picture, icon and
--          name; the drink out of a fight: its icon alone)
--   inner  on face. THE GAME paints its alpha from a hidden value. The lit card
--          (CardArt on it), the flare and the hover are regions of it, and the key
--          label; so every card region the game decides about is on inner
--   mark   on face above inner, Lua's own: the ring of the first of two clicks and
--          the PREVIEW tag, which the game never paints away
--
-- WHAT LUA MAY DO IN A FIGHT: show and hide hint, ring, flare, hover and tag, play
-- and stop the flare's animation, write the reason's text (no refit) and set the
-- alpha of face and inner. Everything that changes a texture, a font or a point
-- (Dress, SetIcon) is for out of a fight, from Refresh and Place.
--
-- The hidden-value rule: nothing here is ever handed a hidden value. The reason
-- comes from plain facts only; where only the game knows, the line is a general
-- one ("low health").

local _, ns = ...
local L = ns.L
local Looks = ns.Looks
local CardArt = Looks.CardArt
local InCombatLockdown = _G.InCombatLockdown

local Card = {}
ns.MomentCard = Card

local RING = "Interface\\AddOns\\Manners\\Textures\\Ring"
local RING_SQUARE = "Interface\\AddOns\\Manners\\Textures\\RingSq"
-- A look with no picture of its own wears the one of a look that is always drawn.
local FALLBACK_LOOK = "framed"
-- The pictures are 256 x 64; a card's size is its height, and its width four times it.
Card.RATIO = 4
local STEADY = 0.35

---------------------------------------------------------------------------
-- the words
---------------------------------------------------------------------------

local function Pair(lit, game) return { lit = lit, game = game or lit } end

-- What the ward says by the route that lit it (Sense.schoolhit sets wardRoute).
local function Ward(slot, cast, hit)
	if slot.wardRoute == "hit" then return Pair(hit) end
	return Pair(cast)
end

-- The reasons of a row, plain facts only: `lit` where Lua knows the need, `game`
-- where only the game does. One table of every variant per row (the longest
-- fits the line at Dress), and Reason picks the one that is true now.
local function Words(slot)
	local key = slot.row.key
	if key == "counterspell" then return Pair(L["your target is casting"]) end
	if key == "spellsteal" then return Pair(L["your target has a buff to steal"]) end
	if key == "blink" then
		local kind = slot.lossKind
		if kind == "STUN" or kind == "STUN_MECHANIC" then return Pair(L["you are stunned"]) end
		if kind == "ROOT" then return Pair(L["you are rooted"]) end
		return Pair(L["you lost control"])
	end
	if key == "iceblock" then return Pair(L["your health is low"], L["low health"]) end
	if key == "coldsnap" then
		local name = ns.Moments.NameOf("iceblock") or slot.name or ""
		return Pair(L["brings back %s"]:format(name))
	end
	if key == "evocation" or key == "managem" or key == "drink" then
		return Pair(L["your mana is low"], L["low mana"])
	end
	if key == "slowfall" then return Pair(L["you are falling"]) end
	if key == "fireward" then return Ward(slot, L["your target casts fire"], L["fire just hit you"]) end
	if key == "frostward" then return Ward(slot, L["your target casts frost"], L["frost just hit you"]) end
	return Pair(slot.name or "")
end

-- The words for a state: "lit" and "game" (or the slot's own state).
function Card.Reason(slot, state)
	local words = Words(slot)
	if (state or slot.state) == "game" then return words.game end
	return words.lit
end

-- Every variant a row may say, for the fit: the longest of them decides the size
-- and the tag's width, so no variant is wider than the room it was fitted to.
local function Longest(slot)
	local key = slot.row.key
	local list
	if key == "blink" then
		list = { L["you are stunned"], L["you are rooted"], L["you lost control"] }
	elseif key == "fireward" then
		list = { L["your target casts fire"], L["fire just hit you"] }
	elseif key == "frostward" then
		list = { L["your target casts frost"], L["frost just hit you"] }
	elseif key == "iceblock" then
		list = { L["your health is low"], L["low health"] }
	elseif key == "evocation" or key == "managem" or key == "drink" then
		list = { L["your mana is low"], L["low mana"] }
	else
		list = { Card.Reason(slot, "lit") }
	end
	local best = list[1]
	for _, text in ipairs(list) do
		if #text > #best then best = text end
	end
	return best
end

-- The reason written on the card for a state. In a fight this is a SetText on a
-- font string and nothing else, and only when the words differ.
function Card.ShowReason(slot, state)
	local text = Card.Reason(slot, state)
	if text ~= slot.reasonText then
		slot.reasonText = text
		slot.card.lines.reason:SetText(text)
	end
end

---------------------------------------------------------------------------
-- building: regions on the frames Moments.lua made
---------------------------------------------------------------------------

-- The colours the look records for its lines and its tag, put on the live regions.
local function Tint(card)
	for _, name in ipairs(card.names) do
		local fs, spec = card.lines[name], card.textAt and card.textAt[name]
		if fs and spec then
			local c = spec.color
			fs:SetTextColor(c[1], c[2], c[3], c[4])
		end
	end
	local pill = card.pillSpec
	for i, slices in ipairs(card.pill) do
		local layer = pill and pill.layers[i]
		if layer then
			local c = layer.color
			for _, t in ipairs(slices) do t:SetVertexColor(c[1], c[2], c[3], c[4]) end
		end
	end
end

function Card.Build(slot)
	local inner, hint, mark = slot.inner, slot.hint, slot.mark
	slot.card = CardArt.New(inner, { "name", "reason" })
	slot.card.onPill = Tint
	slot.hintCard = CardArt.New(hint, { "name" })
	slot.hintCard.onPill = Tint
	-- The pulse: an ADD copy of the picture, over the card.
	local flare = inner:CreateTexture(nil, "OVERLAY", nil, 1)
	flare:SetBlendMode("ADD")
	flare:SetAllPoints(inner)
	flare:Hide()
	local pulse = flare:CreateAnimationGroup()
	if type(pulse.SetLooping) == "function" then pulse:SetLooping("BOUNCE") end
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.6)
	fade:SetToAlpha(0.1)
	fade:SetDuration(0.45)
	-- The same picture, a little lit, under the pointer.
	local hover = inner:CreateTexture(nil, "OVERLAY", nil, 2)
	hover:SetBlendMode("ADD")
	hover:SetAllPoints(inner)
	hover:SetAlpha(0.25)
	hover:Hide()
	local keyText = inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keyText:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -4, 3)
	keyText:SetText("")
	-- Lua's own layer: the prompt's own light round the icon (the first click of two)
	-- and the mark of a preview.
	local ring = mark:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(RING_SQUARE)
	ring:SetAllPoints(mark)
	ring:SetVertexColor(1, 0.82, 0.2, 0.95)
	ring:Hide()
	local tag = mark:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	tag:SetPoint("TOPRIGHT", mark, "TOPRIGHT", -4, -3)
	tag:SetText(L["PREVIEW"])
	tag:Hide()
	slot.flare, slot.pulse, slot.hover, slot.keyText, slot.ring, slot.tag = flare, pulse, hover, keyText, ring, tag
	slot.glow = flare
end

---------------------------------------------------------------------------
-- dressing: out of a fight only
---------------------------------------------------------------------------

-- A change of the spell's icon (the drink's best drink, a gem): on every
-- region that wears it.
function Card.SetIcon(slot, file)
	slot.iconFile = file
	for _, card in ipairs({ slot.card, slot.hintCard }) do
		if card and card.at then
			card.iconFile = file
			card.icon:SetTexture(file)
		end
	end
end

-- What a card's dressing was made from, so a repaint with nothing changed does
-- nothing: the look's picture, the size, the font and the words.
function Card.Signature(slot, key, w, h)
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	local file = Looks.PreviewFile(key) or Looks.PreviewFile(FALLBACK_LOOK)
	return table.concat({ tostring(key), tostring(file), w, h, tostring(p and p.font), tostring(slot.name),
		tostring(slot.row and slot.row.key), tostring(ns.LOCALE) }, ":")
end

-- The card for a look at a size (w x h, four to one): the look's picture, the
-- icon at the look's icon rectangle and the name and reason in the look's own
-- lines. A look with no picture wears framed's.
function Card.Dress(slot, key, w, h)
	if InCombatLockdown() then return end
	local file, at, textAt = Looks.PreviewFile(key), Looks.PreviewIcon(key), Looks.PreviewText(key)
	slot.picture = "own"
	if not file then
		file, at, textAt = Looks.PreviewFile(FALLBACK_LOOK), Looks.PreviewIcon(FALLBACK_LOOK), Looks.PreviewText(FALLBACK_LOOK)
		slot.picture = "framed's"
	end
	slot.cardW, slot.cardH, slot.cardLook = w, h, key
	local words = Longest(slot)
	CardArt.Dress(slot.card, file, at, textAt, slot.iconFile, { name = slot.name, reason = words }, w, h)
	CardArt.Dress(slot.hintCard, file, at, textAt, slot.iconFile, { name = slot.name }, w, h)
	slot.reasonText = words
	Tint(slot.card)
	Tint(slot.hintCard)
	slot.flare:SetTexture(file)
	slot.hover:SetTexture(file)
	local k = h / 50
	slot.keyText:ClearAllPoints()
	slot.keyText:SetPoint("BOTTOMRIGHT", slot.inner, "BOTTOMRIGHT", -4 * k, 3 * k)
	-- The ring round the icon's rectangle, three units (of fifty) outside it.
	local ring, mark = slot.ring, slot.mark
	ring:ClearAllPoints()
	if at then
		local out = 3 * k
		ring:SetTexture(at.round and RING or RING_SQUARE)
		ring:SetPoint("TOPLEFT", mark, "TOPLEFT", at.l * w - out, -at.t * h + out)
		ring:SetPoint("BOTTOMRIGHT", mark, "TOPLEFT", at.r * w + out, -at.b * h - out)
	else
		ring:SetTexture(RING_SQUARE)
		ring:SetAllPoints(mark)
	end
	-- The mouse takes the icon's rectangle (with the ring's room round it) and no more:
	-- a card is dark and invisible through most of a fight, and a block of cards over
	-- the world would swallow every click meant for it. The button's hit area and the
	-- cover that stands over it shrink together; the rest of the card reaches the world.
	-- A key bound for the button takes the mouse off it altogether.
	local button, cover = slot.button, slot.cover
	cover:ClearAllPoints()
	if at then
		local out = 3 * k
		local x0, y0 = math.max(0, at.l * w - out), math.max(0, at.t * h - out)
		local x1, y1 = math.min(w, at.r * w + out), math.min(h, at.b * h + out)
		button:SetHitRectInsets(x0, w - x1, y0, h - y1)
		cover:SetPoint("TOPLEFT", button, "TOPLEFT", x0, -y0)
		cover:SetPoint("BOTTOMRIGHT", button, "TOPLEFT", x1, -y1)
	else
		button:SetHitRectInsets(0, 0, 0, 0)
		cover:SetAllPoints(button)
	end
end

---------------------------------------------------------------------------
-- what Lua may show in a fight
---------------------------------------------------------------------------

-- The dim card on the hint frame: "full" the first of two clicks (the picture, the
-- icon and the name), "icon" the drink out of a fight while only the game knows
-- (the icon alone, at its spot), nil hidden.
function Card.Hint(slot, mode)
	local hint, card = slot.hint, slot.hintCard
	if not mode then
		hint:Hide()
		return
	end
	local full = mode == "full"
	-- A look whose picture records no icon has nothing else to show of a dim card.
	card.shot:SetShown(full or not card.at)
	card.lines.name:SetShown(full and card.lineSize.name ~= nil)
	hint:Show()
end

function Card.Ring(slot, on)
	slot.ring:SetShown(on and true or false)
end

function Card.Tag(slot, on)
	slot.tag:SetShown(on and true or false)
end

-- Calm effects, or a quiet fight, keep the flare steady: nothing loops.
local function Steady()
	local lib = ns.Prompt and ns.Prompt.lib
	if lib and lib.FullEffects and not lib.FullEffects() then return true end
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	return p ~= nil and p.hideInCombat == true and (ns.Sense.fighting or InCombatLockdown()) and true or false
end

-- The flare's breath while a card is lit or left to the game; stopped and hidden
-- when it goes dark.
function Card.Pulse(slot, on)
	local flare, pulse = slot.flare, slot.pulse
	if not on then
		pulse:Stop()
		flare:Hide()
		return
	end
	flare:Show()
	if Steady() then
		pulse:Stop()
		flare:SetAlpha(STEADY)
	elseif not pulse:IsPlaying() then
		pulse:Play()
	end
end
