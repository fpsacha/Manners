-- Profiles from the page, and switching by where you are (AutoProfile.lua).
--
-- A player asked for "profiles, like auto switch in raid, instance, normal,
-- save, edit, delete". The Profiles page makes a profile (from the defaults or
-- from the settings in use), renames the one in use, copies, deletes and
-- resets; and a character can have a profile picked for the open world, a
-- dungeon, a raid and a battleground, switched to on arriving there.
--
-- Every scenario name starts with "autoprofile:" so the mutations in
-- tests/mutations/autoprofile.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local TOUCHED = { "IsInInstance", "GetCurrentKeyBoardFocus" }

-- The mock's AceDB switches profiles the library's way and has none of its
-- other calls. Added here as the library has them: the names, a copy into the
-- profile in use (emptied first, its callback fired), a delete that refuses
-- the profile in use, a reset, and its record of who is on which profile.
local function account(ns)
	local db, sv = ns.db, Mock.sv
	local defaults = ns.defaults.profile
	local function fill(dest, src)
		for k, v in pairs(src) do
			if type(v) == "table" then
				if type(dest[k]) ~= "table" then dest[k] = {} end
				fill(dest[k], v)
			elseif dest[k] == nil then
				dest[k] = v
			end
		end
	end
	local function copy(dest, src)
		for k, v in pairs(src) do
			if type(v) == "table" then
				dest[k] = {}
				copy(dest[k], v)
			else
				dest[k] = v
			end
		end
	end
	local function fire(event, ...)
		local cb = Mock.dbCallbacks[event]
		if cb then cb.target[cb.method](cb.target, event, db, ...) end
	end
	local function current() return sv.profileName or "Default" end
	sv.profiles = sv.profiles or {}
	sv.profileKeys = sv.profileKeys or {}
	db.sv = sv
	db.GetCurrentProfile = function() return current() end
	db.GetProfiles = function(_, out)
		out = out or {}
		local seen = {}
		for name in pairs(sv.profiles) do
			out[#out + 1] = name
			seen[name] = true
		end
		if not seen[current()] then out[#out + 1] = current() end
		return out, #out
	end
	db.CopyProfile = function(self, name)
		if name == current() then error("Cannot have the same source and destination profiles.") end
		local source = sv.profiles[name]
		if type(source) ~= "table" then error("Cannot copy profile '" .. tostring(name) .. "'. It does not exist.") end
		wipe(self.profile)
		copy(self.profile, source)
		fill(self.profile, defaults)
		fire("OnProfileCopied", name)
	end
	db.DeleteProfile = function(_, name)
		if name == current() then error("Cannot delete the active profile in an AceDBObject.") end
		if not sv.profiles[name] then error("Cannot delete profile '" .. tostring(name) .. "'. It does not exist.") end
		sv.profiles[name] = nil
		fire("OnProfileDeleted", name)
	end
	db.ResetProfile = function(self)
		wipe(self.profile)
		fill(self.profile, defaults)
		fire("OnProfileReset")
	end
end

local function place(inside, kind)
	rawset(_G, "IsInInstance", function() return inside, kind end)
end

-- A loading screen's event, and the settle after it.
local function arrive(inside, kind, event)
	place(inside, kind)
	Mock.frameEvent(event or "PLAYER_ENTERING_WORLD")
	Mock.runTimers(2)
end

-- The character's rules, as the page's controls write them.
local function controls(ns)
	return ns.optionsTable.args.profiles.args
end

local function rule(ns, at, name)
	controls(ns)["auto_" .. at].set(nil, name or "")
end

local function switchOn(ns, on)
	controls(ns).autoEnabled.set(nil, on ~= false)
end

-- A profile picked in the page's dropdown, and one of the buttons under it
-- pressed (Use, Delete, Copy into the profile in use, ...).
local function act(ns, name, button)
	local c = controls(ns)
	c.choose.set(nil, name)
	c[button].func()
end

-- Profiles made and left again, so each exists in the saved file.
local function make(ns, ...)
	local home = ns.db:GetCurrentProfile()
	for _, name in ipairs({ ... }) do ns.db:SetProfile(name) end
	ns.db:SetProfile(home)
end

local function said() return table.concat(Mock.printed, "\n") end

-- A session out in the world, the login's own lines over, with the library's
-- calls there and nothing said yet.
local function with(scenario, body)
	Mock.reset()
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	place(false, "none")
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		account(ns)
		-- The login's line, and the key reminder it asks for twenty seconds on.
		Mock.runTimers(5)
		Mock.runTimers(30)
		Mock.printed = {}
		body(ns, ns.Profiles)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function uses(scenario, ns, want, when)
	local got = ns.db:GetCurrentProfile()
	if got ~= want then
		fail(scenario, ("%s: the profile in use is %s, not %s"):format(when, tostring(got), want))
		return false
	end
	return true
end

-- ------------------------------------------------------------------ off
do
	local scenario = "autoprofile: off by default, and then an arrival switches nothing"
	with(scenario, function(ns)
		local c = controls(ns)
		if c.autoEnabled.get() ~= false then fail(scenario, "Switch profile automatically is not off by default") end
		if c.autoSay.get() ~= true then fail(scenario, "Say so in chat is not on by default") end
		for _, at in ipairs({ "world", "dungeon", "raid", "battle" }) do
			if c["auto_" .. at].get() ~= "" then fail(scenario, at .. " does not start on Do not switch") end
			if c["auto_" .. at].disabled() ~= true then fail(scenario, at .. " is not greyed while the switch is off") end
		end
		make(ns, "Raid")
		rule(ns, "raid", "Raid")
		arrive(true, "raid")
		uses(scenario, ns, "Default", "in a raid with the switch off")
		if said() ~= "" then fail(scenario, "something was said with the switch off: " .. said()) end
	end)
end

-- ------------------------------------------------------------------ each place
do
	local scenario = "autoprofile: each situation switches to the profile picked for it"
	with(scenario, function(ns)
		make(ns, "World", "Dungeon", "Raid", "Battle")
		switchOn(ns)
		rule(ns, "world", "World")
		rule(ns, "dungeon", "Dungeon")
		rule(ns, "raid", "Raid")
		rule(ns, "battle", "Battle")
		-- Turning it on was no arrival: still where it was, on what it was.
		arrive(false, "none", "ZONE_CHANGED_NEW_AREA")
		uses(scenario, ns, "Default", "out in the world, where the switch was turned on")
		for _, step in ipairs({
			{ true, "raid", "Raid" }, { true, "party", "Dungeon" }, { true, "pvp", "Battle" },
			{ false, "none", "World" }, { true, "arena", "Battle" }, { true, "scenario", "Dungeon" },
			-- The game's 1 for "inside", as some clients say it.
			{ 1, "raid", "Raid" },
		}) do
			arrive(step[1], step[2])
			uses(scenario, ns, step[3], "arriving in " .. step[2])
		end
		-- A raid group out in the world is the open world.
		Mock.raid = { size = 10 }
		arrive(false, "none")
		uses(scenario, ns, "World", "in a raid group outside an instance")
		Mock.raid = nil
	end)
end

do
	local scenario = "autoprofile: a place the game will not name switches nothing"
	with(scenario, function(ns)
		make(ns, "World", "Raid")
		switchOn(ns)
		rule(ns, "world", "World")
		rule(ns, "raid", "Raid")
		arrive(true, "raid")
		uses(scenario, ns, "Raid", "arriving in a raid")
		rawset(_G, "IsInInstance", function() return nil, nil end)
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.runTimers(2)
		uses(scenario, ns, "Raid", "the game saying nothing of where this is")
		rawset(_G, "IsInInstance", function() error("no") end)
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.runTimers(2)
		uses(scenario, ns, "Raid", "the game refusing to say where this is")
		ns.errors = {}
	end)
end

-- ------------------------------------------------------------------ settle
do
	local scenario = "autoprofile: a loading screen's events are one arrival, read once they have settled"
	with(scenario, function(ns)
		-- No profile picked for the raid: a switch has the rest of the addon
		-- ask where this is too.
		switchOn(ns)
		local asked = 0
		rawset(_G, "IsInInstance", function()
			asked = asked + 1
			return true, "raid"
		end)
		local st = ns.db.char.autoProfile
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.runTimers(1)
		Mock.frameEvent("ZONE_CHANGED_NEW_AREA")
		Mock.runTimers(1)
		if asked ~= 0 or st.at ~= "world" then
			fail(scenario, ("the place was read %d time(s) before the events had settled (at %s)")
				:format(asked, tostring(st.at)))
		end
		Mock.runTimers(1)
		if st.at ~= "raid" then fail(scenario, "the place was not read once the events had settled: " .. tostring(st.at)) end
		if asked ~= 1 then fail(scenario, "two zone events read the place " .. asked .. " times") end
	end)
end

-- ------------------------------------------------------------------ a fight
do
	local scenario = "autoprofile: a switch waits out a fight"
	with(scenario, function(ns)
		make(ns, "Raid")
		switchOn(ns)
		rule(ns, "raid", "Raid")
		Mock.inCombat = true
		arrive(true, "raid")
		Mock.runTimers(10)
		uses(scenario, ns, "Default", "in a fight")
		Mock.inCombat = false
		Mock.frameEvent("PLAYER_REGEN_ENABLED")
		Mock.runTimers(1)
		uses(scenario, ns, "Raid", "once the fight was over")
		Mock.inCombat = false
	end)
end

-- ------------------------------------------------------------------ held back
do
	local scenario = "autoprofile: a press waiting to be settled or a box being typed in holds the switch back"
	with(scenario, function(ns)
		make(ns, "Raid", "Dungeon")
		switchOn(ns)
		rule(ns, "raid", "Raid")
		rule(ns, "dungeon", "Dungeon")
		ns.pendingClick = { name = "Petra Stonewell", at = GetTime() }
		arrive(true, "raid")
		Mock.runTimers(3)
		uses(scenario, ns, "Default", "with a press waiting")
		ns.pendingClick = nil
		Mock.runTimers(1.1)
		uses(scenario, ns, "Raid", "once the press was settled")

		-- A box in the options window with the cursor in it.
		ns.OpenOptions("click")
		if not (ns.WindowUI and ns.WindowUI.Shown()) then
			fail(scenario, "SKIPPED -- the options window did not open")
			return
		end
		local box = {}
		rawset(_G, "GetCurrentKeyBoardFocus", function() return box end)
		arrive(true, "party")
		Mock.runTimers(3)
		uses(scenario, ns, "Raid", "with a box being typed in")
		box = nil
		Mock.runTimers(1.1)
		uses(scenario, ns, "Dungeon", "once the box was left")
		ns.WindowUI.Close()
	end)
end

-- ------------------------------------------------------------------ do not switch
do
	local scenario = "autoprofile: Do not switch leaves the profile as it is, and nothing is put back"
	with(scenario, function(ns)
		make(ns, "Raid")
		switchOn(ns)
		rule(ns, "raid", "Raid")
		arrive(true, "party")
		uses(scenario, ns, "Default", "in a dungeon set to Do not switch")
		arrive(true, "raid")
		uses(scenario, ns, "Raid", "in a raid")
		-- Out again: the open world says Do not switch, so Raid stays.
		arrive(false, "none")
		uses(scenario, ns, "Raid", "back in the world, set to Do not switch")
		if Mock.sv.profiles[""] ~= nil then fail(scenario, "Do not switch made a profile with no name") end
		-- A rule put back to Do not switch from the page.
		rule(ns, "raid", "")
		if ns.db.char.autoProfile.rules.raid ~= nil then fail(scenario, "Do not switch was saved as a profile's name") end
	end)
end

-- ------------------------------------------------------------------ deleted
do
	local scenario = "autoprofile: a deleted profile's rule goes back to Do not switch"
	with(scenario, function(ns)
		local c = controls(ns)
		make(ns, "Raid", "Dungeon")
		switchOn(ns)
		rule(ns, "raid", "Raid")
		rule(ns, "dungeon", "Dungeon")
		-- Deleted from the page.
		act(ns, "Raid", "delete")
		if Mock.sv.profiles.Raid ~= nil then fail(scenario, "SKIPPED -- the page did not delete the profile") end
		if ns.db.char.autoProfile.rules.raid ~= nil then
			fail(scenario, "the rule still names the profile deleted from the page: " .. tostring(ns.db.char.autoProfile.rules.raid))
		end
		if c.auto_raid.get() ~= "" then fail(scenario, "the raid's row still names the deleted profile: " .. tostring(c.auto_raid.get())) end
		if c.auto_dungeon.get() ~= "Dungeon" then fail(scenario, "deleting one profile cleared another's row") end
		arrive(true, "raid")
		uses(scenario, ns, "Default", "in a raid whose profile was deleted")
		if Mock.sv.profiles.Raid ~= nil then fail(scenario, "arriving made the deleted profile again") end
		-- Deleted behind this character's back (another character did it).
		arrive(false, "none")
		Mock.sv.profiles.Dungeon = nil
		arrive(true, "party")
		uses(scenario, ns, "Default", "in a dungeon whose profile another character deleted")
		if Mock.sv.profiles.Dungeon ~= nil then fail(scenario, "arriving made a profile another character deleted") end
		if ns.db.char.autoProfile.rules.dungeon ~= nil then
			fail(scenario, "the rule for a profile that is gone was kept")
		end
	end)
end

-- ------------------------------------------------------------------ by hand
do
	local scenario = "autoprofile: a profile picked by hand holds until the next arrival"
	with(scenario, function(ns, P)
		local c = controls(ns)
		make(ns, "Raid", "Mine")
		switchOn(ns)
		rule(ns, "raid", "Raid")
		arrive(true, "raid")
		uses(scenario, ns, "Raid", "in a raid")
		if not tostring(c.current.name()):find("in a raid", 1, true) then
			fail(scenario, "the page does not say why Raid is in use: " .. tostring(c.current.name()))
		end
		act(ns, "Mine", "use")
		uses(scenario, ns, "Mine", "after picking Mine on the page")
		if P.Why() ~= nil then fail(scenario, "the page still says automatic switching chose it: " .. tostring(P.Why())) end
		-- Back to Raid by hand: the player's choice now, not the raid's.
		act(ns, "Raid", "use")
		if P.Why() ~= nil then
			fail(scenario, "a profile picked by hand reads as chosen automatically: " .. tostring(P.Why()))
		end
		act(ns, "Mine", "use")
		-- Another zone of the same raid, and a /reload inside it: no arrival.
		arrive(true, "raid", "ZONE_CHANGED_NEW_AREA")
		arrive(true, "raid")
		uses(scenario, ns, "Mine", "moving about inside the same raid")
		-- Where the character was is saved, so a login in the same place is none.
		if ns.db.char.autoProfile.at ~= "raid" then
			fail(scenario, "where the character last arrived is not saved: " .. tostring(ns.db.char.autoProfile.at))
		end
		arrive(false, "none")
		uses(scenario, ns, "Mine", "out in the world, set to Do not switch")
		arrive(true, "raid")
		uses(scenario, ns, "Raid", "arriving in the raid again")
	end)
end

-- ------------------------------------------------------------------ quiet
do
	local scenario = "autoprofile: an automatic switch says one line and turns nothing on or off"
	with(scenario, function(ns)
		local M = ns.Milestones
		make(ns, "Raid")
		switchOn(ns)
		rule(ns, "raid", "Raid")
		-- Milestones on in both profiles, the ledger's past read, and one
		-- passed that nothing has looked at yet.
		ns.db.char.milestones = nil
		M.Switched()
		local st = ns.db.char.milestones
		if not (type(st) == "table" and type(st.n) == "table" and st.seeded) then
			fail(scenario, "SKIPPED -- no milestones to count in")
			return
		end
		st.n.strangers = 100
		local hints, reminders, welcomed = ns.db.char.hints, ns.db.char.keyReminders, ns.db.char.welcomed
		local firstRun = ns.db.profile.firstRun
		local repaints = 0
		local Refresh = ns.Prompt.Refresh
		ns.Prompt.Refresh = function(...)
			repaints = repaints + 1
			return Refresh(...)
		end
		Mock.printed = {}
		arrive(true, "raid")
		Mock.runTimers(40)
		ns.Prompt.Refresh = Refresh
		if not uses(scenario, ns, "Raid", "in a raid") then return end
		if #Mock.printed ~= 1 then
			fail(scenario, ("%d line(s) in chat for one automatic switch: %s"):format(#Mock.printed, said()))
		end
		local line = tostring(Mock.printed[1])
		if not (line:find("Raid", 1, true) and line:find("in a raid", 1, true)) then
			fail(scenario, "the line does not name the profile and the place: " .. line)
		end
		if st.earned.strangers ~= nil then
			fail(scenario, "the switch marked a milestone as passed, as turning Milestones on does: "
				.. tostring(st.earned.strangers))
		end
		local toast = M.ToastFrame()
		if toast and toast:IsShown() then fail(scenario, "a toast for an automatic switch") end
		if ns.db.char.hints ~= hints or ns.db.char.keyReminders ~= reminders or ns.db.char.welcomed ~= welcomed then
			fail(scenario, "the switch said a hint, the key reminder or the greeting again")
		end
		if ns.db.profile.firstRun ~= firstRun then
			fail(scenario, "the profile arrived at asks Start here's first questions: " .. tostring(ns.db.profile.firstRun))
		end
		if repaints == 0 then fail(scenario, "the prompt was not painted again for the new profile") end
		-- Still to be had, out loud, the next time milestones are counted.
		Mock.printed = {}
		M.Note("res")
		if not (type(st.earned.strangers) == "number" and st.earned.strangers > 0) then
			fail(scenario, "the milestone was not earned aloud afterwards: " .. tostring(st.earned.strangers))
		end
		-- A profile with Milestones off is the switch turned, as it ever was.
		ns.db:SetProfile("Default")
		ns.db.profile.milestones.enabled = false
		ns.db:SetProfile("Raid")
		st.n.courtesy = 1
		rule(ns, "world", "Default")
		arrive(false, "none")
		uses(scenario, ns, "Default", "back in the world")
		if M.On() then fail(scenario, "SKIPPED -- milestones are on in the profile that has them off") end
	end)
end

do
	local scenario = "autoprofile: the chat line has its own tick, and keeps to Say nothing at all in chat"
	with(scenario, function(ns)
		local c = controls(ns)
		make(ns, "Raid", "Quiet")
		ns.db:SetProfile("Quiet")
		ns.db.profile.silentChat = true
		ns.db:SetProfile("Default")
		switchOn(ns)
		rule(ns, "raid", "Raid")
		rule(ns, "dungeon", "Quiet")
		rule(ns, "world", "Default")
		c.autoSay.set(nil, false)
		Mock.printed = {}
		arrive(true, "raid")
		uses(scenario, ns, "Raid", "in a raid")
		if said() ~= "" then fail(scenario, "a line with Say so in chat unticked: " .. said()) end
		c.autoSay.set(nil, true)
		arrive(false, "none")
		if not said():find("in the open world", 1, true) then
			fail(scenario, "no line with Say so in chat ticked: " .. said())
		end
		-- The profile arrived at hides every line of Manners' own.
		Mock.printed = {}
		arrive(true, "party")
		uses(scenario, ns, "Quiet", "in a dungeon")
		if said() ~= "" then fail(scenario, "a line on a profile that says nothing in chat: " .. said()) end
	end)
end

-- ------------------------------------------------------------------ the page
do
	local scenario = "autoprofile: the page makes a profile from the defaults or from the settings in use"
	with(scenario, function(ns, P)
		local c = controls(ns)
		ns.db.profile.verbose = false
		for _, case in ipairs({
			{ "", "Type a name first" }, { "   ", "Type a name first" },
			{ "Default", "already a profile called Default" },
			{ ("x"):rep(51), "50 characters" },
		}) do
			local answer = c.new.validate(nil, case[1])
			if not (type(answer) == "string" and answer:find(case[2], 1, true)) then
				fail(scenario, ("the name %q is answered %s"):format(case[1], tostring(answer)))
			end
		end
		-- Fifty letters with accents are fifty, not a hundred bytes.
		if c.new.validate(nil, ("\195\169"):rep(50)) ~= true then fail(scenario, "fifty accented letters are refused") end
		if c.new.validate(nil, "Solo") ~= true then fail(scenario, "a new name is refused") end
		c.new.set(nil, "  Solo ")
		if not uses(scenario, ns, "Solo", "after New profile") then return end
		if ns.db.profile.verbose ~= true then fail(scenario, "a new profile did not start at the defaults") end
		ns.db:SetProfile("Default")
		-- Duplicate: a copy of the picked profile (the one in use) under the
		-- name typed, nobody moved onto it.
		c.name.set(nil, "Twin")
		c.duplicate.func()
		if not uses(scenario, ns, "Default", "after Duplicate") then return end
		if c.choose.get() ~= "Twin" then fail(scenario, "the copy is not the profile picked after Duplicate") end
		ns.db:SetProfile("Twin")
		if ns.db.profile.verbose ~= false then fail(scenario, "the copy does not have the settings that were in use") end
		ns.db:SetProfile("Default")
		if ns.db.profile.verbose ~= false then fail(scenario, "making a copy changed the profile copied") end
		-- A name already taken makes nothing.
		c.name.set(nil, "Solo")
		if c.duplicate.disabled() ~= true then fail(scenario, "Duplicate is not greyed for a name already taken") end
		local before = 0
		for _ in pairs(Mock.sv.profiles) do before = before + 1 end
		c.duplicate.func()
		local after = 0
		for _ in pairs(Mock.sv.profiles) do after = after + 1 end
		if after ~= before then fail(scenario, "Duplicate made a profile under a name already taken") end
		uses(scenario, ns, "Default", "after asking for a name already taken")
		-- The dropdown lists them all; Use switches to the one picked.
		local values = c.choose.values()
		for _, name in ipairs({ "Default", "Solo", "Twin" }) do
			if values[name] == nil then fail(scenario, "the dropdown does not list " .. name) end
		end
		if c.choose.get() ~= "Default" then fail(scenario, "the dropdown does not start on the one in use") end
		c.choose.set(nil, "Twin")
		if c.choose.get() ~= "Twin" then fail(scenario, "the dropdown does not keep the profile picked") end
		c.choose.set(nil, "Solo")
		c.use.func()
		uses(scenario, ns, "Solo", "after Use")
		if c.choose.get() ~= "Solo" then fail(scenario, "the dropdown does not show the one in use") end
		if not tostring(c.editNote.name):find("switch to it", 1, true) then
			fail(scenario, "the page does not say how a profile is edited")
		end
		-- Not in a fight: a switch moves the prompt and rewrites its macro.
		Mock.inCombat = true
		c.choose.set(nil, "Twin")
		c.use.func()
		c.new.set(nil, "Fight")
		uses(scenario, ns, "Solo", "in a fight")
		if c.new.disabled() ~= true or c.use.disabled() ~= true then fail(scenario, "the controls are not greyed in a fight") end
		if Mock.sv.profiles.Fight ~= nil then fail(scenario, "a profile was made in a fight") end
		Mock.inCombat = false
	end)
end

do
	local scenario = "autoprofile: the page never deletes the profile in use, and asks before deleting, copying over or resetting"
	with(scenario, function(ns, P)
		local c = controls(ns)
		make(ns, "Raid", "Spare")
		-- The profile in use picked: Delete and Copy into are greyed, and say why.
		c.choose.set(nil, "Default")
		if c.delete.disabled() ~= true then fail(scenario, "Delete is not greyed for the profile in use") end
		if c.pickNote.hidden() or not tostring(c.pickNote.name()):find("profile in use", 1, true) then
			fail(scenario, "the page does not say why Delete is greyed: " .. tostring(c.pickNote.name()))
		end
		c.delete.func()
		if P.Delete("Default") ~= false or ns.db:GetCurrentProfile() ~= "Default" then
			fail(scenario, "the profile in use was deleted")
		end
		c.choose.set(nil, "Raid")
		if c.delete.disabled() ~= false then fail(scenario, "Delete is greyed for another profile") end
		local question = type(c.delete.confirm) == "function" and c.delete.confirm()
		if not (type(question) == "string" and question:find("Raid", 1, true)) then
			fail(scenario, "Delete does not ask first, naming the profile: " .. tostring(question))
		end
		if c.resetProfile.confirm ~= true or type(c.resetProfile.confirmText) ~= "string" then fail(scenario, "Reset does not ask first") end
		local ask = type(c.copyfrom.confirm) == "function" and c.copyfrom.confirm()
		if not (type(ask) == "string" and ask:find("Raid", 1, true)) then
			fail(scenario, "Copy from does not ask first, naming the profile: " .. tostring(ask))
		end
		act(ns, "Spare", "delete")
		if Mock.sv.profiles.Spare ~= nil then fail(scenario, "Delete did not delete the profile picked") end
		-- Copy into the profile in use: the other profile's settings over this one's.
		ns.db:SetProfile("Raid")
		ns.db.profile.verbose = false
		ns.db:SetProfile("Default")
		act(ns, "Raid", "copyfrom")
		uses(scenario, ns, "Default", "after Copy from")
		if ns.db.profile.verbose ~= false then fail(scenario, "Copy from did not bring the other profile's settings") end
		-- Reset: back to the defaults.
		c.resetProfile.func()
		if ns.db.profile.verbose ~= true then fail(scenario, "Reset left a setting off its default") end
		-- With no other profile there is nothing to copy from or delete.
		act(ns, "Raid", "delete")
		if c.delete.disabled() ~= true or c.copyfrom.disabled() ~= true then
			fail(scenario, "Delete and Copy from are not greyed with one profile")
		end
	end)
end

do
	local scenario = "autoprofile: renaming a profile keeps its settings, its characters and the rules that name it"
	with(scenario, function(ns, P)
		local c = controls(ns)
		make(ns, "Raid")
		switchOn(ns)
		rule(ns, "raid", "Raid")
		rule(ns, "world", "Default")
		arrive(true, "raid")
		if not uses(scenario, ns, "Raid", "in a raid") then return end
		ns.db.profile.verbose = false
		-- An alt on the same profile, with a rule of its own that names it.
		Mock.sv.profileKeys["Alt - Mockrealm"] = "Raid"
		Mock.sv.profileKeys["Other - Mockrealm"] = "Default"
		Mock.sv.char = Mock.sv.char or {}
		local alt = { autoProfile = { enabled = true, rules = { raid = "Raid", world = "Default" } } }
		ns.db.sv.char = { ["Alt - Mockrealm"] = alt }
		c.choose.set(nil, "Raid")
		c.name.set(nil, "Default")
		if c.rename.disabled() ~= true then fail(scenario, "a rename onto a name already taken is let through") end
		c.name.set(nil, "Raiding")
		c.rename.func()
		if not uses(scenario, ns, "Raiding", "after the rename") then return end
		if Mock.sv.profiles.Raid ~= nil then fail(scenario, "the old name is still a profile") end
		if ns.db.profile.verbose ~= false then fail(scenario, "the renamed profile lost a setting") end
		if c.auto_raid.get() ~= "Raiding" then
			fail(scenario, "the rule that named the profile did not follow it: " .. tostring(c.auto_raid.get()))
		end
		if c.auto_world.get() ~= "Default" then fail(scenario, "a rule naming another profile changed") end
		if Mock.sv.profileKeys["Alt - Mockrealm"] ~= "Raiding" then fail(scenario, "an alt on the profile was left on the old name") end
		if Mock.sv.profileKeys["Other - Mockrealm"] ~= "Default" then fail(scenario, "a character on another profile was moved") end
		if alt.autoProfile.rules.raid ~= "Raiding" or alt.autoProfile.rules.world ~= "Default" then
			fail(scenario, "an alt's rule naming the profile did not follow it")
		end
		-- Still the one automatic switching chose, under its new name.
		if not tostring(P.Why()):find("in a raid", 1, true) then
			fail(scenario, "the rename forgot why the profile is in use: " .. tostring(P.Why()))
		end
		ns.db.sv.char = nil
	end)
end

do
	local scenario = "autoprofile: the rules are the character's own, repaired as they are read"
	with(scenario, function(ns)
		local c = controls(ns)
		make(ns, "Raid")
		ns.db.char.autoProfile = { enabled = "yes", say = 3, rules = { raid = "Raid", moon = "Raid", dungeon = 7 },
			at = "moon", chose = "Raid" }
		if c.autoEnabled.get() ~= false then fail(scenario, "a damaged switch reads as on") end
		local st = ns.db.char.autoProfile
		if st.rules.raid ~= "Raid" or st.rules.moon ~= nil or st.rules.dungeon ~= nil then
			fail(scenario, "the damaged rules were not repaired")
		end
		if st.at ~= nil or st.chose ~= nil or st.say ~= true then fail(scenario, "the damaged memory was not repaired") end
		-- Nothing of it is in the profile, so no pasted settings line carries it.
		for key in pairs(ns.db.profile) do
			if tostring(key):lower():find("autoprofile", 1, true) then fail(scenario, "the rules are in the profile: " .. tostring(key)) end
		end
		local text = ns.ExportSettings() or ""
		if text:lower():find("autoprofile", 1, true) then fail(scenario, "the settings line carries the rules") end
	end)
end

-- ------------------------------------------------------------------ the window
do
	local scenario = "autoprofile: the window draws the section, the rows gone while the switch is off"
	with(scenario, function(ns)
		local UI = ns.WindowUI
		if not H.layoutInToc() then return end
		make(ns, "Raid")
		ns.OpenOptions("profiles")
		if not (UI and UI.Shown()) then
			fail(scenario, "SKIPPED -- the options window did not open")
			return
		end
		for _, path in ipairs({ "profiles.autoEnabled", "profiles.switchNote", "profiles.new", "profiles.duplicate",
			"profiles.rename", "profiles.choose", "profiles.delete", "profiles.resetProfile", "profiles.current" }) do
			if not UI.RowShown(path) then fail(scenario, path .. " is not drawn on Profiles") end
		end
		if UI.RowShown("profiles.auto_raid") or UI.RowShown("profiles.autoSay") then
			fail(scenario, "a situation's row is drawn while the switch is off")
		end
		switchOn(ns)
		ns.RepaintOptions()
		Mock.runTimers(1)
		for _, path in ipairs({ "profiles.auto_world", "profiles.auto_dungeon", "profiles.auto_raid", "profiles.auto_battle",
			"profiles.autoSay" }) do
			if not UI.RowShown(path) then fail(scenario, path .. " is not drawn with the switch on") end
		end
		-- Search knows the words it was asked for by, and which switch to turn on.
		local layout = ns.WindowLayout
		if not tostring(layout.keywords["profiles.autoEnabled"]):find("raid", 1, true) then
			fail(scenario, "search has no words for the switch")
		end
		if layout.parents["profiles.auto_raid"] ~= "profiles.autoEnabled" then
			fail(scenario, "search is not told which switch shows a situation's row")
		end
		UI.Close()
	end)
end
