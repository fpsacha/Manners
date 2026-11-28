-- Manners: Pets -- now and then, a moment with your companion pet.
--
-- Asked for by the addon's owner: the hunter's Bond with my pet, for the small
-- pet that follows any class (a Panda Cub, a cat in a basket). One switch,
-- "Moments with my companion", off by default. Only the moments: a companion
-- has no health, hunger or death, so there is no care to offer.
--
-- When: at login (hello), after a fight of HARD_FIGHT seconds with it out from
-- the pull to the end (well done), and on a quiet road (a pat). Never in a
-- fight, a battleground or an encounter; at most one in Pace's gap (the
-- hunter's "How often moments come"), shown for SHOW seconds, never a timer.
--
-- A press targets the companion by its exact name, does the emote at it, an
-- /emote of the gesture and its answer, a line from your people with In
-- character on and lines going in /say, and puts your target back. The name
-- is the journal's (customName, else the species): a client with no journal
-- (Classic Era, Burning Crusade) cannot say which companion is out, and gets
-- no moments.
--
-- The entries go through the same hooks as the hunter's (ns.Beast.*, called by
-- the prompt for any entry with `bond`); every wrap below hands anything that
-- is not a companion's to the hunter's own.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("pets"), "Manners module API is missing")
local L = ns.L
local addon = ns.addon
local plain = ns.plain
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown

local Beast = ns.Beast
local K = Beast.K
local Companion = {}
Beast.Companion = Companion

local C = {
	NAME = "?pet:companion",
	PRIORITY = 8.6,
	SHOW = 45,
	EXPIRE = { hello = 180, praise = 60, road = 30 },
	RANK = { praise = 3, hello = 2, road = 1 },
	HARD_FIGHT = 45,
	AFTER_FIGHT = 3,
	HELLO_AFTER = 10,
}
Companion.C = C

local REASON = {
	road = L["pet %s"], praise = L["tell %s: well done"], hello = L["say hello to %s"],
}
local GESTURE = {
	road = L["scratches %s behind the ears."], praise = L["gives %s a proud nod."],
	hello = L["crouches down beside %s."],
}
local ANSWER = { L["%s nuzzles closer."], L["%s stays close."] }
local BACK = "/targetlasttarget"
local CLEARED = { "type1", "macrotext1", "spell1", "unit1", "type", "macrotext", "spell", "unit",
	"type2", "type3", "type4", "type5" }

local function Profile() return addon.db and addon.db.profile end
local function Switches()
	local db = Profile()
	return type(db) == "table" and type(db.beast) == "table" and db.beast or nil
end
-- The switch, and Manners itself on.
local function Wanted()
	local db, beast = Profile(), Switches()
	return ns.ModuleActive("pets") and db ~= nil and db.enabled == true and beast ~= nil and beast.companion == true
end
Companion.Wanted = Wanted

local function Char()
	local char = addon.db and addon.db.char
	if type(char) ~= "table" then return nil end
	if type(char.companionBondAt) ~= "number" then char.companionBondAt = nil end
	return char
end

local function Pace()
	local beast = Switches()
	return K.PACE[beast and beast.companionPace] or K.PACE.sometimes
end

-- One moment's own switch, under the master (nil reads as on).
local MOMENT_SWITCH = { hello = "companionHello", praise = "companionPraise", road = "companionRoad" }
local function MomentOn(kind)
	local beast = Switches()
	return beast ~= nil and beast[MOMENT_SWITCH[kind]] ~= false
end

local function After(seconds, fn)
	local timer = _G.C_Timer
	if timer and type(timer.After) == "function" then timer.After(seconds, fn) end
end

local function RepaintNow()
	local prompt = ns.Prompt
	if prompt and type(prompt.Refresh) == "function" then ns.Guard("companion repaint", prompt.Refresh, prompt) end
end

---------------------------------------------------------------------------
-- which companion is out
---------------------------------------------------------------------------

-- The journal's out pet, read on every queue: one call, no pcall (busy path).
local function OutGuid()
	local journal = _G.C_PetJournal
	local read = type(journal) == "table" and journal.GetSummonedPetGUID
	if type(read) ~= "function" then return nil end
	local guid = plain(read())
	if type(guid) == "string" and guid ~= "" then return guid end
	return nil
end

