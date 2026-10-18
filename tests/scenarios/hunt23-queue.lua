-- Four faults in Queue.lua that a triage of old bug-hunt candidates proved with
-- a red scenario each (STATUS.md, "Bug-hunt candidates never checked"): the
-- refusal back-off keeping the player from the person they have selected, a
-- namesake from another realm read as a friend, a group member offered from
-- the passer-by memory with "People in my group" off, and your own buff said to
-- come first while your name is on the never-offer list. Every name starts with
-- "hunt23-queue:" and then the fault's own words, so a mutation can name exactly
-- one; a scenario run against several clients says so in its name, and a control
-- that fails reads "SKIPPED --".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- Globals a scenario replaces, put back after it whether it finished or threw.
local TOUCHED = { "C_FriendList", "C_Secrets", "UnitExists", "UnitName", "IsSpellKnown", "IsPlayerSpell" }

-- How the client files Anna Aim, as ANNA, for the scenarios that follow the
-- client the suite is standing in for (a nil `flavour` to run() below, so
-- `runscenarios.py --flavour X` and check.py run them as X). On Forever UnitName's
-- second return is a surname, filed with a space; off it a realm, which the
-- client hands over for somebody from another one (Mock.crossRealm, set for
-- these) and the addon joins with a dash. The scenarios about one client, or
-- about the names themselves, say which client and spell their names out.
local ANNA

-- One scenario: the mock reset to `flavour` (nil: the client the suite runs as,
-- Forever unless asked otherwise) and `class`, `names` standing about as strangers
-- on their tokens, the addon loaded and driven to a fresh prompt, and body(ns)
-- run. Everything is put back and the mock reset after it.
local function run(scenario, flavour, class, names, body, before)
	Mock.reset()
	if flavour then
		Mock.setFlavour(flavour)
	else
		Mock.crossRealm = not Mock.surnames
		ANNA = Mock.surnames and "Anna Aim" or "Anna-Aim"
	end
	Mock.class = class
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		if before then before() end
		restore = strangers(names)
		-- The client names nobody for a unit that is not there; the mock answers a
		-- stand-in. Matters for a cleared target, which UnitName("target") then
		-- reads as nil, as the client does.
		local named = UnitName
		rawset(_G, "UnitName", function(unit)
			if unit == "target" and names.target == nil then return nil end
			return named(unit)
		end)
		local ns = load(scenario)
		if not ns then return end
		if not flavour and ns.UnitFullName("nameplate1") ~= ANNA then
			fail(scenario, ("SKIPPED -- the addon files the stranger on the nameplate as %s, not %s")
				:format(tostring(ns.UnitFullName("nameplate1")), ANNA))
			return
		end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
end

