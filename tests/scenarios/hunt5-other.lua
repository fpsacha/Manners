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

-- On retail, Source of Magic is an evoker talent and the Blessing of the
-- Bronze is not: the field means the same in every set, so it is filled in
-- wherever it is true.
do
	local scenario = "hunt5-other: Source of Magic is a talent on retail"
	Mock.reset()
	Mock.interface = 120100
	local ns = load(scenario)
	if ns then
		local source = ns.FindBuff("EVOKER", "sourceofmagic")
		local bronze = ns.FindBuff("EVOKER", "bronze")
		if not (source and bronze) then
			fail(scenario, "the retail evoker is missing a buff")
		else
			if source.talent ~= true then
				fail(scenario, "Source of Magic has talent = " .. tostring(source.talent))
			end
			if bronze.talent ~= nil then
				fail(scenario, "Blessing of the Bronze marked as a talent")
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
