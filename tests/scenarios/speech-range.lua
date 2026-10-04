-- The spoken line and the range (beta.8). A macro runs every line even when its
-- /cast fails, so "May the Light watch over you, Munin Hugins." went out over an
-- Arcane Intellect the game refused for range -- twice. The line now goes in
-- only for somebody the scan measured in reach, goes out with a press only when
-- that press is known to land (speech-range-6), and is held for a while after
-- the game refused a cast on them.
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
-- not say): no line either. It used to keep the line, so nobody whose range
-- went unreported was silenced, and that is how a thank-you went out over
-- "Out of range." (speech-range-6): a line goes only with a press known to
-- land, and the tooltip quotes it only then. Kept on the queue throughout
-- (Only offer in range off), so the range reading is the only thing that
-- changes.
do
	local scenario = "speech-range: the line follows what the scan knows of the range"
	local ns, restore = session(scenario, function(ns)
		ns.db.profile.filters.requireInRange = false
	end)
	if ns then
		local cases = {
			{ "out of range", false, nil, false },
			{ "in range", true, nil, true },
			{ "range unknown", true, { [1459] = true }, false },
			{ "in range again", true, nil, true },
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

-- ------------------------------------------------------------ speech-range-6
-- In game, on one press: "Manners: Weirbeard Jenkins was not buffed -- the
-- game said: Out of range." and "[S] Mort Defrette: The Light already likes
-- you, Weirbeard Jenkins. Consider this a second opinion." The press asked
-- the range again only through a token still naming him. With none -- the
-- cursor gone from him to the prompt, a token handed to somebody else -- or a
-- reading the client would not give, the line went out over a cast the game
-- refused. The author's rule: "if i cant buff someone, i should not say
-- anything". Out of combat the line now goes in only for a press known to
-- land: a token naming him now, alive, in reach, the cooldowns over, the spell
-- usable. The cast itself goes out either way.
local WEIRBEARD = "Weirbeard Jenkins"
local SECOND_OPINION = "The Light already likes you, {name}. Consider this a second opinion."

-- A passer-by session, nobody owed: `units` says who holds which token, and
-- `setup` runs on the profile before the first repaint.
local function passing(scenario, units, setup)
	Mock.reset()
	local restore = H.strangers(units)
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
	speech.phrases = SECOND_OPINION
	-- Your own Intellect would take the panel once the queue empties, where
	-- the press is meant to stay on him.
	ns.db.profile.sources.self = false
	if setup then setup(ns) end
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	return ns, restore
end

-- One press a moment after the last, and whether it cast at him and spoke.
local function pressAt(ns)
	Mock.advance(1)
	local ran = H.pressButton(ns)
	local cast = ran ~= nil and ran:find("/target " .. WEIRBEARD, 1, true) ~= nil
		and ran:find("\n/cast ", 1, true) ~= nil
	return ran, cast, speaks(ran)
end

-- The author's press, each way it could not see him: the cursor gone from him
-- to the prompt as he walked off, a range the client will not read, and a
-- favour returned to somebody no token holds. `before` runs before the first
-- repaint, `after` between it and the press.
local UNSEEN = {
	{ "the cursor left him for the prompt", { mouseover = { "Weirbeard", "Jenkins" } }, nil,
		function()
			Mock.unitNames.mouseover = nil
			Mock.inRange = false
		end },
	{ "his range unread", { nameplate1 = { "Weirbeard", "Jenkins" } },
		function() Mock.rangeless = { [1459] = true } end, nil },
	{ "a favour, no token", {},
		function(ns) H.owe(ns, WEIRBEARD) end, nil },
}
for _, case in ipairs(UNSEEN) do
	local label, units, before, after = case[1], case[2], case[3], case[4]
	local scenario = "speech-range: no line for a press that cannot see him (" .. label .. ")"
	local ns, restore = passing(scenario, units, before)
	if ns then
		if after then after(ns) end
		local ran, cast, said = pressAt(ns)
		if not cast then
			fail(scenario, "SKIPPED -- the press did not cast at Weirbeard: " .. flat(ran))
		elseif said then
			fail(scenario, "the press thanked somebody it could not see: " .. flat(ran))
		end
		guarded(scenario, ns)
		restore()
	end
end

-- In reach, alive, nothing cooling down: the line goes, as it always did.
do
	local scenario = "speech-range: the line goes with a press that lands"
	local ns, restore = passing(scenario, { nameplate1 = { "Weirbeard", "Jenkins" } })
	if ns then
		local ran, cast, said = pressAt(ns)
		if not cast then
			fail(scenario, "SKIPPED -- the press did not cast at Weirbeard: " .. flat(ran))
		elseif not said then
			fail(scenario, "in reach, alive, nothing cooling down, and the press said nothing: " .. flat(ran))
		end
		guarded(scenario, ns)
		restore()
	end
end

-- Walked off between the scan and the press: the fresh queue lets him go, the
-- fuse keeps the press on him, and it casts without the line. The cast is part
-- of the claim: leaving the line out must never take the press with it.
do
	local scenario = "speech-range: out of reach at the press, the cast goes without the line"
	local ns, restore = passing(scenario, { nameplate1 = { "Weirbeard", "Jenkins" } })
	if ns then
		if not speaks(macro(ns)) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			Mock.rangeByUnit = { nameplate1 = false }
			local ran, cast, said = pressAt(ns)
			if not cast then
				fail(scenario, "the press was dropped with the line: " .. flat(ran))
			elseif said then
				fail(scenario, "the press spoke to somebody out of reach: " .. flat(ran))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- The token the scan found him by, handed to somebody else before the press.
do
	local scenario = "speech-range: no line through a token recycled to somebody else"
	local ns, restore = passing(scenario, { nameplate1 = { "Weirbeard", "Jenkins" } })
	if ns then
		if not speaks(macro(ns)) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			Mock.unitNames.nameplate1 = { "Ejp", "Ejp" }
			local ran, cast, said = pressAt(ns)
			if not cast then
				fail(scenario, "SKIPPED -- the press did not stay on Weirbeard: " .. flat(ran))
			elseif said then
				fail(scenario, "the press spoke to him through a token naming Ejp Ejp now: " .. flat(ran))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- Targeted, then the player targets somebody else. The hold keeps him on the
-- panel a moment, so the press goes to the entry the last scan made, whose
-- token ("target") names Ejp Ejp now -- in reach, alive, and not him.
do
	local scenario = "speech-range: no line through your target, retargeted to somebody else"
	local ns, restore = passing(scenario, { target = { "Weirbeard", "Jenkins" } })
	if ns then
		if not speaks(macro(ns)) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			Mock.unitNames.target = { "Ejp", "Ejp" }
			local ran, cast, said = pressAt(ns)
			if not cast then
				fail(scenario, "SKIPPED -- the hold did not keep the press on Weirbeard: " .. flat(ran))
			elseif said then
				fail(scenario, "the press spoke to him through your target, which is Ejp Ejp now: " .. flat(ran))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- The same, with him still on a nameplate, twenty yards off: too far to be
-- offered as a passer-by, so the hold's entry is the only one there is, and
-- well inside the spell's reach. The press finds him there by name, and says
-- the line if that token reads him in reach -- not if its reading is withheld.
for _, unread in ipairs({ false, true }) do
	local scenario = "speech-range: the press follows him to another token ("
		.. (unread and "range unread there" or "in reach") .. ")"
	local ns, restore = passing(scenario, {
		target = { "Weirbeard", "Jenkins" }, nameplate2 = { "Weirbeard", "Jenkins" } }, function()
		Mock.yards = { nameplate2 = 20 }
	end)
	if ns then
		local entry = H.inQueue(ns)[WEIRBEARD]
		if not (entry and entry.unit == "target" and speaks(macro(ns))) then
			fail(scenario, "SKIPPED -- Weirbeard is not armed with the line through your target: "
				.. flat(macro(ns)))
		else
			Mock.unitNames.target = { "Ejp", "Ejp" }
			if unread then Mock.rangeless = { [1459] = true } end
			local ran, cast, said = pressAt(ns)
			if not cast then
				fail(scenario, "SKIPPED -- the hold did not keep the press on Weirbeard: " .. flat(ran))
			elseif said == unread then
				fail(scenario, unread
					and ("the press spoke on a range the client would not read: " .. flat(ran))
					or ("the press lost him when your target moved, though a nameplate holds him: "
						.. flat(ran)))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- Whether he is alive, unread: a corpse is in range too, so the line waits
-- for the client's word.
do
	local scenario = "speech-range: no line for somebody whose life the client will not read"
	local ns, restore = passing(scenario, { nameplate1 = { "Weirbeard", "Jenkins" } })
	if ns then
		if not speaks(macro(ns)) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			local real = rawget(_G, "UnitIsDeadOrGhost")
			rawset(_G, "UnitIsDeadOrGhost", function(unit)
				if unit == "nameplate1" then return nil end
				return real(unit)
			end)
			local ok, ran, cast, said = pcall(pressAt, ns)
			rawset(_G, "UnitIsDeadOrGhost", real)
			if not ok then
				fail(scenario, "the press threw: " .. tostring(ran))
			elseif not cast then
				fail(scenario, "SKIPPED -- the press did not cast at Weirbeard: " .. flat(ran))
			elseif said then
				fail(scenario, "the press spoke without knowing he is alive: " .. flat(ran))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- Forever's names have a surname, and a first name is shared. Weirbeard
-- Jenkins targeted, then the player targets Weirbeard Smith: the hold keeps
-- Jenkins on the panel, and the press looks for him on every token by his
-- whole name. A nameplate twenty yards off (too far for a passer-by, so the
-- hold's entry is the only one) is his only if it says Jenkins.
for _, plate in ipairs({ { "Weirbeard", "Smith" }, { "Weirbeard", "Jenkins" } }) do
	local who = plate[1] .. " " .. plate[2]
	local want = who == WEIRBEARD
	local scenario = "speech-range: the press knows him by his surname (" .. who .. " on a nameplate)"
	local ns, restore = passing(scenario, { target = { "Weirbeard", "Jenkins" } }, function()
		Mock.yards = { nameplate1 = 20 }
	end)
	if ns then
		if not speaks(macro(ns)) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			Mock.unitNames.target = { "Weirbeard", "Smith" }
			Mock.unitNames.nameplate1 = plate
			ns.nameplateUnits.nameplate1 = true
			local ran, cast, said = pressAt(ns)
			if not cast then
				fail(scenario, "SKIPPED -- the hold did not keep the press on Weirbeard Jenkins: " .. flat(ran))
			elseif said ~= want then
				fail(scenario, ("with Weirbeard Smith targeted and %s on a nameplate, the press %s: %s"):format(
					who, want and "left the line out" or "spoke to Weirbeard Jenkins", flat(ran)))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- Every token the scan walks, by the whole filed name: the token the scan
-- found him by first, then the rest.
do
	local scenario = "speech-range: the press finds him by any token, by his whole name"
	Mock.reset()
	local units = { nameplate1 = { "Ejp", "Ejp" }, nameplate2 = { "Weirbeard", "Jenkins" },
		target = { "Weirbeard", "Smith" } }
	local restore = H.strangers(units)
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		if type(ns.UnitFor) ~= "function" then
			fail(scenario, "there is no ns.UnitFor to find a token by name")
		else
			local checks = {
				{ "his token recycled to Ejp Ejp, him on another", WEIRBEARD, "nameplate1", "nameplate2" },
				{ "his own token", WEIRBEARD, "nameplate2", "nameplate2" },
				{ "no token to start from", WEIRBEARD, nil, "nameplate2" },
				{ "another Weirbeard, targeted", "Weirbeard Smith", "nameplate2", "target" },
				{ "a first name alone", "Weirbeard", nil, nil },
				{ "somebody no token holds", MUNIN, "nameplate2", nil },
			}
			for _, check in ipairs(checks) do
				local label, name, hint, want = check[1], check[2], check[3], check[4]
				local got = ns.UnitFor(name, hint)
				if got ~= want then
					fail(scenario, ("%s: %s found on %s, wanted %s"):format(label, name,
						tostring(got), tostring(want)))
				end
			end
			-- In your party, off every nameplate.
			units.nameplate2 = nil
			units.party1 = { "Weirbeard", "Jenkins" }
			Mock.groupSize = 2
			local got = ns.UnitFor(WEIRBEARD, "nameplate1")
			if got ~= "party1" then
				fail(scenario, "in your party: found on " .. tostring(got) .. ", wanted party1")
			end
			Mock.groupSize = 0
		end
		guarded(scenario, ns)
	end
	restore()
end

-- The global cooldown running: the press is held back whole, as before, and
-- says nothing. The spell's own cooldown running: the cast goes out (the game
-- refuses it), and the line does not.
do
	local scenario = "speech-range: no line while the global cooldown runs"
	local ns, restore = passing(scenario, { nameplate1 = { "Weirbeard", "Jenkins" } })
	if ns then
		if not speaks(macro(ns)) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			Mock.advance(1)
			Mock.spellCooldowns = { [61304] = { startTime = Mock.now, duration = 1.5 } }
			local ran = H.pressButton(ns)
			if speaks(ran) then
				fail(scenario, "the press spoke during the global cooldown: " .. flat(ran))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

do
	local scenario = "speech-range: no line while the spell's own cooldown runs"
	local ns, restore = passing(scenario, { nameplate1 = { "Weirbeard", "Jenkins" } })
	if ns then
		if not speaks(macro(ns)) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			Mock.spellCooldowns = { [1459] = 8 }
			local ran, cast, said = pressAt(ns)
			if not cast then
				fail(scenario, "the press was dropped with the line: " .. flat(ran))
			elseif said then
				fail(scenario, "the press spoke with the spell eight seconds from ready: " .. flat(ran))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- Short of mana at the press: the fresh queue drops the buff (Affordable), the
-- fuse keeps the press on him, and the cast goes without the line.
do
	local scenario = "speech-range: no line without the mana to cast"
	local ns, restore = passing(scenario, { nameplate1 = { "Weirbeard", "Jenkins" } })
	if ns then
		if not speaks(macro(ns)) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			local real = rawget(_G, "IsUsableSpell")
			rawset(_G, "IsUsableSpell", function() return false, true end)
			local ok, ran, cast, said = pcall(pressAt, ns)
			rawset(_G, "IsUsableSpell", real)
			if not ok then
				fail(scenario, "the press threw: " .. tostring(ran))
			elseif not cast then
				fail(scenario, "SKIPPED -- the press did not cast at Weirbeard: " .. flat(ran))
			elseif said then
				fail(scenario, "the press spoke over a cast the mana would not pay for: " .. flat(ran))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- In a fight nothing is judged again: the macro the pull armed (with no line,
-- as for every fight) is the one every press runs.
do
	local scenario = "speech-range: in a fight the press runs what the pull armed"
	local ns, restore = passing(scenario, { nameplate1 = { "Weirbeard", "Jenkins" } })
	if ns then
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		local frozen = macro(ns)
		if not (frozen and frozen:find(WEIRBEARD, 1, true)) then
			fail(scenario, "SKIPPED -- the pull armed nothing for Weirbeard: " .. flat(frozen))
		else
			Mock.unitNames.nameplate1 = nil
			local ok, ran = pcall(pressAt, ns)
			if not ok then
				fail(scenario, "the press threw in a fight: " .. tostring(ran))
			elseif ran ~= frozen then
				fail(scenario, "the press changed what the fight froze: " .. flat(frozen) .. "  ->  " .. flat(ran))
			elseif speaks(ran) then
				fail(scenario, "the macro armed for the fight speaks: " .. flat(ran))
			end
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		guarded(scenario, ns)
		restore()
	end
end

-- Nor is a line rolled for an arming that cannot say it: "In character"
-- remembers every line it rolls as said lately, and a line rolled for a
-- favour no token holds is never said. Rolled once a nameplate shows him.
do
	local scenario = "speech-range: no line is rolled for somebody the press cannot reach"
	local rolls, realPick = 0, nil
	local ns, restore = passing(scenario, {}, function(ns)
		H.owe(ns, WEIRBEARD)
		realPick = ns.PickPhrase
		ns.PickPhrase = function(...)
			rolls = rolls + 1
			return realPick(...)
		end
	end)
	if ns then
		local tokenless = macro(ns)
		if not (tokenless and tokenless:find("/target " .. WEIRBEARD, 1, true)) then
			fail(scenario, "SKIPPED -- the favour was not armed: " .. flat(tokenless))
		elseif speaks(tokenless) then
			fail(scenario, "the macro speaks to somebody no token holds: " .. flat(tokenless))
		elseif rolls > 0 then
			fail(scenario, ("%d line(s) rolled for somebody no token holds, none said"):format(rolls))
		else
			Mock.unitNames.nameplate1 = { "Weirbeard", "Jenkins" }
			ns.nameplateUnits.nameplate1 = true
			Mock.advance(1)
			ns.addon:Tick()
			if not speaks(macro(ns)) then
				fail(scenario, "on a nameplate, in reach, he got no line: " .. flat(macro(ns)))
			elseif rolls ~= 1 then
				fail(scenario, ("on a nameplate, %d rolls for one line"):format(rolls))
			end
		end
		if realPick then ns.PickPhrase = realPick end
		guarded(scenario, ns)
		restore()
	end
end

-- A line left out is not spent: the press rolls nothing new, and the line the
-- tooltip quoted is the one said by the next press that lands. ("In
-- character" remembers every line it rolls, and holds back one said lately.)
do
	local scenario = "speech-range: a line left out is kept for the press that lands"
	local ns, restore = passing(scenario, { nameplate1 = { "Weirbeard", "Jenkins" } }, function(ns)
		ns.db.profile.speech.phrases = "One, {name}.\nTwo, {name}.\nThree, {name}.\nFour, {name}.\nFive, {name}.\nSix, {name}."
	end)
	if ns then
		local S = ns.Prompt.state
		local rolled = S.phraseText
		if not (rolled and speaks(macro(ns))) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with: " .. flat(macro(ns)))
		else
			local realPick = ns.PickPhrase
			local rolls = 0
			ns.PickPhrase = function(...)
				rolls = rolls + 1
				return realPick(...)
			end
			Mock.spellCooldowns = { [1459] = 8 }
			local ran, cast, said = pressAt(ns)
			if not cast or said then
				fail(scenario, "SKIPPED -- the press did not cast without the line: " .. flat(ran))
			elseif rolls > 0 then
				fail(scenario, ("the press left the line out and rolled %d more"):format(rolls))
			elseif S.phraseText ~= rolled then
				fail(scenario, ("the line left out was thrown away: %s, now %s"):format(
					flat(rolled), flat(S.phraseText)))
			else
				-- The spell ready again, and that press's bookkeeping cleared.
				Mock.spellCooldowns = nil
				ns.pendingClick = nil
				wipe(ns.tried)
				wipe(ns.refusals)
				local again = pressAt(ns)
				if not (again and again:find(rolled, 1, true)) then
					fail(scenario, ("the press that landed did not say the line kept for it (%s): %s"):format(
						flat(rolled), flat(again)))
				end
			end
			ns.PickPhrase = realPick
		end
		guarded(scenario, ns)
		restore()
	end
end
