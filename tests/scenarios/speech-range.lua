-- The spoken line and the range (beta.8). A macro runs every line even when its
-- /cast fails, so "May the Light watch over you, Munin Hugins." went out over an
-- Arcane Intellect the game refused for range -- twice. The line now goes in
-- only for somebody not known to be out of reach, is dropped at the press when
-- they walked off since the scan, and is held for a while after the game
-- refused a cast on them.
--
-- Every scenario name starts with "speech-range:" so the mutations in
-- tests/mutations/speech-range.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local MUNIN = "Munin Hugins"

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function speaks(text)
	return text ~= nil and text:find("\n/say ", 1, true) ~= nil
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- A session with Munin on a nameplate, owed a favour, and a line to say that
-- always fits. `setup` runs on the profile before the first repaint.
local function session(scenario, setup)
	Mock.reset()
	local restore = H.strangers({ nameplate1 = { "Munin", "Hugins" } })
	local ns = load(scenario)
	if not ns then
		restore()
		return nil
	end
	H.freshPrompt(ns, scenario)
	local speech = ns.db.profile.speech
	speech.enabled = true
	speech.onlyWhenReturning = false
	speech.channel = "SAY"
	speech.phrases = "Thanks, {name}."
	if setup then setup(ns) end
	H.owe(ns, MUNIN)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	return ns, restore
end

-- The entry the scan offers Munin under, as the press would find it.
local function muninEntry(ns)
	return H.inQueue(ns)[MUNIN]
end

-- ------------------------------------------------------------ speech-range-1
-- Known out of range: no line. In range: the line. Unknown (the client will
-- not say): the line, as before, so nobody whose range goes unreported is
-- silenced. Kept on the queue for all three (Only offer in range off), so the
-- range reading is the only thing that changes.
do
	local scenario = "speech-range: the line follows what the scan knows of the range"
	local ns, restore = session(scenario, function(ns)
		ns.db.profile.filters.requireInRange = false
	end)
	if ns then
		local cases = {
			{ "out of range", false, nil, false },
			{ "in range", true, nil, true },
			{ "range unknown", true, { [1459] = true }, true },
			{ "out of range again", false, nil, false },
		}
		for _, case in ipairs(cases) do
			local label, inRange, rangeless, want = case[1], case[2], case[3], case[4]
			Mock.inRange = inRange
			Mock.rangeless = rangeless
			ns.addon:Tick()
			local entry = muninEntry(ns)
			local text = macro(ns)
			if not (entry and text and text:find(MUNIN, 1, true)) then
				fail(scenario, "SKIPPED -- Munin is not armed (" .. label .. "): " .. flat(text))
			elseif speaks(text) ~= want then
				fail(scenario, ("%s (the scan read %s): the macro %s a spoken line: %s"):format(
					label, tostring(entry.ranged), want and "lost" or "kept", flat(text)))
			else
				-- The tooltip quotes what the press will say, and only that.
				local quoted = table.concat(ns.Prompt:ClickSummary(entry), " / ")
				if (quoted:find("Says:", 1, true) ~= nil) ~= want then
					fail(scenario, ("%s: the tooltip %s a line the macro %s: %s"):format(label,
						want and "leaves out" or "quotes", want and "says" or "leaves out", quoted))
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ speech-range-2
-- Armed with the line while Munin was in reach; he walks off before the press.
-- Out of combat PreClick asks again and leaves the line out of what the press
-- runs. In a fight nothing can change the macro, and nothing tries.
do
	local scenario = "speech-range: the press drops the line for somebody who walked off"
	local ns, restore = session(scenario)
	if ns then
		local before = macro(ns)
		if not speaks(before) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(before))
		else
			Mock.inRange = false
			local ran = H.pressButton(ns)
			if not (ran and ran:find("/cast", 1, true) and ran:find(MUNIN, 1, true)) then
				fail(scenario, "SKIPPED -- the press did not cast at Munin: " .. flat(ran))
			elseif speaks(ran) then
				fail(scenario, "the press ran the spoken line at somebody out of range: " .. flat(ran))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

do
	local scenario = "speech-range: in a fight the press leaves the macro alone"
	local ns, restore = session(scenario)
	if ns then
		local before = macro(ns)
		if not speaks(before) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(before))
		else
			Mock.inCombat = true
			Mock.inRange = false
			local ok, ran = pcall(H.pressButton, ns)
			if not ok then
				fail(scenario, "the press threw in a fight: " .. tostring(ran))
			elseif ran ~= before then
				fail(scenario, "the press changed a macro the fight froze: " .. flat(before)
					.. "  ->  " .. flat(ran))
			end
			Mock.inCombat = false
		end
		guarded(scenario, ns)
		restore()
	end
