-- Blessing of Salvation and Blessing of Light on WoW Forever (1.11.4). Build
-- 1.60.1.70790 deleted them (1038 and Greater 25895; 19977 to 19979 and
-- Greater 25890 have no SpellName there), and a paladin was told in /manners
-- debug that Manners was wrong about spells the game no longer has. Forever's
-- set holds Wisdom, Might and Kings only (as without Sanctuary since 1.8);
-- Classic Era and Burning Crusade, which still have them, keep both.
--
-- Every scenario name starts with "retired:" so the mutations in
-- tests/mutations/retired.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local GONE = { 1038, 25895, 19977, 19978, 19979, 25890 }

for _, case in ipairs({
	{ "camelot", false }, { "vanilla", true }, { "tbc", true },
}) do
	local client, has = case[1], case[2]
	local scenario = "retired: " .. client .. ": a paladin " .. (has and "still has" or "no longer has") .. " Salvation and Light"
	Mock.reset()
	Mock.setFlavour(client)
	Mock.class = "PALADIN"
	local ns = load(scenario)
	if ns then
		for _, key in ipairs({ "salvation", "light" }) do
			local found = ns.FindBuff("PALADIN", key) ~= nil
			if found ~= has then
				fail(scenario, client .. "'s paladin " .. (found and "has " or "lacks ") .. key)
			end
		end
		if not has then
			for _, id in ipairs(GONE) do
				if ns.SPELL_SECONDS[id] ~= nil then
					fail(scenario, "Forever keeps a length for spell " .. id .. ", which its client no longer has")
				end
				if ns.BUFF_BY_ID and ns.BUFF_BY_ID[id] then
					fail(scenario, "Forever still reads spell " .. id .. " as a buff")
				end
			end
			local keys = {}
			for _, buff in ipairs(ns.GetClassBuffs("PALADIN")) do keys[#keys + 1] = buff.key end
			-- And Forever's own Oath of Light, for the tank (1.11.11).
			if table.concat(keys, ", ") ~= "wisdom, might, kings, oathoflight" then
				fail(scenario, "Forever's paladin has " .. table.concat(keys, ", ")
					.. ", not wisdom, might, kings, oathoflight")
			end
		end
	end
	Mock.reset()
end
