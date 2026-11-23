-- The buttons for the moment, the framework (Prompt/Moments.lua, MomentsData.lua,
-- MomentsSense.lua): what a mage is offered, how the buttons are made, armed,
-- placed, covered and driven through a fight, and what a pull registers. What
-- each moment waits for is held in moments-counterspell.lua, moments-iceblock.lua
-- and moments-blink.lua; what the log says in moments-diag.lua.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client itself: how Forever hit-tests a frame over a secure button, and whether
-- its health and mana are hidden, only a fight can say (STATUS.md).
--
-- Every name starts with "moments:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")

local function with(name, body, opts) K.withMage(H, "moments: " .. name, body, opts) end
local function name(s) return "moments: " .. s end

local function trailHas(ns, text)
	for _, e in ipairs(ns.addon.db.char.trail or {}) do
		if tostring(e.text):find(text, 1, true) then return true end
	end
	return false
end

local function count(t)
	local n = 0
	for _ in pairs(t or {}) do n = n + 1 end
	return n
end

local ALL_OFF = function(profile)
	for key in pairs(profile.moments) do
		if type(profile.moments[key]) == "boolean" then profile.moments[key] = false end
	end
end

do
	local s = name("every switch off: no frame made, no event registered, a scan asks the client nothing")
	with(s, function(ns)
		for n = 1, 11 do
			if ns.Moments:Button(n) then fail(s, "a button was made for slot " .. n) end
		end
		if ns.Moments:Frame() and count(ns.Moments:Frame().events) + count(ns.Moments:Frame().unitEvents) > 0 then
			fail(s, "events are registered")
		end
		-- Wanted compares plain fields; the client is asked nothing.
		Mock.asked.InCombatLockdown, Mock.asked.UnitExists = 0, 0
		for _ = 1, 20 do ns.Moments:Wanted() end
		local asked = Mock.asked.InCombatLockdown + Mock.asked.UnitExists
		if asked > 0 then fail(s, "a scan asked the client " .. asked .. " times (lockdown " .. Mock.asked.InCombatLockdown .. ", exists " .. Mock.asked.UnitExists .. ")") end
	end, { preload = function(ns) ALL_OFF(ns.defaults.profile) end, count = { "InCombatLockdown", "UnitExists" } })
end

do
	local s = name("not a mage: nothing made, the section has nothing to show")
	with(s, function(ns)
		if ns.caps.moments ~= nil then fail(s, "caps.moments is set for a warrior") end
		if ns.Moments:Slot(1) then fail(s, "a slot was made") end
		if ns.Moments.Has("counterspell") then fail(s, "Has says a warrior has Counterspell") end
		Mock.asked.InCombatLockdown = 0
		for _ = 1, 20 do
			if ns.Moments:Wanted() then fail(s, "Wanted for a warrior") end
		end
		if Mock.asked.InCombatLockdown > 0 then fail(s, "a warrior's scan asked the client " .. Mock.asked.InCombatLockdown .. " times") end
	end, { class = "WARRIOR", count = { "InCombatLockdown" } })
end

do
	local s = name("a row not learned has no button, no switch, and no binding name of a spell")
	with(s, function(ns)
		if not ns.Moments.Has("counterspell") then fail(s, "Counterspell not learned") end
		if ns.Moments.Has("blink") then fail(s, "Blink is not known but Has says so") end
		if ns.Moments:Slot(3) then fail(s, "a slot was made for a spell not known") end
		if _G["BINDING_NAME_CLICK MannersMoment3:LeftButton"] == "Blink" then fail(s, "the binding says Blink for a spell not known") end
		if _G["BINDING_NAME_CLICK MannersMoment1:LeftButton"] ~= "Counterspell" then
			fail(s, "the binding for slot 1 says " .. tostring(_G["BINDING_NAME_CLICK MannersMoment1:LeftButton"]))
		end
	end, { known = { 2139 } })
end

