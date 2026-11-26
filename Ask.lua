-- Manners -- asking, not only giving: a polite line to somebody who could cast
-- a buff you would want and do not wear, at one press of the prompt.
--
-- Manners knows which buffs exist, who can cast them and what suits whom. This
-- turns that round on the player: when somebody of a class with such a buff is
-- in your group or right beside you, an "ask" entry can come up on the prompt,
-- last of everything on it. The press casts nothing and changes no target: its
-- macro is one spoken line, a whisper to them (or /say, as a choice).
--
-- The rules, each held by tests/scenarios/ask.lua:
--   * off until ticked (sources.ask);
--   * one ask per person per buff in ten minutes, one ask in all in two;
--   * never in a fight, never in a battleground or an arena, and in a city or
--     an inn only when that is ticked (ask.inTowns);
--   * never to somebody on your never-offer list or your /ignore list, nor
--     while they are dead, in a fight, away or busy;
--   * only for what the client says plainly you do not wear: a reading it
--     will not give is no reason to ask anybody for anything.
--
-- The hooks are single lines in the shared files: Queue.lua (BuildQueue hands
-- its queue through ns.AskInto), Core.lua (ns.CanCastAnything, ns.BuffInfo,
-- ns.ClampSettings), Prompt/Macro.lua (Arm, ClickSummary, FightMacro),
-- Prompt/Press.lua (OnPostClick), Prompt/Paint.lua (ReasonText) and
-- Prompt/Button.lua (the tooltip).

local _, ns = ...
local L = ns.L
local addon = ns.addon
local plain = ns.plain
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown

local Ask = {}
ns.Ask = Ask

-- Behind everything the queue ranks (Queue.lua, PRIORITY: passers-by are 3).
Ask.PRIORITY = 9
-- One ask per person per buff in this long, and one ask in all in this long.
Ask.PERSON_SECONDS = 600
Ask.REST_SECONDS = 120
-- A buff that lasts less than this is not worth a line to anybody.
Ask.SHORT_SECONDS = 300
-- How long a reading of your own auras stands, so a scan with somebody to ask
-- beside you does not read them all again 2.5 times a second.
Ask.READ_SECONDS = 1

---------------------------------------------------------------------------
-- the words
---------------------------------------------------------------------------

-- The three plain lines, chosen on Who to buff (ask.line).
Ask.LINE_ORDER = { "moment", "may", "mind" }
Ask.LINES = {
	moment = L["Could I have {buff} when you have a moment, {name}? Thank you."],
	may = L["{name}, may I ask you for {buff}, please?"],
	mind = L["Hello {name}, would you mind casting {buff} on me? Thanks!"],
}

-- And the player's own words (ask.line "own", the text in ask.own; asked
-- for on CurseForge): {name} and {buff} as in the lines above, either left
-- out as the player likes. Said even with the In character set on, since
-- the player wrote it; empty, or too long for the macro, the first line.
Ask.OWN_MAX = 200
Ask.CHOICE_ORDER = { "moment", "may", "mind", "own" }
function Ask.Choices()
	return { moment = Ask.LINES.moment, may = Ask.LINES.may, mind = Ask.LINES.mind, own = L["My own words"] }
end

-- The own words as they may go into a macro: one line, no |, trimmed. Only
-- ASCII blanks count as space: a character whose last byte is 0xA0 (the
-- Chinese for you, say) is no space, whatever a machine's locale says of
-- that byte.
function Ask.CleanOwn(text)
	if type(text) ~= "string" then return "" end
	text = text:gsub("|", ""):gsub("[\r\n]", " "):gsub("[ \t\f\v]+", " "):match("^ *(.-) *$")
	if #text > Ask.OWN_MAX then
		text = text:sub(1, Ask.OWN_MAX)
		-- Back up to a whole character: a cut in the middle of one would
		-- go into the macro as bytes that are no letter.
		local i = #text
		while i > 0 and text:byte(i) >= 0x80 and text:byte(i) < 0xC0 do i = i - 1 end
		if i > 0 and text:byte(i) >= 0xC0 then
			local need = text:byte(i) >= 0xF0 and 4 or text:byte(i) >= 0xE0 and 3 or 2
			if #text - i + 1 < need then text = text:sub(1, i - 1) end
		end
	end
	return text
