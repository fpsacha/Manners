-- Manners -- the candidate queue: who is owed a favour, what the game keeps
-- refusing, the never-offer list, friends and guildmates, and BuildQueue,
-- which puts everybody the prompt could offer in order.

local ns = select(2, ...)
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L
local addon = ns.addon

local issecretvalue = _G.issecretvalue
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Core.lua's and Range.lua's, which load first.
local plain, safecall, caps, MANA = ns.plain, ns.safecall, ns.caps, ns.MANA
local ShortName, SafeForMacro = ns.ShortName, ns.SafeForMacro
local UnitHasBuff, UnitHasMana, MANA_CLASSES = ns.UnitHasBuff, ns.UnitHasMana, ns.MANA_CLASSES
local IsBuffableUnit, InRange, ShoutReach, SameParty = ns.IsBuffableUnit, ns.InRange, ns.ShoutReach, ns.SameParty
local prox, Resting = ns.proximity, ns.Resting

---------------------------------------------------------------------------
-- candidate queue
---------------------------------------------------------------------------

-- People who buffed us: [name] = { expires, at, guid?, class? }. `at` is when
-- the favour was noticed, which the grace window and LiveExpiry count from.
local owed = {}

-- [name .. "\0" .. buffKey] = expiry for a buff we just tried on them, so
-- casting Fortitude does not stop the walk reaching Divine Spirit; and
-- [name .. "\0*"] = expiry for the whole person (a right-press skip, or a press
-- that reached nobody), so somebody behind a pillar does not walk the list.
local tried = {}

-- [name] = what the game has been refusing on this person (see NoteRefusal).
-- In memory only, on purpose: a /reload or a new login is a fresh start, and
-- whatever the server held against them (a phase, a duel, a rule nobody
-- names) rarely outlives one.
local refusals = {}

ns.lastGave = {} -- [name] = buffKey, for rotating when auras cannot be read

ns.owed, ns.tried, ns.refusals = owed, tried, refusals

-- When a debt really runs out: the stamp it was filed with, or its age against
-- the window as it stands now, whichever comes first -- so lowering "Remember a
-- buff for" applies to debts already owed. Every reader asks this.
local function LiveExpiry(entry)
	local db = addon.db and addon.db.profile
	local window = db and db.timing and db.timing.reciprocateWindow
	if type(entry.at) ~= "number" or type(window) ~= "number" then return entry.expires end
	return math.min(entry.expires, entry.at + window)
end
ns.DebtExpiry = LiveExpiry

-- GetTime() is time since boot, so it restarts after a reboot and differs per
-- machine: debts go out on the wall clock and are rebased on the way back in,
-- `at` included. db.char, not the profile: a debt is owed to a character.
local function SaveDebts()
	local store = addon.db and addon.db.char
	local wall = plain(time and time())
	if not store or type(wall) ~= "number" then return end

	-- Switched off means the file is cleared, not merely not written.
	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now, out = GetTime(), nil
	for name, entry in pairs(owed) do
		local expires = LiveExpiry(entry)
		if expires > now then
			out = out or {}
			-- The class is all the tokenless fallback has to judge by. The guid
			-- is not kept: nothing reads it back.
			out[name] = {
				expires = wall + (expires - now),
				at = wall - (now - entry.at),
				class = entry.class,
			}
		end
	end
	store.debts = out -- nil when empty, so AceDB prunes the section on logout
end
ns.SaveDebts = SaveDebts

local function RestoreDebts()
	local store = addon.db and addon.db.char
	local saved = store and store.debts
	local wall = plain(time and time())
	if type(saved) ~= "table" or type(wall) ~= "number" then return end

	-- Honoured on the way in too: a file can outlive the setting (a profile
	-- switched between logins, or changed on another character).
	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now = GetTime()
	local window = (addon.db and addon.db.profile.timing.reciprocateWindow) or 120
	for name, entry in pairs(saved) do
		if type(entry) == "table" and type(entry.expires) == "number"
			and type(entry.at) == "number" and SafeForMacro(name) then
			-- Clamped to the window as it stands now, counted from the favour
			-- as LiveExpiry does. A stamp from the future (the clock set back
			-- since it was written) counts as now, or the skew would be added
			-- to the window.
			local at = math.min(entry.at, wall)
			local left = math.min(entry.expires, at + window) - wall
			if left > 0 then
				-- `at` goes negative just after a reboot, correctly: now - at
				-- is still the real age of the debt.
				owed[name] = {
					expires = now + left,
					at = now - (wall - at),
					class = type(entry.class) == "string" and entry.class or nil,
				}
			end
		end
	end
end
-- OnInitialize (Core.lua) brings them back, once a session.
ns.RestoreDebts = RestoreDebts

-- AceDB fires this from its PLAYER_LOGOUT handler, before it strips the
-- defaults, so writing here is safe.
function addon:SaveDebts()
	ns.Guard("SaveDebts", SaveDebts)
end

-- The only writers and reader of the two key shapes in `tried`, in a block of
-- their own for the main chunk's 200 locals.
do
	-- One writer under both shapes. keepLonger extends a block and never
	-- shortens it, so the two-second rewind of a press that went nowhere cannot
	-- cancel a right-press skip at the full retry cooldown.
	local function Block(key, seconds, keepLonger)
		if not seconds then
			local db = addon.db and addon.db.profile
			seconds = (db and db.timing.retryCooldown) or 12
		end
		local expiry = GetTime() + seconds
		local standing = tried[key]
		if keepLonger and standing and standing > expiry then return end
		tried[key] = expiry
	end

	function ns.MarkAttempted(name, buffKey, seconds, keepLonger)
		if not name or not buffKey then return end
		Block(name .. "\0" .. buffKey, seconds, keepLonger)
	end

	function ns.BlockPerson(name, seconds, keepLonger)
		if not name then return end
		Block(name .. "\0*", seconds, keepLonger)
	end

	-- The keys one person's blocks are filed under, built once per person and
	-- kept, since IsBlocked is asked for everybody on every scan. The
	-- whole-person key sits under a table key no buff can have.
	local blockKeys, blockKeyCount = {}, 0
	local WHOLE_PERSON = {}

	local function BlockKeys(name)
		local keys = blockKeys[name]
		if keys then return keys end
		-- Bounded: a city puts hundreds of people through the scan in a session.
		if blockKeyCount >= 500 then
			wipe(blockKeys)
			blockKeyCount = 0
		end
		keys = { [WHOLE_PERSON] = name .. "\0*" }
		blockKeys[name] = keys
		blockKeyCount = blockKeyCount + 1
		return keys
	end

	-- Whether this person, or this one buff for this person, is inside a block.
	-- The whole-person key is always consulted, and so is a back-off after
	-- refusals in a row, which is a block on the whole person as well.
	function ns.IsBlocked(name, buffKey, now)
		if not name then return false end
		now = now or GetTime()
		local refused = refusals[name]
		if refused and refused.blockUntil > now then return true end
		if next(tried) == nil then return false end
		local keys = BlockKeys(name)
		local person = tried[keys[WHOLE_PERSON]]
		if person and person > now then return true end
		if not buffKey then return false end
		local key = keys[buffKey]
		if not key then
			key = name .. "\0" .. buffKey
			keys[buffKey] = key
		end
		local one = tried[key]
		return one ~= nil and one > now
	end
