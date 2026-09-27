-- The fifth bug hunt, on the buff data: which buffs only a talented character
-- has, so that somebody of your own class may still need one from you.
--
-- Every scenario name starts with "hunt5-other:" so the mutations in
-- tests/mutations/hunt5-other.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

-- On the vanilla set Forever runs, Kings, Sanctuary and Divine Spirit come
-- from talents; Might is trained by every paladin and must not be marked.
do
	local scenario = "hunt5-other: talent-only buffs are marked on Forever"
	Mock.reset()
	Mock.interface = 16001
	local ns = load(scenario)
	if ns then
		for _, want in ipairs({
			{ "PALADIN", "kings", true },
			{ "PALADIN", "sanctuary", true },
			{ "PRIEST", "spirit", true },
			{ "PALADIN", "might", nil },
			{ "PRIEST", "fortitude", nil },
		}) do
			local buff = ns.FindBuff(want[1], want[2])
			if not buff then
				fail(scenario, want[1] .. " has no " .. want[2])
			elseif buff.talent ~= want[3] then
				fail(scenario, ("%s %s has talent = %s, wanted %s"):format(want[1],
					want[2], tostring(buff.talent), tostring(want[3])))
			end
		end
	end
end

-- Mists made Kings baseline, so there it is nobody's talent.
do
	local scenario = "hunt5-other: Kings is baseline on Mists"
	Mock.reset()
	Mock.interface = 50504
	Mock.combatLog = true
	local ns = load(scenario)
	if ns then
		local kings = ns.FindBuff("PALADIN", "kings")
		if not kings then
			fail(scenario, "no Kings on Mists")
		elseif kings.talent ~= nil then
			fail(scenario, "Kings marked as a talent on Mists")
		end
	end
end
