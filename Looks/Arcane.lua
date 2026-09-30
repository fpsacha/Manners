-- Manners -- the Arcane look: smoked glass with a rim lit in the reason
-- colour, so the whole outline says why.
--
-- A stub. It is registered so the Look tab, the saved setting and the toc
-- already know it, and it draws as Luxe (`fallback`) until this file is
-- written. The interface is described at the top of Looks/Looks.lua; drop
-- `fallback`, add Build/Apply/Hide and the rest, ship the art under
-- Textures/Arcane/ from a generator in tools/, and test it in
-- tests/scenarios/looks.lua's way.

local _, ns = ...
local L = ns.L

ns.Looks.Register("arcane", {
	name = L["Arcane -- smoked glass, a rim lit by the reason"],
	order = 3,
	fallback = "luxe",
})