-- Its name and icon, read once a pet (a guid), pcall'd: a call the client may
-- have changed.
local named = { guid = nil, name = nil, icon = nil }
local function Out()
	local guid = OutGuid()
	if not guid then return nil end
	if named.guid ~= guid then
		named.guid, named.name, named.icon = guid, nil, nil
		local journal = _G.C_PetJournal
		if type(journal.GetPetInfoByPetID) == "function" then
			local ok, species, custom, _, _, _, _, _, name, icon = pcall(journal.GetPetInfoByPetID, guid)
			if ok then
				custom, name, icon = plain(custom), plain(name), plain(icon)
				named.name = (type(custom) == "string" and custom ~= "" and custom)
					or (type(name) == "string" and name ~= "" and name) or nil
				named.icon = icon
				if not named.icon and type(journal.GetPetInfoBySpeciesID) == "function" and plain(species) then
					local ok2, _, speciesIcon = pcall(journal.GetPetInfoBySpeciesID, plain(species))
					if ok2 then named.icon = plain(speciesIcon) end
				end
			end
		end
	end
	return named.name, named.icon
end
Companion.Out = Out

---------------------------------------------------------------------------
-- the moment
---------------------------------------------------------------------------

local moment
local clock = { afterFight = 0, quietSince = nil, pullAt = nil, outAtPull = nil }

local function GapLeft()
	local char = Char()
	local at = char and char.companionBondAt
	if type(at) ~= "number" then return 0 end
	local since = time() - at
	if since < 0 then return 0 end
	return math.max(0, Pace().gap - since)
end

local function Trigger(kind, now)
	if not Wanted() or not MomentOn(kind) or GapLeft() > 0 then return end
	if moment and C.RANK[moment.kind] >= C.RANK[kind] then return end
	local name = Out()
	if not name then return end
	moment = { kind = kind, at = now, name = name }
	ns.Trail("pet", "a moment with the companion: " .. kind, name)
	After(0, RepaintNow)
	After((C.EXPIRE[kind] or 60) + 0.05, RepaintNow)
end
Companion.Trigger = Trigger

-- A game call's plain answer, nil where this client has no such call.
local function Ask(name, ...)
	local fn = _G[name]
	if type(fn) ~= "function" then return nil end
	return plain(fn(...))
end

-- Why no moment may be offered now, or nil.
local function Held(now)
	if InCombatLockdown() or Ask("UnitAffectingCombat", "player") == true then return "fight" end
	if now < clock.afterFight then return "fight" end
	if ns.InBattleground and ns.InBattleground() then return "battle" end
	if Ask("IsEncounterInProgress") == true then return "encounter" end
	if Ask("UnitIsDeadOrGhost", "player") == true or Ask("UnitOnTaxi", "player") == true then return "unable" end
	if ns.HiddenWhileMounted() then return "mounted" end
	return nil
end

local function Lapsed(now)
	if not moment then return false end
	if moment.shownAt then return now - moment.shownAt >= C.SHOW end
	return now - moment.at >= (C.EXPIRE[moment.kind] or 60)
end

-- A quiet stretch on the road: out in the world, moving, not away.
local function Road(now)
	if moment or not clock.quietSince or now - clock.quietSince < Pace().road then return end
	if GapLeft() > 0 or Held(now) then return end
	if ns.Resting() == true then return end
	if Ask("IsInInstance") == true then return end
	local speed = Ask("GetUnitSpeed", "player")
	if type(speed) ~= "number" or speed <= 0 then return end
	if Ask("UnitIsAFK", "player") == true then return end
	Trigger("road", now)
end

local entry
local function Entry()
	if entry and entry.moment == moment then return entry end
	local _, icon = Out()
	entry = {
		name = C.NAME, short = moment.name, display = moment.name, petName = moment.name,
		bond = moment.kind, moment = moment, companion = true,
		buff = { key = "companion:bond", bond = true, beastInfo = { key = "companion:bond",
			name = L["A moment with your companion"], icon = icon or 136460 } },
		reason = "bond", inGroup = false, priority = C.PRIORITY,
		ranged = true, inRange = true, known = false, checked = true,
	}
	return entry
end

local function Insert(queue, made)
	local at = #queue + 1
	for i, other in ipairs(queue) do
		if type(other.priority) == "number" and other.priority > made.priority then at = i break end
	end
	table.insert(queue, at, made)
end

local function Offer(queue, verdicts, now)
	if type(queue) ~= "table" then return queue, verdicts end
	if not Wanted() then moment = nil return queue, verdicts end
	if ns.SnoozeLeft and ns.SnoozeLeft(now) then return queue, verdicts end
	if InCombatLockdown() then return queue, verdicts end
	local prompt = ns.Prompt
	if prompt and prompt.armedForFight == true then return queue, verdicts end
	if Lapsed(now) then moment = nil end
	Road(now)
	if not moment or Held(now) then return queue, verdicts end
	-- Put away, or another one out, since the moment came: it is gone.
	if Out() ~= moment.name then moment = nil return queue, verdicts end
	Insert(queue, Entry())
	if type(verdicts) ~= "table" then verdicts = {} end
	return queue, verdicts
end
Companion.Offer = Offer

---------------------------------------------------------------------------
-- the button
---------------------------------------------------------------------------

