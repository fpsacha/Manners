-- Manners -- the Toast look: a warm banner pinned by a round gilded medallion,
-- in the grammar of the game's own achievement toasts.
--
-- A stub. It is registered so the Look tab, the saved setting and the toc
-- already know it, and it draws as Luxe (`fallback`) until this file is
-- written. The interface is described at the top of Looks/Looks.lua; drop
-- `fallback`, add Build/Apply/Hide and the rest, ship the art under
-- Textures/Toast/ from a generator in tools/, and test it in
-- tests/scenarios/looks.lua's way.

local _, ns = ...
local L = ns.L

ns.Looks.Register("toast", {
	name = L["Toast -- warm banner, gilded medallion"],
	order = 2,
	fallback = "luxe",
})
