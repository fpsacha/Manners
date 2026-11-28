-- Ask me before thanking (prompt.thankAsk; ThankPress.lua). Asked for on
-- CurseForge: "Automating the thank you message doesn't feel personal and
-- having to manually press it can add a little bit of personal touch." So,
-- off by default, and on: a thank Favours.lua would have sent by itself waits
-- on the prompt as "Thank <name>", and goes out (the emote, the whisper, as
-- set up) only at a press; left alone it lapses and nothing is sent.
--
-- Every scenario name starts with "thankpress:" so the mutations in
-- tests/mutations/thankpress.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom, findOption, pressButton =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom, H.findOption, H.pressButton

local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo", "GetCVar", "IsStealthed",
	"MenuUtil", "UnitAffectingCombat", "IsResting", "UnitGUID", "UnitInParty", "IsSpellKnown", "IsPlayerSpell",
	"GetItemCount", "GetItemInfo", "IsShiftKeyDown" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local emotes, whispers = {}, {}
local place = false

-- One session. opts: flavour, class (a rogue unless named: nothing of his own
-- to offer anybody, so the queue is the thanks alone), names (unit -> name),
-- thank (the /thank, on unless false), whisper (off unless true), unseen,
-- delay, ask (the switch, on unless false), platesOff, group (Mock.groupSize),
-- before (run on the addon before the baseline settles).
local function with(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	local names = opts.names or { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" } }
	local plates = {}
	for unit in pairs(names) do
		if unit:find("^nameplate") then plates[#plates + 1] = unit end
	end
	table.sort(plates)
	Mock.nameplates = plates
	Mock.class = opts.class or "ROGUE"
	if opts.group then Mock.groupSize = opts.group end
	if opts.held then Mock.held = opts.held end
	emotes, whispers, place = {}, {}, false
	rawset(_G, "IsInInstance", function() return place ~= false, place or "none" end)
	rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = { emote, target } end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function(text, channel, _, target)
		whispers[#whispers + 1] = { text = text, channel = channel, target = target }
	end)
	rawset(_G, "UnitAffectingCombat", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	-- A GUID that goes with the person, not the token, as the client's does.
	rawset(_G, "UnitGUID", function(unit)
		local name = Mock.unitNames and Mock.unitNames[unit]
		return "Player-1-" .. (type(name) == "table" and table.concat(name, "-") or tostring(unit))
	end)
	-- The mock counts everybody in a party once there is one; here only the
	-- party tokens are, so a nameplate is a passer-by.
	if opts.group then
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end)
	end
	-- A mage with Arcane Intellect, Arcane Brilliance and its powder.
	if opts.brilliance then
		local known = { [10157] = true, [10156] = true, [1461] = true, [1460] = true, [1459] = true, [23028] = true }
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "GetItemCount", function(id) return id == 17020 and 20 or 0 end)
		rawset(_G, "GetItemInfo", function(id) return id == 17020 and "Arcane Powder" or nil end)
	end
	if opts.platesOff then
		rawset(_G, "GetCVar", function(name)
			if name == "nameplateShowFriendlyPlayers" or name == "nameplateShowFriends" then return "0" end
			return original.GetCVar and original.GetCVar(name) or nil
		end)
	end
	local undo = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		ns.KeyNudge = nil
		freshPrompt(ns, scenario)
		H.extrasOn(ns)
		local db = ns.db.profile
		db.prompt.thankEmote = opts.thank ~= false
		db.prompt.thankWhisper = opts.whisper == true
		db.prompt.thankDelay = opts.delay == true
		db.prompt.thankUnseen = opts.unseen == true
		db.prompt.thankAsk = opts.ask ~= false
		if opts.before then opts.before(ns) end
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		Mock.timers = {}
		Mock.printed = {}
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Power Word: Fortitude as this client numbers it, and the next instance.
local nextId = 9900
local function fortitude(ns) return ns.BUFF_BY_ID[10938] and 10938 or 21562 end
local function favour(ns, unit, spell)
	nextId = nextId + 1
	return favourFrom(ns, unit, spell or fortitude(ns), nextId)
end

local function said() return table.concat(Mock.printed, "\n") end

-- The thank-yous in a queue built now, in order.
local function thanks(ns)
	local out = {}
	for _, e in ipairs(ns.BuildQueue()) do
		if e.thank then out[#out + 1] = e end
	end
	return out
end

local function state(ns) return ns.Prompt.state end
local function shown(ns) return ns.Prompt:GetButton():IsShown() == true end

-- The prompt painted, then pressed with the left button (or `button`).
local function press(ns, button)
	ns.Prompt:Refresh()
	return pressButton(ns, button)
end

local function nameOf(ns, unit) return ns.UnitFullName(unit) end

-- The queue as a line, for a failure to show.
local function dump(ns)
	local out = {}
	for _, e in ipairs(ns.BuildQueue()) do
		out[#out + 1] = ("%s/%s/%s%s"):format(tostring(e.name), tostring(e.reason), tostring(e.priority),
			e.thank and "/thank" or "")
	end
	return table.concat(out, ", ")
end

-- A menu's items as lines, for a failure to show.
local function tree(root, depth)
	depth = depth or 0
	local out = {}
	for _, item in ipairs(root and root.items or {}) do
		out[#out + 1] = string.rep("  ", depth) .. tostring(item.text)
		local sub = tree(item, depth + 1)
		if sub ~= "" then out[#out + 1] = sub end
	end
	return table.concat(out, "\n")
end

-- ------------------------------------------------------------------ the switch
do
	local scenario = "thankpress: off by default, the thanks go by themselves"
	with(scenario, { ask = false }, function(ns)
		if ns.defaults.profile.prompt.thankAsk ~= false then fail(scenario, "the switch is not off in a new profile") end
		favour(ns, "nameplate1")
		if #emotes ~= 1 then fail(scenario, ("%d emotes with the switch off"):format(#emotes)) end
		if #thanks(ns) ~= 0 then fail(scenario, "a thank waits for a press with the switch off") end
	end)
end

do
	local scenario = "thankpress: on, nothing goes by itself and the prompt offers the thank"
	with(scenario, { whisper = true }, function(ns)
		local anna = nameOf(ns, "nameplate1")
		favour(ns, "nameplate1")
		if #emotes ~= 0 or #whispers ~= 0 then
			fail(scenario, ("%d emotes and %d whispers went by themselves"):format(#emotes, #whispers))
		end
		local list = thanks(ns)
		local entry = list[1]
		if #list ~= 1 or not entry then fail(scenario, ("%d thanks on the queue"):format(#list)) return end
		if entry.name ~= anna then fail(scenario, "the thank is for " .. tostring(entry.name)) end
		if entry.reason ~= "thank" then fail(scenario, "its reason is " .. tostring(entry.reason)) end
		if entry.priority ~= 2.5 then fail(scenario, "its priority is " .. tostring(entry.priority)) end
		local spell = ns.SpellNameFor(fortitude(ns))
		if ns.BuffName(entry.buff) ~= spell then
			fail(scenario, "the buff is named " .. tostring(ns.BuffName(entry.buff)) .. ", not " .. tostring(spell))
		end
		local reason = ns.Prompt:ReasonText(entry)
		if reason ~= ns.L["for %s -- they buffed you"]:format(spell) then
			fail(scenario, "the second line reads |" .. tostring(reason) .. "|")
		end
		if entry.display ~= ns.L["Thank %s"]:format(ns.ShortName(anna)) then
			fail(scenario, "the prompt names it |" .. tostring(entry.display) .. "|")
		end
		ns.Prompt:Refresh()
		if not shown(ns) then fail(scenario, "the prompt is not up for a rogue with a thank waiting") end
		local S = state(ns)
		if not (S.current and S.current.thank) then fail(scenario, "the prompt is not on the thank") end
		if ns.Prompt:GetButton():GetAttribute("macrotext1") ~= nil then
			fail(scenario, "the button holds a macro for a thank")
		end
	end)
end

-- ------------------------------------------------------------------ the press
do
	local scenario = "thankpress: a press sends what would have gone by itself"
	with(scenario, { whisper = true }, function(ns)
		-- Bo's thank by itself first, as it always went.
		ns.db.profile.prompt.thankAsk = false
		favour(ns, "nameplate2")
		if #emotes ~= 1 or #whispers ~= 1 then
			fail(scenario, ("SKIPPED -- by itself, %d emotes and %d whispers"):format(#emotes, #whispers))
			return
		end
		ns.db.profile.prompt.thankAsk = true
		-- Two seconds later, inside the gap between two thanks: a press is the player's own.
		Mock.advance(2)
		favour(ns, "nameplate1")
		if #emotes ~= 1 then fail(scenario, "Anna's thank went by itself") return end
		local ran = press(ns)
		if ran ~= nil then fail(scenario, "the press ran a macro: " .. tostring(ran)) end
		if #emotes ~= 2 then fail(scenario, ("%d emotes after the press"):format(#emotes)) return end
		if emotes[2][1] ~= emotes[1][1] then
			fail(scenario, "the press made " .. tostring(emotes[2][1]) .. ", by itself " .. tostring(emotes[1][1]))
		end
		if emotes[2][2] ~= "nameplate1" then fail(scenario, "the emote went at " .. tostring(emotes[2][2])) end
		if #whispers ~= 2 or whispers[2].channel ~= "WHISPER" then
			fail(scenario, ("%d whispers after the press"):format(#whispers))
		end
		if #thanks(ns) ~= 0 then fail(scenario, "the thank is still offered after it went") end
		local log = ns.thankLog.thanked
		if not (log and log.name == nameOf(ns, "nameplate1")) then fail(scenario, "the thank was not written down") end
	end)
end

do
	local scenario = "thankpress: the prompt's key thanks during the global cooldown"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		ns.Prompt:Refresh()
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5 } }
		if ns.CastReady() then
			Mock.spellCooldowns = nil
			fail(scenario, "SKIPPED -- the global cooldown is not running")
			return
		end
		pressButton(ns)
		Mock.spellCooldowns = nil
		if #emotes ~= 1 then fail(scenario, ("%d emotes from a press in the cooldown"):format(#emotes)) end
	end)
end

-- ------------------------------------------------------------------ lapsing
do
	local scenario = "thankpress: twenty seconds on the prompt and it lapses, nothing sent"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		-- The launcher and /manners debug build the queue with nothing shown:
		-- no clock starts.
		for _ = 1, 3 do
			ns.BuildQueue()
			Mock.advance(10)
		end
		if #thanks(ns) ~= 1 then fail(scenario, "the thank lapsed before the prompt ever showed it") return end
		ns.Prompt:Refresh()
		if not shown(ns) then fail(scenario, "SKIPPED -- the prompt did not show the thank") return end
		Mock.runTimers(19)
		if #thanks(ns) ~= 1 then fail(scenario, "the thank went before twenty seconds on the prompt") return end
		-- The cursor resting on the panel holds nothing past the lapse.
		local button = ns.Prompt:GetButton()
		button.scripts.OnEnter(button)
		Mock.runTimers(1.2)
		ns.Prompt:Refresh()
		if #thanks(ns) ~= 0 then fail(scenario, "the thank is still offered after twenty seconds on the prompt") end
		if shown(ns) then fail(scenario, "the panel stays up on a lapsed thank under the cursor") end
		button.scripts.OnLeave(button)
		if #emotes ~= 0 then fail(scenario, "a lapsed thank was sent") end
	end)
end

do
	local scenario = "thankpress: a minute after the landing it lapses, shown or not"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		Mock.advance(59)
		if #thanks(ns) ~= 1 then fail(scenario, "SKIPPED -- the thank went before the minute") return end
		Mock.advance(1.5)
		if #thanks(ns) ~= 0 then fail(scenario, "the thank is still offered a minute after the landing") end
		if #emotes ~= 0 then fail(scenario, "a lapsed thank was sent") end
	end)
end

-- ------------------------------------------------------------------ a fight
do
	local scenario = "thankpress: a fight drops it and nothing is sent"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		ns.Prompt:Refresh()
		-- The pull's own repaint, still before the lockdown.
		ns.addon:PLAYER_REGEN_DISABLED()
		local S = state(ns)
		for _, e in ipairs(S.fightQueue or {}) do
			if e.thank then fail(scenario, "the fight's rota holds a thank") end
		end
		if S.current and S.current.thank then fail(scenario, "the pull left the prompt on a thank") end
		Mock.frameEvent("PLAYER_REGEN_DISABLED")
		Mock.inCombat = true
		pressButton(ns)
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		ns.Prompt.armedForFight = nil
		if #thanks(ns) ~= 0 then fail(scenario, "the thank is offered again after the fight") end
		if #emotes ~= 0 then fail(scenario, "a thank went in or after the fight") end
	end)
end

-- ------------------------------------------------------------------ the order
local AI = { [1459] = true, [1460] = true, [1461] = true, [10156] = true, [10157] = true }

do
	local scenario = "thankpress: a buff your group needs comes first, then the thank, then a passer-by"
	with(scenario, { class = "MAGE", group = 2,
		names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" }, party1 = { "Cy", "Cole" } },
		before = function(ns) ns.db.profile.sources.owed = false end }, function(ns)
		local anna = nameOf(ns, "nameplate1")
		-- Never offered a buff herself, so only her thank is hers on the queue.
		ns.PutOnNeverList(anna)
		favour(ns, "nameplate1")
		local queue = ns.BuildQueue()
		local at, group, passer = {}, nil, nil
		for i, e in ipairs(queue) do
			if e.thank then at.thank = at.thank or i end
			if e.reason == "group" then group = group or i end
			if e.reason == "nearby" then passer = passer or i end
		end
		if not (at.thank and group and passer) then
			fail(scenario, ("SKIPPED -- thank %s, group %s, passer-by %s: %s"):format(tostring(at.thank), tostring(group),
				tostring(passer), dump(ns)))
			return
		end
		if not (group < at.thank and at.thank < passer) then
			fail(scenario, ("the group member is %d, the thank %d, the passer-by %d"):format(group, at.thank, passer))
		end
	end)
end

do
	local scenario = "thankpress: somebody you owe a buff is thanked once it is done"
	with(scenario, { class = "MAGE", names = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		local anna = nameOf(ns, "nameplate1")
		favour(ns, "nameplate1")
		if not ns.owed[anna] then fail(scenario, "SKIPPED -- no debt was filed") return end
		local queue = ns.BuildQueue()
		local seen = {}
		for _, e in ipairs(queue) do
			if seen[e.name] then fail(scenario, e.name .. " is queued twice") end
			seen[e.name] = true
		end
		if #thanks(ns) ~= 0 then fail(scenario, "the thank is offered ahead of the buff she is owed") end
		wipe(ns.owed)
		Mock.held = AI
		ns.ForgetAuraCache()
		if #thanks(ns) ~= 1 then fail(scenario, "the thank is not offered once the buff is done: " .. dump(ns)) end
	end)
end

-- ------------------------------------------------------------------ several givers
do
	local scenario = "thankpress: two givers, two presses, two thanks"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		Mock.advance(1)
		favour(ns, "nameplate2")
		local list = thanks(ns)
		if #list ~= 2 then fail(scenario, ("%d thanks for two givers"):format(#list)) return end
		if list[1].name ~= nameOf(ns, "nameplate1") then fail(scenario, "the first giver is not first") end
		press(ns)
		Mock.advance(1)
		press(ns)
		if #emotes ~= 2 then fail(scenario, ("%d emotes from two presses a second apart"):format(#emotes)) return end
		if emotes[1][2] ~= "nameplate1" or emotes[2][2] ~= "nameplate2" then
			fail(scenario, "the emotes went at " .. tostring(emotes[1][2]) .. " and " .. tostring(emotes[2][2]))
		end
	end)
end

do
	local scenario = "thankpress: a second buff from the same giver is the same thank, for the newer buff"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		-- Divine Spirit where there is one; else another buff the client has (Arcane Intellect).
		local spirit = ns.BUFF_BY_ID[27841] and 27841 or (ns.BUFF_BY_ID[14819] and 14819) or nil
		if not spirit then
			local int = ns.FindBuff("MAGE", "intellect")
			spirit = int and int.ranks[1] or nil
		end
		if not spirit then return end
		-- Offered once already, so its entry has been made.
		if #thanks(ns) ~= 1 then fail(scenario, "SKIPPED -- the first buff's thank is not offered") return end
		Mock.advance(1)
		favour(ns, "nameplate1", spirit)
		local list = thanks(ns)
		if #list ~= 1 then fail(scenario, ("%d thanks for one giver"):format(#list)) return end
		if ns.BuffName(list[1].buff) ~= ns.SpellNameFor(spirit) then
			fail(scenario, "the thank names " .. tostring(ns.BuffName(list[1].buff)) .. ", not the newer buff")
		end
	end)
end

-- ------------------------------------------------------------------ the limits
do
	local scenario = "thankpress: once thanked, the same giver is not offered again for five minutes"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		press(ns)
		if #emotes ~= 1 then fail(scenario, "SKIPPED -- the press did not thank") return end
		Mock.advance(30)
		favour(ns, "nameplate1")
		if #thanks(ns) ~= 0 then fail(scenario, "offered again thirty seconds after a thank") end
		Mock.advance(300)
		favour(ns, "nameplate1")
		if #thanks(ns) ~= 1 then fail(scenario, "not offered again after five minutes") end
	end)
end

do
	local scenario = "thankpress: never in an instance"
	with(scenario, {}, function(ns)
		place = "party"
		favour(ns, "nameplate1")
		place = false
		if #thanks(ns) ~= 0 then fail(scenario, "a buff in a dungeon is offered a thank") end
	end)
end

-- ------------------------------------------------------------------ letting go
do
	local scenario = "thankpress: a right-click lets it go, nothing sent and nobody blocked"
	with(scenario, {}, function(ns)
		local anna = nameOf(ns, "nameplate1")
		favour(ns, "nameplate1")
		local realShift = rawget(_G, "IsShiftKeyDown")
		rawset(_G, "IsShiftKeyDown", function() return true end)
		press(ns, "RightButton")
		rawset(_G, "IsShiftKeyDown", realShift)
		if #emotes ~= 0 then fail(scenario, "a right-click sent the thank") end
		if #thanks(ns) ~= 0 then fail(scenario, "the thank is still offered after a right-click") end
		if ns.IsBlocked(anna, nil, GetTime()) then fail(scenario, "a right-click on a thank blocked Anna") end
		if ns.IsNeverOffered(anna) then fail(scenario, "a shift-right-click on a thank put Anna on the never-offer list") end
	end)
end

do
	local scenario = "thankpress: let go or lapsed, the same giver's next buffs are not offered"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		press(ns, "RightButton")
		Mock.advance(2)
		favour(ns, "nameplate1")
		if #thanks(ns) ~= 0 then fail(scenario, "offered again two seconds after a right-click") end
		-- And Bo, left to lapse.
		favour(ns, "nameplate2")
		ns.Prompt:Refresh()
		Mock.runTimers(21)
		ns.BuildQueue()
		Mock.advance(2)
		favour(ns, "nameplate2")
		if #thanks(ns) ~= 0 then fail(scenario, "offered again two seconds after it lapsed") end
	end)
end

-- ------------------------------------------------------------------ the switches at the press
do
	local scenario = "thankpress: the switches are read at the press"
	with(scenario, { whisper = true }, function(ns)
		favour(ns, "nameplate1")
		ns.db.profile.prompt.thankEmote = false
		press(ns)
		if #emotes ~= 0 then fail(scenario, "the emote went after it was switched off") end
		if #whispers ~= 1 then fail(scenario, ("%d whispers, the whisper still on"):format(#whispers)) end
	end)
end

do
	local scenario = "thankpress: a thank with nothing left to send is dropped"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		if #thanks(ns) ~= 1 then fail(scenario, "SKIPPED -- no thank waits") return end
		ns.db.profile.prompt.thankEmote = false
		ns.db.profile.prompt.thankWhisper = true
		if #thanks(ns) ~= 0 then fail(scenario, "an emote's thank is still offered with the emote off") end
	end)
end

do
	local scenario = "thankpress: the giver's token is looked for again at the press"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		ns.Prompt:Refresh()
		-- Anna's nameplate went to Zed, and Anna is on another.
		Mock.unitNames.nameplate1 = { "Zed", "Gone" }
		Mock.unitNames.nameplate2 = { "Anna", "Aim" }
		pressButton(ns)
		if #emotes ~= 1 or emotes[1][2] ~= "nameplate2" then
			fail(scenario, "the emote went at " .. tostring(emotes[1] and emotes[1][2]))
		end
	end)