end

-- The lines said with the In character set chosen on What I say, in the style
-- of Phrases.lua and held to its rules (tests/scenarios/ask.lua): 85 bytes at
-- most with the tokens filled, never the word "buff", no |, [ or ]. On a
-- client in another language a line with no translation is left out, as the
-- In character pools leave theirs out; a language with none keeps them all.
do
	local real = ns.L
	local english = {}
	-- This block's L is the real one, noting each line's English beside it.
	local L = setmetatable({}, { __index = function(_, key)
		local text = real[key]
		english[text] = key
		return text
	end })
	local pool = {
		L["{name}, might I trouble you for {buff}? You have my thanks."],
		L["A moment of your craft, {name}? {buff} would serve me well."],
		L["{name}, if you can spare it, {buff} would be most welcome."],
		L["Well met, {name}. Could you grant me {buff} before I go?"],
		L["I would be in your debt for {buff}, {name}."],
		L["{name}, the road ahead is long. Would you lend me {buff}?"],
	}
	local locale = ns.LOCALE
	if locale ~= nil and locale ~= "enUS" and locale ~= "enGB" and next(real) ~= nil then
		local kept = {}
		for _, text in ipairs(pool) do
			if rawget(real, english[text]) ~= nil then kept[#kept + 1] = text end
		end
		if kept[1] ~= nil then pool = kept end
	end
	Ask.POOL = pool
end

local function Sanitize(text)
	if type(text) ~= "string" then return nil end
	text = text:gsub("[\r\n]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
	if text == "" then return nil end
	return text
end

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------

local function Profile()
	return addon.db and addon.db.profile
end

-- Whether the switch is on: the one question the rest of the addon asks
-- (ns.CanCastAnything, the first run, Start here).
function ns.AskLive()
	local db = Profile()
	return db ~= nil and type(db.sources) == "table" and db.sources.ask == true
end

-- ns.ClampSettings' repair for the two choices (the switches are repaired by
-- type with every other leaf).
function ns.AskClamp(profile)
	local ask = profile.ask
	if type(ask) ~= "table" then return end
	if ask.channel ~= "WHISPER" and ask.channel ~= "SAY" then ask.channel = "WHISPER" end
	if Ask.LINES[ask.line] == nil and ask.line ~= "own" then ask.line = Ask.LINE_ORDER[1] end
	-- The development branch called this `paladin`; 1.12.2 shipped
	-- `blessing`, so retain only the released key and copy that one if present.
	if ask.blessing == nil and Ask.Blessings()[ask.paladin] ~= nil then ask.blessing = ask.paladin end
	ask.paladin = nil
	ask.own = Ask.CleanOwn(ask.own)
	if ask.blessing ~= "auto" and not Ask.Blessings()[ask.blessing] then ask.blessing = "auto" end
end

-- The blessings a paladin can be asked for on this client (GitHub issue 57,
-- broodwave on CurseForge: a feral druid wanted Might, not Wisdom), by key,
-- with Automatic: the ones Want could ask for at all, named by the spell.
-- Empty but for Automatic on a client whose paladins have none.
function Ask.Blessings()
	local values, order = { auto = L["Automatic"] }, { "auto" }
	for _, key in ipairs({ "kings", "wisdom", "might", "salvation" }) do
		local buff = ns.FindBuff("PALADIN", key)
		if buff and not (buff.optIn or buff.returnOnly or buff.neverAuto or buff.oneTarget
			or buff.tankChoice or buff.selfCast) then
			local name = buff.ranks and buff.ranks[1] and ns.SpellNameFor(buff.ranks[1])
			if type(name) == "string" and name ~= "" then
				values[buff.key] = name
				order[#order + 1] = buff.key
			end
		end
	end
	return values, order
end

---------------------------------------------------------------------------
-- who was asked, and when
---------------------------------------------------------------------------

-- [name .. "\0" .. buff key] = when, and when the last ask of all went out.
-- Kept for the session: a /reload forgets them.
local asked, askedCount = {}, 0
Ask.asked = asked
Ask.lastAt = nil
-- Who the last scan found, kept on them while they still can be asked: the
-- nameplates are walked in no order, and the prompt must not flit between two
-- priests.
Ask.lastName = nil

local function AskedAt(name, key)
	return asked[name .. "\0" .. key]
end

-- A class whose buffs replace one another (a paladin's blessings) is asked
-- for one of them: an ask for any of them counts for them all.
local function AskedLately(name, class, buff, now)
	local list = ns.EXCLUSIVE_BUFFS[class] and ns.BUFFS[class] or nil
	if not list then
		local at = AskedAt(name, buff.key)
		return at ~= nil and now - at < Ask.PERSON_SECONDS
	end
	for _, other in ipairs(list) do
		local at = AskedAt(name, other.key)
		if at ~= nil and now - at < Ask.PERSON_SECONDS then return true end
	end
	return false
end

local function NoteAsked(name, key, now)
	local id = name .. "\0" .. key
	if asked[id] == nil then
		if askedCount >= 400 then
			wipe(asked)
			askedCount = 0
		end
		askedCount = askedCount + 1
	end
	asked[id] = now
	Ask.lastAt = now
end

-- A key recently requested from another Paladin. An Automatic ask may move on
-- to a different blessing rather than asking every Paladin for the same one.
local function AskedByOtherPaladin(name, key, now)
	for id, at in pairs(asked) do
		local who, askedKey = id:match("^(.-)%z(.*)$")
		if who ~= name and askedKey == key and now - at < Ask.PERSON_SECONDS then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- what holds every ask back
---------------------------------------------------------------------------

-- nil when an ask may be offered now, else why not: "off", "fight", "battle",
-- "town" or "rest". The scan, the arming and /manners debug ask it alike.
function Ask.HeldBack(db, now)
	if not (db and type(db.sources) == "table" and db.sources.ask == true) then return "off" end
	local prompt = ns.Prompt
	if InCombatLockdown() or (prompt and prompt.armedForFight == true) then return "fight" end
	local fighting = _G.UnitAffectingCombat
	if type(fighting) == "function" and plain(fighting("player")) == true then return "fight" end
	if ns.InBattleground() then return "battle" end
	-- Only a plain "not resting" is the world: a client that will not say is
	-- taken for a city, as every other spoken line takes a silence for a no.
	if not (type(db.ask) == "table" and db.ask.inTowns == true) and ns.Resting() ~= false then return "town" end
	if Ask.lastAt and now - Ask.lastAt < Ask.REST_SECONDS then return "rest" end
	return nil
end

---------------------------------------------------------------------------
-- what you would want
---------------------------------------------------------------------------

-- The entry's buff: a table of this file's own, not the other class's row,
-- so nothing that reads a buff's flags (a shout, a scroll, a rank to name)
-- takes it for one of yours. Its key is its own too, apart from every key of
-- your class, and its name and icon are handed to ns.BuffInfo (`askInfo`).
-- One per class and buff, kept: the prompt and the list tell an entry by it.
local wrapped = {}

local function Wrap(class, buff)
	local id = class .. "\0" .. buff.key
	local made = wrapped[id]
	if made then return made end
	local top = buff.ranks and buff.ranks[1]
	local name = top and ns.SpellNameFor(top)
	if type(name) ~= "string" or name == "" then return nil end
	made = {
		key = "ask:" .. buff.key,
		ask = true,
		wanted = buff,
		askInfo = {
			key = "ask:" .. buff.key,
			name = name,
			icon = ns.safecall(C_Spell and C_Spell.GetSpellTexture, top),
			known = false,
			readable = false,
			secrecy = {},
			unresolved = {},
		},
	}
	wrapped[id] = made
	return made
end

-- The probe runs again when the spell data arrives (SPELLS_CHANGED): a name
-- the client had not loaded yet is asked for again.
function Ask.Forget()
	wipe(wrapped)
end

-- Whether you wear it: true, false, or nil when the client will not say. Its
-- ranks, its group version and another class's of the same kind (Buffs.lua,
-- auraIds), and what holds it off (blockerIds: a scroll of the same stat),
-- which is reason enough to leave somebody in peace. Your own auras, so each
-- read is one protected call and nothing else; kept a second.
--
-- `own` asks for the class's own ids alone, with nothing another class gives
-- of the same kind (alikeIds): a druid's Mark of the Wild is no blessing, and
-- says nothing of what a paladin has left to give.
local worn, wornOwn = {}, {}
local ownIds = {}

local function OwnIds(buff)
	local ids = ownIds[buff]
	if ids then return ids end
	ids = {}
	for _, id in ipairs(buff.readIds or buff.auraIds or {}) do
		if not buff.alikeIds[id] then ids[#ids + 1] = id end
	end
	ownIds[buff] = ids
	return ids
end

local function Wearing(buff, now, own)
	own = own == true and buff.alikeIds ~= nil
	local cache = own and wornOwn or worn
	local kept = cache[buff]
	if kept and now - kept.at < Ask.READ_SECONDS then return kept.has end
	local read = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
	local has = false
	if type(read) ~= "function" then
		has = nil
	else
		local secret = _G.issecretvalue
		local secrets = _G.C_Secrets
		local hidden = type(secrets) == "table" and secrets.ShouldSpellAuraBeSecret
		for _, id in ipairs(own and OwnIds(buff) or buff.readIds or buff.auraIds or {}) do
			local ok, aura = pcall(read, "player", id)
			if not ok or (secret and secret(aura)) then
				has = nil
			elseif type(aura) == "table" then
				has = true
				break
			elseif type(hidden) == "function" and plain(hidden(id)) == true then
				has = nil
			end
		end
	end
	if kept then
		kept.at, kept.has = now, has
	else
		cache[buff] = { at = now, has = has }
	end
	return has
end

-- For the scenarios, and for a press: what you wear is read afresh.
function Ask.ForgetWorn()
	wipe(worn)
	wipe(wornOwn)
end

-- The same rules that decide what suits somebody else (Core.lua, Castable),
-- turned round on yourself. `me` is the scan's account of you; `grouped` and
-- `unit` are theirs.
local function Suits(buff, me, unit, grouped, level, explicitlyChosen)
	-- Never what not everybody of the class has (a talent), what Manners itself
	-- hands out only on request (optIn, returnOnly, neverAuto), what goes to
	-- one person at a time or to a tank by choice, or a shout.
	if (buff.talent and not explicitlyChosen) or buff.optIn or buff.returnOnly or buff.neverAuto or buff.oneTarget
		or buff.tankChoice or buff.selfCast then
		return false
	end
	if buff.partyOnly and not (grouped and ns.SameParty(unit)) then return false end
	if (buff.groupOnly or buff.membersOnly) and not grouped then return false end
	if buff.manaOnly and me.relevantOnly and me.hasMana == false then return false end
	if buff.meleeOnly and me.caster then return false end
	local seconds = ns.BuffSeconds(buff)
	if seconds and seconds > 0 and seconds < Ask.SHORT_SECONDS then return false end
	-- Too low for every rank of it (Buffs.lua, lowLevel): it could not land.
	if buff.lowLevel and me.level and me.level + 10 < buff.lowLevel then return false end
	-- And they too low to have learned its first rank.
	local first = buff.ranks and ns.RankLevel(buff.ranks[#buff.ranks])
	if first and level and level < first then return false end
	return true
end

local PALADIN_ORDER = { "kings", "wisdom", "might", "salvation" }

-- Which buff of their class to ask this person for, or nil.
local function Want(name, class, unit, grouped, level, me, now)
	local buffs = ns.BUFFS[class]
	if type(buffs) ~= "table" then return nil end
	if ns.EXCLUSIVE_BUFFS[class] then
		-- A Paladin's explicit choice may name a talent buff. Automatic keeps
		-- the existing role-based choice and, once that choice is accounted
		-- for by another Paladin, can ask this one for a different blessing.
		local choice = class == "PALADIN" and Profile() and Profile().ask
			and Profile().ask.blessing or "auto"
		local unknown = false
		-- An explicit request is a statement of intent: a different blessing
		-- already on the player does not cancel it. The chosen one itself must
		-- still be plainly missing and not recently asked of this Paladin.
		if class == "PALADIN" and choice ~= "auto" then
			local first = ns.FindBuff(class, choice)
			if first and Suits(first, me, unit, grouped, level, true)
				and Wearing(first, now) == false and not AskedByOtherPaladin(name, choice, now)
				and not AskedLately(name, class, first, now) then
				return first
			end
			return nil
		end
		for _, buff in ipairs(buffs) do
			if not buff.oneTarget then
				local worn = Wearing(buff, now, true)
				if worn ~= false then
					if worn == nil then
						unknown = true
					elseif not AskedByOtherPaladin(name, buff.key, now) then
						return nil
					end
				end
			end
		end
		if unknown then return nil end
		local auto = ns.CLASS_AUTO[class]
		local preferred = auto and (me.hasMana and auto.mana or auto.other)
		local first = preferred and ns.FindBuff(class, preferred)
		if first and Suits(first, me, unit, grouped, level) and Wearing(first, now) == false
			and not AskedByOtherPaladin(name, first.key, now)
			and not AskedLately(name, class, first, now) then
			return first
		end
		if class == "PALADIN" then
			for _, key in ipairs(PALADIN_ORDER) do
				local other = ns.FindBuff(class, key)
				if other and key ~= preferred and Suits(other, me, unit, grouped, level)
					and Wearing(other, now) == false and not AskedByOtherPaladin(name, key, now)
					and not AskedLately(name, class, other, now) then
					return other
				end
			end
		end
		if class == "PALADIN" then return nil end
	end
	for _, buff in ipairs(buffs) do
		if Suits(buff, me, unit, grouped, level) and Wearing(buff, now) == false
			and not AskedLately(name, class, buff, now) then
			return buff
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- the line and its macro
---------------------------------------------------------------------------

-- The line for this person as it would be said, and for an In character line
-- the line as written. `avoid` is an In character line not to say twice
-- running.
local function Compose(db, entry, room, avoid)
	local spell = ns.BuffName(entry.buff)
	local function Fill(template)
		-- First name only (Speech.lua, ns.SaidName): the words, never the whisper's address.
		local text = ns.Swap(template, "{name}", ns.SaidName(entry.short or entry.name))
		return Sanitize(ns.Swap(text, "{buff}", spell))
	end
	-- My own words, ahead of the In character set: the player wrote them.
	if db.ask.line == "own" then
		-- Empty, Fill gives nil and the plain line below is said.
		local text = Fill(Ask.CleanOwn(db.ask.own))
		if text and #text <= room then return text end
	end
	local rp = ns.InCharacter
	if rp and rp.Active and rp.Active(db.speech) then
		local fits, others = {}, {}
		for _, template in ipairs(Ask.POOL) do
			local text = Fill(template)
			if text and #text <= room then
				fits[#fits + 1] = { text, template }
				if template ~= avoid then others[#others + 1] = fits[#fits] end
			end
		end
		if #others > 0 then fits = others end
		if #fits > 0 then
			local pick = fits[math.random(#fits)]
			return pick[1], pick[2]
		end
	end
	local text = Fill(Ask.LINES[db.ask.line] or Ask.LINES[Ask.LINE_ORDER[1]])
	if text and #text <= room then return text end
	return nil
end

-- The macro for an ask: one line, `/w <name> <line>` or `/say <line>`, with
-- no target change and no cast. nil when no line can go: a name the chat box
-- would read as somebody else's (Speech.lua: on WoW Forever a name is two
-- words, and "/w Petra Could I..." is a whisper to Petra Could), or one that
-- is not safe in a macro. `state` is the prompt's (or a list row's), where
-- the line rolled for this person is kept, so the tooltip quotes what the
-- press says.
function Ask.MacroFor(entry, state)
	local db = Profile()
	if not (db and type(db.ask) == "table" and entry and entry.ask and entry.buff) then return nil end
	local command = ns.CHANNEL_COMMANDS[db.ask.channel == "SAY" and "SAY" or "WHISPER"]
	local to
	if db.ask.channel ~= "SAY" then
		to = ns.WhisperName(entry)
		if not to then return nil end
		command = command .. " " .. to
	end
	local room = ns.MACRO_LIMIT - #command - 2
	local identity = table.concat({ entry.name, entry.buff.key, tostring(db.ask.channel), tostring(db.ask.line),
		tostring(db.ask.own),
		tostring(db.speech and db.speech.presetChoice), tostring(db.speech and db.speech.firstNameOnly) }, "\1")
	local line, source
	if state and state.askKey == identity and state.askLine and #state.askLine <= room then
		line, source = state.askLine, state.askSource
	else
		line, source = Compose(db, entry, room, Ask.lastSource)
		if state then state.askKey, state.askLine, state.askSource = identity, line, source end
	end
	if not line then return nil end
	local macro = "/" .. command .. " " .. line
	if to and ns.WhisperGoesTo(macro) ~= to then return nil end
	return macro, line, source
end

---------------------------------------------------------------------------
-- the scan
---------------------------------------------------------------------------

local TOKENS = { raid = {}, party = {} }
for i = 1, 40 do
	TOKENS.raid[i] = "raid" .. i
	TOKENS.party[i] = "party" .. i
end

-- The scan's account of you, one table reused.
local me = {}
-- Where the scan keeps the line it tried for whoever it last found (MacroFor).
Ask.probe = {}

-- Whether this unit is somebody to ask, and for what: the entry, or nil.
-- `grouped` for a member of your party or raid; anybody else has to be near
-- (Range.lua, as a passer-by is measured), unless they are your target.
local function Consider(unit, grouped, pointed, taken, db, now)
	if plain(UnitExists(unit)) ~= true then return nil end
	if plain(UnitIsUnit(unit, "player")) ~= false then return nil end
	if plain(UnitIsPlayer(unit)) ~= true then return nil end
	-- As every spoken line: what the client will not answer is a no.
	if plain(UnitIsDeadOrGhost(unit)) ~= false then return nil end
	if plain(UnitCanAssist("player", unit)) ~= true then return nil end
	if plain(UnitIsConnected(unit)) == false then return nil end
	local fighting = _G.UnitAffectingCombat
	if type(fighting) == "function" and plain(fighting(unit)) ~= false then return nil end
	local away, busy = _G.UnitIsAFK, _G.UnitIsDND
	if type(away) == "function" and plain(away(unit)) == true then return nil end
	if type(busy) == "function" and plain(busy(unit)) == true then return nil end

	local class = plain(select(2, UnitClass(unit)))
	-- Your own class could give you nothing you cannot give yourself.
	if type(class) ~= "string" or class == me.class or ns.BUFFS[class] == nil then return nil end

	local full = ns.UnitFullName(unit)
	if not full or taken[full] then return nil end
	-- The never-offer list and the /ignore list.
	if ns.IsNeverOffered(full) then return nil end
	if ns.Ignored(unit, plain(UnitGUID(unit))) then return nil end
	-- The mute list (Who to skip): nobody muted is asked, your target included.
	if ns.MuteListed(full, unit, now) then return nil end

	-- A member of your group found through your target or a nameplate is a
	-- member still, and held to the same reach.
	if not grouped then
		local inParty = plain(UnitInParty and UnitInParty(unit))
		local inRaid = plain(UnitInRaid and UnitInRaid(unit))
		grouped = inParty == true or (inRaid ~= nil and inRaid ~= false)
	end
	if grouped then
		-- In sight, and not measured out of reach of a cast on you.
		if plain(_G.UnitIsVisible and _G.UnitIsVisible(unit)) == false then return nil end
		local reach = _G.UnitInRange
		if type(reach) == "function" then
			local near, checked = reach(unit)
			if plain(checked) == true and plain(near) == false then return nil end
		end
	elseif not pointed and ns.NearEnough(unit, true) == false then
		return nil
	end

	local level = plain(UnitLevel(unit))
	if type(level) ~= "number" or level < 1 then level = nil end
	local buff = Want(full, class, unit, grouped, level, me, now)
	local mine = buff and Wrap(class, buff)
	if not mine then return nil end
	-- A right-click's "not now" on them (Queue.lua: the whole person's block is
	-- read with every buff's), and the block a press on this ask wrote.
	if ns.IsBlocked(full, mine.key, now) then return nil end

	local entry = {
		name = full,
		short = ns.ShortName(full),
		targetName = ns.TargetName(full),
		unit = unit,
		class = class,
		buff = mine,
		reason = "ask",
		ask = true,
		inGroup = grouped == true,
		priority = Ask.PRIORITY,
		ranged = true,
		known = false,
		checked = true,
	}
	-- Nobody whose line could not go out: no name a whisper may carry. Asked
	-- with a slot of the scan's own, so the same person scan after scan costs
	-- a comparison and no line rolled.
	if not Ask.MacroFor(entry, Ask.probe) then return nil end
	return entry
end

-- Somebody to ask, or nil. `queue` is what BuildQueue offers this scan:
-- nobody on it is asked for anything, since they have a buff coming.
function Ask.Find(queue, db, now)
	if Ask.HeldBack(db, now) then return nil end
	local class = ns.caps and ns.caps.class
	if type(class) ~= "string" then return nil end
	me.class = class
	me.hasMana = ns.UnitHasMana("player")
	me.relevantOnly = db.filters.relevantOnly ~= false
	me.caster = db.buff.skipCasters == true and ns.CASTER_CLASSES[class] == true
	local level = plain(UnitLevel("player"))
	me.level = ns.LEVEL_GATED and type(level) == "number" and level > 0 and level or nil

	local taken = {}
	for _, entry in ipairs(queue) do
		if entry.name then taken[entry.name] = true end
	end

	local first
	-- True once the walk can stop: the one asked last scan, or with none to
	-- prefer, the first found.
	local function Take(unit, grouped, pointed)
		local entry = Consider(unit, grouped, pointed, taken, db, now)
		if not entry then return false end
		taken[entry.name] = true
		if entry.name == Ask.lastName then
			first = entry
			return true
		end
		first = first or entry
		return Ask.lastName == nil
	end

	local done = false
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n > 0 then
		local inRaid = plain(IsInRaid and IsInRaid()) == true
		local tokens = inRaid and TOKENS.raid or TOKENS.party
		for i = 1, inRaid and n or (n - 1) do
			if tokens[i] and Take(tokens[i], true) then
				done = true
				break
			end
		end
	end
	if not done then done = Take("target", false, true) end
	if not done then
		for token in pairs(ns.nameplateUnits) do
			if Take(token, false) then break end
		end
	end
	Ask.lastName = first and first.name or nil
	return first
end

-- BuildQueue's hook (Queue.lua): the queue with an ask after everybody on
-- it, and the verdicts with nothing said against the one asked.
function ns.AskInto(queue, verdicts)
	local db = Profile()
	if not (db and db.sources.ask == true) then return queue, verdicts end
	local entry = Ask.Find(queue, db, GetTime())
	if not entry then return queue, verdicts end
	queue[#queue + 1] = entry
	if type(verdicts) == "table" then
		verdicts[entry.name] = nil
	else
		verdicts = {}
	end
	return queue, verdicts
end

---------------------------------------------------------------------------
-- the button
---------------------------------------------------------------------------

local CLEARED = { "type1", "macrotext1", "spell1", "unit1", "type", "macrotext", "spell", "unit",
	"type2", "type3", "type4", "type5" }

-- Arm's hook (Prompt/Macro.lua): the button armed with the line and nothing
-- else, or left empty when no ask may go now. Out of combat only, as every
-- arming is; the pull's own repaint (armedForFight) arms nothing, so no ask is
-- ever frozen on the button for a fight.
function ns.AskArm(R, S, entry)
	local now = GetTime()
	local db = Profile()
	local macro, line, source
	local name, key = entry.name, entry.buff.key
	local wanted = entry.buff.wanted
	if db and not Ask.HeldBack(db, now) and not ns.IsBlocked(name, key, now)
		and not (wanted and entry.class and AskedLately(name, entry.class, wanted, now))
		-- Landed on you since the scan that found them: nothing left to ask for.
		and not (wanted and Wearing(wanted, now) ~= false) then
		macro, line, source = Ask.MacroFor(entry, S)
	end
	local applied = table.concat({ "ask", name, key, tostring(macro) }, "\1")
	if applied == S.appliedKey then return end

	-- Nothing of a buff's press stands under an ask: no record for a settle,
	-- no spoken line of the other kind, nothing for the bar macro to carry.
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
	S.askMacro, S.askSaid, S.askWritten = macro, line, source
	if not S.isRow then
		ns.lastMacro = macro or "[ask, not armed]"
		ns.SyncMacroSlot(nil)
	end
	S.appliedKey = applied
end

-- OnPostClick's hook (Prompt/Press.lua): a press on an ask. Nothing was cast,
-- so nothing is parked for a settle; what ran is the button's macro, and only
-- the line this file armed counts as said.
function ns.AskPressed(S, ran)
	local entry = S.current
	if not (entry and entry.ask and entry.buff and entry.name) then return end
	if type(ran) ~= "string" or ran ~= S.askMacro then return end
	local now = GetTime()
	local wanted = entry.buff.wanted
	NoteAsked(entry.name, wanted and wanted.key or entry.buff.key, now)
	-- Off the prompt now, and kept off by the hold and the fuse (Hold.lua,
	-- Retired), which ask the same block.
	ns.MarkAttempted(entry.name, entry.buff.key, Ask.PERSON_SECONDS)
	if S.askWritten then Ask.lastSource = S.askWritten end
	ns.Trail("ask", ("asked for %s, from %s"):format(tostring(wanted and wanted.key),
		S.isRow and "the list" or "the prompt"), entry.name)
	S.askMacro, S.askKey, S.askLine, S.askSource = nil, nil, nil, nil
	Ask.ForgetWorn()
	if not S.isRow then ns.Prompt:StopAttention() end
	ns.Guard("ask repaint", ns.Prompt.Refresh, ns.Prompt)
end

---------------------------------------------------------------------------
-- what the prompt says of it
---------------------------------------------------------------------------

-- The second line of the panel and of a list row.
function Ask.Reason(entry)
	return L["ask for %s"]:format(ns.BuffName(entry.buff))
end

-- The tooltip's line about the person.
function Ask.TooltipLine()
	return L["Could give you a buff you are missing. A press asks them for it, politely."]
end

-- What a press does, for the tooltip (Prompt:ClickSummary). `slot` holds the
-- line armed: the prompt's state, or a list row's, which holds none at rest.
function Ask.Summary(entry, slot)
	local out = {}
	local db = Profile()
	local macro, line = nil, nil
	if db and not Ask.HeldBack(db, GetTime()) then macro, line = Ask.MacroFor(entry, slot) end
	if not macro then
		out[#out + 1] = L["|cffffcc66Does nothing:|r %s."]:format(L["nobody can be asked just now"])
		return out
	end
	local who = entry.short or entry.name or "?"
	if db.ask.channel == "SAY" then
		out[#out + 1] = L["Says: |cffffffff%s|r"]:format(line)
	else
		out[#out + 1] = L["Whispers |cffffffff%s|r: |cffffffff%s|r"]:format(who, line)
	end
	out[#out + 1] = L["Casts nothing and leaves your target alone."]
	return out
end

---------------------------------------------------------------------------
-- /manners debug and the full check-up
---------------------------------------------------------------------------

function ns.AskLines(now)
	local out = {}
	local db = Profile()
	if not db then return out end
	now = now or GetTime()
	local switch = "|cffffd100" .. L["Ask people for a buff I'm missing"] .. "|r"
	local held = Ask.HeldBack(db, now)
	if held == "off" then
		out[#out + 1] = L["asking for buffs: off -- %s is not ticked."]:format(switch)
		return out
	elseif held == "fight" then
		out[#out + 1] = L["asking for buffs: held back -- nobody is asked in a fight."]
	elseif held == "battle" then
		out[#out + 1] = L["asking for buffs: held back -- nobody is asked in a battleground or an arena."]
	elseif held == "town" then
		out[#out + 1] = L["asking for buffs: held back in a city or an inn -- tick %s to ask there too."]
			:format("|cffffd100" .. L["Ask in cities and inns too"] .. "|r")
	elseif held == "rest" then
		out[#out + 1] = L["asking for buffs: held back -- you asked somebody %s ago, and one ask in two minutes is the most."]
			:format(ns.TimeText(now - Ask.lastAt))
	else
		local found
		ns.Guard("ask lines", function()
			local queue = ns.BuildQueue()
			for _, entry in ipairs(type(queue) == "table" and queue or {}) do
				if entry.ask then found = entry end
			end
		end)
		if found then
			out[#out + 1] = L["asking for buffs: |cffffffff%s|r can be asked for %s."]
				:format(found.name, ns.BuffName(found.buff))
		else
			out[#out + 1] = L["asking for buffs: on -- nobody in your group or beside you could give you a buff you are missing right now."]
		end
	end
	for id, at in pairs(asked) do
		if now - at < Ask.PERSON_SECONDS then
			local name = id:match("^(.-)%z")
			out[#out + 1] = L["asked |cffffffff%s|r %s ago -- not again for the same buff for ten minutes."]
				:format(tostring(name), ns.TimeText(now - at))
		end
	end
	return out
end
