-- What the buttons for the moment say of themselves (Prompt/Moments.lua): one
-- trail line per lighting and its rate limit, the second line of a fight's
-- summary, the lines Mark this moment adds, /manners debug's line per row, and
-- the self-test's rows. No name of any player or mob is ever written.
--
-- Every name starts with "moments-diag:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")

local function with(name, body, opts) K.withMage(H, "moments-diag: " .. name, body, opts) end
local function name(s) return "moments-diag: " .. s end

local function lines(ns, needle)
	local out = {}
	for _, e in ipairs(ns.addon.db.char.trail or {}) do
		if tostring(e.text):find(needle, 1, true) then out[#out + 1] = e end
	end
	return out
end

local function printed(needle)
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(needle, 1, true) then return line end
	end
	return nil
end

local function results(ns, id)
	local out = {}
	for _, r in ipairs(ns.Selftest.Run()) do
		if r.id == id then out[#out + 1] = { status = r.status, value = tostring(r.value) } end
	end
	return out
end

local function any(list, status, text)
	for _, r in ipairs(list) do
		if r.status == status and r.value:find(text, 1, true) then return true end
	end
	return false
end

local function show(list)
	local parts = {}
	for _, r in ipairs(list) do parts[#parts + 1] = r.status .. " " .. r.value end
	return table.concat(parts, " | ")
end

do
	local s = name("one trail line per lighting, at most one every two seconds and twelve a fight")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		K.cast(ns)
		K.tick(ns, 0.3)
		K.endCast(ns)
		K.tick(ns, 0.3)
		K.cast(ns)
		K.tick(ns, 0.3)
		local n = #lines(ns, "moment counterspell: lit (")
		if n ~= 1 then fail(s, "two lightings in a second wrote " .. n .. " lines") end
		local line = lines(ns, "moment counterspell: lit (")[1]
		if line and not line.text:find("your target is casting", 1, true) then fail(s, "the line does not say why: " .. line.text) end
		K.endCast(ns)
		K.tick(ns, 2.5)
		K.cast(ns)
		K.tick(ns, 0.3)
		n = #lines(ns, "moment counterspell: lit (")
		if n ~= 2 then fail(s, "a lighting after two seconds wrote " .. n .. " lines in all") end
		for _ = 1, 20 do
			K.endCast(ns)
			K.tick(ns, 2.5)
			K.cast(ns)
			K.tick(ns, 0.3)
		end
		n = #lines(ns, "moment counterspell: lit (")
		if n ~= 12 then fail(s, "a fight wrote " .. n .. " lighting lines, not twelve") end
	end)
end

do
	local s = name("a hidden value is said to be left to the game, never claimed lit")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 10
		K.pull(ns)
		K.tick(ns, 0.5)
		local game = lines(ns, "moment iceblock: left to the game")
		if #game ~= 1 then fail(s, "Ice Block with hidden health wrote " .. #game .. " 'left to the game' lines") end
		if #lines(ns, "moment iceblock: lit") ~= 0 then fail(s, "a hidden value was called lit") end
		K.release(ns)
		local words = table.concat((function() local t = {} for _, e in ipairs(lines(ns, "fight summary, buttons")) do t[#t + 1] = e.text end return t end)(), "\n")
		if not words:find("iceblock lit 0, game 1", 1, true) then fail(s, "the summary does not say game 1: " .. words) end
	end)
end

do
	local s = name("the second fight-summary line says what each button saw, and is absent with nothing armed")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		K.cast(ns)
		K.tick(ns, 0.3)
		Mock.pressBinding("CLICK MannersMoment1:LeftButton")
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2139)
		K.release(ns)
		local found = lines(ns, "fight summary, buttons for the moment: ")
		if #found ~= 1 then fail(s, "the summary line was written " .. #found .. " times") return end
		if not found[1].text:find("counterspell lit 1, game 0, pressed 1, out 1, cover 0", 1, true) then
			fail(s, "what the line says: " .. found[1].text)
		end
		if not found[1].text:find("blink dark", 1, true) then fail(s, "Blink's dark reason is missing: " .. found[1].text) end
		if #lines(ns, "fight summary:") ~= 1 then fail(s, "the first summary line changed") end
	end, { known = { 2139, 1953 }, bindings = { F1 = "CLICK MannersMoment1:LeftButton" } })
	s = name("the second fight-summary line is absent with nothing armed")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		K.release(ns)
		if #lines(ns, "buttons for the moment") ~= 0 then fail(s, "a summary line with nothing armed") end
		if #lines(ns, "fight summary:") ~= 1 then fail(s, "the first line is gone") end
	end, { preload = function(ns) for k, v in pairs(ns.defaults.profile.moments) do if type(v) == "boolean" then ns.defaults.profile.moments[k] = false end end end })
end

do
	local s = name("Mark this moment adds one line per armed button, or says none is armed")
	with(s, function(ns)
		ns.MarkMoment()
		local found = lines(ns, "moment counterspell dark: not in a fight")
		if #found ~= 1 then fail(s, "no mark line for Counterspell: " .. #found) return end
		if not found[1].text:find("shown no, cover down, key none", 1, true) then
			-- Out of a fight the button is hidden and the cover down.
			fail(s, "the mark line: " .. found[1].text)
		end
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		ns.MarkMoment()
		local lit = lines(ns, "moment counterspell lit, shown yes, cover down, key none")
		if #lit ~= 1 then fail(s, "no lit mark line in the fight") end
	end, { known = { 2139 } })
	s = name("Mark this moment says none is armed")
	with(s, function(ns)
		ns.MarkMoment()
		if #lines(ns, "moments: none armed") ~= 1 then fail(s, "nothing said of an empty set") end
	end, { preload = function(ns) for k, v in pairs(ns.defaults.profile.moments) do if type(v) == "boolean" then ns.defaults.profile.moments[k] = false end end end })
end

do
	local s = name("/manners debug has a line per row: learned or not, switch, macro, key, now, last fight")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		K.release(ns)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local head = printed("moments: class MAGE")
		if not head then fail(s, "no first line") return end
		for _, part in ipairs({ "2 learned", "alpha from a boolean yes", "percent scale 1", "refused calls: none", "events this client lacks: ",
			"lock flag proven: no", "the cover let a click through: never" }) do
			if not head:find(part, 1, true) then fail(s, "the first line lacks '" .. part .. "': " .. head) end
		end
		local counter = printed("moment counterspell: spell 2139 Counterspell")
		if not counter then fail(s, "no Counterspell line") return end
		for _, part in ipairs({ "learned yes", "switch on", "armed (/stopcasting | /cast Counterspell)", "key none", "slot 1",
			"one click", "last fight lit 1" }) do
			if not counter:find(part, 1, true) then fail(s, "the Counterspell line lacks '" .. part .. "': " .. counter) end
		end
		if not printed("moment blink: not learned") then fail(s, "Blink is not said to be unlearned") end
		if not printed("moment iceblock: spell 11958") or not printed("two clicks where the game alone knows") then
			fail(s, "Ice Block's two-click rule is not said")
		end
		if not printed("moment evocation: not built yet") then fail(s, "a row of the next part is not marked not built") end
	end, { known = { 2139, 11958 } })
