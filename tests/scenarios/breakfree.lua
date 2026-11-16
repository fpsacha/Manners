-- Breaking free in a fight (Prompt/BreakFree.lua): a Forsaken's Will of the
-- Forsaken on a secure button of its own beside the prompt, with a key of its
-- own, shown by its own state driver for every fight and lit up while feared,
-- charmed or asleep with the spell ready.
--
-- These hold Manners to the mock's model of the client (the state driver and
-- the restricted snippet in tests/mockwidgets.lua, the macro run by a secure
-- click in tests/mockmacros.lua, C_LossOfControl in both of its shapes and
-- UnitIsCharmed in tests/mockapi.lua), not to the client: which loss of
-- control Forever reports, and whether it is plain there, only a real fear
-- can say (STATUS.md).
--
-- Every name starts with "breakfree:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local PROMPT_KEY = "CLICK MannersPrompt:LeftButton"
local COMMAND = "CLICK MannersBreakFree:LeftButton"
local SPELL = "Will of the Forsaken"
local WOTF_ICON = 136187
local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bob", "Bright" }, nameplate3 = { "Cara", "Cole" } }
local NAMES = { "Anna Aim", "Bob Bright", "Cara Cole" }
local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }

-- Forever unless a scenario names the client: a Forsaken who knows Will of
-- the Forsaken, its key on F, three people on nameplates all owed and the
-- prompt up on one of them. opts.race, opts.known (false: the spell not
-- learned), opts.shape (the loss-of-control API's), opts.key (false: none),
-- opts.nobody (nobody owed, so the prompt is off the screen at the pull),
-- opts.edit(p, ns) before the first scan.
local function with(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	-- The client --flavour names (Forever by default) unless the row names one.
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.playerRace = opts.race or "Scourge"
	if opts.known ~= false then Mock.knownSpells = { [7744] = true } end
	Mock.lossOfControlShape = opts.shape
	local restore = strangers(opts.people or PEOPLE)
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			ns.db.profile.verbose = true
			local p = ns.db.profile.prompt
			if opts.edit then opts.edit(p, ns) end
			ns.Prompt:ApplyStyle()
			if opts.key ~= false then
				Mock.bindings = Mock.bindings or {}
				Mock.bindings[opts.key or "F"] = COMMAND
			end
			if not opts.nobody then
				for _, name in ipairs(NAMES) do owe(ns, name) end
			end
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
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The pull as the client orders it (tests/scenarios/fight-rota.lua).
local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

-- A loss of control of `kind` beginning, and every one ending.
local function lose(kind)
	Mock.lossOfControl = { { locType = kind or "FEAR", spellID = 5782 } }
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
end
local function regain()
	Mock.lossOfControl = {}
	Mock.charmed = nil
	Mock.frameEvent("LOSS_OF_CONTROL_UPDATE")
	Mock.frameEvent("PLAYER_CONTROL_GAINED")
end

-- What the button shows: lit, its name line and its key line.
local function shows(ns)
	local button, look = ns.BreakFree:Button(), ns.BreakFree:Look()
	if not (button and look) then return false, "", "" end
	return button:GetAlpha() == 1, tostring(look.name:GetText() or ""), tostring(look.key:GetText() or "")
end

local function promptLines(ns)
	local R = ns.Prompt:Regions()
	return tostring(R.name:GetText() or ""), tostring(R.sub:GetText() or "")
end

-- The prompt's icon as last set: the mock's texture keeps no file, so the
-- writes are watched from the moment this is first asked.
local function promptIcon(ns)
	local icon = ns.Prompt:Regions().icon
	if not icon then return nil end
	if not icon._watched then
		icon._watched = true
		local set = icon.SetTexture
		icon.SetTexture = function(self, texture, ...)
			self._lastTexture = texture
			return set(self, texture, ...)
		end
	end
	return icon._lastTexture
end

local function castsSince(n)
	local out = {}
	for i = n + 1, #Mock.castLog do
		local e = Mock.castLog[i]
		if e.spell and not e.refused then out[#out + 1] = e end
	end
	return out
end

local function printedHas(text)
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(text, 1, true) then return true end
	end
	return false
end

local function option(ns, key)
	local look = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
	return look and look.args and look.args[key]
end

local function hidden(node)
	if type(node.hidden) == "function" then return node.hidden() == true end
	return node.hidden == true
end

-- ------------------------------------------------------------------ 1
-- Armed out of combat, hidden; shown by its own driver at the pull; and
-- nothing in the fight (a fear, scans, the switch thrown, the fear ending)
-- makes Lua show, hide, move or arm it under the lockdown.
with("breakfree: armed out of combat, shown by its own driver in a fight, nothing protected from Lua", function(ns, scenario)
	local button = ns.BreakFree:Button()
	if not button then fail(scenario, "no break-free button for a Forsaken who knows the spell") return end
	if button:GetAttribute("type1") ~= "macro" or button:GetAttribute("macrotext1") ~= "/cast " .. SPELL then
		fail(scenario, "not armed with the spell out of combat: " .. tostring(button:GetAttribute("macrotext1")))
	end
	if button:IsShown() then fail(scenario, "shown out of a fight") end
	Mock.protect(button)
	pull(ns)
	if not button:IsShown() then fail(scenario, "its driver did not show it at the pull") end
	Mock.protectedCalls = {}
	lose("FEAR")
	for _ = 1, 3 do
		Mock.advance(0.4)
		ns.addon:Tick()
		Mock.runTimers(1)
	end
	local switch = option(ns, "breakFree")
	if switch then
		switch.set({ "appearance", "breakFree" }, false)
		switch.set({ "appearance", "breakFree" }, true)
	end
	regain()
	ns.addon:Tick()
	ns.Prompt:Refresh()
	if #Mock.protectedCalls > 0 then
		fail(scenario, "Lua called " .. table.concat(Mock.protectedCalls, ", ") .. " on the break-free button in the fight")
	end
	if not button:IsShown() or button:GetAttribute("macrotext1") ~= "/cast " .. SPELL then
		fail(scenario, "the fight left it hidden or disarmed")
	end
	release(ns)
	if button:IsShown() then fail(scenario, "still shown after the fight") end
end)

-- The driver hides it as the fight ends, before Manners' own handler runs.
with("breakfree: its driver hides it as the fight ends", function(ns, scenario)
	local button = ns.BreakFree:Button()
	if not button then fail(scenario, "no break-free button") return end
	pull(ns)
	Mock.inCombat = false
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
	if button:IsShown() then fail(scenario, "the driver left it shown once the fight was over") end
	ns.addon:PLAYER_REGEN_ENABLED()
end)

-- A driver that still reads [combat] a moment after the lockdown (the client's
-- combat flag and its lockdown are two things): the fight's end takes it down
-- and puts the driver back to peace from Lua, out of lockdown, all the same.
with("breakfree: the fight's end takes it down with the combat flag late", function(ns, scenario)
	local button = ns.BreakFree:Button()
	if not button then fail(scenario, "no break-free button") return end
	pull(ns)
	Mock.affectingCombat = true
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	if button:IsShown() then fail(scenario, "the fight's end left it shown") end
	local header = ns.BreakFree:Header()
	if header and header:GetAttribute("state-mannersbreakfree") ~= "peace" then
		fail(scenario, "the fight's end left its driver on " .. tostring(header:GetAttribute("state-mannersbreakfree")))
	end
	Mock.affectingCombat = nil
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0.5)
	if button:IsShown() then fail(scenario, "shown once the combat flag caught up") end
end)

-- ------------------------------------------------------------------ 2
with("breakfree: not for a human", function(ns, scenario)
	if ns.caps.breakFree then fail(scenario, "a human was found to have it") end
	if ns.BreakFree:Button() or (Mock.namedFrames and Mock.namedFrames.MannersBreakFree) then
		fail(scenario, "a human has a break-free button")
	end
	local switch = option(ns, "breakFree")
	if switch and not hidden(switch) then fail(scenario, "the switch is shown to a human") end
	local key = option(ns, "breakFreeKey")
	if key and not hidden(key) then fail(scenario, "its key is shown to a human") end
end, { race = "Human" })

with("breakfree: not for a Forsaken without the spell", function(ns, scenario)
	if ns.caps.breakFree or ns.BreakFree:Button() then fail(scenario, "made without the spell known") end
	local lines = table.concat(ns.BreakFreeLines(), " / ")
	if not lines:find("not known yet", 1, true) then fail(scenario, "/manners debug does not say the spell is not known: " .. lines) end
end, { known = false })

-- ------------------------------------------------------------------ 3
with("breakfree: switched off, disarmed and not shown in a fight", function(ns, scenario)
	local button = ns.BreakFree:Button()
	local switch = option(ns, "breakFree")
	if not (button and switch) then fail(scenario, "no button or no switch") return end
	switch.set({ "appearance", "breakFree" }, false)
	ns.addon:Tick()
	if button:GetAttribute("macrotext1") ~= nil or button:GetAttribute("type1") ~= nil then
		fail(scenario, "still armed with the switch off")
	end
	pull(ns)
	if button:IsShown() then fail(scenario, "shown in a fight with the switch off") end
	release(ns)
	switch.set({ "appearance", "breakFree" }, true)
	ns.addon:Tick()
	if button:GetAttribute("macrotext1") ~= "/cast " .. SPELL then fail(scenario, "not armed again once switched on") end
end)

-- ------------------------------------------------------------------ 4
-- The commonest pull: nothing offered, so the prompt is off the screen; the
-- button carries the whole display itself.
with("breakfree: feared with the prompt off the screen, the button lights up", function(ns, scenario)
	pull(ns)
	if ns.Prompt:GetButton():IsShown() then fail(scenario, "SKIPPED -- the prompt was up at the pull") return end
	local lit, name, key = shows(ns)
	if lit or name ~= "" then fail(scenario, "lit before any fear") end
	lose("FEAR")
	lit, name, key = shows(ns)
	if not lit then fail(scenario, "not bright while feared") end
	if not name:find(SPELL, 1, true) then fail(scenario, "its name line reads " .. name) end
	if not key:find("press F to break free", 1, true) then fail(scenario, "its key line reads " .. key) end
	regain()
	lit, name = shows(ns)
	if lit or name ~= "" then fail(scenario, "still lit once the fear ended") end
	release(ns)
end, { nobody = true, people = {} })

with("breakfree: with no key it says to click", function(ns, scenario)
	pull(ns)
	lose("SLEEP")
	local lit, _, key = shows(ns)
	if not lit or not key:find("click to break free", 1, true) then fail(scenario, "asleep with no key it reads " .. key) end
	release(ns)
end, { nobody = true, people = {}, key = false })

-- ------------------------------------------------------------------ 5
with("breakfree: feared with the prompt up, the prompt names it and its key", function(ns, scenario)
	pull(ns)
	if not ns.Prompt:GetButton():IsShown() then fail(scenario, "SKIPPED -- the prompt was not up") return end
	promptIcon(ns)
	lose("FEAR")
	local name, sub = promptLines(ns)
	if not name:find("Break free: " .. SPELL, 1, true) then fail(scenario, "the prompt reads " .. name) end
	if ns.db.profile.prompt.showSub ~= false and not sub:find("press F to break free", 1, true) then
		fail(scenario, "the prompt's second line reads " .. sub)
	end
	if promptIcon(ns) ~= WOTF_ICON then fail(scenario, "the prompt's icon is not the spell's") end
	release(ns)
end)

-- ------------------------------------------------------------------ 6
for _, kind in ipairs({ "STUN", "ROOT", "FEAR_MECHANIC", "PACIFYSILENCE" }) do
	with("breakfree: " .. kind .. " is no reason", function(ns, scenario)
		pull(ns)
		lose(kind)
		local lit = shows(ns)
		if lit then fail(scenario, "lit for " .. kind) end
		local name = promptLines(ns)
		if name:find("Break free", 1, true) then fail(scenario, "the prompt names it for " .. kind) end
		release(ns)
	end)
end

-- ------------------------------------------------------------------ 7
with("breakfree: charmed by UnitIsCharmed alone", function(ns, scenario)
	pull(ns)
	Mock.charmed = true
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	local lit = shows(ns)
	if not lit then fail(scenario, "not lit while UnitIsCharmed says so") end
	regain()
	if (shows(ns)) then fail(scenario, "still lit once the charm ended") end
	release(ns)
end, { nobody = true, people = {} })

-- ------------------------------------------------------------------ 8
with("breakfree: a secret loss of control is no reason and throws nothing", function(ns, scenario)
	pull(ns)
	Mock.lossOfControl = { { locType = Mock.SECRET } }
	Mock.frameEvent("LOSS_OF_CONTROL_ADDED", 1)
	if (shows(ns)) then fail(scenario, "lit for a secret type") end
	Mock.lossOfControlCount = Mock.SECRET
	Mock.frameEvent("LOSS_OF_CONTROL_UPDATE")
	if (shows(ns)) then fail(scenario, "lit for a secret count") end
	Mock.charmed = Mock.SECRET
	Mock.frameEvent("PLAYER_CONTROL_LOST")
	if (shows(ns)) then fail(scenario, "lit for a secret charm") end
	local lines = table.concat(ns.BreakFreeLines(), " / ")
	if not lines:find("(secret)", 1, true) then fail(scenario, "/manners debug does not say it came secret: " .. lines) end
	release(ns)
end, { nobody = true, people = {} })

-- ------------------------------------------------------------------ 9
with("breakfree: its key casts the spell alone, steps no rota and files nothing", function(ns, scenario)
	pull(ns)
	local prompt, header = ns.Prompt:GetButton(), ns.Prompt:FightHeader()
	local macro, at = prompt:GetAttribute("macrotext1"), header and header:GetAttribute("manners-rota-i")
	lose("FEAR")
	local before = #Mock.castLog
	Mock.pressBinding(COMMAND)
	local casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= SPELL then
		fail(scenario, "its key cast " .. #casts .. " spells: " .. tostring(casts[1] and casts[1].spell))
	end
	if prompt:GetAttribute("macrotext1") ~= macro then fail(scenario, "its key changed the prompt's macro") end
	if header and header:GetAttribute("manners-rota-i") ~= at then fail(scenario, "its key stepped the fight's rota") end
	if ns.pendingClick then fail(scenario, "its key filed a press for " .. tostring(ns.pendingClick.name)) end
	before = #Mock.castLog
	ns.BreakFree:Button():Click("RightButton", true)
	if #castsSince(before) > 0 then fail(scenario, "a right click cast it") end
	release(ns)
end)

-- ------------------------------------------------------------------ 10
-- Pressed from habit while feared: the prompt files a press that never goes
-- out, then the break-free key. Will of the Forsaken's cast event names
-- nobody and its id is secret in a fight: it must settle nothing.
local function sent()
	Mock.dispatch("UNIT_SPELLCAST_SENT", "player", "", "Cast-wotf", Mock.SECRET)
end

with("breakfree: a prompt press then its key settles no favour", function(ns, scenario)
	pull(ns)
	lose("FEAR")
	local named = ns.Prompt.state.current and ns.Prompt.state.current.name
	if not named then fail(scenario, "SKIPPED -- nobody on the prompt") return end
	Mock.printed = {}
	H.pressButton(ns)
	if not ns.pendingClick then fail(scenario, "SKIPPED -- the prompt's press filed nothing") return end
	Mock.advance(0.1)
	Mock.pressBinding(COMMAND)
	sent()
	if not ns.owed[named] then fail(scenario, "the favour to " .. named .. " was settled by Will of the Forsaken") end
	if not printedHas("you broke free instead") then fail(scenario, "the prompt's press was not let go as broken free") end
	if ns.pendingClick then fail(scenario, "the prompt's press is still waiting") end
	release(ns)
end)

with("breakfree: its key then a prompt press settles no favour", function(ns, scenario)
	pull(ns)
	lose("FEAR")
	local named = ns.Prompt.state.current and ns.Prompt.state.current.name
	if not named then fail(scenario, "SKIPPED -- nobody on the prompt") return end
	Mock.pressBinding(COMMAND)
	Mock.advance(0.1)
	H.pressButton(ns)
	if not ns.pendingClick then fail(scenario, "SKIPPED -- the prompt's press filed nothing") return end
	sent()
	if not ns.owed[named] then fail(scenario, "the favour to " .. named .. " was settled by Will of the Forsaken's cast") end
	release(ns)
end)

-- ------------------------------------------------------------------ 11
with("breakfree: dim while it cools down, lit again once ready", function(ns, scenario)
	pull(ns)
	lose("FEAR")
	if not (shows(ns)) then fail(scenario, "SKIPPED -- not lit") return end
	Mock.pressBinding(COMMAND)
	Mock.dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-wotf", 7744)
	-- Feared again at once: the cooldown is the thing that answers.
	lose("FEAR")
	if (shows(ns)) then fail(scenario, "lit while the spell cools down") end
	local name = promptLines(ns)
	if name:find("Break free", 1, true) then fail(scenario, "the prompt names it while it cools down") end
	Mock.advance(121)
	Mock.frameEvent("LOSS_OF_CONTROL_UPDATE")
	if not (shows(ns)) then fail(scenario, "not lit again once the cooldown was over") end
	release(ns)
end)

-- ------------------------------------------------------------------ 12
with("breakfree: the fear ends and the prompt names the rota's person again", function(ns, scenario)
	pull(ns)
	local current = ns.Prompt.state.current
	if not current then fail(scenario, "SKIPPED -- nobody on the prompt") return end
	promptIcon(ns)
	lose("FEAR")
	if promptIcon(ns) ~= WOTF_ICON then fail(scenario, "SKIPPED -- the prompt never showed the spell's icon") return end
	regain()
	local name = promptLines(ns)
	if name:find("Break free", 1, true) then fail(scenario, "the prompt still names it once the fear ended") end
	if not name:find((current.name:match("^%S+")), 1, true) then fail(scenario, "the prompt does not name " .. current.name .. ": " .. name) end
	if promptIcon(ns) == WOTF_ICON then fail(scenario, "the prompt kept the spell's icon") end
	lose("FEAR")
	release(ns)
	name = promptLines(ns)
	if name:find("Break free", 1, true) then fail(scenario, "the prompt still names it after the fight") end
	if promptIcon(ns) == WOTF_ICON then fail(scenario, "the prompt kept the spell's icon after the fight") end
end)

-- ------------------------------------------------------------------ 13
with("breakfree: after the fight it is hidden and its key casts the spell alone", function(ns, scenario)
	pull(ns)
	release(ns)
	local button = ns.BreakFree:Button()
	if button:IsShown() then fail(scenario, "shown after the fight") end
	local before = #Mock.castLog
	Mock.pressBinding(COMMAND)
	local casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= SPELL then fail(scenario, "its key cast " .. #casts .. " spells out of a fight") end
	for _, line in ipairs(Mock.macroLog or {}) do
		if type(line) == "string" and line:find("/target", 1, true) and line:find(SPELL, 1, true) then
			fail(scenario, "its macro targets somebody")
		end
	end
end)

-- ------------------------------------------------------------------ 14
-- Nothing Manners chooses keeps it from a fight: not Hide the prompt in
-- combat, not a snooze.
with("breakfree: Hide the prompt in combat on, it shows and casts", function(ns, scenario)
	pull(ns)
	if ns.Prompt:GetButton():IsShown() then fail(scenario, "SKIPPED -- the prompt stayed up") return end
	local button = ns.BreakFree:Button()
	if not button:IsShown() then fail(scenario, "hidden with the prompt") end
	lose("FEAR")
	if not (shows(ns)) then fail(scenario, "not lit with the prompt hidden for the fight") end
	local before = #Mock.castLog
	Mock.pressBinding(COMMAND)
	if #castsSince(before) ~= 1 then fail(scenario, "its key cast nothing with the prompt hidden for the fight") end
	release(ns)
end, { edit = function(p) p.hideInFight = true end })

with("breakfree: a snooze of the prompt leaves it", function(ns, scenario)
	ns.StartSnooze(10)
	ns.addon:Tick()
	local button = ns.BreakFree:Button()
	if button:GetAttribute("macrotext1") ~= "/cast " .. SPELL then fail(scenario, "a snooze disarmed it") end
	pull(ns)
	if not button:IsShown() then fail(scenario, "a snooze kept it from the fight") end
	lose("FEAR")
	if not (shows(ns)) then fail(scenario, "not lit under a snooze") end
	release(ns)
end)

-- ------------------------------------------------------------------ 15
with("breakfree: the switch is on Look's In a fight and on by default", function(ns, scenario)
	if ns.defaults.profile.prompt.breakFree ~= true then fail(scenario, "not on out of the box") end
	local switch, key = option(ns, "breakFree"), option(ns, "breakFreeKey")
	if not (switch and key) then fail(scenario, "no switch or no key on Look") return end
	if hidden(switch) or hidden(key) then fail(scenario, "hidden from a Forsaken who has it") end
	if key.type ~= "keybinding" then fail(scenario, "its key is a " .. tostring(key.type)) end
	-- In the In a fight section, the key indented under the switch.
	local found
	local function walk(t)
		if type(t) ~= "table" or found then return end
		if t.key == "appearance.fight" and type(t.items) == "table" then found = t return end
		for _, v in pairs(t) do walk(v) end
	end
	walk(ns.WindowLayout)
	local hasSwitch, hasKey
	for _, item in ipairs(found and found.items or {}) do
		if item == "appearance.breakFree" then hasSwitch = true end
		if type(item) == "table" and item[1] == "appearance.breakFreeKey" and item.indent then hasKey = true end
	end
	if not (hasSwitch and hasKey) then fail(scenario, "not in Look's In a fight section with its key under it") end
	if ns.WindowLayout.parents["appearance.breakFreeKey"] ~= "appearance.breakFree" then
		fail(scenario, "search does not know the key's switch")
	end
	-- Off, the key goes.
	switch.set({ "appearance", "breakFree" }, false)
	if not hidden(key) then fail(scenario, "its key is shown with the switch off") end
end)

-- The key control binds the break-free command, and a key taken from
-- another binding is said as casting the spell, not as buffing anybody.
with("breakfree: its key control binds it and says what the key now does", function(ns, scenario)
	local key = option(ns, "breakFreeKey")
	if not key then fail(scenario, "no key control") return end
	Mock.bindings = { G = "JUMP", F = COMMAND }
	_G.BINDING_NAME_JUMP = "Jump"
	Mock.printed = {}
	key.set({ "appearance", "breakFreeKey" }, "G")
	_G.BINDING_NAME_JUMP = nil
	if Mock.bindings.G ~= COMMAND or key.get({ "appearance", "breakFreeKey" }) ~= "G" then
		fail(scenario, "G was not bound to the break-free button")
	end
	if Mock.bindings.F == COMMAND then fail(scenario, "the old key still casts it") end
	if not printedHas("it now casts " .. SPELL) then fail(scenario, "taking Jump's key did not say it now casts the spell") end
	if printedHas("buffs the prompted player") then fail(scenario, "taking a key for it said it buffs the prompted player") end
	if ns.Setup.Key() ~= nil and ns.Setup.Key() == "G" then fail(scenario, "the prompt's own key moved") end
end)

-- ------------------------------------------------------------------ 16
with("breakfree: no prompt, rota or bar macro carries the spell", function(ns, scenario)
	lose("FEAR")
	pull(ns)
	lose("FEAR")
	local texts = { ns.Prompt:GetButton():GetAttribute("macrotext1") }
	local header = ns.Prompt:FightHeader()
	for i = 1, (header and header:GetAttribute("manners-rota-n") or 0) do
		texts[#texts + 1] = header:GetAttribute("manners-rota-" .. i)
	end
	texts[#texts + 1] = ns.BarBodyNow and ns.BarBodyNow() or nil
	for _, text in ipairs(texts) do
		if type(text) == "string" and text:find(SPELL, 1, true) then
			fail(scenario, "a macro of the prompt's carries it: " .. text:gsub("\n", " / "))
		end
	end
	release(ns)
end)

-- ------------------------------------------------------------------ 17
for _, flavour in ipairs(FLAVOURS) do
	for _, shape in ipairs({ "data", "events", "none" }) do
		with(("breakfree: feared and charmed on %s, loss of control as %s"):format(flavour, shape), function(ns, scenario)
			if not ns.BreakFree:Button() then fail(scenario, "no button on " .. flavour) return end
			pull(ns)
			lose("FEAR")
			local lit = shows(ns)
			if shape == "none" and lit then fail(scenario, "lit for a fear with no API to report one") end
			if shape ~= "none" and not lit then fail(scenario, "not lit while feared") end
			regain()
			Mock.charmed = true
			Mock.frameEvent("PLAYER_CONTROL_LOST")
			if not (shows(ns)) then fail(scenario, "not lit while charmed") end
			regain()
			local lines = table.concat(ns.BreakFreeLines(), " / ")
			if shape == "none" and not lines:find("no API", 1, true) then
				fail(scenario, "/manners debug does not say there is no API: " .. lines)
			end
			release(ns)
		end, { flavour = flavour, shape = shape, nobody = true, people = {} })
	end
end

-- ------------------------------------------------------------------ 18
-- Whether you can is the probe's, never asked per scan.
with("breakfree: the spell book is asked in the probe, never per scan", function(ns, scenario)
	local real, asked = _G.IsSpellKnown, 0
	rawset(_G, "IsSpellKnown", function(id)
		if id == 7744 then asked = asked + 1 end
		return real(id)
	end)
	local ok, err = pcall(function()
		for _ = 1, 5 do
			Mock.advance(0.4)
			ns.addon:Tick()
		end
	end)
	rawset(_G, "IsSpellKnown", real)
	if not ok then error(err, 0) end
	if asked > 0 then fail(scenario, "five scans asked the spell book " .. asked .. " times") end
end)

-- ------------------------------------------------------------------ 19
-- /manners debug, the check-up and /manners selftest launch: the ability,
-- the button, its key and the last loss of control, and how it came.
with("breakfree: /manners debug and the launch check say what they found", function(ns, scenario)
	pull(ns)
	lose("FEAR")
	release(ns)
	local lines = table.concat(ns.BreakFreeLines(), " / ")
	for _, want in ipairs({ SPELL .. " found", "armed (/cast " .. SPELL .. ")", "key F", "last loss of control: FEAR (plain)" }) do
		if not lines:find(want, 1, true) then fail(scenario, "/manners debug lacks \"" .. want .. "\": " .. lines) end
	end
	Mock.printed = {}
	ns.addon:HandleSlash("debug")
	if not printedHas("break free button: armed") then fail(scenario, "/manners debug does not print them") end
	if not (ns.Selftest and ns.Selftest.RunLaunch) then return end
	local results, finish = ns.Selftest.RunLaunch({})
	if finish then results = finish() or results end
	local seen
	for _, r in ipairs(results or {}) do
		if r.id == "launch.breakfree" then
			seen = r
			if r.status == "FAIL" then fail(scenario, "the launch check fails: " .. tostring(r.value)) end
			if not tostring(r.value):find("armed \"/cast " .. SPELL .. "\"", 1, true) then
				fail(scenario, "the launch check does not read the button: " .. tostring(r.value))
			end
		end
	end
	if not seen then fail(scenario, "no launch.breakfree check") end
end)

with("breakfree: launch check fails an unarmed button", function(ns, scenario)
	if not (ns.Selftest and ns.Selftest.RunLaunch) then return end
	local button = ns.BreakFree:Button()
	button:SetAttribute("macrotext1", nil)
	local results, finish = ns.Selftest.RunLaunch({})
	if finish then results = finish() or results end
	for _, r in ipairs(results or {}) do
		if r.id == "launch.breakfree" and r.status ~= "FAIL" then
			fail(scenario, "an unarmed button reads " .. tostring(r.status) .. ": " .. tostring(r.value))
		end
	end
end)
