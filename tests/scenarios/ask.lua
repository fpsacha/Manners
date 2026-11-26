-- Asking, not only giving (Ask.lua): when somebody of a class with a buff you
-- would want is in your group or right beside you, and you do not wear it, an
-- "ask" entry comes up on the prompt, last of everything, and a press says one
-- polite line to them and casts nothing.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- global a scenario replaces is put back after it, by rawset. The mock answers
-- for nothing an ask reads about the moment -- IsResting, UnitAffectingCombat,
-- IsInInstance, UnitIsAFK -- so each scenario is handed a quiet world (out in
-- the open, nobody fighting) and changes the one thing it is about.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton = H.strangers, H.freshPrompt, H.pressButton
local findOption = H.findOption

local TOUCHED = { "IsResting", "UnitAffectingCombat", "IsInInstance", "UnitIsAFK", "UnitIsDND", "UnitLevel",
	"C_FriendList", "UnitIsDeadOrGhost", "UnitExists", "UnitInRange", "UnitIsVisible",
	"IsSpellKnown", "IsPlayerSpell" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local QUIET = {
	IsResting = function() return false end,
	UnitAffectingCombat = function() return false end,
	UnitInRange = function() return true, true end,
	UnitIsVisible = function() return true end,
}

-- Runs one scenario in the quiet world, with `globals` over it, and puts every
-- global back whether it finished or threw. A throw is that scenario's failure.
local function with(scenario, globals, body)
	for name, value in pairs(QUIET) do rawset(_G, name, value) end
	for name, value in pairs(globals or {}) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The ask in the queue, or nil.
local function asking(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.ask then return entry end
	end
	return nil
end

-- A warrior (nothing to give anybody on WoW Forever) who wears nothing, with a
-- priest, Anna Aim, on a nameplate and asking switched on. `setup` changes
-- the mock before the addon loads. Returns the addon and the undo for the
-- units, or nil when the scenario is left out of this run.
local function ready(scenario, setup)
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.unitClass = "PRIEST"
	-- Nothing worn: the mock's player otherwise wears every aura asked about.
	Mock.playerHeld = {}
	local names = { nameplate1 = { "Anna", "Aim" } }
	if setup then names = setup(names) or names end
	local restoreUnits = strangers(names)
	local ns = load(scenario)
	if not ns then
		restoreUnits()
		return nil
	end
	freshPrompt(ns, scenario)
	ns.db.profile.sources.ask = true
	return ns, restoreUnits
end

-- What the line reads as for a person, from the template the settings hold.
local function lineFor(ns, template, name, spell)
	return (template:gsub("{name}", name):gsub("{buff}", spell))
end

local function fortitude(ns)
	local buff = ns.FindBuff("PRIEST", "fortitude")
	return buff, ns.SpellNameFor(buff.ranks[1])
end

-- ---------------------------------------------------------------------- 1
-- Off until ticked: nothing changes for a player who touches no setting.
do
	local scenario = "ask: off until it is ticked, and then somebody who could give you a buff comes up"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		local db = ns.db.profile
		if ns.defaults.profile.sources.ask ~= false then
			fail(scenario, "sources.ask is " .. tostring(ns.defaults.profile.sources.ask) .. " out of the box, not off")
		end
		db.sources.ask = false
		if asking(ns) then fail(scenario, "somebody is asked with the switch off") end
		if ns.CanCastAnything() then
			fail(scenario, "SKIPPED -- a warrior with nothing learned has something to cast, so the off case shows nothing")
		end
		db.sources.ask = true
		local entry = asking(ns)
		local buff, spell = fortitude(ns)
		if not entry then
			fail(scenario, "a priest stands beside a warrior who wears no Fortitude, and nobody is asked")
		else
			if entry.name ~= "Anna Aim" then fail(scenario, "asked " .. tostring(entry.name)) end
			if entry.reason ~= "ask" then fail(scenario, "its reason is " .. tostring(entry.reason)) end
			if not entry.buff or entry.buff.wanted ~= buff then
				fail(scenario, "asked for " .. tostring(entry.buff and entry.buff.key) .. ", not Fortitude")
			end
			if ns.BuffName(entry.buff) ~= spell then
				fail(scenario, "the buff is named " .. tostring(ns.BuffName(entry.buff)) .. ", not " .. tostring(spell))
			end
			if ns.Prompt:ReasonText(entry) ~= ns.L["ask for %s"]:format(spell) then
				fail(scenario, "the prompt's second line reads |" .. tostring(ns.Prompt:ReasonText(entry)) .. "|")
			end
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 2
-- The press: one whispered line, no target change, no cast, nothing filed.
do
	local scenario = "ask: a press whispers one polite line, targets nobody and casts nothing"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		if not button:IsShown() then fail(scenario, "the prompt is not up for somebody to ask") end
		local _, spell = fortitude(ns)
		local want = "/w Anna Aim " .. lineFor(ns, ns.Ask.LINES.moment, "Anna Aim", spell)
		local ran = pressButton(ns)
		if ran ~= want then
			fail(scenario, "the press ran |" .. tostring(ran) .. "|, not |" .. want .. "|")
		end
		if type(ran) == "string" then
			if ran:find("\n", 1, true) then fail(scenario, "the macro has more than one line") end
			if ran:find("/target", 1, true) or ran:find("/cast", 1, true) or ran:find("/use", 1, true) then
				fail(scenario, "the macro targets or casts: " .. ran)
			end
			if ran:find("[@", 1, true) then fail(scenario, "the macro holds a conditional: " .. ran) end
			if #ran > ns.MACRO_LIMIT then fail(scenario, "the macro is " .. #ran .. " characters") end
		end
		if ns.pendingClick then
			fail(scenario, "a press that cast nothing was parked for the game to settle, as a cast is")
		end
		if ns.lastGave["Anna Aim"] ~= nil then
			fail(scenario, "the ask was filed as a buff given to her")
		end
		-- And she is off the prompt at once: nothing is left armed to say it twice.
		if asking(ns) then fail(scenario, "she is asked again straight after the press") end
		local left = button:GetAttribute("macrotext1")
		if left ~= nil then fail(scenario, "the button still holds |" .. tostring(left) .. "| after the press") end
		-- Nor does the panel go on naming her with nothing behind it.
		if button:IsShown() then fail(scenario, "the prompt still names her after the press, with nothing armed") end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 3
-- One ask per person per buff in ten minutes, and one ask in all in two.
do
	local scenario = "ask: one ask a person for a buff in ten minutes, and one ask in all in two"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario, function(names)
			names.nameplate2 = { "Bram", "Bold" }
		end)
		if not ns then return end
		ns.Prompt:Refresh()
		local first = asking(ns)
		if not first then
			fail(scenario, "SKIPPED -- nobody to ask to begin with")
			restoreUnits()
			return
		end
		ns.Prompt:Refresh()
		local ran = pressButton(ns)
		if type(ran) ~= "string" or not ran:find("^/w " .. first.name) then
			fail(scenario, "SKIPPED -- the press asked nobody: " .. tostring(ran))
			restoreUnits()
			return
		end
		local other = first.name == "Anna Aim" and "Bram Bold" or "Anna Aim"
		-- The other priest has not been asked, and still nobody is for two minutes.
		Mock.advance(60)
		if asking(ns) then fail(scenario, "somebody is asked a minute after the last ask") end
		Mock.advance(61)
		local second = asking(ns)
		if not second then
			fail(scenario, "two minutes on, the other priest is still not asked")
		elseif second.name ~= other then
			fail(scenario, "two minutes on " .. second.name .. " is asked again, for the same buff")
		end
		-- Ask them too; then for ten minutes from each ask, neither is asked again.
		ns.Prompt:Refresh()
		pressButton(ns)
		Mock.advance(121)
		if asking(ns) then
			fail(scenario, "four minutes after the first ask, " .. tostring(asking(ns).name) .. " is asked again")
		end
		Mock.advance(600 - 242 - 5)
		if asking(ns) then fail(scenario, "somebody is asked again inside ten minutes") end
		Mock.advance(10)
		local again = asking(ns)
		if not again then
			fail(scenario, "ten minutes after the first ask, nobody is asked again")
		elseif again.name ~= first.name then
			fail(scenario, "ten minutes after the first ask it is " .. again.name .. " who is asked, inside their own ten")
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 4
-- Never in a fight: not offered, not armed, and nothing frozen on the button.
do
	local scenario = "ask: nobody is asked in a fight, and the pull leaves no ask on the button"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		local armed = button:GetAttribute("macrotext1")
		if type(armed) ~= "string" or not armed:find("^/w ") then
			fail(scenario, "SKIPPED -- no ask armed before the fight: " .. tostring(armed))
			restoreUnits()
			return
		end
		-- The pull, as the client delivers it: the event first, the lockdown after.
		ns.addon:PLAYER_REGEN_DISABLED()
		local frozen = button:GetAttribute("macrotext1")
		if frozen ~= nil then
			fail(scenario, "the fight froze |" .. tostring(frozen) .. "| on the button: a press in it would whisper")
		end
		Mock.inCombat = true
		Mock.runTimers(0.1)
		if asking(ns) then fail(scenario, "somebody is asked in a fight") end
		if ns.Prompt.lib.FightMacro(ns.Ask.Find and { ask = true, buff = { key = "ask:fortitude" }, name = "Anna Aim" }) ~= nil then
			fail(scenario, "the fight's rota would hold an ask")
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		-- And while the game says you are in combat with no lockdown yet.
		rawset(_G, "UnitAffectingCombat", function(unit) return unit == "player" end)
		if asking(ns) then fail(scenario, "somebody is asked while you are in combat") end
		rawset(_G, "UnitAffectingCombat", function() return false end)
		if not asking(ns) then fail(scenario, "after the fight nobody is asked any more") end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 5
do
	local scenario = "ask: nobody is asked in a battleground or an arena"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		if not asking(ns) then
			fail(scenario, "SKIPPED -- nobody to ask out in the world")
			restoreUnits()
			return
		end
		for _, kind in ipairs({ "pvp", "arena" }) do
			rawset(_G, "IsInInstance", function() return true, kind end)
			if asking(ns) then fail(scenario, "somebody is asked in an instance of the kind " .. kind) end
		end
		-- A dungeon is neither.
		rawset(_G, "IsInInstance", function() return true, "party" end)
		if not asking(ns) then fail(scenario, "nobody is asked in a dungeon, which is no battleground") end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 6
do
	local scenario = "ask: nobody is asked in a city or an inn until that is ticked"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		if ns.defaults.profile.ask.inTowns ~= false then fail(scenario, "ask.inTowns is on out of the box") end
		if not asking(ns) then
			fail(scenario, "SKIPPED -- nobody to ask out in the world")
			restoreUnits()
			return
		end
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		if type(button:GetAttribute("macrotext1")) ~= "string" then
			fail(scenario, "SKIPPED -- no ask armed out in the world")
		end
		rawset(_G, "IsResting", function() return true end)
		if asking(ns) then fail(scenario, "somebody is asked while you rest in a city") end
		-- The prompt keeps a name a moment after the queue drops it (the fuse):
		-- the line does not stay armed under it.
		ns.Prompt:Refresh()
		local kept = button:GetAttribute("macrotext1")
		if kept ~= nil then
			fail(scenario, "walking into a city left |" .. tostring(kept) .. "| armed on the button")
		end
		ns.db.profile.ask.inTowns = true
		if not asking(ns) then fail(scenario, "with Ask in cities and inns too ticked, nobody is asked there") end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 7
-- Who is never asked.
do
	local scenario = "ask: nobody on the never-offer list or the ignore list, dead, fighting or away is asked"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		if not asking(ns) then
			fail(scenario, "SKIPPED -- nobody to ask to begin with")
			restoreUnits()
			return
		end
		-- The never-offer list.
		ns.NeverOffer("Anna Aim")
		if asking(ns) then fail(scenario, "somebody on the never-offer list is asked") end
		ns.AllowAgain("Anna Aim")
		if not asking(ns) then fail(scenario, "SKIPPED -- off the list again she is still not asked") end
		-- The game's ignore list.
		rawset(_G, "C_FriendList", {
			IsIgnored = function(unit) return unit == "nameplate1" end,
			GetNumIgnores = function() return 1 end,
		})
		if asking(ns) then fail(scenario, "somebody on the ignore list is asked") end
		rawset(_G, "C_FriendList", original.C_FriendList)
		-- Dead.
		local alive = UnitIsDeadOrGhost
		rawset(_G, "UnitIsDeadOrGhost", function(unit)
			if unit == "nameplate1" then return true end
			return alive(unit)
		end)
		if asking(ns) then fail(scenario, "somebody dead is asked") end
		rawset(_G, "UnitIsDeadOrGhost", alive)
		-- In a fight of their own.
		rawset(_G, "UnitAffectingCombat", function(unit) return unit == "nameplate1" end)
		if asking(ns) then fail(scenario, "somebody in a fight is asked") end
		rawset(_G, "UnitAffectingCombat", function() return false end)
		-- Away, or not to be disturbed.
		rawset(_G, "UnitIsAFK", function(unit) return unit == "nameplate1" end)
		if asking(ns) then fail(scenario, "somebody away is asked") end
		rawset(_G, "UnitIsAFK", nil)
		rawset(_G, "UnitIsDND", function(unit) return unit == "nameplate1" end)
		if asking(ns) then fail(scenario, "somebody who is not to be disturbed is asked") end
		rawset(_G, "UnitIsDND", nil)
		-- A right-click's "not now".
		ns.BlockPerson("Anna Aim", 30)
		if asking(ns) then fail(scenario, "somebody skipped with a right-click is asked") end
		Mock.advance(31)
		if not asking(ns) then fail(scenario, "with every reason gone she is still not asked") end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 8
-- What you would want: not what you wear, not what suits another kind of
-- character, not what the client will not let anybody read.
do
	local scenario = "ask: only for a buff you would want and plainly do not wear"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		local buff = fortitude(ns)
		if not asking(ns) then
			fail(scenario, "SKIPPED -- nobody to ask to begin with")
			restoreUnits()
			return
		end
		-- Worn: a rank of it, then the group version.
		Mock.playerHeld = { [buff.ranks[#buff.ranks]] = true }
		ns.Ask.ForgetWorn()
		if asking(ns) then fail(scenario, "asked for a Fortitude you already wear") end
		Mock.playerHeld = { [buff.group[1]] = true }
		ns.Ask.ForgetWorn()
		if asking(ns) then fail(scenario, "asked for Fortitude under a Prayer of Fortitude") end
		-- A reading the client will not give is no reason to ask.
		Mock.playerHeld = {}
		Mock.auraReadRefuse = { [buff.ranks[1]] = "secret" }
		ns.Ask.ForgetWorn()
		if asking(ns) then fail(scenario, "asked on a reading the client would not give") end
		Mock.auraReadRefuse = nil
		ns.Ask.ForgetWorn()
		local entry = asking(ns)
		if not entry then
			fail(scenario, "with nothing worn and everything readable, nobody is asked")
		elseif entry.buff.wanted.talent or entry.buff.wanted.optIn then
			fail(scenario, "asked for " .. tostring(entry.buff.wanted.key) .. ", which not every priest has or hands out")
		end
		-- A mage's Intellect is nothing to a warrior, who has no mana.
		Mock.unitClass = "MAGE"
		if asking(ns) then
			fail(scenario, "a warrior asks a mage for " .. tostring(asking(ns).buff.wanted.key))
		end
		-- Nor is your own class asked for what you could give yourself.
		Mock.unitClass = "WARRIOR"
		if asking(ns) then fail(scenario, "a warrior is asked by a warrior") end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- ---------------------------------------------------------------------- 9
-- Somebody with mana wants what mana is for, and a paladin is asked for the
-- one blessing that suits you.
do
	local scenario = "ask: a mage asks a paladin for Wisdom, never Might"
	with(scenario, {}, function()
		Mock.reset()
		Mock.class = "MAGE"
		Mock.unitClass = "PALADIN"
		Mock.playerHeld = {}
		-- Everybody else wears Intellect, so nobody is offered one and the
		-- queue holds only you and the ask.
		Mock.held = { [1459] = true, [10157] = true }
		local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then
			restoreUnits()
			return
		end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.ask = true
		ns.db.profile.sources.self = false
		local entry = asking(ns)
		if not entry then
			fail(scenario, "a paladin stands beside a mage with no blessing, and is not asked")
		elseif entry.buff.wanted.key ~= "wisdom" then
			fail(scenario, "a mage asks a paladin for " .. tostring(entry.buff.wanted.key))
		end
		-- With any blessing of theirs on you, there is nothing more one paladin gives.
		local might = ns.FindBuff("PALADIN", "might")
		Mock.playerHeld = { [might.ranks[1]] = true }
		ns.Ask.ForgetWorn()
		if asking(ns) then fail(scenario, "a second blessing is asked for over the one worn") end
		-- Nor is another mage asked for the Intellect this one casts himself.
		Mock.playerHeld = {}
		Mock.unitClass = "MAGE"
		ns.Ask.ForgetWorn()
		local own = asking(ns)
		if own then fail(scenario, "a mage asks a mage for " .. tostring(own.buff.wanted.key)) end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- A talent not every priest has, and a buff its owner hands out only once it
-- is switched on, are nothing to ask a stranger for.
do
	local scenario = "ask: never for a talent, or for a buff handed out only on request"
	-- Level 60: on a client whose casts land only within ten levels of their
	-- rank, the mock's level 12 is out of reach of both spells whatever else
	-- is decided, and the scenario would be about nothing.
	with(scenario, { UnitLevel = function() return 60 end }, function()
		Mock.reset()
		-- Classic Era, where Divine Spirit is a talent (WoW Forever trains it).
		Mock.setFlavour("vanilla")
		Mock.class = "MAGE"
		Mock.unitClass = "PRIEST"
		Mock.playerHeld = {}
		-- Everybody else wears Intellect, so nobody is offered one.
		Mock.held = { [1459] = true, [10157] = true }
		local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then
			restoreUnits()
			return
		end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.ask = true
		ns.db.profile.sources.self = false
		local first = asking(ns)
		if not (first and first.buff.wanted.key == "fortitude") then
			fail(scenario, "SKIPPED -- a mage with nothing on is not asking a priest for Fortitude: "
				.. tostring(first and first.buff.wanted.key))
		end
		-- With Fortitude on, what a priest has left is Divine Spirit (a talent
		-- here) and Shadow Protection (off until its owner switches it on).
		local fort = ns.FindBuff("PRIEST", "fortitude")
		local spirit, shadow = ns.FindBuff("PRIEST", "spirit"), ns.FindBuff("PRIEST", "shadow")
		if not (spirit and spirit.talent and shadow and shadow.optIn) then
			fail(scenario, "SKIPPED -- Divine Spirit is no talent, or Shadow Protection is on for everybody, on this client")
		end
		Mock.playerHeld = { [fort.ranks[1]] = true }
		ns.Ask.ForgetWorn()
		local entry = asking(ns)
		if entry then fail(scenario, "asked a priest for " .. tostring(entry.buff.wanted.key)) end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- A string pasted from somebody else never switches on talking to other
-- players: asking stays as the player had it, and the import says so.
do
	local scenario = "ask: a pasted settings string never switches asking on"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		local db = ns.db.profile
		db.sources.ask = true
		local text = ns.ExportSettings()
		db.sources.ask = false
		local ok, message = ns.ImportSettings(text)
		message = tostring(message)
		if not ok then
			fail(scenario, "SKIPPED -- a string with asking on was refused: " .. message)
		elseif db.sources.ask ~= false then
			fail(scenario, "an imported string switched on asking other players for buffs")
		elseif not message:find(ns.L["The string had asking people for a buff switched on. That is left off, because it talks to other players: switch it on under Who to buff if you want it."], 1, true) then
			fail(scenario, "the import left asking off without saying so: " .. message)
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- --------------------------------------------------------------------- 10
-- Last of everything on the prompt, and never somebody who has a buff coming.
do
	local scenario = "ask: an ask ranks after everything else on the prompt"
	with(scenario, {}, function()
		Mock.reset()
		Mock.class = "MAGE"
		Mock.unitClass = "PRIEST"
		Mock.playerHeld = {}
		local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bram", "Bold" } })
		local ns = load(scenario)
		if not ns then
			restoreUnits()
			return
		end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.ask = true
		-- Both priests lack your Intellect: they are offered it, and nobody
		-- with a buff coming is asked for one.
		local queue = ns.BuildQueue()
		if #queue < 2 then fail(scenario, "SKIPPED -- the two priests are not offered Intellect") end
		for _, entry in ipairs(queue) do
			if entry.ask then fail(scenario, entry.name .. " is asked while your own buff is on offer to them") end
		end
		-- Now they wear it: only your own buff is left, and the ask after it.
		Mock.held = { [1459] = true }
		ns.ForgetAuraCache()
		queue = ns.BuildQueue()
		local last = queue[#queue]
		if not (last and last.ask) then
			fail(scenario, "with nobody left to buff, no ask is at the end of the queue")
		else
			for i = 1, #queue - 1 do
				if queue[i].ask then fail(scenario, "two asks in one queue") end
				if not (queue[i].priority < last.priority) then
					fail(scenario, ("the ask (%s) does not rank after %s (%s)"):format(tostring(last.priority),
						tostring(queue[i].reason), tostring(queue[i].priority)))
				end
			end
			if #queue < 2 then fail(scenario, "SKIPPED -- nothing else in the queue to rank the ask after") end
			ns.Prompt:Refresh()
			local top = ns.Prompt:Showing()
			if top and top.ask then fail(scenario, "the ask is on the prompt ahead of your own buff") end
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- --------------------------------------------------------------------- 11
do
	local scenario = "ask: /say as a choice, and each of the three lines"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		local db = ns.db.profile
		local _, spell = fortitude(ns)
		if #ns.Ask.LINE_ORDER ~= 3 then fail(scenario, #ns.Ask.LINE_ORDER .. " plain lines to choose from, not three") end
		local seen = {}
		for _, key in ipairs(ns.Ask.LINE_ORDER) do
			local template = ns.Ask.LINES[key]
			if type(template) ~= "string" or seen[template] then
				fail(scenario, "the line " .. tostring(key) .. " is missing or written twice")
			elseif not (template:find("{name}", 1, true) and template:find("{buff}", 1, true)) then
				fail(scenario, "the line " .. key .. " does not name them and the buff: " .. template)
			else
				seen[template] = true
				db.ask.line = key
				db.ask.channel = "WHISPER"
				ns.Prompt:InvalidateMacro()
				local entry = asking(ns)
				local macro = entry and ns.Ask.MacroFor(entry)
				local want = "/w Anna Aim " .. lineFor(ns, template, "Anna Aim", spell)
				if macro ~= want then fail(scenario, key .. ": |" .. tostring(macro) .. "|, not |" .. want .. "|") end
				db.ask.channel = "SAY"
				macro = entry and ns.Ask.MacroFor(entry)
				want = "/say " .. lineFor(ns, template, "Anna Aim", spell)
				if macro ~= want then fail(scenario, key .. " in /say: |" .. tostring(macro) .. "|, not |" .. want .. "|") end
			end
		end
		if ns.defaults.profile.ask.channel ~= "WHISPER" then
			fail(scenario, "an ask goes out in " .. tostring(ns.defaults.profile.ask.channel) .. " out of the box, not a whisper")
		end
		-- A choice no setting offers is put right at load.
		db.ask.channel, db.ask.line = "YELL", "shout"
		ns.ClampSettings()
		if db.ask.channel ~= "WHISPER" or db.ask.line ~= "moment" then
			fail(scenario, ("a damaged choice was left as %s / %s"):format(tostring(db.ask.channel), tostring(db.ask.line)))
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- --------------------------------------------------------------------- 12
-- The In character lines: a pool of this file's own, held to that set's rules.
do
	local scenario = "ask: with the In character set on, a line from its own pool, short and safe in a macro"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		local pool = ns.Ask.POOL
		if type(pool) ~= "table" or #pool < 5 then
			fail(scenario, (type(pool) == "table" and #pool or 0) .. " lines in the pool, fewer than five")
			restoreUnits()
			return
		end
		local words = {}
		for _, text in ipairs(pool) do
			local said = text:gsub("{name}", "Bartholomewz"):gsub("{buff}", "Power Word: Fortitude")
			if #said > 85 then fail(scenario, #said .. " bytes: " .. said) end
			if text:find("[|%[%]\r\n]") or text:find("^%s*/") then fail(scenario, "not safe in a macro: " .. text) end
			local bare = text:gsub("{name}", ""):gsub("{buff}", "")
			if bare:find("[{}]") then fail(scenario, "a token nothing fills: " .. text) end
			if bare:lower():find("buff", 1, true) then fail(scenario, "says \"buff\" out of character: " .. text) end
			if not text:find("{buff}", 1, true) then fail(scenario, "does not say what is asked for: " .. text) end
			local letters = text:gsub("{%a+}", ""):lower():gsub("[^%a]", "")
			if words[letters] then fail(scenario, "written twice: " .. text) end
			words[letters] = true
		end
		-- The set chosen on What I say: the line said is one of the pool's.
		local db = ns.db.profile
		db.speech.presetChoice = "incharacter"
		db.speech.phrases = ns.PhraseSetText("incharacter")
		if not ns.InCharacter.Active(db.speech) then
			fail(scenario, "SKIPPED -- the In character set is not what speaks")
			restoreUnits()
			return
		end
		local _, spell = fortitude(ns)
		local filled = {}
		for _, text in ipairs(pool) do filled["/w Anna Aim " .. lineFor(ns, text, "Anna Aim", spell)] = true end
		-- One line for this person, kept from repaint to repaint: what the
		-- tooltip quotes is what the press says.
		local lines, count = {}, 0
		for _ = 1, 20 do
			ns.Prompt:InvalidateMacro()
			ns.Prompt:Refresh()
			local now = ns.Prompt:GetButton():GetAttribute("macrotext1")
			if now and not lines[now] then
				lines[now] = true
				count = count + 1
			end
		end
		if count ~= 1 then fail(scenario, count .. " different lines armed for one person over twenty repaints") end
		local quoted = ns.Prompt:GetButton():GetAttribute("macrotext1")
		local ran = pressButton(ns)
		if not filled[ran] then fail(scenario, "the press ran |" .. tostring(ran) .. "|, no line of the pool") end
		if quoted ~= ran then
			fail(scenario, "the line armed (|" .. tostring(quoted) .. "|) is not the line the press said")
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- --------------------------------------------------------------------- 13
-- A whisper needs a name the chat box reads as theirs: on WoW Forever a name
-- is two words, and "/w Petra Could I have..." goes to Petra Could.
do
	local scenario = "ask: nobody whose whisper the chat box would send to somebody else"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario, function()
			return { nameplate1 = { "Petra" } }
		end)
		if not ns then return end
		if ns.UnitFullName("nameplate1") ~= "Petra" then
			fail(scenario, "SKIPPED -- the one-word name is filed as " .. tostring(ns.UnitFullName("nameplate1")))
		end
		if asking(ns) then
			fail(scenario, "asked by a whisper the chat box reads as going to \"Petra Could\"")
		end
		-- /say names nobody on its command, so she can be asked aloud.
		ns.db.profile.ask.channel = "SAY"
		local entry = asking(ns)
		if not entry then
			fail(scenario, "in /say, where no name is on the command, she is still not asked")
		else
			local macro = ns.Ask.MacroFor(entry)
			if type(macro) ~= "string" or not macro:find("^/say ") then
				fail(scenario, "in /say the macro is |" .. tostring(macro) .. "|")
			end
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- --------------------------------------------------------------------- 14
-- A class with nothing to give: the prompt, the first run and Start here.
do
	local scenario = "ask: a class with nothing to give has a prompt for it, and is shown the switch on Start here"
	with(scenario, {}, function()
		-- A rogue: on WoW Forever a class with no buff for anybody else.
		local ns, restoreUnits = ready(scenario, function() Mock.class = "ROGUE" end)
		if not ns then return end
		local db = ns.db.profile
		if not (ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS.ROGUE) then
			fail(scenario, "SKIPPED -- a rogue has a buff for other players on this client")
		end
		local start = findOption(ns.optionsTable, "startAsk")
		local page = H.placedOn(ns, "general.startAsk")
		if not start then
			fail(scenario, "Start here has no switch for asking")
		else
			if start.hidden() then fail(scenario, "the switch is hidden from a rogue on Start here") end
			if page ~= "general" then fail(scenario, "the switch is drawn on " .. tostring(page) .. ", not Start here") end
			db.sources.ask = false
			if start.get() ~= false then fail(scenario, "Start here's switch reads on while asking is off") end
			if ns.CanCastAnything() or ns.OptionsPage.HasPrompt() then
				fail(scenario, "SKIPPED -- a rogue has a prompt with asking off")
			end
			start.set(nil, true)
			if db.sources.ask ~= true then fail(scenario, "Start here's switch did not turn asking on") end
		end
		if not ns.CanCastAnything() then fail(scenario, "with asking on a rogue still has no prompt at all") end
		if not ns.OptionsPage.HasPrompt() then fail(scenario, "with asking on, Start here still has no steps about the prompt") end
		ns.Prompt:Refresh()
		if not ns.Prompt:GetButton():IsShown() then fail(scenario, "the prompt does not come up for a rogue with somebody to ask") end
		local showing = ns.Prompt:Showing()
		if not (showing and showing.ask) then fail(scenario, "the prompt is not on the person to ask") end
		-- What I say has the switch and how it is said, for this class too.
		for _, key in ipairs({ "ask", "askChannel", "askLine", "askInTowns" }) do
			local control = findOption(ns.optionsTable, key)
			if not control then
				fail(scenario, "Who to buff has no control " .. key)
			elseif type(control.hidden) == "function" and control.hidden() then
				fail(scenario, key .. " is hidden from a rogue with asking on")
			end
			local page, section = H.placedOn(ns, "who." .. key)
			if page ~= "click" or not (section and section.key == "click.asking") then
				fail(scenario, "who." .. key .. " is not drawn on What I say, under Asking for a buff")
			end
		end
		local who = ns.optionsTable.args.who
		if who and type(who.hidden) == "function" and who.hidden() then
			fail(scenario, "Who to buff is hidden from a rogue with asking on")
		end
		-- The first run says what it can do for such a class, with asking off.
		db.sources.ask = false
		Mock.printed = {}
		ns.db.char.welcomed = nil
		ns.Welcome(true)
		local said = table.concat(Mock.printed, "\n")
		if not said:find(ns.L["Ask people for a buff I'm missing"], 1, true) then
			fail(scenario, "the greeting for a class with nothing to give does not name the switch: " .. said)
		end
		-- A mage is not shown the Start here switch: Who to buff has it.
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

do
	local scenario = "ask: a class with buffs to give finds the switch on Who to buff alone"
	with(scenario, {}, function()
		Mock.reset()
		Mock.class = "MAGE"
		Mock.playerHeld = {}
		local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then
			restoreUnits()
			return
		end
		freshPrompt(ns, scenario)
		local start = findOption(ns.optionsTable, "startAsk")
		if start and not start.hidden() then fail(scenario, "a mage is shown the switch on Start here as well") end
		local ask = findOption(ns.optionsTable, "ask")
		if not ask then
			fail(scenario, "Who to buff has no switch for asking")
		else
			if type(ask.hidden) == "function" and ask.hidden() then fail(scenario, "the switch is hidden from a mage") end
			if ask.get() ~= false then fail(scenario, "the switch reads on out of the box") end
			for _, key in ipairs({ "askChannel", "askLine", "askInTowns" }) do
				local control = findOption(ns.optionsTable, key)
				if control and not control.hidden() then fail(scenario, key .. " is shown while asking is off") end
			end
			ask.set(nil, true)
			if ns.db.profile.sources.ask ~= true then fail(scenario, "the switch did not turn asking on") end
		end
		-- And the page's reset puts every one of them back.
		local reset = ns.OptionsPage.RESET and ns.OptionsPage.RESET.click or {}
		local listed = {}
		for _, path in ipairs(reset) do listed[path] = true end
		for _, path in ipairs({ "sources.ask", "ask.channel", "ask.line", "ask.inTowns" }) do
			if not listed[path] then fail(scenario, "What I say's reset leaves " .. path .. " as it is") end
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- --------------------------------------------------------------------- 15
do
	local scenario = "ask: /manners debug says whether anybody is asked, and what holds it back"
	with(scenario, {}, function()
		local ns, restoreUnits = ready(scenario)
		if not ns then return end
		local L = ns.L
		local function line() return table.concat(ns.AskLines(GetTime()), "\n") end
		local function has(text, what)
			local head = text:match("^(.-)%%s") or text
			if not line():find(head, 1, true) then
				fail(scenario, what .. ": the lines read |" .. line() .. "|")
			end
		end
		has(L["asking for buffs: |cffffffff%s|r can be asked for %s."], "with somebody to ask")
		ns.db.profile.sources.ask = false
		has(L["asking for buffs: off -- %s is not ticked."], "switched off")
		ns.db.profile.sources.ask = true
		rawset(_G, "IsResting", function() return true end)
		has(L["asking for buffs: held back in a city or an inn -- tick %s to ask there too."], "in a city")
		rawset(_G, "IsResting", function() return false end)
		rawset(_G, "IsInInstance", function() return true, "pvp" end)
		has(L["asking for buffs: held back -- nobody is asked in a battleground or an arena."], "in a battleground")
		rawset(_G, "IsInInstance", original.IsInInstance)
		rawset(_G, "UnitAffectingCombat", function(unit) return unit == "player" end)
		has(L["asking for buffs: held back -- nobody is asked in a fight."], "in a fight")
		rawset(_G, "UnitAffectingCombat", function() return false end)
		ns.Prompt:Refresh()
		pressButton(ns)
		has(L["asking for buffs: held back -- you asked somebody %s ago, and one ask in two minutes is the most."], "just after an ask")
		has(L["asked |cffffffff%s|r %s ago -- not again for the same buff for ten minutes."], "just after an ask")
		-- And /manners debug prints them.
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		if not said:find((L["asking for buffs: held back -- you asked somebody %s ago, and one ask in two minutes is the most."]:match("^(.-)%%s")), 1, true) then
			fail(scenario, "/manners debug does not say why nobody is asked")
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end

-- --------------------------------------------------------------------- 16
-- A member of your group is asked as a passer-by is, and what the tooltip says.
do
	local scenario = "ask: somebody in your group is asked, and the tooltip says what the press will say"
	with(scenario, {}, function()
		Mock.reset()
		Mock.class = "WARRIOR"
		Mock.unitClass = "PRIEST"
		Mock.playerHeld = {}
		Mock.groupSize = 2
		local restoreUnits = strangers({ party1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then
			restoreUnits()
			return
		end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.ask = true
		local entry = asking(ns)
		if not entry then
			fail(scenario, "a priest in the party is not asked")
			restoreUnits()
			return
		end
		if entry.unit ~= "party1" or entry.inGroup ~= true then
			fail(scenario, ("found as %s, in the group: %s"):format(tostring(entry.unit), tostring(entry.inGroup)))
		end
		-- Out of reach of a cast on you, by the game's own word: left alone.
		rawset(_G, "UnitInRange", function() return false, true end)
		if asking(ns) then fail(scenario, "a party member out of range is asked") end
		rawset(_G, "UnitInRange", function() return true, false end)
		if asking(ns) then fail(scenario, "a party member with an unchecked range is asked") end
		rawset(_G, "UnitInRange", QUIET.UnitInRange)
		ns.Prompt:Refresh()
		local macro = ns.Prompt:GetButton():GetAttribute("macrotext1")
		local lines = ns.Prompt:ClickSummary(ns.Prompt:Showing() or entry)
		local text = table.concat(lines, "\n")
		local said = type(macro) == "string" and macro:match("^/w Anna Aim (.+)$")
		if not said then
			fail(scenario, "the button holds |" .. tostring(macro) .. "|")
		elseif not text:find(said, 1, true) then
			fail(scenario, "the tooltip (|" .. text .. "|) does not quote the line the press says")
		end
		if text:find(ns.L["Hands your own target back afterwards."], 1, true) then
			fail(scenario, "the tooltip speaks of a target the press never takes")
		end
		noErrors(scenario, ns)
		restoreUnits()
	end)
end
