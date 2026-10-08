-- Round 30, the settings: four faults, each held here by what the player
-- would see.
--
--   * The raid groups switched off on Who to buff (filters.skipRaidGroups)
--     never travelled in /manners export, and an import, which replaces the
--     profile's settings and puts everything it does not name back to its
--     default, left them as they were. ShareFields walks the defaults and
--     knew only buff.skip as a set; the groups' default is an empty table, so
--     the walk found nothing in it. They travel now as group numbers. The
--     never-offer list, empty by default too, stays out on purpose: it is
--     real players' names, and a paste keeps it.
--   * "Give this character its own settings" went to an own profile that was
--     only visited instead of copying the shared settings into it. The repair
--     (ClampSettings) stamps every profile it meets with keys that have no
--     default, AceDB keeps them, and an own profile picked once on the
--     Profiles tab and left without a change was never empty again.
--   * A string the same version made on another game client was said to come
--     "from a newer version of Manners": each client has its own own-buff
--     families (ownBuffs.pick.<key>), and every name Parse did not know was
--     counted as a later version's.
--   * ClampSettings let NaN (a hand-edited 0/0) through every number it
--     bounds: NaN is below and above nothing, so no group cast was ever
--     offered with atLeast at NaN.
--
-- Every scenario name starts with "settings-fix:" so the mutations in
-- tests/mutations/settings-fixes.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local optionText = H.optionText

local function said() return table.concat(Mock.printed or {}, "\n") end

-- The settings string's own checksum, written out again here.
local function signed(body)
	local head = "MNR1:" .. body
	local h = 0
	for i = 1, #head do h = (h * 31 + head:byte(i)) % 16777213 end
	return head .. ":" .. ("%06x"):format(h)
end

-- One driven session with body(ns) run, the mock reset after it whatever
-- happens.
local function session(scenario, body)
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local ok, err = pcall(body, ns)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ raid groups

-- Backup and restore: exported, the profile lost, the string read back.
do
	local scenario = "settings-fix: an export carries the raid groups switched off"
	session(scenario, function(ns)
		local p = ns.db.profile
		p.filters.skipRaidGroups[3] = true
		p.filters.skipRaidGroups[7] = true
		p.prompt.width = 260
		local text = ns.ExportSettings()
		if not text:find("filters.skipRaidGroups=3,7", 1, true) then
			fail(scenario, "the export does not name groups 3 and 7: " .. text)
		end

		p.filters.skipRaidGroups[3] = nil
		p.filters.skipRaidGroups[7] = nil
		p.prompt.width = 220
		local ok, message = ns.ImportSettings(text)
		if not ok then
			fail(scenario, "SKIPPED -- its own export was refused: " .. tostring(message))
		elseif p.prompt.width ~= 260 then
			fail(scenario, "SKIPPED -- the width did not come back either")
		elseif p.filters.skipRaidGroups[3] ~= true or p.filters.skipRaidGroups[7] ~= true then
			fail(scenario, ("restoring an export lost the raid groups switched off: group 3 %s, group 7 %s (string: %s)")
				:format(tostring(p.filters.skipRaidGroups[3]), tostring(p.filters.skipRaidGroups[7]), text))
		end
	end)
end

-- Somebody else's string, which offers every group: the importer's own group
-- switched off goes back on, and the undo switches it off again.
do
	local scenario = "settings-fix: an import puts the raid groups it does not name back on"
	session(scenario, function(ns)
		local p = ns.db.profile
		p.prompt.width = 300
		local theirs = ns.ExportSettings()
		p.prompt.width = 220
		p.filters.skipRaidGroups[5] = true
		local ok = ns.ImportSettings(theirs)
		p = ns.db.profile
		if not ok then
			fail(scenario, "SKIPPED -- the string was refused")
		elseif p.prompt.width ~= 300 then
			fail(scenario, "SKIPPED -- the import did not apply")
		elseif p.filters.skipRaidGroups[5] ~= nil then
			fail(scenario, "an import that replaces this profile's settings left raid group 5 switched off")
		else
			ns.UndoImport()
			if p.filters.skipRaidGroups[5] ~= true then
				fail(scenario, "the undo did not switch raid group 5 off again")
			end
		end
	end)
end

-- Read as group numbers, and only the eight a raid has.
do
	local scenario = "settings-fix: a string's raid groups are read as group numbers"
	session(scenario, function(ns)
		local p = ns.db.profile
		local ok, message = ns.ImportSettings(signed("filters.skipRaidGroups=2,8;prompt.width=250"))
		if not ok then
			fail(scenario, "a string with raid groups was refused: " .. tostring(message))
		elseif p.filters.skipRaidGroups[2] ~= true or p.filters.skipRaidGroups[8] ~= true
			or p.filters.skipRaidGroups["2"] ~= nil then
			fail(scenario, ("groups 2 and 8 were not switched off by number: 2 %s, 8 %s, \"2\" %s")
				:format(tostring(p.filters.skipRaidGroups[2]), tostring(p.filters.skipRaidGroups[8]),
					tostring(p.filters.skipRaidGroups["2"])))
		end
		p.prompt.width = 220
		ok = ns.ImportSettings(signed("filters.skipRaidGroups=3,9;prompt.width=250"))
		if ok or p.prompt.width ~= 220 then
			fail(scenario, "a string switching off a raid group 9 was read")
		end
	end)
