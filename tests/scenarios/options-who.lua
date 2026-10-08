-- The Who to buff tab (BuildWhoTab in Options/Who.lua): four questions, top to
-- bottom -- what to cast, who it goes to (with the group and raid settings
-- under a heading of their own), who comes first, and who is skipped or never
-- offered. Each setting sits under the question it answers and greys out
-- while the switch it narrows is off, so the page reads as a setup rather
-- than a list of knobs.
--
-- Every scenario name starts with "who tab:" so the mutations in
-- tests/mutations/options-who.py can name the one that has to catch them.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption, optionText = H.findOption, H.optionText

local ARCANE_POWDER, SACRED_CANDLE = 17020, 17029
local ITEM_NAMES = { [ARCANE_POWDER] = "Arcane Powder", [SACRED_CANDLE] = "Sacred Candle" }

-- A mage's Arcane Intellect in every rank, and Arcane Brilliance.
local MAGE = { 10157, 10156, 1461, 1460, 1459, 23028 }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Whether a control can be used: AceConfig reads a missing `disabled` as live.
local function live(option)
	return not (type(option.disabled) == "function" and option.disabled())
end

local function shown(option)
	local hidden = option.hidden
	if type(hidden) == "function" then hidden = hidden() end
	return not hidden
end

-- A session as `env` says: the class, the spells known (by id; nil keeps the
-- mock's), and the bags. Everything swapped is handed back by the restore.
local function session(scenario, env)
	Mock.reset()
	Mock.class = env.class or "MAGE"
	local saved = {
		IsSpellKnown = IsSpellKnown, IsPlayerSpell = IsPlayerSpell,
		GetItemCount = rawget(_G, "GetItemCount"), GetItemInfo = rawget(_G, "GetItemInfo"),
	}
	if env.known then
		local known = {}
		for _, id in ipairs(env.known) do known[id] = true end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
	end
	env.bags = env.bags or {}
	rawset(_G, "GetItemCount", function(id) return env.bags[id] or 0 end)
	rawset(_G, "GetItemInfo", function(id)
		if env.unnamed then return nil end
		return ITEM_NAMES[id]
	end)
	local function restore()
		IsSpellKnown, IsPlayerSpell = saved.IsSpellKnown, saved.IsPlayerSpell
		rawset(_G, "GetItemCount", saved.GetItemCount)
		rawset(_G, "GetItemInfo", saved.GetItemInfo)
	end
	local ns = load(scenario)
	if not ns then
		restore()
		return nil
	end
	drive(scenario, ns)
	ns.Guard("probe", ns.ProbeCapabilities)
	return ns, restore
end

local function priestKnown()
	return { 10938, 27841, 10958, 21564, 27681 }
end

-- ------------------------------------------------------------------ who 1
-- The four questions, in order, each control under its own heading, and the
-- headings that went away gone.
do
	local scenario = "who tab: every control sits under the question it answers"
	local ns, restore = session(scenario, { class = "PRIEST", known = priestKnown() })
	if ns then
		local who = ns.optionsTable and ns.optionsTable.args.who
		if not who then
			fail(scenario, "SKIPPED -- no Who to buff tab")
		else
			local a = who.args
			local headers = {
				{ "buffsHeader", "What to cast" }, { "sourcesHeader", "Offer my buff to" },
				{ "groupHeader", "My group and raid" }, { "firstHeader", "Who comes first" },
				{ "skipHeader", "Who to skip" }, { "neverHeader", "Never offer" },
			}
			local sections = {
				buffsHeader = { "choice", "autoNote", "offer_spirit", "relevantOnly", "pinNote" },
				sourcesHeader = { "emptyWarning", "owed", "group", "strangers", "proximity", "restingOnly", "asked" },
				groupHeader = { "groupBuffsUse", "groupBuffsAtLeast", "reagentNote", "skipRaidGroups" },
				firstHeader = { "target", "friends", "readyCheck", "revived" },
				skipHeader = { "minLevel", "requireInRange" },
				neverHeader = { "neverNote", "neverAdd", "neverPick", "neverRemove", "neverClear" },
			}
			for i, h in ipairs(headers) do
				local header = a[h[1]]
				if not header then
					fail(scenario, "the tab has no " .. h[2] .. " heading")
				else
					if header.name ~= h[2] then
						fail(scenario, h[1] .. " reads " .. tostring(header.name) .. ", not " .. h[2])
					end
					local nextHeader = headers[i + 1] and a[headers[i + 1][1]]
					local limit = nextHeader and nextHeader.order or math.huge
					for _, key in ipairs(sections[h[1]]) do
						local option = a[key]
						if not option then
							fail(scenario, key .. " is not on the tab")
						elseif not (option.order > header.order and option.order < limit) then
							fail(scenario, key .. " is not under " .. h[2] .. " (order " .. tostring(option.order) .. ")")
						end
					end
				end
			end
			-- The passer-by settings right under the passer-by switch, and
			-- the per-spell switches before "Skip players it does nothing for".
			if a.proximity and a.strangers and a.restingOnly and a.asked
				and not (a.proximity.order > a.strangers.order and a.restingOnly.order > a.proximity.order
					and a.asked.order > a.restingOnly.order) then
				fail(scenario, "the passer-by settings are not right under Passers-by")
			end
			if a.offer_shadow and a.relevantOnly and a.offer_shadow.order >= a.relevantOnly.order then
				fail(scenario, "the per-spell switches come after Skip players it does nothing for")
			end
			for _, gone in ipairs({ "raidHeader", "proximityNote", "reasonAsked", "owedClassBuffsOnly",
				"manaFloor", "reachableOnly", "graceSeconds" }) do
				if a[gone] then fail(scenario, gone .. " is still on the Who to buff tab") end
			end
		end
		noErrors(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ who 2
-- The dropdown lists Automatic first and the spells in the order their
-- switches are drawn, not sorted by translated name.
do
	local scenario = "who tab: the buff dropdown is in the switches' order"
	local ns, restore = session(scenario, { class = "PRIEST", known = priestKnown() })
	if ns then
		local choice = findOption(ns.optionsTable, "choice")
		if not choice then
			fail(scenario, "SKIPPED -- no buff dropdown")
		else
			local order = type(choice.sorting) == "function" and choice.sorting() or choice.sorting
			local got = type(order) == "table" and table.concat(order, ",") or tostring(order)
			if got ~= "auto,fortitude,spirit,shadow" then
				fail(scenario, "the dropdown's order is " .. got .. ", not Automatic then the switches' order")
			end
			local values = choice.values()
			if values.auto ~= "Automatic (whatever they are missing)" then
				fail(scenario, "Automatic does not say what it does: " .. tostring(values.auto))
			end
			if choice.name ~= "Buff to offer" then
				fail(scenario, "the dropdown is called " .. tostring(choice.name))
			end
		end
		local toggle = findOption(ns.optionsTable, "offer_spirit")
		if not toggle then
			fail(scenario, "SKIPPED -- no per-spell switch")
		elseif optionText(toggle.desc) ~= "Untick to never offer this buff." then
			fail(scenario, "a per-spell switch does not say what unticking it does: " .. optionText(toggle.desc))
		end
		local note = findOption(ns.optionsTable, "autoNote")
		local text = note and optionText(note.name) or ""
		if not text:find("^Automatic may offer, in this order:") then
			fail(scenario, "the note under the dropdown does not open with what Automatic may offer: " .. text)
		end
		noErrors(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ who 3
-- A pin not learned: said in red, pointing at the dropdown by its name.
do
	local scenario = "who tab: an unlearned pick points back at Buff to offer"
	local ns, restore = session(scenario, { class = "PRIEST", known = { 10938 } })
	if ns then
		ns.db.profile.buff.choice = "shadow"
		local pinNote = findOption(ns.optionsTable, "pinNote")
		if not (pinNote and ns.PinnedBuff and ns.PinnedBuff()) then
			fail(scenario, "SKIPPED -- no pin to explain")
		else
			local text = optionText(pinNote.name)
			if not text:find("|cffff8080You picked", 1, true) then
				fail(scenario, "the warning does not open, in red, with what was picked: " .. text)
			end
			if not text:find("set Buff to offer back to Automatic", 1, true) then
				fail(scenario, "the warning does not say how to undo it: " .. text)
			end
		end
		ns.db.profile.buff.choice = "auto"
		noErrors(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ who 4
-- The passer-by settings follow the passer-by switch, and the distances say
-- roughly how far they are.
do
	local scenario = "who tab: the passer-by settings follow Passers-by"
	local ns, restore = session(scenario, {})
	if ns then
		local proximity = findOption(ns.optionsTable, "proximity")
		local resting = findOption(ns.optionsTable, "restingOnly")
		if not (proximity and resting) then
			fail(scenario, "SKIPPED -- no passer-by settings")
		else
			ns.db.profile.sources.strangers = true
			if not (live(proximity) and live(resting)) then
				fail(scenario, "a passer-by setting is greyed out with Passers-by on")
			end
			ns.db.profile.sources.strangers = false
			if live(proximity) then
				fail(scenario, "the distance stays live with Passers-by off")
			end
			if live(resting) then
				fail(scenario, "cities and inns stays live with Passers-by off")
			end
			ns.db.profile.sources.strangers = true
			local values = proximity.values()
			if values.cast ~= "Anywhere I can cast (about 30 yards)" then
				fail(scenario, "the distances do not say roughly how far: " .. tostring(values.cast))
			end
			local order = proximity.sorting()
			if order[1] ~= "cast" or order[#order] ~= "beside" then
				fail(scenario, "the distances are not loosest to tightest")
			end
		end
		noErrors(scenario, ns)
		restore()
	end

	-- A warrior's shout reaches nobody outside his party: the switch and both
	-- settings are hidden, and one grey line says why.
	local scenario2 = "who tab: a warrior is not shown passer-by settings"
	local ns2, restore2 = session(scenario2, { class = "WARRIOR", known = { 6673 } })
	if ns2 then
		for _, key in ipairs({ "strangers", "proximity", "restingOnly" }) do
			local option = findOption(ns2.optionsTable, key)
			if option and shown(option) then
				fail(scenario2, key .. " is shown to a warrior")
			end
		end
		local owed = findOption(ns2.optionsTable, "owed")
		if owed and not optionText(owed.desc):find("once they join", 1, true) then
			fail(scenario2, "People who buff me does not tell a warrior outsiders wait until they join: "
				.. optionText(owed.desc))
		end
		noErrors(scenario2, ns2)
		restore2()
	end
end

-- ------------------------------------------------------------------ who 5
-- Each switch greys out while what it depends on is off: the target under
-- Always offer, the raid groups without My party and raid.
do
	local scenario = "who tab: switches grey out while they cannot do anything"
	local ns, restore = session(scenario, {})
	if ns then
		local target = findOption(ns.optionsTable, "target")
		local raidGroups = findOption(ns.optionsTable, "skipRaidGroups")
		if not (target and raidGroups) then
			fail(scenario, "SKIPPED -- no target or raid group setting")
		else
			ns.db.profile.filters.whenBuffed = "skip"
			if not live(target) then
				fail(scenario, "My target first is greyed out when buffs are read")
			end
			ns.db.profile.filters.whenBuffed = "always"
			if live(target) then
				fail(scenario, "My target first stays live under Always offer")
			end
			ns.db.profile.filters.whenBuffed = "skip"
			ns.db.profile.sources.group = true
			if not live(raidGroups) then
				fail(scenario, "the raid groups are greyed out with My party and raid on")
			end
			ns.db.profile.sources.group = false
			if live(raidGroups) then
				fail(scenario, "the raid groups stay live with My party and raid off")
			end
			ns.db.profile.sources.group = true
		end
		noErrors(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ who 6
-- The reagent line: how many are in the bags, in red when none, shown only
-- while group buffs can be offered at all.
do
	local scenario = "who tab: the reagent line counts the bags"
	local env = { known = MAGE, bags = { [ARCANE_POWDER] = 20 } }
	local ns, restore = session(scenario, env)
	if ns then
		local note = findOption(ns.optionsTable, "reagentNote")
		if not note then
			fail(scenario, "SKIPPED -- no reagent line")
		else
			ns.db.profile.sources.group = true
			ns.db.profile.groupBuffs.use = true
			if not shown(note) then
				fail(scenario, "the reagent line is hidden with group buffs on")
			end
			local text = optionText(note.name)
			if text ~= "Arcane Powder: 20 in your bags" then
				fail(scenario, "the reagent line does not count the bags: " .. text)
			end
			env.bags[ARCANE_POWDER] = 0
			text = optionText(note.name)
			if not text:find("|cffff8080Arcane Powder: none in your bags, so group buffs are not offered.", 1, true) then
				fail(scenario, "an empty bag is not said in red: " .. text)
			end
			env.bags[ARCANE_POWDER] = 20
			env.unnamed = true
			text = optionText(note.name)
			if not text:find(tostring(ARCANE_POWDER), 1, true) then
				fail(scenario, "a reagent the client has not named yet is not given by its id: " .. text)
			end
			env.unnamed = nil

			ns.db.profile.groupBuffs.use = false
			if shown(note) then
				fail(scenario, "the reagent line is shown with group buffs off")
			end
			ns.db.profile.groupBuffs.use = true
			ns.db.profile.sources.group = false
			if shown(note) then
				fail(scenario, "the reagent line is shown with My party and raid off")
			end
			ns.db.profile.sources.group = true

			-- Anything that throws while the line is read leaves the page up.
			local realInfo = ns.BuffInfo
			ns.BuffInfo = function() error("boom") end
			local ok, said = pcall(note.name)
			ns.BuffInfo = realInfo
			if not ok then
				fail(scenario, "the reagent line threw: " .. tostring(said))
			end
		end
		noErrors(scenario, ns)
		restore()
	end

	-- A priest's three Prayers share one candle: one line, not three.
	local scenario2 = "who tab: one line per reagent"
	local ns2, restore2 = session(scenario2, { class = "PRIEST", known = priestKnown(),
		bags = { [SACRED_CANDLE] = 7 } })
	if ns2 then
		local note = findOption(ns2.optionsTable, "reagentNote")
		if not note then
			fail(scenario2, "SKIPPED -- no reagent line")
		else
			local text = optionText(note.name)
			if text ~= "Sacred Candle: 7 in your bags" then
				fail(scenario2, "the candles are not said once: " .. text)
			end
		end
		noErrors(scenario2, ns2)
		restore2()
	end

	-- A class with no group version is not shown the line at all.
	local scenario3 = "who tab: no reagent line for a class without group buffs"
	local ns3, restore3 = session(scenario3, { class = "WARLOCK", known = { 5697 } })
	if ns3 then
		local note = findOption(ns3.optionsTable, "reagentNote")
		if note and shown(note) then
			fail(scenario3, "a warlock is shown a reagent line")
		end
		noErrors(scenario3, ns3)
		restore3()
	end
end

-- ------------------------------------------------------------------ who: one spell
-- One spell to give is not a choice: the dropdown and Automatic's list are
-- replaced by one line saying which spell, the rule the per-spell switches
-- already follow. A pin brings the dropdown back, as the way to Automatic.
do
	local scenario = "who tab: a class with one spell is not asked to choose"
	local ns, restore = session(scenario, { class = "MAGE", known = MAGE })
	if ns then
		local choice, note = findOption(ns.optionsTable, "choice"), findOption(ns.optionsTable, "autoNote")
		if shown(choice) then
			fail(scenario, "a mage is offered Buff to offer, with nothing to choose between")
		end
		local text = optionText(note.name)
		if not shown(note) or not text:find("You offer ", 1, true) or not text:find("Arcane Intellect", 1, true)
			or text:find("Automatic", 1, true) then
			fail(scenario, "a mage is not told the one spell they offer: " .. text)
		end
		ns.db.profile.buff.choice = "intellect"
		if not shown(choice) then
			fail(scenario, "a mage with a pin has no way back to Automatic")
		end
		ns.db.profile.buff.choice = "auto"
		noErrors(scenario, ns)
		restore()
	end

	local scenario2 = "who tab: a priest still chooses between spells"
	local ns2, restore2 = session(scenario2, { class = "PRIEST", known = priestKnown() })
	if ns2 then
		local choice, note = findOption(ns2.optionsTable, "choice"), findOption(ns2.optionsTable, "autoNote")
		if not shown(choice) then
			fail(scenario2, "a priest is not offered Buff to offer")
		end
		if not optionText(note.name):find("Automatic may offer", 1, true) then
			fail(scenario2, "a priest is not told what Automatic offers: " .. optionText(note.name))
		end
		noErrors(scenario2, ns2)
		restore2()
	end
end

-- ------------------------------------------------------------------ who: mana-only
-- The tooltip names the class's own mana-only spells, never another class's,
-- and the switch is not shown to a class with none, where it does nothing.
do
	local scenario = "who tab: Skip players it does nothing for names this class's spells"
	local ns, restore = session(scenario, { class = "MAGE", known = MAGE })
	if ns then
		local toggle = findOption(ns.optionsTable, "relevantOnly")
		local desc = optionText(toggle.desc)
		if not shown(toggle) or not desc:find("Arcane Intellect is not offered", 1, true)
			or desc:find("Divine Spirit", 1, true) then
			fail(scenario, "a mage's tooltip reads " .. desc)
		end
		noErrors(scenario, ns)
		restore()
	end

	local scenario2 = "who tab: no mana-only switch for a class without mana-only spells"
	local ns2, restore2 = session(scenario2, { class = "WARRIOR", known = { 6673 } })
	if ns2 then
		local toggle = findOption(ns2.optionsTable, "relevantOnly")
		if toggle and shown(toggle) then
			fail(scenario2, "a warrior is shown Skip players it does nothing for, which does nothing for him")
		end
		noErrors(scenario2, ns2)
		restore2()
	end
end
