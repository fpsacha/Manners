-- Bug hunt 33, settings: the profile, its share string, its reset lists.
-- Every scenario name starts with "hunt33-settings:".

local dir, H = ...
local fail, load = H.fail, H.load

local function session(scenario, class, flavour)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.class = class or "PALADIN"
	local ns = load(scenario)
	if not ns then return nil end
	H.drive(scenario, ns)
	ns.Prompt:ExitTest()
	return ns
end

-- A paladin's own Buff order (Who to buff, 1.8.3) is a profile setting like the
-- rest, saved in profile.buff.order. Its default is an empty table, which the
-- share string walks into and finds nothing, so the order is neither written
-- into /manners export, nor put back to Automatic by /manners import (which
-- says everything the string does not name goes back to its default), nor
-- brought back by /manners import undo.
do
	local scenario = "hunt33-settings: the buff order travels in a settings string"
	local ns = session(scenario, "PALADIN")
	if ns then
		-- Put Might ahead of Wisdom.
		local moved = ns.MoveBuff("might", -1)
		local order = ns.BuffOrder()
		if not moved or not order then
			fail(scenario, "SKIPPED -- the order could not be set: " .. tostring(moved))
		else
			local mine = table.concat(order, ",")
			local text = ns.ExportSettings()
			-- Another player's profile: Automatic.
			ns.ClearBuffOrder()
			local ok, said = ns.ImportSettings(text)
			if not ok then fail(scenario, "the player's own export did not import: " .. tostring(said)) end
			local after = ns.BuffOrder()
			if not after or table.concat(after, ",") ~= mine then
				fail(scenario, "the buff order " .. mine .. " was exported and imported as "
					.. tostring(after and table.concat(after, ",") or "Automatic"))
			end
			-- And the other way: a string that carries none is a profile on Automatic.
			ns.MoveBuff("might", -1)
			local plain = ns.ExportSettings()
			local keep = ns.BuffOrder()
			if keep then
				ns.ClearBuffOrder()
				local bare = ns.ExportSettings()
				ns.MoveBuff("might", -1)
				ns.ImportSettings(bare)
				if ns.BuffOrder() then
					fail(scenario, "importing a string with no buff order left the player's own order in place; the import says everything it does not name goes back to its default")
				end
			end
			local _ = plain
		end
	end
end
