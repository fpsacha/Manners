-- The names in the list under the prompt as buttons: one left click on a name
-- buffs that person as a press on the prompt would have, and files it the same
-- way (Prompt/Rows.lua).
--
-- Each row is a secure button registered and silenced as the prompt is, with
-- no macro at rest: PreClick arms it from a fresh queue by the very routine
-- the prompt is armed by, PostClick files the press by the very handler the
-- prompt's goes through, and lets it go. Blizzard's own click-through type
-- would hand the prompt an up click, which a button registered for "AnyDown"
-- with pressAndHoldAction treats as the end of a press (Rows.lua says why).
--
-- The mock has no secure handler, so a click is driven the way compat-fixes.lua
-- drives one: PreClick, then the type and macro the client would look up for
-- the button and the modifiers held (SecureButton_GetModifiedAttribute), then
-- PostClick; and, as the client does, nothing at all for a hidden frame.
--
-- Every scenario name starts with "hunt25-rows:" so the mutations in
-- tests/mutations/hunt25-rows.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
	nameplate3 = { "Cara", "Close" }, nameplate4 = { "Dane", "Dusk" } }
local CROWD = {}
for i, name in ipairs({ "Anna", "Bert", "Cara", "Dane", "Edda", "Finn", "Gwen", "Hugo" }) do
	CROWD["nameplate" .. i] = { name, "Near" }
end
local FLAVOURS = { "camelot", "vanilla", "mainline" }

-- ------------------------------------------------------------------ the client's side

-- frame:GetAttribute(prefix, name, suffix), in the order the client searches.
local function lookup(frame, prefix, name, suffix)
	local a = frame.attributes
	for _, key in ipairs({ prefix .. name .. suffix, "*" .. name .. suffix,
		prefix .. name .. "*", "*" .. name .. "*", name }) do
		if a[key] ~= nil then return a[key] end
	end
	return nil
end

-- SecureButton_GetButtonSuffix.
local function suffix(button)
	if button == "LeftButton" then return "1" end
	if button == "RightButton" then return "2" end
	if button == "MiddleButton" then return "3" end
	local n = tonumber(button:match("^Button(%d+)$") or "")
	if n and n >= 4 and n <= 31 then return tostring(n) end
	return "-" .. button
end

-- What a click with `button` and the modifiers in `prefix` runs: the macro's
-- text, or nil for no action.
local function runs(frame, button, prefix)
	if lookup(frame, prefix, "type", suffix(button)) ~= "macro" then return nil end
	return lookup(frame, prefix, "macrotext", suffix(button))
end

