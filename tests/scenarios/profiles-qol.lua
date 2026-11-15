-- The Profiles page as a profile manager (AutoProfile.lua, 1.12): an
-- overview of every profile and who is on it, one dropdown that picks a
-- profile and buttons that act on the picked one, a line saying what the
-- last of them did with Undo beside it, a paste into a new profile, and the
-- profile a new character starts on.
--
-- Every scenario name starts with "profiles-qol:" so the mutations in
-- tests/mutations/profiles-qol.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local TOUCHED = { "GetRealmName", "MannersDB", "IsInInstance" }
local GOLD = "|cffffd100"

-- This character in AceDB's record of who uses what, as the mock writes it.
local ME = Mock.character .. " - Mockrealm"

-- The mock's AceDB has SetProfile alone. Added here as the library has them:
-- the names, a copy into the profile in use, a delete that refuses the
-- profile in use and takes every character off the deleted one, a reset,
-- this character's key, the account's own section, and SetProfile writing
-- who uses what, as the library's does.
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
	sv.profileKeys[ME] = current()
	db.sv = sv
	db.keys = { char = ME }
	sv.global = sv.global or {}
	db.global = db.global or sv.global
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
	local set = db.SetProfile
	db.SetProfile = function(self, name)
		set(self, name)
		sv.profileKeys[ME] = name
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
		for key, profile in pairs(sv.profileKeys) do
			if profile == name then sv.profileKeys[key] = nil end
		end
		fire("OnProfileDeleted", name)
	end
	db.ResetProfile = function(self)
		wipe(self.profile)
		fill(self.profile, defaults)
		fire("OnProfileReset")
	end
end

local function controls(ns) return ns.optionsTable.args.profiles.args end

-- Profiles made and left again, so each exists in the saved file.
local function make(ns, ...)
	local home = ns.db:GetCurrentProfile()
	for _, name in ipairs({ ... }) do ns.db:SetProfile(name) end
	ns.db:SetProfile(home)
end

-- A profile picked in the dropdown and one of the buttons under it pressed.
local function act(ns, name, button)
	local c = controls(ns)
	c.choose.set(nil, name)
	c[button].func()
end

local function named(ns, name)
	controls(ns).name.set(nil, name)
end

local function line(ns) return tostring(ns.Profiles.Status()) end

local function undoShown(ns)
	local undo = controls(ns).undo
	return not undo.hidden()
end

-- A session with the library's calls there and nothing said yet.
local function with(scenario, body)
	Mock.reset()
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		account(ns)
		Mock.runTimers(5)
		Mock.runTimers(30)
		Mock.printed = {}
		body(ns, ns.Profiles, controls(ns))
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.inCombat = false
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

-- A settings line that differs from the profile's own in the pane's width.
local function otherSettings(ns)
	local p = ns.db.profile
	local width = p.prompt.width
	local other = (width == 300) and 320 or 300
	p.prompt.width = other
	local text = ns.ExportSettings()
	p.prompt.width = width
	return text, other, width
end

