-- Manners -- the looks that have a picture on the options window's cards.
--
-- Written by tools/make_look_previews.py; run it again after a look, a texture or
-- the prompt's defaults change (tests/scenarios/theme-picker.lua says when).

local _, ns = ...
ns.Looks.previews = {
	arcane = true,
	framed = true,
	glass = true,
	leather = true,
	letter = true,
	luxe = true,
	minimal = true,
	ribbon = true,
	toast = true,
}
-- Where each look draws the spell icon in its picture: the rectangle as fractions of
-- the 256 x 64 picture (l and t from its top left), the texcoord crop, and whether it
-- is round, with the mask the look cuts it with. The window lays the live icon there.
ns.Looks.previewIcon = {
	arcane = { l = 0.09073, t = 0.28226, r = 0.1996, b = 0.71774, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	framed = { l = 0.09677, t = 0.25806, r = 0.21774, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	glass = { l = 0.09677, t = 0.25806, r = 0.21774, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	leather = { l = 0.08304, t = 0.25806, r = 0.20401, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	letter = { l = 0.15581, t = 0.31452, r = 0.24855, b = 0.68548, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Letter\\Letter_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	luxe = { l = 0.125, t = 0.25806, r = 0.24597, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	minimal = { l = 0.09677, t = 0.25806, r = 0.21774, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	ribbon = { l = 0.09073, t = 0.28226, r = 0.1996, b = 0.71774, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Ribbon\\Ribbon_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	toast = { l = 0.08554, t = 0.26152, r = 0.20478, b = 0.73848, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Toast\\Toast_IconMask", crop = { 0.08, 0.92, 0.08, 0.92 } },
}
ns.Looks.previewHash = "9143b2ea7598ec6bc0fa5fed8e8f3e24e439d4da19b5570e4e9d716419b0571b"
