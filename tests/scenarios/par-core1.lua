-- The weakest-point review of 2026-11-15, the core job's first share: who the
-- prompt keeps offering once they have walked off, how long a refusal about
-- where somebody stands keeps them off, and what a name in the list casts at
-- while the cursor is on it.
--
-- Every scenario name starts with "par-core1:" so the mutations in
-- tests/mutations/par-core1.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local ANNA, BERT, CARA, DANE = "Anna Aim", "Bert Beside", "Cara Close", "Dane Dusk"
local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
	nameplate3 = { "Cara", "Close" }, nameplate4 = { "Dane", "Dusk" } }

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A mage among strangers on nameplates (a copy of `people`, so a scenario can
-- take one away), passers-by on, the prompt up. `edit` changes the settings
-- before the first scan; `body` gets the addon, the nameplates and the prompt's
-- regions.
local function session(scenario, people, edit, body)
	Mock.reset()
	Mock.class = "MAGE"
	local names = {}
	for unit, name in pairs(people) do names[unit] = name end
	local restore = H.strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		-- A first login parks the welcome and its preview on the clock.
		Mock.timers = {}
		ns.db.profile.sources.strangers = true
		ns.db.profile.speech.enabled = false
		if edit then edit(ns, ns.db.profile.prompt) end
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		body(ns, names, ns.Prompt:Regions())
		guarded(scenario, ns)
	end)
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- One scan, 0.4 s on, as the addon's own ticker makes it.
local function scan(ns)
	Mock.advance(0.4)
	Mock.runTimers(0)
	ns.addon:Tick()
end

-- A nameplate gone from the screen: the person walked out of sight.
local function walkOff(ns, names, unit)
	names[unit] = nil
	ns.nameplateUnits[unit] = nil
end

local function onPrompt(ns)
	local current = ns.Prompt.state.current
	return current and current.name
end

local function armedAt(ns)
	return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1") or "")
end

-- ------------------------------------------------------------ 1. who walked off
-- Two passers-by in reach; the one on the prompt walks off. The queue keeps
-- her by name for ten seconds (Queue.lua, LINGER_SECONDS), unmeasured, and
-- sorts the one still in reach ahead of her; the prompt kept her anyway on the
-- tie of the tier, for the whole ten seconds, and a press went at somebody
-- forty yards off while the one beside you waited.
do
	local scenario = "par-core1: a passer-by who walked off gives way to one still in reach"
	session(scenario, { nameplate1 = PEOPLE.nameplate1, nameplate2 = PEOPLE.nameplate2 }, nil, function(ns, names)
		if onPrompt(ns) ~= ANNA then
			fail(scenario, "SKIPPED -- Anna was not on the prompt to begin with: " .. tostring(onPrompt(ns)))
			return
		end
		walkOff(ns, names, "nameplate1")
		scan(ns)
		if onPrompt(ns) ~= BERT then
			fail(scenario, "one scan after Anna walked off, the prompt still names " .. tostring(onPrompt(ns))
				.. " and not Bert, who is beside you")
		end
		if not armedAt(ns):find("Bert", 1, true) then
			fail(scenario, "the prompt's press is not aimed at Bert: " .. armedAt(ns):gsub("\n", " / "))
		end
		-- And nothing swings back while she is only remembered.
		for _ = 1, 10 do scan(ns) end
		if onPrompt(ns) ~= BERT then
			fail(scenario, "four seconds on, the prompt went back to " .. tostring(onPrompt(ns)))
		end
	end)
end

-- With nobody else about, the one who walked off is still offered while the
-- queue remembers her: a press may yet reach her, and nobody better waits.
do
	local scenario = "par-core1: alone, a passer-by who walked off is still offered"
	session(scenario, { nameplate1 = PEOPLE.nameplate1 }, nil, function(ns, names)
		if onPrompt(ns) ~= ANNA then
			fail(scenario, "SKIPPED -- Anna was not on the prompt to begin with: " .. tostring(onPrompt(ns)))
			return
		end
		walkOff(ns, names, "nameplate1")
		for _ = 1, 5 do scan(ns) end
		if onPrompt(ns) ~= ANNA then
			fail(scenario, "two seconds after Anna walked off, with nobody else about, the prompt names "
				.. tostring(onPrompt(ns)))
		end
	end)
end