end

-- The never-offer list: names put there by hand, never written into a line
-- handed to somebody, and kept through a paste as the page's reset keeps it.
-- A guard on a decision, not on a fault: no mutation undoes it in one place.
do
	local scenario = "settings-fix: the never-offer list stays out of a string and through a paste"
	session(scenario, function(ns)
		local p = ns.db.profile
		p.never["Griefer Grim"] = true
		local text = ns.ExportSettings()
		if text:find("Griefer", 1, true) then
			fail(scenario, "the export carries a name off the never-offer list: " .. text)
		end
		local ok, message = ns.ImportSettings(signed("prompt.width=250;never.Somebody=1"))
		if not ok then
			fail(scenario, "SKIPPED -- the string was refused: " .. tostring(message))
		else
			if not ns.db.profile.never["Griefer Grim"] then
				fail(scenario, "a paste emptied the never-offer list")
			end
			if tostring(message):find("newer version", 1, true) then
				fail(scenario, "a never-offer name in a string was called a newer version's setting: " .. message)
			end
		end
	end)
end

-- ------------------------------------------------------------------ own profile

local ME, ALT = "Mort Defrette - Realm", "Bob Barley - Realm"

-- AceDB's record of who is on which profile, its keys and its CopyProfile, as
-- hunt13-fix3.lua adds them to the mock's AceDB (which switches profiles the
-- library's way, defaults stripped on the way out).
local function accountOf(ns, others)
	local db, sv = ns.db, Mock.sv
	local calls = { copy = 0 }
	sv.profileKeys = { [ME] = sv.profileName or "Default" }
	for char, profile in pairs(others) do sv.profileKeys[char] = profile end
	db.sv, db.keys = sv, { char = ME }
	db.GetCurrentProfile = function() return sv.profileName or "Default" end
	local realSet = db.SetProfile
	db.SetProfile = function(self, name)
		realSet(self, name)
		sv.profileKeys[ME] = name
	end
	local function fill(dest, src)
		for k, v in pairs(src) do
			if type(v) == "table" then
				if type(dest[k]) ~= "table" then dest[k] = {} end
				fill(dest[k], v)
			else
				dest[k] = v
			end
		end
	end
	db.CopyProfile = function(self, name)
		calls.copy = calls.copy + 1
		local source = sv.profiles[name]
		if type(source) ~= "table" then error("Cannot copy profile '" .. tostring(name) .. "'. It does not exist.") end
		wipe(self.profile)
		fill(self.profile, ns.defaults.profile)
		fill(self.profile, source)
		local copied = Mock.dbCallbacks["OnProfileCopied"]
		if copied then copied.target[copied.method](copied.target, "OnProfileCopied", self, name) end
	end
	return calls, function()
		db.SetProfile, db.CopyProfile, db.GetCurrentProfile = realSet, nil, nil
		db.sv, db.keys = nil, nil
	end
end

local function ownSession(scenario, body)
	Mock.reset()
	Mock.sv = {}
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local own = ns.optionsTable.args.general.args.ownProfile
		local calls, undo = accountOf(ns, { [ALT] = "Default" })
		local ok, err = pcall(body, ns, own, calls)
		undo()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end