do
	local s = name("the data's defaults are the profile's defaults")
	with(s, function(ns)
		for _, key in ipairs(ns.MOMENT_KEYS) do
			if ns.MOMENT_DEFAULTS[key] ~= ns.db.profile.moments[key] then
				fail(s, key .. ": data says " .. tostring(ns.MOMENT_DEFAULTS[key]) .. ", profile " .. tostring(ns.db.profile.moments[key]))
			end
		end
		if ns.db.profile.moments.health ~= 20 or ns.db.profile.moments.mana ~= 20 then fail(s, "the shares do not default to 20") end
		for _, row in pairs(ns.Moments.Sets) do
			for _, rows in pairs(row) do
				for _, r in ipairs(rows) do
					if ns.MOMENT_DEFAULTS[r.key] == nil then fail(s, r.key .. " has no default") end
				end
			end
		end
	end)
end

do
	local s = name("every slot number is unique in a class's set and at most eleven")
	with(s, function(ns)
		for _, set in pairs(ns.Moments.Sets) do
			for class, rows in pairs(set) do
				local seen = {}
				for _, r in ipairs(rows) do
					if type(r.slot) ~= "number" or r.slot < 1 or r.slot > 11 then fail(s, class .. " " .. r.key .. ": slot " .. tostring(r.slot)) end
					if seen[r.slot] then fail(s, class .. ": slot " .. tostring(r.slot) .. " twice") end
					seen[r.slot] = true
				end
			end
		end
	end)
end

do
	for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		local s = name("the armed macros of the built buttons on " .. flavour .. ", none over 255 characters, none with a conditional")
		with(s, function(ns)
			local seen = 0
			for n = 1, 3 do
				local macro = K.macro(ns, n)
				if macro then
					seen = seen + 1
					if #macro > 255 then fail(s, "slot " .. n .. ": " .. #macro .. " characters") end
					if macro:find("%[") then fail(s, "slot " .. n .. " has a conditional: " .. macro) end
					if not macro:find("/cast ", 1, true) then fail(s, "slot " .. n .. " casts nothing: " .. macro) end
				end
			end
			if seen == 0 then fail(s, "nothing armed on " .. flavour) end
			local counter = K.macro(ns, 1)
			if counter ~= "/stopcasting\n/cast Counterspell" then fail(s, "Counterspell's macro: " .. tostring(counter)) end
		end, { flavour = flavour })
	end
end

do
	local s = name("armed out of combat, shown by the driver at the pull, hidden at the release")
	with(s, function(ns)
		local b = ns.Moments:Button(1)
		if not b then fail(s, "no button") return end
		if b:IsShown() then fail(s, "shown before the pull") end
		if ns.Moments:Header():GetAttribute("state-mannersmoments") ~= "peace" then fail(s, "the header is not at peace") end
		K.pull(ns)
		if not b:IsShown() then fail(s, "not shown at the pull by the driver") end
		K.release(ns)
		if b:IsShown() then fail(s, "still shown after the release") end
	end)
end

do
	local s = name("nothing protected is called under the lockdown through a whole fight")
	with(s, function(ns)
		Mock.protectedCalls = {}
		Mock.secretOnSecure = {}
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.targetCast = { secret = true, notInterruptible = false }
		K.event(ns, "UNIT_SPELLCAST_START", "target")
		K.tick(ns, 0.3)
		Mock.targetCast = nil
		K.event(ns, "UNIT_SPELLCAST_STOP", "target")
		Mock.health = 10
		K.event(ns, "UNIT_HEALTH", "player")
		K.tick(ns, 0.5)
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.5)
		if #Mock.protectedCalls > 0 then fail(s, "protected calls in the fight: " .. table.concat(Mock.protectedCalls, ", ")) end
		if #Mock.secretOnSecure > 0 then fail(s, "a hidden value reached a protected frame") end
	end)
end

do
	local s = name("the button's own alpha is never written and it has no highlight texture")
	with(s, function(ns)
		Mock.secureAlphaWrites = 0
		K.pull(ns)
		Mock.targetCast = { secret = true, notInterruptible = false }
		K.event(ns, "UNIT_SPELLCAST_START", "target")
		K.tick(ns, 0.5)
		Mock.targetCast = nil
		K.event(ns, "UNIT_SPELLCAST_STOP", "target")
		K.tick(ns, 0.5)
		-- A plain lighting too.
		Mock.targetCast = {}
		K.event(ns, "UNIT_SPELLCAST_START", "target")
		K.tick(ns, 0.5)
		if ns.Moments:Slot(1).state ~= "lit" then fail(s, "a plain cast did not light it") end
		K.release(ns)
		if Mock.secureAlphaWrites ~= 0 then fail(s, "SetAlpha was called on a secure button " .. Mock.secureAlphaWrites .. " times") end
		local b = ns.Moments:Button(1)
		if b._highlight or b._highlightTexture then fail(s, "the button has a highlight texture") end
		if b:GetAlpha() ~= 1 then fail(s, "the button's alpha is " .. tostring(b:GetAlpha())) end
	end)
