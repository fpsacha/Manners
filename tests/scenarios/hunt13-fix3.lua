-- Round 13, the options page and the settings string: four faults, each held
-- here by what the player would see.
--
--   * "Give this character its own settings" on a character that already has
--     a profile of its own: AceDB's CopyProfile empties the profile it copies
--     into, so a second press wiped everything set on it. It goes back to it
--     now, and says so. On a profile an alt came to, the button did nothing
--     without a word; it is hidden there, and the note says who is on it.
--   * The Advanced tab hidden from a hunter, whose own prompt has a first
--     line, a reason, timings and a place like anybody's, while Look sent him
--     there. It follows the prompt now; what is about other people inside it
--     does not show for him, and Look points a rogue at no tab.
--   * A paste reset "Tell me in chat", which the Profiles tab promises a paste
--     keeps. It is kept, and a 1.4.0 string that carries it is read without
--     calling it a newer version's setting.
--   * Sliders and key bindings left at AceConfigDialog's 170 pixels, so a long
--     label was cut before its unit: "Top up when less than this is l...".
--
-- Every scenario name starts with "hunt13-fix3:" so the mutations in
-- tests/mutations/hunt13-fix3.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption, optionText = H.findOption, H.optionText

local ME, ALT = "Mort Defrette - Realm", "Bob Barley - Realm"
local HAWK, MONKEY = 13165, 13163

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function said() return table.concat(Mock.printed, "\n") end

local function shown(control)
	if control == nil then return false end
	local hidden = control.hidden
	if type(hidden) == "function" then hidden = hidden({}) end
	return not hidden
end

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell" }

-- One driven session as `class`, knowing `known` (spell ids) when given, with
-- body(ns) run and everything put back whether it finished or threw.
local function with(scenario, class, known, body)
	Mock.reset()
	Mock.sv = {}
	if class then Mock.class = class end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	if known then
		local set = {}
		for _, id in ipairs(known) do set[id] = true end
		IsSpellKnown = function(id) return set[id] == true end
		IsPlayerSpell = IsSpellKnown
	end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		body(ns)
		noErrors(scenario, ns)
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ profiles
-- The mock's AceDB switches profiles the library's way (Mock.sv.profiles, the
-- defaults stripped on the way out) but has no record of who is on which, no
-- keys and no CopyProfile. Added here as the library has them: SetProfile
-- files this character under the profile it arrives at, and CopyProfile
-- resets the profile being copied into before it copies, which is the whole
-- of the fault. `others` is the rest of the account, character to profile.
local function accountOf(ns, others)
	local db, sv = ns.db, Mock.sv
	local calls = { set = 0, copy = 0 }
	sv.profileKeys = { [ME] = sv.profileName or "Default" }
	for char, profile in pairs(others) do sv.profileKeys[char] = profile end
	db.sv, db.keys = sv, { char = ME }
	db.GetCurrentProfile = function() return sv.profileName or "Default" end
	local realSet = db.SetProfile
	db.SetProfile = function(self, name)
		calls.set = calls.set + 1
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
		if name == self:GetCurrentProfile() then error("Cannot have the same source and destination profiles.") end
		local source = sv.profiles[name]
		if type(source) ~= "table" then error("Cannot copy profile '" .. tostring(name) .. "'. It does not exist.") end
		wipe(self.profile)
		fill(self.profile, ns.defaults.profile)
		fill(self.profile, source)
	end
	return calls, function()
		db.SetProfile, db.CopyProfile, db.GetCurrentProfile = realSet, nil, nil
		db.sv, db.keys = nil, nil
	end
end

