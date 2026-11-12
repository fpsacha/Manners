-- Manners -- a companion pet kept out (1.11.16), under Myself on Who to buff:
-- Buffs.lua's `pet` family, off until it is turned on.
--
-- Two kinds of pet, by client:
--
--   the pet journal (Forever)  most of Forever's pets are taught once by their
--       item and live in the journal after. Manners brings one out itself, with
--       no press: C_PetJournal.SummonPetByGUID, or SummonRandomPet for a
--       favourite or any pet (Which pet). Whether one is out is the journal's
--       own word (GetSummonedPetGUID). Should the game refuse it (a try that
--       brings nothing out, three times running, or ADDON_ACTION_FORBIDDEN or
--       _BLOCKED naming Manners), the journal is left to the player for the
--       session.
--   a pet used from the bags (Classic Era and Burning Crusade, a handful on
--       Forever: Pets.lua)  a press, on the prompt, as food is: /use item:<id>.
--       No call says whether one is out, so Manners keeps its own count: out
--       once the use of one is seen (UNIT_SPELLCAST_SUCCEEDED), gone at death,
--       a loading screen (a /reload keeps it) or a flight, and put away when
--       the same item is used again while it is out (the item is a toggle).
--
-- Never in a fight, a dungeon, a raid, a battleground or an arena; never
-- mounted, stealthed, dead, flying, in a vehicle or casting; and a pet the
-- player put away stays away until they bring one out again. A moment's wait
-- after a loading screen, a landing or a resurrection lets the game settle.
--
-- Kept per character (db.char.pet): the bag pet out (its spell key), whether
-- the player put the pet away, the journal pet last out (its GUID), and which
-- kind was out last ("journal" or the bag pet's key), so a turtle egg used
-- last is offered again rather than the journal's.

local _, ns = ...
local addon = ns.addon
local plain = ns.plain

local Pet = {}
ns.Pet = Pet

-- Seconds between two journal summons; how long a summon has to bring a pet
-- out before it counts as refused; how many refusals in a row leave the
-- journal to the player; the wait after a loading screen, a landing or a
-- resurrection.
local TRY_EVERY, CHECK_AFTER, GIVE_UP, SETTLE = 10, 3, 3, 2
Pet.TRY_EVERY, Pet.CHECK_AFTER, Pet.GIVE_UP, Pet.SETTLE = TRY_EVERY, CHECK_AFTER, GIVE_UP, SETTLE

-- This session's journal state: the last try, whether it is being judged,
-- refusals in a row, refused for the session, the quiet after a loading
-- screen, and whether a summon of ours is running (the hook below takes the
-- player's own dismissals, not ours).
local session = { lastTry = -math.huge, judging = nil, failures = 0, refused = false, quietUntil = 0,
	ours = false }
Pet.session = session

-- This character's pet family (Buffs.lua), or nil where there is none.
local function Family()
	for _, family in ipairs(ns.GetOwnFamilies() or {}) do
		if family.pet then return family end
	end
	return nil
end
Pet.Family = Family

-- db.char.pet, made on first write.
local function Char(create)
	local char = addon.db and addon.db.char
	if type(char) ~= "table" then return nil end
	if type(char.pet) ~= "table" then
		if not create then return nil end
		char.pet = {}
	end
	return char.pet
end

-- The client's pet journal, where it has one.
local function Journal()
	local journal = _G.C_PetJournal
	if type(journal) == "table" and type(journal.GetSummonedPetGUID) == "function" then return journal end
	return nil
end

-- Whether a journal pet is out: true with its GUID, false, nil for the game
-- will not say.
local function JournalOut()
	local journal = Journal()
	if not journal then return false end
	local ok, guid = pcall(journal.GetSummonedPetGUID)
	if not ok then return nil end
	local value = plain(guid)
	if guid ~= nil and value == nil then return nil end
	if type(value) == "string" and value ~= "" then return true, value end
	return false
end
Pet.JournalOut = JournalOut

-- How many pets the journal holds, 0 where it has none.
local function Owned()
	local journal = Journal()
	if not (journal and type(journal.GetNumPets) == "function") then return 0 end
	local ok, _, owned = pcall(journal.GetNumPets)
	owned = ok and plain(owned) or nil
	return type(owned) == "number" and owned or 0
end

-- Whether the journal has a pet for Manners to bring out (Options/Shared.lua
-- shows the switch for it).
function ns.PetJournalOwned()
	local family = Family()
	return family ~= nil and family.journal == true and Owned() > 0
end

-- The summon spell of every bag pet, to its spell entry (Buffs.lua).
local bySpell
local function BagPet(spellId)
	if not bySpell then
		bySpell = {}
		local family = Family()
		for _, spell in ipairs(family and family.spells or {}) do bySpell[spell.ranks[1]] = spell end
	end
	return bySpell[spellId]
end

-- Whether a pet is out: true with the bag pet's spell when it is one, false,
-- nil for the game will not say (Core.lua, ReadOwnFamily). The journal's word
-- first, then Manners' own count of the bag pet.
function ns.ReadPet(family)
	if family.journal then
		local out = JournalOut()
		if out == nil then return nil end
		if out then return true end
	end
	local mine = Char()
	local spell = mine and ns.FindOwnSpell(mine.out)
	if spell and spell.family == family then return true, spell end
	return false
end

-- Whether a dungeon, a raid, a battleground or an arena.
local function Instanced()
	if type(_G.IsInInstance) ~= "function" then return false end
	local inside, kind = _G.IsInInstance()
	if plain(inside) ~= true then return false end
	kind = plain(kind)
	return kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena"
end

local function Yes(fn, ...)
	return type(fn) == "function" and plain(fn(...)) == true
end

-- Why no pet is brought out or offered just now, or nil (Core.lua,
-- OwnVerdict): "dismissed" (the player put it away), "instance", "mounted",
-- "petbusy" (dead, flying, in a vehicle, stealthed, casting, or a moment after
-- a loading screen).
function ns.PetHold(now)
	local mine = Char()
	if mine and mine.dismissed then return "dismissed" end
	if Instanced() then return "instance" end
	if Yes(_G.IsMounted) then return "mounted" end
	if (now or GetTime()) < session.quietUntil then return "petbusy" end
	if Yes(_G.UnitIsDeadOrGhost, "player") or Yes(_G.UnitOnTaxi, "player") or Yes(_G.UnitInVehicle, "player")
		or Yes(_G.IsStealthed) then
		return "petbusy"
	end
	if type(_G.UnitCastingInfo) == "function" and plain((_G.UnitCastingInfo("player"))) ~= nil then return "petbusy" end
	if type(_G.UnitChannelInfo) == "function" and plain((_G.UnitChannelInfo("player"))) ~= nil then return "petbusy" end
	return nil
end

-- Whether a journal pet can be summoned by its GUID.
local function Summonable(guid)
	local journal = Journal()
	if not (journal and type(guid) == "string" and type(journal.PetIsSummonable) == "function") then return false end
	local ok, can = pcall(journal.PetIsSummonable, guid)
	return ok and plain(can) == true
end

-- What Which pet asks for, as the journal can do it: a GUID, "favourite" or
-- "random", or nil for nothing to bring out.
local function JournalPick()
	if Owned() < 1 then return nil end
	local db = addon.db and addon.db.profile
	local choice = db and db.ownBuffs and db.ownBuffs.petChoice or "last"
	local mine = Char()
	if choice == "last" and mine and Summonable(mine.guid) then return mine.guid end
	if choice == "random" then return "random" end
	local journal = Journal()
	local has = type(journal.HasFavoritePets) == "function" and select(2, pcall(journal.HasFavoritePets))
	return plain(has) == true and "favourite" or "random"
end

-- Whether the pet to bring out comes from the journal, Manners bringing it out
-- itself, rather than from the bags on the prompt: the journal, not refused,
-- with a pet in it, unless the pet out last was a bag pet still in the bags.
-- Nil with "refused" when the journal would have been asked and the game
-- turned Manners away this session.
function ns.PetFromJournal(family)
	if not family.journal or not Journal() then return false end
	if not JournalPick() then return false end
	local mine = Char()
	local last = mine and ns.FindOwnSpell(mine.last)
	if last and last.family == family and last.item then
		local count = C_Item and C_Item.GetItemCount
		local n = type(count) == "function" and plain(count(last.item)) or nil
		if type(n) == "number" and n > 0 then return false end
	end
	if session.refused then return false, "refused" end
	return true
end

-- With the switch on, on a client with the journal: the scan pays nothing for
-- this otherwise (Core.lua, TickBody).
function Pet:Wanted()
	local family = Family()
	return family ~= nil and family.journal == true and ns.OwnPick(family) ~= "off"
end

-- One summon from the journal, as Which pet asks.
local function Summon(journal, pick)
	session.ours = true
	if pick == "favourite" or pick == "random" then
		pcall(journal.SummonRandomPet, pick == "favourite")
	else
		pcall(journal.SummonPetByGUID, pick)
	end
	session.ours = false
end

-- The player's own call on the journal a second ago (Pet:PutAway, below).
local function JudgeAsked(now)
	local asked = session.asked
	if not asked or now - asked.at < 1 then return end
	session.asked = nil
	local mine = Char(true)
	if mine and JournalOut() == false and (asked.guid == nil or asked.guid == mine.guid) then
		mine.dismissed = true
	end
end

-- Each scan, with the switch on: judges the last summon, and brings a pet out
-- of the journal when the queue's own verdict says one is due from there
-- (Core.lua, OwnVerdict's "journal").
function Pet:Tick(now)
	now = now or GetTime()
	JudgeAsked(now)
	if session.judging and now - session.judging >= CHECK_AFTER then
		session.judging = nil
		if JournalOut() then
			session.failures = 0
		else
			session.failures = session.failures + 1
			if session.failures >= GIVE_UP and not session.refused then
				session.refused = true
				ns.Trail("pet", "the journal brought no pet out " .. GIVE_UP .. " times: left to the player")
			end
		end
	end
	if session.judging or session.refused or now - session.lastTry < TRY_EVERY then return end
	if InCombatLockdown() then return end
	local db = addon.db and addon.db.profile
	if not (db and db.sources and db.sources.self == true) then return end
	local family = Family()
	local ctx = { name = ns.UnitFullName("player"), now = now, whenBuffed = ns.SelfWhenBuffed(db.filters),
		refreshUnder = db.filters.refreshUnder }
	local _, _, _, why = ns.OwnVerdict(family, ctx)
	if why ~= "journal" then return end
	local journal, pick = Journal(), JournalPick()
	if not (journal and pick) then return end
	session.lastTry, session.judging = now, now
	ns.Trail("pet", "brought a pet out of the journal (" .. (pick == "favourite" and "a favourite"
		or pick == "random" and "any pet" or "the last one out") .. ")")
	Summon(journal, pick)
end

-- A cast of yours: a bag pet's summon puts it out, or away when it was out
-- (the item is a toggle, and Manners offers it only with none out).
function Pet:Cast(spellId)
	spellId = plain(spellId)
	local spell = type(spellId) == "number" and BagPet(spellId)
	if not spell then return end
	local mine = Char(true)
	if not mine then return end
	if mine.out == spell.key then
		mine.out, mine.dismissed = nil, true
	else
		mine.out, mine.dismissed, mine.last = spell.key, nil, spell.key
	end
	ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
end

-- The journal's pet changed: one out is the journal's (a bag pet it replaced
-- is gone), and none out after one was is the game's doing unless the player
-- put it away (the hooks below).
function Pet:JournalChanged()
	local out, guid = JournalOut()
	if not out then return end
	local mine = Char(true)
	if not mine then return end
	mine.out, mine.dismissed, mine.guid, mine.last = nil, nil, guid, "journal"
end

-- The player's own call on the journal: its Dismiss (no GUID), or
-- SummonPetByGUID, which puts the pet away when it is the one out (the
-- journal's toggle, /dismisspet) and brings it out otherwise. Which of the two
-- it was is read a second later (Pet:Tick): none out, and the call was a
-- Dismiss or named the pet last out, is the player putting it away. Not a
-- summon of ours.
function Pet:PutAway(guid)
	if session.ours then return end
	session.asked = { guid = plain(guid), at = GetTime() }
end

-- What the game takes the bag pet away at, and the moment after which a pet
-- is brought out again.
function Pet:Gone(settle)
	local mine = Char()
	if mine then mine.out = nil end
	if settle then session.quietUntil = GetTime() + SETTLE end
end

function Pet:OnEvent(event, ...)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, _, spellId = ...
		if unit == "player" then self:Cast(spellId) end
	elseif event == "COMPANION_UPDATE" then
		if ... ~= "MOUNT" then self:JournalChanged() end
	elseif event == "PLAYER_ENTERING_WORLD" then
		local _, reload = ...
		-- A /reload keeps the pet; a login or a loading screen does not.
		if reload == true then
			session.quietUntil = GetTime() + SETTLE
		else
			self:Gone(true)
		end
	elseif event == "PLAYER_DEAD" then
		self:Gone(false)
	elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "PLAYER_CONTROL_GAINED" then
		session.quietUntil = GetTime() + SETTLE
	elseif event == "PLAYER_CONTROL_LOST" then
		-- A flight takes the pet away.
		if Yes(_G.UnitOnTaxi, "player") then self:Gone(false) end
	elseif event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
		local who, what = ...
		if who == "Manners" and type(what) == "string" and what:find("Pet", 1, true) then
			session.refused = true
			ns.Trail("pet", "the game refused " .. what .. ": the journal is left to the player")
		end
	end
end

-- Registered where a pet family exists, the journal's events where there is a
-- journal (a client without one refuses an unknown event). A frame of its own,
-- so the addon's own handlers for the same events stay theirs.
do
	local frame = CreateFrame("Frame")
	Pet.frame = frame
	frame:SetScript("OnEvent", function(_, event, ...) ns.Guard("companion pet", Pet.OnEvent, Pet, event, ...) end)
	local data = ns.PETS and ns.Flavour and ns.PETS[ns.Flavour.flavour]
	if data then
		for _, event in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE",
			"PLAYER_UNGHOST", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST", "ADDON_ACTION_FORBIDDEN",
			"ADDON_ACTION_BLOCKED" }) do
			pcall(frame.RegisterEvent, frame, event)
		end
		if ns.Flavour.flavour == "camelot" then
			pcall(frame.RegisterEvent, frame, "COMPANION_UPDATE")
			local journal = _G.C_PetJournal
			if type(journal) == "table" and type(hooksecurefunc) == "function" then
				if type(journal.DismissSummonedPet) == "function" then
					hooksecurefunc(journal, "DismissSummonedPet", function() Pet:PutAway(nil) end)
				end
				if type(journal.SummonPetByGUID) == "function" then
					-- Before the toggle has run the pet is still out; a post-hook
					-- runs after, so the GUID last seen out is asked as well.
					hooksecurefunc(journal, "SummonPetByGUID", function(guid) Pet:PutAway(guid) end)
				end
			end
		end
	end
end