local PREFIXES = { "", "shift-", "ctrl-", "ctrl-shift-", "alt-", "alt-shift-", "alt-ctrl-", "alt-ctrl-shift-" }
local OTHERS = { "RightButton", "MiddleButton" }
for n = 4, 31 do OTHERS[#OTHERS + 1] = "Button" .. n end

-- One click on a button registered for "AnyDown": PreClick, the secure
-- handler, PostClick. Answers the macro that ran, nil for none. A hidden
-- frame is not clicked.
local function click(button, which, prefix, down)
	if not button:IsVisible() then return nil, "hidden" end
	which = which or "LeftButton"
	down = down ~= false
	local pre = button.scripts.PreClick
	if pre then pre(button, which, down) end
	local ran = runs(button, which, prefix or "")
	local post = button.scripts.PostClick
	if post then post(button, which, down) end
	return ran
end

-- Held while `body` runs, put back after: the shift key.
local function withShift(held, body)
	local real = IsShiftKeyDown
	IsShiftKeyDown = function() return held end
	local ok, err = pcall(body)
	IsShiftKeyDown = real
	if not ok then error(err, 0) end
end

-- ------------------------------------------------------------------ the world

-- A session on `flavour`: four strangers on nameplates, the list on with three
-- rows, the click option on, and the prompt up. `body` gets the loaded addon,
-- the prompt's regions (rowButtons among them) and the prompt's settings.
local function session(scenario, opts, body)
	opts = opts or {}
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.class = opts.class or "MAGE"
	if opts.tree then FT.install() end
	local restore = H.strangers(opts.people or PEOPLE)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		-- A first login parks the welcome and its preview on the clock.
		Mock.timers = {}
		local p = ns.db.profile.prompt
		p.showQueue, p.queueRows, p.clickRows = true, 3, true
		p.style = opts.style or "glass"
		ns.db.profile.speech.enabled = opts.speech == true
		if opts.edit then opts.edit(ns, p) end
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		if opts.tree then FT.settle() end
		body(ns, ns.Prompt:Regions(), p)
		Mock.inCombat = false
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	if opts.tree then FT.uninstall() end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Who the prompt is on and who each row names, read off what was painted.
local function top(ns) return ns.Prompt.state.current end
local function named(r, i)
	local row = r.rowButtons[i] and r.rowButtons[i].mannersRow
	return row and row.name
end

-- Whether a row holds a macro of any kind.
local function armed(button)
	for _, key in ipairs({ "type", "type1", "macrotext", "macrotext1" }) do
		if button.attributes[key] ~= nil then return key end
	end
	return nil
end

-- What the prompt would have cast on `entry`: the prompt armed at it, read
-- back, and put back on whoever it was on.
local function promptMacro(ns, entry)
	local P = ns.Prompt
	local was = P.state.current
	P:InvalidateMacro()
	P:ApplyTarget(entry)
	local macro = P:GetButton():GetAttribute("macrotext1")
	P:InvalidateMacro()
	P:ApplyTarget(was)
	return macro
end

local function lines(macro)
	local out = {}
	for line in tostring(macro or ""):gmatch("[^\n]+") do out[#out + 1] = line end
	return out
end

-- The queue's entry for a name.
local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
end

local function skipped(scenario, why)
	fail(scenario, "SKIPPED -- " .. why)
end

-- ------------------------------------------------------------------ 1
-- A click on a name arms that person with the macro the prompt would have
-- armed for them, on every client.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt25-rows: a click on the second name casts at that person (" .. flavour .. ")"
	session(scenario, { flavour = flavour }, function(ns, r)
		local second = named(r, 2)
		if not (second and r.rowButtons[2]:IsShown()) then
			return skipped(scenario, "no second name in the list: " .. tostring(second))
		end
		local want = promptMacro(ns, entryFor(ns, second))
		local ran = click(r.rowButtons[2])
		if not ran then
			fail(scenario, "a left click on the second name ran nothing")
			return
		end
		if not ran:find(second, 1, true) then
			fail(scenario, "the click did not aim at the second name, " .. second .. ": " .. ran:gsub("\n", " / "))
		end
		if ran ~= want then
			fail(scenario, "the macro of a row is not the macro of the prompt for the same person:\n"
				.. ran:gsub("\n", " / ") .. "\n" .. tostring(want):gsub("\n", " / "))
		end
		local shape = lines(ran)
		if not (shape[1] and shape[1]:find("^/target ") and shape[2] and shape[2]:find("^/cast ")) then
			fail(scenario, "not the /target and /cast shape: " .. ran:gsub("\n", " / "))
		end
		if ns.db.profile.filters.restoreTarget and shape[#shape] ~= "/targetlasttarget" then
			fail(scenario, "the target is not handed back with the switch on: " .. ran:gsub("\n", " / "))
		end
		if not (ns.pendingClick and ns.pendingClick.name == second) then
			fail(scenario, "the press was not filed for the second name: "
				.. tostring(ns.pendingClick and ns.pendingClick.name))
		end
	end)
end

-- ------------------------------------------------------------------ 2
-- Filed as the prompt files a press: the same record, and the prompt itself
-- is left as it was.
do
	local scenario = "hunt25-rows: a click on a name files the press as a press on the prompt does"
	session(scenario, nil, function(ns, r)
		local second = named(r, 2)
		if not second then return skipped(scenario, "no second name") end
		local was = top(ns)
		local wasMacro = ns.Prompt:GetButton():GetAttribute("macrotext1")

		-- A press on the prompt first, for its record.
		H.pressButton(ns)
		local reference = ns.pendingClick
		if not reference then return skipped(scenario, "the prompt press filed nothing") end
		ns.AbandonPendingClick()
		Mock.advance(1)
		ns.addon:Tick()
		if not named(r, 2) then return skipped(scenario, "the list ran dry after the prompt press") end
		second = named(r, 2)
		wasMacro = ns.Prompt:GetButton():GetAttribute("macrotext1")
		was = top(ns)

		local aim = entryFor(ns, second).targetName
		local stopped = 0
		local stop = ns.Prompt.StopAttention
		ns.Prompt.StopAttention = function(...) stopped = stopped + 1 return stop(...) end
		click(r.rowButtons[2])
		ns.Prompt.StopAttention = stop
		if stopped > 0 then
			fail(scenario, "a press on a name stopped the prompt's own pulse, which is about the prompt's person")
		end
		local filed = ns.pendingClick
		if not filed then
			fail(scenario, "a click on a name filed nothing")
			return
		end
		for key, value in pairs(reference) do
			if key ~= "name" and key ~= "at" and key ~= "gave" and type(filed[key]) ~= type(value) then
				fail(scenario, "the record of a press on a name lacks " .. key
					.. ", which a press on the prompt files")
			end
		end
		for key in pairs(filed) do
			if reference[key] == nil and key ~= "gave" and key ~= "shoutMembers" and key ~= "wideMembers" then
				fail(scenario, "the record of a press on a name carries " .. key .. ", which the prompt's never does")
			end
		end
		if filed.name ~= second or filed.targeted ~= true or filed.aimedAt ~= aim then
			fail(scenario, "the record names the wrong person or aim: " .. tostring(filed.name) .. " / "
				.. tostring(filed.aimedAt))
		end
		if not ns.tried or next(ns.tried) == nil then
			fail(scenario, "the press left no mark that this buff was tried on them")
		end
		-- The prompt is still on its own person with its own macro.
		if top(ns) ~= was or ns.Prompt:GetButton():GetAttribute("macrotext1") ~= wasMacro then
			fail(scenario, "a click on a name moved the prompt off its own person")
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- A favour is repaid when the cast lands; the prompt's own debt stands.
for _, flavour in ipairs(FLAVOURS) do
	local scenario = "hunt25-rows: a favour is repaid when a cast on a name lands (" .. flavour .. ")"
	session(scenario, { flavour = flavour }, function(ns, r)
		local first, second = top(ns), named(r, 1)
		if not (first and second) then return skipped(scenario, "nobody listed") end
		H.owe(ns, first.name)
		H.owe(ns, second)
		ns.addon:Tick()
		-- Whoever is owed longest is on the prompt, the other first in the list.
		local row = r.rowButtons[1].mannersRow
		if not (row.entry and row.entry.reason == "owed") then
			return skipped(scenario, "the first name is not owed: " .. tostring(row.entry and row.entry.reason))
		end
		local owedName, other = row.name, top(ns).name
		Mock.advance(1)
		local ran = click(r.rowButtons[1])
		if not (ran and ran:find(owedName, 1, true)) then
			fail(scenario, "the click did not cast at " .. owedName .. ": " .. tostring(ran))
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-row1", 1459)
		if ns.owed[owedName] then
			fail(scenario, "the favour was not marked repaid when the cast on " .. owedName .. " landed")
		end
		if not ns.owed[other] then
			fail(scenario, "the cast on a name repaid the prompt's person as well")
		end
	end)
end

-- ------------------------------------------------------------------ 4
-- A refusal backs off the name pressed, not the prompt's person.
do
	local scenario = "hunt25-rows: a refused cast on a name backs off that name and not the prompt's"
	session(scenario, nil, function(ns, r)
		local second, first = named(r, 2), top(ns).name
		if not second then return skipped(scenario, "no second name") end
		Mock.advance(1)
		local ran = click(r.rowButtons[2])
		if not ran then return skipped(scenario, "the click ran nothing") end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-row2", 1459)
		Mock.advance(0.1)
		ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-row2", 1459)
		ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
		if not ns.IsBlocked(second, nil, GetTime() + 1) then
			fail(scenario, second .. " was not backed off after the game refused the cast")
		end
		if ns.IsBlocked(first, nil, GetTime() + 1) then
			fail(scenario, "the refusal backed off the prompt's person, " .. first)
		end

		-- The macro's own /target is not the player choosing them: the client
		-- says their target changed, and the back-off stands (the list of who is
		-- backed off is where a lift shows: the two-second block stays either way).
		local function backedOff()
			for _, line in ipairs(ns.RefusalLines(GetTime())) do
				if line:find("backed off", 1, true) and line:find(second, 1, true) then return true end
			end
			return false
		end
		if not backedOff() then return skipped(scenario, second .. " is not listed as backed off to begin with") end
		for _, pair in pairs(PEOPLE) do
			if second:find(pair[1], 1, true) then Mock.unitNames.target = pair end
		end
		if Mock.unitNames.target then ns.addon:PLAYER_TARGET_CHANGED() end
		if not backedOff() then
			fail(scenario, "the macro's own /target on " .. second .. " lifted the back-off as a choice of the player's")
		end
		Mock.unitNames.target = nil
	end)
end

-- ------------------------------------------------------------------ 5
-- The cooldown guard holds a click on a name back as it holds the prompt.
do
	local scenario = "hunt25-rows: a click on a name during the global cooldown casts nothing"
	session(scenario, nil, function(ns, r)
		local second = named(r, 2)
		if not second then return skipped(scenario, "no second name") end
		-- The client's own word: the global cooldown (spell 61304) is running.
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5 } }
		ns.pendingClick = nil
		local ran = click(r.rowButtons[2])
		if ran then fail(scenario, "a click in the global cooldown ran " .. ran:gsub("\n", " / ")) end
		if ns.pendingClick then fail(scenario, "a click in the global cooldown filed a press") end
		if armed(r.rowButtons[2]) then
			fail(scenario, "the row was left armed (" .. armed(r.rowButtons[2]) .. ") after a refused click")
		end
		-- And the cooldown over, the same click casts.
		Mock.spellCooldowns = nil
		Mock.advance(2)
		ns.addon:Tick()
		if not click(r.rowButtons[2]) then
			fail(scenario, "the click did not cast once the cooldown was over")
		end
	end)
end

-- ------------------------------------------------------------------ 6
-- A name that has gone, or that now offers another buff, is not cast on.
do
	local scenario = "hunt25-rows: a name the scan no longer offers is not cast on"
	session(scenario, nil, function(ns, r)
		local second = named(r, 2)
		if not second then return skipped(scenario, "no second name") end
		-- Gone between the paint and the click.
		local real = ns.BuildQueue
		ns.BuildQueue = function(...)
			local out, verdicts = real(...)
			local kept = {}
			for _, entry in ipairs(out) do
				if entry.name ~= second then kept[#kept + 1] = entry end
			end
			return kept, verdicts
		end
		ns.pendingClick = nil
		local ran = click(r.rowButtons[2])
		if ran then fail(scenario, "a click on a name who is gone cast: " .. ran:gsub("\n", " / ")) end
		if ns.pendingClick then fail(scenario, "a click on a name who is gone filed a press") end
		if armed(r.rowButtons[2]) then fail(scenario, "the row kept a macro for somebody who is gone") end

		-- On another buff than the row said: painted with them again, then the scan
		-- offers them something else before the click.
		ns.BuildQueue = real
		Mock.advance(3)
		wipe(ns.tried)
		ns.addon:Tick()
		if named(r, 2) ~= second then return skipped(scenario, "the list did not hold " .. second .. " again") end
		ns.BuildQueue = function(...)
			local out, verdicts = real(...)
			local changed = {}
			for _, entry in ipairs(out) do
				if entry.name == second then
					local copy = {}
					for k, v in pairs(entry) do copy[k] = v end
					copy.buff = { key = "something-else", ranks = entry.buff.ranks, name = entry.buff.name }
					entry = copy
				end
				changed[#changed + 1] = entry
			end
			return changed, verdicts
		end
		ran = click(r.rowButtons[2])
		if ran then fail(scenario, "a click cast a buff the row did not say: " .. ran:gsub("\n", " / ")) end
		ns.BuildQueue = real
	end)
end

-- ------------------------------------------------------------------ 7
-- A row holds nothing at rest, and lets go of a press cut short.
do
	local scenario = "hunt25-rows: a row holds no macro at rest and lets go after the press"
	session(scenario, nil, function(ns, r)
		local button = r.rowButtons[2]
		local second = named(r, 2)
		if not second then return skipped(scenario, "no second name") end
		for i, b in ipairs(r.rowButtons) do
			if armed(b) then fail(scenario, "row " .. i .. " is armed at rest: " .. armed(b)) end
		end
		click(button)
		if armed(button) then fail(scenario, "the row is still armed after its press was filed: " .. armed(button)) end
		if button.mannersRow.current ~= nil or button.mannersRow.appliedKey ~= nil then
			fail(scenario, "the row still stands armed in its state after the press")
		end

		-- A press cut short: PreClick ran and PostClick never did.
		Mock.advance(2)
		ns.addon:Tick()
		local again = r.rowButtons[1]
		if not named(r, 1) then return skipped(scenario, "no first name for the second press") end
		again.scripts.PreClick(again, "LeftButton", true)
		if not armed(again) then return skipped(scenario, "PreClick armed nothing") end
		Mock.advance(1)
		ns.addon:Tick()
		if not armed(again) then
			fail(scenario, "a row armed for a second was let go at once")
		end
		Mock.advance(4)
		ns.addon:Tick()
		if armed(again) then
			fail(scenario, "a row armed and never pressed stayed armed past the timeout: " .. armed(again))
		end

		-- And at the start of a fight.
		Mock.advance(2)
		ns.addon:Tick()
		again.scripts.PreClick(again, "LeftButton", true)
		if not armed(again) then return skipped(scenario, "PreClick armed nothing the second time") end
		ns.addon:PLAYER_REGEN_DISABLED()
		if armed(again) then
			fail(scenario, "a row was still armed when the fight began: " .. armed(again))
		end
	end)
end

-- ------------------------------------------------------------------ 8
-- Inert in a fight: no cast, and no write to any of them.
do
	local scenario = "hunt25-rows: a click on a name in a fight does nothing at all"
	session(scenario, nil, function(ns, r)
		local second = named(r, 2)
		if not second then return skipped(scenario, "no second name") end
		for _, b in ipairs(r.rowButtons) do Mock.protect(b) end
		local frozen = ns.Prompt:GetButton():GetAttribute("macrotext1")
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.protectedCalls = {}
		ns.pendingClick = nil

		-- Every way a press can reach a name, in the two moments of a fight: the
		-- lockdown has begun and nothing has repainted yet (the names still hold
		-- what was painted), and the list has been blanked.
		local function clicks(moment)
			for _, which in ipairs({ "LeftButton", "RightButton" }) do
				for i, b in ipairs(r.rowButtons) do
					local ran = click(b, which)
					if ran then
						fail(scenario, ("%s: a %s click on row %d in a fight ran %s"):format(
							moment, which, i, ran:gsub("\n", " / ")))
					end
				end
			end
			withShift(true, function() click(r.rowButtons[2], "RightButton") end)
			if ns.pendingClick then fail(scenario, moment .. ": a click on a name in a fight filed a press") end
			for _, b in ipairs(r.rowButtons) do
				if armed(b) then fail(scenario, moment .. ": a row was armed in a fight: " .. armed(b)) end
			end
			if ns.IsBlocked(second, nil, GetTime() + 1) or ns.IsNeverOffered(second) then
				fail(scenario, moment .. ": a click on a name in a fight skipped or listed them")
			end
			-- The tooltip says nothing in a fight.
			Mock.tooltip = {}
			local b = r.rowButtons[2]
			if b.scripts.OnEnter then b.scripts.OnEnter(b) end
			if #Mock.tooltip > 0 then
				fail(scenario, moment .. ": a name's tooltip in a fight said: " .. table.concat(Mock.tooltip, " / "))
			end
			if b.scripts.OnLeave then b.scripts.OnLeave(b) end
		end
		clicks("before the repaint")
		ns.addon:Tick()
		clicks("after the repaint")
		if #Mock.protectedCalls > 0 then
			fail(scenario, "a click or a repaint in a fight touched a secure frame: "
				.. table.concat(Mock.protectedCalls, ", "))
		end
		-- The prompt is frozen on its person and a row click never casts at them.
		if ns.Prompt:GetButton():GetAttribute("macrotext1") ~= frozen then
			fail(scenario, "the fight's frozen macro changed")
		end
		-- After the fight the rows work again.
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		Mock.advance(2)
		ns.addon:Tick()
		if not named(r, 2) then return skipped(scenario, "the list did not come back after the fight") end
		if not click(r.rowButtons[2]) then
			fail(scenario, "the names do not cast again once the fight is over")
		end
	end)
end

-- ------------------------------------------------------------------ 9
-- Only the left button casts, with any modifier on any other button.
do
	local scenario = "hunt25-rows: only the left button casts from a name"
	session(scenario, { people = CROWD }, function(ns, r)
		local button = r.rowButtons[2]
		if not named(r, 2) then return skipped(scenario, "no second name") end
		-- Silenced from the start, not only once armed.
		for index = 2, 31 do
			if button.attributes["*type" .. index] ~= "none" then
				fail(scenario, "*type" .. index .. " is not silenced on a row at rest")
				break
			end
		end
		-- Armed as a left press arms it, before the handler reads it.
		button.scripts.PreClick(button, "LeftButton", true)
		if not armed(button) then return skipped(scenario, "nothing armed") end
		local running = {}
		for _, prefix in ipairs(PREFIXES) do
			if not runs(button, "LeftButton", prefix) then
				fail(scenario, "the left button no longer runs the macro as " .. prefix .. "LeftButton")
			end
			for _, other in ipairs(OTHERS) do
				if runs(button, other, prefix) then running[#running + 1] = prefix .. other end
			end
		end
		if #running > 0 then
			fail(scenario, #running .. " other click shapes run the macro, among them "
				.. table.concat(running, ", ", 1, math.min(4, #running)))
		end
		button.scripts.PostClick(button, "LeftButton", true)

		-- The down and the up of one press are one press.
		Mock.advance(2)
		ns.addon:Tick()
		ns.pendingClick = nil
		click(button, "LeftButton", "", true)
		local first = ns.pendingClick
		-- The up comes after a long press, past any debounce, and the person is
		-- as offerable as ever, so nothing but the phase keeps it from arming.
		Mock.advance(0.4)
		wipe(ns.tried)
		click(button, "LeftButton", "", false)
		if not first or ns.pendingClick ~= first then
			fail(scenario, "the up of a press was filed as a second press")
		end
		if armed(button) then
			fail(scenario, "the up of a press armed the row (" .. armed(button) .. ")")
		end

		-- And a click of any other button, whole, casts and files nothing (a
		-- right-click skips the name, which is not a cast: see below).
		Mock.advance(2)
		wipe(ns.tried)
		ns.addon:Tick()
		for _, which in ipairs({ "RightButton", "MiddleButton", "Button4", "Button5" }) do
			ns.pendingClick = nil
			Mock.advance(1)
			wipe(ns.tried)
			ns.addon:Tick()
			if not (button:IsShown() and named(r, 2)) then
				skipped(scenario, "row 2 holds nobody for the " .. which .. " click")
				break
			end
			if click(button, which) or ns.pendingClick then
				fail(scenario, "a " .. which .. " click cast or filed a press")
			end
			withShift(true, function()
				Mock.advance(1)
				if click(button, which, "shift-") or ns.pendingClick then
					fail(scenario, "a shift-" .. which .. " click cast or filed a press")
				end
			end)
			-- Nor does it leave the row armed for the next click to run.
			if armed(button) then
				fail(scenario, "a " .. which .. " click left the row armed (" .. armed(button) .. ")")
			end
		end
	end)
end

-- ------------------------------------------------------------------ 10
-- Right-click skips the name; shift-right-click puts them on the never list.
do
	local scenario = "hunt25-rows: right-click skips a name and shift-right-click lists them"
	session(scenario, nil, function(ns, r)
		local first = top(ns).name
		local second, third = named(r, 1), named(r, 2)
		if not (second and third) then return skipped(scenario, "fewer than two names in the list") end
		ns.pendingClick = nil
		Mock.printed = {}
		click(r.rowButtons[1], "RightButton")
		if ns.pendingClick then fail(scenario, "a right-click on a name filed a cast") end
		if not ns.IsBlocked(second, nil, GetTime() + 1) then
			fail(scenario, "a right-click on " .. second .. " did not skip them")
		end
		if ns.IsNeverOffered(second) then fail(scenario, "a plain right-click listed " .. second .. " as never") end
		if ns.IsBlocked(first, nil, GetTime() + 1) then
			fail(scenario, "a right-click on a name skipped the prompt's person")
		end
		Mock.advance(1)
		ns.addon:Tick()
		third = named(r, 1) or third
		Mock.printed = {}
		withShift(true, function() click(r.rowButtons[1], "RightButton", "shift-") end)
		if ns.pendingClick then fail(scenario, "a shift-right-click filed a cast") end
		if not ns.IsNeverOffered(third) then
			fail(scenario, "a shift-right-click on " .. third .. " did not put them on the never-offer list")
		end
		if ns.IsNeverOffered(first) or ns.IsNeverOffered(second) then
			fail(scenario, "a shift-right-click listed somebody else")
		end
		if not table.concat(Mock.printed, "\n"):find("/manners allow", 1, true) then
			fail(scenario, "the chat line did not say how to undo it: " .. table.concat(Mock.printed, " | "))
		end
	end)
end

-- ------------------------------------------------------------------ 11
-- Hidden rows are not clickable, and neither is a list switched off.
do
	local scenario = "hunt25-rows: hidden names are not clickable"
	session(scenario, { people = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } } },
		function(ns, r, p)
			-- Two people: one on the prompt, one in the list; rows 2 and 3 are empty.
			if not named(r, 1) then return skipped(scenario, "nobody in the list") end
			for i = 2, 3 do
				local b = r.rowButtons[i]
				if b:IsShown() then fail(scenario, "row " .. i .. " has nobody and is shown") end
				if named(r, i) then fail(scenario, "row " .. i .. " still names " .. named(r, i)) end
				ns.pendingClick = nil
				if click(b) or ns.pendingClick then fail(scenario, "an empty row cast") end
			end
			-- Even a click that reached an empty row's script casts nothing.
			local empty = r.rowButtons[3]
			empty.scripts.PreClick(empty, "LeftButton", true)
			if armed(empty) then fail(scenario, "an empty row was armed by a click") end

			-- The list switched off: no row shown, nothing to click.
			p.showQueue = false
			ns.Prompt:ApplyStyle()
			ns.addon:Tick()
			for i, b in ipairs(r.rowButtons) do
				if b:IsShown() then fail(scenario, "row " .. i .. " is shown with the list switched off") end
			end
			-- And the prompt down: the rows go with it.
			p.showQueue = true
			ns.Prompt:ApplyStyle()
			ns.addon:Tick()
			if not r.rowButtons[1]:IsShown() then return skipped(scenario, "the list did not come back") end
			ns.db.profile.enabled = false
			ns.addon:Tick()
			ns.Prompt:Refresh()
			for i, b in ipairs(r.rowButtons) do
				if b:IsShown() then fail(scenario, "row " .. i .. " is shown with the addon switched off") end
			end
			ns.db.profile.enabled = true
		end)
end

-- ------------------------------------------------------------------ 12
-- The option off leaves the names to read.
do
	local scenario = "hunt25-rows: the click option off leaves the list display-only"
	session(scenario, nil, function(ns, r, p)
		local second = named(r, 2)
		if not second then return skipped(scenario, "no second name") end
		if ns.defaults.profile.prompt.clickRows ~= true then
			fail(scenario, "clicking a name is not on by default")
		end
		p.clickRows = false
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		for i, b in ipairs(r.rowButtons) do
			if b:IsShown() then fail(scenario, "row " .. i .. " is clickable with the option off") end
			if armed(b) then fail(scenario, "row " .. i .. " is armed with the option off") end
		end
		if tostring(r.rows[2]:GetText() or "") == "" then
			fail(scenario, "the list lost its text with the option off")
		end
		local b = r.rowButtons[2]
		ns.pendingClick = nil
		b.scripts.PreClick(b, "LeftButton", true)
		if armed(b) then fail(scenario, "a click reached a row's script and armed it with the option off") end
		-- Back on.
		p.clickRows = true
		ns.Prompt:ApplyStyle()
		Mock.advance(1)
		ns.addon:Tick()
		if not (r.rowButtons[2]:IsShown() and click(r.rowButtons[2])) then
			fail(scenario, "the names do not cast with the option back on")
		end
		-- Switched off and a press arriving before the list is repainted: the
		-- row still names somebody, and must not be armed for them.
		ns.AbandonPendingClick()
		Mock.advance(2)
		wipe(ns.tried)
		ns.addon:Tick()
		if not named(r, 2) then return skipped(scenario, "row 2 holds nobody before the switch") end
		p.clickRows = false
		if click(r.rowButtons[2]) or armed(r.rowButtons[2]) then
			fail(scenario, "a press just after the option was switched off still cast")
		end
		p.clickRows = true
		-- And a profile that holds nonsense for it is repaired to on.
		p.clickRows = "yes please"
		ns.ClampSettings()
		if p.clickRows ~= true then fail(scenario, "a click option that is not a yes or a no was kept") end
	end)
end

-- ------------------------------------------------------------------ 13
-- Repainting the list writes no attribute on any row.
do
	local scenario = "hunt25-rows: repainting the list writes no attribute on a row"
	session(scenario, nil, function(ns, r)
		local writes = 0
		for _, b in ipairs(r.rowButtons) do
			local set = b.SetAttribute
			b.SetAttribute = function(self, ...) writes = writes + 1 return set(self, ...) end
		end
		for _ = 1, 12 do
			Mock.advance(0.4)
			ns.addon:Tick()
		end
		ns.Prompt:Refresh()
		if writes > 0 then
			fail(scenario, ("%d attribute writes on the rows while the list was repainted"):format(writes))
		end
	end)
end

-- ------------------------------------------------------------------ 14
-- A press on the prompt and a press on a name close together both file.
do
	local scenario = "hunt25-rows: a press on a name just after one on the prompt is its own press"
	session(scenario, nil, function(ns, r)
		local second = named(r, 2)
		if not second then return skipped(scenario, "no second name") end
		H.pressButton(ns)
		if not ns.pendingClick then return skipped(scenario, "the prompt press filed nothing") end
		Mock.advance(0.1)
		click(r.rowButtons[2])
		if not (ns.pendingClick and ns.pendingClick.name == second) then
			fail(scenario, "the press on the name inside a quarter second of the prompt's was swallowed: "
				.. tostring(ns.pendingClick and ns.pendingClick.name))
		end
	end)
end

-- ------------------------------------------------------------------ 15
-- The spoken line follows the same rules as a press on the prompt.
do
	local scenario = "hunt25-rows: a name's line is the prompt's, and is held back after a line to them"
	session(scenario, { speech = true }, function(ns, r)
		local second = named(r, 2)
		if not second then return skipped(scenario, "no second name") end
		local entry = entryFor(ns, second)
		local reference = lines(promptMacro(ns, entry))
		if #reference < 3 or reference[3]:find("^/targetlasttarget") then
			return skipped(scenario, "the prompt arms no line for them: " .. table.concat(reference, " / "))
		end
		Mock.advance(1)
		local ran = lines(click(r.rowButtons[2]))
		if #ran ~= #reference then
			fail(scenario, ("a name's macro has %d lines, the prompt's for them %d: %s"):format(
				#ran, #reference, table.concat(ran, " / ")))
		end
		-- A line went to them a moment ago: the next press on them is silent.
		ns.AbandonPendingClick()
		Mock.advance(2)
		ns.addon:Tick()
		local again = named(r, 2)
		if not again then return skipped(scenario, "the list ran dry") end
		ns.NoteLineSaid(again, GetTime())
		local plainShape = lines(promptMacro(ns, entryFor(ns, again)))
		local quiet = lines(click(r.rowButtons[2]))
		if #quiet ~= #plainShape then
			fail(scenario, "a name's macro disagrees with the prompt's after a line to them: "
				.. table.concat(quiet, " / "))
		end
		if #quiet >= #reference then
			fail(scenario, "a line went to somebody who had just had one: " .. table.concat(quiet, " / "))
		end
	end)
end

-- ------------------------------------------------------------------ geometry

-- Where each region sits, worked out from the anchors as the client does: two
-- edges on an axis give its extent, one edge and a size the rest.
local function layout(snapshot)
	local byId, rects = {}, {}
	local root
	for _, r in ipairs(snapshot) do
		byId[r.id] = r
		if r.parent == nil then root = r.id end
	end
	local function frac(point)
		local fx, fy = 0.5, 0.5
		if point:find("LEFT", 1, true) then fx = 0 elseif point:find("RIGHT", 1, true) then fx = 1 end
		if point:find("BOTTOM", 1, true) then fy = 0 elseif point:find("TOP", 1, true) then fy = 1 end
		return fx, fy
	end
	local busy = {}
	local function rect(id)
		if rects[id] then return rects[id] end
		if id == root then rects[id] = { 0, 0, 1600, 1000 } return rects[id] end
		local r = byId[id]
		if not r or busy[id] then return nil end
		busy[id] = true
		local L, R, B, T, CX, CY
		for _, p in ipairs(r.points or {}) do
			local rel = rect(p[2] or r.parent)
			if rel then
				local rfx, rfy = frac(p[3] or p[1])
				local ax = rel[1] + (rel[3] - rel[1]) * rfx + (p[4] or 0)
				local ay = rel[2] + (rel[4] - rel[2]) * rfy + (p[5] or 0)
				local fx, fy = frac(p[1])
				if fx == 0 then L = ax elseif fx == 1 then R = ax else CX = ax end
				if fy == 0 then B = ay elseif fy == 1 then T = ay else CY = ay end
			end
		end
		local w, h = r.width or 0, r.height or 0
		if not (L and R) then
			if L then R = L + w elseif R then L = R - w elseif CX then L, R = CX - w / 2, CX + w / 2 end
		end
		if not (B and T) then
			if B then T = B + h elseif T then B = T - h elseif CY then B, T = CY - h / 2, CY + h / 2 end
		end
		busy[id] = nil
		if not (L and R and B and T) then return nil end
		rects[id] = { L, B, R, T }
		return rects[id]
	end
	return rect
end

-- ------------------------------------------------------------------ 16
-- Every visible name has a click area covering its text, in every look, with
-- the list below the prompt and above it; a name that is not there has none.
for _, style in ipairs({ "glass", "framed", "minimal", "luxe", "toast", "arcane", "heritage" }) do
	for _, above in ipairs({ false, true }) do
		local scenario = ("hunt25-rows: every visible name has a click area (%s, list %s)")
			:format(style, above and "above" or "below")
		session(scenario, { tree = true, style = style, edit = function()
			Mock.promptCentreY = above and 40 or 700
		end }, function(ns, r, p)
			local rect = layout(FT.snapshot(UIParent))
			local shown, prior = 0, nil
			for i, button in ipairs(r.rowButtons) do
				local text = tostring(r.rows[i]:GetText() or "")
				if text == "" then
					if button:IsShown() then fail(scenario, "row " .. i .. " has no text and is shown") end
				else
					shown = shown + 1
					if not button:IsShown() then
						fail(scenario, "row " .. i .. " reads " .. text .. " and cannot be clicked")
					else
						local b, f = rect(button._serial), rect(r.rows[i]._serial)
						if not (b and f) then
							fail(scenario, "row " .. i .. ": the click area or the text could not be placed")
						else
							if b[3] - b[1] < 20 or b[4] - b[2] < p.fontSize then
								fail(scenario, ("row %d's click area is %.0f by %.0f, too small to hit")
									:format(i, b[3] - b[1], b[4] - b[2]))
							end
							if b[1] > f[1] + 0.01 or b[3] < f[3] - 0.01 then
								fail(scenario, "row " .. i .. "'s click area does not span its text")
							end
							local mid = (f[2] + f[4]) / 2
							if mid < b[2] - 0.01 or mid > b[4] + 0.01 then
								fail(scenario, "row " .. i .. "'s click area misses its text's line")
							end
							-- The icon and the bar beside the text are part of the name.
							for _, part in ipairs({ r.rowIcons[i], r.bars[i] }) do
								if part:IsShown() then
									local box = rect(part._serial)
									if box and (box[1] < b[1] - 0.01 or box[3] > b[3] + 0.01) then
										fail(scenario, "row " .. i .. ": a marker lies outside its click area")
									end
								end
							end
							-- As tall as the look says its rows are apart (the built-in looks',
							-- the font's size and four).
							local want = r.look and r.look.pitch or (p.fontSize + 4)
							if math.abs((b[4] - b[2]) - want) > 0.01 then
								fail(scenario, ("row %d's click area is %.1f tall, the rows are %.1f apart")
									:format(i, b[4] - b[2], want))
							end
							-- Neighbours meet: the areas are as tall as the rows are apart.
							local centre = (b[2] + b[4]) / 2
							if prior and math.abs(math.abs(prior - centre) - (b[4] - b[2])) > 0.6 then
								fail(scenario, ("the click areas of rows %d and %d leave a gap or overlap")
									:format(i - 1, i))
							end
							prior = centre
						end
					end
				end
			end
			if shown < 2 then skipped(scenario, "fewer than two names to test") end
		end)
	end
end

-- ------------------------------------------------------------------ shapes

-- A copy of a queue entry with fields changed.
local function variant(entry, changes)
	local copy = {}
	for k, v in pairs(entry) do copy[k] = v end
	for k, v in pairs(changes) do copy[k] = v end
	return copy
end

-- The queue handed back as it is, with `extra` after whoever is first.
local function withQueue(ns, build)
	local real = ns.BuildQueue
	ns.BuildQueue = function(...)
		local queue, verdicts = real(...)
		if type(queue) ~= "table" or #queue == 0 then return queue, verdicts end
		return build(queue), verdicts
	end
	return function() ns.BuildQueue = real end
end

-- ------------------------------------------------------------------ 17
-- Every shape of press a name can ask for is the prompt's macro for it: a
-- group cast, a shout, your own buff, a mage's scroll.
do
	local scenario = "hunt25-rows: a name asks for every shape of macro as the prompt does"
	session(scenario, nil, function(ns, r)
		local base = ns.BuildQueue()
		if #base < 3 then return skipped(scenario, "too few people on nameplates") end
		local second = base[2]
		local you = ns.UnitFullName("player") or "Player"
		local shapes = {
			{ "a group cast", variant(second, { display = "Your party", groupCast = {
				spell = 1459, spellName = "Arcane Brilliance", icon = 4001, missing = 3, low = 0,
				members = { base[3].name }, label = "your party", reagent = 17020, reagents = 5 } }) },
			{ "a shout", variant(second, { buff = { key = "shoutx", ranks = { 1459 }, selfCast = true } }) },
			{ "your own buff", variant(second, { reason = "self", name = you, short = you, targetName = you,
				buff = { key = "armorx", ranks = { 1459 }, selfOnly = true } }) },
			{ "a scroll", variant(second, { reason = "self", name = you, short = you, targetName = you,
				buff = { key = "scrollx", ranks = { 1459 }, item = 5555 } }) },
			{ "a single buff", second },
		}
		for _, shape in ipairs(shapes) do
			local label, entry = shape[1], shape[2]
			local restore = withQueue(ns, function(queue) return { queue[1], entry } end)
			Mock.advance(3)
			ns.pendingClick = nil
			ns.addon:Tick()
			local button = r.rowButtons[1]
			if not (button:IsShown() and named(r, 1) == entry.name) then
				skipped(scenario, label .. ": the list does not hold it")
			else
				local want = promptMacro(ns, entry)
				local ran = click(button)
				if not ran then
					fail(scenario, label .. ": the click ran nothing")
				elseif ran ~= want then
					fail(scenario, label .. ": not the prompt's macro:\n" .. ran:gsub("\n", " / ")
						.. "\n" .. tostring(want):gsub("\n", " / "))
				end
				if shape[1] == "a group cast" and ran and not ran:find("Arcane Brilliance", 1, true) then
					fail(scenario, "a group cast casts the single spell: " .. ran:gsub("\n", " / "))
				end
				if shape[1] == "a scroll" and ran and not ran:find("/use item:5555", 1, true) then
					fail(scenario, "a scroll is not used from the bags: " .. ran:gsub("\n", " / "))
				end
				if shape[1] == "a shout" and ran and ran:find("/target", 1, true) then
					fail(scenario, "a shout targets somebody: " .. ran:gsub("\n", " / "))
				end
				if not ns.pendingClick then fail(scenario, label .. ": the press was filed for nobody") end
			end
			restore()
			ns.AbandonPendingClick()
		end
	end)
end

-- ------------------------------------------------------------------ 18
-- Each name wears the icon of the buff it offers, on the three looks drawn
-- here with the spell icon on; the preview's mock names wear one too and none
-- of them can be pressed.
do
	local scenario = "hunt25-rows: each name wears the icon of its own buff"
	session(scenario, nil, function(ns, r, p)
		local base = ns.BuildQueue()
		if #base < 4 then return skipped(scenario, "too few people on nameplates") end
		-- Two buffs the client knows by an icon each, made up for the purpose.
		ns.caps.buffs.iconA = { icon = 7001, name = "Buff A", known = true }
		ns.caps.buffs.iconB = { icon = 7002, name = "Buff B", known = true }
		local fortitude = { key = "iconA", ranks = { 1459 } }
		local spirit = { key = "iconB", ranks = { 1459 } }
		local seen = {}
		for i, icon in ipairs(r.rowIcons) do
			icon.SetTexture = function(self, file) seen[i] = file end
		end
		local group = variant(base[4], { groupCast = { spell = 1, spellName = "Group Buff",
			icon = 7003, missing = 2, low = 0, members = {}, label = "your party" } })
		local restore = withQueue(ns, function(queue)
			return { queue[1], variant(queue[2], { buff = fortitude }), variant(queue[3], { buff = spirit }), group }
		end)
		p.queueRows = 3
		ns.Prompt:ApplyStyle()
		Mock.advance(1)
		ns.addon:Tick()
		if seen[1] ~= 7001 or seen[2] ~= 7002 or seen[3] ~= 7003 then
			fail(scenario, ("the rows wear %s, %s, %s, not the icons of their buffs (7001, 7002, 7003)")
				:format(tostring(seen[1]), tostring(seen[2]), tostring(seen[3])))
		end
		for i = 1, 3 do
			if not r.rowIcons[i]:IsShown() then fail(scenario, "row " .. i .. " has no icon shown") end
		end

		-- The spell icon off: no icons in the list.
		p.showIcon = false
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		for i = 1, 3 do
			if r.rowIcons[i]:IsShown() then fail(scenario, "row " .. i .. " keeps its icon with the spell icon off") end
		end
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()

		-- A look of its own lays the list out itself, without them.
		p.style = "luxe"
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		for i = 1, 3 do
			if r.rowIcons[i]:IsShown() then fail(scenario, "row " .. i .. " shows an icon the look does not lay out") end
		end
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		restore()

		-- The preview's mock names: icon yes, button no.
		Mock.optionsOpen = true
		ns.Prompt:ToggleTest()
		ns.Prompt:Refresh()
		for i = 1, 3 do
			if not r.rowIcons[i]:IsShown() then fail(scenario, "preview row " .. i .. " has no icon") end
			if r.rowButtons[i]:IsShown() then fail(scenario, "preview row " .. i .. " can be clicked") end
		end
		ns.Prompt:ToggleTest()
		Mock.optionsOpen = nil
	end)
end

-- ------------------------------------------------------------------ 19
-- The tooltip over a name says what the prompt says of that person.
do
	local scenario = "hunt25-rows: the tooltip over a name is the prompt's for that person"
	session(scenario, nil, function(ns, r)
		local second = named(r, 2)
		if not second then return skipped(scenario, "no second name") end
		local entry = entryFor(ns, second)
		local P = ns.Prompt
		local was = P.state.current
		-- What the prompt says when it is on them.
		P:InvalidateMacro()
		P:ApplyTarget(entry)
		local button = P:GetButton()
		Mock.tooltip = {}
		button.scripts.OnEnter(button)
		local want = table.concat(Mock.tooltip, "\n")
		button.scripts.OnLeave(button)
		P:InvalidateMacro()
		P:ApplyTarget(was)
		if want == "" then return skipped(scenario, "the prompt's tooltip was empty") end

		Mock.tooltip = {}
		local row = r.rowButtons[2]
		row.scripts.OnEnter(row)
		local got = table.concat(Mock.tooltip, "\n")
		if got ~= want then
			fail(scenario, "the tooltip over the name differs from the prompt's:\n" .. got .. "\n--\n" .. want)
		end
		for _, word in ipairs({ "Click to cast", "Right-click to skip", "Shift-right-click" }) do
			if not got:find(word, 1, true) then fail(scenario, "the tooltip lacks \"" .. word .. "\"") end
		end
		-- Left again, it lets go of the name.
		row.scripts.OnLeave(row)
		if row.mannersRow.hovered then fail(scenario, "the row still thinks the cursor is on it") end
	end)
end

-- ------------------------------------------------------------------ 20
-- A preview still up when a fight starts does not move the lines that the
-- names' buttons hang from: the client will not have it done in combat.
do
	local scenario = "hunt25-rows: the list's lines stay where they are in a fight"
	session(scenario, { edit = function() Mock.promptCentreY = 40 end }, function(ns, r)
		Mock.optionsOpen = true
		ns.Prompt:ToggleTest()
		ns.Prompt:Refresh()
		local moved = 0
		for _, fs in ipairs(r.rows) do
			local set, clear = fs.SetPoint, fs.ClearAllPoints
			fs.SetPoint = function(self, ...) moved = moved + 1 return set(self, ...) end
			fs.ClearAllPoints = function(self, ...) moved = moved + 1 return clear(self, ...) end
		end
		-- The refresh just before the lockdown is out of combat and may place them.
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		moved = 0
		ns.addon:Tick()
		ns.Prompt:Refresh()
		Mock.advance(5)
		ns.Prompt:Refresh()
		if moved > 0 then
			fail(scenario, ("a preview in a fight placed the list's lines %d times"):format(moved))
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		ns.Prompt:ToggleTest()
		Mock.optionsOpen = nil
	end)
end

-- ------------------------------------------------------------------ 21
-- A name keeps the whole width the list had before its icon came: the icon
-- sits in the margin left of the text, under the prompt's own icon. Pushed
-- right by it, a long name and its reason no longer fitted and were drawn cut.
-- And the icon is never wider than that margin holds beside the bar, even
-- with the smallest prompt icon under the largest font.
do
	local scenario = "hunt25-rows: a name keeps its width beside its icon"
	session(scenario, nil, function(ns, r, p)
		p.showIcon = true
		ns.Prompt:ApplyStyle()
		local S = ns.Prompt.state
		local textX = 10 + p.iconSize + 10
		if S.queueTextX ~= textX then
			fail(scenario, ("the list's text starts at %s, not %s: pushed right by its icon")
				:format(tostring(S.queueTextX), textX))
		end
		local width = math.max(20, p.width - textX - 8)
		if r.rows[1]:GetWidth() ~= width then
			fail(scenario, ("a name has %s to fit into, not the %s the list had: pushed right by its icon")
				:format(tostring(r.rows[1]:GetWidth()), width))
		end

		local iconSize, fontSize = p.iconSize, p.fontSize
		p.iconSize, p.fontSize = 12, 32
		ns.Prompt:ApplyStyle()
		local margin = 10 + 12 + 10 - 12
		local w = r.rowIcons[1]:GetWidth()
		if w > margin then
			fail(scenario, ("with a 12 icon and a 32 font a name's icon is %s wide, wider than the margin's %s")
				:format(tostring(w), margin))
		end
		p.iconSize, p.fontSize = iconSize, fontSize
		ns.Prompt:ApplyStyle()
	end)
end