-- Mort makes his own profile, sets it up, then goes back to Default, which an
-- alt shares. The button is back, and pressing it must take him to what he
-- set up, not make a new copy of Default over it.
do
	local scenario = "hunt13-fix3: going back to this character's own profile never copies over it"
	with(scenario, nil, nil, function(ns)
		local general = ns.optionsTable.args.general.args
		local own = general.ownProfile
		local calls, undo = accountOf(ns, { [ALT] = "Default" })
		local ok, err = pcall(function()
			if not shown(own) then
				fail(scenario, "SKIPPED -- the button is not offered on a shared Default")
				return
			end
			if optionText(own.name) ~= "Give this character its own settings" then
				fail(scenario, "with no profile of its own yet the button reads " .. optionText(own.name))
			end
			own.func()
			if ns.db:GetCurrentProfile() ~= ME or calls.copy ~= 1 then
				fail(scenario, "SKIPPED -- the first press did not make a copy: "
					.. tostring(ns.db:GetCurrentProfile()) .. ", " .. calls.copy .. " copies")
				return
			end
			-- What he set up on it.
			local p = ns.db.profile
			p.prompt.width = 400
			p.never["Griefer Grim"] = true
			p.speech.phrases = "Mine, {name}."
			p.filters.skipRaidGroups[7] = true

			-- The Profiles tab, back to the shared one.
			ns.db:SetProfile("Default")
			if not shown(own) then
				fail(scenario, "back on the shared Default, the button is not offered")
			end
			if optionText(own.name) ~= "Go back to this character's own settings" then
				fail(scenario, "with a profile of its own, the button reads " .. optionText(own.name))
			end
			if not optionText(own.desc):find("nothing is copied or overwritten", 1, true) then
				fail(scenario, "the button's tooltip does not say nothing is overwritten: " .. optionText(own.desc))
			end

			Mock.printed = {}
			local copies = calls.copy
			own.func()
			p = ns.db.profile
			if ns.db:GetCurrentProfile() ~= ME then
				fail(scenario, "going back did not switch to " .. ME .. ": " .. tostring(ns.db:GetCurrentProfile()))
			end
			if calls.copy ~= copies then
				fail(scenario, "going back copied over this character's own profile")
			end
			if p.prompt.width ~= 400 or not p.never["Griefer Grim"] or p.speech.phrases ~= "Mine, {name}."
				or not p.filters.skipRaidGroups[7] then
				fail(scenario, ("going back lost what was set on it: width %s, never %s, phrases %q, raid group 7 %s")
					:format(tostring(p.prompt.width), tostring(p.never["Griefer Grim"]),
						tostring(p.speech.phrases), tostring(p.filters.skipRaidGroups[7])))
			end
			if not said():find("This character is back on its own settings (profile: " .. ME .. ").", 1, true) then
				fail(scenario, "going back said: " .. said())
			end
		end)
		undo()
		if not ok then error(err, 0) end
	end)
end

-- An own profile nobody changed is empty once left (AceDB strips the
-- defaults), and a copy into it loses nothing: that one is made fresh.
do
	local scenario = "hunt13-fix3: an empty profile of its own is made again from the shared one"
	with(scenario, nil, nil, function(ns)
		local own = ns.optionsTable.args.general.args.ownProfile
		local calls, undo = accountOf(ns, { [ALT] = "Default" })
		Mock.sv.profiles[ME] = {}
		local ok, err = pcall(function()
			if optionText(own.name) ~= "Give this character its own settings" then
				fail(scenario, "an empty profile of its own counts as one to go back to: " .. optionText(own.name))
			end
			own.func()
			if calls.copy ~= 1 then
				fail(scenario, "an empty profile of its own was not filled from the shared one")
			end
		end)
		undo()
		if not ok then error(err, 0) end
	end)
end

-- Bob picked Mort's profile. On Mort, somebody else is on this profile, so the
-- old rule showed the button, and the press returned at once without a word.
do
	local scenario = "hunt13-fix3: an alt on this character's profile hides the button and says why"
	with(scenario, nil, nil, function(ns)
		local general = ns.optionsTable.args.general.args
		local note, own = general.sharedNote, general.ownProfile
		ns.db:SetProfile(ME)
		local calls, undo = accountOf(ns, { [ALT] = ME })
		local ok, err = pcall(function()
			if ns.Setup.SharedWith() ~= 1 then
				fail(scenario, "SKIPPED -- the alt is not counted on this profile")
				return
			end
			if shown(own) then
				fail(scenario, "the button is offered on a profile the others came to, where it does nothing")
			end
			if not shown(note) then
				fail(scenario, "the note is hidden while an alt is on this character's profile")
			end
			local text = optionText(note.name)
			if not text:find("Your other characters are using this character's settings (profile: "
				.. ME .. "); they can pick their own on the Profiles tab.", 1, true) then
				fail(scenario, "the note does not say the others are on this character's profile: " .. text)
			end
			if not text:find("The Profiles tab also copies settings as text to share.", 1, true) then
				fail(scenario, "the note lost its sentence about sharing as text: " .. text)
			end
			Mock.printed = {}
			local sets, copies = calls.set, calls.copy
			local width = ns.db.profile.prompt.width
			ns.Setup.OwnProfile()
			if calls.set ~= sets or calls.copy ~= copies or ns.db:GetCurrentProfile() ~= ME
				or ns.db.profile.prompt.width ~= width then
				fail(scenario, "a press on this character's own profile changed it")
			end
			if not said():find("they can pick their own on the Profiles tab", 1, true) then
				fail(scenario, "a press on this character's own profile said nothing: " .. said())
			end
		end)
		undo()
		if not ok then error(err, 0) end
	end)