end

do
	local scenario = "thankpress: gone at the press, nothing is sent and the line says why"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		ns.Prompt:Refresh()
		Mock.unitNames.nameplate1 = { "Zed", "Gone" }
		Mock.printed = {}
		pressButton(ns)
		if #emotes ~= 0 then fail(scenario, "the emote went at " .. tostring(emotes[1][2])) end
		if not said():find(ns.L["not thanked: %s."]:format(ns.L["they are out of sight now"]), 1, true) then
			fail(scenario, "the press did not say why: " .. said())
		end
	end)
end

do
	local scenario = "thankpress: stealthed at the press, nothing is sent"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		ns.Prompt:Refresh()
		rawset(_G, "IsStealthed", function() return true end)
		pressButton(ns)
		rawset(_G, "IsStealthed", original.IsStealthed)
		if #emotes ~= 0 then fail(scenario, "the emote went while stealthed") end
	end)
end

-- ------------------------------------------------------------------ nobody named
do
	local scenario = "thankpress: unseen, parked with a target held, and a press asks to clear it"
	with(scenario, { unseen = true, names = { nameplate1 = { "Anna", "Aim" }, target = { "Tess", "Target" } } },
		function(ns)
			favour(ns, nil)
			Mock.advance(1)
			favour(ns, nil)
			local list = thanks(ns)
			if #list ~= 1 then fail(scenario, ("%d thanks for two buffs from nobody named"):format(#list)) return end
			if list[1].name ~= "?thank" then fail(scenario, "the thank is filed under " .. tostring(list[1].name)) end
			if ns.Prompt:ReasonText(list[1]) ~= ns.L["clear your target to thank them"] then
				fail(scenario, "the second line reads |" .. tostring(ns.Prompt:ReasonText(list[1])) .. "|")
			end
			press(ns)
			if #emotes ~= 0 then fail(scenario, "the emote went with somebody targeted") end
			if #thanks(ns) ~= 1 then fail(scenario, "the thank was dropped by a press with a target") end
			Mock.unitNames.target = nil
			Mock.advance(1)
			press(ns)
			if #emotes ~= 1 or emotes[1][2] ~= nil then
				fail(scenario, ("%d emotes, at %s, once the target was cleared"):format(#emotes, tostring(emotes[1] and emotes[1][2])))
			end
		end)
end

do
	local scenario = "thankpress: unseen, no line left out is said at the press"
	with(scenario, { unseen = true, platesOff = true, names = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		ns.db.profile.verbose = true
		favour(ns, nil)
		Mock.printed = {}
		press(ns)
		if said():find("a line was left out", 1, true) then fail(scenario, "the press said a line was left out") end
		if #emotes ~= 1 then fail(scenario, ("SKIPPED -- %d emotes"):format(#emotes)) end
	end)
end

do
	local scenario = "thankpress: classic: a whisper by name and the scan's reading of one landing are one thank"
	with(scenario, { flavour = "vanilla", unseen = true, whisper = true, names = {},
		before = function(ns) ns.db.profile.sources.owed = false end }, function(ns)
		if not ns.combatLogArmed then fail(scenario, "SKIPPED -- the log is not armed") return end
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		local list = thanks(ns)
		if #list ~= 1 or list[1].name ~= "Petra" then
			fail(scenario, ("SKIPPED -- %d thanks from the log, the first %s"):format(#list, tostring(list[1] and list[1].name)))
			return
		end
		Mock.advance(2)
		favour(ns, nil, 21562)
		list = thanks(ns)
		if #list ~= 1 then fail(scenario, ("%d thanks for one landing"):format(#list)) return end
		press(ns)
		if #whispers ~= 1 or whispers[1].target ~= "Petra" then
			fail(scenario, ("%d whispers, the first to %s"):format(#whispers, tostring(whispers[1] and whispers[1].target)))
		end
		if #emotes ~= 0 then fail(scenario, "an emote went too") end
	end)
end

-- ------------------------------------------------------------------ a rogue's prompt
do
	local scenario = "thankpress: a rogue has a prompt while a thank waits, and none after"
	with(scenario, {}, function(ns)
		if ns.CanCastAnything() then fail(scenario, "SKIPPED -- the rogue has something to cast already") return end
		favour(ns, "nameplate1")
		if not ns.CanCastAnything() then fail(scenario, "a thank waiting gives the rogue nothing to press") end
		press(ns)
		if ns.CanCastAnything() then fail(scenario, "the rogue still has something to press once it went") end
	end)
end

do
	local scenario = "thankpress: the pause before thanking is left out"
	with(scenario, { delay = true }, function(ns)
		favour(ns, "nameplate1")
		if #thanks(ns) ~= 1 then fail(scenario, "the thank waits out a pause before it is offered") return end
		press(ns)
		if #emotes ~= 1 then fail(scenario, "the press waited for a pause") end
		Mock.runTimers(4)
		if #emotes ~= 1 then fail(scenario, ("%d emotes after the pause"):format(#emotes)) end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if said():find("wait a moment before thanking: |cff00ff00on", 1, true) then
			fail(scenario, "/manners debug says the pause is on")
		end
	end)
end

-- ------------------------------------------------------------------ a name in the list
do
	local scenario = "thankpress: a name in the list thanks that giver"
	with(scenario, {}, function(ns)
		local db = ns.db.profile
		db.prompt.showQueue, db.prompt.queueRows, db.prompt.clickRows = true, 3, true
		ns.Prompt:ApplyStyle()
		favour(ns, "nameplate1")
		Mock.advance(1)
		favour(ns, "nameplate2")
		ns.Prompt:Refresh()
		local found
		for _, button in ipairs(ns.Prompt:Regions().rowButtons or {}) do
			local row = button.mannersRow
			if row and row.entry and row.entry.thank and row.entry.name == nameOf(ns, "nameplate2") then found = button end
		end
		if not found then fail(scenario, "SKIPPED -- no name in the list is Bo's thank") return end
		local pre, post = found.scripts.PreClick, found.scripts.PostClick
		if pre then pre(found, "LeftButton", true) end
		if post then post(found, "LeftButton", true) end
		if #emotes ~= 1 or emotes[1][2] ~= "nameplate2" then
			fail(scenario, ("%d emotes, the first at %s"):format(#emotes, tostring(emotes[1] and emotes[1][2])))
		end
		local list = thanks(ns)
		if #list ~= 1 or list[1].name ~= nameOf(ns, "nameplate1") then fail(scenario, "Anna's thank did not stay") end
	end)
end

-- ------------------------------------------------------------------ /manners debug
do
	local scenario = "thankpress: /manners debug says the switch is on and who waits"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("ask me before thanking: |cff00ff00on", 1, true) then
			fail(scenario, "/manners debug does not say the switch is on")
		end
		if not said():find("waiting for your press to thank: |cffffffff" .. nameOf(ns, "nameplate1"), 1, true) then
			fail(scenario, "/manners debug does not say who waits")
		end
		if not ns.FullReport():find("thankAsk=true", 1, true) then
			fail(scenario, "the full check-up does not say the switch is on")
		end
	end)
end

-- ------------------------------------------------------------------ the options
do
	local scenario = "thankpress: What I say has the switch, for a rogue too"
	with(scenario, { ask = false, thank = false }, function(ns)
		local control = findOption(ns.optionsTable, "thankAsk")
		if not control then fail(scenario, "What I say has no switch") return end
		local hidden = control.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if hidden then fail(scenario, "the switch is hidden from a rogue") end
		if control.name ~= ns.L["Ask me before thanking"] then fail(scenario, "the switch reads " .. tostring(control.name)) end
		if not (type(control.disabled) == "function" and control.disabled()) then
			fail(scenario, "the switch is live with the /thank and the whisper both off")
		end
		ns.db.profile.prompt.thankWhisper = true
		if control.disabled() then fail(scenario, "the switch is greyed with the whisper on") end
		control.set(nil, true)
		if ns.db.profile.prompt.thankAsk ~= true or control.get() ~= true then fail(scenario, "turning it on was not kept") end
		local delay = findOption(ns.optionsTable, "thankDelay")
		if not (delay and delay.disabled()) then fail(scenario, "the pause is live while the thanks wait for a press") end
		local note = ns.WindowLayout.offNotes["click.thankDelay"]
		local text = type(note) == "function" and note() or note
		if type(text) ~= "string" or not text:find(ns.L["Ask me before thanking"], 1, true) then
			fail(scenario, "the pause's greyed note reads " .. tostring(text))
		end
		ns.db.profile.prompt.thankAsk = "yes"
		ns.ClampSettings()
		if ns.db.profile.prompt.thankAsk ~= false then fail(scenario, "a damaged value was kept") end
	end)
end

do
	local scenario = "thankpress: a pasted string can hold the thanks, never send them by themselves"
	with(scenario, { ask = false }, function(ns)
		local prompt = ns.db.profile.prompt
		prompt.thankAsk = true
		local on = ns.ExportSettings()
		prompt.thankAsk = false
		local off = ns.ExportSettings()
		prompt.thankAsk = true
		local ok = ns.ImportSettings(off)
		if not ok then fail(scenario, "SKIPPED -- the string did not import") return end
		if ns.db.profile.prompt.thankAsk ~= true then fail(scenario, "a pasted string switched it off") end
		ns.db.profile.prompt.thankAsk = false
		ok = ns.ImportSettings(on)
		if ok and ns.db.profile.prompt.thankAsk ~= true then fail(scenario, "a pasted string with it on did not carry it") end
	end)
end

-- ------------------------------------------------------------------ the other entries
do
	local scenario = "thankpress: an ask of the same person gives way to the thank"
	with(scenario, { class = "WARRIOR", names = { nameplate1 = { "Anna", "Aim" } },
		before = function(ns)
			Mock.unitClass = "PRIEST"
			ns.db.profile.sources.ask = true
			ns.Ask.ARRIVE_SECONDS = 0
		end }, function(ns)
		Mock.playerHeld = {}
		if ns.Ask then ns.Ask.ForgetWorn() end
		local asked
		for _, e in ipairs(ns.BuildQueue()) do if e.ask then asked = e end end
		if not asked then fail(scenario, "SKIPPED -- nobody is asked for a buff") return end
		favour(ns, "nameplate1")
		if ns.Ask then ns.Ask.ForgetWorn() end
		local queue = ns.BuildQueue()
		local seen, thank = {}, nil
		for _, e in ipairs(queue) do
			if seen[e.name] then fail(scenario, e.name .. " is queued twice") end
			seen[e.name] = true
			if e.thank then thank = e end
		end
		if not thank then fail(scenario, "the thank gave way to the ask") end
	end)
end

do
	local scenario = "thankpress: a member a group cast covers is thanked once it is done"
	with(scenario, { class = "MAGE", group = 5, brilliance = true,
		names = { party1 = { "Anna", "Aim" }, party2 = { "Bo", "Brisk" }, party3 = { "Cy", "Cole" }, party4 = { "Di", "Dune" } },
		before = function(ns)
			ns.db.profile.sources.owed = false
			ns.db.profile.groupBuffs.use, ns.db.profile.groupBuffs.atLeast = true, 2
		end }, function(ns)
		local int = ns.FindBuff("MAGE", "intellect")
		if not (int and int.groupCast) then return end -- this client has no group cast to cover a member with
		local cast
		for _, e in ipairs(ns.BuildQueue()) do if e.groupCast then cast = e end end
		if not cast then fail(scenario, "SKIPPED -- no group cast on the queue") return end
		local unit
		for _, token in ipairs({ "party1", "party2", "party3", "party4" }) do
			local name = nameOf(ns, token)
			for _, member in ipairs(cast.groupCast.members or {}) do
				if member == name and name ~= cast.name then unit = unit or token end
			end
		end
		if not unit then fail(scenario, "SKIPPED -- no member but the one it is aimed at") return end
		favour(ns, unit)
		for _, e in ipairs(ns.BuildQueue()) do
			if e.thank and e.name == nameOf(ns, unit) then fail(scenario, e.name .. " is thanked beside a group cast that covers them") end
		end
	end)
end

do
	local scenario = "thankpress: a press follows the panel's kind, a thank is never a cast"
	with(scenario, { class = "MAGE", held = AI, names = { nameplate1 = { "Anna", "Aim" } },
		before = function(ns) ns.db.profile.sources.owed = false end }, function(ns)
		favour(ns, "nameplate1")
		ns.Prompt:Refresh()
		local S = state(ns)
		if not (S.current and S.current.thank) then fail(scenario, "SKIPPED -- the prompt is not on the thank") return end
		-- Her Intellect gone since: the queue now offers her a buff.
		Mock.held = nil
		ns.ForgetAuraCache()
		local before = dump(ns)
		Mock.printed = {}
		local ran = pressButton(ns)
		if ran ~= nil then fail(scenario, "the press on the thank cast: " .. tostring(ran)) end
		if #emotes ~= 0 then fail(scenario, "the press emoted at her") end
		if not said():find("the prompt has moved on", 1, true) then
			fail(scenario, "the press did not say the prompt moved on: " .. before)
		end
	end)
end

do
	local scenario = "thankpress: the tooltip and the launcher say what a press does"
	-- A mage among people who all wear his Intellect: the thank is all there is.
	with(scenario, { class = "MAGE", held = AI, names = { nameplate1 = { "Anna", "Aim" } },
		before = function(ns) ns.db.profile.sources.owed = false end }, function(ns)
		ns.db.profile.prompt.tooltip = "full"
		favour(ns, "nameplate1")
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		Mock.tooltip = {}
		button.scripts.OnEnter(button)
		local tip = table.concat(Mock.tooltip, "\n")
		button.scripts.OnLeave(button)
		if not tip:find(ns.L["Click to thank them."], 1, true) then fail(scenario, "the tooltip does not say a click thanks them") end
		if not tip:find(ns.L["Right-click: let it go, nothing is sent."], 1, true) then
			fail(scenario, "the tooltip does not say what a right-click does: " .. tip)
		end
		if tip:find("Click to cast", 1, true) or tip:find("never-offer", 1, true) then
			fail(scenario, "the tooltip offers a cast or the never-offer list: " .. tip)
		end
		local broker = Mock.broker
		if not (broker and broker.OnTooltipShow and broker.OnClick) then fail(scenario, "SKIPPED -- no launcher") return end
		local lines = {}
		broker.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = tostring(text) end })
		local launcher = table.concat(lines, "\n")
		if launcher:find("a passer-by", 1, true) then fail(scenario, "the launcher calls the thank a passer-by") end
		local function newMenu(text, fn)
			local d = { text = text, fn = fn, items = {} }
			local function add(item) d.items[#d.items + 1] = item return item end
			function d:CreateTitle(t) return add({ text = t, items = {} }) end
			function d:CreateDivider() return add({ items = {} }) end
			function d:CreateButton(t, f) return add(newMenu(t, f)) end
			function d:CreateCheckbox(t) return add(newMenu(t)) end
			function d:CreateRadio(t) return add(newMenu(t)) end
			function d:SetEnabled() end
			function d:SetTooltip() end
			return d
		end
		local function child(root, pattern)
			for _, item in ipairs(root and root.items or {}) do
				if item.text and tostring(item.text):find(pattern, 1, true) then return item end
			end
		end
		local opened
		rawset(_G, "MenuUtil", { CreateContextMenu = function(owner, generator)
			opened = newMenu()
			generator(owner, opened)
			return opened
		end })
		local ok, err = pcall(broker.OnClick, {}, "RightButton")
		rawset(_G, "MenuUtil", original.MenuUtil)
		local person = ok and child(child(opened, "Who's next"), ns.L["Thank %s"]:format(ns.ShortName(nameOf(ns, "nameplate1"))))
		if not person then fail(scenario, "Who's next does not list the thank: " .. tostring(err) .. "\n" .. tree(opened)) return end
		if child(person, "Never offer") or child(person, "Skip for now") then
			fail(scenario, "Who's next offers to skip the thank or never to offer her")
		end
		local letGo = child(person, ns.L["Let it go"])
		if not letGo then fail(scenario, "Who's next has no Let it go for the thank") return end
		letGo.fn()
		if #thanks(ns) ~= 0 then fail(scenario, "Let it go left the thank on the queue") end
		if ns.IsNeverOffered(nameOf(ns, "nameplate1")) then fail(scenario, "Let it go put her on the never-offer list") end
		if #emotes ~= 0 then fail(scenario, "Let it go sent the thank") end
	end)
end

-- ------------------------------------------------------------------ review of 1ce7e86
do
	local scenario = "thankpress: a thank the prompt never showed holds back none of their next ones"
	with(scenario, { class = "MAGE", names = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		local anna = nameOf(ns, "nameplate1")
		favour(ns, "nameplate1")
		if not ns.owed[anna] then fail(scenario, "SKIPPED -- no debt was filed") return end
		-- Held behind the buff she is owed for the whole minute, never shown.
		for _ = 1, 7 do
			if #thanks(ns) ~= 0 then fail(scenario, "SKIPPED -- the thank is offered beside her debt") return end
			Mock.advance(10)
		end
		Mock.advance(60)
		favour(ns, "nameplate1")
		wipe(ns.owed)
		Mock.held = AI
		ns.ForgetAuraCache()
		if #thanks(ns) ~= 1 then fail(scenario, "her next buff is not offered a thank: " .. dump(ns)) end
	end)
end

do
	local scenario = "thankpress: the sixth giver pushes out one never shown, who may be offered again"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" }, nameplate3 = { "Cy", "Cole" },
		nameplate4 = { "Di", "Dune" }, nameplate5 = { "Ed", "Eve" }, nameplate6 = { "Flo", "Fen" } }
	with(scenario, { names = names }, function(ns)
		for i = 1, 6 do
			favour(ns, "nameplate" .. i)
			Mock.advance(1)
		end
		local list = thanks(ns)
		if #list ~= 5 then fail(scenario, ("SKIPPED -- %d thanks for six givers"):format(#list)) return end
		if list[1].name == nameOf(ns, "nameplate1") then fail(scenario, "SKIPPED -- the first giver was not pushed out") return end
		favour(ns, "nameplate1")
		local again
		for _, e in ipairs(thanks(ns)) do
			if e.name == nameOf(ns, "nameplate1") then again = true end
		end
		if not again then fail(scenario, "the giver pushed out unseen is not offered again: " .. dump(ns)) end
	end)
end

do
	local scenario = "thankpress: a press the game refuses says so"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		ns.Prompt:Refresh()
		-- The game's answer true: the emote was restricted.
		rawset(_G, "DoEmote", function(emote, target)
			emotes[#emotes + 1] = { emote, target }
			return true
		end)
		Mock.printed = {}
		pressButton(ns)
		if #emotes ~= 1 then fail(scenario, ("SKIPPED -- %d emote calls"):format(#emotes)) return end
		local line = ns.L["not thanked: %s."]:format(ns.L["the game said it was restricted"])
		if not said():find(line, 1, true) then fail(scenario, "the press did not say the game refused it: " .. said()) end
	end)
end

do
	local scenario = "thankpress: stealthed, the thank is kept off the prompt until you show yourself"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		if #thanks(ns) ~= 1 then fail(scenario, "SKIPPED -- no thank waits") return end
		rawset(_G, "IsStealthed", function() return true end)
		local hidden = #thanks(ns)
		rawset(_G, "IsStealthed", original.IsStealthed)
		if hidden ~= 0 then fail(scenario, "the thank is offered while stealthed") end
		if #thanks(ns) ~= 1 then fail(scenario, "the thank is not offered again once out of stealth") end
		if #emotes ~= 0 then fail(scenario, "an emote went") end
	end)
end

do
	local scenario = "thankpress: the full check-up names nobody for an unseen thank"
	with(scenario, { unseen = true, names = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		favour(ns, nil)
		if #thanks(ns) ~= 1 then fail(scenario, "SKIPPED -- no thank waits") return end
		local report = ns.FullReport()
		if not report:find(ns.L["whoever buffed you"], 1, true) then
			fail(scenario, "the check-up turned \"" .. ns.L["whoever buffed you"] .. "\" into an alias")
		end
		if not report:find("(unseen) -- thank:", 1, true) then fail(scenario, "the queue's unseen thank is aliased as a person") end
	end)
end

do
	local scenario = "thankpress: a newer buff from the same giver starts the time on the prompt again"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		ns.Prompt:Refresh()
		if not shown(ns) then fail(scenario, "SKIPPED -- the prompt did not show the thank") return end
		Mock.runTimers(18)
		favour(ns, "nameplate1")
		if #thanks(ns) ~= 1 then fail(scenario, "SKIPPED -- the newer buff is not offered") return end
		Mock.runTimers(5)
		if #thanks(ns) ~= 1 then fail(scenario, "the thank lapsed five seconds after her newer buff") end
	end)
end

do
	local scenario = "thankpress: unseen, two spells let go are both held back"
	with(scenario, { unseen = true, names = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		local int = ns.FindBuff("MAGE", "intellect")
		local fort, intellect = fortitude(ns), ns.BUFF_BY_ID[10157] and 10157 or (int and int.ranks[1])
		if not (intellect and ns.BUFF_BY_ID[intellect]) then fail(scenario, "SKIPPED -- no Arcane Intellect here") return end
		favour(ns, nil, fort)
		Mock.advance(1)
		favour(ns, nil, intellect)
		if #thanks(ns) ~= 1 then fail(scenario, "SKIPPED -- two unseen buffs are not one thank") return end
		ns.Prompt:Refresh()
		Mock.runTimers(21)
		ns.BuildQueue()
		if #thanks(ns) ~= 0 then fail(scenario, "SKIPPED -- the thank did not lapse") return end
		Mock.advance(2)
		favour(ns, nil, fort)
		if #thanks(ns) ~= 0 then fail(scenario, "the first spell of the two is offered again after it lapsed") end
	end)
end