-- 1.1.1's case: the cursor on the panel keeps the one it names while the
-- mouse is on its way (Prompt/Hold.lua, CursorHolds), somebody in reach or not.
do
	local scenario = "par-core1: the cursor on the panel keeps a passer-by who walked off"
	session(scenario, { nameplate1 = PEOPLE.nameplate1, nameplate2 = PEOPLE.nameplate2 }, nil, function(ns, names)
		if onPrompt(ns) ~= ANNA then
			fail(scenario, "SKIPPED -- Anna was not on the prompt to begin with: " .. tostring(onPrompt(ns)))
			return
		end
		local button = ns.Prompt:GetButton()
		button.scripts.OnEnter(button)
		walkOff(ns, names, "nameplate1")
		for _ = 1, 5 do scan(ns) end
		if onPrompt(ns) ~= ANNA then
			fail(scenario, "with the cursor on the panel, Anna gave way to " .. tostring(onPrompt(ns))
				.. " before the click")
		end
		button.scripts.OnLeave(button)
		scan(ns)
		if onPrompt(ns) ~= BERT then
			fail(scenario, "the cursor gone, the prompt still names " .. tostring(onPrompt(ns)))
		end
	end)
end

-- ------------------------------------------------------------ 2. where they stand
-- Refusals about where somebody stands (out of sight, out of range) are put
-- right by a step; refusals about who they are are not. Three in a row of the
-- first kind used to keep a group member off the prompt for five minutes and
-- say in chat that the game keeps refusing them.