-- ------------------------------------------------------------------ overview
do
	local scenario = "profiles-qol: the overview names every profile, who is on it and where switching sends this character"
	with(scenario, function(ns, P, c)
		make(ns, "Raid", "Solo", "Crowd")
		local keys = ns.db.sv.profileKeys
		keys["Ann - Mockrealm"], keys["Bo - Mockrealm"], keys["Cy - Elsewhere"] = "Raid", "Raid", "Raid"
		for i = 1, 8 do keys["Alt" .. i .. " - Mockrealm"] = "Crowd" end
		c.autoEnabled.set(nil, true)
		c.auto_dungeon.set(nil, "Raid")
		c.auto_raid.set(nil, "Raid")
		local text = tostring(c.current.name())
		local lines = {}
		for l in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end
		if not (lines[1] or ""):find(GOLD .. "Default|r (in use)", 1, true) then
			fail(scenario, "the profile in use is not first and marked: " .. tostring(lines[1]))
		end
		if (lines[1] or ""):find(GOLD .. "Default|r (in use): this character.", 1, true) ~= 1 then
			fail(scenario, "the profile in use does not say this character is on it: " .. tostring(lines[1]))
		end
		local function lineFor(name)
			for _, l in ipairs(lines) do
				if l:find(GOLD .. name .. "|r", 1, true) == 1 then return l end
			end
			return ""
		end
		local raid = lineFor("Raid")
		if not raid:find("3 characters: Ann, Bo, Cy - Elsewhere", 1, true) then
			fail(scenario, "Raid does not name its three characters: " .. raid)
		end
		if not raid:find("Switched to in dungeons, raids.", 1, true) then
			fail(scenario, "Raid does not say where automatic switching sends this character: " .. raid)
		end
		if lineFor("Default"):find("Switched to", 1, true) then
			fail(scenario, "Default says switching sends this character there: " .. lineFor("Default"))
		end
		if not lineFor("Solo"):find(": nobody.", 1, true) then
			fail(scenario, "a profile nobody is on does not say nobody: " .. lineFor("Solo"))
		end
		local crowd = lineFor("Crowd")
		if not (crowd:find("8 characters: ", 1, true) and crowd:find("3 more", 1, true)) then
			fail(scenario, "eight characters are not counted, five named and the rest summed: " .. crowd)
		end
		-- With the switch off, nothing is said of where it would send anybody.
		c.autoEnabled.set(nil, false)
		if tostring(c.current.name()):find("Switched to", 1, true) then
			fail(scenario, "the overview speaks of switching while it is off")
		end
		-- Another character on the profile in use.
		keys["Dee - Mockrealm"] = "Default"
		if not tostring(c.current.name()):find("2 characters: this character, Dee", 1, true) then
			fail(scenario, "the profile in use does not name this character and the other: " .. tostring(c.current.name()))
		end
	end)
end

-- ------------------------------------------------------------------ pick, then act
do
	local scenario = "profiles-qol: the buttons act on the picked profile, and say why they are greyed"
	with(scenario, function(ns, P, c)
		make(ns, "Raid")
		if c.choose.get() ~= "Default" then fail(scenario, "the dropdown does not start on the profile in use") end
		if not tostring(c.choose.values().Default):find("(in use)", 1, true) then
			fail(scenario, "the dropdown does not mark the profile in use")
		end
		if c.choose.sorting()[1] ~= "Default" then fail(scenario, "the profile in use is not first in the dropdown") end
		-- The one in use: nothing to use, delete or copy, and the reason said.
		if c.use.disabled() ~= true or c.delete.disabled() ~= true or c.copyfrom.disabled() ~= true then
			fail(scenario, "Use, Delete or Copy into is not greyed for the profile in use")
		end
		if c.pickNote.hidden() or not tostring(c.pickNote.name()):find("profile in use", 1, true) then
			fail(scenario, "the reason Delete is greyed is not shown")
		end
		c.choose.set(nil, "Raid")
		if c.use.disabled() or c.delete.disabled() or c.copyfrom.disabled() then
			fail(scenario, "Use, Delete or Copy into is greyed for another profile")
		end
		if not c.pickNote.hidden() then fail(scenario, "a reason is shown with nothing greyed for it") end
		-- The name: checked as a new profile's is, and said under the buttons.
		for _, case in ipairs({ { "", nil }, { ("x"):rep(51), "50 characters" }, { "Default", "already a profile called Default" } }) do
			named(ns, case[1])
			if c.duplicate.disabled() ~= true or c.rename.disabled() ~= true then
				fail(scenario, ("Duplicate and Rename are not greyed for the name %q"):format(case[1]))
			end
			if case[2] and not tostring(c.pickNote.name()):find(case[2], 1, true) then
				fail(scenario, ("the name %q is not said to be wrong: %s"):format(case[1], tostring(c.pickNote.name())))
			end
		end
		named(ns, "Raid copy")
		if c.duplicate.disabled() or c.rename.disabled() then fail(scenario, "a good name greys Duplicate or Rename") end
		-- Duplicate a profile not in use: its settings, nobody moved.
		ns.db:SetProfile("Raid")
		ns.db.profile.verbose = false
		ns.db:SetProfile("Default")
		c.choose.set(nil, "Raid")
		named(ns, "Raid copy")
		c.duplicate.func()
		uses(scenario, ns, "Default", "after Duplicate")
		if type(Mock.sv.profiles["Raid copy"]) ~= "table" then fail(scenario, "Duplicate made nothing") return end
		if #P.Users("Raid copy") ~= 0 then fail(scenario, "Duplicate moved a character onto the copy") end
		if c.choose.get() ~= "Raid copy" then fail(scenario, "the copy is not picked after Duplicate") end
		if not line(ns):find("a copy of", 1, true) then fail(scenario, "the line does not say what Duplicate did: " .. line(ns)) end
		ns.db:SetProfile("Raid copy")
		if ns.db.profile.verbose ~= false then fail(scenario, "the copy of a profile not in use lost its settings") end
		ns.db:SetProfile("Default")
		-- Use switches to the picked one.
		act(ns, "Raid", "use")
		uses(scenario, ns, "Raid", "after Use")
		-- Delete and Copy into ask first, naming the profile, and Delete the
		-- characters that would go to Default.
		ns.db.sv.profileKeys["Ann - Mockrealm"] = "Raid copy"
		c.choose.set(nil, "Raid copy")
		local q = c.delete.confirm()
		if not (tostring(q):find("Raid copy", 1, true) and tostring(q):find("Ann - Mockrealm", 1, true)
			and tostring(q):find("Default", 1, true)) then
			fail(scenario, "Delete does not ask naming the profile and who goes to Default: " .. tostring(q))
		end
		local cq = c.copyfrom.confirm()
		if not (tostring(cq):find("Raid copy", 1, true) and tostring(cq):find("Raid", 1, true)) then
			fail(scenario, "Copy into does not ask naming both profiles: " .. tostring(cq))
		end
		-- The profile new characters start on is a dropdown of its own.
		local values = c.newCharacters.values()
		if values.Default == nil or values.Raid == nil then fail(scenario, "New characters start on does not list every profile") end
	end)
