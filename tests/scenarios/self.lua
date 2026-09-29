-- Buff myself (1.2.0): "Myself, when I'm missing my own buff" puts you on the
-- prompt when you are missing one of your own buffs, or with top-ups on it is
-- running low. Queue.lua's SelfEntry makes the offer, Prompt.lua casts it with
-- /cast [@player] and nothing said, Clicks.lua settles it with nothing filed,
-- and GroupBuffs.lua counts you into your party's group cast.
--
-- Every scenario name starts with "self:" so the mutations in
-- tests/mutations/self.py can name the one that has to catch them.
--
-- The shared mock dresses the player in every buff of their own
-- (Mock.playerHeld nil), which is what keeps you off every other file's
-- prompt. Here you start wearing nothing unless a scenario says otherwise.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, findOption = H.strangers, H.freshPrompt, H.owe, H.findOption

-- The mock's player on Camelot, where the surname is joined with a space; on
-- the other clients the mock hands over no second name at all.
local ME = "Mort Defrette"

-- Arcane Intellect in every rank, and Arcane Brilliance.
local INTELLECT = { 10157, 10156, 1461, 1460, 1459 }
local BRILLIANCE = 23028
local ARCANE_POWDER = 17020

local function said() return table.concat(Mock.printed, "\n") end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Your own entry in the queue as it stands, or nil.
local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function names(queue)
	local out = {}
	for _, entry in ipairs(queue) do out[#out + 1] = tostring(entry.name) end
	return table.concat(out, ", ")
end

local function hover(ns)
	local button = ns.Prompt:GetButton()
	Mock.tooltip = {}
	if button.scripts.OnEnter then button.scripts.OnEnter(button) end
	return table.concat(Mock.tooltip or {}, " / ")
end

-- What you are wearing of your own, read again at once rather than after the
-- three seconds the aura cache keeps an answer.
local function wear(ns, ids)
	Mock.playerHeld = ids
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "DoEmote", "IsShiftKeyDown",
	"GetItemCount", "GetItemInfo", "C_UnitAuras", "MenuUtil", "UnitPower", "UnitPowerMax" }

-- One scenario: nobody else about (the target, focus, mouseover and nameplates
-- hold only the people `opts.people` names), the lifecycle driven, and you
-- wearing nothing of your own unless `opts.wearing` says what. body(ns) runs
-- and everything is put back, whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.class then Mock.class = opts.class end
	if opts.groupSize then Mock.groupSize = opts.groupSize end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	if opts.known then
		local known = {}
		for _, id in ipairs(opts.known) do known[id] = true end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
	end
	local undo = strangers(opts.people or {})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if opts.before then opts.before(ns) end
		freshPrompt(ns, scenario)
		wear(ns, opts.wearing or {})
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Everybody's auras by token, over the mock's: `held[unit]` is the set of ids
-- that unit wears. You stay the mock's (Mock.playerHeld).
local function auras(held)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit == "player" then return base.GetUnitAuraBySpellID(unit, spellId) end
			if held[unit] and held[unit][spellId] then
				return { spellId = spellId, expirationTime = Mock.now + 3600, sourceUnit = "player" }
			end
			return nil
		end,
	}, { __index = base }))
end

-- Arcane Powder in the bags, for Arcane Brilliance.
local function powder(count)
	GetItemCount = function(id) return id == ARCANE_POWDER and count or 0 end
	GetItemInfo = function(id) return id == ARCANE_POWDER and "Arcane Powder" or nil end
end

local function set(...)
	local out = {}
	for i = 1, select("#", ...) do out[select(i, ...)] = true end
	return out
end

-- ------------------------------------------------------------------ self 1
-- A mage without their own Intellect is offered it: on the prompt as "You",
-- the reason line saying whose it is, the tooltip saying why and what a press
-- does -- which is not "Targets Mort".
Mock.reset()
do
	local scenario = "self: a mage missing their own Intellect is offered it"
	with(scenario, {}, function(ns)
		local queue = ns.BuildQueue()
		local me = queue[1]
		if #queue ~= 1 or not me then
			fail(scenario, "you were not offered your own Intellect: " .. names(queue))
			return
		end
		if me.reason ~= "self" or me.name ~= ME or me.unit ~= "player" then
			fail(scenario, ("offered as %s, %s, %s"):format(tostring(me.reason), tostring(me.name),
				tostring(me.unit)))
		end
		if me.ranged ~= true or me.known ~= false or me.checked ~= true then
			fail(scenario, ("ranged %s, known %s, checked %s"):format(tostring(me.ranged),
				tostring(me.known), tostring(me.checked)))
		end
		if not (me.buff and me.buff.key == "intellect") then
			fail(scenario, "offered " .. tostring(me.buff and me.buff.key))
		end
		ns.Prompt:Refresh()
		if not ns.Prompt:GetButton():IsShown() then
			fail(scenario, "the prompt did not come up for you")
		end
		local first = ns.Prompt:RenderPrimary(me, 0)
		if not first:find("You", 1, true) or first:find("Mort", 1, true) then
			fail(scenario, "the first line does not say You: " .. first)
		end
		local reason = ns.Prompt:ReasonText(me)
		if reason ~= "your own Arcane Intellect" then
			fail(scenario, "the reason line reads " .. tostring(reason))
		end
		local tip = hover(ns)
		if not tip:find("Your own buff, and you are missing it.", 1, true) then
			fail(scenario, "the tooltip does not say it is your own and missing: " .. tip)
		end
		if not tip:find("Casts |cffffffffArcane Intellect|r on you.", 1, true) or tip:find("Targets", 1, true) then
			fail(scenario, "the tooltip does not say it is cast on you: " .. tip)
		end
		if not tip:find("Shift-right-click to stop offering you your own buff.", 1, true) then
			fail(scenario, "the tooltip does not say what shift-right-click does to you: " .. tip)
		end
	end)
end