end

local function lastPoint(b) return b.points[#b.points] end

do
	local s = name("the row sits left of the prompt, five to a row, and clear of the fight buttons on its right")
	with(s, function(ns)
		local prompt = ns.Prompt:GetButton()
		local one, two, three = ns.Moments:Button(1), ns.Moments:Button(2), ns.Moments:Button(3)
		local p1, p2 = lastPoint(one), lastPoint(two)
		if p1[1] ~= "RIGHT" or p1[2] ~= prompt or p1[3] ~= "LEFT" then fail(s, "the first is not right-to-left of the prompt: " .. tostring(p1[1]) .. "/" .. tostring(p1[3])) end
		if not (p1[4] < 0 and p2[4] < p1[4]) then fail(s, "the second is not further left: " .. tostring(p1[4]) .. " then " .. tostring(p2[4])) end
		if lastPoint(three)[5] ~= 0 then fail(s, "three buttons made a second row") end
	end, { known = { 2139, 1953, 11958 } })
	s = name("a sixth button starts a second row")
	with(s, function(ns)
		-- Counterspell, Ice Block, Blink, Evocation, Slow Fall and Cold Snap are armed: the
		-- sixth, in slot order, starts the second row.
		local armed = {}
		for n = 1, 10 do
			local slot = ns.Moments:Slot(n)
			if slot and slot.armed then armed[#armed + 1] = n end
		end
		if #armed ~= 6 then fail(s, "armed buttons: " .. #armed) return end
		for i, n in ipairs(armed) do
			local p = lastPoint(ns.Moments:Button(n))
			local want = i <= 5 and 0 or ns.Moments:Button(n):GetHeight() + 8
			if p[5] ~= want then fail(s, "button " .. i .. " (slot " .. n .. ") sits at y " .. tostring(p[5]) .. ", wanted " .. tostring(want)) end
		end
		if lastPoint(ns.Moments:Button(armed[6]))[4] ~= lastPoint(ns.Moments:Button(armed[1]))[4] then
			fail(s, "the second row does not start under the first button")
		end
	end)
end

do
	local s = name("no room on the left with the list above puts the row below the prompt")
	with(s, function(ns)
		ns.Prompt.state.queueAbove = true
		local prompt = ns.Prompt:GetButton()
		prompt._left = 20
		ns.Moments.Place(ns.db.profile.prompt)
		local p = lastPoint(ns.Moments:Button(1))
		if p[1] ~= "TOPLEFT" or p[3] ~= "BOTTOMLEFT" then fail(s, "not below: " .. tostring(p[1]) .. "/" .. tostring(p[3])) end
	end)
	s = name("no room on the left with the list below puts the row above the prompt")
	with(s, function(ns)
		ns.Prompt.state.queueAbove = false
		local prompt = ns.Prompt:GetButton()
		prompt._left = 20
		ns.Moments.Place(ns.db.profile.prompt)
		local p = lastPoint(ns.Moments:Button(1))
		if p[1] ~= "BOTTOMLEFT" or p[3] ~= "TOPLEFT" then fail(s, "not above: " .. tostring(p[1]) .. "/" .. tostring(p[3])) end
	end)
end

do
	local s = name("a key bound turns the mouse off and uses no cover; a click goes to the world; the key still casts while dark")
	with(s, function(ns)
		local b = ns.Moments:Button(1)
		if b._mouse then fail(s, "the mouse is on with a key bound") end
		K.pull(ns)
		K.tick(ns, 0.3)
		if ns.Moments:Slot(1).cover:IsShown() then fail(s, "a cover is up with a key bound") end
		if K.click(ns, 1) ~= "world" then fail(s, "a click did not go to the world") end
		Mock.pressBinding("CLICK MannersMoment1:LeftButton")
		local cast = false
		for _, e in ipairs(Mock.castLog or {}) do if e.spell == "Counterspell" then cast = true end end
		if not cast then fail(s, "the key did not cast while dark") end
	end, { bindings = { ["F1"] = "CLICK MannersMoment1:LeftButton" } })
end

do
	local s = name("no key: the cover is up while dark and a click casts nothing")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		local slot = ns.Moments:Slot(1)
		if not slot.cover:IsShown() then fail(s, "the cover is down while dark") end
		local before = #(Mock.castLog or {})
		if K.click(ns, 1) ~= slot.cover then fail(s, "the cover did not take the click") end
		if #(Mock.castLog or {}) ~= before then fail(s, "a click on a dark button cast") end
		if slot.tally.cover ~= 1 then fail(s, "the swallowed click was not counted") end
		if not trailHas(ns, "the cover took a click") then fail(s, "no trail line for the swallowed click") end
	end)
	s = name("no key: lit, the click reaches the button and casts")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		local slot = ns.Moments:Slot(1)
		if slot.cover:IsShown() then fail(s, "the cover is up while lit") end
		local before = #(Mock.castLog or {})
		if K.click(ns, 1) ~= ns.Moments:Button(1) then fail(s, "the click did not reach the button") end
		if #(Mock.castLog or {}) <= before then fail(s, "a click on a lit button cast nothing") end
	end)
