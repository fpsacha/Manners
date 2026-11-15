-- The phrase box as releases between the two rewordings of the examples saved
-- it (1.6.5 to 1.11.25): `RP.LEGACY.reworded`'s new lines with
-- `RP.LEGACY.reworded2`'s old ones (Phrases.lua, RP.BETWEEN). A troll's box
-- holds lines of both lists, so it is neither today's box nor 1.6.4's, and it
-- must still read as the untouched set and turn into today's at login.
-- Written out as 1.11.25 saved it, not rebuilt from the pools.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive, findOption = H.fail, H.load, H.drive, H.findOption

local realFaction = rawget(_G, "UnitFactionGroup")

local TROLL_MAGE_11125 = {
	"Ya too kind, {name}! This one's from me.",
	"Thanks, mon! Da spirits smile on ya, {name}.",
	"Ya gave me good mojo, {name}. Now ya get some back, extra spicy.",
	"Death's gonna be real disappointed, {name}. Thanks, mon.",
	"Sure thing, {name}. Hold still; mojo hates a movin' target.",
	"No trouble, {name}. Da loa like ya.",
	"Stay away from da voodoo, {name}. Except this one. This one's fine.",
	"Da loa watch over ya, {name}. They're real nosy that way.",
	"Stay sharp, {name}. Take this with ya.",
	"Ya look like somebody who appreciate quality, {name}. Here: quality.",
	"Here, {name}. Walk like ya own the jungle. I do.",
	"For the Horde, {name}! Go with strength. I've just handed you some.",
	"Go with honour, {name}. Victory awaits.",
	"Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful.",
	"Crew's got style, {name}. Now it's got mojo too.",
	"We go in together, {name}, we come out together. That's the plan, mon.",
	"Our strength is each other, {name}. For the Horde!",
	"Forward, {name}. The Horde advances together. Retreats... never, officially.",
	"We look after our own, {name}. Always, mon.",
	"Here, {name}. I had a spare thought and nowhere to put it.",
	"Take this, {name}. I'd add bread, but conjured bread tastes of nothing.",
	"We have to stop meeting like this, {name}. Actually, no, we don't.",
	"Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt.",
	"Night's the best time for mojo, {name}. Nobody sees where it's from.",
}

do
	local scenario = "rp-between: a box saved between the two rewordings still counts"
	rawset(_G, "UnitFactionGroup", function(unit)
		if unit == "player" then return "Horde", "Horde" end
		return nil
	end)
	local ok, err = pcall(function()
		Mock.reset()
		Mock.playerRace = "Troll"
		Mock.class = "MAGE"
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local preset = findOption(ns.optionsTable, "preset")
		if not (preset and preset.set) then
			fail(scenario, "SKIPPED -- the Load a set dropdown is not on the page")
			return
		end
		preset.set({ "preset" }, "incharacter")
		local RP, speech = ns.InCharacter, ns.db.profile.speech
		local today = RP.Text()
		local saved = table.concat(TROLL_MAGE_11125, "\n")
		if today == saved then
			fail(scenario, "SKIPPED -- the troll's examples read as 1.11.25's")
			return
		end
		speech.phrases = saved
		if not RP.Active(speech) then fail(scenario, "a troll mage's 1.11.25 box counts as edited") end
		ns.ClampSettings()
		if speech.phrases ~= today then
			fail(scenario, "a troll mage's 1.11.25 box was not turned into today's: |" .. tostring(speech.phrases) .. "|")
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	rawset(_G, "UnitFactionGroup", realFaction)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