end

-- The same walk-off with somebody else still in reach: the queue is not empty,
-- so the press goes down PreClick's main path, and the panel's held entry
-- (Munin, left the queue a moment ago) carries the range the last scan read.
-- Only the press's own reading can drop the line there.
do
	local scenario = "speech-range: the press asks again for a held entry that walked off"
	Mock.reset()
	local restore = H.strangers({ nameplate1 = { "Munin", "Hugins" }, nameplate2 = { "Ejp", "Ejp" } })
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled = true
		speech.onlyWhenReturning = false
		speech.channel = "SAY"
		speech.phrases = "Thanks, {name}."
		H.owe(ns, MUNIN)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local before = macro(ns)
		local queue = H.inQueue(ns)
		if not (queue[MUNIN] and queue["Ejp Ejp"]) then
			fail(scenario, "SKIPPED -- the queue did not hold both of them")
		elseif not (speaks(before) and before:find(MUNIN, 1, true)) then
			fail(scenario, "SKIPPED -- Munin was not armed with the line: " .. flat(before))
		else
			Mock.rangeByUnit = { nameplate1 = false }
			local after = H.inQueue(ns)
			if after[MUNIN] or not after["Ejp Ejp"] then
				fail(scenario, "SKIPPED -- the queue did not drop Munin and keep Ejp")
			else
				local ran = H.pressButton(ns)
				if not (ran and ran:find("/cast", 1, true) and ran:find(MUNIN, 1, true)) then
					fail(scenario, "SKIPPED -- the press did not go to the held Munin: " .. flat(ran))
				elseif speaks(ran) then
					fail(scenario, "the press ran the spoken line at a held entry out of range: " .. flat(ran))
				end
			end
		end
		guarded(scenario, ns)
	end
	restore()
end

-- ------------------------------------------------------------ speech-range-3
-- The game refuses the cast. The next arming for Munin carries no line, until a
-- cast on him lands or half a minute passes.
local function refuse(ns)
	ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
end

-- The press as the scenarios in scenarios.lua make it, a cast guid on the SENT.
local function pressAndSend(ns, entry, guid)
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:ApplyTarget(entry)
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	if not ns.pendingClick then return false end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, 1459)
	return true
end

-- Munin as the scan would offer him, in reach, so only the refusal can hold
-- the line.
local function inReach(ns)
	local buff = ns.FindBuff("MAGE", "intellect")
	return { name = MUNIN, short = MUNIN, targetName = MUNIN, unit = "nameplate1",
		buff = buff, reason = "owed", ranged = true }
end

for _, ending in ipairs({ "a cast that lands", "half a minute", "neither" }) do
	local scenario = "speech-range: a refusal holds the line until " .. ending
	local ns, restore = session(scenario)
	if ns then
		if not speaks(macro(ns)) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			H.pressButton(ns)
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- the press parked nothing")
			else
				refuse(ns)
				Mock.advance(2.5)
				ns.addon:Tick()
				ns.Prompt:ApplyTarget(inReach(ns))
				local held = macro(ns)
				if speaks(held) then
					fail(scenario, "the next arming after a refusal still speaks: " .. flat(held))
				end
				if ending == "a cast that lands" then
					if not pressAndSend(ns, inReach(ns), "Cast-L") then
						fail(scenario, "SKIPPED -- the second press settled nothing")
					else
						Mock.advance(2.5)
						ns.addon:Tick()
					end
				elseif ending == "half a minute" then
					Mock.advance(31)
					ns.addon:Tick()
				else
					Mock.advance(10)
					ns.addon:Tick()
				end
				ns.Prompt:ApplyTarget(inReach(ns))
				local after = macro(ns)
				local want = ending ~= "neither"
				if speaks(after) ~= want then
					fail(scenario, ("after %s the line is %s: %s"):format(ending,
						want and "still held" or "back already", flat(after)))
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- A press the settle path calls a failure without the game refusing anybody:
-- the /target resolved nobody and the cast went to whoever was targeted, or
-- another spell beat the macro's /cast. The macro's line thanked Munin anyway,
-- so the next arming for him is quiet too.
for _, kind in ipairs({ "went to somebody else", "sent another spell" }) do
	local scenario = "speech-range: a press that " .. kind .. " holds the line"
	local ns, restore = session(scenario)
	if ns then
		local button = ns.Prompt:GetButton()
		Mock.advance(1)
		ns.pendingClick = nil
		ns.Prompt:ApplyTarget(inReach(ns))
		local armed = macro(ns)
		local post = button.scripts.PostClick
		if post then pcall(post, button, "LeftButton", true) end
		if not speaks(armed) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(armed))
		elseif not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press parked nothing")
		else
			if kind == "went to somebody else" then
				ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Some Body", "Cast-E", 1459)
			else
				ns.addon:UNIT_SPELLCAST_SENT(nil, "player", MUNIN, "Cast-E", 116)
			end
			if ns.pendingClick then
				fail(scenario, "SKIPPED -- the settle path did not call it a failure")
			else
				Mock.advance(2.5)
				ns.addon:Tick()
				ns.Prompt:ApplyTarget(inReach(ns))
				local following = macro(ns)
				if speaks(following) then
					fail(scenario, "the next arming still speaks: " .. flat(following))
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ speech-range-4
-- The two ways a line is chosen both answer to the range: "Only when returning
-- a favour" (Munin is owed, so it would speak) and the "In character" set.
for _, how in ipairs({ "only when returning a favour", "in character" }) do
	local scenario = "speech-range: " .. how .. " stays quiet out of range"
	local ns, restore = session(scenario, function(ns)
		ns.db.profile.filters.requireInRange = false
		local speech = ns.db.profile.speech
		if how == "only when returning a favour" then
			speech.onlyWhenReturning = true
		else
			local preset = H.findOption(ns.optionsTable, "preset")
			if preset and preset.set then preset.set({ "preset" }, "incharacter") end
		end
	end)
	if ns then
		if how == "in character" and not (ns.InCharacter and ns.InCharacter.Active(ns.db.profile.speech)) then
			fail(scenario, "SKIPPED -- the In character set did not load")
		else
			Mock.inRange = true
			ns.addon:Tick()
			local near = macro(ns)
			Mock.inRange = false
			ns.addon:Tick()
			local far = macro(ns)
			if not speaks(near) then
				fail(scenario, "SKIPPED -- nothing was said in range either: " .. flat(near))
			elseif speaks(far) then
				fail(scenario, "out of range the line still went in: " .. flat(far))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ speech-range-5
