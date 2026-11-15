-- Manners -- the looks that have a picture on the options window's cards.
--
-- Written by tools/make_look_previews.py; run it again after a look, a texture or
-- the prompt's defaults change (tests/scenarios/theme-picker.lua says when).

local _, ns = ...
ns.Looks.previews = {
	arcane = true,
	archmage = true,
	demonhunter = true,
	ebon = true,
	evoker = true,
	fel = true,
	firemage = true,
	forge = true,
	framed = true,
	frost = true,
	gearworks = true,
	ghost = true,
	glass = true,
	hairline = true,
	leather = true,
	letter = true,
	lightbringer = true,
	luxe = true,
	minimal = true,
	monk = true,
	pill = true,
	priest = true,
	ribbon = true,
	rogue = true,
	slate = true,
	stormcaller = true,
	toast = true,
	warchief = true,
	wild = true,
}
-- Where each look draws the spell icon in its picture: the rectangle as fractions of
-- the 256 x 64 picture (l and t from its top left), the texcoord crop, and whether it
-- is round, with the mask the look cuts it with. The window lays the live icon there.
ns.Looks.previewIcon = {
	arcane = { l = 0.09073, t = 0.28226, r = 0.1996, b = 0.71774, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	archmage = { l = 0.0984, t = 0.25806, r = 0.21937, b = 0.74194, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Archmage\\Archmage_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	demonhunter = { l = 0.12113, t = 0.26375, r = 0.23051, b = 0.70127, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	ebon = { l = 0.18585, t = 0.38415, r = 0.27732, b = 0.75, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Ebon\\Ebon_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	evoker = { l = 0.07951, t = 0.27367, r = 0.19033, b = 0.71697, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	fel = { l = 0.10887, t = 0.25806, r = 0.22984, b = 0.74194, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Fel\\Fel_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	firemage = { l = 0.09021, t = 0.22517, r = 0.22972, b = 0.78322, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	forge = { l = 0.10887, t = 0.25806, r = 0.22984, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	framed = { l = 0.09677, t = 0.25806, r = 0.21774, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	frost = { l = 0.07222, t = 0.3026, r = 0.16163, b = 0.66024, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Frost\\Frost_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	gearworks = { l = 0.10797, t = 0.25806, r = 0.22894, b = 0.74194, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Gearworks\\Gearworks_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	ghost = { l = 0.08589, t = 0.23927, r = 0.21824, b = 0.76868, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	glass = { l = 0.09677, t = 0.25806, r = 0.21774, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	hairline = { l = 0.0807, t = 0.15226, r = 0.25458, b = 0.84774, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	leather = { l = 0.14637, t = 0.10843, r = 0.23673, b = 0.46988, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	letter = { l = 0.15581, t = 0.31452, r = 0.24855, b = 0.68548, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Letter\\Letter_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	lightbringer = { l = 0.11694, t = 0.25806, r = 0.2379, b = 0.74194, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Lightbringer\\Lightbringer_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	luxe = { l = 0.125, t = 0.25806, r = 0.24597, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	minimal = { l = 0.09677, t = 0.25806, r = 0.21774, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	monk = { l = 0.0575, t = 0.29448, r = 0.16026, b = 0.70552, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	pill = { l = 0.08338, t = 0.23797, r = 0.21521, b = 0.76529, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	priest = { l = 0.07126, t = 0.27617, r = 0.17746, b = 0.70097, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Painted\\Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	ribbon = { l = 0.09073, t = 0.28226, r = 0.1996, b = 0.71774, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Ribbon\\Ribbon_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	rogue = { l = 0.05782, t = 0.22783, r = 0.18985, b = 0.75598, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	slate = { l = 0.09012, t = 0.24139, r = 0.22032, b = 0.76216, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	stormcaller = { l = 0.22253, t = 0.46386, r = 0.31289, b = 0.8253, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	toast = { l = 0.08554, t = 0.26152, r = 0.20478, b = 0.73848, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Toast\\Toast_IconMask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	warchief = { l = 0.12661, t = 0.29032, r = 0.24758, b = 0.77419, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	wild = { l = 0.1129, t = 0.25806, r = 0.23387, b = 0.74194, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Wild\\Wild_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
}
-- Where each look writes its two lines in its picture, and how: the rectangle as
-- fractions of the picture, the justification, the size and the shadow's offsets as
-- fractions of its height, the colour, an outline, and the look's own face (`latin`:
-- drawn only on a client whose alphabet has it). The pictures carry no text: the
-- window writes the name and the reason there live, in the player's language. A
-- reason line the look sets in a tag of its own (`pill`) has the tag's edges, how far
-- it reaches past the words on either side, its caps' width of its height, and its
-- layers, each the look's own file as a three-slice in the look's colour: the window
-- draws it round the live words, as wide as they are.
ns.Looks.previewText = {
	arcane = {
		name = { l = 0.24597, t = 0.29032, r = 0.90323, b = 0.5, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.24597, t = 0.54839, r = 0.90323, b = 0.70968, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.9, 0.7375, 0.395, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	archmage = {
		name = { l = 0.26521, t = 0.29032, r = 0.89516, b = 0.5, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.04, 0, 0.1, 0.9 } } },
		reason = { l = 0.26521, t = 0.53226, r = 0.89516, b = 0.69355, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.96265, 0.82817, 0.60032, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.04, 0, 0.1, 0.95 } } },
	},
	demonhunter = {
		name = { l = 0.37903, t = 0.34698, r = 0.76754, b = 0.52514, h = "LEFT", v = "MIDDLE", size = 0.17816, color = { 1, 1, 1, 1 }, shadow = { x = 0.0137, y = -0.0137, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.37903, t = 0.55364, r = 0.76754, b = 0.69069, h = "LEFT", v = "MIDDLE", size = 0.13704, color = { 0.944, 0.788, 0.452, 1 }, shadow = { x = 0.0137, y = -0.0137, color = { 0, 0, 0, 1 } } },
	},
	ebon = {
		name = { l = 0.31073, t = 0.40854, r = 0.69207, b = 0.56707, h = "LEFT", v = "MIDDLE", size = 0.15854, color = { 1, 1, 1, 1 }, shadow = { x = 0.0122, y = -0.0122, color = { 0, 0.01, 0.02, 0.95 } } },
		reason = { l = 0.31073, t = 0.59146, r = 0.69207, b = 0.71341, h = "LEFT", v = "MIDDLE", size = 0.12195, color = { 0.936, 0.832, 0.572, 1 }, shadow = { x = 0.0122, y = -0.0122, color = { 0, 0.01, 0.02, 1 } } },
	},
	evoker = {
		name = { l = 0.27814, t = 0.30524, r = 0.71742, b = 0.49622, h = "LEFT", v = "MIDDLE", size = 0.19098, color = { 1, 1, 1, 1 }, shadow = { x = 0.01469, y = -0.01469, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.27814, t = 0.52677, r = 0.71742, b = 0.67368, h = "LEFT", v = "MIDDLE", size = 0.14691, color = { 0.944, 0.788, 0.452, 1 }, shadow = { x = 0.01469, y = -0.01469, color = { 0, 0, 0, 1 } } },
	},
	fel = {
		name = { l = 0.29435, t = 0.29032, r = 0.83468, b = 0.5, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0.03, 0, 0.95 } } },
		reason = { l = 0.29435, t = 0.53226, r = 0.83468, b = 0.69355, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.92, 0.812, 0.476, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	firemage = {
		name = { l = 0.29989, t = 0.33799, r = 0.71726, b = 0.51855, h = "LEFT", v = "MIDDLE", size = 0.18056, color = { 1, 1, 1, 1 }, shadow = { x = 0.01389, y = -0.01389, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.29989, t = 0.54744, r = 0.71726, b = 0.68633, h = "LEFT", v = "MIDDLE", size = 0.13889, color = { 0.944, 0.788, 0.452, 1 }, shadow = { x = 0.01389, y = -0.01389, color = { 0, 0, 0, 1 } } },
	},
	forge = {
		name = { l = 0.27016, t = 0.29032, r = 0.90323, b = 0.5, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.27016, t = 0.53226, r = 0.90323, b = 0.69355, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.92, 0.768, 0.444, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	framed = {
		name = { l = 0.25806, t = 0.27419, r = 0.90323, b = 0.48387, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.25806, t = 0.56452, r = 0.90323, b = 0.72581, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.74, 0.6695, 0.547, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	frost = {
		name = { l = 0.2468, t = 0.30345, r = 0.6949, b = 0.49823, h = "LEFT", v = "MIDDLE", size = 0.19479, color = { 1, 1, 1, 1 }, shadow = { x = 0.01498, y = -0.01498, color = { 0, 0.01, 0.04, 0.95 } } },
		reason = { l = 0.2468, t = 0.5282, r = 0.6949, b = 0.67803, h = "LEFT", v = "MIDDLE", size = 0.14984, color = { 0.944, 0.836, 0.58, 1 }, shadow = { x = 0.01498, y = -0.01498, color = { 0, 0.01, 0.04, 1 } } },
	},
	gearworks = {
		name = { l = 0.30645, t = 0.27476, r = 0.73387, b = 0.48444, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0.02, 0.02, 0.9 } } },
		reason = { l = 0.30645, t = 0.5167, r = 0.73387, b = 0.67799, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.808, 0.492, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0.02, 0.02, 1 } } },
	},
	ghost = {
		name = { l = 0.24817, t = 0.34815, r = 0.81855, b = 0.55783, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
		reason = { l = 0.24817, t = 0.59138, r = 0.81855, b = 0.75267, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.788, 0.452, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
	},
	glass = {
		name = { l = 0.25806, t = 0.27419, r = 0.90323, b = 0.48387, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.25806, t = 0.56452, r = 0.90323, b = 0.72581, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.74, 0.6695, 0.547, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	hairline = {
		name = { l = 0.31155, t = 0.31217, r = 0.86694, b = 0.52185, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
		reason = { l = 0.31155, t = 0.5554, r = 0.86694, b = 0.71669, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.788, 0.452, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
	},
	leather = {
		name = { l = 0.2548, t = 0.12048, r = 0.6988, b = 0.31325, h = "LEFT", v = "MIDDLE", size = 0.19277, color = { 1, 1, 1, 1 }, shadow = { x = 0.01205, y = -0.01205, color = { 0.14, 0.07, 0.02, 0.95 } }, font = "Fonts\\MORPHEUS.TTF", latin = true },
		reason = { l = 0.2548, t = 0.33735, r = 0.6988, b = 0.45783, h = "LEFT", v = "MIDDLE", size = 0.12048, color = { 1, 0.9056, 0.728, 1 }, shadow = { x = 0.01205, y = -0.01205, color = { 0.14, 0.07, 0.02, 0.9 } } },
	},
	letter = {
		name = { l = 0.30645, t = 0.25725, r = 0.86331, b = 0.51531, h = "LEFT", v = "MIDDLE", size = 0.25806, color = { 0.23137, 0.21176, 0.19608, 1 }, shadow = { x = 0.00968, y = -0.00968, color = { 0.2, 0.105, 0.04, 0.4 } }, font = "Fonts\\MORPHEUS.TTF", latin = true },
		reason = { l = 0.30645, t = 0.54235, r = 0.86331, b = 0.70364, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.36914, 0.19841, 0.07844, 1 } },
	},
	lightbringer = {
		name = { l = 0.3097, t = 0.29032, r = 0.875, b = 0.5, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0.02, 0.1, 0.9 } } },
		reason = { l = 0.3097, t = 0.53226, r = 0.875, b = 0.69355, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.804, 0.492, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	luxe = {
		name = { l = 0.28629, t = 0.25, r = 0.90323, b = 0.45968, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.31653, t = 0.56935, r = 0.87298, b = 0.73065, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 1, 0.857, 0.545, 1 }, pill = { t = 0.52903, b = 0.77097, lead = 0.12097, tail = 0.12097, cap = 0.5, layers = { { file = "Interface\\AddOns\\Manners\\Textures\\Luxe\\Luxe_Pill", color = { 0.2, 0.156, 0.06, 0.9 } }, { file = "Interface\\AddOns\\Manners\\Textures\\Luxe\\Luxe_PillEdge", color = { 1, 0.78, 0.3, 0.5 } } } } },
	},
	minimal = {
		name = { l = 0.25806, t = 0.27419, r = 0.90323, b = 0.48387, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } }, flags = "OUTLINE" },
		reason = { l = 0.25806, t = 0.56452, r = 0.90323, b = 0.72581, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.909, 0.8385, 0.703, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } }, flags = "OUTLINE" },
	},
	monk = {
		name = { l = 0.24507, t = 0.29017, r = 0.72984, b = 0.49985, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.24507, t = 0.5334, r = 0.72984, b = 0.69469, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.788, 0.452, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
	},
	pill = {
		name = { l = 0.23758, t = 0.29308, r = 0.80645, b = 0.50276, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
		reason = { l = 0.23758, t = 0.53631, r = 0.80645, b = 0.6976, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.94775, 0.80218, 0.48866, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
	},
	priest = {
		name = { l = 0.23653, t = 0.29145, r = 0.72177, b = 0.50113, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.23653, t = 0.53468, r = 0.72177, b = 0.69597, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.788, 0.452, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
	},
	ribbon = {
		name = { l = 0.25, t = 0.27177, r = 0.86694, b = 0.52984, h = "LEFT", v = "MIDDLE", size = 0.25806, color = { 1, 0.91765, 0.67843, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.16, 0.02, 0.03, 1 } }, font = "Fonts\\MORPHEUS.TTF", latin = true },
		reason = { l = 0.25, t = 0.55081, r = 0.86694, b = 0.7121, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 1, 0.88, 0.8, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.16, 0.02, 0.03, 0.95 } } },
	},
	rogue = {
		name = { l = 0.24375, t = 0.2862, r = 0.72581, b = 0.49588, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.24375, t = 0.52943, r = 0.72581, b = 0.69072, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.788, 0.452, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
	},
	slate = {
		name = { l = 0.24654, t = 0.29337, r = 0.80645, b = 0.50305, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
		reason = { l = 0.24654, t = 0.53659, r = 0.80645, b = 0.69788, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.788, 0.452, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } } },
	},
	stormcaller = {
		name = { l = 0.36157, t = 0.48795, r = 0.79217, b = 0.64458, h = "LEFT", v = "MIDDLE", size = 0.15663, color = { 1, 1, 1, 1 }, shadow = { x = 0.01205, y = -0.01205, color = { 0, 0.01, 0.03, 0.95 } } },
		reason = { l = 0.36157, t = 0.66867, r = 0.79217, b = 0.78916, h = "LEFT", v = "MIDDLE", size = 0.12048, color = { 0.936, 0.812, 0.524, 1 }, shadow = { x = 0.01205, y = -0.01205, color = { 0, 0.01, 0.03, 1 } } },
	},
	toast = {
		name = { l = 0.25806, t = 0.28968, r = 0.89516, b = 0.49935, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.25806, t = 0.5329, r = 0.89516, b = 0.69419, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.92, 0.768, 0.444, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	warchief = {
		name = { l = 0.32984, t = 0.32258, r = 0.82661, b = 0.53226, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.02, 0, 0, 1 } } },
		reason = { l = 0.32984, t = 0.56452, r = 0.82661, b = 0.72581, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.952, 0.8, 0.484, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.02, 0, 0, 1 } } },
	},
	wild = {
		name = { l = 0.30242, t = 0.29032, r = 0.77823, b = 0.5, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.03, 0.02, 0, 0.95 } } },
		reason = { l = 0.30242, t = 0.53226, r = 0.77823, b = 0.69355, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.812, 0.484, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
}
-- The looks with an earlier art (Looks.HasEarlierArt), each with a second picture,
-- Preview_<key>_earlier, drawn with Earlier art on, and its icon and text as above:
-- a card wears them while the prompt draws that art.
ns.Looks.previewsEarlier = {
	frost = true,
}
ns.Looks.previewIconEarlier = {
	frost = { l = 0.11694, t = 0.25806, r = 0.2379, b = 0.74194, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Frost\\Frost_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
}
ns.Looks.previewTextEarlier = {
	frost = {
		name = { l = 0.30081, t = 0.29032, r = 0.79032, b = 0.5, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0.01, 0.04, 0.95 } } },
		reason = { l = 0.30081, t = 0.53226, r = 0.79032, b = 0.69355, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.944, 0.836, 0.58, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0.01, 0.04, 1 } } },
	},
}
ns.Looks.previewHash = "1923826c50e572c425ceac881c5e85670ff14ff44aaa683b9fed52e057e7b38a"
