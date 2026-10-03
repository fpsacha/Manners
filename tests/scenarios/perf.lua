-- What the scan remembers between two ticks, and that each of those memories
-- gives way the moment the thing it remembers changes.
--
-- The scan runs two and a half times a second over everybody in front of the
-- player, and tools/profile_scan.py found it doing the same work every time:
-- walking the whole never-offer list with a case-folded compare for every
-- person, building the same block keys, making closures and option tables per
-- person. What replaced that keeps answers -- and an answer kept past the
-- moment it stopped being true is a person offered who should not be, or not
-- offered who should. Each scenario here changes the one thing a kept answer
-- depends on, between two scans with no time passing where time does not
-- matter, and requires the next answer to follow it.
--
-- Called by scenarios.lua with the addon directory and its helpers. Globals a
-- scenario replaces are put back by `with`, whether it finished or threw.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe
local inQueue, knowShout = H.inQueue, H.knowShout

local TOUCHED = { "strcmputf8i", "UnitExists", "C_FriendList", "IsSpellKnown", "IsPlayerSpell",
	"GetNumGroupMembers", "IsInRaid" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local function with(scenario, body)
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Every id Arcane Intellect is read under, so a stranger can be carrying it.
local function intellectIds(ns)
	local held = {}
	for _, id in ipairs(ns.FindBuff("MAGE", "intellect").auraIds) do held[id] = true end
	return held
end

-- ------------------------------------------------------------------ perf 1
-- The never-offer list, edited straight into the profile, is honoured by the
-- very next scan.
--
-- The scan keeps what it has worked out about each name and checks the list
-- against a copy of it once a scan. The edits here are the ones the check has
-- to see and a cheaper one would not: a name added, one taken off, and one
-- swapped for another, which leaves the list the same length. Straight into
-- the table, because an import, a profile switch and the options all put a
-- list there without passing through NeverOffer.
Mock.reset()
do
	local scenario = "the never-offer list edited behind the queue is honoured at once"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local never = ns.db.profile.never
		-- Somebody nobody here answers to, so the list is never empty: an empty
		-- list is answered before anything kept is consulted.
		never["Nobody Here"] = true

		local q = inQueue(ns)
		if not (q["Anna Aim"] and q["Bert Beside"]) then
			fail(scenario, "SKIPPED -- the two strangers were not both offered to begin with")
			return
		end
		-- In another case, so only the case-folded walk can match it.
		never["anna aim"] = true
		q = inQueue(ns)
		if q["Anna Aim"] then fail(scenario, "a name added to the list was still offered") end
		if not q["Bert Beside"] then fail(scenario, "adding one name dropped somebody else") end

		never["anna aim"] = nil
		never["bert beside"] = true
		q = inQueue(ns)
		if not q["Anna Aim"] then
			fail(scenario, "a name swapped off the list, leaving it the same length, was still"
				.. " turned away")
		end
		if q["Bert Beside"] then
			fail(scenario, "a name swapped onto the list, leaving it the same length, was still"
				.. " offered")
		end

		never["bert beside"] = nil
		q = inQueue(ns)
		if not q["Bert Beside"] then fail(scenario, "a name taken off the list was still turned away") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ perf 2
-- What the list's answers were worked out with is part of them.
--
-- A name matches an entry in another case through the client's strcmputf8i
-- where there is one. An answer kept from one compare and served under another
-- is an answer to a different question -- so a different compare throws them
-- away. The one below says no to everything, which is what a compare that has
-- stopped folding case looks like from here.
--
-- The name holds an accented capital, written as its bytes: two names in A to
-- Z are compared by string.lower alone, which folds them all, so only a name
-- in another script asks the client's compare at all.
Mock.reset()
do
	local scenario = "a different name compare throws the never-offer answers away"
	local ANNA = "\195\129nna Aim"
	local restoreUnits = strangers({ nameplate1 = { "\195\129nna", "Aim" } })
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		-- The client's compare, folding the one capital in play as well.
		strcmputf8i = function(a, b)
			a = a:gsub("\195\129", "\195\161"):lower()
			b = b:gsub("\195\129", "\195\161"):lower()
			if a == b then return 0 end
			return a < b and -1 or 1
		end
		freshPrompt(ns, scenario)
		ns.db.profile.never["\195\161nna aim"] = true
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- a name listed in another case was offered to begin with")
			return
		end
		strcmputf8i = function() return 1 end
		if not inQueue(ns)[ANNA] then
			fail(scenario, "the list was matched with the compare the client no longer has")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ perf 3
-- Anybody asking about the list between two scans gets the list, not the last
-- scan's answers.
--
-- The scan's answers are handed to ns.IsNeverOffered for the length of its walk
-- over the units, and the prompt, the tooltip and the options page ask the same
-- function at other moments -- straight after somebody has been put on the list
-- among them. The list is edited here with no time passing at all, in another
-- case so the exact-name shortcut cannot answer for it; and once more after a
-- scan that threw part-way through its walk, which is the one way out of a
-- walk that skips the code after it.
Mock.reset()
do
	local scenario = "the never-offer list asked between scans reads the list"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local never = ns.db.profile.never
		never["Nobody Here"] = true

		if not inQueue(ns)["Anna Aim"] then
			fail(scenario, "SKIPPED -- the stranger was not offered to begin with")
			return
		end
		never["anna aim"] = true
		if not ns.IsNeverOffered("Anna Aim") then
			fail(scenario, "a name put on the list after a scan was answered from that scan")
		end

		-- A scan whose walk throws.
		never["anna aim"] = nil
		if not inQueue(ns)["Anna Aim"] then
			fail(scenario, "SKIPPED -- the stranger was not offered again once taken off")
			return
		end
		local exists = UnitExists
		UnitExists = function(unit)
			if unit == "player" then return true end
			error("the client fell over", 0)
		end
		local ok = pcall(ns.BuildQueue)
		UnitExists = exists
		if ok then
			fail(scenario, "SKIPPED -- the walk did not throw")
			return
		end
		never["anna aim"] = true
		if not ns.IsNeverOffered("Anna Aim") then
			fail(scenario, "a scan that threw left its answers behind for the next question")
		end
		if inQueue(ns)["Anna Aim"] then
			fail(scenario, "a scan that threw left its answers behind for the next scan")
		end
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ perf 4
-- A block is read the moment it is written, one buff at a time.
--
-- The keys a block is filed under are built once per person and kept. One
-- person's key for one buff must never answer for another buff, nor for
-- another person, and a table with nothing in it answers "not blocked" without
-- building anything -- so the moment it has something in it again, that has
-- to be read. Written through the two functions that write blocks, and once
-- straight into the table the way the settle path's tests do.
Mock.reset()
do
	local scenario = "a block is read the moment it is written, buff by buff"
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		wipe(ns.tried)
		if ns.IsBlocked("Anna Aim", "fortitude") or ns.IsBlocked("Anna Aim") then
			fail(scenario, "somebody was blocked with nothing written")
		end
		ns.MarkAttempted("Anna Aim", "fortitude", 5)
		if not ns.IsBlocked("Anna Aim", "fortitude") then
			fail(scenario, "a block just written for one buff was not read")
		end
		if ns.IsBlocked("Anna Aim", "spirit") then
			fail(scenario, "a block on one buff answered for another buff")
		end
		if ns.IsBlocked("Anna Aim") then
			fail(scenario, "a block on one buff answered for the whole person")
		end
		if ns.IsBlocked("Bert Beside", "fortitude") then
			fail(scenario, "a block on one person answered for another")
		end
		ns.BlockPerson("Bert Beside", 5)
		if not (ns.IsBlocked("Bert Beside") and ns.IsBlocked("Bert Beside", "spirit")) then
			fail(scenario, "a whole-person block was not read for them and for each buff")
		end
		ns.tried["Anna Aim\0spirit"] = GetTime() + 5
		if not ns.IsBlocked("Anna Aim", "spirit") then
			fail(scenario, "a block written straight into the table was not read")
		end
		Mock.advance(6)
		if ns.IsBlocked("Anna Aim", "fortitude") or ns.IsBlocked("Bert Beside") then
			fail(scenario, "a block was still read after it ran out")
		end
		wipe(ns.tried)
		ns.MarkAttempted("Anna Aim", "fortitude", 5)
		if not ns.IsBlocked("Anna Aim", "fortitude") then
			fail(scenario, "a block written after the table emptied was not read")
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ perf 5
-- What the walk is told about one person is not carried to the next.
--
-- One table of options is filled in for each person the scan reaches, rather
-- than one made for each of them. Anything not written for somebody is left
-- over from whoever came before: here the target, reached first on every scan,
-- is owed a favour and so offered the buff they already carry -- and the
-- passer-by after them, carrying it too and owed nothing, must not be.
Mock.reset()
do
	local scenario = "one person's favour is not carried to the next person"
	local restoreUnits = strangers({ target = { "Anna", "Aim" }, nameplate1 = { "Bert", "Beside" } })
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.held = intellectIds(ns)
		owe(ns, "Anna Aim")
		local q = inQueue(ns)
		if not q["Anna Aim"] then
			fail(scenario, "SKIPPED -- the owed target was not offered")
		elseif q["Bert Beside"] then
			fail(scenario, "a passer-by who already carries the buff was offered it after"
				.. " somebody who was owed one")
		end
		Mock.held = nil
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ perf 6
-- A reading of somebody's buffs, once it is old, is taken again and believed.
--
-- The aura cache holds a reading for three seconds and then rewrites that
-- reading where it stands instead of replacing it. The rewrite has to carry
-- everything the new reading said: a buff that ran out makes them somebody to
-- offer, and one that arrived makes them somebody not to.
Mock.reset()
do
	local scenario = "an old reading of somebody's buffs is replaced by a new one"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.held = intellectIds(ns)
		if inQueue(ns)["Anna Aim"] then
			fail(scenario, "SKIPPED -- somebody carrying the buff was offered it")
			return
		end
		-- Asked twice each time: once when the reading is taken again, and once
		-- a moment later, when it is the kept reading that answers.
		Mock.held = nil
		Mock.advance(3.5)
		if not inQueue(ns)["Anna Aim"] then
			fail(scenario, "somebody whose buff ran out was still read as carrying it")
		end
		Mock.advance(0.5)
		if not inQueue(ns)["Anna Aim"] then
			fail(scenario, "somebody whose buff ran out was read as carrying it again from"
				.. " the kept reading")
		end
		Mock.held = intellectIds(ns)
		Mock.advance(3.5)
		if inQueue(ns)["Anna Aim"] then
			fail(scenario, "somebody who has since been buffed was still read as missing it")
		end
		Mock.advance(0.5)
		if inQueue(ns)["Anna Aim"] then
			fail(scenario, "somebody who has since been buffed was read as missing it again"
				.. " from the kept reading")
		end
		Mock.held = nil
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ perf 7
-- A friend added -- or taken off -- is ranked accordingly once the last answer
-- about them runs out.
--
-- "Who comes first" keeps each person's answer for ten seconds and then asks
-- again. The old answers are swept away once per ten seconds now rather than
-- on every scan, so one that has run out can still be standing in the table
-- when the person is asked about -- and it must be asked again, not read.
Mock.reset()
do
	local scenario = "a friend added is ranked as one once the answer runs out"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	with(scenario, function()
		local friends = {}
		C_FriendList = { IsFriend = function(guid) return friends[guid] == true end }
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.priority.friends = true
		local q = inQueue(ns)
		if not q["Anna Aim"] or q["Anna Aim"].close ~= nil then
			fail(scenario, "SKIPPED -- the stranger was not offered, or was already a friend")
			return
		end
		friends["Player-1-nameplate1"] = true
		Mock.advance(11)
		q = inQueue(ns)
		if not (q["Anna Aim"] and q["Anna Aim"].close == "friend") then
			fail(scenario, "a friend added was not ranked as one after the answer ran out: "
				.. tostring(q["Anna Aim"] and q["Anna Aim"].close))
		end
		friends["Player-1-nameplate1"] = nil
		Mock.advance(11)
		q = inQueue(ns)
		if q["Anna Aim"] and q["Anna Aim"].close ~= nil then
			fail(scenario, "a friend taken off the list was still ranked as one")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ perf 8
-- The group, read once a scan, follows the group from one scan to the next.
--
-- Whether the player is in a raid used to be asked for every person a shout
-- was judged for, and is asked once a scan now. A warrior's shout reaches the
-- party and, in a raid, the warrior's own subgroup: a member of the party
-- stops being offered it the moment the party becomes a raid that puts them in
-- another subgroup, and is offered it again when it goes back.
Mock.reset()
do
	local scenario = "a shout follows the group from a party to a raid and back"
	Mock.class = "WARRIOR"
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		knowShout(ns)
		freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.profile.filters.requireInRange = false

		Mock.groupSize = 2
		Mock.unitNames = { party1 = { "Gus", "Group" }, raid7 = { "Gus", "Group" } }
		local function gusOffered()
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.name == "Gus Group" then return true end
			end
			return false
		end
		if not gusOffered() then
			fail(scenario, "SKIPPED -- the party member was not offered the shout")
			return
		end
		Mock.raid = { size = 10, player = 1 }
		if gusOffered() then
			fail(scenario, "a raider in another subgroup was offered the shout the scan after"
				.. " the party became a raid")
		end
		Mock.raid = nil
		if not gusOffered() then
			fail(scenario, "the party member was not offered the shout again once the raid"
				.. " was a party")
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ perf 9
-- A spell learned between two scans is offered on the next one.
--
-- What the player can cast is worked out once a scan and handed to everything
-- in it that needs to know, rather than kept: the spellbook changes under the
-- scan when a spell is learned, and a list kept across scans would go on
-- offering yesterday's.
Mock.reset()
do
	local scenario = "a spell learned between scans is offered on the next"
	Mock.class = "PRIEST"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		local known = {}
		for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do known[id] = true end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		freshPrompt(ns, scenario)
		local held = {}
		for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").auraIds) do held[id] = true end
		Mock.held = held
		if inQueue(ns)["Anna Aim"] then
			fail(scenario, "SKIPPED -- somebody carrying the only buff known was offered it")
			return
		end
		for _, id in ipairs(ns.FindBuff("PRIEST", "shadow").ranks) do known[id] = true end
		Mock.advance(10)
		ns.addon:SPELLS_CHANGED()
		local anna = inQueue(ns)["Anna Aim"]
		if not (anna and anna.buff.key == "shadow") then
			fail(scenario, "a spell learned since the last scan was not offered: "
				.. tostring(anna and anna.buff.key))
		end
		Mock.held = nil
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ perf 10
-- Each favour from somebody out of sight is judged on its own class.
--
-- The favours from people the scan holds no token for share one table of
-- options, as the people it does see share another. Class is all that path has
-- to go on, so it is the thing that must be written for each of them: a
-- warrior who buffed a mage is offered nothing -- intellect does nothing for
-- them -- while a priest who did the same is offered it.
Mock.reset()
do
	local scenario = "each favour out of sight is judged on its own class"
	local restoreUnits = strangers({})
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.filters.relevantOnly = true
		local now = GetTime()
		ns.owed["Wes Warrior"] = { expires = now + 100, at = now, class = "WARRIOR" }
		ns.owed["Pia Priest"] = { expires = now + 100, at = now, class = "PRIEST" }
		local q = inQueue(ns)
		if not q["Pia Priest"] then
			fail(scenario, "SKIPPED -- the priest who buffed you out of sight was not offered")
		elseif q["Wes Warrior"] then
			fail(scenario, "a warrior who buffed you out of sight was offered intellect")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ perf 11
-- ns.Swap, which the prompt's repaint asks about seventeen times, answers a
-- line without its token straight away and makes nothing to answer it, and
-- reads neither the line nor the value as a pattern: a reason line typed as
-- "10% left" and a name with "%1" in it come through as typed.
Mock.reset()
do
	local scenario = "ns.Swap swaps only its token, and reads nothing as a pattern"
	with(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		local Swap = ns.Swap
		if Swap(nil, "{name}", "Anna") ~= "" then
			fail(scenario, "no line at all did not come back empty: " .. tostring(Swap(nil, "{name}", "Anna")))
		end
		local line = "Buff them -- 10% left"
		if Swap(line, "{name}", "Anna") ~= line then
			fail(scenario, "a line without the token came back changed: " .. tostring(Swap(line, "{name}", "Anna")))
		end
		local said = Swap("{name} has {time}", "{time}", "10%")
		if said ~= "{name} has 10%" then
			fail(scenario, "a value with % in it was not put in as typed: " .. tostring(said))
		end
		said = Swap("Thanks, {name}!", "{name}", "%1")
		if said ~= "Thanks, %1!" then
			fail(scenario, "a value reading like a capture was not put in as typed: " .. tostring(said))
		end
		said = Swap(Swap("{name}: {buff}, {name}", "{name}", "Anna"), "{buff}", "Arcane Intellect")
		if said ~= "Anna: Arcane Intellect, Anna" then
			fail(scenario, "two tokens in one line were not both swapped: " .. tostring(said))
		end
		if Swap("{name}", "{name}", nil) ~= "" then
			fail(scenario, "no value did not swap the token for nothing")
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()