end

-- ------------------------------------------------------------------ rename
do
	local scenario = "profiles-qol: renaming a profile not in use carries its characters, rules and settings"
	with(scenario, function(ns, P, c)
		make(ns, "Raid")
		ns.db:SetProfile("Raid")
		ns.db.profile.verbose = false
		ns.db:SetProfile("Default")
		c.autoEnabled.set(nil, true)
		c.auto_raid.set(nil, "Raid")
		local keys = ns.db.sv.profileKeys
		keys["Ann - Mockrealm"] = "Raid"
		local alt = { autoProfile = { enabled = true, rules = { raid = "Raid", world = "Default" } } }
		ns.db.sv.char = { ["Ann - Mockrealm"] = alt }
		c.newCharacters.set(nil, "Raid")
		local table0 = Mock.sv.profiles.Raid
		c.choose.set(nil, "Raid")
		named(ns, "Raiding")
		c.rename.func()
		uses(scenario, ns, "Default", "after renaming a profile not in use")
		if Mock.sv.profiles.Raid ~= nil then fail(scenario, "the old name is still a profile") end
		if Mock.sv.profiles.Raiding ~= table0 then fail(scenario, "the renamed profile is not the same settings") end
		if keys["Ann - Mockrealm"] ~= "Raiding" then fail(scenario, "a character on it was left on the old name") end
		if c.auto_raid.get() ~= "Raiding" then fail(scenario, "this character's rule did not follow the name") end
		if alt.autoProfile.rules.raid ~= "Raiding" or alt.autoProfile.rules.world ~= "Default" then
			fail(scenario, "another character's rule did not follow the name")
		end
		if c.newCharacters.get() ~= "Raiding" then fail(scenario, "New characters start on did not follow the name") end
		if c.choose.get() ~= "Raiding" then fail(scenario, "the renamed profile is no longer the one picked") end
		if not line(ns):find("Renamed", 1, true) then fail(scenario, "the line does not say what was renamed: " .. line(ns)) end
		-- Undo: the old name back, with everything that followed it.
		c.undo.func()
		if Mock.sv.profiles.Raid ~= table0 or Mock.sv.profiles.Raiding ~= nil then fail(scenario, "Undo did not put the old name back") end
		if keys["Ann - Mockrealm"] ~= "Raid" or c.auto_raid.get() ~= "Raid" or alt.autoProfile.rules.raid ~= "Raid" then
			fail(scenario, "Undo did not put the characters and rules back on the old name")
		end
		if c.newCharacters.get() ~= "Raid" then fail(scenario, "Undo did not put New characters start on back") end
		-- The profile in use renamed, and back.
		named(ns, "Home")
		c.choose.set(nil, "Default")
		c.rename.func()
		uses(scenario, ns, "Home", "after renaming the profile in use")
		c.undo.func()
		uses(scenario, ns, "Default", "after taking that rename back")
		if Mock.sv.profiles.Home ~= nil then fail(scenario, "Undo of a rename left the new name behind") end
		ns.db.sv.char = nil
	end)