end

do
	local s = name("Show the fight buttons at All fight changes nothing: no button shows without its moment")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		if K.shown(ns, 1) ~= 0 then fail(s, "shown without a moment") end
		ns.db.profile.prompt.fightButtons = "always"
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		if K.shown(ns, 1) ~= 0 then fail(s, "All fight lit a button with no moment") end
	end, { edit = function(p) p.prompt.fightButtons = "always" end })
end

do
	local s = name("hover while dark shows no highlight and no tooltip; hover in a game-painted state shows no tooltip")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		local b, slot = ns.Moments:Button(1), ns.Moments:Slot(1)
		b.scripts.OnEnter(b)
		if slot.hover:IsShown() then fail(s, "a highlight shows while dark") end
		if GameTooltip:IsShown() then fail(s, "a tooltip shows while dark") end
		b.scripts.OnLeave(b)
		Mock.targetCast = { secret = true, notInterruptible = false }
		K.event(ns, "UNIT_SPELLCAST_START", "target")
		K.tick(ns, 0.3)
		if slot.state ~= "game" then fail(s, "not left to the game: " .. slot.state) end
		b.scripts.OnEnter(b)
		if GameTooltip:IsShown() then fail(s, "a tooltip shows in a game-painted state") end
		b.scripts.OnLeave(b)
		Mock.targetCast = { }
		K.event(ns, "UNIT_SPELLCAST_START", "target")
		K.tick(ns, 0.3)
		b.scripts.OnEnter(b)
		if slot.state == "lit" and not GameTooltip:IsShown() then fail(s, "a lit button shows no tooltip") end
		b.scripts.OnLeave(b)
		if GameTooltip:IsShown() then fail(s, "the tooltip stayed after the mouse left") end
	end)
end

do
	local s = name("a press lets the prompt's waiting press go")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		local let = nil
		local real = ns.ExpirePendingClick
		ns.pendingClick = { name = "someone" }
		ns.ExpirePendingClick = function(pending, said) let = said return real and real(pending, said) end
		Mock.pressBinding("CLICK MannersMoment1:LeftButton")
		K.click(ns, 1)
		ns.ExpirePendingClick = real
		ns.pendingClick = nil
		if not let or not tostring(let):find("Counterspell", 1, true) then fail(s, "the prompt's press was not let go, said: " .. tostring(let)) end
	end)
end

do
	local s = name("a paint call the game refuses is tried once and named on the trail; the signal turns blind, so Counterspell lights on the cast alone")
	with(s, function(ns)
		Mock.refuseAlphaFromBoolean = true
		K.pull(ns)
		K.cast(ns, { secret = true, notInterruptible = false })
		K.tick(ns, 0.3)
		if not trailHas(ns, "the game refused not paint") then fail(s, "the refusal is not on the trail") end
		if ns.Moments:Slot(1).state ~= "lit" then fail(s, "a weak row is not lit on the cast alone: " .. ns.Moments:Slot(1).state) end
		if K.shown(ns, 1) ~= 1 then fail(s, "nothing shows") end
		-- Tried once: a second cast does not try again, so no second line.
		K.endCast(ns)
		K.cast(ns, { secret = true, notInterruptible = false })
		K.tick(ns, 0.3)
		local n = 0
		for _, e in ipairs(ns.addon.db.char.trail or {}) do
			if tostring(e.text):find("the game refused not paint", 1, true) then n = n + 1 end
		end
		if n ~= 1 then fail(s, "the refusal was written " .. n .. " times") end
	end)
