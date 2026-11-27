# Dark prompt looks keep the client's class colours. The light-ground rule has
# a separate scenario in tests/scenarios/tint.lua.

S = "runscenarios.py"

mutate("Prompt/Paint.lua",
       "\treturn string.format(\"|c%s%s|r\", c.colorStr, text)\n",
       "\tlocal rgb = c.colorStr:sub(3)\n\tlocal lighter = \"|cff\" .. rgb:gsub(\"%x%x\", function(v) return string.format(\"%02x\", math.floor(tonumber(v, 16) + (255 - tonumber(v, 16)) * 0.5)) end)\n\treturn lighter .. text .. \"|r\"\n",
       "tint: dark looks soften Blizzard class colours",
       expect="tint: dark looks keep Blizzard class colours", script=S)

mutate("Prompt/Text.lua",
       "\tif StandardClassCode(a, r, g, b) then\n"
       "\t\thit = \"|c\" .. key\n"
       "\t\tink.codes[key] = hit\n"
       "\t\treturn hit\n"
       "\tend\n",
       "",
       "tint: dark-ground text re-lightens Blizzard class colours",
       expect="tint: dark looks keep Blizzard class colours", script=S)
