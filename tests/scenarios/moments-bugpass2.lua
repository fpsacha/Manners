-- The second bug pass over the buttons for the moment (Prompt/Moments.lua,
-- Prompt/MomentsData.lua, Selftest.lua, tests/momentskit.lua): a game-painted
-- Counterspell or Spellsteal takes two clicks, the first of two shows a ring and the
-- spell's icon on the layer Lua owns and a double click does not count as two, a
-- drink the game paints shows a hint where Lua can see it, a cast start and a
-- target change keep the recheck going, a probe does not undo the first of two
-- clicks, the buttons that must fire at once stop the cast first, the debug lines
-- keep the character's name out, the cover's leaks are counted for the session,
-- the self-test skips a row with no spell id, and Forever's kit hides what it hides.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client: what Forever hides is the owner's check-up, not something a scenario knows.
--
-- Every name starts with "moments-bugpass2:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")

local function with(name, body, opts) K.withMage(H, "moments-bugpass2: " .. name, body, opts) end
local function name(s) return "moments-bugpass2: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end

local function count(field, value)
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e[field] == value then n = n + 1 end
	end
	return n
end
local function uses()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.use then n = n + 1 end
	end
	return n
end

local TBC = { flavour = "tbc" }

-- A hidden flag the game paints: Counterspell and Spellsteal take two clicks.
do
	local s = name("Counterspell painted by the game: the first click is swallowed, a second one later casts")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		K.cast(ns, { secret = true, notInterruptible = true })
		K.tick(ns, 0.3)
		if slot(ns, 1).state ~= "game" then fail(s, "not left to the game: " .. slot(ns, 1).state) return end
		if not slot(ns, 1).cover:IsShown() then fail(s, "no cover over a button only the game can light") end
		local first = K.click(ns, 1)
		if first == ns.Moments:Button(1) or count("spell", "Counterspell") ~= 0 then fail(s, "one click went through") end
		Mock.runTimers(0.5)
		K.click(ns, 1)
		if count("spell", "Counterspell") ~= 1 then fail(s, "the second click did not cast: " .. count("spell", "Counterspell")) end
	end, { plain = false })
	s = name("Counterspell with a plain verdict: one click casts")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		K.cast(ns, { notInterruptible = false })
		K.tick(ns, 0.3)
		if slot(ns, 1).state ~= "lit" then fail(s, "not lit: " .. slot(ns, 1).state) return end
		if slot(ns, 1).cover:IsShown() then fail(s, "a cover over a lit Counterspell") end
		K.click(ns, 1)
		if count("spell", "Counterspell") ~= 1 then fail(s, "one click did not cast") end
	end, { plain = true })
	s = name("Spellsteal painted by the game takes two clicks")
	with(s, function(ns)
		Mock.buffsWithheld = true
		Mock.targetBuffs = { { steal = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if slot(ns, 8).state ~= "game" then fail(s, "not left to the game: " .. slot(ns, 8).state) return end
		local first = K.click(ns, 8)
		if first == ns.Moments:Button(8) or count("spell", "Spellsteal") ~= 0 then fail(s, "one click went through") end
		Mock.runTimers(0.5)
		K.click(ns, 8)
		if count("spell", "Spellsteal") ~= 1 then fail(s, "the second click did not cast") end
	end, TBC)
end

-- The first of two clicks is seen, and a double click is not two.
do
	local s = name("the first of two clicks shows the ring and the icon on the face, which the game does not paint")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 100
		K.pull(ns)
		K.tick(ns, 0.3)
		local look = ns.Moments:Look(2)
		if slot(ns, 2).state ~= "game" or K.shown(ns, 2) ~= 0 then fail(s, "not painted away: " .. slot(ns, 2).state) return end
		K.click(ns, 2)
		if not look.ring:IsShown() or look.ring:GetParent() == look.inner then fail(s, "the ring is not on a layer Lua owns") end
		if Mock.shownAlpha(look.ring) <= 0 then fail(s, "the ring is not visible while the layer the game paints is 0") end
		if not look.hint:IsShown() or Mock.shownAlpha(look.hint) <= 0 then fail(s, "no icon on the layer Lua owns") end
	end, { plain = false })
	s = name("a second click inside a third of a second is swallowed, a later one casts")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 100
		K.pull(ns)
		K.tick(ns, 0.3)
		K.click(ns, 2)
		Mock.runTimers(0.1)
		local quick = K.click(ns, 2)
		if quick == ns.Moments:Button(2) or count("spell", "Ice Block") ~= 0 then fail(s, "a double click cast") end
		Mock.runTimers(0.5)
		K.click(ns, 2)
		if count("spell", "Ice Block") ~= 1 then fail(s, "a deliberate second click did not cast: " .. count("spell", "Ice Block")) end
	end, { plain = false })
end

