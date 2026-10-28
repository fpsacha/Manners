# Mutations for hunt 39's finds in the six looks and the paint path they share:
# tests/scenarios/hunt39-looks.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back the mistake
# the hunt fixed and names the scenario that has to object.


def _m(file, old, new, label, **kw):
    kw.setdefault("script", "runscenarios.py")
    mutate(file, old, new, "hunt39-looks: " + label, **kw)


# --- the glass's shadow goes with the panel's opacity -------------------------

_m("Prompt/Panel.lua",
   "\t\tlocal shadowK = math.min(1, ba / SHADOW_AT)\n",
   "\t\tlocal shadowK = 1\n",
   "the shadow steps keep their strength under a see-through panel",
   expect="hunt39-looks: glass has no dark box under a see-through panel")

_m("Prompt/Panel.lua",
   "\t\tR.hairBottom:SetVertexColor(0, 0, 0, 0.55 * shadowK)\n",
   "\t\tR.hairBottom:SetVertexColor(0, 0, 0, 0.55)\n",
   "the bevel's dark line keeps its strength under a see-through panel",
   expect="hunt39-looks: glass has no dark box under a see-through panel")
