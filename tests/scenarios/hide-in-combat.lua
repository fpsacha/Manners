-- Hide the prompt in combat (Look; Prompt/Fight.lua): a player asked for the
-- prompt to be off the screen in a fight.
--
-- A hidden secure button still fires from its key binding and /click, and the
-- bar macro casts by its own lines, so hiding alone would cast the frozen
-- macro out of sight. The fight's driver (a SecureHandlerStateTemplate header,
-- "[combat] fight; peace") takes the macro off the prompt and its list rows and
-- only then hides it; the pull, just before the lockdown, leaves the bar macro
-- holding its first line alone, and the prompt is hidden only when the macro
-- reads back that way. These hold Manners to the mock's model of Blizzard's
-- state driver, restricted snippets and SecureActionButton_OnClick
-- (tests/mockwidgets.lua, "secure handlers"; tests/mockmacros.lua, "running
-- macros"), not to the client.
--
-- Every name starts with "hide-in-combat:" so a mutation in
-- tests/mutations/hide-in-combat.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, clearClicks = H.strangers, H.freshPrompt, H.owe, H.clearClicks

local BAR_LINE = "/click MannersBar"
local BINDING = "CLICK MannersPrompt:LeftButton"
local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local ANNA = { "Anna", "Aim" }
local BOB = { "Bob", "Bright" }
local HIDDEN_LINE = "hidden for this fight"
local STAYS_LINE = "stays up for this fight"

local function said() return table.concat(Mock.printed, "\n") end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end
local function bodyNow()
	local macro = Mock.macroList[GetMacroIndexByName("Manners")]
	return macro and macro.body or nil
end
local function castsSince(n)
	local out = {}
	for i = n + 1, #Mock.castLog do
		local e = Mock.castLog[i]
		if e.spell and not e.refused then out[#out + 1] = e end
	end
	return out
end

-- Forever unless a scenario names the client. Anna and Bob on nameplates, both
-- owed, the list on with its names clickable, the macro on bar slot 2.
local function with(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	local restore = strangers({ nameplate1 = { ANNA[1], ANNA[2] }, nameplate2 = { BOB[1], BOB[2] } })
	local saved = rawget(_G, "UnitGUID")
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			local p = ns.db.profile.prompt
			p.showQueue, p.queueRows, p.clickRows = true, 3, true
			p.hideInFight = opts.off ~= true
			ns.Prompt:ApplyStyle()
			owe(ns, "Anna Aim")
			owe(ns, "Bob Bright")
			ns.addon:Tick()
			ns.CreateClickMacro()
			Mock.dropOnBar(2)
			ns.addon:Tick()
			Mock.runTimers(0)
			body(ns, scenario, p)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	Mock.inCombat = false
	restore()
	rawset(_G, "UnitGUID", saved)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The pull as the client orders it: PLAYER_REGEN_DISABLED just before the
-- lockdown, then the lockdown, then the state driver's next frame (its timer
-- put to 0 by the same event). `between` runs after the event, before the
-- lockdown.
local function pull(ns, between)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	if between then between() end
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

-- The fight's end: the lockdown over, PLAYER_REGEN_ENABLED, and, unless
-- `noFrame`, the driver's next frame.
local function release(ns, noFrame)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	if noFrame then return end
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

-- Scans until the prompt is on `name`; whether it got there.
local function settleOn(ns, name)
	for _ = 1, 20 do
		local current = ns.Prompt.state.current
		if current and current.name == name and ns.Prompt:GetButton():IsShown() then return true end
		Mock.advance(1)
		ns.addon:Tick()
		Mock.runTimers(0)
	end
	return false
end

local function firstRow(ns)
	local rows = ns.Prompt:Regions().rowButtons
	return rows and rows[1]
end

-- ------------------------------------------------------------------ 1
-- In a fight the prompt and its list are off the screen, the bar macro holds
-- its first line alone, and nothing the addon itself did touched the secure
-- button in the fight. On every client.
for _, flavour in ipairs(FLAVOURS) do
	with("hide-in-combat: the prompt and its list are off the screen in a fight (" .. flavour .. ")", function(ns, scenario)
		local button = ns.Prompt:GetButton()
		local row = firstRow(ns)
		if not (button:IsShown() and button:GetAttribute("type1") == "macro") then
			fail(scenario, "SKIPPED -- the prompt is not up and armed before the fight")
			return
		end
		if not (row and row:IsShown()) then fail(scenario, "SKIPPED -- no name in the list before the fight") return end
		if not (bodyNow() or ""):find("/cast", 1, true) then
			fail(scenario, "SKIPPED -- the bar macro carries no cast before the fight: " .. flat(bodyNow()))
			return
		end
		Mock.protect(button)
		Mock.protectedCalls = {}
		pull(ns)
		if button:IsShown() then fail(scenario, "the prompt is still on the screen in the fight") end
		if row:IsVisible() then fail(scenario, "a name in the list is still on the screen in the fight") end
		if not ns.Prompt:HiddenForFight() then fail(scenario, "the prompt does not know it is hidden for the fight") end
		if bodyNow() ~= BAR_LINE then fail(scenario, "the bar macro holds " .. flat(bodyNow()) .. " in the fight") end
		if #Mock.protectedCalls > 0 then
			fail(scenario, "the addon's own code called " .. table.concat(Mock.protectedCalls, ", ") .. " on the secure button in the fight")
		end
		-- The fight goes on: the scans and the driver's frames change nothing.
		Mock.advance(1)
		ns.addon:Tick()
		Mock.runTimers(0.5)
		if button:IsShown() then fail(scenario, "a scan in the fight put the prompt back on the screen") end
		release(ns)
	end, { flavour = flavour })
end

-- ------------------------------------------------------------------ 2
-- Off the screen, nothing casts from it: its key (with a modifier held too), a
-- /click of it, the bar macro, a name in its list (armed by a press cut short
-- at the pull, which the fight would otherwise freeze). Nothing is filed, and
-- a press says why. On every client.
for _, flavour in ipairs(FLAVOURS) do
	with("hide-in-combat: its key, the bar macro and a name in the list cast nothing while it is off (" .. flavour .. ")", function(ns, scenario)
		local button = ns.Prompt:GetButton()
		local row = firstRow(ns)
		local slot = row and row.mannersRow
		local entry = slot and slot.entry
		if not (button:GetAttribute("type1") == "macro" and entry) then
			fail(scenario, "SKIPPED -- the prompt is not armed, or the list names nobody")
			return
		end
		pull(ns, function()
			-- A press on a name cut short in the pull's own frame, after the
			-- rows were let go of: the row holds a macro into the fight.
			ns.Prompt:ArmRow(slot, entry)
		end)
		if button:IsShown() then fail(scenario, "SKIPPED -- the prompt was not hidden") return end
		Mock.printed = {}
		ns.pendingClick = nil
		local before = #Mock.castLog
		Mock.pressBinding(BINDING, { release = true })
		local casts = castsSince(before)
		if #casts > 0 then fail(scenario, "its key cast " .. tostring(casts[1].spell) .. " at " .. tostring(casts[1].target) .. " out of sight") end
		if ns.pendingClick then fail(scenario, "a press of its key in the fight was filed as " .. tostring(ns.pendingClick.name)) end
		if not said():find(HIDDEN_LINE, 1, true) then fail(scenario, "a press of its key said: " .. said()) end
		Mock.modifiers.shift = true
		before = #Mock.castLog
		Mock.pressBinding(BINDING)
		Mock.modifiers.shift = nil
		if #castsSince(before) > 0 then fail(scenario, "its key with Shift held cast out of sight") end
		before = #Mock.castLog
		Mock.execLine("/click MannersPrompt LeftButton 1")
		if #castsSince(before) > 0 then fail(scenario, "a /click of it cast out of sight") end
		-- Past the ten seconds the line waits between two sayings.
		Mock.advance(11)
		Mock.printed = {}
		casts = Mock.pressBar(2) or {}
		if #casts > 0 then fail(scenario, "the bar macro cast at " .. tostring(casts[1].target) .. " out of sight") end
		if ns.pendingClick then fail(scenario, "a press of the bar macro in the fight was filed") end
		if not said():find(HIDDEN_LINE, 1, true) then fail(scenario, "a press of the bar macro said: " .. said()) end
		before = #Mock.castLog
		row:Click("LeftButton", true)
		if #castsSince(before) > 0 then fail(scenario, "a name in the hidden list cast out of sight") end
		if row:GetAttribute("type1") or row:GetAttribute("type") then
			fail(scenario, "a name in the hidden list still holds a macro in the fight")
		end
		release(ns)
	end, { flavour = flavour })
end

-- ------------------------------------------------------------------ 3
-- Once the fight ends it is back on the screen, armed for whoever it names
-- now (Anna went in the fight; Bob is owed), never the macro the pull froze;
-- the bar macro follows, a press casts once at Bob and is filed, and the
-- driver's later frames put nothing back.
for _, flavour in ipairs(FLAVOURS) do
	with("hide-in-combat: after the fight it is back and armed for whoever it names now (" .. flavour .. ")", function(ns, scenario)
		local button = ns.Prompt:GetButton()
		if not (ns.Prompt.state.current and ns.Prompt.state.current.name == "Anna Aim") then
			fail(scenario, "SKIPPED -- the prompt is not on Anna before the fight")
			return
		end
		pull(ns)
		if button:IsShown() then fail(scenario, "SKIPPED -- the prompt was not hidden") return end
		-- Anna goes in the fight.
		ns.owed["Anna Aim"] = nil
		Mock.unitNames.nameplate1 = nil
		ns.nameplateUnits.nameplate1 = nil
		Mock.advance(1)
		ns.addon:Tick()
		release(ns)
		if not settleOn(ns, "Bob Bright") then
			fail(scenario, "after the fight the prompt is " .. (button:IsShown() and "up" or "not up") .. " on "
				.. tostring(ns.Prompt.state.current and ns.Prompt.state.current.name))
			return
		end
		local text = button:GetAttribute("macrotext1") or ""
		if button:GetAttribute("type1") ~= "macro" or not text:find("/target Bob Bright", 1, true) then
			fail(scenario, "after the fight the prompt is armed with " .. flat(text))
		end
		if text:find("Anna", 1, true) then fail(scenario, "the macro the pull froze came back: " .. flat(text)) end
		if not (bodyNow() or ""):find("/target Bob Bright", 1, true) then
			fail(scenario, "after the fight the bar macro holds " .. flat(bodyNow()))
		end
		Mock.runTimers(0.5)
		Mock.runTimers(0.5)
		if button:GetAttribute("macrotext1") ~= text or not button:IsShown() then
			fail(scenario, "the driver's frames after the fight changed the prompt: " .. flat(button:GetAttribute("macrotext1")))
		end
		local header = ns.Prompt:FightHeader()
		if header and header:GetAttribute("state-mannersfight") ~= "peace" then
			fail(scenario, "after the fight the driver reads " .. tostring(header:GetAttribute("state-mannersfight")))
		end
		ns.pendingClick = nil
		local before = #Mock.castLog
		Mock.pressBinding(BINDING)
		local casts = castsSince(before)
		if #casts ~= 1 or casts[1].target ~= "Bob Bright" then
			fail(scenario, ("after the fight its key cast %d time(s), at %s"):format(#casts, tostring(casts[1] and casts[1].target)))
		end
		if not (ns.pendingClick and ns.pendingClick.name == "Bob Bright") then
			fail(scenario, "the press after the fight was filed as " .. tostring(ns.pendingClick and ns.pendingClick.name))
		end
	end, { flavour = flavour })
end

-- ------------------------------------------------------------------ 4
-- Off (as it is out of the box), a fight is what it was before the switch:
-- the prompt stays up, its key casts the macro the pull froze, the bar macro
-- carries the cast.
for _, flavour in ipairs(FLAVOURS) do
	with("hide-in-combat: off, the prompt stays up and armed in a fight (" .. flavour .. ")", function(ns, scenario)
		local button = ns.Prompt:GetButton()
		local named = ns.Prompt.state.current and ns.Prompt.state.current.name
		pull(ns)
		if not button:IsShown() then fail(scenario, "switched off, the prompt left the screen in a fight") end
		if ns.Prompt:HiddenForFight() then fail(scenario, "switched off, the prompt thinks it is hidden") end
		if not (bodyNow() or ""):find("/cast", 1, true) then
			fail(scenario, "switched off, the bar macro lost its cast at the pull: " .. flat(bodyNow()))
		end
		local before = #Mock.castLog
		Mock.pressBinding(BINDING)
		local casts = castsSince(before)
		if #casts ~= 1 or casts[1].target ~= named then
			fail(scenario, ("switched off, its key in the fight cast %d time(s), at %s, not %s"):format(#casts,
				tostring(casts[1] and casts[1].target), tostring(named)))
		end
		release(ns)
	end, { flavour = flavour, off = true })
end

-- ------------------------------------------------------------------ 5
-- A press of the bar macro in the pull's own frame keeps its write from going
-- in, so the macro still carries the cast into the fight: the prompt stays
-- up and armed, as with the switch off, and says why. A hidden prompt never
-- sits over a bar macro that casts.
with("hide-in-combat: a bar macro still holding a cast at the pull keeps the prompt up", function(ns, scenario)
	local button = ns.Prompt:GetButton()
	local held = bodyNow() or ""
	if not held:find("/cast", 1, true) then fail(scenario, "SKIPPED -- the bar macro carries no cast: " .. flat(held)) return end
	Mock.printed = {}
	-- The bar's own press, in the frame the fight starts in.
	ns.HoldMacroWrites()
	pull(ns)
	if bodyNow() ~= held then fail(scenario, "SKIPPED -- the pull wrote the macro after all: " .. flat(bodyNow())) return end
	if not button:IsShown() then fail(scenario, "the prompt left the screen over a bar macro that still casts") end
	if button:GetAttribute("type1") ~= "macro" then fail(scenario, "the prompt was disarmed though it stays up") end
	if not said():find(STAYS_LINE, 1, true) then fail(scenario, "nothing said why it stays up: " .. said()) end
	local casts = Mock.pressBar(2) or {}
	if #casts ~= 1 then fail(scenario, ("the bar macro cast %d time(s) with the prompt up"):format(#casts)) end
	release(ns)
end)

-- A macro named Manners changed by hand runs its own lines at every press, so
-- it casts from the bar however the prompt is: the prompt stays up, and the
-- line that says why is not repeated at every pull.
with("hide-in-combat: a Manners macro changed by hand keeps the prompt up", function(ns, scenario)
	local button = ns.Prompt:GetButton()
	local macro = Mock.macroList[GetMacroIndexByName("Manners")]
	if not macro then fail(scenario, "SKIPPED -- no macro") return end
	macro.body = BAR_LINE .. "\n/target Anna Aim\n/cast Arcane Intellect\n/use 13"
	Mock.macrosChanged()
	Mock.printed = {}
	pull(ns)
	if not button:IsShown() then fail(scenario, "the prompt left the screen over a macro changed by hand that still casts") end
	if button:GetAttribute("type1") ~= "macro" then fail(scenario, "the prompt was disarmed though it stays up") end
	if not said():find(STAYS_LINE, 1, true) then fail(scenario, "nothing said why it stays up: " .. said()) end
	release(ns)
	Mock.advance(5)
	Mock.printed = {}
	pull(ns)
	if said():find(STAYS_LINE, 1, true) then fail(scenario, "the next pull said the same line again") end
	release(ns)
end)

-- ------------------------------------------------------------------ 6
-- Two fights a frame apart: the second pull comes before the driver has had a
-- frame to read the peace between them. It is still seen, and the prompt goes.
with("hide-in-combat: a second fight straight after the first hides it too", function(ns, scenario)
	local button = ns.Prompt:GetButton()
	pull(ns)
	if button:IsShown() then fail(scenario, "SKIPPED -- the first fight did not hide it") return end
	release(ns, true)
	if not button:IsShown() then fail(scenario, "SKIPPED -- the end of the first fight did not bring it back") return end
	pull(ns)
	if button:IsShown() then fail(scenario, "the second fight, a frame after the first, left the prompt on the screen") end
	local before = #Mock.castLog
	Mock.pressBinding(BINDING)
	if #castsSince(before) > 0 then fail(scenario, "in the second fight its key cast") end
	release(ns)
end)

-- ------------------------------------------------------------------ 7
-- The player's combat flag can outlast the lockdown for a moment: the driver
-- then reads [combat] after the fight has ended for the addon. That reading
-- hides nothing and disarms nothing.
with("hide-in-combat: a combat flag that outlasts the fight hides nothing after it", function(ns, scenario)
	local button = ns.Prompt:GetButton()
	pull(ns)
	if button:IsShown() then fail(scenario, "SKIPPED -- the fight did not hide it") return end
	Mock.affectingCombat = true
	release(ns)
	if not settleOn(ns, ns.Prompt.state.current and ns.Prompt.state.current.name or "Anna Aim") then
		fail(scenario, "with the combat flag still up after the fight, the prompt is not back")
	end
	Mock.runTimers(0.5)
	if not button:IsShown() then fail(scenario, "the late combat flag took the prompt off the screen after the fight") end
	if button:GetAttribute("type1") ~= "macro" then fail(scenario, "the late combat flag disarmed the prompt after the fight") end
	Mock.affectingCombat = nil
	Mock.runTimers(0.5)
end)

-- ------------------------------------------------------------------ 8
-- The switch: on Look, beside the flashes, off out of the box, writing the
-- prompt's own setting, and found by the word the player looked for.
with("hide-in-combat: the switch is on Look and off out of the box", function(ns, scenario)
	local look = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
	local toggle = look and look.args and look.args.hideInFight
	if not toggle then fail(scenario, "no Hide the prompt in combat on the Look tab") return end
	if ns.defaults.profile.prompt.hideInFight ~= false then fail(scenario, "it is not off out of the box") end
	local p = ns.db.profile.prompt
	toggle.set({ "appearance", "hideInFight" }, false)
	if p.hideInFight ~= false then fail(scenario, "switching it off does not write prompt.hideInFight") end
	toggle.set({ "appearance", "hideInFight" }, true)
	if p.hideInFight ~= true or toggle.get({ "appearance", "hideInFight" }) ~= true then
		fail(scenario, "switching it on does not write and read prompt.hideInFight")
	end
	local flashes = look.args.hideInCombat
	local desc = flashes and H.optionText(flashes.desc) or ""
	if not desc:find(tostring(toggle.name), 1, true) then
		fail(scenario, "No flashes in combat does not point to the switch that hides the prompt: " .. desc)
	end
end, { off = true })