-- Lines in chat saying the game keeps refusing somebody.
local function told()
	local out = {}
	for _, line in ipairs(Mock.printed) do
		if line:find("keeps refusing", 1, true) then out[#out + 1] = line end
	end
	return out
end

-- ------------------------------------------------------ the back-off
-- queue-liftbackoff-needs-target-change-event (Queue.lua NoteRefusal,
-- LiftBackoff; Core.lua PLAYER_TARGET_CHANGED)
--
-- "The back-off must never keep the player from somebody they point at": that
-- is the comment above PLAYER_TARGET_CHANGED, and the back-off is lifted only
-- by that event. Somebody who is already the target when the game refuses the
-- third press on them (out of range, say) was backed off for five minutes
-- while standing selected, and no event could lift it: selecting the unit that
-- is selected fires nothing. The chat line said "target them to try again";
-- the player had to clear the target and select them anew. IterateUnits walks
-- "target" as a pointed unit, and visit() turned it away on IsBlocked like
-- anybody.
--
-- But the prompt's own macro makes somebody the target too, and leaves them so
-- where "Hand my target back" is off or nothing was targeted before: that is
-- no choice of the player's (PLAYER_TARGET_CHANGED ignores it), and somebody
-- the game refuses that way must still be let go, or the first reason for the
-- back-off (a prompt that comes straight back, for good) returns.
do
	local scenario = "hunt23-queue: your own target is not backed off while you point at them"
	local function refuseThrice(ns)
		for _ = 1, 3 do
			ns.NoteRefusal(ANNA, "Out of range.", nil, true)
			Mock.advance(3)
		end
	end
	-- Control: the same three refusals on somebody who is only on a nameplate
	-- back her off, which is what the back-off is for.
	run(scenario, nil, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		Mock.advance(60)
		if not entryFor(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna on a nameplate was not offered to begin with")
			return
		end
		refuseThrice(ns)
		Mock.advance(20)
		if entryFor(ns, ANNA) then
			fail(scenario, "SKIPPED -- three refusals did not back off somebody on a nameplate")
		end
	end)
	-- The player selects Anna (the client sends PLAYER_TARGET_CHANGED once, as
	-- the target changes) and presses on her three times. Selecting her again
	-- afterwards sends nothing, so nothing is sent here.
	run(scenario, nil, "MAGE", { target = { "Anna", "Aim" }, nameplate1 = { "Anna", "Aim" } }, function(ns)
		ns.addon:PLAYER_TARGET_CHANGED()
		Mock.advance(60)
		local before = entryFor(ns, ANNA)
		if not (before and before.unit == "target") then
			fail(scenario, "SKIPPED -- Anna, the standing target, was not offered to begin with")
			return
		end
		Mock.printed = {}
		refuseThrice(ns)
		Mock.advance(20)
		if not entryFor(ns, ANNA) then
			fail(scenario, "Anna has been the player's own target throughout, and after the third refusal the"
				.. " back-off keeps her off the prompt for minutes with nothing that lifts it: the lift"
				.. " waits for a PLAYER_TARGET_CHANGED that selecting the selected unit never sends")
		end
		local lines = told()
		if #lines > 0 then
			fail(scenario, "chat says she will not be offered for a while and to target her to try again,"
				.. " though she is the target and is still offered: " .. lines[1])
		end
		-- The refusals still count: the player moves on to somebody else, and the
		-- next refusal on Anna, now only a passer-by, is her fourth in a row.
		Mock.unitNames.target = nil
		ns.addon:PLAYER_TARGET_CHANGED()
		Mock.advance(3)
		local passerBy = entryFor(ns, ANNA)
		if not (passerBy and passerBy.unit ~= "target") then
			fail(scenario, "SKIPPED -- Anna was not offered as a passer-by once the target was cleared")
			return
		end
		ns.NoteRefusal(ANNA, "Out of range.", nil, true)
		Mock.advance(20)
		if entryFor(ns, ANNA) then
			fail(scenario, "the refusals on her as the player's target were not counted: the fourth in a row,"
				.. " as a passer-by, did not back her off")
		end
	end)
	-- Somebody who was selected, and is not any more (the player cleared the
	-- target, an event the player sent): a later press on her is anybody's. The
	-- macro's own /target makes her the target again, and three refusals back her
	-- off, though she was the player's pick once.
	run(scenario, nil, "MAGE", { target = { "Anna", "Aim" }, nameplate1 = { "Anna", "Aim" } }, function(ns)
		ns.addon:PLAYER_TARGET_CHANGED()
		Mock.unitNames.target = nil
		ns.addon:PLAYER_TARGET_CHANGED()
		Mock.advance(60)
		if not entryFor(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna on a nameplate was not offered after the target was cleared")
			return
		end
		for _ = 1, 3 do
			Mock.unitNames.target = { "Anna", "Aim" }
			ns.pressAt = GetTime()
			ns.addon:PLAYER_TARGET_CHANGED()
			ns.NoteRefusal(ANNA, "Out of range.", nil, true)
			Mock.advance(3)
		end
		Mock.advance(20)
		if entryFor(ns, ANNA) then
			fail(scenario, "somebody the player selected once and cleared again, whom the macro then targeted,"
				.. " was not backed off after three refusals")
		end
	end)
end

do
	local scenario = "hunt23-queue: somebody the macro targeted is still backed off"
	-- Nobody targeted by the player; "Hand my target back" off, so what the
	-- prompt's own /target picked stays the target (a press with nothing
	-- targeted before it leaves them so on the client too). Each press moves the
	-- target within the half second PLAYER_TARGET_CHANGED ignores, as a press
	-- does, and is refused.
	run(scenario, nil, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		ns.db.profile.filters.restoreTarget = false
		Mock.advance(60)
		if not entryFor(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna on a nameplate was not offered to begin with")
			return
		end
		for _ = 1, 3 do
			Mock.unitNames.target = { "Anna", "Aim" }
			ns.pressAt = GetTime()
			ns.addon:PLAYER_TARGET_CHANGED()
			ns.NoteRefusal(ANNA, "Out of range.", nil, true)
			Mock.advance(3)
		end
		Mock.advance(20)
		if entryFor(ns, ANNA) then
			fail(scenario, "the macro's own /target made Anna the target, and three refusals on her did not"
				.. " back her off: a prompt the game keeps refusing comes straight back, for good")
		end
		if #told() ~= 1 then
			fail(scenario, "the third refusal did not say so in chat once: " .. #told() .. " lines")
		end
	end)
end

-- ------------------------------------------------------ the namesake
-- queue-closeness-crossrealm-namesake-is-friend (Queue.lua Closeness)
--
-- "Who comes first: friends and guildmates" takes a player for a friend when
-- their name is a friend's. Closeness runs that name test after
-- C_FriendList.IsFriend has said no, and it used to take the realm off first
-- (ns.TargetName), so a stranger from another realm who shares a name with a
-- friend of yours was put ahead of everybody else of her kind and the tooltip
-- called her a friend. Off Forever only: there the realm is how two Annas
-- differ. The friends list names a friend of another realm with it
-- ("Anna-Otherrealm") and one of your own without, and a friend of either
-- kind is still found: by GUID, and where that is withheld by the name as filed.
do
	local scenario = "hunt23-queue: a namesake from another realm is not a friend"
	local names = { nameplate1 = { "Anna", "Otherrealm" }, nameplate2 = { "Anna", "" } }
	local function friendsList(list, isFriend)
		return {
			IsFriend = isFriend or function() return false end,
			IsIgnored = function() return false end,
			GetNumFriends = function() return #list end,
			GetFriendInfoByIndex = function(i) return list[i] end,
			GetNumIgnores = function() return 0 end,
		}
	end
	for _, flavour in ipairs({ "vanilla", "tbc", "mists", "mainline" }) do
		local label = scenario .. " (" .. flavour .. ")"
		-- Your friend Anna of your own realm is nameplate2, known to the client by
		-- her GUID; nameplate1 is a different Anna from another realm.
		run(label, flavour, "MAGE", names, function(ns)
			Mock.crossRealm = true
			local friendGuid = "Player-1-nameplate2"
			rawset(_G, "C_FriendList", friendsList({ { name = "Anna", guid = friendGuid } },
				function(guid) return guid == friendGuid end))
			ns.db.profile.priority.friends = true
			Mock.advance(60)
			local real = entryFor(ns, "Anna")
			local namesake = entryFor(ns, "Anna-Otherrealm")
			if not (real and namesake) then
				fail(label, "SKIPPED -- both Annas were not offered: "
					.. tostring(real and real.name) .. ", " .. tostring(namesake and namesake.name))
				return
			end
			if real.close ~= "friend" then
				fail(label, "SKIPPED -- the real friend was not read as one: " .. tostring(real.close))
				return
			end
			if namesake.close ~= nil then
				fail(label, "Anna-Otherrealm, whom the client says is no friend"
					.. " (IsFriend false for her GUID), is read as '" .. tostring(namesake.close)
					.. "' because a friend of yours is called Anna")
			end
		end)
		-- Where IsFriend says no for everybody and the GUID on the list is nobody's
		-- here: the friends are found by the name the list gives them.
		run(label .. " by name", flavour, "MAGE", names, function(ns)
			Mock.crossRealm = true
			rawset(_G, "C_FriendList", friendsList({ { name = "Anna", guid = "Player-9-elsewhere" } }))
			ns.db.profile.priority.friends = true
			Mock.advance(60)
			local real, namesake = entryFor(ns, "Anna"), entryFor(ns, "Anna-Otherrealm")
			if not (real and namesake) then
				fail(label .. " by name", "SKIPPED -- both Annas were not offered")
				return
			end
			if real.close ~= "friend" then
				fail(label .. " by name", "a friend of your own realm, listed as Anna, was not found by name: "
					.. tostring(real.close))
			end
			if namesake.close ~= nil then
				fail(label .. " by name", "Anna-Otherrealm was read as '" .. tostring(namesake.close)
					.. "' by the name of the friend Anna")
			end
		end)
		run(label .. " listed with her realm", flavour, "MAGE", names, function(ns)
			Mock.crossRealm = true
			rawset(_G, "C_FriendList", friendsList({ { name = "Anna-Otherrealm", guid = "Player-9-elsewhere" } }))
			ns.db.profile.priority.friends = true
			Mock.advance(60)
			local real, namesake = entryFor(ns, "Anna"), entryFor(ns, "Anna-Otherrealm")
			if not (real and namesake) then
				fail(label .. " listed with her realm", "SKIPPED -- both Annas were not offered")
				return
			end
			if namesake.close ~= "friend" then
				fail(label .. " listed with her realm", "a friend of another realm, listed as Anna-Otherrealm,"
					.. " was not found by name: " .. tostring(namesake.close))
			end
			if real.close ~= nil then
				fail(label .. " listed with her realm", "Anna of your own realm was read as '"
					.. tostring(real.close) .. "' by the name of the friend Anna-Otherrealm")
			end
		end)
	end
	-- Forever files a person by first name and surname, and a friend listed so is
	-- found by that name alone.
	local label = scenario .. " (camelot, by name)"
	run(label, "camelot", "MAGE", { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Anna", "Other" } }, function(ns)
		rawset(_G, "C_FriendList", friendsList({ { name = "Anna Aim", guid = "Player-9-elsewhere" } }))
		ns.db.profile.priority.friends = true
		Mock.advance(60)
		local real, other = entryFor(ns, "Anna Aim"), entryFor(ns, "Anna Other")
		if not (real and other) then
			fail(label, "SKIPPED -- both Annas were not offered")
			return
		end
		if real.close ~= "friend" then
			fail(label, "a friend listed as Anna Aim was not found by name: " .. tostring(real.close))
		end
		if other.close ~= nil then
			fail(label, "Anna Other was read as '" .. tostring(other.close) .. "'")
		end
	end)
end

-- ------------------------------------------------------ the group switch
-- queue-group-source-off-leaks-remembered-passerby (Queue.lua visit,
-- OfferPassersBy)
--
-- With "People in my group" off and passers-by on, a stranger offered as a
-- passer-by is remembered by name for ten seconds after the last token reached
-- them. When she joins your party in those seconds the walk finds her again
-- as a group member, and visit() used to return on `reason == "group" and not
-- db.sources.group` without a verdict (no `seen`, no `rejected`), so
-- OfferPassersBy went on offering her from the old memory as a passer-by: the
-- group switch was ignored for her until the memory ran out. Every other
-- early return of that kind writes a verdict or drops the memories (`drop`).
do
	local scenario = "hunt23-queue: the group switch turns away a remembered passer-by who joins"
	run(scenario, nil, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers = false, true
		Mock.advance(60)
		local before = entryFor(ns, ANNA)
		if not (before and before.reason == "nearby" and ns.passersBy[ANNA]) then
			fail(scenario, "SKIPPED -- Anna was not offered and remembered as a passer-by to begin with")
			return
		end
		-- She joins the party.
		Mock.groupSize = 2
		Mock.advance(1)
		local after = entryFor(ns, ANNA)
		if after then
			fail(scenario, "with People in my group switched off, Anna is offered as '" .. tostring(after.reason)
				.. "' (from the passer-by memory of before she joined) in the seconds after she joins the party")
		end
		-- The scan says so as a verdict, which the prompt's cursor hold reads, and
		-- the memory of her goes with it.
		local _, rejected = ns.BuildQueue()
		if type(rejected) ~= "table" or rejected[ANNA] ~= true then
			fail(scenario, "no verdict was written for a group member the switch turns away: "
				.. tostring(type(rejected) == "table" and rejected[ANNA]))
		end
		if ns.passersBy[ANNA] then
			fail(scenario, "the passer-by memory of Anna outlived the verdict on her")
		end
	end)
	-- Control: with the switch on she is offered as a group member after she joins.
	run(scenario, nil, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers = true, true
		Mock.advance(60)
		Mock.groupSize = 2
		Mock.advance(1)
		local after = entryFor(ns, ANNA)
		if not (after and after.reason == "group") then
			fail(scenario, "SKIPPED -- with People in my group on, Anna was not offered as a group member: "
				.. tostring(after and after.reason))
		end
	end)
end

-- ------------------------------------------------------ yourself, never-offered
-- queue-selfbufffirst-ignores-never-list-self (Queue.lua SelfBuffFirst,
-- Commands.lua MyselfLines)
--
-- SelfEntry, which builds the entry for yourself, ends on `ListedAs(full,
-- verdict)`: your own name on the never-offer list means "no offer for you".
-- SelfBuffFirst, which /manners debug and Diagnostics ask "which group buff
-- would the prompt be on for you", had no such test, so with your own name
-- listed the debug page said "your own Arcane Intellect comes first -- the
-- buffs below wait until it has been cast" while the prompt offered you
-- nothing.
do
	local scenario = "hunt23-queue: your own buff does not come first while your name is never-offered"
	-- A mage who knows Arcane Intellect and her armors, as tests/scenarios/ownbuffs.lua
	-- has her: /manners debug only speaks of "your own X comes first" with a
	-- family of her own to put behind it.
	local known = {}
	for _, id in ipairs({ 1459, 1460, 1461, 10156, 10157, 23028, 168, 7300, 7301, 7302, 6117 }) do
		known[id] = true
	end
	local function comesFirst(ns)
		for _, line in ipairs(ns.MyselfLines(GetTime())) do
			if line:find("comes first", 1, true) then return line end
		end
	end
	local function before()
		local is = function(id) return known[id] == true end
		rawset(_G, "IsSpellKnown", is)
		rawset(_G, "IsPlayerSpell", is)
	end
	run(scenario, nil, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		local db = ns.db.profile
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(60)
		local me = ns.UnitFullName("player")
		local mine = entryFor(ns, me)
		if not (mine and mine.reason == "self") then
			fail(scenario, "SKIPPED -- you were not offered your own buff to begin with")
			return
		end
		local first = ns.SelfBuffFirst(db, GetTime())
		if not first then
			fail(scenario, "SKIPPED -- SelfBuffFirst found no group buff for you before the listing")
			return
		end
		-- Retail's mage has no family of her own (Buffs.lua, `own = {}`), so its
		-- debug page has no such line to be wrong; there only the prompt's side,
		-- SelfBuffFirst, is held to the list.
		local says = next(ns.OWN_BUFFS.MAGE or {}) ~= nil
		if says and not comesFirst(ns) then
			fail(scenario, "SKIPPED -- /manners debug did not say your own buff comes first before the listing")
			return
		end
		-- Somebody else on the list changes nothing for you.
		db.never["Somebody Else"] = true
		if not ns.SelfBuffFirst(db, GetTime()) then
			fail(scenario, "somebody else's name on the never-offer list took your own buff off SelfBuffFirst")
		end
		db.never["Somebody Else"] = nil
		db.never[me] = true
		Mock.advance(20)
		if entryFor(ns, me) then
			fail(scenario, "SKIPPED -- your own name on the never-offer list did not stop the offer")
			return
		end
		local still = ns.SelfBuffFirst(db, GetTime())
		if still then
			fail(scenario, "the prompt offers you nothing (your own name is on the never-offer list), yet"
				.. " SelfBuffFirst, which /manners debug reads, says your own " .. tostring(still.key)
				.. " comes first")
		end
		-- And the line /manners debug prints from it.
		local line = comesFirst(ns)
		if line then fail(scenario, "/manners debug says: " .. line) end
		-- Taken off the list, it is the first again.
		db.never[me] = nil
		if not ns.SelfBuffFirst(db, GetTime()) then
			fail(scenario, "taken off the never-offer list, your own buff did not come first again")
		end
	end, before)
end