end

-- ------------------------------------------------------------------ delete
do
	local scenario = "profiles-qol: Delete sends its characters to Default, and Undo puts the profile, its characters and rules back"
	with(scenario, function(ns, P, c)
		make(ns, "Raid", "Spare")
		ns.db:SetProfile("Raid")
		ns.db.profile.verbose = false
		ns.db:SetProfile("Default")
		local keys = ns.db.sv.profileKeys
		keys["Ann - Mockrealm"], keys["Bo - Mockrealm"] = "Raid", "Raid"
		c.autoEnabled.set(nil, true)
		c.auto_dungeon.set(nil, "Raid")
		local alt = { autoProfile = { enabled = true, rules = { raid = "Raid" } } }
		ns.db.sv.char = { ["Ann - Mockrealm"] = alt }
		local saved = Mock.sv.profiles.Raid
		act(ns, "Raid", "delete")
		if Mock.sv.profiles.Raid ~= nil then fail(scenario, "SKIPPED -- the page did not delete the profile") return end
		if keys["Ann - Mockrealm"] ~= "Default" or keys["Bo - Mockrealm"] ~= "Default" then
			fail(scenario, ("the characters on it did not go to Default: %s, %s")
				:format(tostring(keys["Ann - Mockrealm"]), tostring(keys["Bo - Mockrealm"])))
		end
		if c.auto_dungeon.get() ~= "" then fail(scenario, "the rule naming it was kept") end
		if line(ns) ~= "Deleted " .. GOLD .. "Raid|r." then fail(scenario, "the line does not say what was deleted: " .. line(ns)) end
		if not undoShown(ns) then fail(scenario, "no Undo beside the line") end
		c.undo.func()
		if Mock.sv.profiles.Raid ~= saved then fail(scenario, "Undo did not put the profile's own settings back") end
		if keys["Ann - Mockrealm"] ~= "Raid" or keys["Bo - Mockrealm"] ~= "Raid" then
			fail(scenario, "Undo did not put the characters back on it")
		end
		if c.auto_dungeon.get() ~= "Raid" then fail(scenario, "Undo did not put this character's rule back") end
		if alt.autoProfile.rules.raid ~= "Raid" then fail(scenario, "Undo changed another character's rule") end
		if undoShown(ns) then fail(scenario, "Undo is still offered after it was taken") end
		if not line(ns):find("Put back", 1, true) then fail(scenario, "nothing says it was put back: " .. line(ns)) end
		ns.db:SetProfile("Raid")
		if ns.db.profile.verbose ~= false then fail(scenario, "the profile put back lost a setting") end
		ns.db:SetProfile("Default")
		ns.db.sv.char = nil
	end)
end

