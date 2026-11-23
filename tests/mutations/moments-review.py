# Mutations for the review of the cards for the moment:
# tests/scenarios/moments-review.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one fix back to its
# absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
CARD = "Prompt/MomentsCard.lua"
SENSE = "Prompt/MomentsSense.lua"
PANEL = "Prompt/Panel.lua"
CORE = "Core.lua"

# A look of Looks/ tells the cards how far its painting hangs and its list reaches.
mutate(PANEL,
       '\t\tS.artAbove, S.artBelow = math.ceil(math.max(0, -g.y0)), math.ceil(math.max(0, g.y1 - p.height))\n',
       '',
       "moments-review: a look of Looks/ says nothing of the painting it hangs over the bar",
       expect="moments-review: frost at height", script=S)

mutate(PANEL,
       '\tif type(look.listGap) == "number" and look.listGap > 0 then S.queueGap = math.ceil(look.listGap) end\n',
       '',
       "moments-review: a look of Looks/ says nothing of how far it pushes its list off the bar",
       expect="moments-review: lightbringer at height 44, the list above", script=S)

# The held-dark line does not take the lit line's place on the trail.
mutate(M,
       '\t\t\t\t\ttostring(slot.onGCD)), true)\n',
       '\t\t\t\t\ttostring(slot.onGCD)))\n',
       "moments-review: the held-dark line takes the trail's gap from the lit line",
       expect="moments-review: a Blink held dark and lit", script=S)

# A card takes clicks over its icon alone.
mutate(CARD,
       '\t\tbutton:SetHitRectInsets(x0, w - x1, y0, h - y1)\n',
       '\t\tbutton:SetHitRectInsets(0, 0, 0, 0)\n',
       "moments-review: the button takes clicks over the whole card",
       expect="moments-review: frost: the button and its cover take clicks over the icon alone", script=S)

mutate(CARD,
       '\t\tcover:SetPoint("TOPLEFT", button, "TOPLEFT", x0, -y0)\n\t\tcover:SetPoint("BOTTOMRIGHT", button, "TOPLEFT", x1, -y1)\n',
       '\t\tcover:SetAllPoints(button)\n',
       "moments-review: the cover stands over the whole card",
       expect="moments-review: glass: the button and its cover take clicks over the icon alone", script=S)

# A card is the size of the prompt in the look, 100 by default, 80 at the least.
mutate(M,
       '\tlocal h = math.floor(ns.Looks.PreviewView(p.style or "glass") * percent / 100 * scale + 0.5)\n',
       '\tlocal h = math.floor(62 * percent / 100 * scale + 0.5)\n',
       "moments-review: every look's card is cut to the standard view's height",
       expect="moments-review: frost: at 100 the card's icon is the size of the prompt's own", script=S)

mutate(CORE,
       'health = 20, mana = 20, cardSize = 100 }',
       'health = 20, mana = 20, cardSize = 80 }',
       "moments-review: the default card is 80 percent of the prompt",
       expect="moments-review: frost: at 100 the card's icon is the size of the prompt's own", script=S)

mutate("Options/Look.lua",
       '\t\tmin = 80, max = 150, step = 10,\n',
       '\t\tmin = 60, max = 150, step = 10,\n',
       "moments-review: the slider lets a card be 60 percent",
       expect="moments-review: the card size runs from 80 to 150", script=S)

# A ward says "just hit you" only for a recent hit.
mutate(SENSE,
       '\tslot.wardRoute = (verdict == "yes" and recent == true) and "hit" or "cast"\n',
       '\tslot.wardRoute = verdict == "yes" and "hit" or "cast"\n',
       "moments-review: a ward lit by the guess says a hit of forty seconds ago just landed",
       expect="moments-review: an old fire hit and a target casting", script=S)

# The reason follows the facts while a card stays lit.
mutate(M,
       '\tif state ~= "dark" then Card.ShowReason(slot, state) end\n',
       '',
       "moments-review: a card that stays lit keeps the words it lit with",
       expect="moments-review: Blink lit by a root and then a stun", script=S)