local function EmoteCommand(kind)
	local spec = K.EMOTE[kind] or K.EMOTE.road
	local command = plain(_G[spec[1]])
	if type(command) ~= "string" or not command:find("^/%S+$") then command = spec[2] end
	return command
end

-- The macro: the companion targeted by its exact name, the emote at it, the
-- gesture and its answer, the line when it may go and fits, your target back.
local function Macro(made)
	local m, name = made.moment, made.petName
	if not (m and type(name) == "string") then return nil end
	local lines = { "/targetexact " .. name, EmoteCommand(m.kind) }
	local emote = "/" .. ns.CHANNEL_COMMANDS.EMOTE .. " "
	local gesture = (GESTURE[m.kind] or GESTURE.road):format(name)
	local beast = Switches()
	local answer = (beast and beast.companionAnswer ~= false) and (" " .. ANSWER[(#name % #ANSWER) + 1]:format(name)) or ""
	local used = #table.concat(lines, "\n") + 1 + #BACK + 1
	local n = #lines
	if used + #emote + #gesture + #answer <= ns.MACRO_LIMIT then
		lines[n + 1] = emote .. gesture .. answer
	elseif used + #emote + #gesture <= ns.MACRO_LIMIT then
		lines[n + 1] = emote .. gesture
	end
	local said, source
	if lines[n + 1] and beast and beast.companionWords ~= false and Beast.SayOpen() then
		local say = "/" .. ns.CHANNEL_COMMANDS.SAY .. " "
		local room = ns.MACRO_LIMIT - (used + #lines[n + 1] + 1) - #say
		if m.line == nil then
			m.line, m.source = Beast.Words(K.WORDS[m.kind] or "pet", name, room)
			if m.line == nil then m.line = false end
		end
		if m.line and #m.line <= room then
			said, source = m.line, m.source
			lines[n + 2] = say .. said
		end
	end
	lines[#lines + 1] = BACK
	return table.concat(lines, "\n"), said, source
end
Companion.Macro = Macro

local function Arm(R, S, made)
	local macro, said, source
	local prompt = ns.Prompt
	if not InCombatLockdown() and not (prompt and prompt.armedForFight == true) and made.moment == moment then
		macro, said, source = Macro(made)
	end
	local applied = table.concat({ "companion", tostring(made.bond), tostring(macro) }, "\1")
	if applied == S.appliedKey then return end
	S.armed = nil
	S.phraseKey, S.phraseText, S.phraseArmed, S.phraseSource = nil, nil, nil, nil
	S.barText, S.barSpoke, S.barSource = nil, nil, nil
	if macro then
		R.button:SetAttribute("type1", "macro")
		R.button:SetAttribute("macrotext1", macro)
		R.button:SetAttribute("type", "macro")
		R.button:SetAttribute("macrotext", macro)
		ns.Prompt.lib.SilenceOtherButtons(R)
	else
		for _, attribute in ipairs(CLEARED) do R.button:SetAttribute(attribute, nil) end
	end
	S.beastMacro, S.beastSaid, S.beastSource = macro, said, source
	if not S.isRow then
		local m = made.moment
		if m and m == moment and not m.shownAt and macro then
			local now = GetTime()
			m.shownAt, clock.quietSince = now, now
			local char = Char()
			if char then char.companionBondAt = time() end
			After(C.SHOW + 0.05, RepaintNow)
		end
		ns.lastMacro = macro or "[companion, not armed]"
		ns.SyncMacroSlot(nil)
	end
	S.appliedKey = applied
end

local function Pressed(S, ran)
	if type(ran) ~= "string" or ran ~= S.beastMacro then return end
	local m = S.current.moment
	if S.beastSaid and S.beastSource and ns.InCharacter and ns.InCharacter.Remember then
		ns.InCharacter.Remember(S.beastSource)
	end
	if moment == m then moment = nil end
	ns.Trail("pet", "a moment with the companion, from " .. (S.isRow and "the list" or "the prompt"), S.current.petName)
	S.beastMacro, S.beastSaid, S.beastSource = nil, nil, nil
	if not S.isRow then ns.Prompt:StopAttention() end
	After(0, RepaintNow)
end

local function LetGo(fromRow)
	moment = nil
	local db = Profile()
	if db and db.verbose then addon:Print(L["Right-click: not now."]) end
	if not fromRow and ns.Prompt then ns.Prompt:StopAttention() end
	RepaintNow()
end

-- Each hook the prompt calls on a pet entry: a companion's here, the rest to
-- the hunter's own.
do
	local function Mine(made) return type(made) == "table" and made.companion == true end
	local reason, tooltip, summary, clicks = Beast.Reason, Beast.TooltipLine, Beast.Summary, Beast.ClickLines
	local pressed, dismissEntry, dismissName = Beast.Pressed, Beast.DismissEntry, Beast.DismissName
	local live, arm = Beast.Live, ns.BeastArm
	function Beast.Reason(made)
		if Mine(made) then return (REASON[made.bond] or REASON.road):format(tostring(made.petName)) end
		return reason(made)
	end
	function Beast.TooltipLine(made)
		if Mine(made) then return L["A moment with your companion, now and then. Letting it pass costs nothing."] end
		return tooltip(made)
	end
	function Beast.Summary(made)
		if not Mine(made) then return summary(made) end
		local out = { L["A moment with %s: a press does an emote for it. Your target stays as it is."]:format(tostring(made.petName)) }
		local m = made.moment
		local beast = Switches()
		if m and m.line and beast and beast.companionWords ~= false and Beast.SayOpen() then out[2] = L["Says: |cffffffff%s|r"]:format(m.line) end
		return out
	end
	function Beast.ClickLines(made)
		if Mine(made) then return { L["Right-click: not now."] } end
		return clicks(made)
	end
	function Beast.Pressed(S, ran)
		if Mine(S.current) then return Pressed(S, ran) end
		return pressed(S, ran)
	end
	function Beast.DismissEntry(made, fromRow)
		if Mine(made) then return LetGo(fromRow) end
		return dismissEntry(made, fromRow)
	end
	function Beast.DismissName(name, S)
		if name == C.NAME then return LetGo(S and S.isRow) end
		return dismissName(name, S)
	end
	-- A class with nothing else to press still builds its queue for a moment.
	function Beast.Live()
		if live() then return true end
		return Wanted() and OutGuid() ~= nil
	end
	function ns.BeastArm(R, S, made)
		if Mine(made) then return Arm(R, S, made) end
		return arm(R, S, made)
	end
end

---------------------------------------------------------------------------
-- events and the queue
---------------------------------------------------------------------------

local frame
local function OnEvent(_, event, first)
	local now = GetTime()
	if event == "PLAYER_REGEN_DISABLED" then
		clock.pullAt, clock.outAtPull, clock.quietSince = now, Out(), nil
	elseif event == "PLAYER_REGEN_ENABLED" then
		clock.afterFight, clock.quietSince = now + C.AFTER_FIGHT, now
		local was = clock.outAtPull
		if was and Out() == was and clock.pullAt and now - clock.pullAt >= C.HARD_FIGHT then Trigger("praise", now) end
		clock.pullAt, clock.outAtPull = nil, nil
		After(C.AFTER_FIGHT + 0.05, RepaintNow)
	elseif event == "PLAYER_ENTERING_WORLD" then
		clock.quietSince = now
		if first == true then
			After(C.HELLO_AFTER, function() ns.Guard("companion hello", Trigger, "hello", GetTime()) end)
		end
	end
end

-- The frame is made the first time the switch is found on: a character that
-- never turns it on gets nothing from this file but a comparison.
local function Listen(on)
	if not on then
		if frame then frame:UnregisterAllEvents() end
		return
	end
	if not Wanted() then return end
	if not frame then
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(...) ns.Guard("companion event", OnEvent, ...) end)
	end
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end
After(1, function() ns.Guard("companion start", Listen, true) end)

function Companion.Suspend()
	Listen(false)
	moment = nil
end

function Companion.Resume() Listen(true) end

do
	local Build = ns.BuildQueue
	function ns.BuildQueue(watch)
		local queue, verdicts = Build(watch)
		if not Wanted() then return queue, verdicts end
		if not frame then Listen(true) end
		return Offer(queue, verdicts, GetTime())
	end
end

-- /manners debug and the full check-up: the switch, who is out, the moment
-- waiting and the gap, after the hunter's own lines.
do
	local lines = ns.BeastLines
	function ns.BeastLines(now)
		local out = lines and lines(now) or {}
		local beast = Switches()
		if not (beast and beast.companion == true) then return out end
		now = now or GetTime()
		out[#out + 1] = L["moments with your companion: on, out now: |cffffffff%s|r"]:format(tostring(Out() or "-"))
		if moment then
			local left = moment.shownAt and C.SHOW - (now - moment.shownAt) or (C.EXPIRE[moment.kind] or 60) - (now - moment.at)
			out[#out + 1] = L["a moment with your companion: %s, %ds left"]:format(moment.kind, math.max(0, math.floor(left)))
		end
		local gap = GapLeft()
		if gap > 0 then out[#out + 1] = L["next moment with your companion in %s"]:format(ns.TimeText(gap)) end
		return out
	end
end

-- For /manners debug and the tests.
function Companion.State()
	return { moment = moment and moment.kind or nil, name = moment and moment.name or nil, gap = GapLeft() }
end