end

-- What the game keeps refusing, per person, and the two things that follow
-- from it. The spoken line is held for a while after any refusal: a macro runs
-- every line even when its /cast fails, so a thank-you went out over a buff
-- that never landed, once per press (beta.8). And the person backs off further
-- with each refusal in a row: somebody the game will never let you buff (the
-- server does not say why) came straight back after two seconds, forever. A
-- cast on them that lands forgets all of it (PruneSettled). A block of its own
-- for the main chunk's 200 locals.
do
	-- How long each refusal in a row keeps the person off the prompt. The first
	-- is the two seconds RewindClick has always written, so one stray refusal
	-- costs nothing new. Somebody who buffed you backs off more gently:
	-- returning the favour is the point, and the favour itself stays owed.
	local STEPS = { 2, 30, 300 }
	local OWED_STEPS = { 2, 20, 60 }
	-- The refusal in a row that says so in chat, once per run.
	local TELL_AT = 3
	-- How long the spoken line stays held after a press came to nothing, and
	-- past the end of any back-off.
	local QUIET_SECONDS = 30
	-- A run of refusals this long over is forgotten, and the sweep lets the
	-- person go: somebody never seen again must not be kept all session.
	local FORGET_SECONDS = 600
	local CAP = 200
	-- How close an error line and a refusal must be to be about the same cast.
	local ERROR_SECONDS = 1

	local lastError, lastErrorAt = nil, 0
	-- Who the newest refusal was about, for an error line arriving just after.
	local newest

	-- Errors about the caster rather than the person (out of mana, moving, the
	-- cooldown): they hold the spoken line, since nothing landed, but say nothing
	-- about whether the game will refuse this person next time. Named by the
	-- client's own global strings, since the text is localised.
	local CASTER_SIDE = { "ERR_OUT_OF_MANA", "SPELL_FAILED_MOVING", "SPELL_FAILED_NOT_READY",
		"ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN", "SPELL_FAILED_SPELL_IN_PROGRESS",
		"SPELL_FAILED_SILENCED", "SPELL_FAILED_STUNNED", "SPELL_FAILED_CASTER_DEAD",
		"SPELL_FAILED_INTERRUPTED" }

	local function AboutTheCaster(message)
		if type(message) ~= "string" then return false end
		local bare = message:gsub("%.$", "")
		for _, key in ipairs(CASTER_SIDE) do
			local text = plain(_G[key])
			if type(text) == "string" and text:gsub("%.$", "") == bare then return true end
		end
		return false
	end

	-- Said whether or not chat lines are on: it is the only thing that says
	-- why somebody vanished from the prompt.
	local function Tell(name, why)
		if type(why) == "string" then
			addon:Print(L["|cffff8080the game keeps refusing buffs on %s|r (it said: %s) -- they will not be offered for a while; target them to try again."]
				:format(name, (why:gsub("%.$", ""))))
		else
			addon:Print(L["|cffff8080the game keeps refusing buffs on %s|r -- they will not be offered for a while; target them to try again."]
				:format(name))
		end
	end

	function ns.SweepRefusals(now)
		for name, r in pairs(refusals) do
			if r.blockUntil <= now and r.quietUntil <= now and now - r.last > FORGET_SECONDS then
				refusals[name] = nil
			end
		end
	end

	-- One person's record, room made for it first. Counted here rather than
	-- kept in a tally: a new record is one refusal, so this is rare, and a
	-- count cannot drift from the table.
	local function Record(name, now)
		local r = refusals[name]
		if r then return r end
		local held, oldest, at = 0, nil, nil
		for who, rec in pairs(refusals) do
			held = held + 1
			if not at or rec.last < at then oldest, at = who, rec.last end
		end
		-- Full even so: the person refused longest ago goes.
		if held >= CAP then refusals[oldest] = nil end
		r = { count = 0, last = now, blockUntil = 0, quietUntil = 0 }
		refusals[name] = r
		return r
	end

	-- Every error line the game raises. One arriving just after a refusal that
	-- had no reason of its own is taken as that reason.
	function ns.NoteGameError(message)
		if type(message) ~= "string" then return end
		local now = GetTime()
		lastError, lastErrorAt = message, now
		local r = newest and refusals[newest]
		if r and r.why == nil and now - r.last <= ERROR_SECONDS and not AboutTheCaster(message) then
			r.why = message
		end
	end

	-- A press on this person came to nothing: an error inside the press's
	-- window, or a refusal after it was sent. `why` is the game's own words
	-- where the caller has them. `quietOnly` holds the spoken line and no more,
	-- for a press the game never answered at all: nothing refused anybody
	-- there, so it is no evidence the game will refuse them next time.
	function ns.NoteRefusal(name, why, quietOnly)
		if not name then return end
		local now = GetTime()
		if why == nil and lastError and now - lastErrorAt <= ERROR_SECONDS then why = lastError end
		local r = Record(name, now)
		-- Never shortened: a quiet note must not cut the longer hold a back-off
		-- below wrote.
		if now + QUIET_SECONDS > r.quietUntil then r.quietUntil = now + QUIET_SECONDS end
		newest = name
		if quietOnly or AboutTheCaster(why) then
			r.last = now
			return
		end
		-- A run long over was swept (SweepRefusals), so this starts again at one.
		r.last = now
		r.count = r.count + 1
		r.why = type(why) == "string" and why or nil
		local debt = owed[name]
		local steps = (debt and LiveExpiry(debt) > now) and OWED_STEPS or STEPS
		local seconds = steps[math.min(r.count, #steps)]
		if now + seconds > r.blockUntil then r.blockUntil = now + seconds end
		-- The line stays held past the back-off: somebody the game keeps refusing
		-- comes back when it runs out, and the first press then would thank them
		-- over yet another refused cast. A cast that lands clears it (NoteLanded).
		if r.blockUntil + QUIET_SECONDS > r.quietUntil then r.quietUntil = r.blockUntil + QUIET_SECONDS end
		if r.count >= TELL_AT and not r.said then
			r.said = true
			if r.why or not (C_Timer and C_Timer.After) then
				Tell(name, r.why)
			else
				-- The error line can arrive a moment after the refusal it explains.
				C_Timer.After(0.3, function() ns.Guard("refusal line", Tell, name, r.why) end)
			end
		end
	end

	-- A cast on them landed: nothing the game refused before stands.
	function ns.NoteLanded(name)
		if name then refusals[name] = nil end
	end

	-- Whether the spoken line is held for this person.
	function ns.SpeechHeld(name, now)
		local r = name and refusals[name]
		return r ~= nil and r.quietUntil > (now or GetTime())
	end

	-- The player pointed at them on purpose (PLAYER_TARGET_CHANGED): the
	-- back-off lifts, the count stays, so another refusal backs off again.
	function ns.LiftBackoff(name)
		local r = name and refusals[name]
		if r then r.blockUntil = 0 end
	end

	-- For /manners debug: who is backed off or kept quiet, and for how long.
	-- Seconds rather than a clock time: the minimap clock may be the realm's.
	function ns.RefusalLines(now)
		local out = {}
		for name, r in pairs(refusals) do
			if r.blockUntil > now then
				out[#out + 1] = L["backed off for %ds more: |cffffffff%s|r -- refused %d times in a row"]
					:format(math.ceil(r.blockUntil - now), name, r.count)
			elseif r.quietUntil > now then
				out[#out + 1] = L["no spoken line for %ds more: |cffffffff%s|r -- the game refused a cast on them"]
					:format(math.ceil(r.quietUntil - now), name)
			end
		end
		table.sort(out)
		return out
	end
end

-- The debt is paid. Written through, so a reload cannot raise it again.
function ns.SettleFavour(name)
	if not name then return end
	owed[name] = nil
	SaveDebts()
end

---------------------------------------------------------------------------
-- the never-offer list
--
-- People the player has said never to offer anything to, filed under the same
-- name debts are, in the profile. It reaches the queue at its next rebuild (in
-- a fight, the end of it); nothing here touches the button.
---------------------------------------------------------------------------

-- Defined with the favour ledger's other hook further down, and declared here
-- so the never-offer list below can tell the ledger about a favour it lets go.
local TellLedger

local function NeverSet()
	local db = addon.db and addon.db.profile
	local never = db and db.never
	if type(never) ~= "table" then return nil end
	return never
end

-- What somebody typed, tidied: the space around it off and any run of spaces
-- inside it cut to one. nil for nothing at all.
local function CleanName(name)
	if type(name) ~= "string" then return nil end
	name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
	if name == "" then return nil end
	return name
end

-- Whether a listed name matches, regardless of case, since names are typed by
-- hand. Folded by the client's strcmputf8i where there is one (string.lower
-- leaves accented capitals alone); plain lower is the fallback.
local function SameName(a, b)
	if not b then return false end
	local fold = _G.strcmputf8i
	if type(fold) == "function" then
		local ok, cmp = pcall(fold, a, b)
		if ok and type(cmp) == "number" then return cmp == 0 end
	end
	return a:lower() == b:lower()
end
ns.SameName = SameName

-- Whether a sorts before b, case folded the same way SameName folds it, so a
-- name typed in small letters sorts among the capitalised ones in any script.
-- Not full collation (Ё still sorts apart from Е). Ties fall back to lower and
-- then to bytes, so the order is total, which table.sort needs.
local function NameBefore(a, b)
	local fold = _G.strcmputf8i
	if type(fold) == "function" then
		local ok, cmp = pcall(fold, a, b)
		if ok and type(cmp) == "number" and cmp ~= 0 then return cmp < 0 end
	end
	local la, lb = a:lower(), b:lower()
	if la ~= lb then return la < lb end
	return a < b
end

-- What the list walk has already answered, by name: the entry, or false. The
-- scan asks about everybody 2.5 times a second, two case-folded compares per
-- entry. Checked against a copy of the list rather than cleared by an editor,
-- because imports, profile switches and the scenarios write the table directly;
-- a different fold function throws the answers away too. `scan` is the answers
-- while BuildQueue walks the units, nil otherwise. One table for the main
-- chunk's 200 locals.
local neverSeen = {
	list = nil, fold = nil, size = 0, copy = {}, verdict = {}, count = 0,
	max = 1000, scan = nil,
}

-- The answers, valid for the list as it stands now. nil when there is no list.
local function NeverVerdicts()
	local never = NeverSet()
	if not never then return nil end
	local copy, fold = neverSeen.copy, _G.strcmputf8i
	local fresh = neverSeen.list == never and neverSeen.fold == fold
	if fresh then
		local size = 0
		for key, flag in pairs(never) do
			if copy[key] ~= flag then fresh = false break end
			size = size + 1
		end
		if size ~= neverSeen.size then fresh = false end
	end
	if not fresh then
		wipe(copy)
		local size = 0
		for key, flag in pairs(never) do
			copy[key] = flag
			size = size + 1
		end
		neverSeen.list, neverSeen.fold, neverSeen.size = never, fold, size
		wipe(neverSeen.verdict)
		neverSeen.count = 0
	end
	return neverSeen.verdict
end

-- The entry on the list that names this person, or nil: exact, then regardless
-- of case, then with the realm taken off the name (as the prompt shows it) --
-- never the other way round. `verdict` is NeverVerdicts' table, passed only by
-- the scan; anybody else walks the list.
local function ListedAs(name, verdict)
	local never = NeverSet()
	if not never or type(name) ~= "string" or next(never) == nil then return nil end
	if never[name] == true then return name end
	if verdict then
		local known = verdict[name]
		if known ~= nil then return known or nil end
	end
	local short = ShortName(name)
	local found
	for key in pairs(never) do
		if type(key) == "string" then
			if SameName(key, name) or SameName(key, short) then found = key break end
		end
	end
	if verdict then
		-- Bounded like the other per-person caches.
		if neverSeen.count >= neverSeen.max then
			wipe(verdict)
			neverSeen.count = 0
		end
		verdict[name] = found or false
		neverSeen.count = neverSeen.count + 1
	end
	return found
end
ns.ListedAs = ListedAs

function ns.IsNeverOffered(name)
	return ListedAs(name, neverSeen.scan) ~= nil
end

-- Puts somebody on the list. Returns the spelling now on it, and whether they
-- were already there (whose spelling is kept, so nobody is listed twice).
function ns.NeverOffer(name)
	name = CleanName(name)
	local never = NeverSet()
	if not name or not never then return nil end
	local already = ListedAs(name)
	if already then return already, true end
	never[name] = true
	return name, false
end

-- Takes somebody off. Returns the spelling that came off, or nil when nobody
-- on the list answers to that name.
function ns.AllowAgain(name)
	local listed = ListedAs(CleanName(name))
	if not listed then return nil end
	NeverSet()[listed] = nil
	return listed
end

-- Everybody on it, sorted the way a reader looks for a name.
function ns.NeverList()
	local names = {}
	for name, flag in pairs(NeverSet() or {}) do
		if flag == true then names[#names + 1] = name end
	end
	table.sort(names, NameBefore)
	return names
end

function ns.ClearNeverList()
	local never = NeverSet()
	if never then wipe(never) end
end

-- Puts somebody on the list as a deliberate act (a shift-right-click on the
-- prompt, /manners never, the options box) and always says so, whatever Tell
-- me in chat is set to, since it is where the way back is written down.
-- Returns the spelling on the list, or nil for a name that was only space.
--
-- A favour they are owed goes with them, even when already listed: owed people
-- are exempt from the list (STATUS.md), so they would otherwise come straight
-- back once the skip ran out. Their next favour is offered as usual.
function ns.PutOnNeverList(name)
	local listed, already = ns.NeverOffer(name)
	if not listed then return nil end

	local forgiven = false
	-- Matched against the one entry just listed, by ListedAs' rule, rather than
	-- walking the whole list once per favour.
	for key in pairs(owed) do
		if SameName(listed, key) or SameName(listed, ShortName(key)) then
			owed[key] = nil
			forgiven = true
			-- The ledger's row goes with the debt: its own sweep walks the
			-- debts and could never reach one let go here.
			TellLedger("LetGo", key, "never")
		end
	end
	-- Repainted here too, since somebody already listed never reaches the end.
	if forgiven then
		SaveDebts()
		ns.RepaintOptions()
	end

	-- In a fight the secure button cannot be re-armed, so if the prompt names
	-- the person just listed, a press still casts at them until it ends, and
	-- the line has to say so. Guarded: Prompt.lua may not have loaded.
	local onPromptInFight = false
	if InCombatLockdown() and ns.Prompt and ns.Prompt.Showing then
		ns.Guard("never-offer prompt check", function()
			local showing = ns.Prompt:Showing()
			onPromptInFight = type(showing) == "table" and type(showing.name) == "string"
				and ListedAs(showing.name) == listed
		end)
	end

	if already then
		if forgiven and onPromptInFight then
			addon:Print(L["|cffffffff%s|r is already on your never-offer list, and the favour they did you is let go -- but the prompt cannot move off them in this fight, and a press still casts at them."]
				:format(listed))
		elseif onPromptInFight then
			addon:Print(L["|cffffffff%s|r is already on your never-offer list -- but the prompt cannot move off them in this fight, and a press still casts at them."]
				:format(listed))
		elseif forgiven then
			addon:Print(L["|cffffffff%s|r is already on your never-offer list, and the favour they did you is let go."]
				:format(listed))
		else
			addon:Print(L["|cffffffff%s|r is already on your never-offer list."]:format(listed))
		end
		return listed
	end

	-- The way back goes in whole: it is typed exactly as shown in every language.
	local undo = "/manners allow " .. listed
	if forgiven and onPromptInFight then
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you, and their favour is let go -- but in this fight a press still casts at them. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	elseif onPromptInFight then
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you -- but the prompt cannot move off them in this fight, and a press still casts at them. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	elseif forgiven then
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you, and the favour they just did you is let go. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	else
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	end
	ns.RepaintOptions()
	return listed
end

---------------------------------------------------------------------------
-- friends and guildmates
--
-- For "Who comes first". Every answer here is a preference about order, never
-- a reason to offer or drop anybody, so anything the client will not say --
-- an API that is missing, one that throws, a value withheld as a secret -- is
-- read as "not a friend" and the person is ranked like everybody else.
---------------------------------------------------------------------------

-- The section's two entry points. Everything else is private to the block
-- below, whose locals are released at its end: the main chunk is close to
-- the 200 locals Lua 5.1 allows one function.
local SweepCloseness, Closeness
do
	-- How long an answer about one person is kept: a friends list changes over
	-- minutes, and the scan asks about everybody two and a half times a second.
	local CLOSE_SECONDS = 10
	local closeCache = {}
	-- The friends list by lower-cased name and by GUID, and when it was read.
	local friendNames, friendGuids, friendsReadAt = {}, {}, nil

	-- The fallback for a client whose C_FriendList has no IsFriend: the list read
	-- by index, the way the addons known to work on this client read it.
	local function ReadFriendsList(now)
		if friendsReadAt and now - friendsReadAt < CLOSE_SECONDS then return end
		friendsReadAt = now
		wipe(friendNames)
		wipe(friendGuids)
		local list = _G.C_FriendList
		if type(list) ~= "table" then return end
		local count = safecall(list.GetNumFriends)
		if type(count) ~= "number" then return end
		-- The game caps a friends list well below this; the bound is there so a
		-- nonsense count cannot turn one scan into a very long one.
		for i = 1, math.min(count, 200) do
			local info = safecall(list.GetFriendInfoByIndex, i)
			if type(info) == "table" then
				local name, guid = plain(info.name), plain(info.guid)
				if type(name) == "string" then friendNames[name:lower()] = true end
				if type(guid) == "string" then friendGuids[guid] = true end
			end
		end
	end

	-- Old answers go, once per lifetime of an answer: Closeness checks an answer's
	-- age before trusting it, so one left standing a little longer is never used.
	local closeSweptAt

	function SweepCloseness(now)
		if closeSweptAt and now >= closeSweptAt and now - closeSweptAt < CLOSE_SECONDS then return end
		closeSweptAt = now
		for name, answer in pairs(closeCache) do
			if now - answer.at >= CLOSE_SECONDS then closeCache[name] = nil end
		end
	end

	-- GetGuildInfo's realm as something to compare: "" for your own realm, which
	-- it answers as nil, and nil (matching nothing) for a secret or nonsense.
	local function GuildRealm(realm)
		if issecretvalue and issecretvalue(realm) then return nil end
		if realm == nil then return "" end
		if type(realm) ~= "string" then return nil end
		return realm
	end

	-- "friend", "guild", or nil for neither and for could-not-tell alike; a
	-- friend is the more particular thing for the tooltip to say, so first.
	-- The GUID goes to the client as handed over, secret or not (the friends
	-- API may still take it); it is never compared or read here, because a
	-- secret throws on both.
	function Closeness(unit, full, now)
		local cached = closeCache[full]
		if cached and now - cached.at < CLOSE_SECONDS then return cached.kind or nil end

		local kind
		local rawGuid = UnitGUID(unit)
		local list, bnet = _G.C_FriendList, _G.C_BattleNet
		if type(list) == "table" and safecall(list.IsFriend, rawGuid) == true then
			kind = "friend"
		elseif type(bnet) == "table"
			and type(safecall(bnet.GetGameAccountInfoByGUID, rawGuid)) == "table" then
			-- Answers for Battle.net friends and nobody else; the Camelot social
			-- addon accepts group invites from friends on exactly this.
			kind = "friend"
		else
			ReadFriendsList(now)
			local guid = plain(rawGuid)
			if (type(guid) == "string" and friendGuids[guid])
				or friendNames[full:lower()]
				or friendNames[(ns.TargetName(full) or full):lower()] then
				kind = "friend"
			end
		end

		if not kind then
			local inMine
			if type(_G.UnitIsInMyGuild) == "function" then
				local ok, answer = pcall(_G.UnitIsInMyGuild, unit)
				if ok then inMine = plain(answer) end
			end
			if inMine == true then
				kind = "guild"
			elseif inMine == nil then
				-- Only where UnitIsInMyGuild gave no answer (a plain no is an
				-- answer): the two guild names, when both are readable, and their
				-- realms, since a guild's name is only unique on its realm. pcall
				-- rather than safecall, which keeps only three returns and the
				-- realm is the fourth.
				local okTheirs, theirs, _, _, theirRealm = pcall(_G.GetGuildInfo, unit)
				local okOurs, ours, _, _, ourRealm = pcall(_G.GetGuildInfo, "player")
				theirs, ours = plain(theirs), plain(ours)
				theirRealm, ourRealm = GuildRealm(theirRealm), GuildRealm(ourRealm)
				if okTheirs and okOurs and type(theirs) == "string" and theirs ~= ""
					and theirs == ours and theirRealm and theirRealm == ourRealm then
					kind = "guild"
				end
			end
		end

		closeCache[full] = { at = now, kind = kind or false }
		return kind
	end
end

-- Tell the favour ledger (Ledger.lua) what just happened to a favour. One way
-- only, so it never changes who is offered what, and guarded so a ledger that
-- throws cannot take a settle or a sweep with it. Not a global: this assigns
-- the local declared above the never-offer list.
function TellLedger(event, ...)
	local ledger = ns.Ledger
	local fn = ledger and ledger[event]
	if type(fn) == "function" then ns.Guard("ledger " .. event, fn, ...) end
	-- "In character" counts the exchanges with each person this session from
	-- the same four moments, for its lines about meeting somebody again.
	local heard = ns.InCharacter and ns.InCharacter.Heard
	if type(heard) == "function" then ns.Guard("in character " .. event, heard, event, ...) end
	-- The launcher counts the favours waiting to be returned.
	if ns.RefreshBrokerText then ns.Guard("broker text", ns.RefreshBrokerText) end
end
ns.TellLedger = TellLedger

-- Somebody who asked comes after the people who buffed you and before your
-- group. One and a half rather than a renumbering, so the other numbers keep
-- meaning what they mean in the sort, the prompt's hold and bug reports.
local PRIORITY = { target = 0, owed = 1, asked = 1.5, group = 2, nearby = 3 }
-- A group member put first by a ready check or by coming back from the dead:
-- behind your deliberate target, ahead of everybody else.
PRIORITY.sweep = 0.5

-- The group's unit tokens, spelled out once rather than joined on every scan.
local GROUP_TOKENS = { raid = {}, party = {} }
for i = 1, 40 do
	GROUP_TOKENS.raid[i] = "raid" .. i
	GROUP_TOKENS.party[i] = "party" .. i
end

-- fn(unit, pointed). `pointed` marks a unit the player deliberately picked out:
-- target and focus, which stand until the player changes them. Mouseover is
-- wherever the cursor happens to be, and counting it would flash distant
-- strangers onto the prompt. Focus comes before mouseover because one verdict
-- is reached per person per scan, on whichever token reaches them first.
local function IterateUnits(fn)
	fn("target", true)
	fn("focus", true)
	fn("mouseover")

	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n > 0 then
		local inRaid = plain(IsInRaid and IsInRaid()) == true
		local prefix = inRaid and "raid" or "party"
		local tokens = GROUP_TOKENS[prefix]
		local count = inRaid and n or (n - 1)
		for i = 1, count do
			fn(tokens[i] or (prefix .. i))
		end
	end

	-- namePlateUnitToken read off the frame comes back as a secret value on
	-- this client, so the frames are useless for enumeration. The token handed
	-- to NAME_PLATE_UNIT_ADDED is not, so we keep our own list from the events
	-- and only fall back to the frames if that list is empty.
	local plated = 0
	for token in pairs(ns.nameplateUnits) do
		if plain(UnitExists(token)) then
			plated = plated + 1
			fn(token)
		else
			ns.nameplateUnits[token] = nil
		end
	end

	if plated == 0 and caps.namePlates then
		local plates = safecall(C_NamePlate.GetNamePlates)
		if type(plates) == "table" then
			for _, plate in pairs(plates) do
				local token = plate and plain(plate.namePlateUnitToken)
				if token then fn(token) end
			end
		end
	end
end

---------------------------------------------------------------------------
-- dungeons and raids
--
-- Two moments put a group member missing your buff at the front: a ready
-- check, which is when a buffer sweeps the group before a pull, and coming
-- back from the dead, which costs every buff. And two limits on offers nobody
-- asked for: the mana you keep for yourself, and the raid groups you were
-- given. A favour owed and a request from chat are never held back by either.
---------------------------------------------------------------------------

-- How long a ready check counts as running when the client names no time, or
-- a nonsense one: the game's own lasts 35 seconds.
local READY_CHECK_SECONDS = 35
-- How long somebody back from the dead stays at the front: long enough to be
-- rezzed, to stand up and to be buffed, short enough to be about the death.
local REVIVED_SECONDS = 120

-- readyUntil: when the running ready check ends, or nil. down: [unit token] =
-- the name read when it was seen dead (false when none could be read). revived:
-- [name] = GetTime() they were seen alive again. prefix: which tokens `down`
-- is about. One table for the main chunk's 200 locals.
local sweep = { readyUntil = nil, down = {}, revived = {}, prefix = nil }

-- READY_CHECK hands over who started it and the seconds it runs for. Either
-- end of the check repaints at once rather than at the next scan: a ready
-- check lasts seconds, and the prompt should move as it starts.
function addon:READY_CHECK(_, _, timeLeft)
	local seconds = plain(timeLeft)
	if type(seconds) ~= "number" or seconds <= 0 or seconds > 120 then seconds = READY_CHECK_SECONDS end
	sweep.readyUntil = GetTime() + seconds
	if ns.Prompt then ns.Guard("ready check", ns.Prompt.Refresh, ns.Prompt) end
end

function addon:READY_CHECK_FINISHED()
	sweep.readyUntil = nil
	if ns.Prompt then ns.Guard("ready check over", ns.Prompt.Refresh, ns.Prompt) end
end

function ns.ReadyCheckRunning(now)
	local untilAt = sweep.readyUntil
	return untilAt ~= nil and untilAt > (now or GetTime())
end

-- Who in the group has just come back from the dead. Walked on every scan tick
-- rather than on UNIT_HEALTH, which in a raid fires hundreds of times a second
-- in a fight: forty yes-or-no questions every 0.4 seconds is cheaper, and the
-- tick runs in fights and while you are dead yourself, which the queue's walk
-- does not. A withheld answer (a secret) is no answer, so nothing changes on
-- it. The name is read only when somebody dies or stands up, and checked
-- again then, since a roster change can hand the token to somebody else.
function ns.WatchGroupDeaths(now)
	local db = addon.db and addon.db.profile
	local down, revived = sweep.down, sweep.revived
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if not (db and db.priority.revived == true) or n <= 0 then
		sweep.prefix = nil
		if next(down) then wipe(down) end
		if next(revived) then wipe(revived) end
		return
	end

	local inRaid = plain(IsInRaid and IsInRaid()) == true
	local prefix = inRaid and "raid" or "party"
	-- A party that became a raid renumbered everybody.
	if prefix ~= sweep.prefix then
		wipe(down)
		sweep.prefix = prefix
	end
	local tokens = GROUP_TOKENS[prefix]
	local count = math.min(inRaid and n or (n - 1), 40)
	for i = 1, count do
		local unit = tokens[i]
		local dead = plain(UnitIsDeadOrGhost(unit))
		if dead == true then
			if down[unit] == nil then down[unit] = ns.UnitFullName(unit) or false end
		elseif dead == false and down[unit] ~= nil then
			local was = down[unit]
			down[unit] = nil
			if was and ns.UnitFullName(unit) == was then revived[was] = now end
		end
	end
	-- Tokens past the end of a group that shrank.
	for unit in pairs(down) do
		local index = tonumber(unit:match("(%d+)$"))
		if not index or index > count then down[unit] = nil end
	end
	for name, at in pairs(revived) do
		if now - at >= REVIVED_SECONDS then revived[name] = nil end
	end
end

-- Why this group member goes to the front now, or nil: "readycheck" or
-- "revived". `ready` is the scan's reading of the ready check.
local function SweepReason(name, now, ready, db)
	if ready then return "readycheck" end
	local at = db.priority.revived == true and sweep.revived[name]
	if at and now - at < REVIVED_SECONDS then return "revived" end
	return nil
end

-- The raid group (1-8) a unit is in, or nil when it cannot be told. A raid
-- token's number is its place on the roster; any other token asks UnitInRaid,
-- as SameParty does.
local function RaidGroupOf(unit)
	local index = tonumber(unit:match("^raid(%d+)$")) or plain(UnitInRaid and UnitInRaid(unit))
	if type(index) ~= "number" then return nil end
	local _, _, group = safecall(_G.GetRaidRosterInfo, index)
	if type(group) ~= "number" then return nil end
	return group
end

-- The share of your mana "Keep this much mana for yourself" keeps back, while
-- it is holding back offers nobody asked for; nil when it is not (off, a class
-- with no mana bar, or a reading the client withheld, which offers as before).
function ns.SavingMana()
	local db = addon.db and addon.db.profile
	local floor = db and db.filters and db.filters.manaFloor
	if type(floor) ~= "number" or floor <= 0 then return nil end
	local most = plain(UnitPowerMax("player", MANA))
	if type(most) ~= "number" or most <= 0 then return nil end
	local mana = plain(UnitPower("player", MANA))
	if type(mana) ~= "number" then return nil end
	if mana * 100 < floor * most then return floor end
	return nil
end

-- Whether "Not while mounted" is keeping the prompt away right now: one answer
-- for the queue, a keypress on the empty prompt and /manners debug. A withheld
-- answer counts as not mounted, so the switch can hide the prompt but never
-- lose it.
function ns.HiddenWhileMounted()
	local db = addon.db and addon.db.profile
	if not (db and db.filters and db.filters.hideMounted == true) then return false end
	if type(IsMounted) ~= "function" then return false end
	return plain(safecall(IsMounted)) == true
end

-- PickBuffFor's two callbacks for the queue, at file level so that no person
-- costs a closure. The tokenless path has no aura to read, hence NoReading.
local function QueueBlocked(candidate, opts)
	return ns.IsBlocked(opts.name, candidate.key, opts.now)
end

local function NoReading()
	return nil
end
ns.NoReading = NoReading

function ns.BuildQueue()
	local db = addon.db and addon.db.profile
	if not db or not caps.anyKnown then return {} end

	-- Nothing can be cast while dead, in a vehicle, or on a taxi, so offering
	-- somebody would just be a button that fails.
	if plain(UnitIsDeadOrGhost("player")) == true then return {} end
	if plain(UnitIsCharmed and UnitIsCharmed("player")) == true then return {} end
	if UnitInVehicle and plain(UnitInVehicle("player")) == true then return {} end
	if UnitOnTaxi and plain(UnitOnTaxi("player")) == true then return {} end
	-- A mount is different: the cast works and takes you off it. So it is
	-- the player's call, and only asked when they have made it.
	if ns.HiddenWhileMounted() then return {} end

	local now = GetTime()
	local seen, queue = {}, {}
	-- Anybody the main path looked at and turned down. The owed fallback below
	-- holds no unit token and cannot repeat those judgements, so it reads this.
	local rejected = {}
	local f = db.filters

	-- Per scan, so /manners debug and the options page report the crowd in
	-- front of the player now. The run-of-silence count that demotes a source
	-- is deliberately not reset: forty units over ten scans is the same
	-- evidence as forty in one.
	prox.asked, prox.answered = 0, 0

	-- Everything below until the walk is asked once per scan, not per person.
	local candidates = ns.CastableBuffs()
	if #candidates == 0 then return {} end
	-- A warrior's shout reaches the group and nobody else, so passers-by are
	-- dropped before the distance check rather than measured for nothing
	-- (which would fill the proximity counts with people never offered).
	local groupOnly = ns.OnlyReachesGroup(candidates)
	local inRaid = plain(IsInRaid and IsInRaid()) == true
	-- The never-offer list's answers so far; see NeverVerdicts.
	local neverVerdict = NeverVerdicts()

	-- Offers nobody asked for, held back while you keep your mana and, in a
	-- raid, for the groups you were not given; and whether a ready check has
	-- the group first. See "dungeons and raids". Once per scan.
	local savingMana = ns.SavingMana() ~= nil
	local skipGroups
	if inRaid and type(f.skipRaidGroups) == "table" and next(f.skipRaidGroups) ~= nil then
		skipGroups = f.skipRaidGroups
	end
	local readyCheck = db.priority.readyCheck == true and ns.ReadyCheckRunning(now)

	-- Passers-by left alone out in the world, when asked: only a definite "not
	-- resting" does it, and could-not-tell offers them.
	local notResting = f.restingOnly == true and Resting() == false
	-- Nobody is asked about friends when Who comes first is off, which is most
	-- of its cost.
	local friendsFirst = db.priority.friends == true
	if friendsFirst then SweepCloseness(now) end

	-- A buff that cannot be paid for is a button that fails -- but only classes
	-- with a mana bar can run out: a warrior's mana reads a permanent 0.
	local myMax = plain(UnitPowerMax("player", MANA))
	if myMax and myMax > 0 then
		local myMana = plain(UnitPower("player", MANA))
		if myMana ~= nil and myMana <= 0 then return {} end
	end

	-- What PickBuffFor is told about the person in hand, one table reused for
	-- everybody the walk reaches.
	local opts = {}

	local function visit(unit, pointed)
		local ok, person = IsBuffableUnit(unit, f)
		if not ok then
			-- Somebody turned down here must not walk back in through the
			-- fallback, which cannot check any of this. The name costs a call,
			-- so only when a debt outstanding could resurface.
			if person and next(owed) then
				local bad = ns.UnitFullName(unit)
				if bad then rejected[bad] = true end
			end
			return
		end

		local full = ns.UnitFullName(unit)
		if not full then return end
		-- One verdict per person per scan, whichever way it went: somebody in
		-- front of you is commonly both your target and a nameplate.
		if seen[full] or rejected[full] then return end
		-- The whole-person block: a right-press skip, or a press that reached
		-- nobody, so we do not march down the list failing at each buff.
		if ns.IsBlocked(full, nil, now) then return end

		local inGroup = plain(UnitInParty and UnitInParty(unit)) or plain(UnitInRaid and UnitInRaid(unit))
		local isOwed = db.sources.owed and owed[full] and LiveExpiry(owed[full]) > now

		-- The never-offer list, for everybody but a person owed a favour. That
		-- exception is a decision (STATUS.md), and the options page says so:
		-- returning a favour is what the addon is for. Safe to write into
		-- `rejected`: nobody reaching this line is owed anything the fallback
		-- could offer, since it asks the same two questions isOwed just did.
		if not isOwed and ns.IsNeverOffered(full) then
			rejected[full] = true
			return
		end

		-- What they asked for in chat, of what this character casts; nil for
		-- nobody and for anybody owed, whose favour is the better reason.
		-- Below the never-offer list on purpose: asking is not the exception
		-- buffing you is.
		local asked = not isOwed and ns.AskedFor(unit, full, now, candidates) or nil

		-- Decide whether we would offer this person at all before reading any
		-- auras, which is the expensive part. A request is a source of its own:
		-- the group and passer-by switches, the nearness and city checks do
		-- not apply to it. Casting range still does, further down.
		local reason = isOwed and "owed" or (asked and "asked") or (inGroup and "group" or "nearby")
		if reason == "group" and not db.sources.group then return end
		if reason == "nearby" and not db.sources.strangers then return end
		if reason == "nearby" and groupOnly then return end

		-- Nobody asked for these, so they wait while you keep your mana. A
		-- favour owed or a request never reaches here as group or nearby.
		if savingMana and (reason == "group" or reason == "nearby") then return end
		-- In a raid, only the groups you buff. Whoever you picked out on
		-- purpose is exempt, as from the city rule below; a group that cannot
		-- be read is offered.
		if skipGroups and reason == "group" and not pointed then
			local group = RaidGroupOf(unit)
			if group and skipGroups[group] then return end
		end
		-- A group member the game says is out of sight -- still in town while
		-- the raid is inside, or a long way off in it -- is out of range for
		-- certain, which this client's range check often will not say.
		if reason == "group" and f.requireInRange
			and plain(UnitIsVisible and UnitIsVisible(unit)) == false then
			return
		end

		-- Passers-by only in a city or an inn, when that is asked for. A stranger
		-- you targeted or focused you picked on purpose, and is exempt.
		if reason == "nearby" and not pointed and notResting then
			rejected[full] = true
			return
		end

		-- A passer-by has to be near, not merely castable on. The other reasons
		-- carry their own evidence of nearness, and so does a pointed unit. Above
		-- the aura read on purpose: in a crowd, one distance check is much
		-- cheaper than a walk down somebody's auras.
		if reason == "nearby" and not pointed and ns.NearEnough(unit) == false then
			rejected[full] = true
			return
		end

		local hasMana = UnitHasMana(unit)
		local guid = plain(UnitGUID(unit))
		local whenBuffed = f.whenBuffed or "skip"
		local checked = whenBuffed ~= "always"

		-- The client's answer, and nothing else: a policy (offer the owed
		-- regardless) must never be written as a reading, or PickBuffFor takes
		-- it for the client saying nothing landed. Choosing not to look answers
		-- nil, not false, since the walk stops at the first definite gap.
		local function auraState(buff)
			if not checked then return nil end
			return UnitHasBuff(unit, buff, guid)
		end

		-- Every field written for every person; PickBuffFor keeps nothing.
		-- Somebody who asked gets only what they asked for, relevant to them or
		-- not (a warrior may want Intellect), but never when already covered.
		opts.hasMana = hasMana
		opts.inGroup = inGroup
		-- Who a shout reaches, which in a raid is not the group: see
		-- SameParty. inGroup stays the reason on the card.
		opts.inParty = SameParty(unit, inRaid)
		opts.relevantOnly = f.relevantOnly and not asked
		opts.whenBuffed = whenBuffed
		opts.refreshUnder = f.refreshUnder
		opts.name = full
		-- Owing somebody means offering them even when covered: a decision about
		-- who gets an offer, saying nothing about what their auras read.
		opts.offerAnyway = isOwed
		-- Blocked for this person and this buff; reads name and now off opts.
		opts.blocked = QueueBlocked
		opts.now = now
		local buff, has, remaining = ns.PickBuffFor(asked or candidates, opts, auraState)

		if not buff then rejected[full] = true return end
		if not checked then has = nil end

		local ranged = InRange(unit, buff)
		-- A shout has no range for InRange to measure, so whatever can say how
		-- far off they are is asked instead, and the answer rides on the entry
		-- to the press: a shout nothing measured repays nobody.
		if ranged == nil and buff.selfCast then ranged = ShoutReach(unit) end
		if f.requireInRange and ranged == false then rejected[full] = true return end

		-- A deliberate target outranks a debt, but only once their auras were
		-- read and the buff found missing; promoting a guess would put somebody
		-- covered above a person who really buffed you. Being owed stays the
		-- better line for the prompt to say, so an owed target keeps it, and so
		-- does somebody who asked (the order comes from the priority, the words
		-- from the reason). Switchable: some players target to inspect.
		local priority = PRIORITY[reason]
		if unit == "target" and db.priority.target
			and not isOwed and checked and has == false then
			if not asked then reason = "target" end
			priority = PRIORITY.target
		end

		-- A group member put first by a ready check or by coming back from the
		-- dead -- but, as for a target, only once their auras were read and the
		-- buff found missing or running out: a guess must not jump the queue.
		-- The reason stays, so somebody owed still says so.
		local swept
		if inGroup and checked and (has == false or remaining ~= nil) then
			swept = SweepReason(full, now, readyCheck, db)
			if swept and priority > PRIORITY.sweep then priority = PRIORITY.sweep end
		end

		-- Asked last, since the answer only orders the queue, and not for a
		-- favour owed or your target, who outrank everybody it could pass.
		local close
		if friendsFirst and (reason == "group" or reason == "nearby") then
			close = Closeness(unit, full, now)
		end

		seen[full] = true
		queue[#queue + 1] = {
			name = full,
			short = ShortName(full),
			-- The spelling the macro's /target line carries, which is not always
			-- the name they are filed under: off Camelot a cross-realm player is
			-- keyed "Mort-Ravencrest" and targeted as "Mort".
			targetName = ns.TargetName(full),
			unit = unit,
			class = plain(select(2, UnitClass(unit))),
			buff = buff,
			reason = reason,
			-- Whether they are in the group, which `reason` stops saying once
			-- they are owed or targeted; the ledger files by it.
			inGroup = not not inGroup,
			priority = priority,
			ranged = ranged,
			known = has,
			-- How long what they carry has left, set only for a top-up.
			remaining = remaining,
			-- false when we chose not to look, as opposed to looked and were
			-- refused. Only the second is the client's doing.
			checked = checked,
			-- "friend" or "guild" where Who comes first asked; the sort and the
			-- tooltip read it.
			close = close,
			-- "readycheck" or "revived" when that put them first; the reason
			-- line and the tooltip say so.
			sweep = swept,
		}
	end

	-- The never-offer list's answers stand for the length of the walk only:
	-- the list may be edited between two scans. So the walk is protected, the
	-- answers withdrawn whichever way it ends, and a failure goes on as before.
	neverSeen.scan = neverVerdict
	local walked, walkError = pcall(IterateUnits, visit)
	neverSeen.scan = nil
	if not walked then error(walkError, 0) end

	-- Somebody who buffed you and holds no token we can see is the ordinary
	-- case: a passing stranger rarely shows a nameplate. The macro's /target
	-- line still reaches them ([@Name] would not: it resolves only for group
	-- members), and buffing you proved they were in range, so they are offered
	-- for a short grace window and then let go.
	if db.sources.owed then
		local grace = db.timing.graceSeconds or 45
		-- One table for every favour below; only what differs between two
		-- people is written inside the loop.
		local tokenless = {
			-- No token, so no telling whether they are in the group; a
			-- party-only buff would be a button that fails.
			inGroup = false,
			inParty = false,
			relevantOnly = f.relevantOnly,
			-- No aura reading either, so never rotate past what they may
			-- already be carrying.
			whenBuffed = "skip",
			rotate = false,
		}
		for full, entry in pairs(owed) do
			-- And only for a favour noticed since the last loading screen (see
			-- PLAYER_ENTERING_WORLD); the debt stays, for a token to find them.
			-- Both are "probably gone", so neither applies with that option off.
			local fresh = not db.filters.reachableOnly
				or ((not ns.zonedAt or entry.at >= ns.zonedAt) and (now - entry.at) <= grace)
			if LiveExpiry(entry) > now and fresh and not seen[full] and not rejected[full]
				and SafeForMacro(full) and not ns.IsBlocked(full, nil, now) then
				-- Resolved per person, through the same filters as the main
				-- path. Class is all this path has; a tokenless entry can never
				-- be level- or death-checked.
				local hasMana
				if entry.class then hasMana = MANA_CLASSES[entry.class] == true end

				tokenless.hasMana = hasMana
				tokenless.name = full
				local buff = ns.PickBuffFor(candidates, tokenless, NoReading)

				-- One buff per favour: nothing here can verify the first landed.
				-- selfCast is excluded: a shout is judged repaid on whether the
				-- press measured them inside its reach, and with no token here
				-- there is nothing to measure -- they may be a zone away.
				if buff and not buff.selfCast and not ns.IsBlocked(full, buff.key, now) then
					queue[#queue + 1] = {
						name = full,
						short = ShortName(full),
						-- From the key, since this path has no unit to ask.
						targetName = ns.TargetName(full),
						class = entry.class,
						buff = buff,
						reason = "owed",
						priority = PRIORITY.owed,
						-- ranged and known are left unwritten: a constructor sizes
						-- the table for every field it names. No token means nothing
						-- read, the client's doing, so `checked` follows the setting.
						checked = (f.whenBuffed or "skip") ~= "always",
					}
				end
			end
		end
	end

	table.sort(queue, function(a, b)
		if a.priority ~= b.priority then return a.priority < b.priority end
		local ar = a.ranged == true and 0 or (a.ranged == nil and 1 or 2)
		local br = b.ranged == true and 0 or (b.ranged == nil and 1 or 2)
		if ar ~= br then return ar < br end
		-- Friends first inside a kind of offer, never across one, and below the
		-- range key: a friend out of reach must not lead with a cast that fails
		-- (STATUS.md). With Who comes first off this is always a tie.
		if (a.close ~= nil) ~= (b.close ~= nil) then return a.close ~= nil end
		return (a.name or "") < (b.name or "")
	end)

	return queue
end