-- "Where to say it" on Party or Raid, and nobody to hear it. The macro ran
-- "/party Thanks, Munin Hugins." solo, on every press: the line reached
-- nobody and the server answered each one with "You aren't in a party."
-- Raid chosen while only in a party is the same. The line goes in once the
-- group is there and comes out when it is left, on the next repaint, and the
-- tooltip quotes it only while it goes in.
local function speaksIn(text, command)
	return text ~= nil and text:find("\n/" .. command .. " ", 1, true) ~= nil
end

for _, channel in ipairs({ "PARTY", "RAID" }) do
	local command = channel:lower()
	local scenario = "speech-range: /" .. command .. " is said only in a " .. command
	local ns, restore = session(scenario, function(ns)
		ns.db.profile.speech.channel = channel
	end)
	if ns then
		-- Solo, then (for /raid) a party that is no raid, then the group the
		-- channel needs, then solo again.
		local steps = {
			{ "solo", 0, nil, false },
		}
		if channel == "RAID" then steps[#steps + 1] = { "in a party, no raid", 2, nil, false } end
		steps[#steps + 1] = { "in a " .. command, 2, channel == "RAID" and { size = 2, player = 1 } or nil, true }
		steps[#steps + 1] = { "the group left", 0, nil, false }
		for _, step in ipairs(steps) do
			local label, size, raid, want = step[1], step[2], step[3], step[4]
			Mock.groupSize, Mock.raid = size, raid
			ns.addon:Tick()
			local entry = muninEntry(ns)
			local text = macro(ns)
			if not (entry and text and text:find(MUNIN, 1, true)) then
				fail(scenario, "SKIPPED -- Munin is not armed (" .. label .. "): " .. flat(text))
			elseif speaksIn(text, command) ~= want then
				fail(scenario, ("%s: the macro %s the /%s line: %s"):format(label,
					want and "lost" or "kept", command, flat(text)))
			else
				local quoted = table.concat(ns.Prompt:ClickSummary(entry), " / ")
				if (quoted:find("Says:", 1, true) ~= nil) ~= want then
					fail(scenario, ("%s: the tooltip %s a line the macro %s: %s"):format(label,
						want and "leaves out" or "quotes", want and "says" or "leaves out", quoted))
				end
			end
		end
		Mock.groupSize, Mock.raid = 0, nil
		guarded(scenario, ns)
		restore()
	end
end

-- The other channels need no group: /say solo still speaks.
do
	local scenario = "speech-range: /say needs no group"
	local ns, restore = session(scenario)
	if ns then
		local text = macro(ns)
		if not speaks(text) then
			fail(scenario, "solo, the /say line is gone: " .. flat(text))
		end
		guarded(scenario, ns)
		restore()
	end
end