local function told()
	local out = {}
	for _, line in ipairs(Mock.printed) do
		if line:find("keeps refusing", 1, true) then out[#out + 1] = line end
	end
	return out
end

-- How long from now `name` stays off the prompt, to the second (a minute and
-- more reads as 999).
local function blockedFor(ns, name)
	local now = GetTime()
	for s = 0, 600 do
		if not ns.IsBlocked(name, "intellect", now + s) then return s end
	end
	return 999
end

local ERRORS = {
	{ "SPELL_FAILED_LINE_OF_SIGHT", "Target not in line of sight" },
	{ "ERR_OUT_OF_RANGE", "Out of range." },
	{ "SPELL_FAILED_OUT_OF_RANGE", "Out of range" },
}

-- The client's own strings, which the mock leaves out, for the length of `body`.
local function withErrors(body)
	local saved = {}
	for _, e in ipairs(ERRORS) do
		saved[e[1]] = rawget(_G, e[1])
		rawset(_G, e[1], e[2])
	end
	local ok, err = pcall(body)
	for _, e in ipairs(ERRORS) do rawset(_G, e[1], saved[e[1]]) end
	if not ok then error(err, 0) end
end

for _, e in ipairs(ERRORS) do
	local key, words = e[1], e[2]
	local scenario = "par-core1: refused " .. key .. " three times, back within half a minute"
	local party = { party1 = { "Anna", "Aim" } }
	session(scenario, party, nil, function(ns)
		withErrors(function()
			local longest = 0
			for i = 1, 4 do
				ns.NoteRefusal(ANNA, words, nil, true, "intellect")
				local held = blockedFor(ns, ANNA)
				if held > longest then longest = held end
				if i == 1 and held < 3 then
					fail(scenario, ("the first refusal held Anna back %ds, which brings her straight back"
						.. " to be refused again"):format(held))
				end
				-- The spoken line stays held past the back-off, as for any refusal.
				if i == 1 and not ns.SpeechHeld(ANNA, GetTime() + held + 29) then
					fail(scenario, "the spoken line came back with Anna, over another refused cast")
				end
				Mock.advance(held + 1)
			end
			if longest > 31 then
				fail(scenario, ("refused for where she stands, Anna was held back %ds"):format(longest))
			end
			if #told() > 0 then
				fail(scenario, "chat blamed Anna for where she stands: " .. told()[1])
			end
		end)
	end)
end

-- Somebody the player has picked out and still has selected is not backed off
-- for where they stand either: selecting the selected sends no change of
-- target, which is what lifts a back-off (Queue.lua, LiftBackoff).
do
	local scenario = "par-core1: your own target out of sight is not backed off"
	session(scenario, { party1 = { "Anna", "Aim" } }, nil, function(ns)
		withErrors(function()
			Mock.unitNames.target = { "Anna", "Aim" }
			ns.addon:PLAYER_TARGET_CHANGED()
			ns.NoteRefusal(ANNA, "Target not in line of sight", nil, true, "intellect")
			if ns.IsBlocked(ANNA, "intellect", GetTime() + 1) then
				fail(scenario, "Anna, your own target, was taken off the prompt for where she stands")
			end
		end)
	end)
end

-- The error line can come a moment after the refusal it explains: the refusal,
-- with no reason yet, is a step of the person's run until the line says where
-- they stand, and then it is taken back.
do
	local scenario = "par-core1: out of sight said just after the refusal, back within half a minute"
	session(scenario, { party1 = { "Anna", "Aim" } }, nil, function(ns)
		withErrors(function()
			local longest = 0
			for _ = 1, 4 do
				ns.NoteRefusal(ANNA, nil, nil, true, "intellect")
				Mock.advance(0.1)
				ns.addon:UI_ERROR_MESSAGE(nil, 0, "Target not in line of sight")
				Mock.runTimers(0.5)
				local held = blockedFor(ns, ANNA)
				if held > longest then longest = held end
				Mock.advance(held + 1)
			end
			if longest > 31 then
				fail(scenario, ("refused for where she stands, said a moment late, Anna was held back %ds"):format(longest))
			end
			if #told() > 0 then
				fail(scenario, "chat blamed Anna for where she stands: " .. told()[1])
			end
		end)
	end)
end

-- The step taken back is the third of the person's run, whose chat line waits
-- a moment for the error line: taken back, nothing is said, and the next
-- refusal about the person is the third.
do
	local scenario = "par-core1: a late out of sight on the third refusal takes the step back"
	session(scenario, { party1 = { "Anna", "Aim" } }, nil, function(ns)
		withErrors(function()
			ns.NoteRefusal(ANNA, "Invalid target.", nil, true, "intellect")
			Mock.advance(3)
			ns.NoteRefusal(ANNA, "Invalid target.", nil, true, "intellect")
			Mock.advance(31)
			ns.NoteRefusal(ANNA, nil, nil, true, "intellect")
			Mock.advance(0.1)
			ns.addon:UI_ERROR_MESSAGE(nil, 0, "Target not in line of sight")
			Mock.runTimers(0.5)
			if #told() > 0 then
				fail(scenario, "out of sight, said a moment late, was told as the game refusing Anna: " .. told()[1])
			end
			local held = blockedFor(ns, ANNA)
			if held > 31 then
				fail(scenario, ("out of sight, said a moment late, held Anna back %ds"):format(held))
			end
			Mock.advance(held + 1)
			ns.NoteRefusal(ANNA, "Invalid target.", nil, true, "intellect")
			if blockedFor(ns, ANNA) < 200 then
				fail(scenario, "the next refusal about Anna herself was not the third of her run")
			end
			if #told() ~= 1 then
				fail(scenario, "the third refusal about Anna did not say so in chat once: " .. #told())
			end
		end)
	end)
end

-- Refusals about the person still go the whole way, and a refusal about where
-- they stand neither adds to that run nor cuts it short.
do
	local scenario = "par-core1: refusals about the person still back off for minutes"
	session(scenario, { party1 = { "Anna", "Aim" } }, nil, function(ns)
		withErrors(function()
			ns.NoteRefusal(ANNA, "Invalid target.", nil, true, "intellect")
			Mock.advance(3)
			ns.NoteRefusal(ANNA, "Invalid target.", nil, true, "intellect")
			Mock.advance(31)
			-- Out of sight in between: no step of the person's run.
			ns.NoteRefusal(ANNA, "Target not in line of sight", nil, true, "intellect")
			Mock.advance(31)
			ns.NoteRefusal(ANNA, "Invalid target.", nil, true, "intellect")
			local held = blockedFor(ns, ANNA)
			if held < 200 then
				fail(scenario, ("the third refusal about Anna herself held her back only %ds"):format(held))
			end
			if #told() ~= 1 then
				fail(scenario, "the third refusal about Anna did not say so in chat once: " .. #told())
			end
		end)
	end)
end

-- ------------------------------------------------------------ 3. the row under the cursor
-- The list's names are buttons armed only for the one press, each with the
-- person its row names (Prompt/Rows.lua). The list was rebuilt from the queue on
-- every scan, so in a crowd a row's name changed under the cursor and a click
-- meant for one person buffed whoever had slid into that line.

local function rowName(r, i)
	local row = r.rowButtons[i] and r.rowButtons[i].mannersRow
	return row and row.name
end

-- What line `i` of the list says, read off the prompt's own font string.
local function rowText(ns, i)
	local fs = ns.Prompt.regions.queueRows[i]
	return tostring(fs and fs:GetText() or "")
end

-- One left click on a row as the client delivers it: PreClick, the macro the
-- button then holds, PostClick. Nothing for a hidden row.
local function clickRow(button)
	if not button:IsVisible() then return nil end
	if button.scripts.PreClick then button.scripts.PreClick(button, "LeftButton", true) end
	local ran = button.attributes.macrotext1 or button.attributes.macrotext
	if button.scripts.PostClick then button.scripts.PostClick(button, "LeftButton", true) end
	return ran
end

local function listOn(ns, p)
	p.showQueue, p.queueRows, p.clickRows = true, 3, true
	p.style = "glass"
end

do
	local scenario = "par-core1: the name under the cursor stays put while the list moves"
	session(scenario, PEOPLE, listOn, function(ns, names, r)
		local first = rowName(r, 1)
		if first ~= BERT or rowName(r, 2) ~= CARA then
			fail(scenario, "SKIPPED -- the list did not start Bert, Cara: " .. tostring(first) .. ", "
				.. tostring(rowName(r, 2)))
			return
		end
		local button = r.rowButtons[1]
		button.scripts.OnEnter(button)
		-- Bert walks off: still remembered, and now sorted after the two in reach.
		walkOff(ns, names, "nameplate2")
		scan(ns)
		if rowName(r, 1) ~= BERT then
			fail(scenario, "under the cursor, the first name became " .. tostring(rowName(r, 1)))
		end
		if not rowText(ns, 1):find("Bert", 1, true) then
			fail(scenario, "the first line no longer says Bert: " .. rowText(ns, 1))
		end
		-- Nobody listed twice.
		for i = 2, 3 do
			if rowName(r, i) == BERT then fail(scenario, "Bert is listed on line " .. i .. " as well") end
		end
		local ran = clickRow(button)
		if ran and not ran:find("Bert", 1, true) then
			fail(scenario, "a click on the line that said Bert cast: " .. ran:gsub("\n", " / "))
		end
		-- The cursor gone, the list is the queue's order again.
		button.scripts.OnLeave(button)
		scan(ns)
		if rowName(r, 1) == BERT then
			fail(scenario, "with the cursor gone, the first line still holds Bert out of the queue's order")
		end
	end)
end

-- Somebody gone from the queue altogether while the cursor is on their line: the
-- line goes blank rather than taking the next name, and a click casts nothing.
do
	local scenario = "par-core1: the line under the cursor goes blank when its person leaves"
	session(scenario, PEOPLE, listOn, function(ns, names, r)
		if rowName(r, 1) ~= BERT then
			fail(scenario, "SKIPPED -- the list did not start with Bert: " .. tostring(rowName(r, 1)))
			return
		end
		local button = r.rowButtons[1]
		button.scripts.OnEnter(button)
		walkOff(ns, names, "nameplate2")
		-- Forgotten as well: out of the queue altogether.
		wipe(ns.passersBy)
		scan(ns)
		local now = rowName(r, 1)
		if now and now ~= BERT then
			fail(scenario, "under the cursor, Bert's line took " .. now)
		end
		if rowText(ns, 1):find("Cara", 1, true) or rowText(ns, 1):find("Dane", 1, true) then
			fail(scenario, "under the cursor, Bert's line now says: " .. rowText(ns, 1))
		end
		local ran = clickRow(button)
		if ran and (ran:find("Cara", 1, true) or ran:find("Dane", 1, true)) then
			fail(scenario, "a click on the line that said Bert cast: " .. ran:gsub("\n", " / "))
		end
		if not button.mannersRow.hovered then
			fail(scenario, "the blank line forgot the cursor is on it")
		end
		button.scripts.OnLeave(button)
		scan(ns)
		if rowName(r, 1) ~= CARA then
			fail(scenario, "with the cursor gone, the first line is " .. tostring(rowName(r, 1)) .. ", not Cara")
		end
	end)
end
