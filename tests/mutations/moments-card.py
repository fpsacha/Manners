# Mutations for the cards the buttons for the moment are drawn as:
# tests/scenarios/moments-card.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
CARD = "Prompt/MomentsCard.lua"
ART = "Looks/CardArt.lua"

mutate(CARD,
       '\tif (state or slot.state) == "game" then return words.game end\n\treturn words.lit\n',
       '\tif (state or slot.state) == "game" then return words.lit end\n\treturn words.game\n',
       "moments-card: the game's reason and the plain one are swapped",
       expect="moments-card: hidden health", script=S)

mutate(CARD,
       '\tlocal full = mode == "full"\n',
       '\tlocal full = false\n',
       "moments-card: the first of two clicks shows no dim card",
       expect="moments-card: hidden health", script=S)

mutate(CARD,
       '\tslot.picture = "own"\n\tif not file then\n',
       '\tslot.picture = "own"\n\tif true then\n',
       "moments-card: every card wears framed's picture",
       expect="moments-card: a look with no picture wears framed's", script=S)

mutate(CARD,
       '\tif InCombatLockdown() then return end\n\tlocal file, at, textAt = ',
       '\tlocal file, at, textAt = ',
       "moments-card: a card is dressed in a fight",
       expect="moments-card: a look changed in a fight is dressed only after it", script=S)

mutate(CARD,
       '\tif lib and lib.FullEffects and not lib.FullEffects() then return true end\n',
       '',
       "moments-card: the flare loops under Calm effects",
       expect="moments-card: Calm effects and a quiet fight leave nothing looping", script=S)

mutate(CARD,
       '\treturn p ~= nil and p.hideInCombat == true and (ns.Sense.fighting or InCombatLockdown()) and true or false\n',
       '\treturn false\n',
       "moments-card: the flare loops in a quiet fight",
       expect="moments-card: Calm effects and a quiet fight leave nothing looping", script=S)

mutate(CARD,
       '\t\tpulse:Stop()\n\t\tflare:Hide()\n\t\treturn\n',
       '\t\treturn\n',
       "moments-card: a dark card keeps its flare",
       expect="moments-card: Calm effects and a quiet fight leave nothing looping", script=S)

mutate(CARD,
       '\t\tring:SetTexture(at.round and RING or RING_SQUARE)\n',
       '\t\tring:SetTexture(RING_SQUARE)\n',
       "moments-card: the ring is square on a round look",
       expect="moments-card: a look with no picture wears framed's", script=S)

mutate(CARD,
       '\tcard.lines.name:SetShown(full and card.lineSize.name ~= nil)\n',
       '\tcard.lines.name:SetShown(true)\n',
       "moments-card: the drink at rest shows its dim name",
       expect="moments-card: the drink at rest on Forever shows only its dim icon", script=S)

mutate(M,
       '\tlocal h = math.floor(ns.Looks.PreviewView(p.style or "glass") * percent / 100 * scale + 0.5)\n',
       '\tlocal h = math.floor(ns.Looks.PreviewView(p.style or "glass") * percent / 100 + 0.5)\n',
       "moments-card: the prompt's scale is not in the card's size",
       expect="moments-card: the button is a card four to one", script=S)

mutate(CARD,
       '\tif key == "blink" then\n\t\tlocal kind = slot.lossKind\n',
       '\tif key == "blink" then\n\t\tlocal kind = nil\n',
       "moments-card: Blink always says it lost control",
       expect="moments-card: Blink's reasons", script=S)

mutate(CARD,
       '\tif slot.wardRoute == "hit" then return Pair(hit) end\n',
       '',
       "moments-card: a ward lit by a hit says its target casts",
       expect="moments-card: the wards say whether the cast or the hit lit them", script=S)

mutate(M,
       '\tif state ~= "dark" then Card.ShowReason(slot, state) end\n',
       '',
       "moments-card: a lit card never writes its reason",
       expect="moments-card: Blink's reasons", script=S)