-- ------------------------------------------------------------------ self 2
-- Nothing while you wear it, and nothing on a reading the client withheld:
-- a guess about yourself would come back every retry cooldown, and your own
-- buff bar says it better. "Always offer" is about other people.
Mock.reset()
do
	local scenario = "self: nothing for you while you wear it or nothing can tell"
	with(scenario, { wearing = set(1459) }, function(ns)
		local me = mine(ns)
		if me then fail(scenario, "offered your own Intellect while you wear it") end
		ns.db.profile.filters.whenBuffed = "always"
		wear(ns, set(1459))
		if mine(ns) then fail(scenario, "Always offer offered you the Intellect you wear") end
		ns.db.profile.filters.whenBuffed = "skip"

		wear(ns, {})
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered even with nothing on")
			return
		end
		Mock.auraReadRefuse = {}
		for _, id in ipairs(INTELLECT) do Mock.auraReadRefuse[id] = "secret" end
		Mock.auraReadRefuse[BRILLIANCE] = "secret"
		wear(ns, {})
		local guessed = mine(ns)
		if guessed then
			fail(scenario, "offered on a reading the client withheld (known "
				.. tostring(guessed.known) .. ")")
		end
		Mock.auraReadRefuse = nil
	end)
end

-- ------------------------------------------------------------------ self 3
-- A top-up follows "When they already have it": two minutes left is nothing
-- with skip, and your own top-up with refresh, worded as one.
Mock.reset()
do
	local scenario = "self: a top-up follows When they already have it"
	with(scenario, { wearing = set(1459) }, function(ns)
		Mock.playerHeldFor = 120
		wear(ns, set(1459))
		if mine(ns) then fail(scenario, "offered a top-up with top-ups off") end
		ns.db.profile.filters.whenBuffed = "refresh"
		ns.db.profile.filters.refreshUnder = 5
		wear(ns, set(1459))
		local me = mine(ns)
		if not me then
			fail(scenario, "two minutes left and top-ups on, and you were not offered one")
			return
		end
		if me.known ~= true or type(me.remaining) ~= "number" or me.remaining > 120 then
			fail(scenario, ("the top-up reads known %s, remaining %s"):format(tostring(me.known),
				tostring(me.remaining)))
		end
		if ns.Prompt:ReasonText(me) ~= "expires in 2m" then
			fail(scenario, "the top-up's reason line reads " .. tostring(ns.Prompt:ReasonText(me)))
		end
		ns.Prompt:Refresh()
		if not hover(ns):find("Your own buff, and yours is running out.", 1, true) then
			fail(scenario, "the tooltip does not say yours is running out: " .. hover(ns))
		end
		if not hover(ns):find("Yours expires in 2m.", 1, true) then
			fail(scenario, "the tooltip does not say when yours runs out: " .. hover(ns))
		end
		Mock.playerHeldFor = 3000
		wear(ns, set(1459))
		if mine(ns) then fail(scenario, "offered a top-up with fifty minutes left") end
	end)
end