-- ------------------------------------------------------------------ reset and copy
do
	local scenario = "profiles-qol: Undo puts back what Reset and Copy into replaced"
	with(scenario, function(ns, P, c)
		make(ns, "Raid")
		ns.db:SetProfile("Raid")
		ns.db.profile.verbose = false
		ns.db:SetProfile("Default")
		ns.db.profile.prompt.width = 333
		act(ns, "Raid", "copyfrom")
		if ns.db.profile.verbose ~= false then fail(scenario, "SKIPPED -- Copy into brought nothing") return end
		if not line(ns):find("Copied", 1, true) then fail(scenario, "the line does not say what was copied: " .. line(ns)) end
		c.undo.func()
		if ns.db.profile.verbose ~= true or ns.db.profile.prompt.width ~= 333 then
			fail(scenario, "Undo did not put back the settings Copy into replaced")
		end
		ns.db.profile.verbose = false
		c.resetProfile.func()
		if ns.db.profile.verbose ~= true then fail(scenario, "SKIPPED -- Reset reset nothing") return end
		if not undoShown(ns) then fail(scenario, "no Undo after Reset") end
		c.undo.func()
		if ns.db.profile.verbose ~= false or ns.db.profile.prompt.width ~= 333 then
			fail(scenario, "Undo did not put back the settings Reset replaced")
		end
		-- A change to a profile's settings is undone only on that profile, even
		-- when automatic switching (no action of the player's) left it.
		rawset(_G, "IsInInstance", function() return false, "none" end)
		c.autoEnabled.set(nil, true)
		c.auto_raid.set(nil, "Raid")
		c.resetProfile.func()
		rawset(_G, "IsInInstance", function() return true, "raid" end)
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.runTimers(2)
		if not uses(scenario, ns, "Raid", "arriving in a raid") then return end
		if undoShown(ns) then fail(scenario, "Undo of a reset is offered on another profile") end
	end)
end

-- ------------------------------------------------------------------ one step
do
	local scenario = "profiles-qol: Undo is one step: the next action takes its place"
	with(scenario, function(ns, P, c)
		make(ns, "Raid", "Spare", "Other")
		act(ns, "Spare", "delete")
		c.resetProfile.func()
		if not line(ns):find("back to its default", 1, true) then fail(scenario, "the line is not the last action's: " .. line(ns)) end
		c.undo.func()
		if Mock.sv.profiles.Spare ~= nil then fail(scenario, "Undo took back an action before the last one") end
		-- Use is an action too: the deleted profile cannot come back after it.
		act(ns, "Raid", "delete")
		if not undoShown(ns) then fail(scenario, "SKIPPED -- no Undo after the delete") end
		act(ns, "Other", "use")
		if undoShown(ns) or P.Undo() ~= false then fail(scenario, "Undo of a delete outlived the next action") end
		if Mock.sv.profiles.Raid ~= nil then fail(scenario, "the deleted profile came back") end
		-- So is a profile picked anywhere else (the minimap's menu, Start here).
		make(ns, "Third")
		act(ns, "Third", "delete")
		ns.db:SetProfile("Default")
		if undoShown(ns) then fail(scenario, "Undo of a delete outlived a profile picked elsewhere") end
	end)
end

-- ------------------------------------------------------------------ paste
do
	local scenario = "profiles-qol: a paste is undone from the same line, into the profile in use or a new one"
	with(scenario, function(ns, P, c)
		local text, other, width = otherSettings(ns)
		-- Into the profile in use, as ever.
		if c.pasteInto.get() ~= "mine" then fail(scenario, "a paste does not go into the profile in use by default") end
		if not c.pasteName.hidden() then fail(scenario, "the new profile's name is asked for a paste into the one in use") end
		c.sharePaste.set(nil, text)
		if ns.db.profile.prompt.width ~= other then fail(scenario, "SKIPPED -- the paste applied nothing") return end
		if line(ns) ~= "Pasted settings into " .. GOLD .. "Default|r." then fail(scenario, "the line does not say what was pasted: " .. line(ns)) end
		c.undo.func()
		if ns.db.profile.prompt.width ~= width then fail(scenario, "Undo did not take the paste back") end
		-- One step: an action after the paste ends its undo, from chat too.
		c.sharePaste.set(nil, text)
		named(ns, "Spare copy")
		c.duplicate.func()
		ns.addon:HandleSlash("import undo")
		if ns.db.profile.prompt.width ~= other then fail(scenario, "the paste was taken back after another action") end
		ns.db.profile.prompt.width = width
		-- Into a new profile, named.
		c.pasteInto.set(nil, "new")
		if c.pasteName.hidden() then fail(scenario, "no box for the new profile's name") end
		local refused = c.sharePaste.validate(nil, text)
		if refused == true then fail(scenario, "a paste into a new profile with no name is let through") end
		c.pasteName.set(nil, "Default")
		if c.sharePaste.validate(nil, text) == true then fail(scenario, "a paste into a name already taken is let through") end
		c.pasteName.set(nil, "Theirs")
		if c.sharePaste.validate(nil, text) ~= true then fail(scenario, "a paste into a new name is refused") end
		Mock.printed = {}
		c.sharePaste.set(nil, text)
		if not uses(scenario, ns, "Theirs", "after a paste into a new profile") then return end
		if c.pasteName.get() ~= "" then fail(scenario, "the new profile's name stays in the box after the paste") end
		if ns.db.profile.prompt.width ~= other then fail(scenario, "the new profile does not have the pasted settings") end
		local said = table.concat(Mock.printed, "\n")
		if said:find("/manners import undo", 1, true) or not said:find("Theirs", 1, true) then
			fail(scenario, "chat offers the import's undo, or does not name the new profile: " .. said)
		end
		ns.db:SetProfile("Theirs")
		if not undoShown(ns) then fail(scenario, "no Undo after a paste into a new profile") end
		c.undo.func()
		uses(scenario, ns, "Default", "after taking the paste into a new profile back")
		if Mock.sv.profiles.Theirs ~= nil then fail(scenario, "Undo left the new profile behind") end
		if ns.db.profile.prompt.width ~= width then fail(scenario, "the profile gone back to has the pasted settings") end
	end)
end

-- ------------------------------------------------------------------ new characters
do
	local scenario = "profiles-qol: New characters start on is kept for the account, and Default when the profile is gone"
	with(scenario, function(ns, P, c)
		make(ns, "Healer")
		if c.newCharacters.get() ~= "Default" then fail(scenario, "New characters do not start on Default by default") end
		c.newCharacters.set(nil, "Healer")
		if ns.db.global.newCharacters ~= "Healer" then fail(scenario, "the choice is not kept for the account") end
		if ns.db.profile.newCharacters ~= nil or ns.db.char.newCharacters ~= nil then
			fail(scenario, "the choice went into a profile or a character")
		end
		if not tostring(c.current.name()):find("New characters start here.", 1, true) then
			fail(scenario, "the overview does not say where new characters start")
		end
		c.newCharacters.set(nil, "Default")
		if ns.db.global.newCharacters ~= nil then fail(scenario, "Default is saved as a name") end
		c.newCharacters.set(nil, "Healer")
		act(ns, "Healer", "delete")
		if c.newCharacters.get() ~= "Default" then fail(scenario, "a deleted profile is still where new characters start") end
		c.undo.func()
		if c.newCharacters.get() ~= "Healer" then fail(scenario, "Undo of the delete did not bring the choice back") end
	end)
end

do
	local scenario = "profiles-qol: a character's first login starts on the profile chosen for new characters"
	local function login(sv)
		Mock.reset()
		local saved = { MannersDB = rawget(_G, "MannersDB"), GetRealmName = rawget(_G, "GetRealmName") }
		rawset(_G, "MannersDB", sv)
		rawset(_G, "GetRealmName", function() return "Mockrealm" end)
		local ok, err = pcall(function()
			local ns = load(scenario)
			if not ns then return end
			ns.addon:OnInitialize()
			for _, e in ipairs(ns.errors or {}) do fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err)) end
		end)
		rawset(_G, "MannersDB", saved.MannersDB)
		rawset(_G, "GetRealmName", saved.GetRealmName)
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		return sv
	end
	local key = tostring((UnitName("player"))) .. " - Mockrealm"
	local function file(start, known)
		return { profileKeys = { ["Other - Mockrealm"] = "Default", [key] = known },
			profiles = { Default = {}, Healer = { verbose = false } }, global = { newCharacters = start } }
	end
	local sv = login(file("Healer"))
	if sv.profileKeys[key] ~= "Healer" then
		fail(scenario, "a new character was not started on the chosen profile: " .. tostring(sv.profileKeys[key]))
	end
	sv = login(file("Healer", "Default"))
	if sv.profileKeys[key] ~= "Default" then fail(scenario, "a character that logged in before was moved: " .. tostring(sv.profileKeys[key])) end
	sv = login(file("Gone"))
	if sv.profileKeys[key] ~= nil then fail(scenario, "a new character was started on a profile that is gone") end
	sv = login(file(nil))
	if sv.profileKeys[key] ~= nil then fail(scenario, "a new character was started somewhere with nothing chosen") end
	if sv.profileKeys["Other - Mockrealm"] ~= "Default" then fail(scenario, "another character was moved") end