-- The drink the game paints, out of a fight, is seen from Lua.
do
	local s = name("a drink the game paints shows a dim icon from Lua at any mana, never an invisible square")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.manaSecret = true
		Mock.mana = 100
		Mock.bags = { [3772] = 3 }
		K.event(ns, "BAG_UPDATE_DELAYED")
		K.tick(ns, 0.3)
		local look = ns.Moments:Look(11)
		if slot(ns, 11).state ~= "game" then fail(s, "not left to the game: " .. slot(ns, 11).state) return end
		if K.shown(ns, 11) ~= 0 then fail(s, "painted at full mana: " .. tostring(K.shown(ns, 11))) end
		if not look.hint:IsShown() or Mock.shownAlpha(look.hint) <= 0 then fail(s, "an invisible button takes the mouse") end
		Mock.mana = 10
		K.event(ns, "UNIT_POWER_UPDATE", "player")
		K.tick(ns, 0.3)
		if K.shown(ns, 11) ~= 1 then fail(s, "not painted under the line") end
	end, { plain = false })
end

-- A cast start or a target change starts the recheck for what waits on range.
do
	local s = name("a cast start with the target out of range: stepping in range lights it with no other event")
	with(s, function(ns)
		Mock.targetOutOfRange = true
		K.pull(ns)
		K.tick(ns, 0.3)
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if slot(ns, 1).state ~= "dark" or slot(ns, 1).why ~= "out of range" then
			fail(s, "not dark for range: " .. slot(ns, 1).state .. " " .. tostring(slot(ns, 1).why))
			return
		end
		Mock.targetOutOfRange = nil
		K.tick(ns, 1)
		if slot(ns, 1).state ~= "lit" then fail(s, "still " .. slot(ns, 1).state .. " after stepping in range") end
	end, { flavour = "vanilla", plain = true })
	s = name("a target change onto a caster out of range: stepping in range lights it with no other event")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.targetOutOfRange = true
		Mock.targetCast = {}
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		if slot(ns, 1).state ~= "dark" or slot(ns, 1).why ~= "out of range" then
			fail(s, "not dark for range: " .. slot(ns, 1).state .. " " .. tostring(slot(ns, 1).why))
			return
		end
		Mock.targetOutOfRange = nil
		K.tick(ns, 1)
		if slot(ns, 1).state ~= "lit" then fail(s, "still " .. slot(ns, 1).state .. " after stepping in range") end
	end, { flavour = "vanilla", plain = true })
end

-- A probe that learned nothing new does not undo the first of two clicks.
do
	local s = name("a probe between the two clicks of a drink does not close the opening")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.manaSecret = true
		Mock.mana = 10
		Mock.bags = { [3772] = 3 }
		K.event(ns, "BAG_UPDATE_DELAYED")
		K.tick(ns, 0.3)
		K.click(ns, 11)
		if not slot(ns, 11).ring:IsShown() then fail(s, "no opening to begin with") return end
		ns.ProbeCapabilities()
		ns.addon:Tick()
		Mock.runTimers(0.4)
		if not slot(ns, 11).openUntil then fail(s, "the probe closed the opening") end
		K.click(ns, 11)
		if uses() ~= 1 then fail(s, "the second click did not drink: " .. uses()) end
	end, { plain = false })
	s = name("a probe that learned a different list does refresh")
	with(s, function(ns)
		if not ns.Moments:Slot(2) then fail(s, "no Ice Block button") return end
		Mock.knownSpells[11958] = nil
		ns.ProbeCapabilities()
		ns.addon:Tick()
		Mock.runTimers(0)
		if ns.Moments:Slot(2).armed then fail(s, "Ice Block stayed armed after the spell went") end
	end)
end

-- The buttons that must fire at once stop the cast first.
do
	local s = name("Evocation and the mana gem stop the cast first, on every client that has them")
	for _, flavour in ipairs({ "camelot", "tbc", "mists" }) do
		with(s .. " (" .. flavour .. ")", function(ns)
			local macro = K.macro(ns, 4)
			if not macro or macro:sub(1, 13) ~= "/stopcasting\n" then fail(s, flavour .. ": Evocation's macro is " .. tostring(macro)) end
			Mock.bags = { [flavour == "mists" and 36799 or 8008] = 1 }
			K.relearn(ns)
			local gem = K.macro(ns, 5)
			if not gem or gem:sub(1, 13) ~= "/stopcasting\n" then fail(s, flavour .. ": the gem's macro is " .. tostring(gem)) end
		end, { flavour = flavour })
	end
end

-- /manners debug is pasted into public issues: the character's name stays out.
do
	local s = name("no debug line holds the character's own name")
	with(s, function(ns)
		local who = UnitName("player")
		local macro = K.macro(ns, 6)
		if not (macro and macro:find(who, 1, true)) then fail(s, "the self-cast macro does not hold the name, nothing to hide: " .. tostring(macro)) return end
		for _, line in ipairs(ns.MomentLines()) do
			if line:find(who, 1, true) then fail(s, "a line holds the name: " .. line) end
		end
		local found
		for _, line in ipairs(ns.MomentLines()) do
			if line:find("moment slowfall:", 1, true) and line:find("/target <you>", 1, true) then found = true end
		end
		if not found then fail(s, "the slow fall line does not show the macro with the name left out") end
	end)