-- ------------------------------------------------------------------ self 4
-- Switched off, you are offered nothing, and /manners debug says which way
-- the switch is.
Mock.reset()
do
	local scenario = "self: switched off, you are offered nothing"
	with(scenario, {}, function(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered with the switch on")
			return
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("your own buff: offered to you when you are missing it.", 1, true) then
			fail(scenario, "/manners debug does not say your own buff is offered: " .. flat(said()))
		end
		ns.db.profile.sources.self = false
		local queue = ns.BuildQueue()
		if #queue > 0 then fail(scenario, "offered with the switch off: " .. names(queue)) end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("your own buff: not offered", 1, true) then
			fail(scenario, "/manners debug does not say the switch is off: " .. flat(said()))
		end
	end)
end

-- ------------------------------------------------------------------ self 5
-- The press casts on you by [@player]: no /target, nothing handed back, and no
-- spoken line whatever the speech settings say -- said, whispered, or only
-- when returning a favour.
Mock.reset()
do
	local scenario = "self: the macro casts on you with no target and nothing said"
	with(scenario, {}, function(ns)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		speech.phrases = "Here you are, {name}."
		ns.db.profile.filters.restoreTarget = true
		local me = mine(ns)
		-- Somebody else would be spoken to with these settings, so the silence
		-- below is about you.
		if not (me and ns.PickPhrase({ name = "Anna Aim", short = "Anna Aim", targetName = "Anna Aim",
			reason = "nearby", buff = me.buff }, 200)) then
			fail(scenario, "SKIPPED -- nobody would be spoken to with these settings")
			return
		end
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		local ran = macro(ns)
		if ran ~= "/cast [@player] Arcane Intellect" then
			fail(scenario, "the macro reads " .. flat(ran))
		end
		speech.channel = "WHISPER"
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		if macro(ns) ~= "/cast [@player] Arcane Intellect" then
			fail(scenario, "whispering on, the macro reads " .. flat(macro(ns)))
		end
		if hover(ns):find("Says:", 1, true) then
			fail(scenario, "the tooltip quotes a line for you: " .. hover(ns))
		end
		local pressed = H.pressButton(ns)
		if pressed ~= "/cast [@player] Arcane Intellect" then
			fail(scenario, "the press ran " .. flat(pressed))
		end
		local pending = ns.pendingClick
		if not (pending and pending.onSelf == true and not pending.targeted) then
			fail(scenario, "the press was not parked as one on yourself")
		end
	end)
end

-- ------------------------------------------------------------------ self 6
-- A press on yourself files nothing: no row in the ledger, no favour, no count
-- towards meeting somebody again, and your own buff landing on you afterwards
-- is no favour to thank anybody for. The panel says you buffed yourself.
Mock.reset()
do
	local scenario = "self: a press on yourself files nothing and thanks nobody"
	local emotes = {}
	with(scenario, {}, function(ns)
		rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = tostring(emote) .. " " .. tostring(target) end)
		ns.db.profile.prompt.thankEmote = true
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		H.primeAuras(ns)
		wear(ns, {})
		ns.Prompt:Refresh()
		local pressed = H.pressButton(ns)
		if not (pressed and pressed:find("[@player]", 1, true) and ns.pendingClick) then
			fail(scenario, "SKIPPED -- the press on yourself did not go out: " .. flat(pressed))
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", ME, "Cast-self-1", 1459)
		local s = ns.db.char.ledger
		if s and #s.entries > 0 then
			fail(scenario, ("the press wrote %d ledger rows, the first a %s row under %s")
				:format(#s.entries, tostring(s.entries[1].kind), tostring(s.entries[1].name)))
		end
		if s and (s.totals.group ~= 0 or s.totals.strangers ~= 0 or s.totals.returned ~= 0) then
			fail(scenario, "the press was counted as a buff given")
		end
		if next(ns.owed) then fail(scenario, "somebody is owed after a press on yourself") end
		if ns.InCharacter and ns.InCharacter.Familiar({ name = ME }) ~= nil then
			fail(scenario, "In character counts you as somebody met again")
		end
		if ns.pendingClick then fail(scenario, "the press was never settled") end
		local lead = tostring(ns.Prompt:Regions().name:GetText())
		if not lead:find("yourself", 1, true) then
			fail(scenario, "the panel reads " .. lead)
		end
		if not ns.IsBlocked(ME, "intellect") then
			fail(scenario, "you were not given the retry cooldown after the press")
		end
		-- Your own Intellect landing on you, from you.
		Mock.printed = {}
		H.favourFrom(ns, "player", 1459, 5101)
		Mock.runTimers(1)
		if #emotes > 0 then fail(scenario, "your own buff was thanked: " .. emotes[1]) end
		if next(ns.owed) then fail(scenario, "your own buff filed a favour from you") end
		s = ns.db.char.ledger
		if s and #s.entries > 0 then
			fail(scenario, "your own buff landing wrote a " .. tostring(s.entries[1].kind) .. " row")
		end
	end)
end

-- ------------------------------------------------------------------ self 7
-- A press on yourself that came to nothing says "you", not your name as if you
-- were somebody else; and a different spell going out is not your buff.
Mock.reset()
do
	local scenario = "self: a failed press on yourself says so"
	with(scenario, {}, function(ns)
		ns.Prompt:Refresh()
		if not (H.pressButton(ns) and ns.pendingClick) then
			fail(scenario, "SKIPPED -- the press did not go out")
			return
		end
		Mock.printed = {}
		ns.addon:UI_ERROR_MESSAGE(nil, 0, "You can't do that yet")
		if not said():find("you were not buffed", 1, true) or said():find("Mort", 1, true) then
			fail(scenario, "the refusal reads " .. flat(said()))
		end
		local lead = tostring(ns.Prompt:Regions().name:GetText())
		if not lead:find("could not buff", 1, true) or not lead:find("yourself", 1, true) then
			fail(scenario, "the panel reads " .. lead)
		end

		Mock.advance(30)
		ns.pendingClick = nil
		wipe(ns.tried)
		wipe(ns.refusals)
		ns.Prompt:Refresh()
		if not (H.pressButton(ns) and ns.pendingClick) then
			fail(scenario, "SKIPPED -- the second press did not go out")
			return
		end
		Mock.printed = {}
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", ME, "Cast-self-2", 116)
		if not said():find("you were not buffed", 1, true) or not said():find("Frostbolt", 1, true) then
			fail(scenario, "a Frostbolt was taken for your buff: " .. flat(said()))
		end
		Mock.advance(3)
		if not mine(ns) then
			fail(scenario, "after a Frostbolt went out instead, you are not offered your buff again")
		end

		-- An error, and then the cast going out after all: the error was about
		-- something else, and the press gets its whole retry cooldown back.
		Mock.advance(30)
		ns.pendingClick = nil
		wipe(ns.tried)
		wipe(ns.refusals)
		ns.Prompt:Refresh()
		if not (H.pressButton(ns) and ns.pendingClick) then
			fail(scenario, "SKIPPED -- the third press did not go out")
			return
		end
		ns.addon:UI_ERROR_MESSAGE(nil, 0, "Your bags are full")
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", ME, "Cast-self-3", 1459)
		Mock.advance(3)
		if not ns.IsBlocked(ME, "intellect") then
			fail(scenario, "a cast that went out after an error left you only its two seconds of cooldown")
		end
	end)
end

-- ------------------------------------------------------------------ self 8
-- A shout already covers the warrior who shouts it, so it is never offered to
-- him alone -- solo, in a party, or pinned -- and the switch is not shown.
Mock.reset()
do
	local scenario = "self: a shout is never offered to yourself"
	local shout = {}
	with(scenario, { class = "WARRIOR", before = function(ns)
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do shout[id] = true end
		IsSpellKnown = function(id) return shout[id] == true end
		IsPlayerSpell = IsSpellKnown
	end }, function(ns)
		if not ns.caps.anyKnown then
			fail(scenario, "SKIPPED -- the shout is not learned")
			return
		end
		if mine(ns) then fail(scenario, "a solo warrior was offered his own shout") end
		Mock.groupSize = 5
		wear(ns, {})
		if mine(ns) then fail(scenario, "a warrior in a party was offered his own shout") end
		ns.db.profile.buff.choice = "battleshout"
		wear(ns, {})
		if mine(ns) then fail(scenario, "a pinned shout was offered to the warrior himself") end
		local toggle = findOption(ns.optionsTable, "self")
		if not (toggle and type(toggle.hidden) == "function" and toggle.hidden()) then
			fail(scenario, "the Myself switch is shown to a warrior")
		end
		if ns.QuickSetup.WhoSummary():find("myself", 1, true) then
			fail(scenario, "the summary promises a warrior his own buff: " .. ns.QuickSetup.WhoSummary())
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("your own buff: nothing you cast goes on yourself alone.", 1, true) then
			fail(scenario, "/manners debug does not say a warrior has nothing for himself")
		end
	end)
end

-- ------------------------------------------------------------------ self 9
-- A spell the game will not put on its caster (an evoker's Source of Magic) is
-- never offered to you, in Automatic or pinned; the one it will is.
Mock.reset()
do
	local scenario = "self: a spell the game keeps off its caster is never offered to you"
	with(scenario, { flavour = "mainline", class = "EVOKER", known = { 364342, 369459 },
		wearing = set(364342) }, function(ns)
		local me = mine(ns)
		if me then
			fail(scenario, "offered " .. tostring(me.buff and me.buff.key) .. " while wearing the Blessing")
		end
		wear(ns, {})
		me = mine(ns)
		if not (me and me.buff.key == "bronze") then
			fail(scenario, "SKIPPED -- the Blessing of the Bronze is not offered to you: "
				.. tostring(me and me.buff.key))
			return
		end
		ns.db.profile.buff.choice = "sourceofmagic"
		wear(ns, {})
		me = mine(ns)
		if me then fail(scenario, "a pinned Source of Magic was offered to the evoker casting it") end
	end)
end

-- ------------------------------------------------------------------ self 10
-- Where you stand: behind a favour owed, ahead of your group.
Mock.reset()
do
	local scenario = "self: behind a favour owed and ahead of your group"
	with(scenario, { groupSize = 3,
		people = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } } }, function(ns)
		ns.db.profile.sources.strangers = false
		owe(ns, "Zed Far")
		local queue = ns.BuildQueue()
		local order = names(queue)
		if #queue ~= 4 then
			fail(scenario, "SKIPPED -- expected a favour, you and two of your group: " .. order)
			return
		end
		if queue[1].name ~= "Zed Far" or queue[2].name ~= ME then
			fail(scenario, "not the favour owed, then you: " .. order)
		end
		if queue[3].reason ~= "group" or queue[4].reason ~= "group" then
			fail(scenario, "your group is not behind you: " .. order)
		end
	end)
end

-- ------------------------------------------------------------------ self 11
-- In a party, you count towards the "at least N missing" of a group cast and
-- it covers you: two of four missing it and you make three. The cast is aimed
-- at one of them, never at you, and a press puts you on its cooldown too.
Mock.reset()
do
	local scenario = "self: you count towards your party's group cast"
	local party = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } }
	with(scenario, { groupSize = 5, people = party, known = { 1459, BRILLIANCE } }, function(ns)
		ns.db.profile.sources.strangers = false
		ns.db.profile.groupBuffs.use, ns.db.profile.groupBuffs.atLeast = true, 3
		powder(20)
		auras({ party1 = set(1459), party2 = set(1459) })
		ns.Guard("probe", ns.ProbeCapabilities)
		wear(ns, {})
		local queue = ns.BuildQueue()
		local group
		for _, entry in ipairs(queue) do
			if entry.groupCast then group = entry end
			if entry.reason == "self" then
				fail(scenario, "you are offered apart from the group cast that covers you")
			end
		end
		if not group then
			fail(scenario, "two of the party and you missing it made no group cast: " .. names(queue))
			return
		end
		if group.groupCast.missing ~= 3 then
			fail(scenario, "the group cast counts " .. tostring(group.groupCast.missing) .. " missing, not 3")
		end
		if group.reason == "self" or group.name == ME then
			fail(scenario, "the group cast is aimed at you")
		end
		local covered = false
		for _, name in ipairs(group.groupCast.members) do
			if name == ME then covered = true end
		end
		if not covered then fail(scenario, "the group cast does not cover you") end

		ns.Prompt:Refresh()
		H.pressButton(ns)
		if not ns.IsBlocked(ME, "intellect") then
			fail(scenario, "a press on the group cast left you to be offered the single buff")
		end

		-- Wearing it yourself, the two of them are one short.
		Mock.advance(60)
		ns.pendingClick = nil
		wipe(ns.tried)
		wear(ns, set(1459))
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then
				fail(scenario, "two missing it made a group cast of three: " .. names(ns.BuildQueue()))
			end
		end
	end)