end

-- ------------------------------------------------------------------ Advanced
-- A hunter with his aspects learned has a prompt and so an Advanced tab: the
-- wording of his own line, the timings and the exact place are his. The
-- favours, the other people's reason lines and handing a target back are not.
-- A rogue has no prompt, no tab, and Look points him at none.
local HUNTER_SHOWN = { "reasonSelf", "retryCooldown", "scanInterval", "x", "y", "format",
	"reasonRefresh", "timingHeader", "exactPosHeader", "wordingHeader", "resetAdvanced" }
local HUNTER_HIDDEN = { "favoursHeader", "owedClassBuffsOnly", "reciprocateWindow", "reachableOnly",
	"graceSeconds", "keepDebts", "targetingHeader", "restoreTarget", "noTargetNote", "reasonTarget",
	"reasonOwed", "reasonAsked", "reasonGroup", "reasonNearby", "reasonUnknown" }

do
	local scenario = "hunt13-fix3: the Advanced tab fits a hunter"
	with(scenario, "HUNTER", { HAWK, MONKEY }, function(ns)
		if not (ns.OwnBuffsOnly and ns.OwnBuffsOnly()) then
			fail(scenario, "SKIPPED -- a hunter with his aspects learned has no prompt of his own")
			return
		end
		local adv = ns.optionsTable.args.advanced
		if not shown(adv) then
			fail(scenario, "the Advanced tab is hidden from a hunter, whose own prompt it words and places")
			return
		end
		for _, key in ipairs(HUNTER_SHOWN) do
			if not shown(adv.args[key]) then fail(scenario, key .. " is hidden from a hunter") end
		end
		for _, key in ipairs(HUNTER_HIDDEN) do
			if shown(adv.args[key]) then fail(scenario, key .. " is shown to a hunter") end
		end
		local look = ns.optionsTable.args.appearance.args
		if not optionText(look.posPreset.desc):find("|cffffd100Exact position|r (Advanced)", 1, true) then
			fail(scenario, "posPreset does not point a hunter at Exact position: " .. optionText(look.posPreset.desc))
		end
		if not shown(look.wordingNote) then
			fail(scenario, "wordingNote is hidden from a hunter, whose wording is on Advanced")
		end
	end)
end

do
	local scenario = "hunt13-fix3: a rogue has no Advanced tab and is pointed at none"
	with(scenario, "ROGUE", nil, function(ns)
		if ns.OwnBuffsOnly() or ns.caps.hasClassBuffs then
			fail(scenario, "SKIPPED -- the rogue has a prompt")
			return
		end
		if shown(ns.optionsTable.args.advanced) then
			fail(scenario, "the Advanced tab is shown to a rogue, who has no prompt")
		end
		local look = ns.optionsTable.args.appearance.args
		local desc = optionText(look.posPreset.desc)
		if desc:find("(Advanced)", 1, true) then
			fail(scenario, "posPreset points a rogue at an Advanced tab he does not have: " .. desc)
		end
		if not desc:find("Pick Above the action bars to put it back where it started.", 1, true) then
			fail(scenario, "posPreset lost its first sentence for a rogue: " .. desc)
		end
		if shown(look.wordingNote) then
			fail(scenario, "wordingNote points a rogue at an Advanced tab he does not have")
		end
	end)
end

-- And a mage keeps all of it.
do
	local scenario = "hunt13-fix3: a mage keeps every Advanced control"
	with(scenario, nil, nil, function(ns)
		local adv = ns.optionsTable.args.advanced
		for _, key in ipairs(HUNTER_HIDDEN) do
			if key ~= "noTargetNote" and not shown(adv.args[key]) then
				fail(scenario, key .. " is hidden from a mage")
			end
		end
	end)
end

-- ------------------------------------------------------------------ share
-- The settings string's own checksum, written out again here.
local function signed(body)
	local head = "MNR1:" .. body
	local h = 0
	for i = 1, #head do h = (h * 31 + head:byte(i)) % 16777213 end
	return head .. ":" .. ("%06x"):format(h)
end