-- What a profile left behind holds, for the failure line.
local function holds(t)
	local keys = {}
	for k, v in pairs(t or {}) do
		if type(v) == "table" then
			for k2 in pairs(v) do keys[#keys + 1] = k .. "." .. tostring(k2) end
		else
			keys[#keys + 1] = k
		end
	end
	table.sort(keys)
	return table.concat(keys, ", ")
end

-- The character's own name picked under Existing Profiles, looked at, and
-- left without a change: it holds only what the repair stamped on it.
do
	local scenario = "settings-fix: an own profile only visited is filled from the shared one"
	ownSession(scenario, function(ns, own, calls)
		ns.db.profile.prompt.width = 400
		ns.db.profile.sources.strangers = false
		ns.db:SetProfile(ME)
		ns.db:SetProfile("Default")
		if type(Mock.sv.profiles[ME]) ~= "table" or next(Mock.sv.profiles[ME]) == nil then
			fail(scenario, "SKIPPED -- the visit left nothing behind, so this is hunt13-fix3's empty profile")
		end
		if optionText(own.name) ~= "Give this character its own settings" then
			fail(scenario, ("an own profile nobody changed counts as one to go back to (%s); it holds only %s")
				:format(optionText(own.name), holds(Mock.sv.profiles[ME])))
		end
		own.func()
		local p = ns.db.profile
		if ns.db:GetCurrentProfile() ~= ME then
			fail(scenario, "SKIPPED -- the press did not switch to " .. ME)
		elseif calls.copy ~= 1 or p.prompt.width ~= 400 or p.sources.strangers ~= false then
			fail(scenario, ("the press landed on a profile of defaults, not the shared settings: %d copies, width %s, passers-by %s, firstRun %s")
				:format(calls.copy, tostring(p.prompt.width), tostring(p.sources.strangers), tostring(p.firstRun)))
		end
	end)
end

-- Lines of the player's own typed into it on the visit: set up, so gone back
-- to and never copied over.
do
	local scenario = "settings-fix: an own profile with lines typed on it is gone back to"
	ownSession(scenario, function(ns, own, calls)
		ns.db:SetProfile(ME)
		ns.db.profile.speech.phrases = "Mine, {name}."
		ns.db:SetProfile("Default")
		if optionText(own.name) ~= "Go back to this character's own settings" then
			fail(scenario, ("an own profile holding lines the player typed counts as untouched (%s); it holds %s")
				:format(optionText(own.name), holds(Mock.sv.profiles[ME])))
		end
		own.func()
		if calls.copy ~= 0 or ns.db.profile.speech.phrases ~= "Mine, {name}." then
			fail(scenario, "going back copied the shared settings over the lines typed on it: "
				.. tostring(ns.db.profile.speech.phrases))
		end
		if not said():find("back on its own settings", 1, true) then
			fail(scenario, "going back said: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ other clients

local CASES = {
	-- Made on Forever by a mage who switched an own buff's reminder off, read on
	-- Burning Crusade and on retail.
	{ from = "camelot", class = "MAGE", family = "imbue", value = "off", into = "tbc" },
	{ from = "camelot", class = "MAGE", family = "familiar", value = "off", into = "mainline" },
	-- Made on Burning Crusade by a druid who switched Omen of Clarity off, read
	-- on Forever, which has no Omen family.
	{ from = "tbc", class = "DRUID", family = "omen", value = "off", into = "camelot" },
}

for _, case in ipairs(CASES) do
	local scenario = ("settings-fix: a %s string read on %s is not called newer (%s)")
		:format(case.from, case.into, case.family)
	local text
	Mock.reset()
	Mock.setFlavour(case.from)
	Mock.class = case.class
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		if not ns.FindOwnFamily(case.family) then
			fail(scenario, "SKIPPED -- " .. case.from .. " has no " .. case.family .. " family")
		else
			ns.db.profile.ownBuffs.pick[case.family] = case.value
			ns.db.profile.prompt.width = 260
			text = ns.ExportSettings()
			if not tostring(text):find("ownBuffs.pick." .. case.family .. "=", 1, true) then
				fail(scenario, "SKIPPED -- the export does not carry the pick: " .. tostring(text))
				text = nil
			end
		end
	end
	Mock.reset()

	if text then
		Mock.reset()
		Mock.setFlavour(case.into)
		Mock.class = case.class
		local other = load(scenario)
		if other then
			drive(scenario, other)
			other.Prompt:ExitTest()
			Mock.printed = {}
			local ok, message = other.ImportSettings(text)
			if not ok then
				fail(scenario, "SKIPPED -- the string was refused: " .. tostring(message))
			elseif other.db.profile.prompt.width ~= 260 then
				fail(scenario, "SKIPPED -- the import did not apply")
			elseif tostring(message):find("newer version", 1, true) then
				fail(scenario, ("a string the same version made on %s is said to come from a newer Manners: %s")
					:format(case.from, tostring(message)))
			end
		end
		Mock.reset()
	end
end

-- An own buff no client of this version has is still a later version's.
do
	local scenario = "settings-fix: an own buff no client has is still called newer"
	session(scenario, function(ns)
		local ok, message = ns.ImportSettings(signed("prompt.width=250;ownBuffs.pick.notafamily=off"))
		if not (ok and tostring(message):find("newer version", 1, true)) then
			fail(scenario, "an own buff no client has was skipped without a word: " .. tostring(message))
		end
	end)
end

-- ------------------------------------------------------------------ NaN

do
	local scenario = "settings-fix: a NaN in a saved number is put back to its default"
	session(scenario, function(ns)
		local p = ns.db.profile
		local d = ns.defaults.profile
		local nan = 0 / 0
		p.groupBuffs.atLeast = nan
		p.timing.scanInterval = nan
		p.prompt.scale = nan
		p.filters.manaFloor = nan
		ns.ClampSettings()
		for _, f in ipairs({
			{ "groupBuffs.atLeast", p.groupBuffs.atLeast, d.groupBuffs.atLeast },
			{ "timing.scanInterval", p.timing.scanInterval, d.timing.scanInterval },
			{ "prompt.scale", p.prompt.scale, d.prompt.scale },
			{ "filters.manaFloor", p.filters.manaFloor, d.filters.manaFloor },
		}) do
			if f[2] ~= f[3] then
				fail(scenario, ("%s is %s after the repair, not its default %s")
					:format(f[1], tostring(f[2]), tostring(f[3])))
			end
		end
	end)
end
