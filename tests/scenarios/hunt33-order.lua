-- Bug hunt 33, the buff order (Core.lua WalkBuffs, MoveBuff, ClampSettings'
-- repair, Options/Window/WidgetsOrder.lua) and what travels with a settings
-- string. Every scenario is red on 1.8.5 and says what it found.
--
-- Every scenario name starts with "hunt33-order:".

local dir, H = ...
local fail, load = H.fail, H.load

local function keys(list)
	local out = {}
	for i, buff in ipairs(list) do out[i] = buff.key end
	return table.concat(out, ",")
end

-- ------------------------------------------------------------------ 1
-- /manners export hands over "the current profile as one line of text", and
-- every setting with a default is shareable "as soon as it has a default" (the
-- walk in Commands.lua, ShareFields). buff.order has an empty table for its
-- default, so the walk finds nothing inside it, and the buffs the player put in
-- an order of their own never travel: the string carries Blessing of Kings
-- first (buff.kingsFirst) but not the order that overrides it, and an import
-- leaves the importing player's own order alone. skipRaidGroups, the other
-- empty set, has a "groups" kind of its own for exactly this; buff.skip has
-- "set".
do
	local scenario = "hunt33-order: a buff order you set travels in an exported settings string"
	Mock.reset()
	Mock.class = "PRIEST"
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			H.freshPrompt(ns, scenario)
			local before = keys(ns.BuffWalkOrder())
			local second = ns.BuffWalkOrder()[2]
			if not (second and ns.MoveBuff(second.key, -1)) then
				fail(scenario, "SKIPPED -- could not move " .. tostring(second and second.key) .. " up")
				return
			end
			local mine = keys(ns.BuffWalkOrder())
			if mine == before then
				fail(scenario, "SKIPPED -- the order did not change")
				return
			end
			local text = ns.ExportSettings()
			-- Another character's profile, as the player would meet it: the order
			-- cleared, then the string pasted.
			ns.ClearBuffOrder()
			local applied, said = ns.ImportSettings(text)
			if not applied then
				fail(scenario, "SKIPPED -- the string was refused: " .. tostring(said))
				return
			end
			local after = keys(ns.BuffWalkOrder())
			if after ~= mine then
				fail(scenario, ("exported with the order %s, imported to %s (the string %s)"):format(
					mine, after, text:find("buff%.order") and "names buff.order" or "does not name buff.order"))
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end
	Mock.reset()
end
