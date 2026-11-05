-- "Never remind me about" (1.11.1): a player asked on CurseForge for an
-- exception for one self buff, Sense Undead, to stop its reminders without
-- turning off the rest of the family. Under "Myself" on Who to buff, the
-- spells of a family of several (tracking, an armor, an aspect) that you know
-- can be ticked one by one (ownBuffs.leave, a false per spell by default). A
-- ticked spell is skipped by Automatic, which then offers the next one of its
-- kind, and is never offered even when it is the family's pick or the one you
-- are wearing; a family with nothing left to offer stops counting as a
-- reminder. Core.lua holds the rule (LeftOut, OwnVerdict, OwnReminds), Who.lua
-- the control, and it is repaired, reset and shared like the picks.
--
-- Every scenario name starts with "ownleave:" so the mutations in
-- tests/mutations/ownleave.py can name the one that has to catch them.
--
-- Tracking is the minimap's tracking list on this client, not an aura, so the
-- scenarios drive a stand-in C_Minimap as tracking.lua does.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption = H.findOption

local FIND_HERBS, FIND_MINERALS, SENSE_UNDEAD = 2383, 2580, 5502

local function minimap(entries)
	if entries == nil then
		rawset(_G, "C_Minimap", nil)
		return
	end
	rawset(_G, "C_Minimap", {
		GetNumTrackingTypes = function() return #entries end,
		GetTrackingInfo = function(i) return entries[i] end,
	})
end

local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
local function learn(...)
	local known = { [1459] = true }
	for i = 1, select("#", ...) do known[select(i, ...)] = true end
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
end
local function unlearn()
	rawset(_G, "IsSpellKnown", realKnown)
	rawset(_G, "IsPlayerSpell", realPlayer)
	minimap(nil)
end

local function tracking(ns)
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if family.tracking then return family end
	end
	return nil
end