end

-- ------------------------------------------------------------------ self 11b
-- The same in a raid, where it is your own subgroup the cast reaches, and for
-- a paladin, whose Greater Blessing lands on everybody of your class -- you
-- among them when you are a paladin too.
Mock.reset()
do
	local scenario = "self: you count towards your raid group's and your class's group cast"
	local raid = {}
	for i = 2, 10 do raid["raid" .. i] = { "Raider" .. i, "Stone" } end
	with(scenario, { people = raid, known = { 1459, BRILLIANCE } }, function(ns)
		Mock.raid = { size = 10, player = 1 }
		ns.db.profile.sources.strangers = false
		ns.db.profile.groupBuffs.use, ns.db.profile.groupBuffs.atLeast = true, 3
		powder(20)
		-- Your subgroup is raid1 to raid5: two of the four others missing it,
		-- and the other subgroup all wearing it.
		auras({ raid4 = set(1459), raid5 = set(1459), raid6 = set(1459), raid7 = set(1459),
			raid8 = set(1459), raid9 = set(1459), raid10 = set(1459) })
		ns.Guard("probe", ns.ProbeCapabilities)
		wear(ns, {})
		local group
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then group = entry end
		end
		if not group then
			fail(scenario, "two of your raid group and you missing it made no group cast: "
				.. names(ns.BuildQueue()))
		elseif group.groupCast.missing ~= 3 or group.groupCast.label ~= "your group" then
			fail(scenario, ("the raid's group cast counts %s missing in %s")
				:format(tostring(group.groupCast.missing), tostring(group.groupCast.label)))
		end
		wear(ns, set(1459))
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then fail(scenario, "SKIPPED -- two of the raid group alone made a group cast") end
		end
	end)

	-- A paladin in a party of paladins, knowing Might and its Greater version.
	with(scenario, { class = "PALADIN", groupSize = 5, known = { 19740, 25782 },
		people = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
			party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } } }, function(ns)
		Mock.unitClass = "PALADIN"
		ns.db.profile.sources.strangers = false
		ns.db.profile.groupBuffs.use, ns.db.profile.groupBuffs.atLeast = true, 3
		GetItemCount = function(id) return id == 21177 and 20 or 0 end
		GetItemInfo = function(id) return id == 21177 and "Symbol of Kings" or nil end
		local might = set(unpack(ns.FindBuff("PALADIN", "might").ranks))
		auras({ party3 = might, party4 = might })
		ns.Guard("probe", ns.ProbeCapabilities)
		wear(ns, {})
		local group
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then group = entry end
		end
		if not group then
			fail(scenario, "two paladins and you missing Might made no Greater Blessing: "
				.. names(ns.BuildQueue()))
		elseif group.groupCast.class ~= "PALADIN" or group.groupCast.missing ~= 3 then
			fail(scenario, ("the Greater Blessing is for %s, %s missing")
				:format(tostring(group.groupCast.class), tostring(group.groupCast.missing)))
		end
		wear(ns, might)
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then fail(scenario, "SKIPPED -- two paladins alone made a Greater Blessing") end
		end
	end)
end

-- ------------------------------------------------------------------ self 12
-- A group cast aimed at a favour files its one given row under somebody it
-- covered who was owed nothing -- never under you.
Mock.reset()
do
	local scenario = "self: a group cast never files a gift to you"
	local party = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } }
	with(scenario, { groupSize = 5, people = party, known = { 1459, BRILLIANCE } }, function(ns)
		ns.db.profile.sources.strangers = false
		ns.db.profile.groupBuffs.use, ns.db.profile.groupBuffs.atLeast = true, 3
		powder(20)
		auras({ party2 = set(1459), party3 = set(1459) })
		ns.Guard("probe", ns.ProbeCapabilities)
		owe(ns, "Anna Aim")
		owe(ns, "Dora Deep")
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		wear(ns, {})
		ns.Prompt:Refresh()
		local showing = ns.Prompt:Showing()
		if not (showing and showing.groupCast and showing.name == "Anna Aim") then
			fail(scenario, "SKIPPED -- the group cast is not aimed at Anna: "
				.. tostring(showing and showing.name))
			return
		end
		H.pressButton(ns)
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna Aim", "Cast-group-1", BRILLIANCE)
		local s = ns.db.char.ledger
		for _, e in ipairs(s and s.entries or {}) do
			if e.name == ME then
				fail(scenario, "the ledger filed a " .. tostring(e.kind) .. " row under you")
			end
		end
		if next(ns.owed) then fail(scenario, "SKIPPED -- the favours were not settled") end
	end)