do
	local scenario = "hunt13-fix3: a paste keeps Tell me in chat"
	with(scenario, nil, nil, function(ns)
		local p = ns.db.profile
		p.verbose = false
		if ns.ExportSettings():find("verbose=", 1, true) then
			fail(scenario, "Tell me in chat is written into the settings string: " .. ns.ExportSettings())
		end
		local ok, message = ns.ImportSettings(signed("prompt.width=300"))
		if not ok or p.prompt.width ~= 300 then
			fail(scenario, "SKIPPED -- the paste did not apply: " .. tostring(message))
		elseif p.verbose ~= false then
			fail(scenario, "a paste changed Tell me in chat back on")
		end

		-- A 1.4.0 string carries it. Read, not applied, and not called a
		-- newer version's setting; nor are the lock and the place, which a
		-- string written by hand may carry.
		p.verbose = true
		ok, message = ns.ImportSettings(signed("prompt.width=280;verbose=0;prompt.x=5;minimap.hide=1"))
		if not ok then
			fail(scenario, "a 1.4.0 string was refused: " .. tostring(message))
		else
			if p.verbose ~= true then
				fail(scenario, "a 1.4.0 string's verbose=0 switched Tell me in chat off")
			end
			if tostring(message):find("newer version", 1, true) then
				fail(scenario, "an old string's verbose=0 was called a newer version's setting: " .. tostring(message))
			end
			if p.prompt.width ~= 280 then
				fail(scenario, "the setting beside it did not arrive: " .. tostring(p.prompt.width))
			end
		end
		-- A name no version knows is still owned up to.
		ok, message = ns.ImportSettings(signed("prompt.width=270;prompt.madeUp=1"))
		if not (ok and tostring(message):find("newer version", 1, true)) then
			fail(scenario, "a setting no version knows was skipped without a word: " .. tostring(message))
		end
	end)
end

-- ------------------------------------------------------------------ labels
-- AceConfigDialog gives every control 170 pixels unless told otherwise, and a
-- slider's or key binding's label is one line across the top of it, cut with
-- an ellipsis at the edge. Measured on the recording frames, where a font
-- string is half its size a character wide, 12 before anything sets one.
dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local function withTree(scenario, locale, body)
	Mock.reset()
	Mock.locale = locale
	FT.install()
	FT.measure = nil
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns) end
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function units(node)
	local width = node.width
	if type(width) == "function" then width = width({ option = node }) end
	if width == "full" then return math.huge end
	return type(width) == "number" and width or (width == "double" and 2) or (width == "half" and 0.5) or 1
end

local function labelsOf(node, out)
	if type(node) ~= "table" then return out end
	if node.type == "range" or node.type == "keybinding" then out[#out + 1] = node end
	if type(node.args) == "table" then
		for _, child in pairs(node.args) do labelsOf(child, out) end
	end
	return out
end

local function chars(text)
	return select(2, tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[^\128-\191]", ""))
end

do
	local scenario = "hunt13-fix3: a long slider or key binding label is not cut at 170 pixels"
	withTree(scenario, "enUS", function(ns)
		drive(scenario, ns)
		for _, key in ipairs({ "refreshUnder", "manaFloor", "bindKey" }) do
			local node = findOption(ns.optionsTable, key)
			if not node then
				fail(scenario, "SKIPPED -- there is no " .. key)
			elseif units(node) <= 1 then
				fail(scenario, ("%s is left at 170 pixels with the label %q"):format(key, optionText(node.name)))
			end
		end
		local scale = findOption(ns.optionsTable, "scale")
		if scale and units(scale) ~= 1 then
			fail(scenario, "Scale, a short label, is widened to " .. tostring(units(scale) * 170))
		end
		-- An explicit width is the option's own and is never touched.
		local window = findOption(ns.optionsTable, "reciprocateWindow")
		if window and window.width ~= "double" then
			fail(scenario, "Offer a buff back for lost its double width: " .. tostring(window.width))
		end
	end)
end

for _, locale in ipairs({ "enUS", "deDE", "frFR" }) do
	local scenario = "hunt13-fix3: every fitted slider and key binding holds its label (" .. locale .. ")"
	withTree(scenario, locale, function(ns)
		drive(scenario, ns)
		local nodes = labelsOf(ns.optionsTable, {})
		if #nodes < 10 then
			fail(scenario, ("SKIPPED -- only %d sliders and key bindings found"):format(#nodes))
			return
		end
		for _, node in ipairs(nodes) do
			if type(node.width) == "function" then
				local text = optionText(node.name)
				local needed = chars(text) * 6
				if units(node) * 170 < needed then
					fail(scenario, ("%q is %d wide and needs %d -- the game cuts it with an ellipsis")
						:format(text, units(node) * 170, needed))
				end
			end
		end
	end)
end
Mock.reset()