-- A scenario with the given tracking skills known and on the minimap's list,
-- all of them off; body(ns, family, ctx) runs on a driven session. Put back
-- after, whatever happens.
local function session(scenario, ids, body)
	Mock.reset()
	local list = {}
	for i, id in ipairs(ids) do list[i] = { spellID = id, active = false } end
	minimap(list)
	learn(unpack(ids))
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.ForgetTrackingList()
		local ok, err = pcall(function()
			local family = tracking(ns)
			if not family then
				fail(scenario, "SKIPPED -- tracking is not one of your own buffs here")
				return
			end
			local ctx = { name = ns.UnitFullName("player"), now = GetTime(), whenBuffed = "skip" }
			body(ns, family, ctx, list)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
		if not ok then fail(scenario, "errored: " .. tostring(err)) end
	end
	unlearn()
end

local function remember(ns, key)
	ns.db.char.ownLast = ns.db.char.ownLast or {}
	ns.db.char.ownLast.tracking = key
end

local function offered(ns, family, ctx)
	local spell, up, _, why = ns.OwnVerdict(family, ctx)
	return spell and spell.key or nil, why, up
end

-- ------------------------------------------------------------------ Automatic

do
	local scenario = "ownleave: a spell ticked is skipped and the rest of its kind still reminds"
	session(scenario, { FIND_HERBS, SENSE_UNDEAD }, function(ns, family, ctx)
		remember(ns, "senseundead")
		local first = offered(ns, family, ctx)
		if first ~= "senseundead" then
			fail(scenario, "SKIPPED -- the one you had up last was not offered to begin with: " .. tostring(first))
			return
		end
		ns.db.profile.ownBuffs.leave.senseundead = true
		local now, why = offered(ns, family, ctx)
		if now == "senseundead" then
			fail(scenario, "Sense Undead is ticked under Never remind me about and was offered")
		elseif now ~= "findherbs" then
			fail(scenario, ("with Sense Undead left out the rest of tracking was not offered: %s (%s)")
				:format(tostring(now), tostring(why)))
		end
		-- Unticked, it is the one you had up last again.
		ns.db.profile.ownBuffs.leave.senseundead = false
		if offered(ns, family, ctx) ~= "senseundead" then
			fail(scenario, "unticking Sense Undead did not bring its reminder back")
		end
		-- With nothing remembered Automatic takes the first of the kind you know;
		-- ticked, the next one. (Not the one the verdict would turn away itself.)
		remember(ns, nil)
		ns.db.profile.ownBuffs.leave.findherbs = true
		local next = offered(ns, family, ctx)
		if next ~= "senseundead" then
			fail(scenario, "Find Herbs ticked and nothing remembered: Automatic offered " .. tostring(next)
				.. ", not Sense Undead")
		end
	end)
end

do
	local scenario = "ownleave: every spell of a kind ticked leaves nothing to offer"
	session(scenario, { FIND_HERBS, SENSE_UNDEAD }, function(ns, family, ctx)
		local leave = ns.db.profile.ownBuffs.leave
		leave.senseundead, leave.findherbs = true, true
		local spell, why = offered(ns, family, ctx)
		if spell then
			fail(scenario, "tracking with all its spells ticked still offered " .. tostring(spell))
		elseif why ~= "none" then
			fail(scenario, "the reason for nothing to offer was " .. tostring(why) .. ", not none")
		end
		if ns.OwnReminds(family) then
			fail(scenario, "a family with every spell ticked still counts as reminding you")
		end
		leave.findherbs = false
		if not ns.OwnReminds(family) then
			fail(scenario, "a family with one spell not ticked does not count as reminding you")
		end
	end)
end

do
	local scenario = "ownleave: Sense Undead alone, ticked, stops its reminder"
	session(scenario, { SENSE_UNDEAD }, function(ns, family, ctx)
		if offered(ns, family, ctx) ~= "senseundead" then
			fail(scenario, "SKIPPED -- Sense Undead alone was not offered to begin with")
			return
		end
		ns.db.profile.ownBuffs.leave.senseundead = true
		local spell = offered(ns, family, ctx)
		if spell then
			fail(scenario, "Sense Undead ticked, and it is still offered when it is all you know of tracking")
		end
		if ns.OwnFamiliesOn() ~= 0 then
			fail(scenario, "Myself counts a family that has nothing left to remind you of")
		end
		ns.db.profile.ownBuffs.leave.senseundead = false
		if ns.OwnFamiliesOn() ~= 1 then
			fail(scenario, "unticked, the family does not count as a reminder again")
		end
	end)
end

-- A pin is the player's own pick; the tick is the later word.
do
	local scenario = "ownleave: a spell pinned and ticked is never offered"
	session(scenario, { FIND_HERBS, SENSE_UNDEAD }, function(ns, family, ctx)
		ns.db.profile.ownBuffs.pick.tracking = "senseundead"
		if offered(ns, family, ctx) ~= "senseundead" then
			fail(scenario, "SKIPPED -- the pin was not offered to begin with")
			return
		end
		ns.db.profile.ownBuffs.leave.senseundead = true
		local spell, why = offered(ns, family, ctx)
		if spell then
			fail(scenario, "a pinned spell that is ticked under Never remind me about was offered")
		elseif why ~= "leftout" then
			fail(scenario, "the reason was " .. tostring(why) .. ", not leftout")
		end
		local lines = table.concat(ns.MyselfLines(GetTime()), " / ")
		if not lines:find("ticked under Never remind me about", 1, true) then
			fail(scenario, "/manners debug does not say the spell is ticked: " .. lines)
		end
		if ns.OwnReminds(family) then
			fail(scenario, "a pinned spell that is ticked still counts as a reminder")
		end
	end)
end

-- ------------------------------------------------------------------ the saved settings

do
	local scenario = "ownleave: every spell of a family of several has a false by default"
	session(scenario, { FIND_HERBS }, function(ns)
		local leave = ns.db.profile.ownBuffs.leave
		if type(leave) ~= "table" then
			fail(scenario, "there is no leave-out table in the profile")
			return
		end
		for _, key in ipairs({ "findherbs", "senseundead", "trackbeasts" }) do
			if leave[key] ~= false then
				fail(scenario, ("%s is %s by default, not false"):format(key, tostring(leave[key])))
			end
		end
		-- Only a family of several spells has anything to tick.
		for key in pairs(leave) do
			local spell = ns.FindOwnSpell(key)
			local f = spell and spell.family
			-- Read off the family itself, not the rule that chose it.
			if not f or #f.spells < 2 or f.scroll or f.enhance or f.imbue or f.tank then
				fail(scenario, key .. " is in the leave-out table and is not a spell of a family of several")
			end
		end
	end)
end

do
	local scenario = "ownleave: a hand-edited file is put right"
	session(scenario, { FIND_HERBS, SENSE_UNDEAD }, function(ns)
		local own = ns.db.profile.ownBuffs
		own.leave.nosuchspell = true
		own.leave.senseundead = "yes"
		own.leave.findherbs = true
		own.leave.trackbeasts = nil
		ns.ClampSettings()
		if own.leave.nosuchspell ~= nil then
			fail(scenario, "a spell nobody has was kept in the leave-out table")
		end
		if own.leave.senseundead ~= false then
			fail(scenario, "a leave-out value that is not true or false was kept as " .. tostring(own.leave.senseundead))
		end
		if own.leave.findherbs ~= true then
			fail(scenario, "a spell ticked was un-ticked by the repair")
		end
		if own.leave.trackbeasts ~= false then
			fail(scenario, "a spell missing from the table was not given a false")
		end
		own.leave = "all of them"
		ns.ClampSettings()
		if type(own.leave) ~= "table" or own.leave.findherbs ~= false then
			fail(scenario, "a leave-out table that is not a table was not rebuilt")
		end
	end)
end

do
	local scenario = "ownleave: the ticks travel in a settings string"
	session(scenario, { FIND_HERBS, SENSE_UNDEAD }, function(ns)
		local leave = ns.db.profile.ownBuffs.leave
		leave.senseundead = true
		local text = ns.ExportSettings()
		if not text:find("ownBuffs.leave.senseundead=1", 1, true) then
			fail(scenario, "the export does not carry the tick: " .. text)
			return
		end
		leave.senseundead = false
		local ok, message = ns.ImportSettings(text)
		if not ok then
			fail(scenario, "its own export was refused: " .. tostring(message))
		elseif leave.senseundead ~= true then
			fail(scenario, "importing the string did not bring the tick back")
		end
		-- A tick of a spell only another game client has is not "newer".
		local elsewhere
		for key in pairs(ns.OWN_SPELL_ANY_CLIENT or {}) do
			if ns.FindOwnSpell(key) == nil then elsewhere = key break end
		end
		if not elsewhere then
			fail(scenario, "SKIPPED -- every spell on any client is on this one")
			return
		end
		local head = "MNR1:ownBuffs.leave." .. elsewhere .. "=1"
		local h = 0
		for i = 1, #head do h = (h * 31 + head:byte(i)) % 16777213 end
		local parsed = ns.ParseSettings(head .. ":" .. ("%06x"):format(h))
		if not parsed then
			fail(scenario, "a string with another client's spell was refused")
		elseif parsed.unknown ~= 0 then
			fail(scenario, ("another client's spell was counted as a later version's setting (%d)"):format(parsed.unknown))
		end
	end)
end

-- ------------------------------------------------------------------ the options page

do
	local scenario = "ownleave: the page lists the spells you know and writes the ticks"
	session(scenario, { FIND_HERBS, SENSE_UNDEAD }, function(ns)
		local control = findOption(ns.optionsTable, "own_leave")
		if not control then
			fail(scenario, "Who to buff has no Never remind me about control")
			return
		end
		if control.type ~= "multiselect" then fail(scenario, "the control is a " .. tostring(control.type)) end
		if control.hidden() then fail(scenario, "the control is hidden with two tracking skills known") end
		local values = control.values()
		if not (values.findherbs and values.senseundead) then
			fail(scenario, "the choices do not name the spells you know")
		end
		if values.trackbeasts then fail(scenario, "a spell you do not know is on the list") end
		if control.get({}, "senseundead") ~= false then fail(scenario, "nothing is ticked on a new profile") end
		control.set({}, "senseundead", true)
		if ns.db.profile.ownBuffs.leave.senseundead ~= true or control.get({}, "senseundead") ~= true then
			fail(scenario, "ticking a box did not write the profile")
		end
		control.set({}, "senseundead", false)
		if ns.db.profile.ownBuffs.leave.senseundead ~= false then
			fail(scenario, "unticking a box did not write the profile")
		end
	end)
end

do
	local scenario = "ownleave: the control is hidden when there is nothing to tick"
	Mock.reset()
	learn()
	minimap(nil)
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.ForgetTrackingList()
		local control = findOption(ns.optionsTable, "own_leave")
		if control and not control.hidden() then
			fail(scenario, "the control is shown with no tracking skill and no aspect known")
		end
	end
	unlearn()
end

do
	local scenario = "ownleave: the page's reset un-ticks every spell, and a tick marks the fold"
	session(scenario, { FIND_HERBS, SENSE_UNDEAD }, function(ns)
		local UI = ns.WindowUI
		local leave = ns.db.profile.ownBuffs.leave
		if UI and UI.Differs("who.own_leave") then
			fail(scenario, "nothing is ticked and the page is marked as changed")
		end
		leave.senseundead = true
		if UI and not UI.Differs("who.own_leave") then
			fail(scenario, "a tick does not mark Who to buff as changed from its defaults")
		end
		if ns.OptionsPage.ResetPage("who") ~= true then
			fail(scenario, "SKIPPED -- the reset did not run")
			return
		end
		if leave.senseundead ~= false or ns.db.profile.ownBuffs.leave.senseundead ~= false then
			fail(scenario, "the page's reset left a spell ticked")
		end
	end)
end

do
	local scenario = "ownleave: the Diagnostics report names what is ticked"
	session(scenario, { FIND_HERBS, SENSE_UNDEAD }, function(ns)
		local report = findOption(ns.optionsTable, "report")
		if not report then
			fail(scenario, "SKIPPED -- the report box is not in the model")
			return
		end
		ns.OptionsPage.reportOpen = true
		if report.get():find("own leftOut=", 1, true) then
			fail(scenario, "the report names a leave-out list with nothing ticked")
		end
		ns.db.profile.ownBuffs.leave.senseundead = true
		ns.db.profile.ownBuffs.leave.findherbs = true
		local text = report.get()
		ns.OptionsPage.reportOpen = nil
		if not text:find("own leftOut=findherbs,senseundead", 1, true) then
			fail(scenario, "the report does not name the spells ticked, sorted")
		end
	end)
end

-- A class with nothing for other players is told on Start here what the
-- prompt is for: its own buffs, less the ones left out.
do
	local scenario = "ownleave: Start here names only the families that still remind you"
	Mock.reset()
	Mock.class = "HUNTER"
	local list = { { spellID = 1494, active = false } }
	minimap(list)
	learn(1494)
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.ForgetTrackingList()
		local okay, err = pcall(function()
			if not tracking(ns) then
				fail(scenario, "SKIPPED -- Track Beasts is not one of a hunter's own buffs here")
				return
			end
			local text = ns.QuickSetup.OwnOnlySummary()
			if not text:find("Tracking", 1, true) then
				fail(scenario, "SKIPPED -- Start here does not name tracking to begin with: " .. text)
				return
			end
			ns.db.profile.ownBuffs.leave.trackbeasts = true
			text = ns.QuickSetup.OwnOnlySummary()
			if text:find("Tracking", 1, true) then
				fail(scenario, "Start here still names tracking with its one spell ticked: " .. text)
			end
		end)
		if not okay then fail(scenario, "errored: " .. tostring(err)) end
	end
	unlearn()
	Mock.reset()
end