end

do
	local s = name("events are registered at the pull and gone at the release: a cast event after the release does nothing")
	with(s, function(ns)
		local frame = ns.Moments:Frame()
		if frame.unitEvents and frame.unitEvents.UNIT_SPELLCAST_START then fail(s, "registered before the pull") end
		K.pull(ns)
		if not (frame.unitEvents and frame.unitEvents.UNIT_SPELLCAST_START) then fail(s, "not registered at the pull") end
		K.release(ns)
		if frame.unitEvents and frame.unitEvents.UNIT_SPELLCAST_START then fail(s, "still registered after the release") end
		Mock.targetCast = {}
		if K.event(ns, "UNIT_SPELLCAST_START", "target") then fail(s, "an event was delivered after the release") end
		if ns.Moments:Slot(1).state ~= "dark" then fail(s, "lit after the release") end
	end)
end

do
	local s = name("a cast event for another unit does nothing")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.targetCast = {}
		if K.event(ns, "UNIT_SPELLCAST_START", "focus") then fail(s, "an event for the focus was delivered") end
		if K.event(ns, "UNIT_SPELLCAST_START", "player") then fail(s, "an event for you was delivered") end
		K.tick(ns, 0.3)
		if ns.Moments:Slot(1).state ~= "dark" then fail(s, "lit by another unit's cast") end
	end)
end

do
	local s = name("an event name the client lacks is skipped and the rest of the pull's events are registered")
	with(s, function(ns)
		local frame = ns.Moments:Frame()
		local lacks = {}
		for _, n in ipairs(ns.Sense.lacking) do lacks[n] = true end
		if not lacks.UNIT_SPELLCAST_EMPOWER_START then fail(s, "the empower event was not probed as lacking") end
		K.pull(ns)
		if frame.unitEvents.UNIT_SPELLCAST_EMPOWER_START then fail(s, "a name the client lacks was registered") end
		for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }) do
			if not frame.unitEvents[e] then fail(s, e .. " was not registered") end
		end
	end)
end

do
	local s = name("a click that gets past the cover is counted, logged, and told once after the fight")
	with(s, function(ns)
		Mock.coverLeaks = true
		K.pull(ns)
		K.tick(ns, 0.3)
		K.click(ns, 1)
		K.click(ns, 1)
		local slot = ns.Moments:Slot(1)
		if slot.tally.leak ~= 2 then fail(s, "the leaks counted: " .. slot.tally.leak) end
		if (ns.db.global.momentCoverLeaks or 0) ~= 2 then fail(s, "the account's count: " .. tostring(ns.db.global.momentCoverLeaks)) end
		if not trailHas(ns, "the cover let a click through") then fail(s, "no trail line") end
		local said = 0
		local real = ns.addon.Print
		ns.addon.Print = function(self, text)
			if tostring(text):find("a click reached a button for the moment", 1, true) then said = said + 1 end
			return real(self, text)
		end
		K.release(ns)
		K.pull(ns)
		K.click(ns, 1)
		K.release(ns)
		ns.addon.Print = real
		if said ~= 1 then fail(s, "told " .. said .. " times, not once") end
	end)
end

do
	local s = name("an idle scan with every switch on asks the client nothing")
	with(s, function(ns)
		for _ = 1, 3 do ns.addon:Tick() end
		for call in pairs(Mock.asked) do Mock.asked[call] = 0 end
		for _ = 1, 20 do ns.Moments:Wanted() end
		local asked = 0
		for call, n in pairs(Mock.asked) do asked = asked + n end
		if asked > 0 then fail(s, "an idle scan asked the client " .. asked .. " times") end
	end, { count = { "InCombatLockdown", "UnitCastingInfo", "UnitChannelInfo", "C_Spell.GetSpellCooldown", "UnitHealth", "UnitPower" } })
end
