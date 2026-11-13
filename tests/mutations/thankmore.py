# Mutations for the others to pick from (1.11.20): *Or one of these, at
# random* under Emote to use (Options/Say.lua), the draw (Favours.lua,
# ns.ThankEmoteToken), the default and repair (Core.lua) and the row's place
# (Options/Window/Layout.lua). Each is caught by the scenario in
# tests/scenarios/thankmore.lua (or thank.lua) that names it.

S = "runscenarios.py"

# --- the draw ---

mutate("Favours.lua",
       "\t\treturn pool[math.random(#pool)]\n",
       "\t\treturn first\n",
       "thankmore: the ticks never drawn from",
       expect="thankmore: a thank-you draws from the one picked", script=S)

mutate("Favours.lua",
       "\t\t\tif more[token] == true and token ~= first then pool[#pool + 1] = token end\n",
       "\t\t\tif more[token] == true then pool[#pool + 1] = token end\n",
       "thankmore: the main emote counted twice",
       expect="thankmore: a thank-you draws from the one picked", script=S)

mutate("Favours.lua",
       "\t\tfor _, token in ipairs(ns.THANK_EMOTES) do\n\t\t\tif more[token] == true",
       "\t\tfor token in pairs(more) do\n\t\t\tif more[token] == true",
       "thankmore: an emote the list lacks drawn",
       expect="thankmore: a thank-you draws from the one picked", script=S)

mutate("Favours.lua",
       "\t\tif type(more) ~= \"table\" or next(more) == nil then return first end\n",
       "\t\tif type(more) ~= \"table\" then return first end\n",
       "thankmore: a draw with nothing ticked",
       expect="thankmore: with nothing ticked", script=S)

mutate("Favours.lua",
       "\t\t\tlocal token = ns.ThankEmoteToken(prompt)\n",
       "\t\t\tlocal token = prompt and ns.THANK_EMOTE_SET[prompt.thankEmoteToken] and prompt.thankEmoteToken or \"THANK\"\n",
       "thankmore: the thank-you made ignores the draw",
       expect="thank: a thank-you makes the emote drawn", script=S)

# --- the default and the repair ---

mutate("Core.lua",
       "\t\t\tthankEmoteMore = {},\n",
       "",
       "thankmore: no default table",
       expect="thankmore: with nothing ticked", script=S)

mutate("Core.lua",
       "\t\tif not (ns.THANK_EMOTE_SET[token] and on == true) then\n",
       "\t\tif not ns.THANK_EMOTE_SET[token] then\n",
       "thankmore: a tick that is not true kept",
       expect="thankmore: the repair keeps only known emotes", script=S)

mutate("Core.lua",
       "\tif type(p.thankEmoteMore) ~= \"table\" then\n\t\tfixed(\"thankEmoteMore\", p.thankEmoteMore)\n\t\tp.thankEmoteMore = {}\n\tend\n",
       "\tif type(p.thankEmoteMore) ~= \"table\" then p.thankEmoteMore = { BOW = true } end\n",
       "thankmore: a string repaired to a tick",
       expect="thankmore: the repair keeps only known emotes", script=S)

# --- the page ---

mutate("Options/Say.lua",
       "\t\t\t\t\t\tif token ~= P().thankEmoteToken then values[token] = \"/\" .. token:lower() end\n",
       "\t\t\t\t\t\tvalues[token] = \"/\" .. token:lower()\n",
       "thankmore: the main emote offered again",
       expect="thankmore: What I say ticks the others", script=S)

mutate("Options/Say.lua",
       "\t\t\t\tset = function(_, token, on) P().thankEmoteMore[token] = on and true or nil end,\n",
       "\t\t\t\tset = function(_, token, on) P().thankEmoteMore[token] = on end,\n",
       "thankmore: an untick kept as false",
       expect="thankmore: What I say ticks the others", script=S)

mutate("Options/Say.lua",
       "THANKS_ONLY.thankEmoteMore = true\n",
       "",
       "thankmore: hidden from a class with nothing to give",
       expect="a rogue", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"click.thankEmoteMore\", indent = 2, columns = 4 },\n",
       "",
       "thankmore: the row not placed on the page",
       expect="thankEmoteMore", script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\t\tor name == \"prompt.thankEmoteMore\" then\n",
       "\t\t\t\t\t\t\tor false then\n",
       "thankmore: the ticks do not travel",
       expect="thankmore: the ticks travel", script=S)
