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
--   order           where it sits in the dropdown (glass 10, framed 11,
--                   minimal 12; lower comes first).
--   fallback        a key to draw as instead, until this look is written. A
--                   look with a fallback needs nothing else.
--   combatArtAlpha  the alpha Prompt gives `art` while the fight holds the
--                   panel (default 0.55). 1 when the look dims its own parts.
--   classSoften     0..1: how far a class-coloured name is taken towards white
--                   (nil: as it is), so it never competes with the reason.
--   subOnDark       true when the reason line sits on a dark ground of the
--                   look's own (Luxe's tag): its colour codes, picked for a
--                   dark ground, are not taken darker for a light panel.
--   TwoLineHeight(fontSize)  the height two lines need on this look (nil:
--                   Prompt's own). Options states it; ApplyStyle obeys it.
--   AccentCarriers(p)        ring, stripe: which reason marks are on screen
--                   for these settings, for the options page's notice. Nil:
--                   both, which is right for a look that always carries it.
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
--                   in a quiet fight. Prompt shakes the text on "failed".
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
--   ReasonColor(reason) -> { r, g, b }  the palette's, whatever the marker
--   OUTCOME_SECONDS how long an outcome stays
--
-- Rules every look keeps: no pcall on a per-frame or per-scan path (PaintReason,
-- Fitted, PaintQueue and Chip run on every repaint); no OnUpdate; nothing done
-- to the secure button; art only from Textures/<Look>/, white or grey so the
-- vertex colour carries every reason; and everything the built-in looks honour
-- still works -- size, font, colours, both palettes, the second line and the
-- chip off, the list above and below, a round icon, Calm, the fight, the
-- outcomes, the preview and the drag.

local _, ns = ...
local L = ns.L

local Looks = { list = {} }
ns.Looks = Looks

-- The three Prompt/Panel.lua draws, named here so the dropdown is one list.
-- They are never handed back by Get.
local NATIVE = {
	glass = { name = L["Glass -- dark panel, soft shadow"], order = 10, native = true },
	framed = { name = L["Framed -- flat panel, thin border"], order = 11, native = true },
	minimal = { name = L["Minimal -- text only, no panel"], order = 12, native = true },
}
for key, look in pairs(NATIVE) do
	look.key = key
	Looks.list[key] = look
end

function Looks.Register(key, look)
	look.key = key
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

-- Every style key that may be saved, for ClampSettings.
function Looks.Allowed()
	local out = {}
	for key in pairs(Looks.list) do out[key] = true end
	return out
end

function Looks.Choices()
	local values, sorting = {}, {}
	for key, look in pairs(Looks.list) do
		values[key] = look.name
		sorting[#sorting + 1] = key
	end
	table.sort(sorting, function(a, b)
		local oa, ob = Looks.list[a].order or 50, Looks.list[b].order or 50
		if oa ~= ob then return oa < ob end
		return a < b
	end)
	return values, sorting
end
