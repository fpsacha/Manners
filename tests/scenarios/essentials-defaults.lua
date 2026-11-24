-- 1.12, just the essentials: after players found 1.11.41 bloated ("features
-- enabled by default", "a mess to turn it all off"), the extras are off in a
-- new profile and a player ticks the ones they want. Out of the box Manners
-- returns buffs, buffs your group and passers-by, and says thanks.
--
-- Off by default, held here on every client:
--   * the Will of the Forsaken, Mend Pet and cure buttons in a fight;
--   * on yourself, a weapon's poison, stone, oil or fishing lure (Buffs.lua,
--     `enhance`), Forever's mage scrolls (`isScroll`), tracking (`tracking`),
--     Make a healthstone, and, as before, food, Well-Rested, the companion pet,
--     flasks, elixirs and stat scrolls (`food`, `rest`, `pet`, `consumable`);
--   * the consumables button, and the courtesies on request.
-- And the fight's options 1.12 removed have no default left.
--
-- Every scenario name starts with "essentials-defaults:" so the mutations in
-- tests/mutations/essentials-defaults.py can name the one that has to catch them.

local dir, H = ...
local fail, load, freshPrompt = H.fail, H.load, H.freshPrompt

local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }

-- Why a family is off by default, or nil for one that is on.
local function extra(family)
	if family.enhance then return "a weapon's poison, stone, oil or lure" end
	if family.isScroll then return "a mage's scroll" end
	if family.tracking then return "tracking" end
	if family.key == "makehealthstone" then return "Make a healthstone" end
	if family.food then return "food" end
	if family.rest then return "Well-Rested" end
	if family.pet then return "the companion pet" end
	if family.consumable then return "a flask, elixir or scroll" end
	return nil
end

for _, flavour in ipairs(FLAVOURS) do
	local scenario = "essentials-defaults: " .. flavour .. ": the extras on yourself are off in a new profile"
	Mock.reset()
	Mock.setFlavour(flavour)
	local ns = load(scenario)
	if ns then
		local pick = ns.defaults.profile.ownBuffs.pick
		local seen = {}
		for class, families in pairs(ns.OWN_BUFFS or {}) do
			for _, family in ipairs(families) do
				local why = extra(family)
				if why then
					seen[why] = true
					if pick[family.key] ~= "off" then
						fail(scenario, ("%s's %s (%s) is %s by default, not off"):format(
							tostring(class), tostring(family.key), why, tostring(pick[family.key])))
					end
				end
			end
		end
		-- The list above has to have found something to judge on every client.
		if not seen["a weapon's poison, stone, oil or lure"] and flavour ~= "mainline" then
			fail(scenario, "SKIPPED -- no weapon item family on " .. flavour)
		end
		if not seen["tracking"] and (flavour == "camelot" or flavour == "vanilla" or flavour == "tbc") then
			fail(scenario, "SKIPPED -- no tracking family on " .. flavour)
		end
	end
	Mock.reset()
end

do
	local scenario = "essentials-defaults: the fight buttons, the consumables button and the courtesies are off in a new profile"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local d = ns.defaults.profile
		local want = {
			{ "prompt.breakFree", d.prompt.breakFree },
			{ "prompt.cureFight", d.prompt.cureFight },
			{ "beast.fightMend", d.beast.fightMend },
			{ "ownBuffs.apart", d.ownBuffs.apart },
			{ "sources.courtesyRefresh", d.sources.courtesyRefresh },
			{ "sources.courtesyPortals", d.sources.courtesyPortals },
			{ "sources.courtesyHealthstones", d.sources.courtesyHealthstones },
			{ "sources.courtesySummons", d.sources.courtesySummons },
		}
		for _, row in ipairs(want) do
			if row[2] ~= false then fail(scenario, row[1] .. " is " .. tostring(row[2]) .. " by default, not off") end
		end
		-- The rota stays, on.
		if d.prompt.fightRota ~= true then fail(scenario, "the fight's rota is not on by default") end
		-- What 1.12 removed has no default left.
		for _, key in ipairs({ "fightKeySpells", "fightKeyOn", "hideInFight", "hideInCombat", "dimInCombat" }) do
			if d.prompt[key] ~= nil then fail(scenario, "prompt." .. key .. " still has a default") end
		end
		-- And a new profile reads them off.
		freshPrompt(ns, scenario)
		local p = ns.db.profile
		if p.prompt.breakFree ~= false or p.prompt.cureFight ~= false or p.beast.fightMend ~= false then
			fail(scenario, "a new profile reads a fight button on")
		end
	end
	Mock.reset()
end