end

-- The cover's leaks are this session's, on the row that leaked.
do
	local s = name("a leak from an earlier session warns nothing; one this session warns its own row")
	with(s, function(ns)
		ns.db.global.momentCoverLeaks = 4
		local rows = ns.Moments.SelfRows()
		for _, r in ipairs(rows) do
			if r.warn then fail(s, "an old count warns: " .. r.text) end
		end
		Mock.coverLeaks = true
		K.pull(ns)
		K.tick(ns, 0.3)
		K.click(ns, 1)
		K.release(ns)
		local warned = {}
		for _, r in ipairs(ns.Moments.SelfRows()) do
			if r.warn then warned[#warned + 1] = r.key end
		end
		if #warned ~= 1 or warned[1] ~= "counterspell" then fail(s, "the warnings: " .. table.concat(warned, ",")) end
	end)
end

-- The self-test: a row with no spell id (the drink) has no cooldown to read.
do
	local s = name("the check-up of a priest, whose only row is a drink, does not throw")
	with(s, function(ns)
		local found
		for _, r in ipairs(ns.Selftest.Run()) do
			if r.id == "fight.apis" then
				found = true
				if r.status == "FAIL" then fail(s, "fight.apis: " .. tostring(r.value)) end
			end
		end
		if not found then fail(s, "no fight.apis result") end
		if not ns.Moments.Has("drink") then fail(s, "the priest learned no drink") end
	end, { class = "PRIEST", known = false })
	s = name("a mage's check-up still reads the first cooldown that has an id")
	with(s, function(ns)
		local line
		for _, r in ipairs(ns.Selftest.Run()) do
			if r.id == "fight.apis" and tostring(r.value):find("cooldown flag isActive", 1, true) then line = r end
		end
		if not line then fail(s, "no cooldown line for a mage") end
	end)
end

-- The kit: Forever hides what the owner's check-up says it hides.
do
	local s = name("the kit on Forever hides health, mana and the target's cast, and opts.plain gives plain values")
	with(s, function()
		if not issecretvalue(UnitHealth("player")) then fail(s, "health is plain on Forever") end
		if not issecretvalue(UnitPower("player", 0)) then fail(s, "mana is plain on Forever") end
		Mock.targetCast = {}
		local _, _, _, _, _, _, _, notInt = UnitCastingInfo("target")
		if not issecretvalue(notInt) then fail(s, "the target's cast flag is plain on Forever") end
	end)
	with(s, function()
		if issecretvalue(UnitHealth("player")) or issecretvalue(UnitPower("player", 0)) then fail(s, "opts.plain left a value hidden") end
		Mock.targetCast = {}
		local _, _, _, _, _, _, _, notInt = UnitCastingInfo("target")
		if issecretvalue(notInt) then fail(s, "opts.plain left the cast flag hidden") end
	end, { plain = true })
	with(s, function()
		if issecretvalue(UnitHealth("player")) then fail(s, "Classic Era's health is hidden") end
	end, { flavour = "vanilla" })
end

do
	local s = name("the kit's GetSpellCooldown throws on a nil spell id, as the client does")
	with(s, function()
		local ok = pcall(C_Spell.GetSpellCooldown, nil)
		if ok then fail(s, "a nil spell id was answered") end
	end)
end

-- The name the client gives the Light Feather is feminine in several languages:
-- no translation of "It needs a %s in your bags." puts an article of one gender in front of it.
do
	local s = name("the Light Feather line has no article before the item's name in any language")
	local articles = {
		deDE = { "ein", "eine", "einen" }, esES = { "un", "una" }, frFR = { "un", "une" },
		itIT = { "un", "una", "uno" }, ptBR = { "um", "uma" },
	}
	for locale, list in pairs(articles) do
		local file = io.open(dir .. "/Locales/" .. locale .. ".lua", "rb")
		if not file then
			fail(s, locale .. ": the locale file could not be read")
		else
			local text = file:read("*a")
			file:close()
			local line = text:match('L%["It needs a %%s in your bags%."%] = "([^"\n]*)"')
			if not line then
				fail(s, locale .. ": no translation of the line")
			else
				local before = line:match("^(.-)%%s")
				if not before then
					fail(s, locale .. ": the line does not hold the item's name: " .. line)
				else
					for word in before:gmatch("%S+") do
						for _, article in ipairs(list) do
							if word:lower() == article then fail(s, locale .. ": an article before the name: " .. line) end
						end
					end
				end
			end
		end
	end
end