end

-- ------------------------------------------------------------------ own profile
do
	local scenario = "profiles-qol: Give this character its own settings is there only while others share the profile"
	with(scenario, function(ns, P, c)
		local own = ns.optionsTable.args.general.args.ownProfile
		if not own.hidden() then fail(scenario, "offered while this character is the only one on its profile") end
		ns.db.sv.profileKeys["Ann - Mockrealm"] = "Default"
		if own.hidden() then fail(scenario, "not offered while another character shares the profile") end
		own.func()
		uses(scenario, ns, ME, "after Give this character its own settings")
		if not own.hidden() then fail(scenario, "still offered once this character has its own") end
	end)
end

-- ------------------------------------------------------------------ a fight
do
	local scenario = "profiles-qol: nothing on the page changes a profile in a fight"
	with(scenario, function(ns, P, c)
		make(ns, "Raid", "Spare")
		act(ns, "Spare", "delete")
		local text = otherSettings(ns)
		Mock.inCombat = true
		local before = {}
		for name in pairs(Mock.sv.profiles) do before[#before + 1] = name end
		table.sort(before)
		c.choose.set(nil, "Raid")
		named(ns, "Fight")
		for _, button in ipairs({ "use", "duplicate", "rename", "delete", "copyfrom", "undo", "resetProfile" }) do
			local greyed = c[button].disabled
			if not (type(greyed) == "function" and greyed() == true) then fail(scenario, button .. " is not greyed in a fight") end
		end
		if P.Use("Raid") or P.Duplicate("Fight", "Raid") or P.Rename("Fight", "Raid") or P.Delete("Raid")
			or P.CopyFrom("Raid") or P.Reset() or P.Undo() or P.PasteAsNew("Fight", text) then
			fail(scenario, "an action went through in a fight")
		end
		c.pasteInto.set(nil, "new")
		c.pasteName.set(nil, "Fight")
		if c.sharePaste.validate(nil, text) == true then fail(scenario, "a paste into a new profile is let through in a fight") end
		local after = {}
		for name in pairs(Mock.sv.profiles) do after[#after + 1] = name end
		table.sort(after)
		if table.concat(before, ",") ~= table.concat(after, ",") then
			fail(scenario, "the profiles changed in a fight: " .. table.concat(after, ","))
		end
		uses(scenario, ns, "Default", "in a fight")
		Mock.inCombat = false
		if not undoShown(ns) then fail(scenario, "the delete's Undo did not wait out the fight") end
	end)
end

-- ------------------------------------------------------------------ the window
do
	local scenario = "profiles-qol: the window draws the manager, Undo only once there is something to undo"
	with(scenario, function(ns, P, c)
		local UI = ns.WindowUI
		if not H.layoutInToc() then return end
		make(ns, "Raid")
		ns.OpenOptions("profiles")
		if not (UI and UI.Shown()) then
			fail(scenario, "SKIPPED -- the options window did not open")
			return
		end
		for _, path in ipairs({ "profiles.current", "profiles.choose", "profiles.name", "profiles.use", "profiles.duplicate",
			"profiles.rename", "profiles.delete", "profiles.copyfrom", "profiles.new", "profiles.newCharacters",
			"profiles.resetProfile", "profiles.pasteInto", "profiles.sharePaste" }) do
			if not UI.RowShown(path) then fail(scenario, path .. " is not drawn on Profiles") end
		end
		if UI.RowShown("profiles.undo") or UI.RowShown("profiles.undoNote") then fail(scenario, "Undo is drawn with nothing to undo") end
		if UI.RowShown("profiles.pasteName") then fail(scenario, "the new profile's name is drawn for a paste into the one in use") end
		act(ns, "Raid", "delete")
		ns.RepaintOptions()
		if not (UI.RowShown("profiles.undo") and UI.RowShown("profiles.undoNote")) then
			fail(scenario, "the line and Undo are not drawn after a delete")
		end
		c.pasteInto.set(nil, "new")
		ns.RepaintOptions()
		if not UI.RowShown("profiles.pasteName") then fail(scenario, "the new profile's name is not drawn for a paste into a new one") end
		-- The name box keeps what is typed with no Enter: a click on Duplicate
		-- leaves the focus in the box.
		local row = UI.RowFor("profiles.name")
		local typed = row and row.box and row.box.scripts and row.box.scripts.OnTextChanged
		if not typed then
			fail(scenario, "SKIPPED -- the name box has no OnTextChanged")
		else
			row.box:SetText("Typed name")
			typed(row.box, true)
			if c.name.get() ~= "Typed name" then fail(scenario, "a name typed without Enter does not reach Duplicate and Rename") end
		end
		UI.Close()
	end)
end