end

do
	local s = name("the self-test's rows: not learned, switched off, made, and the WARNs")
	with(s, function(ns)
		local list = results(ns, "fight.moments")
		if not any(list, "PASS", "counterspell: button made, header peace, no key: a click on it casts while it is lit") then
			fail(s, "Counterspell is not a pass: " .. show(list))
		end
		if not any(list, "PASS", "blink: not learned") then fail(s, "Blink is not 'not learned': " .. show(list)) end
		ns.db.profile.moments.counterspell = false
		list = results(ns, "fight.moments")
		if not any(list, "PASS", "counterspell: switched off") then fail(s, "a switch off is not said: " .. show(list)) end
		ns.db.profile.moments.counterspell = true
		if not any(list, "PASS", "iceblock: switched off") then fail(s, "Ice Block is not switched off: " .. show(list)) end
		-- Learned, switched on, never made.
		ns.db.profile.moments.iceblock = true
		list = results(ns, "fight.moments")
		if not any(list, "WARN", "iceblock: switched on, but the button was never made") then
			fail(s, "a button never made is not a warning: " .. show(list))
		end
		ns.addon:Tick()
		ns.Moments:Header():SetAttribute("state-mannersmoments", "fight")
		list = results(ns, "fight.moments")
		if not any(list, "WARN", "header says fight, not peace") then fail(s, "a wrong header state is not a warning: " .. show(list)) end
		ns.Moments:Header():SetAttribute("state-mannersmoments", "peace")
		ns.db.global.momentCoverLeaks = 3
		list = results(ns, "fight.moments")
		if not any(list, "WARN", "the cover let a click through 3 times") then fail(s, "leaks are not a warning: " .. show(list)) end
		ns.db.global.momentCoverLeaks = nil
		-- The calls this client has, and the events it lacks.
		local apis = results(ns, "fight.apis")
		if not any(apis, "PASS", "SetAlphaFromBoolean: yes") then fail(s, "no SetAlphaFromBoolean line: " .. show(apis)) end
		if not any(apis, "PASS", "events this client lacks: UNIT_SPELLCAST_EMPOWER_START") then
			fail(s, "the refused events are not listed: " .. show(apis))
		end
		for _, r in ipairs(apis) do
			if r.status == "FAIL" then fail(s, "a fight.apis line failed: " .. r.value) end
		end
		-- The keys group holds a row for each armed button.
		local keys = results(ns, "fight.keys")
		if not any(keys, "PASS", "counterspell=click") then fail(s, "no key row for Counterspell: " .. show(keys)) end
	end, { known = { 2139, 11958 }, preload = function(ns) ns.defaults.profile.moments.iceblock = false end })
end

do
	local s = name("no name of a target or a mob is ever written")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { name = "Marrowgnaw the Unforgiving" })
		K.tick(ns, 0.3)
		Mock.pressBinding("CLICK MannersMoment1:LeftButton")
		ns.MarkMoment()
		K.release(ns)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		for _, e in ipairs(ns.addon.db.char.trail or {}) do
			if tostring(e.text):find("Marrowgnaw", 1, true) or tostring(e.who or ""):find("Marrowgnaw", 1, true) then
				fail(s, "the trail names the mob: " .. e.text)
			end
		end
		if printed("Marrowgnaw") then fail(s, "/manners debug names the mob") end
	end)
end