end

-- ------------------------------------------------------------------ self 13
-- Only you in reach: no group cast aimed at you, which would spend a reagent
-- on yourself alone; you are offered the single buff.
Mock.reset()
do
	local scenario = "self: a group cast is never aimed at you"
	local party = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } }
	with(scenario, { groupSize = 5, people = party, known = { 1459, BRILLIANCE } }, function(ns)
		ns.db.profile.sources.strangers = false
		ns.db.profile.filters.requireInRange = false
		ns.db.profile.groupBuffs.use, ns.db.profile.groupBuffs.atLeast = true, 3
		powder(20)
		auras({})
		Mock.rangeByUnit = { party1 = false, party2 = false, party3 = false, party4 = false }
		ns.Guard("probe", ns.ProbeCapabilities)
		wear(ns, {})
		local queue = ns.BuildQueue()
		for _, entry in ipairs(queue) do
			if entry.groupCast then
				fail(scenario, "a group cast was made, aimed at " .. tostring(entry.name))
				return
			end
		end
		if #queue < 5 then
			fail(scenario, "SKIPPED -- the party out of reach is not in the queue: " .. names(queue))
			return
		end
		if not (queue[1] and queue[1].reason == "self") then
			fail(scenario, "you are not offered the single buff first: " .. names(queue))
		end
	end)
end

-- ------------------------------------------------------------------ self 14
-- The saved settings: off stays off, nonsense becomes on, a broken wording is
-- put back, and a settings string carries the switch both ways.
Mock.reset()
do
	local scenario = "self: the saved settings keep the switch and repair it"
	with(scenario, {}, function(ns)
		local profile = ns.db.profile
		profile.sources.self = false
		ns.ClampSettings()
		if profile.sources.self ~= false then fail(scenario, "the repair switched you back on") end
		profile.sources.self = "yes"
		ns.ClampSettings()
		if profile.sources.self ~= true then
			fail(scenario, "a nonsense switch was kept: " .. tostring(profile.sources.self))
		end
		profile.prompt.reasonSelf = 5
		ns.ClampSettings()
		if profile.prompt.reasonSelf ~= "your own {buff}" then
			fail(scenario, "a broken wording was kept: " .. tostring(profile.prompt.reasonSelf))
		end

		profile.sources.self = false
		local text = ns.ExportSettings()
		if not tostring(text):find("sources.self", 1, true) then
			fail(scenario, "a settings string leaves the switch out: " .. tostring(text))
		end
		profile.sources.self = true
		ns.ImportSettings(text)
		if ns.db.profile.sources.self ~= false then
			fail(scenario, "importing a string with the switch off left it on")
		end
	end)
end

-- ------------------------------------------------------------------ self 15
-- The options: the switch on Who to buff with the other sources, the warning
-- that nothing is ticked knowing it counts, the summary on Start here naming
-- you, the reason wording on Advanced (and its reset), and the settings line
-- a bug report carries.
Mock.reset()
do
	local scenario = "self: the options offer the switch and say what it does"
	with(scenario, {}, function(ns)
		local root = ns.optionsTable
		local who = root and root.args.who
		local toggle = findOption(root, "self")
		if not (who and toggle) then
			fail(scenario, "there is no Myself switch on Who to buff")
			return
		end
		local a = who.args
		if not (toggle.order > a.sourcesHeader.order and toggle.order < a.groupHeader.order) then
			fail(scenario, "the switch is not under Offer my buff to")
		end
		if toggle.name ~= "Myself, when I'm missing my own buff" then
			fail(scenario, "the switch reads " .. tostring(toggle.name))
		end
		if toggle.hidden and toggle.hidden() then fail(scenario, "the switch is hidden from a mage") end
		toggle.set({ "self" }, false)
		if ns.db.profile.sources.self ~= false or toggle.get({ "self" }) ~= false then
			fail(scenario, "the switch does not write sources.self")
		end
		toggle.set({ "self" }, true)

		local warning = findOption(root, "emptyWarning")
		local s = ns.db.profile.sources
		s.owed, s.group, s.strangers, s.asked = false, false, false, false
		if warning and not warning.hidden() then
			fail(scenario, "with only yourself on, the page says the prompt will never appear")
		end
		s.self = false
		if warning and warning.hidden() then
			fail(scenario, "SKIPPED -- the warning stays hidden with everything off")
		end
		s.owed, s.group, s.strangers, s.self = true, true, true, true

		local summary = ns.QuickSetup.WhoSummary()
		if not summary:find(", myself (outside cities and inns).", 1, true) then
			fail(scenario, "the summary on Start here leaves you out: " .. summary)
		end
		-- Also in cities and inns ticked, you are offered everywhere.
		ns.db.profile.ownBuffs.inCities = true
		if not ns.QuickSetup.WhoSummary():find(", myself.", 1, true) then
			fail(scenario, "with Also in cities and inns ticked the summary reads " .. ns.QuickSetup.WhoSummary())
		end
		ns.db.profile.ownBuffs.inCities = false
		s.self = false
		if ns.QuickSetup.WhoSummary():find("myself", 1, true) then
			fail(scenario, "the summary names you with the switch off")
		end
		s.self = true

		local wording = findOption(root, "reasonSelf")
		if not (wording and wording.set) then
			fail(scenario, "there is no wording for your own buff on Advanced")
		else
			wording.set({ "reasonSelf" }, "mine: {buff}")
			if ns.db.profile.prompt.reasonSelf ~= "mine: {buff}" then
				fail(scenario, "the wording does not write prompt.reasonSelf")
			end
			local reset = findOption(root, "resetAdvanced")
			if reset and reset.func then reset.func() end
			if ns.db.profile.prompt.reasonSelf ~= "your own {buff}" then
				fail(scenario, "Put these back to default kept " .. tostring(ns.db.profile.prompt.reasonSelf))
			end
		end

		local report = findOption(root, "report")
		local text = report and report.get and report.get() or ""
		if not tostring(text):find("sources owed/group/strangers/self=true/true/true/true", 1, true) then
			fail(scenario, "the bug report leaves the switch out: " .. flat(text))
		end
	end)
