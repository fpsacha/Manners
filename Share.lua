-- Manners -- sharing a group with other Manners users.
--
-- Two priests in one party, each with Manners, were both sent to put Fortitude
-- on the same member. Here every Manners says a small hello to its group over
-- the addon channel, and from the hellos each one works out the same split of
-- the group, with nothing negotiated: the sums are made from what both sides
-- hold (who said hello, the roster, everybody's GUID).
--
--   the hello    "H1;build;CLASS;flags;groups;guid;keys" on PARTY or RAID,
--       never a whisper: the build, the class, `g` while this Manners offers
--       its group and shares it (and `q` on a first hello: say hello back),
--       the raid groups it buffs (Who to buff's, as bits), the sender's GUID,
--       and the buff keys it casts for others, a `+` after one whose group
--       version it can cast. Said on joining a group, at login, when somebody
--       new is on the roster, when any of it changes, and in answer to a `q`:
--       never more than one in GAP seconds, never in a fight, never while the
--       client holds chat back (C_ChatInfo.InChatMessagingLockdown). The
--       client allows 255 bytes a message and a burst of ten messages a
--       prefix, one more a second (SendAddonMessageResult: AddonMessageThrottle
--       and AddOnMessageLockdown say no); a hello is under 240 bytes and one
--       in ten seconds.
--   the split    per buff key, among the users of the player's class who cast
--       that key, sorted by GUID. In a raid the occupied subgroups are dealt
--       among them in turn (among those whose own raid groups take that
--       subgroup); in a party the members who are not users, sorted by GUID.
--       A user is always in their own share. A buff that lands on the whole
--       party however it is aimed (a shout; any group buff on Mists and
--       retail) has one caster and no shares: the first user of the order.
--       For a class whose buffs replace one another (a paladin) the order
--       starts one further on for each key, so two paladins give one member
--       two blessings and not the same one twice.
--   what it holds back    only an offer nobody asked for, to a member of the
--       group who is in another user's share for that buff (Queue.lua,
--       visit); another buff of yours that is not theirs is offered in its
--       place (ShareOther). A favour owed, a request, your target and your
--       focus are never held.
--   nobody goes without    a member held back for GRACE seconds out of a
--       fight, still missing the buff, is offered anyway. A user who leaves,
--       goes offline or dies is out of the split at the next scan; one that
--       never said hello was never in it.
--   group casts    one user casts: in a raid whose group version reaches one
--       subgroup, whoever has that subgroup; otherwise the first user of the
--       order who can cast it. That one counts everybody the cast would cover,
--       the others' shares too (kept for the fold alone, as Queue.lua keeps
--       the members out of a single cast's reach); the others never fold it.
--
-- A hello is another player's word: every field is checked for length and
-- shape, the sender has to be somebody in the group, of the class it says,
-- and nothing it says changes anything but the split.

local ns = select(2, ...)
local L = ns.L
local addon = ns.addon
local plain = ns.plain

local PREFIX, TAG = "Manners", "H1"
-- Seconds a member of another user's share may go without before they are
-- offered anyway, counted out of a fight.
local GRACE = 45
-- A hold not renewed for this long starts again: they were buffed, or left.
local LAPSE = 3
-- The least time between two hellos, and how often what a hello says is
-- compared with the last one said while there is anybody to tell.
local GAP, POLL = 10, 5
-- A hello's own limits, well inside the client's 255 bytes.
local MAX_TEXT, MAX_KEYS, MAX_KEY, MAX_USERS = 240, 24, 24, 40

-- users: [filed name] = what their last hello said. plans: [buff key] = the
-- split for it (Deal). known: the roster's names as last read. stats: for the
-- check-up. due: when Tick next has something to do (Core.lua, TickBody).
local users, plans, known = {}, {}, {}
local stats = { heard = 0, refused = 0, own = 0, other = 0, sent = 0, failed = 0, why = nil, result = nil,
	shape = nil }
local Share = { users = users, plans = plans, stats = stats, due = nil, dirty = false,
	GRACE = GRACE, GAP = GAP, POLL = POLL }
ns.Share = Share

-- The player's own entry in every split: what the next hello says.
local me = { me = true, keys = {} }
Share.me = me

local TOKENS = { raid = {}, party = {} }
for i = 1, 40 do
	TOKENS.raid[i] = "raid" .. i
	TOKENS.party[i] = "party" .. i
end

---------------------------------------------------------------------------
-- what a hello says
---------------------------------------------------------------------------

-- The raid groups a user buffs unasked, as bits (group 1 is 1, group 8 is 128).
local function Mask(db)
	local skip = db and db.filters and db.filters.skipRaidGroups
	local mask = 0
	for group = 1, 8 do
		if not (type(skip) == "table" and skip[group]) then mask = mask + 2 ^ (group - 1) end
	end
	return mask
end

local function Buffs(mask, group)
	if type(group) ~= "number" or group < 1 or group > 8 then return true end
	return math.floor(mask / 2 ^ (group - 1)) % 2 == 1
end

local function SafeGuid(guid)
	if type(guid) ~= "string" or #guid < 1 or #guid > 40 or guid:find("[^%w%-]") then return nil end
	return guid
end

-- Whether this Manners shares its group now: not while it is off or snoozed,
-- nor with the group switch off, nor with sharing off.
local function Sharing()
	local db = addon.db and addon.db.profile
	return db ~= nil and db.enabled == true and db.sources.group == true and db.sources.share == true
		and not (ns.SnoozeLeft and ns.SnoozeLeft())
end

-- What this Manners would say now, written into `me`: no key while it does
-- not share. A buff for one target at a time (Earth Shield, a Beacon) is each
-- user's own.
local function Payload()
	local db = addon.db and addon.db.profile
	wipe(me.keys)
	me.name = ns.UnitFullName("player")
	me.guid = SafeGuid(plain(UnitGUID("player")))
	me.class = ns.PlayerClass()
	me.groups = Mask(db)
	me.on = Sharing()
	if me.on then
		local castable = ns.CastableBuffs()
		local ready = ns.GroupReady and ns.GroupReady(db, castable)
		for _, buff in ipairs(castable) do
			if not buff.oneTarget then
				me.keys[buff.key] = (ready and ready[buff.key]) and "group" or "single"
			end
		end
	end
	return me
end

local function BuildText()
	local build = tostring(ns.BUILD or ""):gsub("[^%w%.%-]", ""):sub(1, 20)
	if build == "" then build = "0" end
	return build
end

-- The hello for `rec`, `ask` for one that wants an answer. Keys dropped from
-- the end should a class ever have more than fit.
local function Text(rec, ask)
	local keys = {}
	for key, kind in pairs(rec.keys) do keys[#keys + 1] = kind == "group" and (key .. "+") or key end
	table.sort(keys)
	local head = table.concat({ TAG, BuildText(), tostring(rec.class), (rec.on and "g" or "") .. (ask and "q" or ""),
		tostring(rec.groups), tostring(rec.guid) }, ";") .. ";"
	while #keys > MAX_KEYS do keys[#keys] = nil end
	local body = table.concat(keys, ",")
	while #head + #body > MAX_TEXT and #keys > 0 do
		keys[#keys] = nil
		body = table.concat(keys, ",")
	end
	return head .. body
end
Share.Text = Text

---------------------------------------------------------------------------
-- the roster
---------------------------------------------------------------------------

local roster, byName = {}, {}

-- Everybody in the group, you among them: the filed name, the token, the GUID
-- (nil where the client withholds it), the raid subgroup. Returns whether
-- there is a group, and whether it is a raid. `namesOnly` reads the names and
-- no more, for a group with nobody to share with: a raid's roster changes
-- every few seconds, and all that is asked of it then is who is new.
local function ReadRoster(namesOnly)
	wipe(roster)
	wipe(byName)
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n <= 0 then return false, false end
	local inRaid = plain(IsInRaid and IsInRaid()) == true
	local mine = me.name
	local function add(unit)
		if unit ~= "player" and not plain(UnitExists(unit)) then return end
		local name = ns.UnitFullName(unit)
		if not name or byName[name] then return end
		if namesOnly then
			byName[name] = true
			return
		end
		local member = { name = name, unit = unit, guid = SafeGuid(plain(UnitGUID(unit))),
			sub = inRaid and ns.RaidSubgroup(unit) or nil, me = name == mine }
		roster[#roster + 1] = member
		byName[name] = member
	end
	if inRaid then
		for i = 1, math.min(n, 40) do add(TOKENS.raid[i]) end
	else
		add("player")
		for i = 1, math.min(n - 1, 4) do add(TOKENS.party[i]) end
	end
	return true, inRaid
end

-- Whether a user counts now: not dead, not offline. An answer the client
-- withholds changes nothing.
local function Live(unit)
	if not unit then return false end
	if plain(UnitIsDeadOrGhost(unit)) == true then return false end
	local connected = _G.UnitIsConnected
	if type(connected) == "function" and plain(connected(unit)) == false then return false end
	return true
end

---------------------------------------------------------------------------
-- the split
---------------------------------------------------------------------------

local function ByGuid(a, b) return a.guid < b.guid end

-- How far on the order starts for each key, as { [key] = places }: nothing,
-- but for a class whose buffs replace one another, where each key starts one
-- further on than the one before it, among the keys the users of the class
-- cast between them, sorted (`said`: every such user's keys, yours among
-- them, which every side holds). So two paladins who both cast Might, Wisdom
-- and Kings each have a blessing that is theirs to give any one member.
local function Offsets(said, class)
	local out = {}
	if not (ns.EXCLUSIVE_BUFFS and ns.EXCLUSIVE_BUFFS[class]) then return out end
	local keys = {}
	for key in pairs(said) do keys[#keys + 1] = key end
	table.sort(keys)
	for i, key in ipairs(keys) do out[key] = i - 1 end
	return out
end
Share.Offsets = Offsets

-- The split of `members` for one buff among `sharers` (two or more users,
-- each with name, guid, sub, groups and keys; yours has `me`). Returns the
-- plan: owner[member's name] = the user whose share they are in (nil for
-- nobody's: a member whose GUID or subgroup the client withholds is
-- everybody's), bySub[subgroup] the same by raid subgroup, `capable` the users
-- who can cast its group version, in order. Nothing here reads the client:
-- the same lists give the same plan on every side.
local function Deal(key, buff, sharers, members, inRaid, offset)
	table.sort(sharers, ByGuid)
	-- Lands on the whole party however it is aimed (Queue.lua, LandsOnParty).
	local wide = buff ~= nil and (buff.selfCast == true or (ns.WIDE_CASTS == true and not buff.alone))
	-- Reaches the caster's own subgroup of a raid and nobody else.
	local pooled = buff ~= nil and buff.partyOnly == true and inRaid and ns.PARTY_IS_SUBGROUP == true
	local plan = { key = key, users = sharers, owner = {}, bySub = {}, capable = {}, wide = wide,
		inRaid = inRaid, offset = offset or 0 }
	local isUser = {}
	for _, user in ipairs(sharers) do
		isUser[user.name] = user
		if user.keys[key] == "group" then plan.capable[#plan.capable + 1] = user end
	end

	-- Whose turn it is at place `at`, of the users who reach subgroup `sub`.
	local eligible = {}
	local function Pick(at, sub)
		wipe(eligible)
		for _, user in ipairs(sharers) do
			if (not pooled or user.sub == sub) and (not inRaid or Buffs(user.groups, sub)) then
				eligible[#eligible + 1] = user
			end
		end
		if #eligible == 0 then return nil end
		return eligible[(at - 1 + plan.offset) % #eligible + 1]
	end

	local place = {}
	if inRaid then
		local subs, seen = {}, {}
		for _, member in ipairs(members) do
			if member.sub and not seen[member.sub] then
				seen[member.sub] = true
				subs[#subs + 1] = member.sub
			end
		end
		table.sort(subs)
		for i, sub in ipairs(subs) do plan.bySub[sub] = Pick(wide and 1 or i, sub) or false end
	else
		local rest = {}
		for _, member in ipairs(members) do
			if member.guid and not isUser[member.name] then rest[#rest + 1] = member end
		end
		table.sort(rest, ByGuid)
		for i, member in ipairs(rest) do place[member.name] = i end
	end

	for _, member in ipairs(members) do
		local own = isUser[member.name]
		if own and not wide then
			plan.owner[member.name] = own
		elseif inRaid then
			plan.owner[member.name] = member.sub and plan.bySub[member.sub] or nil
		else
			local at = wide and 1 or place[member.name]
			if at then plan.owner[member.name] = Pick(at, nil) end
		end
	end
	return plan
end
Share.Deal = Deal

-- Who casts the group version for the bucket `where` (GroupBuffs.lua: a class,
-- a raid subgroup, "raid" or "party"), or nil for nobody who can: whoever has
-- that subgroup, when they can; otherwise the first who can.
local function Caster(plan, where)
	local capable = plan.capable
	if #capable == 0 then return nil end
	if type(where) == "number" then
		local has = plan.bySub[where]
		if has and has.keys[plan.key] == "group" then return has end
	end
	return capable[plan.offset % #capable + 1]
end
Share.Caster = Caster

-- since/last by buff key and name: how long somebody has been held back.
-- held: [name] = the time of the scan that held them, for the check-up.
-- left: [key and bucket] = the group cast last left to another user.
local grace, held, left = {}, {}, {}

-- What is kept about people held back, let go once it is a minute old.
local function Forget(now)
	for name, at in pairs(held) do
		if now - at > 60 then held[name] = nil end
	end
	for _, timers in pairs(grace) do
		for name, last in pairs(timers.last) do
			if now - last > 60 then timers.last[name], timers.since[name] = nil, nil end
		end
	end
	for id, cast in pairs(left) do
		if now - cast.at > 60 then left[id] = nil end
	end
end

-- The roster read again and every split worked out afresh: after a roster
-- change, a hello, a user dying or coming back, a setting of your own.
local function Compute()
	Share.dirty = false
	wipe(plans)
	Forget(GetTime())
	Payload()
	-- What the splits below were made from, for the tick to tell a change by.
	Share.sig = Text(me, false)
	local grouped, inRaid = ReadRoster(next(users) == nil)
	if not grouped then
		wipe(users)
		wipe(known)
		return
	end
	for name in pairs(byName) do
		if not known[name] then Share.newcomer = true end
	end
	wipe(known)
	for name in pairs(byName) do known[name] = true end
	for name, user in pairs(users) do
		local member = byName[name]
		if not member then
			users[name] = nil
		else
			user.unit, user.sub = member.unit, member.sub
			user.live = Live(member.unit)
		end
	end
	if next(users) == nil or not (me.on and me.guid and me.name) then return end
	local mine = byName[me.name]
	me.sub = mine and mine.sub or nil
	local said = {}
	for key in pairs(me.keys) do said[key] = true end
	for _, user in pairs(users) do
		if user.live and user.on and user.class == me.class then
			for key in pairs(user.keys) do said[key] = true end
		end
	end
	local offsets = Offsets(said, me.class)
	for key in pairs(me.keys) do
		local sharers
		for _, user in pairs(users) do
			if user.live and user.on and user.class == me.class and user.keys[key] then
				sharers = sharers or { me }
				sharers[#sharers + 1] = user
			end
		end
		if sharers then
			plans[key] = Deal(key, ns.FindBuff(me.class, key), sharers, roster, inRaid, offsets[key])
		end
	end
end
Share.Compute = Compute

---------------------------------------------------------------------------
-- hearing a hello
---------------------------------------------------------------------------

local function Realm(name)
	return name:match("%-(.+)$")
end

-- The group member a sender is, by the name the client gives the message:
-- the filed name itself, else the one member it can be with the realm left
-- off either side, else (on the client with surnames, where a sender may be a
-- first name) the one member of that first name. nil for nobody, or for more
-- than one: the GUID a hello carries is its own word, and finds nobody.
local function UnitOf(sender)
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n <= 0 then return nil end
	local inRaid = plain(IsInRaid and IsInRaid()) == true
	local tokens = inRaid and TOKENS.raid or TOKENS.party
	local count = math.min(inRaid and n or (n - 1), inRaid and 40 or 4)
	local surnames = ns.caps and ns.caps.unitNameIsSurname
	local short, realm = ns.ShortName(sender), Realm(sender)
	local own = _G.GetNormalizedRealmName
	own = type(own) == "function" and plain(own()) or nil
	local exact, loose, loosely, first, firsts = nil, nil, 0, nil, 0
	for i = 1, count do
		local unit = tokens[i]
		if plain(UnitExists(unit)) and plain(UnitIsUnit(unit, "player")) ~= true then
			local name = ns.UnitFullName(unit)
			if name then
				local theirs = Realm(name)
				if name == sender then
					exact = unit
				elseif ns.ShortName(name) == short
					and ((realm and theirs and realm == theirs)
						or (realm and not theirs and (surnames or not own or realm == own))
						or not realm) then
					loose, loosely = unit, loosely + 1
				elseif surnames and ns.FirstName(name) == short then
					first, firsts = unit, firsts + 1
				end
			end
		end
	end
	if exact then return exact end
	if loosely == 1 then return loose end
	if loosely == 0 and firsts == 1 then return first end
	return nil
end

-- One hello, checked field by field. Returns why it was refused, nil when it
-- was taken (or was your own, come back to you).
local function Read(text, channel, sender)
	if #text > 255 then return "too long" end
	if channel ~= "PARTY" and channel ~= "RAID" then return "not from the group's channel" end
	if type(sender) ~= "string" or sender == "" or #sender > 100 then return "no sender" end
	local fields, n = {}, 0
	for field in (text .. ";"):gmatch("([^;]*);") do
		n = n + 1
		if n > 7 then return "too many fields" end
		fields[n] = field
	end
	if n ~= 7 then return "too few fields" end
	local build, class, flags, groups, guid, keys = fields[2], fields[3], fields[4], fields[5], fields[6], fields[7]
	if #build < 1 or #build > 24 or build:find("[^%w%.%-]") then return "build" end
	if #class < 1 or #class > 16 or class:find("[^%u]") then return "class" end
	if #flags > 4 or flags:find("[^gq]") then return "flags" end
	if #groups < 1 or #groups > 3 or groups:find("[^%d]") then return "groups" end
	groups = tonumber(groups)
	if not groups or groups > 255 then return "groups" end
	if not SafeGuid(guid) then return "guid" end
	local said, count = {}, 0
	for word in keys:gmatch("[^,]+") do
		local key, plus = word:match("^(%l[%l%d]*)(%+?)$")
		if not key or #key > MAX_KEY then return "keys" end
		count = count + 1
		if count > MAX_KEYS then return "too many keys" end
		said[key] = plus == "+" and "group" or "single"
	end
	-- Another class's is nothing to you: its buffs are not yours to share, and
	-- it needs no answer from you.
	if class ~= ns.PlayerClass() then
		stats.other = stats.other + 1
		return nil
	end

	-- Your own, as the group's channel hands every message back to its sender.
	-- By the GUID, which a namesake from another realm does not share; by the
	-- name only where the client withholds your own.
	local mine, own = ns.UnitFullName("player"), plain(UnitGUID("player"))
	if (own ~= nil and guid == own)
		or (own == nil and mine ~= nil and (sender == mine or ns.ShortName(sender) == mine)) then
		stats.own = stats.own + 1
		return nil
	end
	local unit = UnitOf(sender)
	if not unit then
		-- The shape of the name alone (letters as "a"), for a report: how this
		-- client writes an addon message's sender.
		stats.shape = sender:gsub("[^%s%-%p]+", "a"):sub(1, 24)
		return "nobody in your group"
	end
	local name = ns.UnitFullName(unit)
	if not name then return "nobody in your group" end
	-- Who the client says they are, where it says: a hello cannot speak for
	-- somebody else, nor for another class.
	local theirs = plain(UnitGUID(unit))
	if type(theirs) == "string" and theirs ~= guid then return "another's GUID" end
	local token = plain(select(2, UnitClass(unit)))
	if type(token) == "string" and token ~= class then return "another class" end
	for other, user in pairs(users) do
		if other ~= name and user.guid == guid then return "a GUID already heard" end
	end
	local user = users[name]
	if not user then
		local held = 0
		for _ in pairs(users) do held = held + 1 end
		if held >= MAX_USERS then return "too many users" end
		user = {}
		users[name] = user
		ns.Trail("share", ("a Manners user said hello: %s %s"):format(class, keys), name)
	end
	local on = flags:find("g", 1, true) ~= nil
	local sig = table.concat({ class, on and "g" or "", tostring(groups), guid, keys }, ";")
	if user.sig ~= sig or user.unit ~= unit then Share.dirty = true end
	user.name, user.unit, user.guid, user.class, user.build = name, unit, guid, class, build
	user.on, user.groups, user.keys, user.sig, user.at = on, groups, said, sig, GetTime()
	if user.live == nil then user.live = Live(unit) end
	-- An answer for whoever asked, and the watch on your own hello from now on.
	if flags:find("q", 1, true) then
		Share.reply = true
		Share.due = 0
	elseif not Share.due then
		Share.due = GetTime() + POLL
	end
	return nil
end

-- An addon message with Manners' prefix (Clicks.lua, ns.HeardAddonMessage):
-- true when it was a hello, taken or not, so nothing else reads it.
function ns.ShareHeard(text, channel, sender)
	text = plain(text)
	if type(text) ~= "string" or text:sub(1, #TAG + 1) ~= TAG .. ";" then return false end
	stats.heard = stats.heard + 1
	local why = Read(text, plain(channel), plain(sender))
	if why then
		stats.refused = stats.refused + 1
		stats.why = why
		-- A handful on the trail, never a flood of them.
		if stats.refused <= 5 then ns.Trail("share", "a hello was refused: " .. why) end
	end
	return true
end

---------------------------------------------------------------------------
-- saying hello
---------------------------------------------------------------------------

-- Whether the client would hold a hello back now: a fight, or its own word on
-- chat from addons. One that will not say is taken to.
local function Quiet()
	if InCombatLockdown() then return true end
	local chat = _G.C_ChatInfo
	if type(chat) == "table" and type(chat.InChatMessagingLockdown) == "function"
		and plain(chat.InChatMessagingLockdown()) ~= false then
		return true
	end
	return false
end

-- Called from the scan's tick when `due` has come (Core.lua, TickBody), under
-- a Guard: the roster read again when it changed, and a hello when one is due.
function Share:Tick(now)
	self.due = nil
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n <= 0 then
		if next(users) then wipe(users) end
		wipe(plans)
		wipe(known)
		self.greeted, self.newcomer, self.reply, self.said, self.dirty = false, false, false, nil, false
		return
	end
	-- A setting of your own changed since the splits were made: made again.
	if not self.dirty then
		Payload()
		if Text(me, false) ~= self.sig then self.dirty = true end
	end
	if self.dirty then Compute() end
	local sig = self.sig
	local speaks = next(me.keys) ~= nil and me.guid ~= nil and me.class ~= nil
	-- A first hello, one for somebody new or in answer, or what the last one
	-- said no longer being so (your share handed back included).
	local want = (speaks and (not self.greeted or self.newcomer or self.reply))
		or (self.said ~= nil and self.said ~= sig)
	if not want then
		self.newcomer, self.reply = false, false
		if next(users) then self.due = now + POLL end
		return
	end
	local chat = _G.C_ChatInfo
	local send = type(chat) == "table" and chat.SendAddonMessage
	if type(send) ~= "function" then return end
	if Quiet() then
		self.due = now + POLL
		return
	end
	if self.sentAt and now - self.sentAt < GAP then
		self.due = self.sentAt + GAP
		return
	end
	local inRaid = plain(IsInRaid and IsInRaid()) == true
	self.sentAt = now
	local result = plain(send(PREFIX, Text(me, not self.greeted), inRaid and "RAID" or "PARTY"))
	-- Enum.SendAddonMessageResult: 0 is Success on all five clients.
	if result == nil or result == true or result == 0 then
		if not self.greeted then ns.Trail("share", "said hello to the group") end
		stats.sent = stats.sent + 1
		self.greeted, self.newcomer, self.reply, self.said = true, false, false, sig
		if next(users) then self.due = now + POLL end
	else
		stats.failed = stats.failed + 1
		stats.result = result
		self.due = now + GAP
	end
end

-- The roster changed, or a loading screen ended: looked at on the next tick.
function Share.OnEvent()
	Share.dirty = true
	Share.due = 0
end

do
	local frame = CreateFrame("Frame")
	Share.frame = frame
	frame:SetScript("OnEvent", Share.OnEvent)
	for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
		pcall(frame.RegisterEvent, frame, event)
	end
	-- Asked for on every client, so the client hands the hellos on (Clicks.lua
	-- asks on Forever alone, for the author's line).
	local chat = _G.C_ChatInfo
	if type(chat) == "table" and type(chat.RegisterAddonMessagePrefix) == "function" then
		pcall(chat.RegisterAddonMessagePrefix, PREFIX)
	end
end

---------------------------------------------------------------------------
-- the walk's question
---------------------------------------------------------------------------

-- The entries kept for the fold alone, one table apiece reused from scan to
-- scan (Queue.lua keeps its own the same way); scanQueue is the queue of the
-- scan in hand.
local pool, scanQueue = { used = 0 }, nil

-- Once a scan, at the first member it asks about: the users still alive and
-- online, and the splits made again when that changed or anything else did.
local function BeginScan(queue)
	scanQueue = queue
	pool.used = 0
	-- The switch itself is asked every scan: off, nobody is left to anybody
	-- from this scan on, and not from the next hello.
	if Sharing() ~= me.on then Share.dirty = true end
	if not Share.dirty then
		for _, user in pairs(users) do
			if Live(user.unit) ~= user.live then
				Share.dirty = true
				break
			end
		end
	end
	if Share.dirty then Compute() end
end

-- The bucket a group cast would count `unit` in, as GroupBuffs.lua names it.
local function Bucket(unit, inRaid)
	if ns.GROUP_BY_CLASS[me.class] == true then return plain(select(2, UnitClass(unit))) end
	if inRaid then return ns.GROUP_IS_RAID and "raid" or ns.RaidSubgroup(unit) end
	return "party"
end

-- Somebody held back who a group cast of yours would cover: kept for the
-- fold alone, counted towards "When this many need it" and one the cast may
-- be aimed at, gone again after the fold if no group cast came of it. Only
-- who the fold counts (read as missing it, or running out), and nobody out of
-- a single cast's reach where the group version reaches no further.
local function Keep(opts, buff, has, remaining, queue)
	if not (opts.checked and (has == false or remaining ~= nil)) then return end
	-- Nor a top-up off what was last read worn, which the walk offers nobody on.
	if has and ns.ReadingSource(opts.guid, buff.key) == "kept" then return end
	local unit, name = opts.unit, opts.name
	local ranged = ns.ReachNow(unit, buff)
	if ranged == false and not ns.GROUP_IS_RAID then
		local db = addon.db and addon.db.profile
		if db and db.filters.requireInRange then return end
	end
	pool.used = pool.used + 1
	local kept = pool[pool.used]
	if not kept then
		kept = { inGroup = true, foldOnly = true, reason = "group", checked = true }
		pool[pool.used] = kept
	end
	kept.name, kept.short, kept.targetName, kept.unit = name, ns.ShortName(name), ns.TargetName(name), unit
	kept.class, kept.buff, kept.priority = plain(select(2, UnitClass(unit))), buff, ns.PRIORITY.group
	kept.known, kept.remaining, kept.ranged = has, remaining, ranged
	queue[#queue + 1] = kept
	opts.folding = true
end

-- Whether the walk leaves this member to another Manners user (Queue.lua,
-- visit: asked only of a member of the group nobody asked about and you did
-- not pick out). `opts` is the walk's own table for the person in hand,
-- `petOwner` the token of the member a pet belongs to, whose share it goes by.
function ns.ShareHolds(opts, buff, petOwner, has, remaining, queue)
	if next(users) == nil then return false end
	if scanQueue ~= queue then BeginScan(queue) end
	local plan = plans[buff.key]
	if not plan then return false end
	local name = opts.name
	local whose = plan.owner[petOwner and ns.UnitFullName(petOwner) or name]
	if not whose or whose.me then return false end

	-- Nobody goes without: held for GRACE seconds running, they are offered
	-- anyway. A fight's seconds do not count, and a hold not renewed for a
	-- moment (they were buffed, or went out of sight) starts again.
	local now = opts.now or GetTime()
	local timers = grace[buff.key]
	if not timers then
		timers = { since = {}, last = {} }
		grace[buff.key] = timers
	end
	local last = timers.last[name]
	if not last or now - last > LAPSE then
		timers.since[name] = now
	elseif InCombatLockdown() then
		timers.since[name] = timers.since[name] + (now - last)
	end
	timers.last[name] = now
	if now - timers.since[name] >= GRACE then return false end

	held[name] = now
	if not petOwner and not plan.wide and me.keys[buff.key] == "group" then
		local where = Bucket(opts.unit, plan.inRaid)
		if where and Caster(plan, where) == me then Keep(opts, buff, has, remaining, queue) end
	end
	return true
end

-- Somebody the walk was just told is another user's for the buff it picked
-- (ShareHolds): the pick made again among the buffs of yours that are not
-- another user's for them -- one only you cast, or, for a class whose buffs
-- replace one another, the blessing that is yours to give them. PickBuffFor's
-- own answer, nil for nothing: where every buff is shared by the same users
-- there is no other, and the pick is not made twice. `candidates` is the
-- scan's castable list, `read` its aura reader.
local others = {}
function ns.ShareOther(candidates, opts, read, petOwner)
	-- A pin is the one buff, whoever else casts it.
	if ns.PinnedBuff() then return nil end
	local name = petOwner and ns.UnitFullName(petOwner) or opts.name
	wipe(others)
	for _, buff in ipairs(candidates) do
		local plan = plans[buff.key]
		local whose = plan and plan.owner[name]
		if not whose or whose.me then others[#others + 1] = buff end
	end
	if #others == 0 then return nil end
	return ns.PickBuffFor(others, opts, read)
end

-- Whether a group cast for `bucket` (GroupBuffs.lua, GroupCasts) is another
-- Manners user's to cast: one caster for each, by the rule every side works
-- out alike (Caster).
function ns.ShareLeavesCast(bucket)
	if next(users) == nil then return false end
	local plan = plans[bucket.buff.key]
	if not plan then return false end
	local who = Caster(plan, bucket.where)
	if not who or who.me then return false end
	local id = bucket.buff.key .. "\0" .. tostring(bucket.where)
	local cast = left[id]
	if not cast then
		cast = {}
		left[id] = cast
	end
	local info = bucket.ready and bucket.ready.info
	cast.at, cast.who, cast.spell = GetTime(), who.name, info and info.groupName or ns.BuffName(bucket.buff)
	return true
end

---------------------------------------------------------------------------
-- saying so
---------------------------------------------------------------------------

local function White(name)
	return "|cffffffff" .. tostring(name) .. "|r"
end

-- For /manners debug and the full check-up: who you share the group with,
-- which share is yours, and what the last scan left to somebody else. Nothing
-- while no other Manners user has said hello. `scan` scans first.
function ns.ShareLines(scan)
	if scan then ns.Guard("share lines", ns.BuildQueue) end
	local out = {}
	local db = addon.db and addon.db.profile
	if not db or next(users) == nil then return out end
	if Share.dirty then Compute() end
	if next(users) == nil then return out end
	if db.sources.share ~= true then
		out[1] = L["other Manners users are in your group, but %s is switched off, so you may both be offered the same person"]
			:format("|cffffd100" .. L["Share the group with other Manners users"] .. "|r")
		return out
	end
	local keys = {}
	for key in pairs(plans) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local plan = plans[key]
		local spell = ns.BuffName(ns.FindBuff(me.class, key))
		local others = {}
		for _, user in ipairs(plan.users) do
			if not user.me then others[#others + 1] = White(user.name) end
		end
		local with = table.concat(others, ", ")
		if plan.wide then
			local who = plan.owner[me.name]
			if who and who.me then
				out[#out + 1] = L["|cffffd100sharing your group|r -- %s: yours to cast, left to you by %s"]
					:format(spell, with)
			elseif who then
				out[#out + 1] = L["|cffffd100sharing your group|r -- %s: %s casts it, and you are offered it only when it is still missing after %d seconds"]
					:format(spell, White(who.name), GRACE)
			end
		else
			local share = {}
			if plan.inRaid then
				for sub = 1, 8 do
					if plan.bySub[sub] == me then share[#share + 1] = tostring(sub) end
				end
				share = #share > 0 and L["groups %s"]:format(table.concat(share, ", ")) or nil
			else
				for name, who in pairs(plan.owner) do
					if who == me and name ~= me.name then share[#share + 1] = White(name) end
				end
				table.sort(share)
				share = #share > 0 and table.concat(share, ", ") or nil
			end
			out[#out + 1] = L["|cffffd100sharing your group|r -- %s with %s: your share is %s"]
				:format(spell, with, share or L["nobody but yourself"])
		end
	end
	local now, count = GetTime(), 0
	for _, at in pairs(held) do
		if at == now then count = count + 1 end
	end
	if count > 0 then
		out[#out + 1] = L["%d left to another Manners user on this scan"]:format(count)
	end
	for _, cast in pairs(left) do
		if cast.at == now then
			out[#out + 1] = L["no %s from you: %s casts it for the group"]:format(cast.spell, White(cast.who))
		end
	end
	return out
end

-- One line of numbers for the bug report: the switch, who has said hello, and
-- what became of the hellos heard and said.
function ns.ShareSummary()
	local db = addon.db and addon.db.profile
	local count = 0
	for _ in pairs(users) do count = count + 1 end
	return ("share=%s users=%d hellos heard=%d refused=%d%s%s own=%d other classes=%d sent=%d failed=%d%s"):format(
		tostring(db and db.sources.share), count, stats.heard, stats.refused,
		stats.why and (" (last: " .. stats.why .. ")") or "",
		stats.shape and (" (a sender written \"" .. stats.shape .. "\")") or "", stats.own, stats.other, stats.sent,
		stats.failed,
		stats.result ~= nil and (" (result " .. tostring(stats.result) .. ")") or "")
end

-- The full check-up's own part (Options/Diagnostics.lua, ns.FullReport), in
-- the report's plain words: every user heard, what each said, and each split.
-- Names in white, which the report replaces with aliases.
function ns.ShareReport()
	local out = { ns.ShareSummary() }
	if Share.dirty then Compute() else Payload() end
	local function said(rec)
		local keys = {}
		for key, kind in pairs(rec.keys or {}) do keys[#keys + 1] = kind == "group" and (key .. "+") or key end
		table.sort(keys)
		return ("%s on=%s groups=%s keys=%s"):format(tostring(rec.class), tostring(rec.on), tostring(rec.groups),
			#keys > 0 and table.concat(keys, ",") or "none")
	end
	out[#out + 1] = "you: " .. said(me)
	local names = {}
	for name in pairs(users) do names[#names + 1] = name end
	table.sort(names)
	if #names == 0 then
		out[#out + 1] = "no other Manners user has said hello in this group"
		return out
	end
	for _, name in ipairs(names) do
		local user = users[name]
		out[#out + 1] = ("%s: %s build %s live=%s"):format(White(name), said(user), tostring(user.build),
			tostring(user.live))
	end
	local keys = {}
	for key in pairs(plans) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local plan = plans[key]
		local total, yours = 0, 0
		for _, who in pairs(plan.owner) do
			total = total + 1
			if who == me then yours = yours + 1 end
		end
		local caster = Caster(plan, plan.inRaid and (ns.GROUP_IS_RAID and "raid" or me.sub) or "party")
		out[#out + 1] = ("%s: %d users, yours %d of %d%s, group cast: %s"):format(key, #plan.users, yours, total,
			plan.wide and " (one caster)" or "",
			caster == nil and "nobody's" or caster.me and "yours" or White(caster.name))
	end
	for _, line in ipairs(ns.ShareLines()) do out[#out + 1] = line end
	return out
end