end

-- ------------------------------------------------------------------ self 16
-- A right-press on you skips you for now, and says so about your buff rather
-- than your name; shift-right-press switches you off, since the never-offer
-- list is of other people, and says how to have it back.
Mock.reset()
do
	local scenario = "self: right-click skips you, shift-right-click switches you off"
	with(scenario, {}, function(ns)
		ns.Prompt:Refresh()
		if not (ns.Prompt:Showing() and ns.Prompt:Showing().reason == "self") then
			fail(scenario, "SKIPPED -- the prompt is not on you")
			return
		end
		Mock.printed = {}
		H.pressButton(ns, "RightButton")
		if not said():find("skipping your own buff for now.", 1, true) then
			fail(scenario, "the skip reads " .. flat(said()))
		end
		if mine(ns) then fail(scenario, "still offered right after a skip") end
		Mock.advance(60)
		wipe(ns.tried)
		ns.Prompt:Refresh()
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered again after the skip ran out")
			return
		end
		IsShiftKeyDown = function() return true end
		Mock.printed = {}
		Mock.advance(1)
		H.pressButton(ns, "RightButton")
		IsShiftKeyDown = nil
		if ns.db.profile.sources.self ~= false then
			fail(scenario, "shift-right-click left the switch on")
		end
		if #ns.NeverList() > 0 then
			fail(scenario, "shift-right-click put " .. ns.NeverList()[1] .. " on the never-offer list")
		end
		if not said():find("your own buff will not be offered to you any more", 1, true) then
			fail(scenario, "nothing says how to have your own buff back: " .. flat(said()))
		end
	end)
end

-- ------------------------------------------------------------------ self 17
-- Your own name put on the never-offer list by hand keeps your own buff off
-- the prompt too, as it does anybody's.
Mock.reset()
do
	local scenario = "self: your own name on the never-offer list is honoured"
	with(scenario, {}, function(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered to begin with")
			return
		end
		ns.NeverOffer("mort defrette")
		if mine(ns) then fail(scenario, "offered your own buff with your name on the never-offer list") end
	end)
end

-- ------------------------------------------------------------------ self 18
-- Your own buff wears your group's colour in both palettes, not the grey of a
-- passer-by, which is what an unknown reason falls back to.
Mock.reset()
do
	local scenario = "self: your own buff wears your group's colour"
	with(scenario, {}, function(ns)
		for _, palette in ipairs({ "standard", "colourblind" }) do
			ns.db.profile.prompt.reasonPalette = palette
			local r1, g1, b1 = ns.Prompt:AccentColor("self")
			local r2, g2, b2 = ns.Prompt:AccentColor("group")
			if r1 ~= r2 or g1 ~= g2 or b1 ~= b2 then
				fail(scenario, ("in the %s palette you are %s,%s,%s and your group %s,%s,%s")
					:format(palette, tostring(r1), tostring(g1), tostring(b1),
						tostring(r2), tostring(g2), tostring(b2)))
			end
		end
	end)
end

-- ------------------------------------------------------------------ self 19
-- The launcher says it is your own buff, in its tooltip and in Who's next,
-- and its menu's Skip and Never act on you as the prompt's presses do.
Mock.reset()
do
	local scenario = "self: the launcher says it is your own buff"
	with(scenario, {}, function(ns)
		ns.Prompt:Refresh()
		local broker = Mock.broker
		if not (broker and broker.OnTooltipShow and ns.Prompt:Showing()) then
			fail(scenario, "SKIPPED -- no launcher, or no prompt on you")
			return
		end
		local lines = {}
		broker.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = tostring(text) end })
		local tip = table.concat(lines, " / ")
		if not tip:find("On the prompt: |cffffffffYou|r -- Arcane Intellect, your own buff", 1, true) then
			fail(scenario, "the launcher's tooltip reads " .. tip)
		end

		-- The right-click menu, in the shape the client's MenuUtil builds it.
		local function newMenu(text, fn)
			local d = { text = text, fn = fn, items = {} }
			local function add(c) d.items[#d.items + 1] = c return c end
			function d:CreateTitle(t) return add(newMenu(t)) end
			function d:CreateDivider() return add(newMenu()) end
			function d:CreateButton(t, f) return add(newMenu(t, f)) end
			function d:CreateCheckbox(t, _, f) return add(newMenu(t, f)) end
			function d:CreateRadio(t, _, f) return add(newMenu(t, f)) end
			function d:SetEnabled() end
			function d:SetTooltip() end
			return d
		end
		local function find(root, text)
			for _, item in ipairs(root.items) do
				if item.text and tostring(item.text):find(text, 1, true) then return item end
				local inner = find(item, text)
				if inner then return inner end
			end
		end
		local opened
		MenuUtil = { CreateContextMenu = function(owner, generator)
			opened = newMenu()
			generator(owner, opened)
			return opened
		end }
		broker.OnClick({}, "RightButton")
		local row = opened and find(opened, "(your own buff), on the prompt")
		if not row then
			fail(scenario, "Who's next does not say it is your own buff")
			return
		end
		Mock.printed = {}
		local skip = find(row, "Skip for now")
		if skip and skip.fn then skip.fn() end
		if not said():find("skipping your own buff for now.", 1, true) then
			fail(scenario, "Skip for now on you reads " .. flat(said()))
		end
		local never = find(row, "Never offer")
		if never and never.fn then never.fn() end
		if ns.db.profile.sources.self ~= false or #ns.NeverList() > 0 then
			fail(scenario, "Never offer on you did not switch your own buff off")
		end
	end)
end

-- ------------------------------------------------------------------ self 20
-- A /manners try macro arms no record of its own, but a press of it on your own
-- entry is still a press on yourself: the game naming you as the one it
-- reached files no gift to you, counts nothing, and settles nothing.
Mock.reset()
do
	local scenario = "self: a /manners try press on yourself files nothing"
	with(scenario, {}, function(ns)
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		ns.Prompt:Refresh()
		if not (ns.Prompt:Showing() and ns.Prompt:Showing().reason == "self") then
			fail(scenario, "SKIPPED -- the prompt is not on you")
			return
		end
		ns.addon:HandleSlash("try /target {name}\\n/cast {spell}")
		ns.Prompt:Refresh()
		local pressed = H.pressButton(ns)
		ns.addon:HandleSlash("try")
		if not (pressed and pressed:find("/target " .. ME, 1, true) and ns.pendingClick) then
			fail(scenario, "SKIPPED -- the try macro did not go out on you: " .. flat(pressed))
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", ME, "Cast-try-1", 1459)
		local s = ns.db.char.ledger
		if s and #s.entries > 0 then
			fail(scenario, ("a /manners try press on yourself wrote %d ledger rows, the first a %s row under %s")
				:format(#s.entries, tostring(s.entries[1].kind), tostring(s.entries[1].name)))
		end
		if s and (s.totals.group ~= 0 or s.totals.strangers ~= 0) then
			fail(scenario, "a /manners try press on yourself was counted as a buff given")
		end
		if ns.pendingClick then fail(scenario, "the try press was never settled") end
		local lead = tostring(ns.Prompt:Regions().name:GetText())
		if not lead:find("yourself", 1, true) then
			fail(scenario, "after a try press on you the panel reads " .. lead)
		end
	end)
end

-- ------------------------------------------------------------------ self 21
-- Saving mana keeps your own buff (Queue.lua, SelfEntry), so every line that
-- says who is still offered names it -- the tooltip on your own entry,
-- /manners debug, an empty press, the slider and the note under it -- and
-- none of them does with "Myself" off.
Mock.reset()
do
	local scenario = "self: saving mana, the lines say your own buff is kept"
	with(scenario, {}, function(ns)
		UnitPower = function(unit) return unit == "player" and 100 or 1000 end
		UnitPowerMax = function() return 1000 end
		ns.db.profile.filters.manaFloor = 30
		local KEPT = "only your own buff and people who buffed you or asked are offered"
		local OLD = "only people who buffed you or asked are offered"
		if not ns.SavingMana() then
			fail(scenario, "SKIPPED -- not saving mana at a tenth of it")
			return
		end
		if not mine(ns) then
			fail(scenario, "your own buff was held back while saving mana")
			return
		end
		ns.Prompt:Refresh()
		local tip = hover(ns)
		if not tip:find("Saving mana: until you are back to 35% mana, " .. KEPT, 1, true) then
			fail(scenario, "the tooltip under your own buff says " .. tip)
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find(KEPT, 1, true) then
			fail(scenario, "/manners debug while saving mana leaves your own buff out: " .. flat(said()))
		end
		local root = ns.optionsTable
		local floor, note = findOption(root, "manaFloor"), findOption(root, "manaNote")
		local desc = floor and (type(floor.desc) == "function" and floor.desc() or floor.desc) or ""
		if not tostring(desc):find("only your own buff and people who buffed you or asked are offered", 1, true) then
			fail(scenario, "the mana floor's description leaves your own buff out: " .. tostring(desc))
		end
		local noted = note and (type(note.name) == "function" and note.name() or note.name) or ""
		if not tostring(noted):find("only favours, requests and your own buff are offered", 1, true) then
			fail(scenario, "the mana note leaves your own buff out: " .. tostring(noted))
		end

		-- Wearing it, nobody is left: an empty press says what is kept.
		wear(ns, set(1459))
		for _ = 1, 3 do
			Mock.advance(2)
			ns.Prompt:Refresh()
		end
		if ns.Prompt:GetButton():IsShown() then
			fail(scenario, "SKIPPED -- the prompt is still up with nobody to offer")
		else
			Mock.printed = {}
			H.pressButton(ns)
			if not said():find(KEPT, 1, true) then
				fail(scenario, "an empty press while saving mana leaves your own buff out: " .. flat(said()))
			end
		end

		-- "Myself" off: the old sentences, which are true again.
		ns.db.profile.sources.self = false
		owe(ns, "Zed Far")
		ns.Prompt:Refresh()
		tip = hover(ns)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		desc = floor and (type(floor.desc) == "function" and floor.desc() or floor.desc) or ""
		noted = note and (type(note.name) == "function" and note.name() or note.name) or ""
		if tip:find("your own buff", 1, true) or not tip:find(OLD, 1, true)
			or said():find("your own buff and", 1, true) or tostring(desc):find("your own buff", 1, true)
			or tostring(noted):find("your own buff", 1, true) then
			fail(scenario, "with Myself off, a line still keeps your own buff: " .. tip .. " / " .. flat(said())
				.. " / " .. tostring(desc) .. " / " .. tostring(noted))
		end
	end)
end

-- ------------------------------------------------------------------ self 22
-- Start here: "Only people who buff me" leaves you out, as it says, and the
-- other choices put you back. Ticking yourself back on is fine-tuning, not
-- Custom -- nor is a profile from before 1.2, which gains the switch on
-- without anybody touching it.
Mock.reset()
do
	local scenario = "self: Only people who buff me leaves you out"
	with(scenario, {}, function(ns)
		local quick, s = ns.QuickSetup, ns.db.profile.sources
		-- A 1.1 profile on that choice: the new switch at its default.
		s.owed, s.group, s.strangers, s.self = true, false, false, true
		ns.db.profile.filters.whenBuffed = "skip"
		if quick.Match(quick.WHO) ~= "favours" then
			fail(scenario, "a profile from before 1.2 shows " .. tostring(quick.Match(quick.WHO))
				.. " rather than Only people who buff me")
		end
		quick.Apply(quick.WHO, "favours")
		if s.self ~= false or mine(ns) then
			fail(scenario, "Only people who buff me left you offered your own buff")
		end
		if quick.WhoSummary():find("myself", 1, true) then
			fail(scenario, "after Only people who buff me the summary names you: " .. quick.WhoSummary())
		end
		s.self = true
		if quick.Match(quick.WHO) ~= "favours" then
			fail(scenario, "ticking Myself back on shows " .. tostring(quick.Match(quick.WHO)))
		end
		for _, key in ipairs({ "group", "nearby", "raid" }) do
			quick.Apply(quick.WHO, "favours")
			quick.Apply(quick.WHO, key)
			if s.self ~= true then
				fail(scenario, "moving on from Only people who buff me to " .. key .. " left you out")
			end
			s.self = false
			if quick.Match(quick.WHO) ~= key then
				fail(scenario, "switching Myself off on " .. key .. " shows " .. tostring(quick.Match(quick.WHO)))
			end
		end
	end)
end

-- ------------------------------------------------------------------ self 23
-- The other lines a press on yourself can bring: the prompt moving on to you,
-- a second press before the game answered the first, and the game refusing
-- your own buff three times in a row. Each says you, never your name as if you
-- were somebody else who shares it.
Mock.reset()
do
	local scenario = "self: the other lines about a press on you say you"
	with(scenario, {}, function(ns)
		local me = mine(ns)
		if not me then
			fail(scenario, "SKIPPED -- not offered to begin with")
			return
		end
		Mock.printed = {}
		ns.Prompt:MovedOn(me)
		if not said():find("the prompt has moved on to your own buff", 1, true) or said():find("Mort", 1, true) then
			fail(scenario, "the moved-on line reads " .. flat(said()))
		end

		ns.Prompt:Refresh()
		if not (H.pressButton(ns) and ns.pendingClick) then
			fail(scenario, "SKIPPED -- the press on you did not go out")
			return
		end
		Mock.advance(0.5)
		Mock.printed = {}
		ns.AbandonPendingClick()
		if not said():find("no answer yet for the press on yourself", 1, true) or said():find("Mort", 1, true) then
			fail(scenario, "the abandoned press reads " .. flat(said()))
		end

		Mock.printed = {}
		for _ = 1, 3 do
			Mock.advance(1)
			ns.NoteRefusal(ME, "Can't do that while mounted.")
		end
		if not said():find("the game keeps refusing your own buff", 1, true) or said():find("Mort", 1, true) then
			fail(scenario, "the back-off line reads " .. flat(said()))
		end
	end)
end

-- ------------------------------------------------------------------ self 24
-- An error inside the window says you were not buffed; the cast going out
-- after it takes that back in chat, as it does for anybody, so chat and the
-- panel ("buffed yourself") agree.
Mock.reset()
do
	local scenario = "self: a cast after an error takes back that you were not buffed"
	with(scenario, {}, function(ns)
		ns.Prompt:Refresh()
		if not (H.pressButton(ns) and ns.pendingClick) then
			fail(scenario, "SKIPPED -- the press on you did not go out")
			return
		end
		Mock.printed = {}
		ns.addon:UI_ERROR_MESSAGE(nil, 0, "Your bags are full")
		if not said():find("you were not buffed", 1, true) then
			fail(scenario, "SKIPPED -- the error did not say you were not buffed: " .. flat(said()))
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", ME, "Cast-self-after", 1459)
		if not said():find("you were buffed after all", 1, true) or said():find("Mort", 1, true) then
			fail(scenario, "after an error and the cast going out, chat reads " .. flat(said()))
		end
		local lead = tostring(ns.Prompt:Regions().name:GetText())
		if not lead:find("buffed", 1, true) or not lead:find("yourself", 1, true) then
			fail(scenario, "after the cast went out the panel reads " .. lead)
		end
	end)
end

-- ------------------------------------------------------------------ self 25
-- A Greater Blessing lands on the paladin casting it when the class is their
-- own, so it must not take another of their own blessings off them either:
-- wearing their own Kings (which keeps their own entry off the queue), three
-- paladins missing Might make no Greater Blessing of Might. Missing Might
-- themselves, or wearing it, it forms as before.
Mock.reset()
do
	local scenario = "self: a Greater Blessing never replaces your own other blessing"
	local KINGS = 20217
	with(scenario, { class = "PALADIN", groupSize = 5, known = { 19740, KINGS, 25782 },
		people = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
			party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } } }, function(ns)
		Mock.unitClass = "PALADIN"
		ns.db.profile.sources.strangers = false
		ns.db.profile.groupBuffs.use, ns.db.profile.groupBuffs.atLeast = true, 3
		GetItemCount = function(id) return id == 21177 and 20 or 0 end
		GetItemInfo = function(id) return id == 21177 and "Symbol of Kings" or nil end
		local might = set(unpack(ns.FindBuff("PALADIN", "might").ranks))
		auras({ party4 = might })
		ns.Guard("probe", ns.ProbeCapabilities)
		local function greater()
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.groupCast then return entry end
			end
		end

		wear(ns, {})
		local group = greater()
		if not (group and group.buff.key == "might" and group.groupCast.class == "PALADIN") then
			fail(scenario, "SKIPPED -- no Greater Blessing of Might for four paladins and you missing it: "
				.. names(ns.BuildQueue()))
			return
		end
		wear(ns, might)
		if not greater() then
			fail(scenario, "wearing your own Might, three paladins missing it made no Greater Blessing")
		end

		wear(ns, set(KINGS))
		if mine(ns) then
			fail(scenario, "SKIPPED -- wearing your own Kings, you were offered " .. tostring(mine(ns).buff.key))
			return
		end
		group = greater()
		if group then
			fail(scenario, "a Greater Blessing of " .. tostring(group.buff.key)
				.. " was offered over your own Kings, for " .. tostring(group.groupCast.label))
		end
		ns.db.profile.sources.self = false
		wear(ns, set(KINGS))
		if greater() then
			fail(scenario, "with Myself off, a Greater Blessing was offered over your own Kings")
		end
	end)
end

-- ------------------------------------------------------------------ self 26
-- The cursor resting on the panel holds it for a token lost, never for a
-- verdict (see hovering in Prompt.lua). Buffed by hand while the cursor is on
-- "You", the scan no longer offers you, and that is a verdict on you: the
-- panel goes as it would with the cursor elsewhere, rather than holding your
-- own buff up for the cursor's ten seconds.
Mock.reset()
do
	local scenario = "self: a hovered You moves on once you buff yourself by hand"
	with(scenario, {}, function(ns)
		local button = ns.Prompt:GetButton()
		local function scan(seconds)
			for _ = 1, math.floor(seconds / 0.4 + 0.5) do
				Mock.runTimers(0.4)
				ns.addon:Tick()
			end
		end
		ns.Prompt:Refresh()
		if not (ns.Prompt:Showing() and ns.Prompt:Showing().reason == "self") then
			fail(scenario, "SKIPPED -- the prompt is not on you")
			return
		end
		button.scripts.OnEnter(button)
		scan(1)
		if not button:IsShown() then
			fail(scenario, "SKIPPED -- the prompt went while you were still missing your buff")
			button.scripts.OnLeave(button)
			return
		end
		wear(ns, set(1459))
		scan(3)
		if button:IsShown() then
			fail(scenario, "buffed by hand with the cursor on the panel, \"You\" stayed up for the cursor")
		end
		button.scripts.OnLeave(button)
	end)
end
